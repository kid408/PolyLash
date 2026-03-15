extends "res://scenes/skills/skill_f_base.gd"

const ROLE_ID: String = "banner"

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
		_apply_temp_meta_delta("buff_speed_boost", 0.14, 2.2)
		_apply_temp_attack_boost(2.0, 0.16)
		_add_player_armor(1)
		_spawn_parallel_wall_pair(
			q_center,
			q_dir,
			q_radius * 1.72,
			48.0,
			1.3,
			int(max(1.0, _get_player_base_damage() * 0.16)),
			Color(0.96, 0.88, 0.42, 0.70)
		)
		_line_slice_burst(
			q_center - q_side * q_line_len * 0.70,
			q_center + q_side * q_line_len * 0.70,
			18.0,
			0.24,
			"marked",
			1.1,
			0.18,
			true,
			180.0
		)
		_knock_enemies_burst(q_center, q_radius * 0.70, 5, 150.0)
		_schedule_line_sweep_sequence(
			q_center,
			q_dir,
			q_radius * 1.34,
			28.0,
			2,
			0.10,
			14.0,
			0.18,
			"marked",
			1.0,
			0.16,
			true,
			150.0
		)
	else:
		_apply_temp_meta_delta("buff_speed_boost", 0.08, 1.4)
		_line_slice_burst(
			q_center - q_dir * q_line_len * 0.42,
			q_center + q_dir * q_line_len * 0.42,
			12.0,
			0.12,
			"marked",
			0.8,
			0.14,
			true,
			90.0
		)
		_schedule_line_sweep_sequence(
			q_center,
			q_side,
			q_radius * 1.04,
			14.0,
			1,
			0.10,
			10.0,
			0.12,
			"marked",
			0.8,
			0.14,
			true,
			90.0
		)

func _role_signature(phase: String, packet: Dictionary, center: Vector2) -> void:
	_signature_banner(phase, packet, center)
	var radius: float = max(90.0, float(packet.get("radius", 120.0)) * 0.92)
	var aim_dir: Vector2 = _get_player_aim_direction()
	if phase == "line":
		_apply_temp_meta_delta("buff_speed_boost", 0.08, 1.2)
		_add_player_armor(1)
		_line_slice_burst(
			center - aim_dir * radius * 0.72,
			center + aim_dir * radius * 0.72,
			14.0,
			0.14,
			"marked",
			0.8,
			0.14,
			true,
			100.0
		)
		_spawn_parallel_wall_pair(
			center,
			aim_dir,
			radius * 1.12,
			28.0,
			0.85,
			int(max(1.0, _get_player_base_damage() * 0.10)),
			Color(0.96, 0.9, 0.45, 0.56)
		)
	elif phase == "closure":
		_apply_temp_meta_delta("buff_speed_boost", 0.12, 1.8)
		_apply_temp_attack_boost(1.8, 0.12)
		_knock_enemies_burst(center, radius * 0.72, 6, 160.0)
		_apply_status_burst(center, radius * 0.66, 4, "slow", 1.1, 0.28)
		_spawn_parallel_wall_pair(
			center,
			aim_dir,
			radius * 1.66,
			42.0,
			1.2,
			int(max(1.0, _get_player_base_damage() * 0.14)),
			Color(0.94, 0.84, 0.36, 0.66)
		)
		_schedule_line_sweep_sequence(
			center,
			aim_dir,
			radius * 1.50,
			0.0,
			2,
			0.11,
			14.0,
			0.18,
			"marked",
			1.0,
			0.16,
			true,
			160.0
		)
		_schedule_line_sweep_sequence(
			center,
			Vector2(-aim_dir.y, aim_dir.x),
			radius * 1.22,
			16.0,
			2,
			0.12,
			12.0,
			0.16,
			"marked",
			0.9,
			0.15,
			true,
			130.0
		)
