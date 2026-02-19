extends Node

# ============================================================================
# 团队护符管理器 - 管理局内持有的徽章和遗物
# ============================================================================
#
# 功能说明:
# - 维护当前局内持有的护符列表（Bond_Emblem + Global_Relic）
# - 提供添加、移除、查询护符的接口
# - 唯一遗物（artifact_type="relic"）不可重复持有
# - 羁绊徽章（artifact_type="emblem"）可叠加
# - 支持序列化/反序列化用于局内存档恢复
#
# 使用方法:
#   EmblemManager.add_emblem("emblem_inkborn")
#   var tags = EmblemManager.get_emblem_tags()  # {inkborn: 1}
#   EmblemManager.clear_all()  # 局结束时调用
# ============================================================================

# 信号
signal emblem_added(emblem_data: Dictionary)
signal emblem_removed(emblem_data: Dictionary)
signal wildcard_assignment_requested(emblem_data: Dictionary)

# 当前局内持有的护符列表
# 格式: [{emblem_id, display_name, bond_tag, artifact_type, is_wildcard, rarity}]
var held_emblems: Array[Dictionary] = []

# ============================================================================
# 添加/移除护符
# ============================================================================

func add_emblem(emblem_id: String) -> bool:
	"""添加护符到持有列表
	
	Args:
		emblem_id: 护符ID（如 "emblem_inkborn", "relic_gold_ink"）
	
	Returns:
		是否成功添加（唯一遗物已持有时返回 false）
	"""
	var config = ConfigManager.get_emblem_config(emblem_id)
	if config.is_empty():
		printerr("[EmblemManager] 无效的护符ID: %s" % emblem_id)
		return false
	
	# 唯一遗物检查
	if config.get("artifact_type", "") == "relic" and has_unique_relic(emblem_id):
		printerr("[EmblemManager] 已持有唯一遗物: %s" % emblem_id)
		return false
	
	# 创建护符条目
	var emblem_entry: Dictionary = {
		"emblem_id": emblem_id,
		"display_name": str(config.get("display_name", "")),
		"bond_tag": str(config.get("bond_tag", "")),
		"artifact_type": str(config.get("artifact_type", "emblem")),
		"is_wildcard": emblem_id == "emblem_wildcard",
		"rarity": str(config.get("rarity", "common"))
	}
	
	held_emblems.append(emblem_entry)
	emblem_added.emit(emblem_entry)
	
	print("[EmblemManager] 添加护符: %s (%s)" % [emblem_entry.display_name, emblem_id])
	return true


const VALID_BOND_TAGS: Array[String] = [
	"inkborn", "colossus", "nomad", "alchemist", "blaster",
	"architect", "hexer", "geometrist", "assist", "vanguard", "commander"
]

func add_wildcard() -> void:
	"""添加万能鬼牌并发出分配请求信号
	
	调用 add_emblem 创建 is_wildcard=true 的条目，
	成功后发出 wildcard_assignment_requested 信号提示玩家选择目标羁绊。
	"""
	var success = add_emblem("emblem_wildcard")
	if success:
		# 刚添加的万能鬼牌是列表中最后一个条目
		var wildcard_data = held_emblems[held_emblems.size() - 1]
		wildcard_assignment_requested.emit(wildcard_data)
		print("[EmblemManager] 万能鬼牌已添加，等待玩家选择目标羁绊")

func assign_wildcard(emblem_index: int, target_bond_tag: String) -> void:
	"""分配万能鬼牌到指定羁绊标签
	
	Args:
		emblem_index: 万能鬼牌在 held_emblems 中的索引
		target_bond_tag: 目标羁绊标签（如 "inkborn"）
	"""
	# 验证索引范围
	if emblem_index < 0 or emblem_index >= held_emblems.size():
		printerr("[EmblemManager] 无效的护符索引: %d" % emblem_index)
		return
	
	# 验证该条目是万能鬼牌
	var emblem = held_emblems[emblem_index]
	if not emblem.get("is_wildcard", false):
		printerr("[EmblemManager] 索引 %d 的护符不是万能鬼牌" % emblem_index)
		return
	
	# 验证目标羁绊标签有效性
	if target_bond_tag not in VALID_BOND_TAGS:
		printerr("[EmblemManager] 无效的羁绊标签: %s" % target_bond_tag)
		return
	
	# 设置目标标签
	held_emblems[emblem_index]["bond_tag"] = target_bond_tag
	print("[EmblemManager] 万能鬼牌已分配到羁绊: %s" % target_bond_tag)

func remove_emblem(index: int) -> void:
	"""移除指定索引的护符
	
	Args:
		index: 护符在 held_emblems 中的索引
	"""
	if index < 0 or index >= held_emblems.size():
		printerr("[EmblemManager] 无效的护符索引: %d" % index)
		return
	
	var removed = held_emblems[index]
	held_emblems.remove_at(index)
	emblem_removed.emit(removed)
	
	print("[EmblemManager] 移除护符: %s (%s)" % [removed.get("display_name", ""), removed.get("emblem_id", "")])

func clear_all() -> void:
	"""清空所有持有的护符（局结束时调用）"""
	held_emblems.clear()
	print("[EmblemManager] 已清空所有护符")

# ============================================================================
# 查询接口
# ============================================================================

func has_unique_relic(emblem_id: String) -> bool:
	"""检查是否已持有指定的唯一遗物
	
	Args:
		emblem_id: 护符ID
	
	Returns:
		是否已持有
	"""
	for emblem in held_emblems:
		if emblem.get("emblem_id", "") == emblem_id:
			return true
	return false

func get_emblem_tags() -> Dictionary:
	"""获取所有护符提供的羁绊标签及计数
	
	跳过未分配的万能鬼牌（bond_tag 为 "wildcard"）
	
	Returns:
		{bond_tag: count} 字典
	"""
	var tags: Dictionary = {}
	for emblem in held_emblems:
		var tag = emblem.get("bond_tag", "")
		if tag == "" or tag == "wildcard":
			continue
		tags[tag] = tags.get(tag, 0) + 1
	return tags

func get_emblems_for_bond(bond_id: String) -> int:
	"""获取指定羁绊标签的徽章数量
	
	Args:
		bond_id: 羁绊标签（如 "inkborn"）
	
	Returns:
		该标签的徽章数量
	"""
	var count: int = 0
	for emblem in held_emblems:
		var tag = emblem.get("bond_tag", "")
		if tag == bond_id:
			count += 1
	return count

func get_all_emblems() -> Array[Dictionary]:
	"""获取所有持有的护符
	
	Returns:
		护符数组的副本
	"""
	return held_emblems.duplicate(true)

func get_emblem_count() -> int:
	"""获取当前持有的护符总数
	
	Returns:
		护符数量
	"""
	return held_emblems.size()

# ============================================================================
# 序列化/反序列化（局内存档支持）
# ============================================================================

func serialize() -> Dictionary:
	"""序列化为可存储的字典
	
	Returns:
		包含 held_emblems 的字典
	"""
	return {
		"held_emblems": held_emblems.duplicate(true)
	}

func deserialize(data: Dictionary) -> void:
	"""从存档恢复护符数据
	
	恢复后为每个护符发出 emblem_added 信号，触发 BondManager 重算
	
	Args:
		data: 序列化的字典数据
	"""
	held_emblems.clear()
	var saved_emblems = data.get("held_emblems", [])
	for emblem in saved_emblems:
		held_emblems.append(emblem)
		emblem_added.emit(emblem)
	
	print("[EmblemManager] 从存档恢复 %d 个护符" % held_emblems.size())
