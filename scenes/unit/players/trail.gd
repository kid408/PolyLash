extends Line2D
class_name Trail

@export var player: Player
# 【修改】把 25 改成 500！
# 500帧 ≈ 8秒钟，足够你冲完整个连招，线条都不会断
@export var trail_length := 500 
@export var trail_duration := 1.0

@onready var trail_timer: Timer = %TrailTimer

var points_array: Array[Vector2] = []
var is_active := false
var width_multiplier:float

func _process(delta: float) -> void:
	if not is_active:
		return
	
	# 记录位置
	points_array.append(player.global_position)
	
	# 只有当由于时间过长导致点数过多时，才移除旧点
	if points_array.size() > trail_length:
		points_array.pop_front()
	
	points = points_array

func start_trail() -> void:
	is_active = true
	width_multiplier = 1.0 # 重置宽度（为了配合下面的停止动画）
	clear_points()         # 立刻清除旧的
	points_array.clear()
	# trail_timer.start(trail_duration) # 这行可以不要，由 Player 手动控制 stop

# 【核心修改】优雅停止
func stop() -> void:
	is_active = false
	trail_timer.stop() 
	
	# 修改点：把原来的 0.5 改成 0.1 (极速) 或者 0.05 (近乎瞬间)
	var tween = create_tween()
	tween.tween_property(self, "width_multiplier", 0.0, 0.1) 
	
	tween.tween_callback(func():
		clear_points()
		points_array.clear()
		width_multiplier = 1.0 
	)

func _on_trail_timer_timeout() -> void:
	# 如果你保留 timer，这里的逻辑也要改
	stop()
