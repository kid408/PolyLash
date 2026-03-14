extends "res://scenes/skills/players/skill_ultimate_qef_v3.gd"

const ROLE_ID: String = "vacuum"

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
		_pull_enemies_burst(q_center, q_radius * 1.02, 8, 24.0)
		_apply_status_burst(q_center, q_radius * 0.86, 6, "slow", 1.2, 0.32)
		_emit_vortex_tunnel(q_center, q_dir, q_radius * 1.36, true)
		_schedule_line_sweep_sequence(
			q_center,
			q_dir,
			q_radius * 1.72,
			24.0,
			3,
			0.08,
			22.0,
			0.28,
			"slow",
			1.0,
			0.26,
			true,
			240.0
		)
		_schedule_line_sweep_sequence(
			q_center,
			q_side,
			q_radius * 1.48,
			16.0,
			2,
			0.10,
			18.0,
			0.22,
			"slow",
			0.9,
			0.24,
			true,
			200.0
		)
	else:
		_pull_enemies_burst(q_center, q_radius * 0.66, 4, 12.0)
		_line_slice_burst(
			q_center - q_side * q_line_len * 0.46,
			q_center + q_side * q_line_len * 0.46,
			14.0,
			0.16,
			"slow",
			0.8,
			0.18,
			true,
			120.0
		)

func _role_signature(phase: String, packet: Dictionary, center: Vector2) -> void:
	_signature_vacuum(phase, packet, center)
	var radius: float = max(90.0, float(packet.get("radius", 120.0)) * 1.02)
	var aim_dir: Vector2 = _get_player_aim_direction()
	var side_dir: Vector2 = Vector2(-aim_dir.y, aim_dir.x)
	if phase == "line":
		_emit_vortex_tunnel(center, aim_dir, radius * 1.12, false)
		_pull_enemies_burst(center, radius * 0.76, 6, 12.0)
		_line_slice_burst(
			center - side_dir * radius * 0.58,
			center + side_dir * radius * 0.58,
			16.0,
			0.16,
			"slow",
			0.8,
			0.16,
			true,
			140.0
		)
	elif phase == "closure":
		_emit_vortex_tunnel(center, aim_dir, radius * 1.34, true)
		_pull_enemies_burst(center, radius * 0.96, 8, 18.0)
		_schedule_line_sweep_sequence(
			center,
			aim_dir,
			radius * 1.72,
			30.0,
			2,
			0.09,
			20.0,
			0.26,
			"slow",
			1.0,
			0.24,
			true,
			230.0
		)
		_schedule_line_sweep_sequence(
			center,
			side_dir,
			radius * 1.46,
			20.0,
			2,
			0.12,
			16.0,
			0.22,
			"slow",
			0.9,
			0.22,
			true,
			190.0
		)
		_heal_player(_get_player_base_damage() * 0.05)

func _emit_vortex_tunnel(center: Vector2, aim_dir: Vector2, length: float, closure_phase: bool) -> void:
	var dir: Vector2 = aim_dir
	if dir.length_squared() <= 0.001:
		dir = Vector2.RIGHT
	var side: Vector2 = Vector2(-dir.y, dir.x)
	var half_len: float = max(84.0, length * 0.5)
	var lanes: int = 2 if not closure_phase else 3
	for i: int in range(lanes):
		var lane_t: float = -0.5 + float(i) / float(max(1, lanes - 1))
		var offset: Vector2 = side * lane_t * 70.0
		_schedule_line_sweep_sequence(
			center + offset,
			dir,
			half_len * 1.8,
			16.0,
			1,
			0.08 + float(i) * 0.02,
			16.0,
			0.18 if not closure_phase else 0.26,
			"slow",
			1.0,
			0.20,
			true,
			180.0
		)
	if closure_phase:
		_schedule_line_sweep_sequence(
			center + dir * half_len * 0.52,
			-dir,
			half_len * 1.5,
			20.0,
			2,
			0.08,
			16.0,
			0.24,
			"slow",
			1.0,
			0.22,
			true,
			200.0
		)
