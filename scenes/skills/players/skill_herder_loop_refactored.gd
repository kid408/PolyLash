extends SkillDrawingBase
class_name SkillHerderLoopRefactored

var dash_speed: float = 2400.0
var dash_base_damage: int = 38
var dash_knockback: float = 2.8
var pack_mark_damage_amp: float = 0.20
var pen_duration: float = 5.8
var execute_bonus_damage: int = 120
var execute_threshold_ratio: float = 0.35
var energy_refund_ratio: float = 0.45
var pen_pull_force: float = 260.0
var line_width: float = 18.0

func _spawn_line_effect(start: Vector2, end: Vector2) -> void:
	var duration: float = max(2.2, _get_line_duration())
	SkillEffectManager.create_wall_effect({
		"start": start,
		"end": end,
		"width": line_width,
		"duration": duration,
		"block_enemies": false,
		"contact_damage": dash_base_damage,
		"contact_interval": 0.18,
		"color": Color(1.0, 0.85, 0.24, 0.92)
	})

	SkillEffectManager.create_debuff_zone({
		"start": start,
		"end": end,
		"width": line_width + 10.0,
		"duration": duration,
		"debuff_type": "damage_amp",
		"debuff_value": pack_mark_damage_amp * 0.5,
		"debuff_duration": 1.2,
		"tick_interval": 0.4,
		"color": Color(1.0, 0.92, 0.4, 0.28)
	})

	_apply_herd_knockback(start, end)

func _spawn_area_effect(polygon: PackedVector2Array) -> void:
	if polygon.size() < 3:
		return

	var duration: float = max(3.0, pen_duration)
	var circle_damage: int = int(round(float(dash_base_damage) * 1.45))
	SkillEffectManager.create_area_effect({
		"polygon": polygon,
		"damage": circle_damage,
		"damage_interval": 0.24,
		"duration": duration,
		"color": Color(1.0, 0.78, 0.22, 0.48),
		"pull_to_center": true,
		"pull_force": pen_pull_force,
		"pull_interval": 0.05
	})

	SkillEffectManager.create_debuff_zone({
		"polygon": polygon,
		"duration": duration,
		"debuff_type": "slow",
		"debuff_value": 0.58,
		"debuff_duration": 1.2,
		"tick_interval": 0.35,
		"color": Color(1.0, 0.9, 0.3, 0.22)
	})

	SkillEffectManager.create_debuff_zone({
		"polygon": polygon,
		"duration": duration,
		"debuff_type": "damage_amp",
		"debuff_value": pack_mark_damage_amp,
		"debuff_duration": 1.6,
		"tick_interval": 0.45,
		"color": Color(1.0, 0.72, 0.2, 0.18)
	})

	var result: Dictionary = _apply_execute_sweep(polygon)
	_apply_herder_rewards(int(result["hit_count"]), int(result["execute_count"]))

func _apply_herd_knockback(start: Vector2, end: Vector2) -> void:
	var route_dir: Vector2 = (end - start)
	if route_dir.length() < 0.001:
		return
	route_dir = route_dir.normalized()
	var push_distance: float = dash_knockback * 14.0 + dash_speed * 0.006
	var enemies: Array = get_tree().get_nodes_in_group("enemies")

	for enemy in enemies:
		if not is_instance_valid(enemy):
			continue
		var closest: Vector2 = Geometry2D.get_closest_point_to_segment(enemy.global_position, start, end)
		if enemy.global_position.distance_to(closest) > line_width + 20.0:
			continue
		enemy.global_position += route_dir * push_distance

func _apply_execute_sweep(polygon: PackedVector2Array) -> Dictionary:
	var hit_count := 0
	var execute_count := 0
	var enemies: Array = get_tree().get_nodes_in_group("enemies")

	for enemy in enemies:
		if not is_instance_valid(enemy):
			continue
		if not enemy.has_node("HealthComponent"):
			continue
		if not Geometry2D.is_point_in_polygon(enemy.global_position, polygon):
			continue

		var health_component = enemy.get_node("HealthComponent")
		var execute_threshold: float = float(health_component.max_health) * execute_threshold_ratio
		if float(health_component.current_health) <= execute_threshold:
			health_component.take_damage(execute_bonus_damage)
			Global.spawn_floating_text(enemy.global_position, "CULL!", Color(1.2, 0.95, 0.35))
			execute_count += 1
		else:
			var chip_damage: int = int(round(float(execute_bonus_damage) * 0.35))
			health_component.take_damage(max(1, chip_damage))
			Global.spawn_floating_text(enemy.global_position, "HERD!", Color(1.0, 0.82, 0.28))
		hit_count += 1

	if hit_count > 0:
		var shake_power: float = 7.0 + float(execute_count) * 2.0 + float(hit_count) * 0.5
		Global.on_camera_shake.emit(shake_power, 0.18)
		SoundManager.play("skill_q_closure_generic")

	return {
		"hit_count": hit_count,
		"execute_count": execute_count
	}

func _apply_herder_rewards(hit_count: int, execute_count: int) -> void:
	if not is_instance_valid(skill_owner):
		return
	if hit_count <= 0:
		return

	if skill_owner.has_method("gain_energy"):
		var refund_ratio: float = min(0.9, energy_refund_ratio + 0.04 * float(hit_count) + 0.08 * float(execute_count))
		var refund: float = energy_cost * refund_ratio
		if refund > 0.0:
			skill_owner.gain_energy(refund)

	if execute_count >= 3 and skill_owner.has_node("HealthComponent"):
		var health_component = skill_owner.get_node("HealthComponent")
		if health_component.has_method("heal"):
			health_component.heal(12 + execute_count * 2)

func _get_line_color() -> Color:
	return Color(1.0, 0.85, 0.24, 1.0)

func _get_closure_color() -> Color:
	return Color(1.25, 0.72, 0.2, 1.0)
