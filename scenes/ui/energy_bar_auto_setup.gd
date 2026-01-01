extends Node
# 自动创建能量槽UI的辅助脚本
# 使用方法：将此脚本添加到任何节点，运行一次后删除

func _ready() -> void:
	print("=== 开始自动创建能量槽UI ===")
	create_energy_bar()

func create_energy_bar() -> void:
	# 检查玩家是否存在
	if not is_instance_valid(Global.player):
		print("[错误] 找不到玩家节点")
		return
	
	# 检查玩家是否已经有能量槽
	var existing_energy_bar = Global.player.get_node_or_null("EnergyBar")
	if existing_energy_bar:
		print("[警告] 玩家已经有能量槽了")
		return
	
	# 创建能量槽UI
	var energy_bar = Control.new()
	energy_bar.name = "EnergyBar"
	energy_bar.set_script(load("res://scenes/ui/energy_bar.gd"))
	
	# 设置位置（在血条下方）
	energy_bar.position = Vector2(20, 80)  # 根据实际情况调整
	energy_bar.size = Vector2(200, 30)
	
	# 创建ProgressBar
	var progress_bar = ProgressBar.new()
	progress_bar.name = "ProgressBar"
	progress_bar.size = Vector2(200, 30)
	progress_bar.max_value = 1.0
	progress_bar.value = 1.0
	progress_bar.show_percentage = false
	energy_bar.add_child(progress_bar)
	
	# 创建Label
	var label = Label.new()
	label.name = "EnergyAmount"
	label.position = Vector2(10, 5)
	label.text = "100"
	energy_bar.add_child(label)
	
	# 添加到玩家节点
	Global.player.add_child(energy_bar)
	
	# 连接信号
	if Global.player.has_signal("energy_changed"):
		Global.player.energy_changed.connect(energy_bar._on_player_energy_changed)
		print("[成功] 能量槽已创建并连接信号")
	else:
		print("[错误] 玩家没有energy_changed信号")
	
	# 设置颜色
	energy_bar.back_color = Color(0.2, 0.2, 0.3)
	energy_bar.fill_color = Color(0.3, 0.8, 1.0)
	
	# 调用_ready初始化颜色
	if energy_bar.has_method("_ready"):
		energy_bar._ready()
	
	print("=== 能量槽创建完成 ===")
	print("位置: ", energy_bar.position)
	print("大小: ", energy_bar.size)
	
	# 自动删除此脚本节点
	await get_tree().create_timer(1.0).timeout
	queue_free()
