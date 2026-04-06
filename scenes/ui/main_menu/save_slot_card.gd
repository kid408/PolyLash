extends PanelContainer

signal clicked(slot_index: int)
signal delete_requested(slot_index: int)

const COLOR_BG := Color("#161B22")
const COLOR_BORDER := Color("#30363D")
const COLOR_ACCENT := Color("#00F0FF")
const COLOR_TEXT := Color("#E6EDF3")
const COLOR_DIM := Color("#8B949E")

@onready var slot_label: Label = $MarginContainer/VBox/Header/SlotLabel
@onready var timestamp_label: Label = $MarginContainer/VBox/Header/TimestampLabel
@onready var portrait_1: TextureRect = $MarginContainer/VBox/CenterAvatars/PortraitRow/Portrait1
@onready var portrait_2: TextureRect = $MarginContainer/VBox/CenterAvatars/PortraitRow/Portrait2
@onready var portrait_3: TextureRect = $MarginContainer/VBox/CenterAvatars/PortraitRow/Portrait3
@onready var status_label: Label = $MarginContainer/VBox/MetaVBox/StatusLabel
@onready var team_label: Label = $MarginContainer/VBox/MetaVBox/TeamLabel
@onready var progress_label: Label = $MarginContainer/VBox/MetaVBox/ProgressLabel

var _slot_index := -1
var _mode := "new_game"
var _portrait_slots: Array[TextureRect] = []
var _ui_font: Font
var _style_normal: StyleBoxFlat
var _style_active: StyleBoxFlat
var _hover_tween: Tween

func _ready() -> void:
	_ui_font = _create_font()
	_portrait_slots = [portrait_1, portrait_2, portrait_3]
	_apply_theme()
	mouse_entered.connect(_set_focused.bind(true))
	mouse_exited.connect(_set_focused.bind(false))
	focus_entered.connect(_set_focused.bind(true))
	focus_exited.connect(_set_focused.bind(false))
	gui_input.connect(_on_gui_input)

func setup(slot_index: int, data: Dictionary, card_mode: String = "new_game") -> void:
	_slot_index = slot_index
	_mode = card_mode
	slot_label.text = "存档 %d" % (slot_index + 1)

	if data.is_empty():
		_apply_empty_state()
	else:
		_apply_active_state(data)
	_set_focused(false)

func _apply_theme() -> void:
	for label in [slot_label, status_label, team_label, progress_label, timestamp_label]:
		label.add_theme_font_override("font", _ui_font)
	slot_label.add_theme_font_size_override("font_size", 24)
	slot_label.add_theme_color_override("font_color", COLOR_TEXT)
	timestamp_label.add_theme_font_size_override("font_size", 14)
	timestamp_label.add_theme_color_override("font_color", COLOR_DIM)
	status_label.add_theme_font_size_override("font_size", 18)
	status_label.add_theme_color_override("font_color", COLOR_TEXT)
	team_label.add_theme_font_size_override("font_size", 18)
	team_label.add_theme_color_override("font_color", COLOR_TEXT)
	progress_label.add_theme_font_size_override("font_size", 14)
	progress_label.add_theme_color_override("font_color", COLOR_DIM)

	_style_normal = _build_style(COLOR_BORDER, 1)
	_style_active = _build_style(COLOR_ACCENT, 2)
	add_theme_stylebox_override("panel", _style_normal)

func _apply_empty_state() -> void:
	timestamp_label.text = "空槽"
	status_label.text = "等待写入"
	team_label.text = "暂无角色数据"
	progress_label.text = "点击以%s" % ("覆盖创建" if _mode == "new_game" else "载入")
	for slot in _portrait_slots:
		slot.texture = null
		slot.modulate = Color(0.2, 0.2, 0.2, 1.0)

func _apply_active_state(data: Dictionary) -> void:
	timestamp_label.text = SaveManager.format_last_played(int(data.get("last_played_timestamp", 0)))
	status_label.text = "可继续" if str(data.get("game_state", "")) == "character_selection" else "进行中"
	team_label.text = _build_team_name_text(_extract_saved_player_ids(data))
	progress_label.text = _build_progress_text(data)
	_update_portraits(_extract_saved_player_ids(data))

func _build_progress_text(data: Dictionary) -> String:
	var play_time := SaveManager.format_play_time(int(data.get("play_time_seconds", 0)))
	if str(data.get("game_state", "")) == "in_battle" and data.has("battle_state"):
		var battle_state: Dictionary = data.get("battle_state", {})
		return "第 %d 层 / 波次 %d    %s" % [
			int(battle_state.get("current_floor", data.get("current_floor", 1))),
			int(battle_state.get("current_wave", data.get("current_wave", 1))),
			play_time,
		]
	return "第 %d 层 / 波次 %d    %s" % [
		int(data.get("current_floor", 1)),
		int(data.get("current_wave", 1)),
		play_time,
	]

func _update_portraits(player_ids: Array[String]) -> void:
	for i in range(_portrait_slots.size()):
		var slot := _portrait_slots[i]
		if i < player_ids.size():
			slot.texture = _load_player_portrait(player_ids[i])
			slot.modulate = Color.WHITE
		else:
			slot.texture = null
			slot.modulate = Color(0.2, 0.2, 0.2, 1.0)

func _build_team_name_text(player_ids: Array[String]) -> String:
	if player_ids.is_empty():
		return "未记录小队"
	var names: Array[String] = []
	for player_id in player_ids:
		var intro := ConfigManager.get_player_intro(player_id)
		var config := ConfigManager.get_player_config(player_id)
		names.append(str(intro.get("display_name", config.get("display_name", player_id))))
	return " / ".join(names)

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

func _set_focused(active: bool) -> void:
	if _hover_tween:
		_hover_tween.kill()
	add_theme_stylebox_override("panel", _style_active if active else _style_normal)
	_hover_tween = create_tween()
	_hover_tween.tween_property(self, "scale", Vector2(1.01, 1.01) if active else Vector2.ONE, 0.14)

func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.pressed and mouse_event.button_index == MOUSE_BUTTON_LEFT:
			clicked.emit(_slot_index)

func _build_style(border_color: Color, border_width: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = COLOR_BG
	style.border_width_left = border_width
	style.border_width_top = border_width
	style.border_width_right = border_width
	style.border_width_bottom = 4
	style.border_color = border_color
	style.corner_radius_top_left = 12
	style.corner_radius_top_right = 12
	style.corner_radius_bottom_left = 12
	style.corner_radius_bottom_right = 12
	return style

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
	font.font_weight = 500
	return font
