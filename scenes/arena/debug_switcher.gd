extends Node

const TOGGLE_QEF_TEST_KEY: Key = KEY_8
const EXPORT_QEF_CHECKLIST_KEY: Key = KEY_9
const QUICK_RECORD_KEY: Key = KEY_0
const PRESET_PASS_KEY: Key = KEY_U
const PRESET_FAIL_KEY: Key = KEY_I
const PRESET_BUG_KEY: Key = KEY_O
const PRESET_MIX_KEY: Key = KEY_P
const RATING_2_KEY: Key = KEY_J
const RATING_3_KEY: Key = KEY_K
const RATING_4_KEY: Key = KEY_L
const RATING_5_KEY: Key = KEY_M
const NEXT_CHARACTER_KEY: Key = KEY_BRACKETRIGHT
const PREV_CHARACTER_KEY: Key = KEY_BRACKETLEFT
const SQUAD_BACKUP_FILE: String = "user://qa_reports/qef_squad_backup.json"

var character_ids: Array[String] = []
var current_character_index: int = 0
var qef_test_mode_enabled: bool = false

var _saved_selected_player_ids: Array[String] = []
var _saved_selected_player_weapons: Dictionary = {}
var _saved_current_player_index: int = 0

func _ready() -> void:
	_try_restore_squad_from_backup_file()
	_set_qef_mode_flag(false)
	_reload_character_ids()

func _input(event: InputEvent) -> void:
	if not (event is InputEventKey):
		return
	var key_event: InputEventKey = event
	if not key_event.pressed or key_event.echo:
		return

	if _is_toggle_key(key_event):
		_toggle_qef_test_mode()
		get_viewport().set_input_as_handled()
		return
	if _is_export_key(key_event):
		_export_qef_checklist_csv()
		get_viewport().set_input_as_handled()
		return
	if _is_quick_record_key(key_event):
		_record_current_role_quick_score()
		get_viewport().set_input_as_handled()
		return
	if _try_handle_direct_score_key(key_event):
		get_viewport().set_input_as_handled()
		return

	if not qef_test_mode_enabled:
		return

	if key_event.keycode == NEXT_CHARACTER_KEY:
		_cycle_character(1)
		get_viewport().set_input_as_handled()
		return
	if key_event.keycode == PREV_CHARACTER_KEY:
		_cycle_character(-1)
		get_viewport().set_input_as_handled()
		return

func _toggle_qef_test_mode() -> void:
	if not qef_test_mode_enabled:
		_reload_character_ids()
		if character_ids.is_empty():
			_print_debug_tip("QEF TEST: no enabled players")
			return
		_save_current_squad_state()
		_write_squad_backup_to_disk()
		qef_test_mode_enabled = true
		_set_qef_mode_flag(true)
		_align_current_index_to_active_player()
		_activate_current_character()
		_print_debug_tip("QEF TEST ON [%d/%d] %s" % [
			current_character_index + 1,
			character_ids.size(),
			character_ids[current_character_index]
		])
		_print_debug_tip("SCORE KEYS: U/I/O/P + J/K/L/M")
		return

	qef_test_mode_enabled = false
	_set_qef_mode_flag(false)
	_restore_saved_squad_state()
	_delete_squad_backup_file()
	_print_debug_tip("QEF TEST OFF")

func _cycle_character(step: int) -> void:
	if character_ids.is_empty():
		return
	var size: int = character_ids.size()
	current_character_index = (current_character_index + step) % size
	if current_character_index < 0:
		current_character_index += size
	_activate_current_character()
	_print_debug_tip("QEF TEST [%d/%d] %s" % [
		current_character_index + 1,
		size,
		character_ids[current_character_index]
	])

func _activate_current_character() -> void:
	if character_ids.is_empty():
		return
	var player_id: String = character_ids[current_character_index]
	_ensure_weapon_for_player(player_id)
	Global.selected_player_ids = [player_id]
	Global.current_player_index = 0
	Global.emit_signal("on_player_switch_requested", player_id)

func _reload_character_ids() -> void:
	character_ids.clear()
	var enabled_players: Array[Dictionary] = ConfigManager.get_enabled_players()
	for cfg in enabled_players:
		var player_id: String = str(cfg.get("player_id", "")).strip_edges()
		if not player_id.is_empty():
			character_ids.append(player_id)

func _align_current_index_to_active_player() -> void:
	if character_ids.is_empty():
		current_character_index = 0
		return
	var current_id: String = ""
	if is_instance_valid(Global.player) and ("player_id" in Global.player):
		current_id = str(Global.player.player_id)
	elif Global.selected_player_ids.size() > 0:
		current_id = str(Global.selected_player_ids[0])

	var idx: int = character_ids.find(current_id)
	current_character_index = idx if idx >= 0 else 0

func _ensure_weapon_for_player(player_id: String) -> void:
	var current_weapon: String = str(Global.selected_player_weapons.get(player_id, ""))
	if not current_weapon.is_empty():
		return
	var weapon_types: Array[String] = ConfigManager.get_player_available_weapon_types(player_id)
	if weapon_types.is_empty():
		return
	Global.selected_player_weapons[player_id] = weapon_types[0]

func _save_current_squad_state() -> void:
	_saved_selected_player_ids = Global.selected_player_ids.duplicate()
	_saved_selected_player_weapons = Global.selected_player_weapons.duplicate(true)
	_saved_current_player_index = Global.current_player_index

func _restore_saved_squad_state() -> void:
	if _saved_selected_player_ids.is_empty():
		_try_restore_squad_from_backup_file()
		return
	_apply_squad_snapshot(_saved_selected_player_ids, _saved_selected_player_weapons, _saved_current_player_index)

func _print_debug_tip(text: String) -> void:
	print("[DebugSwitcher] %s" % text)
	if is_instance_valid(Global.player):
		Global.spawn_floating_text(Global.player.global_position, text, Color(0.55, 1.85, 1.45))

func _set_qef_mode_flag(active: bool) -> void:
	Global.set_meta("qef_test_mode_active", active)

func _export_qef_checklist_csv() -> void:
	_reload_character_ids()
	if character_ids.is_empty():
		_print_debug_tip("QEF CSV export failed: no players")
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

	var out_dir: String = "user://qa_reports"
	var mk_err: int = DirAccess.make_dir_recursive_absolute(out_dir)
	if mk_err != OK:
		push_error("[DebugSwitcher] create qa_reports failed: %d" % mk_err)
		_print_debug_tip("QEF CSV export failed")
		return

	var out_path: String = "%s/qef_checklist_%s.csv" % [out_dir, timestamp]
	var f: FileAccess = FileAccess.open(out_path, FileAccess.WRITE)
	if f == null:
		var code: int = FileAccess.get_open_error()
		push_error("[DebugSwitcher] open csv failed: %d, path=%s" % [code, out_path])
		_print_debug_tip("QEF CSV export failed")
		return

	var header: Array[String] = [
		"index", "player_id", "display_name", "ties", "origin_tag", "mastery_tag", "tactic_tag",
		"weapon_type", "skill_q", "skill_e", "skill_f",
		"q_pass", "e_pass", "f_pass", "qef_combo_pass",
		"feel_score_1_5", "balance_score_1_5", "bug_found_0_1", "bug_note",
		"tester", "tested_at", "extra_note"
	]
	f.store_line(_to_csv_line(header))

	for i in range(character_ids.size()):
		var player_id: String = character_ids[i]
		var cfg: Dictionary = ConfigManager.get_player_config(player_id)
		var binds: Dictionary = ConfigManager.get_player_skill_bindings(player_id)

		var weapon_type: String = str(Global.selected_player_weapons.get(player_id, ""))
		if weapon_type.is_empty():
			var available: Array[String] = ConfigManager.get_player_available_weapon_types(player_id)
			if not available.is_empty():
				weapon_type = available[0]

		var row: Array[String] = [
			str(i + 1),
			player_id,
			str(cfg.get("display_name", "")),
			str(cfg.get("ties", "")),
			str(cfg.get("origin_tag", "")),
			str(cfg.get("mastery_tag", "")),
			str(cfg.get("tactic_tag", "")),
			weapon_type,
			str(binds.get("slot_q", "")),
			str(binds.get("slot_e", "")),
			str(binds.get("slot_f", "")),
			"", "", "", "",
			"", "", "", "",
			"", "", ""
		]
		f.store_line(_to_csv_line(row))

	f.flush()
	f.close()

	var global_path: String = ProjectSettings.globalize_path(out_path)
	print("[DebugSwitcher] QEF checklist exported: %s" % global_path)
	_print_debug_tip("QEF CSV EXPORTED")

func _to_csv_line(cells: Array[String]) -> String:
	var escaped: Array[String] = []
	for cell in cells:
		var text: String = str(cell)
		text = text.replace("\"", "\"\"")
		escaped.append("\"%s\"" % text)
	return ",".join(escaped)

func _is_toggle_key(key_event: InputEventKey) -> bool:
	return _match_key(key_event, TOGGLE_QEF_TEST_KEY, KEY_KP_8) or _has_digit_unicode(key_event, "8")

func _is_export_key(key_event: InputEventKey) -> bool:
	return _match_key(key_event, EXPORT_QEF_CHECKLIST_KEY, KEY_KP_9) or _has_digit_unicode(key_event, "9")

func _is_quick_record_key(key_event: InputEventKey) -> bool:
	return _match_key(key_event, QUICK_RECORD_KEY, KEY_KP_0) or _has_digit_unicode(key_event, "0")

func _try_handle_direct_score_key(key_event: InputEventKey) -> bool:
	if not qef_test_mode_enabled:
		return false
	if _match_letter_key(key_event, PRESET_PASS_KEY, "u"):
		_record_current_role_preset("PASS")
		return true
	if _match_letter_key(key_event, PRESET_FAIL_KEY, "i"):
		_record_current_role_preset("FAIL")
		return true
	if _match_letter_key(key_event, PRESET_BUG_KEY, "o"):
		_record_current_role_preset("BUG")
		return true
	if _match_letter_key(key_event, PRESET_MIX_KEY, "p"):
		_record_current_role_preset("MIX")
		return true
	if _match_letter_key(key_event, RATING_2_KEY, "j"):
		_record_current_role_direct_rating(2)
		return true
	if _match_letter_key(key_event, RATING_3_KEY, "k"):
		_record_current_role_direct_rating(3)
		return true
	if _match_letter_key(key_event, RATING_4_KEY, "l"):
		_record_current_role_direct_rating(4)
		return true
	if _match_letter_key(key_event, RATING_5_KEY, "m"):
		_record_current_role_direct_rating(5)
		return true
	return false

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

func _match_letter_key(key_event: InputEventKey, keycode: Key, letter: String) -> bool:
	return (
		key_event.keycode == keycode
		or key_event.physical_keycode == keycode
		or _has_letter_unicode(key_event, letter)
	)

func _has_letter_unicode(key_event: InputEventKey, letter: String) -> bool:
	if letter.length() != 1:
		return false
	var lower: String = letter.to_lower()
	var upper: String = letter.to_upper()
	return (
		key_event.unicode == lower.unicode_at(0)
		or key_event.unicode == upper.unicode_at(0)
	)

func _record_current_role_quick_score() -> void:
	_record_current_role_preset("PASS")

func _record_current_role_direct_rating(score: int) -> void:
	var clamped_score: int = int(clamp(score, 2, 5))
	_record_current_role_preset("SCORE_%d" % clamped_score)

func _record_current_role_preset(preset: String) -> void:
	var active_player_id: String = _get_active_player_id()
	if active_player_id.is_empty():
		_print_debug_tip("QEF QUICK LOG: no active player")
		return

	_ensure_weapon_for_player(active_player_id)

	var log_path: String = _ensure_quick_log_file_path()
	if log_path.is_empty():
		_print_debug_tip("QEF QUICK LOG failed")
		return

	var cfg: Dictionary = ConfigManager.get_player_config(active_player_id)
	var binds: Dictionary = ConfigManager.get_player_skill_bindings(active_player_id)
	var weapon_type: String = str(Global.selected_player_weapons.get(active_player_id, ""))
	if weapon_type.is_empty():
		var available: Array[String] = ConfigManager.get_player_available_weapon_types(active_player_id)
		if not available.is_empty():
			weapon_type = available[0]

	var q_pass: String = "1"
	var e_pass: String = "1"
	var f_pass: String = "1"
	var combo_pass: String = "1"
	var feel_score: String = "4"
	var balance_score: String = "4"
	var bug_found: String = "0"
	var bug_note: String = ""

	match preset:
		"FAIL":
			q_pass = "0"
			e_pass = "0"
			f_pass = "0"
			combo_pass = "0"
			feel_score = "2"
			balance_score = "2"
			bug_found = "1"
			bug_note = "manual_fail"
		"BUG":
			q_pass = "1"
			e_pass = "1"
			f_pass = "1"
			combo_pass = "0"
			feel_score = "3"
			balance_score = "2"
			bug_found = "1"
			bug_note = "needs_fix"
		"MIX":
			q_pass = "1"
			e_pass = "1"
			f_pass = "0"
			combo_pass = "0"
			feel_score = "3"
			balance_score = "3"
			bug_found = "1"
			bug_note = "f_issue"
		"SCORE_2":
			feel_score = "2"
			balance_score = "2"
			bug_note = "rate_2"
		"SCORE_3":
			feel_score = "3"
			balance_score = "3"
			bug_note = "rate_3"
		"SCORE_4":
			feel_score = "4"
			balance_score = "4"
			bug_note = "rate_4"
		"SCORE_5":
			feel_score = "5"
			balance_score = "5"
			bug_note = "rate_5"
		_:
			preset = "PASS"

	var dt: Dictionary = Time.get_datetime_dict_from_system()
	var tested_at: String = "%04d-%02d-%02d %02d:%02d:%02d" % [
		int(dt.get("year", 1970)),
		int(dt.get("month", 1)),
		int(dt.get("day", 1)),
		int(dt.get("hour", 0)),
		int(dt.get("minute", 0)),
		int(dt.get("second", 0))
	]

	var line_cells: Array[String] = [
		str(Time.get_ticks_msec()),
		tested_at,
		preset,
		active_player_id,
		str(cfg.get("display_name", "")),
		str(cfg.get("ties", "")),
		weapon_type,
		str(binds.get("slot_q", "")),
		str(binds.get("slot_e", "")),
		str(binds.get("slot_f", "")),
		q_pass,
		e_pass,
		f_pass,
		combo_pass,
		feel_score,
		balance_score,
		bug_found,
		bug_note,
		"",
		""
	]

	var file: FileAccess = FileAccess.open(log_path, FileAccess.READ_WRITE)
	if file == null:
		_print_debug_tip("QEF QUICK LOG open failed")
		return
	file.seek_end()
	file.store_line(_to_csv_line(line_cells))
	file.flush()
	file.close()

	var global_log_path: String = ProjectSettings.globalize_path(log_path)
	print("[DebugSwitcher] QEF quick log appended: %s" % global_log_path)
	_print_debug_tip("QEF QUICK LOG [%s] %s" % [preset, active_player_id])

func _ensure_quick_log_file_path() -> String:
	var out_dir: String = "user://qa_reports"
	var mk_err: int = DirAccess.make_dir_recursive_absolute(out_dir)
	if mk_err != OK:
		push_error("[DebugSwitcher] create qa_reports failed: %d" % mk_err)
		return ""

	var dt: Dictionary = Time.get_datetime_dict_from_system()
	var day_stamp: String = "%04d%02d%02d" % [
		int(dt.get("year", 1970)),
		int(dt.get("month", 1)),
		int(dt.get("day", 1))
	]
	var path: String = "%s/qef_quick_log_%s.csv" % [out_dir, day_stamp]
	if FileAccess.file_exists(path):
		return path

	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		var code: int = FileAccess.get_open_error()
		push_error("[DebugSwitcher] create quick log failed: %d, path=%s" % [code, path])
		return ""

	var header: Array[String] = [
		"log_id", "tested_at", "preset", "player_id", "display_name", "ties", "weapon_type",
		"skill_q", "skill_e", "skill_f",
		"q_pass", "e_pass", "f_pass", "qef_combo_pass",
		"feel_score_1_5", "balance_score_1_5", "bug_found_0_1", "bug_note",
		"tester", "extra_note"
	]
	file.store_line(_to_csv_line(header))
	file.flush()
	file.close()

	return path

func _get_active_player_id() -> String:
	if is_instance_valid(Global.player) and ("player_id" in Global.player):
		return str(Global.player.player_id)
	if Global.selected_player_ids.size() > 0:
		var idx: int = int(clamp(Global.current_player_index, 0, max(0, Global.selected_player_ids.size() - 1)))
		return str(Global.selected_player_ids[idx])
	return ""

func _apply_squad_snapshot(ids: Array[String], weapons: Dictionary, index: int) -> void:
	if ids.is_empty():
		return
	Global.selected_player_ids = ids.duplicate()
	Global.selected_player_weapons = weapons.duplicate(true)
	var size: int = Global.selected_player_ids.size()
	Global.current_player_index = int(clamp(index, 0, max(0, size - 1)))
	var restore_player_id: String = Global.selected_player_ids[Global.current_player_index]
	if not restore_player_id.is_empty():
		Global.emit_signal("on_player_switch_requested", restore_player_id)

func _write_squad_backup_to_disk() -> void:
	if _saved_selected_player_ids.is_empty():
		return
	var dir_err: int = DirAccess.make_dir_recursive_absolute("user://qa_reports")
	if dir_err != OK:
		push_error("[DebugSwitcher] backup mkdir failed: %d" % dir_err)
		return
	var file: FileAccess = FileAccess.open(SQUAD_BACKUP_FILE, FileAccess.WRITE)
	if file == null:
		push_error("[DebugSwitcher] backup open failed: %d" % FileAccess.get_open_error())
		return
	var payload: Dictionary = {
		"selected_player_ids": _saved_selected_player_ids,
		"selected_player_weapons": _saved_selected_player_weapons,
		"current_player_index": _saved_current_player_index
	}
	file.store_string(JSON.stringify(payload))
	file.flush()
	file.close()

func _delete_squad_backup_file() -> void:
	if not FileAccess.file_exists(SQUAD_BACKUP_FILE):
		return
	var abs_path: String = ProjectSettings.globalize_path(SQUAD_BACKUP_FILE)
	var err: int = DirAccess.remove_absolute(abs_path)
	if err != OK:
		push_warning("[DebugSwitcher] delete backup failed: %d, path=%s" % [err, abs_path])

func _try_restore_squad_from_backup_file() -> void:
	if not FileAccess.file_exists(SQUAD_BACKUP_FILE):
		return
	var file: FileAccess = FileAccess.open(SQUAD_BACKUP_FILE, FileAccess.READ)
	if file == null:
		return
	var text: String = file.get_as_text()
	file.close()
	var parsed = JSON.parse_string(text)
	if not (parsed is Dictionary):
		_delete_squad_backup_file()
		return
	var data: Dictionary = parsed
	var ids_data = data.get("selected_player_ids", [])
	if not (ids_data is Array):
		_delete_squad_backup_file()
		return
	var ids: Array[String] = []
	for id_val in ids_data:
		var id_text: String = str(id_val).strip_edges()
		if not id_text.is_empty():
			ids.append(id_text)
	if ids.size() < 2:
		_delete_squad_backup_file()
		return
	var weapons: Dictionary = data.get("selected_player_weapons", {})
	if not (weapons is Dictionary):
		weapons = {}
	var idx: int = int(data.get("current_player_index", 0))
	_apply_squad_snapshot(ids, weapons, idx)
	_saved_selected_player_ids = ids.duplicate()
	_saved_selected_player_weapons = weapons.duplicate(true)
	_saved_current_player_index = idx
	_delete_squad_backup_file()
	_print_debug_tip("QEF TEST AUTO-RESTORE SQUAD")
