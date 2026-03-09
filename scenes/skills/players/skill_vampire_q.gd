extends SkillDrawingBase
class_name SkillVampireQ

var hp_cost_percent: float = 0.08
var blood_damage: int = 36
var lifesteal_value: float = 1.0
var blood_pool_duration: float = 5.5
var blood_mark_amp: float = 0.25
var blood_heal_value: int = 4

func _spawn_line_effect(start: Vector2, end: Vector2) -> void:
	if skill_owner and skill_owner.has_node("HealthComponent"):
		var hc = skill_owner.health_component
		var cost: int = int(round(float(hc.max_health) * hp_cost_percent))
		if hc.current_health > 1:
			var actual_cost: int = min(cost, int(hc.current_health) - 1)
			hc.take_damage(actual_cost)
			Global.spawn_floating_text(skill_owner.global_position, "-%d HP" % actual_cost, Color(0.7, 0.1, 0.1))

	SkillEffectManager.create_line_effect({
		"start": start,
		"end": end,
		"width": 26.0,
		"damage": blood_damage,
		"damage_interval": 0.45,
		"duration": _get_line_duration(),
		"color": Color(0.7, 0.1, 0.1, 0.72)
	})

	SkillEffectManager.create_debuff_zone({
		"start": start,
		"end": end,
		"width": 20.0,
		"duration": _get_line_duration(),
		"debuff_type": "damage_amp",
		"debuff_value": blood_mark_amp,
		"debuff_duration": 2.0,
		"tick_interval": 0.5,
		"color": Color(0.62, 0.08, 0.08, 0.24)
	})

func _spawn_area_effect(polygon: PackedVector2Array) -> void:
	SkillEffectManager.create_buff_zone({
		"polygon": polygon,
		"duration": blood_pool_duration,
		"buff_type": "lifesteal",
		"buff_value": lifesteal_value,
		"tick_interval": 0.45,
		"color": Color(0.5, 0.0, 0.0, 0.55)
	})

	SkillEffectManager.create_buff_zone({
		"polygon": polygon,
		"duration": blood_pool_duration,
		"buff_type": "heal",
		"buff_value": float(blood_heal_value),
		"tick_interval": 0.55,
		"color": Color(0.62, 0.08, 0.08, 0.28)
	})

func _get_line_color() -> Color:
	return Color(0.7, 0.1, 0.1, 1.0)

func _get_closure_color() -> Color:
	return Color(0.5, 0.0, 0.0, 1.0)
