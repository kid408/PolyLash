extends "res://scenes/skills/players/skill_ultimate_qef_v3.gd"

const ROLE_ID: String = "new_pyro"

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
		_spawn_pyro_patch(q_center, q_radius * 0.46, 1.8, 0.30)
		_spawn_pyro_patch(q_center + q_dir * (q_radius * 0.28), q_radius * 0.30, 1.2, 0.24)
		_emit_rune_bloom(q_center, q_dir, q_radius * 1.24, true)
		_line_slice_burst(
			q_center - q_side * q_line_len * 0.62,
			q_center + q_side * q_line_len * 0.62,
			20.0,
			0.30,
			"burn",
			1.2,
			max(1.0, base_damage * 0.10),
			false,
			220.0
		)
		_schedule_line_sweep_sequence(
			q_center,
			q_dir,
			q_radius * 1.44,
			20.0,
			2,
			0.10,
			16.0,
			0.24,
			"burn",
			1.2,
			max(1.0, base_damage * 0.08),
			false,
			170.0
		)
	else:
		_spawn_pyro_patch(q_center, q_radius * 0.24, 1.0, 0.14)
		_line_slice_burst(
			q_center - q_dir * q_line_len * 0.44,
			q_center + q_dir * q_line_len * 0.44,
			14.0,
			0.18,
			"burn",
			0.9,
			max(1.0, base_damage * 0.06),
			false,
			110.0
		)

func _role_signature(phase: String, packet: Dictionary, center: Vector2) -> void:
	_signature_new_pyro(phase, packet, center)
	var radius: float = max(90.0, float(packet.get("radius", 120.0)) * 0.96)
	var base_damage: float = _get_player_base_damage()
	var aim_dir: Vector2 = _get_player_aim_direction()
	var side_dir: Vector2 = Vector2(-aim_dir.y, aim_dir.x)
	if phase == "line":
		_emit_rune_bloom(center, aim_dir, radius * 1.10, false)
		_spawn_pyro_patch(center + aim_dir * (radius * 0.24), radius * 0.22, 1.1, 0.16)
		_line_slice_burst(
			center - side_dir * radius * 0.56,
			center + side_dir * radius * 0.56,
			14.0,
			0.14,
			"burn",
			0.9,
			max(1.0, base_damage * 0.05),
			false,
			110.0
		)
	elif phase == "closure":
		_emit_rune_bloom(center, aim_dir, radius * 1.34, true)
		_spawn_pyro_patch(center, radius * 0.34, 1.6, 0.26)
		_spawn_pyro_patch(center + aim_dir * (radius * 0.26), radius * 0.24, 1.3, 0.20)
		_schedule_line_sweep_sequence(
			center,
			aim_dir,
			radius * 1.36,
			18.0,
			2,
			0.10,
			14.0,
			0.22,
			"burn",
			1.1,
			max(1.0, base_damage * 0.07),
			false,
			150.0
		)
		_schedule_line_sweep_sequence(
			center,
			side_dir,
			radius * 1.18,
			14.0,
			1,
			0.12,
			12.0,
			0.18,
			"burn",
			0.9,
			max(1.0, base_damage * 0.06),
			false,
			120.0
		)

func _emit_rune_bloom(center: Vector2, aim_dir: Vector2, length: float, closure_phase: bool) -> void:
	var dir: Vector2 = aim_dir
	if dir.length_squared() <= 0.001:
		dir = Vector2.RIGHT
	var side: Vector2 = Vector2(-dir.y, dir.x)
	var half_len: float = max(80.0, length * 0.5)
	var petals: int = 4 if closure_phase else 3
	for i: int in range(petals):
		var angle: float = TAU * float(i) / float(max(1, petals))
		var sweep_dir: Vector2 = dir.rotated(angle)
		var offset: Vector2 = side.rotated(angle) * (20.0 if closure_phase else 12.0)
		_schedule_line_sweep_sequence(
			center + offset,
			sweep_dir,
			half_len * (1.8 if closure_phase else 1.5),
			14.0,
			1,
			0.07 + 0.03 * float(i),
			12.0,
			0.20 if not closure_phase else 0.28,
			"burn",
			1.0,
			max(1.0, _get_player_base_damage() * 0.07),
			false,
			150.0
		)
	if closure_phase:
		_spawn_pyro_patch(center, half_len * 0.32, 1.2, 0.20)
