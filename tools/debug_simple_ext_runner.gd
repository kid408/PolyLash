extends "res://tools/top10_effect_selftest_runner.gd"

const DEBUG_PLAYER_EFFECT_GROUPS: Array[String] = [
	"player_skill_effects",
	"projectiles",
	"elite_projectiles",
]

func _init() -> void:
	printerr("[debug_simple_ext] init")
	call_deferred("_run")

func _run() -> void:
	printerr("[debug_simple_ext] run")
	await process_frame
	printerr("[debug_simple_ext] global=%s debug=%s config=%s" % [
		str(_global_node()),
		str(_debug_switcher_node()),
		str(_config_manager_node()),
	])
	var player: Node2D = await _prepare_role_arena("butcher")
	printerr("[debug_simple_ext] player=%s" % str(player))
	if is_instance_valid(player):
		printerr("[debug_simple_ext] player_id=%s pos=%s" % [str(player.get("player_id")), str(player.global_position)])
		var result: Dictionary = await _validate_role_manual("butcher", player)
		printerr("[debug_simple_ext] result=%s" % JSON.stringify(result))
	quit(0)

func _validate_role_manual(role_id: String, player: Node2D) -> Dictionary:
	var anchor: Vector2 = player.global_position
	var standalone: Dictionary = await _run_e_standalone_phase_manual(player, anchor)
	var q_open_phase: Dictionary = await _run_qe_phase_manual(player, anchor, false)
	var q_closed_phase: Dictionary = await _run_qe_phase_manual(player, anchor, true)
	var f_phase: Dictionary = await _run_f_phase_manual(player, anchor, role_id)
	return {
		"role_id": role_id,
		"e_single": standalone,
		"q_open_then_e": q_open_phase,
		"q_closed_then_e": q_closed_phase,
		"f_window": f_phase,
	}

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
	_refill_player_energy(player)
	var e_ok: bool = await _tap_action("skill_e", 10, 18)
	var e_snapshot: Dictionary = _get_player_context_snapshot()
	return {
		"input_ok": q_ok,
		"q_context_ok": q_context_ok,
		"q_effect_ok": _has_any_effect_delta(_diff_counts_manual(before_q_counts, after_q_counts)),
		"e_context_ok": not e_snapshot.get("e_context", {}).is_empty(),
		"e_input_ok": e_ok,
	}

func _run_f_phase_manual(player: Node2D, anchor: Vector2, role_id: String) -> Dictionary:
	await _reset_phase_state_manual(player, anchor)
	var before_counts: Dictionary = _collect_effect_counts_manual()
	var f_ok: bool = await _tap_action("skill_f", 10, 70)
	var snapshot: Dictionary = _get_player_context_snapshot()
	var runtime: Dictionary = _get_player_runtime_snapshot()
	var qef_runtime: Dictionary = runtime.get("qef_runtime", {}) if runtime.get("qef_runtime", {}) is Dictionary else {}
	var f_context: Dictionary = snapshot.get("f_context", {})
	var ultimate_snapshot: Dictionary = runtime.get("ultimate", {})
	return {
		"input_ok": f_ok,
		"f_context_ok": not f_context.is_empty(),
		"f_active_ok": bool(qef_runtime.get("active", false)) or bool(ultimate_snapshot.get("active", false)),
		"f_role_id_ok": (
			str(qef_runtime.get("role_id", qef_runtime.get("f_role_id", ""))).strip_edges() == role_id
			or str(f_context.get("payload", {}).get("f_role_id", "")).strip_edges() == role_id
		),
		"effect_delta": _diff_counts_manual(before_counts, _collect_effect_counts_manual()),
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
	for group_name: String in DEBUG_PLAYER_EFFECT_GROUPS:
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
	for group_name: String in DEBUG_PLAYER_EFFECT_GROUPS:
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

func _has_any_effect_delta(delta: Dictionary) -> bool:
	return int(delta.get("active_effects", 0)) > 0 or int(delta.get("player_effect_nodes", 0)) > 0
