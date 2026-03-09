extends SkillDrawingBase
class_name SkillAmmoQ

var line_damage_amp: float = 0.22
var line_damage: int = 10
var supply_cooldown_reduction: float = 0.22
var supply_attack_boost: float = 0.25
var buff_duration: float = 5.0

func _spawn_line_effect(start: Vector2, end: Vector2) -> void:
	SkillEffectManager.create_debuff_zone({
		"start": start,
		"end": end,
		"width": 22.0,
		"duration": _get_line_duration(),
		"debuff_type": "damage_amp",
		"debuff_value": line_damage_amp,
		"debuff_duration": 2.0,
		"tick_interval": 0.45,
		"damage": line_damage,
		"damage_interval": 0.45,
		"color": Color(0.25, 0.75, 0.95, 0.55)
	})

func _spawn_area_effect(polygon: PackedVector2Array) -> void:
	SkillEffectManager.create_buff_zone({
		"polygon": polygon,
		"duration": buff_duration,
		"buff_type": "cooldown_reduction",
		"buff_value": supply_cooldown_reduction,
		"tick_interval": 0.5,
		"color": Color(0.2, 0.55, 0.75, 0.45)
	})

	SkillEffectManager.create_buff_zone({
		"polygon": polygon,
		"duration": buff_duration,
		"buff_type": "attack_boost",
		"buff_value": supply_attack_boost,
		"tick_interval": 0.5,
		"color": Color(0.35, 0.8, 1.0, 0.25)
	})

func _get_line_color() -> Color:
	return Color(0.25, 0.75, 0.95, 1.0)

func _get_closure_color() -> Color:
	return Color(0.2, 0.55, 0.75, 1.0)
