extends SkillDrawingBase
class_name SkillHunterQ

var slow_value: float = 0.5
var slow_duration: float = 3.0
var freeze_duration: float = 2.0
var trap_duration: float = 8.0
var trap_damage: int = 14
var mark_damage_amp: float = 0.28
var burst_damage: int = 24

func _spawn_line_effect(start: Vector2, end: Vector2) -> void:
	SkillEffectManager.create_debuff_zone({
		"start": start,
		"end": end,
		"width": 24.0,
		"duration": _get_line_duration(),
		"debuff_type": "slow",
		"debuff_value": slow_value,
		"debuff_duration": slow_duration,
		"tick_interval": 0.5,
		"damage": trap_damage,
		"damage_interval": 0.5,
		"color": Color(0.2, 0.5, 0.2, 0.5)
	})

	SkillEffectManager.create_debuff_zone({
		"start": start,
		"end": end,
		"width": 18.0,
		"duration": _get_line_duration(),
		"debuff_type": "freeze",
		"debuff_value": 0.0,
		"debuff_duration": freeze_duration * 0.5,
		"tick_interval": 1.6,
		"color": Color(0.25, 0.6, 0.35, 0.25)
	})

func _spawn_area_effect(polygon: PackedVector2Array) -> void:
	SkillEffectManager.create_debuff_zone({
		"polygon": polygon,
		"duration": trap_duration,
		"debuff_type": "damage_amp",
		"debuff_value": mark_damage_amp,
		"debuff_duration": trap_duration,
		"tick_interval": 0.45,
		"color": Color(0.25, 0.55, 0.25, 0.4)
	})

	SkillEffectManager.create_debuff_zone({
		"polygon": polygon,
		"duration": trap_duration,
		"debuff_type": "freeze",
		"debuff_value": 0.0,
		"debuff_duration": freeze_duration,
		"tick_interval": 1.3,
		"color": Color(0.2, 0.45, 0.22, 0.3)
	})

	SkillEffectManager.create_area_effect({
		"polygon": polygon,
		"damage": burst_damage,
		"damage_interval": 0.7,
		"duration": trap_duration,
		"color": Color(0.2, 0.45, 0.2, 0.18)
	})

func _get_line_color() -> Color:
	return Color(0.2, 0.5, 0.2, 1.0)

func _get_closure_color() -> Color:
	return Color(0.15, 0.4, 0.15, 1.0)
