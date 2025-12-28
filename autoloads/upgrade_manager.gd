extends Node

# ============================================================================
# 升级管理器 - 管理玩家属性升级
# ============================================================================
# 
# 功能说明:
# - 管理玩家的属性升级系统
# - 跟踪每个属性的升级等级和累计加成
# - 生成随机属性选项供玩家选择
# - 将属性加成应用到玩家对象
# 
# 工作流程:
# 1. 玩家打开宝箱
# 2. 调用 generate_random_attributes() 生成3个随机属性选项
# 3. 玩家选择一个属性
# 4. 调用 apply_upgrade() 应用属性升级
# 5. 属性直接修改玩家对象的相应字段
# 
# 使用方法:
#   # 生成选项
#   var options = UpgradeManager.generate_random_attributes(3, chest_tier)
#   
#   # 应用升级
#   UpgradeManager.apply_upgrade(attribute_id, chest_tier)
#   
#   # 查询属性
#   var level = UpgradeManager.get_attribute_level("max_health")
#   var bonus = UpgradeManager.get_attribute_bonus("max_health")
# 
# ============================================================================

# ============================================================================
# 属性数据
# ============================================================================

# 玩家当前的属性升级等级
# 格式: {attribute_id: level, ...}
# 示例: {"max_health": 3, "base_speed": 2}
var attribute_levels: Dictionary = {}

# 玩家当前的属性加成值
# 格式: {attribute_id: bonus, ...}
# 示例: {"max_health": 50.0, "base_speed": 30.0}
var attribute_bonuses: Dictionary = {}

# ============================================================================
# 初始化
# ============================================================================

func _ready() -> void:
	"""
	Godot 生命周期函数，节点准备就绪时调用
	初始化所有属性的等级和加成为0
	"""
	print("=== 升级管理器初始化 ===")
	_initialize_attributes()

func _initialize_attributes() -> void:
	"""
	初始化所有属性等级为0
	
	说明:
	- 从 ConfigManager 读取所有可升级属性
	- 将每个属性的等级和加成初始化为0
	"""
	var all_attributes = ConfigManager.get_all_upgrade_attributes()
	for attr_id in all_attributes.keys():
		attribute_levels[attr_id] = 0
		attribute_bonuses[attr_id] = 0.0

# ============================================================================
# 核心功能 - 属性升级
# ============================================================================

func apply_upgrade(attribute_id: String, chest_tier: int) -> Dictionary:
	"""
	应用属性升级到玩家
	
	参数:
	- attribute_id: 属性ID（如 "max_health"）
	- chest_tier: 宝箱等级（1-4），决定升级幅度
	
	返回:
	- Dictionary: 升级结果信息
	  {
		"attribute_id": String,
		"display_name": String,
		"upgrade_value": float,
		"value_type": String,
		"new_level": int
	  }
	
	说明:
	- 检查属性是否达到最大等级
	- 根据宝箱等级获取对应的升级值
	- 更新属性等级和累计加成
	- 调用 _apply_to_player() 将加成应用到玩家对象
	"""
	var attr_config = ConfigManager.get_upgrade_attribute(attribute_id)
	if attr_config.is_empty():
		printerr("[UpgradeManager] 错误: 未找到属性配置 ", attribute_id)
		return {}
	
	# 检查是否达到最大等级
	var current_level = attribute_levels.get(attribute_id, 0)
	var max_level = attr_config.get("max_level", 10)
	if current_level >= max_level:
		print("[UpgradeManager] 属性已达到最大等级: ", attribute_id)
		return {}
	
	# 获取提升值
	var value_key = "tier%d_value" % chest_tier
	var upgrade_value = attr_config.get(value_key, 0)
	var value_type = attr_config.get("value_type", "flat")
	
	# 更新等级和加成
	attribute_levels[attribute_id] = current_level + 1
	attribute_bonuses[attribute_id] = attribute_bonuses.get(attribute_id, 0.0) + upgrade_value
	
	print("[UpgradeManager] 升级属性: %s, 等级: %d, 加成: %s" % [attribute_id, attribute_levels[attribute_id], str(upgrade_value)])
	
	# 应用到玩家
	_apply_to_player(attribute_id, upgrade_value, value_type)
	
	return {
		"attribute_id": attribute_id,
		"display_name": attr_config.get("display_name", ""),
		"upgrade_value": upgrade_value,
		"value_type": value_type,
		"new_level": attribute_levels[attribute_id]
	}

func _apply_to_player(attribute_id: String, value: float, value_type: String) -> void:
	"""
	将属性加成应用到玩家对象
	
	参数:
	- attribute_id: 属性ID
	- value: 加成值
	- value_type: 值类型（"flat" 或 "percent"）
	
	说明:
	- 直接修改 Global.player 对象的相应字段
	- 使用 match 语句处理不同的属性类型
	- 打印详细的调试日志，显示修改前后的数值
	
	支持的属性:
	- max_health: 最大生命值（同时增加当前生命值）
	- max_energy: 最大能量（同时增加当前能量）
	- energy_regen: 能量恢复速度
	- base_speed: 移动速度（同时修改 stats.speed）
	- dash_distance: 冲刺距离
	- dash_damage: 冲刺伤害
	- dash_cost: 冲刺消耗（负值表示降低）
	- skill_q_cost: Q技能消耗（负值表示降低）
	- skill_e_cost: E技能消耗（负值表示降低）
	- weapon_damage: 武器伤害（存储加成，在武器攻击时应用）
	- crit_chance, crit_damage, damage_reduction, lifesteal, energy_on_kill: 
	  存储在 attribute_bonuses 中，在相应逻辑中使用
	"""
	if not is_instance_valid(Global.player):
		printerr("[UpgradeManager] 错误: 玩家对象无效")
		return
	
	var player = Global.player
	var player_name = player.name if player.name else "Unknown Player"
	
	print("\n========================================")
	print("[UpgradeManager] 属性升级详情")
	print("========================================")
	print("玩家名称: %s" % player_name)
	print("属性ID: %s" % attribute_id)
	print("增加值: %s (%s)" % [str(value), value_type])
	print("----------------------------------------")
	
	match attribute_id:
		"max_health":
			if "health_component" in player and player.health_component:
				var old_max = player.health_component.max_health
				var old_current = player.health_component.current_health
				player.health_component.max_health += int(value)
				player.health_component.current_health += int(value)
				print("✓ 最大生命值: %d -> %d (+%d)" % [old_max, player.health_component.max_health, int(value)])
				print("✓ 当前生命值: %d -> %d (+%d)" % [old_current, player.health_component.current_health, int(value)])
			else:
				print("✗ 玩家没有 health_component")
		
		"max_energy":
			if "max_energy" in player:
				var old_max = player.max_energy
				var old_current = player.energy
				player.max_energy += int(value)
				player.energy = min(player.energy + int(value), player.max_energy)
				print("✓ 最大能量: %d -> %d (+%d)" % [old_max, player.max_energy, int(value)])
				print("✓ 当前能量: %d -> %d (+%d)" % [old_current, player.energy, int(player.energy - old_current)])
			else:
				print("✗ 玩家没有 max_energy 属性")
		
		"energy_regen":
			if "energy_regen" in player:
				var old_regen = player.energy_regen
				player.energy_regen += value
				print("✓ 能量恢复: %.2f/s -> %.2f/s (+%.2f/s)" % [old_regen, player.energy_regen, value])
			else:
				print("✗ 玩家没有 energy_regen 属性")
		
		"base_speed":
			if "base_speed" in player:
				var old_speed = player.base_speed
				player.base_speed += value
				print("✓ 基础速度: %.1f -> %.1f (+%.1f)" % [old_speed, player.base_speed, value])
			if "stats" in player and player.stats:
				var old_stats_speed = player.stats.speed
				player.stats.speed += value
				print("✓ Stats速度: %.1f -> %.1f (+%.1f)" % [old_stats_speed, player.stats.speed, value])
		
		"dash_distance":
			if "dash_distance" in player:
				var old_dist = player.dash_distance
				player.dash_distance += value
				print("✓ 冲刺距离: %.1f -> %.1f (+%.1f)" % [old_dist, player.dash_distance, value])
			else:
				print("✗ 玩家没有 dash_distance 属性")
		
		"dash_damage":
			if "dash_damage" in player:
				var old_dmg = player.dash_damage
				player.dash_damage += int(value)
				print("✓ 冲刺伤害: %d -> %d (+%d)" % [old_dmg, player.dash_damage, int(value)])
			else:
				print("✗ 玩家没有 dash_damage 属性")
		
		"dash_cost":
			if "dash_cost" in player:
				var old_cost = player.dash_cost
				player.dash_cost = max(1, player.dash_cost + value)
				var actual_change = player.dash_cost - old_cost
				print("✓ 冲刺消耗: %.1f -> %.1f (%+.1f)" % [old_cost, player.dash_cost, actual_change])
			else:
				print("✗ 玩家没有 dash_cost 属性")
		
		"skill_q_cost":
			if "skill_q_cost" in player:
				var old_cost = player.skill_q_cost
				player.skill_q_cost = max(1, player.skill_q_cost + value)
				var actual_change = player.skill_q_cost - old_cost
				print("✓ Q技能消耗: %.1f -> %.1f (%+.1f)" % [old_cost, player.skill_q_cost, actual_change])
			else:
				print("✗ 玩家没有 skill_q_cost 属性")
		
		"skill_e_cost":
			if "skill_e_cost" in player:
				var old_cost = player.skill_e_cost
				player.skill_e_cost = max(1, player.skill_e_cost + value)
				var actual_change = player.skill_e_cost - old_cost
				print("✓ E技能消耗: %.1f -> %.1f (%+.1f)" % [old_cost, player.skill_e_cost, actual_change])
			else:
				print("✗ 玩家没有 skill_e_cost 属性")
		
		"weapon_damage":
			# 武器伤害加成存储，在武器攻击时应用
			print("✓ 武器伤害加成: +%s%% (累计: %.1f%%)" % [str(value), get_attribute_bonus("weapon_damage")])
		
		"crit_chance":
			print("✓ 暴击率: +%s%% (累计: %.1f%%)" % [str(value), get_attribute_bonus("crit_chance")])
		
		"crit_damage":
			print("✓ 暴击伤害: +%s%% (累计: %.1f%%)" % [str(value), get_attribute_bonus("crit_damage")])
		
		"damage_reduction":
			print("✓ 伤害减免: +%s%% (累计: %.1f%%)" % [str(value), get_attribute_bonus("damage_reduction")])
		
		"lifesteal":
			print("✓ 生命偷取: +%s%% (累计: %.1f%%)" % [str(value), get_attribute_bonus("lifesteal")])
		
		"energy_on_kill":
			print("✓ 击杀回能: +%s (累计: %.1f)" % [str(value), get_attribute_bonus("energy_on_kill")])
	
	print("========================================\n")

# ============================================================================
# 属性选择生成
# ============================================================================

func generate_random_attributes(count: int, chest_tier: int) -> Array[Dictionary]:
	"""
	生成随机属性选择（用于宝箱）
	
	参数:
	- count: 生成数量（通常为3）
	- chest_tier: 宝箱等级（1-4）
	
	返回:
	- Array[Dictionary]: 属性选项数组
	  [{
		"attribute_id": String,
		"display_name": String,
		"description": String,
		"upgrade_value": float,
		"value_type": String,
		"current_level": int
	  }, ...]
	
	说明:
	- 只选择未达到最大等级的属性
	- 随机打乱顺序
	- 根据宝箱等级获取对应的升级值
	"""
	var all_attributes = ConfigManager.get_all_upgrade_attributes()
	var available_attrs: Array[String] = []
	
	# 筛选未达到最大等级的属性
	for attr_id in all_attributes.keys():
		var attr_config = all_attributes[attr_id]
		var current_level = attribute_levels.get(attr_id, 0)
		var max_level = attr_config.get("max_level", 10)
		if current_level < max_level:
			available_attrs.append(attr_id)
	
	# 随机选择
	available_attrs.shuffle()
	var selected: Array[Dictionary] = []
	
	for i in range(min(count, available_attrs.size())):
		var attr_id = available_attrs[i]
		var attr_config = all_attributes[attr_id]
		var value_key = "tier%d_value" % chest_tier
		var upgrade_value = attr_config.get(value_key, 0)
		
		selected.append({
			"attribute_id": attr_id,
			"display_name": attr_config.get("display_name", ""),
			"description": attr_config.get("description", ""),
			"upgrade_value": upgrade_value,
			"value_type": attr_config.get("value_type", "flat"),
			"current_level": attribute_levels.get(attr_id, 0)
		})
	
	return selected

# ============================================================================
# 查询方法
# ============================================================================

# 获取属性加成值
func get_attribute_bonus(attribute_id: String) -> float:
	"""
	获取属性的累计加成值
	
	参数:
	- attribute_id: 属性ID
	
	返回:
	- float: 累计加成值
	"""
	return attribute_bonuses.get(attribute_id, 0.0)

# 获取属性等级
func get_attribute_level(attribute_id: String) -> int:
	"""
	获取属性的当前等级
	
	参数:
	- attribute_id: 属性ID
	
	返回:
	- int: 当前等级
	"""
	return attribute_levels.get(attribute_id, 0)

# ============================================================================
# 工具方法
# ============================================================================

func reset_all_attributes() -> void:
	"""
	重置所有属性（用于测试或重新开始游戏）
	
	说明:
	- 清空所有等级和加成数据
	- 重新初始化为0
	"""
	attribute_levels.clear()
	attribute_bonuses.clear()
	_initialize_attributes()
	print("[UpgradeManager] 所有属性已重置")
