extends "res://scenes/skills/skill_f_base.gd"

const ROLE_ID: String = "swarm"

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
		_apply_status_burst(q_center, q_radius * 0.92, 7, "poison", 1.2, max(1.0, base_damage * 0.10))
		_pull_enemies_burst(q_center, q_radius * 0.84, 6, 10.0)
		_emit_swarm_orbit(q_center, q_dir, q_radius * 1.22, true)
		_line_slice_burst(
			q_center - q_side * q_line_len * 0.68,
			q_center + q_side * q_line_len * 0.68,
			20.0,
			0.22,
			"poison",
			1.1,
			max(1.0, base_damage * 0.08),
			false,
			130.0
		)
		_schedule_line_sweep_sequence(
			q_center,
			q_dir,
			q_radius * 1.36,
			18.0,
			2,
			0.11,
			14.0,
			0.22,
			"poison",
			1.1,
			max(1.0, base_damage * 0.08),
			false,
			140.0
		)
	else:
		_line_slice_burst(
			q_center - q_dir * q_line_len * 0.40,
			q_center + q_dir * q_line_len * 0.40,
			14.0,
			0.16,
			"poison",
			0.8,
			max(1.0, base_damage * 0.05),
			false,
			80.0
		)

func _role_signature(phase: String, packet: Dictionary, center: Vector2) -> void:
	var radius: float = max(90.0, float(packet.get("radius", 120.0)) * 1.12)
	var target: Node2D = _pick_nearest_enemy(center, radius * 1.2, [])
	if SkillEffectManager != null and SkillEffectManager.has_method("command_summons"):
		SkillEffectManager.command_summons("skill_swarm_q", "focus_fire", target)
	var boost: float = 0.07
	var boost_duration: float = 1.6
	if phase == "line":
		boost = 0.1
		boost_duration = 1.9
	elif phase == "closure":
		boost = 0.14
		boost_duration = 2.4
	_apply_temp_attack_boost(boost_duration, boost)
	if phase == "closure":
		var burst_center: Vector2 = target.global_position if target != null else center
		var burst_damage: float = _get_player_base_damage() * 0.46
		for enemy in _get_enemies_in_radius(burst_center, radius * 0.45):
			_damage_enemy(enemy, burst_damage)
			_apply_enemy_status(enemy, "poison", 1.6, max(1.0, burst_damage * 0.4), 1, 0.6)
	var swarm_dir: Vector2 = _get_player_aim_direction()
	var swarm_side: Vector2 = Vector2(-swarm_dir.y, swarm_dir.x)
	if phase == "line":
		_emit_swarm_orbit(center, swarm_dir, radius * 1.10, false)
		_schedule_line_sweep_sequence(
			center,
			swarm_dir,
			radius * 1.35,
			30.0,
			2,
			0.12,
			14.0,
			0.20,
			"poison",
			1.0,
			max(1.0, _get_player_base_damage() * 0.08),
			false,
			110.0
		)
	elif phase == "closure":
		_emit_swarm_orbit(center, swarm_dir, radius * 1.32, true)
		_schedule_line_sweep_sequence(
			center,
			swarm_dir,
			radius * 1.5,
			36.0,
			3,
			0.10,
			15.0,
			0.24,
			"poison",
			1.2,
			max(1.0, _get_player_base_damage() * 0.10),
			false,
			130.0
		)
		_schedule_line_sweep_sequence(
			center,
			swarm_side,
			radius * 1.24,
			18.0,
			1,
			0.13,
			13.0,
			0.18,
			"poison",
			1.0,
			max(1.0, _get_player_base_damage() * 0.08),
			false,
			100.0
		)

func _emit_swarm_orbit(center: Vector2, aim_dir: Vector2, length: float, closure_phase: bool) -> void:
	var dir: Vector2 = aim_dir
	if dir.length_squared() <= 0.001:
		dir = Vector2.RIGHT
	var side: Vector2 = Vector2(-dir.y, dir.x)
	var half_len: float = max(80.0, length * 0.5)
	var segments: int = 4 if closure_phase else 3
	for i: int in range(segments):
		var t: float = float(i) / float(max(1, segments - 1))
		var offset: Vector2 = side * lerp(-56.0, 56.0, t)
		_schedule_line_sweep_sequence(
			center + offset,
			dir.rotated(lerp(-0.25, 0.25, t)),
			half_len * 1.6,
			14.0,
			1,
			0.08 + 0.03 * float(i),
			12.0,
			0.16 if not closure_phase else 0.22,
			"poison",
			1.0,
			max(1.0, _get_player_base_damage() * 0.07),
			false,
			110.0
		)
