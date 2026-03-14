extends Control
class_name AttributeShopPanel

const DEBUG_VERBOSE := false

signal attribute_purchased(attribute_id: String)
signal shop_closed()

@onready var title_label: Label = %TitleLabel
@onready var gold_label: Label = %GoldLabel
@onready var wave_label: Label = %WaveLabel
@onready var attributes_container: HBoxContainer = %AttributesContainer
@onready var reroll_button: Button = %RerollButton
@onready var close_button: Button = %CloseButton

var attribute_card_scene: PackedScene = preload("res://scenes/ui/shop_panel/shop_item_card.tscn")
var current_wave: int = 1
var current_cards: Array = []
var purchased_indices: Array = []

func _ready() -> void:
	if reroll_button:
		reroll_button.pressed.connect(_on_reroll_button_pressed)
	if close_button:
		close_button.pressed.connect(_on_close_button_pressed)

	if DataManager.has_signal("run_gold_changed"):
		DataManager.run_gold_changed.connect(_on_gold_changed)
	elif DataManager.has_signal("gold_changed"):
		DataManager.gold_changed.connect(_on_gold_changed)

	visible = false

func show_shop(wave_number: int) -> void:
	if DEBUG_VERBOSE:
		print("[AttributeShopPanel] show wave=%d" % wave_number)
	current_wave = wave_number
	purchased_indices.clear()

	if wave_label:
		wave_label.text = "第%d波" % wave_number

	var attributes: Array = ShopAttributeManager.generate_shop_for_wave(wave_number)
	_display_attributes(attributes)
	_update_gold_display()
	visible = true
	SoundManager.play("ui_panel_open")

func hide_shop() -> void:
	visible = false
	SoundManager.play("ui_panel_close")
	shop_closed.emit()

func _display_attributes(attributes: Array) -> void:
	_clear_cards()

	for i in range(attributes.size()):
		var attr: Dictionary = attributes[i]
		var card = attribute_card_scene.instantiate()
		card.card_index = i
		var display_data: Dictionary = {
			"item_id": attr.attribute_id,
			"item_name": attr.display_name,
			"price": attr.price,
			"effects": [{
				"description": _format_attribute_description(attr),
				"is_trade_off": not bool(attr.is_positive)
			}]
		}
		card.setup(display_data)
		card.purchase_requested.connect(_on_card_purchase_requested)
		attributes_container.add_child(card)
		current_cards.append(card)

	_update_all_cards_affordability()

func _format_attribute_description(attr: Dictionary) -> String:
	var value_str: String = ""
	if attr.value_type == "flat":
		value_str = "%+.0f" % float(attr.value)
	else:
		value_str = "%+.0f%%" % (float(attr.value) * 100.0)

	var color := "[color=green]" if bool(attr.is_positive) else "[color=red]"
	return "%s%s: %s[/color]" % [color, str(attr.display_name), value_str]

func _clear_cards() -> void:
	for card in current_cards:
		card.queue_free()
	current_cards.clear()

func _update_gold_display() -> void:
	var gold: int = RunStateService.get_run_gold()
	if gold_label:
		gold_label.text = "金币: %d" % gold

	if reroll_button:
		var reroll_cost: int = ShopAttributeManager.get_reroll_cost(current_wave)
		reroll_button.disabled = gold < reroll_cost
		reroll_button.text = "刷新 (%d金币)" % reroll_cost

	_update_all_cards_affordability()

func _update_all_cards_affordability() -> void:
	var gold: int = RunStateService.get_run_gold()
	for card in current_cards:
		if card.has_method("set_affordable"):
			var price: int = int(card.item_data.get("price", 0))
			card.set_affordable(gold >= price)

func _on_card_purchase_requested(card_index: int) -> void:
	if card_index in purchased_indices:
		return

	var attributes: Array = ShopAttributeManager.get_current_shop_attributes()
	if card_index < 0 or card_index >= attributes.size():
		printerr("[AttributeShopPanel] invalid card_index: %d" % card_index)
		return

	var attr: Dictionary = attributes[card_index]
	var price: int = int(attr.price)
	var gold: int = RunStateService.get_run_gold()
	if gold < price:
		SoundManager.play("ui_error")
		return

	var result: Dictionary = ShopDomainService.try_purchase(price, func() -> bool:
		_apply_attribute_to_player(attr)
		return true
	)
	if not bool(result.get("success", false)):
		SoundManager.play("ui_error")
		return

	purchased_indices.append(card_index)
	if card_index < current_cards.size():
		current_cards[card_index].set_purchased(true)

	_update_gold_display()
	attribute_purchased.emit(str(attr.attribute_id))
	SoundManager.play("ui_purchase")

func _apply_attribute_to_player(attr: Dictionary) -> void:
	var player: Node = Global.player
	if not player:
		printerr("[AttributeShopPanel] player is null")
		return

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
		printerr("[AttributeShopPanel] apply effect failed: %s" % str(effect))

func _on_reroll_button_pressed() -> void:
	var reroll_cost: int = ShopAttributeManager.get_reroll_cost(current_wave)
	var gold: int = RunStateService.get_run_gold()
	if gold < reroll_cost:
		SoundManager.play("ui_error")
		return

	SoundManager.play("ui_click")
	var result: Dictionary = ShopDomainService.try_reroll(reroll_cost, func() -> bool:
		purchased_indices.clear()
		var attributes: Array = ShopAttributeManager.generate_shop_for_wave(current_wave)
		_display_attributes(attributes)
		return true
	)
	if not bool(result.get("success", false)):
		SoundManager.play("ui_error")
		return

func _on_close_button_pressed() -> void:
	SoundManager.play("ui_click")
	hide_shop()

func _on_gold_changed(_new_gold: int) -> void:
	_update_gold_display()

func print_current_attributes() -> void:
	ShopAttributeManager.print_shop_attributes()
