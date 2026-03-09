extends SkillDrawingBase
class_name SkillMedicQ

var heal_value: int = 5
var slow_value: float = 0.4
var invincible_duration: float = 3.0
var triage_speed_boost: float = 0.18
var field_lifesteal: float = 0.12
var field_heal_multiplier: float = 1.6

func _spawn_line_effect(start: Vector2, end: Vector2) -> void:
	SkillEffectManager.create_buff_zone({
		"start": start,
		"end": end,
		"width": 26.0,
		"duration": _get_line_duration(),
		"buff_type": "heal",
		"buff_value": float(heal_value),
		"tick_interval": 0.35,
		"color": Color(0.35, 1.0, 0.58, 0.45)
	})

	SkillEffectManager.create_buff_zone({
		"start": start,
		"end": end,
		"width": 20.0,
		"duration": _get_line_duration(),
		"buff_type": "speed_boost",
		"buff_value": triage_speed_boost,
		"tick_interval": 0.5,
		"color": Color(0.6, 1.0, 0.8, 0.25)
	})

	SkillEffectManager.create_debuff_zone({
		"start": start,
		"end": end,
		"width": 24.0,
		"duration": _get_line_duration(),
		"debuff_type": "slow",
		"debuff_value": slow_value,
		"debuff_duration": 2.4,
		"tick_interval": 0.45,
		"color": Color(0.4, 0.85, 0.6, 0.25)
	})

func _spawn_area_effect(polygon: PackedVector2Array) -> void:
	var field_duration: float = float(max(invincible_duration, 3.0))
	var field_heal: int = max(1, int(round(float(heal_value) * field_heal_multiplier)))

	SkillEffectManager.create_buff_zone({
		"polygon": polygon,
		"duration": field_duration,
		"buff_type": "heal",
		"buff_value": float(field_heal),
		"tick_interval": 0.35,
		"color": Color(0.35, 1.0, 0.55, 0.42)
	})

	SkillEffectManager.create_buff_zone({
		"polygon": polygon,
		"duration": field_duration,
		"buff_type": "lifesteal",
		"buff_value": field_lifesteal,
		"tick_interval": 0.5,
		"color": Color(0.5, 0.95, 0.75, 0.25)
	})

	SkillEffectManager.create_debuff_zone({
		"polygon": polygon,
		"duration": field_duration,
		"debuff_type": "slow",
		"debuff_value": min(0.85, slow_value + 0.15),
		"debuff_duration": 1.8,
		"tick_interval": 0.4,
		"color": Color(0.25, 0.75, 0.55, 0.22)
	})

func _get_line_color() -> Color:
	return Color(0.35, 1.0, 0.58, 1.0)

func _get_closure_color() -> Color:
	return Color(0.25, 0.9, 0.45, 1.0)
