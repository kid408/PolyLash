extends Node

# ============================================================================
# 配置管理器 - 统一管理所有 CSV 配置
# ============================================================================
# 
# 功能说明:
# - 在游戏启动时自动加载所有 CSV 配置文件
# - 将配置数据缓存到内存中，提供快速访问
# - 提供便捷的访问方法，避免直接操作字典
# 
# 使用方法:
#   var config = ConfigManager.get_player_config("player_herder")
#   var weapon = ConfigManager.get_weapon_config("weapon_sword")
# 
# 注意事项:
# - 配置在游戏启动时加载，修改 CSV 后需要重启游戏
# - 所有配置都是只读的，不应该在运行时修改
# ============================================================================

# ============================================================================
# 配置数据缓存
# ============================================================================

# 玩家相关配置
var player_configs: Dictionary = {}              # 玩家基础属性配置 (player_id -> config)
var player_visual_configs: Dictionary = {}       # 玩家视觉配置 (player_id -> visual)
var player_weapon_configs: Dictionary = {}       # 玩家武器配置 (player_id -> weapons)

# 敌人相关配置
var enemy_configs: Dictionary = {}               # 敌人基础属性配置 (enemy_id -> config)
var enemy_visual_configs: Dictionary = {}        # 敌人视觉配置 (enemy_id -> visual)
var enemy_weapon_configs: Dictionary = {}        # 敌人武器配置 (enemy_id -> weapons)

# 武器配置
var weapon_configs: Dictionary = {}              # 武器属性配置 (weapon_id -> config)

# 输入配置
var input_configs: Dictionary = {}               # 输入映射配置 (action -> key)

# 全局配置
var game_config: Dictionary = {}                 # 游戏全局设置 (setting -> value)
var camera_config: Dictionary = {}               # 摄像机设置 (setting -> value)
var map_config: Dictionary = {}                  # 地图设置 (setting -> value)

# 升级系统配置
var upgrade_attributes: Dictionary = {}          # 升级属性配置 (attribute_id -> config)

# 宝箱系统配置
var chest_configs: Dictionary = {}               # 宝箱配置 (tier -> config)
var wave_chest_configs: Array[Dictionary] = []   # 波次宝箱配置 (数组，按波次范围)

# 音效系统配置
var sound_configs: Dictionary = {}               # 音效配置 (sound_id -> config)

# 配置文件路径
const CONFIG_DIR = "res://config/"
const PLAYER_CONFIG = CONFIG_DIR + "player_config.csv"
const PLAYER_VISUAL = CONFIG_DIR + "player_visual.csv"
const PLAYER_WEAPONS = CONFIG_DIR + "player_weapons.csv"
const ENEMY_CONFIG = CONFIG_DIR + "enemy_config.csv"
const ENEMY_VISUAL = CONFIG_DIR + "enemy_visual.csv"
const ENEMY_WEAPONS = CONFIG_DIR + "enemy_weapons.csv"
const WEAPON_CONFIG = CONFIG_DIR + "weapon_config.csv"
const INPUT_CONFIG = CONFIG_DIR + "input_config.csv"
const GAME_CONFIG = CONFIG_DIR + "game_config.csv"
const CAMERA_CONFIG = CONFIG_DIR + "camera_config.csv"
const MAP_CONFIG = CONFIG_DIR + "map_config.csv"
const UPGRADE_ATTRIBUTES = CONFIG_DIR + "upgrade_attributes.csv"
const CHEST_CONFIG = CONFIG_DIR + "chest_config.csv"
const WAVE_CHEST_CONFIG = CONFIG_DIR + "wave_chest_config.csv"
const SOUND_CONFIG = CONFIG_DIR + "sound_config.csv"

# ============================================================================
# 初始化
# ============================================================================

func _ready() -> void:
	"""
	Godot 生命周期函数，节点准备就绪时调用
	在这里加载所有配置文件
	"""
	print("=== 配置管理器初始化 ===")
	load_all_configs()
	print("=== 配置加载完成 ===")

# ============================================================================
# 配置加载
# ============================================================================

func load_all_configs() -> void:
	"""
	加载所有 CSV 配置文件
	
	说明:
	- 按照依赖顺序加载配置
	- 使用不同的加载方法处理不同格式的配置
	- load_csv_as_dict: 多行数据，以某列为 key
	- load_csv_as_array: 多行数据，返回数组
	- load_csv_as_single: 单行数据，返回字典
	"""
	# 玩家配置
	player_configs = load_csv_as_dict(PLAYER_CONFIG, "player_id")
	player_visual_configs = load_csv_as_dict(PLAYER_VISUAL, "player_id")
	player_weapon_configs = load_csv_as_dict(PLAYER_WEAPONS, "player_id")
	
	# 敌人配置
	enemy_configs = load_csv_as_dict(ENEMY_CONFIG, "enemy_id")
	enemy_visual_configs = load_csv_as_dict(ENEMY_VISUAL, "enemy_id")
	enemy_weapon_configs = load_csv_as_dict(ENEMY_WEAPONS, "enemy_id")
	
	# 武器配置
	weapon_configs = load_csv_as_dict(WEAPON_CONFIG, "weapon_id")
	
	# 输入配置
	input_configs = load_csv_as_dict(INPUT_CONFIG, "action")
	
	# 升级系统配置
	upgrade_attributes = load_csv_as_dict(UPGRADE_ATTRIBUTES, "attribute_id")
	
	# 宝箱系统配置
	chest_configs = load_csv_as_dict(CHEST_CONFIG, "chest_tier")
	wave_chest_configs = load_csv_as_array(WAVE_CHEST_CONFIG)
	
	# 音效配置
	sound_configs = load_csv_as_dict(SOUND_CONFIG, "sound_id")
	
	# 全局配置
	game_config = load_csv_as_single(GAME_CONFIG)
	camera_config = load_csv_as_single(CAMERA_CONFIG)
	map_config = load_csv_as_single(MAP_CONFIG)

# ============================================================================
# CSV 加载方法
# ============================================================================

func load_csv_as_dict(path: String, key_column: String) -> Dictionary:
	"""
	加载 CSV 文件为字典（多行数据，以某列为 key）
	
	参数:
	- path: CSV 文件路径
	- key_column: 作为字典 key 的列名
	
	返回:
	- Dictionary: {key_value: {column: value, ...}, ...}
	
	CSV 格式:
	- 第一行: 列名
	- 第二行: 注释行（第一列为 -1）
	- 第三行及以后: 数据行
	
	示例:
	  player_id,health,speed
	  -1,玩家ID,生命值,速度
	  player_1,100,300
	  
	  返回: {"player_1": {"player_id": "player_1", "health": 100, "speed": 300}}
	"""
	var result = {}
	var file = FileAccess.open(path, FileAccess.READ)
	
	if not file:
		print("[ConfigManager] 警告: 无法打开文件 ", path)
		return result
	
	var headers = []
	var line_num = 0
	
	while not file.eof_reached():
		var line = file.get_csv_line()
		line_num += 1
		
		# 跳过空行
		if line.size() == 0 or (line.size() == 1 and line[0].strip_edges() == ""):
			continue
		
		# 第一行：列名
		if line_num == 1:
			headers = line
			continue
		
		# 第二行：如果第一列是 -1，跳过（注释行）
		if line_num == 2 and line[0].strip_edges() == "-1":
			continue
		
		# 数据行
		if headers.size() > 0:
			var row_data = {}
			var key_value = ""
			
			for i in range(min(line.size(), headers.size())):
				var header = headers[i].strip_edges()
				var value = line[i].strip_edges()
				
				# 记录 key 列的值
				if header == key_column:
					key_value = value
				
				# 尝试转换数值
				if value.is_valid_float():
					row_data[header] = float(value)
				elif value.is_valid_int():
					row_data[header] = int(value)
				else:
					row_data[header] = value
			
			if key_value != "":
				result[key_value] = row_data
	
	file.close()
	print("[ConfigManager] 加载配置: ", path, " - ", result.size(), " 条记录")
	return result

func load_csv_as_single(path: String) -> Dictionary:
	"""
	加载 CSV 文件为单个配置对象（只有一行数据）
	
	参数:
	- path: CSV 文件路径
	
	返回:
	- Dictionary: {column: value, ...}
	
	说明:
	- 用于只有一行数据的配置文件（如游戏全局设置）
	- 只读取第一行数据
	
	示例:
	  setting,value
	  -1,设置名,值
	  max_enemies,100
	  
	  返回: {"setting": "max_enemies", "value": 100}
	"""
	var result = {}
	var file = FileAccess.open(path, FileAccess.READ)
	
	if not file:
		print("[ConfigManager] 警告: 无法打开文件 ", path)
		return result
	
	var headers = []
	var line_num = 0
	
	while not file.eof_reached():
		var line = file.get_csv_line()
		line_num += 1
		
		# 跳过空行
		if line.size() == 0 or (line.size() == 1 and line[0].strip_edges() == ""):
			continue
		
		# 第一行：列名
		if line_num == 1:
			headers = line
			continue
		
		# 第二行：如果第一列是 -1，跳过（注释行）
		if line_num == 2 and line[0].strip_edges() == "-1":
			continue
		
		# 数据行（只取第一行）
		if headers.size() > 0:
			for i in range(min(line.size(), headers.size())):
				var header = headers[i].strip_edges()
				var value = line[i].strip_edges()
				
				# 尝试转换数值
				if value.is_valid_float():
					result[header] = float(value)
				elif value.is_valid_int():
					result[header] = int(value)
				else:
					result[header] = value
			break  # 只读第一行数据
	
	file.close()
	print("[ConfigManager] 加载配置: ", path, " - ", result.size(), " 个字段")
	return result

# ============================================================================
# 便捷访问方法
# ============================================================================

func get_player_config(player_id: String) -> Dictionary:
	return player_configs.get(player_id, {})

func get_player_visual(player_id: String) -> Dictionary:
	return player_visual_configs.get(player_id, {})

func get_player_weapons(player_id: String) -> Dictionary:
	return player_weapon_configs.get(player_id, {})

func get_weapon_config(weapon_id: String) -> Dictionary:
	return weapon_configs.get(weapon_id, {})

func get_enemy_config(enemy_id: String) -> Dictionary:
	return enemy_configs.get(enemy_id, {})

func get_enemy_visual(enemy_id: String) -> Dictionary:
	return enemy_visual_configs.get(enemy_id, {})

func get_enemy_weapons(enemy_id: String) -> Dictionary:
	return enemy_weapon_configs.get(enemy_id, {})

func get_input_mapping(action: String) -> Dictionary:
	return input_configs.get(action, {})

func get_game_setting(key: String, default_value = null):
	return game_config.get(key, default_value)

func get_camera_setting(key: String, default_value = null):
	return camera_config.get(key, default_value)

func get_map_setting(key: String, default_value = null):
	return map_config.get(key, default_value)

func get_upgrade_attribute(attribute_id: String) -> Dictionary:
	return upgrade_attributes.get(attribute_id, {})

func get_chest_config(tier: int) -> Dictionary:
	return chest_configs.get(str(tier), {})

func get_all_upgrade_attributes() -> Dictionary:
	return upgrade_attributes

func get_all_chest_configs() -> Dictionary:
	return chest_configs

func get_sound_config(sound_id: String) -> Dictionary:
	return sound_configs.get(sound_id, {})

func get_all_sound_configs() -> Dictionary:
	return sound_configs

func load_csv_as_array(path: String) -> Array[Dictionary]:
	"""
	加载 CSV 文件为数组（多行数据）
	
	参数:
	- path: CSV 文件路径
	
	返回:
	- Array[Dictionary]: [{column: value, ...}, ...]
	
	说明:
	- 用于需要保持顺序的配置（如波次配置）
	- 返回数组，每个元素是一行数据的字典
	
	示例:
	  wave,min_tier,max_tier
	  -1,波次,最小等级,最大等级
	  1,1,2
	  2,2,3
	  
	  返回: [
	    {"wave": 1, "min_tier": 1, "max_tier": 2},
	    {"wave": 2, "min_tier": 2, "max_tier": 3}
	  ]
	"""
	var result: Array[Dictionary] = []
	var file = FileAccess.open(path, FileAccess.READ)
	
	if not file:
		print("[ConfigManager] 警告: 无法打开文件 ", path)
		return result
	
	var headers = []
	var line_num = 0
	
	while not file.eof_reached():
		var line = file.get_csv_line()
		line_num += 1
		
		# 跳过空行
		if line.size() == 0 or (line.size() == 1 and line[0].strip_edges() == ""):
			continue
		
		# 第一行：列名
		if line_num == 1:
			headers = line
			continue
		
		# 第二行：如果第一列是 -1，跳过（注释行）
		if line_num == 2 and line[0].strip_edges() == "-1":
			continue
		
		# 数据行
		if headers.size() > 0:
			var row_data = {}
			
			for i in range(min(line.size(), headers.size())):
				var header = headers[i].strip_edges()
				var value = line[i].strip_edges()
				
				# 尝试转换数值
				if value.is_valid_float():
					row_data[header] = float(value)
				elif value.is_valid_int():
					row_data[header] = int(value)
				else:
					row_data[header] = value
			
			result.append(row_data)
	
	file.close()
	print("[ConfigManager] 加载配置: ", path, " - ", result.size(), " 条记录")
	return result

# 根据波次获取宝箱配置
func get_wave_chest_config(wave_index: int) -> Dictionary:
	for config in wave_chest_configs:
		var start = config.get("wave_range_start", 1)
		var end = config.get("wave_range_end", 999)
		if wave_index >= start and wave_index <= end:
			return config
	
	# 返回默认配置
	if wave_chest_configs.size() > 0:
		return wave_chest_configs[0]
	
	return {}
