extends CanvasLayer

signal closed

const COLOR_BG := Color("#0D1117")
const COLOR_PANEL := Color("#161B22")
const COLOR_BORDER := Color("#30363D")
const COLOR_ACCENT := Color("#00F0FF")
const COLOR_TEXT := Color("#E6EDF3")
const COLOR_DIM := Color("#8B949E")

const CATEGORY_KEYS := [
	["general", "常规"],
	["display", "显示"],
	["audio", "音频"],
	["gameplay", "游戏性"],
]

@onready var overlay: ColorRect = $Overlay
@onready var main_panel: PanelContainer = $MainPanel
@onready var category_list: VBoxContainer = $MainPanel/Layout/CategoryList
@onready var content_area: MarginContainer = $MainPanel/Layout/ContentArea

var is_visible_panel := false
var _ui_font: Font
var _category_buttons: Dictionary = {}
var _content_views: Dictionary = {}
var _active_category := "general"

var resolution_dropdown: OptionButton
var display_mode_dropdown: OptionButton
var vsync_toggle: CheckButton
var fps_dropdown: OptionButton
var shake_slider: HSlider
var shake_label: Label

var master_slider: HSlider
var master_label: Label
var bgm_slider: HSlider
var bgm_label: Label
var sfx_slider: HSlider
var sfx_label: Label
var ui_slider: HSlider
var ui_label: Label

var sensitivity_slider: HSlider
var smart_cast_toggle: CheckButton
var skill_mode_dropdown: OptionButton
var damage_number_toggle: CheckButton

var language_dropdown: OptionButton
var cloud_save_toggle: CheckButton

func _ready() -> void:
	process_mode = PROCESS_MODE_ALWAYS
	_ui_font = _create_font()
	_apply_theme()
	_build_layout()
	_load_settings_to_ui()
	hide()

func show_panel() -> void:
	show()
	is_visible_panel = true

func _on_close() -> void:
	SoundManager.play("ui_click")
	SaveManager.save_settings()
	is_visible_panel = false
	closed.emit()
	hide()

func _input(event: InputEvent) -> void:
	if not is_visible_panel:
		return
	if event.is_action_pressed("ui_cancel"):
		_on_close()
		get_viewport().set_input_as_handled()

func _apply_theme() -> void:
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = COLOR_PANEL
	panel_style.border_width_left = 1
	panel_style.border_width_top = 1
	panel_style.border_width_right = 1
	panel_style.border_width_bottom = 1
	panel_style.border_color = COLOR_BORDER
	panel_style.corner_radius_top_left = 14
	panel_style.corner_radius_top_right = 14
	panel_style.corner_radius_bottom_left = 14
	panel_style.corner_radius_bottom_right = 14
	main_panel.add_theme_stylebox_override("panel", panel_style)

	var category_style := StyleBoxFlat.new()
	category_style.bg_color = COLOR_PANEL
	category_style.border_width_right = 1
	category_style.border_color = COLOR_BORDER
	$MainPanel/Layout/CategoryList.add_theme_stylebox_override("panel", category_style)

func _build_layout() -> void:
	var title := Label.new()
	title.text = "设置"
	title.add_theme_font_override("font", _ui_font)
	title.add_theme_font_size_override("font_size", 32)
	title.add_theme_color_override("font_color", COLOR_TEXT)
	category_list.add_child(title)

	for pair in CATEGORY_KEYS:
		var key := str(pair[0])
		var label := str(pair[1])
		var button := Button.new()
		button.text = label
		button.custom_minimum_size = Vector2(200, 52)
		button.flat = true
		button.add_theme_font_override("font", _ui_font)
		button.add_theme_font_size_override("font_size", 20)
		button.pressed.connect(_show_category.bind(key))
		category_list.add_child(button)
		_category_buttons[key] = button

	var close_button := Button.new()
	close_button.text = "关闭"
	close_button.custom_minimum_size = Vector2(200, 44)
	close_button.flat = true
	close_button.add_theme_font_override("font", _ui_font)
	close_button.add_theme_font_size_override("font_size", 18)
	close_button.add_theme_color_override("font_color", COLOR_DIM)
	close_button.pressed.connect(_on_close)
	category_list.add_child(close_button)

	for pair in CATEGORY_KEYS:
		var key := str(pair[0])
		var scroll := ScrollContainer.new()
		scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
		var vbox := VBoxContainer.new()
		vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		vbox.add_theme_constant_override("separation", 18)
		scroll.add_child(vbox)
		content_area.add_child(scroll)
		_content_views[key] = scroll

	_build_general_tab()
	_build_display_tab()
	_build_audio_tab()
	_build_gameplay_tab()
	_show_category("general")

func _show_category(category: String) -> void:
	_active_category = category
	for key in _content_views.keys():
		var view: Control = _content_views[key]
		view.visible = str(key) == category
	for key in _category_buttons.keys():
		var button: Button = _category_buttons[key]
		var active := str(key) == category
		button.add_theme_color_override("font_color", COLOR_ACCENT if active else COLOR_DIM)

func _build_general_tab() -> void:
	var vbox := _get_content_box("general")
	language_dropdown = _add_option_row(vbox, "语言", ["中文", "English"])
	language_dropdown.item_selected.connect(func(idx: int):
		SaveManager.set_setting("general.language", "zh" if idx == 0 else "en")
	)
	cloud_save_toggle = _add_toggle_row(vbox, "云存档", "即将推出")
	cloud_save_toggle.disabled = true

func _build_display_tab() -> void:
	var vbox := _get_content_box("display")
	resolution_dropdown = _add_option_row(vbox, "分辨率", ["1280x720", "1600x900", "1920x1080", "2560x1440"])
	resolution_dropdown.item_selected.connect(func(idx: int):
		var res_text := resolution_dropdown.get_item_text(idx)
		SaveManager.set_setting("display.resolution", res_text)
		SaveManager.apply_display_settings()
	)
	display_mode_dropdown = _add_option_row(vbox, "显示模式", ["窗口", "全屏", "无边框窗口"])
	display_mode_dropdown.item_selected.connect(func(idx: int):
		var modes := ["windowed", "fullscreen", "borderless"]
		SaveManager.set_setting("display.display_mode", modes[idx])
		SaveManager.apply_display_settings()
	)
	vsync_toggle = _add_toggle_row(vbox, "垂直同步")
	vsync_toggle.toggled.connect(func(pressed: bool):
		SaveManager.set_setting("display.vsync", pressed)
		SaveManager.apply_display_settings()
	)
	fps_dropdown = _add_option_row(vbox, "帧率限制", ["30", "60", "120", "不限"])
	fps_dropdown.item_selected.connect(func(idx: int):
		var fps_values := [30, 60, 120, 0]
		SaveManager.set_setting("display.fps_limit", fps_values[idx])
		SaveManager.apply_display_settings()
	)
	var shake_result := _add_slider_row(vbox, "屏幕震动", 0, 100, 1)
	shake_slider = shake_result[0]
	shake_label = shake_result[1]
	shake_slider.value_changed.connect(func(val: float):
		shake_label.text = "%d%%" % int(val)
		SaveManager.set_setting("display.shake_intensity", int(val))
	)

func _build_audio_tab() -> void:
	var vbox := _get_content_box("audio")
	var master_result := _add_slider_row(vbox, "主音量", 0, 100, 1)
	master_slider = master_result[0]
	master_label = master_result[1]
	master_slider.value_changed.connect(func(val: float):
		master_label.text = "%d%%" % int(val)
		SaveManager.set_setting("audio.master_volume", int(val))
		SaveManager.apply_audio_settings()
	)
	var bgm_result := _add_slider_row(vbox, "BGM", 0, 100, 1)
	bgm_slider = bgm_result[0]
	bgm_label = bgm_result[1]
	bgm_slider.value_changed.connect(func(val: float):
		bgm_label.text = "%d%%" % int(val)
		SaveManager.set_setting("audio.bgm_volume", int(val))
		SaveManager.apply_audio_settings()
	)
	var sfx_result := _add_slider_row(vbox, "SFX", 0, 100, 1)
	sfx_slider = sfx_result[0]
	sfx_label = sfx_result[1]
	sfx_slider.value_changed.connect(func(val: float):
		sfx_label.text = "%d%%" % int(val)
		SaveManager.set_setting("audio.sfx_volume", int(val))
		SaveManager.apply_audio_settings()
	)
	var ui_result := _add_slider_row(vbox, "UI 音效", 0, 100, 1)
	ui_slider = ui_result[0]
	ui_label = ui_result[1]
	ui_slider.value_changed.connect(func(val: float):
		ui_label.text = "%d%%" % int(val)
		SaveManager.set_setting("audio.ui_volume", int(val))
		SaveManager.apply_audio_settings()
	)

func _build_gameplay_tab() -> void:
	var vbox := _get_content_box("gameplay")
	var sensitivity_result := _add_slider_row(vbox, "画线灵敏度", 1, 3, 1)
	sensitivity_slider = sensitivity_result[0]
	var sensitivity_value_label: Label = sensitivity_result[1]
	sensitivity_slider.value_changed.connect(func(val: float):
		var labels := {1: "低", 2: "中", 3: "高"}
		sensitivity_value_label.text = str(labels.get(int(val), "中"))
		SaveManager.set_setting("gameplay.draw_sensitivity", int(val))
	)
	smart_cast_toggle = _add_toggle_row(vbox, "智能施法")
	smart_cast_toggle.toggled.connect(func(pressed: bool):
		SaveManager.set_setting("gameplay.smart_cast", pressed)
	)
	skill_mode_dropdown = _add_option_row(vbox, "技能释放模式", ["按下释放", "点击释放"])
	skill_mode_dropdown.item_selected.connect(func(idx: int):
		var modes := ["press_release", "click_release"]
		SaveManager.set_setting("gameplay.skill_mode", modes[idx])
	)
	damage_number_toggle = _add_toggle_row(vbox, "伤害数字")
	damage_number_toggle.toggled.connect(func(pressed: bool):
		SaveManager.set_setting("gameplay.show_damage_numbers", pressed)
	)

func _load_settings_to_ui() -> void:
	language_dropdown.selected = 0 if SaveManager.get_setting("general.language", "zh") == "zh" else 1
	var res_options := ["1280x720", "1600x900", "1920x1080", "2560x1440"]
	var res_idx := res_options.find(str(SaveManager.get_setting("display.resolution", "1920x1080")))
	resolution_dropdown.selected = res_idx if res_idx >= 0 else 2
	var dm := str(SaveManager.get_setting("display.display_mode", "fullscreen"))
	display_mode_dropdown.selected = {"windowed": 0, "fullscreen": 1, "borderless": 2}.get(dm, 1)
	vsync_toggle.button_pressed = bool(SaveManager.get_setting("display.vsync", true))
	fps_dropdown.selected = {30: 0, 60: 1, 120: 2, 0: 3}.get(int(SaveManager.get_setting("display.fps_limit", 0)), 3)
	var shake_val := int(SaveManager.get_setting("display.shake_intensity", 100))
	shake_slider.value = shake_val
	shake_label.text = "%d%%" % shake_val

	var mv := int(SaveManager.get_setting("audio.master_volume", 100))
	master_slider.value = mv
	master_label.text = "%d%%" % mv
	var bv := int(SaveManager.get_setting("audio.bgm_volume", 80))
	bgm_slider.value = bv
	bgm_label.text = "%d%%" % bv
	var sv := int(SaveManager.get_setting("audio.sfx_volume", 100))
	sfx_slider.value = sv
	sfx_label.text = "%d%%" % sv
	var uv := int(SaveManager.get_setting("audio.ui_volume", 100))
	ui_slider.value = uv
	ui_label.text = "%d%%" % uv

	var sens := int(SaveManager.get_setting("gameplay.draw_sensitivity", 2))
	sensitivity_slider.value = sens
	smart_cast_toggle.button_pressed = bool(SaveManager.get_setting("gameplay.smart_cast", false))
	skill_mode_dropdown.selected = 0 if SaveManager.get_setting("gameplay.skill_mode", "press_release") == "press_release" else 1
	damage_number_toggle.button_pressed = bool(SaveManager.get_setting("gameplay.show_damage_numbers", true))

func _get_content_box(category: String) -> VBoxContainer:
	var scroll: ScrollContainer = _content_views[category]
	return scroll.get_child(0) as VBoxContainer

func _add_option_row(parent: VBoxContainer, label_text: String, options: Array) -> OptionButton:
	var row := HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 18)

	var label := _make_row_label(label_text)
	row.add_child(label)

	var option := OptionButton.new()
	option.custom_minimum_size = Vector2(220, 40)
	option.add_theme_font_override("font", _ui_font)
	option.add_theme_font_size_override("font_size", 16)
	for opt in options:
		option.add_item(str(opt))
	row.add_child(option)

	parent.add_child(row)
	return option

func _add_toggle_row(parent: VBoxContainer, label_text: String, suffix: String = "") -> CheckButton:
	var row := HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 18)

	var label := _make_row_label(label_text)
	row.add_child(label)

	var toggle := CheckButton.new()
	toggle.add_theme_font_override("font", _ui_font)
	toggle.add_theme_font_size_override("font_size", 16)
	toggle.add_theme_color_override("font_color", COLOR_ACCENT)
	row.add_child(toggle)

	if not suffix.is_empty():
		var suffix_label := Label.new()
		suffix_label.text = suffix
		suffix_label.add_theme_font_override("font", _ui_font)
		suffix_label.add_theme_font_size_override("font_size", 14)
		suffix_label.add_theme_color_override("font_color", COLOR_DIM)
		row.add_child(suffix_label)

	parent.add_child(row)
	return toggle

func _add_slider_row(parent: VBoxContainer, label_text: String, min_val: float, max_val: float, step: float) -> Array:
	var row := HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 18)

	var label := _make_row_label(label_text)
	row.add_child(label)

	var slider := HSlider.new()
	slider.min_value = min_val
	slider.max_value = max_val
	slider.step = step
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(slider)

	var value_label := Label.new()
	value_label.custom_minimum_size = Vector2(56, 0)
	value_label.add_theme_font_override("font", _ui_font)
	value_label.add_theme_font_size_override("font_size", 16)
	value_label.add_theme_color_override("font_color", COLOR_TEXT)
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value_label.text = "%d%%" % int(min_val)
	row.add_child(value_label)

	parent.add_child(row)
	return [slider, value_label]

func _make_row_label(label_text: String) -> Label:
	var label := Label.new()
	label.text = label_text
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.add_theme_font_override("font", _ui_font)
	label.add_theme_font_size_override("font_size", 20)
	label.add_theme_color_override("font_color", COLOR_TEXT)
	return label

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
