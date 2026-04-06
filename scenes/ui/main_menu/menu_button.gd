extends Button

@export var action_id: String = ""

signal button_action(action: String)

const COLOR_TEXT := Color("#E6EDF3")
const COLOR_DIM := Color("#8B949E")
const COLOR_ACCENT := Color("#00F0FF")
const HOVER_DURATION := 0.14

@onready var indicator: ColorRect = $Indicator

var _ui_font: Font
var _hover_tween: Tween

func _ready() -> void:
	_ui_font = _create_font()
	add_theme_font_override("font", _ui_font)
	add_theme_font_size_override("font_size", 32)
	add_theme_color_override("font_color", COLOR_DIM)
	add_theme_color_override("font_hover_color", COLOR_TEXT)
	add_theme_color_override("font_pressed_color", COLOR_TEXT)
	add_theme_color_override("font_focus_color", COLOR_TEXT)
	mouse_entered.connect(_on_hover_enter)
	mouse_exited.connect(_on_hover_exit)
	focus_entered.connect(_on_hover_enter)
	focus_exited.connect(_on_hover_exit)
	pressed.connect(_on_pressed)
	_update_visual(is_hovered() or has_focus())

func setup(label_text: String, action: String) -> void:
	text = label_text
	action_id = action

func _on_hover_enter() -> void:
	_update_visual(true)
	SoundManager.play("ui_hover")

func _on_hover_exit() -> void:
	if has_focus():
		return
	_update_visual(false)

func _on_pressed() -> void:
	SoundManager.play("ui_click")
	_update_visual(true)
	button_action.emit(action_id)

func _update_visual(active: bool) -> void:
	if _hover_tween:
		_hover_tween.kill()
	_hover_tween = create_tween().set_parallel(true)
	indicator.visible = active
	indicator.modulate = Color(1, 1, 1, 0.0 if not active else 1.0)
	_hover_tween.tween_property(indicator, "modulate:a", 1.0 if active else 0.0, HOVER_DURATION)
	_hover_tween.tween_property(self, "theme_override_colors/font_color", COLOR_TEXT if active else COLOR_DIM, HOVER_DURATION)
	_hover_tween.tween_property(self, "position:x", 12.0 if active else 0.0, HOVER_DURATION)

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
