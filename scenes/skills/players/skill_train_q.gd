extends SkillDrawingBase
class_name SkillTrainQ

var shockwave_delay: float = 0.8
var shockwave_damage: int = 56
var beam_damage: int = 30
var beam_duration: float = 5.5
var aftershock_delay: float = 1.6
var aftershock_damage: int = 42
var rail_width: float = 32.0

func _spawn_line_effect(start: Vector2, end: Vector2) -> void:
	var line_duration: float = _get_line_duration()
	var first_duration: float = max(0.3, line_duration - shockwave_delay)
	var second_duration: float = max(0.3, line_duration - aftershock_delay)
	var p0: Vector2 = start
	var p1: Vector2 = end

	get_tree().create_timer(shockwave_delay).timeout.connect(
		_spawn_primary_shockwave.bind(p0, p1, first_duration)
	)
	get_tree().create_timer(aftershock_delay).timeout.connect(
		_spawn_secondary_shockwave.bind(p0, p1, second_duration)
	)

func _spawn_area_effect(polygon: PackedVector2Array) -> void:
	SkillEffectManager.create_area_effect({
		"polygon": polygon,
		"damage": beam_damage,
		"damage_interval": 0.35,
		"duration": beam_duration,
		"color": Color(0.5, 0.5, 0.6, 0.55)
	})

	SkillEffectManager.create_debuff_zone({
		"polygon": polygon,
		"duration": beam_duration,
		"debuff_type": "fear",
		"debuff_value": 1.0,
		"debuff_duration": 0.55,
		"tick_interval": 1.05,
		"color": Color(0.4, 0.4, 0.5, 0.2)
	})

func _get_line_color() -> Color:
	return Color(0.6, 0.6, 0.7, 1.0)

func _get_closure_color() -> Color:
	return Color(0.5, 0.5, 0.6, 1.0)

func _spawn_primary_shockwave(start: Vector2, end: Vector2, duration: float) -> void:
	SkillEffectManager.create_line_effect({
		"start": start,
		"end": end,
		"width": rail_width,
		"damage": shockwave_damage,
		"damage_interval": 0.4,
		"duration": duration,
		"color": Color(0.65, 0.65, 0.75, 0.85)
	})

func _spawn_secondary_shockwave(start: Vector2, end: Vector2, duration: float) -> void:
	SkillEffectManager.create_line_effect({
		"start": start,
		"end": end,
		"width": rail_width * 0.78,
		"damage": aftershock_damage,
		"damage_interval": 0.35,
		"duration": duration,
		"color": Color(0.78, 0.78, 0.88, 0.72)
	})
