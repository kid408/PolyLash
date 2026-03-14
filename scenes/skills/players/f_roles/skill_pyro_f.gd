extends "res://scenes/skills/players/skill_ultimate_qef_v3.gd"

const ROLE_ID: String = "pyro"

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
		_spawn_pyro_patch(q_center, q_radius * 0.5, 1.5, 0.24)
		_emit_fire_funnel(q_center, q_dir, q_radius * 1.42, true)
		_line_slice_burst(
			q_center - q_dir * q_line_len * 0.58,
			q_center + q_dir * q_line_len * 0.58,
			22.0,
			0.30,
			"burn",
			1.2,
			max(1.0, base_damage * 0.10),
			false,
			220.0
		)
		_schedule_line_sweep_sequence(
			q_center,
			q_side,
			q_radius * 1.45,
			38.0,
			2,
			0.10,
			16.0,
			0.20,
			"burn",
			1.0,
			max(1.0, base_damage * 0.08),
			false,
			160.0
		)
	else:
		_line_slice_burst(
			q_center - q_side * q_line_len * 0.46,
			q_center + q_side * q_line_len * 0.46,
			16.0,
			0.20,
			"burn",
			0.9,
			max(1.0, base_damage * 0.06),
			false,
			140.0
		)

func _role_signature(phase: String, packet: Dictionary, center: Vector2) -> void:
	var radius: float = max(70.0, float(packet.get("radius", 120.0)) * (0.56 if phase != "closure" else 0.64))
	var duration: float = 1.2 if phase == "tick" else 1.8
	var damage_scale: float = 0.25 if phase == "tick" else 0.34
	var aim_dir: Vector2 = _get_player_aim_direction()
	var line_len: float = radius * (1.45 if phase != "closure" else 1.75)
	_spawn_pyro_patch(center, radius, duration, damage_scale)
	if phase == "line":
		_emit_fire_funnel(center, aim_dir, radius * 1.30, false)
		_schedule_line_sweep_sequence(
			center,
			aim_dir,
			line_len,
			34.0,
			2,
			0.10,
			16.0,
			0.28,
			"burn",
			1.1,
			max(1.0, _get_player_base_damage() * 0.09),
			false,
			180.0
		)
	if phase == "closure":
		_emit_fire_funnel(center, aim_dir, radius * 1.58, true)
		for i: int in range(2):
			var angle: float = randf_range(0.0, TAU)
			var offset: Vector2 = Vector2(cos(angle), sin(angle)) * radius * 0.8
			_spawn_pyro_patch(center + offset, radius * 0.7, duration * 0.8, damage_scale * 0.9)
		_schedule_line_sweep_sequence(
			center,
			aim_dir,
			line_len,
			44.0,
			3,
			0.08,
			18.0,
			0.34,
			"burn",
			1.3,
			max(1.0, _get_player_base_damage() * 0.11),
			false,
			220.0
		)
		_schedule_line_sweep_sequence(
			center,
			-aim_dir,
			line_len,
			44.0,
			2,
			0.18,
			18.0,
			0.30,
			"burn",
			1.1,
			max(1.0, _get_player_base_damage() * 0.10),
			false,
			200.0
		)

func _emit_fire_funnel(center: Vector2, aim_dir: Vector2, length: float, closure_phase: bool) -> void:
	var dir: Vector2 = aim_dir
	if dir.length_squared() <= 0.001:
		dir = Vector2.RIGHT
	var side: Vector2 = Vector2(-dir.y, dir.x)
	var half_len: float = max(90.0, length * 0.5)
	var lane_count: int = 3 if closure_phase else 2
	for i: int in range(lane_count):
		var lane_t: float = -0.5 + float(i) / float(max(1, lane_count - 1))
		var offset: Vector2 = side * lane_t * 72.0
		_schedule_line_sweep_sequence(
			center + offset,
			dir,
			half_len * 1.8,
			16.0,
			1,
			0.08 + float(i) * 0.03,
			14.0,
			0.22 if not closure_phase else 0.30,
			"burn",
			1.0,
			max(1.0, _get_player_base_damage() * 0.08),
			false,
			180.0
		)
	if closure_phase:
		_schedule_line_sweep_sequence(
			center + dir * half_len * 0.60,
			-dir,
			half_len * 1.6,
			20.0,
			2,
			0.08,
			15.0,
			0.28,
			"burn",
			1.2,
			max(1.0, _get_player_base_damage() * 0.09),
			false,
			220.0
		)
