extends MarginContainer

const COLOR_ALERT := Color("#FF4655")
const COLOR_TEXT := Color("#E6EDF3")
const COLOR_DIM := Color("#8B949E")
const COLOR_LINK := Color("#00F0FF")

var _url := ""
var _ui_font: Font

@onready var category_label: Label = $VBox/Line1/CategoryLabel
@onready var title_label: Label = $VBox/Line1/TitleLabel
@onready var link_button: Button = $VBox/Line1/LinkButton
@onready var meta_label: Label = $VBox/MetaLabel

func _ready() -> void:
	_ui_font = _create_font()
	_apply_theme()
	link_button.pressed.connect(_on_link_pressed)

func setup(data: Dictionary) -> void:
	category_label.text = "[%s]" % str(data.get("category", ""))
	title_label.text = str(data.get("asset_name", ""))
	meta_label.text = "%s / %s" % [str(data.get("author", "")), str(data.get("license_type", ""))]
	_url = str(data.get("url", "")).strip_edges()
	link_button.visible = not _url.is_empty()
	tooltip_text = str(data.get("description", ""))

func _apply_theme() -> void:
	category_label.add_theme_font_override("font", _ui_font)
	category_label.add_theme_font_size_override("font_size", 14)
	category_label.add_theme_color_override("font_color", COLOR_ALERT)
	title_label.add_theme_font_override("font", _ui_font)
	title_label.add_theme_font_size_override("font_size", 20)
	title_label.add_theme_color_override("font_color", COLOR_TEXT)
	meta_label.add_theme_font_override("font", _ui_font)
	meta_label.add_theme_font_size_override("font_size", 16)
	meta_label.add_theme_color_override("font_color", COLOR_DIM)
	link_button.add_theme_font_override("font", _ui_font)
	link_button.add_theme_font_size_override("font_size", 18)
	link_button.add_theme_color_override("font_color", COLOR_LINK)

func _on_link_pressed() -> void:
	if not _url.is_empty():
		OS.shell_open(_url)

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
