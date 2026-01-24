extends Node

# ============================================================================
# 装备管理器 - 管理角色装备和仓库联动
# ============================================================================

# 装备数据：{player_id: item_type}
var equipped_items: Dictionary = {}

# 本地存储路径
const EQUIPMENT_SAVE_PATH = "user://equipment_data.json"

# ============================================================================
# 初始化
# ============================================================================

func _ready() -> void:
	_load_equipment_data()
	print("[EquipmentManager] 初始化完成")

# ============================================================================
# 数据持久化
# ============================================================================

func _load_equipment_data() -> void:
	"""从本地文件加载装备数据"""
	if not FileAccess.file_exists(EQUIPMENT_SAVE_PATH):
		print("[EquipmentManager] 装备数据文件不存在，使用默认值")
		return
	
	var file = FileAccess.open(EQUIPMENT_SAVE_PATH, FileAccess.READ)
	if not file:
		printerr("[EquipmentManager] 无法打开装备数据文件")
		return
	
	var json_text = file.get_as_text()
	file.close()
	
	var json = JSON.new()
	var error = json.parse(json_text)
	if error != OK:
		printerr("[EquipmentManager] 解析装备数据JSON失败: %s" % json.get_error_message())
		return
	
	var data = json.get_data()
	if data is Dictionary:
		# 加载装备数据
		if data.has("equipped_items"):
			equipped_items = data["equipped_items"]
		
		print("[EquipmentManager] 加载装备数据: %s" % str(equipped_items))

func save_equipment_data() -> void:
	"""保存装备数据到本地文件"""
	var save_data = {
		"equipped_items": equipped_items
	}
	
	var file = FileAccess.open(EQUIPMENT_SAVE_PATH, FileAccess.WRITE)
	if not file:
		printerr("[EquipmentManager] 无法创建装备数据文件")
		return
	
	var json_text = JSON.stringify(save_data)
	file.store_string(json_text)
	file.close()
	print("[EquipmentManager] 保存装备数据: %s" % str(equipped_items))

# ============================================================================
# 装备操作接口
# ============================================================================

func equip_item(player_id: String, item_type: int, slot_index: int) -> bool:
	"""为角色装备道具"""
	# 检查角色是否已装备其他道具
	if equipped_items.has(player_id):
		var old_item = equipped_items[player_id]
		if old_item > 0:
			# 先卸下旧装备
			unequip_item(player_id)
	
	# 从仓库移除道具
	if not WarehouseManager.remove_item(slot_index):
		printerr("[EquipmentManager] 无法从仓库移除道具")
		return false
	
	# 装备道具
	equipped_items[player_id] = item_type
	save_equipment_data()
	
	print("[EquipmentManager] 角色 %s 装备了道具 %d" % [player_id, item_type])
	return true

func unequip_item(player_id: String) -> bool:
	"""卸下角色装备"""
	if not equipped_items.has(player_id):
		return false
	
	var item_type = equipped_items[player_id]
	if item_type <= 0:
		return false
	
	# 添加回仓库
	if not WarehouseManager.add_item(item_type):
		printerr("[EquipmentManager] 仓库已满，无法卸下装备")
		return false
	
	# 清除装备
	equipped_items[player_id] = 0
	save_equipment_data()
	
	print("[EquipmentManager] 角色 %s 卸下了道具 %d" % [player_id, item_type])
	return true

func get_equipped_item(player_id: String) -> int:
	"""获取角色装备的道具类型（0表示未装备）"""
	return equipped_items.get(player_id, 0)

func is_equipped(player_id: String) -> bool:
	"""检查角色是否装备了道具"""
	return get_equipped_item(player_id) > 0

func clear_all_equipment() -> void:
	"""清空所有装备"""
	equipped_items.clear()
	save_equipment_data()
	print("[EquipmentManager] 清空所有装备")
