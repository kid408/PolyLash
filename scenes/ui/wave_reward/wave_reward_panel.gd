extends Control
class_name WaveRewardPanel

signal reward_chosen(reward_data: Dictionary)

var wave_reward_system: Node = null

@export var reward_card_scene: PackedScene = preload("res://scenes/ui/wave_reward/reward_card.tscn")

@onready var cards_container: HBoxContainer = %CardsContainer

var cards: Array[RewardCard] = []

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false

func show_rewards(options: Array[Dictionary]) -> void:
	_clear_cards()

	for i in range(options.size()):
		var card: RewardCard = null
		if reward_card_scene:
			card = reward_card_scene.instantiate() as RewardCard
		if card == null:
			card = RewardCard.new()

		cards_container.add_child(card)
		card.setup(i, options[i])
		card.card_pressed.connect(_on_card_pressed)
		cards.append(card)

	visible = true
	get_tree().paused = true
	SoundManager.play("ui_panel_open")
	print("[WaveRewardPanel] 显示 %d 个奖励选项" % options.size())

func _hide_panel() -> void:
	visible = false
	_clear_cards()
	SoundManager.play("ui_panel_close")
	get_tree().paused = false
	print("[WaveRewardPanel] 面板关闭，游戏恢复")

func _clear_cards() -> void:
	for card in cards:
		if is_instance_valid(card):
			card.queue_free()
	cards.clear()

func _on_card_pressed(index: int) -> void:
	print("[WaveRewardPanel] 玩家选择了奖励 #%d" % index)

	if wave_reward_system and wave_reward_system.has_method("select_reward"):
		wave_reward_system.select_reward(index)

	var reward: Dictionary = {}
	if index >= 0 and index < cards.size():
		reward = cards[index].reward_data
	reward_chosen.emit(reward)

	_hide_panel()
