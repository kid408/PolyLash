extends Node

# ============================================================================
# 羁绊 UI 加载器 - 管理羁绊图标和数据
# ============================================================================

# 羁绊配置缓存：{bond_id: {bond_type, icon_path_index, display_name, description}}
var bond_configs: Dictionary = {}

# 图标路径模板
const ICON_PATH_TEMPLATES = {
	"origin": "res://assets/sprites/Icons/origins/origin%d.png",
	"mastery": "res://assets/sprites/Icons/masterys/mastery%d.png",
	"tactic": "res://assets/sprites/Icons/tactics/tactic%d.png"
}

# ============================================================================
# 初始化
# ============================================================================

func _ready() -> void:
	_load_bond_configs()
	print("[BondUILoader] 初始化完成，加载了 %d 个羁绊配置" % bond_configs.size())

# ============================================================================
# 配置加载
# ============================================================================

func _load_bond_configs() -> void:
	"""从 CSV 加载羁绊配置"""
	var csv_path = "res://config/player/bond_config.csv"
	if not FileAccess.file_exists(csv_path):
		printerr("[BondUILoader] 羁绊配置文件不存在: %s" % csv_path)
		return
	
	var file = FileAccess.open(csv_path, FileAccess.READ)
	if not file:
		printerr("[BondUILoader] 无法打开羁绊配置文件")
		return
	
	# 跳过表头
	file.get_csv_line()
	# 跳过说明行
	file.get_csv_line()
	
	while not file.eof_reached():
		var line = file.get_csv_line()
		if line.size() < 10:  # 现在需要至少10列
			continue
		
		# CSV 列顺序: bond_id, type, level, required_count, effect_type, effect_param, effect_value, icon_path_index, display_name, description
		var bond_id = line[0]
		var bond_type = line[1]
		var icon_path_index = int(line[7])  # 修复：使用正确的列索引
		var display_name = line[8]          # 修复：使用正确的列索引
		var description = line[9]           # 修复：使用正确的列索引
		
		if bond_id == "" or bond_id == "-1":
			continue
		
		# 只在第一次遇到该 bond_id 时创建配置（避免重复）
		if not bond_configs.has(bond_id):
			bond_configs[bond_id] = {
				"bond_type": bond_type,
				"icon_path_index": icon_path_index,
				"display_name": display_name,
				"description": description
			}
	
	file.close()
	print("[BondUILoader] 加载了 %d 个羁绊配置" % bond_configs.size())

# ============================================================================
# 公共接口
# ============================================================================

func get_bond_icon(bond_tag: String, bond_type: String) -> Texture2D:
	"""获取羁绊图标（带资源回退逻辑）
	
	Args:
		bond_tag: 羁绊标签（如 "inkborn", "blaster"）
		bond_type: 羁绊类型（"origin", "mastery", "tactic"）
	
	Returns:
		Texture2D: 图标纹理，如果找不到返回 null
	"""
	if not bond_configs.has(bond_tag):
		printerr("[BondUILoader] 找不到羁绊配置: %s" % bond_tag)
		return null
	
	var config = bond_configs[bond_tag]
	
	# 验证类型匹配
	if config.bond_type != bond_type:
		printerr("[BondUILoader] 羁绊类型不匹配: %s 应该是 %s，但传入了 %s" % [bond_tag, config.bond_type, bond_type])
		return null
	
	# 构建图标路径
	var icon_path_template = ICON_PATH_TEMPLATES.get(bond_type, "")
	if icon_path_template == "":
		printerr("[BondUILoader] 未知的羁绊类型: %s" % bond_type)
		return null
	
	var icon_path = icon_path_template % config.icon_path_index
	
	# 尝试加载图标
	if FileAccess.file_exists(icon_path):
		var texture = load(icon_path) as Texture2D
		if texture:
			return texture
		else:
			push_warning("[BondUILoader] 无法加载图标: %s" % icon_path)
	else:
		push_warning("[BondUILoader] 图标文件不存在: %s，尝试回退到默认图标" % icon_path)
	
	# ============================================================================
	# 资源回退逻辑 (Asset Fallback)
	# ============================================================================
	# 如果指定的图标不存在，尝试加载同类型的第一个图标作为占位符
	var fallback_path = icon_path_template % 1
	
	if FileAccess.file_exists(fallback_path):
		var fallback_texture = load(fallback_path) as Texture2D
		if fallback_texture:
			push_warning("[BondUILoader] 使用回退图标: %s -> %s" % [icon_path, fallback_path])
			return fallback_texture
	
	# 如果回退也失败，返回null
	printerr("[BondUILoader] 回退图标也不存在: %s" % fallback_path)
	return null

func get_bond_display_name(bond_tag: String) -> String:
	"""获取羁绊显示名称"""
	if not bond_configs.has(bond_tag):
		return bond_tag
	return bond_configs[bond_tag].get("display_name", bond_tag)

func get_bond_description(bond_tag: String) -> String:
	"""获取羁绊描述"""
	if not bond_configs.has(bond_tag):
		return ""
	return bond_configs[bond_tag].get("description", "")

func get_bond_config(bond_tag: String) -> Dictionary:
	"""获取完整的羁绊配置"""
	return bond_configs.get(bond_tag, {})

# ============================================================================
# 辅助函数
# ============================================================================

func create_bond_icon_container(origin_tag: String, mastery_tag: String, tactic_tag: String, icon_size: int = 24, team_player_ids: Array = []) -> HBoxContainer:
	"""创建羁绊图标容器
	
	Args:
		origin_tag: 身世标签
		mastery_tag: 职能标签
		tactic_tag: 战术标签
		icon_size: 图标大小（默认24）
		team_player_ids: 当前队伍角色ID列表（用于计算羁绊数量）
	
	Returns:
		HBoxContainer: 包含3个图标的容器
	"""
	var container = HBoxContainer.new()
	container.name = "BondIconsContainer"
	container.add_theme_constant_override("separation", 4)
	
	# 如果提供了队伍信息，计算当前羁绊数量
	var bond_counts = {}
	if not team_player_ids.is_empty():
		var bond_stats = calculate_team_bonds(team_player_ids)
		for bond_id in bond_stats.bonds.keys():
			bond_counts[bond_id] = bond_stats.bonds[bond_id].count
	
	# 创建3个图标
	var bonds = [
		{"tag": origin_tag, "type": "origin"},
		{"tag": mastery_tag, "type": "mastery"},
		{"tag": tactic_tag, "type": "tactic"}
	]
	
	for bond in bonds:
		var bond_tag = bond.tag
		var bond_type = bond.type
		
		var icon_rect = TextureRect.new()
		icon_rect.custom_minimum_size = Vector2(icon_size, icon_size)
		icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		
		var texture = get_bond_icon(bond_tag, bond_type)
		if texture:
			icon_rect.texture = texture
			
			# 生成详细的 Tooltip
			var current_count = bond_counts.get(bond_tag, 0)
			if current_count > 0:
				# 如果有队伍信息，显示详细 Tooltip
				icon_rect.tooltip_text = BondManager.get_bond_tooltip_text(bond_tag, current_count)
			else:
				# 否则只显示名称
				icon_rect.tooltip_text = BondManager.get_bond_display_name(bond_tag)
		else:
			# 如果找不到图标，显示占位符
			icon_rect.modulate = Color(0.3, 0.3, 0.3, 0.5)
		
		container.add_child(icon_rect)
	
	return container

func update_bond_icons(container: HBoxContainer, origin_tag: String, mastery_tag: String, tactic_tag: String, team_player_ids: Array = []) -> void:
	"""更新现有容器中的羁绊图标
	
	Args:
		container: 羁绊图标容器
		origin_tag: 身世标签
		mastery_tag: 职能标签
		tactic_tag: 战术标签
		team_player_ids: 当前队伍角色ID列表（用于计算羁绊数量）
	"""
	if not container:
		printerr("[BondUILoader] 无效的羁绊图标容器")
		return
	
	# 清除现有图标
	for child in container.get_children():
		child.queue_free()
	
	var bonds = [
		{"tag": origin_tag, "type": "origin"},
		{"tag": mastery_tag, "type": "mastery"},
		{"tag": tactic_tag, "type": "tactic"}
	]
	
	# 如果提供了队伍信息，计算当前羁绊数量
	var bond_counts = {}
	if not team_player_ids.is_empty():
		var bond_stats = calculate_team_bonds(team_player_ids)
		for bond_id in bond_stats.bonds.keys():
			bond_counts[bond_id] = bond_stats.bonds[bond_id].count
	
	# 创建新图标
	for bond in bonds:
		var bond_tag = bond.tag
		var bond_type = bond.type
		
		var icon_rect = TextureRect.new()
		icon_rect.custom_minimum_size = Vector2(24, 24)
		icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		
		var texture = get_bond_icon(bond_tag, bond_type)
		if texture:
			icon_rect.texture = texture
			
			# 生成详细的 Tooltip
			var current_count = bond_counts.get(bond_tag, 0)
			if current_count > 0:
				# 如果有队伍信息，显示详细 Tooltip
				icon_rect.tooltip_text = BondManager.get_bond_tooltip_text(bond_tag, current_count)
			else:
				# 否则只显示名称
				icon_rect.tooltip_text = BondManager.get_bond_display_name(bond_tag)
			
			icon_rect.modulate = Color.WHITE
		else:
			icon_rect.texture = null
			icon_rect.modulate = Color(0.3, 0.3, 0.3, 0.5)
		
		container.add_child(icon_rect)

# ============================================================================
# 队伍羁绊统计
# ============================================================================

func calculate_team_bonds(selected_player_ids: Array) -> Dictionary:
	"""计算队伍羁绊统计（角色标签 + 装备bond_grant）
	
	Args:
		selected_player_ids: 已选角色ID数组（如 ["butcher", "wind", "pyro"]）
	
	Returns:
		Dictionary: 羁绊统计结果
		格式: {
			"bonds": {
				"martial": {"count": 2, "type": "origin"},
				"destruction": {"count": 1, "type": "mastery"},
				...
			}
		}
	"""
	var result = {
		"bonds": {}
	}
	
	# 统计每个羁绊标签的出现次数
	for player_id in selected_player_ids:
		var config = ConfigManager.get_player_config(player_id)
		if config.is_empty():
			continue
		
		# 获取三个羁绊标签
		var tags = [
			{"tag": config.get("origin_tag", ""), "type": "origin"},
			{"tag": config.get("mastery_tag", ""), "type": "mastery"},
			{"tag": config.get("tactic_tag", ""), "type": "tactic"}
		]
		
		# 统计每个标签
		for tag_info in tags:
			var tag = tag_info.tag
			var type = tag_info.type
			
			if tag == "":
				continue
			
			if not result.bonds.has(tag):
				result.bonds[tag] = {
					"count": 0,
					"type": type
				}
			
			result.bonds[tag].count += 1
		
		# 统计装备的 bond_grant（支持 | 分隔多羁绊）
		var item_data = EquipmentManager.get_equipped_item_data(str(player_id))
		if not item_data.is_empty():
			var bond_grant = str(item_data.get("bond_grant", "")).strip_edges()
			if bond_grant != "":
				var bond_tags = bond_grant.split("|")
				for bt in bond_tags:
					bt = bt.strip_edges()
					if bt == "":
						continue
					# 查找该羁绊的类型
					var bt_config = bond_configs.get(bt, {})
					var bt_type = bt_config.get("bond_type", "tactic")
					if not result.bonds.has(bt):
						result.bonds[bt] = {
							"count": 0,
							"type": bt_type
						}
					result.bonds[bt].count += 1
	
	return result

func get_sorted_bonds(bond_stats: Dictionary) -> Array:
	"""获取排序后的羁绊列表
	
	Args:
		bond_stats: calculate_team_bonds 返回的统计结果
	
	Returns:
		Array: 排序后的羁绊数组，格式: [{"bond_id": "martial", "count": 2, "type": "origin", "max": 2}, ...]
		按 count 降序排列
	"""
	var bonds_array = []
	
	for bond_id in bond_stats.bonds.keys():
		var bond_data = bond_stats.bonds[bond_id]
		var bond_type = bond_data.type
		var count = bond_data.count
		
		# 从 BondManager 获取最大等级（动态）
		var max_level = BondManager.get_bond_max_level(bond_id)
		
		# 获取最高等级的需求数量
		var max_count = 0
		if max_level > 0:
			max_count = BondManager.get_bond_required_count(bond_id, max_level)
		
		bonds_array.append({
			"bond_id": bond_id,
			"count": count,
			"type": bond_type,
			"max": max_count,
			"max_level": max_level
		})
	
	# 按 count 降序排序
	bonds_array.sort_custom(func(a, b): return a.count > b.count)
	
	return bonds_array
