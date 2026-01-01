extends Camera2D
class_name Camera

var shake_strength: float = 0.0
var shake_decay: float = 5.0 
var rng = RandomNumberGenerator.new()

func _ready() -> void:
	Global.on_camera_shake.connect(apply_shake)
	Global.on_directional_shake.connect(apply_directional_shake)
	rng.randomize()
	
	# 【修改】设置缩放，数值越小，视野越大 (Godot 4.x)
	# 0.6 表示缩小画面，也就是拉高摄像机，能看到更多地图
	zoom = Vector2(0.8, 0.8) 
	
func apply_shake(intensity: float, duration: float = 0.2) -> void:
	shake_strength = max(shake_strength, intensity)

# 指向性震动：根据攻击方向产生定向震动
func apply_directional_shake(direction: Vector2, strength: float) -> void:
	shake_strength = max(shake_strength, strength)
	# 在攻击方向上产生更强的震动
	offset = direction.normalized() * strength * 0.5
	
func _process(delta: float) -> void:
	if is_instance_valid(Global.player):
		global_position = Global.player.position
		
	if shake_strength > 0:
		shake_strength = lerp(shake_strength, 0.0, shake_decay * delta)
		offset = Vector2(
			rng.randf_range(-shake_strength, shake_strength),
			rng.randf_range(-shake_strength, shake_strength)
		)
		if shake_strength < 1.0:
			shake_strength = 0
			offset = Vector2.ZERO
