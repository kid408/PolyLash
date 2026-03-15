extends "res://scenes/skills/skill_f_base.gd"

const ROLE_ID: String = "medic"

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
		_heal_player(base_damage * 0.46)
		_add_player_armor(1)
		_apply_temp_meta_delta("buff_speed_boost", 0.08, 1.6)
		_spawn_parallel_wall_pair(
			q_center,
			q_dir,
			q_radius * 1.56,
			40.0,
			1.1,
			int(max(1.0, base_damage * 0.12)),
			Color(0.62, 0.94, 0.82, 0.68)
		)
		_line_slice_burst(
			q_center - q_side * q_line_len * 0.52,
			q_center + q_side * q_line_len * 0.52,
			16.0,
			0.18,
			"slow",
			0.9,
			0.20,
			true,
			130.0
		)
		_schedule_line_sweep_sequence(
			q_center,
			q_dir,
			q_radius * 1.26,
			24.0,
			2,
			0.10,
			12.0,
			0.18,
			"slow",
			0.9,
			0.20,
			true,
			120.0
		)
		_knock_enemies_burst(q_center, q_radius * 0.68, 4, 110.0)
	else:
		_heal_player(base_damage * 0.12)
		_line_slice_burst(
			q_center - q_side * q_line_len * 0.36,
			q_center + q_side * q_line_len * 0.36,
			12.0,
			0.12,
			"slow",
			0.7,
			0.18,
			true,
			80.0
		)
		_schedule_line_sweep_sequence(
			q_center,
			q_side,
			q_radius * 1.02,
			18.0,
			1,
			0.10,
			10.0,
			0.16,
			"slow",
			0.8,
			0.16,
			true,
			90.0
		)

func _role_signature(phase: String, packet: Dictionary, center: Vector2) -> void:
	_signature_medic(phase, packet, center)
	var radius: float = max(90.0, float(packet.get("radius", 120.0)) * 0.90)
	var base_damage: float = _get_player_base_damage()
	var aim_dir: Vector2 = _get_player_aim_direction()
	if phase == "line":
		_heal_player(base_damage * 0.08)
		_apply_temp_meta_delta("buff_speed_boost", 0.05, 1.0)
		_add_player_armor(1)
		_line_slice_burst(
			center - aim_dir * radius * 0.64,
			center + aim_dir * radius * 0.64,
			12.0,
			0.12,
			"slow",
			0.8,
			0.14,
			true,
			90.0
		)
		_spawn_parallel_wall_pair(
			center,
			aim_dir,
			radius * 1.10,
			34.0,
			0.85,
			int(max(1.0, base_damage * 0.10)),
			Color(0.66, 0.98, 0.86, 0.62)
		)
	elif phase == "closure":
		_heal_player(base_damage * 0.20)
		_add_player_armor(1)
		_apply_temp_meta_delta("buff_speed_boost", 0.08, 1.4)
		_knock_enemies_burst(center, radius * 0.70, 5, 130.0)
		_apply_status_burst(center, radius * 0.66, 4, "slow", 1.0, 0.26)
		_schedule_line_sweep_sequence(
			center,
			aim_dir,
			radius * 1.32,
			0.0,
			2,
			0.11,
			12.0,
			0.16,
			"slow",
			0.9,
			0.16,
			true,
			120.0
		)
		_schedule_line_sweep_sequence(
			center,
			Vector2(-aim_dir.y, aim_dir.x),
			radius * 1.18,
			20.0,
			2,
			0.12,
			10.0,
			0.14,
			"slow",
			0.9,
			0.18,
			true,
			110.0
		)
		_spawn_parallel_wall_pair(
			center,
			Vector2(-aim_dir.y, aim_dir.x),
			radius * 1.22,
			40.0,
			0.95,
			int(max(1.0, base_damage * 0.12)),
			Color(0.72, 1.0, 0.9, 0.64)
		)
