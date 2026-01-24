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

# ==============================================================================
# 2. 道具系统 (Item System)
# ==============================================================================

# 修改器管理器（Tier 2 道具使用）
var modifier_manager: Node = null

# 当前装备的道具 ID（用于 Tier 3 圣物）
var equipped_item_id: String = "" 

func _ready() -> void:
	# 从CSV加载配置（必须在super._ready()之前，这样才能设置stats）
	_load_config_from_csv()
	
	# 从CSV加载精灵图片
	_load_sprite_from_csv()
	
	super._ready() # 初始化 Stats
	
	# 初始化修改器管理器
	modifier_manager = ModifierManager
	if not modifier_manager:
		printerr("[PlayerBase] 错误: ModifierManager 未加载")
		return
	
	# 装备道具（从 EquipmentManager 读取）
	_load_and_equip_item()
	
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

func _exit_tree() -> void:
	# 不清理任何技能效果，让它们按照自己的生命周期自然消失
	# 技能效果（火海、风墙、地雷等）已经添加到场景根节点，有独立的生命周期管理
	# 切换角色时不应该强制清理这些效果
	pass


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
	
	# 如果stats不存在，创建一个新的
	if stats == null:
		stats = UnitStats.new()
	
	# 从CSV设置生命值和速度
	var csv_health = config.get("health", 5000.0)
	var csv_speed = config.get("base_speed", 300.0)
	
	stats.health = csv_health
	stats.speed = csv_speed
	
	# 确保 block_chance 被初始化（防止 nil 错误）
	if not stats.has_meta("block_chance"):
		stats.block_chance = 0.0

func _load_sprite_from_csv() -> void:
	"""从CSV加载角色精灵图片，覆盖场景文件中的硬编码纹理"""
	if player_id.is_empty():
		return
	
	var visual_config = ConfigManager.get_player_visual(player_id)
	if visual_config.is_empty():
		return
	
	var sprite_path = visual_config.get("sprite_path", "")
	if sprite_path == "":
		return
	
	# 获取Sprite节点（在Visuals下）
	var sprite_node = null
	if has_node("Visuals/Sprite"):
		sprite_node = get_node("Visuals/Sprite")
	elif visuals and visuals.has_node("Sprite"):
		sprite_node = visuals.get_node("Sprite")
	
	if not sprite_node:
		return
	
	# 加载纹理
	var texture = load(sprite_path) as Texture2D
	if texture:
		sprite_node.texture = texture
	else:
		printerr("[PlayerBase] 错误: 无法加载精灵纹理: %s" % sprite_path)

func _load_weapons_from_config() -> void:
	if player_id.is_empty() or not weapon_container:
		return
	
	# 检查是否有从选择界面传入的武器类型
	var selected_weapon_type = ""
	if Global.selected_player_weapons.has(player_id):
		selected_weapon_type = Global.selected_player_weapons[player_id]
	
	# 如果有选择的武器类型，只加载1级武器
	if selected_weapon_type != "":
		var weapon_id = "%s_1" % selected_weapon_type
		var item_weapon = _create_item_weapon_from_csv(weapon_id)
		if item_weapon:
			_add_weapon(item_weapon)
		return

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

# ==============================================================================
# 道具装备系统 (Item Equipment System)
# ==============================================================================

## 从 EquipmentManager 加载并装备道具
func _load_and_equip_item() -> void:
	if not EquipmentManager:
		return
	
	# 获取装备的道具类型（整数）
	var item_type = EquipmentManager.get_equipped_item(player_id)
	if item_type <= 0:
		if OS.is_debug_build():
			print("[PlayerBase] 角色 %s 未装备任何道具" % player_id)
		return
	
	# 将 item_type 转换为 item_id
	# 注意：这里需要根据实际的道具系统映射关系来转换
	# 暂时使用占位逻辑，后续需要完善
	var item_id = _get_item_id_from_type(item_type)
	if item_id != "":
		equip_item(item_id)

## 装备道具（核心函数）
## @param item_id: 道具 ID（如 "attr_hp_potion", "magic_fire_heart"）
func equip_item(item_id: String) -> void:
	if item_id.is_empty():
		return
	
	# 从 ConfigManager 读取道具配置
	var item_data = _load_item_config(item_id)
	if item_data.is_empty():
		printerr("[PlayerBase] 错误: 未找到道具配置 '%s'" % item_id)
		return
	
	var tier = int(item_data.get("item_tier", 1))
	
	if OS.is_debug_build():
		print("[PlayerBase] 装备道具: %s (Tier %d)" % [item_data.get("item_name", item_id), tier])
	
	# Step 1: 重置基础属性（确保数值一致性）
	_load_config_from_csv()
	
	# Step 2: 根据 Tier 分流处理
	match tier:
		1:  # Tier 1: 直接修改属性
			_apply_tier1_item(item_data)
		2:  # Tier 2: 添加修改器
			_apply_tier2_item(item_data)
		3:  # Tier 3: 注册圣物（供 BondManager 读取）
			_apply_tier3_item(item_data)
		_:
			printerr("[PlayerBase] 错误: 未知的道具层级 %d" % tier)
	
	# 保存装备的道具 ID
	equipped_item_id = item_id

## Tier 1: 直接修改属性
func _apply_tier1_item(item_data: Dictionary) -> void:
	var effect_target = item_data.get("effect_target", "")
	var target_tags = item_data.get("target_tags", "")
	var value = float(item_data.get("effect_value", 0.0))
	
	if effect_target != "stat":
		printerr("[PlayerBase] 错误: Tier 1 道具的 effect_target 必须是 'stat'")
		return
	
	# 解析目标属性（如 "health", "speed", "damage"）
	var stat_name = target_tags.strip_edges()
	
	match stat_name:
		"health":
			stats.health += value
			if OS.is_debug_build():
				print("[PlayerBase] 生命值 +%.0f -> %.0f" % [value, stats.health])
		"speed":
			stats.speed += value
			if OS.is_debug_build():
				print("[PlayerBase] 速度 +%.0f -> %.0f" % [value, stats.speed])
		"damage":
			stats.damage += value
			if OS.is_debug_build():
				print("[PlayerBase] 攻击力 +%.0f -> %.0f" % [value, stats.damage])
		_:
			printerr("[PlayerBase] 警告: 未知的属性名称 '%s'" % stat_name)

## Tier 2: 添加修改器
func _apply_tier2_item(item_data: Dictionary) -> void:
	var effect_type = item_data.get("effect_type", "")
	var target_tags_str = item_data.get("target_tags", "")
	var value = float(item_data.get("effect_value", 0.0))
	
	if not modifier_manager:
		printerr("[PlayerBase] 错误: ModifierManager 未初始化")
		return
	
	# 解析标签（如 "fire" 或 "fire;aoe"）
	var target_tags = []
	if target_tags_str != "":
		target_tags = target_tags_str.split(";")
	
	# 添加修改器
	modifier_manager.add_modifier(target_tags, effect_type, value)
	
	if OS.is_debug_build():
		print("[PlayerBase] 添加修改器: tags=%s, type=%s, value=%.2f" % [target_tags, effect_type, value])

## Tier 3: 注册圣物（供 BondManager 读取）
func _apply_tier3_item(item_data: Dictionary) -> void:
	var target_tags = item_data.get("target_tags", "")
	var value = int(item_data.get("effect_value", 1))
	
	# 注意：这里只是存储 item_id，实际的羁绊标签应用由 BondManager 处理
	# BondManager 会调用 get_equipped_relic_tags() 获取圣物提供的标签
	
	if OS.is_debug_build():
		print("[PlayerBase] 注册圣物: 提供羁绊标签 '%s' x%d" % [target_tags, value])

## 获取装备的圣物提供的羁绊标签（供 BondManager 调用）
func get_equipped_relic_tags() -> Dictionary:
	if equipped_item_id.is_empty():
		return {}
	
	var item_data = _load_item_config(equipped_item_id)
	if item_data.is_empty():
		return {}
	
	var tier = int(item_data.get("item_tier", 1))
	if tier != 3:
		return {}
	
	var tag = item_data.get("target_tags", "")
	var count = int(item_data.get("effect_value", 1))
	
	return {tag: count}

## 从 CSV 加载道具配置
func _load_item_config(item_id: String) -> Dictionary:
	var file = FileAccess.open("res://config/item/item_effect_config.csv", FileAccess.READ)
	if not file:
		printerr("[PlayerBase] 错误: 无法打开 item_effect_config.csv")
		return {}
	
	file.get_line()  # 跳过表头
	
	while not file.eof_reached():
		var line = file.get_csv_line()
		if line.size() < 10:
			continue
		
		if line[0] == item_id:
			return {
				"item_id": line[0],
				"item_name": line[1],
				"item_type": line[2],
				"item_tier": line[3],
				"effect_type": line[4],
				"effect_target": line[5],
				"target_tags": line[6],
				"effect_value": line[7],
				"icon_path": line[8],
				"description": line[9]
			}
	
	return {}

## 将 item_type（整数）转换为 item_id（字符串）
## 注意：这是临时映射，后续需要根据实际道具系统完善
func _get_item_id_from_type(item_type: int) -> String:
	# 从 item_config.csv 读取映射关系
	var file = FileAccess.open("res://config/item/item_config.csv", FileAccess.READ)
	if not file:
		printerr("[PlayerBase] 错误: 无法打开 item_config.csv")
		return ""
	
	file.get_line()  # 跳过表头
	
	while not file.eof_reached():
		var line = file.get_csv_line()
		if line.size() < 3:
			continue
		
		var type_id = int(line[0])
		if type_id == item_type:
			# 从 item_effect_config.csv 中查找对应的 item_id
			# 这里使用简单的命名规则：根据 item_type 推断 item_id
			# 例如：item_type=1 -> "attr_hp_potion"
			return _infer_item_id_from_type(item_type)
	
	return ""

## 根据 item_type 推断 item_id（临时方案）
func _infer_item_id_from_type(item_type: int) -> String:
	# 这是一个临时映射表，后续需要根据实际道具系统完善
	var type_to_id_map = {
		# Tier 1: 属性道具
		1: "attr_hp_potion",
		2: "attr_speed_boots",
		3: "attr_damage_dagger",
		# Tier 2: 魔法道具
		4: "magic_fire_heart",
		5: "magic_ice_crystal",
		6: "magic_aoe_amplifier",
		7: "magic_damage_boost",
		8: "magic_duration_extend",
		9: "magic_speed_boost",
		# Tier 3: 圣物道具
		10: "relic_martial",
		11: "relic_arcane",
		12: "relic_survivor",
		13: "relic_destruction",
		14: "relic_velocity",
		15: "relic_control"
	}
	
	return type_to_id_map.get(item_type, "")

## 获取技能参数（经过道具加成）
## @param base_value: 基础数值
## @param tags: 技能标签数组（如 ["damage", "fire", "aoe"]）
## @return: 修改后的最终数值
func get_skill_param(base_value: float, tags: Array) -> float:
	if not modifier_manager:
		return base_value
	
	return modifier_manager.get_modified_value(base_value, tags)

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

# 获得经验值 - 使用 Global.session_xp（局内累积）
func add_xp(amount: int) -> void:
	Global.add_session_xp(amount)  # 直接更新 Global 的 session_xp
	xp = Global.session_xp  # 同步本地变量（兼容性）
	xp_changed.emit(Global.session_xp)
	Global.spawn_floating_text(global_position + Vector2(20, -10), "+%d XP" % amount, Color.MEDIUM_PURPLE)

# 获得金币 - 使用 DataManager（局外持久化）
func add_gold(amount: int) -> void:
	DataManager.add_gold(amount)  # 直接更新 DataManager
	gold = DataManager.get_total_gold()  # 同步本地变量（兼容性）
	gold_changed.emit(DataManager.get_total_gold())
	Global.spawn_floating_text(global_position + Vector2(-20, -10), "+%d Gold" % amount, Color.GOLD)

func update_ui_signals() -> void:
	energy_changed.emit(energy, max_energy)
	armor_changed.emit(armor)
	
	# 同时更新能量槽UI（如果存在）
	if energy_bar_ui and energy_bar_ui.has_method("update_bar"):
		var value = energy / max_energy if max_energy > 0 else 0
		energy_bar_ui.update_bar(value, energy)

func _create_energy_bar_ui() -> void:
	# 已禁用 - 能量条现在由底部 Squad HUD 显示
	# 不再在左上角创建单独的能量条
	pass

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

# ==============================================================================
# LineBreaker 切线逻辑 - 虚函数，子类可重写
# ==============================================================================
## 尝试切断玩家的线（由 LineBreaker 敌人调用）
## 子类如果有线技能，应该重写此方法来处理切线逻辑
func try_break_line(enemy_pos: Vector2, radius: float) -> void:
	# 默认实现：什么都不做
	# 子类（如 PlayerHerder, PlayerWeaver 等）可以重写此方法
	pass

## 清理所有技能效果（角色切换时调用）
func _cleanup_all_skills() -> void:
	# 获取所有技能并调用cleanup()
	if has_node("SkillManager"):
		var skill_manager = get_node("SkillManager")
		if skill_manager.has_method("cleanup_all_skills"):
			skill_manager.cleanup_all_skills()
	
	# 直接清理各个技能
	for child in get_children():
		if child.has_method("cleanup"):
			child.cleanup()
