extends "res://scenes/skills/skill_f_base.gd"

const ROLE_ID: String = "arcstriker"
const TESLA_E_META_CENTER: String = "arcstriker_e_overload_center"
const TESLA_E_META_RADIUS: String = "arcstriker_e_overload_radius"
const TESLA_E_META_EXPIRE_MSEC: String = "arcstriker_e_overload_expire_msec"
const TESLA_E_META_ARC_HITS: String = "arcstriker_e_overload_arc_hits"

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
		_apply_status_burst(q_center, q_radius * 0.78, 4, "stun", 0.32, 0.0)
		_emit_arcstriker_grid(q_center, q_dir, q_radius * 1.22, true)
		_line_slice_burst(q_center - q_side * q_line_len * 0.62, q_center + q_side * q_line_len * 0.62, 18.0, 0.26, "stun", 0.24, 0.0, false, 160.0)
		var overload_data: Array = _get_e_overload_window(q_center, q_radius)
		if bool(overload_data[0]):
			var overload_radius: float = float(overload_data[2]) if overload_data.size() > 2 else q_radius
			_line_slice_burst(
				q_center - q_dir * overload_radius * 0.72,
				q_center + q_dir * overload_radius * 0.72,
				16.0,
				0.22,
				"stun",
				0.22,
				0.0,
				false,
				180.0
			)
	else:
		_line_slice_burst(q_center - q_dir * q_line_len * 0.56, q_center + q_dir * q_line_len * 0.56, 14.0, 0.20, "marked", 0.9, 0.16, false, 100.0)

func _role_signature(phase: String, packet: Dictionary, center: Vector2) -> void:
	var radius: float = max(100.0, float(packet.get("radius", 120.0)) * 1.08)
	var jump_count: int = 2
	var link_range: float = radius * 0.72
	var base_scale: float = 0.42
	var overload_data: Array = _get_e_overload_window(center, radius)
	var overload_active: bool = bool(overload_data[0])
	var overload_arc_hits: int = int(overload_data[3]) if overload_data.size() > 3 else 0
	if overload_active:
		var overload_center: Variant = overload_data[1]
		if overload_center is Vector2:
			center = center.lerp(overload_center, 0.55)
		var overload_radius: float = float(overload_data[2]) if overload_data.size() > 2 else radius
		radius = max(radius, overload_radius * 0.86)
	match phase:
		"line":
			jump_count = 3
			base_scale = 0.48
		"closure":
			jump_count = 5
			link_range = radius * 0.88
			base_scale = 0.62
		_:
			jump_count = 2
			base_scale = 0.42
	if overload_active:
		var jump_bonus: int = 1 + (1 if phase == "closure" else 0)
		jump_bonus += min(2, int(round(float(overload_arc_hits) / 4.0)))
		jump_count += jump_bonus
		link_range *= 1.10 + min(0.20, float(overload_arc_hits) * 0.015)
		base_scale *= 1.12 if phase == "line" else 1.18
	var chain: Array = _build_chain_targets(center, radius, jump_count, link_range)
	if chain.is_empty():
		return
	var base_damage: float = _get_player_base_damage()
	for i: int in range(chain.size()):
		var enemy: Node = chain[i]
		var step_scale: float = max(0.55, 1.0 - 0.1 * float(i))
		_damage_enemy(enemy, base_damage * base_scale * step_scale, "ARC", Color(0.45, 0.95, 1.3))
		var stun_duration: float = 0.38 + 0.08 * float(i == 0)
		if overload_active:
			stun_duration += 0.08
		_apply_enemy_status(enemy, "stun", stun_duration, 0.0, 1, 0.1)
		_apply_enemy_status(enemy, "marked", 1.2, 0.18, 1, 0.3)
	var arcstriker_dir: Vector2 = _get_player_aim_direction()
	if phase == "line":
		_emit_arcstriker_grid(center, arcstriker_dir, radius * 1.26, false)
		_schedule_line_sweep_sequence(
			center,
			arcstriker_dir,
			radius * 1.45,
			34.0,
			2,
			0.10,
			14.0,
			0.24,
			"stun",
			0.18,
			0.0,
			false,
			120.0
		)
	elif phase == "closure":
		_emit_arcstriker_grid(center, arcstriker_dir, radius * 1.46, true)
		_schedule_line_sweep_sequence(
			center,
			arcstriker_dir,
			radius * 1.55,
			40.0,
			3,
			0.08,
			15.0,
			0.28,
			"stun",
			0.22,
			0.0,
			false,
			150.0
		)
		_schedule_line_sweep_sequence(
			center,
			Vector2(-arcstriker_dir.y, arcstriker_dir.x),
			radius * 1.35,
			32.0,
			2,
			0.12,
			13.0,
			0.20,
			"marked",
			1.0,
			0.16,
			false,
			100.0
		)
	if overload_active:
		_schedule_line_sweep_sequence(
			center,
			Vector2(-arcstriker_dir.y, arcstriker_dir.x),
			radius * (1.25 if phase == "line" else 1.45),
			24.0,
			1 if phase == "line" else 2,
			0.09,
			13.0,
			0.20 if phase == "line" else 0.26,
			"stun",
			0.20,
			0.0,
			false,
			130.0 if phase == "line" else 170.0
		)
		if phase == "closure":
			_consume_e_overload_window()

func _emit_arcstriker_grid(center: Vector2, aim_dir: Vector2, length: float, closure_phase: bool) -> void:
	var dir: Vector2 = aim_dir
	if dir.length_squared() <= 0.001:
		dir = Vector2.RIGHT
	var side: Vector2 = Vector2(-dir.y, dir.x)
	var half_len: float = max(90.0, length * 0.5)
	_line_slice_burst(
		center - dir * half_len,
		center + dir * half_len,
		18.0,
		0.20 if not closure_phase else 0.30,
		"stun",
		0.18 if not closure_phase else 0.26,
		0.0,
		false,
		160.0
	)
	_line_slice_burst(
		center - side * half_len * 0.86,
		center + side * half_len * 0.86,
		18.0,
		0.20 if not closure_phase else 0.30,
		"marked",
		1.0,
		0.18,
		false,
		160.0
	)
	if closure_phase:
		_schedule_line_sweep_sequence(
			center,
			dir.rotated(0.45),
			half_len * 1.8,
			18.0,
			1,
			0.08,
			13.0,
			0.24,
			"stun",
			0.22,
			0.0,
			false,
			140.0
		)
		_schedule_line_sweep_sequence(
			center,
			dir.rotated(-0.45),
			half_len * 1.8,
			18.0,
			1,
			0.08,
			13.0,
			0.24,
			"stun",
			0.22,
			0.0,
			false,
			140.0
		)

func _get_e_overload_window(default_center: Vector2, default_radius: float) -> Array:
	var data: Array = [false, default_center, default_radius, 0]
	if not is_instance_valid(player_ref):
		return data
	if not player_ref.has_meta(TESLA_E_META_EXPIRE_MSEC):
		return data
	var expire_msec: int = int(player_ref.get_meta(TESLA_E_META_EXPIRE_MSEC, 0))
	if Time.get_ticks_msec() > expire_msec:
		return data
	var center_val: Variant = player_ref.get_meta(TESLA_E_META_CENTER, default_center)
	var radius_val: Variant = player_ref.get_meta(TESLA_E_META_RADIUS, default_radius)
	var arc_val: Variant = player_ref.get_meta(TESLA_E_META_ARC_HITS, 0)
	if not (center_val is Vector2):
		return data
	data[0] = true
	data[1] = center_val
	data[2] = max(default_radius, float(radius_val))
	data[3] = max(0, int(arc_val))
	return data

func _consume_e_overload_window() -> void:
	if not is_instance_valid(player_ref):
		return
	player_ref.remove_meta(TESLA_E_META_EXPIRE_MSEC)
	player_ref.remove_meta(TESLA_E_META_ARC_HITS)
