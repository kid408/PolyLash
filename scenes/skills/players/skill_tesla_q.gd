extends SkillDrawingBase
class_name SkillTeslaQ

var arc_damage: int = 28
var arc_stun_duration: float = 0.6
var field_damage: int = 36
var field_duration: float = 4.5
var arc_interval: float = 0.4
var field_damage_amp: float = 0.25

func _spawn_line_effect(start: Vector2, end: Vector2) -> void:
	SkillEffectManager.create_debuff_zone({
		"start": start,
		"end": end,
		"width": 22.0,
		"damage": arc_damage,
		"damage_interval": arc_interval,
		"duration": _get_line_duration(),
		"debuff_type": "freeze",
		"debuff_value": 0.0,
		"debuff_duration": arc_stun_duration,
		"tick_interval": arc_interval,
		"color": Color(0.3, 0.72, 1.0, 0.9)
	})

func _spawn_area_effect(polygon: PackedVector2Array) -> void:
	SkillEffectManager.create_area_effect({
		"polygon": polygon,
		"damage": field_damage,
		"damage_interval": 0.4,
		"duration": field_duration,
		"color": Color(0.2, 0.5, 1.0, 0.52)
	})

	SkillEffectManager.create_debuff_zone({
		"polygon": polygon,
		"duration": field_duration,
		"debuff_type": "damage_amp",
		"debuff_value": field_damage_amp,
		"debuff_duration": field_duration,
		"tick_interval": 0.65,
		"color": Color(0.28, 0.6, 1.0, 0.22)
	})

func _get_line_color() -> Color:
	return Color(0.3, 0.7, 1.0, 1.0)

func _get_closure_color() -> Color:
	return Color(0.2, 0.5, 1.0, 1.0)
