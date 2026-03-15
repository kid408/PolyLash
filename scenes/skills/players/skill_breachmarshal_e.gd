extends SkillEBase
class_name SkillBreachmarshalE

var blind_radius: float = 200.0
var blind_duration: float = 2.5
var breach_length: float = 260.0
var breach_width: float = 64.0
var breach_delay: float = 0.18
var breach_push_force: float = 26.0

const RAIL_META_CENTER: String = "breachmarshal_rail_center"
const RAIL_META_RADIUS: String = "breachmarshal_rail_radius"
const RAIL_META_EXPIRE_MSEC: String = "breachmarshal_rail_expire_msec"

func execute() -> void:
	if not can_execute():
		return
	if not consume_energy():
		if is_instance_valid(skill_owner):
			Global.spawn_floating_text(skill_owner.global_position, "No Energy!", Color.RED)
		return
	if not is_instance_valid(skill_owner):
		return

	var damage_amp: float = get_e_damage_amp(0.24, 0.34)
	var duration_amp: float = get_e_duration_amp(0.34)
	var recent_asset := get_recent_q_asset("", 8000)
	var rail_points: Array[Vector2] = get_q_asset_points(recent_asset)
	if rail_points.size() < 2:
		rail_points = get_recent_draw_points(8.0)

	var context_center: Vector2 = skill_owner.global_position
	var context_radius: float = blind_radius
	var mode: String = "shoulder_breach"
	var synergy_used: bool = false

	if rail_points.size() >= 2 and _is_asset_closed(recent_asset):
		synergy_used = _trigger_yard_lock(rail_points, damage_amp, duration_amp)
		context_center = _points_center(rail_points)
		context_radius = _points_radius(rail_points, context_center)
		mode = "yard_lock"
	elif rail_points.size() >= 2:
		synergy_used = _trigger_rail_breach(rail_points, damage_amp, duration_amp)
		context_center = rail_points[rail_points.size() - 1]
		context_radius = max(blind_radius, _points_radius(rail_points, _points_center(rail_points)))
		mode = "rail_breach"
	else:
		synergy_used = _trigger_shoulder_breach(damage_amp, duration_amp)

	publish_e_context(
		context_center,
		context_radius,
		"breachmarshal_breach",
		{
			"mode": mode,
			"synergy_used": synergy_used,
		},
		"breachmarshal_breach_window",
		1.8 + (0.5 if synergy_used else 0.0)
	)
	Global.on_camera_shake.emit(8.6, 0.18)
	start_cooldown()

func _trigger_shoulder_breach(damage_amp: float, duration_amp: float) -> bool:
	var aim_dir: Vector2 = _get_aim_direction()
	var start: Vector2 = skill_owner.global_position
	var finish: Vector2 = start + aim_dir * breach_length
	spawn_transient_polyline([start, finish], Color(1.0, 0.95, 0.84, 0.96), 14.0, 0.24)
	var hit_count := _apply_line_breach_pass(
		start,
		finish,
		breach_width * 0.58,
		max(1, int(round(38.0 * damage_amp))),
		duration_amp,
		aim_dir,
		breach_push_force
	)
	if hit_count > 0:
		Global.spawn_floating_text(finish, "SHOULDER BREACH x%d" % hit_count, Color(1.0, 0.92, 0.76))
	else:
		Global.spawn_floating_text(finish, "SHOULDER BREACH", Color(1.0, 0.92, 0.76))
	spawn_skill_vfx(finish, Color(0.96, 0.9, 0.78, 0.84), 0.68)
	return true

func _trigger_rail_breach(points: Array[Vector2], damage_amp: float, duration_amp: float) -> bool:
	spawn_transient_polyline(points, Color(0.98, 0.98, 1.0, 0.96), 15.0, 0.4)
	var hit_count: int = 0
	for i in range(points.size() - 1):
		var dir: Vector2 = (points[i + 1] - points[i]).normalized()
		if dir.length_squared() <= 0.001:
			dir = Vector2.RIGHT
		hit_count += _apply_line_breach_pass(
			points[i],
			points[i + 1],
			breach_width,
			max(1, int(round(34.0 * damage_amp))),
			duration_amp,
			dir,
			breach_push_force
		)
	var mouth: Vector2 = points[points.size() - 1]
	spawn_transient_ring(mouth, blind_radius * 0.45, Color(1.0, 0.96, 0.88, 0.88), 8.0, 0.32)
	get_tree().create_timer(breach_delay * (0.8 if is_f_window_active() else 1.0)).timeout.connect(
		_on_rail_return_timeout.bind(points.duplicate(), damage_amp, duration_amp)
	)
	Global.spawn_floating_text(mouth, "RAIL IGNITE", Color(1.0, 0.95, 0.82))
	_refund_q_cooldown(1.0)
	return hit_count > 0

func _on_rail_return_timeout(points: Array[Vector2], damage_amp: float, duration_amp: float) -> void:
	if points.size() < 2:
		return
	var reversed_points: Array[Vector2] = points.duplicate()
	reversed_points.reverse()
	spawn_transient_polyline(reversed_points, Color(1.0, 0.94, 0.88, 0.95), 12.0, 0.28)
	for i in range(reversed_points.size() - 1):
		var dir: Vector2 = (reversed_points[i + 1] - reversed_points[i]).normalized()
		if dir.length_squared() <= 0.001:
			dir = Vector2.LEFT
		_apply_line_breach_pass(
			reversed_points[i],
			reversed_points[i + 1],
			breach_width * 0.82,
			max(1, int(round(28.0 * damage_amp))),
			duration_amp,
			dir,
			-breach_push_force
		)
	if is_instance_valid(skill_owner):
		Global.spawn_floating_text(skill_owner.global_position, "BACKSHOCK", Color(1.0, 0.9, 0.74))

func _trigger_yard_lock(points: Array[Vector2], damage_amp: float, duration_amp: float) -> bool:
	var center: Vector2 = _points_center(points)
	var radius: float = _points_radius(points, center)
	spawn_transient_polyline(points, Color(0.94, 0.94, 1.0, 0.9), 12.0, 0.42, true)
	spawn_transient_ring(center, radius * 0.9, Color(1.0, 0.98, 0.9, 0.95), 9.0, 0.42)
	var hit_count: int = 0
	for enemy: Node2D in _get_enemies_in_radius(center, radius):
		_apply_damage(enemy, max(1, int(round(36.0 * damage_amp))))
		_apply_status(enemy, "silence", blind_duration * duration_amp, 0.0, 1, 0.1)
		_apply_status(enemy, "slow", 1.0 * duration_amp, 0.32, 1, 0.1)
		_apply_pull_towards(enemy, center, breach_push_force)
		hit_count += 1
	get_tree().create_timer(0.16 if not is_f_window_active() else 0.12).timeout.connect(
		_on_yard_rebound_timeout.bind(center, radius, damage_amp, duration_amp)
	)
	Global.spawn_floating_text(center, "YARD LOCK x%d" % hit_count, Color(1.0, 0.96, 0.82))
	_refund_q_cooldown(1.2)
	return hit_count > 0

func _on_yard_rebound_timeout(center: Vector2, radius: float, damage_amp: float, duration_amp: float) -> void:
	var spoke_count: int = 4 + (2 if is_f_window_active() else 0)
	for i in range(spoke_count):
		var angle: float = TAU * float(i) / float(max(1, spoke_count))
		var dir: Vector2 = Vector2.RIGHT.rotated(angle)
		var start: Vector2 = center - dir * radius * 0.12
		var finish: Vector2 = center + dir * radius * 1.05
		spawn_transient_polyline([start, finish], Color(1.0, 0.95, 0.88, 0.94), 10.0, 0.24)
		_apply_line_breach_pass(
			start,
			finish,
			breach_width * 0.5,
			max(1, int(round(30.0 * damage_amp))),
			duration_amp,
			dir,
			breach_push_force + 6.0
		)
	Global.spawn_floating_text(center, "YARD REBOUND", Color(1.0, 0.92, 0.74))

func _get_rail_window(default_center: Vector2, default_radius: float) -> Array:
	var data: Array = [false, default_center, default_radius]
	if not is_instance_valid(skill_owner):
		return data
	if not skill_owner.has_meta(RAIL_META_EXPIRE_MSEC):
		return data
	var expire_msec: int = int(skill_owner.get_meta(RAIL_META_EXPIRE_MSEC, 0))
	if Time.get_ticks_msec() > expire_msec:
		return data
	var center_val: Variant = skill_owner.get_meta(RAIL_META_CENTER, default_center)
	var radius_val: Variant = skill_owner.get_meta(RAIL_META_RADIUS, default_radius)
	if not (center_val is Vector2):
		return data
	data[0] = true
	data[1] = center_val
	data[2] = max(default_radius, float(radius_val))
	return data

func _refund_q_cooldown(seconds: float) -> void:
	if seconds <= 0.0 or not is_instance_valid(skill_owner):
		return
	var skill_manager: Node = skill_owner.get_node_or_null("SkillManager")
	if skill_manager == null or not ("skill_slots" in skill_manager):
		return
	var slots: Dictionary = skill_manager.skill_slots
	if not slots.has("q"):
		return
	var q_skill_obj: Variant = slots.get("q")
	if q_skill_obj == null or not (q_skill_obj is SkillBase):
		return
	var q_skill: SkillBase = q_skill_obj
	var remaining: float = q_skill.get_cooldown_remaining()
	if remaining <= 0.0:
		return
	q_skill.set_cooldown_remaining(max(0.0, remaining - seconds))

func _apply_line_breach_pass(
	start: Vector2,
	finish: Vector2,
	width: float,
	damage: int,
	duration_amp: float,
	push_dir: Vector2,
	push_force: float
) -> int:
	var safe_dir: Vector2 = push_dir.normalized()
	if safe_dir.length_squared() <= 0.001:
		safe_dir = Vector2.RIGHT
	var hit_count: int = 0
	for enemy_obj: Variant in get_tree().get_nodes_in_group("enemies"):
		if enemy_obj == null or not is_instance_valid(enemy_obj):
			continue
		if not (enemy_obj is Node2D):
			continue
		var enemy: Node2D = enemy_obj
		var dist_to_path: float = distance_point_to_segment(enemy.global_position, start, finish)
		if dist_to_path > width:
			continue
		_apply_damage(enemy, damage)
		_apply_status(enemy, "silence", blind_duration * 0.6 * duration_amp, 0.0, 1, 0.1)
		_apply_status(enemy, "slow", 0.9 * duration_amp, 0.28, 1, 0.1)
		if push_force >= 0.0:
			enemy.global_position += safe_dir * push_force
		else:
			enemy.global_position -= safe_dir * absf(push_force)
		hit_count += 1
	return hit_count

func _apply_pull_towards(enemy: Node2D, center: Vector2, amount: float) -> void:
	if enemy == null or not is_instance_valid(enemy):
		return
	var offset: Vector2 = center - enemy.global_position
	var dist: float = offset.length()
	if dist <= 0.001:
		return
	enemy.global_position += offset / dist * amount

func _is_asset_closed(asset: Dictionary) -> bool:
	if not asset.is_empty():
		var payload_var: Variant = asset.get("payload", {})
		if payload_var is Dictionary:
			return bool((payload_var as Dictionary).get("is_closed", false))
	var window_data := _get_rail_window(skill_owner.global_position, blind_radius)
	if bool(window_data[0]):
		return true
	return is_recent_draw_closed(8.0)

func _points_center(points: Array[Vector2]) -> Vector2:
	if points.is_empty():
		return skill_owner.global_position if is_instance_valid(skill_owner) else Vector2.ZERO
	var center: Vector2 = Vector2.ZERO
	for point: Vector2 in points:
		center += point
	return center / float(points.size())

func _points_radius(points: Array[Vector2], center: Vector2) -> float:
	var radius: float = 0.0
	for point: Vector2 in points:
		radius = max(radius, center.distance_to(point))
	return max(48.0, radius)

func _get_aim_direction() -> Vector2:
	if not is_instance_valid(skill_owner):
		return Vector2.RIGHT
	var dir: Vector2 = skill_owner.get_global_mouse_position() - skill_owner.global_position
	if dir.length_squared() <= 0.01:
		return Vector2.RIGHT
	return dir.normalized()

func _get_enemies_in_radius(center: Vector2, radius: float) -> Array:
	var result: Array = []
	for enemy_obj: Variant in get_tree().get_nodes_in_group("enemies"):
		if enemy_obj == null or not is_instance_valid(enemy_obj):
			continue
		if not (enemy_obj is Node2D):
			continue
		var enemy_node: Node2D = enemy_obj
		if center.distance_to(enemy_node.global_position) <= radius:
			result.append(enemy_node)
	return result

func _apply_damage(enemy: Node, amount: int) -> void:
	if not is_instance_valid(enemy):
		return
	if enemy.has_node("HealthComponent"):
		var hc: Node = enemy.get_node("HealthComponent")
		if hc and hc.has_method("take_damage"):
			hc.take_damage(max(1, amount))

func _apply_status(enemy: Node, status_name: String, duration: float, value: float, stacks: int = 1, tick_interval: float = 0.5) -> void:
	if not is_instance_valid(enemy):
		return
	if enemy.has_method("apply_status"):
		enemy.apply_status(status_name, max(0.1, duration), value, max(1, stacks), max(0.05, tick_interval))
