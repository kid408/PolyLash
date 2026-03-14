extends "res://scenes/skills/players/skill_ultimate_qef_v3.gd"

const ROLE_ID: String = "paladin"

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
		_add_player_armor(4)
		_heal_player(base_damage * 0.22)
		_emit_holy_lance(q_center, q_dir, q_radius * 1.18, true)
		_knock_enemies_burst(q_center, q_radius * 0.80, 5, 160.0)
		_line_slice_burst(
			q_center - q_dir * q_line_len * 0.54,
			q_center + q_dir * q_line_len * 0.54,
			18.0,
			0.24,
			"stun",
			0.26,
			0.0,
			false,
			170.0
		)
		_line_slice_burst(
			q_center - q_side * q_line_len * 0.42,
			q_center + q_side * q_line_len * 0.42,
			14.0,
			0.18,
			"slow",
			0.9,
			0.20,
			false,
			120.0
		)
	else:
		_line_slice_burst(
			q_center - q_side * q_line_len * 0.34,
			q_center + q_side * q_line_len * 0.34,
			12.0,
			0.14,
			"slow",
			0.8,
			0.20,
			false,
			80.0
		)

func _role_signature(phase: String, packet: Dictionary, center: Vector2) -> void:
	_signature_paladin(phase, packet, center)
	var radius: float = max(95.0, float(packet.get("radius", 120.0)) * 0.94)
	var base_damage: float = _get_player_base_damage()
	var aim_dir: Vector2 = _get_player_aim_direction()
	var side_dir: Vector2 = Vector2(-aim_dir.y, aim_dir.x)
	if phase == "line":
		_emit_holy_lance(center, aim_dir, radius * 1.10, false)
		_knock_enemies_burst(center, radius * 0.72, 4, 120.0)
		_line_slice_burst(
			center - aim_dir * radius * 0.70,
			center + aim_dir * radius * 0.70,
			14.0,
			0.16,
			"stun",
			0.20,
			0.0,
			false,
			120.0
		)
	elif phase == "closure":
		_emit_holy_lance(center, aim_dir, radius * 1.34, true)
		_add_player_armor(2)
		_heal_player(base_damage * 0.18)
		_spawn_parallel_wall_pair(
			center,
			aim_dir,
			radius * 1.54,
			46.0,
			1.2,
			int(max(1.0, base_damage * 0.14)),
			Color(0.90, 0.86, 0.66, 0.70)
		)
		_schedule_line_sweep_sequence(
			center,
			aim_dir,
			radius * 1.42,
			0.0,
			2,
			0.10,
			15.0,
			0.24,
			"stun",
			0.22,
			0.0,
			false,
			180.0
		)
		_schedule_line_sweep_sequence(
			center,
			side_dir,
			radius * 1.20,
			18.0,
			1,
			0.12,
			12.0,
			0.18,
			"slow",
			0.9,
			0.16,
			false,
			130.0
		)

func _emit_holy_lance(center: Vector2, aim_dir: Vector2, length: float, closure_phase: bool) -> void:
	var dir: Vector2 = aim_dir
	if dir.length_squared() <= 0.001:
		dir = Vector2.RIGHT
	var side: Vector2 = Vector2(-dir.y, dir.x)
	var half_len: float = max(80.0, length * 0.5)
	_schedule_line_sweep_sequence(
		center,
		dir,
		half_len * 1.9,
		12.0,
		1,
		0.08,
		12.0,
		0.20 if not closure_phase else 0.28,
		"stun",
		0.18 if not closure_phase else 0.26,
		0.0,
		false,
		140.0
	)
	_schedule_line_sweep_sequence(
		center + dir * half_len * 0.54,
		-dir,
		half_len * 1.5,
		12.0,
		1 if not closure_phase else 2,
		0.10,
		12.0,
		0.18 if not closure_phase else 0.24,
		"slow",
		0.9,
		0.18,
		false,
		130.0
	)
	if closure_phase:
		_spawn_parallel_wall_pair(
			center,
			side,
			half_len * 1.2,
			32.0,
			0.9,
			int(max(1.0, _get_player_base_damage() * 0.10)),
			Color(0.92, 0.88, 0.70, 0.62)
		)
