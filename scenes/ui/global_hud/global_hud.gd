extends Control
class_name GlobalHUD

# UI 节点引用
@onready var wave_label: Label = $VBoxContainer/WaveContainer/WaveLabel
@onready var wave_time_label: Label = $VBoxContainer/WaveContainer/WaveTimeLabel
@onready var xp_label: Label = $VBoxContainer/ResourceContainer/XPLabel
@onready var gold_label: Label = $VBoxContainer/ResourceContainer/GoldLabel

# 颜色配置
const XP_COLOR: Color = Color(0.7, 0.5, 1.0)  # 紫色
const GOLD_COLOR: Color = Color(1.0, 0.85, 0.0)  # 金黄色
const TIMER_NORMAL_COLOR: Color = Color.WHITE
const TIMER_URGENT_COLOR: Color = Color(1.0, 0.3, 0.3)  # 红色（紧急）

func _ready() -> void:
	# 连接 Global 信号
	Global.on_session_xp_changed.connect(_on_session_xp_changed)
	
	# 连接 DataManager 信号
	if DataManager.has_signal("gold_changed"):
		DataManager.gold_changed.connect(_on_gold_changed)
		print("[GlobalHUD] 已连接 DataManager.gold_changed 信号")
	
	# 设置资源标签颜色
	if xp_label:
		xp_label.add_theme_color_override("font_color", XP_COLOR)
	if gold_label:
		gold_label.add_theme_color_override("font_color", GOLD_COLOR)
	
	# 初始化显示
	update_xp(Global.session_xp)
	update_gold(DataManager.get_total_gold())

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
	print("[GlobalHUD] 收到金币变化信号: new_gold=%d" % new_gold)
	update_gold(new_gold)
