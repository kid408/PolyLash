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
#   var config = ConfigManager.get_player_config("shaman")
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
var player_skill_bindings: Dictionary = {}       # 玩家技能绑定 (player_id -> bindings)
var player_available_weapons: Dictionary = {}    # 玩家可用武器类型 (player_id -> weapon_types)
var skill_params: Dictionary = {}                # 技能参数配置 (skill_id -> params)

# 敌人相关配置
var enemy_configs: Dictionary = {}               # 敌人基础属性配置 (enemy_id -> config)
var enemy_visual_configs: Dictionary = {}        # 敌人视觉配置 (enemy_id -> visual)
var enemy_weapon_configs: Dictionary = {}        # 敌人武器配置 (enemy_id -> weapons)

# 武器配置
var weapon_configs: Dictionary = {}              # 武器属性配置 (weapon_id -> config)

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

# 新格式道具配置（合并后的统一道具配置）
var item_configs_new: Dictionary = {}            # 新格式道具配置 (item_id -> config)

# 团队护符配置
var emblem_configs: Dictionary = {}              # 护符配置 (emblem_id -> config)

# 致谢配置
var credits_configs: Array[Dictionary] = []      # 致谢条目配置 (数组，按顺序)

# 配置文件路径
const CONFIG_DIR = "res://config/"
const PLAYER_CONFIG = CONFIG_DIR + "player/player_config.csv"
const PLAYER_VISUAL = CONFIG_DIR + "player/player_visual.csv"
const PLAYER_WEAPONS = CONFIG_DIR + "player/player_weapons.csv"
const PLAYER_SKILL_BINDINGS = CONFIG_DIR + "player/player_skill_bindings.csv"
const SKILL_PARAMS = CONFIG_DIR + "player/skill_params_wide.csv"
const ULT_CONFIG = CONFIG_DIR + "player/ult_config.csv"
const PLAYER_AVAILABLE_WEAPONS = CONFIG_DIR + "player/player_available_weapons.csv"
const ENEMY_CONFIG = CONFIG_DIR + "enemy/enemy_config.csv"
const ENEMY_VISUAL = CONFIG_DIR + "enemy/enemy_visual.csv"
const ENEMY_WEAPONS = CONFIG_DIR + "enemy/enemy_weapons.csv"
const WEAPON_CONFIG = CONFIG_DIR + "weapon/weapon_config_optimized.csv"
const WAVE_CONFIG = CONFIG_DIR + "wave/wave_config.csv"
const WAVE_UNITS_CONFIG = CONFIG_DIR + "wave/wave_units_config.csv"
const INPUT_CONFIG = CONFIG_DIR + "system/input_config.csv"
const GAME_CONFIG = CONFIG_DIR + "system/game_config.csv"
const CAMERA_CONFIG = CONFIG_DIR + "system/camera_config.csv"
const MAP_CONFIG = CONFIG_DIR + "system/map_config.csv"
const UPGRADE_ATTRIBUTES = CONFIG_DIR + "item/upgrade_attributes.csv"
const CHEST_CONFIG = CONFIG_DIR + "item/chest_config.csv"
const WAVE_CHEST_CONFIG = CONFIG_DIR + "wave/wave_chest_config.csv"
const ITEM_CONFIG_NEW = CONFIG_DIR + "item/item_config.csv"
const EMBLEM_CONFIG = CONFIG_DIR + "item/emblem_config.csv"
const CREDITS_CONFIG = CONFIG_DIR + "system/credits_config.csv"
const LEGACY_PLAYER_ID_ALIASES: Dictionary = {
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

# ============================================================================
# 初始化
# ============================================================================

var ult_configs: Dictionary = {}

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
	player_skill_bindings = load_csv_as_dict(PLAYER_SKILL_BINDINGS, "player_id")
	player_available_weapons = load_csv_as_dict(PLAYER_AVAILABLE_WEAPONS, "player_id")
	skill_params = load_skill_params_wide_format(SKILL_PARAMS)
	ult_configs = load_csv_as_dict(ULT_CONFIG, "ult_id")
	
	# 敌人配置
	enemy_configs = load_csv_as_dict(ENEMY_CONFIG, "enemy_id")
	enemy_visual_configs = load_csv_as_dict(ENEMY_VISUAL, "enemy_id")
	enemy_weapon_configs = load_csv_as_dict(ENEMY_WEAPONS, "enemy_id")
	
	# 武器配置
	weapon_configs = load_csv_as_dict(WEAPON_CONFIG, "weapon_base_id")
	
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
	
	# 全局配置 (key-value 格式)
	game_config = _load_key_value_config(GAME_CONFIG)
	camera_config = _load_key_value_config(CAMERA_CONFIG)
	map_config = _load_key_value_config(MAP_CONFIG)
	
	# 新格式道具配置
	_load_item_configs_new()
	
	# 团队护符配置
	_load_emblem_configs()
	
	# 致谢配置
	_load_credits_configs()

# ============================================================================
# CSV 加载方法
# ============================================================================

func load_skill_params_wide_format(path: String) -> Dictionary:
	"""
	加载宽表格式的 skill_params CSV 文件
	
	参数:
	- path: CSV 文件路径
	
	返回:
	- Dictionary: {skill_id: {param_name: param_value, ...}, ...}
	
	CSV 格式:
	- 第一行: 列名 (skill_id, energy_cost, cooldown, ..., param1, param1_note, ...)
	- 第二行: 注释行（第一列为 -1）
	- 第三行及以后: 数据行，每行一个技能
	
	通用列（列名即变量名）: energy_cost, cooldown, fixed_segment_length, dash_speed,
	  energy_per_10px, energy_threshold_distance, energy_scale_multiplier, base_line_duration
	描述列: desc_q_line, desc_q_circle, desc_e
	扩展列: param1~param10 + param1_note~param10_note
	  note格式: "中文说明(变量名)" — 括号内的英文名作为字典key
	"""
	var result: Dictionary = {}
	var file = FileAccess.open(path, FileAccess.READ)
	
	if not file:
		push_warning("[ConfigManager] 警告: 无法打开文件 %s" % path)
		return result
	
	var headers: PackedStringArray = []
	var line_num: int = 0
	
	# 通用列和描述列（列名直接作为key）
	var direct_cols: Array[String] = [
		"energy_cost", "cooldown", "fixed_segment_length", "dash_speed",
		"energy_per_10px", "energy_threshold_distance", "energy_scale_multiplier",
		"base_line_duration", "desc_q_line", "desc_q_circle", "desc_e", "tags"
	]
	
	# 列名 -> 索引 映射
	var col_indices: Dictionary = {}
	
	while not file.eof_reached():
		var line = file.get_csv_line()
		line_num += 1
		
		# 跳过空行
		if line.size() == 0 or (line.size() == 1 and line[0].strip_edges() == ""):
			continue
		
		# 第一行：列名
		if line_num == 1:
			headers = line
			for i in range(headers.size()):
				col_indices[headers[i].strip_edges()] = i
			continue
		
		# 第二行：注释行（第一列为 -1）
		if line[0].strip_edges() == "-1":
			continue
		
		var sid = line[0].strip_edges()
		if sid == "":
			continue
		
		var params: Dictionary = {}
		
		# 读取通用列和描述列
		for col_name in direct_cols:
			if not col_indices.has(col_name):
				continue
			var idx = col_indices[col_name]
			if idx >= line.size():
				continue
			var val_str = line[idx].strip_edges()
			if val_str == "":
				continue
			params[col_name] = _convert_value(val_str)
		
		# 读取扩展列 param1~param10
		for i in range(1, 11):
			var param_col = "param%d" % i
			var note_col = "param%d_note" % i
			if not col_indices.has(param_col) or not col_indices.has(note_col):
				continue
			var param_idx = col_indices[param_col]
			var note_idx = col_indices[note_col]
			if param_idx >= line.size() or note_idx >= line.size():
				continue
			var val_str = line[param_idx].strip_edges()
			var note_str = line[note_idx].strip_edges()
			if val_str == "" or note_str == "":
				continue
			# 从 note 提取变量名: "中文说明(变量名)" -> "变量名"
			var var_name = _extract_var_name(note_str)
			if var_name != "":
				params[var_name] = _convert_value(val_str)
		
		result[sid] = params
	
	file.close()
	var desc_count = 0
	for sid in result:
		for pname in result[sid]:
			if str(pname).begins_with("desc_"):
				desc_count += 1
	print("[ConfigManager] 加载宽表技能参数: ", path, " - ", result.size(), " 个技能, ", desc_count, " 条描述")
	return result

func _extract_var_name(note: String) -> String:
	"""从 note 字符串提取变量名: '中文说明(var_name)' -> 'var_name'"""
	var start = note.find("(")
	var end = note.find(")")
	if start >= 0 and end > start:
		return note.substr(start + 1, end - start - 1).strip_edges()
	# 如果没有括号，整个字符串作为变量名（纯英文的情况）
	return note.strip_edges()

func _convert_value(value_str: String):
	"""
	将字符串值转换为合适的类型（int、float 或保留字符串）
	
	转换规则:
	- 优先尝试 int（纯整数字符串）
	- 其次尝试 float（含小数点的数值字符串）
	- 否则保留为字符串
	"""
	if value_str.is_valid_int():
		return int(value_str)
	if value_str.is_valid_float():
		return float(value_str)
	return value_str

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

func _load_key_value_config(path: String) -> Dictionary:
	"""
	加载 key-value 格式的 CSV 配置文件
	
	格式:
	  setting,value,description
	  -1,值,说明
	  key1,value1,desc1
	  key2,value2,desc2
	
	返回:
	  {key1: value1, key2: value2, ...}
	"""
	var result = {}
	var file = FileAccess.open(path, FileAccess.READ)
	
	if not file:
		print("[ConfigManager] 警告: 无法打开文件 ", path)
		return result
	
	var line_num = 0
	
	while not file.eof_reached():
		var line = file.get_csv_line()
		line_num += 1
		
		# 跳过空行
		if line.size() == 0 or (line.size() == 1 and line[0].strip_edges() == ""):
			continue
		
		# 第一行：列名，跳过
		if line_num == 1:
			continue
		
		# 第二行：如果第一列是 -1，跳过（注释行）
		if line_num == 2 and line[0].strip_edges() == "-1":
			continue
		
		# 数据行：setting, value, description
		if line.size() >= 2:
			var key = line[0].strip_edges()
			var value_str = line[1].strip_edges()
			
			if key == "":
				continue
			
			# 尝试转换数值
			var value
			if value_str.is_valid_float():
				value = float(value_str)
			elif value_str.is_valid_int():
				value = int(value_str)
			else:
				value = value_str
			
			result[key] = value
	
	file.close()
	print("[ConfigManager] 加载 key-value 配置: ", path, " - ", result.size(), " 条记录")
	return result

# ============================================================================
# 便捷访问方法
# ============================================================================

func normalize_player_id(player_id: String) -> String:
	if player_id.is_empty():
		return player_id
	return str(LEGACY_PLAYER_ID_ALIASES.get(player_id, player_id))

func get_player_config(player_id: String) -> Dictionary:
	var normalized_player_id := normalize_player_id(player_id)
	return player_configs.get(normalized_player_id, {})

func get_player_visual(player_id: String) -> Dictionary:
	var normalized_player_id := normalize_player_id(player_id)
	return player_visual_configs.get(normalized_player_id, {})

func get_player_weapons(player_id: String) -> Dictionary:
	var normalized_player_id := normalize_player_id(player_id)
	return player_weapon_configs.get(normalized_player_id, {})

func get_player_skill_bindings(player_id: String) -> Dictionary:
	var normalized_player_id := normalize_player_id(player_id)
	return player_skill_bindings.get(normalized_player_id, {})

func get_all_player_configs() -> Dictionary:
	return player_configs

func get_skill_params(skill_id: String) -> Dictionary:
	return skill_params.get(skill_id, {})

func get_ult_config(ult_id: String) -> Dictionary:
	return ult_configs.get(ult_id, {})

func get_player_ult_config(player_id: String) -> Dictionary:
	var normalized_player_id := normalize_player_id(player_id)
	return ult_configs.get("%s_ult" % normalized_player_id, {})

func get_weapon_config(weapon_id: String) -> Dictionary:
	return weapon_configs.get(weapon_id, {})

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

# ============================================================================
# 新格式道具配置加载与访问
# ============================================================================

func _load_item_configs_new() -> void:
	"""
	加载新格式 item_config.csv 并缓存到 item_configs_new
	
	新格式字段: id, name, tier, type, slot_type, base_stat, base_value,
	            mod_type, mod_value, bond_grant, shop_price, icon_path, description
	
	mod_type 和 mod_value 支持分号分隔的多修正（如 "attack_speed;switch_cd_reduce_pct" / "0.15;0.25"）
	"""
	item_configs_new.clear()
	var file = FileAccess.open(ITEM_CONFIG_NEW, FileAccess.READ)
	
	if not file:
		push_warning("[ConfigManager] 警告: 无法打开新格式道具配置 %s" % ITEM_CONFIG_NEW)
		return
	
	var headers: PackedStringArray = []
	var line_num: int = 0
	
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
		
		# 第二行：注释行（第一列为 -1）
		if line_num == 2 and line[0].strip_edges() == "-1":
			continue
		
		if headers.size() == 0:
			continue
		
		var row_data: Dictionary = {}
		for i in range(mini(line.size(), headers.size())):
			var header = headers[i].strip_edges()
			var value = line[i].strip_edges()
			
			# tier、base_value、shop_price 转为数值
			if header in ["tier", "base_value", "shop_price"]:
				if value.is_valid_float():
					row_data[header] = float(value)
				elif value.is_valid_int():
					row_data[header] = int(value)
				else:
					row_data[header] = 0
			else:
				row_data[header] = value
		
		var item_id = row_data.get("id", "")
		if item_id == "":
			continue
		
		# 解析多修正字段
		var mod_type_str = str(row_data.get("mod_type", ""))
		var mod_value_str = str(row_data.get("mod_value", ""))
		row_data["modifiers"] = _parse_modifiers(mod_type_str, mod_value_str)
		
		item_configs_new[item_id] = row_data
	
	file.close()
	print("[ConfigManager] 加载新格式道具配置: %s - %d 条记录" % [ITEM_CONFIG_NEW, item_configs_new.size()])

func _parse_modifiers(mod_type_str: String, mod_value_str: String) -> Array:
	"""
	解析分号分隔的多修正字段
	
	参数:
	- mod_type_str: 修正类型字符串，如 "attack_speed;switch_cd_reduce_pct"
	- mod_value_str: 修正值字符串，如 "0.15;0.25"
	
	返回:
	- Array: [{"type": "attack_speed", "value": 0.15}, {"type": "switch_cd_reduce_pct", "value": 0.25}]
	"""
	var modifiers: Array = []
	if mod_type_str.is_empty():
		return modifiers
	var types = mod_type_str.split(";")
	var values = mod_value_str.split(";")
	for i in range(types.size()):
		modifiers.append({
			"type": types[i].strip_edges(),
			"value": float(values[i].strip_edges()) if i < values.size() else 0.0
		})
	return modifiers

func get_item_config_by_id(item_id: String) -> Dictionary:
	"""
	通过 item_id 获取新格式道具配置
	
	参数:
	- item_id: 道具唯一标识符（如 "relic_colossus", "potion_heal"）
	
	返回:
	- Dictionary: 完整的道具配置，包含 modifiers 数组；未找到返回空字典
	"""
	return item_configs_new.get(item_id, {})

# ============================================================================
# 团队护符配置加载与访问
# ============================================================================

func _load_emblem_configs() -> void:
	"""
	加载 emblem_config.csv 并缓存到 emblem_configs
	
	字段: emblem_id, display_name, artifact_type, bond_tag, rarity,
	      shop_price, is_unique, icon_path, description
	
	shop_price 和 is_unique 解析为数值，其余字段保留为字符串。
	"""
	emblem_configs.clear()
	var file = FileAccess.open(EMBLEM_CONFIG, FileAccess.READ)
	
	if not file:
		push_warning("[ConfigManager] 警告: 无法打开护符配置 %s" % EMBLEM_CONFIG)
		return
	
	var headers: PackedStringArray = []
	var line_num: int = 0
	
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
		
		# 第二行：注释行（第一列为 -1）
		if line_num == 2 and line[0].strip_edges() == "-1":
			continue
		
		if headers.size() == 0:
			continue
		
		var row_data: Dictionary = {}
		for i in range(mini(line.size(), headers.size())):
			var header = headers[i].strip_edges()
			var value = line[i].strip_edges()
			
			# shop_price 和 is_unique 转为数值
			if header in ["shop_price", "is_unique"]:
				if value.is_valid_int():
					row_data[header] = int(value)
				elif value.is_valid_float():
					row_data[header] = float(value)
				else:
					row_data[header] = 0
			else:
				row_data[header] = value
		
		var emblem_id = row_data.get("emblem_id", "")
		if emblem_id == "":
			continue
		
		emblem_configs[emblem_id] = row_data
	
	file.close()
	print("[ConfigManager] 加载护符配置: %s - %d 条记录" % [EMBLEM_CONFIG, emblem_configs.size()])

func get_emblem_config(emblem_id: String) -> Dictionary:
	"""
	通过 emblem_id 获取护符配置
	
	参数:
	- emblem_id: 护符唯一标识符（如 "emblem_inkborn", "relic_gold_ink"）
	
	返回:
	- Dictionary: 完整的护符配置；未找到返回空字典
	"""
	return emblem_configs.get(emblem_id, {})

func get_all_emblem_configs() -> Dictionary:
	"""
	获取所有护符配置
	
	返回:
	- Dictionary: {emblem_id: config_dict, ...}
	"""
	return emblem_configs

func get_emblems_by_bond_tag(bond_tag: String) -> Array:
	"""
	获取指定羁绊标签的所有护符配置
	
	参数:
	- bond_tag: 羁绊标签（如 "inkborn", "colossus"）
	
	返回:
	- Array: 匹配的护符配置数组
	"""
	var result: Array = []
	for emblem_id in emblem_configs:
		var config = emblem_configs[emblem_id]
		if config.get("bond_tag", "") == bond_tag:
			result.append(config)
	return result

# ============================================================================
# 角色选择相关方法
# ============================================================================

func get_enabled_players() -> Array[Dictionary]:
	"""
	获取所有启用的角色配置（按display_order排序）
	
	返回:
	- Array[Dictionary]: 启用的角色配置数组，按display_order升序排列
	"""
	var result: Array[Dictionary] = []
	for player_id in player_configs.keys():
		var config = player_configs[player_id]
		if int(config.get("enabled", 0)) == 1:
			result.append(config)
	
	# 按 display_order 排序
	result.sort_custom(func(a, b): return a.get("display_order", 999) < b.get("display_order", 999))
	return result

func get_player_available_weapon_types(player_id: String) -> Array[String]:
	"""
	获取角色可用武器类型列表
	
	参数:
	- player_id: 角色ID
	
	返回:
	- Array[String]: 可用武器类型数组（如 ["punch", "laser"]）
	"""
	var normalized_player_id := normalize_player_id(player_id)
	var config = player_available_weapons.get(normalized_player_id, {})
	var weapons: Array[String] = []
	for i in range(1, 5):
		var weapon_type = config.get("weapon_type_%d" % i, "")
		if weapon_type != "" and weapon_type != null:
			weapons.append(str(weapon_type))
	return weapons

func get_weapon_by_type_level(weapon_type: String, level: int = 1) -> Dictionary:
	"""
	获取指定类型和等级的武器配置
	
	参数:
	- weapon_type: 武器类型（如 "punch", "laser"）
	- level: 武器等级（默认1）
	
	返回:
	- Dictionary: 武器配置，如果未找到返回空字典
	
	注意: 此函数返回基础配置（weapon_base_id），不包含等级缩放
	      如需完整的武器数据，请使用 WeaponConfigLoader.get_weapon_stats()
	"""
	# 新系统：weapon_configs 使用 weapon_base_id 作为键
	return weapon_configs.get(weapon_type, {})

func get_weapons_by_type(weapon_type: String) -> Array[Dictionary]:
	"""
	获取指定类型的所有武器配置
	
	参数:
	- weapon_type: 武器类型（如 "punch", "laser"）
	
	返回:
	- Array[Dictionary]: 该类型所有武器的配置数组
	"""
	var result: Array[Dictionary] = []
	for weapon_id in weapon_configs.keys():
		var config = weapon_configs[weapon_id]
		if config.get("type", "") == weapon_type:
			result.append(config)
	return result

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

# ============================================================================
# 致谢配置加载与访问
# ============================================================================

func _load_credits_configs() -> void:
	"""
	加载 credits_config.csv 并缓存到 credits_configs
	
	字段: id, category, asset_name, author, license_type, url, description
	
	使用 Array 存储以保持条目顺序。
	"""
	credits_configs.clear()
	var file = FileAccess.open(CREDITS_CONFIG, FileAccess.READ)
	
	if not file:
		push_warning("[ConfigManager] 警告: 无法打开致谢配置 %s" % CREDITS_CONFIG)
		return
	
	var headers: PackedStringArray = []
	var line_num: int = 0
	
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
		
		# 第二行：注释行（第一列为 -1）
		if line_num == 2 and line[0].strip_edges() == "-1":
			continue
		
		if headers.size() == 0:
			continue
		
		var row_data: Dictionary = {}
		for i in range(mini(line.size(), headers.size())):
			var header = headers[i].strip_edges()
			var value = line[i].strip_edges()
			row_data[header] = value
		
		var entry_id = row_data.get("id", "")
		if entry_id == "":
			continue
		
		credits_configs.append(row_data)
	
	file.close()
	print("[ConfigManager] 加载致谢配置: %s - %d 条记录" % [CREDITS_CONFIG, credits_configs.size()])

func get_credits_configs() -> Array[Dictionary]:
	"""
	获取所有致谢配置条目
	
	返回:
	- Array[Dictionary]: 致谢条目数组，每个条目包含 id, category, asset_name, author, license_type, url, description
	"""
	return credits_configs
