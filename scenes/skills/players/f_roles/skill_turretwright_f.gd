extends "res://scenes/skills/skill_f_base.gd"

const ROLE_ID: String = "turretwright"

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
	var base_damage: float = _get_player_base_damage()

	if q_closed:
		_spawn_turret_pylon(q_center, q_radius * 0.45, 2.2, 0.30)
		_spawn_turret_pylon(q_center + q_side * (q_radius * 0.24), q_radius * 0.30, 1.6, 0.24)
		_spawn_parallel_wall_pair(
			q_center,
			q_dir,
			q_radius * 1.38,
			36.0,
			1.1,
			int(max(1.0, base_damage * 0.14)),
			Color(0.58, 0.86, 1.0, 0.64)
		)
		_line_slice_burst(
			q_center - q_dir * q_line_len * 0.52,
			q_center + q_dir * q_line_len * 0.52,
			16.0,
			0.26,
			"marked",
			1.0,
			0.18,
			false,
			150.0
		)
	else:
		_line_slice_burst(
			q_center - q_side * q_line_len * 0.34,
			q_center + q_side * q_line_len * 0.34,
			12.0,
			0.16,
			"marked",
			0.8,
			0.14,
			false,
			80.0
		)

func _role_signature(phase: String, packet: Dictionary, center: Vector2) -> void:
	var count: int = 1
	var radius: float = max(90.0, float(packet.get("radius", 120.0)) * 0.64)
	var duration: float = 1.6
	var damage_scale: float = 0.34
	if phase == "line":
		count = 1
		duration = 1.9
		damage_scale = 0.4
	elif phase == "closure":
		count = 2
		duration = 2.5
		damage_scale = 0.56
	var aim_dir: Vector2 = _get_player_aim_direction()
	var spread: float = 0.4
	for i: int in range(count):
		var ratio: float = 0.5 if count <= 1 else float(i) / float(count - 1)
		var angle: float = lerp(-spread, spread, ratio)
		var dir: Vector2 = aim_dir.rotated(angle)
		var pos: Vector2 = center + dir * (66.0 + float(i) * 22.0)
		_spawn_turret_pylon(pos, radius, duration, damage_scale)
	if phase == "line":
		_schedule_line_sweep_sequence(
			center,
			aim_dir,
			radius * 1.25,
			24.0,
			2,
			0.12,
			13.0,
			0.20,
			"marked",
			0.9,
			0.16,
			false,
			110.0
		)
	elif phase == "closure":
		_schedule_line_sweep_sequence(
			center,
			aim_dir,
			radius * 1.35,
			28.0,
			3,
			0.10,
			14.0,
			0.24,
			"marked",
			1.1,
			0.18,
			false,
			130.0
		)
		_spawn_parallel_wall_pair(
			center,
			aim_dir,
			radius * 1.48,
			34.0,
			1.0,
			int(max(1.0, _get_player_base_damage() * 0.12)),
			Color(0.54, 0.82, 1.0, 0.60)
		)
