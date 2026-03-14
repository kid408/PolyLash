extends Control
class_name ShopPanel

const DEBUG_VERBOSE := false

signal next_wave_requested()

@onready var gold_label: Label = %GoldLabel
@onready var items_container: HBoxContainer = %ItemsContainer
@onready var reroll_button: Button = %RerollButton
@onready var next_wave_button: Button = %NextWaveButton

var shop_item_card_scene: PackedScene = preload("res://scenes/ui/shop_panel/shop_item_card.tscn")
var item_cards: Array = []

func _ready() -> void:
	reroll_button.pressed.connect(_on_reroll_button_pressed)
	next_wave_button.pressed.connect(_on_next_wave_button_pressed)

	ShopManager.shop_items_generated.connect(_on_shop_items_generated)
	ShopManager.item_purchased.connect(_on_item_purchased)
	ShopManager.shop_rerolled.connect(_on_shop_rerolled)
	ShopManager.purchase_failed.connect(_on_purchase_failed)

	if DataManager.has_signal("run_gold_changed"):
		DataManager.run_gold_changed.connect(_on_gold_changed)
		if DEBUG_VERBOSE:
			print("[ShopPanel] connected run_gold_changed")
	elif DataManager.has_signal("gold_changed"):
		DataManager.gold_changed.connect(_on_gold_changed)
		if DEBUG_VERBOSE:
			print("[ShopPanel] connected gold_changed")
	else:
		printerr("[ShopPanel] DataManager has no gold signal")

	visible = false

func show_shop(wave_number: int) -> void:
	if DEBUG_VERBOSE:
		print("[ShopPanel] show_shop wave=%d" % wave_number)
	next_wave_button.text = "开始第 %d 波" % wave_number
	ShopManager.generate_shop_items(3)
	_update_gold_display()
	visible = true
	SoundManager.play("ui_panel_open")
	PauseService.request_pause("shop_panel", get_tree())

func hide_shop() -> void:
	if DEBUG_VERBOSE:
		print("[ShopPanel] hide_shop")
	SoundManager.play("ui_panel_close")
	visible = false
	PauseService.release_pause("shop_panel", get_tree())

func _update_gold_display() -> void:
	var gold: int = RunStateService.get_run_gold()
	gold_label.text = "金币: %d" % gold

	var reroll_cost: int = ShopManager.get_reroll_cost()
	reroll_button.disabled = gold < reroll_cost
	reroll_button.text = "刷新 (%d金币)" % reroll_cost

	for card in item_cards:
		if card is ShopItemCard:
			var item_price: int = int(card.item_data.get("price", 0))
			card.set_affordable(gold >= item_price)

func _clear_item_cards() -> void:
	for card in item_cards:
		card.queue_free()
	item_cards.clear()

func _create_item_cards(items: Array) -> void:
	_clear_item_cards()

	for i in range(items.size()):
		var item: Dictionary = items[i]
		var card := shop_item_card_scene.instantiate() as ShopItemCard
		items_container.add_child(card)
		item_cards.append(card)
		card.setup(i, item)
		card.purchase_requested.connect(_on_card_purchase_requested)
		if ShopManager.is_item_purchased(i):
			card.set_purchased(true)

	_update_gold_display()

func _on_shop_items_generated(items: Array) -> void:
	if DEBUG_VERBOSE:
		print("[ShopPanel] generated items=%d" % items.size())
	_create_item_cards(items)

func _on_card_purchase_requested(card_index: int) -> void:
	ShopManager.purchase_item(card_index)

func _on_item_purchased(item_id: String, index: int) -> void:
	if DEBUG_VERBOSE:
		print("[ShopPanel] purchased item=%s index=%d" % [item_id, index])
	SoundManager.play("ui_purchase")
	if index >= 0 and index < item_cards.size():
		var card = item_cards[index]
		if card is ShopItemCard:
			card.set_purchased(true)
	_update_gold_display()

func _on_shop_rerolled() -> void:
	if DEBUG_VERBOSE:
		print("[ShopPanel] rerolled")

func _on_purchase_failed(reason: String) -> void:
	if DEBUG_VERBOSE:
		print("[ShopPanel] purchase failed: %s" % reason)
	SoundManager.play("ui_error")

func _on_gold_changed(_new_gold: int) -> void:
	_update_gold_display()

func _on_reroll_button_pressed() -> void:
	SoundManager.play("ui_click")
	ShopManager.reroll_shop()

func _on_next_wave_button_pressed() -> void:
	SoundManager.play("ui_click")
	hide_shop()
	next_wave_requested.emit()
