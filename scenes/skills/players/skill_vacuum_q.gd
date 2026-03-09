extends SkillDrawingBase
class_name SkillVacuumQ

var pull_force: float = 280.0
var pull_damage: int = 18
var vortex_force: float = 460.0
var vortex_damage: int = 30
var vortex_duration: float = 4.5
var suction_damage_amp: float = 0.2

func _spawn_line_effect(start: Vector2, end: Vector2) -> void:
	SkillEffectManager.create_area_effect({
		"polygon": _line_to_polygon(start, end, 26.0),
		"damage": pull_damage,
		"damage_interval": 0.55,
		"duration": _get_line_duration(),
		"color": Color(0.4, 0.2, 0.6, 0.54),
		"pull_to_center": true,
		"pull_force": pull_force
	})

	SkillEffectManager.create_debuff_zone({
		"start": start,
		"end": end,
		"width": 20.0,
		"duration": _get_line_duration(),
		"debuff_type": "damage_amp",
		"debuff_value": suction_damage_amp,
		"debuff_duration": 2.0,
		"tick_interval": 0.55,
		"color": Color(0.35, 0.2, 0.55, 0.22)
	})

func _spawn_area_effect(polygon: PackedVector2Array) -> void:
	SkillEffectManager.create_area_effect({
		"polygon": polygon,
		"damage": vortex_damage,
		"damage_interval": 0.35,
		"duration": vortex_duration,
		"color": Color(0.3, 0.15, 0.5, 0.45),
		"pull_to_center": true,
		"pull_force": vortex_force
	})

	SkillEffectManager.create_debuff_zone({
		"polygon": polygon,
		"duration": vortex_duration,
		"debuff_type": "slow",
		"debuff_value": 0.45,
		"debuff_duration": 1.6,
		"tick_interval": 0.35,
		"color": Color(0.26, 0.12, 0.45, 0.2)
	})

func _get_line_color() -> Color:
	return Color(0.4, 0.2, 0.6, 1.0)

func _get_closure_color() -> Color:
	return Color(0.3, 0.15, 0.5, 1.0)

func _line_to_polygon(start: Vector2, end: Vector2, width: float) -> PackedVector2Array:
	var vec := end - start
	if vec.length() < 0.001:
		return PackedVector2Array([start, start + Vector2.RIGHT, start + Vector2(1.0, 1.0)])
	var perp := vec.normalized().rotated(PI / 2.0) * width * 0.5
	var polygon := PackedVector2Array()
	polygon.append(start + perp)
	polygon.append(end + perp)
	polygon.append(end - perp)
	polygon.append(start - perp)
	return polygon
