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
	print("[GameOverScreen] 返回角色选择界面")
	SoundManager.play("ui_click")
	
	# 恢复游戏状态
	get_tree().paused = false
	Global.game_paused = false
	
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
	"""将当前 Global 的角色/武器数据写入 SelectionPanel 的缓存文件"""
	# 写入 player_selection_cache.json
	var selection_cache: Array = []
	for i in range(Global.selected_player_ids.size()):
		var pid: String = Global.selected_player_ids[i]
		var wtype: String = Global.selected_player_weapons.get(pid, "")
		selection_cache.append({
			"player_id": pid,
			"weapon_type": wtype,
			"slot_index": i
		})
	
	var sel_file := FileAccess.open("user://player_selection_cache.json", FileAccess.WRITE)
	if sel_file:
		sel_file.store_string(JSON.stringify(selection_cache))
		sel_file.close()
		print("[GameOverScreen] 已同步角色选择缓存: %s" % str(selection_cache))
	
	# 写入 player_weapon_cache.json
	var weapon_cache: Dictionary = {}
	for pid in Global.selected_player_ids:
		var wtype: String = Global.selected_player_weapons.get(pid, "")
		if wtype != "":
			weapon_cache[pid] = wtype
	
	var wpn_file := FileAccess.open("user://player_weapon_cache.json", FileAccess.WRITE)
	if wpn_file:
		wpn_file.store_string(JSON.stringify(weapon_cache))
		wpn_file.close()
		print("[GameOverScreen] 已同步武器选择缓存: %s" % str(weapon_cache))
