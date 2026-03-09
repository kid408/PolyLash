extends SkillBase
class_name SkillHerderE

var explosion_radius: float = 220.0
var explosion_damage: int = 108
var explosion_knockback: float = 560.0

var mark_duration: float = 2.0
var mark_amp: float = 0.16
var armor_gain: int = 1

var charge_lane_count: int = 3
var charge_lane_length: float = 280.0
var charge_lane_width: float = 52.0
var charge_lane_damage: int = 42

func execute() -> void:
	if not can_execute():
		if is_on_cooldown and is_instance_valid(skill_owner):
			Global.spawn_floating_text(skill_owner.global_position, "Cooldown!", Color.YELLOW)
		return
	if not consume_energy():
		if is_instance_valid(skill_owner):
			Global.spawn_floating_text(skill_owner.global_position, "No Energy!", Color.RED)
		return
	if not is_instance_valid(skill_owner):
		return

	var damage_amp: float = get_e_damage_amp(0.38, 0.42)
	var duration_amp: float = get_e_duration_amp(0.36)
	var center: Vector2 = skill_owner.global_position
	var final_damage: int = max(1, int(round(float(explosion_damage) * damage_amp)))
	var final_mark: float = mark_amp * damage_amp
	var final_knockback: float = explosion_knockback * duration_amp

	var burst_hits: int = _detonate(center, explosion_radius, final_damage, final_knockback, final_mark, mark_duration * duration_amp)
	var lane_hits: int = _emit_pack_charge(center, damage_amp, duration_amp, is_f_window_active())
	_grant_armor()
	spawn_skill_vfx(center, Color(1.1, 0.95, 0.35, 0.9), 0.8)
	Global.on_camera_shake.emit(6.8 + float(burst_hits + lane_hits) * 0.24, 0.12)
	if burst_hits > 0 or lane_hits > 0:
		Global.spawn_floating_text(center, "HERD x%d / CHARGE x%d" % [burst_hits, lane_hits], Color(1.2, 1.0, 0.45))

	start_cooldown()

func _emit_pack_charge(center: Vector2, damage_amp: float, duration_amp: float, enhanced: bool) -> int:
	var total_hits: int = 0
	var lanes: int = charge_lane_count + (1 if enhanced else 0)
	var base_dir: Vector2 = _get_aim_direction()
	var half_span: float = 0.52
	for i: int in range(lanes):
		var ratio: float = 0.5 if lanes <= 1 else float(i) / float(lanes - 1)
		var angle_offset: float = lerp(-half_span, half_span, ratio)
		var dir: Vector2 = base_dir.rotated(angle_offset)
		var lane_length: float = charge_lane_length * (1.1 if enhanced else 1.0)
		var end_pos: Vector2 = center + dir * lane_length
		var lane_damage: int = max(
			1,
			int(round(float(charge_lane_damage) * damage_amp * (1.0 + abs(angle_offset) * 0.12)))
		)
		total_hits += _damage_along_lane(
			center,
			end_pos,
			charge_lane_width * (1.08 if enhanced else 1.0),
			lane_damage,
			explosion_knockback * 0.62 * duration_amp,
			mark_amp * 0.72 * damage_amp,
			mark_duration * 0.9
		)
	return total_hits

func _damage_along_lane(
	start: Vector2,
	finish: Vector2,
	width: float,
	damage: int,
	knockback: float,
	mark_value: float,
	mark_time: float
) -> int:
	var hits: int = 0
	var enemies: Array = get_tree().get_nodes_in_group("enemies")
	for enemy_obj: Variant in enemies:
		if enemy_obj == null or not is_instance_valid(enemy_obj):
			continue
		if not (enemy_obj is Node2D):
			continue
		var enemy: Node2D = enemy_obj
		var path_dist: float = _distance_point_to_segment(enemy.global_position, start, finish)
		if path_dist > width:
			continue
		_apply_damage(enemy, damage)
		_apply_knockback(enemy, (enemy.global_position - start).normalized(), knockback)
		_apply_status(enemy, "marked", mark_time, mark_value)
		_apply_status(enemy, "slow", max(0.5, mark_time * 0.55), 0.34)
		hits += 1
	return hits

func _detonate(center: Vector2, radius: float, damage: int, knockback: float, mark_value: float, mark_time: float) -> int:
	var hits: int = 0
	var enemies: Array = get_tree().get_nodes_in_group("enemies")
	for enemy_obj: Variant in enemies:
		if enemy_obj == null or not is_instance_valid(enemy_obj):
			continue
		if not (enemy_obj is Node2D):
			continue
		var enemy: Node2D = enemy_obj
		if enemy.global_position.distance_to(center) > radius:
			continue
		_apply_damage(enemy, damage)
		_apply_knockback(enemy, (enemy.global_position - center).normalized(), knockback)
		_apply_status(enemy, "marked", mark_time, mark_value)
		_apply_status(enemy, "slow", max(0.45, mark_time * 0.55), 0.32)
		hits += 1
	return hits

func _apply_damage(enemy: Node2D, amount: int) -> void:
	if enemy == null or not is_instance_valid(enemy):
		return
	if not enemy.has_node("HealthComponent"):
		return
	var hc: Node = enemy.get_node("HealthComponent")
	if hc != null and hc.has_method("take_damage"):
		hc.call("take_damage", amount)

func _apply_status(enemy: Node2D, status_type: String, duration: float, value: float) -> void:
	if enemy == null or not is_instance_valid(enemy):
		return
	if enemy.has_method("apply_status"):
		enemy.call("apply_status", status_type, duration, value)

func _apply_knockback(enemy: Node2D, direction: Vector2, force: float) -> void:
	if enemy == null or not is_instance_valid(enemy):
		return
	if enemy.has_method("apply_knockback"):
		enemy.call("apply_knockback", direction, force)

func _distance_point_to_segment(point: Vector2, a: Vector2, b: Vector2) -> float:
	var ab: Vector2 = b - a
	var len_sq: float = ab.length_squared()
	if len_sq <= 0.0001:
		return point.distance_to(a)
	var t: float = clamp((point - a).dot(ab) / len_sq, 0.0, 1.0)
	var closest: Vector2 = a + ab * t
	return point.distance_to(closest)

func _get_aim_direction() -> Vector2:
	if not is_instance_valid(skill_owner):
		return Vector2.RIGHT
	var dir: Vector2 = skill_owner.get_global_mouse_position() - skill_owner.global_position
	if dir.length_squared() <= 0.01:
		return Vector2.RIGHT
	return dir.normalized()

func _grant_armor() -> void:
	if not is_instance_valid(skill_owner):
		return
	if not ("armor" in skill_owner and "max_armor" in skill_owner):
		return
	var before: int = int(skill_owner.armor)
	var after: int = min(int(skill_owner.max_armor), before + armor_gain)
	if after <= before:
		return
	skill_owner.armor = after
	if skill_owner.has_signal("armor_changed"):
		skill_owner.armor_changed.emit(after)
	Global.spawn_floating_text(skill_owner.global_position, "+ARMOR", Color(0.6, 1.0, 1.0))
