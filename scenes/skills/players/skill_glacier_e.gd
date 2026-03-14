extends SkillBase
class_name SkillGlacierE

var knockback_force: float = 500.0
var shield_amount: int = 3
var explosion_radius: float = 150.0
var explosion_damage: int = 50

var spike_count: int = 3
var spike_length: float = 260.0
var spike_width: float = 44.0
var spike_damage: int = 32
const GLACIER_ACTIVE_META: String = "glacier_zone_active_until_msec"
const GLACIER_E_SHATTER_META: String = "glacier_e_shatter_until_msec"

func execute() -> void:
	if not consume_energy():
		if skill_owner:
			Global.spawn_floating_text(skill_owner.global_position, "No Energy!", Color.RED)
		return
	if not is_instance_valid(skill_owner):
		return

	var damage_amp: float = get_e_damage_amp(0.28, 0.36)
	var duration_amp: float = get_e_duration_amp(0.35)
	var q_combo_active: bool = _is_glacier_zone_active()
	var final_radius: float = explosion_radius * (1.0 + (duration_amp - 1.0) * 0.45)
	if q_combo_active:
		final_radius *= 1.16
	var final_damage: int = max(1, int(round(float(explosion_damage) * damage_amp)))
	var final_knockback: float = knockback_force * (1.0 + (duration_amp - 1.0) * 0.3)
	var freeze_duration: float = 1.0 * duration_amp
	if q_combo_active:
		freeze_duration *= 1.18
	var aim_dir: Vector2 = _get_aim_direction()

	var enemies: Array = get_tree().get_nodes_in_group("enemies")
	var hit_count: int = 0
	for enemy in enemies:
		if enemy == null or not is_instance_valid(enemy):
			continue
		if not (enemy is Node2D):
			continue
		var enemy_node: Node2D = enemy
		var dist: float = skill_owner.global_position.distance_to(enemy_node.global_position)
		if dist > final_radius:
			continue
		if enemy_node.has_node("HealthComponent"):
			enemy_node.get_node("HealthComponent").take_damage(final_damage)
		var dir: Vector2 = (enemy_node.global_position - skill_owner.global_position).normalized()
		enemy_node.global_position += dir * final_knockback * 0.1
		if enemy_node.has_method("apply_status"):
			enemy_node.apply_status("freeze", freeze_duration, 0.0)
		hit_count += 1

	var spike_hits: int = _emit_frost_spikes(skill_owner.global_position, aim_dir, damage_amp, duration_amp, q_combo_active)
	if q_combo_active:
		var bonus_pulse_damage: int = max(1, int(round(float(final_damage) * 0.45)))
		_apply_glacier_combo_pulse(skill_owner.global_position, final_radius * 0.78, bonus_pulse_damage, duration_amp)
	if hit_count > 0 or spike_hits > 0:
		Global.spawn_floating_text(skill_owner.global_position, "ICE x%d / SPIKE x%d" % [hit_count, spike_hits], Color(0.7, 0.95, 1.2))
	var shatter_window: float = 1.9 + (0.7 if q_combo_active else 0.0)
	skill_owner.set_meta(GLACIER_E_SHATTER_META, Time.get_ticks_msec() + int(round(shatter_window * 1000.0)))

	if "armor" in skill_owner:
		skill_owner.armor = min(skill_owner.armor + shield_amount, skill_owner.max_armor)

	if is_f_window_active():
		var pulse_damage: int = max(1, int(round(float(final_damage) * 0.6)))
		var pulse_radius: float = final_radius * 0.75
		get_tree().create_timer(0.3).timeout.connect(_on_frost_pulse_timeout.bind(pulse_radius, pulse_damage, duration_amp))

	spawn_skill_vfx(skill_owner.global_position, Color(0.5, 0.8, 1.0, 0.8), 0.8)
	Global.on_camera_shake.emit(8.0, 0.2)
	Global.spawn_floating_text(skill_owner.global_position, "ICE BURST!", Color(0.5, 0.8, 1.0))
	start_cooldown()

func _on_frost_pulse_timeout(pulse_radius: float, pulse_damage: int, duration_amp: float) -> void:
	if not is_instance_valid(skill_owner):
		return
	var owner: Node2D = skill_owner
	var pulse_hits: int = 0
	var pulse_enemies: Array = get_tree().get_nodes_in_group("enemies")
	for pulse_enemy in pulse_enemies:
		if pulse_enemy == null or not is_instance_valid(pulse_enemy):
			continue
		if not (pulse_enemy is Node2D):
			continue
		var enemy_node: Node2D = pulse_enemy
		if owner.global_position.distance_to(enemy_node.global_position) > pulse_radius:
			continue
		if enemy_node.has_node("HealthComponent"):
			enemy_node.get_node("HealthComponent").take_damage(pulse_damage)
		if enemy_node.has_method("apply_status"):
			enemy_node.apply_status("slow", 1.0 * duration_amp, 0.38)
		pulse_hits += 1
	if pulse_hits > 0:
		spawn_skill_vfx(owner.global_position, Color(0.7, 0.95, 1.15, 0.7), 0.6)

func _emit_frost_spikes(center: Vector2, aim_dir: Vector2, damage_amp: float, duration_amp: float, q_combo_active: bool) -> int:
	var hits: int = 0
	var lanes: int = spike_count + (1 if q_combo_active else 0)
	var half_angle: float = 0.55
	for i in range(lanes):
		var ratio: float = 0.5 if lanes <= 1 else float(i) / float(lanes - 1)
		var angle: float = lerp(-half_angle, half_angle, ratio)
		var dir: Vector2 = aim_dir.rotated(angle)
		var end_pos: Vector2 = center + dir * spike_length
		var lane_damage: int = max(1, int(round(float(spike_damage) * damage_amp * (1.0 + abs(angle) * 0.12))))
		hits += _damage_along_spike(center, end_pos, spike_width, lane_damage, 0.65 * duration_amp)
		spawn_skill_vfx(end_pos, Color(0.72, 0.95, 1.22, 0.78), 0.45)
	return hits

func _damage_along_spike(start: Vector2, finish: Vector2, width: float, damage: int, freeze_time: float) -> int:
	var hits: int = 0
	var enemies: Array = get_tree().get_nodes_in_group("enemies")
	for enemy in enemies:
		if enemy == null or not is_instance_valid(enemy):
			continue
		if not (enemy is Node2D):
			continue
		var enemy_node: Node2D = enemy
		var dist_to_path: float = _distance_point_to_segment(enemy_node.global_position, start, finish)
		if dist_to_path > width:
			continue
		if enemy_node.has_node("HealthComponent"):
			enemy_node.get_node("HealthComponent").take_damage(damage)
		if enemy_node.has_method("apply_status"):
			enemy_node.apply_status("freeze", freeze_time, 0.0)
			enemy_node.apply_status("slow", max(0.5, freeze_time * 1.2), 0.35)
		hits += 1
	return hits

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

func _is_glacier_zone_active() -> bool:
	if not is_instance_valid(skill_owner):
		return false
	if not skill_owner.has_meta(GLACIER_ACTIVE_META):
		return false
	var expire_msec: int = int(skill_owner.get_meta(GLACIER_ACTIVE_META))
	return Time.get_ticks_msec() <= expire_msec

func _apply_glacier_combo_pulse(center: Vector2, radius: float, damage: int, duration_amp: float) -> void:
	var enemies: Array = get_tree().get_nodes_in_group("enemies")
	for enemy_obj: Variant in enemies:
		if enemy_obj == null or not is_instance_valid(enemy_obj):
			continue
		if not (enemy_obj is Node2D):
			continue
		var enemy: Node2D = enemy_obj
		if enemy.global_position.distance_to(center) > radius:
			continue
		if enemy.has_node("HealthComponent"):
			var hc: Node = enemy.get_node("HealthComponent")
			if hc != null and hc.has_method("take_damage"):
				hc.call("take_damage", damage)
		if enemy.has_method("apply_status"):
			enemy.apply_status("freeze", 0.6 * duration_amp, 0.0)
			enemy.apply_status("slow", 1.0 * duration_amp, 0.4)
