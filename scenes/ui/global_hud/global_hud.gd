extends Control
class_name GlobalHUD

const DEBUG_VERBOSE := false

# UI 节点引用
@onready var vbox_container: VBoxContainer = $VBoxContainer
@onready var resource_container: HBoxContainer = $VBoxContainer/ResourceContainer
@onready var wave_label: Label = $VBoxContainer/WaveContainer/WaveLabel
@onready var wave_time_label: Label = $VBoxContainer/WaveContainer/WaveTimeLabel
@onready var xp_label: Label = $VBoxContainer/ResourceContainer/XPLabel
@onready var gold_label: Label = $VBoxContainer/ResourceContainer/GoldLabel

# 颜色配置
const XP_COLOR: Color = Color(0.7, 0.5, 1.0)  # 紫色
const GOLD_COLOR: Color = Color(1.0, 0.85, 0.0)  # 金黄色
const TIMER_NORMAL_COLOR: Color = Color.WHITE
const TIMER_URGENT_COLOR: Color = Color(1.0, 0.3, 0.3)  # 红色（紧急）
const DANGER_COLOR_LV1: Color = Color(1.00, 0.75, 0.25)
const DANGER_COLOR_LV2: Color = Color(1.00, 0.40, 0.20)
const DANGER_COLOR_LV3: Color = Color(1.00, 0.15, 0.15)

var danger_label: Label = null
var _danger_show_token: int = 0
var level_label: Label = null
var xp_progress: ProgressBar = null

func _ready() -> void:
	# 连接 Global 信号
	Global.on_session_xp_changed.connect(_on_session_xp_changed)
	var progression: Node = get_node_or_null("/root/ProgressionManager")
	if progression and progression.has_signal("progression_changed"):
		var progression_changed_cb: Callable = Callable(self, "_on_progression_changed")
		if not progression.is_connected("progression_changed", progression_changed_cb):
			progression.connect("progression_changed", progression_changed_cb)
	
	# 连接 DataManager 局内金币信号
	if DataManager.has_signal("run_gold_changed"):
		DataManager.run_gold_changed.connect(_on_gold_changed)
		if DEBUG_VERBOSE: print("[GlobalHUD] 已连接 DataManager.run_gold_changed 信号")
	elif DataManager.has_signal("gold_changed"):
		DataManager.gold_changed.connect(_on_gold_changed)
		if DEBUG_VERBOSE: print("[GlobalHUD] 已连接 DataManager.gold_changed 信号(兼容)")
	
	# 设置资源标签颜色
	if xp_label:
		xp_label.add_theme_color_override("font_color", XP_COLOR)
	if gold_label:
		gold_label.add_theme_color_override("font_color", GOLD_COLOR)

	_ensure_progress_widgets()
	
	# 初始化显示
	if progression and progression.has_method("get_current_level"):
		_on_progression_changed(
			int(progression.call("get_current_level")),
			int(progression.call("get_xp_in_level")),
			int(progression.call("get_xp_to_next_level")),
			int(progression.call("get_total_xp"))
		)
	else:
		update_xp(RunStateService.get_run_xp())
	update_gold(RunStateService.get_run_gold())
	_ensure_danger_label()

# 更新波次显示
func update_wave(wave_number: int, wave_time: float) -> void:
	if wave_label:
		wave_label.text = "Wave %d" % wave_number
	if wave_time_label:
		wave_time_label.text = "%d" % int(wave_time)

# 更新波次文本（直接设置）- 添加分隔符格式
func set_wave_text(text: String) -> void:
	if wave_label:
		wave_label.text = text

# 更新波次时间文本（直接设置）- 简化为秒数显示
func set_wave_time_text(text: String) -> void:
	if wave_time_label:
		var seconds = int(text) if text.is_valid_int() else 0
		wave_time_label.text = "| %ds" % seconds
		
		# 紧急状态：时间 < 10 秒时变红
		if seconds < 10 and seconds > 0:
			wave_time_label.add_theme_color_override("font_color", TIMER_URGENT_COLOR)
		else:
			wave_time_label.add_theme_color_override("font_color", TIMER_NORMAL_COLOR)

# 更新 XP 显示
func update_xp(current_xp: int) -> void:
	if xp_label:
		var progression: Node = get_node_or_null("/root/ProgressionManager")
		if progression and progression.has_method("get_xp_in_level"):
			var cur: int = int(progression.call("get_xp_in_level"))
			var need: int = max(1, int(progression.call("get_xp_to_next_level")))
			xp_label.text = "XP: %d/%d" % [cur, need]
		else:
			xp_label.text = "XP: %d" % current_xp

# 更新金币显示
func update_gold(total_gold: int) -> void:
	if gold_label:
		gold_label.text = "Gold: %d" % total_gold

# 信号处理
func _on_session_xp_changed(current: int) -> void:
	update_xp(current)

func _on_gold_changed(new_gold: int) -> void:
	"""金币变化时更新显示"""
	if DEBUG_VERBOSE: print("[GlobalHUD] 收到金币变化信号: new_gold=%d" % new_gold)
	update_gold(new_gold)

func _ensure_progress_widgets() -> void:
	if not resource_container or not vbox_container:
		return

	if level_label == null:
		level_label = Label.new()
		level_label.name = "LevelLabel"
		level_label.text = "LV 1"
		level_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		level_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		level_label.add_theme_font_size_override("font_size", 20)
		level_label.add_theme_color_override("font_color", Color(1.0, 0.95, 0.6))
		resource_container.add_child(level_label)
		resource_container.move_child(level_label, 0)

	if xp_progress == null:
		xp_progress = ProgressBar.new()
		xp_progress.name = "XPProgress"
		xp_progress.custom_minimum_size = Vector2(420, 14)
		xp_progress.show_percentage = false
		xp_progress.max_value = 100.0
		xp_progress.value = 0.0
		vbox_container.add_child(xp_progress)
		vbox_container.move_child(xp_progress, 1)

func _on_progression_changed(level: int, xp_in_level: int, xp_to_next: int, _total_xp: int) -> void:
	if level_label:
		level_label.text = "LV %d" % level

	if xp_progress:
		xp_progress.max_value = float(max(1, xp_to_next))
		xp_progress.value = clamp(float(xp_in_level), 0.0, xp_progress.max_value)

	if xp_label:
		xp_label.text = "XP: %d/%d" % [xp_in_level, max(1, xp_to_next)]

func _ensure_danger_label() -> void:
	if danger_label and is_instance_valid(danger_label):
		return

	danger_label = Label.new()
	danger_label.name = "DangerLabel"
	danger_label.text = ""
	danger_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	danger_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	danger_label.anchor_left = 0.5
	danger_label.anchor_right = 0.5
	danger_label.anchor_top = 0.0
	danger_label.anchor_bottom = 0.0
	danger_label.offset_left = -260.0
	danger_label.offset_right = 260.0
	danger_label.offset_top = 86.0
	danger_label.offset_bottom = 122.0
	danger_label.visible = false
	danger_label.modulate = Color.WHITE
	danger_label.add_theme_font_size_override("font_size", 30)
	add_child(danger_label)

func show_health_danger(level: int, current: float, max_val: float, ratio: float) -> void:
	_ensure_danger_label()

	var hp_text := "%d/%d" % [int(current), int(max_val)]
	var percent := int(ratio * 100.0)
	var hold_time := 1.2

	match level:
		1:
			danger_label.text = "警告: 生命值危险 (%d%%)  %s" % [percent, hp_text]
			danger_label.add_theme_color_override("font_color", DANGER_COLOR_LV1)
			hold_time = 1.4
		2:
			danger_label.text = "危险: 生命值极低 (%d%%)  %s" % [percent, hp_text]
			danger_label.add_theme_color_override("font_color", DANGER_COLOR_LV2)
			hold_time = 1.8
		_:
			danger_label.text = "致命: 立即脱离战斗! (%d%%)  %s" % [percent, hp_text]
			danger_label.add_theme_color_override("font_color", DANGER_COLOR_LV3)
			hold_time = 2.3

	danger_label.visible = true
	danger_label.scale = Vector2.ONE
	var pulse = create_tween()
	pulse.tween_property(danger_label, "scale", Vector2(1.05, 1.05), 0.10)
	pulse.tween_property(danger_label, "scale", Vector2.ONE, 0.12)

	# 使用 token 防止旧的延迟隐藏请求覆盖新的高等级警告
	_danger_show_token += 1
	var token = _danger_show_token
	_hide_danger_later(token, hold_time)

func clear_health_danger() -> void:
	if not danger_label:
		return
	_danger_show_token += 1
	danger_label.visible = false
	danger_label.text = ""

func _hide_danger_later(token: int, hold_time: float) -> void:
	var timer := get_tree().create_timer(hold_time)
	timer.timeout.connect(func() -> void:
		if token != _danger_show_token:
			return
		if danger_label:
			danger_label.visible = false
	)

