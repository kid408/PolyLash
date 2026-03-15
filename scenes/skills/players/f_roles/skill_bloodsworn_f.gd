extends "res://scenes/skills/skill_f_base.gd"

const ROLE_ID: String = "bloodsworn"
const VAMPIRE_E_META_CENTER: String = "bloodsworn_e_rite_center"
const VAMPIRE_E_META_RADIUS: String = "bloodsworn_e_rite_radius"
const VAMPIRE_E_META_EXPIRE_MSEC: String = "bloodsworn_e_rite_expire_msec"
const VAMPIRE_E_META_INTENSITY: String = "bloodsworn_e_rite_intensity"

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
		_drain_nearby(q_center, q_radius * 0.86, 5, base_damage * 0.38, 0.24, 1.2)
		_emit_blood_tether(q_center, q_dir, q_radius * 1.28, true)
		_line_slice_burst(
			q_center - q_dir * q_line_len * 0.54,
			q_center + q_dir * q_line_len * 0.54,
			16.0,
			0.26,
			"curse",
			1.1,
			max(1.0, base_damage * 0.08),
			true,
			150.0
		)
		_line_slice_burst(
			q_center - q_side * q_line_len * 0.40,
			q_center + q_side * q_line_len * 0.40,
			14.0,
			0.20,
			"curse",
			0.9,
			max(1.0, base_damage * 0.06),
			true,
			110.0
		)
	else:
		_drain_nearby(q_center, q_radius * 0.62, 3, base_damage * 0.22, 0.16, 0.9)

func _role_signature(phase: String, packet: Dictionary, center: Vector2) -> void:
	_signature_bloodsworn(phase, packet, center)
	var radius: float = max(90.0, float(packet.get("radius", 120.0)) * 0.92)
	var base_damage: float = _get_player_base_damage()
	var aim_dir: Vector2 = _get_player_aim_direction()
	var rite_data: Array = _get_e_blood_rite_window(center, radius)
	var rite_active: bool = bool(rite_data[0])
	var rite_intensity: int = int(rite_data[3]) if rite_data.size() > 3 else 0
	if rite_active:
		var rite_center: Variant = rite_data[1]
		if rite_center is Vector2:
			center = center.lerp(rite_center, 0.58)
		var rite_radius: float = float(rite_data[2]) if rite_data.size() > 2 else radius
		radius = max(radius, rite_radius * 0.92)
	if phase == "line":
		_emit_blood_tether(center, aim_dir, radius * 1.16, false)
		_drain_nearby(
			center,
			radius * 0.70,
			3 + (1 if rite_active else 0),
			base_damage * (0.18 + (0.04 if rite_active else 0.0)),
			0.12 + (0.03 if rite_active else 0.0),
			0.8 + (0.2 if rite_active else 0.0)
		)
		_line_slice_burst(
			center - aim_dir * radius * 0.68,
			center + aim_dir * radius * 0.68,
			12.0,
			0.16,
			"curse",
			0.9,
			max(1.0, base_damage * 0.05),
			true,
			100.0
		)
	elif phase == "closure":
		_emit_blood_tether(center, aim_dir, radius * 1.34, true)
		_drain_nearby(
			center,
			radius * 0.92,
			6 + (2 if rite_active else 0),
			base_damage * (0.32 + (0.06 if rite_active else 0.0)),
			0.20 + (0.04 if rite_active else 0.0),
			1.2 + (0.2 if rite_active else 0.0)
		)
		_schedule_line_sweep_sequence(
			center,
			aim_dir,
			radius * 1.42,
			22.0,
			2,
			0.11,
			14.0,
			0.24,
			"curse",
			1.0,
			max(1.0, base_damage * 0.07),
			true,
			150.0
		)
		if rite_active:
			_schedule_line_sweep_sequence(
				center,
				Vector2(-aim_dir.y, aim_dir.x),
				radius * 1.26,
				16.0,
				2,
				0.10,
				13.0,
				0.22,
				"curse",
				1.1,
				max(1.0, base_damage * 0.08),
				true,
				130.0
			)
			_heal_player(base_damage * (0.22 + min(0.18, float(rite_intensity) * 0.03)))
			_consume_e_blood_rite_window()
		_apply_temp_attack_boost(1.6, 0.14 + (0.03 if rite_active else 0.0))

func _emit_blood_tether(center: Vector2, aim_dir: Vector2, length: float, closure_phase: bool) -> void:
	var dir: Vector2 = aim_dir
	if dir.length_squared() <= 0.001:
		dir = Vector2.RIGHT
	var side: Vector2 = Vector2(-dir.y, dir.x)
	var half_len: float = max(80.0, length * 0.5)
	_schedule_line_sweep_sequence(
		center,
		dir,
		half_len * 1.8,
		14.0,
		1,
		0.08,
		12.0,
		0.18 if not closure_phase else 0.26,
		"curse",
		1.0,
		max(1.0, _get_player_base_damage() * 0.06),
		true,
		120.0
	)
	_schedule_line_sweep_sequence(
		center + dir * half_len * 0.52,
		-dir,
		half_len * 1.5,
		14.0,
		1 if not closure_phase else 2,
		0.10,
		12.0,
		0.18 if not closure_phase else 0.24,
		"curse",
		1.0,
		max(1.0, _get_player_base_damage() * 0.06),
		true,
		120.0
	)
	if closure_phase:
		_line_slice_burst(
			center - side * half_len * 0.70,
			center + side * half_len * 0.70,
			14.0,
			0.22,
			"curse",
			1.1,
			max(1.0, _get_player_base_damage() * 0.07),
			true,
			130.0
		)

func _drain_nearby(center: Vector2, radius: float, limit: int, damage: float, heal_ratio: float, curse_duration: float) -> void:
	var targets: Array = _sort_enemies_by_distance(_get_enemies_in_radius(center, radius), center)
	if targets.is_empty():
		return
	var hit_count: int = 0
	var total_heal: float = 0.0
	for i: int in range(min(limit, targets.size())):
		var enemy: Node = targets[i]
		if not is_instance_valid(enemy):
			continue
		_damage_enemy(enemy, damage, "DRAIN", Color(1.0, 0.28, 0.4))
		_apply_enemy_status(enemy, "curse", curse_duration, max(1.0, damage * 0.35), 1, 0.5)
		total_heal += damage * heal_ratio
		hit_count += 1
	if hit_count > 0:
		_heal_player(total_heal)

func _get_e_blood_rite_window(default_center: Vector2, default_radius: float) -> Array:
	var data: Array = [false, default_center, default_radius, 0]
	if not is_instance_valid(player_ref):
		return data
	if not player_ref.has_meta(VAMPIRE_E_META_EXPIRE_MSEC):
		return data
	var expire_msec: int = int(player_ref.get_meta(VAMPIRE_E_META_EXPIRE_MSEC, 0))
	if Time.get_ticks_msec() > expire_msec:
		return data
	var center_val: Variant = player_ref.get_meta(VAMPIRE_E_META_CENTER, default_center)
	var radius_val: Variant = player_ref.get_meta(VAMPIRE_E_META_RADIUS, default_radius)
	var intensity_val: Variant = player_ref.get_meta(VAMPIRE_E_META_INTENSITY, 0)
	if not (center_val is Vector2):
		return data
	data[0] = true
	data[1] = center_val
	data[2] = max(default_radius, float(radius_val))
	data[3] = max(0, int(intensity_val))
	return data

func _consume_e_blood_rite_window() -> void:
	if not is_instance_valid(player_ref):
		return
	player_ref.remove_meta(VAMPIRE_E_META_EXPIRE_MSEC)
	player_ref.remove_meta(VAMPIRE_E_META_INTENSITY)
