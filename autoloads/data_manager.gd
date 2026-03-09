extends Node

# ============================================================================
# 数据管理器 - 负责双货币和升级数据的持久化
# ============================================================================

# 信号
signal gold_changed(new_gold: int)  # 兼容旧链路：等同 run_gold_changed
signal run_gold_changed(new_gold: int)  # 局内金币变化
signal soul_shard_changed(new_shard: int)  # 局外碎片变化

const SAVE_PATH = "user://player_save.json"
const SESSION_SAVE_PATH = "user://session_data.json"

# 保存数据结构
var save_data: Dictionary = {
	"run_gold": 0,
	"soul_shard": 0,
	"upgrades": {}  # { "player_id": { "hp_level": 0, "max_energy_level": 0, ... } }
}

# 升级配置缓存
var upgrade_configs: Array[Dictionary] = []
var max_upgrade_level: int = 5

# ============================================================================
# 初始化
# ============================================================================

func _ready() -> void:
	_load_upgrade_configs()
	_load_save_data()
	# 检查局内会话存档并恢复
	if has_session_data():
		load_session_data()
	print("[DataManager] 初始化完成，run_gold=%d, soul_shard=%d" % [get_run_gold(), get_soul_shard()])

# ============================================================================
# 配置加载
# ============================================================================

func _load_upgrade_configs() -> void:
	"""加载属性升级配置"""
	upgrade_configs.clear()
	
	var file_path = "res://config/player/attribute_upgrade.csv"
	if not FileAccess.file_exists(file_path):
		printerr("[DataManager] 升级配置文件不存在: %s" % file_path)
		return
	
	var file = FileAccess.open(file_path, FileAccess.READ)
	if not file:
		printerr("[DataManager] 无法打开升级配置文件")
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
	
	# 加载最大升级等级
	max_upgrade_level = int(ConfigManager.get_game_setting("max_upgrade_level", 5))
	
	print("[DataManager] 加载了 %d 个升级配置，最大等级: %d" % [upgrade_configs.size(), max_upgrade_level])

# ============================================================================
# 存档管理
# ============================================================================

func _load_save_data() -> void:
	"""从本地文件加载存档"""
	if not FileAccess.file_exists(SAVE_PATH):
		print("[DataManager] 存档不存在，使用默认值")
		_init_default_save()
		return
	
	var file = FileAccess.open(SAVE_PATH, FileAccess.READ)
	if not file:
		printerr("[DataManager] 无法打开存档文件")
		_init_default_save()
		return
	
	var json_text = file.get_as_text()
	file.close()
	
	var json = JSON.new()
	var error = json.parse(json_text)
	if error != OK:
		printerr("[DataManager] 解析存档JSON失败: %s" % json.get_error_message())
		_init_default_save()
		return
	
	var data = json.get_data()
	if data is Dictionary:
		save_data = data
		var migrated = _migrate_currency_fields()
		if migrated:
			save_game()
	
	print("[DataManager] 加载存档成功，run_gold=%d, soul_shard=%d" % [get_run_gold(), get_soul_shard()])

func _init_default_save() -> void:
	"""初始化默认存档"""
	save_data = {
		"run_gold": 0,
		"soul_shard": _get_default_soul_shard(),
		"upgrades": {}
	}
	save_game()

func _get_default_gold() -> int:
	"""兼容旧接口：默认金币值等同默认局外碎片"""
	return _get_default_soul_shard()

func _get_default_soul_shard() -> int:
	"""获取默认局外碎片数"""
	var default_shard = ConfigManager.get_game_setting("default_soul_shard", null)
	if default_shard == null:
		default_shard = ConfigManager.get_game_setting("default_gold", 1000)
	return int(default_shard)

func _migrate_currency_fields() -> bool:
	"""兼容旧档：total_gold -> soul_shard，并补齐 run_gold 字段。"""
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
	"""保存游戏数据到本地"""
	var file = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if not file:
		printerr("[DataManager] 无法创建存档文件")
		return
	
	var json_text = JSON.stringify(save_data, "\t")
	file.store_string(json_text)
	file.close()
	#print("[DataManager] 存档保存成功")

func serialize_progress_data() -> Dictionary:
	"""导出可写入槽位存档的进度数据。"""
	var upgrades = save_data.get("upgrades", {})
	var upgrades_data: Dictionary = upgrades.duplicate(true) if upgrades is Dictionary else {}
	return {
		"gold": get_run_gold(),  # 兼容旧字段
		"run_gold": get_run_gold(),
		"soul_shard": get_soul_shard(),
		"upgrades": upgrades_data
	}

func deserialize_progress_data(data: Dictionary, persist: bool = true) -> void:
	"""从槽位数据恢复双货币和升级进度。"""
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
# 货币管理
# ============================================================================

func get_run_gold() -> int:
	"""获取局内金币"""
	return int(save_data.get("run_gold", 0))

func set_run_gold(amount: int) -> void:
	"""设置局内金币（最小为0）"""
	save_data["run_gold"] = max(0, amount)
	save_game()
	_emit_run_gold_changed()

func add_run_gold(amount: int) -> void:
	"""增减局内金币（可传负数）"""
	if amount == 0:
		return
	save_data["run_gold"] = max(0, get_run_gold() + amount)
	save_game()
	_emit_run_gold_changed()
	print("[DataManager] 局内金币变化 %+d，当前: %d" % [amount, get_run_gold()])

func spend_run_gold(amount: int) -> bool:
	"""消费局内金币，返回是否成功"""
	if amount <= 0:
		return false
	if get_run_gold() < amount:
		return false
	save_data["run_gold"] = get_run_gold() - amount
	save_game()
	_emit_run_gold_changed()
	print("[DataManager] 消费局内金币 %d，剩余: %d" % [amount, get_run_gold()])
	return true

func reset_run_gold() -> void:
	"""局结束后重置局内金币"""
	save_data["run_gold"] = 0
	save_game()
	_emit_run_gold_changed()

func get_soul_shard() -> int:
	"""获取局外碎片"""
	return int(save_data.get("soul_shard", 0))

func set_soul_shard(amount: int) -> void:
	"""设置局外碎片（最小为0）"""
	save_data["soul_shard"] = max(0, amount)
	save_game()
	_emit_soul_shard_changed()

func add_soul_shard(amount: int) -> void:
	"""增减局外碎片（可传负数）"""
	if amount == 0:
		return
	save_data["soul_shard"] = max(0, get_soul_shard() + amount)
	save_game()
	_emit_soul_shard_changed()
	print("[DataManager] 局外碎片变化 %+d，当前: %d" % [amount, get_soul_shard()])

func spend_soul_shard(amount: int) -> bool:
	"""消费局外碎片，返回是否成功"""
	if amount <= 0:
		return false
	if get_soul_shard() < amount:
		return false
	save_data["soul_shard"] = get_soul_shard() - amount
	save_game()
	_emit_soul_shard_changed()
	print("[DataManager] 消费局外碎片 %d，剩余: %d" % [amount, get_soul_shard()])
	return true

func settle_run_to_soul_shard(run_income: int = -1) -> Dictionary:
	"""结算局内收益，发放局外碎片并清空 run_gold。
	
	run_income < 0 时，默认按当前 run_gold 计算。
	"""
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
	print("[DataManager] 结算完成: %s" % str(result))
	return result

func get_total_gold() -> int:
	"""兼容旧接口：返回局内金币"""
	return get_run_gold()

func add_gold(amount: int) -> void:
	"""兼容旧接口：增减局内金币"""
	add_run_gold(amount)

func spend_gold(amount: int) -> bool:
	"""兼容旧接口：消费局内金币"""
	return spend_run_gold(amount)

# ============================================================================
# 升级管理
# ============================================================================

func get_upgrade_level(player_id: String, attribute_name: String) -> int:
	"""获取角色某属性的升级等级"""
	if not save_data.upgrades.has(player_id):
		return 0
	var player_upgrades = save_data.upgrades[player_id]
	var key = attribute_name + "_level"
	return player_upgrades.get(key, 0)

func set_upgrade_level(player_id: String, attribute_name: String, level: int) -> void:
	"""设置角色某属性的升级等级"""
	if not save_data.upgrades.has(player_id):
		save_data.upgrades[player_id] = {}
	var key = attribute_name + "_level"
	save_data.upgrades[player_id][key] = level
	save_game()

func can_upgrade(player_id: String, attribute_name: String, use_run_gold: bool = false) -> bool:
	"""检查是否可以升级。

	use_run_gold=true 时消耗局内金币；否则消耗局外碎片。
	"""
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
	"""执行升级操作。

	use_run_gold=true 时消耗局内金币；否则消耗局外碎片。
	"""
	if not can_upgrade(player_id, attribute_name, use_run_gold):
		return false
	
	var config = get_upgrade_config(attribute_name)
	var current_level = get_upgrade_level(player_id, attribute_name)
	
	# 扣除货币（局内/局外）
	if use_run_gold:
		if not spend_run_gold(config.cost):
			return false
	else:
		if not spend_soul_shard(config.cost):
			return false
	
	# 增加等级
	set_upgrade_level(player_id, attribute_name, current_level + 1)
	
	print("[DataManager] 升级成功: %s.%s -> Lv.%d (currency=%s)" % [
		player_id,
		attribute_name,
		current_level + 1,
		"run_gold" if use_run_gold else "soul_shard"
	])
	return true

func get_upgrade_config(attribute_name: String) -> Dictionary:
	"""获取属性升级配置"""
	for config in upgrade_configs:
		if config.attribute_name == attribute_name:
			return config
	return {}

func get_all_upgrade_configs() -> Array[Dictionary]:
	"""获取所有升级配置"""
	return upgrade_configs

func get_attribute_bonus(player_id: String, attribute_name: String) -> float:
	"""获取角色某属性的升级加成值"""
	var level = get_upgrade_level(player_id, attribute_name)
	if level == 0:
		return 0.0
	
	var config = get_upgrade_config(attribute_name)
	if config.is_empty():
		return 0.0
	
	return config.value_increase * level

func get_max_upgrade_level() -> int:
	"""获取最大升级等级"""
	return max_upgrade_level

# ============================================================================
# 单局重置逻辑 (Roguelike Mode)
# ============================================================================

func reset_all_upgrades() -> void:
	"""重置所有角色的升级等级（保留局外碎片）"""
	save_data.upgrades = {}
	save_game()
	print("[DataManager] 已重置所有角色升级等级")

func check_and_reset_on_new_game() -> void:
	"""检查配置并在新游戏时重置升级（如果启用）"""
	var should_reset = ConfigManager.get_game_setting("reset_attributes_on_new_game", 0)
	# 转换为整数进行比较：1=重置，0=保留
	var reset_value = int(should_reset)
	if reset_value == 1:
		print("[DataManager] Roguelike模式：重置所有升级")
		reset_all_upgrades()

func get_player_base_attribute(player_id: String, attribute_name: String) -> float:
	"""获取角色某属性的基础值（从配置读取）"""
	var config = ConfigManager.get_player_config(player_id)
	if config.is_empty():
		return 0.0
	
	# 属性名映射：upgrade config -> player config
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
	"""获取角色某属性的当前值（基础值 + 升级加成）"""
	var base_value = get_player_base_attribute(player_id, attribute_name)
	var bonus = get_attribute_bonus(player_id, attribute_name)
	return base_value + bonus

# ============================================================================
# 局内会话存档（防崩溃恢复）
# ============================================================================

func save_session_data() -> void:
	"""保存局内会话数据（每波结束时调用）"""
	var session: Dictionary = {
		"emblem_data": EmblemManager.serialize()
	}
	
	var file = FileAccess.open(SESSION_SAVE_PATH, FileAccess.WRITE)
	if not file:
		printerr("[DataManager] 无法创建局内会话存档文件")
		return
	
	var json_text = JSON.stringify(session, "\t")
	file.store_string(json_text)
	file.close()
	print("[DataManager] 局内会话存档已保存")

func load_session_data() -> void:
	"""加载局内会话存档并恢复状态"""
	if not FileAccess.file_exists(SESSION_SAVE_PATH):
		print("[DataManager] 无局内会话存档")
		return
	
	var file = FileAccess.open(SESSION_SAVE_PATH, FileAccess.READ)
	if not file:
		printerr("[DataManager] 无法打开局内会话存档文件")
		return
	
	var json_text = file.get_as_text()
	file.close()
	
	var json = JSON.new()
	var error = json.parse(json_text)
	if error != OK:
		printerr("[DataManager] 解析局内会话存档失败: %s" % json.get_error_message())
		return
	
	var data = json.get_data()
	if data is Dictionary and data.has("emblem_data"):
		EmblemManager.deserialize(data["emblem_data"])
		print("[DataManager] 局内会话存档已恢复")

func clear_session_data() -> void:
	"""清理局内会话存档（局结束时调用）"""
	if FileAccess.file_exists(SESSION_SAVE_PATH):
		DirAccess.remove_absolute(SESSION_SAVE_PATH)
		print("[DataManager] 局内会话存档已清理")

func has_session_data() -> bool:
	"""检查是否存在局内会话存档"""
	return FileAccess.file_exists(SESSION_SAVE_PATH)

# ============================================================================
# 随机武器商店 (Starting Weapon Shop)
# ============================================================================

# 当前随机的武器 {player_id: weapon_type}
var random_weapons: Dictionary = {}

# 已购买的武器 {player_id: weapon_type}
var purchased_weapons: Dictionary = {}

func generate_random_weapons_for_players(player_ids: Array) -> void:
	"""为每个角色生成随机武器"""
	random_weapons.clear()
	
	# 获取所有可用武器类型（排除默认武器 punch）
	var available_types: Array[String] = []
	var all_weapons = ConfigManager.weapon_configs
	
	for weapon_id in all_weapons.keys():
		var weapon_type = _extract_weapon_type(weapon_id)
		if weapon_type != "" and weapon_type != "punch" and not available_types.has(weapon_type):
			available_types.append(weapon_type)
	
	if available_types.is_empty():
		print("[DataManager] 没有可用的随机武器类型")
		return
	
	# 打乱顺序
	available_types.shuffle()
	
	# 为每个角色分配不同的武器
	var type_index = 0
	for player_id in player_ids:
		if type_index >= available_types.size():
			type_index = 0  # 循环使用
		random_weapons[player_id] = available_types[type_index]
		type_index += 1
	
	print("[DataManager] 生成随机武器: %s (可用类型: %d)" % [str(random_weapons), available_types.size()])

func _extract_weapon_type(weapon_id: String) -> String:
	"""从 weapon_id 提取武器类型
	   ConfigManager.weapon_configs 的键已经是 base_id（如 punch, laser, heal_bolt）
	   直接返回即可，不需要拆分"""
	return weapon_id

func get_random_weapon_for_player(player_id: String) -> String:
	"""获取角色的随机武器类型"""
	return random_weapons.get(player_id, "")

func has_purchased_weapon(player_id: String) -> bool:
	"""检查角色是否已购买随机武器"""
	return purchased_weapons.has(player_id)

func purchase_starting_weapon(player_id: String) -> bool:
	"""购买随机初始武器"""
	if has_purchased_weapon(player_id):
		return false
	
	var weapon_type = get_random_weapon_for_player(player_id)
	if weapon_type == "":
		return false
	
	var price = int(ConfigManager.get_game_setting("starting_weapon_price", 100))
	if not spend_soul_shard(price):
		return false
	
	purchased_weapons[player_id] = weapon_type
	print("[DataManager] 购买武器成功: %s -> %s" % [player_id, weapon_type])
	return true

func get_purchased_weapon(player_id: String) -> String:
	"""获取角色已购买的武器类型"""
	return purchased_weapons.get(player_id, "")

func reset_weapon_shop() -> void:
	"""重置武器商店（清空购买记录和随机武器）"""
	random_weapons.clear()
	purchased_weapons.clear()
	print("[DataManager] 武器商店已重置")
