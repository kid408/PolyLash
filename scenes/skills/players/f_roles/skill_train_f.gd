extends "res://scenes/skills/players/skill_ultimate_qef_v3.gd"

const ROLE_ID: String = "train"

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
	var base_damage: float = _get_player_base_damage()
	var q_dir: Vector2 = _get_player_aim_direction()
	if q_dir.length_squared() <= 0.001:
		q_dir = Vector2.RIGHT
	var q_side: Vector2 = Vector2(-q_dir.y, q_dir.x)
	var q_line_len: float = q_radius * 1.18

	if q_closed:
		_knock_enemies_burst(q_center, q_radius * 0.92, 6, 260.0)
		_spawn_parallel_wall_pair(
			q_center,
			q_dir,
			q_radius * 1.82,
			54.0,
			1.2,
			int(max(1.0, base_damage * 0.18)),
			Color(1.0, 0.72, 0.26, 0.72)
		)
		_schedule_line_sweep_sequence(
			q_center,
			q_dir,
			q_radius * 1.95,
			0.0,
			2,
			0.09,
			22.0,
			0.44,
			"slow",
			1.0,
			0.26,
			false,
			320.0
		)
		_line_slice_burst(
			q_center - q_side * q_line_len * 0.52,
			q_center + q_side * q_line_len * 0.52,
			20.0,
			0.24,
			"slow",
			0.9,
			0.20,
			false,
			180.0
		)
	elif phase == "line":
		_knock_enemies_burst(q_center, q_radius * 0.86, 5, 220.0)
		_line_slice_burst(
			q_center - q_dir * q_line_len * 0.72,
			q_center + q_dir * q_line_len * 0.72,
			24.0,
			0.36,
			"slow",
			0.9,
			0.28,
			false,
			260.0
		)
		_gain_energy(2.0)

func _role_signature(phase: String, packet: Dictionary, center: Vector2) -> void:
	_signature_train(phase, packet, center)
	var radius: float = max(95.0, float(packet.get("radius", 120.0)) * 0.98)
	var base_damage: float = _get_player_base_damage()
	var train_dir: Vector2 = _get_player_aim_direction()
	var train_side: Vector2 = Vector2(-train_dir.y, train_dir.x)
	if phase == "line":
		_emit_train_corridor(center, train_dir, radius * 1.42, false)
		_schedule_line_sweep_sequence(
			center,
			train_dir,
			radius * 1.55,
			0.0,
			1,
			0.08,
			18.0,
			0.26,
			"slow",
			0.8,
			0.18,
			false,
			220.0
		)
		_line_slice_burst(
			center - train_side * radius * 0.44,
			center + train_side * radius * 0.44,
			14.0,
			0.16,
			"marked",
			0.8,
			0.16,
			false,
			120.0
		)
	elif phase == "closure":
		_emit_train_corridor(center, train_dir, radius * 1.72, true)
		_spawn_parallel_wall_pair(
			center,
			train_dir,
			radius * 1.88,
			58.0,
			1.3,
			int(max(1.0, base_damage * 0.20)),
			Color(1.0, 0.74, 0.30, 0.74)
		)
		_schedule_line_sweep_sequence(
			center,
			train_dir,
			radius * 1.98,
			0.0,
			3,
			0.09,
			22.0,
			0.42,
			"slow",
			1.1,
			0.24,
			false,
			340.0
		)
		_knock_enemies_burst(center, radius * 0.95, 8, 260.0)
		_add_player_armor(1)

func _emit_train_corridor(center: Vector2, aim_dir: Vector2, length: float, closure_phase: bool) -> void:
	var dir: Vector2 = aim_dir
	if dir.length_squared() <= 0.001:
		dir = Vector2.RIGHT
	var side: Vector2 = Vector2(-dir.y, dir.x)
	var half_len: float = max(90.0, length * 0.5)
	var lane_gap: float = 52.0 if closure_phase else 42.0
	_spawn_parallel_wall_pair(
		center,
		dir,
		half_len * 2.0,
		lane_gap,
		1.0 if not closure_phase else 1.3,
		int(max(1.0, _get_player_base_damage() * (0.14 if not closure_phase else 0.20))),
		Color(1.0, 0.76, 0.30, 0.72)
	)
	_schedule_line_sweep_sequence(
		center + side * lane_gap * 0.52,
		dir,
		half_len * 1.9,
		0.0,
		1 if not closure_phase else 2,
		0.08,
		20.0,
		0.24 if not closure_phase else 0.34,
		"slow",
		1.0,
		0.20,
		false,
		280.0
	)
	_schedule_line_sweep_sequence(
		center - side * lane_gap * 0.52,
		dir,
		half_len * 1.9,
		0.0,
		1 if not closure_phase else 2,
		0.10,
		20.0,
		0.24 if not closure_phase else 0.34,
		"slow",
		1.0,
		0.20,
		false,
		280.0
	)
	if closure_phase:
		_knock_enemies_burst(center + dir * half_len * 0.45, half_len * 0.72, 6, 220.0)
