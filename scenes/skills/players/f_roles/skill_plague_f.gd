extends "res://scenes/skills/skill_f_base.gd"

const ROLE_ID: String = "plague"
const PLAGUE_E_META_CENTER: String = "plague_e_bloom_center"
const PLAGUE_E_META_RADIUS: String = "plague_e_bloom_radius"
const PLAGUE_E_META_EXPIRE_MSEC: String = "plague_e_bloom_expire_msec"
const PLAGUE_E_META_INTENSITY: String = "plague_e_bloom_intensity"

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
		_apply_status_burst(q_center, q_radius * 0.92, 6, "poison", 1.6, max(1.0, base_damage * 0.14))
		_pull_enemies_burst(q_center, q_radius * 0.84, 5, 12.0)
		_emit_plague_fan(q_center, q_dir, q_radius * 1.24, true)
		_line_slice_burst(
			q_center - q_dir * q_line_len * 0.62,
			q_center + q_dir * q_line_len * 0.62,
			18.0,
			0.22,
			"poison",
			1.2,
			max(1.0, base_damage * 0.08),
			false,
			120.0
		)
		_schedule_line_sweep_sequence(
			q_center,
			q_side,
			q_radius * 1.32,
			20.0,
			2,
			0.12,
			14.0,
			0.20,
			"poison",
			1.0,
			max(1.0, base_damage * 0.06),
			false,
			140.0
		)
	else:
		_line_slice_burst(
			q_center - q_side * q_line_len * 0.42,
			q_center + q_side * q_line_len * 0.42,
			12.0,
			0.14,
			"poison",
			0.9,
			max(1.0, base_damage * 0.05),
			false,
			80.0
		)

func _role_signature(phase: String, packet: Dictionary, center: Vector2) -> void:
	_signature_plague(phase, packet, center)
	var radius: float = max(90.0, float(packet.get("radius", 120.0)) * 0.98)
	var base_damage: float = _get_player_base_damage()
	var aim_dir: Vector2 = _get_player_aim_direction()
	var side_dir: Vector2 = Vector2(-aim_dir.y, aim_dir.x)
	var bloom_data: Array = _get_e_bloom_window(center, radius)
	var bloom_active: bool = bool(bloom_data[0])
	var bloom_intensity: int = int(bloom_data[3]) if bloom_data.size() > 3 else 0
	if bloom_active:
		var bloom_center: Variant = bloom_data[1]
		if bloom_center is Vector2:
			center = center.lerp(bloom_center, 0.6)
		var bloom_radius: float = float(bloom_data[2]) if bloom_data.size() > 2 else radius
		radius = max(radius, bloom_radius * 0.84)
		_apply_status_burst(
			center,
			radius * 0.66,
			4 + min(4, bloom_intensity),
			"poison",
			1.0 + float(bloom_intensity) * 0.12,
			max(1.0, base_damage * (0.05 + float(bloom_intensity) * 0.01))
		)
	if phase == "line":
		_emit_plague_fan(center, aim_dir, radius * 1.12, false)
		_apply_status_burst(center, radius * 0.74, 5, "poison", 1.0, max(1.0, base_damage * 0.06))
		_line_slice_burst(
			center - side_dir * radius * 0.58,
			center + side_dir * radius * 0.58,
			14.0,
			0.14,
			"poison",
			0.9,
			max(1.0, base_damage * 0.05),
			false,
			100.0
		)
	elif phase == "closure":
		_emit_plague_fan(center, aim_dir, radius * 1.36, true)
		_apply_status_burst(center, radius * 0.92, 7, "poison", 1.4, max(1.0, base_damage * 0.10))
		_schedule_line_sweep_sequence(
			center,
			aim_dir,
			radius * 1.46,
			18.0,
			2,
			0.10,
			14.0,
			0.24,
			"poison",
			1.1,
			max(1.0, base_damage * 0.06),
			false,
			150.0
		)
		_schedule_line_sweep_sequence(
			center,
			side_dir,
			radius * 1.26,
			14.0,
			2,
			0.13,
			12.0,
			0.18,
			"poison",
			0.9,
			max(1.0, base_damage * 0.05),
			false,
			120.0
		)
	if bloom_active:
		var bloom_scale: float = 0.20 + min(0.18, float(bloom_intensity) * 0.03)
		var bloom_delay: float = 0.24 if phase == "closure" else 0.32
		_queue_afterbloom(center, radius * (0.42 if phase == "closure" else 0.34), bloom_scale, bloom_delay)
		if phase == "closure":
			_consume_e_bloom_window()

func _emit_plague_fan(center: Vector2, aim_dir: Vector2, length: float, closure_phase: bool) -> void:
	var dir: Vector2 = aim_dir
	if dir.length_squared() <= 0.001:
		dir = Vector2.RIGHT
	var half_len: float = max(80.0, length * 0.5)
	var rays: int = 3 if not closure_phase else 5
	for i: int in range(rays):
		var t: float = 0.5 if rays <= 1 else float(i) / float(rays - 1)
		var angle_offset: float = lerp(-0.58, 0.58, t)
		var ray_dir: Vector2 = dir.rotated(angle_offset)
		_schedule_line_sweep_sequence(
			center,
			ray_dir,
			half_len * (1.5 if not closure_phase else 1.8),
			12.0,
			1,
			0.08 + float(i) * 0.02,
			12.0,
			0.16 if not closure_phase else 0.24,
			"poison",
			1.0,
			max(1.0, _get_player_base_damage() * 0.06),
			false,
			120.0
		)

func _queue_afterbloom(center: Vector2, radius: float, damage_scale: float, delay: float) -> void:
	var safe_radius: float = max(50.0, radius)
	var safe_scale: float = max(0.12, damage_scale)
	var safe_delay: float = max(0.06, delay)
	get_tree().create_timer(safe_delay).timeout.connect(_on_afterbloom_timeout.bind(center, safe_radius, safe_scale))

func _on_afterbloom_timeout(center: Vector2, radius: float, damage_scale: float) -> void:
	var base_damage: float = _get_player_base_damage()
	for enemy in _get_enemies_in_radius(center, radius):
		_damage_enemy(enemy, base_damage * damage_scale, "BLOOM", Color(0.56, 0.95, 0.32))
		_apply_enemy_status(enemy, "poison", 1.3, max(1.0, base_damage * damage_scale * 0.42), 1, 0.7)
		_apply_enemy_status(enemy, "slow", 0.8, 0.24, 1, 0.1)

func _get_e_bloom_window(default_center: Vector2, default_radius: float) -> Array:
	var data: Array = [false, default_center, default_radius, 0]
	if not is_instance_valid(player_ref):
		return data
	if not player_ref.has_meta(PLAGUE_E_META_EXPIRE_MSEC):
		return data
	var expire_msec: int = int(player_ref.get_meta(PLAGUE_E_META_EXPIRE_MSEC, 0))
	if Time.get_ticks_msec() > expire_msec:
		return data
	var center_val: Variant = player_ref.get_meta(PLAGUE_E_META_CENTER, default_center)
	var radius_val: Variant = player_ref.get_meta(PLAGUE_E_META_RADIUS, default_radius)
	var intensity_val: Variant = player_ref.get_meta(PLAGUE_E_META_INTENSITY, 0)
	if not (center_val is Vector2):
		return data
	data[0] = true
	data[1] = center_val
	data[2] = max(default_radius, float(radius_val))
	data[3] = max(0, int(intensity_val))
	return data

func _consume_e_bloom_window() -> void:
	if not is_instance_valid(player_ref):
		return
	player_ref.remove_meta(PLAGUE_E_META_EXPIRE_MSEC)
	player_ref.remove_meta(PLAGUE_E_META_INTENSITY)
