extends "res://scenes/skills/skill_f_base.gd"

const ROLE_ID: String = "lurewarden"
const HERDER_E_PACK_META: String = "lurewarden_e_pack_until_msec"

func _resolve_f_role_id() -> String:
	return ROLE_ID

func _apply_mode_signature(phase: String, packet: Dictionary, center: Vector2, _hit_count: int) -> void:
	if not is_active:
		return
	_role_signature(phase, packet, center)
	_spawn_lurewarden_pickups(phase, packet, center)

func _apply_q_link_signature(phase: String, packet: Dictionary, center: Vector2) -> void:
	if phase == "tick":
		return
	var q_ctx: Dictionary = _resolve_recent_q_context()
	if q_ctx.is_empty():
		return
	var q_center_raw: Variant = q_ctx.get("center", center)
	var q_center: Vector2 = q_center_raw if q_center_raw is Vector2 else center
	var q_radius: float = max(90.0, float(q_ctx.get("radius", float(packet.get("radius", 140.0)))))
	var q_dir: Vector2 = _get_player_aim_direction()
	if q_dir.length_squared() <= 0.001:
		q_dir = Vector2.RIGHT
	var q_line_len: float = q_radius * 1.20

	if phase == "line":
		_knock_enemies_burst(q_center, q_radius * 0.7, 4, 140.0)
		_line_slice_burst(
			q_center - q_dir * q_line_len * 0.64,
			q_center + q_dir * q_line_len * 0.64,
			18.0,
			0.28,
			"marked",
			1.1,
			0.16,
			false,
			180.0
		)
		if _is_pack_window():
			_spawn_parallel_wall_pair(
				q_center,
				q_dir,
				q_radius * 1.24,
				52.0,
				0.9,
				int(max(1.0, _get_player_base_damage() * 0.14)),
				Color(0.94, 0.84, 0.34, 0.66)
			)

func _role_signature(phase: String, packet: Dictionary, center: Vector2) -> void:
	var radius: float = max(100.0, float(packet.get("radius", 120.0)) * 0.98)
	var inner_radius: float = radius * 0.35
	var targets: Array = _get_enemies_in_radius(center, radius)
	if targets.is_empty():
		return
	var base_damage: float = _get_player_base_damage()
	var hit: int = 0
	for enemy in targets:
		if hit >= 10:
			break
		if not is_instance_valid(enemy) or not (enemy is Node2D):
			continue
		var enemy_node: Node2D = enemy
		var dist: float = enemy_node.global_position.distance_to(center)
		if dist < inner_radius:
			continue
		_knock_enemy(enemy, center, 120.0 + (70.0 if phase == "closure" else 0.0))
		_damage_enemy(enemy, base_damage * (0.35 + (0.28 if phase == "closure" else 0.0)))
		_apply_enemy_status(enemy, "marked", 1.4, 0.16, 1, 0.4)
		hit += 1
	if phase == "line":
		var line_dir: Vector2 = _get_player_aim_direction()
		_emit_drive_corridor(center, line_dir, radius * 1.16, false)
	if phase == "closure" and hit > 0:
		_add_player_armor(1)
	if phase == "closure":
		var aim_dir: Vector2 = _get_player_aim_direction()
		_emit_drive_corridor(center, aim_dir, radius * 1.34, true)
		_spawn_parallel_wall_pair(
			center,
			aim_dir,
			radius * 1.5,
			70.0,
			1.4,
			int(max(1.0, base_damage * 0.22)),
			Color(0.92, 0.82, 0.35, 0.72)
		)
		_schedule_line_sweep_sequence(
			center,
			aim_dir,
			radius * 1.4,
			0.0,
			1,
			0.08,
			20.0,
			0.34,
			"marked",
			1.1,
			0.18,
			false,
			300.0
		)
		if _is_pack_window():
			_spawn_parallel_wall_pair(
				center,
				Vector2(-aim_dir.y, aim_dir.x),
				radius * 1.22,
				52.0,
				1.0,
				int(max(1.0, base_damage * 0.18)),
				Color(0.9, 0.78, 0.28, 0.64)
			)
			_knock_enemies_burst(center, radius * 0.86, 7, 240.0)

func _emit_drive_corridor(center: Vector2, aim_dir: Vector2, length: float, closure_phase: bool) -> void:
	var dir: Vector2 = aim_dir
	if dir.length_squared() <= 0.001:
		dir = Vector2.RIGHT
	var side: Vector2 = Vector2(-dir.y, dir.x)
	var half_len: float = max(90.0, length * 0.5)
	_spawn_parallel_wall_pair(
		center,
		dir,
		half_len * 1.9,
		56.0 if closure_phase else 46.0,
		1.2 if closure_phase else 0.95,
		int(max(1.0, _get_player_base_damage() * (0.20 if closure_phase else 0.14))),
		Color(0.94, 0.84, 0.34, 0.64)
	)
	_schedule_line_sweep_sequence(
		center + side * 28.0,
		dir,
		half_len * 1.9,
		18.0,
		2 if closure_phase else 1,
		0.10,
		18.0,
		0.28 if closure_phase else 0.22,
		"marked",
		1.1,
		0.16,
		false,
		240.0
	)
	_schedule_line_sweep_sequence(
		center - side * 28.0,
		dir,
		half_len * 1.9,
		18.0,
		2 if closure_phase else 1,
		0.10,
		18.0,
		0.28 if closure_phase else 0.22,
		"marked",
		1.1,
		0.16,
		false,
		240.0
	)
	if closure_phase:
		_knock_enemies_burst(center, half_len * 0.8, 6, 200.0)

func _is_pack_window() -> bool:
	return _is_e_window_active("lurewarden_pack_window", HERDER_E_PACK_META)

func _spawn_lurewarden_pickups(phase: String, packet: Dictionary, center: Vector2) -> void:
	var radius: float = max(58.0, float(packet.get("radius", 140.0)) * 0.58)
	var count: int = 1 if phase != "closure" else 2
	_spawn_signature_pickup_burst(
		center,
		count,
		radius,
		Color(0.72, 1.0, 0.3, 0.95),
		{
			"effect_id": "lurewarden_decoy",
			"pickup_text": "诱哨",
			"radius": radius,
			"text_color": Color(0.82, 1.0, 0.45),
			"vfx_color": Color(0.6, 1.0, 0.24, 0.90),
			"effect_scale": 0.56,
		},
		5.4 if phase == "tick" else 6.4
	)

