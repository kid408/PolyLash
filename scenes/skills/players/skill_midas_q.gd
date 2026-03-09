extends SkillDrawingBase
class_name SkillMidasQ

var petrify_slow: float = 0.95
var petrify_duration: float = 3.0
var transmute_damage_amp: float = 0.5
var transmute_duration: float = 5.0
var gilded_line_damage: int = 10
var transmute_coin_count: int = 4
var transmute_bonus_damage: int = 22

func _spawn_line_effect(start: Vector2, end: Vector2) -> void:
	SkillEffectManager.create_debuff_zone({
		"start": start,
		"end": end,
		"width": 24.0,
		"duration": _get_line_duration(),
		"debuff_type": "slow",
		"debuff_value": petrify_slow,
		"debuff_duration": petrify_duration,
		"tick_interval": 0.75,
		"damage": gilded_line_damage,
		"damage_interval": 0.75,
		"color": Color(0.9, 0.7, 0.1, 0.5)
	})

	SkillEffectManager.create_debuff_zone({
		"start": start,
		"end": end,
		"width": 20.0,
		"duration": _get_line_duration(),
		"debuff_type": "damage_amp",
		"debuff_value": transmute_damage_amp * 0.5,
		"debuff_duration": 2.0,
		"tick_interval": 0.75,
		"color": Color(0.95, 0.78, 0.2, 0.3)
	})

func _spawn_area_effect(polygon: PackedVector2Array) -> void:
	SkillEffectManager.create_debuff_zone({
		"polygon": polygon,
		"duration": transmute_duration,
		"debuff_type": "damage_amp",
		"debuff_value": transmute_damage_amp,
		"debuff_duration": transmute_duration,
		"tick_interval": 0.6,
		"color": Color(0.92, 0.74, 0.14, 0.42)
	})

	SkillEffectManager.create_debuff_zone({
		"polygon": polygon,
		"duration": transmute_duration,
		"debuff_type": "slow",
		"debuff_value": min(0.98, petrify_slow + 0.03),
		"debuff_duration": petrify_duration,
		"tick_interval": 1.1,
		"color": Color(0.85, 0.65, 0.05, 0.25)
	})

	SkillEffectManager.create_area_effect({
		"polygon": polygon,
		"damage": transmute_bonus_damage,
		"damage_interval": 0.8,
		"duration": transmute_duration,
		"color": Color(0.8, 0.6, 0.0, 0.18)
	})

	_spawn_transmute_coin_burst(polygon, transmute_coin_count)

func _spawn_transmute_coin_burst(polygon: PackedVector2Array, base_count: int) -> void:
	if base_count <= 0 or polygon.size() < 3:
		return

	var center := _calculate_polygon_center(polygon)
	var area := _calculate_polygon_area(polygon)
	var scaled_count := base_count + int(clamp(area / 18000.0, 0.0, 4.0))

	for i in range(scaled_count):
		var angle := TAU * float(i) / float(max(scaled_count, 1))
		var radius := 36.0 + float(i % 3) * 18.0
		var pos := center + Vector2.RIGHT.rotated(angle) * radius
		Global.spawn_coin(pos, 1)

	Global.spawn_floating_text(center, "GOLD RUSH!", Color(1.0, 0.85, 0.22))

func _get_line_color() -> Color:
	return Color(0.9, 0.7, 0.1, 1.0)

func _get_closure_color() -> Color:
	return Color(0.8, 0.6, 0.0, 1.0)
