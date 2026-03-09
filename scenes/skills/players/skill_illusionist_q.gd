extends SkillDrawingBase
class_name SkillIllusionistQ

var wall_width: float = 16.0
var wall_duration: float = 5.5
var phantom_damage: int = 18
var phantom_duration: float = 10.0
var phantom_count: int = 3
var mirror_mark_amp: float = 0.2
var mirror_fear_duration: float = 0.75

func _spawn_line_effect(start: Vector2, end: Vector2) -> void:
	SkillEffectManager.create_wall_effect({
		"start": start,
		"end": end,
		"width": wall_width,
		"duration": max(wall_duration, _get_line_duration()),
		"block_enemies": true,
		"block_bullets": true,
		"reflect_bullets": true,
		"color": Color(0.72, 0.72, 0.92, 0.74)
	})

	SkillEffectManager.create_debuff_zone({
		"start": start,
		"end": end,
		"width": 18.0,
		"duration": _get_line_duration(),
		"debuff_type": "damage_amp",
		"debuff_value": mirror_mark_amp,
		"debuff_duration": 2.2,
		"tick_interval": 0.55,
		"color": Color(0.65, 0.65, 0.9, 0.28)
	})

func _spawn_area_effect(polygon: PackedVector2Array) -> void:
	var center := _calculate_polygon_center(polygon)
	for i in range(phantom_count):
		var angle := TAU * float(i) / float(max(phantom_count, 1))
		var pos := center + Vector2.RIGHT.rotated(angle) * 46.0
		SkillEffectManager.create_summon({
			"position": pos,
			"summon_type": "phantom",
			"duration": phantom_duration,
			"damage": phantom_damage,
			"attack_interval": 0.9,
			"attack_range": 160.0,
			"max_count": phantom_count,
			"owner_skill_id": "skill_illusionist_q",
			"color": Color(0.7, 0.7, 0.9, 0.66)
		})

	SkillEffectManager.create_debuff_zone({
		"polygon": polygon,
		"duration": phantom_duration,
		"debuff_type": "fear",
		"debuff_value": 1.0,
		"debuff_duration": mirror_fear_duration,
		"tick_interval": 1.15,
		"color": Color(0.58, 0.58, 0.85, 0.2)
	})

func _get_line_color() -> Color:
	return Color(0.7, 0.7, 0.9, 1.0)

func _get_closure_color() -> Color:
	return Color(0.6, 0.6, 0.85, 1.0)
