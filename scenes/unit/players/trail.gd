extends Line2D
class_name Trail

@export var player: PlayerBase
# 【修改】把 25 改成 500！
# 500帧 ≈ 8秒钟，足够你冲完整个连招，线条都不会断
@export var trail_length := 500 
@export var trail_duration := 1.0

@onready var trail_timer: Timer = %TrailTimer

var points_array: Array[Vector2] = []
var is_active := false
var width_multiplier:float

func _process(delta: float) -> void:
	# 【修改 2】增加安全检查：如果没有激活，或者player没赋值，就别跑逻辑
	if not is_active or not is_instance_valid(player):
		return
	
	# 记录位置
	points_array.append(player.global_position)
	
	# 只有当由于时间过长导致点数过多时，才移除旧点
	if points_array.size() > trail_length:
		points_array.pop_front()
	
	points = points_array

func start_trail() -> void:
	# 【修改 3】启动前也检查一下
	if not is_instance_valid(player):
		print("Trail Error: Player 节点未赋值！")
		return

	is_active = true
	width_multiplier = 1.0 # 重置宽度
	clear_points()         # 立刻清除旧的
	points_array.clear()

func stop() -> void:
	is_active = false
	if trail_timer: trail_timer.stop() 
	
	var tween = create_tween()
	tween.tween_property(self, "width_multiplier", 0.0, 0.1) 
	
	tween.tween_callback(func():
		clear_points()
		points_array.clear()
		width_multiplier = 1.0 
	)

func _on_trail_timer_timeout() -> void:
	stop()
