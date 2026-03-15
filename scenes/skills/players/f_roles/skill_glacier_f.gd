extends "res://scenes/skills/skill_f_base.gd"

const ROLE_ID: String = "glacier"
const GLACIER_E_SHATTER_META: String = "glacier_e_shatter_until_msec"

func _resolve_f_role_id() -> String:
	return ROLE_ID

func _apply_mode_signature(phase: String, packet: Dictionary, center: Vector2, _hit_count: int) -> void:
	if not is_active:
		return
	_role_signature(phase, packet, center)
	_spawn_glacier_pickups(phase, packet, center)

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
	var q_line_len: float = q_radius * 1.12

	_spawn_glacier_ring_walls(q_center, q_radius * 0.66, 1.3, 6, int(max(1.0, base_damage * 0.12)), 0.32, false)
	_line_slice_burst(
		q_center - q_dir * q_line_len * 0.46,
		q_center + q_dir * q_line_len * 0.46,
		20.0,
		0.22,
		"freeze",
		0.34,
		0.0,
		true,
		120.0
	)
	_line_slice_burst(
		q_center - q_side * q_line_len * 0.46,
		q_center + q_side * q_line_len * 0.46,
		20.0,
		0.22,
		"freeze",
		0.34,
		0.0,
		true,
		120.0
	)
	_spawn_glacier_core_zone(q_center, q_radius * 0.52, 1.7, int(max(1.0, base_damage * 0.20)), 0.50)
	if _is_shatter_window():
		_spawn_glacier_ring_walls(q_center, q_radius * 0.74, 1.1, 8, int(max(1.0, base_damage * 0.10)), 0.26, true)
		_schedule_line_sweep_sequence(
			q_center,
			q_side,
			q_radius * 1.26,
			24.0,
			2,
			0.10,
			16.0,
			0.22,
			"freeze",
			0.28,
			0.0,
			true,
			150.0
		)

func _role_signature(phase: String, packet: Dictionary, center: Vector2) -> void:
	var radius: float = max(96.0, float(packet.get("radius", 120.0)) * 1.02)
	var inner_radius: float = radius * (0.58 if phase == "closure" else (0.50 if phase == "line" else 0.42))
	var ring_radius: float = radius * (0.88 if phase != "tick" else 0.78)
	var base_damage: float = _get_player_base_damage()

	var core_damage_scale: float = 0.30
	var freeze_duration: float = 0.35
	var pull_distance: float = 3.0
	match phase:
		"line":
			core_damage_scale = 0.40
			freeze_duration = 0.55
			pull_distance = 6.0
		"closure":
			core_damage_scale = 0.56
			freeze_duration = 0.95
			pull_distance = 10.0
		_:
			core_damage_scale = 0.30
			freeze_duration = 0.35
			pull_distance = 3.0

	var enemies: Array = _get_enemies_in_radius(center, radius)
	for enemy in enemies:
		if not is_instance_valid(enemy) or not (enemy is Node2D):
			continue
		var enemy_node: Node2D = enemy
		var dist: float = enemy_node.global_position.distance_to(center)
		if dist <= inner_radius:
			_damage_enemy(enemy, base_damage * core_damage_scale, "FROST", Color(0.72, 0.95, 1.22))
			_apply_enemy_status(enemy, "freeze", freeze_duration, 0.0, 1, 0.1)
			if pull_distance > 0.0:
				_pull_enemy(enemy, center, pull_distance)
		elif dist <= ring_radius:
			_apply_enemy_status(enemy, "slow", 1.2 + (0.4 if phase == "closure" else 0.0), 0.36, 1, 0.1)
			if phase == "closure":
				_knock_enemy(enemy, center, 120.0)
		elif phase == "closure":
			_knock_enemy(enemy, center, 180.0)

	match phase:
		"line":
			_spawn_glacier_ring_walls(center, ring_radius, 1.25, 6, 0, 0.35, true)
			_emit_glacier_shatter_lane(center, _get_player_aim_direction(), ring_radius * 1.22, false)
			_schedule_line_sweep_sequence(
				center,
				_get_player_aim_direction(),
				ring_radius * 1.35,
				0.0,
				1,
				0.08,
				16.0,
				0.20,
				"freeze",
				0.30,
				0.0,
				true,
				120.0
			)
		"closure":
			_spawn_glacier_ring_walls(center, ring_radius, 2.0, 8, int(max(1.0, base_damage * 0.18)), 0.28, true)
			_spawn_glacier_core_zone(center, inner_radius * 1.06, 2.1, int(max(1.0, base_damage * 0.24)), 0.45)
			var glacier_dir: Vector2 = _get_player_aim_direction()
			_emit_glacier_shatter_lane(center, glacier_dir, ring_radius * 1.42, true)
			_spawn_parallel_wall_pair(
				center,
				glacier_dir,
				ring_radius * 1.2,
				72.0,
				1.4,
				int(max(1.0, base_damage * 0.14)),
				Color(0.62, 0.9, 1.18, 0.70)
			)
			_schedule_line_sweep_sequence(
				center,
				glacier_dir,
				ring_radius * 1.3,
				50.0,
				3,
				0.11,
				17.0,
				0.26,
				"freeze",
				0.36,
				0.0,
				true,
				160.0
			)
			if _is_shatter_window():
				_spawn_glacier_core_zone(center, inner_radius * 0.92, 1.4, int(max(1.0, base_damage * 0.18)), 0.38)
				_schedule_line_sweep_sequence(
					center,
					Vector2(-glacier_dir.y, glacier_dir.x),
					ring_radius * 1.14,
					34.0,
					2,
					0.09,
					15.0,
					0.20,
					"freeze",
					0.30,
					0.0,
					true,
					130.0
				)
		_:
			pass

func _emit_glacier_shatter_lane(center: Vector2, aim_dir: Vector2, length: float, closure_phase: bool) -> void:
	var dir: Vector2 = aim_dir
	if dir.length_squared() <= 0.001:
		dir = Vector2.RIGHT
	var side: Vector2 = Vector2(-dir.y, dir.x)
	var half_len: float = max(90.0, length * 0.5)
	_line_slice_burst(
		center - dir * half_len,
		center + dir * half_len,
		24.0,
		0.24 if not closure_phase else 0.34,
		"freeze",
		0.30 if not closure_phase else 0.46,
		0.0,
		true,
		140.0
	)
	_schedule_line_sweep_sequence(
		center + side * 26.0,
		dir.rotated(0.22),
		half_len * 1.6,
		20.0,
		1 if not closure_phase else 2,
		0.10,
		14.0,
		0.20 if not closure_phase else 0.26,
		"freeze",
		0.26 if not closure_phase else 0.34,
		0.0,
		true,
		130.0
	)
	_schedule_line_sweep_sequence(
		center - side * 26.0,
		dir.rotated(-0.22),
		half_len * 1.6,
		20.0,
		1 if not closure_phase else 2,
		0.10,
		14.0,
		0.20 if not closure_phase else 0.26,
		"freeze",
		0.26 if not closure_phase else 0.34,
		0.0,
		true,
		130.0
	)
	if closure_phase:
		_knock_enemies_burst(center, half_len * 0.82, 6, 165.0)

func _is_shatter_window() -> bool:
	return _is_e_window_active("glacier_shatter_window", GLACIER_E_SHATTER_META)

func _spawn_glacier_pickups(phase: String, packet: Dictionary, center: Vector2) -> void:
	var radius: float = max(54.0, float(packet.get("radius", 140.0)) * 0.52)
	var count: int = 1 if phase != "closure" else 2
	_spawn_signature_pickup_burst(
		center,
		count,
		radius,
		Color(0.68, 0.96, 1.0, 0.95),
		{
			"effect_id": "glacier_wedge",
			"pickup_text": "冰楔",
			"radius": radius,
			"text_color": Color(0.78, 0.98, 1.0),
			"vfx_color": Color(0.62, 0.9, 1.0, 0.92),
			"effect_scale": 0.58,
		},
		5.4 if phase == "tick" else 6.6
	)
