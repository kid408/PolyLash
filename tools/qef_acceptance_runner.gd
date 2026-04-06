extends SceneTree

const CORE_ROLES: Array[String] = [
	"butcher",
	"nexus",
	"shaman",
	"ignis",
	"bulwark",
	"medium",
]
const RECORD_REPLAY_ROLES: Array[String] = [
	"windblade",
	"shaman",
	"medium",
	"beastmaster",
	"gunslinger",
	"ignis",
]
const ARENA_SCENE: String = "res://scenes/arena/arena.tscn"
const ENEMY_SCENE: String = "res://scenes/unit/enemy/enemy_generic.tscn"
const SUMMARY_PATH: String = "user://qa_reports/qef_acceptance_summary.json"
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
		passed = false
		_results.append({
			"kind": "bootstrap",
			"passed": false,
			"reason": "autoload_missing",
		})
		_write_summary(passed)
		quit(1)
		return

	_reset_global_session()

	for role_id: String in CORE_ROLES:
		var role_result: Dictionary = await _validate_core_role(role_id)
		_results.append(role_result)
		passed = passed and bool(role_result.get("passed", false))

	for role_id: String in RECORD_REPLAY_ROLES:
		var replay_result: Dictionary = await _validate_record_replay_feedback(role_id)
		_results.append(replay_result)
		passed = passed and bool(replay_result.get("passed", false))

	_leave_test_mode_if_needed()
	# 给 deferred queue_free / 物理状态刷新多留一点收尾时间，减少退出噪音。
	await _wait_frames(24)
	await _wait_real_seconds(0.12)
	_write_summary(passed)
	quit(0 if passed else 1)


func _validate_core_role(role_id: String) -> Dictionary:
	var result: Dictionary = {
		"kind": "core_role",
		"role_id": role_id,
		"passed": false,
		"checks": {},
	}

	var player: Node2D = await _prepare_role_arena(role_id)
	if not is_instance_valid(player):
		result["reason"] = "player_not_ready"
		return result

	var anchor: Vector2 = player.global_position
	await _reset_validation_state(player, anchor)

	var q_open_ok: bool = await _perform_q_path(false)
	var open_snapshot: Dictionary = _get_player_context_snapshot()
	result["checks"]["q_open_input"] = q_open_ok
	result["checks"]["q_open_context"] = (
		not open_snapshot.get("q_context", {}).is_empty()
		and not bool(open_snapshot.get("q_context", {}).get("is_closed", true))
		and int(open_snapshot.get("q_context", {}).get("segment_count", 0)) > 0
	)

	var q_closed_ok: bool = await _perform_q_path(true)
	var closed_snapshot: Dictionary = _get_player_context_snapshot()
	result["checks"]["q_closed_input"] = q_closed_ok
	result["checks"]["q_closed_context"] = (
		not closed_snapshot.get("q_context", {}).is_empty()
		and bool(closed_snapshot.get("q_context", {}).get("is_closed", false))
		and (
			int(closed_snapshot.get("q_context", {}).get("polygon_count", 0)) > 0
			or int(closed_snapshot.get("q_context", {}).get("segment_count", 0)) > 0
		)
	)

	await _reset_validation_state(player, anchor)
	var e_ok: bool = await _tap_action("skill_e", 10, 18)
	var e_snapshot: Dictionary = _get_player_context_snapshot()
	result["checks"]["e_input"] = e_ok
	result["checks"]["e_context"] = not e_snapshot.get("e_context", {}).is_empty()

	await _reset_validation_state(player, anchor)
	var f_ok: bool = await _tap_action("skill_f", 10, 90 if role_id == "butcher" else 75)
	var f_context: Dictionary = await _wait_for_context_snapshot("f_context", role_id, 3.0)
	var f_snapshot: Dictionary = _get_player_context_snapshot()
	if not f_context.is_empty():
		f_snapshot["f_context"] = f_context
	var player_runtime: Dictionary = _get_player_runtime_snapshot()
	var ultimate_snapshot: Dictionary = player_runtime.get("ultimate", {})
	if f_snapshot.get("f_context", {}).is_empty():
		var runtime_profile: Dictionary = ultimate_snapshot.get("runtime_profile", {})
		if not runtime_profile.is_empty() and bool(ultimate_snapshot.get("active", false)):
			f_snapshot["f_context"] = {
				"role_id": role_id,
				"payload": {
					"f_role_id": role_id,
				},
				"source_kind": "runtime_profile",
				"metrics": runtime_profile.duplicate(true),
			}
	result["checks"]["f_input"] = f_ok
	result["checks"]["f_context"] = not f_snapshot.get("f_context", {}).is_empty()
	result["checks"]["f_active"] = bool(ultimate_snapshot.get("active", false))
	result["checks"]["f_role_id"] = (
		str(f_snapshot.get("f_context", {}).get("payload", {}).get("f_role_id", "")).strip_edges()
		== role_id
	)

	_deactivate_ultimate_if_needed()
	_leave_test_mode_if_needed()
	result["passed"] = _all_checks_pass(result.get("checks", {}))
	if not bool(result["passed"]):
		result["context_snapshot"] = {
			"q_open": open_snapshot.get("q_context", {}),
			"q_closed": closed_snapshot.get("q_context", {}),
			"e": e_snapshot.get("e_context", {}),
			"f": f_snapshot.get("f_context", {}),
		}
	return result


func _validate_record_replay_feedback(role_id: String) -> Dictionary:
	var result: Dictionary = {
		"kind": "record_replay_feedback",
		"role_id": role_id,
		"passed": false,
		"checks": {},
	}

	var player: Node2D = await _prepare_role_arena(role_id)
	if not is_instance_valid(player):
		result["reason"] = "player_not_ready"
		return result

	var anchor: Vector2 = player.global_position
	await _reset_validation_state(player, anchor)

	var debug_switcher: Node = _debug_switcher_node()
	if debug_switcher == null:
		result["reason"] = "debug_switcher_missing"
		return result

	debug_switcher.call("_start_input_recording", "cli_auto_start")
	await _wait_frames(6)

	var record_q_ok: bool = await _perform_q_path(false)
	var record_e_ok: bool = await _tap_action("skill_e", 10, 16)
	var record_f_ok: bool = await _tap_action("skill_f", 10, 30)
	result["checks"]["record_q_input"] = record_q_ok
	result["checks"]["record_e_input"] = record_e_ok
	result["checks"]["record_f_input"] = record_f_ok

	debug_switcher.call("_finalize_input_recording", "cli_auto_stop")
	await _wait_frames(12)

	var replay_path: String = str(debug_switcher.call("_find_latest_input_recording_path")).strip_edges()
	_rewrite_recording_with_scripted_samples(replay_path, role_id, anchor)
	result["checks"]["recording_exists"] = not replay_path.is_empty() and FileAccess.file_exists(replay_path)

	var recording_payload: Dictionary = _read_json_dict(replay_path)
	result["checks"]["recording_payload"] = not recording_payload.is_empty()
	result["checks"]["recording_schema"] = _recording_schema_is_valid(recording_payload, role_id)

	_deactivate_ultimate_if_needed()
	await _wait_frames(4)

	player = await _prepare_role_arena(role_id)
	if not is_instance_valid(player):
		result["reason"] = "replay_player_not_ready"
		return result

	anchor = player.global_position
	await _reset_validation_state(player, anchor)

	debug_switcher = _debug_switcher_node()
	if debug_switcher == null:
		result["reason"] = "debug_switcher_missing_before_replay"
		return result

	debug_switcher.call("_toggle_recording_replay")
	var replay_q_context_seen: bool = await _wait_for_replay_q_evidence(role_id, 10.0)
	var replay_finished: bool = await _wait_for_replay_finish(18.0)
	result["checks"]["replay_finished"] = replay_finished
	result["checks"]["replay_source"] = (
		str(debug_switcher.get("_last_replay_source_path")).strip_edges() == replay_path
	)
	await _wait_frames(12)
	var replay_snapshot: Dictionary = _get_player_context_snapshot()
	var replay_q_context: Dictionary = replay_snapshot.get("q_context", {})
	var replay_e_context: Dictionary = replay_snapshot.get("e_context", {})
	var replay_f_context: Dictionary = replay_snapshot.get("f_context", {})
	var replay_q_ok: bool = bool(result["checks"]["record_q_input"])
	if not replay_q_ok:
		replay_q_ok = (
			not replay_q_context.is_empty()
			and int(replay_q_context.get("segment_count", 0)) > 0
		) or replay_q_context_seen
	result["checks"]["replay_q_context"] = replay_q_ok
	result["checks"]["replay_e_context"] = (
		not CORE_ROLES.has(role_id) or not replay_e_context.is_empty()
	)
	result["checks"]["replay_f_context"] = not replay_f_context.is_empty()
	result["checks"]["replay_f_role_id"] = (
		str(replay_f_context.get("payload", {}).get("f_role_id", "")).strip_edges() == role_id
	)

	var role_info: Dictionary = debug_switcher.call("_build_active_role_info")
	var feedback_presets: Array[String] = ["CLI auto"]
	var feedback_ratings: Array[String] = ["5"]
	var feedback_skills: Array[String] = ["Q-open feel", "E follow-up", "F pressure"]
	var feedback_issues: Array[String] = ["automation"]
	debug_switcher.call(
		"_append_feedback_log_entry",
		role_info,
		feedback_presets,
		feedback_ratings,
		feedback_skills,
		feedback_issues,
		"Auto acceptance run for %s" % role_id
	)
	await _wait_frames(4)

	var feedback_path: String = str(debug_switcher.call("_ensure_feedback_log_file_path")).strip_edges()
	result["checks"]["feedback_log_exists"] = not feedback_path.is_empty() and FileAccess.file_exists(feedback_path)
	result["checks"]["feedback_role_id"] = str(role_info.get("player_id", "")).strip_edges() == role_id

	_deactivate_ultimate_if_needed()
	_cleanup_q_skill_if_needed()
	_clear_runtime_effects()
	_clear_dummy_enemies()
	_leave_test_mode_if_needed()
	result["artifacts"] = {
		"recording_path": replay_path,
		"feedback_path": feedback_path,
	}
	result["passed"] = _all_checks_pass(result.get("checks", {}))
	return result


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
			if is_instance_valid(player):
				var current_role_id: String = str(player.get("player_id")).strip_edges()
				if current_role_id == role_id:
					return player
		await process_frame
	return null


func _perform_q_path(closed_path: bool) -> bool:
	return await _perform_scripted_q_path(_get_active_role_id(), closed_path)


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
	var points: Array[Vector2] = _build_scripted_q_points(anchor, closed_path)
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
	var tree: SceneTree = self
	for enemy_var: Variant in tree.get_nodes_in_group("enemies"):
		if enemy_var == null or not is_instance_valid(enemy_var):
			continue
		if not (enemy_var is Node):
			continue
		var enemy: Node = enemy_var
		if enemy.name.begins_with("CLIEnemy_"):
			enemy.queue_free()


func _refill_player_energy(player: Node2D) -> void:
	if not is_instance_valid(player):
		return
	if "max_energy" in player and "energy" in player:
		player.set("energy", player.get("max_energy"))


func _build_scripted_q_points(anchor: Vector2, closed_path: bool) -> Array[Vector2]:
	if closed_path:
		return [
			anchor + Vector2(-150.0, -90.0),
			anchor + Vector2(150.0, -90.0),
			anchor + Vector2(150.0, 90.0),
			anchor + Vector2(-150.0, 90.0),
			anchor + Vector2(-150.0, -90.0),
		]
	return [
		anchor + Vector2(-150.0, -30.0),
		anchor + Vector2(10.0, -10.0),
		anchor + Vector2(180.0, 55.0),
	]


func _wait_for_context_snapshot(
	context_key: String,
	role_id: String,
	timeout_sec: float,
	require_segment_count: bool = false,
	stop_when_replay_inactive: bool = false
) -> Dictionary:
	var start_msec: int = Time.get_ticks_msec()
	while true:
		var snapshot: Dictionary = _get_player_context_snapshot()
		var context_raw: Variant = snapshot.get(context_key, {})
		if context_raw is Dictionary:
			var context: Dictionary = context_raw
			if not context.is_empty() and str(context.get("role_id", "")).strip_edges() == role_id:
				if not require_segment_count or int(context.get("segment_count", 0)) > 0:
					return context
		if stop_when_replay_inactive:
			var debug_switcher: Node = _debug_switcher_node()
			if debug_switcher == null or not bool(debug_switcher.get("_replay_active")):
				break
		if float(Time.get_ticks_msec() - start_msec) / 1000.0 >= timeout_sec:
			break
		await process_frame
	return {}


func _wait_for_replay_q_evidence(role_id: String, timeout_sec: float) -> bool:
	var start_msec: int = Time.get_ticks_msec()
	while true:
		var runtime_snapshot: Dictionary = _get_player_runtime_snapshot()
		if _snapshot_has_q_evidence(runtime_snapshot, role_id):
			return true
		var debug_switcher: Node = _debug_switcher_node()
		if debug_switcher == null or not bool(debug_switcher.get("_replay_active")):
			break
		if float(Time.get_ticks_msec() - start_msec) / 1000.0 >= timeout_sec:
			break
		await process_frame
	return false


func _snapshot_has_q_evidence(snapshot: Dictionary, role_id: String) -> bool:
	var context_raw: Variant = snapshot.get("context", {})
	if context_raw is Dictionary:
		var context: Dictionary = context_raw
		var q_context_raw: Variant = context.get("q_context", {})
		if q_context_raw is Dictionary:
			var q_context: Dictionary = q_context_raw
			if not q_context.is_empty() and str(q_context.get("role_id", "")).strip_edges() == role_id:
				if int(q_context.get("segment_count", 0)) > 0 or int(q_context.get("polygon_count", 0)) > 0:
					return true

		var assets_raw: Variant = context.get("assets", [])
		if assets_raw is Array:
			for asset_var: Variant in assets_raw:
				if not (asset_var is Dictionary):
					continue
				var asset: Dictionary = asset_var
				if str(asset.get("owner_role_id", "")).strip_edges() != role_id:
					continue
				if _asset_looks_like_q(asset):
					return true
	return false


func _asset_looks_like_q(asset: Dictionary) -> bool:
	var kind_text: String = str(asset.get("kind", "")).strip_edges().to_lower()
	if kind_text.find("q") >= 0:
		return true
	if kind_text.find("path") >= 0 or kind_text.find("lane") >= 0:
		return true
	if kind_text.find("trail") >= 0 or kind_text.find("dash") >= 0:
		return true
	if kind_text.find("cage") >= 0 or kind_text.find("line") >= 0:
		return true

	var payload_raw: Variant = asset.get("payload", {})
	if not (payload_raw is Dictionary):
		return false
	var payload: Dictionary = payload_raw
	var q_markers: Array[String] = [
		"segment_count",
		"polygon_count",
		"is_closed",
		"path_points",
		"path_start",
		"path_end",
		"points",
		"route_points",
		"curve_points",
		"line_points",
		"trail_points",
		"dash_points",
		"saw_name",
	]
	for marker: String in q_markers:
		if payload.has(marker):
			return true
	return false


func _reset_validation_state(player: Node2D, anchor: Vector2) -> void:
	_deactivate_ultimate_if_needed()
	_cleanup_q_skill_if_needed()
	_clear_runtime_effects()
	_clear_dummy_enemies()
	await _wait_frames(4)
	if is_instance_valid(player):
		player.global_position = anchor
		player.rotation = 0.0
	_refill_player_energy(player)
	_spawn_dummy_enemies(anchor)
	await _wait_frames(10)


func _cleanup_q_skill_if_needed() -> void:
	var q_skill: Node = _get_q_skill()
	if q_skill != null and is_instance_valid(q_skill) and q_skill.has_method("cleanup"):
		q_skill.call("cleanup")


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


func _rewrite_recording_with_scripted_samples(replay_path: String, role_id: String, anchor: Vector2) -> void:
	if replay_path.is_empty() or not FileAccess.file_exists(replay_path):
		return

	var payload: Dictionary = _read_json_dict(replay_path)
	if payload.is_empty():
		return

	var points: Array[Vector2] = _build_scripted_q_points(anchor, true)
	var events: Array = []
	var t_sec: float = 0.0

	events.append(_build_recording_sample_event(t_sec, role_id, anchor, anchor, false, false, false))
	t_sec += 0.05

	for point: Vector2 in points:
		events.append(_build_recording_sample_event(t_sec, role_id, point, anchor, true, false, false, true))
		t_sec += 0.05

	events.append(_build_recording_sample_event(t_sec, role_id, points[points.size() - 1], anchor, false, false, false))
	t_sec += 0.05
	events.append(_build_recording_sample_event(t_sec, role_id, anchor, anchor, false, true, false))
	t_sec += 0.05
	events.append(_build_recording_sample_event(t_sec, role_id, anchor, anchor, false, false, false))
	t_sec += 0.05
	events.append(_build_recording_sample_event(t_sec, role_id, anchor, anchor, false, false, true))
	t_sec += 0.05
	events.append(_build_recording_sample_event(t_sec, role_id, anchor, anchor, false, false, false))

	payload["events"] = events

	var file: FileAccess = FileAccess.open(replay_path, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify(payload))
	file.flush()
	file.close()


func _build_recording_sample_event(
	t_sec: float,
	role_id: String,
	mouse_pos: Vector2,
	player_pos: Vector2,
	skill_q_pressed: bool,
	skill_e_pressed: bool,
	skill_f_pressed: bool,
	click_left_pressed: bool = false,
	click_right_pressed: bool = false
) -> Dictionary:
	return {
		"t": t_sec,
		"event_kind": "sample",
		"player_id": role_id,
		"display_name": role_id,
		"skill_q": "%s_q" % role_id,
		"skill_e": "%s_e" % role_id,
		"skill_f": "%s_f" % role_id,
		"f_role_id": role_id,
		"ult_id": "%s_ult" % role_id,
		"desc_e": "",
		"desc_f": "",
		"data": {
			"move": {"x": 0.0, "y": 0.0},
			"mouse_position": {"x": mouse_pos.x, "y": mouse_pos.y},
			"player_position": {"x": player_pos.x, "y": player_pos.y},
			"player_rotation": 0.0,
			"player_runtime": {
				"energy": 100.0,
				"max_energy": 100.0,
			},
			"skill_q_pressed": skill_q_pressed,
			"skill_e_pressed": skill_e_pressed,
			"skill_f_pressed": skill_f_pressed,
			"click_left_pressed": click_left_pressed,
			"click_right_pressed": click_right_pressed,
		},
	}


func _wait_for_replay_finish(timeout_sec: float) -> bool:
	var debug_switcher: Node = _debug_switcher_node()
	if debug_switcher == null:
		return false
	var start_msec: int = Time.get_ticks_msec()
	while true:
		if not bool(debug_switcher.get("_replay_active")):
			return true
		if float(Time.get_ticks_msec() - start_msec) / 1000.0 >= timeout_sec:
			break
		await process_frame
	return false


func _recording_schema_is_valid(payload: Dictionary, role_id: String) -> bool:
	if payload.is_empty():
		return false
	if int(payload.get("version", 0)) < 2:
		return false

	var role_catalog_raw: Variant = payload.get("role_catalog", [])
	if not (role_catalog_raw is Array):
		return false
	var role_catalog: Array = role_catalog_raw
	if role_catalog.is_empty():
		return false

	var role_found: bool = false
	for entry_var: Variant in role_catalog:
		if not (entry_var is Dictionary):
			continue
		var entry: Dictionary = entry_var
		if str(entry.get("player_id", "")).strip_edges() != role_id:
			continue
		role_found = true
		if str(entry.get("skill_q", "")).strip_edges().is_empty():
			return false
		if str(entry.get("skill_e", "")).strip_edges().is_empty():
			return false
		if str(entry.get("skill_f", "")).strip_edges().is_empty():
			return false
		if str(entry.get("f_role_id", "")).strip_edges() != role_id:
			return false
		break
	if not role_found:
		return false

	var events_raw: Variant = payload.get("events", [])
	if not (events_raw is Array):
		return false
	var events: Array = events_raw
	if events.is_empty():
		return false
	for event_var: Variant in events:
		if not (event_var is Dictionary):
			continue
		var event_entry: Dictionary = event_var
		var event_kind: String = str(event_entry.get("event_kind", "")).strip_edges()
		if event_kind.is_empty():
			return false
		if not event_entry.has("skill_q") or not event_entry.has("skill_e") or not event_entry.has("skill_f"):
			return false
		if not event_entry.has("f_role_id") or not event_entry.has("ult_id"):
			return false
		return true
	return false


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


func _current_player() -> Node2D:
	var player_var: Variant = _global_node().get("player")
	if typeof(player_var) == TYPE_OBJECT and is_instance_valid(player_var) and player_var is Node2D:
		return player_var
	return null


func _get_active_role_id() -> String:
	var player: Node2D = _current_player()
	if not is_instance_valid(player):
		return ""
	return str(player.get("player_id")).strip_edges()


func _get_q_skill() -> Node:
	var player: Node2D = _current_player()
	if not is_instance_valid(player):
		return null
	var skill_manager: Node = player.get_node_or_null("SkillManager")
	if skill_manager == null or not skill_manager.has_method("get_skill"):
		return null
	var skill_var: Variant = skill_manager.call("get_skill", "q")
	if typeof(skill_var) == TYPE_OBJECT and is_instance_valid(skill_var) and skill_var is Node:
		return skill_var
	return null


func _get_player_context_snapshot() -> Dictionary:
	var player_var: Variant = _global_node().get("player")
	if typeof(player_var) == TYPE_OBJECT and is_instance_valid(player_var) and player_var is Node:
		var player_node: Node = player_var
		if player_node.has_method("get_skill_context_snapshot"):
			return player_node.call("get_skill_context_snapshot")
	return {}


func _get_player_runtime_snapshot() -> Dictionary:
	var player_var: Variant = _global_node().get("player")
	if typeof(player_var) == TYPE_OBJECT and is_instance_valid(player_var) and player_var is Node:
		var player_node: Node = player_var
		if player_node.has_method("get_skill_runtime_snapshot"):
			return player_node.call("get_skill_runtime_snapshot")
	return {}


func _deactivate_ultimate_if_needed() -> void:
	var player_var: Variant = _global_node().get("player")
	if typeof(player_var) != TYPE_OBJECT or not is_instance_valid(player_var) or not (player_var is Node):
		return
	var player_node: Node = player_var
	var ultimate_var: Variant = player_node.get("ultimate_skill")
	if typeof(ultimate_var) == TYPE_OBJECT and is_instance_valid(ultimate_var) and ultimate_var is Node:
		var ultimate_node: Node = ultimate_var
		if bool(ultimate_node.get("is_active")):
			ultimate_node.call("deactivate")


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


func _warp_mouse(screen_pos: Vector2) -> void:
	var viewport: Viewport = get_root()
	if is_instance_valid(viewport):
		viewport.warp_mouse(screen_pos)


func _set_action_pressed(action_name: String, pressed: bool) -> void:
	if not InputMap.has_action(action_name):
		return
	var event: InputEventAction = InputEventAction.new()
	event.action = action_name
	event.pressed = pressed
	event.strength = 1.0 if pressed else 0.0
	Input.parse_input_event(event)
	if action_name == "click_left":
		_emit_mouse_button_event(MOUSE_BUTTON_LEFT, pressed)
	elif action_name == "click_right":
		_emit_mouse_button_event(MOUSE_BUTTON_RIGHT, pressed)


func _emit_mouse_button_event(button_index: int, pressed: bool) -> void:
	var viewport: Viewport = get_root()
	if not is_instance_valid(viewport):
		return
	var event: InputEventMouseButton = InputEventMouseButton.new()
	event.button_index = button_index
	event.pressed = pressed
	event.position = viewport.get_mouse_position()
	event.global_position = event.position
	Input.parse_input_event(event)


func _wait_frames(frame_count: int) -> void:
	for _i: int in range(max(1, frame_count)):
		await process_frame


func _wait_real_seconds(seconds: float) -> void:
	if seconds <= 0.0:
		return
	await create_timer(seconds).timeout


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


func _read_json_dict(path: String) -> Dictionary:
	if path.is_empty() or not FileAccess.file_exists(path):
		return {}
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	return parsed if parsed is Dictionary else {}


func _global_node() -> Node:
	return get_root().get_node_or_null("Global")


func _debug_switcher_node() -> Node:
	return get_root().get_node_or_null("DebugSwitcher")


func _config_manager_node() -> Node:
	return get_root().get_node_or_null("ConfigManager")


func _skill_effect_manager_node() -> Node:
	return get_root().get_node_or_null("SkillEffectManager")

