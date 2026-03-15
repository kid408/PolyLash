extends "res://scenes/skills/skill_f_base.gd"

const ROLE_ID: String = "fatebinder"

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
	var roll: float = randf()

	if q_closed or phase == "closure":
		if roll < 0.33:
			_apply_temp_attack_boost(1.8, 0.16)
			_gain_energy(2.2)
		elif roll < 0.66:
			_drop_coins_at(q_center, 3)
			_add_player_armor(1)
		else:
			_pull_enemies_burst(q_center, q_radius * 0.82, 6, 14.0)
			_knock_enemies_burst(q_center, q_radius * 0.74, 4, 160.0)
		_line_slice_burst(
			q_center - q_dir * q_line_len * 0.58,
			q_center + q_dir * q_line_len * 0.58,
			14.0,
			randf_range(0.14, 0.40),
			"marked",
			1.0,
			0.16,
			false,
			randf_range(70.0, 190.0)
		)
		_schedule_line_sweep_sequence(
			q_center,
			q_side,
			q_radius * 1.20,
			randf_range(10.0, 24.0),
			2,
			0.12,
			12.0,
			randf_range(0.14, 0.24),
			"marked",
			0.9,
			0.14,
			false,
			randf_range(80.0, 160.0)
		)
	else:
		_line_slice_burst(
			q_center - q_side * q_line_len * 0.40,
			q_center + q_side * q_line_len * 0.40,
			10.0,
			randf_range(0.08, 0.22),
			"marked",
			0.8,
			0.12,
			false,
			randf_range(40.0, 120.0)
		)

func _role_signature(phase: String, packet: Dictionary, center: Vector2) -> void:
	_signature_fatebinder(phase, packet, center)
	var radius: float = max(88.0, float(packet.get("radius", 120.0)) * 0.92)
	var aim_dir: Vector2 = _get_player_aim_direction()
	var side_dir: Vector2 = Vector2(-aim_dir.y, aim_dir.x)
	if phase == "line":
		_gain_energy(randf_range(0.8, 1.6))
		_line_slice_burst(
			center - aim_dir * radius * 0.72,
			center + aim_dir * radius * 0.72,
			12.0,
			randf_range(0.10, 0.20),
			"marked",
			0.8,
			0.14,
			false,
			randf_range(70.0, 130.0)
		)
	elif phase == "closure":
		if randf() < 0.45:
			_drop_coins_at(center, 2)
		else:
			_apply_temp_attack_boost(1.6, 0.12)
		_schedule_line_sweep_sequence(
			center,
			aim_dir,
			radius * 1.30,
			randf_range(10.0, 22.0),
			2,
			0.12,
			12.0,
			randf_range(0.14, 0.24),
			"marked",
			0.9,
			0.14,
			false,
			randf_range(90.0, 170.0)
		)
		_schedule_line_sweep_sequence(
			center,
			side_dir,
			radius * 1.10,
			randf_range(8.0, 18.0),
			1,
			0.14,
			10.0,
			randf_range(0.10, 0.20),
			"marked",
			0.8,
			0.12,
			false,
			randf_range(70.0, 130.0)
		)
