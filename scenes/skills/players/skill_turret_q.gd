extends SkillDrawingBase
class_name SkillTurretQ

var turret_damage: int = 24
var turret_count: int = 3
var turret_duration: float = 12.0
var repair_boost: float = 0.65
var repair_duration: float = 6.5
var overclock_turret_damage: int = 34
var overclock_count: int = 1

func _spawn_line_effect(start: Vector2, end: Vector2) -> void:
	for i in range(turret_count):
		var t := float(i) / float(max(turret_count - 1, 1))
		var pos := start.lerp(end, t)
		SkillEffectManager.create_summon({
			"position": pos,
			"summon_type": "turret",
			"duration": turret_duration,
			"damage": turret_damage,
			"attack_interval": 0.95,
			"attack_range": 260.0,
			"max_count": 8,
			"owner_skill_id": "skill_turret_q",
			"color": Color(0.4, 0.5, 0.3)
		})

func _spawn_area_effect(polygon: PackedVector2Array) -> void:
	var center := _calculate_polygon_center(polygon)

	for i in range(overclock_count):
		var angle := TAU * float(i) / float(max(overclock_count, 1))
		var pos := center + Vector2.RIGHT.rotated(angle) * 24.0
		SkillEffectManager.create_summon({
			"position": pos,
			"summon_type": "turret",
			"duration": repair_duration,
			"damage": overclock_turret_damage,
			"attack_interval": 0.7,
			"attack_range": 280.0,
			"max_count": 8,
			"owner_skill_id": "skill_turret_q",
			"color": Color(0.5, 0.62, 0.35)
		})

	SkillEffectManager.create_buff_zone({
		"polygon": polygon,
		"duration": repair_duration,
		"buff_type": "attack_boost",
		"buff_value": repair_boost,
		"tick_interval": 0.5,
		"color": Color(0.3, 0.4, 0.2, 0.4)
	})

	SkillEffectManager.create_buff_zone({
		"polygon": polygon,
		"duration": repair_duration,
		"buff_type": "cooldown_reduction",
		"buff_value": 0.22,
		"tick_interval": 0.5,
		"color": Color(0.35, 0.45, 0.25, 0.22)
	})

func _get_line_color() -> Color:
	return Color(0.4, 0.5, 0.3, 1.0)

func _get_closure_color() -> Color:
	return Color(0.3, 0.4, 0.2, 1.0)
