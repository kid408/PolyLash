extends SkillDrawingBase
class_name SkillNewTempestQ

var speed_boost_value: float = 0.55
var buff_duration: float = 4.0
var pull_damage: int = 24
var pull_force: float = 360.0
var area_duration: float = 5.5
var wind_cut_damage: int = 14
var storm_slow_value: float = 0.35

func _spawn_line_effect(start: Vector2, end: Vector2) -> void:
	SkillEffectManager.create_buff_zone({
		"start": start,
		"end": end,
		"width": 48.0,
		"duration": _get_line_duration(),
		"buff_type": "speed_boost",
		"buff_value": speed_boost_value,
		"tick_interval": 0.45,
		"color": Color(0.3, 0.9, 0.8, 0.5)
	})

	SkillEffectManager.create_debuff_zone({
		"start": start,
		"end": end,
		"width": 20.0,
		"duration": _get_line_duration(),
		"debuff_type": "slow",
		"debuff_value": storm_slow_value,
		"debuff_duration": 1.6,
		"tick_interval": 0.45,
		"damage": wind_cut_damage,
		"damage_interval": 0.45,
		"color": Color(0.26, 0.82, 0.76, 0.25)
	})

func _spawn_area_effect(polygon: PackedVector2Array) -> void:
	SkillEffectManager.create_area_effect({
		"polygon": polygon,
		"damage": pull_damage,
		"damage_interval": 0.4,
		"duration": area_duration,
		"color": Color(0.2, 0.8, 0.7, 0.5),
		"pull_to_center": true,
		"pull_force": pull_force
	})

	SkillEffectManager.create_debuff_zone({
		"polygon": polygon,
		"duration": area_duration,
		"debuff_type": "slow",
		"debuff_value": min(0.7, storm_slow_value + 0.2),
		"debuff_duration": 1.5,
		"tick_interval": 0.4,
		"color": Color(0.18, 0.65, 0.62, 0.2)
	})

func _get_line_color() -> Color:
	return Color(0.3, 0.9, 0.8, 1.0)

func _get_closure_color() -> Color:
	return Color(0.2, 0.8, 0.7, 1.0)
