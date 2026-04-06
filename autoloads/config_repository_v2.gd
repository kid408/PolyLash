extends Node

signal configs_reloaded

const CONFIG_DIR: String = "res://config/player/"
const PLAYER_CONFIG_PATH: String = CONFIG_DIR + "player_config.csv"
const PLAYER_RUNTIME_BINDINGS_PATH: String = CONFIG_DIR + "player_runtime_bindings.csv"
const SPACE_SKILL_CONFIG_PATH: String = CONFIG_DIR + "space_skill_config.csv"
const SKILL_E_CONFIG_PATH: String = CONFIG_DIR + "skill_e_config.csv"
const SKILL_F_CONFIG_PATH: String = CONFIG_DIR + "skill_f_config.csv"
const ASSIST_CONFIG_PATH: String = CONFIG_DIR + "assist_config.csv"

var player_configs: Dictionary = {}
var runtime_bindings: Dictionary = {}
var space_skill_configs: Dictionary = {}
var skill_e_configs: Dictionary = {}
var skill_f_configs: Dictionary = {}
var assist_configs: Dictionary = {}

func _ready() -> void:
	reload_all()

func reload_all() -> void:
	player_configs = _load_csv_as_dict(PLAYER_CONFIG_PATH, "player_id")
	runtime_bindings = _load_csv_as_dict(PLAYER_RUNTIME_BINDINGS_PATH, "player_id")
	space_skill_configs = _load_csv_as_dict(SPACE_SKILL_CONFIG_PATH, "space_skill_id")
	skill_e_configs = _load_csv_as_dict(SKILL_E_CONFIG_PATH, "e_skill_id")
	skill_f_configs = _load_csv_as_dict(SKILL_F_CONFIG_PATH, "f_skill_id")
	assist_configs = _load_csv_as_dict(ASSIST_CONFIG_PATH, "assist_id")
	print("[RoleConfigRepository] Loaded role tables: players=%d bindings=%d space=%d e=%d f=%d assist=%d" % [
		player_configs.size(),
		runtime_bindings.size(),
		space_skill_configs.size(),
		skill_e_configs.size(),
		skill_f_configs.size(),
		assist_configs.size()
	])
	configs_reloaded.emit()

func has_player(player_id: String) -> bool:
	return player_configs.has(player_id)

func get_player_config(player_id: String) -> Dictionary:
	return player_configs.get(player_id, {}).duplicate(true)

func get_runtime_binding(player_id: String) -> Dictionary:
	return runtime_bindings.get(player_id, {}).duplicate(true)

func get_space_skill_config(space_skill_id: String) -> Dictionary:
	return space_skill_configs.get(space_skill_id, {}).duplicate(true)

func get_e_skill_config(e_skill_id: String) -> Dictionary:
	return skill_e_configs.get(e_skill_id, {}).duplicate(true)

func get_f_skill_config(f_skill_id: String) -> Dictionary:
	return skill_f_configs.get(f_skill_id, {}).duplicate(true)

func get_assist_config(assist_id: String) -> Dictionary:
	return assist_configs.get(assist_id, {}).duplicate(true)

func get_all_player_ids() -> Array[String]:
	var ids: Array[String] = []
	for key_variant: Variant in player_configs.keys():
		ids.append(str(key_variant))
	return ids

func _load_csv_as_dict(path: String, key_column: String) -> Dictionary:
	var rows: Array[Dictionary] = _load_csv_rows(path)
	var result: Dictionary = {}
	for row: Dictionary in rows:
		var key_value: String = str(row.get(key_column, "")).strip_edges()
		if key_value.is_empty():
			continue
		result[key_value] = row
	return result

func _load_csv_rows(path: String) -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	if not FileAccess.file_exists(path):
		push_warning("[RoleConfigRepository] Missing CSV: %s" % path)
		return rows

	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_warning("[RoleConfigRepository] Failed to open CSV: %s" % path)
		return rows

	var headers: PackedStringArray = PackedStringArray()
	var line_number: int = 0

	while not file.eof_reached():
		var line: PackedStringArray = file.get_csv_line()
		line_number += 1
		if line.is_empty():
			continue
		if line.size() == 1 and line[0].strip_edges().is_empty():
			continue
		if line[0].strip_edges() == "-1":
			continue
		if line[0].begins_with("#"):
			continue

		if headers.is_empty():
			headers = line
			continue

		var row: Dictionary = {}
		var max_columns: int = headers.size()
		for column_index: int in range(max_columns):
			var header_name: String = headers[column_index].strip_edges()
			if header_name.is_empty():
				continue
			var raw_value: String = ""
			if column_index < line.size():
				raw_value = line[column_index].strip_edges()
			row[header_name] = _coerce_value(raw_value)
		rows.append(row)

	file.close()
	return rows

func _coerce_value(raw_value: String) -> Variant:
	var trimmed_value: String = raw_value.strip_edges()
	if trimmed_value.is_empty():
		return ""

	var lowered_value: String = trimmed_value.to_lower()
	if lowered_value == "true":
		return true
	if lowered_value == "false":
		return false
	if trimmed_value.is_valid_int():
		return int(trimmed_value)
	if trimmed_value.is_valid_float():
		return float(trimmed_value)
	return trimmed_value
