extends Node

# ============================================================================
# 存档管理器 - 负责存档数据的序列化、反序列化、读写和管理
# ============================================================================

const SAVE_DIR = "user://saves/"
const SAVE_FILE_TEMPLATE = "save_slot_%d.json"
const SETTINGS_PATH = "user://settings.json"
const MAX_SLOTS = 3
const CURRENT_VERSION = 1

signal save_slot_updated(slot_index: int)
signal settings_changed()

# 存档槽位缓存
var save_slots: Array[Dictionary] = [{}, {}, {}]

# 设置数据
var settings: Dictionary = {}

# 损坏槽位追踪（与 save_slots 索引对应）
var corrupted_slots: Array[bool] = [false, false, false]

# 必要字段定义及其期望类型
const REQUIRED_FIELDS: Dictionary = {
	"version": TYPE_FLOAT,
	"slot_index": TYPE_FLOAT,
	"leader_id": TYPE_STRING,
	"selected_players": TYPE_ARRAY,
	"current_floor": TYPE_FLOAT,
	"current_wave": TYPE_FLOAT,
	"play_time_seconds": TYPE_FLOAT,
	"last_played_timestamp": TYPE_FLOAT,
	"bond_summary": TYPE_ARRAY,
}

# ============================================================================
# 初始化
# ============================================================================

func _ready() -> void:
	_ensure_save_dir()
	_load_all_slots()
	_load_settings()

# ============================================================================
# 序列化与反序列化
# ============================================================================

func serialize_save_data(data: Dictionary) -> String:
	"""将存档字典序列化为格式化 JSON 字符串（制表符缩进）"""
	return JSON.stringify(data, "\t")


func deserialize_save_data(json_string: String) -> Dictionary:
	"""将 JSON 字符串反序列化为存档字典，解析失败返回空字典"""
	var json = JSON.new()
	var error = json.parse(json_string)
	if error != OK:
		push_error("[SaveManager] JSON 解析失败: %s" % json.get_error_message())
		return {}

	var result = json.get_data()
	if result is Dictionary:
		return result

	push_error("[SaveManager] JSON 数据不是字典类型")
	return {}


func validate_save_data(data: Dictionary) -> bool:
	"""验证存档数据是否包含所有必要字段且类型正确
	注意：JSON 解析后所有数字类型均为 float，因此数字字段统一检查 TYPE_FLOAT"""
	for field_name in REQUIRED_FIELDS:
		if not data.has(field_name):
			return false

		var expected_type: int = REQUIRED_FIELDS[field_name]
		var actual_type: int = typeof(data[field_name])

		# JSON 解析后 int 和 float 都是 TYPE_FLOAT，
		# 但直接构造的字典中数字可能是 TYPE_INT，两者都应视为有效
		if expected_type == TYPE_FLOAT:
			if actual_type != TYPE_FLOAT and actual_type != TYPE_INT:
				return false
		else:
			if actual_type != expected_type:
				return false

	return true

# ============================================================================
# 目录管理
# ============================================================================

func _ensure_save_dir() -> void:
	"""确保 user://saves/ 目录存在，不存在则创建"""
	if not DirAccess.dir_exists_absolute(SAVE_DIR):
		var err = DirAccess.make_dir_recursive_absolute(SAVE_DIR)
		if err != OK:
			push_error("[SaveManager] 无法创建存档目录: %s, 错误码: %d" % [SAVE_DIR, err])
		else:
			print("[SaveManager] 已创建存档目录: %s" % SAVE_DIR)

# ============================================================================
# 存档槽位管理
# ============================================================================

func _load_all_slots() -> void:
	"""从文件系统加载3个槽位数据，验证每个槽位，标记损坏的槽位"""
	for i in range(MAX_SLOTS):
		var file_path = SAVE_DIR + SAVE_FILE_TEMPLATE % (i + 1)
		if not FileAccess.file_exists(file_path):
			save_slots[i] = {}
			corrupted_slots[i] = false
			continue

		var file = FileAccess.open(file_path, FileAccess.READ)
		if file == null:
			push_error("[SaveManager] 无法打开存档文件: %s" % file_path)
			save_slots[i] = {}
			corrupted_slots[i] = true
			continue

		var json_string = file.get_as_text()
		file.close()

		var data = deserialize_save_data(json_string)
		if data.is_empty() or not validate_save_data(data):
			push_warning("[SaveManager] 存档槽位 %d 数据损坏或无效" % (i + 1))
			save_slots[i] = {}
			corrupted_slots[i] = true
		else:
			save_slots[i] = data
			corrupted_slots[i] = false


func get_slot_data(slot_index: int) -> Dictionary:
	"""获取指定槽位的存档数据，索引无效返回空字典"""
	if slot_index < 0 or slot_index >= MAX_SLOTS:
		return {}
	return save_slots[slot_index]


func is_slot_empty(slot_index: int) -> bool:
	"""检查指定槽位是否为空"""
	if slot_index < 0 or slot_index >= MAX_SLOTS:
		return true
	return save_slots[slot_index].is_empty()


func is_slot_corrupted(slot_index: int) -> bool:
	"""检查指定槽位是否损坏"""
	if slot_index < 0 or slot_index >= MAX_SLOTS:
		return false
	return corrupted_slots[slot_index]


func create_new_save(slot_index: int, leader_id: String, selected_players: Array) -> bool:
	"""在指定槽位创建新存档，返回是否成功"""
	if slot_index < 0 or slot_index >= MAX_SLOTS:
		return false
	
	var run_gold: int = 0
	var soul_shard: int = 0
	if DataManager:
		if DataManager.has_method("get_run_gold"):
			run_gold = DataManager.get_run_gold()
		if DataManager.has_method("get_soul_shard"):
			soul_shard = DataManager.get_soul_shard()

	var data: Dictionary = {
		"version": CURRENT_VERSION,
		"slot_index": slot_index,
		"leader_id": leader_id,
		"selected_players": selected_players,
		"current_floor": 1,
		"current_wave": 1,
		"play_time_seconds": 0,
		"last_played_timestamp": int(Time.get_unix_time_from_system()),
		"bond_summary": [],
		"gold": run_gold,  # 兼容旧字段
		"run_gold": run_gold,
		"soul_shard": soul_shard,
		"upgrades": {},
		"inventory": [],
		"game_state": "in_progress",
	}

	var json_string = serialize_save_data(data)
	var file_path = SAVE_DIR + SAVE_FILE_TEMPLATE % (slot_index + 1)
	var file = FileAccess.open(file_path, FileAccess.WRITE)
	if file == null:
		push_error("[SaveManager] 无法写入存档文件: %s" % file_path)
		return false

	file.store_string(json_string)
	file.close()

	save_slots[slot_index] = data
	corrupted_slots[slot_index] = false
	save_slot_updated.emit(slot_index)
	return true


func save_game_progress(slot_index: int, data: Dictionary) -> bool:
	"""合并数据并保存游戏进度到指定槽位，返回是否成功"""
	if slot_index < 0 or slot_index >= MAX_SLOTS:
		return false

	# 合并新数据到现有槽位数据
	var current_data = save_slots[slot_index].duplicate(true)
	for key in data:
		current_data[key] = data[key]

	# 更新最后游玩时间戳
	current_data["last_played_timestamp"] = int(Time.get_unix_time_from_system())

	if not validate_save_data(current_data):
		push_error("[SaveManager] 合并后的存档数据验证失败，槽位: %d" % slot_index)
		return false

	var json_string = serialize_save_data(current_data)
	var file_path = SAVE_DIR + SAVE_FILE_TEMPLATE % (slot_index + 1)
	var file = FileAccess.open(file_path, FileAccess.WRITE)
	if file == null:
		push_error("[SaveManager] 无法写入存档文件: %s" % file_path)
		return false

	file.store_string(json_string)
	file.close()

	save_slots[slot_index] = current_data
	corrupted_slots[slot_index] = false
	save_slot_updated.emit(slot_index)
	return true


func load_game_save(slot_index: int) -> Dictionary:
	"""加载指定槽位的存档数据（从缓存返回）"""
	if slot_index < 0 or slot_index >= MAX_SLOTS:
		return {}
	return save_slots[slot_index].duplicate(true)


func delete_save(slot_index: int) -> bool:
	"""删除指定槽位的存档文件并清除缓存，返回是否成功"""
	if slot_index < 0 or slot_index >= MAX_SLOTS:
		return false

	var file_path = SAVE_DIR + SAVE_FILE_TEMPLATE % (slot_index + 1)
	if FileAccess.file_exists(file_path):
		var dir = DirAccess.open(SAVE_DIR)
		if dir == null:
			push_error("[SaveManager] 无法打开存档目录: %s" % SAVE_DIR)
			return false
		var err = dir.remove(SAVE_FILE_TEMPLATE % (slot_index + 1))
		if err != OK:
			push_error("[SaveManager] 无法删除存档文件: %s, 错误码: %d" % [file_path, err])
			return false

	save_slots[slot_index] = {}
	corrupted_slots[slot_index] = false
	save_slot_updated.emit(slot_index)
	return true


func get_most_recent_slot() -> int:
	"""返回最近游玩的槽位索引，无存档返回 -1"""
	var most_recent_index: int = -1
	var most_recent_timestamp: int = -1

	for i in range(MAX_SLOTS):
		if save_slots[i].is_empty():
			continue
		var timestamp = save_slots[i].get("last_played_timestamp", 0)
		if timestamp > most_recent_timestamp:
			most_recent_timestamp = timestamp
			most_recent_index = i

	return most_recent_index


func has_any_save() -> bool:
	"""检查是否存在任何非空存档"""
	for i in range(MAX_SLOTS):
		if not save_slots[i].is_empty():
			return true
	return false


# ============================================================================
# 设置管理
# ============================================================================

func get_default_settings() -> Dictionary:
	"""返回默认设置字典"""
	return {
		"general": {
			"language": "zh",
			"cloud_save": false,
		},
		"display": {
			"resolution": "1920x1080",
			"display_mode": "fullscreen",
			"vsync": true,
			"fps_limit": 0,
			"shake_intensity": 100,
		},
		"audio": {
			"master_volume": 100,
			"bgm_volume": 80,
			"sfx_volume": 100,
			"ui_volume": 100,
		},
		"gameplay": {
			"draw_sensitivity": 2,
			"smart_cast": false,
			"skill_mode": "press_release",
			"show_damage_numbers": true,
		},
	}


func get_setting(key: String, default_value = null):
	"""获取设置值，支持点号分隔的嵌套键（如 'audio.master_volume'）"""
	var keys = key.split(".")
	var current = settings

	for k in keys:
		if current is Dictionary and current.has(k):
			current = current[k]
		else:
			return default_value

	return current


func set_setting(key: String, value) -> void:
	"""设置值，支持点号分隔的嵌套键，自动保存"""
	var keys = key.split(".")
	var current = settings

	# 遍历到倒数第二层，确保中间层级存在
	for i in range(keys.size() - 1):
		var k = keys[i]
		if not current.has(k) or not (current[k] is Dictionary):
			current[k] = {}
		current = current[k]

	# 设置最终值
	current[keys[-1]] = value
	settings_changed.emit()
	save_settings()


func save_settings() -> void:
	"""将设置数据序列化为 JSON 并写入 user://settings.json"""
	var json_string = JSON.stringify(settings, "\t")
	var file = FileAccess.open(SETTINGS_PATH, FileAccess.WRITE)
	if file == null:
		push_error("[SaveManager] 无法写入设置文件: %s" % SETTINGS_PATH)
		return

	file.store_string(json_string)
	file.close()


func _load_settings() -> void:
	"""从 user://settings.json 加载设置，文件不存在或损坏时使用默认值"""
	var defaults = get_default_settings()

	if not FileAccess.file_exists(SETTINGS_PATH):
		settings = defaults
		return

	var file = FileAccess.open(SETTINGS_PATH, FileAccess.READ)
	if file == null:
		push_error("[SaveManager] 无法读取设置文件: %s" % SETTINGS_PATH)
		settings = defaults
		return

	var json_string = file.get_as_text()
	file.close()

	var json = JSON.new()
	var error = json.parse(json_string)
	if error != OK:
		push_warning("[SaveManager] 设置文件 JSON 解析失败，使用默认值")
		settings = defaults
		# 删除损坏文件
		var dir = DirAccess.open("user://")
		if dir:
			dir.remove("settings.json")
		return

	var loaded = json.get_data()
	if not (loaded is Dictionary):
		push_warning("[SaveManager] 设置文件格式无效，使用默认值")
		settings = defaults
		return

	# 合并：以默认值为基础，用加载的值覆盖（确保缺失项有默认值）
	settings = _merge_settings(defaults, loaded)

	apply_display_settings()
	apply_audio_settings()


func load_settings() -> void:
	"""公开的加载设置方法（委托给内部 _load_settings）"""
	_load_settings()


func _merge_settings(defaults: Dictionary, loaded: Dictionary) -> Dictionary:
	"""递归合并设置：以 defaults 为基础，用 loaded 中存在的值覆盖"""
	var result = defaults.duplicate(true)
	for key in loaded:
		if result.has(key) and result[key] is Dictionary and loaded[key] is Dictionary:
			result[key] = _merge_settings(result[key], loaded[key])
		else:
			result[key] = loaded[key]
	return result


func apply_display_settings() -> void:
	"""应用显示设置到引擎"""
	# 分辨率
	var resolution_str: String = get_setting("display.resolution", "1920x1080")
	var parts = resolution_str.split("x")
	if parts.size() == 2:
		var w = int(parts[0])
		var h = int(parts[1])
		if w > 0 and h > 0:
			DisplayServer.window_set_size(Vector2i(w, h))
			# 居中窗口
			var screen_size = DisplayServer.screen_get_size()
			var window_pos = Vector2i((screen_size.x - w) / 2, (screen_size.y - h) / 2)
			DisplayServer.window_set_position(window_pos)

	# 显示模式
	var display_mode: String = get_setting("display.display_mode", "fullscreen")
	match display_mode:
		"fullscreen":
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		"windowed":
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		"borderless":
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
			DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, true)

	# 垂直同步
	var vsync_enabled: bool = get_setting("display.vsync", true)
	if vsync_enabled:
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED)
	else:
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)

	# 帧率限制
	var fps_limit: int = int(get_setting("display.fps_limit", 0))
	Engine.max_fps = fps_limit


func apply_audio_settings() -> void:
	"""应用音频设置到 AudioServer 各总线"""
	_apply_bus_volume("Master", get_setting("audio.master_volume", 100))
	_apply_bus_volume("Music", get_setting("audio.bgm_volume", 80))
	_apply_bus_volume("SFX", get_setting("audio.sfx_volume", 100))
	_apply_bus_volume("UI", get_setting("audio.ui_volume", 100))


func _apply_bus_volume(bus_name: String, volume_percent) -> void:
	"""将百分比音量 (0-100) 应用到指定音频总线"""
	var bus_idx = AudioServer.get_bus_index(bus_name)
	if bus_idx == -1:
		# 总线不存在时跳过（避免报错）
		return

	var percent = clampf(float(volume_percent), 0.0, 100.0)
	if percent <= 0.0:
		AudioServer.set_bus_mute(bus_idx, true)
	else:
		AudioServer.set_bus_mute(bus_idx, false)
		AudioServer.set_bus_volume_db(bus_idx, linear_to_db(percent / 100.0))


# ============================================================================
# 时间格式化工具
# ============================================================================

static func format_play_time(seconds: int) -> String:
	"""将秒数转为 'HH:MM:SS' 格式，HH 无上限，MM/SS 为 0-59，始终显示两位数"""
	var total_seconds: int = maxi(seconds, 0)
	var hh: int = total_seconds / 3600
	var mm: int = (total_seconds % 3600) / 60
	var ss: int = total_seconds % 60
	return "%02d:%02d:%02d" % [hh, mm, ss]


static func format_last_played(timestamp: int) -> String:
	"""将 Unix 时间戳转为 'YYYY-MM-DD HH:MM' 格式"""
	var dt: Dictionary = Time.get_datetime_dict_from_unix_time(timestamp)
	return "%04d-%02d-%02d %02d:%02d" % [
		dt.get("year", 1970),
		dt.get("month", 1),
		dt.get("day", 1),
		dt.get("hour", 0),
		dt.get("minute", 0),
	]
