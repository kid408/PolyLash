extends SkillDrawingBase
class_name SkillSwarmQ

var beetle_damage: int = 32
var beetle_interval: float = 0.8
var beetle_duration: float = 5.5
var turret_damage: int = 18
var turret_count: int = 3
var heal_value: int = 3
var brood_slow_value: float = 0.35
var turret_duration: float = 10.0
var brood_heal_duration: float = 8.0

func _spawn_line_effect(start: Vector2, end: Vector2) -> void:
	var duration: float = _get_line_duration()
	var spawn_count: int = max(1, int(floor(duration / max(0.1, beetle_interval))))

	for i in range(spawn_count):
		var delay: float = beetle_interval * float(i)
		var t: float = float(i) / float(max(spawn_count - 1, 1))
		var pos: Vector2 = start.lerp(end, t)
		get_tree().create_timer(delay).timeout.connect(_spawn_beetle_at.bind(pos))

	SkillEffectManager.create_debuff_zone({
		"start": start,
		"end": end,
		"width": 18.0,
		"duration": duration,
		"debuff_type": "slow",
		"debuff_value": brood_slow_value,
		"debuff_duration": 1.6,
		"tick_interval": 0.5,
		"color": Color(0.45, 0.38, 0.1, 0.24)
	})

func _spawn_area_effect(polygon: PackedVector2Array) -> void:
	var center: Vector2 = _calculate_polygon_center(polygon)
	for i in range(turret_count):
		var angle: float = TAU * float(i) / float(max(turret_count, 1))
		var pos: Vector2 = center + Vector2.RIGHT.rotated(angle) * 55.0
		SkillEffectManager.create_summon({
			"position": pos,
			"summon_type": "turret",
			"duration": turret_duration,
			"damage": turret_damage,
			"attack_interval": 0.9,
			"attack_range": 220.0,
			"max_count": 6,
			"owner_skill_id": "skill_swarm_q",
			"color": Color(0.4, 0.3, 0.0)
		})

	SkillEffectManager.create_buff_zone({
		"polygon": polygon,
		"duration": brood_heal_duration,
		"buff_type": "heal",
		"buff_value": float(heal_value),
		"tick_interval": 0.6,
		"color": Color(0.5, 0.6, 0.2, 0.3)
	})

	SkillEffectManager.create_buff_zone({
		"polygon": polygon,
		"duration": brood_heal_duration,
		"buff_type": "attack_boost",
		"buff_value": 0.2,
		"tick_interval": 0.6,
		"color": Color(0.55, 0.48, 0.16, 0.18)
	})

func _get_line_color() -> Color:
	return Color(0.5, 0.4, 0.1, 1.0)

func _get_closure_color() -> Color:
	return Color(0.4, 0.3, 0.0, 1.0)

func _spawn_beetle_at(pos: Vector2) -> void:
	SkillEffectManager.create_summon({
		"position": pos,
		"summon_type": "beetle",
		"duration": beetle_duration,
		"damage": beetle_damage,
		"attack_interval": 0.45,
		"attack_range": 90.0,
		"max_count": 12,
		"owner_skill_id": "skill_swarm_q",
		"color": Color(0.5, 0.4, 0.1)
	})
