extends SceneTree

const TEST_ROLES: Array[String] = [
	"butcher",
	"frostbite",
	"shaman",
	"nexus",
	"bulwark",
	"windblade",
	"polaris",
	"bloodhowl",
	"beastmaster",
	"medium",
]
const ARENA_SCENE: String = "res://scenes/arena/arena.tscn"
const ENEMY_SCENE: String = "res://scenes/unit/enemy/enemy_generic.tscn"
const SUMMARY_PATH: String = "user://qa_reports/top10_effect_selftest_summary.json"
const PLAYER_EFFECT_GROUPS: Array[String] = [
	"player_skill_effects",
	"projectiles",
	"elite_projectiles",
]

var _results: Array[Dictionary] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var passed: bool = true
	await process_frame

	if _global_node() == null or _debug_switcher_node() == null or _config_manager_node() == null:
		_results.append({
			"kind": "bootstrap",
			"passed": false,
			"reason": "autoload_missing",
		})
		_write_summary(false)
		quit(1)
		return

	_reset_global_session()

	for role_id: String in TEST_ROLES:
		var result: Dictionary = await _validate_role(role_id)
		_results.append(result)
		passed = passed and bool(result.get("passed", false))

	_leave_test_mode_if_needed()
	# 给 deferred queue_free / 物理状态刷新多留一点收尾时间，减少退出噪音。
	await _wait_frames(24)
	await _wait_real_seconds(0.12)
	_write_summary(passed)
	quit(0 if passed else 1)


func _validate_role(role_id: String) -> Dictionary:
	var result: Dictionary = {
		"kind": "top10_effect_selftest",
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

	var standalone: Dictionary = await _run_e_standalone_phase(player, anchor)
	result["phases"]["e_single"] = standalone
	result["checks"]["e_single_context"] = bool(standalone.get("e_context_ok", false))

	var q_open_phase: Dictionary = await _run_qe_phase(player, anchor, false)
	result["phases"]["q_open_then_e"] = q_open_phase
	result["checks"]["q_open_context"] = bool(q_open_phase.get("q_context_ok", false))
	result["checks"]["q_open_effect"] = bool(q_open_phase.get("q_effect_ok", false))
	result["checks"]["e_after_open_context"] = bool(q_open_phase.get("e_context_ok", false))

	var q_closed_phase: Dictionary = await _run_qe_phase(player, anchor, true)
	result["phases"]["q_closed_then_e"] = q_closed_phase
	result["checks"]["q_closed_context"] = bool(q_closed_phase.get("q_context_ok", false))
	result["checks"]["q_closed_effect"] = bool(q_closed_phase.get("q_effect_ok", false))
	result["checks"]["e_after_closed_context"] = bool(q_closed_phase.get("e_context_ok", false))

	var f_phase: Dictionary = await _run_f_phase(player, anchor, role_id)
	result["phases"]["f_window"] = f_phase
	result["checks"]["f_context"] = bool(f_phase.get("f_context_ok", false))
	result["checks"]["f_active"] = bool(f_phase.get("f_active_ok", false))
	result["checks"]["f_role_id"] = bool(f_phase.get("f_role_id_ok", false))

	result["passed"] = _all_checks_pass(result.get("checks", {}))
	return result


func _run_e_standalone_phase(player: Node2D, anchor: Vector2) -> Dictionary:
	await _reset_phase_state(player, anchor)
	var before_counts: Dictionary = _collect_effect_counts()
	var e_ok: bool = await _tap_action("skill_e", 10, 18)
	var snapshot: Dictionary = _get_player_context_snapshot()
	var after_counts: Dictionary = _collect_effect_counts()
	return {
		"input_ok": e_ok,
		"counts_before": before_counts,
		"counts_after": after_counts,
		"counts_delta": _diff_counts(before_counts, after_counts),
		"e_context_ok": not snapshot.get("e_context", {}).is_empty(),
		"e_context": snapshot.get("e_context", {}),
	}


func _run_qe_phase(player: Node2D, anchor: Vector2, closed_path: bool) -> Dictionary:
	await _reset_phase_state(player, anchor)
	var before_q_counts: Dictionary = _collect_effect_counts()
	var q_ok: bool = await _perform_scripted_q_path(_get_active_role_id(), closed_path)
	var q_snapshot: Dictionary = _get_player_context_snapshot()
	var after_q_counts: Dictionary = _collect_effect_counts()

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

	var q_delta: Dictionary = _diff_counts(before_q_counts, after_q_counts)
	var q_effect_ok: bool = int(q_delta.get("active_effects", 0)) > 0 or int(q_delta.get("player_effect_nodes", 0)) > 0

	_refill_player_energy(player)
	var e_ok: bool = await _tap_action("skill_e", 10, 18)
	var e_snapshot: Dictionary = _get_player_context_snapshot()
	var after_e_counts: Dictionary = _collect_effect_counts()
	return {
		"input_ok": q_ok,
		"counts_before_q": before_q_counts,
		"counts_after_q": after_q_counts,
		"counts_after_e": after_e_counts,
		"q_counts_delta": q_delta,
		"e_counts_delta": _diff_counts(after_q_counts, after_e_counts),
		"q_context_ok": q_context_ok,
		"q_effect_ok": q_effect_ok,
		"q_context": q_context,
		"e_input_ok": e_ok,
		"e_context_ok": not e_snapshot.get("e_context", {}).is_empty(),
		"e_context": e_snapshot.get("e_context", {}),
	}


func _run_f_phase(player: Node2D, anchor: Vector2, role_id: String) -> Dictionary:
	await _reset_phase_state(player, anchor)
	var before_counts: Dictionary = _collect_effect_counts()
	var f_ok: bool = await _tap_action("skill_f", 10, 70)
	var snapshot: Dictionary = _get_player_context_snapshot()
	var runtime: Dictionary = _get_player_runtime_snapshot()
	var after_counts: Dictionary = _collect_effect_counts()
	var f_context: Dictionary = snapshot.get("f_context", {})
	var ultimate_snapshot: Dictionary = runtime.get("ultimate", {})
	return {
		"input_ok": f_ok,
		"counts_before": before_counts,
		"counts_after": after_counts,
		"counts_delta": _diff_counts(before_counts, after_counts),
		"f_context_ok": not f_context.is_empty(),
		"f_active_ok": bool(ultimate_snapshot.get("active", false)),
		"f_role_id_ok": str(f_context.get("payload", {}).get("f_role_id", "")).strip_edges() == role_id,
		"f_context": f_context,
		"ultimate_runtime": ultimate_snapshot,
	}


func _reset_phase_state(player: Node2D, anchor: Vector2) -> void:
	_deactivate_ultimate_if_needed()
	_clear_runtime_effects()
	_clear_dummy_enemies()
	await _wait_frames(4)
	if is_instance_valid(player):
		player.global_position = anchor
		player.rotation = 0.0
	_refill_player_energy(player)
	_spawn_dummy_enemies(anchor)
	await _wait_frames(10)


func _clear_runtime_effects() -> void:
	var skill_effect_manager: Node = _skill_effect_manager_node()
	if skill_effect_manager != null and skill_effect_manager.has_method("clear_all_effects"):
		skill_effect_manager.call("clear_all_effects")
	for group_name: String in PLAYER_EFFECT_GROUPS:
		for node_var: Variant in get_nodes_in_group(group_name):
			if node_var == null or not is_instance_valid(node_var):
				continue
			if node_var is Node:
				(node_var as Node).queue_free()


func _collect_effect_counts() -> Dictionary:
	var active_effects_count: int = 0
	var skill_effect_manager: Node = _skill_effect_manager_node()
	if skill_effect_manager != null and "active_effects" in skill_effect_manager:
		active_effects_count = int((skill_effect_manager.get("active_effects") as Dictionary).size())
	var player_effect_nodes: int = 0
	for group_name: String in PLAYER_EFFECT_GROUPS:
		player_effect_nodes += get_nodes_in_group(group_name).size()
	return {
		"active_effects": active_effects_count,
		"player_effect_nodes": player_effect_nodes,
	}


func _diff_counts(before: Dictionary, after: Dictionary) -> Dictionary:
	return {
		"active_effects": int(after.get("active_effects", 0)) - int(before.get("active_effects", 0)),
		"player_effect_nodes": int(after.get("player_effect_nodes", 0)) - int(before.get("player_effect_nodes", 0)),
	}


func _refill_player_energy(player: Node2D) -> void:
	if not is_instance_valid(player):
		return
	if "max_energy" in player and "energy" in player:
		player.set("energy", player.get("max_energy"))


func _prepare_role_arena(role_id: String) -> Node2D:
	_leave_test_mode_if_needed()
	_reset_global_session()

	var global_node: Node = _global_node()
	var selected_ids: Array[String] = [role_id]
	global_node.set("selected_player_ids", selected_ids)
	global_node.set("selected_player_weapons", {role_id: _pick_default_weapon(role_id)})
	global_node.set("current_player_index", 0)
	if global_node.has_method("init_player_states"):
		global_node.call("init_player_states")

	var change_err: Error = change_scene_to_file(ARENA_SCENE)
	if change_err != OK:
		return null

	var player: Node2D = await _wait_for_player(role_id, 240)
	if not is_instance_valid(player):
		return null

	var debug_switcher: Node = _debug_switcher_node()
	if debug_switcher != null:
		debug_switcher.call("_enter_test_mode")
	await _wait_frames(18)
	return await _wait_for_player(role_id, 120)


func _wait_for_player(role_id: String, max_frames: int) -> Node2D:
	for _i: int in range(max_frames):
		var player_var: Variant = _global_node().get("player")
		if player_var is Node2D:
			var player: Node2D = player_var
			if is_instance_valid(player) and str(player.get("player_id")).strip_edges() == role_id:
				return player
		await process_frame
	return null


func _perform_scripted_q_path(role_id: String, closed_path: bool) -> bool:
	var q_skill: Node = _get_q_skill()
	var player: Node2D = _current_player()
	if q_skill == null or not is_instance_valid(q_skill) or not is_instance_valid(player):
		return false
	if not q_skill.has_method("_enter_planning_mode") or not q_skill.has_method("release"):
		return false

	q_skill.call("_enter_planning_mode")
	await _wait_frames(2)
	await _wait_real_seconds(0.04)

	var anchor: Vector2 = player.global_position
	var points: Array[Vector2] = []
	if closed_path:
		points = [
			anchor + Vector2(-150.0, -90.0),
			anchor + Vector2(150.0, -90.0),
			anchor + Vector2(150.0, 90.0),
			anchor + Vector2(-150.0, 90.0),
			anchor + Vector2(-150.0, -90.0),
		]
	else:
		points = [
			anchor + Vector2(-150.0, -30.0),
			anchor + Vector2(10.0, -10.0),
			anchor + Vector2(180.0, 55.0),
		]
	if points.size() < 2:
		return false

	var path_segments: Array[Dictionary] = []
	var total_distance: float = 0.0
	for idx: int in range(points.size() - 1):
		var start: Vector2 = points[idx]
		var finish: Vector2 = points[idx + 1]
		path_segments.append({"start": start, "end": finish})
		total_distance += start.distance_to(finish)

	q_skill.set("path_points", points.duplicate())
	q_skill.set("path_segments", path_segments)
	if "last_point" in q_skill:
		q_skill.set("last_point", points[points.size() - 1])
	if "total_distance_drawn" in q_skill:
		q_skill.set("total_distance_drawn", total_distance)
	if "is_drawing" in q_skill:
		q_skill.set("is_drawing", false)
	if "has_closure" in q_skill:
		q_skill.set("has_closure", closed_path)
	if role_id == "butcher" and "is_path_closed" in q_skill:
		q_skill.set("is_path_closed", closed_path)

	q_skill.call("release")
	await _wait_frames(18)
	await _wait_real_seconds(0.08)
	return true


func _tap_action(action_name: String, press_frames: int = 8, settle_frames: int = 12) -> bool:
	_set_action_pressed(action_name, true)
	await _wait_frames(max(1, press_frames))
	await _wait_real_seconds(0.05)
	_set_action_pressed(action_name, false)
	await _wait_frames(max(1, settle_frames))
	await _wait_real_seconds(0.06)
	return true


func _spawn_dummy_enemies(anchor: Vector2) -> void:
	_clear_dummy_enemies()
	var scene: PackedScene = load(ENEMY_SCENE) as PackedScene
	if scene == null or current_scene == null:
		return

	var offsets: Array[Vector2] = [
		Vector2(180.0, 0.0),
		Vector2(120.0, 90.0),
		Vector2(90.0, -120.0),
	]
	for offset: Vector2 in offsets:
		var enemy: Node2D = scene.instantiate() as Node2D
		if enemy == null:
			continue
		if "enemy_id" in enemy:
			enemy.set("enemy_id", "basic_enemy")
		enemy.name = "CLIEnemy_%s" % str(offset)
		current_scene.add_child(enemy)
		enemy.global_position = anchor + offset


func _clear_dummy_enemies() -> void:
	for enemy_var: Variant in get_nodes_in_group("enemies"):
		if enemy_var == null or not is_instance_valid(enemy_var):
			continue
		if enemy_var is Node:
			var enemy: Node = enemy_var
			if enemy.name.begins_with("CLIEnemy_"):
				enemy.queue_free()


func _current_player() -> Node2D:
	var player_var: Variant = _global_node().get("player")
	if player_var is Node2D and is_instance_valid(player_var):
		return player_var
	return null


func _get_q_skill() -> Node:
	var player: Node2D = _current_player()
	if not is_instance_valid(player):
		return null
	var skill_manager: Node = player.get_node_or_null("SkillManager")
	if skill_manager == null or not skill_manager.has_method("get_skill"):
		return null
	var skill_var: Variant = skill_manager.call("get_skill", "q")
	return skill_var if skill_var is Node else null


func _get_active_role_id() -> String:
	var player: Node2D = _current_player()
	if not is_instance_valid(player):
		return ""
	return str(player.get("player_id")).strip_edges()


func _get_player_context_snapshot() -> Dictionary:
	var player_var: Variant = _global_node().get("player")
	if player_var is Node and (player_var as Node).has_method("get_skill_context_snapshot"):
		return (player_var as Node).call("get_skill_context_snapshot")
	return {}


func _get_player_runtime_snapshot() -> Dictionary:
	var player_var: Variant = _global_node().get("player")
	if player_var is Node and (player_var as Node).has_method("get_skill_runtime_snapshot"):
		return (player_var as Node).call("get_skill_runtime_snapshot")
	return {}


func _deactivate_ultimate_if_needed() -> void:
	var player_var: Variant = _global_node().get("player")
	if not (player_var is Node):
		return
	var player_node: Node = player_var
	var ultimate_var: Variant = player_node.get("ultimate_skill")
	if ultimate_var is Node and bool((ultimate_var as Node).get("is_active")):
		(ultimate_var as Node).call("deactivate")


func _leave_test_mode_if_needed() -> void:
	var debug_switcher: Node = _debug_switcher_node()
	if debug_switcher == null:
		return
	if bool(debug_switcher.get("_test_mode_active")):
		debug_switcher.call("_leave_test_mode", "cli_cleanup")


func _reset_global_session() -> void:
	var global_node: Node = _global_node()
	if global_node == null:
		return
	if global_node.has_method("reset_selection"):
		global_node.call("reset_selection")
	if global_node.has_method("reset_session_data"):
		global_node.call("reset_session_data")
	global_node.set("pending_battle_state", {})
	global_node.set("player", null)


func _pick_default_weapon(role_id: String) -> String:
	var config_manager: Node = _config_manager_node()
	if config_manager == null or not config_manager.has_method("get_player_available_weapon_types"):
		return ""
	var weapon_types_raw: Variant = config_manager.call("get_player_available_weapon_types", role_id)
	if not (weapon_types_raw is Array):
		return ""
	var weapon_types: Array = weapon_types_raw
	if weapon_types.is_empty():
		return ""
	return str(weapon_types[0]).strip_edges()


func _set_action_pressed(action_name: String, pressed: bool) -> void:
	if not InputMap.has_action(action_name):
		return
	var event: InputEventAction = InputEventAction.new()
	event.action = action_name
	event.pressed = pressed
	event.strength = 1.0 if pressed else 0.0
	Input.parse_input_event(event)


func _wait_frames(frame_count: int) -> void:
	for _i: int in range(max(1, frame_count)):
		await process_frame


func _wait_real_seconds(seconds: float) -> void:
	if seconds <= 0.0:
		return
	await create_timer(seconds).timeout


func _all_checks_pass(checks_raw: Variant) -> bool:
	if not (checks_raw is Dictionary):
		return false
	var checks: Dictionary = checks_raw
	if checks.is_empty():
		return false
	for value_var: Variant in checks.values():
		if not bool(value_var):
			return false
	return true


func _write_summary(passed: bool) -> void:
	DirAccess.make_dir_recursive_absolute("user://qa_reports")
	var payload: Dictionary = {
		"passed": passed,
		"generated_at": Time.get_datetime_string_from_system(false, true),
		"results": _results,
	}
	var file: FileAccess = FileAccess.open(SUMMARY_PATH, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify(payload, "\t"))
	file.flush()
	file.close()


func _global_node() -> Node:
	return get_root().get_node_or_null("Global")


func _debug_switcher_node() -> Node:
	return get_root().get_node_or_null("DebugSwitcher")


func _config_manager_node() -> Node:
	return get_root().get_node_or_null("ConfigManager")


func _skill_effect_manager_node() -> Node:
	return get_root().get_node_or_null("SkillEffectManager")

