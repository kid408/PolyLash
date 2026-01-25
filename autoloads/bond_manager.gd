extends Node

# ============================================================================
# 羁绊管理器 - 核心数值逻辑系统
# ============================================================================

# 信号
signal bonds_recalculated(active_bonds: Dictionary)
signal stat_modifiers_changed()

# ============================================================================
# 数据结构
# ============================================================================

# 羁绊配置数据：{bond_id: {levels: [{level, required_count, effect_type, ...}]}}
var bond_configs: Dictionary = {}

# 当前激活的羁绊：{bond_id: {level: int, effects: [{effect_type, effect_param, effect_value}]}}
var active_bonds: Dictionary = {}

# 当前队伍的羁绊标签统计：{bond_id: count}
var current_bond_counts: Dictionary = {}

# 临时羁绊标签（来自技能/大招）：{bond_id: count}
var temp_bonus_tags: Dictionary = {}

# 变身过载模式（F键变身）
var is_overdrive_mode: bool = false

# ============================================================================
# 初始化
# ============================================================================

func _ready() -> void:
	_load_bond_configs()
	print("[BondManager] 初始化完成，加载了 %d 个羁绊配置" % bond_configs.size())

# ============================================================================
# 配置加载
# ============================================================================

func _load_bond_configs() -> void:
	"""从 CSV 加载羁绊配置"""
	var csv_path = "res://config/player/bond_config.csv"
	if not FileAccess.file_exists(csv_path):
		printerr("[BondManager] 羁绊配置文件不存在: %s" % csv_path)
		return
	
	var file = FileAccess.open(csv_path, FileAccess.READ)
	if not file:
		printerr("[BondManager] 无法打开羁绊配置文件")
		return
	
	# 跳过表头
	file.get_csv_line()
	# 跳过说明行
	file.get_csv_line()
	
	var line_count = 0
	while not file.eof_reached():
		var line = file.get_csv_line()
		if line.size() < 10:
			continue
		
		var bond_id = line[0]
		var bond_type = line[1]
		var level = int(line[2])
		var required_count = int(line[3])
		var effect_type = line[4]
		var effect_param = line[5]
		var effect_value = float(line[6])
		var icon_path_index = int(line[7])
		var display_name = line[8]
		var description = line[9]
		
		if bond_id == "" or bond_id == "-1":
			continue
		
		# 初始化羁绊配置
		if not bond_configs.has(bond_id):
			bond_configs[bond_id] = {
				"bond_type": bond_type,
				"display_name": display_name,
				"icon_path_index": icon_path_index,
				"levels": []
			}
		
		# 添加等级配置
		bond_configs[bond_id].levels.append({
			"level": level,
			"required_count": required_count,
			"effect_type": effect_type,
			"effect_param": effect_param,
			"effect_value": effect_value,
			"description": description
		})
		
		line_count += 1
	
	file.close()
	
	# 对每个羁绊的等级进行排序
	for bond_id in bond_configs.keys():
		bond_configs[bond_id].levels.sort_custom(func(a, b): return a.level < b.level)
	
	print("[BondManager] 加载了 %d 行羁绊配置数据" % line_count)

# ============================================================================
# 核心计算逻辑
# ============================================================================

func recalculate_active_bonds(team_player_ids: Array, equipped_relics: Array = []) -> void:
	"""重新计算激活的羁绊
	
	Args:
		team_player_ids: 当前队伍角色ID列表
		equipped_relics: 已装备圣物列表（可选，未来扩展）
	"""
	# 清空当前数据
	current_bond_counts.clear()
	active_bonds.clear()
	
	# 统计所有羁绊标签
	for player_id in team_player_ids:
		var config = ConfigManager.get_player_config(player_id)
		if config.is_empty():
			continue
		
		# 统计三种羁绊标签
		var tags = [
			config.get("origin_tag", ""),
			config.get("mastery_tag", ""),
			config.get("tactic_tag", "")
		]
		
		for tag in tags:
			if tag == "":
				continue
			
			if not current_bond_counts.has(tag):
				current_bond_counts[tag] = 0
			current_bond_counts[tag] += 1
	
	# 添加临时标签
	for tag in temp_bonus_tags.keys():
		current_bond_counts[tag] = current_bond_counts.get(tag, 0) + temp_bonus_tags[tag]
	
	# TODO: 处理圣物提供的额外羁绊标签
	# for relic in equipped_relics:
	#     if relic.has("bond_tags"):
	#         for tag in relic.bond_tags:
	#             current_bond_counts[tag] = current_bond_counts.get(tag, 0) + 1
	
	# 检查每个羁绊的激活状态
	for bond_id in bond_configs.keys():
		var count = current_bond_counts.get(bond_id, 0)
		if count == 0:
			continue
		
		# 获取该羁绊的最高激活等级
		var activated_level = _get_activated_level(bond_id, count)
		if activated_level > 0:
			_activate_bond(bond_id, activated_level)
	
	print("[BondManager] 重新计算羁绊: %d 个标签, %d 个激活羁绊" % [current_bond_counts.size(), active_bonds.size()])
	print("[BondManager] 羁绊统计: %s" % str(current_bond_counts))
	print("[BondManager] 激活羁绊: %s" % str(active_bonds.keys()))
	
	# 发出信号
	bonds_recalculated.emit(active_bonds)
	stat_modifiers_changed.emit()

func _get_activated_level(bond_id: String, current_count: int) -> int:
	"""获取羁绊的激活等级
	
	Args:
		bond_id: 羁绊ID
		current_count: 当前标签数量
	
	Returns:
		激活的等级（0表示未激活）
	"""
	if not bond_configs.has(bond_id):
		return 0
	
	var levels = bond_configs[bond_id].levels
	var activated_level = 0
	
	# 变身过载模式：只要有1个标签就激活最高等级
	if is_overdrive_mode and current_count >= 1:
		if levels.size() > 0:
			return levels[levels.size() - 1].level
	
	# 正常模式：检查满足条件的最高等级
	for level_data in levels:
		if current_count >= level_data.required_count:
			activated_level = level_data.level
		else:
			break  # 因为已排序，后面的等级更高，不会满足
	
	return activated_level

func _activate_bond(bond_id: String, level: int) -> void:
	"""激活指定等级的羁绊
	
	Args:
		bond_id: 羁绊ID
		level: 激活的等级
	"""
	if not bond_configs.has(bond_id):
		return
	
	var levels = bond_configs[bond_id].levels
	var effects = []
	
	# 收集所有激活等级的效果（累加）
	for level_data in levels:
		if level_data.level <= level:
			effects.append({
				"level": level_data.level,
				"effect_type": level_data.effect_type,
				"effect_param": level_data.effect_param,
				"effect_value": level_data.effect_value,
				"description": level_data.description
			})
	
	active_bonds[bond_id] = {
		"level": level,
		"effects": effects,
		"bond_type": bond_configs[bond_id].bond_type,
		"display_name": bond_configs[bond_id].display_name
	}

# ============================================================================
# 查询接口
# ============================================================================

func get_active_bond_level(bond_id: String) -> int:
	"""获取羁绊的激活等级
	
	Args:
		bond_id: 羁绊ID
	
	Returns:
		激活的等级（0表示未激活）
	"""
	if active_bonds.has(bond_id):
		return active_bonds[bond_id].level
	return 0

func get_bond_max_level(bond_id: String) -> int:
	"""获取羁绊的最大等级
	
	Args:
		bond_id: 羁绊ID
	
	Returns:
		最大等级
	"""
	if not bond_configs.has(bond_id):
		return 0
	
	var levels = bond_configs[bond_id].levels
	if levels.size() == 0:
		return 0
	
	return levels[levels.size() - 1].level

func get_bond_required_count(bond_id: String, level: int) -> int:
	"""获取羁绊指定等级的需求数量
	
	Args:
		bond_id: 羁绊ID
		level: 等级
	
	Returns:
		需求数量（0表示未找到）
	"""
	if not bond_configs.has(bond_id):
		return 0
	
	for level_data in bond_configs[bond_id].levels:
		if level_data.level == level:
			return level_data.required_count
	
	return 0

func get_bond_current_count(bond_id: String) -> int:
	"""获取羁绊的当前标签数量
	
	Args:
		bond_id: 羁绊ID
	
	Returns:
		当前数量
	"""
	return current_bond_counts.get(bond_id, 0)

func is_bond_active(bond_id: String) -> bool:
	"""检查羁绊是否激活
	
	Args:
		bond_id: 羁绊ID
	
	Returns:
		是否激活
	"""
	return active_bonds.has(bond_id)

func get_all_active_bonds() -> Dictionary:
	"""获取所有激活的羁绊
	
	Returns:
		激活的羁绊字典
	"""
	return active_bonds.duplicate(true)

func get_bond_config(bond_id: String) -> Dictionary:
	"""获取羁绊的完整配置
	
	Args:
		bond_id: 羁绊ID
	
	Returns:
		羁绊配置字典
	"""
	return bond_configs.get(bond_id, {})

func get_bond_display_name(bond_id: String) -> String:
	"""获取羁绊的显示名称
	
	Args:
		bond_id: 羁绊ID
	
	Returns:
		显示名称（如 "武道世家"）
	"""
	if not bond_configs.has(bond_id):
		return bond_id
	
	return bond_configs[bond_id].get("display_name", bond_id)

func get_bond_tooltip_text(bond_id: String, current_count: int) -> String:
	"""获取羁绊的悬浮提示文本
	
	Args:
		bond_id: 羁绊ID
		current_count: 当前标签数量
	
	Returns:
		格式化的提示文本
	"""
	if not bond_configs.has(bond_id):
		return "未知羁绊"
	
	var config = bond_configs[bond_id]
	var display_name = config.get("display_name", bond_id)
	var levels = config.get("levels", [])
	
	if levels.is_empty():
		return display_name
	
	# 构建提示文本
	var tooltip = "【%s】(当前: %d)\n" % [display_name, current_count]
	
	for level_data in levels:
		var level = level_data.level
		var required = level_data.required_count
		var description = level_data.description
		
		# 判断是否激活
		var is_active = current_count >= required
		var status = "[√]" if is_active else "[ ]"
		
		tooltip += "%s (%d) %s\n" % [status, required, description]
	
	return tooltip.strip_edges()

# ============================================================================
# 属性应用接口
# ============================================================================

func apply_stat_modifiers(player_stats: Dictionary) -> Dictionary:
	"""应用羁绊的属性加成
	
	Args:
		player_stats: 玩家属性字典
	
	Returns:
		应用加成后的属性字典
	"""
	var modified_stats = player_stats.duplicate(true)
	
	# 遍历所有激活的羁绊
	for bond_id in active_bonds.keys():
		var bond_data = active_bonds[bond_id]
		
		# 遍历该羁绊的所有效果
		for effect in bond_data.effects:
			if effect.effect_type == "stat_mod":
				_apply_stat_modifier(modified_stats, effect.effect_param, effect.effect_value)
	
	return modified_stats

func _apply_stat_modifier(stats: Dictionary, param: String, value: float) -> void:
	"""应用单个属性修改
	
	Args:
		stats: 属性字典
		param: 属性参数名
		value: 修改值
	"""
	# 处理特殊的属性名映射
	var stat_key = param
	
	# 根据属性类型应用加成
	match param:
		"crit_chance":
			stats["crit_chance"] = stats.get("crit_chance", 0) + value
		"crit_damage":
			stats["crit_damage"] = stats.get("crit_damage", 1.0) + value
		"energy_regen":
			stats["energy_regen"] = stats.get("energy_regen", 0) + value
		"cooldown_reduction":
			stats["cooldown_reduction"] = stats.get("cooldown_reduction", 0) + value
		"max_health":
			stats["max_health"] = stats.get("max_health", 100) + value
		"speed":
			stats["speed"] = stats.get("speed", 100) + value
		"armor":
			stats["armor"] = stats.get("armor", 0) + value
		"stat_share_ratio":
			stats["stat_share_ratio"] = stats.get("stat_share_ratio", 0) + value
		"gold_gain":
			stats["gold_gain"] = stats.get("gold_gain", 1.0) + value
		"exp_gain":
			stats["exp_gain"] = stats.get("exp_gain", 1.0) + value
		"dodge_chance":
			stats["dodge_chance"] = stats.get("dodge_chance", 0) + value
		"health_regen":
			stats["health_regen"] = stats.get("health_regen", 0) + value
		"projectile_speed":
			stats["projectile_speed"] = stats.get("projectile_speed", 1.0) + value
		"heal_power":
			stats["heal_power"] = stats.get("heal_power", 1.0) + value
		"damage_taken_reduction":
			stats["damage_taken_reduction"] = stats.get("damage_taken_reduction", 0) + value
		_:
			# 通用处理：直接加到对应键
			if stats.has(param):
				stats[param] = stats[param] + value
			else:
				stats[param] = value

func get_active_mechanics() -> Array:
	"""获取所有激活的机制效果
	
	Returns:
		机制效果数组 [{bond_id, effect_param, effect_value, description}]
	"""
	var mechanics = []
	
	for bond_id in active_bonds.keys():
		var bond_data = active_bonds[bond_id]
		
		for effect in bond_data.effects:
			if effect.effect_type == "mechanic":
				mechanics.append({
					"bond_id": bond_id,
					"effect_param": effect.effect_param,
					"effect_value": effect.effect_value,
					"description": effect.description,
					"level": effect.level
				})
	
	return mechanics

func has_mechanic(mechanic_name: String) -> bool:
	"""检查是否激活了指定机制
	
	Args:
		mechanic_name: 机制名称（effect_param）
	
	Returns:
		是否激活
	"""
	for bond_id in active_bonds.keys():
		var bond_data = active_bonds[bond_id]
		
		for effect in bond_data.effects:
			if effect.effect_type == "mechanic" and effect.effect_param == mechanic_name:
				return true
	
	return false

func get_mechanic_value(mechanic_name: String) -> float:
	"""获取机制的效果值
	
	Args:
		mechanic_name: 机制名称（effect_param）
	
	Returns:
		效果值（未找到返回0）
	"""
	for bond_id in active_bonds.keys():
		var bond_data = active_bonds[bond_id]
		
		for effect in bond_data.effects:
			if effect.effect_type == "mechanic" and effect.effect_param == mechanic_name:
				return effect.effect_value
	
	return 0.0

# ============================================================================
# 临时标签管理（用于大招/技能）
# ============================================================================

func add_temp_tag(tag: String) -> void:
	"""添加临时羁绊标签（例如大招激活时）
	
	Args:
		tag: 羁绊标签ID
	"""
	if tag.is_empty():
		return
	
	temp_bonus_tags[tag] = temp_bonus_tags.get(tag, 0) + 1
	print("[BondManager] 添加临时标签: %s (数量: %d)" % [tag, temp_bonus_tags[tag]])
	
	# 立即重新计算羁绊（保持当前队伍）
	_recalculate_with_current_team()

func remove_temp_tag(tag: String) -> void:
	"""移除临时羁绊标签
	
	Args:
		tag: 羁绊标签ID
	"""
	if tag.is_empty() or not temp_bonus_tags.has(tag):
		return
	
	temp_bonus_tags[tag] -= 1
	if temp_bonus_tags[tag] <= 0:
		temp_bonus_tags.erase(tag)
	
	print("[BondManager] 移除临时标签: %s (剩余: %d)" % [tag, temp_bonus_tags.get(tag, 0)])
	
	# 立即重新计算羁绊（保持当前队伍）
	_recalculate_with_current_team()

func get_temp_tags() -> Dictionary:
	"""获取当前所有临时标签
	
	Returns:
		临时标签字典
	"""
	return temp_bonus_tags.duplicate()

func clear_temp_tags() -> void:
	"""清空所有临时标签"""
	temp_bonus_tags.clear()
	_recalculate_with_current_team()

func _recalculate_with_current_team() -> void:
	"""使用当前队伍数据重新计算羁绊"""
	# 从 current_bond_counts 中提取原始队伍标签（排除临时标签）
	var team_tags = {}
	for tag in current_bond_counts.keys():
		var base_count = current_bond_counts[tag] - temp_bonus_tags.get(tag, 0)
		if base_count > 0:
			team_tags[tag] = base_count
	
	# 重建队伍ID列表（简化处理，直接使用标签重算）
	# 注意：这里假设每个标签对应一个角色，实际可能需要更复杂的逻辑
	var team_ids = []
	# 由于无法从标签反推角色ID，我们直接触发信号让外部重新计算
	stat_modifiers_changed.emit()

# ============================================================================
# 变身过载模式
# ============================================================================

func set_overdrive_mode(enabled: bool) -> void:
	"""设置变身过载模式
	
	Args:
		enabled: 是否启用
	"""
	if is_overdrive_mode != enabled:
		is_overdrive_mode = enabled
		print("[BondManager] 变身过载模式: %s" % ("启用" if enabled else "禁用"))
		
		# 重新计算羁绊（如果已有队伍数据）
		if not current_bond_counts.is_empty():
			# 保存当前队伍ID
			var team_ids = []
			for bond_id in current_bond_counts.keys():
				# 这里需要从其他地方获取队伍ID，暂时跳过自动重算
				pass
			
			# 触发信号通知需要重新计算
			stat_modifiers_changed.emit()

func is_in_overdrive_mode() -> bool:
	"""检查是否处于变身过载模式
	
	Returns:
		是否启用
	"""
	return is_overdrive_mode

# ============================================================================
# 调试接口
# ============================================================================

func print_active_bonds() -> void:
	"""打印所有激活的羁绊（调试用）"""
	print("\n========== 激活的羁绊 ==========")
	for bond_id in active_bonds.keys():
		var bond_data = active_bonds[bond_id]
		print("【%s】 Lv.%d - %s" % [bond_data.display_name, bond_data.level, bond_id])
		for effect in bond_data.effects:
			print("  - Lv.%d %s: %s = %.2f (%s)" % [
				effect.level,
				effect.effect_type,
				effect.effect_param,
				effect.effect_value,
				effect.description
			])
	print("================================\n")
