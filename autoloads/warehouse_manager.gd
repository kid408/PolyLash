extends Node

# ============================================================================
# 仓库管理器 - 管理玩家的道具仓库
# ============================================================================

# 仓库数据：{slot_index: itemType}
var warehouse_items: Dictionary = {}

# 道具配置缓存：{itemType: config_dict}（含完整新格式字段 + 向后兼容字段）
var item_configs: Dictionary = {}

# 整数类型 → 字符串ID 映射表（按 CSV 行序自动生成）
var _type_to_id_map: Dictionary = {}
# 字符串ID → 整数类型 反向映射
var _id_to_type_map: Dictionary = {}

# 仓库容量
var warehouse_capacity: int = 48

# 本地存储路径
const WAREHOUSE_SAVE_PATH = "user://warehouse_data.json"

# ============================================================================
# 初始化
# ============================================================================

func _ready() -> void:
	_load_item_configs()
	_load_warehouse_data()
	print("[WarehouseManager] 初始化完成，容量: %d" % warehouse_capacity)

# ============================================================================
# 配置加载
# ============================================================================

func _load_item_configs() -> void:
	"""从 ConfigManager 加载道具配置（委托模式，避免重复解析 CSV）"""
	item_configs.clear()
	_type_to_id_map.clear()
	_id_to_type_map.clear()
	
	# ConfigManager 在 _ready() 中已加载 item_configs_new
	# 按插入顺序为每个 item_id 分配整数 type（从 1 开始，跳过 consumable）
	var type_counter: int = 0
	for item_id in ConfigManager.item_configs_new.keys():
		var cfg: Dictionary = ConfigManager.item_configs_new[item_id]
		type_counter += 1
		
		_type_to_id_map[type_counter] = item_id
		_id_to_type_map[item_id] = type_counter
		
		# 构建兼容旧调用方的配置字典（保留 description / resourcePath 键）
		var compat_config: Dictionary = cfg.duplicate()
		compat_config["description"] = cfg.get("name", "")
		compat_config["resourcePath"] = cfg.get("icon_path", "")
		
		item_configs[type_counter] = compat_config
	
	print("[WarehouseManager] 加载了 %d 个道具配置（委托 ConfigManager）" % item_configs.size())

# ============================================================================
# 仓库数据持久化
# ============================================================================

func _load_warehouse_data() -> void:
	"""从本地文件加载仓库数据"""
	if not FileAccess.file_exists(WAREHOUSE_SAVE_PATH):
		print("[WarehouseManager] 仓库数据文件不存在，初始化默认道具")
		_init_default_items()
		return
	
	var file = FileAccess.open(WAREHOUSE_SAVE_PATH, FileAccess.READ)
	if not file:
		printerr("[WarehouseManager] 无法打开仓库数据文件")
		_init_default_items()
		return
	
	var json_text = file.get_as_text()
	file.close()
	
	var json = JSON.new()
	var error = json.parse(json_text)
	if error != OK:
		printerr("[WarehouseManager] 解析仓库数据JSON失败: %s" % json.get_error_message())
		_init_default_items()
		return
	
	var data = json.get_data()
	if data is Dictionary:
		# 转换键为整数
		for key in data.keys():
			warehouse_items[int(key)] = int(data[key])
		print("[WarehouseManager] 加载仓库数据: %d 个道具" % warehouse_items.size())
	else:
		_init_default_items()

func save_warehouse_data() -> void:
	"""保存仓库数据到本地文件"""
	var file = FileAccess.open(WAREHOUSE_SAVE_PATH, FileAccess.WRITE)
	if not file:
		printerr("[WarehouseManager] 无法创建仓库数据文件")
		return
	
	var json_text = JSON.stringify(warehouse_items)
	file.store_string(json_text)
	file.close()
	print("[WarehouseManager] 保存仓库数据: %d 个道具" % warehouse_items.size())

func _init_default_items() -> void:
	"""初始化默认测试道具（包含所有三个层级）"""
	warehouse_items.clear()
	
	# Tier 1: 属性道具（3个）— 对应 CSV 行序 1-3
	warehouse_items[0] = 1   # attr_hp_potion 生命药水
	warehouse_items[1] = 2   # attr_speed_boots 疾风靴
	warehouse_items[2] = 3   # attr_damage_dagger 锋利匕首
	
	# Tier 2: 魔法道具（6个）— 对应 CSV 行序 4-9
	warehouse_items[3] = 4   # magic_fire_heart 火焰之心
	warehouse_items[4] = 5   # magic_ice_crystal 冰霜水晶
	warehouse_items[5] = 6   # magic_aoe_amplifier 范围扩增器
	warehouse_items[6] = 7   # magic_damage_boost 通用伤害增幅
	warehouse_items[7] = 8   # magic_duration_extend 持续时间延长
	warehouse_items[8] = 9   # magic_speed_boost 速度强化
	
	# Tier 3: 圣物道具（6个）— 对应 CSV 行序 10-15
	warehouse_items[9] = 10   # relic_colossus 巨擘圣物
	warehouse_items[10] = 11  # relic_inkborn 墨灵圣物
	warehouse_items[11] = 12  # relic_alchemist 炼金圣物
	warehouse_items[12] = 13  # relic_blaster 爆破圣物
	warehouse_items[13] = 14  # relic_nomad 风行圣物
	warehouse_items[14] = 15  # relic_architect 筑墙圣物
	
	save_warehouse_data()
	print("[WarehouseManager] 初始化默认测试道具: 15个（Tier1:3, Tier2:6, Tier3:6）")

# ============================================================================
# 仓库操作接口
# ============================================================================

func add_item(item_type: int) -> bool:
	"""添加道具到仓库（自动寻找空槽位）"""
	if not item_configs.has(item_type):
		printerr("[WarehouseManager] 道具类型不存在: %d" % item_type)
		return false
	
	# 查找空槽位
	for i in range(warehouse_capacity):
		if not warehouse_items.has(i):
			warehouse_items[i] = item_type
			save_warehouse_data()
			print("[WarehouseManager] 添加道具 %d 到槽位 %d" % [item_type, i])
			return true
	
	printerr("[WarehouseManager] 仓库已满，无法添加道具 %d" % item_type)
	return false

func remove_item(slot_index: int) -> bool:
	"""从指定槽位移除道具"""
	if warehouse_items.has(slot_index):
		var item_type = warehouse_items[slot_index]
		warehouse_items.erase(slot_index)
		
		# 整理仓库，移除空位
		_compact_warehouse()
		
		save_warehouse_data()
		print("[WarehouseManager] 从槽位 %d 移除道具 %d，已整理仓库" % [slot_index, item_type])
		return true
	return false

func _compact_warehouse() -> void:
	"""整理仓库，移除中间的空位"""
	# 提取所有道具类型
	var items_list: Array = []
	var sorted_slots = warehouse_items.keys()
	sorted_slots.sort()
	
	for slot in sorted_slots:
		items_list.append(warehouse_items[slot])
	
	# 清空仓库
	warehouse_items.clear()
	
	# 重新按顺序排列（从槽位0开始）
	for i in range(items_list.size()):
		warehouse_items[i] = items_list[i]
	
	print("[WarehouseManager] 仓库整理完成，当前有 %d 个道具" % items_list.size())

func get_item_at_slot(slot_index: int) -> int:
	"""获取指定槽位的道具类型（0表示空）"""
	return warehouse_items.get(slot_index, 0)

func get_item_config(item_type: int) -> Dictionary:
	"""获取道具配置（完整数据，含 bond_grant、modifiers 等新字段及向后兼容的 description/resourcePath）"""
	return item_configs.get(item_type, {})

func get_item_config_by_id(item_id: String) -> Dictionary:
	"""通过字符串 item_id 获取道具配置（委托 ConfigManager，附加兼容字段）"""
	var type_val = _id_to_type_map.get(item_id, 0)
	if type_val > 0:
		return item_configs.get(type_val, {})
	return ConfigManager.get_item_config_by_id(item_id)

func get_item_id_from_type(item_type: int) -> String:
	"""将整数 item_type 转换为字符串 item_id"""
	return _type_to_id_map.get(item_type, "")

func get_type_from_item_id(item_id: String) -> int:
	"""将字符串 item_id 转换为整数 item_type"""
	return _id_to_type_map.get(item_id, 0)

func get_all_items() -> Dictionary:
	"""获取所有仓库道具"""
	return warehouse_items.duplicate()

func clear_warehouse() -> void:
	"""清空仓库"""
	warehouse_items.clear()
	save_warehouse_data()
	print("[WarehouseManager] 清空仓库")

func compact_warehouse() -> void:
	"""手动整理仓库（公共接口）"""
	_compact_warehouse()
	save_warehouse_data()
	print("[WarehouseManager] 手动整理仓库完成")
