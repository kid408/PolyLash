extends Node2D
class_name FloatingText

@onready var value_label: Label = $ValueLabel

var _active_tween: Tween = null
var _release_callback: Callable = Callable()

func _ready() -> void:
	reset_for_pool()

func setup(value: String, color: Color, options: Dictionary = {}, release_callback: Callable = Callable()) -> void:
	_release_callback = release_callback
	if is_instance_valid(_active_tween):
		_active_tween.kill()
	_active_tween = null

	var scale_mult: float = max(0.6, float(options.get("scale_mult", 1.0)))
	var intro_duration: float = max(0.05, float(options.get("intro_duration", 0.14)))
	var hold_duration: float = max(0.0, float(options.get("hold_duration", 0.30)))
	var fade_duration: float = max(0.05, float(options.get("fade_duration", 0.40)))
	var rise_distance: float = max(18.0, float(options.get("rise_distance", 48.0)))
	var spread_x: float = max(0.0, float(options.get("spread_x", 48.0)))

	value_label.text = value
	modulate = Color(color.r, color.g, color.b, 1.0)
	visible = true
	rotation = deg_to_rad(randf_range(-6.0, 6.0))

	var start_pos: Vector2 = global_position
	var horizontal_offset: float = randf_range(-spread_x, spread_x)
	var peak_scale: float = scale_mult * randf_range(0.96, 1.10)
	var settle_scale: float = peak_scale * 0.86

	scale = Vector2.ONE * (0.55 * scale_mult)
	modulate.a = 0.0

	var mid_pos := start_pos + Vector2(horizontal_offset * 0.55, -rise_distance * 0.52)
	var end_pos := start_pos + Vector2(horizontal_offset, -rise_distance)

	_active_tween = create_tween()
	_active_tween.set_parallel(true)
	_active_tween.tween_property(self, "global_position", mid_pos, intro_duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_active_tween.tween_property(self, "scale", Vector2.ONE * peak_scale, intro_duration).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_active_tween.tween_property(self, "modulate:a", 1.0, intro_duration * 0.9)

	_active_tween.chain().tween_interval(hold_duration)
	_active_tween.set_parallel(true)
	_active_tween.tween_property(self, "global_position", end_pos, fade_duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_active_tween.tween_property(self, "scale", Vector2.ONE * settle_scale, fade_duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	_active_tween.tween_property(self, "modulate:a", 0.0, fade_duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	_active_tween.chain().tween_callback(_finish_playback)

func reset_for_pool() -> void:
	if is_instance_valid(_active_tween):
		_active_tween.kill()
	_active_tween = null
	_release_callback = Callable()
	hide()
	rotation = 0.0
	scale = Vector2.ONE
	modulate = Color(1.0, 1.0, 1.0, 1.0)
	if is_instance_valid(value_label):
		value_label.text = ""

func _finish_playback() -> void:
	var callback := _release_callback
	reset_for_pool()
	if callback.is_valid():
		callback.call()
	else:
		queue_free()
