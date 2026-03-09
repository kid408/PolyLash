extends SkillDrawingBase
class_name SkillBannerQ

var line_speed_boost: float = 0.28
var defense_reduction: float = 0.35
var debuff_duration: float = 5.0
var fear_duration: float = 0.9

func _spawn_line_effect(start: Vector2, end: Vector2) -> void:
	SkillEffectManager.create_buff_zone({
		"start": start,
		"end": end,
		"width": 24.0,
		"duration": _get_line_duration(),
		"buff_type": "ignore_collision",
		"buff_value": 1.0,
		"tick_interval": 0.5,
		"color": Color(0.9, 0.2, 0.2, 0.5)
	})
	SkillEffectManager.create_buff_zone({
		"start": start,
		"end": end,
		"width": 24.0,
		"duration": _get_line_duration(),
		"buff_type": "speed_boost",
		"buff_value": line_speed_boost,
		"tick_interval": 0.5,
		"color": Color(1.0, 0.35, 0.25, 0.3)
	})

func _spawn_area_effect(polygon: PackedVector2Array) -> void:
	SkillEffectManager.create_debuff_zone({
		"polygon": polygon,
		"duration": debuff_duration,
		"debuff_type": "damage_amp",
		"debuff_value": defense_reduction,
		"debuff_duration": debuff_duration,
		"tick_interval": 1.0,
		"color": Color(0.8, 0.1, 0.1, 0.4)
	})
	SkillEffectManager.create_debuff_zone({
		"polygon": polygon,
		"duration": debuff_duration,
		"debuff_type": "fear",
		"debuff_value": 1.0,
		"debuff_duration": fear_duration,
		"tick_interval": 1.2,
		"color": Color(0.9, 0.25, 0.2, 0.25)
	})

func _get_line_color() -> Color:
	return Color(0.9, 0.2, 0.2, 1.0)

func _get_closure_color() -> Color:
	return Color(0.8, 0.1, 0.1, 1.0)
