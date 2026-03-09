extends SkillDrawingBase
class_name SkillGooQ

var slow_value: float = 0.88
var slow_duration: float = 4.0
var pool_damage: int = 24
var pool_duration: float = 5.5
var slime_count: int = 3
var goo_poison_value: float = 9.0
var split_radius: float = 52.0

func _spawn_line_effect(start: Vector2, end: Vector2) -> void:
	SkillEffectManager.create_debuff_zone({
		"start": start,
		"end": end,
		"width": 26.0,
		"duration": _get_line_duration(),
		"debuff_type": "slow",
		"debuff_value": slow_value,
		"debuff_duration": slow_duration,
		"tick_interval": 0.45,
		"color": Color(0.3, 0.9, 0.2, 0.5)
	})

	SkillEffectManager.create_debuff_zone({
		"start": start,
		"end": end,
		"width": 20.0,
		"duration": _get_line_duration(),
		"debuff_type": "poison",
		"debuff_value": goo_poison_value,
		"debuff_duration": 2.5,
		"tick_interval": 0.7,
		"color": Color(0.25, 0.72, 0.12, 0.3)
	})

func _spawn_area_effect(polygon: PackedVector2Array) -> void:
	SkillEffectManager.create_area_effect({
		"polygon": polygon,
		"damage": pool_damage,
		"damage_interval": 0.6,
		"duration": pool_duration,
		"color": Color(0.2, 0.8, 0.1, 0.45)
	})

	SkillEffectManager.create_debuff_zone({
		"polygon": polygon,
		"duration": pool_duration,
		"debuff_type": "slow",
		"debuff_value": min(0.95, slow_value + 0.05),
		"debuff_duration": 2.0,
		"tick_interval": 0.4,
		"color": Color(0.2, 0.7, 0.1, 0.25)
	})

	var center := _calculate_polygon_center(polygon)
	for i in range(slime_count):
		var angle := TAU * float(i) / float(max(slime_count, 1))
		var pos := center + Vector2.RIGHT.rotated(angle) * split_radius
		SkillEffectManager.create_summon({
			"position": pos,
			"summon_type": "slime",
			"duration": pool_duration,
			"damage": pool_damage,
			"attack_interval": 1.0,
			"attack_range": 110.0,
			"max_count": 8,
			"owner_skill_id": "skill_goo_q",
			"color": Color(0.3, 0.9, 0.2, 0.85)
		})

func _get_line_color() -> Color:
	return Color(0.3, 0.9, 0.2, 1.0)

func _get_closure_color() -> Color:
	return Color(0.2, 0.8, 0.1, 1.0)
