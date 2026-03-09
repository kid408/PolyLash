extends SkillDrawingBase
class_name SkillNewTotemQ

var totem_damage: int = 24
var totem_duration: float = 10.0
var chain_damage: int = 18
var quake_damage: int = 40
var slow_value: float = 0.52
var quake_duration: float = 4.5
var overload_damage_amp: float = 0.24

func _spawn_line_effect(start: Vector2, end: Vector2) -> void:
	SkillEffectManager.create_summon({
		"position": start,
		"summon_type": "turret",
		"duration": totem_duration,
		"damage": totem_damage,
		"attack_interval": 1.3,
		"attack_range": 220.0,
		"max_count": 6,
		"owner_skill_id": "skill_new_totem_q",
		"color": Color(0.6, 0.3, 0.8)
	})
	SkillEffectManager.create_summon({
		"position": end,
		"summon_type": "turret",
		"duration": totem_duration,
		"damage": totem_damage,
		"attack_interval": 1.3,
		"attack_range": 220.0,
		"max_count": 6,
		"owner_skill_id": "skill_new_totem_q",
		"color": Color(0.6, 0.3, 0.8)
	})
	SkillEffectManager.create_line_effect({
		"start": start,
		"end": end,
		"width": 10.0,
		"damage": chain_damage,
		"damage_interval": 0.4,
		"duration": _get_line_duration(),
		"color": Color(0.7, 0.4, 1.0, 0.65)
	})

func _spawn_area_effect(polygon: PackedVector2Array) -> void:
	SkillEffectManager.create_area_effect({
		"polygon": polygon,
		"damage": quake_damage,
		"damage_interval": 0.45,
		"duration": quake_duration,
		"color": Color(0.5, 0.2, 0.7, 0.45)
	})
	SkillEffectManager.create_debuff_zone({
		"polygon": polygon,
		"duration": quake_duration,
		"debuff_type": "slow",
		"debuff_value": slow_value,
		"debuff_duration": 1.8,
		"tick_interval": 0.45,
		"color": Color(0.4, 0.2, 0.6, 0.3)
	})
	SkillEffectManager.create_debuff_zone({
		"polygon": polygon,
		"duration": quake_duration,
		"debuff_type": "damage_amp",
		"debuff_value": overload_damage_amp,
		"debuff_duration": quake_duration,
		"tick_interval": 0.75,
		"color": Color(0.6, 0.3, 0.9, 0.2)
	})

func _get_line_color() -> Color:
	return Color(0.6, 0.3, 0.8, 1.0)

func _get_closure_color() -> Color:
	return Color(0.5, 0.2, 0.7, 1.0)
