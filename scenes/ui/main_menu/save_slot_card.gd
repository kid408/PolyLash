extends PanelContainer
## 存档槽卡片：用于主菜单显示一个存档位（空槽/进行中/损坏）。

signal clicked(slot_index: int)
signal delete_requested(slot_index: int)

# UI 节点
@onready var slot_label: Label = $MarginContainer/VBox/SlotLabel
@onready var status_label: Label = $MarginContainer/VBox/StatusLabel
@onready var info_container: VBoxContainer = $MarginContainer/VBox/InfoContainer
@onready var portrait_1: TextureRect = $MarginContainer/VBox/InfoContainer/HBox/TeamPortraits/Portrait1
@onready var portrait_2: TextureRect = $MarginContainer/VBox/InfoContainer/HBox/TeamPortraits/Portrait2
@onready var portrait_3: TextureRect = $MarginContainer/VBox/InfoContainer/HBox/TeamPortraits/Portrait3
@onready var floor_wave_label: Label = $MarginContainer/VBox/InfoContainer/HBox/InfoVBox/FloorWaveLabel
@onready var team_label: Label = $MarginContainer/VBox/InfoContainer/HBox/InfoVBox/TeamLabel
@onready var bond_container: HBoxContainer = $MarginContainer/VBox/InfoContainer/HBox/InfoVBox/BondContainer
@onready var play_time_label: Label = $MarginContainer/VBox/InfoContainer/TimeVBox/PlayTimeLabel
@onready var last_played_label: Label = $MarginContainer/VBox/InfoContainer/TimeVBox/LastPlayedLabel
@onready var delete_button: Button = $DeleteButton
@onready var empty_label: Label = $MarginContainer/VBox/EmptyLabel
@onready var warning_icon: Label = $MarginContainer/VBox/WarningIcon

# 运行时状态
var _slot_index: int = -1
var _is_empty: bool = true
var _mode: String = "new_game"

# 样式缓存
var _style_normal: StyleBoxFlat = null
var _style_hover: StyleBoxFlat = null

# 颜色常量
const BORDER_EMPTY := Color("#666666")
const BORDER_ACTIVE := Color("#444444")
const BORDER_CORRUPTED := Color("#FF4444")
const BORDER_HOVER := Color("#4CAF50")
const BG_COLOR := Color("#222222")

# 字体与头像槽
var _font: Font = preload("res://assets/font/Bake Soda.otf")
var _portrait_slots: Array[TextureRect] = []

func _ready() -> void:
	_portrait_slots = [portrait_1, portrait_2, portrait_3]

	# 交互事件
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	delete_button.pressed.connect(_on_delete_pressed)
	gui_input.connect(_on_gui_input)

## 刷新一个存档槽卡片
func setup(slot_index: int, data: Dictionary, card_mode: String = "new_game") -> void:
	_slot_index = slot_index
	_mode = card_mode

	slot_label.text = "存档 %d" % (slot_index + 1)

	var is_corrupted := SaveManager.is_slot_corrupted(slot_index)
	_is_empty = data.is_empty() and not is_corrupted

	if is_corrupted:
		_setup_corrupted_state()
	elif data.is_empty():
		_setup_empty_state()
	else:
		_setup_active_state(data)

	_build_styles(is_corrupted)
	add_theme_stylebox_override("panel", _style_normal)

func _setup_empty_state() -> void:
	status_label.text = "空槽"
	status_label.visible = true
	empty_label.visible = true
	info_container.visible = false
	for slot in _portrait_slots:
		slot.texture = null
		slot.visible = false
	warning_icon.visible = false
	delete_button.visible = false

func _setup_active_state(data: Dictionary) -> void:
	var game_state: String = str(data.get("game_state", "in_progress"))
	if game_state == "character_selection":
		status_label.text = "可继续"
	else:
		status_label.text = "进行中"
	status_label.visible = true
	empty_label.visible = false
	info_container.visible = true
	warning_icon.visible = false
	delete_button.visible = (_mode == "new_game")
	_update_team_portraits(data)
	_update_team_text(data)
	if game_state == "character_selection":
		floor_wave_label.text = "角色准备中"
	elif game_state == "in_battle" and data.has("battle_state"):
		var battle_state: Dictionary = data.get("battle_state", {})
		var floor_num_battle: int = int(battle_state.get("current_floor", data.get("current_floor", 1)))
		var wave_num_battle: int = int(battle_state.get("current_wave", data.get("current_wave", 1)))
		floor_wave_label.text = "第%d层 - 波次%d" % [floor_num_battle, wave_num_battle]
	else:
		var floor_num: int = int(data.get("current_floor", 1))
		var wave_num: int = int(data.get("current_wave", 1))
		floor_wave_label.text = "第%d层 - 波次%d" % [floor_num, wave_num]

	_clear_children(bond_container)
	var bond_items: Array[String] = _build_bond_preview_items(data.get("bond_summary", []))
	for text in bond_items:
		var bond_label := Label.new()
		bond_label.text = text
		bond_label.custom_minimum_size = Vector2(72, 0)
		bond_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		bond_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		bond_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		bond_label.add_theme_font_size_override("font_size", 12)
		bond_label.add_theme_color_override("font_color", Color("#AAAAAA"))
		bond_label.add_theme_font_override("font", _font)
		bond_container.add_child(bond_label)

	var play_seconds: int = int(data.get("play_time_seconds", 0))
	play_time_label.text = SaveManager.format_play_time(play_seconds)

	var timestamp: int = int(data.get("last_played_timestamp", 0))
	last_played_label.text = SaveManager.format_last_played(timestamp)

func _setup_corrupted_state() -> void:
	status_label.text = "存档损坏"
	status_label.add_theme_color_override("font_color", BORDER_CORRUPTED)
	status_label.visible = true
	empty_label.visible = false
	info_container.visible = false
	for slot in _portrait_slots:
		slot.texture = null
		slot.visible = false
	warning_icon.visible = true
	delete_button.visible = true

func _build_styles(is_corrupted: bool) -> void:
	_style_normal = StyleBoxFlat.new()
	_style_normal.bg_color = BG_COLOR
	_style_normal.corner_radius_top_left = 8
	_style_normal.corner_radius_top_right = 8
	_style_normal.corner_radius_bottom_right = 8
	_style_normal.corner_radius_bottom_left = 8
	_style_normal.border_width_left = 2
	_style_normal.border_width_top = 2
	_style_normal.border_width_right = 2
	_style_normal.border_width_bottom = 2

	if is_corrupted:
		_style_normal.border_color = BORDER_CORRUPTED
	elif _is_empty:
		_style_normal.border_color = BORDER_EMPTY
		_style_normal.border_color.a = 0.5
	else:
		_style_normal.border_color = BORDER_ACTIVE

	_style_hover = _style_normal.duplicate()
	_style_hover.border_color = BORDER_HOVER

func _on_mouse_entered() -> void:
	add_theme_stylebox_override("panel", _style_hover)

func _on_mouse_exited() -> void:
	add_theme_stylebox_override("panel", _style_normal)

func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		clicked.emit(_slot_index)

func _on_delete_pressed() -> void:
	delete_requested.emit(_slot_index)

func _clear_children(container: Node) -> void:
	for child in container.get_children():
		child.queue_free()

func _update_team_portraits(data: Dictionary) -> void:
	var player_ids := _extract_saved_player_ids(data)

	for i in range(_portrait_slots.size()):
		var slot = _portrait_slots[i]
		if i < player_ids.size():
			var tex := _load_player_portrait(player_ids[i])
			slot.texture = tex
			slot.modulate = Color(1, 1, 1, 1)
			slot.visible = tex != null
			slot.tooltip_text = _get_player_display_name(player_ids[i])
		else:
			slot.texture = null
			slot.visible = false
			slot.tooltip_text = ""

func _update_team_text(data: Dictionary) -> void:
	var player_ids := _extract_saved_player_ids(data)
	if player_ids.is_empty():
		team_label.text = "队伍：未知"
		return

	var names: Array[String] = []
	for pid in player_ids:
		names.append(_get_player_display_name(pid))
	team_label.text = "队伍：%s" % " / ".join(names)

func _build_bond_preview_items(raw_bonds: Variant) -> Array[String]:
	var result: Array[String] = []
	if not (raw_bonds is Array):
		return ["无羁绊"]

	for entry in raw_bonds:
		var text := _format_bond_preview_item(entry)
		if text.is_empty():
			continue
		result.append(text)
		if result.size() >= 3:
			break

	if result.is_empty():
		result.append("无羁绊")
	return result

func _format_bond_preview_item(entry: Variant) -> String:
	if entry is Dictionary:
		var item: Dictionary = entry
		var bond_id := str(item.get("bond_id", "")).strip_edges()
		var level := int(item.get("level", 0))
		var count := int(item.get("count", 0))
		var display_name := _truncate_text(_get_bond_display_name(bond_id), 10)
		if level > 0 and count > 0:
			return "%s Lv.%d(%d)" % [display_name, level, count]
		if level > 0:
			return "%s Lv.%d" % [display_name, level]
		return display_name

	var text := str(entry).strip_edges()
	if text.begins_with("{") and text.ends_with("}"):
		return "羁绊已激活"
	return _truncate_text(text, 16)

func _get_bond_display_name(bond_id: String) -> String:
	if bond_id.is_empty():
		return "未知羁绊"
	if BondManager and BondManager.has_method("get_bond_display_name"):
		var name := str(BondManager.get_bond_display_name(bond_id)).strip_edges()
		if not name.is_empty():
			return name
	return bond_id

func _truncate_text(text: String, max_len: int) -> String:
	if max_len <= 0:
		return ""
	if text.length() <= max_len:
		return text
	return text.substr(0, max_len - 3) + "..."

func _extract_saved_player_ids(data: Dictionary) -> Array[String]:
	var result: Array[String] = []
	var selected_players = data.get("selected_players", [])
	if selected_players is Array:
		for entry in selected_players:
			var pid := ""
			if entry is Dictionary:
				pid = str(entry.get("player_id", "")).strip_edges()
			elif entry is String:
				pid = str(entry).strip_edges()
			if pid == "":
				continue
			result.append(pid)
			if result.size() >= _portrait_slots.size():
				return result

	var leader_id := str(data.get("leader_id", "")).strip_edges()
	if result.is_empty() and leader_id != "":
		result.append(leader_id)
	return result

func _load_player_portrait(player_id: String) -> Texture2D:
	var visual := ConfigManager.get_player_visual(player_id)
	var sprite_path := str(visual.get("sprite_path", "")).strip_edges()
	if sprite_path == "" or not ResourceLoader.exists(sprite_path):
		return null
	return load(sprite_path) as Texture2D

func _get_player_display_name(player_id: String) -> String:
	var config := ConfigManager.get_player_config(player_id)
	return str(config.get("display_name", player_id))
