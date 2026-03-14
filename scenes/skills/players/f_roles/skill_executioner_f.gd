extends "res://scenes/skills/players/skill_ultimate_qef_v3.gd"

const ROLE_ID: String = "executioner"

func _resolve_mode_id() -> String:
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
		_apply_status_burst(q_center, q_radius * 0.82, 6, "marked", 1.4, 0.22)
		_knock_enemies_burst(q_center, q_radius * 0.72, 4, 140.0)
		_line_slice_burst(
			q_center - q_dir * q_line_len * 0.56,
			q_center + q_dir * q_line_len * 0.56,
			18.0,
			0.44,
			"marked",
			1.3,
			0.22,
			false,
			180.0
		)
		_line_slice_burst(
			q_center - q_side * q_line_len * 0.46,
			q_center + q_side * q_line_len * 0.46,
			16.0,
			0.32,
			"marked",
			1.1,
			0.20,
			false,
			140.0
		)
	elif phase == "line":
		_line_slice_burst(
			q_center - q_dir * q_line_len * 0.42,
			q_center + q_dir * q_line_len * 0.42,
			12.0,
			0.16,
			"marked",
			0.8,
			0.14,
			false,
			90.0
		)
		_gain_energy(1.6)

func _role_signature(phase: String, packet: Dictionary, center: Vector2) -> void:
	_signature_executioner(phase, packet, center)
	var radius: float = max(85.0, float(packet.get("radius", 120.0)) * 0.92)
	var aim_dir: Vector2 = _get_player_aim_direction()
	var side_dir: Vector2 = Vector2(-aim_dir.y, aim_dir.x)
	if phase == "line":
		_apply_status_burst(center, radius * 0.74, 4, "marked", 1.0, 0.16)
		_line_slice_burst(
			center - aim_dir * radius * 0.76,
			center + aim_dir * radius * 0.76,
			14.0,
			0.22,
			"marked",
			0.9,
			0.16,
			false,
			130.0
		)
	elif phase == "closure":
		_apply_status_burst(center, radius * 0.92, 6, "marked", 1.4, 0.22)
		_schedule_line_sweep_sequence(
			center,
			aim_dir,
			radius * 1.52,
			24.0,
			2,
			0.10,
			16.0,
			0.34,
			"marked",
			1.1,
			0.20,
			false,
			180.0
		)
		_schedule_line_sweep_sequence(
			center,
			side_dir,
			radius * 1.28,
			16.0,
			2,
			0.13,
			14.0,
			0.26,
			"marked",
			1.0,
			0.18,
			false,
			140.0
		)
		_apply_temp_attack_boost(1.6, 0.14)
