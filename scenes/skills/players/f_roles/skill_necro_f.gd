extends "res://scenes/skills/skill_f_base.gd"

const ROLE_ID: String = "necro"
const GRAVE_META_CENTER: String = "necro_grave_center"
const GRAVE_META_RADIUS: String = "necro_grave_radius"
const GRAVE_META_EXPIRE_MSEC: String = "necro_grave_expire_msec"

func _resolve_f_role_id() -> String:
	return ROLE_ID

func _apply_mode_signature(phase: String, packet: Dictionary, center: Vector2, _hit_count: int) -> void:
	if not is_active:
		return
	_role_signature(phase, packet, center)

func _apply_q_link_signature(phase: String, packet: Dictionary, center: Vector2) -> void:
	if phase == "tick":
		return
	var q_ctx: Dictionary = _resolve_recent_q_context()
	if q_ctx.is_empty():
		return

	var q_center_raw: Variant = q_ctx.get("center", center)
	var q_center: Vector2 = q_center_raw if q_center_raw is Vector2 else center
	var q_radius: float = max(90.0, float(q_ctx.get("radius", float(packet.get("radius", 140.0)))))
	var q_closed: bool = bool(q_ctx.get("is_closed", false))
	var base_damage: float = _get_player_base_damage()
	var q_dir: Vector2 = _get_player_aim_direction()
	if q_dir.length_squared() <= 0.001:
		q_dir = Vector2.RIGHT
	var q_side: Vector2 = Vector2(-q_dir.y, q_dir.x)
	var q_line_len: float = q_radius * 1.18

	if q_closed:
		_apply_status_burst(q_center, q_radius * 0.82, 5, "curse", 1.2, max(1.0, base_damage * 0.12))
		_line_slice_burst(q_center - q_dir * q_line_len * 0.54, q_center + q_dir * q_line_len * 0.54, 18.0, 0.24, "curse", 1.2, max(1.0, base_damage * 0.10), true, 170.0)
		_schedule_line_sweep_sequence(
			q_center,
			Vector2(-q_dir.y, q_dir.x),
			q_radius * 1.28,
			26.0,
			2,
			0.10,
			14.0,
			0.22,
			"curse",
			1.1,
			max(1.0, base_damage * 0.09),
			true,
			150.0
		)
		if _is_grave_window():
			_pull_enemies_burst(q_center, q_radius * 0.88, 6, 16.0)
			_apply_status_burst(q_center, q_radius * 0.74, 4, "slow", 1.1, 0.32)
	else:
		_line_slice_burst(q_center - q_side * q_line_len * 0.42, q_center + q_side * q_line_len * 0.42, 14.0, 0.18, "curse", 0.9, max(1.0, base_damage * 0.06), true, 120.0)
		if _is_grave_window():
			_schedule_line_sweep_sequence(
				q_center,
				q_dir,
				q_radius * 1.08,
				22.0,
				1,
				0.10,
				12.0,
				0.18,
				"curse",
				0.9,
				max(1.0, base_damage * 0.07),
				true,
				110.0
			)

func _role_signature(phase: String, packet: Dictionary, center: Vector2) -> void:
	var radius: float = max(95.0, float(packet.get("radius", 120.0)) * 1.02)
	var targets: Array = _sort_enemies_by_distance(_get_enemies_in_radius(center, radius), center)
	if targets.is_empty():
		return
	var max_targets: int = 2 if phase == "tick" else (4 if phase == "line" else 6)
	var refs: Array = []
	for i: int in range(min(max_targets, targets.size())):
		var enemy: Node = targets[i]
		_apply_enemy_status(enemy, "curse", 1.5 + (0.4 if phase == "closure" else 0.0), max(1.0, _get_player_base_damage() * 0.14), 1, 0.6)
		refs.append(weakref(enemy))
	var reap_delay: float = 0.46 if phase != "closure" else 0.33
	var reap_scale: float = 0.38 if phase != "closure" else 0.62
	get_tree().create_timer(reap_delay).timeout.connect(_on_necro_reap_timeout.bind(refs, reap_scale, center))
	var necro_dir: Vector2 = _get_player_aim_direction()
	if phase == "line":
		_schedule_line_sweep_sequence(
			center,
			necro_dir,
			radius * 1.45,
			34.0,
			2,
			0.12,
			15.0,
			0.24,
			"curse",
			1.1,
			max(1.0, _get_player_base_damage() * 0.09),
			true,
			150.0
		)
	elif phase == "closure":
		_pull_enemies_burst(center, radius * 0.78, 6, 18.0)
		_apply_status_burst(center, radius * 0.70, 4, "slow", 1.0, 0.28)
		_spawn_parallel_wall_pair(
			center,
			necro_dir,
			radius * 1.20,
			44.0,
			1.0,
			int(max(1.0, _get_player_base_damage() * 0.16)),
			Color(0.74, 0.38, 0.9, 0.62)
		)
		_schedule_line_sweep_sequence(
			center,
			necro_dir,
			radius * 1.6,
			40.0,
			3,
			0.10,
			16.0,
			0.30,
			"curse",
			1.3,
			max(1.0, _get_player_base_damage() * 0.11),
			true,
			180.0
		)
		_schedule_line_sweep_sequence(
			center,
			Vector2(-necro_dir.y, necro_dir.x),
			radius * 1.35,
			32.0,
			2,
			0.14,
			14.0,
			0.22,
			"slow",
			1.0,
			0.24,
			true,
			120.0
		)
		_schedule_reap_echo(center, radius, 0.22, 0.36)
	elif phase == "line":
		_schedule_reap_echo(center, radius * 0.85, 0.26, 0.24)

func _is_grave_window() -> bool:
	if not is_instance_valid(player_ref):
		return false
	if not player_ref.has_meta(GRAVE_META_EXPIRE_MSEC):
		return false
	var expire_msec: int = int(player_ref.get_meta(GRAVE_META_EXPIRE_MSEC, 0))
	return Time.get_ticks_msec() <= expire_msec

func _schedule_reap_echo(center: Vector2, radius: float, delay_sec: float, scale: float) -> void:
	var safe_radius: float = max(80.0, radius)
	var safe_scale: float = clamp(scale, 0.1, 1.0)
	get_tree().create_timer(max(0.05, delay_sec)).timeout.connect(
		_on_reap_echo_timeout.bind(center, safe_radius, safe_scale)
	)

func _on_reap_echo_timeout(center: Vector2, radius: float, scale: float) -> void:
	if not is_active:
		return
	var base_damage: float = _get_player_base_damage()
	_apply_status_burst(center, radius * 0.72, 4, "curse", 1.1, max(1.0, base_damage * 0.10 * scale))
	_line_slice_burst(
		center + Vector2.LEFT * radius * 0.45,
		center + Vector2.RIGHT * radius * 0.45,
		16.0,
		0.18,
		"curse",
		1.0,
		max(1.0, base_damage * 0.08 * scale),
		true,
		130.0
	)
