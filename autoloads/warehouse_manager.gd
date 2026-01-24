extends Node

# ============================================================================
# 仓库管理器 - 管理玩家的道具仓库
# ============================================================================

# 仓库数据：{slot_index: itemType}
var warehouse_items: Dictionary = {}

# 道具配置缓存：{itemType: {description, resourcePath}}
var item_configs: Dictionary = {}

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
	"""从 CSV 加载道具配置"""
	var csv_path = "res://config/item/item_config.csv"
	if not FileAccess.file_exists(csv_path):
		printerr("[WarehouseManager] 道具配置文件不存在: %s" % csv_path)
		return
	
	var file = FileAccess.open(csv_path, FileAccess.READ)
	if not file:
		printerr("[WarehouseManager] 无法打开道具配置文件")
		return
	
	# 跳过表头
	file.get_csv_line()
	# 跳过说明行
	file.get_csv_line()
	
	while not file.eof_reached():
		var line = file.get_csv_line()
		if line.size() < 3:
			continue
		
		var item_type = int(line[0])
		var description = line[1]
		var resource_path = line[2]
		
		if item_type <= 0:
			continue
		
		item_configs[item_type] = {
			"description": description,
			"resourcePath": resource_path
		}
	
	file.close()
	print("[WarehouseManager] 加载了 %d 个道具配置" % item_configs.size())

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
	
	# Tier 1: 属性道具（3个）
	warehouse_items[0] = 1   # 生命药水
	warehouse_items[1] = 2   # 疾风靴
	warehouse_items[2] = 3   # 锋利匕首
	
	# Tier 2: 魔法道具（6个）
	warehouse_items[3] = 4   # 火焰之心
	warehouse_items[4] = 5   # 冰霜水晶
	warehouse_items[5] = 6   # 范围扩增器
	warehouse_items[6] = 7   # 通用伤害增幅
	warehouse_items[7] = 8   # 持续时间延长
	warehouse_items[8] = 9   # 速度强化
	
	# Tier 3: 圣物道具（6个）
	warehouse_items[9] = 10   # 武道圣物
	warehouse_items[10] = 11  # 秘术圣物
	warehouse_items[11] = 12  # 幸存者圣物
	warehouse_items[12] = 13  # 毁灭圣物
	warehouse_items[13] = 14  # 速度圣物
	warehouse_items[14] = 15  # 控制圣物
	
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
	"""获取道具配置"""
	return item_configs.get(item_type, {})

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
