extends "res://scenes/skills/skill_f_base.gd"

const ROLE_ID: String = "spiritcaller"
const TOTEM_META_CENTER: String = "spiritcaller_field_center"
const TOTEM_META_RADIUS: String = "spiritcaller_field_radius"
const TOTEM_META_EXPIRE_MSEC: String = "spiritcaller_field_expire_msec"

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

	if q_closed:
		_on_spiritcaller_pulse_timeout(q_center, q_radius * 0.72, 0.30, true)
		get_tree().create_timer(0.18).timeout.connect(
			_on_spiritcaller_pulse_timeout.bind(q_center + q_dir * (q_radius * 0.22), q_radius * 0.66, 0.24, false)
		)
		_line_slice_burst(
			q_center - q_side * q_line_len * 0.56,
			q_center + q_side * q_line_len * 0.56,
			16.0,
			0.20,
			"marked",
			1.0,
			0.18,
			true,
			130.0
		)
		_schedule_line_sweep_sequence(
			q_center,
			q_dir,
			q_radius * 1.24,
			24.0,
			2,
			0.10,
			14.0,
			0.20,
			"marked",
			0.9,
			0.16,
			true,
			130.0
		)
		if _is_totem_window():
			_on_spiritcaller_pulse_timeout(q_center, q_radius * 0.60, 0.26, true)
	else:
		_on_spiritcaller_pulse_timeout(q_center, q_radius * 0.50, 0.18, false)
		_line_slice_burst(
			q_center - q_dir * q_line_len * 0.42,
			q_center + q_dir * q_line_len * 0.42,
			12.0,
			0.12,
			"marked",
			0.8,
			0.14,
			true,
			70.0
		)
		if _is_totem_window():
			get_tree().create_timer(0.12).timeout.connect(
				_on_spiritcaller_pulse_timeout.bind(q_center, q_radius * 0.46, 0.16, false)
			)

func _role_signature(phase: String, packet: Dictionary, center: Vector2) -> void:
	_signature_spiritcaller(phase, packet, center)
	var radius: float = max(90.0, float(packet.get("radius", 120.0)) * 0.96)
	var aim_dir: Vector2 = _get_player_aim_direction()
	var side_dir: Vector2 = Vector2(-aim_dir.y, aim_dir.x)
	if phase == "line":
		_on_spiritcaller_pulse_timeout(center, radius * 0.52, 0.18, false)
		_line_slice_burst(
			center - aim_dir * radius * 0.64,
			center + aim_dir * radius * 0.64,
			12.0,
			0.12,
			"marked",
			0.8,
			0.14,
			true,
			80.0
		)
		_spawn_parallel_wall_pair(
			center,
			aim_dir,
			radius * 1.18,
			36.0,
			0.9,
			int(max(1.0, _get_player_base_damage() * 0.12)),
			Color(0.84, 0.62, 1.0, 0.62)
		)
		_gain_energy(0.4)
	elif phase == "closure":
		_on_spiritcaller_pulse_timeout(center, radius * 0.74, 0.28, true)
		get_tree().create_timer(0.20).timeout.connect(
			_on_spiritcaller_pulse_timeout.bind(center + side_dir * (radius * 0.26), radius * 0.64, 0.22, false)
		)
		_schedule_line_sweep_sequence(
			center,
			aim_dir,
			radius * 1.34,
			16.0,
			2,
			0.12,
			14.0,
			0.20,
			"marked",
			0.9,
			0.16,
			true,
			140.0
		)
		_schedule_line_sweep_sequence(
			center,
			side_dir,
			radius * 1.20,
			28.0,
			2,
			0.12,
			12.0,
			0.18,
			"marked",
			0.9,
			0.15,
			true,
			120.0
		)
		_spawn_parallel_wall_pair(
			center,
			side_dir,
			radius * 1.26,
			44.0,
			1.0,
			int(max(1.0, _get_player_base_damage() * 0.14)),
			Color(0.9, 0.72, 1.0, 0.64)
		)
		_gain_energy(0.8)

func _is_totem_window() -> bool:
	if not is_instance_valid(player_ref):
		return false
	if not player_ref.has_meta(TOTEM_META_EXPIRE_MSEC):
		return false
	var expire_msec: int = int(player_ref.get_meta(TOTEM_META_EXPIRE_MSEC, 0))
	return Time.get_ticks_msec() <= expire_msec
