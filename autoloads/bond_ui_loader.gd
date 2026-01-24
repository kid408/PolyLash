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
		if line.size() < 5:
			continue
		
		var bond_id = line[0]
		var bond_type = line[1]
		var icon_path_index = int(line[2])
		var display_name = line[3]
		var description = line[4]
		
		if bond_id == "" or bond_id == "-1":
			continue
		
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
	"""获取羁绊图标
	
	Args:
		bond_tag: 羁绊标签（如 "martial", "destruction"）
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
	
	# 加载图标
	if not FileAccess.file_exists(icon_path):
		printerr("[BondUILoader] 图标文件不存在: %s" % icon_path)
		return null
	
	var texture = load(icon_path) as Texture2D
	if not texture:
		printerr("[BondUILoader] 无法加载图标: %s" % icon_path)
		return null
	
	return texture

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

func create_bond_icon_container(origin_tag: String, mastery_tag: String, tactic_tag: String, icon_size: int = 24) -> HBoxContainer:
	"""创建羁绊图标容器
	
	Args:
		origin_tag: 身世标签
		mastery_tag: 职能标签
		tactic_tag: 战术标签
		icon_size: 图标大小（默认24）
	
	Returns:
		HBoxContainer: 包含3个图标的容器
	"""
	var container = HBoxContainer.new()
	container.name = "BondIconsContainer"
	container.add_theme_constant_override("separation", 4)
	
	# 创建3个图标
	var bonds = [
		{"tag": origin_tag, "type": "origin"},
		{"tag": mastery_tag, "type": "mastery"},
		{"tag": tactic_tag, "type": "tactic"}
	]
	
	for bond in bonds:
		var icon_rect = TextureRect.new()
		icon_rect.custom_minimum_size = Vector2(icon_size, icon_size)
		icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		
		var texture = get_bond_icon(bond.tag, bond.type)
		if texture:
			icon_rect.texture = texture
			icon_rect.tooltip_text = get_bond_display_name(bond.tag)
		else:
			# 如果找不到图标，显示占位符
			icon_rect.modulate = Color(0.3, 0.3, 0.3, 0.5)
		
		container.add_child(icon_rect)
	
	return container

func update_bond_icons(container: HBoxContainer, origin_tag: String, mastery_tag: String, tactic_tag: String) -> void:
	"""更新现有容器中的羁绊图标
	
	Args:
		container: 羁绊图标容器
		origin_tag: 身世标签
		mastery_tag: 职能标签
		tactic_tag: 战术标签
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
	
	# 创建新图标
	for bond in bonds:
		var icon_rect = TextureRect.new()
		icon_rect.custom_minimum_size = Vector2(24, 24)
		icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		
		var texture = get_bond_icon(bond.tag, bond.type)
		if texture:
			icon_rect.texture = texture
			icon_rect.tooltip_text = get_bond_display_name(bond.tag)
			icon_rect.modulate = Color.WHITE
		else:
			icon_rect.texture = null
			icon_rect.modulate = Color(0.3, 0.3, 0.3, 0.5)
		
		container.add_child(icon_rect)

# ============================================================================
# 队伍羁绊统计
# ============================================================================

# 羁绊阈值配置（硬编码用于原型）
const BOND_THRESHOLDS = {
	"origin": 2,   # 身世羁绊需要2个
	"mastery": 3,  # 职能羁绊需要3个
	"tactic": 2    # 战术羁绊需要2个
}

func calculate_team_bonds(selected_player_ids: Array) -> Dictionary:
	"""计算队伍羁绊统计
	
	Args:
		selected_player_ids: 已选角色ID数组（如 ["butcher", "wind", "pyro"]）
	
	Returns:
		Dictionary: 羁绊统计结果
		格式: {
			"bonds": {
				"martial": {"count": 2, "type": "origin"},
				"destruction": {"count": 1, "type": "mastery"},
				...
			},
			"thresholds": {"origin": 2, "mastery": 3, "tactic": 2}
		}
	"""
	var result = {
		"bonds": {},
		"thresholds": BOND_THRESHOLDS.duplicate()
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
	var thresholds = bond_stats.get("thresholds", BOND_THRESHOLDS)
	
	for bond_id in bond_stats.bonds.keys():
		var bond_data = bond_stats.bonds[bond_id]
		var bond_type = bond_data.type
		var count = bond_data.count
		var max_count = thresholds.get(bond_type, 2)
		
		bonds_array.append({
			"bond_id": bond_id,
			"count": count,
			"type": bond_type,
			"max": max_count
		})
	
	# 按 count 降序排序
	bonds_array.sort_custom(func(a, b): return a.count > b.count)
	
	return bonds_array
