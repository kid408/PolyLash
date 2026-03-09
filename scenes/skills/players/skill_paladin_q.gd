extends SkillDrawingBase
class_name SkillPaladinQ

var wall_width: float = 16.0
var wall_duration: float = 6.0
var heal_value: int = 3
var buff_duration: float = 5.0
var sanctuary_attack_boost: float = 0.3
var sanctuary_damage_amp: float = 0.2
var reflect_contact_damage: int = 10

func _spawn_line_effect(start: Vector2, end: Vector2) -> void:
	var duration: float = max(wall_duration, _get_line_duration())
	SkillEffectManager.create_wall_effect({
		"start": start,
		"end": end,
		"width": wall_width,
		"duration": duration,
		"block_enemies": false,
		"block_bullets": true,
		"reflect_bullets": true,
		"contact_damage": reflect_contact_damage,
		"contact_interval": 0.6,
		"color": Color(1.0, 0.85, 0.3, 0.75)
	})

func _spawn_area_effect(polygon: PackedVector2Array) -> void:
	SkillEffectManager.create_buff_zone({
		"polygon": polygon,
		"duration": buff_duration,
		"buff_type": "heal",
		"buff_value": float(heal_value),
		"tick_interval": 0.45,
		"color": Color(1.0, 0.92, 0.5, 0.45)
	})

	SkillEffectManager.create_buff_zone({
		"polygon": polygon,
		"duration": buff_duration,
		"buff_type": "attack_boost",
		"buff_value": sanctuary_attack_boost,
		"tick_interval": 0.5,
		"color": Color(1.0, 0.88, 0.35, 0.32)
	})

	SkillEffectManager.create_debuff_zone({
		"polygon": polygon,
		"duration": buff_duration,
		"debuff_type": "damage_amp",
		"debuff_value": sanctuary_damage_amp,
		"debuff_duration": buff_duration,
		"tick_interval": 0.8,
		"color": Color(0.95, 0.75, 0.25, 0.25)
	})

func _get_line_color() -> Color:
	return Color(1.0, 0.85, 0.3, 1.0)

func _get_closure_color() -> Color:
	return Color(1.0, 0.9, 0.4, 1.0)
