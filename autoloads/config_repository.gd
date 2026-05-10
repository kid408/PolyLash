extends RefCounted
class_name ConfigRepository

# ============================================================================
# 配置仓库（P0-ARC-01）
# 统一业务层配置读取入口，并提供基础 Schema 校验。
# 覆盖：Bond / Shop / Wave / Ult
# ============================================================================

const BOND_CONFIG_PATH := "res://config/player/bond_config.csv"
const BOND_RESONANCE_CONFIG_PATH := "res://config/player/bond_resonance_config.csv"
const SHOP_ITEM_CONFIG_PATH := "res://config/item/shop_item_config.csv"
const SHOP_ATTRIBUTE_CONFIG_PATH := "res://config/wave/shop_attribute_config.csv"
const SHOP_WAVE_CONFIG_PATH := "res://config/wave/shop_wave_config.csv"
const ULT_CONFIG_PATH := "res://config/player/ult_config.csv"
const ENEMY_CONFIG_PATH := "res://config/enemy/enemy_config.csv"
const BOSS_PHASE_CONFIG_PATH := "res://config/enemy/boss_phase_config.csv"
const WAVE_CONFIG_PATH := "res://config/wave/wave_config.csv"
const WAVE_UNITS_CONFIG_PATH := "res://config/wave/wave_units_config.csv"
const ELITE_POOL_CONFIG_PATH := "res://config/wave/elite_pool_config.csv"
const BOSS_POOL_CONFIG_PATH := "res://config/wave/boss_pool_config.csv"
const LEGACY_PLAYER_ID_ALIASES := {
	"new_ignis": "frostbite",
	"new_totem": "plague",
	"new_tempest": "snareweaver",
	"tempest": "snareweaver",
	"train": "polaris",
	"goo": "chronomancer",
	"herder": "shaman",
	"hunter": "botanist",
	"ammo": "medium",
	"turret_eng": "shadow",
	"vacuum": "beastmaster",
	"tesla": "flashblade",
	"voodoo": "leviathan",
	"gambler": "demolitionist",
	"merchant": "pathfinder",
	"midas": "necromancer",
	"vampire": "astrologer"
}

static func load_bond_configs() -> Dictionary:
	var bond_configs: Dictionary = {}
	var file := _open_csv_file(_resolve_bond_config_path())
	if file == null:
		return bond_configs

	_skip_csv_header_and_comment(file)
	var line_no: int = 2

	while not file.eof_reached():
		line_no += 1
		var line := file.get_csv_line()
		if not _is_data_row(line):
			continue
		if not _validate_bond_row(line):
			push_warning("[ConfigRepository] Bond 配置行非法，已跳过: line=%d, data=%s" % [line_no, str(line)])
			continue

		var bond_id = line[0].strip_edges()
		if not bond_configs.has(bond_id):
			bond_configs[bond_id] = {
				"bond_type": line[1].strip_edges(),
				"display_name": line[8].strip_edges(),
				"icon_path_index": _to_int(line[7]),
				"levels": []
			}

		bond_configs[bond_id].levels.append({
			"level": _to_int(line[2]),
			"required_count": _to_int(line[3]),
			"effect_type": line[4].strip_edges(),
			"effect_param": line[5].strip_edges(),
			"effect_value": _to_float(line[6]),
			"description": line[9].strip_edges()
		})

	file.close()

	for bond_id in bond_configs.keys():
		bond_configs[bond_id].levels.sort_custom(func(a, b): return a.level < b.level)

	return bond_configs

static func _resolve_bond_config_path() -> String:
	return BOND_CONFIG_PATH

static func load_shop_item_configs() -> Dictionary:
	var item_configs: Dictionary = {}
	var file := _open_csv_file(SHOP_ITEM_CONFIG_PATH)
	if file == null:
		return item_configs

	_skip_csv_header_and_comment(file)
	var line_no: int = 2

	while not file.eof_reached():
		line_no += 1
		var line := file.get_csv_line()
		if not _is_data_row(line):
			continue
		if not _validate_shop_item_row(line):
			push_warning("[ConfigRepository] ShopItem 配置行非法，已跳过: line=%d, data=%s" % [line_no, str(line)])
			continue

		var item_id = line[0].strip_edges()
		var item_name = line[1].strip_edges()
		var item_type = line[2].strip_edges()
		var item_tier = _to_int(line[3])
		var effect_type = line[4].strip_edges()
		var effect_target = line[5].strip_edges()
		var target_tags_str = line[6].strip_edges()
		var effect_value = _to_float(line[7])
		var icon_path = line[8].strip_edges()
		var description = line[9].strip_edges()
		var price = _to_int(line[10])
		var shop_weight = _to_int(line[11])
		var is_trade_off = _to_int(line[12]) == 1

		var target_tags: Array = target_tags_str.split(",") if target_tags_str != "" else []

		if not item_configs.has(item_id):
			item_configs[item_id] = {
				"item_id": item_id,
				"item_name": item_name,
				"item_type": item_type,
				"item_tier": item_tier,
				"icon_path": icon_path,
				"price": price,
				"shop_weight": shop_weight,
				"effects": []
			}

		item_configs[item_id].effects.append({
			"effect_type": effect_type,
			"effect_target": effect_target,
			"target_tags": target_tags,
			"effect_value": effect_value,
			"description": description,
			"is_trade_off": is_trade_off
		})

	file.close()
	return item_configs

static func load_bond_resonance_configs() -> Array:
	var rows: Array = []
	var file := _open_csv_file(BOND_RESONANCE_CONFIG_PATH)
	if file == null:
		return rows

	_skip_csv_header_and_comment(file)
	while not file.eof_reached():
		var line := file.get_csv_line()
		if not _is_data_row(line):
			continue
		if line.size() < 7:
			continue
		rows.append({
			"player_id": line[0].strip_edges(),
			"trigger_bond": line[1].strip_edges(),
			"trigger_level": _to_int(line[2], 3),
			"resonance_id": line[3].strip_edges(),
			"params_json": line[4].strip_edges(),
			"icd": _to_float(line[5], 8.0),
			"duration": _to_float(line[6], 4.0)
		})

	file.close()
	return rows

static func load_shop_attribute_configs() -> Dictionary:
	var attribute_configs: Dictionary = {}
	var file := _open_csv_file(SHOP_ATTRIBUTE_CONFIG_PATH)
	if file == null:
		return attribute_configs

	_skip_csv_header_and_comment(file)
	var line_no: int = 2

	while not file.eof_reached():
		line_no += 1
		var line := file.get_csv_line()
		if not _is_data_row(line):
			continue
		if not _validate_shop_attribute_row(line):
			push_warning("[ConfigRepository] ShopAttribute 配置行非法，已跳过: line=%d, data=%s" % [line_no, str(line)])
			continue

		var attr_id = line[0].strip_edges()
		var target_tags: Array = line[4].split(",") if line[4] != "" else []
		attribute_configs[attr_id] = {
			"attribute_id": attr_id,
			"display_name": line[1].strip_edges(),
			"attribute_type": line[2].strip_edges(),
			"effect_target": line[3].strip_edges(),
			"target_tags": target_tags,
			"base_value": _to_float(line[5]),
			"value_type": line[6].strip_edges(),
			"base_price": _to_int(line[7]),
			"price_scaling": _to_float(line[8]),
			"shop_weight": _to_int(line[9]),
			"min_wave": _to_int(line[10]),
			"max_wave": _to_int(line[11]),
			"is_positive": _to_int(line[12]) == 1
		}

	file.close()
	return attribute_configs

static func load_shop_wave_configs() -> Array:
	var wave_configs: Array = []
	var file := _open_csv_file(SHOP_WAVE_CONFIG_PATH)
	if file == null:
		return wave_configs

	_skip_csv_header_and_comment(file)
	var line_no: int = 2

	while not file.eof_reached():
		line_no += 1
		var line := file.get_csv_line()
		if not _is_data_row(line):
			continue
		if not _validate_shop_wave_row(line):
			push_warning("[ConfigRepository] ShopWave 配置行非法，已跳过: line=%d, data=%s" % [line_no, str(line)])
			continue

		wave_configs.append({
			"wave_range_start": _to_int(line[0]),
			"wave_range_end": _to_int(line[1]),
			"item_count": _to_int(line[2]),
			"reroll_cost": _to_int(line[3]),
			"positive_weight": _to_int(line[4]),
			"negative_weight": _to_int(line[5]),
			"allow_duplicates": _to_int(line[6]) == 1,
			"price_multiplier": _to_float(line[7]),
		})

	file.close()
	return wave_configs

static func load_enemy_v2_configs() -> Dictionary:
	var configs: Dictionary = {}
	var rows: Array[Dictionary] = _load_csv_rows_with_headers(ENEMY_CONFIG_PATH)
	if rows.is_empty():
		return configs

	for row: Dictionary in rows:
		var enemy_id := str(row.get("enemy_id", "")).strip_edges()
		if enemy_id.is_empty():
			continue

		configs[enemy_id] = {
			"enemy_id": enemy_id,
			"role": str(row.get("role", "")).strip_edges().to_lower(),
			"cost": _to_float(row.get("cost", 1.0), 1.0),
			"hp": _to_float(row.get("health", 0.0), 0.0),
			"speed": _to_float(row.get("speed", 0.0), 0.0),
			"damage": _to_float(row.get("damage", 0.0), 0.0),
			"behavior_params": str(row.get("behavior_params", "")).strip_edges()
		}
	return configs

static func load_boss_phase_configs() -> Dictionary:
	var grouped: Dictionary = {}
	var file := _open_csv_file(BOSS_PHASE_CONFIG_PATH)
	if file == null:
		return grouped

	_skip_csv_header_and_comment(file)
	while not file.eof_reached():
		var line := file.get_csv_line()
		if not _is_data_row(line):
			continue
		if line.size() < 8:
			continue

		var enemy_id := line[0].strip_edges()
		if enemy_id.is_empty():
			continue

		if not grouped.has(enemy_id):
			grouped[enemy_id] = []

		grouped[enemy_id].append({
			"enemy_id": enemy_id,
			"phase": _to_int(line[1], 1),
			"trigger_hp_ratio": _to_float(line[2], 1.0),
			"speed_multiplier": _to_float(line[3], 1.0),
			"damage_multiplier": _to_float(line[4], 1.0),
			"spawn_budget_multiplier": _to_float(line[5], 1.0),
			"event_tag": line[6].strip_edges(),
			"description": line[7].strip_edges()
		})

	file.close()

	for enemy_id in grouped.keys():
		grouped[enemy_id].sort_custom(func(a, b): return int(a.get("phase", 1)) < int(b.get("phase", 1)))

	return grouped

static func load_wave_v2_configs() -> Dictionary:
	var configs: Dictionary = {}
	var rows: Array[Dictionary] = _load_csv_rows_with_headers(WAVE_CONFIG_PATH)
	if rows.is_empty():
		return configs

	for row: Dictionary in rows:
		var wave_id := str(row.get("wave_id", "")).strip_edges()
		if wave_id.is_empty():
			continue
		if wave_id.find("wave_") != 0:
			continue

		configs[wave_id] = {
			"wave_id": wave_id,
			"from_wave": _to_int(row.get("from_wave", 1), 1),
			"to_wave": _to_int(row.get("to_wave", 1), 1),
			"wave_time": _to_float(row.get("wave_time", 100.0), 100.0),
			"spawn_type": str(row.get("spawn_type", "")).strip_edges(),
			"fixed_spawn_time": _to_float(row.get("fixed_spawn_time", 2.0), 2.0),
			"spawn_interval_min": _to_float(row.get("min_spawn_time", 1.5), 1.5),
			"spawn_interval_max": _to_float(row.get("max_spawn_time", 2.5), 2.5),
			"budget_multiplier": _to_float(row.get("budget_multiplier", 1.0), 1.0),
			"peak_event": str(row.get("peak_event", "")).strip_edges(),
			"elite_slot_count": _to_int(row.get("elite_slot_count", 0), 0),
		}
	return configs

static func load_elite_pool_configs() -> Array[Dictionary]:
	var configs: Array[Dictionary] = []
	var rows: Array[Dictionary] = _load_csv_rows_with_headers(ELITE_POOL_CONFIG_PATH)
	if rows.is_empty():
		return configs

	for row: Dictionary in rows:
		var elite_id: String = str(row.get("elite_id", "")).strip_edges()
		if elite_id.is_empty():
			continue
		configs.append({
			"elite_id": elite_id,
			"min_wave": _to_int(row.get("min_wave", 1), 1),
			"base_weight": _to_float(row.get("base_weight", 1.0), 1.0),
			"is_unique": str(row.get("is_unique", "FALSE")).strip_edges().to_lower() == "true",
			"difficulty_score": _to_float(row.get("difficulty_score", 1.0), 1.0),
			"enabled": str(row.get("enabled", "TRUE")).strip_edges().to_lower() == "true",
		})
	return configs

static func load_boss_pool_configs() -> Array[Dictionary]:
	var configs: Array[Dictionary] = []
	var rows: Array[Dictionary] = _load_csv_rows_with_headers(BOSS_POOL_CONFIG_PATH)
	if rows.is_empty():
		return configs

	for row: Dictionary in rows:
		var boss_id: String = str(row.get("boss_id", "")).strip_edges()
		if boss_id.is_empty():
			continue
		configs.append({
			"boss_id": boss_id,
			"tier": _to_int(row.get("tier", 1), 1),
			"min_wave": _to_int(row.get("min_wave", 1), 1),
			"base_weight": _to_float(row.get("base_weight", 1.0), 1.0),
			"description": str(row.get("description", "")).strip_edges(),
		})
	return configs

static func load_wave_units_v2_grouped() -> Dictionary:
	var grouped: Dictionary = {}
	var rows: Array[Dictionary] = _load_csv_rows_with_headers(WAVE_UNITS_CONFIG_PATH)
	if rows.is_empty():
		return grouped

	for row: Dictionary in rows:
		var wave_id := str(row.get("wave_id", "")).strip_edges()
		if wave_id.is_empty():
			continue

		if not grouped.has(wave_id):
			grouped[wave_id] = []

		grouped[wave_id].append({
			"wave_id": wave_id,
			"enemy_scene": str(row.get("enemy_scene", "")).strip_edges(),
			"enemy_id": str(row.get("enemy_id", "")).strip_edges(),
			"weight": _to_float(row.get("weight", 1.0), 1.0)
		})
	return grouped

static func load_ult_configs() -> Dictionary:
	var ult_configs: Dictionary = {}
	var file := _open_csv_file(ULT_CONFIG_PATH)
	if file == null:
		return ult_configs

	_skip_csv_header_and_comment(file)
	var line_no: int = 2

	while not file.eof_reached():
		line_no += 1
		var line := file.get_csv_line()
		if not _is_data_row(line):
			continue
		if not _validate_ult_row(line):
			push_warning("[ConfigRepository] Ult 配置行非法，已跳过: line=%d, data=%s" % [line_no, str(line)])
			continue

		var ult_id = line[0].strip_edges()
		ult_configs[ult_id] = {
			"ult_id": ult_id,
			"name": line[1].strip_edges(),
			"duration": _to_float(line[2]),
			"energy_cost": _to_float(line[3]),
			"bonus_bond_tag": line[4].strip_edges(),
			"visual_color_hex": line[5].strip_edges(),
			"scale_multiplier": _to_float(line[6]),
			"explosion_radius": _to_float(line[7]),
			"explosion_damage_scale": _to_float(line[8]),
			"description": line[9].strip_edges(),
			"f_role_id": _csv_get(line, 10, ""),
			"f_internal_cd": _to_float(_csv_get(line, 11, "1.0"), 1.0),
			"f_q_line_amp": _to_float(_csv_get(line, 12, "1.0"), 1.0),
			"f_q_closure_amp": _to_float(_csv_get(line, 13, "1.0"), 1.0),
			"f_special_value_1": _to_float(_csv_get(line, 14, "0.0"), 0.0),
			"f_special_value_2": _to_float(_csv_get(line, 15, "0.0"), 0.0),
			"f_special_value_3": _to_float(_csv_get(line, 16, "0.0"), 0.0),
			"f_bond_o_payload": _csv_get(line, 17, ""),
			"f_bond_m_payload": _csv_get(line, 18, ""),
			"f_bond_t_payload": _csv_get(line, 19, ""),
		}

	file.close()
	return ult_configs

static func get_ult_config_for_player(player_id: String) -> Dictionary:
	var normalized_player_id := _normalize_player_id(player_id)
	var ult_id = normalized_player_id + "_ult"
	var ult_configs = load_ult_configs()
	return ult_configs.get(ult_id, {})

static func _normalize_player_id(player_id: String) -> String:
	if player_id.is_empty():
		return player_id
	return str(LEGACY_PLAYER_ID_ALIASES.get(player_id, player_id))

static func _open_csv_file(path: String) -> FileAccess:
	if not FileAccess.file_exists(path):
		printerr("[ConfigRepository] 配置文件不存在: %s" % path)
		return null
	var file = FileAccess.open(path, FileAccess.READ)
	if file == null:
		printerr("[ConfigRepository] 无法打开配置文件: %s" % path)
	return file

static func _load_csv_rows_with_headers(path: String) -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	var file := _open_csv_file(path)
	if file == null:
		return rows

	var headers: PackedStringArray = PackedStringArray()
	while not file.eof_reached():
		var line := file.get_csv_line()
		if line.is_empty():
			continue
		var first: String = line[0].strip_edges()
		if first.is_empty():
			continue
		if headers.is_empty():
			headers = line
			continue
		if first == "-1":
			continue
		var row: Dictionary = {}
		for i: int in range(headers.size()):
			var header_name: String = headers[i].strip_edges()
			if header_name.is_empty():
				continue
			row[header_name] = _csv_get(line, i, "")
		rows.append(row)

	file.close()
	return rows

static func _skip_csv_header_and_comment(file: FileAccess) -> void:
	if file == null:
		return
	if not file.eof_reached():
		file.get_csv_line()
	if not file.eof_reached():
		var pos = file.get_position()
		var second = file.get_csv_line()
		if second.size() == 0 or second[0].strip_edges() != "-1":
			file.seek(pos)

static func _is_data_row(line: PackedStringArray) -> bool:
	if line.size() == 0:
		return false
	var first = line[0].strip_edges()
	return first != "" and first != "-1"

static func _validate_bond_row(line: PackedStringArray) -> bool:
	if line.size() < 10:
		return false
	return line[0].strip_edges() != "" \
		and line[1].strip_edges() != "" \
		and line[2].strip_edges().is_valid_int() \
		and line[3].strip_edges().is_valid_int() \
		and line[6].strip_edges().is_valid_float()

static func _validate_shop_item_row(line: PackedStringArray) -> bool:
	if line.size() < 13:
		return false
	return line[0].strip_edges() != "" \
		and line[10].strip_edges().is_valid_int() \
		and line[11].strip_edges().is_valid_int() \
		and line[12].strip_edges().is_valid_int() \
		and line[3].strip_edges().is_valid_int() \
		and line[7].strip_edges().is_valid_float()

static func _validate_shop_attribute_row(line: PackedStringArray) -> bool:
	if line.size() < 13:
		return false
	return line[0].strip_edges() != "" \
		and line[5].strip_edges().is_valid_float() \
		and line[7].strip_edges().is_valid_int() \
		and line[8].strip_edges().is_valid_float() \
		and line[9].strip_edges().is_valid_int() \
		and line[10].strip_edges().is_valid_int() \
		and line[11].strip_edges().is_valid_int() \
		and line[12].strip_edges().is_valid_int()

static func _validate_shop_wave_row(line: PackedStringArray) -> bool:
	if line.size() < 8:
		return false
	return line[0].strip_edges().is_valid_int() \
		and line[1].strip_edges().is_valid_int() \
		and line[2].strip_edges().is_valid_int() \
		and line[3].strip_edges().is_valid_int() \
		and line[4].strip_edges().is_valid_int() \
		and line[5].strip_edges().is_valid_int() \
		and line[6].strip_edges().is_valid_int() \
		and line[7].strip_edges().is_valid_float()

static func _validate_ult_row(line: PackedStringArray) -> bool:
	if line.size() < 10:
		return false
	return line[0].strip_edges() != "" \
		and line[2].strip_edges().is_valid_float() \
		and line[3].strip_edges().is_valid_float() \
		and line[6].strip_edges().is_valid_float() \
		and line[7].strip_edges().is_valid_float() \
		and line[8].strip_edges().is_valid_float()

static func _to_int(value: Variant, default_value: int = 0) -> int:
	var text = str(value).strip_edges()
	if text.is_valid_int():
		return int(text)
	if text.is_valid_float():
		return int(float(text))
	return default_value

static func _to_float(value: Variant, default_value: float = 0.0) -> float:
	var text = str(value).strip_edges()
	if text.is_valid_float():
		return float(text)
	if text.is_valid_int():
		return float(int(text))
	return default_value

static func _csv_get(line: PackedStringArray, index: int, default_value: String = "") -> String:
	if index < 0 or index >= line.size():
		return default_value
	return line[index].strip_edges()
