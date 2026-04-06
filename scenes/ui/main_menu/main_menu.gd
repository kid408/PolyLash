extends Control

signal menu_action(action: String)

const MENU_BUTTON_SCENE = preload("res://scenes/ui/main_menu/menu_button.tscn")

const CONTINUE_FONT_SIZE := 47
const CONTINUE_COLOR := Color("#4CAF50")

const BUTTON_DEFS: Array = [
	["继续游戏", "continue", true],
	["新游戏", "new_game", false],
	["读取存档", "load_game", false],
	["图鉴", "compendium", false],
	["设置", "settings", false],
	["制作名单", "credits", false],
	["退出游戏", "quit", false],
]

@onready var button_container: VBoxContainer = $ButtonContainer
@onready var continue_info_card: PanelContainer = $ContinueInfoCard
@onready var card_portrait_1: TextureRect = $ContinueInfoCard/CardMargin/CardVBox/CardHeader/CardPortraits/CardPortrait1
@onready var card_portrait_2: TextureRect = $ContinueInfoCard/CardMargin/CardVBox/CardHeader/CardPortraits/CardPortrait2
@onready var card_portrait_3: TextureRect = $ContinueInfoCard/CardMargin/CardVBox/CardHeader/CardPortraits/CardPortrait3
@onready var card_name_label: Label = $ContinueInfoCard/CardMargin/CardVBox/CardHeader/CardNameLabel
@onready var card_floor_label: Label = $ContinueInfoCard/CardMargin/CardVBox/CardFloorLabel
@onready var card_time_label: Label = $ContinueInfoCard/CardMargin/CardVBox/CardTimeLabel

var _buttons: Array[Button] = []
var _continue_button: Button = null
var _card_portrait_slots: Array[TextureRect] = []

func _ready() -> void:
	_card_portrait_slots = [card_portrait_1, card_portrait_2, card_portrait_3]
	continue_info_card.visible = false
	_build_menu_buttons()
	await get_tree().process_frame
	_focus_first_visible_button()

func _build_menu_buttons() -> void:
	for child in button_container.get_children():
		child.queue_free()
	_buttons.clear()
	_continue_button = null

	var has_save: bool = SaveManager.has_any_save()
	for def: Array in BUTTON_DEFS:
		var label_text: String = str(def[0])
		var action: String = str(def[1])
		var is_continue: bool = bool(def[2])

		if is_continue and not has_save:
			continue

		var btn := MENU_BUTTON_SCENE.instantiate() as Button
		button_container.add_child(btn)
		btn.setup(label_text, action)

		if is_continue:
			_continue_button = btn
			btn.add_theme_font_size_override("font_size", CONTINUE_FONT_SIZE)
			btn.add_theme_color_override("font_color", CONTINUE_COLOR)
			btn.mouse_entered.connect(_on_continue_hover_enter)
			btn.mouse_exited.connect(_on_continue_hover_exit)
			btn.focus_entered.connect(_on_continue_hover_enter)
			btn.focus_exited.connect(_on_continue_hover_exit)

		btn.button_action.connect(_on_button_action)
		_buttons.append(btn)

	_setup_focus_neighbors()

func _setup_focus_neighbors() -> void:
	for i in range(_buttons.size()):
		var btn: Button = _buttons[i]
		var prev_idx: int = i - 1 if i > 0 else _buttons.size() - 1
		var next_idx: int = i + 1 if i < _buttons.size() - 1 else 0
		btn.focus_neighbor_top = _buttons[prev_idx].get_path()
		btn.focus_neighbor_bottom = _buttons[next_idx].get_path()
		btn.focus_neighbor_left = btn.get_path()
		btn.focus_neighbor_right = btn.get_path()

func _focus_first_visible_button() -> void:
	if not _buttons.is_empty():
		_buttons[0].grab_focus()

func _on_continue_hover_enter() -> void:
	var slot_index: int = SaveManager.get_most_recent_slot()
	if slot_index < 0:
		return

	var data: Dictionary = SaveManager.get_slot_data(slot_index)
	if data.is_empty():
		return

	var player_ids: Array[String] = _extract_saved_player_ids(data)
	_update_continue_portraits(player_ids)
	card_name_label.text = _build_team_name_text(player_ids)

	var game_state: String = str(data.get("game_state", "in_progress"))
	if game_state == "character_selection":
		card_floor_label.text = "角色选择"
	elif game_state == "in_battle" and data.has("battle_state"):
		var battle_state: Dictionary = data.get("battle_state", {})
		var floor_num_battle: int = int(battle_state.get("current_floor", data.get("current_floor", 1)))
		var wave_num_battle: int = int(battle_state.get("current_wave", data.get("current_wave", 1)))
		card_floor_label.text = "第 %d 层 - 第 %d 波" % [floor_num_battle, wave_num_battle]
	else:
		var floor_num: int = int(data.get("current_floor", 1))
		var wave_num: int = int(data.get("current_wave", 1))
		card_floor_label.text = "第 %d 层 - 第 %d 波" % [floor_num, wave_num]

	var play_seconds: int = int(data.get("play_time_seconds", 0))
	card_time_label.text = SaveManager.format_play_time(play_seconds)
	continue_info_card.visible = true

func _on_continue_hover_exit() -> void:
	continue_info_card.visible = false

func _update_continue_portraits(player_ids: Array[String]) -> void:
	for i in range(_card_portrait_slots.size()):
		var slot: TextureRect = _card_portrait_slots[i]
		if i < player_ids.size():
			var tex: Texture2D = _load_player_portrait(player_ids[i])
			slot.texture = tex
			slot.visible = tex != null
			slot.tooltip_text = _get_player_display_name(player_ids[i])
		else:
			slot.texture = null
			slot.visible = false
			slot.tooltip_text = ""

func _build_team_name_text(player_ids: Array[String]) -> String:
	if player_ids.is_empty():
		return "暂无队伍"
	var names: Array[String] = []
	for pid in player_ids:
		names.append(_get_player_display_name(pid))
	return " / ".join(names)

func _extract_saved_player_ids(data: Dictionary) -> Array[String]:
	var result: Array[String] = []
	var selected_players: Variant = data.get("selected_players", [])
	if selected_players is Array:
		for entry in selected_players:
			var pid: String = ""
			if entry is Dictionary:
				pid = str(entry.get("player_id", "")).strip_edges()
			elif entry is String:
				pid = str(entry).strip_edges()
			if pid.is_empty():
				continue
			result.append(pid)
			if result.size() >= _card_portrait_slots.size():
				return result

	var leader_id: String = str(data.get("leader_id", "")).strip_edges()
	if result.is_empty() and not leader_id.is_empty():
		result.append(leader_id)
	return result

func _load_player_portrait(player_id: String) -> Texture2D:
	var visual: Dictionary = ConfigManager.get_player_visual(player_id)
	var sprite_path: String = str(visual.get("sprite_path", "")).strip_edges()
	if sprite_path.is_empty() or not ResourceLoader.exists(sprite_path):
		return null
	return load(sprite_path) as Texture2D

func _get_player_display_name(player_id: String) -> String:
	var config: Dictionary = ConfigManager.get_player_config(player_id)
	return str(config.get("display_name", player_id))

func _on_button_action(action: String) -> void:
	menu_action.emit(action)

func refresh() -> void:
	_build_menu_buttons()
	await get_tree().process_frame
	_focus_first_visible_button()
