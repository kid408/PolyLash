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
# 目录结构:
#   config/
#   ├── system/   - 系统配置（游戏、地图、摄像机、输入、音效）
#   ├── player/   - 玩家配置（属性、视觉、武器）
#   ├── enemy/    - 敌人配置（属性、视觉、武器）
#   ├── weapon/   - 武器配置（基础、详细属性）
#   ├── wave/     - 波次配置（波次、单位、宝箱）
#   └── item/     - 物品配置（宝箱、升级属性）
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
var player_skill_configs: Dictionary = {}        # 玩家技能配置 (player_id -> skills)
var player_skill_bindings: Dictionary = {}       # 玩家技能绑定 (player_id -> bindings)
var skill_params: Dictionary = {}                # 技能参数配置 (skill_id -> params)

# 敌人相关配置
var enemy_configs: Dictionary = {}               # 敌人基础属性配置 (enemy_id -> config)
var enemy_visual_configs: Dictionary = {}        # 敌人视觉配置 (enemy_id -> visual)
var enemy_weapon_configs: Dictionary = {}        # 敌人武器配置 (enemy_id -> weapons)

# 武器配置
var weapon_configs: Dictionary = {}              # 武器属性配置 (weapon_id -> config)
var weapon_stats_configs: Dictionary = {}        # 武器详细属性配置 (weapon_id -> stats)

# 波次配置
var wave_configs: Dictionary = {}                # 波次配置 (wave_id -> config)
var wave_units_configs: Dictionary = {}          # 波次单位配置 (wave_id -> [units])

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
const PLAYER_CONFIG = CONFIG_DIR + "player/player_config.csv"
const PLAYER_VISUAL = CONFIG_DIR + "player/player_visual.csv"
const PLAYER_WEAPONS = CONFIG_DIR + "player/player_weapons.csv"
const PLAYER_SKILLS = CONFIG_DIR + "player/player_skills.csv"
const PLAYER_SKILL_BINDINGS = CONFIG_DIR + "player/player_skill_bindings.csv"
const SKILL_PARAMS = CONFIG_DIR + "player/skill_params.csv"
const ENEMY_CONFIG = CONFIG_DIR + "enemy/enemy_config.csv"
const ENEMY_VISUAL = CONFIG_DIR + "enemy/enemy_visual.csv"
const ENEMY_WEAPONS = CONFIG_DIR + "enemy/enemy_weapons.csv"
const WEAPON_CONFIG = CONFIG_DIR + "weapon/weapon_config.csv"
const WEAPON_STATS_CONFIG = CONFIG_DIR + "weapon/weapon_stats_config.csv"
const WAVE_CONFIG = CONFIG_DIR + "wave/wave_config.csv"
const WAVE_UNITS_CONFIG = CONFIG_DIR + "wave/wave_units_config.csv"
const INPUT_CONFIG = CONFIG_DIR + "system/input_config.csv"
const GAME_CONFIG = CONFIG_DIR + "system/game_config.csv"
const CAMERA_CONFIG = CONFIG_DIR + "system/camera_config.csv"
const MAP_CONFIG = CONFIG_DIR + "system/map_config.csv"
const UPGRADE_ATTRIBUTES = CONFIG_DIR + "item/upgrade_attributes.csv"
const CHEST_CONFIG = CONFIG_DIR + "item/chest_config.csv"
const WAVE_CHEST_CONFIG = CONFIG_DIR + "wave/wave_chest_config.csv"
const SOUND_CONFIG = CONFIG_DIR + "system/sound_config.csv"

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
	player_skill_configs = load_csv_as_dict(PLAYER_SKILLS, "player_id")
	player_skill_bindings = load_csv_as_dict(PLAYER_SKILL_BINDINGS, "player_id")
	skill_params = load_csv_as_dict(SKILL_PARAMS, "skill_id")
	
	# 敌人配置
	enemy_configs = load_csv_as_dict(ENEMY_CONFIG, "enemy_id")
	enemy_visual_configs = load_csv_as_dict(ENEMY_VISUAL, "enemy_id")
	enemy_weapon_configs = load_csv_as_dict(ENEMY_WEAPONS, "enemy_id")
	
	# 武器配置
	weapon_configs = load_csv_as_dict(WEAPON_CONFIG, "weapon_id")
	weapon_stats_configs = load_csv_as_dict(WEAPON_STATS_CONFIG, "weapon_id")
	
	# 波次配置
	wave_configs = load_csv_as_dict(WAVE_CONFIG, "wave_id")
	wave_units_configs = load_wave_units_grouped(WAVE_UNITS_CONFIG)
	
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

func get_player_skills(player_id: String) -> Dictionary:
	return player_skill_configs.get(player_id, {})

func get_player_skill_bindings(player_id: String) -> Dictionary:
	return player_skill_bindings.get(player_id, {})

func get_skill_params(skill_id: String) -> Dictionary:
	return skill_params.get(skill_id, {})

func get_weapon_config(weapon_id: String) -> Dictionary:
	return weapon_configs.get(weapon_id, {})

func get_weapon_stats(weapon_id: String) -> Dictionary:
	return weapon_stats_configs.get(weapon_id, {})

func get_wave_config(wave_id: String) -> Dictionary:
	return wave_configs.get(wave_id, {})

func get_wave_units(wave_id: String) -> Array:
	return wave_units_configs.get(wave_id, [])

func get_enemy_config(enemy_id: String) -> Dictionary:
	return enemy_configs.get(enemy_id, {})

func get_enemy_visual(enemy_id: String) -> Dictionary:
	return enemy_visual_configs.get(enemy_id, {})

func get_enemy_weapons(enemy_id: String) -> Dictionary:
	return enemy_weapon_configs.get(enemy_id, {})

func get_input_mapping(action: String) -> Dictionary:
	return input_configs.get(action, {})

func get_game_setting(key: String, default_value = null):
	if not game_config.has(key) and default_value != null:
		push_warning("[ConfigManager] game_config 缺少键 '%s'，使用默认值: %s" % [key, str(default_value)])
	return game_config.get(key, default_value)

func get_camera_setting(key: String, default_value = null):
	if not camera_config.has(key) and default_value != null:
		push_warning("[ConfigManager] camera_config 缺少键 '%s'，使用默认值: %s" % [key, str(default_value)])
	return camera_config.get(key, default_value)

func get_map_setting(key: String, default_value = null):
	if not map_config.has(key) and default_value != null:
		push_warning("[ConfigManager] map_config 缺少键 '%s'，使用默认值: %s" % [key, str(default_value)])
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

# ============================================================================
# 配置值获取辅助方法（带默认值回退和警告）
# ============================================================================

func get_config_value(config: Dictionary, key: String, default_value, config_name: String = "config"):
	"""
	从配置字典中获取值，缺失时使用默认值并输出警告
	
	参数:
	- config: 配置字典
	- key: 键名
	- default_value: 默认值
	- config_name: 配置名称（用于警告信息）
	
	返回:
	- 配置值或默认值
	"""
	if not config.has(key):
		if default_value != null:
			push_warning("[ConfigManager] %s 缺少键 '%s'，使用默认值: %s" % [config_name, key, str(default_value)])
		return default_value
	return config.get(key)

func get_skill_param_value(skill_id: String, key: String, default_value = null):
	"""
	获取技能参数值，缺失时使用默认值并输出警告
	
	参数:
	- skill_id: 技能ID
	- key: 参数键名
	- default_value: 默认值
	
	返回:
	- 参数值或默认值
	"""
	var params = get_skill_params(skill_id)
	if params.is_empty():
		push_warning("[ConfigManager] 未找到技能配置 '%s'，使用默认值: %s" % [skill_id, str(default_value)])
		return default_value
	return get_config_value(params, key, default_value, "skill_params[%s]" % skill_id)

func get_enemy_config_value(enemy_id: String, key: String, default_value = null):
	"""
	获取敌人配置值，缺失时使用默认值并输出警告
	
	参数:
	- enemy_id: 敌人ID
	- key: 配置键名
	- default_value: 默认值
	
	返回:
	- 配置值或默认值
	"""
	var config = get_enemy_config(enemy_id)
	if config.is_empty():
		push_warning("[ConfigManager] 未找到敌人配置 '%s'，使用默认值: %s" % [enemy_id, str(default_value)])
		return default_value
	return get_config_value(config, key, default_value, "enemy_config[%s]" % enemy_id)

func get_enemy_visual_value(enemy_id: String, key: String, default_value = null):
	"""
	获取敌人视觉配置值，缺失时使用默认值并输出警告
	
	参数:
	- enemy_id: 敌人ID
	- key: 配置键名
	- default_value: 默认值
	
	返回:
	- 配置值或默认值
	"""
	var config = get_enemy_visual(enemy_id)
	if config.is_empty():
		push_warning("[ConfigManager] 未找到敌人视觉配置 '%s'，使用默认值: %s" % [enemy_id, str(default_value)])
		return default_value
	return get_config_value(config, key, default_value, "enemy_visual[%s]" % enemy_id)

func get_player_config_value(player_id: String, key: String, default_value = null):
	"""
	获取玩家配置值，缺失时使用默认值并输出警告
	
	参数:
	- player_id: 玩家ID
	- key: 配置键名
	- default_value: 默认值
	
	返回:
	- 配置值或默认值
	"""
	var config = get_player_config(player_id)
	if config.is_empty():
		push_warning("[ConfigManager] 未找到玩家配置 '%s'，使用默认值: %s" % [player_id, str(default_value)])
		return default_value
	return get_config_value(config, key, default_value, "player_config[%s]" % player_id)

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

func load_wave_units_grouped(path: String) -> Dictionary:
	"""
	加载波次单位配置并按wave_id分组
	
	参数:
	- path: CSV 文件路径
	
	返回:
	- Dictionary: {wave_id: [{enemy_scene: "...", weight: 1.0}, ...], ...}
	
	说明:
	- 将同一个wave_id的所有单位配置组合成数组
	- 用于波次系统快速查找某个波次的所有敌人配置
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
			var wave_id = ""
			
			for i in range(min(line.size(), headers.size())):
				var header = headers[i].strip_edges()
				var value = line[i].strip_edges()
				
				if header == "wave_id":
					wave_id = value
				
				# 尝试转换数值
				if value.is_valid_float():
					row_data[header] = float(value)
				elif value.is_valid_int():
					row_data[header] = int(value)
				else:
					row_data[header] = value
			
			# 按wave_id分组
			if wave_id != "":
				if not result.has(wave_id):
					result[wave_id] = []
				result[wave_id].append(row_data)
	
	file.close()
	print("[ConfigManager] 加载波次单位配置: ", path, " - ", result.size(), " 个波次")
	return result
