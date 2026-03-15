extends "res://scenes/skills/skill_f_base.gd"

const ROLE_ID: String = "hexwarden"

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
		_apply_status_burst(q_center, q_radius * 0.82, 5, "curse", 1.4, max(1.0, base_damage * 0.11))
		_pull_enemies_burst(q_center, q_radius * 0.74, 5, 10.0)
		_emit_hex_lattice(q_center, q_dir, q_radius * 1.24, true)
		_line_slice_burst(
			q_center - q_dir * q_line_len * 0.56,
			q_center + q_dir * q_line_len * 0.56,
			16.0,
			0.22,
			"curse",
			1.1,
			max(1.0, base_damage * 0.08),
			true,
			130.0
		)
		_schedule_line_sweep_sequence(
			q_center,
			q_side,
			q_radius * 1.20,
			14.0,
			2,
			0.13,
			12.0,
			0.18,
			"marked",
			1.0,
			0.18,
			true,
			120.0
		)
	else:
		_line_slice_burst(
			q_center - q_side * q_line_len * 0.34,
			q_center + q_side * q_line_len * 0.34,
			12.0,
			0.14,
			"marked",
			0.8,
			0.16,
			true,
			80.0
		)

func _role_signature(phase: String, packet: Dictionary, center: Vector2) -> void:
	_signature_hexwarden(phase, packet, center)
	var radius: float = max(90.0, float(packet.get("radius", 120.0)) * 0.94)
	var base_damage: float = _get_player_base_damage()
	var aim_dir: Vector2 = _get_player_aim_direction()
	var side_dir: Vector2 = Vector2(-aim_dir.y, aim_dir.x)
	if phase == "line":
		_emit_hex_lattice(center, aim_dir, radius * 1.08, false)
		_apply_status_burst(center, radius * 0.70, 4, "marked", 1.0, 0.16)
		_line_slice_burst(
			center - side_dir * radius * 0.56,
			center + side_dir * radius * 0.56,
			12.0,
			0.14,
			"marked",
			0.8,
			0.16,
			true,
			90.0
		)
	elif phase == "closure":
		_emit_hex_lattice(center, aim_dir, radius * 1.28, true)
		_apply_status_burst(center, radius * 0.90, 6, "curse", 1.3, max(1.0, base_damage * 0.10))
		_schedule_line_sweep_sequence(
			center,
			aim_dir,
			radius * 1.28,
			16.0,
			2,
			0.12,
			13.0,
			0.20,
			"curse",
			1.0,
			max(1.0, base_damage * 0.07),
			true,
			130.0
		)
		_schedule_line_sweep_sequence(
			center,
			side_dir,
			radius * 1.10,
			12.0,
			1,
			0.14,
			11.0,
			0.16,
			"marked",
			0.9,
			0.16,
			true,
			100.0
		)

func _emit_hex_lattice(center: Vector2, aim_dir: Vector2, length: float, closure_phase: bool) -> void:
	var dir: Vector2 = aim_dir
	if dir.length_squared() <= 0.001:
		dir = Vector2.RIGHT
	var side: Vector2 = Vector2(-dir.y, dir.x)
	var half_len: float = max(80.0, length * 0.5)
	_line_slice_burst(
		center - dir * half_len,
		center + dir * half_len,
		12.0,
		0.14 if not closure_phase else 0.22,
		"marked",
		0.9,
		0.16,
		true,
		90.0
	)
	_line_slice_burst(
		center - side * half_len * 0.86,
		center + side * half_len * 0.86,
		12.0,
		0.14 if not closure_phase else 0.22,
		"curse",
		1.0,
		max(1.0, _get_player_base_damage() * 0.06),
		true,
		100.0
	)
	if closure_phase:
		_schedule_line_sweep_sequence(
			center,
			dir.rotated(0.52),
			half_len * 1.6,
			14.0,
			1,
			0.10,
			12.0,
			0.20,
			"curse",
			1.0,
			max(1.0, _get_player_base_damage() * 0.07),
			true,
			120.0
		)
		_schedule_line_sweep_sequence(
			center,
			dir.rotated(-0.52),
			half_len * 1.6,
			14.0,
			1,
			0.10,
			12.0,
			0.20,
			"curse",
			1.0,
			max(1.0, _get_player_base_damage() * 0.07),
			true,
			120.0
		)
