extends Unit
class_name PlayerBase

# ==============================================================================
# 1. 通用信号 & 属性
# ==============================================================================
signal energy_changed(current, max_val)
signal armor_changed(current)
signal xp_changed(current)
signal gold_changed(current)

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

# 技能消耗（从CSV加载）
var skill_q_cost: float = 50.0
var skill_e_cost: float = 30.0

# 其他通用配置
var close_threshold: float = 60.0

# 状态相关
var energy: float = 0.0
var armor: int = 0
var xp: int = 0           # 经验值
var gold: int = 0         # 金币
var move_dir: Vector2 = Vector2.ZERO
var external_force: Vector2 = Vector2.ZERO
var external_force_decay: float = 50.0  # 从CSV加载
var knockback_scale: float = 0.3  # 从CSV加载
var reduction_per_armor: float = 0.2  # 从game_config加载

@onready var collision: CollisionShape2D = $CollisionShape2D
@onready var weapon_container: WeaponContainer = $WeaponContainer if has_node("WeaponContainer") else null

# 武器管理
var current_weapons: Array[Weapon] = []

# UI元素
var energy_bar_ui: Control = null 

func _ready() -> void:
	print("[PlayerBase] _ready() 开始, player_id=%s" % player_id)
	# 从CSV加载配置（必须在super._ready()之前，这样才能设置stats）
	_load_config_from_csv()
	
	# 从CSV加载精灵图片
	_load_sprite_from_csv()
	
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
	
	# 加载技能消耗
	skill_q_cost = config.get("skill_q_cost", 50.0)
	skill_e_cost = config.get("skill_e_cost", 30.0)
	
	# 加载其他配置
	close_threshold = config.get("close_threshold", 60.0)
	external_force_decay = config.get("external_force_decay", 50.0)
	knockback_scale = config.get("knockback_scale", 0.3)
	
	# 从game_config加载护甲减伤系数
	reduction_per_armor = ConfigManager.get_game_setting("armor_reduction_per_level", 0.2)
	
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

func _load_sprite_from_csv() -> void:
	"""从CSV加载角色精灵图片，覆盖场景文件中的硬编码纹理"""
	if player_id.is_empty():
		return
	
	var visual_config = ConfigManager.get_player_visual(player_id)
	if visual_config.is_empty():
		print("[PlayerBase] 警告: 未找到视觉配置 '%s'" % player_id)
		return
	
	var sprite_path = visual_config.get("sprite_path", "")
	if sprite_path == "":
		print("[PlayerBase] 警告: 视觉配置 '%s' 缺少 sprite_path" % player_id)
		return
	
	# 获取Sprite节点（在Visuals下）
	var sprite_node = null
	if has_node("Visuals/Sprite"):
		sprite_node = get_node("Visuals/Sprite")
	elif visuals and visuals.has_node("Sprite"):
		sprite_node = visuals.get_node("Sprite")
	
	if not sprite_node:
		print("[PlayerBase] 警告: 未找到 Sprite 节点")
		return
	
	# 加载纹理
	var texture = load(sprite_path) as Texture2D
	if texture:
		sprite_node.texture = texture
		print("[PlayerBase] 从CSV加载精灵: %s -> %s" % [player_id, sprite_path])
	else:
		printerr("[PlayerBase] 错误: 无法加载精灵纹理: %s" % sprite_path)

func _load_weapons_from_config() -> void:
	if player_id.is_empty() or not weapon_container:
		print("[PlayerBase] _load_weapons_from_config: player_id=%s, weapon_container=%s" % [player_id, weapon_container])
		return
	
	print("[PlayerBase] _load_weapons_from_config 开始: player_id=%s" % player_id)
	print("[PlayerBase] Global.selected_player_weapons = %s" % str(Global.selected_player_weapons))
	
	# 检查是否有从选择界面传入的武器类型
	var selected_weapon_type = ""
	if Global.selected_player_weapons.has(player_id):
		selected_weapon_type = Global.selected_player_weapons[player_id]
		print("[PlayerBase] 使用选择的武器类型: %s" % selected_weapon_type)
	else:
		print("[PlayerBase] 未找到选择的武器，使用默认配置")
	
	# 如果有选择的武器类型，只加载1级武器
	if selected_weapon_type != "":
		var weapon_id = "%s_1" % selected_weapon_type
		var item_weapon = _create_item_weapon_from_csv(weapon_id)
		if item_weapon:
			_add_weapon(item_weapon)
			print("[PlayerBase] 加载武器: %s" % weapon_id)
		return
	
	# 否则使用默认配置（从CSV表加载，暂时禁用）
	# var weapon_cfg = ConfigManager.get_player_weapons(player_id)
	# if weapon_cfg.is_empty():
	#     return
	# 
	# # 加载每个武器槽位
	# for i in range(1, 7):
	#     var slot_key = "weapon_slot_%d" % i
	#     var weapon_id = weapon_cfg.get(slot_key, "")
	#     if weapon_id != "":
	#         var item_weapon = _create_item_weapon_from_csv(weapon_id)
	#         if item_weapon:
	#             _add_weapon(item_weapon)
	print("[PlayerBase] 未选择武器，跳过默认配置加载")

func _create_item_weapon_from_csv(weapon_id: String) -> ItemWeapon:
	"""从CSV配置创建ItemWeapon对象"""
	var weapon_stats_data = ConfigManager.get_weapon_stats(weapon_id)
	if weapon_stats_data.is_empty():
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
		return null
	
	item_weapon.scene = load(weapon_scene_path) as PackedScene
	if not item_weapon.scene:
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
	# 移动逻辑
	move_dir = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if can_move():
		var current_speed = base_speed 
		if stats != null:
			current_speed = stats.speed
		position += move_dir * current_speed * delta
		# 移除移动限制，允许无限移动
		# position.x = clamp(position.x, -2000, 2000)
		# position.y = clamp(position.y, -2000, 2000)

	# 技能按键分发由各个子类的SkillManager处理

# --- 虚函数 (子类重写) ---
func can_move() -> bool: 
	return true  # 移动控制现在由SkillManager和各个技能处理

func _process_subclass(delta: float) -> void: 
	pass  # 子类可以重写此方法添加额外逻辑       

# --- 战斗逻辑 ---
func take_damage(raw_amount: float) -> void:
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
	# 应用击退力缩放系数，减少击退效果（从CSV加载）
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

# 获得经验值
func add_xp(amount: int) -> void:
	xp += amount
	xp_changed.emit(xp)
	Global.spawn_floating_text(global_position + Vector2(20, -10), "+%d XP" % amount, Color.MEDIUM_PURPLE)

# 获得金币
func add_gold(amount: int) -> void:
	gold += amount
	gold_changed.emit(gold)
	Global.spawn_floating_text(global_position + Vector2(-20, -10), "+%d Gold" % amount, Color.GOLD)

func update_ui_signals() -> void:
	energy_changed.emit(energy, max_energy)
	armor_changed.emit(armor)
	
	# 同时更新能量槽UI（如果存在）
	if energy_bar_ui and energy_bar_ui.has_method("update_bar"):
		var value = energy / max_energy if max_energy > 0 else 0
		energy_bar_ui.update_bar(value, energy)

func _create_energy_bar_ui() -> void:
	# 加载能量槽脚本
	var energy_bar_script = load("res://scenes/ui/energy_bar.gd")
	if not energy_bar_script:
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
	
	# 调用全局游戏结束逻辑
	Global.game_over()

## 清理技能效果（角色切换时调用）
func _cleanup_skill_effects() -> void:
	# 检查子类是否有skill_manager
	if "skill_manager" in self and self.skill_manager:
		var sm = self.skill_manager as SkillManager
		if sm:
			# 遍历所有技能并调用cleanup
			for skill in sm.get_all_skills():
				if skill and skill.has_method("cleanup"):
					skill.cleanup()
			print("[PlayerBase] 已清理所有技能效果")
