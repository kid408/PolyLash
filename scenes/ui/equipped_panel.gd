extends Panel
class_name EquippedPanel

# ============================================================================
# 已装备面板 - 显示所有角色的装备情况，支持快速卸下
# ============================================================================

@onready var scroll_container: ScrollContainer = $MarginContainer/VBoxContainer/ScrollContainer
@onready var list_container: VBoxContainer = $MarginContainer/VBoxContainer/ScrollContainer/ListContainer
@onready var close_button: Button = $MarginContainer/VBoxContainer/TopBar/CloseButton
@onready var title_label: Label = $MarginContainer/VBoxContainer/TopBar/TitleLabel

# Tooltip
var _tooltip: PanelContainer = null

# 卸下后的回调（通知仓库刷新）
signal equipment_changed

func _ready() -> void:
	close_button.pressed.connect(_on_close_pressed)
	
	# 创建tooltip
	_tooltip = ItemTooltipHelper.create_tooltip_panel()
	add_child(_tooltip)
	
	_build_list()
	print("[EquippedPanel] 初始化完成")

func _build_list() -> void:
	"""构建角色装备列表"""
	# 清空
	for child in list_container.get_children():
		child.queue_free()
	
	# 遍历所有角色
	var player_configs = ConfigManager.player_configs
	var has_any_equipped = false
	
	for player_id in player_configs.keys():
		var config = player_configs[player_id]
		if int(config.get("enabled", 0)) != 1:
			continue
		
		var item_type = EquipmentManager.get_equipped_item(player_id)
		if item_type <= 0:
			continue
		
		has_any_equipped = true
		var row = _create_character_row(player_id, config, item_type)
		list_container.add_child(row)
	
	if not has_any_equipped:
		var hint = Label.new()
		hint.text = "暂无角色装备道具"
		hint.add_theme_font_size_override("font_size", 18)
		hint.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
		hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		list_container.add_child(hint)

func _create_character_row(player_id: String, config: Dictionary, item_type: int) -> Control:
	"""创建单个角色装备行"""
	var row_panel = PanelContainer.new()
	row_panel.custom_minimum_size = Vector2(0, 64)
	
	var row_style = StyleBoxFlat.new()
	row_style.bg_color = Color(0.14, 0.14, 0.14, 1)
	row_style.set_corner_radius_all(8)
	row_style.content_margin_left = 12
	row_style.content_margin_right = 12
	row_style.content_margin_top = 8
	row_style.content_margin_bottom = 8
	row_panel.add_theme_stylebox_override("panel", row_style)
	
	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 12)
	row_panel.add_child(hbox)
	
	# 角色头像
	var avatar = TextureRect.new()
	avatar.custom_minimum_size = Vector2(48, 48)
	avatar.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	avatar.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	var visual = ConfigManager.get_player_visual(player_id)
	var sprite_path = visual.get("sprite_path", "")
	if sprite_path != "":
		var tex = load(sprite_path)
		if tex:
			avatar.texture = tex
	hbox.add_child(avatar)
	
	# 角色名称
	var name_label = Label.new()
	name_label.text = config.get("display_name", player_id)
	name_label.custom_minimum_size = Vector2(80, 0)
	name_label.add_theme_font_size_override("font_size", 18)
	name_label.add_theme_color_override("font_color", Color(1, 1, 1))
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hbox.add_child(name_label)
	
	# 装备图标按钮（悬浮显示tooltip）
	var item_config = WarehouseManager.get_item_config(item_type)
	var item_btn = Button.new()
	item_btn.custom_minimum_size = Vector2(48, 48)
	item_btn.expand_icon = true
	item_btn.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	
	var icon_path = item_config.get("resourcePath", "")
	if icon_path != "":
		var tex = load(icon_path)
		if tex:
			item_btn.icon = tex
			item_btn.add_theme_constant_override("icon_max_width", 40)
	
	var btn_style = StyleBoxFlat.new()
	btn_style.bg_color = Color(0.1, 0.1, 0.1, 1)
	btn_style.set_corner_radius_all(6)
	btn_style.set_border_width_all(1)
	btn_style.border_color = Color(0.3, 0.3, 0.3)
	var btn_hover = StyleBoxFlat.new()
	btn_hover.bg_color = Color(0.1, 0.1, 0.1, 1)
	btn_hover.set_corner_radius_all(6)
	btn_hover.set_border_width_all(2)
	btn_hover.border_color = Color(1, 0.84, 0, 1)
	item_btn.add_theme_stylebox_override("normal", btn_style)
	item_btn.add_theme_stylebox_override("hover", btn_hover)
	item_btn.add_theme_stylebox_override("pressed", btn_hover)
	
	item_btn.mouse_entered.connect(_on_item_mouse_entered.bind(item_type))
	item_btn.mouse_exited.connect(_on_item_mouse_exited)
	hbox.add_child(item_btn)
	
	# 装备简要信息
	var info_widget = ItemTooltipHelper.create_equip_info_widget(item_type)
	info_widget.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info_widget.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hbox.add_child(info_widget)
	
	# 卸下按钮
	var unequip_btn = Button.new()
	unequip_btn.text = "卸下"
	unequip_btn.custom_minimum_size = Vector2(64, 32)
	unequip_btn.add_theme_font_size_override("font_size", 14)
	
	var unequip_style = StyleBoxFlat.new()
	unequip_style.bg_color = Color(0.6, 0.3, 0.3, 1)
	unequip_style.set_corner_radius_all(6)
	var unequip_hover = StyleBoxFlat.new()
	unequip_hover.bg_color = Color(0.7, 0.35, 0.35, 1)
	unequip_hover.set_corner_radius_all(6)
	unequip_btn.add_theme_stylebox_override("normal", unequip_style)
	unequip_btn.add_theme_stylebox_override("hover", unequip_hover)
	unequip_btn.add_theme_stylebox_override("pressed", unequip_hover)
	
	unequip_btn.pressed.connect(_on_unequip_pressed.bind(player_id))
	hbox.add_child(unequip_btn)
	
	return row_panel

# ============================================================================
# Tooltip
# ============================================================================

func _on_item_mouse_entered(item_type: int) -> void:
	ItemTooltipHelper.populate_tooltip(_tooltip, item_type)
	_tooltip.reset_size()
	_tooltip.visible = true

func _on_item_mouse_exited() -> void:
	_tooltip.visible = false

func _process(_delta: float) -> void:
	if _tooltip and _tooltip.visible:
		ItemTooltipHelper.update_tooltip_position(_tooltip, get_viewport())

# ============================================================================
# 卸下装备
# ============================================================================

func _on_unequip_pressed(player_id: String) -> void:
	SoundManager.play("ui_click")
	if EquipmentManager.unequip_item(player_id):
		print("[EquippedPanel] 卸下成功: %s" % player_id)
		equipment_changed.emit()
		_build_list()
	else:
		SoundManager.play("ui_error")
		print("[EquippedPanel] 卸下失败（仓库已满）: %s" % player_id)

# ============================================================================
# 关闭
# ============================================================================

func _on_close_pressed() -> void:
	SoundManager.play("ui_click")
	queue_free()
