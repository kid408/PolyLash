extends "res://scenes/skills/skill_f_base.gd"

const ROLE_ID: String = "sapper"
const SAPPER_E_CHAIN_META: String = "sapper_e_chain_until_msec"
const SAPPER_E_REMOTE_COUNT_META: String = "sapper_e_remote_count"

func _resolve_f_role_id() -> String:
	return ROLE_ID

func _apply_mode_signature(phase: String, packet: Dictionary, center: Vector2, hit_count: int) -> void:
	if not is_active:
		return
	_role_signature(phase, packet, center, hit_count)

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
	var q_line_len: float = q_radius * 1.18

	if bool(q_ctx.get("is_closed", false)):
		_spawn_sapper_mine(q_center, 0.35, q_radius * 0.44, 0.34)
		_line_slice_burst(
			q_center - q_dir * q_line_len * 0.56,
			q_center + q_dir * q_line_len * 0.56,
			20.0,
			0.26,
			"marked",
			1.2,
			0.20,
			false,
			220.0
		)
		_schedule_line_sweep_sequence(
			q_center,
			q_dir,
			q_radius * 1.5,
			42.0,
			2,
			0.10,
			14.0,
			0.22,
			"slow",
			0.9,
			0.24,
			false,
			180.0
		)
		if _is_chain_window():
			var chain_count: int = clamp(_get_remote_count(), 1, 4)
			for i: int in range(chain_count):
				var angle: float = TAU * float(i) / float(chain_count)
				var offset: Vector2 = Vector2(cos(angle), sin(angle)) * q_radius * 0.32
				_spawn_sapper_mine(q_center + offset, 0.28, q_radius * 0.28, 0.30)
			_detonate_all_sapper_mines(true)

func _role_signature(phase: String, packet: Dictionary, center: Vector2, _hit_count: int) -> void:
	if phase == "closure":
		_detonate_all_sapper_mines(true)
		var closure_radius: float = max(90.0, float(packet.get("radius", 120.0)) * 1.1)
		var closure_dir: Vector2 = _get_player_aim_direction()
		_plant_mine_corridor(center, closure_dir, closure_radius * 1.2, 4, 0.10, 0.28)
		_schedule_line_sweep_sequence(
			center,
			closure_dir,
			closure_radius * 1.5,
			56.0,
			3,
			0.10,
			18.0,
			0.34,
			"marked",
			1.1,
			0.20,
			false,
			220.0
		)
		if _is_chain_window():
			_plant_mine_corridor(center, Vector2(-closure_dir.y, closure_dir.x), closure_radius, 3, 0.08, 0.24)
			_schedule_line_sweep_sequence(
				center,
				Vector2(-closure_dir.y, closure_dir.x),
				closure_radius * 1.24,
				40.0,
				2,
				0.10,
				16.0,
				0.28,
				"marked",
				1.0,
				0.20,
				false,
				180.0
			)
		return
	var orbit_radius: float = max(60.0, float(packet.get("radius", 120.0)) * 0.34)
	var angle: float = randf_range(0.0, TAU)
	var spawn_pos: Vector2 = center + Vector2(cos(angle), sin(angle)) * orbit_radius
	_spawn_sapper_mine(spawn_pos, 0.9, max(48.0, orbit_radius * 0.7), 0.52)
	if phase == "line":
		var line_dir: Vector2 = _get_player_aim_direction()
		_plant_mine_corridor(center, line_dir, orbit_radius * 2.4, 3, 0.14, 0.20)
		_schedule_line_sweep_sequence(
			center,
			line_dir,
			orbit_radius * 2.8,
			38.0,
			2,
			0.14,
			14.0,
			0.24,
			"slow",
			0.9,
			0.24,
			false,
			170.0
		)

func _plant_mine_corridor(center: Vector2, aim_dir: Vector2, length: float, count: int, base_delay: float, damage_scale: float) -> void:
	var dir: Vector2 = aim_dir
	if dir.length_squared() <= 0.001:
		dir = Vector2.RIGHT
	var total: int = max(1, count)
	var step: float = max(36.0, length / float(total))
	for i: int in range(total):
		var distance: float = step * float(i + 1)
		var mine_pos: Vector2 = center + dir * distance
		var delay: float = max(0.05, base_delay + float(i) * 0.05)
		_spawn_sapper_mine(mine_pos, delay, max(40.0, step * 0.72), max(0.12, damage_scale + float(i) * 0.02))

func _is_chain_window() -> bool:
	if not is_instance_valid(player_ref):
		return false
	if not player_ref.has_meta(SAPPER_E_CHAIN_META):
		return false
	var expire_msec: int = int(player_ref.get_meta(SAPPER_E_CHAIN_META))
	return Time.get_ticks_msec() <= expire_msec

func _get_remote_count() -> int:
	if not is_instance_valid(player_ref):
		return 0
	if not player_ref.has_meta(SAPPER_E_REMOTE_COUNT_META):
		return 0
	return max(0, int(player_ref.get_meta(SAPPER_E_REMOTE_COUNT_META)))
