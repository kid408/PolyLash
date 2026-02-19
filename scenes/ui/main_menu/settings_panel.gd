extends CanvasLayer
## 设置面板 - CanvasLayer 弹窗，四个 Tab：常规/显示/音频/游戏性
## 修改即时生效，关闭时自动保存

signal closed

@onready var overlay: ColorRect = $Overlay
@onready var panel: PanelContainer = $Panel
@onready var close_button: Button = $Panel/MarginContainer/VBoxContainer/Header/CloseButton
@onready var tab_container: TabContainer = $Panel/MarginContainer/VBoxContainer/TabContainer

# 字体引用（从 tscn 中的 TitleLabel 获取）
var _font: Font

# --- 显示设置控件 ---
var resolution_dropdown: OptionButton
var display_mode_dropdown: OptionButton
var vsync_toggle: CheckButton
var fps_dropdown: OptionButton
var shake_slider: HSlider
var shake_label: Label

# --- 音频设置控件 ---
var master_slider: HSlider
var master_label: Label
var bgm_slider: HSlider
var bgm_label: Label
var sfx_slider: HSlider
var sfx_label: Label
var ui_slider: HSlider
var ui_label: Label

# --- 游戏性设置控件 ---
var sensitivity_slider: HSlider
var smart_cast_toggle: CheckButton
var skill_mode_dropdown: OptionButton
var damage_number_toggle: CheckButton

# --- 常规设置控件 ---
var language_dropdown: OptionButton
var cloud_save_toggle: CheckButton

var is_visible_panel: bool = false


func _ready() -> void:
	process_mode = PROCESS_MODE_ALWAYS
	# 获取字体引用
	var title_label: Label = $Panel/MarginContainer/VBoxContainer/Header/TitleLabel
	_font = title_label.get_theme_font("font")
	close_button.pressed.connect(_on_close)
	# 构建四个 Tab 的内容
	_build_general_tab()
	_build_display_tab()
	_build_audio_tab()
	_build_gameplay_tab()
	# 加载当前设置到 UI
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


# ============================================================================
# Tab 构建 - 常规
# ============================================================================

func _build_general_tab() -> void:
	var container = _create_tab_scroll("常规")
	var vbox = container.get_child(0) as VBoxContainer

	# 语言选择
	language_dropdown = _add_option_row(vbox, "语言", ["中文", "English"])
	language_dropdown.item_selected.connect(func(idx: int):
		var lang = "zh" if idx == 0 else "en"
		SaveManager.set_setting("general.language", lang)
	)

	# 云存档（置灰）
	cloud_save_toggle = _add_toggle_row(vbox, "云存档", "即将推出")
	cloud_save_toggle.disabled = true
	cloud_save_toggle.button_pressed = false


# ============================================================================
# Tab 构建 - 显示
# ============================================================================

func _build_display_tab() -> void:
	var container = _create_tab_scroll("显示")
	var vbox = container.get_child(0) as VBoxContainer

	# 分辨率
	resolution_dropdown = _add_option_row(vbox, "分辨率", ["1280x720", "1600x900", "1920x1080", "2560x1440"])
	resolution_dropdown.item_selected.connect(func(idx: int):
		var res_text = resolution_dropdown.get_item_text(idx)
		SaveManager.set_setting("display.resolution", res_text)
		SaveManager.apply_display_settings()
	)

	# 显示模式
	display_mode_dropdown = _add_option_row(vbox, "显示模式", ["窗口", "全屏", "无边框窗口"])
	display_mode_dropdown.item_selected.connect(func(idx: int):
		var modes = ["windowed", "fullscreen", "borderless"]
		SaveManager.set_setting("display.display_mode", modes[idx])
		SaveManager.apply_display_settings()
	)

	# 垂直同步
	vsync_toggle = _add_toggle_row(vbox, "垂直同步")
	vsync_toggle.toggled.connect(func(pressed: bool):
		SaveManager.set_setting("display.vsync", pressed)
		SaveManager.apply_display_settings()
	)

	# 帧率限制
	fps_dropdown = _add_option_row(vbox, "帧率限制", ["30", "60", "120", "不限制"])
	fps_dropdown.item_selected.connect(func(idx: int):
		var fps_values = [30, 60, 120, 0]
		SaveManager.set_setting("display.fps_limit", fps_values[idx])
		SaveManager.apply_display_settings()
	)

	# 屏幕震动
	var shake_result = _add_slider_row(vbox, "屏幕震动", 0, 100, 1)
	shake_slider = shake_result[0]
	shake_label = shake_result[1]
	shake_slider.value_changed.connect(func(val: float):
		shake_label.text = "%d%%" % int(val)
		SaveManager.set_setting("display.shake_intensity", int(val))
	)


# ============================================================================
# Tab 构建 - 音频
# ============================================================================

func _build_audio_tab() -> void:
	var container = _create_tab_scroll("音频")
	var vbox = container.get_child(0) as VBoxContainer

	# 主音量
	var master_result = _add_slider_row(vbox, "主音量", 0, 100, 1)
	master_slider = master_result[0]
	master_label = master_result[1]
	master_slider.value_changed.connect(func(val: float):
		master_label.text = "%d%%" % int(val)
		SaveManager.set_setting("audio.master_volume", int(val))
		SaveManager.apply_audio_settings()
	)

	# BGM
	var bgm_result = _add_slider_row(vbox, "BGM", 0, 100, 1)
	bgm_slider = bgm_result[0]
	bgm_label = bgm_result[1]
	bgm_slider.value_changed.connect(func(val: float):
		bgm_label.text = "%d%%" % int(val)
		SaveManager.set_setting("audio.bgm_volume", int(val))
		SaveManager.apply_audio_settings()
	)

	# SFX
	var sfx_result = _add_slider_row(vbox, "SFX", 0, 100, 1)
	sfx_slider = sfx_result[0]
	sfx_label = sfx_result[1]
	sfx_slider.value_changed.connect(func(val: float):
		sfx_label.text = "%d%%" % int(val)
		SaveManager.set_setting("audio.sfx_volume", int(val))
		SaveManager.apply_audio_settings()
	)

	# UI 音效
	var ui_result = _add_slider_row(vbox, "UI音效", 0, 100, 1)
	ui_slider = ui_result[0]
	ui_label = ui_result[1]
	ui_slider.value_changed.connect(func(val: float):
		ui_label.text = "%d%%" % int(val)
		SaveManager.set_setting("audio.ui_volume", int(val))
		SaveManager.apply_audio_settings()
	)


# ============================================================================
# Tab 构建 - 游戏性
# ============================================================================

func _build_gameplay_tab() -> void:
	var container = _create_tab_scroll("游戏性")
	var vbox = container.get_child(0) as VBoxContainer

	# 画线灵敏度（3档：低/中/高 → 值 1/2/3）
	var sens_result = _add_slider_row(vbox, "画线灵敏度", 1, 3, 1)
	sensitivity_slider = sens_result[0]
	var sens_label: Label = sens_result[1]
	sensitivity_slider.value_changed.connect(func(val: float):
		var labels_map = {1: "低", 2: "中", 3: "高"}
		sens_label.text = labels_map.get(int(val), "中")
		SaveManager.set_setting("gameplay.draw_sensitivity", int(val))
	)

	# 智能施法
	smart_cast_toggle = _add_toggle_row(vbox, "智能施法")
	smart_cast_toggle.toggled.connect(func(pressed: bool):
		SaveManager.set_setting("gameplay.smart_cast", pressed)
	)

	# 技能释放模式
	skill_mode_dropdown = _add_option_row(vbox, "技能释放模式", ["按下释放", "点击释放"])
	skill_mode_dropdown.item_selected.connect(func(idx: int):
		var modes = ["press_release", "click_release"]
		SaveManager.set_setting("gameplay.skill_mode", modes[idx])
	)

	# 伤害数字
	damage_number_toggle = _add_toggle_row(vbox, "伤害数字")
	damage_number_toggle.toggled.connect(func(pressed: bool):
		SaveManager.set_setting("gameplay.show_damage_numbers", pressed)
	)


# ============================================================================
# 加载设置到 UI
# ============================================================================

func _load_settings_to_ui() -> void:
	# --- 常规 ---
	var lang = SaveManager.get_setting("general.language", "zh")
	language_dropdown.selected = 0 if lang == "zh" else 1

	# --- 显示 ---
	var res_str = SaveManager.get_setting("display.resolution", "1920x1080")
	var res_options = ["1280x720", "1600x900", "1920x1080", "2560x1440"]
	var res_idx = res_options.find(res_str)
	resolution_dropdown.selected = res_idx if res_idx >= 0 else 2

	var dm = SaveManager.get_setting("display.display_mode", "fullscreen")
	var dm_map = {"windowed": 0, "fullscreen": 1, "borderless": 2}
	display_mode_dropdown.selected = dm_map.get(dm, 1)

	vsync_toggle.button_pressed = SaveManager.get_setting("display.vsync", true)

	var fps = int(SaveManager.get_setting("display.fps_limit", 0))
	var fps_map = {30: 0, 60: 1, 120: 2, 0: 3}
	fps_dropdown.selected = fps_map.get(fps, 3)

	var shake_val = int(SaveManager.get_setting("display.shake_intensity", 100))
	shake_slider.value = shake_val
	shake_label.text = "%d%%" % shake_val

	# --- 音频 ---
	var mv = int(SaveManager.get_setting("audio.master_volume", 100))
	master_slider.value = mv
	master_label.text = "%d%%" % mv

	var bv = int(SaveManager.get_setting("audio.bgm_volume", 80))
	bgm_slider.value = bv
	bgm_label.text = "%d%%" % bv

	var sv = int(SaveManager.get_setting("audio.sfx_volume", 100))
	sfx_slider.value = sv
	sfx_label.text = "%d%%" % sv

	var uv = int(SaveManager.get_setting("audio.ui_volume", 100))
	ui_slider.value = uv
	ui_label.text = "%d%%" % uv

	# --- 游戏性 ---
	var sens = int(SaveManager.get_setting("gameplay.draw_sensitivity", 2))
	sensitivity_slider.value = sens
	var sens_labels = {1: "低", 2: "中", 3: "高"}
	# 更新灵敏度标签（通过获取 slider 的兄弟 label）
	var sens_row = sensitivity_slider.get_parent()
	if sens_row and sens_row.get_child_count() > 2:
		sens_row.get_child(2).text = sens_labels.get(sens, "中")

	smart_cast_toggle.button_pressed = SaveManager.get_setting("gameplay.smart_cast", false)

	var skill_mode = SaveManager.get_setting("gameplay.skill_mode", "press_release")
	skill_mode_dropdown.selected = 0 if skill_mode == "press_release" else 1

	damage_number_toggle.button_pressed = SaveManager.get_setting("gameplay.show_damage_numbers", true)


# ============================================================================
# UI 构建辅助方法
# ============================================================================

func _create_tab_scroll(tab_name: String) -> ScrollContainer:
	"""创建一个带 ScrollContainer 和 VBoxContainer 的 Tab 页"""
	var scroll = ScrollContainer.new()
	scroll.name = tab_name
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL

	var vbox = VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 12)
	scroll.add_child(vbox)

	tab_container.add_child(scroll)
	return scroll


func _add_option_row(parent: VBoxContainer, label_text: String, options: Array) -> OptionButton:
	"""添加一行：标签 + OptionButton"""
	var row = HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var label = Label.new()
	label.text = label_text
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.add_theme_color_override("font_color", Color.WHITE)
	if _font:
		label.add_theme_font_override("font", _font)
	label.add_theme_font_size_override("font_size", 16)
	row.add_child(label)

	var option = OptionButton.new()
	option.custom_minimum_size = Vector2(180, 0)
	for opt in options:
		option.add_item(opt)
	if _font:
		option.add_theme_font_override("font", _font)
	option.add_theme_font_size_override("font_size", 14)
	row.add_child(option)

	parent.add_child(row)
	return option


func _add_toggle_row(parent: VBoxContainer, label_text: String, suffix: String = "") -> CheckButton:
	"""添加一行：标签 + CheckButton，可选后缀文本"""
	var row = HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var label = Label.new()
	label.text = label_text
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.add_theme_color_override("font_color", Color.WHITE)
	if _font:
		label.add_theme_font_override("font", _font)
	label.add_theme_font_size_override("font_size", 16)
	row.add_child(label)

	var toggle = CheckButton.new()
	if _font:
		toggle.add_theme_font_override("font", _font)
	toggle.add_theme_font_size_override("font_size", 14)
	row.add_child(toggle)

	if suffix != "":
		var suffix_label = Label.new()
		suffix_label.text = suffix
		suffix_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
		if _font:
			suffix_label.add_theme_font_override("font", _font)
		suffix_label.add_theme_font_size_override("font_size", 12)
		row.add_child(suffix_label)

	parent.add_child(row)
	return toggle


func _add_slider_row(parent: VBoxContainer, label_text: String, min_val: float, max_val: float, step: float) -> Array:
	"""添加一行：标签 + HSlider + 百分比 Label，返回 [slider, label]"""
	var row = HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var label = Label.new()
	label.text = label_text
	label.custom_minimum_size = Vector2(100, 0)
	label.add_theme_color_override("font_color", Color.WHITE)
	if _font:
		label.add_theme_font_override("font", _font)
	label.add_theme_font_size_override("font_size", 16)
	row.add_child(label)

	var slider = HSlider.new()
	slider.min_value = min_val
	slider.max_value = max_val
	slider.step = step
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.custom_minimum_size = Vector2(200, 0)
	row.add_child(slider)

	var value_label = Label.new()
	value_label.custom_minimum_size = Vector2(50, 0)
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value_label.add_theme_color_override("font_color", Color.WHITE)
	if _font:
		value_label.add_theme_font_override("font", _font)
	value_label.add_theme_font_size_override("font_size", 14)
	value_label.text = "%d%%" % int(min_val)
	row.add_child(value_label)

	parent.add_child(row)
	return [slider, value_label]
