extends "res://scenes/skills/skill_f_base.gd"

const ROLE_ID: String = "stormseer"

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
	var q_dir: Vector2 = _get_player_aim_direction()
	if q_dir.length_squared() <= 0.001:
		q_dir = Vector2.RIGHT
	var q_side: Vector2 = Vector2(-q_dir.y, q_dir.x)
	var q_line_len: float = q_radius * 1.18

	if q_closed:
		_pull_enemies_burst(q_center, q_radius * 0.96, 6, 20.0)
		_apply_status_burst(q_center, q_radius * 0.86, 5, "slow", 1.2, 0.28)
		_schedule_line_sweep_sequence(
			q_center,
			q_dir,
			q_radius * 1.64,
			26.0,
			3,
			0.09,
			18.0,
			0.30,
			"slow",
			1.0,
			0.24,
			true,
			220.0
		)
		_schedule_line_sweep_sequence(
			q_center,
			q_side,
			q_radius * 1.36,
			18.0,
			2,
			0.12,
			14.0,
			0.22,
			"slow",
			0.9,
			0.20,
			true,
			170.0
		)
	else:
		_line_slice_burst(
			q_center - q_side * q_line_len * 0.54,
			q_center + q_side * q_line_len * 0.54,
			14.0,
			0.16,
			"slow",
			0.8,
			0.20,
			true,
			120.0
		)
		_gain_energy(1.8)

func _role_signature(phase: String, packet: Dictionary, center: Vector2) -> void:
	_signature_stormseer(phase, packet, center)
	var radius: float = max(92.0, float(packet.get("radius", 120.0)) * 0.96)
	var aim_dir: Vector2 = _get_player_aim_direction()
	var side_dir: Vector2 = Vector2(-aim_dir.y, aim_dir.x)
	if phase == "line":
		_pull_enemies_burst(center, radius * 0.74, 5, 12.0)
		_line_slice_burst(
			center - side_dir * radius * 0.58,
			center + side_dir * radius * 0.58,
			14.0,
			0.14,
			"slow",
			0.8,
			0.18,
			true,
			120.0
		)
	elif phase == "closure":
		_pull_enemies_burst(center, radius * 0.90, 7, 18.0)
		_apply_status_burst(center, radius * 0.82, 5, "slow", 1.1, 0.26)
		_schedule_line_sweep_sequence(
			center,
			aim_dir,
			radius * 1.56,
			24.0,
			2,
			0.10,
			16.0,
			0.26,
			"slow",
			0.9,
			0.22,
			true,
			200.0
		)
		_schedule_line_sweep_sequence(
			center,
			side_dir,
			radius * 1.26,
			18.0,
			2,
			0.13,
			14.0,
			0.20,
			"slow",
			0.8,
			0.18,
			true,
			160.0
		)
