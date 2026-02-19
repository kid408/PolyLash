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
		# 加载装备数据（JSON数字为float，需转int）
		if data.has("equipped_items"):
			var raw = data["equipped_items"]
			equipped_items.clear()
			for key in raw.keys():
				var val = raw[key]
				if val is float:
					val = int(val)
				equipped_items[key] = val
		
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
	if item_type is float:
		item_type = int(item_type)
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
	var val = equipped_items.get(player_id, 0)
	if val is float:
		val = int(val)
	return val

func is_equipped(player_id: String) -> bool:
	"""检查角色是否装备了道具"""
	return get_equipped_item(player_id) > 0

func clear_all_equipment() -> void:
	"""清空所有装备"""
	equipped_items.clear()
	save_equipment_data()
	print("[EquipmentManager] 清空所有装备")

# ============================================================================
# 新增：统一装备/使用入口 & 数据查询
# ============================================================================

func equip_or_use_item(player_id: String, item_id: String, slot_index: int = 0) -> bool:
	"""统一入口：根据道具类型决定穿戴还是立即使用
	
	consumable 类型 -> 调用 player.apply_consumable_effect() 立即使用，不存入槽位
	equipment 类型 -> 执行穿戴/替换逻辑
	"""
	var config = ConfigManager.get_item_config_by_id(item_id)
	if config.is_empty():
		printerr("[EquipmentManager] 未找到道具配置: %s" % item_id)
		return false
	
	# 消耗品分支：立即使用，不存入槽位
	if config.get("type", "") == "consumable":
		var player = _get_player_node(player_id)
		if player and player.has_method("apply_consumable_effect"):
			player.apply_consumable_effect(config)
			print("[EquipmentManager] 消耗品已使用: %s" % config.get("name", item_id))
		return true
	
	# 装备分支：执行穿戴/替换逻辑
	return _equip_item_with_replace(player_id, item_id, slot_index)

func _equip_item_with_replace(player_id: String, new_item_id: String, slot_index: int) -> bool:
	"""装备新道具，自动替换旧装备（旧装备按 50% 回收金币）"""
	var old_item_type = get_equipped_item(player_id)
	if old_item_type > 0:
		# 旧装备自动出售（50% 回收）
		var old_item_id = WarehouseManager.get_item_id_from_type(old_item_type)
		if not old_item_id.is_empty():
			var old_config = ConfigManager.get_item_config_by_id(old_item_id)
			var sell_price = int(float(old_config.get("shop_price", 0)) * 0.5)
			if sell_price > 0:
				DataManager.add_gold(sell_price)
				print("[EquipmentManager] 旧装备自动出售: +%d 金币" % sell_price)
	
	# 装备新道具
	var new_item_type = WarehouseManager.get_type_from_item_id(new_item_id)
	if new_item_type <= 0:
		# 如果 WarehouseManager 没有映射，直接用 item_id 的 hash 作为 type
		# 这是为了兼容新格式道具
		new_item_type = new_item_id.hash()
	
	equipped_items[player_id] = new_item_type
	save_equipment_data()
	
	# 让角色实际装备道具
	var player = _get_player_node(player_id)
	if player and player.has_method("equip_item"):
		player.equip_item(new_item_id)
	
	# 触发 BondManager 重算
	if BondManager:
		BondManager.stat_modifiers_changed.emit()
	
	print("[EquipmentManager] 角色 %s 装备了 %s" % [player_id, new_item_id])
	return true

func get_equipped_item_data(player_id: String) -> Dictionary:
	"""获取角色装备的完整道具数据（含 bond_grant）"""
	var item_type = get_equipped_item(player_id)
	if item_type <= 0:
		return {}
	var item_id = WarehouseManager.get_item_id_from_type(item_type)
	if item_id.is_empty():
		return {}
	return ConfigManager.get_item_config_by_id(item_id)

func _get_player_node(player_id: String) -> Node:
	"""获取指定 player_id 的玩家节点"""
	# 优先检查 Global.player
	if Global.player and is_instance_valid(Global.player):
		if Global.player.get("player_id") == player_id:
			return Global.player
	
	# 遍历 player 组查找
	var players = get_tree().get_nodes_in_group("player")
	for player in players:
		if is_instance_valid(player) and player.get("player_id") == player_id:
			return player
	
	return null
