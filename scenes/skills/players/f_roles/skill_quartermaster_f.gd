extends "res://scenes/skills/skill_f_base.gd"

const ROLE_ID: String = "quartermaster"

func _resolve_f_role_id() -> String:
	return ROLE_ID

func _apply_mode_signature(phase: String, packet: Dictionary, center: Vector2, _hit_count: int) -> void:
	if not is_active:
		return
	_role_signature(phase, packet, center)
	_spawn_quartermaster_pickups(phase, packet, center)

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
		_gain_energy(3.2)
		_apply_temp_attack_boost(1.6, 0.12)
		_line_slice_burst(
			q_center - q_dir * q_line_len * 0.66,
			q_center + q_dir * q_line_len * 0.66,
			14.0,
			0.26,
			"marked",
			1.0,
			0.20,
			false,
			150.0
		)
		_schedule_line_sweep_sequence(
			q_center,
			q_side,
			q_radius * 1.28,
			14.0,
			2,
			0.11,
			12.0,
			0.18,
			"marked",
			0.9,
			0.18,
			false,
			120.0
		)
		_schedule_line_sweep_sequence(
			q_center,
			q_dir,
			q_radius * 1.22,
			22.0,
			1,
			0.10,
			12.0,
			0.16,
			"marked",
			0.9,
			0.16,
			false,
			110.0
		)
	else:
		_gain_energy(1.8)
		_line_slice_burst(
			q_center - q_side * q_line_len * 0.46,
			q_center + q_side * q_line_len * 0.46,
			12.0,
			0.16,
			"marked",
			0.8,
			0.16,
			false,
			80.0
		)
		_schedule_line_sweep_sequence(
			q_center,
			q_dir,
			q_radius * 1.02,
			12.0,
			1,
			0.10,
			10.0,
			0.14,
			"marked",
			0.8,
			0.14,
			false,
			75.0
		)

func _role_signature(phase: String, packet: Dictionary, center: Vector2) -> void:
	_signature_quartermaster(phase, packet, center)
	var radius: float = max(88.0, float(packet.get("radius", 120.0)) * 0.90)
	var aim_dir: Vector2 = _get_player_aim_direction()
	var side_dir: Vector2 = Vector2(-aim_dir.y, aim_dir.x)
	if phase == "line":
		_gain_energy(1.2)
		_line_slice_burst(
			center - aim_dir * radius * 0.76,
			center + aim_dir * radius * 0.76,
			12.0,
			0.16,
			"marked",
			0.8,
			0.16,
			false,
			110.0
		)
		_spawn_parallel_wall_pair(
			center,
			aim_dir,
			radius * 1.12,
			30.0,
			0.85,
			int(max(1.0, _get_player_base_damage() * 0.10)),
			Color(0.84, 0.95, 0.7, 0.56)
		)
	elif phase == "closure":
		_gain_energy(2.2)
		_apply_temp_attack_boost(1.5, 0.10)
		_schedule_line_sweep_sequence(
			center,
			aim_dir,
			radius * 1.34,
			16.0,
			2,
			0.11,
			13.0,
			0.20,
			"marked",
			1.0,
			0.18,
			false,
			140.0
		)
		_schedule_line_sweep_sequence(
			center,
			side_dir,
			radius * 1.14,
			12.0,
			1,
			0.13,
			11.0,
			0.16,
			"marked",
			0.8,
			0.16,
			false,
			100.0
		)
		_schedule_line_sweep_sequence(
			center,
			aim_dir.rotated(0.42),
			radius * 1.10,
			12.0,
			1,
			0.10,
			11.0,
			0.16,
			"marked",
			0.9,
			0.16,
			false,
			95.0
		)

func _spawn_quartermaster_pickups(phase: String, packet: Dictionary, center: Vector2) -> void:
	var radius: float = max(58.0, float(packet.get("radius", 140.0)) * 0.58)
	var count: int = 1 if phase != "closure" else 2
	_spawn_signature_pickup_burst(
		center,
		count,
		radius,
		Color(1.0, 0.96, 0.42, 0.95),
		{
			"effect_id": "quartermaster_reload",
			"pickup_text": "装填牌",
			"radius": radius,
			"text_color": Color(1.0, 1.0, 0.62),
			"vfx_color": Color(1.0, 0.92, 0.28, 0.90),
			"effect_scale": 0.58,
		},
		5.2 if phase == "tick" else 6.4
	)

