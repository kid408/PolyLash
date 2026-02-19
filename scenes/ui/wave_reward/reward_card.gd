extends PanelContainer
class_name RewardCard

# ============================================================================
# 奖励卡片 - 显示单个波次奖励选项
# ============================================================================

# 卡片被点击
signal card_pressed(index: int)

# 卡片索引
var card_index: int = -1
# 奖励数据
var reward_data: Dictionary = {}

# 内部节点引用
var _name_label: Label
var _desc_label: Label
var _type_label: Label
var _select_button: Button

# ============================================================================
# 初始化
# ============================================================================

func _ready() -> void:
	_build_ui()

func _build_ui() -> void:
	"""程序化构建卡片 UI"""
	# 卡片最小尺寸
	custom_minimum_size = Vector2(220, 280)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL

	# 外边距
	var margin = MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	add_child(margin)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	margin.add_child(vbox)

	# 类型标签（顶部小字）
	_type_label = Label.new()
	_type_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_type_label.add_theme_font_size_override("font_size", 14)
	_type_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	vbox.add_child(_type_label)

	# 名称标签
	_name_label = Label.new()
	_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_name_label.add_theme_font_size_override("font_size", 20)
	vbox.add_child(_name_label)

	# 分隔
	var sep = HSeparator.new()
	vbox.add_child(sep)

	# 描述标签
	_desc_label = Label.new()
	_desc_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_desc_label.add_theme_font_size_override("font_size", 14)
	_desc_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(_desc_label)

	# 选择按钮
	_select_button = Button.new()
	_select_button.text = "选择"
	_select_button.pressed.connect(_on_select_pressed)
	vbox.add_child(_select_button)

# ============================================================================
# 数据设置
# ============================================================================

func setup(index: int, data: Dictionary) -> void:
	"""设置卡片显示内容
	
	Args:
		index: 卡片索引（0/1/2）
		data: 奖励数据字典 {type, display_name, description, ...}
	"""
	card_index = index
	reward_data = data

	if not is_node_ready():
		await ready

	_name_label.text = str(data.get("display_name", "未知奖励"))
	_desc_label.text = str(data.get("description", ""))

	# 根据类型设置标签和颜色
	var reward_type = data.get("type", "")
	match reward_type:
		"artifact":
			_type_label.text = "【护符】"
			_type_label.add_theme_color_override("font_color", Color(0.4, 0.8, 1.0))
		"equipment":
			_type_label.text = "【装备】"
			_type_label.add_theme_color_override("font_color", Color(1.0, 0.8, 0.3))
		"gold":
			_type_label.text = "【金币】"
			_type_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.4))
		_:
			_type_label.text = "【奖励】"

# ============================================================================
# 信号处理
# ============================================================================

func _on_select_pressed() -> void:
	SoundManager.play("ui_click")
	card_pressed.emit(card_index)
