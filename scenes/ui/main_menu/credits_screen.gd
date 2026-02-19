extends Control
# ============================================================================
# 致谢界面 - 以档案清单风格展示游戏使用的素材、作者和协议信息
# ============================================================================

signal back_pressed

# 条目预制体
const CREDITS_ITEM = preload("res://scenes/ui/main_menu/credits_item.tscn")

# 分类列表
const CATEGORIES := ["All", "Art", "Audio", "Font", "Code", "Special"]

# 颜色常量
const COLOR_TEXT := Color("#FFFFFF")
const COLOR_TEXT_DIM := Color("#AAAAAA")
const COLOR_FILTER_BG := Color("#2a2a2a")
const COLOR_FILTER_ACTIVE := Color("#4CAF50")

# 统一字体
var _font: Font = preload("res://assets/font/Bake Soda.otf")

# 所有致谢数据
var all_credits: Array[Dictionary] = []
# 当前筛选分类
var current_filter: String = "All"
# 筛选按钮引用
var filter_buttons: Dictionary = {}  # category -> Button

# 节点引用
@onready var back_button: Button = $MarginContainer/VBox/TopBar/BackButton
@onready var title_label: Label = $MarginContainer/VBox/TopBar/TitleLabel
@onready var content_hbox: HBoxContainer = $MarginContainer/VBox/ContentArea
@onready var filter_container: VBoxContainer = $MarginContainer/VBox/ContentArea/LeftPanel/FilterContainer
@onready var scroll_container: ScrollContainer = $MarginContainer/VBox/ContentArea/RightPanel/ScrollContainer
@onready var content_list: VBoxContainer = $MarginContainer/VBox/ContentArea/RightPanel/ScrollContainer/ContentList
@onready var copyright_label: Label = $MarginContainer/VBox/CopyrightLabel

func _ready() -> void:
	# 加载致谢数据
	all_credits = ConfigManager.get_credits_configs()
	# 构建筛选按钮
	_build_filter_buttons()
	# 连接返回按钮
	back_button.pressed.connect(func(): back_pressed.emit())
	# 默认显示全部
	_show_filtered("All")

# ============================================================================
# 筛选按钮构建
# ============================================================================

func _build_filter_buttons() -> void:
	for category in CATEGORIES:
		var btn := Button.new()
		btn.text = category
		btn.custom_minimum_size = Vector2(120, 36)
		btn.flat = true
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		# 样式
		var style_normal := StyleBoxFlat.new()
		style_normal.bg_color = COLOR_FILTER_BG
		style_normal.corner_radius_top_left = 4
		style_normal.corner_radius_top_right = 4
		style_normal.corner_radius_bottom_right = 4
		style_normal.corner_radius_bottom_left = 4
		style_normal.content_margin_left = 12
		style_normal.content_margin_right = 12
		style_normal.content_margin_top = 6
		style_normal.content_margin_bottom = 6
		btn.add_theme_stylebox_override("normal", style_normal)
		btn.add_theme_stylebox_override("hover", style_normal)
		btn.add_theme_stylebox_override("pressed", style_normal)
		btn.add_theme_color_override("font_color", COLOR_TEXT_DIM)
		btn.add_theme_color_override("font_hover_color", COLOR_TEXT)
		btn.add_theme_font_override("font", _font)
		btn.add_theme_font_size_override("font_size", 16)
		btn.pressed.connect(_on_filter_pressed.bind(category))
		filter_container.add_child(btn)
		filter_buttons[category] = btn

# ============================================================================
# 筛选逻辑
# ============================================================================

func _on_filter_pressed(category: String) -> void:
	_show_filtered(category)

func _show_filtered(category: String) -> void:
	current_filter = category
	_update_filter_styles()
	_clear_list()
	for entry in all_credits:
		if category == "All" or entry.get("category", "") == category:
			_add_credit_item(entry)
	# 滚动回顶部
	scroll_container.scroll_vertical = 0

func _update_filter_styles() -> void:
	for cat in filter_buttons:
		var btn: Button = filter_buttons[cat]
		var is_active: bool = (str(cat) == current_filter)
		var style := StyleBoxFlat.new()
		style.corner_radius_top_left = 4
		style.corner_radius_top_right = 4
		style.corner_radius_bottom_right = 4
		style.corner_radius_bottom_left = 4
		style.content_margin_left = 12
		style.content_margin_right = 12
		style.content_margin_top = 6
		style.content_margin_bottom = 6
		if is_active:
			style.bg_color = COLOR_FILTER_ACTIVE
			btn.add_theme_color_override("font_color", COLOR_TEXT)
		else:
			style.bg_color = COLOR_FILTER_BG
			btn.add_theme_color_override("font_color", COLOR_TEXT_DIM)
		btn.add_theme_stylebox_override("normal", style)
		btn.add_theme_stylebox_override("hover", style)
		btn.add_theme_stylebox_override("pressed", style)

# ============================================================================
# 条目创建（使用 credits_item.tscn 预制体）
# ============================================================================

func _add_credit_item(data: Dictionary) -> void:
	var item = CREDITS_ITEM.instantiate()
	content_list.add_child(item)
	item.setup(data)

# ============================================================================
# 工具方法
# ============================================================================

func _clear_list() -> void:
	for child in content_list.get_children():
		child.queue_free()
