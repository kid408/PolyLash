extends Panel
class_name CharacterUpgradePanel

# ============================================================================
# 角色强化面板 - 使用金币升级角色属性
# 新版UI：宽敞布局，显示具体数值和增量预览
# ============================================================================

# ============================================================================
# 节点引用
# ============================================================================

@onready var back_button: Button = $MarginContainer/VBoxContainer/TopBar/BackButton
@onready var gold_label: Label = $MarginContainer/VBoxContainer/TopBar/GoldContainer/GoldLabel
@onready var gold_icon: TextureRect = $MarginContainer/VBoxContainer/TopBar/GoldContainer/GoldIcon
@onready var character_cards_container: HBoxContainer = $MarginContainer/VBoxContainer/CardsContainer

# 金币图标纹理缓存
var gold_texture: Texture2D = null

# 武器商店开关
var weapon_shop_enabled: bool = false

# ============================================================================
# 初始化
# ============================================================================

func _ready() -> void:
	back_button.pressed.connect(_on_back_pressed)
	
	# 预加载金币图标
	gold_texture = load("res://assets/sprites/Gold/gold_1.png")
	if gold_texture:
		gold_icon.texture = gold_texture
	
	# 检查武器商店开关
	weapon_shop_enabled = int(ConfigManager.get_game_setting("enable_starting_weapon_shop", 0)) == 1
	
	# 如果启用武器商店，生成随机武器
	if weapon_shop_enabled:
		DataManager.generate_random_weapons_for_players(Global.selected_player_ids)
	
	# 更新金币显示
	_update_gold_display()
	
	# 生成角色卡片
	_generate_character_cards()
	
	print("[CharacterUpgrade] 初始化完成，武器商店: %s" % ("启用" if weapon_shop_enabled else "禁用"))

# ============================================================================
# 金币显示
# ============================================================================

func _update_gold_display() -> void:
	gold_label.text = str(DataManager.get_total_gold())

# ============================================================================
# 角色卡片生成
# ============================================================================

func _generate_character_cards() -> void:
	# 清除现有卡片
	for child in character_cards_container.get_children():
		child.queue_free()
	
	# 获取已选角色
	var selected_ids = Global.selected_player_ids
	if selected_ids.is_empty():
		var hint = Label.new()
		hint.text = "请先在角色选择界面选择角色"
		hint.add_theme_font_size_override("font_size", 24)
		hint.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
		hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		character_cards_container.add_child(hint)
		return
	
	# 为每个已选角色创建卡片
	for player_id in selected_ids:
		var card = _create_character_card(player_id)
		character_cards_container.add_child(card)

func _create_character_card(player_id: String) -> Control:
	var config = ConfigManager.get_player_config(player_id)
	var visual = ConfigManager.get_player_visual(player_id)
	
	# 卡片容器
	var card = PanelContainer.new()
	card.name = "Card_" + player_id
	card.custom_minimum_size = Vector2(380, 0)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.size_flags_vertical = Control.SIZE_EXPAND_FILL
	
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.12, 0.12, 1)
	style.set_corner_radius_all(16)
	style.set_border_width_all(2)
	style.border_color = Color(0.25, 0.25, 0.25)
	style.content_margin_left = 20
	style.content_margin_right = 20
	style.content_margin_top = 20
	style.content_margin_bottom = 20
	card.add_theme_stylebox_override("panel", style)
	
	# 内容VBox
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 16)
	card.add_child(vbox)
	
	# === 头部：头像 + 名称 ===
	var header = HBoxContainer.new()
	header.add_theme_constant_override("separation", 16)
	vbox.add_child(header)
	
	# 角色头像
	var avatar = TextureRect.new()
	avatar.custom_minimum_size = Vector2(96, 96)
	avatar.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	avatar.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	var sprite_path = visual.get("sprite_path", "")
	if sprite_path != "":
		var tex = load(sprite_path)
		if tex:
			avatar.texture = tex
	header.add_child(avatar)
	
	# 名称和羁绊
	var name_vbox = VBoxContainer.new()
	name_vbox.add_theme_constant_override("separation", 4)
	name_vbox.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	header.add_child(name_vbox)
	
	var name_label = Label.new()
	name_label.text = config.get("display_name", player_id)
	name_label.add_theme_font_size_override("font_size", 26)
	name_label.add_theme_color_override("font_color", Color(1, 1, 1))
	name_vbox.add_child(name_label)
	
	var ties_label = Label.new()
	ties_label.text = "[%s]" % config.get("ties", "无")
	ties_label.add_theme_font_size_override("font_size", 16)
	ties_label.add_theme_color_override("font_color", Color(0.9, 0.75, 0.2))
	name_vbox.add_child(ties_label)
	
	# === 分隔线 ===
	var sep = HSeparator.new()
	sep.add_theme_constant_override("separation", 8)
	vbox.add_child(sep)
	
	# === 属性升级列表 ===
	var attrs_container = VBoxContainer.new()
	attrs_container.name = "AttrsContainer"
	attrs_container.add_theme_constant_override("separation", 16)  # 宽松间距
	attrs_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(attrs_container)
	
	# 为每个可升级属性创建行
	var upgrade_configs = DataManager.get_all_upgrade_configs()
	for upgrade_config in upgrade_configs:
		var attr_row = _create_attribute_row(player_id, upgrade_config)
		attrs_container.add_child(attr_row)
	
	# === 随机武器商店区域 (如果启用) ===
	if weapon_shop_enabled:
		var weapon_shop = _create_weapon_shop_section(player_id)
		if weapon_shop:
			vbox.add_child(weapon_shop)
	
	# 底部留白 (无论是否启用武器商店都添加)
	var bottom_spacer = Control.new()
	bottom_spacer.custom_minimum_size = Vector2(0, 30)
	vbox.add_child(bottom_spacer)
	
	return card


func _create_attribute_row(player_id: String, upgrade_config: Dictionary) -> Control:
	var attr_name = upgrade_config.get("attribute_name", "")
	var display_name = upgrade_config.get("display_name", attr_name)
	var cost = int(upgrade_config.get("cost", 0))
	var value_increase = upgrade_config.get("value_increase", 0)
	
	var current_level = DataManager.get_upgrade_level(player_id, attr_name)
	var max_level = DataManager.get_max_upgrade_level()
	var is_maxed = current_level >= max_level
	
	# 获取当前数值和基础数值
	var current_value = DataManager.get_player_current_attribute(player_id, attr_name)
	
	# 行容器
	var row = HBoxContainer.new()
	row.name = "AttrRow_" + attr_name
	row.add_theme_constant_override("separation", 12)
	row.custom_minimum_size = Vector2(0, 36)
	
	# 1. 属性名称 (左对齐，固定宽度)
	var label = Label.new()
	label.text = display_name
	label.custom_minimum_size = Vector2(100, 0)
	label.add_theme_font_size_override("font_size", 18)
	label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
	row.add_child(label)
	
	# 2. 当前数值 (白色)
	var value_label = Label.new()
	if value_increase is float and value_increase < 1:
		value_label.text = "%.1f" % current_value
	else:
		value_label.text = str(int(current_value))
	value_label.custom_minimum_size = Vector2(60, 0)
	value_label.add_theme_font_size_override("font_size", 20)
	value_label.add_theme_color_override("font_color", Color(1, 1, 1))
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(value_label)
	
	# 3. 增量预览 或 MAX 标签
	var increment_label = Label.new()
	increment_label.custom_minimum_size = Vector2(80, 0)
	increment_label.add_theme_font_size_override("font_size", 18)
	increment_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	
	if is_maxed:
		increment_label.text = "MAX"
		increment_label.add_theme_color_override("font_color", Color(1, 0.85, 0.2))  # 金色
	else:
		if value_increase is float and value_increase < 1:
			increment_label.text = "+%.1f" % value_increase
		else:
			increment_label.text = "+%d" % int(value_increase)
		increment_label.add_theme_color_override("font_color", Color(0.3, 0.9, 0.4))  # 绿色
	row.add_child(increment_label)
	
	# 4. 弹性空间
	var spacer = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer)
	
	# 5. 购买按钮 (如果未满级) - 使用 HBoxContainer 实现完美居中
	if not is_maxed:
		var buy_btn = Button.new()
		buy_btn.name = "BuyBtn_" + attr_name
		buy_btn.custom_minimum_size = Vector2(100, 36)
		buy_btn.text = ""  # 清空文字，使用子节点显示内容
		
		# 按钮样式
		var can_afford = DataManager.can_upgrade(player_id, attr_name)
		var btn_style = StyleBoxFlat.new()
		btn_style.set_corner_radius_all(8)
		
		if can_afford:
			btn_style.bg_color = Color(0.2, 0.55, 0.3)
			buy_btn.disabled = false
		else:
			btn_style.bg_color = Color(0.35, 0.35, 0.35)
			buy_btn.disabled = true
		
		buy_btn.add_theme_stylebox_override("normal", btn_style)
		buy_btn.add_theme_stylebox_override("hover", btn_style)
		buy_btn.add_theme_stylebox_override("pressed", btn_style)
		buy_btn.add_theme_stylebox_override("disabled", btn_style)
		
		# 按钮内容容器：使用 CenterContainer 包裹 HBoxContainer 实现完美居中
		var center_container = CenterContainer.new()
		center_container.set_anchors_preset(Control.PRESET_FULL_RECT)
		center_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
		buy_btn.add_child(center_container)
		
		var btn_hbox = HBoxContainer.new()
		btn_hbox.add_theme_constant_override("separation", 6)
		btn_hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
		center_container.add_child(btn_hbox)
		
		# 金币小图标
		var coin_icon = TextureRect.new()
		coin_icon.custom_minimum_size = Vector2(20, 20)
		coin_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		coin_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		coin_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if gold_texture:
			coin_icon.texture = gold_texture
		btn_hbox.add_child(coin_icon)
		
		# 价格文字 (垂直居中)
		var price_label = Label.new()
		price_label.text = str(cost)
		price_label.add_theme_font_size_override("font_size", 16)
		price_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		price_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		btn_hbox.add_child(price_label)
		
		buy_btn.pressed.connect(_on_upgrade_pressed.bind(player_id, attr_name))
		row.add_child(buy_btn)
	
	return row

# ============================================================================
# 随机武器商店
# ============================================================================

func _create_weapon_shop_section(player_id: String) -> Control:
	"""创建随机武器商店区域"""
	var weapon_type = DataManager.get_random_weapon_for_player(player_id)
	if weapon_type == "":
		return null
	
	# 获取武器配置
	var weapon_id = weapon_type + "_1"
	var weapon_stats = ConfigManager.get_weapon_stats(weapon_id)
	if weapon_stats.is_empty():
		return null
	
	var price = int(ConfigManager.get_game_setting("starting_weapon_price", 100))
	var is_purchased = DataManager.has_purchased_weapon(player_id)
	
	# 外层容器
	var section = VBoxContainer.new()
	section.name = "WeaponShopSection"
	section.add_theme_constant_override("separation", 12)
	
	# 分隔线
	var sep = HSeparator.new()
	sep.add_theme_constant_override("separation", 16)
	section.add_child(sep)
	
	# 武器购买区背景
	var shop_panel = PanelContainer.new()
	shop_panel.custom_minimum_size = Vector2(0, 80)
	
	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color = Color(0.08, 0.08, 0.08, 1)
	panel_style.set_corner_radius_all(8)
	panel_style.content_margin_left = 12
	panel_style.content_margin_right = 12
	panel_style.content_margin_top = 10
	panel_style.content_margin_bottom = 10
	shop_panel.add_theme_stylebox_override("panel", panel_style)
	section.add_child(shop_panel)
	
	# 内容VBox
	var content_vbox = VBoxContainer.new()
	content_vbox.add_theme_constant_override("separation", 8)
	shop_panel.add_child(content_vbox)
	
	# 标题
	var title_label = Label.new()
	title_label.text = "随机初始武器"
	title_label.add_theme_font_size_override("font_size", 14)
	title_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	content_vbox.add_child(title_label)
	
	# 内容行
	var content_row = HBoxContainer.new()
	content_row.add_theme_constant_override("separation", 12)
	content_vbox.add_child(content_row)
	
	# 武器图标
	var weapon_icon = TextureRect.new()
	weapon_icon.custom_minimum_size = Vector2(40, 40)
	weapon_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	weapon_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	var icon_path = weapon_stats.get("icon_path", "")
	if icon_path != "":
		var tex = load(icon_path)
		if tex:
			weapon_icon.texture = tex
	content_row.add_child(weapon_icon)
	
	# 武器名称
	var weapon_name = Label.new()
	weapon_name.text = weapon_stats.get("display_name", weapon_type)
	weapon_name.add_theme_font_size_override("font_size", 18)
	weapon_name.add_theme_color_override("font_color", Color(0.9, 0.8, 0.4))
	weapon_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	weapon_name.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	content_row.add_child(weapon_name)
	
	# 购买按钮或已装备标签
	if is_purchased:
		var equipped_label = Label.new()
		equipped_label.text = "已装备"
		equipped_label.add_theme_font_size_override("font_size", 16)
		equipped_label.add_theme_color_override("font_color", Color(0.3, 0.8, 0.4))
		equipped_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		content_row.add_child(equipped_label)
	else:
		var buy_btn = Button.new()
		buy_btn.name = "BuyWeaponBtn_" + player_id
		buy_btn.custom_minimum_size = Vector2(100, 36)
		buy_btn.text = ""
		
		var can_afford = DataManager.get_total_gold() >= price
		var btn_style = StyleBoxFlat.new()
		btn_style.set_corner_radius_all(8)
		
		if can_afford:
			btn_style.bg_color = Color(0.5, 0.35, 0.15)
			buy_btn.disabled = false
		else:
			btn_style.bg_color = Color(0.35, 0.35, 0.35)
			buy_btn.disabled = true
		
		buy_btn.add_theme_stylebox_override("normal", btn_style)
		buy_btn.add_theme_stylebox_override("hover", btn_style)
		buy_btn.add_theme_stylebox_override("pressed", btn_style)
		buy_btn.add_theme_stylebox_override("disabled", btn_style)
		
		# 按钮内容
		var center = CenterContainer.new()
		center.set_anchors_preset(Control.PRESET_FULL_RECT)
		center.mouse_filter = Control.MOUSE_FILTER_IGNORE
		buy_btn.add_child(center)
		
		var btn_hbox = HBoxContainer.new()
		btn_hbox.add_theme_constant_override("separation", 6)
		btn_hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
		center.add_child(btn_hbox)
		
		var coin_icon = TextureRect.new()
		coin_icon.custom_minimum_size = Vector2(20, 20)
		coin_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		coin_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		coin_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if gold_texture:
			coin_icon.texture = gold_texture
		btn_hbox.add_child(coin_icon)
		
		var price_label = Label.new()
		price_label.text = str(price)
		price_label.add_theme_font_size_override("font_size", 16)
		price_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		price_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		btn_hbox.add_child(price_label)
		
		buy_btn.pressed.connect(_on_weapon_purchase_pressed.bind(player_id))
		content_row.add_child(buy_btn)
	
	return section

func _on_weapon_purchase_pressed(player_id: String) -> void:
	"""购买随机武器"""
	print("[CharacterUpgrade] 尝试购买武器: %s" % player_id)
	
	if DataManager.purchase_starting_weapon(player_id):
		print("[CharacterUpgrade] 武器购买成功!")
		_update_gold_display()
		_generate_character_cards()
	else:
		print("[CharacterUpgrade] 武器购买失败 - 金币不足或已购买")

# ============================================================================
# 升级按钮事件
# ============================================================================

func _on_upgrade_pressed(player_id: String, attr_name: String) -> void:
	print("[CharacterUpgrade] 尝试升级: %s.%s" % [player_id, attr_name])
	
	if DataManager.do_upgrade(player_id, attr_name):
		print("[CharacterUpgrade] 升级成功!")
		_update_gold_display()
		_generate_character_cards()
	else:
		print("[CharacterUpgrade] 升级失败 - 金币不足或已满级")

# ============================================================================
# 返回按钮
# ============================================================================

func _on_back_pressed() -> void:
	print("[CharacterUpgrade] 返回角色选择")
	get_tree().change_scene_to_file("res://scenes/ui/selection_panel/selection_panel.tscn")
