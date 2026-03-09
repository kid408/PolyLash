extends SkillDrawingBase
class_name SkillNecroQ

var wall_health: int = 3
var wall_width: float = 16.0
var corpse_damage: int = 60
var corpse_duration: float = 6.0
var grave_curse_value: float = 8.0
var grave_tick_interval: float = 1.0
var skeleton_count: int = 2
var summon_duration: float = 6.0
var summon_damage_ratio: float = 0.45
var bone_contact_damage: int = 12

func _spawn_line_effect(start: Vector2, end: Vector2) -> void:
	SkillEffectManager.create_wall_effect({
		"start": start,
		"end": end,
		"width": wall_width,
		"duration": _get_line_duration(),
		"health": wall_health,
		"block_enemies": true,
		"block_bullets": false,
		"contact_damage": bone_contact_damage,
		"contact_interval": 0.55,
		"color": Color(0.45, 0.12, 0.52, 0.75)
	})

func _spawn_area_effect(polygon: PackedVector2Array) -> void:
	SkillEffectManager.create_area_effect({
		"polygon": polygon,
		"damage": corpse_damage,
		"damage_interval": 0.75,
		"duration": corpse_duration,
		"color": Color(0.3, 0.02, 0.4, 0.48)
	})

	SkillEffectManager.create_debuff_zone({
		"polygon": polygon,
		"duration": corpse_duration,
		"debuff_type": "curse",
		"debuff_value": grave_curse_value,
		"debuff_duration": 2.5,
		"tick_interval": grave_tick_interval,
		"color": Color(0.35, 0.08, 0.46, 0.28)
	})

	_spawn_skeleton_swarm(_calculate_polygon_center(polygon))

func _spawn_skeleton_swarm(center: Vector2) -> void:
	if skeleton_count <= 0:
		return

	var summon_damage: int = max(8, int(round(float(corpse_damage) * summon_damage_ratio)))
	for i in range(skeleton_count):
		var angle := TAU * float(i) / float(max(skeleton_count, 1))
		var pos := center + Vector2.RIGHT.rotated(angle) * 48.0
		SkillEffectManager.create_summon({
			"position": pos,
			"summon_type": "beetle",
			"duration": max(corpse_duration, summon_duration),
			"damage": summon_damage,
			"attack_interval": 1.1,
			"attack_range": 180.0,
			"max_count": 8,
			"owner_skill_id": "skill_necro_q",
			"color": Color(0.5, 0.2, 0.6, 0.85)
		})

func _get_line_color() -> Color:
	return Color(0.45, 0.12, 0.52, 1.0)

func _get_closure_color() -> Color:
	return Color(0.3, 0.02, 0.4, 1.0)
