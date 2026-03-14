extends Node

const DEBUG_VERBOSE := false

# ============================================================================
# 鏁版嵁绠＄悊鍣?- 璐熻矗鍙岃揣甯佸拰鍗囩骇鏁版嵁鐨勬寔涔呭寲
# ============================================================================

# 淇″彿
signal gold_changed(new_gold: int)  # 鍏煎鏃ч摼璺細绛夊悓 run_gold_changed
signal run_gold_changed(new_gold: int)  # 局内金币变化
signal soul_shard_changed(new_shard: int)  # 局外碎片变化
const SAVE_PATH = "user://player_save.json"
const SESSION_SAVE_PATH = "user://session_data.json"

# 淇濆瓨鏁版嵁缁撴瀯
var save_data: Dictionary = {
	"run_gold": 0,
	"soul_shard": 0,
	"upgrades": {}  # { "player_id": { "hp_level": 0, "max_energy_level": 0, ... } }
}

# 鍗囩骇閰嶇疆缂撳瓨
var upgrade_configs: Array[Dictionary] = []
var max_upgrade_level: int = 5

# ============================================================================
# 鍒濆鍖?
# ============================================================================

func _ready() -> void:
	_load_upgrade_configs()
	_load_save_data()
	# 妫€鏌ュ眬鍐呬細璇濆瓨妗ｅ苟鎭㈠
	if has_session_data():
		load_session_data()
	if DEBUG_VERBOSE: print("[DataManager] 鍒濆鍖栧畬鎴愶紝run_gold=%d, soul_shard=%d" % [get_run_gold(), get_soul_shard()])

# ============================================================================
# 閰嶇疆鍔犺浇
# ============================================================================

func _load_upgrade_configs() -> void:
	upgrade_configs.clear()
	
	var file_path = "res://config/player/attribute_upgrade.csv"
	if not FileAccess.file_exists(file_path):
		printerr("[DataManager] 鍗囩骇閰嶇疆鏂囦欢涓嶅瓨鍦? %s" % file_path)
		return
	
	var file = FileAccess.open(file_path, FileAccess.READ)
	if not file:
		printerr("[DataManager] 鏃犳硶鎵撳紑鍗囩骇閰嶇疆鏂囦欢")
		return
	
	var headers: Array = []
	var is_first_line = true
	
	while not file.eof_reached():
		var line = file.get_line().strip_edges()
		if line.is_empty() or line.begins_with("#"):
			continue
		
		var values = line.split(",")
		
		if is_first_line:
			headers = Array(values)
			is_first_line = false
			continue
		
		if values.size() < headers.size():
			continue
		
		var config: Dictionary = {}
		for i in range(headers.size()):
			var key = headers[i].strip_edges()
			var value = values[i].strip_edges()
			
			if key in ["cost", "value_increase"]:
				if value.contains("."):
					config[key] = float(value)
				else:
					config[key] = int(value)
			else:
				config[key] = value
		
		upgrade_configs.append(config)
	
	file.close()
	
	# 鍔犺浇鏈€澶у崌绾х瓑绾?
	max_upgrade_level = int(ConfigManager.get_game_setting("max_upgrade_level", 5))
	
	if DEBUG_VERBOSE: print("[DataManager] 鍔犺浇浜?%d 涓崌绾ч厤缃紝鏈€澶х瓑绾? %d" % [upgrade_configs.size(), max_upgrade_level])

# ============================================================================
# 瀛樻。绠＄悊
# ============================================================================

func _load_save_data() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		if DEBUG_VERBOSE:
			print("[DataManager] save file not found, use defaults")
		_init_default_save()
		return
	
	var file = FileAccess.open(SAVE_PATH, FileAccess.READ)
	if not file:
		printerr("[DataManager] 鏃犳硶鎵撳紑瀛樻。鏂囦欢")
		_init_default_save()
		return
	
	var json_text = file.get_as_text()
	file.close()
	
	var json = JSON.new()
	var error = json.parse(json_text)
	if error != OK:
		printerr("[DataManager] 瑙ｆ瀽瀛樻。JSON澶辫触: %s" % json.get_error_message())
		_init_default_save()
		return
	
	var data = json.get_data()
	if data is Dictionary:
		save_data = data
		var migrated = _migrate_currency_fields()
		if migrated:
			save_game()
	
	if DEBUG_VERBOSE: print("[DataManager] 鍔犺浇瀛樻。鎴愬姛锛宺un_gold=%d, soul_shard=%d" % [get_run_gold(), get_soul_shard()])

func _init_default_save() -> void:
	save_data = {
		"run_gold": 0,
		"soul_shard": _get_default_soul_shard(),
		"upgrades": {}
	}
	save_game()

func _get_default_gold() -> int:
	return _get_default_soul_shard()

func _get_default_soul_shard() -> int:
	var default_shard = ConfigManager.get_game_setting("default_soul_shard", null)
	if default_shard == null:
		default_shard = ConfigManager.get_game_setting("default_gold", 1000)
	return int(default_shard)

func _migrate_currency_fields() -> bool:
	var migrated = false
	
	if save_data.has("total_gold") and not save_data.has("soul_shard"):
		save_data["soul_shard"] = int(save_data.get("total_gold", _get_default_soul_shard()))
		migrated = true
	
	if save_data.has("total_gold"):
		save_data.erase("total_gold")
		migrated = true
	
	if not save_data.has("run_gold"):
		save_data["run_gold"] = 0
		migrated = true
	
	if not save_data.has("soul_shard"):
		save_data["soul_shard"] = _get_default_soul_shard()
		migrated = true
	
	if not save_data.has("upgrades"):
		save_data["upgrades"] = {}
		migrated = true
	
	return migrated

func _emit_run_gold_changed() -> void:
	var current = get_run_gold()
	run_gold_changed.emit(current)
	gold_changed.emit(current)

func _emit_soul_shard_changed() -> void:
	soul_shard_changed.emit(get_soul_shard())

func save_game() -> void:
	var file = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if not file:
		printerr("[DataManager] 鏃犳硶鍒涘缓瀛樻。鏂囦欢")
		return
	
	var json_text = JSON.stringify(save_data, "\t")
	file.store_string(json_text)
	file.close()
	#print("[DataManager] 瀛樻。淇濆瓨鎴愬姛")

func serialize_progress_data() -> Dictionary:
	var upgrades = save_data.get("upgrades", {})
	var upgrades_data: Dictionary = upgrades.duplicate(true) if upgrades is Dictionary else {}
	return {
		"gold": get_run_gold(),
		"run_gold": get_run_gold(),
		"soul_shard": get_soul_shard(),
		"upgrades": upgrades_data
	}

func deserialize_progress_data(data: Dictionary, persist: bool = true) -> void:
	var game_state := str(data.get("game_state", "in_progress"))
	var legacy_gold := int(data.get("gold", data.get("total_gold", 0)))
	var run_gold := int(data.get("run_gold", legacy_gold if game_state == "in_battle" else 0))
	save_data["run_gold"] = max(0, run_gold)

	var fallback_shard := int(save_data.get("soul_shard", _get_default_soul_shard()))
	var shard_value := int(data.get("soul_shard", data.get("total_gold", fallback_shard)))
	save_data["soul_shard"] = max(0, shard_value)

	var upgrades = data.get("upgrades", {})
	save_data["upgrades"] = upgrades.duplicate(true) if upgrades is Dictionary else {}

	_migrate_currency_fields()
	if persist:
		save_game()

	_emit_run_gold_changed()
	_emit_soul_shard_changed()

# ============================================================================
# 璐у竵绠＄悊
# ============================================================================

func get_run_gold() -> int:
	return int(save_data.get("run_gold", 0))

func set_run_gold(amount: int) -> void:
	save_data["run_gold"] = max(0, amount)
	save_game()
	_emit_run_gold_changed()

func add_run_gold(amount: int) -> void:
	if amount == 0:
		return
	save_data["run_gold"] = max(0, get_run_gold() + amount)
	save_game()
	_emit_run_gold_changed()
	if DEBUG_VERBOSE: print("[DataManager] 灞€鍐呴噾甯佸彉鍖?%+d锛屽綋鍓? %d" % [amount, get_run_gold()])

func spend_run_gold(amount: int) -> bool:
	if amount <= 0:
		return false
	if get_run_gold() < amount:
		return false
	save_data["run_gold"] = get_run_gold() - amount
	save_game()
	_emit_run_gold_changed()
	if DEBUG_VERBOSE: print("[DataManager] 娑堣垂灞€鍐呴噾甯?%d锛屽墿浣? %d" % [amount, get_run_gold()])
	return true

func reset_run_gold() -> void:
	save_data["run_gold"] = 0
	save_game()
	_emit_run_gold_changed()

func get_soul_shard() -> int:
	return int(save_data.get("soul_shard", 0))

func set_soul_shard(amount: int) -> void:
	save_data["soul_shard"] = max(0, amount)
	save_game()
	_emit_soul_shard_changed()

func add_soul_shard(amount: int) -> void:
	if amount == 0:
		return
	save_data["soul_shard"] = max(0, get_soul_shard() + amount)
	save_game()
	_emit_soul_shard_changed()
	if DEBUG_VERBOSE: print("[DataManager] 灞€澶栫鐗囧彉鍖?%+d锛屽綋鍓? %d" % [amount, get_soul_shard()])

func spend_soul_shard(amount: int) -> bool:
	if amount <= 0:
		return false
	if get_soul_shard() < amount:
		return false
	save_data["soul_shard"] = get_soul_shard() - amount
	save_game()
	_emit_soul_shard_changed()
	if DEBUG_VERBOSE: print("[DataManager] 娑堣垂灞€澶栫鐗?%d锛屽墿浣? %d" % [amount, get_soul_shard()])
	return true

func settle_run_to_soul_shard(run_income: int = -1) -> Dictionary:
	var run_gold_before = get_run_gold()
	var settle_base = run_income if run_income >= 0 else run_gold_before
	settle_base = max(0, settle_base)
	
	var ratio = float(ConfigManager.get_game_setting("run_gold_to_soul_shard_ratio", 1.0))
	var flat_bonus = int(ConfigManager.get_game_setting("run_gold_to_soul_shard_flat", 0))
	var min_reward = int(ConfigManager.get_game_setting("run_settlement_min_shard", 0))
	
	var shard_gain = int(floor(float(settle_base) * ratio)) + flat_bonus
	if settle_base > 0:
		shard_gain = max(shard_gain, min_reward)
	else:
		shard_gain = 0
	
	if shard_gain > 0:
		save_data["soul_shard"] = max(0, get_soul_shard() + shard_gain)
	
	save_data["run_gold"] = 0
	save_game()
	_emit_run_gold_changed()
	if shard_gain > 0:
		_emit_soul_shard_changed()
	
	var result = {
		"run_gold_before": run_gold_before,
		"settle_base": settle_base,
		"soul_shard_gain": shard_gain,
		"soul_shard_after": get_soul_shard()
	}
	if DEBUG_VERBOSE: print("[DataManager] 缁撶畻瀹屾垚: %s" % str(result))
	return result

func get_total_gold() -> int:
	return get_run_gold()

func add_gold(amount: int) -> void:
	add_run_gold(amount)

func spend_gold(amount: int) -> bool:
	return spend_run_gold(amount)

# ============================================================================
# 鍗囩骇绠＄悊
# ============================================================================

func get_upgrade_level(player_id: String, attribute_name: String) -> int:
	if not save_data.upgrades.has(player_id):
		return 0
	var player_upgrades = save_data.upgrades[player_id]
	var key = attribute_name + "_level"
	return player_upgrades.get(key, 0)

func set_upgrade_level(player_id: String, attribute_name: String, level: int) -> void:
	if not save_data.upgrades.has(player_id):
		save_data.upgrades[player_id] = {}
	var key = attribute_name + "_level"
	save_data.upgrades[player_id][key] = level
	save_game()

func can_upgrade(player_id: String, attribute_name: String, use_run_gold: bool = false) -> bool:
	var current_level = get_upgrade_level(player_id, attribute_name)
	if current_level >= max_upgrade_level:
		return false
	
	var config = get_upgrade_config(attribute_name)
	if config.is_empty():
		return false
	
	if use_run_gold:
		return get_run_gold() >= config.cost
	return get_soul_shard() >= config.cost

func do_upgrade(player_id: String, attribute_name: String, use_run_gold: bool = false) -> bool:
	if not can_upgrade(player_id, attribute_name, use_run_gold):
		return false
	
	var config = get_upgrade_config(attribute_name)
	var current_level = get_upgrade_level(player_id, attribute_name)
	
	# 鎵ｉ櫎璐у竵锛堝眬鍐?灞€澶栵級
	if use_run_gold:
		if not spend_run_gold(config.cost):
			return false
	else:
		if not spend_soul_shard(config.cost):
			return false
	
	# 澧炲姞绛夌骇
	set_upgrade_level(player_id, attribute_name, current_level + 1)
	
	if DEBUG_VERBOSE: print("[DataManager] 鍗囩骇鎴愬姛: %s.%s -> Lv.%d (currency=%s)" % [
		player_id,
		attribute_name,
		current_level + 1,
		"run_gold" if use_run_gold else "soul_shard"
	])
	return true

func get_upgrade_config(attribute_name: String) -> Dictionary:
	for config in upgrade_configs:
		if config.attribute_name == attribute_name:
			return config
	return {}

func get_all_upgrade_configs() -> Array[Dictionary]:
	return upgrade_configs

func get_attribute_bonus(player_id: String, attribute_name: String) -> float:
	var level = get_upgrade_level(player_id, attribute_name)
	if level == 0:
		return 0.0
	
	var config = get_upgrade_config(attribute_name)
	if config.is_empty():
		return 0.0
	
	return config.value_increase * level

func get_max_upgrade_level() -> int:
	return max_upgrade_level

# ============================================================================
# 鍗曞眬閲嶇疆閫昏緫 (Roguelike Mode)
# ============================================================================

func reset_all_upgrades() -> void:
	save_data.upgrades = {}
	save_game()
	if DEBUG_VERBOSE:
		print("[DataManager] reset all upgrade levels")

func check_and_reset_on_new_game() -> void:
	var should_reset = ConfigManager.get_game_setting("reset_attributes_on_new_game", 0)
	# 杞崲涓烘暣鏁拌繘琛屾瘮杈冿細1=閲嶇疆锛?=淇濈暀
	var reset_value = int(should_reset)
	if reset_value == 1:
		if DEBUG_VERBOSE:
			print("[DataManager] roguelike mode: reset upgrades")
		reset_all_upgrades()

func get_player_base_attribute(player_id: String, attribute_name: String) -> float:
	var config = ConfigManager.get_player_config(player_id)
	if config.is_empty():
		return 0.0
	
	# 灞炴€у悕鏄犲皠锛歶pgrade config -> player config
	var attr_map = {
		"hp": "health",
		"max_energy": "max_energy",
		"energy_regen": "energy_regen",
		"base_speed": "base_speed",
		"max_armor": "max_armor"
	}
	
	var config_key = attr_map.get(attribute_name, attribute_name)
	return float(config.get(config_key, 0))

func get_player_current_attribute(player_id: String, attribute_name: String) -> float:
	var base_value = get_player_base_attribute(player_id, attribute_name)
	var bonus = get_attribute_bonus(player_id, attribute_name)
	return base_value + bonus

# ============================================================================
# 灞€鍐呬細璇濆瓨妗ｏ紙闃插穿婧冩仮澶嶏級
# ============================================================================

func save_session_data() -> void:
	var session: Dictionary = {
		"emblem_data": EmblemManager.serialize()
	}
	
	var file = FileAccess.open(SESSION_SAVE_PATH, FileAccess.WRITE)
	if not file:
		printerr("[DataManager] failed to create session save file")
		return
	
	var json_text = JSON.stringify(session, "\t")
	file.store_string(json_text)
	file.close()
	if DEBUG_VERBOSE: print("[DataManager] 灞€鍐呬細璇濆瓨妗ｅ凡淇濆瓨")

func load_session_data() -> void:
	if not FileAccess.file_exists(SESSION_SAVE_PATH):
		if DEBUG_VERBOSE:
			print("[DataManager] no session save file")
		return
	
	var file = FileAccess.open(SESSION_SAVE_PATH, FileAccess.READ)
	if not file:
		printerr("[DataManager] failed to open session save file")
		return
	
	var json_text = file.get_as_text()
	file.close()
	
	var json = JSON.new()
	var error = json.parse(json_text)
	if error != OK:
		printerr("[DataManager] 瑙ｆ瀽灞€鍐呬細璇濆瓨妗ｅけ璐? %s" % json.get_error_message())
		return
	
	var data = json.get_data()
	if data is Dictionary and data.has("emblem_data"):
		EmblemManager.deserialize(data["emblem_data"])
		if DEBUG_VERBOSE: print("[DataManager] 灞€鍐呬細璇濆瓨妗ｅ凡鎭㈠")

func clear_session_data() -> void:
	if FileAccess.file_exists(SESSION_SAVE_PATH):
		DirAccess.remove_absolute(SESSION_SAVE_PATH)
		if DEBUG_VERBOSE: print("[DataManager] 灞€鍐呬細璇濆瓨妗ｅ凡娓呯悊")

func has_session_data() -> bool:
	return FileAccess.file_exists(SESSION_SAVE_PATH)

# ============================================================================
# 闅忔満姝﹀櫒鍟嗗簵 (Starting Weapon Shop)
# ============================================================================

# 褰撳墠闅忔満鐨勬鍣?{player_id: weapon_type}
var random_weapons: Dictionary = {}

# 宸茶喘涔扮殑姝﹀櫒 {player_id: weapon_type}
var purchased_weapons: Dictionary = {}

func generate_random_weapons_for_players(player_ids: Array) -> void:
	random_weapons.clear()
	
	# 鑾峰彇鎵€鏈夊彲鐢ㄦ鍣ㄧ被鍨嬶紙鎺掗櫎榛樿姝﹀櫒 punch锛?
	var available_types: Array[String] = []
	var all_weapons = ConfigManager.weapon_configs
	
	for weapon_id in all_weapons.keys():
		var weapon_type = _extract_weapon_type(weapon_id)
		if weapon_type != "" and weapon_type != "punch" and not available_types.has(weapon_type):
			available_types.append(weapon_type)
	
	if available_types.is_empty():
		if DEBUG_VERBOSE:
			print("[DataManager] no available random weapon types")
		return
	
	# 鎵撲贡椤哄簭
	available_types.shuffle()
	
	# 涓烘瘡涓鑹插垎閰嶄笉鍚岀殑姝﹀櫒
	var type_index = 0
	for player_id in player_ids:
		if type_index >= available_types.size():
			type_index = 0  # 寰幆浣跨敤
		random_weapons[player_id] = available_types[type_index]
		type_index += 1
	
	if DEBUG_VERBOSE: print("[DataManager] 鐢熸垚闅忔満姝﹀櫒: %s (鍙敤绫诲瀷: %d)" % [str(random_weapons), available_types.size()])

func _extract_weapon_type(weapon_id: String) -> String:
	# ConfigManager.weapon_configs 的 key 已经是 base_id（如 punch/laser）
	return weapon_id

func get_random_weapon_for_player(player_id: String) -> String:
	return random_weapons.get(player_id, "")

func has_purchased_weapon(player_id: String) -> bool:
	return purchased_weapons.has(player_id)

func purchase_starting_weapon(player_id: String) -> bool:
	if has_purchased_weapon(player_id):
		return false
	
	var weapon_type = get_random_weapon_for_player(player_id)
	if weapon_type == "":
		return false
	
	var price = int(ConfigManager.get_game_setting("starting_weapon_price", 100))
	if not spend_soul_shard(price):
		return false
	
	purchased_weapons[player_id] = weapon_type
	if DEBUG_VERBOSE: print("[DataManager] 璐拱姝﹀櫒鎴愬姛: %s -> %s" % [player_id, weapon_type])
	return true

func get_purchased_weapon(player_id: String) -> String:
	return purchased_weapons.get(player_id, "")

func reset_weapon_shop() -> void:
	random_weapons.clear()
	purchased_weapons.clear()
	if DEBUG_VERBOSE:
		print("[DataManager] weapon shop reset")
