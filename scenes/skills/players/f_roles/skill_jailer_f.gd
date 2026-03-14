extends "res://scenes/skills/players/skill_ultimate_qef_v3.gd"

const ROLE_ID: String = "jailer"

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
		_apply_status_burst(q_center, q_radius * 0.82, 5, "stun", 0.32, 0.0)
		_spawn_parallel_wall_pair(
			q_center,
			q_dir,
			q_radius * 1.54,
			46.0,
			1.2,
			int(max(1.0, _get_player_base_damage() * 0.14)),
			Color(0.70, 0.90, 1.0, 0.66)
		)
		_line_slice_burst(
			q_center - q_side * q_line_len * 0.60,
			q_center + q_side * q_line_len * 0.60,
			16.0,
			0.22,
			"stun",
			0.24,
			0.0,
			true,
			150.0
		)
	else:
		_line_slice_burst(
			q_center - q_dir * q_line_len * 0.36,
			q_center + q_dir * q_line_len * 0.36,
			12.0,
			0.14,
			"slow",
			0.8,
			0.20,
			true,
			90.0
		)

func _role_signature(phase: String, packet: Dictionary, center: Vector2) -> void:
	_signature_jailer(phase, packet, center)
	var radius: float = max(88.0, float(packet.get("radius", 120.0)) * 0.92)
	var base_damage: float = _get_player_base_damage()
	var aim_dir: Vector2 = _get_player_aim_direction()
	var side_dir: Vector2 = Vector2(-aim_dir.y, aim_dir.x)
	if phase == "line":
		_apply_status_burst(center, radius * 0.72, 4, "slow", 0.9, 0.26)
		_line_slice_burst(
			center - aim_dir * radius * 0.70,
			center + aim_dir * radius * 0.70,
			12.0,
			0.16,
			"slow",
			0.8,
			0.18,
			true,
			100.0
		)
	elif phase == "closure":
		_apply_status_burst(center, radius * 0.90, 6, "stun", 0.30, 0.0)
		_spawn_parallel_wall_pair(
			center,
			aim_dir,
			radius * 1.46,
			42.0,
			1.2,
			int(max(1.0, base_damage * 0.14)),
			Color(0.68, 0.86, 1.0, 0.64)
		)
		_schedule_line_sweep_sequence(
			center,
			aim_dir,
			radius * 1.34,
			16.0,
			2,
			0.11,
			14.0,
			0.20,
			"stun",
			0.24,
			0.0,
			true,
			140.0
		)
		_schedule_line_sweep_sequence(
			center,
			side_dir,
			radius * 1.16,
			14.0,
			1,
			0.13,
			12.0,
			0.16,
			"slow",
			0.8,
			0.16,
			true,
			100.0
		)
