extends PanelContainer
## 存档槽位卡片预制体
## 显示单个存档槽位的信息，支持空/进行中/损坏三种状态
## 悬停时边框变为 #4CAF50，右上角删除按钮仅非空槽位显示

signal clicked(slot_index: int)
signal delete_requested(slot_index: int)

# 子节点引用
@onready var slot_label: Label = $MarginContainer/VBox/SlotLabel
@onready var status_label: Label = $MarginContainer/VBox/StatusLabel
@onready var info_container: VBoxContainer = $MarginContainer/VBox/InfoContainer
@onready var leader_icon: TextureRect = $MarginContainer/VBox/InfoContainer/HBox/LeaderIcon
@onready var floor_wave_label: Label = $MarginContainer/VBox/InfoContainer/HBox/InfoVBox/FloorWaveLabel
@onready var bond_container: HBoxContainer = $MarginContainer/VBox/InfoContainer/HBox/InfoVBox/BondContainer
@onready var play_time_label: Label = $MarginContainer/VBox/InfoContainer/TimeVBox/PlayTimeLabel
@onready var last_played_label: Label = $MarginContainer/VBox/InfoContainer/TimeVBox/LastPlayedLabel
@onready var delete_button: Button = $DeleteButton
@onready var empty_label: Label = $MarginContainer/VBox/EmptyLabel
@onready var warning_icon: Label = $MarginContainer/VBox/WarningIcon

# 状态
var _slot_index: int = -1
var _is_empty: bool = true
var _mode: String = "new_game"  # "new_game" 或 "load"

# 边框样式缓存
var _style_normal: StyleBoxFlat = null
var _style_hover: StyleBoxFlat = null

# 边框颜色常量
const BORDER_EMPTY := Color("#666666")
const BORDER_ACTIVE := Color("#444444")
const BORDER_CORRUPTED := Color("#FF4444")
const BORDER_HOVER := Color("#4CAF50")
const BG_COLOR := Color("#222222")

# 统一字体
var _font: Font = preload("res://assets/font/Bake Soda.otf")

func _ready() -> void:
	# 连接鼠标悬停信号
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	delete_button.pressed.connect(_on_delete_pressed)
	# 启用鼠标点击
	gui_input.connect(_on_gui_input)

## 设置卡片数据
func setup(slot_index: int, data: Dictionary, card_mode: String = "new_game") -> void:
	_slot_index = slot_index
	_mode = card_mode

	# 设置槽位标签
	slot_label.text = "存档 %d" % (slot_index + 1)

	var is_corrupted := SaveManager.is_slot_corrupted(slot_index)
	_is_empty = data.is_empty() and not is_corrupted

	if is_corrupted:
		_setup_corrupted_state()
	elif data.is_empty():
		_setup_empty_state()
	else:
		_setup_active_state(data)

	# 创建边框样式
	_build_styles(is_corrupted)
	add_theme_stylebox_override("panel", _style_normal)

## 空槽位状态：虚线边框 + "空" 标签
func _setup_empty_state() -> void:
	status_label.text = "空"
	status_label.visible = true
	empty_label.visible = true
	info_container.visible = false
	warning_icon.visible = false
	delete_button.visible = false

## 进行中状态：实线边框 + 完整信息
func _setup_active_state(data: Dictionary) -> void:
	status_label.text = "进行中"
	status_label.visible = true
	empty_label.visible = false
	info_container.visible = true
	warning_icon.visible = false
	# load 模式不显示删除按钮，new_game 模式显示
	delete_button.visible = (_mode == "new_game")

	# 队长头像
	var leader_id: String = data.get("leader_id", "")
	if leader_id != "":
		var portrait_path := "res://assets/portrait/%s.png" % leader_id
		if ResourceLoader.exists(portrait_path):
			leader_icon.texture = load(portrait_path)

	# 层数/波次
	var floor_num: int = int(data.get("current_floor", 1))
	var wave_num: int = int(data.get("current_wave", 1))
	floor_wave_label.text = "第%d层 - 波次%d" % [floor_num, wave_num]

	# 羁绊图标（暂用文本标签）
	_clear_children(bond_container)
	var bonds: Array = data.get("bond_summary", [])
	var bond_count := mini(bonds.size(), 3)
	for i in range(bond_count):
		var bond_label := Label.new()
		bond_label.text = str(bonds[i])
		bond_label.add_theme_font_size_override("font_size", 12)
		bond_label.add_theme_color_override("font_color", Color("#AAAAAA"))
		bond_label.add_theme_font_override("font", _font)
		bond_container.add_child(bond_label)

	# 游戏时长
	var play_seconds: int = int(data.get("play_time_seconds", 0))
	play_time_label.text = SaveManager.format_play_time(play_seconds)

	# 最后游玩时间
	var timestamp: int = int(data.get("last_played_timestamp", 0))
	last_played_label.text = SaveManager.format_last_played(timestamp)

## 损坏状态：红色边框 + 警告图标
func _setup_corrupted_state() -> void:
	status_label.text = "存档损坏"
	status_label.add_theme_color_override("font_color", BORDER_CORRUPTED)
	status_label.visible = true
	empty_label.visible = false
	info_container.visible = false
	warning_icon.visible = true
	delete_button.visible = true

## 构建边框样式
func _build_styles(is_corrupted: bool) -> void:
	_style_normal = StyleBoxFlat.new()
	_style_normal.bg_color = BG_COLOR
	_style_normal.corner_radius_top_left = 8
	_style_normal.corner_radius_top_right = 8
	_style_normal.corner_radius_bottom_right = 8
	_style_normal.corner_radius_bottom_left = 8
	_style_normal.border_width_left = 2
	_style_normal.border_width_top = 2
	_style_normal.border_width_right = 2
	_style_normal.border_width_bottom = 2

	if is_corrupted:
		_style_normal.border_color = BORDER_CORRUPTED
	elif _is_empty:
		_style_normal.border_color = BORDER_EMPTY
		# 虚线效果：使用较低透明度模拟
		_style_normal.border_color.a = 0.5
	else:
		_style_normal.border_color = BORDER_ACTIVE

	# 悬停样式
	_style_hover = _style_normal.duplicate()
	_style_hover.border_color = BORDER_HOVER

## 鼠标进入 - 边框变绿
func _on_mouse_entered() -> void:
	add_theme_stylebox_override("panel", _style_hover)

## 鼠标离开 - 恢复原边框
func _on_mouse_exited() -> void:
	add_theme_stylebox_override("panel", _style_normal)

## 卡片点击
func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		clicked.emit(_slot_index)

## 删除按钮点击
func _on_delete_pressed() -> void:
	delete_requested.emit(_slot_index)

## 清除容器子节点
func _clear_children(container: Node) -> void:
	for child in container.get_children():
		child.queue_free()
