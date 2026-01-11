extends Node

# ============================================================================
# 数据管理器 - 负责金币和升级数据的持久化
# ============================================================================

const SAVE_PATH = "user://player_save.json"

# 保存数据结构
var save_data: Dictionary = {
	"total_gold": 0,
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
	print("[DataManager] 初始化完成，当前金币: %d" % save_data.total_gold)

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
		# 确保必要字段存在
		if not save_data.has("total_gold"):
			save_data.total_gold = _get_default_gold()
		if not save_data.has("upgrades"):
			save_data.upgrades = {}
	
	print("[DataManager] 加载存档成功，金币: %d" % save_data.total_gold)

func _init_default_save() -> void:
	"""初始化默认存档"""
	save_data = {
		"total_gold": _get_default_gold(),
		"upgrades": {}
	}
	save_game()

func _get_default_gold() -> int:
	"""获取默认金币数"""
	return int(ConfigManager.get_game_setting("default_gold", 1000))

func save_game() -> void:
	"""保存游戏数据到本地"""
	var file = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if not file:
		printerr("[DataManager] 无法创建存档文件")
		return
	
	var json_text = JSON.stringify(save_data, "\t")
	file.store_string(json_text)
	file.close()
	print("[DataManager] 存档保存成功")

# ============================================================================
# 金币管理
# ============================================================================

func get_total_gold() -> int:
	"""获取当前金币总数"""
	return save_data.total_gold

func add_gold(amount: int) -> void:
	"""增加金币"""
	save_data.total_gold += amount
	save_game()
	print("[DataManager] 增加金币 %d，当前: %d" % [amount, save_data.total_gold])

func spend_gold(amount: int) -> bool:
	"""消费金币，返回是否成功"""
	if save_data.total_gold < amount:
		return false
	save_data.total_gold -= amount
	save_game()
	print("[DataManager] 消费金币 %d，剩余: %d" % [amount, save_data.total_gold])
	return true

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

func can_upgrade(player_id: String, attribute_name: String) -> bool:
	"""检查是否可以升级"""
	var current_level = get_upgrade_level(player_id, attribute_name)
	if current_level >= max_upgrade_level:
		return false
	
	var config = get_upgrade_config(attribute_name)
	if config.is_empty():
		return false
	
	return save_data.total_gold >= config.cost

func do_upgrade(player_id: String, attribute_name: String) -> bool:
	"""执行升级操作"""
	if not can_upgrade(player_id, attribute_name):
		return false
	
	var config = get_upgrade_config(attribute_name)
	var current_level = get_upgrade_level(player_id, attribute_name)
	
	# 扣除金币
	if not spend_gold(config.cost):
		return false
	
	# 增加等级
	set_upgrade_level(player_id, attribute_name, current_level + 1)
	
	print("[DataManager] 升级成功: %s.%s -> Lv.%d" % [player_id, attribute_name, current_level + 1])
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
	"""重置所有角色的升级等级（保留金币）"""
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
	var all_weapons = ConfigManager.get_all_weapon_stats()
	
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
	
	print("[DataManager] 生成随机武器: %s" % str(random_weapons))

func _extract_weapon_type(weapon_id: String) -> String:
	"""从 weapon_id 提取武器类型 (例如 laser_1 -> laser)"""
	var parts = weapon_id.split("_")
	if parts.size() >= 2:
		return parts[0]
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
	if not spend_gold(price):
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
