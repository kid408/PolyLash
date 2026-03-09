extends SkillDrawingBase
class_name SkillNewPyroQ

var wall_contact_damage: int = 15
var fire_sea_damage: int = 40
var fire_sea_duration: float = 5.0
var scorch_damage_amp: float = 0.25
var burn_dot_value: float = 10.0
var burn_tick_interval: float = 0.5
var flame_wall_width: float = 18.0

func _spawn_line_effect(start: Vector2, end: Vector2) -> void:
	SkillEffectManager.create_wall_effect({
		"start": start,
		"end": end,
		"width": flame_wall_width,
		"duration": _get_line_duration(),
		"block_enemies": true,
		"block_bullets": false,
		"contact_damage": wall_contact_damage,
		"contact_interval": 0.4,
		"color": Color(1.0, 0.42, 0.1, 0.85)
	})

	SkillEffectManager.create_debuff_zone({
		"start": start,
		"end": end,
		"width": 20.0,
		"duration": _get_line_duration(),
		"debuff_type": "damage_amp",
		"debuff_value": scorch_damage_amp,
		"debuff_duration": 2.0,
		"tick_interval": 0.4,
		"color": Color(1.0, 0.5, 0.18, 0.32)
	})

func _spawn_area_effect(polygon: PackedVector2Array) -> void:
	SkillEffectManager.create_area_effect({
		"polygon": polygon,
		"damage": fire_sea_damage,
		"damage_interval": 0.35,
		"duration": fire_sea_duration,
		"color": Color(1.0, 0.32, 0.0, 0.5)
	})

	SkillEffectManager.create_debuff_zone({
		"polygon": polygon,
		"duration": fire_sea_duration,
		"debuff_type": "poison",
		"debuff_value": burn_dot_value,
		"debuff_duration": 2.5,
		"tick_interval": burn_tick_interval,
		"color": Color(1.0, 0.45, 0.0, 0.26)
	})

func _get_line_color() -> Color:
	return Color(1.0, 0.42, 0.1, 1.0)

func _get_closure_color() -> Color:
	return Color(1.0, 0.3, 0.0, 1.0)
