extends "res://scenes/skills/skill_f_base.gd"

const ROLE_ID: String = "mirebinder"
const GOO_E_META_CENTER: String = "mirebinder_e_devour_center"
const GOO_E_META_RADIUS: String = "mirebinder_e_devour_radius"
const GOO_E_META_EXPIRE_MSEC: String = "mirebinder_e_devour_expire_msec"
const GOO_E_META_SPLIT: String = "mirebinder_e_devour_split"

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
		_spawn_mirebinder_pool(q_center, q_radius * 0.34, 1.8, 0.26, 2)
		_spawn_mirebinder_pool(q_center + q_side * (q_radius * 0.26), q_radius * 0.26, 1.4, 0.22, 1)
		_line_slice_burst(
			q_center - q_dir * q_line_len * 0.52,
			q_center + q_dir * q_line_len * 0.52,
			18.0,
			0.18,
			"poison",
			1.1,
			max(1.0, base_damage * 0.06),
			false,
			110.0
		)
		_pull_enemies_burst(q_center, q_radius * 0.74, 5, 8.0)
	else:
		_spawn_mirebinder_pool(q_center, q_radius * 0.22, 1.1, 0.16, 0)
		_line_slice_burst(
			q_center - q_side * q_line_len * 0.38,
			q_center + q_side * q_line_len * 0.38,
			12.0,
			0.12,
			"slow",
			0.8,
			0.18,
			false,
			70.0
		)

func _role_signature(phase: String, packet: Dictionary, center: Vector2) -> void:
	_signature_mirebinder(phase, packet, center)
	var radius: float = max(90.0, float(packet.get("radius", 120.0)) * 0.96)
	var base_damage: float = _get_player_base_damage()
	var aim_dir: Vector2 = _get_player_aim_direction()
	var side_dir: Vector2 = Vector2(-aim_dir.y, aim_dir.x)
	var devour_data: Array = _get_e_devour_window(center, radius)
	var devour_active: bool = bool(devour_data[0])
	var split_bonus: int = int(devour_data[3]) if devour_data.size() > 3 else 0
	if devour_active:
		var devour_center: Variant = devour_data[1]
		if devour_center is Vector2:
			center = center.lerp(devour_center, 0.62)
		var devour_radius: float = float(devour_data[2]) if devour_data.size() > 2 else radius
		radius = max(radius, devour_radius * 0.90)
		_spawn_mirebinder_pool(center, radius * 0.24, 1.4, 0.22, 1)
	if phase == "line":
		_spawn_mirebinder_pool(center + aim_dir * (radius * 0.24), radius * 0.22, 1.2, 0.16, 1)
		_line_slice_burst(
			center - side_dir * radius * 0.54,
			center + side_dir * radius * 0.54,
			12.0,
			0.12,
			"slow",
			0.8,
			0.16,
			false,
			90.0
		)
		if devour_active:
			_spawn_mirebinder_pool(center - aim_dir * (radius * 0.20), radius * 0.20, 1.1, 0.16, 0)
	elif phase == "closure":
		var closure_split: int = 2 + min(2, max(0, split_bonus - 2))
		_spawn_mirebinder_pool(center, radius * 0.30, 1.7, 0.24, closure_split)
		_spawn_mirebinder_pool(center + aim_dir * (radius * 0.28), radius * 0.24, 1.4, 0.20, 1 + min(1, split_bonus / 3))
		_schedule_line_sweep_sequence(
			center,
			aim_dir,
			radius * 1.30,
			12.0,
			2,
			0.13,
			14.0,
			0.18,
			"poison",
			1.0,
			max(1.0, base_damage * 0.05),
			false,
			120.0
		)
		if devour_active:
			_schedule_line_sweep_sequence(
				center,
				side_dir,
				radius * 1.18,
				10.0,
				2,
				0.11,
				13.0,
				0.18,
				"poison",
				1.0,
				max(1.0, base_damage * 0.05),
				true,
				110.0
			)
			_consume_e_devour_window()

func _get_e_devour_window(default_center: Vector2, default_radius: float) -> Array:
	var data: Array = [false, default_center, default_radius, 0]
	if not is_instance_valid(player_ref):
		return data
	if not player_ref.has_meta(GOO_E_META_EXPIRE_MSEC):
		return data
	var expire_msec: int = int(player_ref.get_meta(GOO_E_META_EXPIRE_MSEC, 0))
	if Time.get_ticks_msec() > expire_msec:
		return data
	var center_val: Variant = player_ref.get_meta(GOO_E_META_CENTER, default_center)
	var radius_val: Variant = player_ref.get_meta(GOO_E_META_RADIUS, default_radius)
	var split_val: Variant = player_ref.get_meta(GOO_E_META_SPLIT, 0)
	if not (center_val is Vector2):
		return data
	data[0] = true
	data[1] = center_val
	data[2] = max(default_radius, float(radius_val))
	data[3] = max(0, int(split_val))
	return data

func _consume_e_devour_window() -> void:
	if not is_instance_valid(player_ref):
		return
	player_ref.remove_meta(GOO_E_META_EXPIRE_MSEC)
	player_ref.remove_meta(GOO_E_META_SPLIT)
