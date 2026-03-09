extends SkillDrawingBase
class_name SkillWindPath

# Core parameters from config/player/skill_params_wide.csv (skill_wind_path).
var wind_wall_pull_force: float = 350.0
var wind_wall_damage: int = 15
var storm_zone_damage: int = 30
var wind_wall_duration: float = 3.0
var wind_wall_width: float = 24.0
var wind_wall_effect_radius: float = 120.0
var storm_zone_pull_force: float = 400.0
var storm_zone_duration: float = 3.0

# Extra tuning for new drawing framework implementation.
var wind_cut_damage: int = 18
var storm_slow_value: float = 0.36

func _spawn_line_effect(start: Vector2, end: Vector2) -> void:
	var duration: float = max(_get_line_duration(), wind_wall_duration)
	SkillEffectManager.create_line_effect({
		"start": start,
		"end": end,
		"width": wind_wall_width,
		"damage": wind_wall_damage,
		"damage_interval": 0.28,
		"duration": duration,
		"color": Color(0.24, 1.38, 1.45, 0.88),
		"pull_to_line": true,
		"pull_force": wind_wall_pull_force,
		"pull_interval": 0.05
	})

	SkillEffectManager.create_debuff_zone({
		"start": start,
		"end": end,
		"width": wind_wall_width + 8.0,
		"duration": duration,
		"debuff_type": "slow",
		"debuff_value": storm_slow_value * 0.75,
		"debuff_duration": 1.0,
		"tick_interval": 0.35,
		"color": Color(0.22, 1.1, 1.2, 0.2)
	})

	_apply_wind_cut(start, end)

func _spawn_area_effect(polygon: PackedVector2Array) -> void:
	if polygon.size() < 3:
		return

	var duration: float = max(2.8, storm_zone_duration)
	SkillEffectManager.create_area_effect({
		"polygon": polygon,
		"damage": storm_zone_damage,
		"damage_interval": 0.32,
		"duration": duration,
		"color": Color(0.18, 1.1, 1.15, 0.5),
		"pull_to_center": true,
		"pull_force": storm_zone_pull_force,
		"pull_interval": 0.05
	})

	SkillEffectManager.create_debuff_zone({
		"polygon": polygon,
		"duration": duration,
		"debuff_type": "slow",
		"debuff_value": storm_slow_value,
		"debuff_duration": 1.2,
		"tick_interval": 0.35,
		"color": Color(0.22, 1.0, 1.0, 0.22)
	})

	SkillEffectManager.create_debuff_zone({
		"polygon": polygon,
		"duration": duration,
		"debuff_type": "marked",
		"debuff_value": 0.14,
		"debuff_duration": 1.0,
		"tick_interval": 0.5,
		"color": Color(0.26, 1.1, 1.15, 0.15)
	})

	_apply_storm_burst(polygon)

func _apply_wind_cut(start: Vector2, end: Vector2) -> void:
	var cut_radius: float = max(20.0, wind_wall_effect_radius * 0.35)
	var damage: int = max(1, int(round(float(wind_cut_damage) * 0.7)))
	var enemies: Array = get_tree().get_nodes_in_group("enemies")
	for enemy_obj: Variant in enemies:
		if enemy_obj == null or not is_instance_valid(enemy_obj):
			continue
		if not (enemy_obj is Node2D):
			continue
		var enemy: Node2D = enemy_obj
		var closest: Vector2 = Geometry2D.get_closest_point_to_segment(enemy.global_position, start, end)
		if enemy.global_position.distance_to(closest) > cut_radius:
			continue
		if enemy.has_node("HealthComponent"):
			var hc: Node = enemy.get_node("HealthComponent")
			if hc != null and hc.has_method("take_damage"):
				hc.call("take_damage", damage)

func _apply_storm_burst(polygon: PackedVector2Array) -> void:
	var center: Vector2 = _polygon_center(polygon)
	var radius: float = _max_distance_to_center(polygon, center)
	var damage: int = max(1, wind_cut_damage)
	var hit_count: int = 0
	var enemies: Array = get_tree().get_nodes_in_group("enemies")
	for enemy_obj: Variant in enemies:
		if enemy_obj == null or not is_instance_valid(enemy_obj):
			continue
		if not (enemy_obj is Node2D):
			continue
		var enemy: Node2D = enemy_obj
		if enemy.global_position.distance_to(center) > radius:
			continue
		if not Geometry2D.is_point_in_polygon(enemy.global_position, polygon):
			continue
		if enemy.has_node("HealthComponent"):
			var hc: Node = enemy.get_node("HealthComponent")
			if hc != null and hc.has_method("take_damage"):
				hc.call("take_damage", damage)
		if enemy.has_method("apply_status"):
			enemy.call("apply_status", "slow", 0.9, storm_slow_value * 0.8)
		hit_count += 1
	if hit_count > 0:
		Global.spawn_floating_text(center, "WIND BURST", Color(0.55, 1.25, 1.35))
		spawn_skill_vfx(center, Color(0.5, 1.2, 1.3, 0.85), 0.58)

func _polygon_center(polygon: PackedVector2Array) -> Vector2:
	if polygon.is_empty():
		return Vector2.ZERO
	var center: Vector2 = Vector2.ZERO
	for point: Vector2 in polygon:
		center += point
	return center / float(polygon.size())

func _max_distance_to_center(polygon: PackedVector2Array, center: Vector2) -> float:
	var max_dist: float = 0.0
	for point: Vector2 in polygon:
		max_dist = max(max_dist, center.distance_to(point))
	return max_dist

func _get_line_color() -> Color:
	return Color(0.28, 1.4, 1.5, 1.0)

func _get_closure_color() -> Color:
	return Color(0.6, 1.25, 1.3, 1.0)
