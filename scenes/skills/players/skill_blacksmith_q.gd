extends SkillDrawingBase
class_name SkillBlacksmithQ

var rail_contact_damage: int = 18
var rail_contact_interval: float = 0.35
var rail_width: float = 20.0
var forge_attack_boost: float = 0.45
var forge_lifesteal: float = 0.18
var buff_duration: float = 5.5

func _spawn_line_effect(start: Vector2, end: Vector2) -> void:
	SkillEffectManager.create_wall_effect({
		"start": start,
		"end": end,
		"width": rail_width,
		"duration": _get_line_duration(),
		"block_enemies": true,
		"block_bullets": false,
		"contact_damage": rail_contact_damage,
		"contact_interval": rail_contact_interval,
		"color": Color(0.95, 0.48, 0.08, 0.75)
	})

func _spawn_area_effect(polygon: PackedVector2Array) -> void:
	SkillEffectManager.create_buff_zone({
		"polygon": polygon,
		"duration": buff_duration,
		"buff_type": "attack_boost",
		"buff_value": forge_attack_boost,
		"tick_interval": 0.5,
		"color": Color(1.0, 0.45, 0.08, 0.45)
	})

	SkillEffectManager.create_buff_zone({
		"polygon": polygon,
		"duration": buff_duration,
		"buff_type": "lifesteal",
		"buff_value": forge_lifesteal,
		"tick_interval": 0.5,
		"color": Color(1.0, 0.65, 0.18, 0.25)
	})

func _get_line_color() -> Color:
	return Color(0.9, 0.5, 0.1, 1.0)

func _get_closure_color() -> Color:
	return Color(1.0, 0.4, 0.0, 1.0)
