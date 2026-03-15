extends "res://scenes/skills/skill_f_base.gd"

const ROLE_ID: String = "butcher"
const BUTCHER_E_CHAIN_META: String = "butcher_e_chain_until_msec"

func _resolve_f_role_id() -> String:
	return ROLE_ID

func _apply_mode_signature(phase: String, packet: Dictionary, center: Vector2, _hit_count: int) -> void:
	if not is_active:
		return
	_role_signature(phase, packet, center)
	_spawn_butcher_pickups(phase, packet, center)

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
	var q_dir: Vector2 = _get_player_aim_direction()
	if q_dir.length_squared() <= 0.001:
		q_dir = Vector2.RIGHT
	var q_line_len: float = q_radius * 1.22
	var base_damage: float = _get_player_base_damage()

	_pull_enemies_burst(q_center, q_radius * 0.74, 3, 20.0)
	_line_slice_burst(
		q_center - q_dir * q_line_len * 0.56,
		q_center + q_dir * q_line_len * 0.56,
		24.0,
		0.36,
		"curse",
		1.2,
		max(1.0, base_damage * 0.12),
		true,
		240.0
	)
	_spawn_parallel_wall_pair(
		q_center,
		q_dir,
		q_radius * 1.30,
		62.0,
		1.3,
		int(max(1.0, base_damage * 0.20)),
		Color(0.92, 0.28, 0.26, 0.68)
	)
	if _is_chain_window():
		_pull_enemies_burst(q_center, q_radius * 0.92, 6, 18.0)
		_schedule_line_sweep_sequence(
			q_center,
			Vector2(-q_dir.y, q_dir.x),
			q_radius * 1.42,
			36.0,
			2,
			0.10,
			18.0,
			0.32,
			"curse",
			1.1,
			max(1.0, base_damage * 0.09),
			true,
			230.0
		)

func _role_signature(phase: String, packet: Dictionary, center: Vector2) -> void:
	var radius: float = max(80.0, float(packet.get("radius", 120.0)) * 0.84)
	var targets: Array = _sort_enemies_by_distance(_get_enemies_in_radius(center, radius), center)
	if targets.is_empty():
		return
	var limit: int = 1
	var damage_scale: float = 0.45
	match phase:
		"line":
			limit = 2
			damage_scale = 0.62
		"closure":
			limit = 3
			damage_scale = 0.92
		_:
			limit = 1
			damage_scale = 0.45
	var base_damage: float = _get_player_base_damage()
	var chain_window: bool = _is_chain_window()
	for i: int in range(min(limit, targets.size())):
		var enemy: Node = targets[i]
		_pull_enemy(enemy, center, 14.0 + 8.0 * float(i))
		var final_scale: float = damage_scale + (0.12 if chain_window else 0.0)
		_damage_enemy(enemy, base_damage * final_scale, "RIP", Color(1.0, 0.35, 0.35))
		_apply_enemy_status(enemy, "curse", 1.2 + (0.4 if phase == "closure" else 0.0), max(1.0, base_damage * 0.12), 1, 0.6)
		if phase != "tick" and _is_enemy_below_threshold(enemy, 0.28):
			_damage_enemy(enemy, base_damage * 3.1, "EXEC", Color(1.0, 0.24, 0.24))
	if phase == "line":
		var line_dir: Vector2 = _get_player_aim_direction()
		_emit_chain_scissor(center, line_dir, radius * 1.22, chain_window, base_damage)
	if phase == "closure":
		var aim_dir: Vector2 = _get_player_aim_direction()
		_schedule_line_sweep_sequence(
			center,
			aim_dir,
			radius * 1.65,
			46.0,
			3,
			0.12,
			18.0,
			0.38,
			"curse",
			1.1,
			max(1.0, base_damage * 0.10),
			true,
			220.0
		)
		_spawn_parallel_wall_pair(
			center,
			aim_dir,
			radius * 1.46,
			58.0,
			1.2,
			int(max(1.0, base_damage * 0.18)),
			Color(0.96, 0.32, 0.30, 0.66)
		)
		_emit_chain_scissor(center, aim_dir, radius * 1.38, true, base_damage)
		if chain_window:
			_spawn_parallel_wall_pair(
				center,
				Vector2(-aim_dir.y, aim_dir.x),
				radius * 1.26,
				42.0,
				1.0,
				int(max(1.0, base_damage * 0.16)),
				Color(0.96, 0.30, 0.28, 0.58)
			)
	_heal_player(base_damage * (0.04 + 0.01 * float(limit)))

func _emit_chain_scissor(center: Vector2, aim_dir: Vector2, length: float, chain_window: bool, base_damage: float) -> void:
	var dir: Vector2 = aim_dir
	if dir.length_squared() <= 0.001:
		dir = Vector2.RIGHT
	var side: Vector2 = Vector2(-dir.y, dir.x)
	var half_len: float = max(70.0, length * 0.5)
	_line_slice_burst(
		center - dir * half_len,
		center + dir * half_len,
		24.0,
		0.30,
		"curse",
		1.2,
		max(1.0, base_damage * 0.10),
		true,
		220.0
	)
	_line_slice_burst(
		center - side * half_len * 0.74,
		center + side * half_len * 0.74,
		20.0,
		0.24,
		"marked",
		1.0,
		0.18,
		true,
		180.0
	)
	if chain_window:
		_schedule_line_sweep_sequence(
			center,
			dir.rotated(0.42),
			half_len * 2.0,
			26.0,
			2,
			0.10,
			16.0,
			0.30,
			"curse",
			1.1,
			max(1.0, base_damage * 0.09),
			true,
			200.0
		)
		_schedule_line_sweep_sequence(
			center,
			dir.rotated(-0.42),
			half_len * 2.0,
			26.0,
			2,
			0.10,
			16.0,
			0.30,
			"curse",
			1.1,
			max(1.0, base_damage * 0.09),
			true,
			200.0
		)

func _is_chain_window() -> bool:
	return _is_e_window_active("butcher_hook_window", BUTCHER_E_CHAIN_META)

func _spawn_butcher_pickups(phase: String, packet: Dictionary, center: Vector2) -> void:
	var radius: float = max(54.0, float(packet.get("radius", 140.0)) * 0.54)
	var count: int = 1 if phase != "closure" else 2
	_spawn_signature_pickup_burst(
		center,
		count,
		radius,
		Color(1.0, 0.24, 0.22, 0.95),
		{
			"effect_id": "butcher_hook",
			"pickup_text": "血钩碎片",
			"radius": radius,
			"text_color": Color(1.0, 0.4, 0.32),
			"vfx_color": Color(1.0, 0.2, 0.2, 0.92),
			"effect_scale": 0.56,
		},
		5.2 if phase == "tick" else 6.4
	)
