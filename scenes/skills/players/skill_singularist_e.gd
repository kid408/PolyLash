extends SkillEBase
class_name SkillSingularistE

var singularist_radius: float = 300.0
var anchor_capture_radius: float = 150.0
var polarity_line_width: float = 58.0
var polarity_slingshot_delay: float = 0.18
var polarity_pull_force: float = 24.0
var polarity_push_force: float = 34.0

const VACUUM_META_CENTER: String = "singularist_vortex_center"
const VACUUM_META_RADIUS: String = "singularist_vortex_radius"
const VACUUM_META_EXPIRE_MSEC: String = "singularist_vortex_expire_msec"

func execute() -> void:
	if not can_execute():
		return
	if not consume_energy():
		if is_instance_valid(skill_owner):
			Global.spawn_floating_text(skill_owner.global_position, "No Energy!", Color.RED)
		return
	if not is_instance_valid(skill_owner):
		return

	var duration_amp: float = get_e_duration_amp(0.36)
	var damage_amp: float = get_e_damage_amp(0.24, 0.32)
	var recent_asset := get_recent_q_asset("", 8000)
	var path_points: Array[Vector2] = get_q_asset_points(recent_asset)
	if path_points.size() < 2:
		path_points = get_recent_draw_points(8.0)
	var anchor_points: Array[Vector2] = _get_asset_anchor_points(recent_asset)
	if anchor_points.is_empty():
		anchor_points = _find_runtime_anchor_points()

	var is_closed: bool = _is_asset_closed(recent_asset)
	var context_center: Vector2 = skill_owner.global_position
	var context_radius: float = singularist_radius * 0.42
	var mode: String = "self_polarity"
	var synergy_used: bool = false

	if is_closed and path_points.size() >= 3:
		context_center = _points_center(path_points)
		context_radius = _points_radius(path_points, context_center)
		synergy_used = _trigger_vortex_collapse(path_points, damage_amp, duration_amp)
		mode = "vortex_collapse"
	elif not anchor_points.is_empty() or path_points.size() >= 2:
		var route_points: Array[Vector2] = []
		if path_points.size() >= 2:
			route_points = path_points
		else:
			route_points = anchor_points.duplicate()
		var focus_points: Array[Vector2] = []
		if not anchor_points.is_empty():
			focus_points = anchor_points
		else:
			focus_points = route_points.duplicate()
		context_center = focus_points[focus_points.size() - 1]
		var radius_points: Array[Vector2] = []
		if route_points.size() >= 2:
			radius_points = route_points
		else:
			radius_points = focus_points
		context_radius = max(120.0, _points_radius(radius_points, _points_center(radius_points)))
		synergy_used = _trigger_anchor_rewrite(focus_points, route_points, damage_amp, duration_amp)
		mode = "anchor_rewrite"
	else:
		synergy_used = _trigger_personal_polarity(damage_amp, duration_amp)

	publish_e_context(
		context_center,
		context_radius,
		"singularist_polarity",
		{
			"mode": mode,
			"synergy_used": synergy_used,
			"anchor_count": anchor_points.size(),
			"closed_path": is_closed,
		},
		"singularist_polarity_window",
		2.2 + (0.6 if synergy_used else 0.0)
	)
	Global.on_camera_shake.emit(7.0, 0.16)
	start_cooldown()

func _trigger_personal_polarity(damage_amp: float, duration_amp: float) -> bool:
	var center: Vector2 = skill_owner.global_position
	var radius: float = singularist_radius * 0.42
	spawn_transient_ring(center, radius, Color(0.74, 0.52, 1.0, 0.92), 8.0, 0.34)
	var hit_count: int = 0
	for enemy in _get_enemies_in_radius(center, radius):
		apply_damage(enemy, max(1, int(round(22.0 * damage_amp))))
		apply_status(enemy, "slow", 1.0 * duration_amp, 0.3, 1, 0.1)
		_apply_pull_towards(enemy, center, polarity_pull_force + 8.0 * duration_amp)
		hit_count += 1
	get_tree().create_timer(0.18 if not is_f_window_active() else 0.12).timeout.connect(
		_on_personal_polarity_flip_timeout.bind(center, radius, damage_amp, duration_amp)
	)
	if hit_count > 0:
		Global.spawn_floating_text(center, "POLARITY PULSE x%d" % hit_count, Color(0.74, 0.58, 1.0))
	else:
		Global.spawn_floating_text(center, "POLARITY PULSE", Color(0.74, 0.58, 1.0))
	return true

func _on_personal_polarity_flip_timeout(center: Vector2, radius: float, damage_amp: float, duration_amp: float) -> void:
	var spoke_count: int = 4 + (2 if is_f_window_active() else 0)
	for i in range(spoke_count):
		var angle: float = TAU * float(i) / float(max(1, spoke_count))
		var dir: Vector2 = Vector2.RIGHT.rotated(angle)
		var finish: Vector2 = center + dir * radius * 1.12
		spawn_transient_polyline([center, finish], Color(0.92, 0.72, 1.0, 0.95), 9.0, 0.24)
		_apply_line_push_pass(
			center,
			finish,
			polarity_line_width * 0.45,
			max(1, int(round(18.0 * damage_amp))),
			duration_amp,
			dir,
			polarity_push_force + 4.0
		)
	Global.spawn_floating_text(center, "PHASE FLIP", Color(0.92, 0.7, 1.0))

func _trigger_anchor_rewrite(
	anchor_points: Array[Vector2],
	route_points: Array[Vector2],
	damage_amp: float,
	duration_amp: float
) -> bool:
	var primary: Vector2 = anchor_points[anchor_points.size() - 1]
	var display_route: Array[Vector2] = []
	if route_points.size() >= 2:
		display_route = route_points
	else:
		display_route = anchor_points.duplicate()
	if display_route.size() >= 2:
		spawn_transient_polyline(display_route, Color(0.7, 0.46, 0.98, 0.95), 12.0, 0.4)
	if anchor_points.size() >= 2:
		spawn_transient_polyline(anchor_points, Color(0.9, 0.72, 1.0, 0.86), 9.0, 0.34)
	for point: Vector2 in anchor_points:
		if point == primary:
			continue
		spawn_transient_polyline([point, primary], Color(0.88, 0.72, 1.0, 0.9), 6.0, 0.22)
	spawn_transient_ring(primary, anchor_capture_radius * 0.7, Color(0.96, 0.78, 1.0, 0.94), 8.0, 0.32)

	var hit_count: int = 0
	var route_damage: int = max(1, int(round(24.0 * damage_amp)))
	for i in range(display_route.size() - 1):
		hit_count += _apply_line_pull_pass(
			display_route[i],
			display_route[i + 1],
			polarity_line_width,
			route_damage,
			duration_amp,
			primary,
			polarity_pull_force + 6.0
		)
	for point: Vector2 in anchor_points:
		hit_count += _capture_anchor_space(
			point,
			anchor_capture_radius,
			max(1, int(round(14.0 * damage_amp))),
			duration_amp,
			primary
		)

	var exit_dir: Vector2 = get_aim_direction()
	if display_route.size() >= 2:
		exit_dir = (display_route[display_route.size() - 1] - display_route[display_route.size() - 2]).normalized()
	if exit_dir.length_squared() <= 0.001:
		exit_dir = Vector2.RIGHT
	get_tree().create_timer(polarity_slingshot_delay * (0.8 if is_f_window_active() else 1.0)).timeout.connect(
		_on_anchor_slingshot_timeout.bind(display_route.duplicate(), primary, exit_dir, damage_amp, duration_amp)
	)
	_refund_q_cooldown(1.0)
	Global.spawn_floating_text(primary, "SWITCH THE ANCHOR", Color(0.92, 0.76, 1.0))
	return hit_count > 0

func _on_anchor_slingshot_timeout(
	route_points: Array[Vector2],
	primary: Vector2,
	exit_dir: Vector2,
	damage_amp: float,
	duration_amp: float
) -> void:
	var sling_route: Array[Vector2] = route_points.duplicate()
	if sling_route.size() >= 2:
		sling_route.reverse()
		spawn_transient_polyline(sling_route, Color(1.0, 0.84, 1.0, 0.95), 11.0, 0.28)
		for i in range(sling_route.size() - 1):
			var seg_dir: Vector2 = (sling_route[i + 1] - sling_route[i]).normalized()
			if seg_dir.length_squared() <= 0.001:
				seg_dir = exit_dir
			_apply_line_push_pass(
				sling_route[i],
				sling_route[i + 1],
				polarity_line_width * 0.84,
				max(1, int(round(22.0 * damage_amp))),
				duration_amp,
				seg_dir,
				polarity_push_force
			)
	var finish: Vector2 = primary + exit_dir.normalized() * 220.0
	spawn_transient_polyline([primary, finish], Color(0.96, 0.8, 1.0, 0.96), 12.0, 0.26)
	_apply_line_push_pass(
		primary,
		finish,
		polarity_line_width * 0.72,
		max(1, int(round(24.0 * damage_amp))),
		duration_amp,
		exit_dir,
		polarity_push_force + 8.0
	)
	Global.spawn_floating_text(primary, "POLARITY SLING", Color(0.96, 0.8, 1.0))

func _trigger_vortex_collapse(points: Array[Vector2], damage_amp: float, duration_amp: float) -> bool:
	var center: Vector2 = _points_center(points)
	var radius: float = _points_radius(points, center)
	spawn_transient_polyline(points, Color(0.68, 0.42, 0.96, 0.92), 12.0, 0.42, true)
	spawn_transient_ring(center, radius * 0.9, Color(0.92, 0.74, 1.0, 0.96), 9.0, 0.4)
	var hit_count: int = 0
	for enemy in _get_enemies_in_radius(center, radius):
		apply_damage(enemy, max(1, int(round(30.0 * damage_amp))))
		apply_status(enemy, "slow", 1.1 * duration_amp, 0.36, 1, 0.1)
		_apply_pull_towards(enemy, center, polarity_pull_force + 10.0)
		hit_count += 1
	get_tree().create_timer(0.16 if not is_f_window_active() else 0.12).timeout.connect(
		_on_vortex_reversal_timeout.bind(center, radius, damage_amp, duration_amp)
	)
	Global.spawn_floating_text(center, "COLLAPSE CORE x%d" % hit_count, Color(0.88, 0.72, 1.0))
	_refund_q_cooldown(1.2)
	return hit_count > 0

func _on_vortex_reversal_timeout(center: Vector2, radius: float, damage_amp: float, duration_amp: float) -> void:
	var spoke_count: int = 5 + (2 if is_f_window_active() else 0)
	spawn_transient_ring(center, radius * 0.42, Color(0.98, 0.84, 1.0, 0.92), 8.0, 0.24)
	for i in range(spoke_count):
		var angle: float = TAU * float(i) / float(max(1, spoke_count))
		var dir: Vector2 = Vector2.RIGHT.rotated(angle)
		var start: Vector2 = center - dir * radius * 0.08
		var finish: Vector2 = center + dir * radius * 1.05
		spawn_transient_polyline([start, finish], Color(0.98, 0.84, 1.0, 0.95), 10.0, 0.24)
		_apply_line_push_pass(
			start,
			finish,
			polarity_line_width * 0.58,
			max(1, int(round(24.0 * damage_amp))),
			duration_amp,
			dir,
			polarity_push_force + 10.0
		)
	Global.spawn_floating_text(center, "REVERSE CASCADE", Color(0.98, 0.84, 1.0))

func _capture_anchor_space(
	center: Vector2,
	radius: float,
	damage: int,
	duration_amp: float,
	primary: Vector2
) -> int:
	var hit_count: int = 0
	for enemy in _get_enemies_in_radius(center, radius):
		apply_damage(enemy, damage)
		apply_status(enemy, "slow", 0.9 * duration_amp, 0.26, 1, 0.1)
		_apply_pull_towards(enemy, primary, polarity_pull_force * 0.7)
		hit_count += 1
	return hit_count

func _apply_line_pull_pass(
	start: Vector2,
	finish: Vector2,
	width: float,
	damage: int,
	duration_amp: float,
	pull_center: Vector2,
	pull_amount: float
) -> int:
	var hit_count: int = 0
	for enemy_obj: Variant in get_tree().get_nodes_in_group("enemies"):
		if enemy_obj == null or not is_instance_valid(enemy_obj):
			continue
		if not (enemy_obj is Node2D):
			continue
		var enemy: Node2D = enemy_obj
		if distance_point_to_segment(enemy.global_position, start, finish) > width:
			continue
		apply_damage(enemy, damage)
		apply_status(enemy, "slow", 0.95 * duration_amp, 0.28, 1, 0.1)
		_apply_pull_towards(enemy, pull_center, pull_amount)
		hit_count += 1
	return hit_count

func _apply_line_push_pass(
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
		if distance_point_to_segment(enemy.global_position, start, finish) > width:
			continue
		apply_damage(enemy, damage)
		apply_status(enemy, "slow", 0.9 * duration_amp, 0.28, 1, 0.1)
		_apply_push(enemy, safe_dir, push_force)
		hit_count += 1
	return hit_count

func _get_asset_anchor_points(asset: Dictionary) -> Array[Vector2]:
	if asset.is_empty():
		return []
	var payload_var: Variant = asset.get("payload", {})
	if not (payload_var is Dictionary):
		return []
	var payload: Dictionary = payload_var
	var points_var: Variant = payload.get("anchor_points", [])
	if not (points_var is Array):
		return []
	var result: Array[Vector2] = []
	for point_var in points_var:
		if point_var is Vector2:
			result.append(point_var)
	return result

func _find_runtime_anchor_points() -> Array[Vector2]:
	var q_skill: Node = get_q_skill()
	if q_skill == null or not is_instance_valid(q_skill):
		return []
	var result: Array[Vector2] = []
	_collect_runtime_anchor_points(q_skill, result)
	return result

func _collect_runtime_anchor_points(node: Node, result: Array[Vector2]) -> void:
	if node == null or not is_instance_valid(node):
		return
	if node.name == "VacuumAnchor" and node is Node2D:
		result.append((node as Node2D).global_position)
	for child_var: Variant in node.get_children():
		if child_var is Node:
			_collect_runtime_anchor_points(child_var, result)

func _is_asset_closed(asset: Dictionary) -> bool:
	if not asset.is_empty():
		var payload_var: Variant = asset.get("payload", {})
		if payload_var is Dictionary:
			return bool((payload_var as Dictionary).get("is_closed", false))
	if _is_vortex_window_active():
		return true
	return is_recent_draw_closed(8.0)

func _is_vortex_window_active() -> bool:
	if not is_instance_valid(skill_owner):
		return false
	if not skill_owner.has_meta(VACUUM_META_EXPIRE_MSEC):
		return false
	var expire_msec: int = int(skill_owner.get_meta(VACUUM_META_EXPIRE_MSEC, 0))
	return Time.get_ticks_msec() <= expire_msec

func _get_enemies_in_radius(center: Vector2, radius: float) -> Array[Node2D]:
	var result: Array[Node2D] = []
	for enemy_obj: Variant in get_tree().get_nodes_in_group("enemies"):
		if enemy_obj == null or not is_instance_valid(enemy_obj):
			continue
		if not (enemy_obj is Node2D):
			continue
		var enemy: Node2D = enemy_obj
		if center.distance_to(enemy.global_position) <= radius:
			result.append(enemy)
	return result

func _apply_pull_towards(enemy: Node2D, center: Vector2, amount: float) -> void:
	if enemy == null or not is_instance_valid(enemy):
		return
	var offset: Vector2 = center - enemy.global_position
	var dist: float = offset.length()
	if dist <= 0.001:
		return
	if enemy.has_method("apply_knockback"):
		enemy.call("apply_knockback", offset / dist, amount * 18.0)
	else:
		enemy.global_position += offset / dist * amount

func _apply_push(enemy: Node2D, dir: Vector2, amount: float) -> void:
	if enemy == null or not is_instance_valid(enemy):
		return
	var safe_dir: Vector2 = dir.normalized()
	if safe_dir.length_squared() <= 0.001:
		safe_dir = Vector2.RIGHT
	if enemy.has_method("apply_knockback"):
		enemy.call("apply_knockback", safe_dir, amount * 18.0)
	else:
		enemy.global_position += safe_dir * amount

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
	return max(60.0, radius)

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
