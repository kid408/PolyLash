extends MarginContainer

signal menu_action(action: String)

const MENU_BUTTON_SCENE := preload("res://scenes/ui/main_menu/menu_button.tscn")
const COLOR_BG_PANEL := Color("#161B22")
const COLOR_BORDER := Color("#30363D")
const COLOR_TEXT := Color("#E6EDF3")
const COLOR_TEXT_DIM := Color("#8B949E")

const BUTTON_DEFS: Array = [
	["新游戏", "new_game"],
	["读取存档", "load_game"],
	["图鉴", "compendium"],
	["设置", "settings"],
	["鸣谢", "credits"],
	["退出", "quit"],
]

@onready var nav_list: VBoxContainer = $HBoxContainer/NavList
@onready var quick_start_panel: PanelContainer = $HBoxContainer/QuickStartPanel
@onready var quick_title: Label = $HBoxContainer/QuickStartPanel/QuickMargin/QuickVBox/QuickTitle
@onready var quick_subtitle: Label = $HBoxContainer/QuickStartPanel/QuickMargin/QuickVBox/QuickSubtitle
@onready var quick_portrait_1: TextureRect = $HBoxContainer/QuickStartPanel/QuickMargin/QuickVBox/QuickHeader/QuickPortraits/QuickPortrait1
@onready var quick_portrait_2: TextureRect = $HBoxContainer/QuickStartPanel/QuickMargin/QuickVBox/QuickHeader/QuickPortraits/QuickPortrait2
@onready var quick_portrait_3: TextureRect = $HBoxContainer/QuickStartPanel/QuickMargin/QuickVBox/QuickHeader/QuickPortraits/QuickPortrait3
@onready var quick_name: Label = $HBoxContainer/QuickStartPanel/QuickMargin/QuickVBox/QuickHeader/QuickInfo/QuickName
@onready var quick_time: Label = $HBoxContainer/QuickStartPanel/QuickMargin/QuickVBox/QuickHeader/QuickInfo/QuickTime
@onready var quick_detail: Label = $HBoxContainer/QuickStartPanel/QuickMargin/QuickVBox/QuickDetail

var _buttons: Array[Button] = []
var _quick_portraits: Array[TextureRect] = []
var _ui_font: Font

func _ready() -> void:
	_ui_font = _create_font()
	_quick_portraits = [quick_portrait_1, quick_portrait_2, quick_portrait_3]
	_apply_theme()
	if not quick_start_panel.gui_input.is_connected(_on_quick_start_gui_input):
		quick_start_panel.gui_input.connect(_on_quick_start_gui_input)
	_build_menu_buttons()
	_refresh_quick_start_panel()
	await get_tree().process_frame
	if not _buttons.is_empty():
		_buttons[0].grab_focus()

func refresh() -> void:
	_build_menu_buttons()
	_refresh_quick_start_panel()
	await get_tree().process_frame
	if not _buttons.is_empty():
		_buttons[0].grab_focus()

func _apply_theme() -> void:
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = COLOR_BG_PANEL
	panel_style.border_width_left = 1
	panel_style.border_width_top = 1
	panel_style.border_width_right = 1
	panel_style.border_width_bottom = 1
	panel_style.border_color = COLOR_BORDER
	panel_style.corner_radius_top_left = 12
	panel_style.corner_radius_top_right = 12
	panel_style.corner_radius_bottom_left = 12
	panel_style.corner_radius_bottom_right = 12
	quick_start_panel.add_theme_stylebox_override("panel", panel_style)

	for label in [quick_title, quick_name]:
		label.add_theme_font_override("font", _ui_font)
		label.add_theme_color_override("font_color", COLOR_TEXT)
	quick_title.add_theme_font_size_override("font_size", 24)
	quick_name.add_theme_font_size_override("font_size", 20)

	for label in [quick_subtitle, quick_time, quick_detail]:
		label.add_theme_font_override("font", _ui_font)
		label.add_theme_color_override("font_color", COLOR_TEXT_DIM)
	quick_subtitle.add_theme_font_size_override("font_size", 12)
	quick_time.add_theme_font_size_override("font_size", 14)
	quick_detail.add_theme_font_size_override("font_size", 15)

func _build_menu_buttons() -> void:
	for child in nav_list.get_children():
		child.queue_free()
	_buttons.clear()

	for def in BUTTON_DEFS:
		var button := MENU_BUTTON_SCENE.instantiate() as Button
		nav_list.add_child(button)
		button.setup(str(def[0]), str(def[1]))
		button.button_action.connect(_on_button_action)
		_buttons.append(button)

	_setup_focus_neighbors()

func _setup_focus_neighbors() -> void:
	for i in range(_buttons.size()):
		var button := _buttons[i]
		var prev_idx := i - 1 if i > 0 else _buttons.size() - 1
		var next_idx := i + 1 if i < _buttons.size() - 1 else 0
		button.focus_neighbor_top = _buttons[prev_idx].get_path()
		button.focus_neighbor_bottom = _buttons[next_idx].get_path()
		button.focus_neighbor_left = button.get_path()
		button.focus_neighbor_right = button.get_path()

func _refresh_quick_start_panel() -> void:
	var data := SaveManager.get_slot_data(0)
	if data.is_empty():
		_clear_quick_portraits()
		quick_name.text = "暂无存档"
		quick_time.text = "--:--:--"
		quick_detail.text = "创建存档后，这里会显示三人小队、进度与游戏时长。"
		quick_start_panel.mouse_default_cursor_shape = Control.CURSOR_ARROW
		return

	var player_ids := _extract_saved_player_ids(data)
	_update_quick_portraits(player_ids)
	quick_name.text = _build_team_name_text(player_ids) if not player_ids.is_empty() else "未记录小队"
	quick_time.text = SaveManager.format_play_time(int(data.get("play_time_seconds", 0)))

	var floor_num := int(data.get("current_floor", 1))
	var wave_num := int(data.get("current_wave", 1))
	if str(data.get("game_state", "")) == "in_battle" and data.has("battle_state"):
		var battle_state: Dictionary = data.get("battle_state", {})
		floor_num = int(battle_state.get("current_floor", floor_num))
		wave_num = int(battle_state.get("current_wave", wave_num))
	quick_detail.text = "进度：第 %d 层 / 波次 %d" % [floor_num, wave_num]
	quick_start_panel.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

func _update_quick_portraits(player_ids: Array[String]) -> void:
	for i in range(_quick_portraits.size()):
		var portrait := _quick_portraits[i]
		if i < player_ids.size():
			portrait.texture = _load_player_portrait(player_ids[i])
			portrait.visible = true
		else:
			portrait.texture = null
			portrait.visible = false

func _clear_quick_portraits() -> void:
	for portrait in _quick_portraits:
		portrait.texture = null
		portrait.visible = false

func _extract_saved_player_ids(data: Dictionary) -> Array[String]:
	var result: Array[String] = []
	var selected_players: Variant = data.get("selected_players", [])
	if selected_players is Array:
		for entry in selected_players:
			var player_id := ""
			if entry is Dictionary:
				player_id = str(entry.get("player_id", "")).strip_edges()
			elif entry is String:
				player_id = str(entry).strip_edges()
			if player_id.is_empty():
				continue
			result.append(player_id)
	if result.is_empty():
		var leader_id := str(data.get("leader_id", "")).strip_edges()
		if not leader_id.is_empty():
			result.append(leader_id)
	return result

func _build_team_name_text(player_ids: Array[String]) -> String:
	var names: Array[String] = []
	for player_id in player_ids:
		var intro := ConfigManager.get_player_intro(player_id)
		var config := ConfigManager.get_player_config(player_id)
		names.append(str(intro.get("display_name", config.get("display_name", player_id))))
	return " / ".join(names)

func _load_player_portrait(player_id: String) -> Texture2D:
	var config := ConfigManager.get_player_config(player_id)
	var portrait_path := str(config.get("portrait_sprite_path", "")).strip_edges()
	if not portrait_path.is_empty() and ResourceLoader.exists(portrait_path):
		return load(portrait_path) as Texture2D
	var visual := ConfigManager.get_player_visual(player_id)
	var sprite_path := str(visual.get("sprite_path", "")).strip_edges()
	if sprite_path.is_empty() or not ResourceLoader.exists(sprite_path):
		return null
	return load(sprite_path) as Texture2D

func _on_button_action(action: String) -> void:
	menu_action.emit(action)

func _on_quick_start_gui_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton):
		return
	var mouse_event := event as InputEventMouseButton
	if not mouse_event.pressed or mouse_event.button_index != MOUSE_BUTTON_LEFT:
		return
	if SaveManager.get_slot_data(0).is_empty():
		return
	SoundManager.play("ui_click")
	menu_action.emit("continue")

func _create_font() -> Font:
	var font := SystemFont.new()
	font.font_names = PackedStringArray([
		"Noto Sans SC",
		"Source Han Sans SC",
		"Microsoft YaHei UI",
		"Microsoft YaHei",
		"Segoe UI",
		"Arial",
	])
	font.font_weight = 600
	return font

