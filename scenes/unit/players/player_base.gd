extends Unit
class_name PlayerBase

# ==============================================================================
# 1. 通用信号 & 属性
# ==============================================================================
signal energy_changed(current, max_val)
signal armor_changed(current)

# 玩家ID，用于从CSV加载配置
@export var player_id: String = ""

@export_group("Common Settings")
@export var dash_vfx_scene: PackedScene 

# 从CSV加载的配置数据
var config: Dictionary = {}

# 通用数值（从CSV加载）
var max_energy: float = 999.0
var energy_regen: float = 0.5
var max_armor: int = 3
var base_speed: float = 300.0

# 冲刺相关（从CSV加载）
var dash_distance: float = 400.0
var dash_speed: float = 2000.0
var dash_damage: int = 20
var dash_knockback: float = 2.0
var dash_cost: float = 10.0

# 技能消耗（从CSV加载）
var skill_q_cost: float = 50.0
var skill_e_cost: float = 30.0

# 其他通用配置
var close_threshold: float = 60.0

# 状态相关
var energy: float = 0.0
var armor: int = 0
var move_dir: Vector2 = Vector2.ZERO
var external_force: Vector2 = Vector2.ZERO
var external_force_decay: float = 50.0  # 进一步增加衰减速度，从30.0改为50.0

# 冲刺状态
var is_dashing: bool = false
var dash_target: Vector2 = Vector2.ZERO
var dash_start_pos: Vector2 = Vector2.ZERO

@onready var collision: CollisionShape2D = $CollisionShape2D
@onready var dash_hitbox: HitboxComponent = $DashHitbox
@onready var trail: Trail = %Trail if has_node("%Trail") else null
@onready var weapon_container: WeaponContainer = $WeaponContainer if has_node("WeaponContainer") else null

# 武器管理
var current_weapons: Array[Weapon] = []

# UI元素
var energy_bar_ui: Control = null 

func _ready() -> void:
	# 从CSV加载配置（必须在super._ready()之前，这样才能设置stats）
	_load_config_from_csv()
	
	super._ready() # 初始化 Stats
	
	# 加载武器
	_load_weapons_from_config()
	
	# 确保加入 player 组
	if not is_in_group("player"):
		add_to_group("player")
	
	# 注册全局引用
	Global.player = self
	
	# 连接死亡信号
	if health_component and not health_component.on_unit_died.is_connected(_on_death):
		health_component.on_unit_died.connect(_on_death)
	
	# 初始化数值
	energy = max_energy
	armor = max_armor
	update_ui_signals()
	
	# 创建能量槽UI
	_create_energy_bar_ui()
	
	print(">>> 玩家加载完成: %s (ID: %s, 武器数: %d)" % [self.name, player_id, current_weapons.size()])

func _load_config_from_csv() -> void:
	if player_id.is_empty():
		printerr("[PlayerBase] 警告: player_id 未设置，使用默认值")
		return
	
	config = ConfigManager.get_player_config(player_id)
	
	if config.is_empty():
		printerr("[PlayerBase] 警告: 未找到配置 '%s'，使用默认值" % player_id)
		return
	
	# 加载基础属性
	max_energy = config.get("max_energy", 999.0)
	energy_regen = config.get("energy_regen", 0.5)
	max_armor = config.get("max_armor", 3)
	base_speed = config.get("base_speed", 300.0)
	
	# 加载冲刺属性
	dash_distance = config.get("dash_distance", 400.0)
	dash_speed = config.get("dash_speed", 2000.0)
	dash_damage = config.get("dash_damage", 20)
	dash_knockback = config.get("dash_knockback", 2.0)
	dash_cost = config.get("dash_cost", 10.0)
	
	# 加载技能消耗
	skill_q_cost = config.get("skill_q_cost", 50.0)
	skill_e_cost = config.get("skill_e_cost", 30.0)
	
	# 加载其他配置
	close_threshold = config.get("close_threshold", 60.0)
	
	# 加载初始能量值
	var initial_energy = config.get("initial_energy", max_energy)
	energy = initial_energy
	
	# 【关键修复】从CSV加载生命值和速度，覆盖场景文件中的stats
	# 如果stats不存在，创建一个新的
	if stats == null:
		stats = UnitStats.new()
	
	# 从CSV设置生命值和速度
	var csv_health = config.get("health", 5000.0)
	var csv_speed = config.get("base_speed", 300.0)
	
	stats.health = csv_health
	stats.speed = csv_speed
	
	print("[PlayerBase] 从CSV加载属性:")
	print("  - health: %d" % csv_health)
	print("  - speed: %d" % csv_speed)
	print("  - dash_distance: %d" % dash_distance)
	print("  - dash_speed: %d" % dash_speed)

func _load_weapons_from_config() -> void:
	if player_id.is_empty() or not weapon_container:
		return
	
	var weapon_cfg = ConfigManager.get_player_weapons(player_id)
	if weapon_cfg.is_empty():
		print("[PlayerBase] 未找到武器配置 for ", player_id)
		return
	
	# 加载每个武器槽位
	for i in range(1, 7):
		var slot_key = "weapon_slot_%d" % i
		var weapon_id = weapon_cfg.get(slot_key, "")
		
		if weapon_id != "":
			# 从CSV创建ItemWeapon对象
			var item_weapon = _create_item_weapon_from_csv(weapon_id)
			if item_weapon:
				_add_weapon(item_weapon)

func _create_item_weapon_from_csv(weapon_id: String) -> ItemWeapon:
	"""从CSV配置创建ItemWeapon对象"""
	var weapon_stats_data = ConfigManager.get_weapon_stats(weapon_id)
	if weapon_stats_data.is_empty():
		print("[PlayerBase] 未找到武器配置: ", weapon_id)
		return null
	
	# 创建WeaponStats对象
	var weapon_stats = WeaponStats.new()
	weapon_stats.damage = weapon_stats_data.get("damage", 10.0)
	weapon_stats.accuracy = weapon_stats_data.get("accuracy", 0.9)
	weapon_stats.cooldown = weapon_stats_data.get("cooldown", 1.0)
	weapon_stats.crit_chance = weapon_stats_data.get("crit_chance", 0.05)
	weapon_stats.crit_damage = weapon_stats_data.get("crit_damage", 1.5)
	weapon_stats.max_range = weapon_stats_data.get("max_range", 150.0)
	weapon_stats.knockback = weapon_stats_data.get("knockback", 0.0)
	weapon_stats.life_steal = weapon_stats_data.get("life_steal", 0.0)
	weapon_stats.recoil = weapon_stats_data.get("recoil", 25.0)
	weapon_stats.recoil_duration = weapon_stats_data.get("recoil_duration", 0.1)
	weapon_stats.attack_duration = weapon_stats_data.get("attack_duration", 0.2)
	weapon_stats.back_duration = weapon_stats_data.get("back_duration", 0.15)
	weapon_stats.projectile_speed = weapon_stats_data.get("projectile_speed", 1600.0)
	
	# 加载子弹场景（如果有）
	var projectile_scene_path = weapon_stats_data.get("projectile_scene", "")
	if projectile_scene_path != "":
		weapon_stats.projectile_scene = load(projectile_scene_path) as PackedScene
		if not weapon_stats.projectile_scene:
			printerr("[PlayerBase] 错误: 无法加载子弹场景: ", projectile_scene_path)
	
	# 创建ItemWeapon对象
	var item_weapon = ItemWeapon.new()
	item_weapon.item_name = weapon_stats_data.get("display_name", weapon_id)
	item_weapon.stats = weapon_stats
	
	# 加载武器场景
	var weapon_scene_path = weapon_stats_data.get("weapon_scene", "")
	if weapon_scene_path == "":
		print("[PlayerBase] 武器场景路径为空: ", weapon_id)
		return null
	
	item_weapon.scene = load(weapon_scene_path) as PackedScene
	if not item_weapon.scene:
		print("[PlayerBase] 无法加载武器场景: ", weapon_scene_path)
		return null
	
	# 设置武器类型（根据是否有子弹场景判断）
	if projectile_scene_path != "":
		item_weapon.type = ItemWeapon.WeaponType.RANGE
	else:
		item_weapon.type = ItemWeapon.WeaponType.MELEE
	
	return item_weapon

func _add_weapon(data: ItemWeapon) -> void:
	"""添加武器到玩家"""
	if not data or not data.scene:
		return
	
	var weapon := data.scene.instantiate() as Weapon
	if not weapon:
		return
	
	add_child(weapon)
	weapon.setup_weapon(data)
	current_weapons.append(weapon)
	
	if weapon_container:
		weapon_container.update_weapons_position(current_weapons)
	
	print("[PlayerBase] 添加武器: ", data.item_name)

func _process(delta: float) -> void:
	if Global.game_paused: return
	
	# 能量恢复
	if energy < max_energy:
		energy += energy_regen * delta
		update_ui_signals()
	
	# 外力衰减（极快的衰减，几乎消除击退感）
	if external_force.length() > 1.0:  # 进一步降低阈值，从5.0改为1.0
		position += external_force * delta
		external_force = external_force.lerp(Vector2.ZERO, external_force_decay * delta)
	else:
		external_force = Vector2.ZERO
	
	_handle_input(delta)
	_process_subclass(delta)
	update_rotation()

func _handle_input(delta: float) -> void:
	# 1. 移动逻辑
	move_dir = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if can_move():
		var current_speed = base_speed 
		if stats != null:
			current_speed = stats.speed
		position += move_dir * current_speed * delta
		# 移除移动限制，允许无限移动
		# position.x = clamp(position.x, -2000, 2000)
		# position.y = clamp(position.y, -2000, 2000)

	# 2. 技能按键分发 (核心修复在这里！)
	
	# === 优先级 1: E 技能 ===
	if Input.is_action_just_pressed("skill_e"):
		use_skill_e()
		return # 阻止其他输入

	# === 优先级 2: Q 技能 (规划模式) ===
	if Input.is_action_pressed("skill_q"):
		charge_skill_q(delta)
		# 【关键】如果正在按 Q，左键点击只属于 Q 技能，
		# 哪怕你点了左键，也不要往下执行 use_dash！
		return 
	
	elif Input.is_action_just_released("skill_q"):
		release_skill_q()
		return

	# === 优先级 3: 普通左键冲刺 ===
	# 只有没按 Q 也没按 E 的时候，左键才算冲刺
	if Input.is_action_just_pressed("click_left"):
		use_dash()

# --- 虚函数 (子类重写) ---
func can_move() -> bool: return not is_dashing
func _process_subclass(delta: float) -> void: 
	# 处理冲刺移动
	_process_dash_movement(delta)

# 通用冲刺实现（子类可以重写）
func use_dash() -> void: 
	if is_dashing or not consume_energy(dash_cost): 
		return
	
	var mouse_pos = get_global_mouse_position()
	var dir = (mouse_pos - global_position).normalized()
	dash_start_pos = global_position
	dash_target = dash_start_pos + dir * dash_distance
	
	_start_dash()

func _start_dash() -> void:
	is_dashing = true
	collision.set_deferred("disabled", true)
	dash_hitbox.set_deferred("monitorable", true)
	dash_hitbox.set_deferred("monitoring", true)
	dash_hitbox.setup(dash_damage, false, dash_knockback, self)
	
	if trail: 
		trail.start_trail()
	
	Global.play_player_dash()

func _process_dash_movement(delta: float) -> void:
	if not is_dashing:
		return
		
	position = position.move_toward(dash_target, dash_speed * delta)
	
	if position.distance_to(dash_target) < 10.0:
		_end_dash()

func _end_dash() -> void:
	is_dashing = false
	collision.set_deferred("disabled", false)
	dash_hitbox.set_deferred("monitorable", false)
	dash_hitbox.set_deferred("monitoring", false)
	
	if trail: 
		trail.stop()
	
	_on_dash_complete()

# 子类可重写此方法来添加冲刺结束后的逻辑
func _on_dash_complete() -> void:
	pass

# 技能虚函数（子类必须实现）       
func charge_skill_q(delta:float) -> void: pass 
func release_skill_q() -> void: pass   
func use_skill_e() -> void: pass       

# --- 战斗逻辑 ---
func take_damage(raw_amount: float) -> void:
	var reduction_per_armor = 0.2
	var damage_multiplier = 1.0 - (clamp(armor, 0, max_armor) * reduction_per_armor)
	var final_damage = max(1, raw_amount * damage_multiplier)
	
	if armor > 0:
		armor -= 1
		Global.spawn_floating_text(global_position, "Armor Crack!", Color.YELLOW)
		armor_changed.emit(armor)
		# 护甲破碎时的轻微反馈
		Global.on_camera_shake.emit(4.0, 0.1)
		Global.frame_freeze(0.03, 0.2)
	else:
		Global.spawn_floating_text(global_position, "-%d" % final_damage, Color.RED)
		# 增强玩家受击反馈
		Global.on_camera_shake.emit(10.0, 0.25)
		Global.frame_freeze(0.08, 0.15)
	
	health_component.take_damage(final_damage)

func apply_knockback_self(force: Vector2) -> void:
	# 应用击退力缩放系数，减少击退效果
	var knockback_scale = 0.3  # 只应用30%的击退力
	external_force = force * knockback_scale
	Global.on_camera_shake.emit(5.0, 0.1)

func consume_energy(amount: float) -> bool:
	if energy >= amount:
		energy -= amount
		update_ui_signals()
		return true
	else:
		Global.spawn_floating_text(global_position, "No Energy!", Color.RED)
		return false

# 击杀敌人时获得能量
func gain_energy(amount: float) -> void:
	energy = min(energy + amount, max_energy)
	update_ui_signals()
	Global.spawn_floating_text(global_position, "+%d Energy" % amount, Color.CYAN)

func update_ui_signals() -> void:
	energy_changed.emit(energy, max_energy)
	armor_changed.emit(armor)
	
	# 同时更新能量槽UI（如果存在）
	if energy_bar_ui and energy_bar_ui.has_method("update_bar"):
		var value = energy / max_energy if max_energy > 0 else 0
		energy_bar_ui.update_bar(value, energy)

func _create_energy_bar_ui() -> void:
	print("[PlayerBase] 开始创建能量槽UI")
	
	# 加载能量槽脚本
	var energy_bar_script = load("res://scenes/ui/energy_bar.gd")
	if not energy_bar_script:
		print("[PlayerBase] 错误：无法加载energy_bar.gd")
		return
	
	# 创建能量槽控件
	energy_bar_ui = Control.new()
	energy_bar_ui.name = "EnergyBarUI"
	energy_bar_ui.set_script(energy_bar_script)
	
	# 设置为Canvas Layer的子节点，这样UI会显示在屏幕上
	var canvas_layer = CanvasLayer.new()
	canvas_layer.name = "EnergyBarLayer"
	add_child(canvas_layer)
	
	# 创建ProgressBar
	var progress_bar = ProgressBar.new()
	progress_bar.name = "ProgressBar"
	progress_bar.custom_minimum_size = Vector2(200, 30)
	progress_bar.max_value = 1.0
	progress_bar.value = 1.0
	progress_bar.show_percentage = false
	energy_bar_ui.add_child(progress_bar)
	
	# 创建Label
	var label = Label.new()
	label.name = "EnergyAmount"
	label.position = Vector2(10, 5)
	label.text = str(int(energy))
	label.add_theme_font_size_override("font_size", 16)
	energy_bar_ui.add_child(label)
	
	# 设置位置（屏幕左上角，血条下方）
	energy_bar_ui.position = Vector2(20, 80)
	energy_bar_ui.custom_minimum_size = Vector2(200, 30)
	
	# 添加到Canvas Layer
	canvas_layer.add_child(energy_bar_ui)
	
	# 设置颜色
	energy_bar_ui.set("back_color", Color(0.2, 0.2, 0.3))
	energy_bar_ui.set("fill_color", Color(0.3, 0.8, 1.0))
	
	# 调用_ready初始化
	if energy_bar_ui.has_method("_ready"):
		energy_bar_ui._ready()
	
	# 连接信号
	if not energy_changed.is_connected(_on_energy_changed_for_ui):
		energy_changed.connect(_on_energy_changed_for_ui)
	
	print("[PlayerBase] 能量槽UI创建完成")
	print("  位置: ", energy_bar_ui.position)
	print("  大小: ", energy_bar_ui.custom_minimum_size)

func _on_energy_changed_for_ui(current: float, max_val: float) -> void:
	if energy_bar_ui and energy_bar_ui.has_method("_on_player_energy_changed"):
		energy_bar_ui._on_player_energy_changed(current, max_val)

func update_rotation() -> void:
	var facing_dir = get_global_mouse_position() - global_position
	if facing_dir.x != 0:
		visuals.scale.x = -0.5 if facing_dir.x > 0 else 0.5

func is_facing_right() -> bool:
	# 根据 visuals 的 scale.x 判断朝向
	# scale.x = -0.5 表示朝右，0.5 表示朝左
	return visuals.scale.x < 0

func _on_death() -> void:
	print(">>> 玩家死亡 <<<")
	Global.play_player_death()
	visuals.visible = false
	# 简单的死亡粒子生成
	var emitter = CPUParticles2D.new()
	emitter.emitting = true
	emitter.one_shot = true
	emitter.amount = 30
	emitter.explosiveness = 1.0
	emitter.gravity = Vector2(0, 800)
	emitter.color = Color.WHITE
	emitter.global_position = global_position
	get_tree().current_scene.add_child(emitter)
	
	collision.set_deferred("disabled", true)
	set_process(false)
	set_physics_process(false)
	
	# 慢动作后重开
	Engine.time_scale = 0.2
	await get_tree().create_timer(1.0).timeout
	Engine.time_scale = 1.0
	get_tree().reload_current_scene()
