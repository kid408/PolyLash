extends Camera2D
class_name Camera

var shake_strength: float = 0.0
var shake_decay: float = 5.0
var rng := RandomNumberGenerator.new()

var drag_margin_ratio: Vector2 = Vector2(0.18, 0.18)
var follow_smoothing_speed: float = 7.0
var _follow_initialized: bool = false

func _ready() -> void:
	Global.on_camera_shake.connect(apply_shake)
	Global.on_directional_shake.connect(apply_directional_shake)
	rng.randomize()
	zoom = Vector2(0.8, 0.8)

func apply_shake(intensity: float, duration: float = 0.2) -> void:
	shake_strength = max(shake_strength, intensity)

func apply_directional_shake(direction: Vector2, strength: float) -> void:
	shake_strength = max(shake_strength, strength)
	offset = direction.normalized() * strength * 0.5

func _process(delta: float) -> void:
	if is_instance_valid(Global.player):
		var player_pos: Vector2 = Global.player.global_position
		if not _follow_initialized:
			global_position = player_pos
			_follow_initialized = true
		else:
			var desired_position: Vector2 = _get_deadzone_follow_position(player_pos)
			var follow_weight: float = 1.0 - exp(-follow_smoothing_speed * delta)
			global_position = global_position.lerp(desired_position, clamp(follow_weight, 0.0, 1.0))

	if shake_strength > 0.0:
		shake_strength = lerp(shake_strength, 0.0, shake_decay * delta)
		offset = Vector2(
			rng.randf_range(-shake_strength, shake_strength),
			rng.randf_range(-shake_strength, shake_strength)
		)
		if shake_strength < 1.0:
			shake_strength = 0.0
			offset = Vector2.ZERO

func _get_deadzone_follow_position(target_pos: Vector2) -> Vector2:
	var desired_position: Vector2 = global_position
	var viewport_size: Vector2 = get_viewport_rect().size
	var visible_world_size: Vector2 = viewport_size * zoom
	var deadzone_half_extents: Vector2 = visible_world_size * drag_margin_ratio

	var min_x: float = global_position.x - deadzone_half_extents.x
	var max_x: float = global_position.x + deadzone_half_extents.x
	var min_y: float = global_position.y - deadzone_half_extents.y
	var max_y: float = global_position.y + deadzone_half_extents.y

	if target_pos.x < min_x:
		desired_position.x = target_pos.x + deadzone_half_extents.x
	elif target_pos.x > max_x:
		desired_position.x = target_pos.x - deadzone_half_extents.x

	if target_pos.y < min_y:
		desired_position.y = target_pos.y + deadzone_half_extents.y
	elif target_pos.y > max_y:
		desired_position.y = target_pos.y - deadzone_half_extents.y

	return desired_position
