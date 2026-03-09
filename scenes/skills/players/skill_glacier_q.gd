extends SkillDrawingBase
class_name SkillGlacierQ

var wall_duration: float = 5.0
var wall_width: float = 16.0
var freeze_duration: float = 2.0
var frost_contact_damage: int = 12
var frost_contact_interval: float = 0.45
var blizzard_damage: int = 18
var deep_slow: float = 0.62

func _spawn_line_effect(start: Vector2, end: Vector2) -> void:
	var duration: float = float(max(wall_duration, _get_line_duration()))
	SkillEffectManager.create_wall_effect({
		"start": start,
		"end": end,
		"width": wall_width,
		"duration": duration,
		"block_enemies": true,
		"block_bullets": true,
		"contact_damage": frost_contact_damage,
		"contact_interval": frost_contact_interval,
		"color": Color(0.5, 0.8, 1.0, 0.7)
	})

func _spawn_area_effect(polygon: PackedVector2Array) -> void:
	var zone_duration: float = freeze_duration + 2.0
	SkillEffectManager.create_debuff_zone({
		"polygon": polygon,
		"duration": zone_duration,
		"debuff_type": "freeze",
		"debuff_value": 0.0,
		"debuff_duration": freeze_duration,
		"tick_interval": 1.1,
		"color": Color(0.35, 0.65, 1.0, 0.45)
	})

	SkillEffectManager.create_debuff_zone({
		"polygon": polygon,
		"duration": zone_duration,
		"debuff_type": "slow",
		"debuff_value": deep_slow,
		"debuff_duration": 1.8,
		"tick_interval": 0.35,
		"color": Color(0.45, 0.8, 1.0, 0.25)
	})

	SkillEffectManager.create_area_effect({
		"polygon": polygon,
		"damage": blizzard_damage,
		"damage_interval": 0.6,
		"duration": zone_duration,
		"color": Color(0.28, 0.58, 0.95, 0.18)
	})

func _get_line_color() -> Color:
	return Color(0.5, 0.8, 1.0, 1.0)

func _get_closure_color() -> Color:
	return Color(0.3, 0.6, 1.0, 1.0)
