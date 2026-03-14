extends Node

const TOGGLE_RECORD_KEY: Key = KEY_6
const REPLAY_RECORDING_KEY: Key = KEY_7
const TOGGLE_CAPTURE_KEY: Key = KEY_8
const FEEDBACK_INPUT_KEY: Key = KEY_QUOTELEFT

const CHARACTER_FEEDBACK_LOG_PREFIX: String = "user://qa_reports/character_feedback_"
const INPUT_RECORDING_DIR: String = "user://qa_reports/input_recordings"
const INPUT_RECORDING_PREFIX: String = "player_ops_"

const INPUT_SAMPLE_INTERVAL: float = 0.05
const RUNTIME_INFO_REFRESH_INTERVAL: float = 0.20
const E_NO_CD_REFRESH_INTERVAL: float = 0.08
const MOUSE_MOTION_MIN_INTERVAL_MSEC: int = 8
const RECORD_ROLE_GROUP_SIZE: int = 3

var synergy_test_mode_enabled: bool = false

var _runtime_info_layer: CanvasLayer = null
var _runtime_info_panel: PanelContainer = null
var _runtime_info_label: Label = null
var _runtime_info_update_accum: float = 0.0
var _e_no_cd_update_accum: float = 0.0
var _runtime_overlay_activated: bool = false
var _test_mode_active: bool = false

var _feedback_layer: CanvasLayer = null
var _feedback_panel: PanelContainer = null
var _feedback_input_line: LineEdit = null
var _feedback_status_label: Label = null
var _feedback_role_label: Label = null
var _feedback_visible: bool = false
var _feedback_preset_checks: Array[CheckBox] = []
var _feedback_rating_checks: Array[CheckBox] = []
var _feedback_skill_checks: Array[CheckBox] = []
var _feedback_issue_checks: Array[CheckBox] = []
var _last_feedback_log_path: String = ""

var _input_recording_active: bool = false
var _input_recording_started_msec: int = 0
var _input_recording_started_at: String = ""
var _input_recording_path: String = ""
var _input_recording_events: Array[Dictionary] = []
var _input_recording_initial_squad: Dictionary = {}
var _input_recording_initial_player_states: Dictionary = {}
var _input_recording_initial_runtime: Dictionary = {}
var _input_recording_sample_accum: float = 0.0
var _last_mouse_motion_record_msec: int = 0
var _replay_active: bool = false
var _replay_injecting_event: bool = false
var _last_replay_source_path: String = ""
var _recording_role_pool: Array[String] = []
var _recording_group_index: int = 0
var _replay_sample_action_state: Dictionary = {}

func _ready() -> void:
	Global.set_meta("debug_e_no_cooldown", false)
	Global.set_meta("skill_synergy_test_mode_active", false)
	Global.set_meta("skill_synergy_test_no_damage", false)
	Global.set_meta("qef_test_mode_active", false)
	if Global.has_signal("on_player_switch_requested"):
		if not Global.on_player_switch_requested.is_connected(_on_global_player_switch_requested):
			Global.on_player_switch_requested.connect(_on_global_player_switch_requested)
	call_deferred("_bootstrap_runtime_nodes")

func _bootstrap_runtime_nodes() -> void:
	_ensure_runtime_info_overlay()
	_ensure_feedback_ui()
	_refresh_runtime_info_overlay()

func _process(delta: float) -> void:
	var safe_delta: float = max(0.0, delta)

	if _is_e_no_cooldown_enabled():
		_e_no_cd_update_accum += safe_delta
		if _e_no_cd_update_accum >= E_NO_CD_REFRESH_INTERVAL:
			_e_no_cd_update_accum = 0.0
			_clear_active_player_e_cooldown()

	if _input_recording_active and not _replay_active:
		_input_recording_sample_accum += safe_delta
		if _input_recording_sample_accum >= INPUT_SAMPLE_INTERVAL:
			_input_recording_sample_accum = 0.0
			_record_input_sample()

	_runtime_info_update_accum += safe_delta
	if _runtime_info_update_accum >= RUNTIME_INFO_REFRESH_INTERVAL:
		_runtime_info_update_accum = 0.0
		_refresh_runtime_info_overlay()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_EXIT_TREE:
		_replay_active = false
		_replay_release_sample_actions()
		_finalize_input_recording("game_exit")

func _on_global_player_switch_requested(player_id: String) -> void:
	_refresh_runtime_info_overlay()
	_refresh_feedback_role_label()
	if _is_e_no_cooldown_enabled():
		call_deferred("_clear_active_player_e_cooldown")
	if _input_recording_active and not _replay_active:
		_append_input_record_event("switch_role", {"player_id": player_id})

func _input(event: InputEvent) -> void:
	if _input_recording_active and not _replay_active and not _replay_injecting_event:
		_record_input_event(event)

	if _replay_injecting_event:
		return
	if not (event is InputEventKey):
		return

	var key_event: InputEventKey = event
	if not key_event.pressed or key_event.echo:
		return

	if _is_feedback_input_key(key_event):
		_toggle_feedback_input()
		get_viewport().set_input_as_handled()
		return

	if _feedback_visible:
		if _handle_feedback_input_keys(key_event):
			get_viewport().set_input_as_handled()
		return

	if _is_toggle_record_key(key_event):
		_toggle_recording()
		get_viewport().set_input_as_handled()
		return
	if not _test_mode_active:
		return
	if _is_toggle_capture_key(key_event):
		_toggle_capture_recording()
		get_viewport().set_input_as_handled()
		return
	if _is_replay_recording_key(key_event):
		_toggle_recording_replay()
		get_viewport().set_input_as_handled()
		return
	if _handle_recording_group_shortcuts(key_event):
		get_viewport().set_input_as_handled()
		return

# 兼容 arena_core.gd 对协同测试接口的调用
func is_synergy_test_mode_enabled() -> bool:
	return _test_mode_active

func advance_synergy_group() -> void:
	if not _test_mode_active:
		return
	_switch_recording_group_by_offset(1)

func _is_toggle_record_key(key_event: InputEventKey) -> bool:
	if key_event.ctrl_pressed:
		return false
	return _match_key(key_event, TOGGLE_RECORD_KEY, KEY_KP_6) or _has_digit_unicode(key_event, "6")

func _is_replay_recording_key(key_event: InputEventKey) -> bool:
	return _match_key(key_event, REPLAY_RECORDING_KEY, KEY_KP_7) or _has_digit_unicode(key_event, "7")

func _is_toggle_capture_key(key_event: InputEventKey) -> bool:
	return _match_key(key_event, TOGGLE_CAPTURE_KEY, KEY_KP_8) or _has_digit_unicode(key_event, "8")

func _is_feedback_input_key(key_event: InputEventKey) -> bool:
	if key_event.keycode == FEEDBACK_INPUT_KEY or key_event.physical_keycode == FEEDBACK_INPUT_KEY:
		return true
	return key_event.unicode == 96

func _match_key(key_event: InputEventKey, main_key: Key, keypad_key: Key) -> bool:
	return (
		key_event.keycode == main_key
		or key_event.physical_keycode == main_key
		or key_event.keycode == keypad_key
		or key_event.physical_keycode == keypad_key
	)

func _has_digit_unicode(key_event: InputEventKey, digit: String) -> bool:
	if digit.length() != 1:
		return false
	return key_event.unicode == digit.unicode_at(0)

func _handle_recording_group_shortcuts(key_event: InputEventKey) -> bool:
	if _replay_active:
		return false
	if _recording_role_pool.is_empty():
		_prepare_recording_groups_for_active_role()
	if _recording_role_pool.is_empty():
		return false

	if _match_key(key_event, KEY_1, KEY_KP_1) or _has_digit_unicode(key_event, "1"):
		return _switch_recording_group_slot(0)
	if _match_key(key_event, KEY_2, KEY_KP_2) or _has_digit_unicode(key_event, "2"):
		return _switch_recording_group_slot(1)
	if _match_key(key_event, KEY_3, KEY_KP_3) or _has_digit_unicode(key_event, "3"):
		return _switch_recording_group_slot(2)
	if key_event.keycode == KEY_TAB or key_event.physical_keycode == KEY_TAB:
		return _switch_recording_group_by_offset(1)
	return false

func _prepare_recording_groups_for_active_role() -> void:
	_recording_role_pool = _build_recording_role_pool()
	_recording_group_index = 0
	if _recording_role_pool.is_empty():
		return
	var active_id: String = _get_active_player_id()
	var active_idx: int = _recording_role_pool.find(active_id)
	if active_idx < 0:
		active_idx = 0
	_recording_group_index = int(active_idx / RECORD_ROLE_GROUP_SIZE)
	var slot_in_group: int = active_idx % RECORD_ROLE_GROUP_SIZE
	_apply_recording_group(_recording_group_index, slot_in_group, true)

func _build_recording_role_pool() -> Array[String]:
	var ids: Array[String] = []
	if ConfigManager.has_method("get_enabled_players"):
		var enabled: Array[Dictionary] = ConfigManager.get_enabled_players()
		for row in enabled:
			var pid: String = str(row.get("player_id", "")).strip_edges()
			if pid.is_empty():
				continue
			if not ids.has(pid):
				ids.append(pid)
	if ids.is_empty():
		for pid_raw in Global.selected_player_ids:
			var fallback_id: String = str(pid_raw).strip_edges()
			if fallback_id.is_empty():
				continue
			if not ids.has(fallback_id):
				ids.append(fallback_id)
	return ids

func _get_record_group_count() -> int:
	if _recording_role_pool.is_empty():
		return 0
	return int(ceil(float(_recording_role_pool.size()) / float(RECORD_ROLE_GROUP_SIZE)))

func _get_record_group_ids(group_index: int) -> Array[String]:
	var group_ids: Array[String] = []
	if _recording_role_pool.is_empty():
		return group_ids
	var start: int = group_index * RECORD_ROLE_GROUP_SIZE
	for i in range(RECORD_ROLE_GROUP_SIZE):
		var idx: int = start + i
		if idx < 0 or idx >= _recording_role_pool.size():
			break
		group_ids.append(_recording_role_pool[idx])
	return group_ids

func _switch_recording_group_by_offset(offset: int) -> bool:
	var group_count: int = _get_record_group_count()
	if group_count <= 0:
		return false
	var next_group: int = _recording_group_index + offset
	next_group = posmod(next_group, group_count)
	var switched: bool = _apply_recording_group(next_group, 0)
	if switched and _input_recording_active:
		_append_input_record_event("switch_group", {
			"group_index": next_group,
			"group_ids": _get_record_group_ids(next_group)
		})
	return switched

func _switch_recording_group_slot(slot_index: int) -> bool:
	var group_ids: Array[String] = _get_record_group_ids(_recording_group_index)
	if group_ids.is_empty():
		return false
	if slot_index < 0 or slot_index >= group_ids.size():
		_print_debug_tip("slot not available in current group: %d" % (slot_index + 1))
		return true
	var switched: bool = _apply_recording_group(_recording_group_index, slot_index)
	if switched and _input_recording_active:
		_append_input_record_event("switch_slot", {
			"group_index": _recording_group_index,
			"slot_index": slot_index,
			"player_id": group_ids[slot_index]
		})
	return switched

func _apply_recording_group(group_index: int, preferred_slot: int = -1, force_snapshot: bool = false) -> bool:
	if _recording_role_pool.is_empty():
		return false
	var group_count: int = _get_record_group_count()
	if group_count <= 0:
		return false

	group_index = posmod(group_index, group_count)
	var group_ids: Array[String] = _get_record_group_ids(group_index)
	if group_ids.is_empty():
		return false

	_recording_group_index = group_index
	var target_slot: int = preferred_slot
	if target_slot < 0 or target_slot >= group_ids.size():
		var active_id: String = _get_active_player_id()
		var active_idx: int = group_ids.find(active_id)
		target_slot = active_idx if active_idx >= 0 else 0

	var same_group: bool = _is_same_player_group(Global.selected_player_ids, group_ids)
	if not same_group or force_snapshot:
		var weapons: Dictionary = _build_weapon_map_for_ids(group_ids)
		_apply_squad_snapshot(group_ids, weapons, target_slot)
	else:
		var switched: bool = false
		if Global.has_method("switch_to_player_by_index"):
			switched = bool(Global.call("switch_to_player_by_index", target_slot))
		if not switched:
			_force_switch_player_by_index(target_slot)

	_refresh_runtime_info_overlay()
	return true

func _is_same_player_group(current_ids: Array, target_ids: Array[String]) -> bool:
	if current_ids.size() != target_ids.size():
		return false
	for i in range(target_ids.size()):
		if str(current_ids[i]).strip_edges() != str(target_ids[i]).strip_edges():
			return false
	return true

func _build_weapon_map_for_ids(player_ids: Array[String]) -> Dictionary:
	var weapons: Dictionary = {}
	for pid in player_ids:
		var player_id: String = str(pid).strip_edges()
		if player_id.is_empty():
			continue
		var selected_weapon: String = str(Global.selected_player_weapons.get(player_id, "")).strip_edges()
		if selected_weapon.is_empty() and ConfigManager.has_method("get_player_available_weapon_types"):
			var weapon_types: Array[String] = ConfigManager.get_player_available_weapon_types(player_id)
			if not weapon_types.is_empty():
				selected_weapon = str(weapon_types[0]).strip_edges()
		if not selected_weapon.is_empty():
			weapons[player_id] = selected_weapon
	return weapons

func _toggle_recording() -> void:
	_runtime_overlay_activated = true
	if _test_mode_active:
		_leave_test_mode("key_6_disable")
	else:
		_enter_test_mode()
	_refresh_runtime_info_overlay()

func _enter_test_mode() -> void:
	var active_player_id: String = _get_active_player_id()
	if active_player_id.is_empty():
		_print_debug_tip("test mode failed: no active role")
		return
	_test_mode_active = true
	synergy_test_mode_enabled = true
	Global.set_meta("debug_e_no_cooldown", true)
	Global.set_meta("skill_synergy_test_mode_active", true)
	Global.set_meta("skill_synergy_test_no_damage", true)
	Global.set_meta("skill_synergy_test_wave_time", 999.0)
	Global.set_meta("qef_test_mode_active", true)
	_prepare_recording_groups_for_active_role()
	_clear_active_player_e_cooldown()
	_apply_test_mode_wave_time_override()
	_print_debug_tip("test mode enabled: wave_time=999, key8 toggles recording")

func _leave_test_mode(reason: String) -> void:
	if _input_recording_active:
		_finalize_input_recording(reason)
	_replay_active = false
	_replay_release_sample_actions()
	_test_mode_active = false
	synergy_test_mode_enabled = false
	_recording_role_pool.clear()
	_recording_group_index = 0
	Global.set_meta("debug_e_no_cooldown", false)
	Global.set_meta("skill_synergy_test_mode_active", false)
	Global.set_meta("skill_synergy_test_no_damage", false)
	Global.set_meta("qef_test_mode_active", false)
	_print_debug_tip("test mode disabled")

func _toggle_capture_recording() -> void:
	if not _test_mode_active:
		_print_debug_tip("press 6 to enter test mode first")
		return
	if _input_recording_active:
		_finalize_input_recording("key_8_stop")
		_print_debug_tip("recording stopped and saved")
	else:
		_start_input_recording("key_8_start")
	_refresh_runtime_info_overlay()

func _apply_test_mode_wave_time_override() -> void:
	var scene: Node = get_tree().current_scene
	if not is_instance_valid(scene):
		return
	var spawner_node: Node = scene.get_node_or_null("Spawner")
	if not is_instance_valid(spawner_node):
		return
	var wave_timer: Timer = spawner_node.get_node_or_null("WaveTimer")
	if not is_instance_valid(wave_timer):
		return
	wave_timer.stop()
	wave_timer.wait_time = 999.0
	wave_timer.start()

func _toggle_recording_replay() -> void:
	if not _test_mode_active:
		_print_debug_tip("press 6 to enter test mode first")
		return
	if _replay_active:
		_replay_active = false
		_replay_release_sample_actions()
		_print_debug_tip("replay stop requested")
		_refresh_runtime_info_overlay()
		return

	if _input_recording_active:
		_finalize_input_recording("before_replay")

	var replay_path: String = _find_latest_input_recording_path()
	if replay_path.is_empty():
		_print_debug_tip("replay failed: no recording file")
		return

	var file: FileAccess = FileAccess.open(replay_path, FileAccess.READ)
	if file == null:
		_print_debug_tip("replay failed: cannot open file")
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if not (parsed is Dictionary):
		_print_debug_tip("replay failed: invalid file format")
		return

	_replay_active = true
	_replay_sample_action_state.clear()
	_last_replay_source_path = replay_path
	_refresh_runtime_info_overlay()
	_print_debug_tip("replay started: %s" % ProjectSettings.globalize_path(replay_path))
	call_deferred("_run_input_replay", parsed)

func _start_input_recording(trigger: String) -> void:
	if not _test_mode_active:
		_print_debug_tip("press 6 to enter test mode, then press 8 to record")
		return
	if _input_recording_active:
		return

	var active_player_id: String = _get_active_player_id()
	if active_player_id.is_empty():
		_print_debug_tip("record failed: no active role")
		return
	if DirAccess.make_dir_recursive_absolute(INPUT_RECORDING_DIR) != OK:
		_print_debug_tip("record failed: cannot create recording dir")
		return

	var dt: Dictionary = Time.get_datetime_dict_from_system()
	var timestamp: String = "%04d%02d%02d_%02d%02d%02d" % [
		int(dt.get("year", 1970)),
		int(dt.get("month", 1)),
		int(dt.get("day", 1)),
		int(dt.get("hour", 0)),
		int(dt.get("minute", 0)),
		int(dt.get("second", 0))
	]
	_input_recording_path = "%s/%s%s.json" % [INPUT_RECORDING_DIR, INPUT_RECORDING_PREFIX, timestamp]
	_input_recording_started_msec = Time.get_ticks_msec()
	_input_recording_started_at = Time.get_datetime_string_from_system(false, true)
	_input_recording_events.clear()
	if Global.has_method("save_current_player_state"):
		Global.call("save_current_player_state")
	_input_recording_initial_squad = _build_recording_initial_squad_snapshot()
	_input_recording_initial_player_states = Global.player_states.duplicate(true)
	_input_recording_initial_runtime = _build_recording_initial_runtime_snapshot()
	_input_recording_sample_accum = 0.0
	_last_mouse_motion_record_msec = 0
	_input_recording_active = true

	_append_input_record_event("record_start", {"trigger": trigger})
	_prepare_recording_groups_for_active_role()
	_print_debug_tip("recording started: %s" % ProjectSettings.globalize_path(_input_recording_path))
	_refresh_runtime_info_overlay()

func _finalize_input_recording(reason: String) -> void:
	if not _input_recording_active:
		return

	_append_input_record_event("record_end", {"reason": reason})
	var duration_sec: float = max(
		0.0,
		float(Time.get_ticks_msec() - _input_recording_started_msec) / 1000.0
	)

	var ids_for_catalog: Array = Global.selected_player_ids.duplicate()
	var active_player_id: String = _get_active_player_id()
	if ids_for_catalog.is_empty() and not active_player_id.is_empty():
		ids_for_catalog = [active_player_id]

	var payload: Dictionary = {
		"version": 2,
		"source": "DebugSwitcher",
		"started_at": _input_recording_started_at,
		"ended_at": Time.get_datetime_string_from_system(false, true),
		"duration_sec": duration_sec,
		"stop_reason": reason,
		"e_no_cooldown_default": _is_e_no_cooldown_enabled(),
		"initial_squad": _input_recording_initial_squad.duplicate(true),
		"initial_player_states": _input_recording_initial_player_states.duplicate(true),
		"initial_runtime": _input_recording_initial_runtime.duplicate(true),
		"role_catalog": _build_recording_role_catalog(ids_for_catalog),
		"record_role_pool": _recording_role_pool.duplicate(),
		"events": _input_recording_events
	}

	var file: FileAccess = FileAccess.open(_input_recording_path, FileAccess.WRITE)
	if file == null:
		_print_debug_tip("record save failed: cannot write file")
	else:
		file.store_string(JSON.stringify(payload))
		file.flush()
		file.close()
		_print_debug_tip("record saved: %s" % ProjectSettings.globalize_path(_input_recording_path))

	_input_recording_active = false
	_input_recording_started_msec = 0
	_input_recording_started_at = ""
	_input_recording_events.clear()
	_input_recording_initial_squad.clear()
	_input_recording_initial_player_states.clear()
	_input_recording_initial_runtime.clear()
	_input_recording_sample_accum = 0.0
	_last_mouse_motion_record_msec = 0
	if not _test_mode_active:
		_recording_role_pool.clear()
		_recording_group_index = 0
	_refresh_runtime_info_overlay()

func _build_recording_initial_squad_snapshot() -> Dictionary:
	return {
		"selected_player_ids": Global.selected_player_ids.duplicate(),
		"selected_player_weapons": Global.selected_player_weapons.duplicate(true),
		"current_player_index": Global.current_player_index
	}

func _build_recording_initial_runtime_snapshot() -> Dictionary:
	var snapshot: Dictionary = {
		"mouse_position": _serialize_vec2(get_viewport().get_mouse_position())
	}
	var player_2d: Node2D = Global.player as Node2D
	if is_instance_valid(player_2d):
		snapshot["player_position"] = _serialize_vec2(player_2d.global_position)
		snapshot["player_rotation"] = player_2d.global_rotation
	return snapshot

func _record_input_event(event: InputEvent) -> void:
	if not _input_recording_active or _replay_active or _replay_injecting_event:
		return

	if event is InputEventKey:
		var key_event: InputEventKey = event
		_append_input_record_event("key", {
			"pressed": key_event.pressed,
			"echo": key_event.echo,
			"keycode": int(key_event.keycode),
			"physical_keycode": int(key_event.physical_keycode),
			"unicode": int(key_event.unicode),
			"location": int(key_event.location),
			"device": int(key_event.device),
			"alt_pressed": key_event.alt_pressed,
			"shift_pressed": key_event.shift_pressed,
			"ctrl_pressed": key_event.ctrl_pressed,
			"meta_pressed": key_event.meta_pressed
		})
		return

	if event is InputEventMouseButton:
		var btn_event: InputEventMouseButton = event
		_append_input_record_event("mouse_button", {
			"device": int(btn_event.device),
			"button_index": int(btn_event.button_index),
			"pressed": btn_event.pressed,
			"double_click": btn_event.double_click,
			"factor": float(btn_event.factor),
			"position": _serialize_vec2(btn_event.position),
			"global_position": _serialize_vec2(btn_event.global_position),
			"button_mask": int(btn_event.button_mask),
			"canceled": bool(btn_event.canceled),
			"alt_pressed": btn_event.alt_pressed,
			"shift_pressed": btn_event.shift_pressed,
			"ctrl_pressed": btn_event.ctrl_pressed,
			"meta_pressed": btn_event.meta_pressed
		})
		return

	if event is InputEventMouseMotion:
		var motion_event: InputEventMouseMotion = event
		if motion_event.relative.length_squared() <= 0.001:
			return
		var now_msec: int = Time.get_ticks_msec()
		var left_pressed: bool = Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
		if (
			now_msec - _last_mouse_motion_record_msec < MOUSE_MOTION_MIN_INTERVAL_MSEC
			and motion_event.relative.length_squared() < 1.0
			and not left_pressed
		):
			return
		_last_mouse_motion_record_msec = now_msec
		_append_input_record_event("mouse_motion", {
			"device": int(motion_event.device),
			"position": _serialize_vec2(motion_event.position),
			"global_position": _serialize_vec2(motion_event.global_position),
			"relative": _serialize_vec2(motion_event.relative),
			"velocity": _serialize_vec2(motion_event.velocity),
			"button_mask": int(motion_event.button_mask),
			"pressure": float(motion_event.pressure),
			"tilt": _serialize_vec2(motion_event.tilt),
			"alt_pressed": motion_event.alt_pressed,
			"shift_pressed": motion_event.shift_pressed,
			"ctrl_pressed": motion_event.ctrl_pressed,
			"meta_pressed": motion_event.meta_pressed
		})
		return

	if event is InputEventAction:
		var action_event: InputEventAction = event
		_append_input_record_event("action", {
			"action": action_event.action,
			"pressed": action_event.pressed,
			"strength": action_event.strength
		})

func _record_input_sample() -> void:
	if not _input_recording_active:
		return

	var move_vec: Vector2 = Vector2(
		_action_strength_safe("move_right") - _action_strength_safe("move_left"),
		_action_strength_safe("move_down") - _action_strength_safe("move_up")
	)
	var mouse_pos: Vector2 = get_viewport().get_mouse_position()
	var player_pos: Vector2 = Vector2.ZERO
	var player_rot: float = 0.0
	var player_runtime: Dictionary = {}
	var player_2d: Node2D = Global.player as Node2D
	if is_instance_valid(player_2d):
		player_pos = player_2d.global_position
		player_rot = player_2d.global_rotation
		if player_2d is PlayerBase:
			var player_base: PlayerBase = player_2d as PlayerBase
			player_runtime = {
				"energy": player_base.energy,
				"max_energy": player_base.max_energy,
				"armor": player_base.armor,
				"skill_cooldowns": player_base.get_skill_cooldowns_snapshot()
			}
	_append_input_record_event("sample", {
		"move": _serialize_vec2(move_vec),
		"mouse_position": _serialize_vec2(mouse_pos),
		"player_position": _serialize_vec2(player_pos),
		"player_rotation": player_rot,
		"player_runtime": player_runtime,
		"skill_q_pressed": _action_pressed_safe("skill_q"),
		"skill_e_pressed": _action_pressed_safe("skill_e"),
		"skill_f_pressed": _action_pressed_safe("skill_f"),
		"click_left_pressed": _action_pressed_safe("click_left"),
		"click_right_pressed": _action_pressed_safe("click_right")
	})

func _action_strength_safe(action_name: String) -> float:
	if not InputMap.has_action(action_name):
		return 0.0
	return Input.get_action_strength(action_name)

func _action_pressed_safe(action_name: String) -> bool:
	if not InputMap.has_action(action_name):
		return false
	return Input.is_action_pressed(action_name)

func _append_input_record_event(event_kind: String, data: Dictionary) -> void:
	if not _input_recording_active:
		return

	var t_sec: float = max(
		0.0,
		float(Time.get_ticks_msec() - _input_recording_started_msec) / 1000.0
	)
	var role_info: Dictionary = _build_active_role_info()
	_input_recording_events.append({
		"t": t_sec,
		"event_kind": event_kind,
		"player_id": str(role_info.get("player_id", "")),
		"display_name": str(role_info.get("display_name", "")),
		"skill_e": str(role_info.get("skill_e", "")),
		"desc_e": str(role_info.get("desc_e", "")),
		"data": data
	})

func _find_latest_input_recording_path() -> String:
	var dir: DirAccess = DirAccess.open(INPUT_RECORDING_DIR)
	if dir == null:
		return ""
	var latest_name: String = ""
	dir.list_dir_begin()
	while true:
		var name: String = dir.get_next()
		if name.is_empty():
			break
		if dir.current_is_dir():
			continue
		if not name.begins_with(INPUT_RECORDING_PREFIX) or not name.ends_with(".json"):
			continue
		if latest_name.is_empty() or name > latest_name:
			latest_name = name
	dir.list_dir_end()
	if latest_name.is_empty():
		return ""
	return "%s/%s" % [INPUT_RECORDING_DIR, latest_name]
func _run_input_replay(recording_payload: Dictionary) -> void:
	if not _replay_active:
		return

	_replay_sample_action_state.clear()
	await _apply_recording_initial_state(recording_payload)

	var events_raw: Variant = recording_payload.get("events", [])
	if not (events_raw is Array):
		_replay_active = false
		_print_debug_tip("replay failed: events missing")
		_refresh_runtime_info_overlay()
		return

	var events: Array = _prepare_replay_events(events_raw)
	var use_sample_fallback: bool = not _has_replay_raw_input_events(events)
	var previous_t: float = 0.0
	for item in events:
		if not _replay_active:
			break
		if not (item is Dictionary):
			continue

		var event_entry: Dictionary = item
		var event_t: float = max(0.0, float(event_entry.get("t", previous_t)))
		var wait_sec: float = max(0.0, event_t - previous_t)
		previous_t = event_t
		if wait_sec > 0.0:
			await _wait_replay_seconds(wait_sec)
			if not _replay_active:
				break

		var event_kind: String = str(event_entry.get("event_kind", ""))
		if event_kind == "record_start" or event_kind == "record_end":
			continue
		if event_kind == "sample":
			if use_sample_fallback:
				_replay_apply_sample_mouse(event_entry)
				_replay_apply_sample_player_state(event_entry)
				_replay_sample_event(event_entry)
			else:
				await _replay_sync_sample_during_raw_input(event_entry)
			continue
		if event_kind == "switch_group":
			_replay_switch_group_event(event_entry)
			await get_tree().process_frame
			continue
		if event_kind == "switch_slot":
			_replay_switch_slot_event(event_entry)
			await get_tree().process_frame
			continue
		if event_kind == "switch_role":
			_replay_switch_role_event(event_entry)
			await get_tree().process_frame
			continue

		await _ensure_replay_player_for_event(event_entry)
		_replay_recorded_input_event(event_entry)

	var finished_normally: bool = _replay_active
	_replay_release_sample_actions()
	_replay_active = false
	_refresh_runtime_info_overlay()
	if finished_normally:
		_print_debug_tip("replay finished")
	else:
		_print_debug_tip("replay stopped")

func _wait_replay_seconds(seconds: float) -> void:
	if seconds <= 0.0:
		return
	var start_msec: int = Time.get_ticks_msec()
	while _replay_active:
		var elapsed_sec: float = float(Time.get_ticks_msec() - start_msec) / 1000.0
		if elapsed_sec >= seconds:
			break
		await get_tree().process_frame

func _prepare_replay_events(events_raw: Array) -> Array:
	var wrapped: Array = []
	var order_idx: int = 0
	for item in events_raw:
		if not (item is Dictionary):
			order_idx += 1
			continue
		var entry: Dictionary = item
		wrapped.append({
			"idx": order_idx,
			"t": float(entry.get("t", 0.0)),
			"entry": entry
		})
		order_idx += 1

	wrapped.sort_custom(func(a, b):
		var ta: float = float(a.get("t", 0.0))
		var tb: float = float(b.get("t", 0.0))
		if is_equal_approx(ta, tb):
			return int(a.get("idx", 0)) < int(b.get("idx", 0))
		return ta < tb
	)

	var sorted_entries: Array = []
	for row in wrapped:
		sorted_entries.append(row.get("entry", {}))
	return sorted_entries

func _has_replay_raw_input_events(events: Array) -> bool:
	for item in events:
		if not (item is Dictionary):
			continue
		var entry: Dictionary = item
		var event_kind: String = str(entry.get("event_kind", ""))
		if (
			event_kind == "key"
			or event_kind == "mouse_button"
			or event_kind == "mouse_motion"
			or event_kind == "action"
		):
			return true
	return false

func _normalize_string_array(raw: Variant) -> Array[String]:
	var result: Array[String] = []
	if not (raw is Array):
		return result
	for item in raw:
		var text: String = str(item).strip_edges()
		if text.is_empty():
			continue
		result.append(text)
	return result

func _ensure_recording_role_pool_for_replay() -> bool:
	if not _recording_role_pool.is_empty():
		return true
	_recording_role_pool = _build_recording_role_pool()
	if _recording_role_pool.is_empty():
		_recording_role_pool = _normalize_string_array(Global.selected_player_ids)
	return not _recording_role_pool.is_empty()

func _replay_switch_group_to_index(group_index: int) -> bool:
	if not _ensure_recording_role_pool_for_replay():
		return false
	var group_count: int = _get_record_group_count()
	if group_count <= 0:
		return false
	var normalized_group_index: int = posmod(group_index, group_count)
	var group_ids: Array[String] = _get_record_group_ids(normalized_group_index)
	if group_ids.is_empty():
		return false
	_apply_squad_snapshot(group_ids, _build_weapon_map_for_ids(group_ids), 0)
	_recording_group_index = normalized_group_index
	return true

func _ensure_player_available_for_replay(player_id: String) -> bool:
	var normalized_id: String = player_id.strip_edges()
	if normalized_id.is_empty():
		return false
	if Global.selected_player_ids.has(normalized_id):
		return true
	if not _ensure_recording_role_pool_for_replay():
		return false
	var role_idx: int = _recording_role_pool.find(normalized_id)
	if role_idx < 0:
		return false
	var group_index: int = int(role_idx / RECORD_ROLE_GROUP_SIZE)
	var slot_index: int = role_idx % RECORD_ROLE_GROUP_SIZE
	var group_ids: Array[String] = _get_record_group_ids(group_index)
	if group_ids.is_empty():
		return false
	_apply_squad_snapshot(group_ids, _build_weapon_map_for_ids(group_ids), slot_index)
	_recording_group_index = group_index
	return true

func _replay_switch_to_slot(slot_index: int) -> bool:
	var ids: Array[String] = Global.selected_player_ids
	if slot_index < 0 or slot_index >= ids.size():
		return false
	if int(Global.current_player_index) == slot_index:
		return true
	var switched: bool = false
	if Global.has_method("switch_to_player_by_index"):
		switched = bool(Global.call("switch_to_player_by_index", slot_index))
	if not switched:
		switched = _force_switch_player_by_index(slot_index)
	return switched

func _replay_switch_role_event(event_entry: Dictionary) -> void:
	var data_raw: Variant = event_entry.get("data", {})
	if not (data_raw is Dictionary):
		return
	var data: Dictionary = data_raw
	var target_player_id: String = str(
		data.get("player_id", event_entry.get("player_id", ""))
	).strip_edges()
	if target_player_id.is_empty():
		return
	if not _switch_to_player_id_for_replay(target_player_id):
		if _ensure_player_available_for_replay(target_player_id):
			_switch_to_player_id_for_replay(target_player_id)

func _replay_switch_group_event(event_entry: Dictionary) -> void:
	var data_raw: Variant = event_entry.get("data", {})
	if not (data_raw is Dictionary):
		return
	var data: Dictionary = data_raw
	var group_index: int = int(data.get("group_index", _recording_group_index))
	var group_ids: Array[String] = _normalize_string_array(data.get("group_ids", []))
	if not group_ids.is_empty():
		_apply_squad_snapshot(group_ids, _build_weapon_map_for_ids(group_ids), 0)
		if _ensure_recording_role_pool_for_replay():
			var role_idx: int = _recording_role_pool.find(group_ids[0])
			if role_idx >= 0:
				_recording_group_index = int(role_idx / RECORD_ROLE_GROUP_SIZE)
			else:
				_recording_group_index = posmod(group_index, max(1, _get_record_group_count()))
		return
	_replay_switch_group_to_index(group_index)

func _replay_switch_slot_event(event_entry: Dictionary) -> void:
	var data_raw: Variant = event_entry.get("data", {})
	if not (data_raw is Dictionary):
		return
	var data: Dictionary = data_raw
	var group_index: int = int(data.get("group_index", _recording_group_index))
	_replay_switch_group_to_index(group_index)
	var target_player_id: String = str(data.get("player_id", "")).strip_edges()
	if not target_player_id.is_empty():
		if not _switch_to_player_id_for_replay(target_player_id):
			if _ensure_player_available_for_replay(target_player_id):
				_switch_to_player_id_for_replay(target_player_id)
		return
	var slot_index: int = int(data.get("slot_index", 0))
	_replay_switch_to_slot(slot_index)

func _replay_emit_action_event(action_name: String, pressed: bool, strength: float = 1.0) -> void:
	if not InputMap.has_action(action_name):
		return
	var action_event: InputEventAction = InputEventAction.new()
	action_event.action = action_name
	action_event.pressed = pressed
	action_event.strength = strength if pressed else 0.0
	var was_injecting: bool = _replay_injecting_event
	_replay_injecting_event = true
	Input.parse_input_event(action_event)
	_replay_injecting_event = was_injecting

func _replay_apply_sample_action(action_name: String, pressed: bool) -> void:
	var prev_pressed: bool = bool(_replay_sample_action_state.get(action_name, false))
	if prev_pressed == pressed:
		return
	_replay_emit_action_event(action_name, pressed, 1.0)
	_replay_sample_action_state[action_name] = pressed

func _replay_apply_sample_move(move_vec: Vector2) -> void:
	_replay_apply_sample_action("move_left", move_vec.x < -0.1)
	_replay_apply_sample_action("move_right", move_vec.x > 0.1)
	_replay_apply_sample_action("move_up", move_vec.y < -0.1)
	_replay_apply_sample_action("move_down", move_vec.y > 0.1)

func _replay_apply_sample_mouse(event_entry: Dictionary) -> void:
	var data_raw: Variant = event_entry.get("data", {})
	if not (data_raw is Dictionary):
		return
	var data: Dictionary = data_raw
	_replay_warp_mouse_position(_deserialize_vec2(data.get("mouse_position", {})))

func _replay_sync_sample_during_raw_input(event_entry: Dictionary) -> void:
	var data_raw: Variant = event_entry.get("data", {})
	if not (data_raw is Dictionary):
		return
	var data: Dictionary = data_raw
	var skill_q_pressed: bool = bool(data.get("skill_q_pressed", false))
	var click_left_pressed: bool = bool(data.get("click_left_pressed", false))
	if not skill_q_pressed and not click_left_pressed:
		return
	await _ensure_replay_player_for_event(event_entry)
	_replay_apply_sample_player_state(event_entry)
	_replay_warp_mouse_position(_deserialize_vec2(data.get("mouse_position", {})))

func _replay_apply_sample_player_state(event_entry: Dictionary) -> void:
	var data_raw: Variant = event_entry.get("data", {})
	if not (data_raw is Dictionary):
		return
	var data: Dictionary = data_raw

	var sample_player_id: String = str(event_entry.get("player_id", "")).strip_edges()
	if not sample_player_id.is_empty() and sample_player_id != _get_active_player_id():
		if _ensure_player_available_for_replay(sample_player_id):
			_switch_to_player_id_for_replay(sample_player_id)

	var pos_raw: Variant = data.get("player_position", {})
	if not (pos_raw is Dictionary):
		return
	var pos_dict: Dictionary = pos_raw
	if not pos_dict.has("x") or not pos_dict.has("y"):
		return
	var player_2d: Node2D = Global.player as Node2D
	if not is_instance_valid(player_2d):
		return
	var target_pos: Vector2 = _deserialize_vec2(pos_dict)
	if player_2d.global_position.distance_to(target_pos) > 4.0:
		player_2d.global_position = target_pos
	if player_2d is PlayerBase:
		var player_base: PlayerBase = player_2d as PlayerBase
		if data.has("player_rotation"):
			player_base.global_rotation = float(data.get("player_rotation", player_base.global_rotation))
		var runtime_raw: Variant = data.get("player_runtime", {})
		if runtime_raw is Dictionary:
			var runtime: Dictionary = runtime_raw
			if runtime.has("max_energy"):
				player_base.max_energy = float(runtime.get("max_energy", player_base.max_energy))
			if runtime.has("energy"):
				player_base.energy = clamp(
					float(runtime.get("energy", player_base.energy)),
					0.0,
					player_base.max_energy
				)
			if runtime.has("armor"):
				player_base.armor = int(runtime.get("armor", player_base.armor))
			var cooldowns_raw: Variant = runtime.get("skill_cooldowns", {})
			if cooldowns_raw is Dictionary and player_base.has_method("queue_restore_skill_cooldowns"):
				player_base.queue_restore_skill_cooldowns(cooldowns_raw, 0.0, 1.0)

func _replay_warp_mouse_position(screen_pos: Vector2) -> void:
	var viewport: Viewport = get_viewport()
	if not is_instance_valid(viewport):
		return
	viewport.warp_mouse(screen_pos)

func _replay_sample_event(event_entry: Dictionary) -> void:
	var data_raw: Variant = event_entry.get("data", {})
	if not (data_raw is Dictionary):
		return
	var data: Dictionary = data_raw
	_replay_apply_sample_move(_deserialize_vec2(data.get("move", {})))
	_replay_apply_sample_action("skill_q", bool(data.get("skill_q_pressed", false)))
	_replay_apply_sample_action("skill_e", bool(data.get("skill_e_pressed", false)))
	_replay_apply_sample_action("skill_f", bool(data.get("skill_f_pressed", false)))
	_replay_apply_sample_action("click_left", bool(data.get("click_left_pressed", false)))
	_replay_apply_sample_action("click_right", bool(data.get("click_right_pressed", false)))

func _replay_release_sample_actions() -> void:
	for action_key in _replay_sample_action_state.keys():
		var action_name: String = str(action_key)
		if bool(_replay_sample_action_state.get(action_name, false)):
			_replay_emit_action_event(action_name, false, 0.0)
	_replay_sample_action_state.clear()

func _apply_recording_initial_state(recording_payload: Dictionary) -> void:
	var squad_raw: Variant = recording_payload.get("initial_squad", {})
	var player_states_raw: Variant = recording_payload.get("initial_player_states", {})
	var player_states_snapshot: Dictionary = (
		player_states_raw if player_states_raw is Dictionary else {}
	)
	if squad_raw is Dictionary:
		var squad: Dictionary = squad_raw
		var ids_raw: Variant = squad.get("selected_player_ids", [])
		var ids: Array[String] = []
		if ids_raw is Array:
			for raw_id in ids_raw:
				var normalized_id: String = str(raw_id).strip_edges()
				if not normalized_id.is_empty():
					ids.append(normalized_id)
		var weapons_raw: Variant = squad.get("selected_player_weapons", {})
		var weapons: Dictionary = weapons_raw if weapons_raw is Dictionary else {}
		var idx: int = int(squad.get("current_player_index", 0))
		_apply_squad_snapshot(ids, weapons, idx, player_states_snapshot)
		await _restore_replay_initial_runtime_state(recording_payload.get("initial_runtime", {}))

	var role_pool_raw: Variant = recording_payload.get("record_role_pool", [])
	_recording_role_pool = _normalize_string_array(role_pool_raw)
	if _recording_role_pool.is_empty():
		_recording_role_pool = _build_recording_role_pool()
	_recording_group_index = 0
	if not _recording_role_pool.is_empty():
		var active_idx: int = _recording_role_pool.find(_get_active_player_id())
		if active_idx >= 0:
			_recording_group_index = int(active_idx / RECORD_ROLE_GROUP_SIZE)

	Global.set_meta("debug_e_no_cooldown", true)
	call_deferred("_clear_active_player_e_cooldown")
	_refresh_runtime_info_overlay()

func _restore_replay_initial_runtime_state(runtime_raw: Variant) -> void:
	if not (runtime_raw is Dictionary):
		return
	var runtime: Dictionary = runtime_raw
	var mouse_pos_raw: Variant = runtime.get("mouse_position", {})
	if mouse_pos_raw is Dictionary:
		_replay_warp_mouse_position(_deserialize_vec2(mouse_pos_raw))

	var has_player_position: bool = false
	var player_pos_raw: Variant = runtime.get("player_position", {})
	if player_pos_raw is Dictionary:
		var pos_dict: Dictionary = player_pos_raw
		has_player_position = pos_dict.has("x") and pos_dict.has("y")

	var retry_frames: int = 6
	while retry_frames > 0 and not is_instance_valid(Global.player):
		retry_frames -= 1
		await get_tree().process_frame

	var player_2d: Node2D = Global.player as Node2D
	if not is_instance_valid(player_2d):
		return
	if has_player_position:
		player_2d.global_position = _deserialize_vec2(player_pos_raw)
	if runtime.has("player_rotation"):
		player_2d.global_rotation = float(runtime.get("player_rotation", player_2d.global_rotation))

func _ensure_replay_player_for_event(event_entry: Dictionary) -> void:
	var target_player_id: String = str(event_entry.get("player_id", "")).strip_edges()
	if target_player_id.is_empty():
		return
	if _get_active_player_id() != target_player_id:
		if not _switch_to_player_id_for_replay(target_player_id):
			if _ensure_player_available_for_replay(target_player_id):
				_switch_to_player_id_for_replay(target_player_id)
	var retry_frames: int = 6
	while retry_frames > 0:
		if _get_active_player_id() == target_player_id and is_instance_valid(Global.player):
			return
		retry_frames -= 1
		await get_tree().process_frame

func _replay_recorded_input_event(event_entry: Dictionary) -> void:
	var event_kind: String = str(event_entry.get("event_kind", ""))
	var data_raw: Variant = event_entry.get("data", {})
	if not (data_raw is Dictionary):
		return
	var data: Dictionary = data_raw
	if event_kind == "key" and bool(data.get("echo", false)):
		return

	_replay_injecting_event = true
	if event_kind == "key":
		var key_event: InputEventKey = InputEventKey.new()
		key_event.pressed = bool(data.get("pressed", false))
		key_event.echo = bool(data.get("echo", false))
		key_event.keycode = int(data.get("keycode", 0))
		key_event.physical_keycode = int(data.get("physical_keycode", 0))
		key_event.unicode = int(data.get("unicode", 0))
		key_event.location = int(data.get("location", KEY_LOCATION_UNSPECIFIED))
		key_event.device = int(data.get("device", -1))
		key_event.alt_pressed = bool(data.get("alt_pressed", false))
		key_event.shift_pressed = bool(data.get("shift_pressed", false))
		key_event.ctrl_pressed = bool(data.get("ctrl_pressed", false))
		key_event.meta_pressed = bool(data.get("meta_pressed", false))
		Input.parse_input_event(key_event)
	elif event_kind == "mouse_button":
		var mouse_btn_event: InputEventMouseButton = InputEventMouseButton.new()
		mouse_btn_event.device = int(data.get("device", -1))
		mouse_btn_event.button_index = int(data.get("button_index", MOUSE_BUTTON_LEFT))
		mouse_btn_event.pressed = bool(data.get("pressed", false))
		mouse_btn_event.double_click = bool(data.get("double_click", false))
		mouse_btn_event.factor = float(data.get("factor", 1.0))
		mouse_btn_event.position = _deserialize_vec2(data.get("position", {}))
		mouse_btn_event.global_position = _deserialize_vec2(data.get("global_position", data.get("position", {})))
		mouse_btn_event.button_mask = int(data.get("button_mask", 0))
		mouse_btn_event.canceled = bool(data.get("canceled", false))
		mouse_btn_event.alt_pressed = bool(data.get("alt_pressed", false))
		mouse_btn_event.shift_pressed = bool(data.get("shift_pressed", false))
		mouse_btn_event.ctrl_pressed = bool(data.get("ctrl_pressed", false))
		mouse_btn_event.meta_pressed = bool(data.get("meta_pressed", false))
		_replay_warp_mouse_position(mouse_btn_event.position)
		Input.parse_input_event(mouse_btn_event)
	elif event_kind == "mouse_motion":
		var motion_event: InputEventMouseMotion = InputEventMouseMotion.new()
		motion_event.device = int(data.get("device", -1))
		motion_event.position = _deserialize_vec2(data.get("position", {}))
		motion_event.global_position = _deserialize_vec2(data.get("global_position", data.get("position", {})))
		motion_event.relative = _deserialize_vec2(data.get("relative", {}))
		motion_event.velocity = _deserialize_vec2(data.get("velocity", {}))
		motion_event.button_mask = int(data.get("button_mask", 0))
		motion_event.pressure = float(data.get("pressure", 0.0))
		motion_event.tilt = _deserialize_vec2(data.get("tilt", {}))
		motion_event.alt_pressed = bool(data.get("alt_pressed", false))
		motion_event.shift_pressed = bool(data.get("shift_pressed", false))
		motion_event.ctrl_pressed = bool(data.get("ctrl_pressed", false))
		motion_event.meta_pressed = bool(data.get("meta_pressed", false))
		_replay_warp_mouse_position(motion_event.position)
		Input.parse_input_event(motion_event)
	elif event_kind == "action":
		var action_event: InputEventAction = InputEventAction.new()
		action_event.action = str(data.get("action", ""))
		action_event.pressed = bool(data.get("pressed", false))
		action_event.strength = float(data.get("strength", 0.0))
		Input.parse_input_event(action_event)
	_replay_injecting_event = false

func _switch_to_player_id_for_replay(player_id: String) -> bool:
	var normalized_id: String = player_id.strip_edges()
	if normalized_id.is_empty():
		return false
	var ids: Array[String] = Global.selected_player_ids
	var target_index: int = ids.find(normalized_id)
	if target_index < 0:
		return false
	if int(Global.current_player_index) == target_index:
		return true

	var switched: bool = false
	if Global.has_method("switch_to_player_by_index"):
		switched = bool(Global.call("switch_to_player_by_index", target_index))
	if not switched:
		switched = _force_switch_player_by_index(target_index)
	return switched

func _force_switch_player_by_index(index: int) -> bool:
	var ids: Array[String] = Global.selected_player_ids
	if index < 0 or index >= ids.size():
		return false
	if int(Global.current_player_index) == index:
		return false
	var next_player_id: String = str(ids[index]).strip_edges()
	if next_player_id.is_empty():
		return false
	Global.current_player_index = index
	if Global.has_signal("on_player_switch_requested"):
		Global.emit_signal("on_player_switch_requested", next_player_id)
	return true

func _is_e_no_cooldown_enabled() -> bool:
	if not _test_mode_active:
		return false
	if not Global.has_meta("debug_e_no_cooldown"):
		return false
	return bool(Global.get_meta("debug_e_no_cooldown"))

func _clear_active_player_e_cooldown() -> void:
	if not _is_e_no_cooldown_enabled():
		return
	if not is_instance_valid(Global.player):
		return

	var skill_manager: Node = Global.player.get_node_or_null("SkillManager")
	if not is_instance_valid(skill_manager):
		return
	if not skill_manager.has_method("get_skill"):
		return

	var e_skill_raw: Variant = skill_manager.call("get_skill", "e")
	if e_skill_raw == null:
		return
	if not (e_skill_raw is Object):
		return
	var e_skill_obj: Object = e_skill_raw
	if not is_instance_valid(e_skill_obj):
		return
	if e_skill_obj.has_method("reset_cooldown"):
		e_skill_obj.call("reset_cooldown")
	elif e_skill_obj.has_method("set_cooldown_remaining"):
		e_skill_obj.call("set_cooldown_remaining", 0.0)

func _build_active_role_info() -> Dictionary:
	var player_id: String = _get_active_player_id()
	if player_id.is_empty():
		return {}
	var info: Dictionary = _build_role_info_by_id(player_id)
	info["current_player_index"] = int(Global.current_player_index)
	return info

func _build_role_info_by_id(player_id: String) -> Dictionary:
	var normalized_id: String = player_id.strip_edges()
	if normalized_id.is_empty():
		return {}

	var config: Dictionary = ConfigManager.get_player_config(normalized_id)
	var bindings: Dictionary = ConfigManager.get_player_skill_bindings(normalized_id)
	var q_skill_id: String = str(bindings.get("slot_q", "")).strip_edges()
	var e_skill_id: String = str(bindings.get("slot_e", "")).strip_edges()

	var q_params: Dictionary = {}
	if not q_skill_id.is_empty():
		q_params = ConfigManager.get_skill_params(q_skill_id)
	var e_params: Dictionary = {}
	if not e_skill_id.is_empty():
		e_params = ConfigManager.get_skill_params(e_skill_id)

	var desc_q: String = str(q_params.get("desc_q_line", q_params.get("desc_q_circle", ""))).strip_edges()
	var desc_e: String = str(e_params.get("desc_e", "")).strip_edges()

	return {
		"player_id": normalized_id,
		"display_name": str(config.get("display_name", normalized_id)),
		"skill_q": q_skill_id,
		"skill_e": e_skill_id,
		"desc_q": desc_q,
		"desc_e": desc_e,
		"ultimate": _get_player_ultimate_label(normalized_id)
	}

func _should_show_runtime_info_overlay() -> bool:
	if not _runtime_overlay_activated:
		return false
	return _test_mode_active or _feedback_visible

func _ensure_runtime_info_overlay() -> void:
	if is_instance_valid(_runtime_info_layer) and is_instance_valid(_runtime_info_label):
		return

	_runtime_info_layer = CanvasLayer.new()
	_runtime_info_layer.name = "DebugRuntimeInfoLayer"
	_runtime_info_layer.layer = 120

	_runtime_info_panel = PanelContainer.new()
	_runtime_info_panel.name = "RuntimeInfoPanel"
	_runtime_info_panel.anchor_left = 0.0
	_runtime_info_panel.anchor_top = 0.0
	_runtime_info_panel.anchor_right = 0.0
	_runtime_info_panel.anchor_bottom = 0.0
	_runtime_info_panel.offset_left = 12.0
	_runtime_info_panel.offset_top = 12.0
	_runtime_info_panel.custom_minimum_size = Vector2(520.0, 150.0)

	var margin: MarginContainer = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_bottom", 8)
	_runtime_info_panel.add_child(margin)

	_runtime_info_label = Label.new()
	_runtime_info_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_runtime_info_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_runtime_info_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	_runtime_info_label.text = ""
	margin.add_child(_runtime_info_label)

	_runtime_info_layer.add_child(_runtime_info_panel)
	get_tree().root.call_deferred("add_child", _runtime_info_layer)

func _refresh_runtime_info_overlay() -> void:
	_ensure_runtime_info_overlay()
	if not is_instance_valid(_runtime_info_panel) or not is_instance_valid(_runtime_info_label):
		return
	if not _should_show_runtime_info_overlay():
		_runtime_info_panel.visible = false
		return

	_runtime_info_panel.visible = true
	var role_info: Dictionary = _build_active_role_info()
	var lines: Array[String] = []
	lines.append("快捷键：[6]测试模式 [8]录制 [7]回放 [`]评价")
	lines.append("测试模式：%s" % ("开启" if _test_mode_active else "关闭"))
	lines.append("E无冷却：%s" % ("开启" if _is_e_no_cooldown_enabled() else "关闭"))
	lines.append("录制状态：%s" % ("进行中" if _input_recording_active else "空闲"))
	if _input_recording_active:
		lines.append("录制文件：%s" % _input_recording_path)
	lines.append("回放状态：%s" % ("进行中" if _replay_active else "空闲"))
	if not _last_replay_source_path.is_empty():
		lines.append("回放文件：%s" % _last_replay_source_path)

	var display_name: String = str(role_info.get("display_name", ""))
	var player_id: String = str(role_info.get("player_id", ""))
	if player_id.is_empty():
		lines.append("当前角色：无")
	else:
		lines.append("当前角色：%s (%s)" % [display_name, player_id])
		lines.append("E技能ID：%s" % str(role_info.get("skill_e", "")))
		lines.append("E技能描述：%s" % str(role_info.get("desc_e", "")))
		lines.append("F技能：%s" % str(role_info.get("ultimate", "")))
	if _test_mode_active and not _recording_role_pool.is_empty():
		var group_count: int = _get_record_group_count()
		var group_label: String = "%d/%d" % [_recording_group_index + 1, max(1, group_count)]
		lines.append("角色分组：%s（1/2/3 切槽位，Tab 下一组）" % group_label)
		lines.append("分组角色：%s" % ", ".join(_get_record_group_ids(_recording_group_index)))

	_runtime_info_label.text = "\n".join(lines)

func _toggle_feedback_input() -> void:
	if _feedback_visible:
		_close_feedback_input()
	else:
		_open_feedback_input()

func _open_feedback_input() -> void:
	_ensure_feedback_ui()
	_feedback_visible = true
	if is_instance_valid(_feedback_panel):
		_feedback_panel.visible = true
	if is_instance_valid(_feedback_layer):
		_feedback_layer.visible = true
	_refresh_feedback_role_label()
	if is_instance_valid(_feedback_status_label):
		_feedback_status_label.text = "回车提交，Esc关闭"
	call_deferred("_focus_feedback_input_line")

func _close_feedback_input() -> void:
	_feedback_visible = false
	if is_instance_valid(_feedback_panel):
		_feedback_panel.visible = false
	if is_instance_valid(_feedback_layer):
		_feedback_layer.visible = false

func _handle_feedback_input_keys(key_event: InputEventKey) -> bool:
	if key_event.keycode == KEY_ESCAPE or key_event.physical_keycode == KEY_ESCAPE:
		_close_feedback_input()
		return true
	if key_event.keycode == KEY_ENTER or key_event.keycode == KEY_KP_ENTER:
		_submit_feedback_note()
		return true
	return false

func _on_feedback_input_line_gui_input(event: InputEvent) -> void:
	if not _feedback_visible:
		return
	if not (event is InputEventKey):
		return
	var key_event: InputEventKey = event
	if not key_event.pressed or key_event.echo:
		return
	if key_event.keycode == KEY_ESCAPE or key_event.physical_keycode == KEY_ESCAPE:
		_close_feedback_input()
		get_viewport().set_input_as_handled()

func _focus_feedback_input_line() -> void:
	if not _feedback_visible:
		return
	if not is_instance_valid(_feedback_input_line):
		return
	if not _feedback_input_line.is_inside_tree():
		call_deferred("_focus_feedback_input_line")
		return
	_feedback_input_line.grab_focus()

func _submit_feedback_note() -> void:
	if not _feedback_visible:
		return
	var role_info: Dictionary = _build_active_role_info()
	var player_id: String = str(role_info.get("player_id", "")).strip_edges()
	if player_id.is_empty():
		if is_instance_valid(_feedback_status_label):
			_feedback_status_label.text = "提交失败：当前无激活角色"
		return

	var note: String = ""
	if is_instance_valid(_feedback_input_line):
		note = _feedback_input_line.text.strip_edges()

	var presets: Array[String] = _collect_checked_values(_feedback_preset_checks)
	var ratings: Array[String] = _collect_checked_values(_feedback_rating_checks)
	var skills: Array[String] = _collect_checked_values(_feedback_skill_checks)
	var issues: Array[String] = _collect_checked_values(_feedback_issue_checks)

	if presets.is_empty() and ratings.is_empty() and skills.is_empty() and issues.is_empty() and note.is_empty():
		if is_instance_valid(_feedback_status_label):
			_feedback_status_label.text = "请至少勾选一项或输入备注"
		return

	_append_feedback_log_entry(role_info, presets, ratings, skills, issues, note)
	if is_instance_valid(_feedback_input_line):
		_feedback_input_line.clear()

func _append_feedback_log_entry(
	role_info: Dictionary,
	presets: Array[String],
	ratings: Array[String],
	skills: Array[String],
	issues: Array[String],
	note: String
) -> void:
	if DirAccess.make_dir_recursive_absolute("user://qa_reports") != OK:
		if is_instance_valid(_feedback_status_label):
			_feedback_status_label.text = "提交失败：无法创建 qa_reports 目录"
		return

	var log_path: String = _ensure_feedback_log_file_path()
	var write_header: bool = not FileAccess.file_exists(log_path)
	var file: FileAccess = null
	if write_header:
		file = FileAccess.open(log_path, FileAccess.WRITE)
	else:
		file = FileAccess.open(log_path, FileAccess.READ_WRITE)
	if file == null:
		if is_instance_valid(_feedback_status_label):
			_feedback_status_label.text = "提交失败：无法打开 CSV 文件"
		return

	if write_header:
		_write_utf8_bom(file)
		file.store_line(_to_csv_line([
			"timestamp",
			"player_id",
			"display_name",
			"skill_q",
			"skill_e",
			"desc_q",
			"desc_e",
			"ultimate",
			"preset_conclusions",
			"ratings",
			"skill_focus",
			"issue_tags",
			"note",
			"recording_file",
			"replay_file"
		]))
	else:
		file.seek_end()

	file.store_line(_to_csv_line([
		Time.get_datetime_string_from_system(false, true),
		str(role_info.get("player_id", "")),
		str(role_info.get("display_name", "")),
		str(role_info.get("skill_q", "")),
		str(role_info.get("skill_e", "")),
		str(role_info.get("desc_q", "")),
		str(role_info.get("desc_e", "")),
		str(role_info.get("ultimate", "")),
		";".join(presets),
		";".join(ratings),
		";".join(skills),
		";".join(issues),
		note,
		_input_recording_path,
		_last_replay_source_path
	]))
	file.flush()
	file.close()

	if is_instance_valid(_feedback_status_label):
		_feedback_status_label.text = "已保存：%s" % ProjectSettings.globalize_path(log_path)

func _ensure_feedback_log_file_path() -> String:
	var dt: Dictionary = Time.get_datetime_dict_from_system()
	var date_tag: String = "%04d%02d%02d" % [
		int(dt.get("year", 1970)),
		int(dt.get("month", 1)),
		int(dt.get("day", 1))
	]
	_last_feedback_log_path = "%s%s.csv" % [CHARACTER_FEEDBACK_LOG_PREFIX, date_tag]
	return _last_feedback_log_path

func _ensure_feedback_ui() -> void:
	if is_instance_valid(_feedback_layer) and is_instance_valid(_feedback_panel):
		return

	_feedback_layer = CanvasLayer.new()
	_feedback_layer.name = "DebugFeedbackLayer"
	_feedback_layer.layer = 121

	_feedback_panel = PanelContainer.new()
	_feedback_panel.name = "FeedbackPanel"
	_feedback_panel.anchor_left = 0.5
	_feedback_panel.anchor_top = 0.15
	_feedback_panel.anchor_right = 0.5
	_feedback_panel.anchor_bottom = 0.15
	_feedback_panel.offset_left = -360.0
	_feedback_panel.offset_top = 0.0
	_feedback_panel.offset_right = 360.0
	_feedback_panel.offset_bottom = 420.0
	_feedback_panel.visible = false

	var margin: MarginContainer = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_bottom", 10)
	_feedback_panel.add_child(margin)

	var root_vbox: VBoxContainer = VBoxContainer.new()
	root_vbox.add_theme_constant_override("separation", 6)
	margin.add_child(root_vbox)

	var title: Label = Label.new()
	title.text = "角色评价面板（` 打开/关闭）"
	root_vbox.add_child(title)

	_feedback_role_label = Label.new()
	_feedback_role_label.text = "当前角色：-"
	root_vbox.add_child(_feedback_role_label)

	_feedback_preset_checks = _build_feedback_checkbox_group(
		root_vbox,
		"预设结论",
		["手感顺畅", "需要调优", "偏弱", "偏强", "有BUG", "与预期不符"],
		3
	)
	_feedback_rating_checks = _build_feedback_checkbox_group(
		root_vbox,
		"评分",
		["1", "2", "3", "4", "5"],
		5
	)
	_feedback_skill_checks = _build_feedback_checkbox_group(
		root_vbox,
		"关注维度",
		["伤害", "范围", "前摇", "后摇", "打击感", "生存", "连招流畅度"],
		4
	)
	_feedback_issue_checks = _build_feedback_checkbox_group(
		root_vbox,
		"问题标签",
		["卡顿", "判定", "文本", "特效", "音效", "交互"],
		3
	)

	var note_label: Label = Label.new()
	note_label.text = "补充说明"
	root_vbox.add_child(note_label)

	_feedback_input_line = LineEdit.new()
	_feedback_input_line.placeholder_text = "输入对当前角色/技能的看法，按回车提交"
	_feedback_input_line.gui_input.connect(_on_feedback_input_line_gui_input)
	root_vbox.add_child(_feedback_input_line)

	var button_row: HBoxContainer = HBoxContainer.new()
	button_row.add_theme_constant_override("separation", 8)
	root_vbox.add_child(button_row)

	var submit_btn: Button = Button.new()
	submit_btn.text = "提交（Enter）"
	submit_btn.pressed.connect(_submit_feedback_note)
	button_row.add_child(submit_btn)

	var close_btn: Button = Button.new()
	close_btn.text = "关闭（Esc）"
	close_btn.pressed.connect(_close_feedback_input)
	button_row.add_child(close_btn)

	_feedback_status_label = Label.new()
	_feedback_status_label.text = ""
	root_vbox.add_child(_feedback_status_label)

	_feedback_layer.add_child(_feedback_panel)
	_feedback_layer.visible = false
	get_tree().root.call_deferred("add_child", _feedback_layer)

func _build_feedback_checkbox_group(
	parent: VBoxContainer,
	title: String,
	options: Array[String],
	columns: int
) -> Array[CheckBox]:
	var checks: Array[CheckBox] = []

	var title_label: Label = Label.new()
	title_label.text = title
	parent.add_child(title_label)

	var grid: GridContainer = GridContainer.new()
	grid.columns = max(1, columns)
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 4)
	parent.add_child(grid)

	for option in options:
		var cb: CheckBox = CheckBox.new()
		cb.text = option
		grid.add_child(cb)
		checks.append(cb)

	return checks

func _collect_checked_values(checks: Array[CheckBox]) -> Array[String]:
	var values: Array[String] = []
	for cb in checks:
		if not is_instance_valid(cb):
			continue
		if cb.button_pressed:
			values.append(cb.text)
	return values

func _refresh_feedback_role_label() -> void:
	if not is_instance_valid(_feedback_role_label):
		return
	var role_info: Dictionary = _build_active_role_info()
	var pid: String = str(role_info.get("player_id", ""))
	var display_name: String = str(role_info.get("display_name", ""))
	var skill_e: String = str(role_info.get("skill_e", ""))
	if pid.is_empty():
		_feedback_role_label.text = "当前角色：无"
		return
	_feedback_role_label.text = "当前角色：%s (%s) | E技能：%s" % [display_name, pid, skill_e]

func _serialize_vec2(v: Vector2) -> Dictionary:
	return {"x": v.x, "y": v.y}

func _deserialize_vec2(data: Variant) -> Vector2:
	if data is Dictionary:
		var d: Dictionary = data
		return Vector2(float(d.get("x", 0.0)), float(d.get("y", 0.0)))
	if data is Array:
		var a: Array = data
		if a.size() >= 2:
			return Vector2(float(a[0]), float(a[1]))
	return Vector2.ZERO

func _build_recording_role_catalog(player_ids: Array) -> Array:
	var catalog: Array = []
	for raw_id in player_ids:
		var player_id: String = str(raw_id).strip_edges()
		if player_id.is_empty():
			continue
		catalog.append(_build_role_info_by_id(player_id))
	return catalog

func _get_player_ultimate_label(player_id: String) -> String:
	var normalized_id: String = player_id.strip_edges()
	if normalized_id.is_empty():
		return ""
	var ult_config: Dictionary = ConfigRepository.get_ult_config_for_player(normalized_id)
	if ult_config.is_empty():
		return ""
	return str(ult_config.get("name", ult_config.get("ult_name", ""))).strip_edges()

func _get_active_player_id() -> String:
	if is_instance_valid(Global.player):
		var current_player_id_raw: Variant = Global.player.get("player_id")
		var current_player_id: String = str(current_player_id_raw).strip_edges()
		if not current_player_id.is_empty():
			return current_player_id
	if Global.has_method("get_current_player_id"):
		return str(Global.call("get_current_player_id")).strip_edges()
	var ids: Array[String] = Global.selected_player_ids
	if ids.is_empty():
		return ""
	var index: int = int(clamp(Global.current_player_index, 0, ids.size() - 1))
	return str(ids[index]).strip_edges()

func _apply_squad_snapshot(
	ids: Array[String],
	weapons: Dictionary,
	index: int,
	player_states_snapshot: Dictionary = {}
) -> void:
	if ids.is_empty():
		return

	Global.selected_player_ids = ids.duplicate()
	Global.selected_player_weapons = weapons.duplicate(true)
	Global.current_player_index = int(clamp(index, 0, ids.size() - 1))
	if Global.has_method("init_player_states"):
		Global.call("init_player_states")
	if not player_states_snapshot.is_empty():
		Global.player_states = player_states_snapshot.duplicate(true)

	var active_player_id: String = str(ids[Global.current_player_index]).strip_edges()
	if not active_player_id.is_empty():
		if Global.has_method("mark_player_activated"):
			Global.call("mark_player_activated", active_player_id)
		if Global.has_signal("on_player_switch_requested"):
			Global.emit_signal("on_player_switch_requested", active_player_id)

func _to_csv_line(cells: Array[String]) -> String:
	var escaped: Array[String] = []
	for cell in cells:
		var content: String = str(cell).replace("\"", "\"\"")
		escaped.append("\"%s\"" % content)
	return ",".join(escaped)

func _write_utf8_bom(file: FileAccess) -> void:
	file.store_buffer(PackedByteArray([0xEF, 0xBB, 0xBF]))

func _print_debug_tip(text: String) -> void:
	print("[DebugSwitcher] %s" % text)
