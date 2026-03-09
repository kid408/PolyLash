extends SkillDrawingBase
class_name SkillHerderLoop

# Core parameters from config/player/skill_params_wide.csv (skill_herder_loop).
var dash_damage: int = 1
var dash_base_damage: int = 10
var dash_knockback: float = 2.0

# Extra tuning for new drawing framework implementation.
var pen_duration: float = 5.6
var pen_pull_force: float = 220.0
var pack_mark_damage_amp: float = 0.16
var execute_bonus_damage: int = 68
var execute_threshold_ratio: float = 0.32
var energy_refund_ratio: float = 0.25
var fence_width: float = 20.0

func _spawn_line_effect(start: Vector2, end: Vector2) -> void:
	var duration: float = max(_get_line_duration(), 2.4)
	var lane_damage: int = max(1, dash_base_damage)
	var pull_force: float = max(100.0, pen_pull_force * 0.55)
	var lane_width: float = max(14.0, fence_width)

	SkillEffectManager.create_line_effect({
		"start": start,
		"end": end,
		"width": lane_width,
		"damage": lane_damage,
		"damage_interval": 0.24,
		"duration": duration,
		"color": Color(1.05, 0.88, 0.28, 0.9),
		"pull_to_line": true,
		"pull_force": pull_force,
		"pull_interval": 0.06
	})

	SkillEffectManager.create_debuff_zone({
		"start": start,
		"end": end,
		"width": lane_width + 8.0,
		"duration": duration,
		"debuff_type": "slow",
		"debuff_value": 0.44,
		"debuff_duration": 1.0,
		"tick_interval": 0.35,
		"color": Color(1.0, 0.9, 0.35, 0.2)
	})

	SkillEffectManager.create_debuff_zone({
		"start": start,
		"end": end,
		"width": lane_width + 4.0,
		"duration": duration,
		"debuff_type": "marked",
		"debuff_value": pack_mark_damage_amp * 0.75,
		"debuff_duration": 1.2,
		"tick_interval": 0.4,
		"color": Color(1.0, 0.82, 0.25, 0.16)
	})

func _spawn_area_effect(polygon: PackedVector2Array) -> void:
	if polygon.size() < 3:
		return

	var duration: float = max(3.0, pen_duration)
	var ring_damage: int = max(1, int(round(float(dash_base_damage) * 1.25)))
	var ring_pull_force: float = max(140.0, pen_pull_force)

	_spawn_pen_fence(polygon, duration)

	SkillEffectManager.create_area_effect({
		"polygon": polygon,
		"damage": ring_damage,
		"damage_interval": 0.28,
		"duration": duration,
		"color": Color(1.0, 0.78, 0.2, 0.45),
		"pull_to_center": true,
		"pull_force": ring_pull_force,
		"pull_interval": 0.06
	})

	SkillEffectManager.create_debuff_zone({
		"polygon": polygon,
		"duration": duration,
		"debuff_type": "slow",
		"debuff_value": 0.52,
		"debuff_duration": 1.2,
		"tick_interval": 0.35,
		"color": Color(1.0, 0.86, 0.3, 0.24)
	})

	SkillEffectManager.create_debuff_zone({
		"polygon": polygon,
		"duration": duration,
		"debuff_type": "marked",
		"debuff_value": pack_mark_damage_amp,
		"debuff_duration": 1.6,
		"tick_interval": 0.45,
		"color": Color(1.0, 0.72, 0.2, 0.18)
	})

	_apply_execute_sweep(polygon)

func _spawn_pen_fence(polygon: PackedVector2Array, duration: float) -> void:
	var point_count: int = polygon.size()
	if point_count < 3:
		return
	for i: int in range(point_count):
		var start: Vector2 = polygon[i]
		var end: Vector2 = polygon[(i + 1) % point_count]
		SkillEffectManager.create_wall_effect({
			"start": start,
			"end": end,
			"width": max(10.0, fence_width * 0.6),
			"duration": duration,
			"block_enemies": true,
			"block_bullets": true,
			"contact_damage": max(1, int(round(float(dash_base_damage) * 0.5))),
			"contact_interval": 0.32,
			"color": Color(1.1, 0.9, 0.35, 0.82)
		})

func _apply_execute_sweep(polygon: PackedVector2Array) -> void:
	var execute_count: int = 0
	var hit_count: int = 0
	var enemies: Array = get_tree().get_nodes_in_group("enemies")
	for enemy_obj: Variant in enemies:
		if enemy_obj == null or not is_instance_valid(enemy_obj):
			continue
		if not (enemy_obj is Node2D):
			continue
		var enemy: Node2D = enemy_obj
		if not Geometry2D.is_point_in_polygon(enemy.global_position, polygon):
			continue
		if not enemy.has_node("HealthComponent"):
			continue

		var hc: Node = enemy.get_node("HealthComponent")
		var hp_ratio: float = 1.0
		if hc != null and "max_health" in hc and "current_health" in hc:
			var max_hp: float = max(1.0, float(hc.get("max_health")))
			hp_ratio = float(hc.get("current_health")) / max_hp

		var damage: int = max(1, int(round(float(dash_base_damage) * 1.4)))
		if hp_ratio <= execute_threshold_ratio:
			damage = max(damage, execute_bonus_damage)
			execute_count += 1
		else:
			hit_count += 1

		if hc != null and hc.has_method("take_damage"):
			hc.call("take_damage", damage)
		if enemy.has_method("apply_status"):
			enemy.call("apply_status", "slow", 0.8, 0.42)
			enemy.call("apply_status", "marked", 1.2, pack_mark_damage_amp * 0.85)

	if execute_count > 0:
		_grant_execute_refund(execute_count)

	if execute_count > 0 or hit_count > 0:
		var center: Vector2 = _polygon_center(polygon)
		Global.spawn_floating_text(
			center,
			"HERD EXEC %d / HIT %d" % [execute_count, hit_count],
			Color(1.2, 1.0, 0.4)
		)
		spawn_skill_vfx(center, Color(1.15, 0.88, 0.3, 0.9), 0.75)
		Global.on_camera_shake.emit(6.0 + float(execute_count) * 0.8, 0.14)

func _grant_execute_refund(execute_count: int) -> void:
	if execute_count <= 0:
		return
	if not is_instance_valid(skill_owner):
		return
	if not skill_owner.has_method("gain_energy"):
		return
	var base_refund: float = max(1.0, energy_cost * energy_refund_ratio)
	var total_refund: float = base_refund * float(execute_count)
	skill_owner.call("gain_energy", total_refund)

func _polygon_center(polygon: PackedVector2Array) -> Vector2:
	if polygon.is_empty():
		return Vector2.ZERO
	var center: Vector2 = Vector2.ZERO
	for point: Vector2 in polygon:
		center += point
	return center / float(polygon.size())

func _get_line_color() -> Color:
	return Color(1.05, 0.9, 0.3, 1.0)

func _get_closure_color() -> Color:
	return Color(1.2, 0.7, 0.18, 1.0)
