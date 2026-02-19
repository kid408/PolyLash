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
		compat_config["display_name"] = cfg.get("name", "")
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
		
		# 去重：每个 item_type 只保留一个
		_deduplicate_warehouse()
		
		print("[WarehouseManager] 加载仓库数据: %d 个道具（去重后）" % warehouse_items.size())
		
		# 检查仓库是否包含完整的圣物
		# 旧存档可能缺少圣物，需要重新初始化
		var relic_count = 0
		for slot in warehouse_items.keys():
			var item_type = warehouse_items[slot]
			var item_id = _type_to_id_map.get(item_type, "")
			if item_id.begins_with("relic_"):
				relic_count += 1
		
		# 加上已装备的圣物数量
		var equipped_relic_count = 0
		for player_id in EquipmentManager.equipped_items.keys():
			var eq_type = EquipmentManager.equipped_items[player_id]
			if eq_type is float:
				eq_type = int(eq_type)
			if eq_type > 0:
				var eq_id = _type_to_id_map.get(eq_type, "")
				if eq_id.begins_with("relic_"):
					equipped_relic_count += 1
		
		var total_relics = relic_count + equipped_relic_count
		if total_relics < 48:
			print("[WarehouseManager] 圣物总数不足 (仓库%d + 装备%d = %d/48)，重新初始化" % [relic_count, equipped_relic_count, total_relics])
			_init_default_items()
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
	"""初始化默认道具（48个圣物，排除已装备的）"""
	warehouse_items.clear()
	
	var slot = 0
	
	# 收集所有已装备的 item_type，初始化时排除
	var equipped_types: Dictionary = {}
	for player_id in EquipmentManager.equipped_items.keys():
		var item_type = EquipmentManager.equipped_items[player_id]
		if item_type is float:
			item_type = int(item_type)
		if item_type > 0:
			equipped_types[item_type] = true
	
	# Tier 3: 48个圣物道具
	var relic_ids: Array[String] = [
		"relic_skull_human", "relic_bone_femur", "relic_bone_jaw", "relic_bone_wrapped",
		"relic_skeletal_hand", "relic_bone_cross", "relic_ribcage", "relic_giant_tooth",
		"relic_sharp_fang", "relic_skull_bird", "relic_jaw_trap", "relic_fresh_heart",
		"relic_dual_eyes", "relic_brain", "relic_severed_arm", "relic_severed_foot",
		"relic_gem_bone_green", "relic_ring_sapphire", "relic_ring_amethyst", "relic_crown_spiked",
		"relic_necklace_teeth", "relic_rune_blue", "relic_rune_red", "relic_necklace_skull",
		"relic_flask_green", "relic_bag_leather", "relic_wood_logs", "relic_scroll_rolled",
		"relic_book_necro", "relic_glove_dark", "relic_dagger_ritual", "relic_hood_dark",
		"relic_candle_skull", "relic_candle_dual", "relic_page_script", "relic_vial_blood",
		"relic_root_mandrake", "relic_doll_voodoo", "relic_coin_ancient", "relic_bowl_blood",
		"relic_key_skeleton", "relic_letter_sealed", "relic_parchment_open", "relic_horn_war",
		"relic_glove_leather", "relic_boot_worn", "relic_arrow_broken", "relic_skull_deer"
	]
	
	for relic_id in relic_ids:
		var type_val = _id_to_type_map.get(relic_id, 0)
		if type_val > 0 and not equipped_types.has(type_val):
			warehouse_items[slot] = type_val
			slot += 1
	
	save_warehouse_data()
	print("[WarehouseManager] 初始化默认道具: %d 个圣物已放入仓库（排除 %d 个已装备）" % [slot, equipped_types.size()])

# ============================================================================
# 仓库操作接口
# ============================================================================

func add_item(item_type: int) -> bool:
	"""添加道具到仓库（自动追加到末尾，不允许重复）"""
	if not item_configs.has(item_type):
		printerr("[WarehouseManager] 道具类型不存在: %d" % item_type)
		return false
	
	# 检查仓库中是否已有该道具（去重）
	for slot in warehouse_items.keys():
		if warehouse_items[slot] == item_type:
			printerr("[WarehouseManager] 仓库中已存在道具 %d，跳过添加" % item_type)
			return false
	
	# 追加到末尾
	var next_slot = 0
	if not warehouse_items.is_empty():
		var keys = warehouse_items.keys()
		keys.sort()
		next_slot = keys[-1] + 1
	
	warehouse_items[next_slot] = item_type
	save_warehouse_data()
	print("[WarehouseManager] 添加道具 %d 到槽位 %d" % [item_type, next_slot])
	return true

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

func _deduplicate_warehouse() -> void:
	"""去重：每个 item_type 只保留第一个，移除重复项"""
	var seen_types: Dictionary = {}
	var duplicates: Array = []
	
	var sorted_slots = warehouse_items.keys()
	sorted_slots.sort()
	
	for slot in sorted_slots:
		var item_type = warehouse_items[slot]
		if seen_types.has(item_type):
			duplicates.append(slot)
		else:
			seen_types[item_type] = true
	
	if duplicates.size() > 0:
		for slot in duplicates:
			warehouse_items.erase(slot)
		_compact_warehouse()
		save_warehouse_data()
		print("[WarehouseManager] 去重完成，移除了 %d 个重复道具" % duplicates.size())

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
