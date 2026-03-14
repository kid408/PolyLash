extends "res://scenes/skills/players/skill_ultimate_qef_v3.gd"

const ROLE_ID: String = "weaver"
const WEAVER_E_RECALL_META: String = "weaver_e_recall_until_msec"

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
	var q_line_len: float = q_radius * 1.18

	_apply_status_burst(q_center, q_radius * 0.8, 4, "slow", 1.0, 0.30)
	_line_slice_burst(
		q_center - q_side * q_line_len * 0.52,
		q_center + q_side * q_line_len * 0.52,
		20.0,
		0.24,
		"slow",
		1.1,
		0.28,
		true,
		160.0
	)
	_line_slice_burst(
		q_center - q_dir * q_line_len * 0.44,
		q_center + q_dir * q_line_len * 0.44,
		16.0,
		0.20,
		"curse",
		1.1,
		max(1.0, base_damage * 0.06),
		true,
		120.0
	)
	if _is_recall_window():
		_apply_status_burst(q_center, q_radius * 0.86, 6, "stun", 0.22, 0.0)
		_schedule_line_sweep_sequence(
			q_center,
			q_dir,
			q_radius * 1.34,
			30.0,
			2,
			0.10,
			15.0,
			0.24,
			"slow",
			1.1,
			0.26,
			true,
			160.0
		)

func _role_signature(phase: String, packet: Dictionary, center: Vector2) -> void:
	var radius: float = max(90.0, float(packet.get("radius", 120.0)) * 1.06)
	var targets: Array = _sort_enemies_by_distance(_get_enemies_in_radius(center, radius), center)
	if targets.is_empty():
		return
	var limit: int = 2 if phase == "tick" else 4
	var recall_window: bool = _is_recall_window()
	for i: int in range(min(limit, targets.size())):
		var enemy: Node = targets[i]
		_pull_enemy(enemy, center, 10.0 + (10.0 if phase == "closure" else 4.0))
		_apply_enemy_status(enemy, "slow", 1.2 + 0.25 * float(i), 0.32, 1, 0.1)
		if phase == "closure":
			_apply_enemy_status(enemy, "stun", 0.55, 0.0, 1, 0.1)
	if phase == "line":
		var line_dir: Vector2 = _get_player_aim_direction()
		_emit_web_recall_net(center, line_dir, radius * 1.26, false)
	if phase == "closure":
		var aim_dir: Vector2 = _get_player_aim_direction()
		_emit_web_recall_net(center, aim_dir, radius * 1.40, true)
		_schedule_line_sweep_sequence(
			center,
			aim_dir,
			radius * 1.5,
			58.0,
			3,
			0.10,
			16.0,
			0.28,
			"slow",
			1.0,
			0.30,
			true,
			180.0
		)
		_schedule_line_sweep_sequence(
			center,
			Vector2(-aim_dir.y, aim_dir.x),
			radius * 1.3,
			52.0,
			2,
			0.14,
			14.0,
			0.24,
			"slow",
			0.9,
			0.28,
			true,
			150.0
		)
		if recall_window:
			_schedule_line_sweep_sequence(
				center,
				aim_dir.rotated(0.55),
				radius * 1.18,
				36.0,
				1,
				0.10,
				14.0,
				0.24,
				"stun",
				0.20,
				0.0,
				true,
				120.0
			)
			_schedule_line_sweep_sequence(
				center,
				aim_dir.rotated(-0.55),
				radius * 1.18,
				36.0,
				1,
				0.10,
				14.0,
				0.24,
				"stun",
				0.20,
				0.0,
				true,
				120.0
			)

func _emit_web_recall_net(center: Vector2, aim_dir: Vector2, length: float, closure_phase: bool) -> void:
	var dir: Vector2 = aim_dir
	if dir.length_squared() <= 0.001:
		dir = Vector2.RIGHT
	var side: Vector2 = Vector2(-dir.y, dir.x)
	var half_len: float = max(80.0, length * 0.5)
	_line_slice_burst(
		center - side * half_len,
		center + side * half_len,
		20.0,
		0.20,
		"slow",
		1.1,
		0.30,
		true,
		180.0
	)
	_schedule_line_sweep_sequence(
		center,
		dir,
		half_len * 1.9,
		20.0,
		1,
		0.12,
		14.0,
		0.24,
		"slow",
		1.0,
		0.26,
		true,
		160.0
	)
	if closure_phase or _is_recall_window():
		_pull_enemies_burst(center, half_len * 0.95, 6, 12.0)
		_schedule_line_sweep_sequence(
			center,
			-dir,
			half_len * 1.9,
			24.0,
			1,
			0.10,
			15.0,
			0.24,
			"stun",
			0.20,
			0.0,
			true,
			170.0
		)

func _is_recall_window() -> bool:
	if not is_instance_valid(player_ref):
		return false
	if not player_ref.has_meta(WEAVER_E_RECALL_META):
		return false
	var expire_msec: int = int(player_ref.get_meta(WEAVER_E_RECALL_META))
	return Time.get_ticks_msec() <= expire_msec
