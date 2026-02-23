extends Node

# ============================================================================
# 羁绊管理器 - 核心数值逻辑系统
# ============================================================================

# 信号
signal bonds_recalculated(active_bonds: Dictionary)
signal stat_modifiers_changed()
signal bond_level_changed(bond_id: String, old_level: int, new_level: int)

# ============================================================================
# 数据结构
# ============================================================================

# 羁绊配置数据：{bond_id: {levels: [{level, required_count, effect_type, ...}]}}
var bond_configs: Dictionary = {}

# 当前激活的羁绊：{bond_id: {level: int, effects: [{effect_type, effect_param, effect_value}]}}
var active_bonds: Dictionary = {}

# 当前队伍的羁绊标签统计：{bond_id: count}
var current_bond_counts: Dictionary = {}

# 标签来源追踪：{bond_tag: {character: int, equipment: int, emblem: int}}
var tag_sources: Dictionary = {}

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
	"""重新计算激活的羁绊（三源标签统计）
	
	Args:
		team_player_ids: 当前队伍角色ID列表
		equipped_relics: 已装备圣物列表（可选，未来扩展）
	"""
	# 保存旧的激活羁绊状态（用于等级变化检测）
	var old_bonds = active_bonds.duplicate(true)
	
	# 清空当前数据
	current_bond_counts.clear()
	tag_sources.clear()
	active_bonds.clear()
	
	# 来源1: 角色自带标签
	_count_character_tags(team_player_ids)
	
	# 来源2: 装备 bond_grant
	_count_equipment_tags(team_player_ids)
	
	# 来源3: 全局徽章
	_count_emblem_tags()
	
	# 添加临时标签
	_add_temp_tags()
	
	# 检查每个羁绊的激活状态
	for bond_id in bond_configs.keys():
		var count = current_bond_counts.get(bond_id, 0)
		if count == 0:
			continue
		
		# 获取该羁绊的最高激活等级
		var activated_level = _get_activated_level(bond_id, count)
		if activated_level > 0:
			_activate_bond(bond_id, activated_level)
	
	# 检测等级变化（升级/降级/失活）
	_detect_level_changes(old_bonds)
	
	print("[BondManager] 重新计算羁绊: %d 个标签, %d 个激活羁绊" % [current_bond_counts.size(), active_bonds.size()])
	print("[BondManager] 羁绊统计: %s" % str(current_bond_counts))
	print("[BondManager] 标签来源: %s" % str(tag_sources))
	print("[BondManager] 激活羁绊: %s" % str(active_bonds.keys()))
	
	# 发出信号
	bonds_recalculated.emit(active_bonds)
	stat_modifiers_changed.emit()

# ============================================================================
# 三源标签统计内部方法
# ============================================================================

func _count_character_tags(team_player_ids: Array) -> void:
	"""来源1: 统计角色自带的羁绊标签（origin_tag, mastery_tag, tactic_tag）"""
	for player_id in team_player_ids:
		var config = ConfigManager.get_player_config(player_id)
		if config.is_empty():
			continue
		
		var tags = [
			config.get("origin_tag", ""),
			config.get("mastery_tag", ""),
			config.get("tactic_tag", "")
		]
		
		for tag in tags:
			if tag == "":
				continue
			current_bond_counts[tag] = current_bond_counts.get(tag, 0) + 1
			_add_tag_source(tag, "character", 1)

func _count_equipment_tags(team_player_ids: Array) -> void:
	"""来源2: 统计角色装备的 bond_grant 标签（支持 | 分隔多羁绊）"""
	for pid in team_player_ids:
		var item_data = EquipmentManager.get_equipped_item_data(str(pid))
		if item_data.is_empty():
			continue
		var bond_grant = str(item_data.get("bond_grant", "")).strip_edges()
		if bond_grant.is_empty():
			continue
		var bond_tags = bond_grant.split("|")
		for tag in bond_tags:
			tag = tag.strip_edges()
			if tag.is_empty():
				continue
			current_bond_counts[tag] = current_bond_counts.get(tag, 0) + 1
			_add_tag_source(tag, "equipment", 1)

func _count_emblem_tags() -> void:
	"""来源3: 统计全局徽章提供的羁绊标签"""
	var emblem_tags = EmblemManager.get_emblem_tags()
	for tag in emblem_tags:
		current_bond_counts[tag] = current_bond_counts.get(tag, 0) + emblem_tags[tag]
		_add_tag_source(tag, "emblem", emblem_tags[tag])

func _add_temp_tags() -> void:
	"""添加临时羁绊标签（来自技能/大招）到统计"""
	for tag in temp_bonus_tags.keys():
		current_bond_counts[tag] = current_bond_counts.get(tag, 0) + temp_bonus_tags[tag]

func _add_tag_source(bond_tag: String, source: String, count: int) -> void:
	"""更新标签来源追踪字典
	
	Args:
		bond_tag: 羁绊标签
		source: 来源类型（"character", "equipment", "emblem"）
		count: 数量
	"""
	if not tag_sources.has(bond_tag):
		tag_sources[bond_tag] = {"character": 0, "equipment": 0, "emblem": 0}
	tag_sources[bond_tag][source] += count

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

func _detect_level_changes(old_bonds: Dictionary) -> void:
	"""检测羁绊等级变化（升级/降级/失活），发出 bond_level_changed 信号
	
	stat_mod 效果基于基础值重算，降级自动生效；
	mechanic 效果通过实时查询 active_bonds，降级后自动失效。
	
	Args:
		old_bonds: 重算前的 active_bonds 快照
	"""
	# 检查升级或降级（当前激活的羁绊）
	for bond_id in active_bonds.keys():
		var new_level = active_bonds[bond_id].level
		var old_level = old_bonds.get(bond_id, {}).get("level", 0)
		if new_level != old_level:
			bond_level_changed.emit(bond_id, old_level, new_level)
	
	# 检查完全失活（旧有但新没有）
	for bond_id in old_bonds.keys():
		if not active_bonds.has(bond_id):
			bond_level_changed.emit(bond_id, old_bonds[bond_id].level, 0)

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

func get_activated_level(bond_id: String, count: int) -> int:
	"""获取指定标签数量下的羁绊激活等级（供 UI 组件调用）
	
	Args:
		bond_id: 羁绊ID
		count: 当前标签数量
	
	Returns:
		激活的等级（0表示未激活）
	"""
	return _get_activated_level(bond_id, count)

func get_tag_sources(bond_tag: String) -> Dictionary:
	"""获取指定羁绊标签的来源分布
	
	Args:
		bond_tag: 羁绊标签
	
	Returns:
		来源分布字典 {character: int, equipment: int, emblem: int}
	"""
	if tag_sources.has(bond_tag):
		return tag_sources[bond_tag].duplicate()
	return {"character": 0, "equipment": 0, "emblem": 0}

# ============================================================================
# 格式化工具函数
# ============================================================================

static func format_bond_status(count: int, activated_level: int, max_level: int, next_required: int) -> String:
	"""统一格式化羁绊状态文本，供 BondHUD 和 BondSummaryItem 共用
	
	格式规则：
	- 未激活: "0/N"（N 为 Lv.1 需求数量）
	- 已激活未满级: "Lv.X (cur/next)"
	- 已满级: "Lv.MAX"；溢出时 "Lv.X (cur/next)"
	
	Args:
		count: 当前标签数量
		activated_level: 当前激活等级（0=未激活）
		max_level: 该羁绊的最大等级
		next_required: 下一级需求数量（满级时为当前级需求数量）
	
	Returns:
		格式化的状态文本
	"""
	if activated_level == 0:
		return "0/%d" % next_required
	elif activated_level >= max_level:
		if count > next_required:
			return "Lv.%d (%d/%d)" % [activated_level, count, next_required]
		return "Lv.MAX"
	else:
		return "Lv.%d (%d/%d)" % [activated_level, count, next_required]

func get_bond_status_text(bond_id: String, count: int) -> String:
	"""便捷方法：根据 bond_id 和当前数量生成格式化状态文本
	
	Args:
		bond_id: 羁绊ID
		count: 当前标签数量
	
	Returns:
		格式化的状态文本
	"""
	var activated_level = get_activated_level(bond_id, count)
	var max_level = get_bond_max_level(bond_id)
	
	# 计算 next_required：下一级需求，满级时用当前级需求
	var next_required: int = 0
	if activated_level == 0:
		# 未激活：Lv.1 的需求
		next_required = get_bond_required_count(bond_id, 1)
	elif activated_level >= max_level:
		# 满级：当前级需求（用于溢出判断）
		next_required = get_bond_required_count(bond_id, max_level)
	else:
		# 已激活未满级：下一级需求
		next_required = get_bond_required_count(bond_id, activated_level + 1)
	
	if next_required == 0:
		next_required = 1  # 防止除零或显示异常
	
	return BondManager.format_bond_status(count, activated_level, max_level, next_required)

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
	
	# P4-3: 应用属性共享（指挥型 Lv.1）
	if has_mechanic("stat_share"):
		_apply_stat_share(modified_stats)
	
	return modified_stats

# P4-3: 应用属性共享（指挥型 Lv.1）
func _apply_stat_share(stats: Dictionary) -> void:
	"""应用后台角色的属性共享
	
	Args:
		stats: 当前角色的属性字典
	"""
	var share_ratio = get_mechanic_value("stat_share")
	if share_ratio <= 0:
		return
	
	# 获取后台角色列表（未激活的角色）
	var bench_characters = _get_bench_characters()
	if bench_characters.is_empty():
		return
	
	print("[BondManager] [P4-3] 属性共享激活，共享比例: %.0f%%" % (share_ratio * 100))
	
	# 累加后台角色的基础属性
	var total_bonus_damage = 0.0
	var total_bonus_health = 0.0
	var total_bonus_speed = 0.0
	
	for char_id in bench_characters:
		var char_config = ConfigManager.get_player_config(char_id)
		if char_config.is_empty():
			continue
		
		# 获取基础属性（不包括羁绊加成）
		var base_damage = float(char_config.get("damage", 0))
		var base_health = float(char_config.get("health", 0))
		var base_speed = float(char_config.get("base_speed", 0))
		
		# 计算共享加成
		total_bonus_damage += base_damage * share_ratio
		total_bonus_health += base_health * share_ratio
		total_bonus_speed += base_speed * share_ratio
		
		print("[BondManager] [P4-3] 后台角色 %s: 攻击力+%.0f, 生命+%.0f, 速度+%.0f" % [
			char_id,
			base_damage * share_ratio,
			base_health * share_ratio,
			base_speed * share_ratio
		])
	
	# 应用加成到当前角色
	if total_bonus_damage > 0:
		stats["damage"] = stats.get("damage", 0) + total_bonus_damage
		print("[BondManager] [P4-3] 获得后台攻击力加成: +%.0f" % total_bonus_damage)
	
	if total_bonus_health > 0:
		stats["max_health"] = stats.get("max_health", 100) + total_bonus_health
		print("[BondManager] [P4-3] 获得后台生命加成: +%.0f" % total_bonus_health)
	
	if total_bonus_speed > 0:
		stats["speed"] = stats.get("speed", 100) + total_bonus_speed
		print("[BondManager] [P4-3] 获得后台速度加成: +%.0f" % total_bonus_speed)

# P4-3: 获取后台角色列表
func _get_bench_characters() -> Array[String]:
	"""获取后台角色ID列表（未激活的角色）
	
	Returns:
		后台角色ID数组
	"""
	var bench: Array[String] = []
	
	# 获取当前激活角色
	var current_player_id = Global.get_current_player_id()
	
	# 遍历所有选择的角色
	for player_id in Global.selected_player_ids:
		if player_id != current_player_id:
			# 检查角色是否存活
			var state = Global.get_player_state(player_id)
			var health = state.get("health", 0)
			if health > 0:
				bench.append(player_id)
	
	return bench

func _apply_stat_modifier(stats: Dictionary, param: String, value: float) -> void:
	"""应用单个属性修改
	
	Args:
		stats: 属性字典
		param: 属性参数名
		value: 修改值
	"""
	# 检查是否为百分比属性（_pct 后缀）
	var is_percentage = param.ends_with("_pct")
	var base_param = param.trim_suffix("_pct") if is_percentage else param
	
	# 百分比属性：基于当前值的乘法加成
	if is_percentage:
		match base_param:
			"energy_regen":
				var base_value = stats.get("energy_regen", 0)
				stats["energy_regen"] = base_value * (1.0 + value)
			"max_health":
				var base_value = stats.get("max_health", 100)
				stats["max_health"] = base_value * (1.0 + value)
			"movement_speed", "speed":
				var base_value = stats.get("speed", 100)
				stats["speed"] = base_value * (1.0 + value)
			"pickup_range":
				var base_value = stats.get("pickup_range", 100)
				stats["pickup_range"] = base_value * (1.0 + value)
			_:
				# 通用百分比处理
				if stats.has(base_param):
					stats[base_param] = stats[base_param] * (1.0 + value)
				else:
					# 如果属性不存在，假设基础值为0，百分比加成无效
					pass
		return
	
	# 固定值属性：直接加法
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
		"stat_share", "stat_share_ratio":
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
		"pickup_range":
			stats["pickup_range"] = stats.get("pickup_range", 100) + value
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

func get_bond_summary() -> Array:
	"""获取羁绊摘要（用于存档）
	
	Returns:
		羁绊摘要数组 [{bond_id: String, level: int, count: int}]
	"""
	var summary: Array = []
	
	for bond_id in active_bonds.keys():
		var bond_data = active_bonds[bond_id]
		summary.append({
			"bond_id": bond_id,
			"level": bond_data.level,
			"count": current_bond_counts.get(bond_id, 0)
		})
	
	return summary

func restore_from_save(bond_counts_data: Dictionary) -> void:
	"""从存档恢复羁绊统计数据
	
	Args:
		bond_counts_data: 羁绊标签统计数据 {bond_id: count}
	"""
	print("[BondManager] 从存档恢复羁绊数据: %s" % str(bond_counts_data))
	
	# 直接使用存档的标签统计
	current_bond_counts = bond_counts_data.duplicate(true)
	
	# 重新计算激活的羁绊
	active_bonds.clear()
	for bond_id in current_bond_counts.keys():
		var count = current_bond_counts[bond_id]
		var activated_level = _get_activated_level(bond_id, count)
		if activated_level > 0:
			_activate_bond(bond_id, activated_level)
	
	print("[BondManager] 恢复完成: %d 个激活羁绊" % active_bonds.size())
	bonds_recalculated.emit(active_bonds)
	stat_modifiers_changed.emit()

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
