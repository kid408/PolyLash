extends PanelContainer

const TIER_COLORS := {
	1: Color.WHITE,
	2: Color("#4488FF"),
	3: Color("#AA44FF"),
}

var _ui_font: Font

@onready var close_button: Button = $MarginContainer/VBoxContainer/TopBar/CloseButton
@onready var portrait: TextureRect = $MarginContainer/VBoxContainer/Portrait
@onready var name_label: Label = $MarginContainer/VBoxContainer/NameLabel
@onready var tags_label: Label = $MarginContainer/VBoxContainer/TagsLabel
@onready var separator: HSeparator = $MarginContainer/VBoxContainer/Separator
@onready var stats_label: Label = $MarginContainer/VBoxContainer/StatsLabel
@onready var desc_label: Label = $MarginContainer/VBoxContainer/DescLabel

func _ready() -> void:
	_ui_font = _create_ui_font()
	_apply_theme()
	close_button.pressed.connect(hide_panel)
	visible = false

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

func _apply_theme() -> void:
	for label in [name_label, tags_label, stats_label, desc_label]:
		label.add_theme_font_override("font", _ui_font)
	close_button.text = "关闭"
	close_button.add_theme_font_override("font", _ui_font)
	close_button.flat = true
	close_button.add_theme_font_size_override("font_size", 16)
	name_label.add_theme_font_size_override("font_size", 24)
	name_label.add_theme_color_override("font_color", Color("#E6EDF3"))
	tags_label.add_theme_font_size_override("font_size", 14)
	tags_label.add_theme_color_override("font_color", Color("#8B949E"))
	stats_label.add_theme_font_size_override("font_size", 16)
	stats_label.add_theme_color_override("font_color", Color("#E6EDF3"))
	desc_label.add_theme_font_size_override("font_size", 15)
	desc_label.add_theme_color_override("font_color", Color("#8B949E"))

func show_character_detail(player_id: String) -> void:
	var config: Dictionary = ConfigManager.get_player_config(player_id)
	if config.is_empty():
		return
	var intro: Dictionary = ConfigManager.get_player_intro(player_id)
	var visual: Dictionary = ConfigManager.get_player_visual(player_id)

	portrait.texture = _load_texture(_resolve_player_portrait(player_id, config, visual))
	portrait.modulate = Color.WHITE
	portrait.visible = portrait.texture != null

	name_label.text = str(intro.get("display_name", config.get("display_name", player_id)))
	name_label.add_theme_color_override("font_color", Color.WHITE)

	var ties_text := str(config.get("ties", "")).replace("|", " / ")
	tags_label.text = ties_text
	tags_label.visible = not ties_text.is_empty()

	stats_label.text = "生命值 %s    护甲 %s\n速度 %s    能量 %s" % [
		str(int(config.get("health", 0))),
		str(int(config.get("max_armor", 0))),
		str(int(config.get("base_speed", 0))),
		str(int(config.get("max_energy", 0))),
	]
	stats_label.visible = true

	var desc := str(intro.get("experience_goal", config.get("description", "")))
	desc_label.text = desc
	desc_label.visible = not desc.is_empty()
	separator.visible = true
	_show()

func show_relic_detail(item_id: String) -> void:
	var config: Dictionary = ConfigManager.item_configs_new.get(item_id, {})
	if config.is_empty():
		return

	portrait.texture = _load_texture(str(config.get("icon_path", "")))
	portrait.modulate = Color.WHITE
	portrait.visible = portrait.texture != null

	var tier := int(config.get("tier", 1))
	name_label.text = "%s  (Tier %d)" % [str(config.get("name", item_id)), tier]
	name_label.add_theme_color_override("font_color", TIER_COLORS.get(tier, Color.WHITE))

	tags_label.visible = false

	var stats_text := ""
	var base_stat := str(config.get("base_stat", ""))
	var base_value := str(config.get("base_value", ""))
	if not base_stat.is_empty() and not base_value.is_empty() and base_value != "0":
		stats_text = "基础属性：%s +%s" % [base_stat, base_value]
	var modifiers: Array = config.get("modifiers", [])
	for modifier_variant in modifiers:
		if modifier_variant is Dictionary:
			var modifier: Dictionary = modifier_variant
			if not stats_text.is_empty():
				stats_text += "\n"
			stats_text += "修正：%s %s" % [str(modifier.get("type", "")), str(modifier.get("value", 0))]
	stats_label.text = stats_text
	stats_label.visible = not stats_text.is_empty()

	desc_label.text = str(config.get("description", ""))
	desc_label.visible = not desc_label.text.is_empty()
	separator.visible = true
	_show()

func show_monster_detail(enemy_id: String) -> void:
	var config: Dictionary = ConfigManager.enemy_configs.get(enemy_id, {})
	if config.is_empty():
		return
	var visual: Dictionary = ConfigManager.enemy_visual_configs.get(enemy_id, {})

	portrait.texture = _load_texture(str(visual.get("sprite_path", "")))
	portrait.modulate = Color.WHITE
	portrait.visible = portrait.texture != null

	name_label.text = str(config.get("display_name", enemy_id))
	name_label.add_theme_color_override("font_color", Color.WHITE)
	tags_label.visible = false

	stats_label.text = "生命值 %s    攻击 %s\n速度 %s" % [
		str(int(config.get("health", 0))),
		str(int(config.get("damage", 0))),
		str(int(config.get("speed", 0))),
	]
	stats_label.visible = true

	desc_label.text = str(config.get("description", ""))
	desc_label.visible = not desc_label.text.is_empty()
	separator.visible = true
	_show()

func hide_panel() -> void:
	if not visible:
		return
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.15)
	tween.tween_callback(func(): visible = false)

func _show() -> void:
	modulate.a = 0.0
	visible = true
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 1.0, 0.15)

func _resolve_player_portrait(player_id: String, config: Dictionary, visual: Dictionary) -> String:
	var portrait_path := str(config.get("portrait_sprite_path", "")).strip_edges()
	if not portrait_path.is_empty() and ResourceLoader.exists(portrait_path):
		return portrait_path
	return str(visual.get("sprite_path", "")).strip_edges()

func _load_texture(path: String) -> Texture2D:
	if path.is_empty() or not ResourceLoader.exists(path):
		return null
	return load(path)
