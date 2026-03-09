extends Control
class_name WaveRewardPanel

signal reward_chosen(reward_data: Dictionary)

var wave_reward_system: Node = null

@export var reward_card_scene: PackedScene = preload("res://scenes/ui/wave_reward/reward_card.tscn")
const CHARACTER_UPGRADE_SCENE: PackedScene = preload("res://scenes/ui/selection_panel/character_upgrade.tscn")

@onready var cards_container: HBoxContainer = %CardsContainer
@onready var upgrade_button: Button = %UpgradeButton
@onready var replace_picker_layer: ColorRect = %ReplacePickerLayer
@onready var replace_title_label: Label = %ReplaceTitleLabel
@onready var replace_candidates_container: VBoxContainer = %ReplaceCandidatesContainer
@onready var replace_cancel_button: Button = %ReplaceCancelButton

var cards: Array[RewardCard] = []
var _embedded_upgrade_panel: CharacterUpgradePanel = null
var _pending_replace_option_index: int = -1

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	if is_instance_valid(upgrade_button):
		upgrade_button.pressed.connect(_on_upgrade_button_pressed)
	if is_instance_valid(replace_cancel_button):
		replace_cancel_button.pressed.connect(_on_replace_cancel_pressed)
	if is_instance_valid(replace_picker_layer):
		replace_picker_layer.visible = false

func show_rewards(options: Array[Dictionary]) -> void:
	if options.is_empty():
		push_warning("[WaveRewardPanel] reward options is empty")
		return

	_close_replace_picker(false)
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
	_set_reward_interactable(true)
	PauseService.request_pause("wave_reward_panel", get_tree())
	SoundManager.play("ui_panel_open")
	print("[WaveRewardPanel] show %d reward options" % options.size())

func _hide_panel() -> void:
	if is_instance_valid(_embedded_upgrade_panel):
		_embedded_upgrade_panel.queue_free()
		_embedded_upgrade_panel = null
	_close_replace_picker(false)
	visible = false
	_set_reward_interactable(false)
	_clear_cards()
	SoundManager.play("ui_panel_close")
	PauseService.release_pause("wave_reward_panel", get_tree())
	print("[WaveRewardPanel] panel closed")

func _clear_cards() -> void:
	for card in cards:
		if is_instance_valid(card):
			card.queue_free()
	cards.clear()

func _on_card_pressed(index: int) -> void:
	if is_instance_valid(_embedded_upgrade_panel):
		return
	if _is_replace_picker_visible():
		return
	if index < 0 or index >= cards.size():
		return

	var reward: Dictionary = cards[index].reward_data
	if _needs_replace_picker(reward):
		_show_replace_picker(index, reward)
		return

	_apply_reward(index)

func _apply_reward(index: int) -> void:
	print("[WaveRewardPanel] player selected reward #%d" % index)

	var reward_applied: bool = true
	if wave_reward_system and wave_reward_system.has_method("select_reward"):
		var result: Variant = wave_reward_system.select_reward(index)
		if result is bool:
			reward_applied = bool(result)

	if not reward_applied:
		SoundManager.play("ui_error")
		print("[WaveRewardPanel] reward apply failed, keep panel opened")
		return

	var reward: Dictionary = {}
	if index >= 0 and index < cards.size():
		reward = cards[index].reward_data
	reward_chosen.emit(reward)

	_hide_panel()

func _needs_replace_picker(reward: Dictionary) -> bool:
	var reward_type: String = str(reward.get("type", ""))
	if reward_type != "recruit_replace":
		return false
	return bool(reward.get("requires_replace_choose", false))

func _show_replace_picker(option_index: int, reward: Dictionary) -> void:
	if not is_instance_valid(replace_picker_layer):
		push_warning("[WaveRewardPanel] replace picker layer missing")
		return

	_clear_replace_candidate_buttons()
	_pending_replace_option_index = option_index

	var candidates_raw: Variant = reward.get("replace_candidates", [])
	if not (candidates_raw is Array):
		push_warning("[WaveRewardPanel] replace candidates invalid")
		_pending_replace_option_index = -1
		return

	var candidate_count: int = 0
	for entry in candidates_raw:
		if not (entry is Dictionary):
			continue
		var candidate: Dictionary = entry
		var player_id: String = str(candidate.get("player_id", ""))
		if player_id.is_empty():
			continue

		var display_name: String = str(candidate.get("display_name", player_id))
		var button: Button = Button.new()
		button.custom_minimum_size = Vector2(280, 44)
		button.text = "Replace %s" % display_name
		button.set_meta("replace_player_id", player_id)
		button.focus_mode = Control.FOCUS_NONE
		button.pressed.connect(_on_replace_candidate_pressed.bind(button))
		replace_candidates_container.add_child(button)
		candidate_count += 1

	if candidate_count <= 0:
		push_warning("[WaveRewardPanel] no valid replace candidates")
		_pending_replace_option_index = -1
		return

	if is_instance_valid(replace_title_label):
		replace_title_label.text = "Choose one teammate to replace"

	replace_picker_layer.visible = true
	_set_reward_interactable(false)
	SoundManager.play("ui_panel_open")

func _on_replace_candidate_pressed(source_button: Button) -> void:
	if not is_instance_valid(source_button):
		return
	if _pending_replace_option_index < 0:
		return

	var out_player_id: String = str(source_button.get_meta("replace_player_id", ""))
	if out_player_id.is_empty():
		return

	var option_index: int = _pending_replace_option_index
	var update_ok: bool = true
	if wave_reward_system and wave_reward_system.has_method("set_option_context"):
		var context: Dictionary = {
			"replace_out_player_id": out_player_id,
			"requires_replace_choose": false
		}
		var update_result: Variant = wave_reward_system.set_option_context(option_index, context)
		if update_result is bool:
			update_ok = bool(update_result)
	else:
		update_ok = false

	if not update_ok:
		SoundManager.play("ui_error")
		push_warning("[WaveRewardPanel] failed to set replace target")
		return

	if option_index >= 0 and option_index < cards.size():
		var reward_data: Dictionary = cards[option_index].reward_data.duplicate(true)
		reward_data["replace_out_player_id"] = out_player_id
		reward_data["requires_replace_choose"] = false
		cards[option_index].reward_data = reward_data

	_close_replace_picker(true)
	_apply_reward(option_index)

func _on_replace_cancel_pressed() -> void:
	_close_replace_picker(true)

func _close_replace_picker(restore_interactable: bool = true) -> void:
	_pending_replace_option_index = -1
	_clear_replace_candidate_buttons()
	if is_instance_valid(replace_picker_layer):
		replace_picker_layer.visible = false

	if not restore_interactable:
		return
	if not visible:
		return
	if is_instance_valid(_embedded_upgrade_panel):
		return
	_set_reward_interactable(true)

func _clear_replace_candidate_buttons() -> void:
	if not is_instance_valid(replace_candidates_container):
		return
	for child in replace_candidates_container.get_children():
		if is_instance_valid(child):
			child.queue_free()

func _is_replace_picker_visible() -> bool:
	return is_instance_valid(replace_picker_layer) and replace_picker_layer.visible

func _on_upgrade_button_pressed() -> void:
	if is_instance_valid(_embedded_upgrade_panel):
		return
	if _is_replace_picker_visible():
		return
	if CHARACTER_UPGRADE_SCENE == null:
		printerr("[WaveRewardPanel] unable to load character upgrade scene")
		return

	var panel: Node = CHARACTER_UPGRADE_SCENE.instantiate()
	if panel == null:
		printerr("[WaveRewardPanel] character upgrade scene instantiate failed")
		return
	if panel is CharacterUpgradePanel:
		_embedded_upgrade_panel = panel as CharacterUpgradePanel
		_embedded_upgrade_panel.configure_context(true, true)
		_embedded_upgrade_panel.close_requested.connect(_on_upgrade_panel_closed)
		_set_reward_interactable(false)
		add_child(_embedded_upgrade_panel)
		move_child(_embedded_upgrade_panel, get_child_count() - 1)
		SoundManager.play("ui_panel_open")
	else:
		add_child(panel)
		printerr("[WaveRewardPanel] character upgrade panel type mismatch")

func _on_upgrade_panel_closed() -> void:
	_embedded_upgrade_panel = null
	if not _is_replace_picker_visible():
		_set_reward_interactable(true)

func _set_reward_interactable(enabled: bool) -> void:
	if is_instance_valid(upgrade_button):
		upgrade_button.disabled = not enabled
	for card in cards:
		if is_instance_valid(card):
			card.set_selectable(enabled)