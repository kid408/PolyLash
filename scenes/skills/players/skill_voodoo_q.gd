extends SkillDrawingBase
class_name SkillVoodooQ

var curse_duration: float = 6.0
var curse_damage: int = 11
var pin_damage: int = 34
var pin_duration: float = 4.5
var hex_fear_duration: float = 0.75
var hex_damage_amp: float = 0.22

func _spawn_line_effect(start: Vector2, end: Vector2) -> void:
	SkillEffectManager.create_debuff_zone({
		"start": start,
		"end": end,
		"width": 24.0,
		"duration": _get_line_duration(),
		"debuff_type": "curse",
		"debuff_value": curse_damage,
		"debuff_duration": curse_duration,
		"tick_interval": 0.8,
		"color": Color(0.5, 0.1, 0.4, 0.62)
	})

	SkillEffectManager.create_debuff_zone({
		"start": start,
		"end": end,
		"width": 18.0,
		"duration": _get_line_duration(),
		"debuff_type": "fear",
		"debuff_value": 1.0,
		"debuff_duration": hex_fear_duration,
		"tick_interval": 1.1,
		"color": Color(0.44, 0.08, 0.35, 0.2)
	})

func _spawn_area_effect(polygon: PackedVector2Array) -> void:
	SkillEffectManager.create_area_effect({
		"polygon": polygon,
		"damage": pin_damage,
		"damage_interval": 0.7,
		"duration": pin_duration,
		"color": Color(0.5, 0.1, 0.4, 0.52)
	})

	SkillEffectManager.create_debuff_zone({
		"polygon": polygon,
		"duration": pin_duration,
		"debuff_type": "curse",
		"debuff_value": curse_damage,
		"debuff_duration": curse_duration,
		"tick_interval": 1.0,
		"color": Color(0.4, 0.05, 0.3, 0.32)
	})

	SkillEffectManager.create_debuff_zone({
		"polygon": polygon,
		"duration": pin_duration,
		"debuff_type": "damage_amp",
		"debuff_value": hex_damage_amp,
		"debuff_duration": pin_duration,
		"tick_interval": 0.85,
		"color": Color(0.46, 0.1, 0.38, 0.2)
	})

func _get_line_color() -> Color:
	return Color(0.5, 0.1, 0.4, 1.0)

func _get_closure_color() -> Color:
	return Color(0.4, 0.05, 0.3, 1.0)
