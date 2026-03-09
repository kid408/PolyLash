extends SkillDrawingBase
class_name SkillJailerQ

var wall_contact_damage: int = 22
var wall_width: float = 16.0
var wall_duration: float = 6.5
var prison_slow_value: float = 0.58
var prison_fear_duration: float = 0.6

func _spawn_line_effect(start: Vector2, end: Vector2) -> void:
	SkillEffectManager.create_wall_effect({
		"start": start,
		"end": end,
		"width": wall_width,
		"duration": _get_line_duration(),
		"block_enemies": true,
		"block_bullets": false,
		"contact_damage": wall_contact_damage,
		"contact_interval": 0.42,
		"color": Color(0.92, 0.8, 0.2, 0.75)
	})

func _spawn_area_effect(polygon: PackedVector2Array) -> void:
	var point_count := polygon.size()
	if point_count < 3:
		return

	for i in range(point_count):
		var p0 := polygon[i]
		var p1 := polygon[(i + 1) % point_count]
		SkillEffectManager.create_wall_effect({
			"start": p0,
			"end": p1,
			"width": wall_width,
			"duration": wall_duration,
			"block_enemies": true,
			"block_bullets": false,
			"contact_damage": wall_contact_damage,
			"contact_interval": 0.42,
			"color": Color(0.92, 0.8, 0.2, 0.72)
		})

	SkillEffectManager.create_debuff_zone({
		"polygon": polygon,
		"duration": wall_duration,
		"debuff_type": "slow",
		"debuff_value": prison_slow_value,
		"debuff_duration": 1.8,
		"tick_interval": 0.45,
		"color": Color(0.88, 0.75, 0.16, 0.22)
	})

	SkillEffectManager.create_debuff_zone({
		"polygon": polygon,
		"duration": wall_duration,
		"debuff_type": "fear",
		"debuff_value": 1.0,
		"debuff_duration": prison_fear_duration,
		"tick_interval": 1.2,
		"color": Color(0.82, 0.65, 0.12, 0.18)
	})

func _get_line_color() -> Color:
	return Color(0.92, 0.8, 0.2, 1.0)

func _get_closure_color() -> Color:
	return Color(0.9, 0.8, 0.2, 1.0)
