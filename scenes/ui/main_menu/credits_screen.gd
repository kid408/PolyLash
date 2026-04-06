extends MarginContainer

signal back_pressed

const CREDITS_ITEM := preload("res://scenes/ui/main_menu/credits_item.tscn")
const COLOR_TEXT := Color("#E6EDF3")
const COLOR_DIM := Color("#8B949E")

@onready var back_button: Button = $VBox/TopBar/BackButton
@onready var title_label: Label = $VBox/TopBar/TitleLabel
@onready var content_list: VBoxContainer = $VBox/CreditScroll/CreditList

var _ui_font: Font

func _ready() -> void:
	_ui_font = _create_font()
	_apply_theme()
	back_button.pressed.connect(func(): back_pressed.emit())
	_populate_credits()

func _apply_theme() -> void:
	back_button.flat = true
	back_button.add_theme_font_override("font", _ui_font)
	back_button.add_theme_font_size_override("font_size", 18)
	back_button.add_theme_color_override("font_color", COLOR_DIM)
	title_label.add_theme_font_override("font", _ui_font)
	title_label.add_theme_font_size_override("font_size", 36)
	title_label.add_theme_color_override("font_color", COLOR_TEXT)

func _populate_credits() -> void:
	for child in content_list.get_children():
		child.queue_free()
	for entry in ConfigManager.get_credits_configs():
		var item := CREDITS_ITEM.instantiate()
		content_list.add_child(item)
		item.setup(entry)

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
