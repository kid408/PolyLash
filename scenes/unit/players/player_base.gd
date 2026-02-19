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
var max_energy: float = 100.0
var energy_regen: float = 0.5
var max_armor: int = 3
var base_speed: float = 300.0
var pickup_range: float = 150.0  # 拾取范围（炼金术士羁绊会修改）

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

# 大招系统 (F键)
var ultimate_skill: SkillUltimate = null

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
	# 从CSV加载配置（必须在super._ready()之前，这样才能设置属性）
	_load_config_from_csv()
	
	# 从CSV加载精灵图片
	_load_sprite_from_csv()
	
	super._ready() # 初始化基类（会调用 health_component.setup_with_health）
	
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
	if health_component:
		if not health_component.on_unit_died.is_connected(_on_death):
			health_component.on_unit_died.connect(_on_death)
			print("[PlayerBase] 死亡信号已连接")
		else:
			print("[PlayerBase] 死亡信号已经连接过了")
	else:
		printerr("[PlayerBase] 错误：health_component 不存在！")
	
	# 初始化数值
	energy = max_energy
	armor = max_armor
	update_ui_signals()
	
	# 创建能量槽UI
	_create_energy_bar_ui()
	
	# 加载大招技能
	_load_ultimate_skill()
	
	# 延迟创建技能管理器，等待子类 _ready() 完成后再检查
	# 这样子类有机会先创建自己的 SkillManager
	call_deferred("_auto_create_skill_manager")

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
	max_energy = config.get("max_energy", 100.0)
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
	
	# 从CSV设置生命值和速度（直接设置到 Unit 基类的属性）
	var csv_health = config.get("health", 100.0)
	var csv_speed = config.get("base_speed", 300.0)
	
	health = csv_health
	speed = csv_speed
	
	# 应用 DataManager 升级加成（角色强化界面购买的属性提升）
	if DataManager:
		var hp_bonus = DataManager.get_attribute_bonus(player_id, "hp")
		var energy_bonus = DataManager.get_attribute_bonus(player_id, "max_energy")
		var regen_bonus = DataManager.get_attribute_bonus(player_id, "energy_regen")
		var speed_bonus = DataManager.get_attribute_bonus(player_id, "base_speed")
		var armor_bonus = DataManager.get_attribute_bonus(player_id, "max_armor")
		
		if hp_bonus > 0:
			health += hp_bonus
			print("[PlayerBase] 升级加成 HP: +%.0f -> %.0f" % [hp_bonus, health])
		if energy_bonus > 0:
			max_energy += energy_bonus
			print("[PlayerBase] 升级加成 能量: +%.0f -> %.0f" % [energy_bonus, max_energy])
		if regen_bonus > 0:
			energy_regen += regen_bonus
			print("[PlayerBase] 升级加成 能量恢复: +%.1f -> %.1f" % [regen_bonus, energy_regen])
		if speed_bonus > 0:
			speed += speed_bonus
			base_speed += speed_bonus
			print("[PlayerBase] 升级加成 速度: +%.0f -> %.0f" % [speed_bonus, speed])
		if armor_bonus > 0:
			max_armor += int(armor_bonus)
			print("[PlayerBase] 升级加成 护甲: +%d -> %d" % [int(armor_bonus), max_armor])
	
	# 确保 block_chance 被初始化
	block_chance = 0.0

## 应用羁绊属性加成（在 BondManager 计算完成后调用）
func apply_bond_stat_modifiers() -> void:
	"""将 BondManager 的 stat_mod 效果应用到玩家属性上"""
	if not BondManager:
		return
	
	# 构建当前属性字典
	var stats = {
		"max_health": health,
		"speed": speed,
		"energy_regen": energy_regen,
		"pickup_range": pickup_range,
		"damage": damage,
	}
	
	# 调用 BondManager 应用属性修改
	var modified = BondManager.apply_stat_modifiers(stats)
	
	# 写回修改后的属性
	var old_health = health
	health = modified.get("max_health", health)
	speed = modified.get("speed", speed)
	energy_regen = modified.get("energy_regen", energy_regen)
	pickup_range = modified.get("pickup_range", pickup_range)
	damage = modified.get("damage", damage)
	
	# 更新 health_component（如果已初始化且数值有变化）
	if health_component:
		# 始终同步 health_component，确保道具和羁绊加成都生效
		if abs(health - health_component.max_health) > 0.01:
			health_component.setup_with_health(health)
		energy = max_energy  # 重置能量为满
	
	if OS.is_debug_build():
		print("[PlayerBase] 羁绊属性加成已应用:")
		print("  HP: %.0f -> %.0f" % [old_health, health])
		print("  速度: %.0f" % speed)
		print("  能量恢复: %.1f" % energy_regen)
		print("  拾取范围: %.0f" % pickup_range)
		print("  攻击力: %.0f" % damage)

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
	
	# 加载选择界面选定的武器（1级）
	if selected_weapon_type != "":
		var weapon_id = "%s_1" % selected_weapon_type
		var item_weapon = _create_item_weapon_from_csv(weapon_id)
		if item_weapon:
			_add_weapon(item_weapon)
	
	# 加载强化界面购买的武器（1级，仅本局生效）
	var purchased_weapon_type = DataManager.get_purchased_weapon(player_id)
	if purchased_weapon_type != "" and purchased_weapon_type != selected_weapon_type:
		var purchased_weapon_id = "%s_1" % purchased_weapon_type
		var purchased_item = _create_item_weapon_from_csv(purchased_weapon_id)
		if purchased_item:
			_add_weapon(purchased_item)
			print("[PlayerBase] 加载购买武器: %s" % purchased_weapon_id)
	
	if current_weapons.is_empty():
		print("[PlayerBase] 警告: 角色 %s 没有加载任何武器" % player_id)
	else:
		print("[PlayerBase] 角色 %s 共加载 %d 把武器" % [player_id, current_weapons.size()])
	return

func _create_item_weapon_from_csv(weapon_id: String) -> ItemWeapon:
	"""从CSV配置创建ItemWeapon对象"""
	# 使用 ItemWeapon 的静态方法创建武器
	return ItemWeapon.create_from_csv(weapon_id)

func _add_weapon(data: ItemWeapon) -> void:
	"""添加武器到玩家"""
	if not data:
		printerr("[Player] 错误: 武器数据为空")
		return
	
	if not data.scene:
		printerr("[Player] 错误: 武器场景为空 - weapon_id: ", data.weapon_id)
		printerr("[Player] 场景路径: ", data.stats.base_scene_path if data.stats else "stats为空")
		return
	
	var weapon := data.scene.instantiate() as Weapon
	if not weapon:
		printerr("[Player] 错误: 无法实例化武器场景 - weapon_id: ", data.weapon_id)
		return
	
	print("[Player] 成功添加武器: ", data.item_name, " (", data.weapon_id, ")")
	
	# 武器应该添加到玩家节点，而不是weapon_container
	# weapon_container只负责定位，不负责持有武器
	add_child(weapon)
	
	print("[Player] 武器已添加到场景树")
	print("[Player] 武器位置: ", weapon.position)
	print("[Player] 武器全局位置: ", weapon.global_position)
	print("[Player] 武器可见性: ", weapon.visible)
	print("[Player] 武器 z_index: ", weapon.z_index)
	
	# 设置武器数据
	weapon.setup_weapon(data)
	current_weapons.append(weapon)
	
	# 更新武器位置（通过weapon_container的marker定位）
	if weapon_container:
		weapon_container.update_weapons_position(current_weapons)
		print("[Player] 武器定位后位置: ", weapon.position)
		print("[Player] 武器定位后全局位置: ", weapon.global_position)

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
	
	# 通过 WarehouseManager 将 item_type 转换为 item_id
	var item_id = WarehouseManager.get_item_id_from_type(item_type)
	if item_id != "":
		equip_item(item_id)

## 装备道具（核心函数）
## @param item_id: 道具 ID（如 "attr_hp_potion", "magic_fire_heart"）
func equip_item(item_id: String) -> void:
	if item_id.is_empty():
		return
	
	# 通过 ConfigManager 读取新格式道具配置
	var item_data = ConfigManager.get_item_config_by_id(item_id)
	if item_data.is_empty():
		printerr("[PlayerBase] 错误: 未找到道具配置 '%s'" % item_id)
		return
	
	var tier = int(item_data.get("tier", 1))
	
	if OS.is_debug_build():
		print("[PlayerBase] 装备道具: %s (Tier %d)" % [item_data.get("name", item_id), tier])
	
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

## Tier 1: 直接修改属性（纯基础数值加成）
func _apply_tier1_item(item_data: Dictionary) -> void:
	var stat_name = str(item_data.get("base_stat", "")).strip_edges()
	var value = float(item_data.get("base_value", 0.0))
	
	if stat_name.is_empty() or value == 0.0:
		printerr("[PlayerBase] 错误: Tier 1 道具缺少 base_stat 或 base_value")
		return
	
	_apply_base_stat(stat_name, value)

## Tier 2: 基础属性加成 + 修改器
func _apply_tier2_item(item_data: Dictionary) -> void:
	# Step 1: 应用基础属性加成
	var stat_name = str(item_data.get("base_stat", "")).strip_edges()
	var base_value = float(item_data.get("base_value", 0.0))
	if not stat_name.is_empty() and base_value != 0.0:
		_apply_base_stat(stat_name, base_value)
	
	# Step 2: 应用修改器（支持多修正）
	if not modifier_manager:
		printerr("[PlayerBase] 错误: ModifierManager 未初始化")
		return
	
	var modifiers = item_data.get("modifiers", [])
	for mod in modifiers:
		var mod_type = str(mod.get("type", ""))
		var mod_value = float(mod.get("value", 0.0))
		if not mod_type.is_empty():
			modifier_manager.add_modifier([mod_type], "percent", mod_value)
			if OS.is_debug_build():
				print("[PlayerBase] 添加修改器: type=%s, value=%.2f" % [mod_type, mod_value])

## Tier 3: 高数值加成 + 修改器 + bond_grant 羁绊标签
func _apply_tier3_item(item_data: Dictionary) -> void:
	# Step 1: 应用基础属性加成
	var stat_name = str(item_data.get("base_stat", "")).strip_edges()
	var base_value = float(item_data.get("base_value", 0.0))
	if not stat_name.is_empty() and base_value != 0.0:
		_apply_base_stat(stat_name, base_value)
	
	# Step 2: 应用修改器（支持多修正）
	if modifier_manager:
		var modifiers = item_data.get("modifiers", [])
		for mod in modifiers:
			var mod_type = str(mod.get("type", ""))
			var mod_value = float(mod.get("value", 0.0))
			if not mod_type.is_empty():
				modifier_manager.add_modifier([mod_type], "percent", mod_value)
				if OS.is_debug_build():
					print("[PlayerBase] T3 修改器: type=%s, value=%.2f" % [mod_type, mod_value])
	
	# Step 3: 注册 bond_grant 标签（供 BondManager 通过 EquipmentManager 查询）
	var bond_grant = str(item_data.get("bond_grant", "")).strip_edges()
	if not bond_grant.is_empty():
		if OS.is_debug_build():
			print("[PlayerBase] T3 注册 bond_grant 标签: '%s'" % bond_grant)

## 获取装备的圣物提供的羁绊标签（供 BondManager 调用）
func get_equipped_relic_tags() -> Dictionary:
	if equipped_item_id.is_empty():
		return {}
	
	var item_data = ConfigManager.get_item_config_by_id(equipped_item_id)
	if item_data.is_empty():
		return {}
	
	var tier = int(item_data.get("tier", 1))
	if tier != 3:
		return {}
	
	var bond_grant = str(item_data.get("bond_grant", "")).strip_edges()
	if bond_grant.is_empty():
		return {}
	
	return {bond_grant: 1}

## 应用基础属性加成（共用辅助方法）
func _apply_base_stat(stat_name: String, value: float) -> void:
	match stat_name:
		"hp", "health":
			health += value
			if OS.is_debug_build():
				print("[PlayerBase] 生命值 +%.0f -> %.0f" % [value, health])
		"speed":
			speed += value
			if OS.is_debug_build():
				print("[PlayerBase] 速度 +%.0f -> %.0f" % [value, speed])
		"attack", "damage":
			damage += value
			if OS.is_debug_build():
				print("[PlayerBase] 攻击力 +%.0f -> %.0f" % [value, damage])
		"energy":
			energy = min(energy + value, max_energy)
			if OS.is_debug_build():
				print("[PlayerBase] 能量 +%.0f -> %.0f" % [value, energy])
		_:
			printerr("[PlayerBase] 警告: 未知的属性名称 '%s'" % stat_name)

## 消耗品立即使用（不存入槽位）
## @param config: 道具配置字典（来自 ConfigManager.get_item_config_by_id()）
func apply_consumable_effect(config: Dictionary) -> void:
	var stat_name = str(config.get("base_stat", "")).strip_edges()
	var value = float(config.get("base_value", 0.0))
	
	if stat_name.is_empty() or value == 0.0:
		printerr("[PlayerBase] 消耗品配置无效: 缺少 base_stat 或 base_value")
		return
	
	match stat_name:
		"hp", "health":
			if health_component:
				health_component.heal(value)
				Global.spawn_floating_text(global_position, "+%d HP" % int(value), Color.GREEN)
				if OS.is_debug_build():
					print("[PlayerBase] 消耗品: 恢复 %.0f 生命" % value)
		"energy":
			energy = min(energy + value, max_energy)
			update_ui_signals()
			Global.spawn_floating_text(global_position, "+%d Energy" % int(value), Color.CYAN)
			if OS.is_debug_build():
				print("[PlayerBase] 消耗品: 恢复 %.0f 能量" % value)
		_:
			# 其他属性直接加成
			_apply_base_stat(stat_name, value)
			Global.spawn_floating_text(global_position, "+%d %s" % [int(value), stat_name], Color.WHITE)

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
		var current_speed = speed  # 直接使用 Unit 基类的 speed 属性
		# 应用 Buff 区域的速度加成（如新风暴风带）
		if has_meta("buff_speed_boost"):
			current_speed *= (1.0 + get_meta("buff_speed_boost"))
		position += move_dir * current_speed * delta
		# 移除移动限制，允许无限移动
		# position.x = clamp(position.x, -2000, 2000)
		# position.y = clamp(position.y, -2000, 2000)

	# 技能按键分发 - 如果有SkillManager则自动处理
	if has_node("SkillManager"):
		var skill_manager = get_node("SkillManager")
		
		# E技能（瞬发）
		if Input.is_action_just_pressed("skill_e"):
			print("[PlayerBase] E键按下，调用 execute_skill('e')")
			skill_manager.execute_skill("e")
			return
		
		# Q技能（蓄力）
		if Input.is_action_pressed("skill_q"):
			skill_manager.charge_skill("q", delta)
			return
		elif Input.is_action_just_released("skill_q"):
			print("[PlayerBase] Q键释放，调用 release_skill('q')")
			skill_manager.release_skill("q")
			return
		
		# 左键技能
		if Input.is_action_just_pressed("click_left"):
			skill_manager.execute_skill("lmb")
			return
	
	# F键 - 大招
	if Input.is_action_just_pressed("skill_f"):
		print("[PlayerBase] F键按下，ultimate_skill = %s" % str(ultimate_skill))
		if ultimate_skill:
			print("[PlayerBase] 尝试激活大招，能量: %.1f%%" % get_energy_percent())
			ultimate_skill.try_activate()
		else:
			print("[PlayerBase] 大招未加载！")
			# 显示飘字提示
			Global.spawn_floating_text(global_position, "大招未实现", Color.GRAY)

# --- 虚函数 (子类重写) ---
func can_move() -> bool: 
	return true  # 移动控制现在由SkillManager和各个技能处理

func _process_subclass(delta: float) -> void: 
	pass  # 子类可以重写此方法添加额外逻辑       

# --- 战斗逻辑 ---
func take_damage(raw_amount: float) -> void:
	var damage_multiplier = 1.0 - (clamp(armor, 0, max_armor) * reduction_per_armor)
	var final_damage = max(1, raw_amount * damage_multiplier)
	
	print("[PlayerBase] 受到伤害: raw=%d, final=%d, 当前血量=%d" % [raw_amount, final_damage, health_component.current_health])
	
	# 玩家受击音效
	SoundManager.play("player_hurt")
	
	if armor > 0:
		armor -= 1
		# 护甲破碎音效（护甲层数减少时播放）
		if armor == 0:
			SoundManager.play("player_armor_break")
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
	
	# P4-4: 灵魂附着 - 受击时触发反击
	if BondManager.has_mechanic("soul_attach"):
		_trigger_soul_attach_on_hit()
	
	print("[PlayerBase] 伤害后血量=%d" % health_component.current_health)

# P4-4: 灵魂附着 - 受击时触发反击（指挥型 Lv.2）
func _trigger_soul_attach_on_hit() -> void:
	"""受击时触发灵魂附着反击效果"""
	var attach_damage_scale = BondManager.get_mechanic_value("soul_attach")
	if attach_damage_scale <= 0:
		return
	
	# 计算反击伤害（基于玩家攻击力）
	var attach_damage = int(damage * attach_damage_scale)
	
	print("[PlayerBase] [P4-4] 灵魂附着触发: 反击伤害=%d (攻击力的%.0f%%)" % [
		attach_damage,
		attach_damage_scale * 100
	])
	
	# 对周围敌人造成小范围AoE伤害
	var attach_radius = 150.0  # 反击范围
	var enemies = get_tree().get_nodes_in_group("enemies")
	var hit_count = 0
	
	for enemy in enemies:
		if not is_instance_valid(enemy):
			continue
		
		var distance = global_position.distance_to(enemy.global_position)
		if distance <= attach_radius:
			# 造成伤害
			if enemy.has_node("HealthComponent"):
				enemy.get_node("HealthComponent").take_damage(attach_damage)
				hit_count += 1
			
			# 视觉反馈
			Global.spawn_floating_text(enemy.global_position, "SOUL!", Color(1.5, 0.5, 1.5))
	
	if hit_count > 0:
		# 播放反击特效
		SoundManager.play("bond_soul_attach")
		Global.on_camera_shake.emit(5.0, 0.15)
		Global.spawn_floating_text(global_position, "SOUL ATTACH!", Color(2.0, 0.5, 2.0))
		print("[PlayerBase] [P4-4] 灵魂附着命中 %d 个敌人" % hit_count)

func apply_knockback_self(force: Vector2) -> void:
	# P1-2: 霸体机制 - 画图时免疫击退
	if _is_drawing_active() and BondManager.has_mechanic("super_armor"):
		print("[PlayerBase] [P1-2] 触发霸体，免疫击退（仍然受到伤害）")
		SoundManager.play("super_armor_trigger")
		Global.spawn_floating_text(global_position, "SUPER ARMOR!", Color.ORANGE)
		# 仍然播放受击反馈，但不应用击退
		Global.on_camera_shake.emit(3.0, 0.08)
		return
	
	# 应用击退力缩放系数，减少击退效果（从CSV加载）
	external_force = force * knockback_scale
	Global.on_camera_shake.emit(5.0, 0.1)

func consume_energy(amount: float) -> bool:
	if energy >= amount:
		energy -= amount
		update_ui_signals()
		return true
	else:
		SoundManager.play("player_energy_low")
		Global.spawn_floating_text(global_position, "No Energy!", Color.RED)
		return false

# 击杀敌人时获得能量
func gain_energy(amount: float) -> void:
	energy = min(energy + amount, max_energy)
	update_ui_signals()
	SoundManager.play("player_energy_gain")
	Global.spawn_floating_text(global_position, "+%d Energy" % amount, Color.CYAN)

# 获得经验值 - 使用 Global.session_xp（局内累积）
func add_xp(amount: int) -> void:
	Global.add_session_xp(amount)  # 直接更新 Global 的 session_xp
	xp = Global.session_xp  # 同步本地变量（兼容性）
	xp_changed.emit(Global.session_xp)
	SoundManager.play("player_level_up")
	Global.spawn_floating_text(global_position + Vector2(20, -10), "+%d XP" % amount, Color.MEDIUM_PURPLE)

# 获得金币 - 使用 DataManager（局外持久化）
func add_gold(amount: int) -> void:
	DataManager.add_gold(amount)  # 直接更新 DataManager
	gold = DataManager.get_total_gold()  # 同步本地变量（兼容性）
	gold_changed.emit(DataManager.get_total_gold())
	Global.add_session_gold(amount)  # 记录局内金币
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

## P1-2: 检查是否正在画图（用于霸体判定）
func _is_drawing_active() -> bool:
	"""检查玩家是否正在画图
	
	Returns:
		是否正在画图
	"""
	# 检查是否有SkillManager
	if not has_node("SkillManager"):
		return false
	
	var skill_manager = get_node("SkillManager")
	
	# 遍历所有技能，检查是否有正在画图的技能
	if skill_manager.has_method("get_all_skills"):
		for skill in skill_manager.get_all_skills():
			# 检查是否是画图技能
			if skill is SkillDrawingBase:
				# 检查是否处于规划模式或正在画图
				if skill.is_planning or skill.is_drawing:
					return true
	
	return false

## P1-3: 计算速度转伤害加成（风行者羁绊）
func get_speed_damage_bonus() -> float:
	"""计算基于速度的伤害加成
	
	Returns:
		伤害加成倍率（例如 0.15 表示 +15% 伤害）
	"""
	# 检查风行者羁绊 - 速度转伤害
	if not BondManager.has_mechanic("speed_to_damage"):
		return 0.0
	
	# 获取转换系数（从配置中读取，例如 0.01 = 每点速度增加1%伤害）
	var conversion_rate = BondManager.get_mechanic_value("speed_to_damage")
	
	# 计算速度差值
	var current_speed = speed  # 当前速度（可能被buff影响）
	var speed_diff = current_speed - base_speed
	
	# 只有速度高于基础速度时才有加成
	if speed_diff <= 0:
		return 0.0
	
	# 计算加成
	var bonus = speed_diff * conversion_rate
	
	print("[PlayerBase] [P1-3] 速度转伤害: 当前速度%.0f, 基础速度%.0f, 差值%.0f, 转换率%.4f, 伤害加成+%.1f%%" % [
		current_speed,
		base_speed,
		speed_diff,
		conversion_rate,
		bonus * 100
	])
	
	return bonus

func _on_death() -> void:
	print("[PlayerBase] ========== 玩家死亡 ==========")
	print("[PlayerBase] 当前血量: %d" % health_component.current_health)
	
	SoundManager.play("player_death")
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
	
	# 标记游戏结束并立即暂停游戏
	print("[PlayerBase] 设置 Global.is_game_over = true")
	Global.is_game_over = true
	print("[PlayerBase] 设置 Global.game_paused = true")
	Global.game_paused = true
	
	print("[PlayerBase] ========== 玩家死亡处理完成 ==========")
	# Arena 会在下一帧检测到死亡并显示结算界面

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
# 大招系统 (Ultimate Skill - F Key)
# ==============================================================================

func _load_ultimate_skill() -> void:
	"""从配置加载大招技能"""
	print("[PlayerBase] 开始加载大招，player_id = %s" % player_id)
	
	if player_id.is_empty():
		print("[PlayerBase] player_id 为空，跳过大招加载")
		return
	
	# 从CSV加载大招配置
	var ult_config = _load_ult_config_from_csv(player_id)
	if ult_config.is_empty():
		print("[PlayerBase] 角色 %s 没有配置大招" % player_id)
		return
	
	print("[PlayerBase] 大招配置加载成功: %s" % str(ult_config))
	
	# 根据角色ID创建对应的大招实例
	var ult_script = _get_ultimate_script_for_player(player_id)
	if not ult_script:
		print("[PlayerBase] 角色 %s 没有大招脚本" % player_id)
		return
	
	print("[PlayerBase] 大招脚本加载成功: %s" % str(ult_script))
	
	# 创建大招节点
	ultimate_skill = ult_script.new()
	ultimate_skill.name = "UltimateSkill"
	add_child(ultimate_skill)
	
	print("[PlayerBase] 大招节点创建成功")
	
	# 初始化大招
	ultimate_skill.initialize(ult_config, self)
	
	print("[PlayerBase] 加载大招完成: %s" % ult_config.get("name", "Unknown"))

func _load_ult_config_from_csv(pid: String) -> Dictionary:
	"""从CSV加载大招配置
	
	Args:
		pid: 玩家ID
	
	Returns:
		大招配置字典
	"""
	var csv_path = "res://config/player/ult_config.csv"  # 修正路径
	if not FileAccess.file_exists(csv_path):
		printerr("[PlayerBase] 大招配置文件不存在: %s" % csv_path)
		return {}
	
	var file = FileAccess.open(csv_path, FileAccess.READ)
	if not file:
		printerr("[PlayerBase] 无法打开大招配置文件")
		return {}
	
	# 跳过表头
	var header = file.get_csv_line()
	
	# 跳过注释行（-1 开头的行）
	while not file.eof_reached():
		var pos = file.get_position()
		var line = file.get_csv_line()
		if line.size() == 0 or line[0] == "-1":
			continue  # 跳过空行和注释行
		else:
			# 回退到这一行的开始
			file.seek(pos)
			break
	
	# 查找匹配的大招ID（格式: player_id + "_ult"）
	var target_ult_id = pid + "_ult"
	
	while not file.eof_reached():
		var line = file.get_csv_line()
		if line.size() < 10:  # 现在有10个字段（增加了 explosion_radius 和 explosion_damage_scale）
			continue
		
		# 跳过注释行
		if line[0] == "-1":
			continue
		
		var ult_id = line[0]
		if ult_id == target_ult_id:
			file.close()
			return {
				"ult_id": ult_id,
				"name": line[1],
				"duration": float(line[2]),
				"energy_cost": float(line[3]),
				"bonus_bond_tag": line[4],
				"visual_color_hex": line[5],
				"scale_multiplier": float(line[6]),
				"explosion_radius": float(line[7]),        # 新增：爆炸半径
				"explosion_damage_scale": float(line[8]),  # 新增：爆炸伤害倍率
				"description": line[9]
			}
	
	file.close()
	return {}

func _get_ultimate_script_for_player(pid: String) -> Script:
	"""获取角色对应的大招脚本
	
	Args:
		pid: 玩家ID
	
	Returns:
		大招脚本资源
	"""
	# 映射表：player_id -> 大招脚本路径
	var ult_script_map = {
		"butcher": "res://scenes/skills/players/skill_ultimate_butcher.gd",
		"pyro": "res://scenes/skills/players/skill_ultimate_pyro.gd",
		"sapper": "res://scenes/skills/players/skill_ultimate_sapper.gd",
		"merchant": "res://scenes/skills/players/skill_ultimate_merchant.gd",
		"midas": "res://scenes/skills/players/skill_ultimate_midas.gd",
		"vacuum": "res://scenes/skills/players/skill_ultimate_vacuum.gd",
		"executioner": "res://scenes/skills/players/skill_ultimate_executioner.gd",
		"gambler": "res://scenes/skills/players/skill_ultimate_gambler.gd",
		"hunter": "res://scenes/skills/players/skill_ultimate_hunter.gd",
		# 其他角色使用基础大招（包含爆炸效果）
	}
	
	var script_path = ult_script_map.get(pid, "")
	
	# 如果没有特殊脚本，使用基础大招脚本
	if script_path == "":
		script_path = "res://scenes/skills/skill_ultimate_base.gd"
		print("[PlayerBase] 角色 %s 使用基础大招脚本（包含爆炸效果）" % pid)
	
	if not FileAccess.file_exists(script_path):
		printerr("[PlayerBase] 大招脚本不存在: %s" % script_path)
		return null
	
	return load(script_path) as Script

## 自动创建技能管理器（如果子类没有创建）
## 这使得纯CSV配置的角色也能拥有Q/E/LMB技能
func _auto_create_skill_manager() -> void:
	# 检查是否已经有SkillManager（子类可能已经创建）
	# 同时检查名称和类型，防止子类创建了未命名的SkillManager导致重复
	for child in get_children():
		if child is SkillManager:
			var sm = child as SkillManager
			print("[PlayerBase] 技能管理器已存在（由子类创建: %s），已加载 %d 个技能，跳过自动创建" % [child.name, sm.get_loaded_skill_count()])
			# 确保名称统一为 "SkillManager"，以便 _handle_input 能找到
			if child.name != "SkillManager":
				child.name = "SkillManager"
			# 打印技能槽位信息
			sm.print_skills_info()
			return
	
	# 检查是否有技能绑定配置
	var bindings = ConfigManager.get_player_skill_bindings(player_id)
	if bindings.is_empty():
		print("[PlayerBase] 角色 %s 没有技能绑定配置，跳过技能管理器创建" % player_id)
		return
	
	# 检查是否至少有一个技能槽位配置
	var has_any_skill = false
	for slot in ["q", "e", "lmb", "rmb"]:
		var skill_id = bindings.get("slot_%s" % slot, "")
		if not skill_id.is_empty():
			has_any_skill = true
			break
	
	if not has_any_skill:
		print("[PlayerBase] 角色 %s 没有配置任何技能，跳过技能管理器创建" % player_id)
		return
	
	# 创建技能管理器
	var skill_manager = SkillManager.new(self)
	skill_manager.name = "SkillManager"
	skill_manager.debug_mode = false
	add_child(skill_manager)
	
	# 加载技能配置
	var success = skill_manager.load_skills_from_config(player_id)
	
	if success:
		print("[PlayerBase] ✅ 自动创建技能管理器成功: %s (已加载 %d 个技能)" % [
			player_id, 
			skill_manager.get_loaded_skill_count()
		])
	else:
		print("[PlayerBase] ⚠️ 技能管理器创建成功，但技能加载失败: %s" % player_id)

func get_energy_percent() -> float:
	"""获取能量百分比（0-100）
	
	Returns:
		能量百分比
	"""
	if max_energy <= 0:
		return 0.0
	return (energy / max_energy) * 100.0

func consume_energy_percent(percent: float) -> bool:
	"""消耗百分比能量
	
	Args:
		percent: 百分比（0-100）
	
	Returns:
		是否成功消耗
	"""
	var amount = (percent / 100.0) * max_energy
	return consume_energy(amount)

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
