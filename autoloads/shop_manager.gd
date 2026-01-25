extends Node

# ============================================================================
# 商店管理器 - 波次间商店系统
# ============================================================================
#
# 功能说明:
# - 管理波次间商店的物品生成和购买
# - 从 shop_item_config.csv 加载商店物品配置
# - 支持权重随机抽取
# - 支持刷新（Reroll）功能
#
# 使用方法:
#   ShopManager.generate_shop_items(3)  # 生成3个商品
#   ShopManager.purchase_item(0)        # 购买第一个商品
#   ShopManager.reroll_shop()           # 刷新商店
#
# ============================================================================

# ============================================================================
# 信号
# ============================================================================

signal shop_items_generated(items: Array)  # 商店物品生成完成
signal item_purchased(item_id: String, index: int)  # 物品购买成功
signal shop_rerolled()  # 商店刷新完成
signal purchase_failed(reason: String)  # 购买失败

# ============================================================================
# 配置
# ============================================================================

const SHOP_CSV_PATH = "res://config/item/shop_item_config.csv"
const REROLL_COST = 50  # 刷新商店的金币消耗

# ============================================================================
# 数据结构
# ============================================================================

# 商店物品配置 {item_id: {effects: [], price: int, weight: int, ...}}
var shop_item_configs: Dictionary = {}

# 当前商店物品列表 [{item_id, effects, price, icon_path, ...}]
var current_shop_items: Array = []

# 已购买的物品索引（用于UI状态）
var purchased_indices: Array = []

# ============================================================================
# 初始化
# ============================================================================

func _ready() -> void:
	_load_shop_configs()
	print("[ShopManager] 初始化完成，加载了 %d 个商店物品配置" % shop_item_configs.size())

# ============================================================================
# 配置加载
# ============================================================================

func _load_shop_configs() -> void:
	"""从 CSV 加载商店物品配置"""
	if not FileAccess.file_exists(SHOP_CSV_PATH):
		printerr("[ShopManager] 错误: 找不到商店配置文件: %s" % SHOP_CSV_PATH)
		return
	
	var file = FileAccess.open(SHOP_CSV_PATH, FileAccess.READ)
	if not file:
		printerr("[ShopManager] 错误: 无法打开商店配置文件")
		return
	
	# 跳过表头
	file.get_csv_line()
	# 跳过说明行
	file.get_csv_line()
	
	var line_count = 0
	while not file.eof_reached():
		var line = file.get_csv_line()
		if line.size() < 13:
			continue
		
		var item_id = line[0]
		var item_name = line[1]
		var item_type = line[2]
		var item_tier = int(line[3])
		var effect_type = line[4]
		var effect_target = line[5]
		var target_tags_str = line[6]
		var effect_value = float(line[7])
		var icon_path = line[8]
		var description = line[9]
		var price = int(line[10])
		var shop_weight = int(line[11])
		var is_trade_off = int(line[12])
		
		if item_id == "" or item_id == "-1":
			continue
		
		# 解析标签
		var target_tags = []
		if target_tags_str != "":
			target_tags = target_tags_str.split(",")
		
		# 初始化物品配置
		if not shop_item_configs.has(item_id):
			shop_item_configs[item_id] = {
				"item_id": item_id,
				"item_name": item_name,
				"item_type": item_type,
				"item_tier": item_tier,
				"icon_path": icon_path,
				"price": price,
				"shop_weight": shop_weight,
				"effects": []
			}
		
		# 添加效果
		shop_item_configs[item_id].effects.append({
			"effect_type": effect_type,
			"effect_target": effect_target,
			"target_tags": target_tags,
			"effect_value": effect_value,
			"description": description,
			"is_trade_off": is_trade_off == 1
		})
		
		line_count += 1
	
	file.close()
	print("[ShopManager] 加载了 %d 行商店配置数据" % line_count)

# ============================================================================
# 商店生成
# ============================================================================

func generate_shop_items(count: int = 3) -> void:
	"""生成商店物品
	
	Args:
		count: 生成的物品数量（默认3个）
	"""
	print("[ShopManager] 生成 %d 个商店物品..." % count)
	
	current_shop_items.clear()
	purchased_indices.clear()
	
	if shop_item_configs.is_empty():
		printerr("[ShopManager] 错误: 没有可用的商店物品配置")
		return
	
	# 构建权重池
	var weighted_pool: Array = []
	for item_id in shop_item_configs.keys():
		var config = shop_item_configs[item_id]
		var weight = config.get("shop_weight", 10)
		for i in range(weight):
			weighted_pool.append(item_id)
	
	if weighted_pool.is_empty():
		printerr("[ShopManager] 错误: 权重池为空")
		return
	
	# 随机抽取物品（允许重复）
	for i in range(count):
		var random_index = randi() % weighted_pool.size()
		var item_id = weighted_pool[random_index]
		var config = shop_item_configs[item_id].duplicate(true)
		current_shop_items.append(config)
	
	print("[ShopManager] 商店物品生成完成: %s" % str(_get_item_ids()))
	shop_items_generated.emit(current_shop_items)

func _get_item_ids() -> Array:
	"""获取当前商店物品的ID列表（用于调试）"""
	var ids = []
	for item in current_shop_items:
		ids.append(item.get("item_id", "unknown"))
	return ids

# ============================================================================
# 购买逻辑
# ============================================================================

func purchase_item(index: int) -> bool:
	"""购买商店物品
	
	Args:
		index: 物品在商店列表中的索引
	
	Returns:
		是否购买成功
	"""
	print("[ShopManager] 尝试购买物品: index=%d" % index)
	
	# 检查索引有效性
	if index < 0 or index >= current_shop_items.size():
		printerr("[ShopManager] 错误: 无效的物品索引: %d" % index)
		purchase_failed.emit("无效的物品索引")
		return false
	
	# 检查是否已购买
	if index in purchased_indices:
		print("[ShopManager] 物品已购买: index=%d" % index)
		purchase_failed.emit("物品已购买")
		return false
	
	var item = current_shop_items[index]
	var item_id = item.get("item_id", "")
	var price = item.get("price", 0)
	
	# 检查金币是否足够
	var current_gold = DataManager.get_total_gold()
	if current_gold < price:
		print("[ShopManager] 金币不足: 需要=%d, 拥有=%d" % [price, current_gold])
		purchase_failed.emit("金币不足")
		return false
	
	# 扣除金币
	DataManager.add_gold(-price)
	print("[ShopManager] 扣除金币: %d, 剩余: %d" % [price, DataManager.get_total_gold()])
	
	# 应用物品效果到玩家
	_apply_item_effects(item)
	
	# 标记为已购买
	purchased_indices.append(index)
	
	print("[ShopManager] 购买成功: item_id=%s, price=%d" % [item_id, price])
	item_purchased.emit(item_id, index)
	
	return true

func _apply_item_effects(item: Dictionary) -> void:
	"""应用物品效果到玩家
	
	Args:
		item: 物品配置字典
	"""
	var effects = item.get("effects", [])
	var item_id = item.get("item_id", "unknown")
	
	print("[ShopManager] 应用物品效果: item_id=%s, effects=%d" % [item_id, effects.size()])
	
	for effect in effects:
		var effect_type = effect.get("effect_type", "")
		var effect_target = effect.get("effect_target", "")
		var target_tags = effect.get("target_tags", [])
		var effect_value = effect.get("effect_value", 0.0)
		var is_trade_off = effect.get("is_trade_off", false)
		
		match effect_target:
			"modifier":
				# 添加修改器（通过 ModifierManager）
				ModifierManager.add_modifier(target_tags, effect_type, effect_value)
				print("[ShopManager] 添加修改器: tags=%s, type=%s, value=%s" % [target_tags, effect_type, effect_value])
			
			"stat":
				# 直接修改玩家属性
				if Global.player:
					_apply_stat_effect(Global.player, target_tags, effect_value)
				else:
					printerr("[ShopManager] 错误: 玩家不存在，无法应用属性效果")
			
			"bond":
				# 添加羁绊标签（未来扩展）
				print("[ShopManager] 羁绊标签效果暂未实现: %s" % target_tags)
			
			_:
				printerr("[ShopManager] 未知的效果目标: %s" % effect_target)

func _apply_stat_effect(player: PlayerBase, stat_tags: Array, value: float) -> void:
	"""应用属性效果到玩家
	
	Args:
		player: 玩家对象
		stat_tags: 属性标签（如 ["max_health"]）
		value: 效果数值
	"""
	if stat_tags.is_empty():
		return
	
	var stat_name = stat_tags[0]  # 使用第一个标签作为属性名
	
	match stat_name:
		"max_health":
			# 生命值存储在 HealthComponent 中
			if player.has_node("HealthComponent"):
				var health_comp = player.get_node("HealthComponent")
				health_comp.max_health += value
				health_comp.current_health = min(health_comp.current_health, health_comp.max_health)
				print("[ShopManager] 修改生命上限: %+.0f, 新值: %.0f" % [value, health_comp.max_health])
			else:
				printerr("[ShopManager] 玩家没有 HealthComponent")
		
		"speed":
			# 速度现在直接存储在 player 中
			if "speed" in player:
				player.speed += value
				print("[ShopManager] 修改移动速度: %+.0f, 新值: %.0f" % [value, player.speed])
			else:
				printerr("[ShopManager] 玩家没有 speed 属性")
		
		"damage":
			# 伤害现在直接存储在 player 中
			if "damage" in player:
				player.damage += value
				print("[ShopManager] 修改基础伤害: %+.0f, 新值: %.0f" % [value, player.damage])
			else:
				printerr("[ShopManager] 玩家没有 damage 属性")
		
		"armor":
			# 护甲存储在 PlayerBase 中
			if "max_armor" in player:
				player.max_armor += int(value)
				player.armor = min(player.armor, player.max_armor)
				print("[ShopManager] 修改护甲上限: %+d, 新值: %d" % [int(value), player.max_armor])
			else:
				printerr("[ShopManager] 玩家没有 armor 属性")
		
		"crit_chance":
			# 暴击率通过 UpgradeManager 管理
			UpgradeManager.add_attribute_bonus("crit_chance", value)
			print("[ShopManager] 修改暴击率: %+.0f%%" % value)
		
		_:
			print("[ShopManager] 警告: 未知的属性类型: %s" % stat_name)
		"attack_speed":
			if "attack_speed" in player:
				player.attack_speed += value
				print("[ShopManager] 修改攻击速度: %+.0f%%" % (value * 100))
		
		"gold_gain":
			# 金币获取加成（可以存储在 Global 或 DataManager）
			print("[ShopManager] 金币获取加成: %+.0f%%" % (value * 100))
		
		"exp_gain":
			# 经验获取加成
			print("[ShopManager] 经验获取加成: %+.0f%%" % (value * 100))
		
		_:
			printerr("[ShopManager] 未知的属性类型: %s" % stat_name)

# ============================================================================
# 刷新商店
# ============================================================================

func reroll_shop() -> bool:
	"""刷新商店（重新生成物品）
	
	Returns:
		是否刷新成功
	"""
	print("[ShopManager] 尝试刷新商店...")
	
	# 检查金币是否足够
	var current_gold = DataManager.get_total_gold()
	if current_gold < REROLL_COST:
		print("[ShopManager] 金币不足: 需要=%d, 拥有=%d" % [REROLL_COST, current_gold])
		purchase_failed.emit("金币不足")
		return false
	
	# 扣除金币
	DataManager.add_gold(-REROLL_COST)
	print("[ShopManager] 扣除刷新费用: %d, 剩余: %d" % [REROLL_COST, DataManager.get_total_gold()])
	
	# 重新生成商店物品
	generate_shop_items(current_shop_items.size())
	
	print("[ShopManager] 商店刷新成功")
	shop_rerolled.emit()
	
	return true

# ============================================================================
# 查询接口
# ============================================================================

func get_current_shop_items() -> Array:
	"""获取当前商店物品列表"""
	return current_shop_items

func is_item_purchased(index: int) -> bool:
	"""检查物品是否已购买"""
	return index in purchased_indices

func get_reroll_cost() -> int:
	"""获取刷新商店的费用"""
	return REROLL_COST

# ============================================================================
# 调试接口
# ============================================================================

func print_shop_items() -> void:
	"""打印当前商店物品（调试用）"""
	print("\n========== 当前商店物品 ==========")
	for i in range(current_shop_items.size()):
		var item = current_shop_items[i]
		var item_id = item.get("item_id", "unknown")
		var item_name = item.get("item_name", "未知")
		var price = item.get("price", 0)
		var purchased = " [已购买]" if is_item_purchased(i) else ""
		print("[%d] %s (%s) - %d金币%s" % [i, item_name, item_id, price, purchased])
		
		var effects = item.get("effects", [])
		for effect in effects:
			var desc = effect.get("description", "")
			var is_trade_off = effect.get("is_trade_off", false)
			var color = "红色" if is_trade_off else "绿色"
			print("    - %s (%s)" % [desc, color])
	print("==================================\n")
