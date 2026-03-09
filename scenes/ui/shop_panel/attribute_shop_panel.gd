extends Control
class_name AttributeShopPanel

# ============================================================================
# 属性商店面板 - 波次间属性购买 UI
# ============================================================================
#
# 功能说明:
# - 显示可购买的属性（正属性和负属性）
# - 支持属性购买和刷新
# - 与物品商店（ShopPanel）独立运行
#
# 使用方法:
#   attribute_shop_panel.show_shop(wave_number)
#
# ============================================================================

# 信号
signal attribute_purchased(attribute_id: String)
signal shop_closed()

# 节点引用
@onready var title_label: Label = %TitleLabel
@onready var gold_label: Label = %GoldLabel
@onready var wave_label: Label = %WaveLabel
@onready var attributes_container: HBoxContainer = %AttributesContainer
@onready var reroll_button: Button = %RerollButton
@onready var close_button: Button = %CloseButton

# 属性卡片场景（复用 shop_item_card）
var attribute_card_scene: PackedScene = preload("res://scenes/ui/shop_panel/shop_item_card.tscn")

# 当前数据
var current_wave: int = 1
var current_cards: Array = []
var purchased_indices: Array = []

# ============================================================================
# 初始化
# ============================================================================

func _ready() -> void:
	# 连接按钮信号
	if reroll_button:
		reroll_button.pressed.connect(_on_reroll_button_pressed)
	if close_button:
		close_button.pressed.connect(_on_close_button_pressed)
	
	# 连接局内金币变化信号
	if DataManager.has_signal("run_gold_changed"):
		DataManager.run_gold_changed.connect(_on_gold_changed)
	elif DataManager.has_signal("gold_changed"):
		DataManager.gold_changed.connect(_on_gold_changed)
	
	# 初始隐藏
	visible = false

# ============================================================================
# 显示/隐藏
# ============================================================================

func show_shop(wave_number: int) -> void:
	"""显示属性商店
	
	Args:
		wave_number: 当前波次号
	"""
	print("[AttributeShopPanel] 显示属性商店: 波次=%d" % wave_number)
	
	current_wave = wave_number
	purchased_indices.clear()
	
	# 更新标题
	if wave_label:
		wave_label.text = "第 %d 波" % wave_number
	
	# 生成属性
	var attributes = ShopAttributeManager.generate_shop_for_wave(wave_number)
	_display_attributes(attributes)
	
	# 更新金币显示
	_update_gold_display()
	
	# 显示面板
	visible = true
	SoundManager.play("ui_panel_open")

func hide_shop() -> void:
	"""隐藏属性商店"""
	print("[AttributeShopPanel] 隐藏属性商店")
	SoundManager.play("ui_panel_close")
	visible = false
	shop_closed.emit()

# ============================================================================
# 属性显示
# ============================================================================

func _display_attributes(attributes: Array) -> void:
	"""显示属性列表
	
	Args:
		attributes: 属性数组
	"""
	_clear_cards()
	
	for i in range(attributes.size()):
		var attr = attributes[i]
		var card = attribute_card_scene.instantiate()
		
		# 设置卡片索引
		card.card_index = i
		
		# 构造显示数据（转换为物品格式）
		var display_data = {
			"item_id": attr.attribute_id,
			"item_name": attr.display_name,
			"price": attr.price,
			"effects": [{
				"description": _format_attribute_description(attr),
				"is_trade_off": not attr.is_positive
			}]
		}
		
		card.setup(display_data)
		card.purchase_requested.connect(_on_card_purchase_requested)
		
		attributes_container.add_child(card)
		current_cards.append(card)
	
	_update_all_cards_affordability()
	
	print("[AttributeShopPanel] 显示了 %d 个属性" % attributes.size())

func _format_attribute_description(attr: Dictionary) -> String:
	"""格式化属性描述
	
	Args:
		attr: 属性字典
	
	Returns:
		格式化的描述文本
	"""
	var value_str = ""
	
	if attr.value_type == "flat":
		value_str = "%+.0f" % attr.value
	else:  # percent
		value_str = "%+.0f%%" % (attr.value * 100)
	
	var color = "[color=green]" if attr.is_positive else "[color=red]"
	var end_color = "[/color]"
	
	return "%s%s: %s%s" % [color, attr.display_name, value_str, end_color]

func _clear_cards() -> void:
	"""清空所有卡片"""
	for card in current_cards:
		card.queue_free()
	current_cards.clear()

# ============================================================================
# UI 更新
# ============================================================================

func _update_gold_display() -> void:
	"""更新金币显示"""
	var gold = RunStateService.get_run_gold()
	
	if gold_label:
		gold_label.text = "金币: %d" % gold
	
	# 更新刷新按钮
	if reroll_button:
		var reroll_cost = ShopAttributeManager.get_reroll_cost(current_wave)
		reroll_button.disabled = gold < reroll_cost
		reroll_button.text = "刷新 (%d金币)" % reroll_cost
	
	_update_all_cards_affordability()

func _update_all_cards_affordability() -> void:
	"""更新所有卡片的买得起状态"""
	var gold = RunStateService.get_run_gold()
	
	for card in current_cards:
		if card.has_method("set_affordable"):
			var price = card.item_data.get("price", 0)
			card.set_affordable(gold >= price)

# ============================================================================
# 购买逻辑
# ============================================================================

func _on_card_purchase_requested(card_index: int) -> void:
	"""卡片请求购买
	
	Args:
		card_index: 卡片索引
	"""
	print("[AttributeShopPanel] 请求购买属性: index=%d" % card_index)
	
	# 检查是否已购买
	if card_index in purchased_indices:
		print("[AttributeShopPanel] 属性已购买")
		return
	
	var attributes = ShopAttributeManager.get_current_shop_attributes()
	if card_index < 0 or card_index >= attributes.size():
		printerr("[AttributeShopPanel] 错误: 无效的卡片索引")
		return
	
	var attr = attributes[card_index]
	var price = attr.price
	var gold = RunStateService.get_run_gold()
	
	# 检查金币
	if gold < price:
		print("[AttributeShopPanel] 金币不足: 需要=%d, 拥有=%d" % [price, gold])
		SoundManager.play("ui_error")
		return

	var result = ShopDomainService.try_purchase(price, func() -> bool:
		_apply_attribute_to_player(attr)
		return true
	)
	if not bool(result.get("success", false)):
		print("[AttributeShopPanel] 购买失败: %s" % str(result.get("reason", "未知错误")))
		SoundManager.play("ui_error")
		return

	print("[AttributeShopPanel] 扣除金币: %d, 剩余: %d" % [price, RunStateService.get_run_gold()])
	
	# 标记为已购买
	purchased_indices.append(card_index)
	if card_index < current_cards.size():
		current_cards[card_index].set_purchased(true)
	
	# 更新UI
	_update_gold_display()
	
	# 发送信号
	attribute_purchased.emit(attr.attribute_id)
	SoundManager.play("ui_purchase")
	
	print("[AttributeShopPanel] 购买成功: %s" % attr.display_name)

func _apply_attribute_to_player(attr: Dictionary) -> void:
	"""应用属性到玩家
	
	Args:
		attr: 属性字典
	"""
	var player = Global.player
	if not player:
		printerr("[AttributeShopPanel] 错误: 玩家不存在")
		return
	
	print("[AttributeShopPanel] 应用属性: %s = %s" % [attr.display_name, attr.value])

	var effect := {
		"effect_target": str(attr.get("effect_target", "")),
		"target_tags": attr.get("target_tags", []),
		"effect_type": str(attr.get("effect_type", "")),
		"effect_value": float(attr.get("value", 0.0)),
		"value_type": str(attr.get("value_type", "flat"))
	}
	if not PurchaseEffectPipeline.apply_effect(player, effect, {
		"source": "attribute_shop_panel",
		"attribute_id": str(attr.get("attribute_id", ""))
	}):
		printerr("[AttributeShopPanel] 属性效果应用失败: %s" % str(effect))

# ============================================================================
# 按钮事件
# ============================================================================

func _on_reroll_button_pressed() -> void:
	"""刷新按钮被点击"""
	print("[AttributeShopPanel] 刷新按钮被点击")
	
	var reroll_cost = ShopAttributeManager.get_reroll_cost(current_wave)
	var gold = RunStateService.get_run_gold()
	
	if gold < reroll_cost:
		print("[AttributeShopPanel] 金币不足，无法刷新")
		SoundManager.play("ui_error")
		return
	
	SoundManager.play("ui_click")
	
	var result = ShopDomainService.try_reroll(reroll_cost, func() -> bool:
		purchased_indices.clear()
		var attributes = ShopAttributeManager.generate_shop_for_wave(current_wave)
		_display_attributes(attributes)
		return true
	)
	if not bool(result.get("success", false)):
		print("[AttributeShopPanel] 刷新失败: %s" % str(result.get("reason", "未知错误")))
		SoundManager.play("ui_error")
		return
	
	print("[AttributeShopPanel] 商店已刷新")

func _on_close_button_pressed() -> void:
	"""关闭按钮被点击"""
	print("[AttributeShopPanel] 关闭按钮被点击")
	SoundManager.play("ui_click")
	hide_shop()

func _on_gold_changed(new_gold: int) -> void:
	"""金币变化回调"""
	_update_gold_display()

# ============================================================================
# 调试接口
# ============================================================================

func print_current_attributes() -> void:
	"""打印当前属性（调试用）"""
	ShopAttributeManager.print_shop_attributes()
