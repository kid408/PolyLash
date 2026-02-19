extends Node

# ============================================================================
# 波次奖励系统 - 在特定波次结束后提供三选一奖励
# ============================================================================
#
# 功能说明:
# - 检查当前波次是否触发奖励（默认第 5、10、15 波）
# - 生成三选一奖励选项（徽章/遗物、T3装备、金币）
# - 玩家选择后应用对应奖励
#
# 使用方法:
#   var wrs = WaveRewardSystem.new()
#   if wrs.check_wave_reward(5):
#       var options = wrs.generate_reward_options()
#       # 显示 UI，玩家选择后调用 select_reward(index)
# ============================================================================

# 玩家选择奖励后发出
signal reward_selected(reward_data: Dictionary)

# 可配置的奖励波次
const REWARD_WAVES: Array[int] = [5, 10, 15]

# 金币奖励范围
const GOLD_MIN: int = 200
const GOLD_MAX: int = 300

# 当前生成的奖励选项缓存
var _current_options: Array[Dictionary] = []

# ============================================================================
# 波次检查
# ============================================================================

func check_wave_reward(wave_number: int) -> bool:
	"""检查当前波次是否触发奖励
	
	Args:
		wave_number: 当前波次编号
	
	Returns:
		是否触发奖励
	"""
	return wave_number in REWARD_WAVES

# ============================================================================
# 三选一生成
# ============================================================================

func generate_reward_options() -> Array[Dictionary]:
	"""生成三选一奖励选项
	
	选项 A: 随机团队徽章/遗物（排除万能鬼牌和已持有唯一遗物）
	选项 B: 随机 T3 装备
	选项 C: 大量金币
	
	Returns:
		包含 3 个选项字典的数组
	"""
	_current_options.clear()
	
	# 选项 A: 随机团队徽章/遗物
	var option_a = _generate_artifact_option()
	_current_options.append(option_a)
	
	# 选项 B: 随机 T3 装备
	var option_b = _generate_equipment_option()
	_current_options.append(option_b)
	
	# 选项 C: 大量金币
	var option_c = _generate_gold_option()
	_current_options.append(option_c)
	
	return _current_options


func _generate_artifact_option() -> Dictionary:
	"""生成选项 A: 随机团队徽章/遗物
	
	排除万能鬼牌（emblem_wildcard）和已持有的唯一遗物。
	
	Returns:
		选项字典 {type, emblem_id, display_name, description, icon_path}
	"""
	var all_configs = ConfigManager.get_all_emblem_configs()
	var candidates: Array[String] = []
	
	for emblem_id in all_configs:
		var config = all_configs[emblem_id]
		# 排除万能鬼牌
		if emblem_id == "emblem_wildcard":
			continue
		# 排除已持有的唯一遗物
		if config.get("artifact_type", "") == "relic" and EmblemManager.has_unique_relic(emblem_id):
			continue
		candidates.append(emblem_id)
	
	# 如果没有可选护符，返回备用金币选项
	if candidates.is_empty():
		return {
			"type": "gold",
			"amount": randi_range(GOLD_MIN, GOLD_MAX),
			"display_name": "金币奖励",
			"description": "获得一笔金币",
			"icon_path": ""
		}
	
	# 随机选择一个
	var chosen_id = candidates[randi() % candidates.size()]
	var config = all_configs[chosen_id]
	
	return {
		"type": "artifact",
		"emblem_id": chosen_id,
		"display_name": str(config.get("display_name", chosen_id)),
		"description": str(config.get("description", "")),
		"icon_path": str(config.get("icon_path", ""))
	}

func _generate_equipment_option() -> Dictionary:
	"""生成选项 B: 随机 T3 装备
	
	从 ConfigManager.item_configs_new 中筛选 tier==3 的装备。
	
	Returns:
		选项字典 {type, item_id, display_name, description, icon_path}
	"""
	var candidates: Array[String] = []
	
	for item_id in ConfigManager.item_configs_new:
		var config = ConfigManager.item_configs_new[item_id]
		if int(config.get("tier", 0)) == 3:
			candidates.append(item_id)
	
	# 如果没有 T3 装备，返回备用金币选项
	if candidates.is_empty():
		return {
			"type": "gold",
			"amount": randi_range(GOLD_MIN, GOLD_MAX),
			"display_name": "金币奖励",
			"description": "获得一笔金币",
			"icon_path": ""
		}
	
	var chosen_id = candidates[randi() % candidates.size()]
	var config = ConfigManager.item_configs_new[chosen_id]
	
	return {
		"type": "equipment",
		"item_id": chosen_id,
		"display_name": str(config.get("name", chosen_id)),
		"description": str(config.get("description", "")),
		"icon_path": str(config.get("icon_path", ""))
	}

func _generate_gold_option() -> Dictionary:
	"""生成选项 C: 大量金币
	
	Returns:
		选项字典 {type, amount, display_name, description, icon_path}
	"""
	var amount = randi_range(GOLD_MIN, GOLD_MAX)
	return {
		"type": "gold",
		"amount": amount,
		"display_name": "%d 金币" % amount,
		"description": "获得 %d 金币" % amount,
		"icon_path": ""
	}

# ============================================================================
# 奖励选择
# ============================================================================

func select_reward(option_index: int) -> void:
	"""玩家选择奖励，应用对应效果
	
	Args:
		option_index: 选项索引（0=A, 1=B, 2=C）
	"""
	if option_index < 0 or option_index >= _current_options.size():
		printerr("[WaveRewardSystem] 无效的选项索引: %d" % option_index)
		return
	
	var reward = _current_options[option_index]
	var reward_type = reward.get("type", "")
	
	match reward_type:
		"artifact":
			var emblem_id = reward.get("emblem_id", "")
			if not emblem_id.is_empty():
				EmblemManager.add_emblem(emblem_id)
				print("[WaveRewardSystem] 获得护符: %s" % reward.get("display_name", emblem_id))
		"equipment":
			var item_id = reward.get("item_id", "")
			if not item_id.is_empty():
				# 将 item_id 转为整数 type 后添加到仓库
				var item_type = WarehouseManager.get_type_from_item_id(item_id)
				if item_type > 0:
					WarehouseManager.add_item(item_type)
					print("[WaveRewardSystem] 获得装备: %s" % reward.get("display_name", item_id))
				else:
					printerr("[WaveRewardSystem] 无法找到装备类型: %s" % item_id)
		"gold":
			var amount = int(reward.get("amount", 0))
			if amount > 0:
				DataManager.add_gold(amount)
				print("[WaveRewardSystem] 获得金币: %d" % amount)
	
	reward_selected.emit(reward)
	_current_options.clear()
