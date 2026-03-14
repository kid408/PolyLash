extends "res://scenes/skills/players/skill_ultimate_qef_v3.gd"

const ROLE_ID: String = "blacksmith"
const FORGE_HEAT_META: String = "blacksmith_forge_heat"

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
		_knock_enemies_burst(q_center, q_radius * 0.72, 4, 180.0)
		_line_slice_burst(q_center - q_side * q_line_len * 0.54, q_center + q_side * q_line_len * 0.54, 18.0, 0.28, "burn", 1.0, max(1.0, base_damage * 0.08), false, 220.0)
		_schedule_line_sweep_sequence(
			q_center,
			q_dir,
			q_radius * 1.34,
			30.0,
			2,
			0.10,
			16.0,
			0.28,
			"burn",
			1.2,
			max(1.0, base_damage * 0.09),
			false,
			210.0
		)
	else:
		_line_slice_burst(q_center - q_dir * q_line_len * 0.46, q_center + q_dir * q_line_len * 0.46, 14.0, 0.20, "burn", 0.8, max(1.0, base_damage * 0.05), false, 140.0)
		_schedule_line_sweep_sequence(
			q_center,
			q_side,
			q_radius * 1.10,
			24.0,
			1,
			0.10,
			14.0,
			0.22,
			"burn",
			0.9,
			max(1.0, base_damage * 0.06),
			false,
			150.0
		)

func _role_signature(phase: String, packet: Dictionary, center: Vector2) -> void:
	var radius: float = max(90.0, float(packet.get("radius", 120.0)) * 0.92)
	var aim_dir: Vector2 = _get_player_aim_direction()
	var sweep_angle: float = 0.65 if phase == "line" else (0.95 if phase == "closure" else 0.48)
	var damage_scale: float = 0.52 if phase == "line" else (0.88 if phase == "closure" else 0.38)
	if _is_forge_heat_high():
		damage_scale += 0.12
	var base_damage: float = _get_player_base_damage()
	var enemies: Array = _get_enemies_in_radius(center, radius)
	var hit_count: int = 0
	for enemy in enemies:
		if hit_count >= 10:
			break
		if not is_instance_valid(enemy) or not (enemy is Node2D):
			continue
		var enemy_node: Node2D = enemy
		var dir: Vector2 = (enemy_node.global_position - center).normalized()
		var angle_delta: float = absf(aim_dir.angle_to(dir))
		if angle_delta > sweep_angle:
			continue
		_damage_enemy(enemy, base_damage * damage_scale, "FORGE", Color(1.0, 0.68, 0.28))
		_apply_enemy_status(enemy, "burn", 1.2 + (0.6 if phase == "closure" else 0.0), max(1.0, base_damage * 0.22), 1, 0.5)
		if phase != "tick":
			_knock_enemy(enemy, center, 95.0 + (40.0 if phase == "closure" else 0.0))
		hit_count += 1
	if phase == "closure" and hit_count > 0:
		_apply_temp_attack_boost(1.8, 0.12)
		_apply_status_burst(center, radius * 0.68, 3, "burn", 1.3, max(1.0, base_damage * 0.12))
		_knock_enemies_burst(center, radius * 0.72, 4, 180.0)
	if phase == "line":
		_schedule_line_sweep_sequence(
			center,
			aim_dir,
			radius * 1.3,
			0.0,
			1,
			0.08,
			15.0,
			0.26,
			"burn",
			1.0,
			max(1.0, base_damage * 0.08),
			false,
			150.0
		)
		_spawn_parallel_wall_pair(
			center,
			aim_dir,
			radius * 1.18,
			40.0,
			0.95,
			int(max(1.0, base_damage * 0.14)),
			Color(1.0, 0.68, 0.3, 0.66)
		)
	elif phase == "closure":
		_schedule_line_sweep_sequence(
			center,
			aim_dir,
			radius * 1.45,
			32.0,
			3,
			0.09,
			16.0,
			0.30,
			"burn",
			1.3,
			max(1.0, base_damage * 0.10),
			false,
			190.0
		)
		_schedule_line_sweep_sequence(
			center,
			Vector2(-aim_dir.y, aim_dir.x),
			radius * 1.24,
			26.0,
			2,
			0.12,
			14.0,
			0.24,
			"burn",
			1.1,
			max(1.0, base_damage * 0.09),
			false,
			170.0
		)
		_spawn_parallel_wall_pair(
			center,
			Vector2(-aim_dir.y, aim_dir.x),
			radius * 1.30,
			52.0,
			1.1,
			int(max(1.0, base_damage * 0.17)),
			Color(1.0, 0.62, 0.28, 0.64)
		)

func _is_forge_heat_high() -> bool:
	if not is_instance_valid(player_ref):
		return false
	var heat: float = float(player_ref.get_meta(FORGE_HEAT_META, 0.0))
	return heat >= 3.0
