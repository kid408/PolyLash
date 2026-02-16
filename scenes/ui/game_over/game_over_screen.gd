extends CanvasLayer
class_name GameOverScreen

@onready var kills_value: Label = %KillsValue
@onready var gold_value: Label = %GoldValue
@onready var stats_container: GridContainer = %StatsContainer

func _ready() -> void:
	# 确保初始隐藏
	hide()
	# 设置为不受暂停影响
	process_mode = Node.PROCESS_MODE_ALWAYS

# 设置统计数据
func set_stats(data: Dictionary) -> void:
	"""
	设置结算数据
	参数:
		data: 统计数据字典，例如 {"kills": 105, "gold": 500}
	"""
	# 更新击杀数
	if data.has("kills"):
		kills_value.text = str(data["kills"])
	
	# 更新金币数
	if data.has("gold"):
		gold_value.text = str(data["gold"])
	
	# 未来可以在这里添加更多统计项
	# 例如: 存活时间、造成伤害、最高连击等
	# 只需在 StatsContainer 中动态添加新的 Label 即可

# 动态添加统计项（扩展接口）
func add_stat_row(label_text: String, value_text: String, value_color: Color = Color(1, 0.9, 0.3)) -> void:
	"""
	动态添加一行统计数据
	参数:
		label_text: 左侧标签文本（如 "存活时间:"）
		value_text: 右侧数值文本（如 "5:32"）
		value_color: 数值颜色
	"""
	var label = Label.new()
	label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
	label.add_theme_font_size_override("font_size", 28)
	label.text = label_text
	stats_container.add_child(label)
	
	var value = Label.new()
	value.add_theme_color_override("font_color", value_color)
	value.add_theme_font_size_override("font_size", 28)
	value.text = value_text
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	stats_container.add_child(value)

# 显示结算界面
func show_screen() -> void:
	print("[GameOverScreen] 显示结算界面")
	show()
	# 使用 Godot 的场景树暂停
	get_tree().paused = true
	print("[GameOverScreen] 游戏已暂停")

# 返回按钮点击
func _on_return_button_pressed() -> void:
	print("[GameOverScreen] 返回大厅")
	SoundManager.play("ui_click")
	
	# 恢复游戏状态
	get_tree().paused = false
	Global.game_paused = false
	
	# 重置全局状态
	Global.reset_selection()
	Global.reset_session_data()
	
	# 切换到选择界面
	get_tree().change_scene_to_file("res://scenes/ui/selection_panel/selection_panel.tscn")
