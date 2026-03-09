extends Node

# 仓库管理器（局内）
# - 开局默认空仓库
# - 仅通过局内掉落/商店获取道具
# - 存档恢复由 SaveFacade -> restore_from_save 处理

const DEFAULT_CAPACITY: int = 48

# {slot_index: item_type(int)}
var warehouse_items: Dictionary = {}

# {item_type(int): config_dict}
var item_configs: Dictionary = {}

# 双向映射
var _type_to_id_map: Dictionary = {}
var _id_to_type_map: Dictionary = {}

var warehouse_capacity: int = DEFAULT_CAPACITY

func _ready() -> void:
	_load_item_configs()
	# 默认进入局内空仓库；继续游戏时会被存档覆盖
	reset_for_new_run(false)
	print("[WarehouseManager] 初始化完成（局内模式），容量: %d" % warehouse_capacity)

func _load_item_configs() -> void:
	item_configs.clear()
	_type_to_id_map.clear()
	_id_to_type_map.clear()

	var all_new_configs: Dictionary = ConfigManager.item_configs_new
	var type_counter: int = 0

	for item_id_variant in all_new_configs.keys():
		var item_id: String = str(item_id_variant)
		var raw_cfg: Variant = all_new_configs[item_id]
		if not (raw_cfg is Dictionary):
			continue
		var cfg: Dictionary = raw_cfg

		type_counter += 1
		_type_to_id_map[type_counter] = item_id
		_id_to_type_map[item_id] = type_counter

		# 兼容旧字段
		var compat_config: Dictionary = cfg.duplicate(true)
		compat_config["display_name"] = str(cfg.get("name", ""))
		compat_config["resourcePath"] = str(cfg.get("icon_path", ""))
		item_configs[type_counter] = compat_config

	print("[WarehouseManager] 加载了 %d 个道具配置（委托 ConfigManager）" % item_configs.size())

func reset_for_new_run(log_reset: bool = true) -> void:
	warehouse_items.clear()
	warehouse_capacity = DEFAULT_CAPACITY
	if log_reset:
		print("[WarehouseManager] 新局已重置：仓库为空")

# 兼容旧调用：旧逻辑是填充默认道具，现在改为空仓库
func _init_default_items() -> void:
	reset_for_new_run(true)
	push_warning("[WarehouseManager] _init_default_items 已废弃，当前为局内空仓库模式")

# 兼容旧调用：仓库不再单独写 user:// 文件，统一由 SaveFacade 持久化
func save_warehouse_data() -> void:
	return

func add_item(item_type: int) -> bool:
	if item_type <= 0:
		printerr("[WarehouseManager] 无效道具类型: %d" % item_type)
		return false
	if not item_configs.has(item_type):
		printerr("[WarehouseManager] 道具类型不存在: %d" % item_type)
		return false
	if warehouse_items.size() >= warehouse_capacity:
		printerr("[WarehouseManager] 仓库已满: %d/%d" % [warehouse_items.size(), warehouse_capacity])
		return false

	# 去重：同一种道具只保留一个
	for slot_variant in warehouse_items.keys():
		var slot: int = int(slot_variant)
		if int(warehouse_items.get(slot, 0)) == item_type:
			printerr("[WarehouseManager] 仓库中已存在道具 %d，跳过添加" % item_type)
			return false

	var next_slot: int = warehouse_items.size()
	while warehouse_items.has(next_slot):
		next_slot += 1

	warehouse_items[next_slot] = item_type
	print("[WarehouseManager] 添加道具 %d 到槽位 %d" % [item_type, next_slot])
	return true

func add_item_by_id(item_id: String) -> bool:
	var item_type: int = get_type_from_item_id(item_id)
	if item_type <= 0:
		printerr("[WarehouseManager] 未知 item_id: %s" % item_id)
		return false
	return add_item(item_type)

func remove_item(slot_index: int) -> bool:
	if not warehouse_items.has(slot_index):
		return false

	var item_type: int = int(warehouse_items.get(slot_index, 0))
	warehouse_items.erase(slot_index)
	_compact_warehouse()
	print("[WarehouseManager] 从槽位 %d 移除道具 %d" % [slot_index, item_type])
	return true

func _compact_warehouse() -> void:
	var sorted_slots: Array = warehouse_items.keys()
	sorted_slots.sort()

	var rebuilt: Dictionary = {}
	var write_index: int = 0
	for slot_variant in sorted_slots:
		var slot: int = int(slot_variant)
		var item_type: int = int(warehouse_items.get(slot, 0))
		if item_type <= 0:
			continue
		rebuilt[write_index] = item_type
		write_index += 1

	warehouse_items = rebuilt

func _deduplicate_warehouse() -> void:
	var sorted_slots: Array = warehouse_items.keys()
	sorted_slots.sort()

	var seen: Dictionary = {}
	var rebuilt: Dictionary = {}
	var write_index: int = 0

	for slot_variant in sorted_slots:
		var slot: int = int(slot_variant)
		var item_type: int = int(warehouse_items.get(slot, 0))
		if item_type <= 0:
			continue
		if seen.has(item_type):
			continue
		seen[item_type] = true
		rebuilt[write_index] = item_type
		write_index += 1

	warehouse_items = rebuilt

func get_item_at_slot(slot_index: int) -> int:
	return int(warehouse_items.get(slot_index, 0))

func get_item_config(item_type: int) -> Dictionary:
	return item_configs.get(item_type, {})

func get_item_config_by_id(item_id: String) -> Dictionary:
	var type_val: int = int(_id_to_type_map.get(item_id, 0))
	if type_val > 0:
		return item_configs.get(type_val, {})
	return ConfigManager.get_item_config_by_id(item_id)

func get_item_id_from_type(item_type: int) -> String:
	return str(_type_to_id_map.get(item_type, ""))

func get_type_from_item_id(item_id: String) -> int:
	return int(_id_to_type_map.get(item_id, 0))

func get_all_items() -> Dictionary:
	return warehouse_items.duplicate(true)

func get_capacity() -> int:
	return warehouse_capacity

func clear_warehouse() -> void:
	warehouse_items.clear()
	print("[WarehouseManager] 清空仓库")

func compact_warehouse() -> void:
	_compact_warehouse()
	print("[WarehouseManager] 手动整理仓库完成")

func restore_from_save(warehouse_data: Dictionary) -> void:
	warehouse_items.clear()

	var capacity: int = int(warehouse_data.get("capacity", DEFAULT_CAPACITY))
	if capacity > 0:
		warehouse_capacity = capacity
	else:
		warehouse_capacity = DEFAULT_CAPACITY

	var raw_items: Variant = warehouse_data.get("items", {})
	if raw_items is Dictionary:
		var items: Dictionary = raw_items
		for slot_key in items.keys():
			var slot_index: int = int(slot_key)
			var item_type: int = int(items[slot_key])
			if slot_index < 0 or item_type <= 0:
				continue
			if not item_configs.has(item_type):
				continue
			warehouse_items[slot_index] = item_type

	_deduplicate_warehouse()
	_compact_warehouse()
	print("[WarehouseManager] 从存档恢复 %d 个道具，容量: %d" % [warehouse_items.size(), warehouse_capacity])

func serialize_for_save() -> Dictionary:
	return {
		"items": get_all_items(),
		"capacity": warehouse_capacity
	}
