extends Control

signal back_pressed

const COMPENDIUM_DATA_PATH := "user://compendium_data.json"
const CARD_WIDTH := 96
const CARD_HEIGHT := 96
const PORTRAIT_SIZE := 76
const GRID_COLUMNS := 6

const COLOR_BG := Color("#161B22")
const COLOR_BORDER := Color(0.22, 0.25, 0.29, 1.0)
const COLOR_ACCENT := Color("#00F0FF")
const COLOR_TEXT := Color(0.92, 0.94, 0.97, 1.0)
const COLOR_TEXT_DIM := Color(0.62, 0.66, 0.71, 1.0)
const COLOR_LOCKED := Color(0.08, 0.08, 0.08, 1.0)
const TIER_COLORS := {
	1: Color.WHITE,
	2: Color("#4488FF"),
	3: Color("#AA44FF"),
}

var current_tab: String = "characters"
var unlocked_data: Dictionary = {
	"unlocked_characters": [],
	"unlocked_relics": [],
	"encountered_monsters": [],
}

var _ui_font: Font

@onready var back_button: Button = $TabBar/BackButton
@onready var tab_characters: Button = $TabBar/TabCharacters
@onready var tab_relics: Button = $TabBar/TabRelics
@onready var tab_monsters: Button = $TabBar/TabMonsters
@onready var progress_label: Label = $TabBar/ProgressLabel
@onready var scroll_container: ScrollContainer = $MainContent/ItemScroll
@onready var content_grid: GridContainer = $MainContent/ItemScroll/ItemGrid
@onready var detail_panel: PanelContainer = $MainContent/CompendiumDetailPanel

func _ready() -> void:
	_ui_font = _create_ui_font()
	_apply_static_texts()
	_apply_theme()
	_load_unlock_data()
	_connect_signals()
	_show_tab("characters")

func _create_ui_font() -> Font:
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

func _apply_static_texts() -> void:
	back_button.text = "返回"
	tab_characters.text = "角色"
	tab_relics.text = "圣物"
	tab_monsters.text = "怪物"
	progress_label.text = "已解锁 0/0"

func _apply_theme() -> void:
	for button in [back_button, tab_characters, tab_relics, tab_monsters]:
		button.add_theme_font_override("font", _ui_font)
		button.add_theme_font_size_override("font_size", 18)
		button.flat = true
	for label in [progress_label]:
		label.add_theme_font_override("font", _ui_font)
		label.add_theme_font_size_override("font_size", 16)
		label.add_theme_color_override("font_color", COLOR_TEXT_DIM)
	content_grid.add_theme_constant_override("h_separation", 16)
	content_grid.add_theme_constant_override("v_separation", 18)

func _connect_signals() -> void:
	back_button.pressed.connect(func(): back_pressed.emit())
	tab_characters.pressed.connect(func(): _show_tab("characters"))
	tab_relics.pressed.connect(func(): _show_tab("relics"))
	tab_monsters.pressed.connect(func(): _show_tab("monsters"))

func _load_unlock_data() -> void:
	if not FileAccess.file_exists(COMPENDIUM_DATA_PATH):
		return
	var file := FileAccess.open(COMPENDIUM_DATA_PATH, FileAccess.READ)
	if not file:
		return
	var json_str := file.get_as_text()
	file.close()
	var json := JSON.new()
	if json.parse(json_str) != OK:
		push_warning("[Compendium] 解锁数据解析失败，使用默认空数据")
		return
	if json.data is Dictionary:
		var data: Dictionary = json.data
		unlocked_data["unlocked_characters"] = data.get("unlocked_characters", [])
		unlocked_data["unlocked_relics"] = data.get("unlocked_relics", [])
		unlocked_data["encountered_monsters"] = data.get("encountered_monsters", [])

func _show_tab(tab: String) -> void:
	current_tab = tab
	_update_tab_styles()
	_clear_grid()
	if detail_panel and detail_panel.has_method("hide_panel"):
		detail_panel.hide_panel()

	match tab:
		"characters":
			_populate_characters()
		"relics":
			_populate_relics()
		"monsters":
			_populate_monsters()

	_update_progress()
	scroll_container.scroll_vertical = 0

func _update_tab_styles() -> void:
	var active_color := COLOR_ACCENT
	var inactive_color := COLOR_TEXT_DIM
	tab_characters.add_theme_color_override("font_color", active_color if current_tab == "characters" else inactive_color)
	tab_relics.add_theme_color_override("font_color", active_color if current_tab == "relics" else inactive_color)
	tab_monsters.add_theme_color_override("font_color", active_color if current_tab == "monsters" else inactive_color)
	_set_tab_underline(tab_characters, current_tab == "characters")
	_set_tab_underline(tab_relics, current_tab == "relics")
	_set_tab_underline(tab_monsters, current_tab == "monsters")

func _set_tab_underline(button: Button, active: bool) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color.TRANSPARENT
	style.border_color = COLOR_ACCENT if active else Color.TRANSPARENT
	style.border_width_bottom = 3 if active else 0
	style.content_margin_bottom = 4
	style.content_margin_left = 8
	style.content_margin_right = 8
	style.content_margin_top = 4
	button.add_theme_stylebox_override("normal", style)
	button.add_theme_stylebox_override("hover", style)
	button.add_theme_stylebox_override("pressed", style)

func _populate_characters() -> void:
	content_grid.columns = GRID_COLUMNS
	var players: Array[Dictionary] = ConfigManager.get_enabled_players()
	var unlocked: Array = unlocked_data.get("unlocked_characters", [])
	for config in players:
		var player_id := str(config.get("player_id", ""))
		var is_unlocked := unlocked.has(player_id)
		var display_name := str(ConfigManager.get_player_intro(player_id).get("display_name", config.get("display_name", player_id)))
		var sprite_path := _get_player_portrait_path(player_id, config)
		_add_card_to(content_grid, player_id, display_name, sprite_path, is_unlocked, "characters")

func _populate_relics() -> void:
	content_grid.columns = 1
	var unlocked: Array = unlocked_data.get("unlocked_relics", [])
	var grouped: Dictionary = {}
	for item_id in ConfigManager.item_configs_new.keys():
		var config: Dictionary = ConfigManager.item_configs_new[item_id]
		var tier := int(config.get("tier", 1))
		if not grouped.has(tier):
			grouped[tier] = []
		grouped[tier].append({"id": item_id, "config": config})

	var tiers := grouped.keys()
	tiers.sort()
	for tier in tiers:
		var header := Label.new()
		header.text = "Tier %d" % int(tier)
		header.add_theme_font_override("font", _ui_font)
		header.add_theme_font_size_override("font_size", 18)
		header.add_theme_color_override("font_color", TIER_COLORS.get(tier, COLOR_TEXT))
		content_grid.add_child(header)

		var tier_grid := GridContainer.new()
		tier_grid.columns = GRID_COLUMNS
		tier_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tier_grid.add_theme_constant_override("h_separation", 16)
		tier_grid.add_theme_constant_override("v_separation", 18)
		content_grid.add_child(tier_grid)

		var entries: Array = grouped[tier]
		entries.sort_custom(func(a: Dictionary, b: Dictionary): return str(a["id"]) < str(b["id"]))
		for entry in entries:
			var item_id := str(entry["id"])
			var config: Dictionary = entry["config"]
			var is_unlocked := unlocked.has(item_id)
			var display_name := str(config.get("name", item_id))
			var icon_path := str(config.get("icon_path", ""))
			_add_card_to(tier_grid, item_id, display_name, icon_path, is_unlocked, "relics")

func _populate_monsters() -> void:
	content_grid.columns = GRID_COLUMNS
	var encountered: Array = unlocked_data.get("encountered_monsters", [])
	var enemy_ids: Array = ConfigManager.enemy_configs.keys()
	enemy_ids.sort()
	for enemy_id_variant in enemy_ids:
		var enemy_id := str(enemy_id_variant)
		var config: Dictionary = ConfigManager.enemy_configs.get(enemy_id, {})
		var is_encountered := encountered.has(enemy_id)
		var display_name := str(config.get("display_name", enemy_id))
		var visual: Dictionary = ConfigManager.enemy_visual_configs.get(enemy_id, {})
		var sprite_path := str(visual.get("sprite_path", ""))
		_add_card_to(content_grid, enemy_id, display_name, sprite_path, is_encountered, "monsters")

func _add_card_to(container: Container, entry_id: String, display_name: String, sprite_path: String, is_unlocked: bool, tab_type: String) -> void:
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(CARD_WIDTH, CARD_HEIGHT)
	card.add_theme_stylebox_override("panel", _make_card_style(is_unlocked))
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_bottom", 8)
	card.add_child(margin)

	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 8)
	margin.add_child(box)

	var portrait_container := CenterContainer.new()
	portrait_container.custom_minimum_size = Vector2(PORTRAIT_SIZE, PORTRAIT_SIZE)
	box.add_child(portrait_container)

	var portrait := TextureRect.new()
	portrait.custom_minimum_size = Vector2(PORTRAIT_SIZE, PORTRAIT_SIZE)
	portrait.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	if not sprite_path.is_empty() and ResourceLoader.exists(sprite_path):
		portrait.texture = load(sprite_path)
	portrait.modulate = Color.WHITE if is_unlocked else COLOR_LOCKED
	portrait_container.add_child(portrait)

	if not is_unlocked:
		var lock_label := Label.new()
		lock_label.text = "锁"
		lock_label.add_theme_font_override("font", _ui_font)
		lock_label.add_theme_font_size_override("font_size", 18)
		lock_label.add_theme_color_override("font_color", COLOR_TEXT)
		lock_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lock_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		portrait_container.add_child(lock_label)

	if is_unlocked:
		card.mouse_filter = Control.MOUSE_FILTER_STOP
		card.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		card.gui_input.connect(_on_card_gui_input.bind(entry_id, tab_type))

	container.add_child(card)

func _make_card_style(is_unlocked: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = COLOR_BG
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.border_color = COLOR_BORDER if is_unlocked else Color(0.18, 0.18, 0.18, 1.0)
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	return style

func _update_progress() -> void:
	var total := 0
	var unlocked_count := 0
	match current_tab:
		"characters":
			var players: Array[Dictionary] = ConfigManager.get_enabled_players()
			total = players.size()
			var unlocked_list: Array = unlocked_data.get("unlocked_characters", [])
			for config in players:
				var player_id := str(config.get("player_id", ""))
				if unlocked_list.has(player_id):
					unlocked_count += 1
		"relics":
			total = ConfigManager.item_configs_new.size()
			var unlocked_relics: Array = unlocked_data.get("unlocked_relics", [])
			for relic_id in unlocked_relics:
				if ConfigManager.item_configs_new.has(relic_id):
					unlocked_count += 1
		"monsters":
			total = ConfigManager.enemy_configs.size()
			var encountered: Array = unlocked_data.get("encountered_monsters", [])
			for enemy_id in encountered:
				if ConfigManager.enemy_configs.has(enemy_id):
					unlocked_count += 1
	progress_label.text = "已解锁 %d/%d" % [unlocked_count, total]

func _on_card_gui_input(event: InputEvent, entry_id: String, tab_type: String) -> void:
	if not (event is InputEventMouseButton):
		return
	var mouse_event := event as InputEventMouseButton
	if not mouse_event.pressed or mouse_event.button_index != MOUSE_BUTTON_LEFT:
		return
	match tab_type:
		"characters":
			if detail_panel.has_method("show_character_detail"):
				detail_panel.show_character_detail(entry_id)
		"relics":
			if detail_panel.has_method("show_relic_detail"):
				detail_panel.show_relic_detail(entry_id)
		"monsters":
			if detail_panel.has_method("show_monster_detail"):
				detail_panel.show_monster_detail(entry_id)

func _clear_grid() -> void:
	for child in content_grid.get_children():
		child.queue_free()

func _get_player_portrait_path(player_id: String, config: Dictionary) -> String:
	var portrait_path := str(config.get("portrait_sprite_path", "")).strip_edges()
	if not portrait_path.is_empty() and ResourceLoader.exists(portrait_path):
		return portrait_path
	var visual: Dictionary = ConfigManager.get_player_visual(player_id)
	var sprite_path := str(visual.get("sprite_path", "")).strip_edges()
	if not sprite_path.is_empty() and ResourceLoader.exists(sprite_path):
		return sprite_path
	return ""
