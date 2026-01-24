extends Control
class_name ShopPanel

# ============================================================================
# 商店面板 - 波次间商店 UI
# ============================================================================

# 信号
signal next_wave_requested()  # 请求开始下一波

# 节点引用
@onready var gold_label: Label = %GoldLabel
@onready var items_container: HBoxContainer = %ItemsContainer
@onready var reroll_button: Button = %RerollButton
@onready var next_wave_button: Button = %NextWaveButton

# 商品卡片场景
var shop_item_card_scene: PackedScene = preload("res://scenes/ui/shop_panel/shop_item_card.tscn")

# 当前卡片列表
var item_cards: Array = []

# ============================================================================
# 初始化
# ============================================================================

func _ready() -> void:
	# 连接按钮信号
	reroll_button.pressed.connect(_on_reroll_button_pressed)
	next_wave_button.pressed.connect(_on_next_wave_button_pressed)
	
	# 连接 ShopManager 信号
	ShopManager.shop_items_generated.connect(_on_shop_items_generated)
	ShopManager.item_purchased.connect(_on_item_purchased)
	ShopManager.shop_rerolled.connect(_on_shop_rerolled)
	ShopManager.purchase_failed.connect(_on_purchase_failed)
	
	# 连接 DataManager 金币变化信号
	if DataManager.has_signal("gold_changed"):
		DataManager.gold_changed.connect(_on_gold_changed)
		print("[ShopPanel] 已连接 DataManager.gold_changed 信号")
	else:
		printerr("[ShopPanel] 错误: DataManager 没有 gold_changed 信号")
	
	# 初始隐藏
	visible = false

# ============================================================================
# 显示/隐藏
# ============================================================================

func show_shop(wave_number: int) -> void:
	"""显示商店
	
	Args:
		wave_number: 下一波的波次号
	"""
	print("[ShopPanel] 显示商店: 下一波=%d" % wave_number)
	
	# 更新下一波按钮文本
	next_wave_button.text = "开始第 %d 波" % wave_number
	
	# 生成商店物品
	ShopManager.generate_shop_items(3)
	
	# 更新金币显示
	_update_gold_display()
	
	# 显示面板
	visible = true
	
	# 暂停游戏
	get_tree().paused = true

func hide_shop() -> void:
	"""隐藏商店"""
	print("[ShopPanel] 隐藏商店")
	
	visible = false
	
	# 恢复游戏
	get_tree().paused = false

# ============================================================================
# UI 更新
# ============================================================================

func _update_gold_display() -> void:
	"""更新金币显示"""
	var gold = DataManager.get_total_gold()
	print("[ShopPanel] 更新金币显示: gold=%d" % gold)
	gold_label.text = "金币: %d" % gold
	
	# 更新刷新按钮状态
	var reroll_cost = ShopManager.get_reroll_cost()
	reroll_button.disabled = gold < reroll_cost
	reroll_button.text = "刷新 (%d金币)" % reroll_cost
	
	# 更新所有卡片的买得起状态
	for card in item_cards:
		if card is ShopItemCard:
			var item_price = card.item_data.get("price", 0)
			card.set_affordable(gold >= item_price)

func _clear_item_cards() -> void:
	"""清空所有商品卡片"""
	for card in item_cards:
		card.queue_free()
	item_cards.clear()

func _create_item_cards(items: Array) -> void:
	"""创建商品卡片
	
	Args:
		items: 商店物品数组
	"""
	_clear_item_cards()
	
	for i in range(items.size()):
		var item = items[i]
		
		# 实例化卡片
		var card = shop_item_card_scene.instantiate() as ShopItemCard
		items_container.add_child(card)
		item_cards.append(card)
		
		# 设置卡片数据
		card.setup(i, item)
		
		# 连接购买信号
		card.purchase_requested.connect(_on_card_purchase_requested)
		
		# 检查是否已购买
		if ShopManager.is_item_purchased(i):
			card.set_purchased(true)
	
	# 更新金币显示（会更新买得起状态）
	_update_gold_display()

# ============================================================================
# 信号处理
# ============================================================================

func _on_shop_items_generated(items: Array) -> void:
	"""商店物品生成完成"""
	print("[ShopPanel] 商店物品生成完成: %d 个" % items.size())
	_create_item_cards(items)

func _on_card_purchase_requested(card_index: int) -> void:
	"""卡片请求购买"""
	print("[ShopPanel] 卡片请求购买: index=%d" % card_index)
	ShopManager.purchase_item(card_index)

func _on_item_purchased(item_id: String, index: int) -> void:
	"""物品购买成功"""
	print("[ShopPanel] 物品购买成功: item_id=%s, index=%d" % [item_id, index])
	
	# 更新卡片状态
	if index >= 0 and index < item_cards.size():
		var card = item_cards[index]
		if card is ShopItemCard:
			card.set_purchased(true)
	
	# 更新金币显示
	_update_gold_display()

func _on_shop_rerolled() -> void:
	"""商店刷新完成"""
	print("[ShopPanel] 商店刷新完成")
	# 物品会通过 shop_items_generated 信号自动更新

func _on_purchase_failed(reason: String) -> void:
	"""购买失败"""
	print("[ShopPanel] 购买失败: %s" % reason)
	# TODO: 显示错误提示

func _on_gold_changed(new_gold: int) -> void:
	"""金币变化"""
	print("[ShopPanel] 收到金币变化信号: new_gold=%d" % new_gold)
	_update_gold_display()

func _on_reroll_button_pressed() -> void:
	"""刷新按钮被点击"""
	print("[ShopPanel] 刷新按钮被点击")
	ShopManager.reroll_shop()

func _on_next_wave_button_pressed() -> void:
	"""下一波按钮被点击"""
	print("[ShopPanel] 下一波按钮被点击")
	hide_shop()
	next_wave_requested.emit()
