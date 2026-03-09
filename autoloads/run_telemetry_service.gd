extends Node

# 局内羁绊/共鸣采样服务
# 产物：
# - user://bond_balance_active_run.json
# - user://bond_balance_runs.jsonl

const ACTIVE_RUN_PATH: String = "user://bond_balance_active_run.json"
const RUNS_JSONL_PATH: String = "user://bond_balance_runs.jsonl"

var _is_run_active: bool = false
var _run_started_msec: int = 0
var _run_data: Dictionary = {}

func _ready() -> void:
	call_deferred("_connect_event_signals")
	_try_resume_active_run()

func _connect_event_signals() -> void:
	if BondManager and BondManager.has_signal("bond_level_changed"):
		var callable_ref: Callable = Callable(self, "_on_bond_level_changed")
		if not BondManager.bond_level_changed.is_connected(callable_ref):
			BondManager.bond_level_changed.connect(callable_ref)

func begin_run(team_player_ids: Array, team_weapons: Dictionary = {}) -> void:
	if _is_run_active:
		# 已在追踪中，补齐队伍信息并刷新落盘
		if str(_run_data.get("team_comp", "")).is_empty():
			_run_data["team_comp"] = _format_team_comp(team_player_ids, team_weapons)
		_save_active_run()
		return

	_run_data = {
		"run_id": _build_run_id(),
		"date": Time.get_date_string_from_system(),
		"team_comp": _format_team_comp(team_player_ids, team_weapons),
		"team_players": team_player_ids.duplicate(),
		"team_weapons": team_weapons.duplicate(true),
		"duration_sec": 0.0,
		"duration_min": 0.0,
		"highest_wave": 0,
		"cleared": false,
		"end_reason": "",
		"lv2plus_triggers": 0,
		"lv3_triggers": 0,
		"resonance_trigger_count": 0,
		"resonance_players": {},
		"resonance_players_verified": [],
		"created_at_unix": Time.get_unix_time_from_system(),
		"started_at_text": Time.get_datetime_string_from_system(),
		"ended_at_text": ""
	}
	_is_run_active = true
	_run_started_msec = Time.get_ticks_msec()
	_save_active_run()
	print("[RunTelemetryService] 开始采样 run_id=%s team=%s" % [str(_run_data.get("run_id", "")), str(_run_data.get("team_comp", ""))])

func record_wave_completed(wave_number: int) -> void:
	if not _is_run_active:
		return
	var old_wave: int = int(_run_data.get("highest_wave", 0))
	if wave_number > old_wave:
		_run_data["highest_wave"] = wave_number
		_save_active_run()

func record_resonance_trigger(player_id: String, resonance_id: String, source: String) -> void:
	if not _is_run_active:
		return
	if player_id.is_empty() or resonance_id.is_empty():
		return

	var players: Dictionary = _run_data.get("resonance_players", {})
	if not (players is Dictionary):
		players = {}
	var old_count: int = int(players.get(player_id, 0))
	players[player_id] = old_count + 1
	_run_data["resonance_players"] = players
	_run_data["resonance_trigger_count"] = int(_run_data.get("resonance_trigger_count", 0)) + 1
	_save_active_run()
	print("[RunTelemetryService] 共鸣触发: player=%s resonance=%s source=%s" % [player_id, resonance_id, source])

func end_run(cleared: bool, reason: String = "") -> void:
	if not _is_run_active:
		return

	var now_msec: int = Time.get_ticks_msec()
	var elapsed_sec: float = float(max(0, now_msec - _run_started_msec)) / 1000.0
	var prev_sec: float = float(_run_data.get("duration_sec", 0.0))
	var total_sec: float = max(0.0, prev_sec + elapsed_sec)
	_run_data["duration_sec"] = total_sec
	_run_data["duration_min"] = round(total_sec / 60.0 * 100.0) / 100.0
	_run_data["cleared"] = bool(cleared)
	_run_data["end_reason"] = reason
	_run_data["ended_at_text"] = Time.get_datetime_string_from_system()

	var players: Dictionary = _run_data.get("resonance_players", {})
	if not (players is Dictionary):
		players = {}
	var verified_players: Array[String] = []
	for key in players.keys():
		var pid: String = str(key).strip_edges()
		if pid.is_empty():
			continue
		if int(players.get(pid, 0)) <= 0:
			continue
		verified_players.append(pid)
	verified_players.sort()
	_run_data["resonance_players_verified"] = verified_players

	_append_run_record(_run_data)
	print("[RunTelemetryService] 结束采样 run_id=%s cleared=%s reason=%s lv2plus=%d lv3=%d resonance_players=%d" % [
		str(_run_data.get("run_id", "")),
		str(_run_data.get("cleared", false)),
		reason,
		int(_run_data.get("lv2plus_triggers", 0)),
		int(_run_data.get("lv3_triggers", 0)),
		verified_players.size()
	])

	_is_run_active = false
	_run_started_msec = 0
	_run_data.clear()
	_remove_user_file(ACTIVE_RUN_PATH)

func _on_bond_level_changed(_bond_id: String, old_level: int, new_level: int) -> void:
	if not _is_run_active:
		return
	# 只统计升级触发，避免重算导致的重复记数
	if new_level <= old_level:
		return
	if new_level >= 2:
		_run_data["lv2plus_triggers"] = int(_run_data.get("lv2plus_triggers", 0)) + 1
	if new_level >= 3:
		_run_data["lv3_triggers"] = int(_run_data.get("lv3_triggers", 0)) + 1
	_save_active_run()

func _build_run_id() -> String:
	var unix_text: String = str(int(Time.get_unix_time_from_system()))
	var tick_text: String = str(Time.get_ticks_msec())
	return "run_%s_%s" % [unix_text, tick_text]

func _format_team_comp(team_player_ids: Array, team_weapons: Dictionary) -> String:
	var parts: Array[String] = []
	for value in team_player_ids:
		var pid: String = str(value).strip_edges()
		if pid.is_empty():
			continue
		var weapon: String = str(team_weapons.get(pid, "")).strip_edges()
		if weapon.is_empty():
			parts.append(pid)
		else:
			parts.append("%s(%s)" % [pid, weapon])
	return ",".join(parts)

func _try_resume_active_run() -> void:
	if not FileAccess.file_exists(ACTIVE_RUN_PATH):
		return
	var file: FileAccess = FileAccess.open(ACTIVE_RUN_PATH, FileAccess.READ)
	if not file:
		return
	var text: String = file.get_as_text()
	file.close()
	if text.strip_edges().is_empty():
		return
	var parsed: Variant = JSON.parse_string(text)
	if not (parsed is Dictionary):
		return
	_run_data = parsed
	_is_run_active = true
	_run_started_msec = Time.get_ticks_msec()
	print("[RunTelemetryService] 恢复采样 run_id=%s" % str(_run_data.get("run_id", "")))

func _save_active_run() -> void:
	if not _is_run_active:
		return
	var payload: String = JSON.stringify(_run_data)
	var file: FileAccess = FileAccess.open(ACTIVE_RUN_PATH, FileAccess.WRITE)
	if not file:
		return
	file.store_string(payload)
	file.close()

func _append_run_record(data: Dictionary) -> void:
	var payload: String = JSON.stringify(data)
	var file: FileAccess = FileAccess.open(RUNS_JSONL_PATH, FileAccess.READ_WRITE)
	if not file:
		file = FileAccess.open(RUNS_JSONL_PATH, FileAccess.WRITE)
	if not file:
		return
	file.seek_end()
	file.store_line(payload)
	file.close()

func _remove_user_file(path: String) -> void:
	if not FileAccess.file_exists(path):
		return
	var dir: DirAccess = DirAccess.open("user://")
	if not dir:
		return
	var file_name: String = path.get_file()
	var err: int = dir.remove(file_name)
	if err != OK:
		push_warning("[RunTelemetryService] 删除文件失败: %s err=%d" % [path, err])
