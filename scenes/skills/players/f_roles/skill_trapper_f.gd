extends "res://scenes/skills/skill_f_base.gd"

const ROLE_ID: String = "trapper"

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

	if q_closed or phase == "closure":
		var target: Node2D = _pick_trapper_target(q_center, q_radius)
		if target != null:
			_damage_enemy(target, _get_player_base_damage() * 0.78, "HUNT", Color(1.0, 0.85, 0.3))
			_apply_enemy_status(target, "marked", 1.6, 0.28, 1, 0.4)
			get_tree().create_timer(0.12).timeout.connect(_on_trapper_shot_timeout.bind(weakref(target), 0.52))
		_emit_crosshair_lance(q_center, q_dir, q_radius * 1.24, true)
		_line_slice_burst(
			q_center - q_dir * q_line_len * 0.66,
			q_center + q_dir * q_line_len * 0.66,
			12.0,
			0.30,
			"marked",
			1.0,
			0.22,
			false,
			120.0
		)
		_schedule_line_sweep_sequence(
			q_center,
			q_side,
			q_radius * 1.20,
			14.0,
			2,
			0.11,
			12.0,
			0.20,
			"marked",
			0.9,
			0.18,
			false,
			110.0
		)
	else:
		_line_slice_burst(
			q_center - q_dir * q_line_len * 0.52,
			q_center + q_dir * q_line_len * 0.20,
			10.0,
			0.18,
			"marked",
			0.8,
			0.18,
			false,
			80.0
		)

func _role_signature(phase: String, packet: Dictionary, center: Vector2) -> void:
	var radius: float = max(110.0, float(packet.get("radius", 120.0)) * 1.1)
	var target: Node2D = _pick_trapper_target(center, radius)
	if target == null:
		return
	var mark_time: float = 1.6 if phase != "closure" else 2.3
	var mark_value: float = 0.22 if phase != "closure" else 0.34
	_apply_enemy_status(target, "marked", mark_time, mark_value, 1, 0.4)
	_apply_enemy_status(target, "slow", 1.0, 0.28, 1, 0.1)
	var delay: float = 0.2 if phase != "closure" else 0.12
	var shot_scale: float = 0.56 if phase != "closure" else 1.05
	get_tree().create_timer(delay).timeout.connect(_on_trapper_shot_timeout.bind(weakref(target), shot_scale))
	var trapper_dir: Vector2 = _get_player_aim_direction()
	var trapper_side: Vector2 = Vector2(-trapper_dir.y, trapper_dir.x)
	if phase == "line":
		_emit_crosshair_lance(center, trapper_dir, radius * 1.10, false)
		_schedule_line_sweep_sequence(
			center,
			trapper_dir,
			radius * 1.45,
			0.0,
			1,
			0.08,
			12.0,
			0.24,
			"marked",
			1.0,
			0.18,
			false,
			100.0
		)
	elif phase == "closure":
		_emit_crosshair_lance(center, trapper_dir, radius * 1.32, true)
		_schedule_line_sweep_sequence(
			center,
			trapper_dir,
			radius * 1.6,
			28.0,
			2,
			0.10,
			12.0,
			0.30,
			"marked",
			1.2,
			0.22,
			false,
			120.0
		)
		_schedule_line_sweep_sequence(
			center,
			trapper_side,
			radius * 1.24,
			16.0,
			1,
			0.12,
			11.0,
			0.22,
			"marked",
			1.0,
			0.18,
			false,
			100.0
		)
		_apply_temp_attack_boost(1.5, 0.10)

func _emit_crosshair_lance(center: Vector2, aim_dir: Vector2, length: float, closure_phase: bool) -> void:
	var dir: Vector2 = aim_dir
	if dir.length_squared() <= 0.001:
		dir = Vector2.RIGHT
	var side: Vector2 = Vector2(-dir.y, dir.x)
	var half_len: float = max(88.0, length * 0.5)
	_line_slice_burst(
		center - dir * half_len,
		center + dir * half_len,
		10.0,
		0.20 if not closure_phase else 0.30,
		"marked",
		1.0,
		0.20,
		false,
		110.0
	)
	_line_slice_burst(
		center - side * half_len * 0.82,
		center + side * half_len * 0.82,
		10.0,
		0.14 if not closure_phase else 0.22,
		"marked",
		0.9,
		0.18,
		false,
		100.0
	)
	if closure_phase:
		_schedule_line_sweep_sequence(
			center + dir * half_len * 0.55,
			-dir,
			half_len * 1.4,
			14.0,
			1,
			0.08,
			12.0,
			0.22,
			"marked",
			1.1,
			0.20,
			false,
			120.0
		)
