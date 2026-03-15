extends SkillEBase
class_name SkillWindE

var storm_eye_radius: float = 160.0
var storm_eye_damage: int = 36
var storm_eye_pull_force: float = 540.0
var dash_distance: float = 260.0
var path_slash_width: float = 54.0
var path_slash_damage: int = 28
var return_slash_delay: float = 0.14
var return_slash_damage_scale: float = 0.72

const WIND_ACTIVE_META: String = "wind_path_active_until_msec"
const WIND_E_GUST_META: String = "wind_e_gust_until_msec"

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

	var damage_amp: float = get_e_damage_amp(0.42, 0.36)
	var duration_amp: float = get_e_duration_amp(0.38)
	var enhanced: bool = is_f_window_active()
	var recent_asset := get_recent_q_asset("", 8000)
	var path_points: Array[Vector2] = get_q_asset_points(recent_asset)
	if path_points.size() < 2:
		path_points = get_recent_draw_points(8.0)
	var q_combo_active: bool = _is_wind_path_active() or path_points.size() >= 2
	var is_closed: bool = _is_asset_closed(recent_asset)

	var context_center: Vector2 = skill_owner.global_position
	var context_radius: float = storm_eye_radius
	var mode: String = "wind_step"
	var synergy_used: bool = false

	if is_closed and path_points.size() >= 3:
		context_center = _points_center(path_points)
		context_radius = _points_radius(path_points, context_center)
		synergy_used = _trigger_eye_fold(path_points, damage_amp, duration_amp, enhanced)
		mode = "eye_fold"
	elif path_points.size() >= 2:
		context_center = path_points[path_points.size() - 1]
		context_radius = max(storm_eye_radius, _points_radius(path_points, _points_center(path_points)))
		synergy_used = _trigger_route_return(path_points, damage_amp, duration_amp, enhanced)
		mode = "route_return"
	else:
		synergy_used = _trigger_wind_step_fallback(damage_amp, duration_amp, enhanced)

	var gust_window: float = 1.8 + (0.7 if q_combo_active else 0.0) + (0.4 if enhanced else 0.0)
	skill_owner.set_meta(WIND_E_GUST_META, Time.get_ticks_msec() + int(round(gust_window * 1000.0)))
	publish_e_context(
		context_center,
		context_radius,
		"wind_route_rewrite",
		{
			"mode": mode,
			"synergy_used": synergy_used,
			"q_combo_active": q_combo_active,
			"closed_path": is_closed,
		},
		"wind_route_rewrite",
		gust_window
	)
	Global.on_camera_shake.emit(6.4, 0.14)
	start_cooldown()

func _trigger_wind_step_fallback(damage_amp: float, duration_amp: float, enhanced: bool) -> bool:
	var start: Vector2 = skill_owner.global_position
	var aim_dir: Vector2 = get_aim_direction()
	var finish: Vector2 = start + aim_dir * dash_distance
	skill_owner.global_position = finish
	spawn_transient_polyline([start, finish], Color(0.62, 1.28, 1.34, 0.96), 12.0, 0.24)
	_apply_line_slash(
		start,
		finish,
		path_slash_width * 0.72,
		max(1, int(round(float(path_slash_damage) * damage_amp))),
		duration_amp,
		finish,
		storm_eye_pull_force * 0.16
	)
	get_tree().create_timer(return_slash_delay * (0.8 if enhanced else 1.0)).timeout.connect(
		_on_fallback_return_timeout.bind(finish, start, damage_amp, duration_amp, enhanced)
	)
	Global.spawn_floating_text(finish, "WIND STEP", Color(0.62, 1.28, 1.34))
	return true

func _on_fallback_return_timeout(
	from_pos: Vector2,
	to_pos: Vector2,
	damage_amp: float,
	duration_amp: float,
	enhanced: bool
) -> void:
	spawn_transient_polyline([from_pos, to_pos], Color(0.86, 1.45, 1.5, 0.95), 10.0, 0.24)
	_apply_line_slash(
		from_pos,
		to_pos,
		path_slash_width * (1.05 if enhanced else 0.9),
		max(1, int(round(float(path_slash_damage) * return_slash_damage_scale * damage_amp * (1.15 if enhanced else 1.0)))),
		duration_amp,
		to_pos,
		storm_eye_pull_force * 0.22
	)
	Global.spawn_floating_text(to_pos, "RETURN GUST", Color(0.84, 1.44, 1.5))

func _trigger_route_return(
	path_points: Array[Vector2],
	damage_amp: float,
	duration_amp: float,
	enhanced: bool
) -> bool:
	var move_start: Vector2 = skill_owner.global_position
	var raw_target: Vector2 = path_points[path_points.size() - 1]
	var move_end: Vector2 = _clamp_move_target(move_start, raw_target, dash_distance * (1.35 if enhanced else 1.15))
	skill_owner.global_position = move_end

	spawn_transient_polyline(path_points, Color(0.58, 1.24, 1.34, 0.95), 13.0, 0.4)
	spawn_transient_ring(raw_target, storm_eye_radius * 0.42, Color(0.84, 1.44, 1.5, 0.86), 8.0, 0.28)

	var hit_count: int = 0
	var forward_damage: int = max(1, int(round(float(path_slash_damage) * damage_amp)))
	for i in range(path_points.size() - 1):
		hit_count += _apply_line_slash(
			path_points[i],
			path_points[i + 1],
			path_slash_width,
			forward_damage,
			duration_amp,
			path_points[i + 1],
			storm_eye_pull_force * 0.12
		)
	if move_end.distance_to(raw_target) > 8.0:
		spawn_transient_polyline([move_start, move_end], Color(0.8, 1.38, 1.46, 0.84), 8.0, 0.22)

	get_tree().create_timer(return_slash_delay * (0.75 if enhanced else 1.0)).timeout.connect(
		_on_route_return_timeout.bind(path_points.duplicate(), damage_amp, duration_amp, enhanced)
	)
	_refund_q_cooldown(1.0)
	Global.spawn_floating_text(raw_target, "FOLD THE GALE", Color(0.7, 1.36, 1.44))
	return hit_count > 0

func _on_route_return_timeout(
	path_points: Array[Vector2],
	damage_amp: float,
	duration_amp: float,
	enhanced: bool
) -> void:
	if path_points.size() < 2:
		return
	var reversed_points: Array[Vector2] = path_points.duplicate()
	reversed_points.reverse()
	spawn_transient_polyline(reversed_points, Color(0.9, 1.5, 1.56, 0.96), 11.0, 0.28)
	var return_damage: int = max(1, int(round(float(path_slash_damage) * return_slash_damage_scale * damage_amp * (1.2 if enhanced else 1.0))))
	for i in range(reversed_points.size() - 1):
		_apply_line_slash(
			reversed_points[i],
			reversed_points[i + 1],
			path_slash_width * 1.08,
			return_damage,
			duration_amp,
			reversed_points[i + 1],
			storm_eye_pull_force * 0.18
		)
	Global.spawn_floating_text(reversed_points[reversed_points.size() - 1], "CUT BACK", Color(0.88, 1.48, 1.54))

func _trigger_eye_fold(
	path_points: Array[Vector2],
	damage_amp: float,
	duration_amp: float,
	enhanced: bool
) -> bool:
	var center: Vector2 = _points_center(path_points)
	var radius: float = _points_radius(path_points, center)
	spawn_transient_polyline(path_points, Color(0.52, 1.18, 1.28, 0.92), 12.0, 0.42, true)
	spawn_transient_ring(center, radius * 0.92, Color(0.84, 1.44, 1.52, 0.96), 9.0, 0.4)

	var hit_count: int = 0
	for enemy in _get_enemies_in_radius(center, radius):
		apply_damage(enemy, max(1, int(round(float(storm_eye_damage) * 0.72 * damage_amp))))
		apply_status(enemy, "slow", 1.0 * duration_amp, 0.34, 1, 0.1)
		_apply_pull(enemy, center, storm_eye_pull_force * 0.24)
		hit_count += 1

	var aim_dir: Vector2 = get_aim_direction()
	get_tree().create_timer(0.16 if not enhanced else 0.12).timeout.connect(
		_on_eye_fold_recut_timeout.bind(center, radius, aim_dir, damage_amp, duration_amp, enhanced)
	)
	_refund_q_cooldown(1.2)
	Global.spawn_floating_text(center, "EYE COLLAPSE x%d" % hit_count, Color(0.84, 1.44, 1.52))
	return hit_count > 0

func _on_eye_fold_recut_timeout(
	center: Vector2,
	radius: float,
	aim_dir: Vector2,
	damage_amp: float,
	duration_amp: float,
	enhanced: bool
) -> void:
	var main_dir: Vector2 = aim_dir.normalized()
	if main_dir.length_squared() <= 0.001:
		main_dir = Vector2.RIGHT
	var side_dir: Vector2 = Vector2(-main_dir.y, main_dir.x)
	var slash_damage: int = max(1, int(round(float(storm_eye_damage) * 0.58 * damage_amp)))

	var main_start: Vector2 = center + main_dir * radius * 1.02
	var main_end: Vector2 = center - main_dir * radius * 1.02
	spawn_transient_polyline([main_start, main_end], Color(0.94, 1.54, 1.6, 0.96), 12.0, 0.24)
	_apply_line_slash(main_start, main_end, path_slash_width * 1.08, slash_damage, duration_amp, center, storm_eye_pull_force * 0.12)

	var side_start: Vector2 = center + side_dir * radius * 0.9
	var side_end: Vector2 = center - side_dir * radius * 0.9
	spawn_transient_polyline([side_start, side_end], Color(0.84, 1.46, 1.54, 0.92), 10.0, 0.22)
	_apply_line_slash(side_start, side_end, path_slash_width * 0.92, max(1, int(round(float(slash_damage) * 0.88))), duration_amp, center, storm_eye_pull_force * 0.1)

	if enhanced:
		var diag_a: Vector2 = (main_dir + side_dir).normalized()
		var diag_b: Vector2 = (main_dir - side_dir).normalized()
		var diag_dirs: Array[Vector2] = [diag_a, diag_b]
		for diag_dir: Vector2 in diag_dirs:
			var start: Vector2 = center + diag_dir * radius * 0.94
			var finish: Vector2 = center - diag_dir * radius * 0.94
			spawn_transient_polyline([start, finish], Color(0.98, 1.58, 1.62, 0.9), 8.0, 0.2)
			_apply_line_slash(start, finish, path_slash_width * 0.72, max(1, int(round(float(slash_damage) * 0.72))), duration_amp, center, storm_eye_pull_force * 0.08)
	Global.spawn_floating_text(center, "CUT BACK", Color(0.94, 1.54, 1.6))

func _apply_line_slash(
	start: Vector2,
	finish: Vector2,
	width: float,
	damage: int,
	duration_amp: float,
	pull_target: Vector2,
	pull_force: float
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
		apply_status(enemy, "slow", 1.0 * duration_amp, 0.32, 1, 0.1)
		_apply_pull(enemy, pull_target, pull_force)
		hit_count += 1
	return hit_count

func _is_asset_closed(asset: Dictionary) -> bool:
	if not asset.is_empty():
		var payload_var: Variant = asset.get("payload", {})
		if payload_var is Dictionary:
			return bool((payload_var as Dictionary).get("is_closed", false))
	return is_recent_draw_closed(8.0)

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

func _apply_pull(enemy: Node2D, target_pos: Vector2, force: float) -> void:
	if enemy == null or not is_instance_valid(enemy):
		return
	var pull_dir: Vector2 = target_pos - enemy.global_position
	if pull_dir.length_squared() <= 0.001:
		return
	var safe_dir: Vector2 = pull_dir.normalized()
	if enemy.has_method("apply_knockback"):
		enemy.call("apply_knockback", safe_dir, force)
	else:
		enemy.global_position += safe_dir * min(28.0, force * 0.012)

func _clamp_move_target(origin: Vector2, target: Vector2, max_distance: float) -> Vector2:
	var offset: Vector2 = target - origin
	if offset.length() <= max_distance:
		return target
	if offset.length_squared() <= 0.001:
		return origin
	return origin + offset.normalized() * max_distance

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

func _is_wind_path_active() -> bool:
	if not is_instance_valid(skill_owner):
		return false
	if not skill_owner.has_meta(WIND_ACTIVE_META):
		return false
	var expire_msec: int = int(skill_owner.get_meta(WIND_ACTIVE_META, 0))
	return Time.get_ticks_msec() <= expire_msec

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
