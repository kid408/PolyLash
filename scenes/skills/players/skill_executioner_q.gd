extends SkillDrawingBase
class_name SkillExecutionerQ

var damage_amp_value: float = 0.45
var damage_amp_duration: float = 4.5
var guillotine_damage: int = 120
var guillotine_duration: float = 1.2
var line_bleed_damage: int = 16
var line_tick_interval: float = 0.45
var execute_fear_duration: float = 0.8

func _spawn_line_effect(start: Vector2, end: Vector2) -> void:
	SkillEffectManager.create_debuff_zone({
		"start": start,
		"end": end,
		"width": 24.0,
		"duration": _get_line_duration(),
		"debuff_type": "damage_amp",
		"debuff_value": damage_amp_value,
		"debuff_duration": damage_amp_duration,
		"tick_interval": line_tick_interval,
		"damage": line_bleed_damage,
		"damage_interval": line_tick_interval,
		"color": Color(0.62, 0.08, 0.08, 0.56)
	})

func _spawn_area_effect(polygon: PackedVector2Array) -> void:
	SkillEffectManager.create_area_effect({
		"polygon": polygon,
		"damage": guillotine_damage,
		"damage_interval": 0.3,
		"duration": guillotine_duration,
		"color": Color(0.7, 0.1, 0.1, 0.62)
	})

	SkillEffectManager.create_debuff_zone({
		"polygon": polygon,
		"duration": guillotine_duration,
		"debuff_type": "fear",
		"debuff_value": 1.0,
		"debuff_duration": execute_fear_duration,
		"tick_interval": 0.65,
		"color": Color(0.55, 0.08, 0.08, 0.28)
	})

func _get_line_color() -> Color:
	return Color(0.62, 0.08, 0.08, 1.0)

func _get_closure_color() -> Color:
	return Color(0.5, 0.05, 0.05, 1.0)
