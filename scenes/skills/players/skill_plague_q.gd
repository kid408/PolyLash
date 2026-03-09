extends SkillDrawingBase
class_name SkillPlagueQ

var slow_value: float = 0.55
var poison_damage: int = 10
var poison_duration: float = 5.5
var damage_amp_value: float = 0.35
var debuff_zone_duration: float = 6.5
var miasma_damage: int = 18
var curse_value: float = 8.0

func _spawn_line_effect(start: Vector2, end: Vector2) -> void:
	SkillEffectManager.create_debuff_zone({
		"start": start,
		"end": end,
		"width": 24.0,
		"duration": _get_line_duration(),
		"debuff_type": "slow",
		"debuff_value": slow_value,
		"debuff_duration": poison_duration,
		"tick_interval": 0.55,
		"color": Color(0.4, 0.7, 0.1, 0.5)
	})
	SkillEffectManager.create_debuff_zone({
		"start": start,
		"end": end,
		"width": 24.0,
		"duration": _get_line_duration(),
		"debuff_type": "poison",
		"debuff_value": poison_damage,
		"debuff_duration": poison_duration,
		"tick_interval": 0.55,
		"color": Color(0.3, 0.5, 0.0, 0.3)
	})

func _spawn_area_effect(polygon: PackedVector2Array) -> void:
	SkillEffectManager.create_debuff_zone({
		"polygon": polygon,
		"duration": debuff_zone_duration,
		"debuff_type": "damage_amp",
		"debuff_value": damage_amp_value,
		"debuff_duration": debuff_zone_duration,
		"tick_interval": 0.65,
		"color": Color(0.4, 0.7, 0.1, 0.4)
	})

	SkillEffectManager.create_area_effect({
		"polygon": polygon,
		"damage": miasma_damage,
		"damage_interval": 0.65,
		"duration": debuff_zone_duration,
		"color": Color(0.28, 0.5, 0.05, 0.22)
	})

	SkillEffectManager.create_debuff_zone({
		"polygon": polygon,
		"duration": debuff_zone_duration,
		"debuff_type": "curse",
		"debuff_value": curse_value,
		"debuff_duration": 2.5,
		"tick_interval": 1.0,
		"color": Color(0.26, 0.42, 0.05, 0.22)
	})

func _get_line_color() -> Color:
	return Color(0.4, 0.7, 0.1, 1.0)

func _get_closure_color() -> Color:
	return Color(0.3, 0.5, 0.0, 1.0)
