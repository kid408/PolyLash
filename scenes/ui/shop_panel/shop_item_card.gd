extends PanelContainer
class_name ShopItemCard

signal purchase_requested(card_index: int)
signal replace_target_selected(card_index: int, replace_out_player_id: String)

const TYPE_LABELS := {
	"emblem": "羁绊徽记",
	"equipment": "装备",
	"consumable": "补给",
	"recruit": "角色招募",
	"recruit_replace": "换员招募",
}

const TAG_DISPLAY_OVERRIDES := {
	"cyber": "赛博",
	"esper": "异能",
	"mech": "机械",
	"military": "军工",
	"vanguard": "锋芒",
	"anomaly": "术理",
	"sentinel": "御阵",
	"harmony": "协律",
	"shuttle": "爆发",
	"link": "连携",
	"knockback": "击退",
}

@onready var icon_texture: TextureRect = %IconTexture
@onready var name_label: Label = %NameLabel
@onready var meta_label: RichTextLabel = %MetaLabel
@onready var bond_tags_container: HBoxContainer = %BondTagsContainer
@onready var effects_label: RichTextLabel = %EffectsLabel
@onready var replace_panel: VBoxContainer = %ReplacePanel
@onready var replace_title_label: Label = %ReplaceTitleLabel
@onready var replace_options_container: HBoxContainer = %ReplaceOptionsContainer
@onready var price_button: Button = %PriceButton
@onready var purchased_label: Label = %PurchasedLabel

var card_index: int = -1
var item_data: Dictionary = {}
var is_purchased: bool = false
var _replace_button_group: ButtonGroup

func _ready() -> void:
	_replace_button_group = ButtonGroup.new()
	if not price_button.pressed.is_connected(_on_price_button_pressed):
		price_button.pressed.connect(_on_price_button_pressed)

func setup(index: int, item: Dictionary) -> void:
	card_index = index
	refresh(item)

func refresh(item: Dictionary) -> void:
	item_data = item.duplicate(true)
	_apply_item_data()

func _apply_item_data() -> void:
	name_label.text = str(item_data.get("item_name", "未知物品"))
	_load_icon(str(item_data.get("icon_path", "")))
	meta_label.text = _build_meta_text(item_data)
	_setup_bond_tags()
	_setup_effects_text(item_data.get("effects", []))
	_setup_replace_panel()
	_update_price_button_text()
	set_purchased(is_purchased)

func _load_icon(icon_path: String) -> void:
	icon_texture.texture = null
	if icon_path.is_empty():
		return
	if not FileAccess.file_exists(icon_path):
		return
	var texture: Texture2D = load(icon_path) as Texture2D
	if texture != null:
		icon_texture.texture = texture

func _build_meta_text(item: Dictionary) -> String:
	var item_type: String = str(item.get("item_type", ""))
	var type_label: String = str(TYPE_LABELS.get(item_type, "商店物品"))
	if item_type == "recruit" or item_type == "recruit_replace":
		var spawn_rate: float = float(item.get("recruit_spawn_chance", 0.0)) * 100.0
		var recruit_weight: float = float(item.get("recruit_weight", 0.0))
		var share: float = float(item.get("recruit_weight_share", 0.0))
		return "[center][color=#00F0FF]%s[/color]  [color=#8B949E]角色卡概率 %.0f%%[/color]\n[color=#E6EDF3]权重 %.0f[/color]  [color=#8B949E]候选占比 %.1f%%[/color][/center]" % [
			type_label,
			spawn_rate,
			recruit_weight,
			share
		]
	return "[center][color=#8B949E]%s[/color][/center]" % type_label

func _setup_bond_tags() -> void:
	for child: Node in bond_tags_container.get_children():
		child.queue_free()

	var item_type: String = str(item_data.get("item_type", ""))
	var show_tags: bool = item_type == "recruit" or item_type == "recruit_replace"
	bond_tags_container.visible = show_tags
	if not show_tags:
		return

	var tags: Array[Dictionary] = [
		{"type": "origin", "tag": str(item_data.get("origin_tag", "")), "accent": Color("6EA8FE")},
		{"type": "mastery", "tag": str(item_data.get("mastery_tag", "")), "accent": Color("00F0FF")},
		{"type": "tactic", "tag": str(item_data.get("tactic_tag", "")), "accent": Color("FFB86B")},
	]

	for tag_info_variant in tags:
		var tag_info: Dictionary = tag_info_variant
		var tag_id: String = str(tag_info.get("tag", "")).strip_edges()
		if tag_id.is_empty():
			continue
		var tag_type: String = str(tag_info.get("type", ""))
		var chip: PanelContainer = PanelContainer.new()
		var style := StyleBoxFlat.new()
		style.bg_color = Color(0.09, 0.12, 0.16, 0.95)
		style.border_color = Color(tag_info.get("accent", Color.WHITE))
		style.set_border_width_all(1)
		style.set_corner_radius_all(6)
		chip.add_theme_stylebox_override("panel", style)

		var margin := MarginContainer.new()
		margin.add_theme_constant_override("margin_left", 6)
		margin.add_theme_constant_override("margin_top", 4)
		margin.add_theme_constant_override("margin_right", 6)
		margin.add_theme_constant_override("margin_bottom", 4)
		chip.add_child(margin)

		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 4)
		margin.add_child(row)

		var icon_rect := TextureRect.new()
		icon_rect.custom_minimum_size = Vector2(16, 16)
		icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		var texture: Texture2D = null
		if BondUILoader != null and BondUILoader.has_method("get_bond_icon"):
			texture = BondUILoader.get_bond_icon(tag_id, tag_type)
		if texture != null:
			icon_rect.texture = texture
			row.add_child(icon_rect)

		var label := Label.new()
		label.text = _resolve_tag_display(tag_id)
		label.tooltip_text = _resolve_tag_display(tag_id)
		row.add_child(label)
		bond_tags_container.add_child(chip)

func _resolve_tag_display(tag_id: String) -> String:
	var normalized_tag: String = tag_id.strip_edges()
	if TAG_DISPLAY_OVERRIDES.has(normalized_tag):
		return str(TAG_DISPLAY_OVERRIDES[normalized_tag])
	if BondUILoader != null and BondUILoader.has_method("get_bond_display_name"):
		var display_name: String = str(BondUILoader.get_bond_display_name(normalized_tag))
		if not display_name.is_empty() and not display_name.contains("?"):
			return display_name
	return normalized_tag.capitalize()

func _setup_effects_text(effects: Array) -> void:
	var text_parts: Array[String] = []
	for effect_variant in effects:
		if not (effect_variant is Dictionary):
			continue
		var effect: Dictionary = effect_variant
		var description: String = str(effect.get("description", "")).strip_edges()
		if description.is_empty():
			continue
		var is_trade_off: bool = bool(effect.get("is_trade_off", false))
		if is_trade_off:
			text_parts.append("[color=#FF6B6B]%s[/color]" % description)
		else:
			text_parts.append("[color=#C9D1D9]%s[/color]" % description)
	effects_label.text = "\n".join(text_parts)

func _setup_replace_panel() -> void:
	for child: Node in replace_options_container.get_children():
		child.queue_free()

	var item_type: String = str(item_data.get("item_type", ""))
	var show_replace_panel: bool = item_type == "recruit_replace"
	replace_panel.visible = show_replace_panel
	if not show_replace_panel:
		return

	replace_title_label.text = "选择要替换的编队成员"
	var selected_target: String = str(item_data.get("replace_out_player_id", ""))
	for candidate_variant in item_data.get("replace_candidates", []):
		if not (candidate_variant is Dictionary):
			continue
		var candidate: Dictionary = candidate_variant
		var player_id: String = str(candidate.get("player_id", ""))
		if player_id.is_empty():
			continue
		var button := Button.new()
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.custom_minimum_size = Vector2(0, 34)
		button.toggle_mode = true
		button.button_group = _replace_button_group
		button.text = str(candidate.get("display_name", player_id))
		button.tooltip_text = "替换 %s" % str(candidate.get("display_name", player_id))
		button.button_pressed = player_id == selected_target
		button.pressed.connect(_on_replace_button_pressed.bind(player_id))
		replace_options_container.add_child(button)

func _update_price_button_text() -> void:
	var price: int = int(item_data.get("price", 0))
	var item_type: String = str(item_data.get("item_type", ""))
	var action_text: String = "购买"
	match item_type:
		"recruit":
			action_text = "招募"
		"recruit_replace":
			action_text = "确认换员"
		"emblem":
			action_text = "获取"
		"equipment":
			action_text = "购入"
		"consumable":
			action_text = "购买"
	price_button.text = "%s（%d 金币）" % [action_text, price]

func set_purchased(purchased: bool) -> void:
	is_purchased = purchased
	if purchased:
		price_button.visible = false
		replace_panel.visible = false
		purchased_label.visible = true
		modulate = Color(0.72, 0.72, 0.72, 1.0)
	else:
		price_button.visible = true
		purchased_label.visible = false
		modulate = Color(1.0, 1.0, 1.0, 1.0)
		if str(item_data.get("item_type", "")) == "recruit_replace":
			replace_panel.visible = true

func set_affordable(affordable: bool) -> void:
	if is_purchased:
		return
	price_button.disabled = not affordable

func _on_price_button_pressed() -> void:
	if is_purchased:
		return
	SoundManager.play("ui_click")
	purchase_requested.emit(card_index)

func _on_replace_button_pressed(player_id: String) -> void:
	replace_target_selected.emit(card_index, player_id)
