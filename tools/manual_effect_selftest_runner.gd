extends "res://tools/top10_effect_selftest_runner.gd"

const MANUAL_SUMMARY_PATH: String = "user://qa_reports/qef_effect_selftest_manual_summary.json"
const MANUAL_PLAYER_EFFECT_GROUPS: Array[String] = [
	"player_skill_effects",
	"projectiles",
	"elite_projectiles",
]

func _init() -> void:
	printerr("[manual_effect_selftest] init")
	call_deferred("_run")

func _run() -> void:
	printerr("[manual_effect_selftest] run")
	await process_frame

	if _global_node() == null or _debug_switcher_node() == null or _config_manager_node() == null:
		_write_manual_summary(false, [{
			"kind": "bootstrap",
			"passed": false,
			"reason": "autoload_missing",
		}])
		quit(1)
		return

	var results: Array[Dictionary] = []
	var passed: bool = true
	var roles: Array[String] = _collect_enabled_role_ids()
	for role_id: String in roles:
		var result: Dictionary = await _validate_role_manual(role_id)
		results.append(result)
		passed = passed and bool(result.get("passed", false))
		printerr("[manual_effect_selftest] role=%s passed=%s" % [role_id, result.get("passed", false)])

	_leave_test_mode_if_needed()
	_write_manual_summary(passed, results)
	printerr("[manual_effect_selftest] finished passed=%s results=%d" % [passed, results.size()])
	quit(0 if passed else 1)

func _collect_enabled_role_ids() -> Array[String]:
	var ids: Array[String] = []
	var config_manager: Node = _config_manager_node()
	if config_manager != null and config_manager.has_method("get_enabled_players"):
		var rows: Array[Dictionary] = config_manager.call("get_enabled_players")
		for row in rows:
			var role_id: String = str(row.get("player_id", "")).strip_edges()
			if role_id.is_empty() or ids.has(role_id):
				continue
			ids.append(role_id)
	return ids

func _validate_role_manual(role_id: String) -> Dictionary:
	var result: Dictionary = {
		"kind": "qef_effect_selftest_manual",
		"role_id": role_id,
		"passed": false,
		"checks": {},
		"phases": {},
	}

	var player: Node2D = await _prepare_role_arena(role_id)
	if not is_instance_valid(player):
		result["reason"] = "player_not_ready"
		return result

	var anchor: Vector2 = player.global_position

	var standalone: Dictionary = await _run_e_standalone_phase_manual(player, anchor)
	result["phases"]["e_single"] = standalone
	result["checks"]["e_single_context"] = bool(standalone.get("e_context_ok", false))

	var q_open_phase: Dictionary = await _run_qe_phase_manual(player, anchor, false)
	result["phases"]["q_open_then_e"] = q_open_phase
	result["checks"]["q_open_context"] = bool(q_open_phase.get("q_context_ok", false))
	result["checks"]["q_open_effect"] = bool(q_open_phase.get("q_effect_ok", false))
	result["checks"]["e_after_open_context"] = bool(q_open_phase.get("e_context_ok", false))

	var q_closed_phase: Dictionary = await _run_qe_phase_manual(player, anchor, true)
	result["phases"]["q_closed_then_e"] = q_closed_phase
	result["checks"]["q_closed_context"] = bool(q_closed_phase.get("q_context_ok", false))
	result["checks"]["q_closed_effect"] = bool(q_closed_phase.get("q_effect_ok", false))
	result["checks"]["e_after_closed_context"] = bool(q_closed_phase.get("e_context_ok", false))

	var f_phase: Dictionary = await _run_f_phase_manual(player, anchor, role_id)
	result["phases"]["f_window"] = f_phase
	result["checks"]["f_context"] = bool(f_phase.get("f_context_ok", false))
	result["checks"]["f_active"] = bool(f_phase.get("f_active_ok", false))
	result["checks"]["f_role_id"] = bool(f_phase.get("f_role_id_ok", false))

	result["passed"] = _all_checks_pass_manual(result.get("checks", {}))
	return result

func _run_e_standalone_phase_manual(player: Node2D, anchor: Vector2) -> Dictionary:
	await _reset_phase_state_manual(player, anchor)
	var before_counts: Dictionary = _collect_effect_counts_manual()
	var e_ok: bool = await _tap_action("skill_e", 10, 18)
	var snapshot: Dictionary = _get_player_context_snapshot()
	var after_counts: Dictionary = _collect_effect_counts_manual()
	return {
		"input_ok": e_ok,
		"counts_before": before_counts,
		"counts_after": after_counts,
		"counts_delta": _diff_counts_manual(before_counts, after_counts),
		"e_context_ok": not snapshot.get("e_context", {}).is_empty(),
		"e_context": snapshot.get("e_context", {}),
	}

func _run_qe_phase_manual(player: Node2D, anchor: Vector2, closed_path: bool) -> Dictionary:
	await _reset_phase_state_manual(player, anchor)
	var before_q_counts: Dictionary = _collect_effect_counts_manual()
	var q_ok: bool = await _perform_scripted_q_path(_get_active_role_id(), closed_path)
	var q_snapshot: Dictionary = _get_player_context_snapshot()
	var after_q_counts: Dictionary = _collect_effect_counts_manual()

	var q_context: Dictionary = q_snapshot.get("q_context", {})
	var q_context_ok: bool = (
		not q_context.is_empty()
		and bool(q_context.get("is_closed", false)) == closed_path
		and int(q_context.get("segment_count", 0)) > 0
	)
	if closed_path:
		q_context_ok = q_context_ok and (
			int(q_context.get("polygon_count", 0)) > 0
			or int(q_context.get("segment_count", 0)) >= 4
		)

	var q_delta: Dictionary = _diff_counts_manual(before_q_counts, after_q_counts)
	var q_effect_ok: bool = int(q_delta.get("active_effects", 0)) > 0 or int(q_delta.get("player_effect_nodes", 0)) > 0

	_refill_player_energy(player)
	var e_ok: bool = await _tap_action("skill_e", 10, 18)
	var e_snapshot: Dictionary = _get_player_context_snapshot()
	var after_e_counts: Dictionary = _collect_effect_counts_manual()
	return {
		"input_ok": q_ok,
		"counts_before_q": before_q_counts,
		"counts_after_q": after_q_counts,
		"counts_after_e": after_e_counts,
		"q_counts_delta": q_delta,
		"e_counts_delta": _diff_counts_manual(after_q_counts, after_e_counts),
		"q_context_ok": q_context_ok,
		"q_effect_ok": q_effect_ok,
		"q_context": q_context,
		"e_input_ok": e_ok,
		"e_context_ok": not e_snapshot.get("e_context", {}).is_empty(),
		"e_context": e_snapshot.get("e_context", {}),
	}

func _run_f_phase_manual(player: Node2D, anchor: Vector2, role_id: String) -> Dictionary:
	await _reset_phase_state_manual(player, anchor)
	var before_counts: Dictionary = _collect_effect_counts_manual()
	var f_ok: bool = await _tap_action("skill_f", 10, 70)
	var snapshot: Dictionary = _get_player_context_snapshot()
	var runtime: Dictionary = _get_player_runtime_snapshot()
	var qef_runtime: Dictionary = runtime.get("qef_runtime", {}) if runtime.get("qef_runtime", {}) is Dictionary else {}
	var after_counts: Dictionary = _collect_effect_counts_manual()
	var f_context: Dictionary = snapshot.get("f_context", {})
	var ultimate_snapshot: Dictionary = runtime.get("ultimate", {})
	return {
		"input_ok": f_ok,
		"counts_before": before_counts,
		"counts_after": after_counts,
		"counts_delta": _diff_counts_manual(before_counts, after_counts),
		"f_context_ok": not f_context.is_empty(),
		"f_active_ok": bool(qef_runtime.get("active", false)) or bool(ultimate_snapshot.get("active", false)),
		"f_role_id_ok": (
			str(qef_runtime.get("role_id", qef_runtime.get("f_role_id", ""))).strip_edges() == role_id
			or str(f_context.get("payload", {}).get("f_role_id", "")).strip_edges() == role_id
		),
		"f_context": f_context,
		"qef_runtime": qef_runtime,
		"ultimate_runtime": ultimate_snapshot,
	}

func _reset_phase_state_manual(player: Node2D, anchor: Vector2) -> void:
	_deactivate_ultimate_if_needed()
	_clear_runtime_effects_manual()
	_clear_dummy_enemies()
	await _wait_frames(4)
	if is_instance_valid(player):
		player.global_position = anchor
		player.rotation = 0.0
	_refill_player_energy(player)
	_spawn_dummy_enemies(anchor)
	await _wait_frames(10)

func _clear_runtime_effects_manual() -> void:
	var skill_effect_manager: Node = _skill_effect_manager_node()
	if skill_effect_manager != null and skill_effect_manager.has_method("clear_all_effects"):
		skill_effect_manager.call("clear_all_effects")
	for group_name: String in MANUAL_PLAYER_EFFECT_GROUPS:
		for node_var: Variant in get_nodes_in_group(group_name):
			if node_var == null or not is_instance_valid(node_var):
				continue
			if node_var is Node:
				(node_var as Node).queue_free()

func _collect_effect_counts_manual() -> Dictionary:
	var active_effects_count: int = 0
	var skill_effect_manager: Node = _skill_effect_manager_node()
	if skill_effect_manager != null and "active_effects" in skill_effect_manager:
		active_effects_count = int((skill_effect_manager.get("active_effects") as Dictionary).size())
	var player_effect_nodes: int = 0
	for group_name: String in MANUAL_PLAYER_EFFECT_GROUPS:
		player_effect_nodes += get_nodes_in_group(group_name).size()
	return {
		"active_effects": active_effects_count,
		"player_effect_nodes": player_effect_nodes,
	}

func _diff_counts_manual(before: Dictionary, after: Dictionary) -> Dictionary:
	return {
		"active_effects": int(after.get("active_effects", 0)) - int(before.get("active_effects", 0)),
		"player_effect_nodes": int(after.get("player_effect_nodes", 0)) - int(before.get("player_effect_nodes", 0)),
	}

func _all_checks_pass_manual(checks_raw: Variant) -> bool:
	if not (checks_raw is Dictionary):
		return false
	var checks: Dictionary = checks_raw
	if checks.is_empty():
		return false
	for value_var: Variant in checks.values():
		if not bool(value_var):
			return false
	return true

func _write_manual_summary(passed: bool, results: Array[Dictionary]) -> void:
	DirAccess.make_dir_recursive_absolute("user://qa_reports")
	var payload: Dictionary = {
		"passed": passed,
		"generated_at": Time.get_datetime_string_from_system(false, true),
		"results": results,
	}
	var file: FileAccess = FileAccess.open(MANUAL_SUMMARY_PATH, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify(payload, "\t"))
	file.flush()
	file.close()
