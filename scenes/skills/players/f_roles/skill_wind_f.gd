extends "res://scenes/skills/skill_f_base.gd"

const ROLE_ID: String = "wind"
const WIND_E_GUST_META: String = "wind_e_gust_until_msec"

func _resolve_f_role_id() -> String:
	return ROLE_ID

func _apply_mode_signature(phase: String, packet: Dictionary, center: Vector2, _hit_count: int) -> void:
	if not is_active:
		return
	_role_signature(phase, packet, center)
	_spawn_wind_pickups(phase, packet, center)

func _apply_q_link_signature(phase: String, packet: Dictionary, center: Vector2) -> void:
	if phase == "tick":
		return
	var q_ctx: Dictionary = _resolve_recent_q_context()
	if q_ctx.is_empty():
		return
	if not bool(q_ctx.get("is_closed", false)):
		return
	var q_center_raw: Variant = q_ctx.get("center", center)
	var q_center: Vector2 = q_center_raw if q_center_raw is Vector2 else center
	var q_radius: float = max(90.0, float(q_ctx.get("radius", float(packet.get("radius", 140.0)))))
	var base_damage: float = _get_player_base_damage()
	var q_dir: Vector2 = _get_player_aim_direction()
	if q_dir.length_squared() <= 0.001:
		q_dir = Vector2.RIGHT
	var q_side: Vector2 = Vector2(-q_dir.y, q_dir.x)
	var q_line_len: float = q_radius * 1.18

	_pull_enemies_burst(q_center, q_radius * 0.92, 5, 14.0)
	_line_slice_burst(
		q_center - q_side * q_line_len * 0.58,
		q_center + q_side * q_line_len * 0.58,
		24.0,
		0.24,
		"slow",
		1.0,
		0.26,
		true,
		200.0
	)
	_line_slice_burst(
		q_center - q_dir * q_line_len * 0.42,
		q_center + q_dir * q_line_len * 0.42,
		16.0,
		0.18,
		"slow",
		0.9,
		0.22,
		true,
		140.0
	)
	_schedule_line_sweep_sequence(
		q_center,
		q_side,
		q_radius * 1.55,
		36.0,
		2,
		0.12,
		16.0,
		0.20,
		"slow",
		0.9,
		0.24,
		true,
		160.0
	)
	if _is_gust_window():
		_schedule_line_sweep_sequence(
			q_center,
			-q_side,
			q_radius * 1.45,
			20.0,
			1,
			0.10,
			15.0,
			0.24,
			"slow",
			1.0,
			0.24,
			true,
			180.0
		)
		_heal_player(base_damage * 0.06)
	_apply_status_burst(q_center, q_radius * 0.68, 4, "slow", 1.0, 0.30)
	_heal_player(base_damage * 0.04)

func _role_signature(phase: String, packet: Dictionary, center: Vector2) -> void:
	var radius: float = max(85.0, float(packet.get("radius", 120.0)) * 0.82)
	var targets: Array = _sort_enemies_by_distance(_get_enemies_in_radius(center, radius), center)
	if targets.is_empty():
		return
	var base_damage: float = _get_player_base_damage()
	var limit: int = 3 if phase != "closure" else 5
	for i: int in range(min(limit, targets.size())):
		var enemy: Node = targets[i]
		_pull_enemy(enemy, center, 14.0 + (10.0 if phase == "closure" else 6.0))
		_apply_enemy_status(enemy, "slow", 1.0 + 0.2 * float(i), 0.30, 1, 0.1)
		if phase == "closure":
			_damage_enemy(enemy, base_damage * 0.42)
	if phase == "line":
		var line_dir: Vector2 = _get_player_aim_direction()
		_emit_wind_tunnel(center, line_dir, radius * 1.36, false)
	if phase == "closure":
		var aim_dir: Vector2 = _get_player_aim_direction()
		_emit_wind_tunnel(center, aim_dir, radius * 1.56, true)
		_schedule_line_sweep_sequence(
			center,
			Vector2(-aim_dir.y, aim_dir.x),
			radius * 1.8,
			42.0,
			3,
			0.09,
			22.0,
			0.28,
			"slow",
			1.0,
			0.28,
			true,
			220.0
		)
		if _is_gust_window():
			_pull_enemies_burst(center, radius * 1.02, 7, 18.0)
			_schedule_line_sweep_sequence(
				center,
				aim_dir,
				radius * 1.54,
				20.0,
				2,
				0.08,
				18.0,
				0.24,
				"slow",
				1.0,
				0.26,
				true,
				200.0
			)

func _emit_wind_tunnel(center: Vector2, aim_dir: Vector2, length: float, closure_phase: bool) -> void:
	var dir: Vector2 = aim_dir
	if dir.length_squared() <= 0.001:
		dir = Vector2.RIGHT
	var side: Vector2 = Vector2(-dir.y, dir.x)
	var half_len: float = max(90.0, length * 0.5)
	var sweep_count: int = 3 if closure_phase else 2
	for i: int in range(sweep_count):
		var offset_t: float = -0.45 + (0.45 * 2.0 * float(i) / float(max(1, sweep_count - 1)))
		var offset: Vector2 = side * (offset_t * 64.0)
		_schedule_line_sweep_sequence(
			center + offset,
			dir,
			half_len * 1.9,
			20.0,
			1,
			0.08 + float(i) * 0.02,
			15.0,
			0.22 if not closure_phase else 0.30,
			"slow",
			1.0,
			0.24,
			true,
			180.0
		)
	if closure_phase:
		_schedule_line_sweep_sequence(
			center + dir * half_len * 0.55,
			-dir,
			half_len * 1.4,
			26.0,
			2,
			0.08,
			16.0,
			0.26,
			"slow",
			1.0,
			0.24,
			true,
			220.0
		)
		_pull_enemies_burst(center + dir * half_len * 0.25, half_len * 0.95, 7, 16.0)

func _is_gust_window() -> bool:
	if not is_instance_valid(player_ref):
		return false
	if not player_ref.has_meta(WIND_E_GUST_META):
		return false
	var expire_msec: int = int(player_ref.get_meta(WIND_E_GUST_META))
	return Time.get_ticks_msec() <= expire_msec

func _spawn_wind_pickups(phase: String, packet: Dictionary, center: Vector2) -> void:
	var radius: float = max(58.0, float(packet.get("radius", 140.0)) * 0.56)
	var count: int = 1 if phase != "closure" else 2
	_spawn_signature_pickup_burst(
		center,
		count,
		radius,
		Color(0.55, 1.0, 1.0, 0.95),
		{
			"effect_id": "wind_gust",
			"pickup_text": "风痕羽片",
			"radius": radius,
			"text_color": Color(0.68, 1.0, 1.0),
			"vfx_color": Color(0.45, 1.0, 0.96, 0.92),
			"effect_scale": 0.56,
		},
		5.0 if phase == "tick" else 6.2
	)
