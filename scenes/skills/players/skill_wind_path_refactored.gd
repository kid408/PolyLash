extends SkillDrawingBase
class_name SkillWindPathRefactored

var wind_wall_pull_force: float = 420.0
var wind_wall_damage: int = 24
var wind_wall_duration: float = 3.8
var wind_wall_width: float = 26.0
var wind_wall_effect_radius: float = 130.0
var storm_zone_damage: int = 44
var storm_zone_pull_force: float = 520.0
var storm_zone_duration: float = 4.8
var wind_cut_damage: int = 34
var storm_slow_value: float = 0.42

func _spawn_line_effect(start: Vector2, end: Vector2) -> void:
	SkillEffectManager.create_line_effect({
		"start": start,
		"end": end,
		"width": wind_wall_width,
		"damage": wind_wall_damage,
		"damage_interval": 0.3,
		"duration": wind_wall_duration,
		"color": Color(0.2, 1.5, 1.5, 0.86),
		"pull_to_line": true,
		"pull_force": wind_wall_pull_force,
		"pull_interval": 0.05
	})

	SkillEffectManager.create_debuff_zone({
		"start": start,
		"end": end,
		"width": wind_wall_width + 8.0,
		"duration": wind_wall_duration,
		"debuff_type": "slow",
		"debuff_value": storm_slow_value * 0.6,
		"debuff_duration": 1.0,
		"tick_interval": 0.35,
		"color": Color(0.2, 1.2, 1.2, 0.2)
	})

	_apply_wind_cut(start, end)

func _spawn_area_effect(polygon: PackedVector2Array) -> void:
	if polygon.size() < 3:
		return

	SkillEffectManager.create_area_effect({
		"polygon": polygon,
		"damage": storm_zone_damage,
		"damage_interval": 0.32,
		"duration": storm_zone_duration,
		"color": Color(0.18, 1.15, 1.15, 0.5),
		"pull_to_center": true,
		"pull_force": storm_zone_pull_force,
		"pull_interval": 0.05
	})

	SkillEffectManager.create_debuff_zone({
		"polygon": polygon,
		"duration": storm_zone_duration,
		"debuff_type": "slow",
		"debuff_value": storm_slow_value,
		"debuff_duration": 1.3,
		"tick_interval": 0.35,
		"color": Color(0.2, 1.0, 1.0, 0.22)
	})

	SkillEffectManager.create_debuff_zone({
		"polygon": polygon,
		"duration": storm_zone_duration,
		"debuff_type": "damage_amp",
		"debuff_value": 0.14,
		"debuff_duration": 1.0,
		"tick_interval": 0.5,
		"color": Color(0.3, 1.15, 1.15, 0.16)
	})

	_apply_storm_burst(polygon)

func _apply_wind_cut(start: Vector2, end: Vector2) -> void:
	var cut_radius: float = float(max(20.0, wind_wall_effect_radius * 0.35))
	var chip_damage: int = max(1, int(round(float(wind_cut_damage) * 0.55)))
	var enemies: Array = get_tree().get_nodes_in_group("enemies")

	for enemy in enemies:
		if not is_instance_valid(enemy):
			continue
		if not (enemy is Node2D):
			continue
		var enemy_node: Node2D = enemy
		var closest: Vector2 = Geometry2D.get_closest_point_to_segment(enemy_node.global_position, start, end)
		var dist: float = enemy_node.global_position.distance_to(closest)
		if dist > cut_radius:
			continue

		if enemy_node.has_node("HealthComponent"):
			var health_component: Node = enemy_node.get_node("HealthComponent")
			if health_component.has_method("take_damage"):
				health_component.call("take_damage", chip_damage)

		var pull_dir: Vector2 = closest - enemy_node.global_position
		if pull_dir.length() > 0.001:
			enemy_node.global_position += pull_dir.normalized() * min(24.0, wind_wall_pull_force * 0.03)

func _apply_storm_burst(polygon: PackedVector2Array) -> void:
	var hit_count: int = 0
	var center: Vector2 = _polygon_center(polygon)
	var enemies: Array = get_tree().get_nodes_in_group("enemies")

	for enemy in enemies:
		if not is_instance_valid(enemy):
			continue
		if not (enemy is Node2D):
			continue
		var enemy_node: Node2D = enemy
		if not enemy_node.has_node("HealthComponent"):
			continue
		if not Geometry2D.is_point_in_polygon(enemy_node.global_position, polygon):
			continue

		var health_component: Node = enemy_node.get_node("HealthComponent")
		if health_component.has_method("take_damage"):
			health_component.call("take_damage", wind_cut_damage)
		var drag_dir: Vector2 = center - enemy_node.global_position
		if drag_dir.length() > 0.001:
			enemy_node.global_position += drag_dir.normalized() * min(28.0, storm_zone_pull_force * 0.035)
		Global.spawn_floating_text(enemy_node.global_position, "GUST!", Color(0.35, 1.2, 1.2))
		hit_count += 1

	if hit_count > 0:
		Global.on_camera_shake.emit(7.0 + float(hit_count), 0.16)

func _polygon_center(polygon: PackedVector2Array) -> Vector2:
	if polygon.is_empty():
		return Vector2.ZERO
	var center: Vector2 = Vector2.ZERO
	for p in polygon:
		center += p
	return center / float(polygon.size())

func _get_line_color() -> Color:
	return Color(0.2, 1.5, 1.5, 1.0)

func _get_closure_color() -> Color:
	return Color(0.12, 1.18, 1.18, 1.0)
