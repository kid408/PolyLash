extends Node

# ============================================================================
# 道具Tooltip辅助器 - 统一的道具提示信息生成
# 供仓库UI、角色强化面板等复用
# ============================================================================

const STAT_DISPLAY_NAMES = {
	"hp": "生命",
	"attack": "攻击",
	"speed": "速度",
	"energy": "能量",
	"max_health_pct": "最大生命",
	"energy_regen_pct": "魔力回复",
	"movement_speed_pct": "移动速度",
	"pickup_range_pct": "拾取范围",
	"damage_percent": "伤害加成",
	"fire_percent": "火焰伤害",
	"ice_percent": "冰霜伤害",
	"aoe_percent": "范围效果",
	"duration_percent": "持续时间",
	"speed_percent": "速度加成",
	"debuff_duration_pct": "减益延长",
	"shape_tolerance_pct": "图形容错",
	"line_duration_pct": "线条持续",
	"bench_cd_reduce_pct": "后台冷却",
	"switch_cd_reduce_pct": "切换冷却",
	"stat_share_pct": "属性共享",
	"attack_speed": "攻速",
}

# 面板 -> VBox 的映射缓存
var _panel_vbox_map: Dictionary = {}

func get_stat_display_name(stat_key: String) -> String:
	return STAT_DISPLAY_NAMES.get(stat_key, stat_key)

# ============================================================================
# 创建Tooltip面板（代码创建，供 character_upgrade 等使用）
# ============================================================================

func create_tooltip_panel() -> PanelContainer:
	var panel = PanelContainer.new()
	panel.name = "ItemTooltipPanel"
	panel.visible = false
	panel.top_level = true
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.custom_minimum_size = Vector2(220, 0)

	# 样式
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.08, 0.1, 1.0)
	style.set_corner_radius_all(6)
	style.border_color = Color(0.72, 0.58, 0.2, 1)
	style.set_border_width_all(2)
	style.shadow_color = Color(0, 0, 0, 0.6)
	style.shadow_size = 6
	panel.add_theme_stylebox_override("panel", style)

	# MarginContainer
	var margin = MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_bottom", 8)
	panel.add_child(margin)

	# ContentVBox
	var vbox = VBoxContainer.new()
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_theme_constant_override("separation", 3)
	margin.add_child(vbox)

	# 缓存映射
	_panel_vbox_map[panel] = vbox
	return panel

# ============================================================================
# 注册已有面板（供 warehouse_ui.tscn 等场景面板使用）
# ============================================================================

func register_panel(panel: PanelContainer) -> void:
	if _panel_vbox_map.has(panel):
		return
	var vbox = panel.get_node_or_null("MarginContainer/ContentVBox")
	if vbox:
		_panel_vbox_map[panel] = vbox

# ============================================================================
# 填充Tooltip内容
# ============================================================================

func populate_tooltip(panel: PanelContainer, item_type: int) -> void:
	# 自动注册未缓存的面板
	if not _panel_vbox_map.has(panel):
		register_panel(panel)
	
	var vbox = _panel_vbox_map.get(panel)
	if not vbox:
		printerr("[ItemTooltipHelper] 面板未注册且无法自动发现 VBox")
		return

	# 清空旧内容
	for child in vbox.get_children():
		child.queue_free()

	var config = WarehouseManager.get_item_config(item_type)
	if config.is_empty():
		return

	# 名称
	var name_label = Label.new()
	name_label.text = config.get("display_name", config.get("name", "未知"))
	name_label.add_theme_font_size_override("font_size", 15)
	name_label.add_theme_color_override("font_color", Color(1, 0.9, 0.5))
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(name_label)

	# 层级
	var tier = str(config.get("tier", ""))
	if tier != "":
		var tier_label = Label.new()
		tier_label.text = "T%s 装备" % tier
		tier_label.add_theme_font_size_override("font_size", 12)
		tier_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
		tier_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vbox.add_child(tier_label)

	# 基础属性
	var base_stat = str(config.get("base_stat", "")).strip_edges()
	var base_value = str(config.get("base_value", "")).strip_edges()
	if base_stat != "" and base_value != "" and base_value != "0":
		_add_stat_line(vbox, get_stat_display_name(base_stat), "+" + base_value, Color(0.4, 0.9, 0.5))

	# 修正属性
	var mod_type = str(config.get("mod_type", "")).strip_edges()
	var mod_value_str = str(config.get("mod_value", "")).strip_edges()
	if mod_type != "" and mod_value_str != "" and mod_value_str != "0":
		var mod_val = float(mod_value_str)
		var display_val = "%+d%%" % int(mod_val * 100)
		_add_stat_line(vbox, get_stat_display_name(mod_type), display_val, Color(0.5, 0.7, 1.0))

	# 羁绊图标行
	var bond_grant = str(config.get("bond_grant", "")).strip_edges()
	if bond_grant != "":
		var bond_tags = bond_grant.split("|")
		for bt in bond_tags:
			bt = bt.strip_edges()
			if bt == "":
				continue
			_add_bond_icon_line(vbox, bt)

	# 描述
	var desc = str(config.get("description", "")).strip_edges()
	if desc != "":
		var desc_label = Label.new()
		desc_label.text = desc
		desc_label.add_theme_font_size_override("font_size", 11)
		desc_label.add_theme_color_override("font_color", Color(0.65, 0.65, 0.65))
		desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		desc_label.custom_minimum_size = Vector2(200, 0)
		desc_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vbox.add_child(desc_label)

# ============================================================================
# 辅助：添加属性行
# ============================================================================

func _add_stat_line(vbox: VBoxContainer, stat_name: String, value_text: String, value_color: Color) -> void:
	var hbox = HBoxContainer.new()
	hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.add_theme_constant_override("separation", 6)

	var name_lbl = Label.new()
	name_lbl.text = stat_name
	name_lbl.add_theme_font_size_override("font_size", 13)
	name_lbl.add_theme_color_override("font_color", Color(0.75, 0.75, 0.75))
	name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.add_child(name_lbl)

	var val_lbl = Label.new()
	val_lbl.text = value_text
	val_lbl.add_theme_font_size_override("font_size", 13)
	val_lbl.add_theme_color_override("font_color", value_color)
	val_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.add_child(val_lbl)

	vbox.add_child(hbox)

# ============================================================================
# 辅助：添加羁绊图标行
# ============================================================================

func _add_bond_icon_line(vbox: VBoxContainer, bond_tag: String) -> void:
	var bond_config = BondUILoader.get_bond_config(bond_tag)
	if bond_config.is_empty():
		return

	var bond_type = bond_config.get("bond_type", "")
	var display_name = bond_config.get("display_name", bond_tag)

	var hbox = HBoxContainer.new()
	hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.add_theme_constant_override("separation", 4)

	var icon = TextureRect.new()
	icon.custom_minimum_size = Vector2(16, 16)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var tex = BondUILoader.get_bond_icon(bond_tag, bond_type)
	if tex:
		icon.texture = tex
	hbox.add_child(icon)

	var lbl = Label.new()
	lbl.text = display_name
	lbl.add_theme_font_size_override("font_size", 12)
	lbl.add_theme_color_override("font_color", Color(0.9, 0.75, 0.3))
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.add_child(lbl)

	vbox.add_child(hbox)

# ============================================================================
# Tooltip位置更新
# ============================================================================

func update_tooltip_position(panel: PanelContainer, viewport: Viewport) -> void:
	var mouse_pos = viewport.get_mouse_position()
	var vp_size = viewport.get_visible_rect().size
	var panel_size = panel.size
	var offset = Vector2(16, 16)

	var pos = mouse_pos + offset
	# 右边界
	if pos.x + panel_size.x > vp_size.x:
		pos.x = mouse_pos.x - panel_size.x - 8
	# 下边界
	if pos.y + panel_size.y > vp_size.y:
		pos.y = vp_size.y - panel_size.y - 4
	# 上边界
	if pos.y < 0:
		pos.y = 4

	panel.position = pos

# ============================================================================
# 创建简要装备信息控件（用于角色卡片内联显示）
# ============================================================================

func create_equip_info_widget(item_type: int) -> Control:
	"""创建紧凑的装备信息控件：名称 + 关键属性 + 羁绊图标"""
	var config = WarehouseManager.get_item_config(item_type)
	if config.is_empty():
		return Control.new()

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 2)

	# 道具名称
	var name_lbl = Label.new()
	name_lbl.text = config.get("display_name", config.get("name", ""))
	name_lbl.add_theme_font_size_override("font_size", 13)
	name_lbl.add_theme_color_override("font_color", Color(1, 0.9, 0.5))
	vbox.add_child(name_lbl)

	# 关键属性（基础 + 修正合并一行）
	var stat_parts: Array[String] = []
	var base_stat = str(config.get("base_stat", "")).strip_edges()
	var base_value = str(config.get("base_value", "")).strip_edges()
	if base_stat != "" and base_value != "" and base_value != "0":
		stat_parts.append("%s+%s" % [get_stat_display_name(base_stat), base_value])

	var mod_type = str(config.get("mod_type", "")).strip_edges()
	var mod_value_str = str(config.get("mod_value", "")).strip_edges()
	if mod_type != "" and mod_value_str != "" and mod_value_str != "0":
		var mod_val = float(mod_value_str)
		stat_parts.append("%s+%d%%" % [get_stat_display_name(mod_type), int(mod_val * 100)])

	if not stat_parts.is_empty():
		var stat_lbl = Label.new()
		stat_lbl.text = " | ".join(stat_parts)
		stat_lbl.add_theme_font_size_override("font_size", 11)
		stat_lbl.add_theme_color_override("font_color", Color(0.5, 0.8, 0.5))
		vbox.add_child(stat_lbl)

	# 羁绊图标
	var bond_grant = str(config.get("bond_grant", "")).strip_edges()
	if bond_grant != "":
		var icon_hbox = HBoxContainer.new()
		icon_hbox.add_theme_constant_override("separation", 3)
		var bond_tags = bond_grant.split("|")
		for bt in bond_tags:
			bt = bt.strip_edges()
			if bt == "":
				continue
			var bc = BondUILoader.get_bond_config(bt)
			var bt_type = bc.get("bond_type", "")
			var tex = BondUILoader.get_bond_icon(bt, bt_type)
			if tex:
				var icon = TextureRect.new()
				icon.custom_minimum_size = Vector2(14, 14)
				icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
				icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
				icon.texture = tex
				icon_hbox.add_child(icon)
		if icon_hbox.get_child_count() > 0:
			vbox.add_child(icon_hbox)

	return vbox
