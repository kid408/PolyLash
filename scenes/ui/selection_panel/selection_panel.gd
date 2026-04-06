extends Panel
class_name SelectionPanel

const ARENA_SCENE_PATH := "res://scenes/arena/arena.tscn"
const MAIN_MENU_SCENE_PATH := "res://scenes/ui/main_menu/main_menu_root.tscn"
const MAX_SELECTED_PLAYERS := 3
const PLAYER_BUTTON_SIZE := 120
const GRID_COLUMNS := 5

const CLASS_GROUP_ORDER: Array[String] = ["vanguard", "mystic", "sentinel", "harmony"]
const CLASS_GROUP_TITLES := {
	"sentinel": "御阵 (Sentinel)",
	"vanguard": "锋芒 (Vanguard)",
	"mystic": "术理 (Mystic)",
	"harmony": "协律 (Harmony)",
}
const CLASS_GROUP_ALIASES := {
	"sentinel": "sentinel",
	"御阵": "sentinel",
	"colossus": "sentinel",
	"architect": "sentinel",
	"vanguard": "vanguard",
	"锋芒": "vanguard",
	"nomad": "vanguard",
	"mystic": "mystic",
	"术理": "mystic",
	"inkborn": "mystic",
	"blaster": "mystic",
	"hexer": "mystic",
	"geometrist": "mystic",
	"harmony": "harmony",
	"协律": "harmony",
	"alchemist": "harmony",
	"assist": "harmony",
	"commander": "harmony",
}
const DISPLAY_CLASS_BY_PLAYER := {
	"minimalist": "vanguard",
	"collapse": "mystic",
	"parasite": "mystic",
	"joule": "sentinel",
	"phalanx": "sentinel",
	"silk": "harmony",
	"arc": "vanguard",
	"overtone": "harmony",
}

const DEFAULT_WEAPON_BY_PLAYER := {
	"minimalist": "sword",
	"collapse": "laser",
	"parasite": "punch",
	"joule": "shotgun",
	"phalanx": "shotgun",
	"silk": "wand",
	"arc": "laser",
	"overtone": "wand",
}

@onready var left_title: Label = $MarginContainer/HBoxContainer/LeftPanel/Label
@onready var synergy_title: Label = $MarginContainer/HBoxContainer/LeftPanel/SynergyLabel
@onready var role_title: Label = $MarginContainer/HBoxContainer/MainContent/MiddleSection/Label
@onready var weapon_title: Label = $MarginContainer/HBoxContainer/MainContent/BottomSection/Label2
@onready var player_scroll_container: ScrollContainer = $MarginContainer/HBoxContainer/MainContent/MiddleSection/PlayerContainerWrapper/PlayerScrollContainer
@onready var player_container: Container = $MarginContainer/HBoxContainer/MainContent/MiddleSection/PlayerContainerWrapper/PlayerScrollContainer/PlayerContainer
@onready var weapon_container: GridContainer = $MarginContainer/HBoxContainer/MainContent/BottomSection/WeaponContainerWrapper/WeaponContainer
@onready var selected_list: VBoxContainer = $MarginContainer/HBoxContainer/LeftPanel/SelectedList
@onready var synergy_list: VBoxContainer = $MarginContainer/HBoxContainer/LeftPanel/SynergyScrollContainer/SynergyList
@onready var player_ico: TextureRect = $MarginContainer/HBoxContainer/MainContent/TopSection/InfoPanel/MarginContainer/PlayerInfo/PlayerIco
@onready var player_name_label: Label = $MarginContainer/HBoxContainer/MainContent/TopSection/InfoPanel/MarginContainer/PlayerInfo/StatsColumn/PlayerName
@onready var player_ties_label: Label = $MarginContainer/HBoxContainer/MainContent/TopSection/InfoPanel/MarginContainer/PlayerInfo/StatsColumn/PlayerTies
@onready var bond_icons_container: HBoxContainer = $MarginContainer/HBoxContainer/MainContent/TopSection/InfoPanel/MarginContainer/PlayerInfo/StatsColumn/BondIconsContainer
@onready var player_description: RichTextLabel = $MarginContainer/HBoxContainer/MainContent/TopSection/InfoPanel/MarginContainer/PlayerInfo/StatsColumn/StatsScroll/PlayerDescription
@onready var skill_description: RichTextLabel = $MarginContainer/HBoxContainer/MainContent/TopSection/InfoPanel/MarginContainer/PlayerInfo/SkillColumn/SkillDescription
@onready var continue_button: Button = $MarginContainer/HBoxContainer/RightPanel/Continue
@onready var warehouse_button: Button = $MarginContainer/HBoxContainer/RightPanel/WarehouseButton
@onready var exit_dialog: ExitConfirmDialog = $ExitConfirmDialog

var _role_entries: Array[Dictionary] = []
var _selected_players: Array[Dictionary] = []
var _preview_player_id := ""
var _preview_weapon_type := ""
var _player_buttons: Dictionary = {}
var _selected_slot_buttons: Array[SelectedSlotButton] = []
var _player_weapon_cache: Dictionary = {}

func _ready() -> void:
	_configure_static_texts()
	_connect_signals()
	_load_roles()
	_generate_selected_slots()
	_generate_player_buttons()
	_clear_player_info()
	_clear_weapon_cards()
	_restore_previous_selection()
	if _selected_players.is_empty():
		_restore_initial_preview()
	_refresh_synergy_summary()
	_update_continue_button_state()

func _configure_static_texts() -> void:
	left_title.text = "已选角色"
	synergy_title.text = "职能统计"
	role_title.text = "选择角色"
	weapon_title.text = "武器选择"
	continue_button.text = "开始战斗"
	warehouse_button.text = "返回主菜单"
	player_description.bbcode_enabled = false
	skill_description.bbcode_enabled = false

func _connect_signals() -> void:
	if not continue_button.pressed.is_connected(_on_continue_pressed):
		continue_button.pressed.connect(_on_continue_pressed)
	if not warehouse_button.pressed.is_connected(_on_back_pressed):
		warehouse_button.pressed.connect(_on_back_pressed)
	if exit_dialog != null:
		if not exit_dialog.confirmed.is_connected(_on_exit_confirmed):
			exit_dialog.confirmed.connect(_on_exit_confirmed)
		if not exit_dialog.cancelled.is_connected(_on_exit_cancelled):
			exit_dialog.cancelled.connect(_on_exit_cancelled)

func _load_roles() -> void:
	_role_entries.clear()
	for config_variant: Dictionary in ConfigManager.get_enabled_players():
		var player_id: String = str(config_variant.get("player_id", "")).strip_edges()
		if player_id.is_empty():
			continue
		_role_entries.append(config_variant.duplicate(true))
	_seed_default_weapon_cache()

func _seed_default_weapon_cache() -> void:
	for config: Dictionary in _role_entries:
		var player_id: String = str(config.get("player_id", ""))
		if not _player_weapon_cache.has(player_id):
			_player_weapon_cache[player_id] = _resolve_default_weapon(player_id)

func _generate_selected_slots() -> void:
	for child in selected_list.get_children():
		child.queue_free()
	_selected_slot_buttons.clear()

	for i in range(MAX_SELECTED_PLAYERS):
		var slot_button := SelectedSlotButton.new()
		slot_button.custom_minimum_size = Vector2(110, 110)
		slot_button.text = ""
		slot_button.setup(i)
		slot_button.player_dropped.connect(_on_player_dropped)
		slot_button.pressed.connect(_on_selected_slot_pressed.bind(i))
		selected_list.add_child(slot_button)
		_selected_slot_buttons.append(slot_button)

func _generate_player_buttons() -> void:
	for child in player_scroll_container.get_children():
		if child != player_container:
			child.queue_free()
	player_container.queue_free()

	var root_vbox := VBoxContainer.new()
	root_vbox.name = "PlayerVBox"
	root_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root_vbox.add_theme_constant_override("separation", 18)
	player_scroll_container.add_child(root_vbox)
	player_container = root_vbox
	_player_buttons.clear()

	var grouped := {}
	for group_key in CLASS_GROUP_ORDER:
		grouped[group_key] = []

	for config: Dictionary in _role_entries:
		var group_key := _resolve_config_class_group(config)
		(grouped[group_key] as Array).append(config)

	for group_key in CLASS_GROUP_ORDER:
		_build_group_section(root_vbox, group_key, grouped[group_key])

func _build_group_section(root_vbox: VBoxContainer, group_key: String, entries: Array) -> void:
	var section := VBoxContainer.new()
	section.add_theme_constant_override("separation", 10)
	root_vbox.add_child(section)

	var title := Label.new()
	title.text = str(CLASS_GROUP_TITLES.get(group_key, group_key))
	title.add_theme_font_size_override("font_size", 20)
	section.add_child(title)

	var grid := GridContainer.new()
	grid.columns = GRID_COLUMNS
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	section.add_child(grid)

	if entries.is_empty():
		var empty_label := Label.new()
		empty_label.text = "暂无角色"
		empty_label.modulate = Color(0.7, 0.7, 0.7, 0.9)
		section.add_child(empty_label)
		return

	for config_variant in entries:
		var config: Dictionary = config_variant
		var player_id: String = str(config.get("player_id", ""))
		var button := PlayerSelectButton.new()
		button.custom_minimum_size = Vector2(PLAYER_BUTTON_SIZE, PLAYER_BUTTON_SIZE)
		button.text = str(config.get("display_name", player_id))
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		button.expand_icon = true
		button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		button.setup(player_id, _resolve_default_weapon(player_id))
		button.pressed.connect(_on_player_button_pressed.bind(player_id))

		var visual_config: Dictionary = ConfigManager.get_player_visual(player_id)
		var sprite_path: String = str(visual_config.get("sprite_path", "")).strip_edges()
		if not sprite_path.is_empty() and ResourceLoader.exists(sprite_path):
			button.icon = load(sprite_path)

		grid.add_child(button)
		_player_buttons[player_id] = button

func _restore_initial_preview() -> void:
	if _role_entries.is_empty():
		return
	_preview_player(str(_role_entries[0].get("player_id", "")))

func _restore_previous_selection() -> void:
	var restored_ids: Array[String] = []
	var restored_weapons: Dictionary = {}

	if not Global.selected_player_ids.is_empty():
		restored_ids = Global.selected_player_ids.duplicate()
		restored_weapons = Global.selected_player_weapons.duplicate(true)
	elif Global.has_method("get_selection_preset"):
		var preset: Dictionary = Global.get_selection_preset()
		var preset_ids_var: Variant = preset.get("player_ids", [])
		if preset_ids_var is Array:
			for raw_id in preset_ids_var:
				var player_id: String = str(raw_id).strip_edges()
				if not player_id.is_empty():
					restored_ids.append(player_id)
		var preset_weapons_var: Variant = preset.get("player_weapons", {})
		if preset_weapons_var is Dictionary:
			restored_weapons = (preset_weapons_var as Dictionary).duplicate(true)

	if restored_ids.is_empty():
		return

	for key in restored_weapons.keys():
		var player_id: String = str(key).strip_edges()
		if not player_id.is_empty():
			_player_weapon_cache[player_id] = str(restored_weapons.get(key, "")).strip_edges()

	_selected_players.clear()
	var slot_index: int = 0
	for player_id in restored_ids:
		if slot_index >= MAX_SELECTED_PLAYERS:
			break
		if ConfigManager.get_player_config(player_id).is_empty():
			continue
		_selected_players.append({
			"player_id": player_id,
			"slot_index": slot_index,
			"weapon_type": str(_player_weapon_cache.get(player_id, _resolve_default_weapon(player_id))),
		})
		slot_index += 1

	_sort_selected_players()
	_refresh_all_selected_slots()
	if not _selected_players.is_empty():
		_preview_player(str(_selected_players[0].get("player_id", "")))
	else:
		_refresh_player_button_states()

func _preview_player(player_id: String) -> void:
	var config := ConfigManager.get_player_config(player_id)
	if config.is_empty():
		_clear_player_info()
		return

	_preview_player_id = player_id
	_preview_weapon_type = _resolve_default_weapon(player_id)

	var visual_config := ConfigManager.get_player_visual(player_id)
	var sprite_path: String = str(visual_config.get("sprite_path", "")).strip_edges()
	player_ico.texture = load(sprite_path) if (not sprite_path.is_empty() and ResourceLoader.exists(sprite_path)) else null

	player_name_label.text = str(config.get("display_name", player_id))
	player_ties_label.text = _build_ties_text(config)
	_refresh_bond_icons(config)
	player_description.text = _build_stats_text(config)
	skill_description.text = _build_skill_text(player_id)

	_refresh_weapon_cards(player_id)
	_refresh_player_button_states()

func _build_ties_text(config: Dictionary) -> String:
	var ties: String = str(config.get("ties", "")).strip_edges()
	if ties.is_empty():
		return ""
	return "[" + ties.replace("|", " / ") + "]"

func _refresh_bond_icons(config: Dictionary) -> void:
	for child in bond_icons_container.get_children():
		child.queue_free()
	if BondUILoader == null:
		return
	var team_player_ids: Array[String] = []
	for entry in _selected_players:
		team_player_ids.append(str(entry.get("player_id", "")))
	BondUILoader.update_bond_icons(
		bond_icons_container,
		str(config.get("origin_tag", "")),
		str(config.get("mastery_tag", "")),
		str(config.get("tactic_tag", "")),
		team_player_ids
	)

func _build_stats_text(config: Dictionary) -> String:
	var lines: Array[String] = []
	lines.append("生命值: %s" % str(config.get("health", 0)))
	lines.append("生命恢复: %s / 秒" % str(config.get("health_regen", 0)))
	lines.append("最大护甲: %s" % str(config.get("max_armor", 0)))
	lines.append("移动速度: %s" % str(config.get("base_speed", 0)))
	lines.append("最大能量: %s" % str(config.get("max_energy", 0)))
	lines.append("初始能量: %s" % str(config.get("initial_energy", 0)))
	lines.append("能量恢复: %s / 秒" % str(config.get("energy_regen", 0)))
	lines.append("通用Q消耗: %s" % str(config.get("skill_q_cost", 0)))
	lines.append("E技能消耗: %s" % str(config.get("skill_e_cost", 0)))
	lines.append("")
	lines.append(str(config.get("description", "")))
	return "\n".join(lines)

func _build_skill_text(player_id: String) -> String:
	var bindings := ConfigManager.get_player_skill_bindings(player_id)
	var space_skill_id: String = str(bindings.get("slot_q", ""))
	var e_skill_id: String = str(bindings.get("slot_e", ""))
	var space_params := ConfigManager.get_skill_params(space_skill_id)
	var e_params := ConfigManager.get_skill_params(e_skill_id)
	var f_config := ConfigManager.get_player_ult_config(player_id)

	var sections: Array[String] = []
	sections.append("[Space]")
	var line_desc: String = str(space_params.get("desc_q_line", "")).strip_edges()
	var circle_desc: String = str(space_params.get("desc_q_circle", "")).strip_edges()
	sections.append(line_desc if not line_desc.is_empty() else "暂无说明")
	if not circle_desc.is_empty():
		sections.append("")
		sections.append("[闭合结算]")
		sections.append(circle_desc)

	sections.append("")
	sections.append("[E]")
	var e_desc: String = str(e_params.get("desc_e", "")).strip_edges()
	sections.append(e_desc if not e_desc.is_empty() else "暂无说明")

	sections.append("")
	sections.append("[F]")
	var f_desc: String = str(f_config.get("description", "")).strip_edges()
	sections.append(f_desc if not f_desc.is_empty() else "暂无说明")

	return "\n".join(sections)

func _refresh_weapon_cards(player_id: String) -> void:
	_clear_weapon_cards()
	var weapon_types: Array[String] = ConfigManager.get_player_available_weapon_types(player_id)
	var selected_weapon: String = str(_player_weapon_cache.get(player_id, _resolve_default_weapon(player_id)))

	if weapon_types.is_empty():
		var empty_button := Button.new()
		empty_button.custom_minimum_size = Vector2(96, 96)
		empty_button.disabled = true
		empty_button.text = "无武器"
		weapon_container.add_child(empty_button)
		return

	weapon_container.columns = max(1, weapon_types.size())
	for weapon_type in weapon_types:
		var weapon_config := ConfigManager.get_weapon_by_type_level(weapon_type, 1)
		var card := Button.new()
		card.custom_minimum_size = Vector2(96, 96)
		card.focus_mode = Control.FOCUS_NONE
		card.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		card.text = _get_weapon_display_name(weapon_type)
		card.tooltip_text = card.text
		card.pressed.connect(_on_weapon_selected.bind(player_id, weapon_type))

		var icon_path: String = str(weapon_config.get("icon_path_template", "")).strip_edges()
		if not icon_path.is_empty() and ResourceLoader.exists(icon_path):
			card.icon = load(icon_path)
			card.expand_icon = true
			card.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER

		var style := StyleBoxFlat.new()
		style.set_corner_radius_all(8)
		style.set_border_width_all(2)
		if weapon_type == selected_weapon:
			style.bg_color = Color(0.28, 0.28, 0.18, 1.0)
			style.border_color = Color(1.0, 0.88, 0.26, 1.0)
		else:
			style.bg_color = Color(0.18, 0.18, 0.18, 1.0)
			style.border_color = Color(0.35, 0.35, 0.35, 1.0)
		card.add_theme_stylebox_override("normal", style)
		card.add_theme_stylebox_override("hover", style.duplicate())
		card.add_theme_stylebox_override("pressed", style.duplicate())
		weapon_container.add_child(card)

func _clear_weapon_cards() -> void:
	for child in weapon_container.get_children():
		child.queue_free()

func _resolve_default_weapon(player_id: String) -> String:
	var cached: String = str(_player_weapon_cache.get(player_id, "")).strip_edges()
	if not cached.is_empty():
		return cached

	var preferred: String = str(DEFAULT_WEAPON_BY_PLAYER.get(player_id, "")).strip_edges()
	var weapon_types: Array[String] = ConfigManager.get_player_available_weapon_types(player_id)
	if not preferred.is_empty() and weapon_types.has(preferred):
		return preferred
	if not weapon_types.is_empty():
		return weapon_types[0]
	return preferred

func _get_weapon_display_name(weapon_type: String) -> String:
	var weapon_config := ConfigManager.get_weapon_by_type_level(weapon_type, 1)
	var template: String = str(weapon_config.get("display_name_template", "")).strip_edges()
	if not template.is_empty():
		return template.replace("%d", "").replace("（", "").replace("）", "").strip_edges()
	return weapon_type

func _on_weapon_selected(player_id: String, weapon_type: String) -> void:
	_player_weapon_cache[player_id] = weapon_type
	if player_id == _preview_player_id:
		_preview_weapon_type = weapon_type
		_refresh_weapon_cards(player_id)
	for i in range(_selected_players.size()):
		if str(_selected_players[i].get("player_id", "")) == player_id:
			_selected_players[i]["weapon_type"] = weapon_type
	_refresh_all_selected_slots()
	_persist_current_selection()

func _on_player_button_pressed(player_id: String) -> void:
	_preview_player(player_id)

func is_player_selected(player_id: String) -> bool:
	for entry in _selected_players:
		if str(entry.get("player_id", "")) == player_id:
			return true
	return false

func _find_selected_player_index(player_id: String) -> int:
	for i in range(_selected_players.size()):
		if str(_selected_players[i].get("player_id", "")) == player_id:
			return i
	return -1

func _find_selected_slot_index(slot_index: int) -> int:
	for i in range(_selected_players.size()):
		if int(_selected_players[i].get("slot_index", -1)) == slot_index:
			return i
	return -1

func _sort_selected_players() -> void:
	_selected_players.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a.get("slot_index", 0)) < int(b.get("slot_index", 0))
	)

func _on_selected_slot_pressed(slot_index: int) -> void:
	var occupied_index: int = _find_selected_slot_index(slot_index)
	if occupied_index >= 0:
		_remove_player_from_selected(occupied_index)
		return
	if not _preview_player_id.is_empty():
		_add_player_to_selected(_preview_player_id, slot_index)

func _on_player_dropped(slot_index: int, player_id: String, weapon_type: String) -> void:
	_player_weapon_cache[player_id] = weapon_type if not weapon_type.is_empty() else _resolve_default_weapon(player_id)
	_add_player_to_selected(player_id, slot_index)
	_preview_player(player_id)

func _add_player_to_selected(player_id: String, slot_index: int = 0) -> void:
	if player_id.is_empty():
		return
	slot_index = clampi(slot_index, 0, MAX_SELECTED_PLAYERS - 1)

	var existing_player_index: int = _find_selected_player_index(player_id)
	if existing_player_index >= 0:
		_selected_players[existing_player_index]["slot_index"] = slot_index
		_selected_players[existing_player_index]["weapon_type"] = str(_player_weapon_cache.get(player_id, _resolve_default_weapon(player_id)))
	else:
		var existing_slot_index: int = _find_selected_slot_index(slot_index)
		if existing_slot_index >= 0:
			_selected_players.remove_at(existing_slot_index)
		elif _selected_players.size() >= MAX_SELECTED_PLAYERS:
			return

		_selected_players.append({
			"player_id": player_id,
			"slot_index": slot_index,
			"weapon_type": str(_player_weapon_cache.get(player_id, _resolve_default_weapon(player_id))),
		})

	_sort_selected_players()
	_refresh_all_selected_slots()
	_refresh_player_button_states()
	_refresh_synergy_summary()
	_update_continue_button_state()
	_persist_current_selection()

func _remove_player_from_selected(index: int) -> void:
	if index < 0 or index >= _selected_players.size():
		return
	_selected_players.remove_at(index)
	_sort_selected_players()
	_refresh_all_selected_slots()
	_refresh_player_button_states()
	_refresh_synergy_summary()
	_update_continue_button_state()
	_persist_current_selection()

func _refresh_all_selected_slots() -> void:
	for i in range(_selected_slot_buttons.size()):
		_clear_selected_slot_display(i)
	for entry in _selected_players:
		_update_selected_slot_display(int(entry.get("slot_index", 0)), str(entry.get("player_id", "")))

func _update_selected_slot_display(slot_index: int, player_id: String) -> void:
	if slot_index < 0 or slot_index >= _selected_slot_buttons.size():
		return
	var btn := _selected_slot_buttons[slot_index]
	var config := ConfigManager.get_player_config(player_id)
	var visual_config := ConfigManager.get_player_visual(player_id)
	btn.text = str(config.get("display_name", player_id))
	btn.tooltip_text = "%s | 武器: %s" % [btn.text, _get_weapon_display_name(str(_player_weapon_cache.get(player_id, "")))]
	var sprite_path: String = str(visual_config.get("sprite_path", "")).strip_edges()
	btn.icon = load(sprite_path) if (not sprite_path.is_empty() and ResourceLoader.exists(sprite_path)) else null

func _clear_selected_slot_display(slot_index: int) -> void:
	if slot_index < 0 or slot_index >= _selected_slot_buttons.size():
		return
	var btn := _selected_slot_buttons[slot_index]
	btn.text = ""
	btn.icon = null
	btn.tooltip_text = "拖拽或点击左侧槽位放入当前预览角色"

func _refresh_player_button_states() -> void:
	for player_id in _player_buttons.keys():
		var btn: PlayerSelectButton = _player_buttons[player_id]
		var style := StyleBoxFlat.new()
		style.set_corner_radius_all(10)
		style.set_border_width_all(2)
		if is_player_selected(str(player_id)):
			style.bg_color = Color(0.20, 0.32, 0.22, 1.0)
			style.border_color = Color(0.90, 0.85, 0.40, 1.0)
		elif str(player_id) == _preview_player_id:
			style.bg_color = Color(0.24, 0.24, 0.24, 1.0)
			style.border_color = Color(0.65, 0.65, 0.65, 1.0)
		else:
			style.bg_color = Color(0.16, 0.16, 0.16, 1.0)
			style.border_color = Color(0.28, 0.28, 0.28, 1.0)
		btn.add_theme_stylebox_override("normal", style)
		btn.add_theme_stylebox_override("hover", style.duplicate())
		btn.add_theme_stylebox_override("pressed", style.duplicate())

func _refresh_synergy_summary() -> void:
	for child in synergy_list.get_children():
		child.queue_free()

	if _selected_players.is_empty():
		var empty_label := Label.new()
		empty_label.text = "当前未选择角色"
		synergy_list.add_child(empty_label)
		return

	var counts := {}
	for group_key in CLASS_GROUP_ORDER:
		counts[group_key] = 0

	for entry in _selected_players:
		var config := ConfigManager.get_player_config(str(entry.get("player_id", "")))
		var group_key := _resolve_config_class_group(config)
		counts[group_key] = int(counts.get(group_key, 0)) + 1

	for group_key in CLASS_GROUP_ORDER:
		var label := Label.new()
		label.text = "%s  %d/%d" % [CLASS_GROUP_TITLES[group_key], int(counts[group_key]), MAX_SELECTED_PLAYERS]
		label.add_theme_font_size_override("font_size", 18)
		synergy_list.add_child(label)

func _resolve_class_group(raw_tag: String) -> String:
	var tag: String = raw_tag.strip_edges()
	if CLASS_GROUP_ALIASES.has(tag):
		return str(CLASS_GROUP_ALIASES[tag])
	return "sentinel"

func _resolve_config_class_group(config: Dictionary) -> String:
	var player_id: String = str(config.get("player_id", "")).strip_edges()
	if DISPLAY_CLASS_BY_PLAYER.has(player_id):
		return str(DISPLAY_CLASS_BY_PLAYER[player_id])
	return _resolve_class_group(str(config.get("mastery_tag", "")))

func _update_continue_button_state() -> void:
	continue_button.disabled = _selected_players.is_empty() and _preview_player_id.is_empty()

func _clear_player_info() -> void:
	player_ico.texture = null
	player_name_label.text = "选择角色"
	player_ties_label.text = ""
	for child in bond_icons_container.get_children():
		child.queue_free()
	player_description.text = "点击角色查看详情，再点击左侧槽位或直接继续进入战斗。"
	skill_description.text = ""

func _on_continue_pressed() -> void:
	if _selected_players.is_empty() and not _preview_player_id.is_empty():
		_add_player_to_selected(_preview_player_id, 0)
	if _selected_players.is_empty():
		return

	_sort_selected_players()
	var player_ids: Array[String] = []
	var player_weapons: Dictionary = {}
	for entry in _selected_players:
		var player_id: String = str(entry.get("player_id", ""))
		player_ids.append(player_id)
		player_weapons[player_id] = str(entry.get("weapon_type", _resolve_default_weapon(player_id)))

	if Global.has_method("save_selection_preset"):
		Global.save_selection_preset(player_ids, player_weapons, player_ids[0] if not player_ids.is_empty() else "")
	Global.reset_selection()
	Global.selected_player_ids = player_ids
	Global.leader_player_id = player_ids[0] if not player_ids.is_empty() else ""
	Global.current_player_index = 0
	Global.selected_player_weapons = player_weapons
	get_tree().change_scene_to_file(ARENA_SCENE_PATH)

func _on_back_pressed() -> void:
	if exit_dialog != null:
		exit_dialog.show_dialog("返回主菜单？")
	else:
		get_tree().change_scene_to_file(MAIN_MENU_SCENE_PATH)

func _on_exit_confirmed() -> void:
	if not _selected_players.is_empty() and Global.has_method("save_selection_preset"):
		_sort_selected_players()
		var player_ids: Array[String] = []
		var player_weapons: Dictionary = {}
		for entry in _selected_players:
			var player_id: String = str(entry.get("player_id", ""))
			player_ids.append(player_id)
			player_weapons[player_id] = str(entry.get("weapon_type", _resolve_default_weapon(player_id)))
		Global.save_selection_preset(player_ids, player_weapons, player_ids[0] if not player_ids.is_empty() else "")
	Global.reset_selection()
	get_tree().change_scene_to_file(MAIN_MENU_SCENE_PATH)

func _persist_current_selection() -> void:
	if not Global.has_method("save_selection_preset"):
		return
	_sort_selected_players()
	var player_ids: Array[String] = []
	var player_weapons: Dictionary = {}
	for entry in _selected_players:
		var player_id: String = str(entry.get("player_id", "")).strip_edges()
		if player_id.is_empty():
			continue
		player_ids.append(player_id)
		player_weapons[player_id] = str(entry.get("weapon_type", _resolve_default_weapon(player_id))).strip_edges()
	Global.save_selection_preset(player_ids, player_weapons, player_ids[0] if not player_ids.is_empty() else "")

func _on_exit_cancelled() -> void:
	pass

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_on_back_pressed()
		get_viewport().set_input_as_handled()
