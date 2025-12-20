extends Camera2D
class_name Camera

var shake_strength: float = 0.0
var shake_decay: float = 5.0 # 震动衰减速度
var rng = RandomNumberGenerator.new()

func _ready() -> void:
	# 监听全局震动信号
	Global.on_camera_shake.connect(apply_shake)
	rng.randomize()
	
func apply_shake(intensity: float, duration: float = 0.2) -> void:
	# 取最大值，防止弱震动覆盖了强震动
	shake_strength = max(shake_strength, intensity)
	# 如果想做更复杂的 duration 控制，可以在这里加 Timer，但在 process 里衰减通常手感更自然
	
func _process(delta: float) -> void:
	if is_instance_valid(Global.player):
		global_position = Global.player.position
		
	if shake_strength > 0:
		# 随着时间衰减强度
		shake_strength = lerp(shake_strength, 0.0, shake_decay * delta)
		
		# 应用随机偏移
		offset = Vector2(
			rng.randf_range(-shake_strength, shake_strength),
			rng.randf_range(-shake_strength, shake_strength)
		)
		
		# 当强度很低时归零，节省运算
		if shake_strength < 1.0:
			shake_strength = 0
			offset = Vector2.ZERO
