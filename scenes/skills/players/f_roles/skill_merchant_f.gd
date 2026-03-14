extends "res://scenes/skills/players/skill_ultimate_qef_v3.gd"

const ROLE_ID: String = "merchant"

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

	if q_closed or phase == "closure":
		_drop_coins_at(q_center, 2)
		_gain_energy(2.4)
		_apply_temp_attack_boost(1.8, 0.10)
		_line_slice_burst(
			q_center - q_side * q_line_len * 0.62,
			q_center + q_side * q_line_len * 0.62,
			14.0,
			0.18,
			"marked",
			1.0,
			0.16,
			false,
			100.0
		)
		_schedule_line_sweep_sequence(
			q_center,
			q_dir,
			q_radius * 1.22,
			20.0,
			2,
			0.10,
			12.0,
			0.16,
			"marked",
			0.9,
			0.14,
			false,
			110.0
		)
		if phase == "closure":
			_drop_coins_at(q_center, 1)
	else:
		_gain_energy(1.0)
		_line_slice_burst(
			q_center - q_dir * q_line_len * 0.34,
			q_center + q_dir * q_line_len * 0.34,
			10.0,
			0.10,
			"marked",
			0.7,
			0.12,
			false,
			60.0
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
			0.12,
			false,
			70.0
		)

func _role_signature(phase: String, packet: Dictionary, center: Vector2) -> void:
	_signature_merchant(phase, packet, center)
	var radius: float = max(86.0, float(packet.get("radius", 120.0)) * 0.88)
	var base_damage: float = _get_player_base_damage()
	var aim_dir: Vector2 = _get_player_aim_direction()
	if phase == "line":
		_gain_energy(1.0)
		_drop_coins_at(center, 1)
		_line_slice_burst(
			center - aim_dir * radius * 0.70,
			center + aim_dir * radius * 0.70,
			12.0,
			0.12,
			"marked",
			0.8,
			0.14,
			false,
			90.0
		)
		_spawn_parallel_wall_pair(
			center,
			aim_dir,
			radius * 1.10,
			28.0,
			0.85,
			int(max(1.0, base_damage * 0.09)),
			Color(1.0, 0.86, 0.32, 0.56)
		)
	elif phase == "closure":
		_drop_coins_at(center, 1)
		_gain_energy(1.2)
		_apply_temp_attack_boost(1.6, 0.08)
		_spawn_parallel_wall_pair(
			center,
			aim_dir,
			radius * 1.36,
			36.0,
			1.0,
			int(max(1.0, base_damage * 0.10)),
			Color(1.0, 0.84, 0.28, 0.64)
		)
		_schedule_line_sweep_sequence(
			center,
			aim_dir,
			radius * 1.28,
			0.0,
			2,
			0.13,
			12.0,
			0.16,
			"marked",
			0.9,
			0.14,
			false,
			110.0
		)
		_schedule_line_sweep_sequence(
			center,
			Vector2(-aim_dir.y, aim_dir.x),
			radius * 1.14,
			14.0,
			1,
			0.12,
			11.0,
			0.14,
			"marked",
			0.8,
			0.13,
			false,
			95.0
		)
