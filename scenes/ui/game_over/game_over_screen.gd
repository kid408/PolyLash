extends CanvasLayer
class_name GameOverScreen

@onready var kills_value: Label = %KillsValue
@onready var gold_value: Label = %GoldValue
@onready var gold_label: Label = $CenterContainer/MainPanel/MarginContainer/VBoxContainer/StatsContainer/GoldLabel
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
		data: 统计数据字典，例如 {"kills": 105, "soul_shard": 120}
	"""
	# 更新击杀数
	if data.has("kills"):
		kills_value.text = str(data["kills"])
	
	# 更新结算奖励（优先显示 soul_shard）
	if data.has("soul_shard"):
		if gold_label:
			gold_label.text = "获得碎片:"
		gold_value.text = str(data["soul_shard"])
	elif data.has("gold"):
		if gold_label:
			gold_label.text = "获得金币:"
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
	# 统一暂停入口
	PauseService.request_pause("game_over_screen", get_tree())
	print("[GameOverScreen] 游戏已暂停")

# 返回按钮点击
func _on_return_button_pressed() -> void:
	print("[GameOverScreen] 返回角色选择界面")
	SoundManager.play("ui_click")

	var current_scene := get_tree().current_scene
	if is_instance_valid(current_scene) and current_scene.has_method("prepare_run_exit_cleanup"):
		current_scene.call("prepare_run_exit_cleanup")
	
	# 恢复游戏状态
	PauseService.release_pause("game_over_screen", get_tree())
	
	# 先同步选角缓存（reset_selection 会清空数据，必须在之前写入）
	_sync_selection_cache_from_global()
	
	# 重置全局状态，但保留 current_save_slot
	var slot := Global.current_save_slot
	Global.reset_selection()
	Global.reset_session_data()
	Global.current_save_slot = slot
	
	# 先处理输入再切换场景
	get_viewport().set_input_as_handled()
	# 返回角色选择界面
	get_tree().change_scene_to_file("res://scenes/ui/selection_panel/selection_panel.tscn")

func _sync_selection_cache_from_global() -> void:
	"""将当前小队写入正式选角缓存。"""
	if not Global.has_method("save_selection_preset"):
		return

	var player_ids: Array[String] = Global.selected_player_ids.duplicate()
	var player_weapons: Dictionary = Global.selected_player_weapons.duplicate(true)
	var leader_id: String = ""
	if not player_ids.is_empty():
		leader_id = player_ids[0]

	Global.save_selection_preset(player_ids, player_weapons, leader_id)
	print("[GameOverScreen] 已同步角色选择缓存: %s" % str(player_ids))
