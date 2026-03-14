extends "res://scenes/skills/players/skill_ultimate_qef_v3.gd"

const ROLE_ID: String = "midas"
const MIDAS_E_META_CENTER: String = "midas_e_touch_center"
const MIDAS_E_META_RADIUS: String = "midas_e_touch_radius"
const MIDAS_E_META_EXPIRE_MSEC: String = "midas_e_touch_expire_msec"
const MIDAS_E_META_COINS: String = "midas_e_touch_coin_bonus"

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
	var q_dir: Vector2 = _get_player_aim_direction()
	if q_dir.length_squared() <= 0.001:
		q_dir = Vector2.RIGHT
	var q_side: Vector2 = Vector2(-q_dir.y, q_dir.x)
	var q_line_len: float = q_radius * 1.18

	if q_closed or phase == "closure":
		_drop_coins_at(q_center, 2)
		_gain_energy(2.0)
		_apply_temp_attack_boost(1.8, 0.10)
		_emit_midas_coin_rail(q_center, q_dir, q_radius * 1.16, true)
		_line_slice_burst(
			q_center - q_dir * q_line_len * 0.56,
			q_center + q_dir * q_line_len * 0.56,
			14.0,
			0.24,
			"slow",
			1.0,
			0.24,
			false,
			150.0
		)
		_line_slice_burst(
			q_center - q_side * q_line_len * 0.46,
			q_center + q_side * q_line_len * 0.46,
			12.0,
			0.18,
			"marked",
			0.9,
			0.18,
			false,
			110.0
		)
	else:
		_line_slice_burst(
			q_center - q_side * q_line_len * 0.38,
			q_center + q_side * q_line_len * 0.38,
			10.0,
			0.12,
			"slow",
			0.8,
			0.18,
			false,
			70.0
		)

func _role_signature(phase: String, packet: Dictionary, center: Vector2) -> void:
	_signature_midas(phase, packet, center)
	var radius: float = max(86.0, float(packet.get("radius", 120.0)) * 0.90)
	var base_damage: float = _get_player_base_damage()
	var aim_dir: Vector2 = _get_player_aim_direction()
	var side_dir: Vector2 = Vector2(-aim_dir.y, aim_dir.x)
	var touch_data: Array = _get_e_touch_window(center, radius)
	var touch_active: bool = bool(touch_data[0])
	var coin_bonus: int = int(touch_data[3]) if touch_data.size() > 3 else 0
	if touch_active:
		var touch_center: Variant = touch_data[1]
		if touch_center is Vector2:
			center = center.lerp(touch_center, 0.56)
		var touch_radius: float = float(touch_data[2]) if touch_data.size() > 2 else radius
		radius = max(radius, touch_radius * 0.94)
	if phase == "line":
		_emit_midas_coin_rail(center, aim_dir, radius * 1.02, false)
		_gain_energy(1.0 + (1.0 if touch_active else 0.0))
		if touch_active:
			_drop_coins_at(center, 1)
		_line_slice_burst(
			center - aim_dir * radius * 0.70,
			center + aim_dir * radius * 0.70,
			12.0,
			0.14,
			"slow",
			0.8,
			0.18,
			false,
			90.0
		)
	elif phase == "closure":
		_emit_midas_coin_rail(center, aim_dir, radius * 1.24, true)
		var closure_coin_bonus: int = min(2, int(coin_bonus / 2))
		_drop_coins_at(center, 1 + closure_coin_bonus)
		_apply_temp_attack_boost(1.6, 0.08 + (0.03 if touch_active else 0.0))
		_schedule_line_sweep_sequence(
			center,
			aim_dir,
			radius * 1.30,
			16.0,
			2,
			0.12,
			12.0,
			0.22,
			"slow",
			1.0,
			0.20,
			false,
			130.0
		)
		_schedule_line_sweep_sequence(
			center,
			side_dir,
			radius * 1.10,
			12.0,
			1,
			0.14,
			10.0,
			0.16,
			"marked",
			0.9,
			0.16,
			false,
			90.0
		)
		_line_slice_burst(
			center - aim_dir * radius * 0.86,
			center + aim_dir * radius * 0.86,
			14.0,
			0.20,
			"slow",
			0.9,
			0.20,
			false,
			120.0
		)
		if touch_active:
			for enemy in _get_enemies_in_radius(center, radius * 0.54):
				_damage_enemy(enemy, base_damage * 0.26, "MINT", Color(1.0, 0.82, 0.32))
				_apply_enemy_status(enemy, "marked", 1.0, 0.18, 1, 0.3)
			_consume_e_touch_window()

func _emit_midas_coin_rail(center: Vector2, aim_dir: Vector2, length: float, closure_phase: bool) -> void:
	var dir: Vector2 = aim_dir
	if dir.length_squared() <= 0.001:
		dir = Vector2.RIGHT
	var side: Vector2 = Vector2(-dir.y, dir.x)
	var half_len: float = max(72.0, length * 0.5)
	_line_slice_burst(
		center - dir * half_len,
		center + dir * half_len,
		10.0,
		0.14 if not closure_phase else 0.22,
		"slow",
		0.9,
		0.18,
		false,
		100.0
	)
	_line_slice_burst(
		center - side * half_len * 0.80,
		center + side * half_len * 0.80,
		10.0,
		0.12 if not closure_phase else 0.18,
		"marked",
		0.9,
		0.16,
		false,
		90.0
	)
	if closure_phase:
		_drop_coins_at(center + dir * half_len * 0.40, 1)

func _get_e_touch_window(default_center: Vector2, default_radius: float) -> Array:
	var data: Array = [false, default_center, default_radius, 0]
	if not is_instance_valid(player_ref):
		return data
	if not player_ref.has_meta(MIDAS_E_META_EXPIRE_MSEC):
		return data
	var expire_msec: int = int(player_ref.get_meta(MIDAS_E_META_EXPIRE_MSEC, 0))
	if Time.get_ticks_msec() > expire_msec:
		return data
	var center_val: Variant = player_ref.get_meta(MIDAS_E_META_CENTER, default_center)
	var radius_val: Variant = player_ref.get_meta(MIDAS_E_META_RADIUS, default_radius)
	var coin_val: Variant = player_ref.get_meta(MIDAS_E_META_COINS, 0)
	if not (center_val is Vector2):
		return data
	data[0] = true
	data[1] = center_val
	data[2] = max(default_radius, float(radius_val))
	data[3] = max(0, int(coin_val))
	return data

func _consume_e_touch_window() -> void:
	if not is_instance_valid(player_ref):
		return
	player_ref.remove_meta(MIDAS_E_META_EXPIRE_MSEC)
	player_ref.remove_meta(MIDAS_E_META_COINS)
