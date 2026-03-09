extends Node

# ============================================================================
# 商店属性管理器 - 基于CSV配置的商店属性系统
# ============================================================================
#
# 功能说明:
# - 从 shop_attribute_config.csv 加载属性配置
# - 从 shop_wave_config.csv 加载波次配置
# - 根据波次动态生成商店属性
# - 支持正负属性权重控制
# - 支持价格缩放和波次限制
#
# 使用方法:
#   ShopAttributeManager.generate_shop_for_wave(5)  # 为第5波生成商店
#   ShopAttributeManager.get_attribute_price("health_boost", 5)  # 获取属性价格
#
# ============================================================================

# ============================================================================
# 数据结构
# ============================================================================

# 属性配置 {attribute_id: {display_name, base_value, base_price, ...}}
var attribute_configs: Dictionary = {}

# 波次配置 [{wave_range_start, wave_range_end, item_count, ...}]
var wave_configs: Array = []

# 当前商店属性列表
var current_shop_attributes: Array = []

# ============================================================================
# 初始化
# ============================================================================

func _ready() -> void:
	_load_attribute_configs()
	_load_wave_configs()
	print("[ShopAttributeManager] 初始化完成: %d个属性, %d个波次配置" % [attribute_configs.size(), wave_configs.size()])

# ============================================================================
# 配置加载
# ============================================================================

func _load_attribute_configs() -> void:
	"""通过 ConfigRepository 加载属性配置（含 Schema 校验）。"""
	attribute_configs = ConfigRepository.load_shop_attribute_configs()
	print("[ShopAttributeManager] 通过 ConfigRepository 加载了 %d 个属性配置" % attribute_configs.size())

func _load_wave_configs() -> void:
	"""通过 ConfigRepository 加载波次配置（含 Schema 校验）。"""
	wave_configs = ConfigRepository.load_shop_wave_configs()
	print("[ShopAttributeManager] 通过 ConfigRepository 加载了 %d 个波次配置" % wave_configs.size())

# ============================================================================
# 商店生成
# ============================================================================

func generate_shop_for_wave(wave_number: int) -> Array:
	"""为指定波次生成商店属性
	
	Args:
		wave_number: 当前波次号
	
	Returns:
		生成的属性列表 [{attribute_id, display_name, value, price, is_positive, ...}]
	"""
	print("[ShopAttributeManager] 为波次 %d 生成商店..." % wave_number)
	
	current_shop_attributes.clear()
	
	# 获取波次配置
	var wave_config = _get_wave_config(wave_number)
	if wave_config.is_empty():
		printerr("[ShopAttributeManager] 错误: 找不到波次 %d 的配置" % wave_number)
		return []
	
	var item_count = wave_config.get("item_count", 3)
	var positive_weight = wave_config.get("positive_weight", 70)
	var negative_weight = wave_config.get("negative_weight", 30)
	var allow_duplicates = wave_config.get("allow_duplicates", false)
	var price_multiplier = wave_config.get("price_multiplier", 1.0)
	
	# 构建可用属性池
	var available_attrs = _get_available_attributes(wave_number)
	if available_attrs.is_empty():
		printerr("[ShopAttributeManager] 错误: 没有可用的属性")
		return []
	
	# 分离正负属性
	var positive_attrs = []
	var negative_attrs = []
	for attr in available_attrs:
		if attr.is_positive:
			positive_attrs.append(attr)
		else:
			negative_attrs.append(attr)
	
	# 生成属性
	var used_ids = []
	for i in range(item_count):
		var is_positive = _weighted_random_bool(positive_weight, negative_weight)
		var pool = positive_attrs if is_positive else negative_attrs
		
		if pool.is_empty():
			print("[ShopAttributeManager] 警告: %s属性池为空" % ("正" if is_positive else "负"))
			continue
		
		# 根据权重选择属性
		var selected_attr = _weighted_random_select(pool)
		
		# 检查重复
		if not allow_duplicates and selected_attr.attribute_id in used_ids:
			# 尝试重新选择
			var retry_count = 0
			while selected_attr.attribute_id in used_ids and retry_count < 10:
				selected_attr = _weighted_random_select(pool)
				retry_count += 1
			
			if selected_attr.attribute_id in used_ids:
				print("[ShopAttributeManager] 警告: 无法避免重复属性")
		
		used_ids.append(selected_attr.attribute_id)
		
		# 计算价格
		var price = _calculate_price(selected_attr, wave_number, price_multiplier)
		
		# 创建商店物品
		var shop_item = {
			"attribute_id": selected_attr.attribute_id,
			"display_name": selected_attr.display_name,
			"attribute_type": selected_attr.attribute_type,
			"effect_target": selected_attr.effect_target,
			"target_tags": selected_attr.target_tags,
			"value": selected_attr.base_value,
			"value_type": selected_attr.value_type,
			"price": price,
			"is_positive": selected_attr.is_positive,
			"shop_weight": selected_attr.shop_weight
		}
		
		current_shop_attributes.append(shop_item)
	
	print("[ShopAttributeManager] 生成了 %d 个商店属性" % current_shop_attributes.size())
	return current_shop_attributes

func _get_wave_config(wave_number: int) -> Dictionary:
	"""获取波次配置"""
	for config in wave_configs:
		if wave_number >= config.wave_range_start and wave_number <= config.wave_range_end:
			return config
	return {}

func _get_available_attributes(wave_number: int) -> Array:
	"""获取当前波次可用的属性"""
	var available = []
	for attr_id in attribute_configs.keys():
		var attr = attribute_configs[attr_id]
		if wave_number >= attr.min_wave and wave_number <= attr.max_wave:
			available.append(attr)
	return available

func _weighted_random_bool(true_weight: int, false_weight: int) -> bool:
	"""根据权重随机返回布尔值"""
	var total = true_weight + false_weight
	var rand_val = randi() % total
	return rand_val < true_weight

func _weighted_random_select(pool: Array) -> Dictionary:
	"""根据权重从池中随机选择"""
	var total_weight = 0
	for item in pool:
		total_weight += item.shop_weight
	
	var rand_val = randi() % total_weight
	var current_weight = 0
	
	for item in pool:
		current_weight += item.shop_weight
		if rand_val < current_weight:
			return item
	
	return pool[0] if pool.size() > 0 else {}

func _calculate_price(attr: Dictionary, wave_number: int, multiplier: float) -> int:
	"""计算属性价格
	
	Args:
		attr: 属性配置
		wave_number: 当前波次
		multiplier: 价格倍率
	
	Returns:
		最终价格
	"""
	var base_price = attr.base_price
	var scaling = attr.price_scaling
	
	# 根据波次缩放价格: price = base_price * (scaling ^ (wave_number / 5))
	var wave_factor = pow(scaling, wave_number / 5.0)
	var final_price = int(base_price * wave_factor * multiplier)
	
	return final_price

# ============================================================================
# 查询接口
# ============================================================================

func get_current_shop_attributes() -> Array:
	"""获取当前商店属性列表"""
	return current_shop_attributes

func get_attribute_config(attribute_id: String) -> Dictionary:
	"""获取属性配置"""
	return attribute_configs.get(attribute_id, {})

func get_reroll_cost(wave_number: int) -> int:
	"""获取刷新费用"""
	var config = _get_wave_config(wave_number)
	return config.get("reroll_cost", 50)

# ============================================================================
# 调试接口
# ============================================================================

func print_shop_attributes() -> void:
	"""打印当前商店属性（调试用）"""
	print("\n========== 当前商店属性 ==========")
	for i in range(current_shop_attributes.size()):
		var attr = current_shop_attributes[i]
		var name = attr.display_name
		var value = attr.value
		var price = attr.price
		var type_str = "正属性" if attr.is_positive else "负属性"
		var value_str = "%+.0f" % value if attr.value_type == "flat" else "%+.0f%%" % (value * 100)
		print("[%d] %s: %s - %d金币 (%s)" % [i, name, value_str, price, type_str])
	print("==================================\n")
