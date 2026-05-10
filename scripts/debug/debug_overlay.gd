extends CanvasLayer
class_name DebugOverlay

const AUTO_PLAYER_CONTROLLER_SCRIPT := preload("res://scripts/debug/auto_player_controller.gd")
const DEBUG_INTENSITY_GRAPH_SCRIPT := preload("res://scripts/debug/debug_intensity_graph.gd")
const PAUSE_SOURCE: String = "debug_overlay"
const PANEL_BG: Color = Color(0.08, 0.11, 0.14, 0.96)
const SECTION_BG: Color = Color(0.11, 0.14, 0.18, 0.96)
const BORDER: Color = Color(0.19, 0.24, 0.31, 1.0)
const ACCENT: Color = Color(0.0, 0.94, 1.0, 1.0)
const INTENSITY_SAMPLE_INTERVAL: float = 0.5
const INTENSITY_NEARBY_RADIUS: float = 600.0
const INTENSITY_KILL_WINDOW: float = 2.0
const INTENSITY_HISTORY_WINDOW: float = 10.0
const INTENSITY_PEAK_THRESHOLD: float = 75.0
const INTENSITY_IDLE_THRESHOLD: float = 15.0

var _bond_option: OptionButton
var _bond_option_tags: Array[String] = []
var _elite_option: OptionButton
var _elite_option_ids: Array[String] = []
var _training_option: OptionButton
var _training_option_ids: Array[String] = []
var _boss_option: OptionButton
var _boss_option_ids: Array[String] = []
var _overlay_root: Control
var _temp_tag_label: Label
var _runtime_label: Label
var _status_label: Label
var _invincible_toggle: CheckBox
var _infinite_energy_toggle: CheckBox
var _time_scale_slider: HSlider
var _time_scale_value_label: Label
var _wave_time_spinbox: SpinBox
var _wave_lock_toggle: CheckBox
var _spawn_rate_slider: HSlider
var _spawn_rate_value_label: Label
var _max_enemy_spinbox: SpinBox
var _auto_player_toggle: CheckBox
var _auto_player_status_label: Label
var _auto_player_controller: AutoPlayerController
var _auto_player_monitor_panel: PanelContainer
var _auto_player_monitor_label: Label
var _intensity_score_label: Label
var _intensity_graph: DebugIntensityGraph
var _intensity_breakdown_label: Label
var _intensity_summary_label: Label
var _last_invincible_player_ref: WeakRef = null
var _connected_spawner_ref: WeakRef = null
var _info_refresh_accumulator: float = 0.0
var _intensity_refresh_accumulator: float = 0.0
var _kill_event_times: Array[float] = []
var _last_session_kills: int = 0
var _intensity_history: Array[Dictionary] = []
var _current_intensity_score: float = 0.0
var _current_intensity_breakdown: Dictionary = {}
var _wave_profile_index: int = -1
var _wave_profile_elapsed: float = 0.0
var _wave_profile_score_sum: float = 0.0
var _wave_profile_peak_time: float = 0.0
var _wave_profile_idle_time: float = 0.0
var _summary_visible_until_msec: int = 0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 99
	visible = true
	_build_ui()
	_ensure_spawner_connection()
	_populate_bond_tags()
	_sync_controls_from_runtime()
	_refresh_runtime_info()
	_reset_intensity_session_state()
	_refresh_intensity_snapshot()

func _exit_tree() -> void:
	PauseService.release_pause(PAUSE_SOURCE, get_tree())
	_clear_invincible_override()
	if _auto_player_controller != null:
		_auto_player_controller.disable()

func _input(event: InputEvent) -> void:
	if event is InputEventKey:
		var key_event: InputEventKey = event as InputEventKey
		if key_event.pressed and not key_event.echo:
			if key_event.keycode == KEY_0 or key_event.physical_keycode == KEY_0:
				_set_overlay_visible(_overlay_root == null or not _overlay_root.visible)
				get_viewport().set_input_as_handled()

func _process(delta: float) -> void:
	_ensure_spawner_connection()
	_track_recent_kills()
	_apply_player_state_toggles()
	_info_refresh_accumulator += delta
	if _info_refresh_accumulator >= 0.12:
		_info_refresh_accumulator = 0.0
		_refresh_runtime_info()
	_intensity_refresh_accumulator += delta
	if _intensity_refresh_accumulator >= INTENSITY_SAMPLE_INTERVAL:
		_intensity_refresh_accumulator = 0.0
		_refresh_intensity_snapshot()
	_update_summary_visibility()

func _set_overlay_visible(is_visible: bool) -> void:
	if _overlay_root != null:
		_overlay_root.visible = is_visible
	if is_visible:
		PauseService.request_pause(PAUSE_SOURCE, get_tree())
		_populate_bond_tags()
		_sync_controls_from_runtime()
		_refresh_runtime_info()
		_display_status("调试面板已开启")
	else:
		PauseService.release_pause(PAUSE_SOURCE, get_tree())
		_display_status("调试面板已隐藏")

func _build_ui() -> void:
	_build_intensity_monitor()
	_build_auto_player_monitor()

	var backdrop: ColorRect = ColorRect.new()
	backdrop.color = Color(0.0, 0.0, 0.0, 0.58)
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	backdrop.visible = false
	_overlay_root = backdrop
	add_child(backdrop)

	var margin: MarginContainer = MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_top", 24)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_bottom", 24)
	backdrop.add_child(margin)

	var panel: PanelContainer = PanelContainer.new()
	panel.custom_minimum_size = Vector2(560.0, 760.0)
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	panel.add_theme_stylebox_override("panel", _build_panel_style(PANEL_BG))
	margin.add_child(panel)

	var panel_margin: MarginContainer = MarginContainer.new()
	panel_margin.add_theme_constant_override("margin_left", 16)
	panel_margin.add_theme_constant_override("margin_top", 16)
	panel_margin.add_theme_constant_override("margin_right", 16)
	panel_margin.add_theme_constant_override("margin_bottom", 16)
	panel.add_child(panel_margin)

	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel_margin.add_child(scroll)

	var root: VBoxContainer = VBoxContainer.new()
	root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.add_theme_constant_override("separation", 14)
	scroll.add_child(root)

	var header: VBoxContainer = VBoxContainer.new()
	header.add_theme_constant_override("separation", 4)
	root.add_child(header)

	var title: Label = Label.new()
	title.text = "局内调试覆盖层"
	title.add_theme_font_size_override("font_size", 24)
	title.modulate = ACCENT
	header.add_child(title)

	var hint: Label = Label.new()
	hint.text = "按数字键 0 显示或隐藏。本面板会暂停游戏，但所有按钮都直接调用正式运行时接口。"
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.modulate = Color(0.82, 0.86, 0.9, 0.92)
	header.add_child(hint)

	_runtime_label = Label.new()
	_runtime_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_runtime_label.modulate = Color(0.88, 0.91, 0.95, 0.96)
	header.add_child(_runtime_label)

	_build_bond_section(root)
	_build_spawner_section(root)
	_build_player_state_section(root)
	_build_game_flow_section(root)
	_build_wave_section(root)
	_build_auto_player_section(root)

	_status_label = Label.new()
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status_label.modulate = Color(0.95, 0.96, 0.98, 0.96)
	root.add_child(_status_label)

func _build_bond_section(root: VBoxContainer) -> void:
	var section: VBoxContainer = _create_section(root, "A. 羁绊注入")

	var option_row: HBoxContainer = HBoxContainer.new()
	option_row.add_theme_constant_override("separation", 10)
	section.add_child(option_row)

	_bond_option = OptionButton.new()
	_bond_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	option_row.add_child(_bond_option)

	var add_button: Button = _make_button("添加", Callable(self, "_on_add_selected_tag_pressed"))
	option_row.add_child(add_button)

	var add_six_button: Button = _make_button("添加 6 次", Callable(self, "_on_add_selected_tag_x6_pressed"))
	option_row.add_child(add_six_button)

	var clear_button: Button = _make_button("清空临时标签", Callable(self, "_on_clear_temp_tags_pressed"))
	option_row.add_child(clear_button)

	_temp_tag_label = Label.new()
	_temp_tag_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_temp_tag_label.modulate = Color(0.86, 0.89, 0.93, 0.96)
	_temp_tag_label.custom_minimum_size = Vector2(0.0, 72.0)
	_temp_tag_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	section.add_child(_temp_tag_label)

func _build_spawner_section(root: VBoxContainer) -> void:
	var section: VBoxContainer = _create_section(root, "B. 实体生成")

	var elite_row: HBoxContainer = HBoxContainer.new()
	elite_row.add_theme_constant_override("separation", 10)
	section.add_child(elite_row)

	var elite_label: Label = Label.new()
	elite_label.text = "精英类型"
	elite_label.custom_minimum_size = Vector2(72.0, 0.0)
	elite_row.add_child(elite_label)

	_elite_option = OptionButton.new()
	_elite_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	elite_row.add_child(_elite_option)

	var training_row: HBoxContainer = HBoxContainer.new()
	training_row.add_theme_constant_override("separation", 10)
	section.add_child(training_row)

	var training_label: Label = Label.new()
	training_label.text = "教学敌人"
	training_label.custom_minimum_size = Vector2(72.0, 0.0)
	training_row.add_child(training_label)

	_training_option = OptionButton.new()
	_training_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	training_row.add_child(_training_option)

	var boss_row: HBoxContainer = HBoxContainer.new()
	boss_row.add_theme_constant_override("separation", 10)
	section.add_child(boss_row)

	var boss_label: Label = Label.new()
	boss_label.text = "Boss 类型"
	boss_label.custom_minimum_size = Vector2(72.0, 0.0)
	boss_row.add_child(boss_label)

	_boss_option = OptionButton.new()
	_boss_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	boss_row.add_child(_boss_option)

	var button_grid: GridContainer = GridContainer.new()
	button_grid.columns = 2
	button_grid.add_theme_constant_override("h_separation", 10)
	button_grid.add_theme_constant_override("v_separation", 10)
	section.add_child(button_grid)

	button_grid.add_child(_make_button("刷教学怪", Callable(self, "_on_spawn_training_enemy_pressed")))

	button_grid.add_child(_make_button("刷 10 只基础怪", Callable(self, "_on_spawn_basic_pack_pressed")))
	button_grid.add_child(_make_button("刷精英怪", Callable(self, "_on_spawn_elite_pressed")))
	button_grid.add_child(_make_button("刷木桩", Callable(self, "_on_spawn_dummy_pressed")))
	button_grid.add_child(_make_button("清空敌人", Callable(self, "_on_clear_enemies_pressed")))

func _build_player_state_section(root: VBoxContainer) -> void:
	var section: VBoxContainer = _create_section(root, "C. 玩家状态")

	var toggle_row: HBoxContainer = HBoxContainer.new()
	toggle_row.add_theme_constant_override("separation", 14)
	section.add_child(toggle_row)

	_invincible_toggle = CheckBox.new()
	_invincible_toggle.text = "前台角色无敌"
	toggle_row.add_child(_invincible_toggle)

	_infinite_energy_toggle = CheckBox.new()
	_infinite_energy_toggle.text = "无限能量"
	toggle_row.add_child(_infinite_energy_toggle)

	var action_row: HBoxContainer = HBoxContainer.new()
	action_row.add_theme_constant_override("separation", 10)
	section.add_child(action_row)
	action_row.add_child(_make_button("重置冷却", Callable(self, "_on_reset_cooldowns_pressed")))
	action_row.add_child(_make_button("补满能量", Callable(self, "_on_fill_energy_pressed")))

func _build_auto_player_section(root: VBoxContainer) -> void:
	var section: VBoxContainer = _create_section(root, "F. 自动化测试机器人")
	_ensure_auto_player_controller()

	var toggle_row: HBoxContainer = HBoxContainer.new()
	toggle_row.add_theme_constant_override("separation", 12)
	section.add_child(toggle_row)

	_auto_player_toggle = CheckBox.new()
	_auto_player_toggle.text = "开启 AI 代打"
	_auto_player_toggle.toggled.connect(_on_auto_player_toggled)
	toggle_row.add_child(_auto_player_toggle)

	var overdrive_button: Button = _make_button("AI 极速测试 x5", Callable(self, "_on_auto_player_overdrive_pressed"))
	toggle_row.add_child(overdrive_button)

	_auto_player_status_label = Label.new()
	_auto_player_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_auto_player_status_label.custom_minimum_size = Vector2(0.0, 42.0)
	_auto_player_status_label.modulate = Color(0.88, 0.91, 0.95, 0.96)
	section.add_child(_auto_player_status_label)
	_refresh_auto_player_ui()

func _build_game_flow_section(root: VBoxContainer) -> void:
	var section: VBoxContainer = _create_section(root, "D. 游戏进程")

	var time_row: HBoxContainer = HBoxContainer.new()
	time_row.add_theme_constant_override("separation", 10)
	section.add_child(time_row)

	var time_label: Label = Label.new()
	time_label.text = "时间流速"
	time_label.custom_minimum_size = Vector2(80.0, 0.0)
	time_row.add_child(time_label)

	_time_scale_slider = HSlider.new()
	_time_scale_slider.min_value = 0.1
	_time_scale_slider.max_value = 2.0
	_time_scale_slider.step = 0.05
	_time_scale_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_time_scale_slider.value = Engine.time_scale
	_time_scale_slider.value_changed.connect(_on_time_scale_changed)
	time_row.add_child(_time_scale_slider)

	_time_scale_value_label = Label.new()
	_time_scale_value_label.custom_minimum_size = Vector2(56.0, 0.0)
	time_row.add_child(_time_scale_value_label)

	var flow_row: HBoxContainer = HBoxContainer.new()
	flow_row.add_theme_constant_override("separation", 10)
	section.add_child(flow_row)
	flow_row.add_child(_make_button("重置时间", Callable(self, "_on_reset_time_scale_pressed")))
	flow_row.add_child(_make_button("清屏", Callable(self, "_on_clear_enemies_pressed")))

func _build_wave_section(root: VBoxContainer) -> void:
	var section: VBoxContainer = _create_section(root, "E. 波次与心流控制")

	var wave_row: HBoxContainer = HBoxContainer.new()
	wave_row.add_theme_constant_override("separation", 10)
	section.add_child(wave_row)

	var wave_label: Label = Label.new()
	wave_label.text = "波次时间"
	wave_label.custom_minimum_size = Vector2(80.0, 0.0)
	wave_row.add_child(wave_label)

	_wave_time_spinbox = SpinBox.new()
	_wave_time_spinbox.min_value = 1.0
	_wave_time_spinbox.max_value = 999.0
	_wave_time_spinbox.step = 1.0
	_wave_time_spinbox.value = 30.0
	wave_row.add_child(_wave_time_spinbox)

	_wave_lock_toggle = CheckBox.new()
	_wave_lock_toggle.text = "锁定"
	wave_row.add_child(_wave_lock_toggle)

	wave_row.add_child(_make_button("应用", Callable(self, "_on_apply_wave_override_pressed")))
	wave_row.add_child(_make_button("清除", Callable(self, "_on_clear_wave_override_pressed")))

	var spawn_rate_row: HBoxContainer = HBoxContainer.new()
	spawn_rate_row.add_theme_constant_override("separation", 10)
	section.add_child(spawn_rate_row)

	var spawn_rate_label: Label = Label.new()
	spawn_rate_label.text = "出怪倍率"
	spawn_rate_label.custom_minimum_size = Vector2(80.0, 0.0)
	spawn_rate_row.add_child(spawn_rate_label)

	_spawn_rate_slider = HSlider.new()
	_spawn_rate_slider.min_value = 0.1
	_spawn_rate_slider.max_value = 5.0
	_spawn_rate_slider.step = 0.1
	_spawn_rate_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_spawn_rate_slider.value_changed.connect(_on_spawn_rate_changed)
	spawn_rate_row.add_child(_spawn_rate_slider)

	_spawn_rate_value_label = Label.new()
	_spawn_rate_value_label.custom_minimum_size = Vector2(56.0, 0.0)
	spawn_rate_row.add_child(_spawn_rate_value_label)

	var cap_row: HBoxContainer = HBoxContainer.new()
	cap_row.add_theme_constant_override("separation", 10)
	section.add_child(cap_row)

	var cap_label: Label = Label.new()
	cap_label.text = "同屏上限"
	cap_label.custom_minimum_size = Vector2(80.0, 0.0)
	cap_row.add_child(cap_label)

	_max_enemy_spinbox = SpinBox.new()
	_max_enemy_spinbox.min_value = 0.0
	_max_enemy_spinbox.max_value = 200.0
	_max_enemy_spinbox.step = 1.0
	_max_enemy_spinbox.value_changed.connect(_on_max_enemy_changed)
	cap_row.add_child(_max_enemy_spinbox)

	cap_row.add_child(_make_button("重置上限", Callable(self, "_on_reset_enemy_cap_pressed")))

	var transition_grid: GridContainer = GridContainer.new()
	transition_grid.columns = 2
	transition_grid.add_theme_constant_override("h_separation", 10)
	transition_grid.add_theme_constant_override("v_separation", 10)
	section.add_child(transition_grid)
	transition_grid.add_child(_make_button("跳过当前波次", Callable(self, "_on_skip_wave_pressed")))
	transition_grid.add_child(_make_button("立刻生成 Boss", Callable(self, "_on_spawn_boss_pressed")))

func _build_intensity_monitor() -> void:
	var anchor: MarginContainer = MarginContainer.new()
	anchor.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	anchor.offset_left = -320.0
	anchor.offset_top = 18.0
	anchor.offset_right = -18.0
	anchor.offset_bottom = 210.0
	anchor.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(anchor)

	var panel: PanelContainer = PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", _build_panel_style(Color(0.05, 0.08, 0.11, 0.88)))
	anchor.add_child(panel)

	var margin: MarginContainer = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_bottom", 10)
	panel.add_child(margin)

	var root: VBoxContainer = VBoxContainer.new()
	root.add_theme_constant_override("separation", 4)
	margin.add_child(root)

	var title: Label = Label.new()
	title.text = "战斗强度"
	title.add_theme_font_size_override("font_size", 18)
	title.modulate = ACCENT
	root.add_child(title)

	_intensity_score_label = Label.new()
	_intensity_score_label.text = "--"
	_intensity_score_label.add_theme_font_size_override("font_size", 28)
	root.add_child(_intensity_score_label)

	_intensity_graph = DEBUG_INTENSITY_GRAPH_SCRIPT.new()
	_intensity_graph.custom_minimum_size = Vector2(0.0, 72.0)
	_intensity_graph.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.add_child(_intensity_graph)

	_intensity_breakdown_label = Label.new()
	_intensity_breakdown_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_intensity_breakdown_label.modulate = Color(0.86, 0.89, 0.93, 0.96)
	_intensity_breakdown_label.custom_minimum_size = Vector2(0.0, 74.0)
	root.add_child(_intensity_breakdown_label)

	_intensity_summary_label = Label.new()
	_intensity_summary_label.visible = false
	_intensity_summary_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_intensity_summary_label.modulate = Color(1.0, 0.96, 0.84, 0.98)
	_intensity_summary_label.custom_minimum_size = Vector2(0.0, 54.0)
	root.add_child(_intensity_summary_label)

func _build_auto_player_monitor() -> void:
	_ensure_auto_player_controller()
	var anchor: MarginContainer = MarginContainer.new()
	anchor.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	anchor.offset_left = -320.0
	anchor.offset_top = 236.0
	anchor.offset_right = -18.0
	anchor.offset_bottom = 390.0
	anchor.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(anchor)

	_auto_player_monitor_panel = PanelContainer.new()
	_auto_player_monitor_panel.visible = false
	_auto_player_monitor_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_auto_player_monitor_panel.add_theme_stylebox_override("panel", _build_panel_style(Color(0.05, 0.08, 0.11, 0.88)))
	anchor.add_child(_auto_player_monitor_panel)

	var margin: MarginContainer = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_bottom", 10)
	_auto_player_monitor_panel.add_child(margin)

	var root: VBoxContainer = VBoxContainer.new()
	root.add_theme_constant_override("separation", 4)
	margin.add_child(root)

	var title: Label = Label.new()
	title.text = "AI 代打"
	title.add_theme_font_size_override("font_size", 18)
	title.modulate = ACCENT
	root.add_child(title)

	_auto_player_monitor_label = Label.new()
	_auto_player_monitor_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_auto_player_monitor_label.custom_minimum_size = Vector2(0.0, 92.0)
	_auto_player_monitor_label.modulate = Color(0.88, 0.91, 0.95, 0.96)
	root.add_child(_auto_player_monitor_label)

func _create_section(root: VBoxContainer, title_text: String) -> VBoxContainer:
	var panel: PanelContainer = PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _build_panel_style(SECTION_BG))
	root.add_child(panel)

	var margin: MarginContainer = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	panel.add_child(margin)

	var section: VBoxContainer = VBoxContainer.new()
	section.add_theme_constant_override("separation", 10)
	margin.add_child(section)

	var title: Label = Label.new()
	title.text = title_text
	title.add_theme_font_size_override("font_size", 18)
	title.modulate = ACCENT
	section.add_child(title)
	return section

func _build_panel_style(bg_color: Color) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = bg_color
	style.border_color = BORDER
	style.set_border_width_all(1)
	style.set_corner_radius_all(8)
	style.content_margin_left = 8.0
	style.content_margin_top = 8.0
	style.content_margin_right = 8.0
	style.content_margin_bottom = 8.0
	return style

func _make_button(text_value: String, callback: Callable) -> Button:
	var button: Button = Button.new()
	button.text = text_value
	button.custom_minimum_size = Vector2(0.0, 34.0)
	button.pressed.connect(callback)
	return button

func _populate_bond_tags() -> void:
	if _bond_option == null:
		return
	_bond_option.clear()
	_bond_option_tags.clear()
	var entries: Array[Dictionary] = []
	for tag_variant: Variant in BondManager.bond_configs.keys():
		var tag: String = str(tag_variant)
		var config_variant: Variant = BondManager.bond_configs.get(tag, {})
		var config: Dictionary = config_variant if config_variant is Dictionary else {}
		entries.append({
			"tag": tag,
			"bond_type": str(config.get("bond_type", "")),
			"display_name": str(config.get("display_name", tag))
		})
	entries.sort_custom(_sort_bond_entries)
	for entry: Dictionary in entries:
		var tag: String = str(entry.get("tag", ""))
		var bond_type: String = str(entry.get("bond_type", ""))
		var display_name: String = str(entry.get("display_name", tag))
		_bond_option.add_item("%s_%s | %s" % [bond_type, tag, display_name])
		_bond_option_tags.append(tag)

func _sort_bond_entries(a: Dictionary, b: Dictionary) -> bool:
	var a_type: String = str(a.get("bond_type", ""))
	var b_type: String = str(b.get("bond_type", ""))
	var a_order: int = _get_bond_type_sort_order(a_type)
	var b_order: int = _get_bond_type_sort_order(b_type)
	if a_order != b_order:
		return a_order < b_order
	return str(a.get("display_name", "")).naturalnocasecmp_to(str(b.get("display_name", ""))) < 0

func _get_bond_type_sort_order(bond_type: String) -> int:
	match bond_type:
		"origin":
			return 0
		"mastery":
			return 1
		"tactic":
			return 2
		_:
			return 99

func _sync_controls_from_runtime() -> void:
	_on_time_scale_changed(Engine.time_scale)
	_refresh_auto_player_ui()
	_populate_elite_ids()
	_populate_training_enemy_ids()
	_populate_boss_ids()
	var spawner: Spawner = _get_spawner()
	if spawner == null:
		return
	var wave_time_value: float = max(1.0, spawner.wave_timer.time_left if spawner.wave_timer != null and not spawner.wave_timer.is_stopped() else 30.0)
	if spawner.debug_wave_time_override_active:
		wave_time_value = max(1.0, spawner.debug_wave_time_override_value)
	_wave_time_spinbox.value = wave_time_value
	_wave_lock_toggle.button_pressed = spawner.debug_wave_time_locked
	_spawn_rate_slider.value = spawner.debug_spawn_interval_multiplier
	_max_enemy_spinbox.value = float(spawner.debug_max_active_enemies_override)
	_update_spawn_rate_label(spawner.debug_spawn_interval_multiplier)

func _refresh_runtime_info() -> void:
	if _runtime_label == null:
		return
	_refresh_auto_player_ui()
	var spawner: Spawner = _get_spawner()
	var wave_text: String = "无刷怪器"
	var wave_time_text: String = "--"
	var enemy_count: int = 0
	var cap_text: String = "无限制"
	if spawner != null:
		wave_text = spawner.get_wave_text()
		wave_time_text = spawner.get_wave_timer_text()
		if spawner.has_method("_count_alive_enemies"):
			enemy_count = int(spawner.call("_count_alive_enemies"))
		var active_cap: int = spawner.get_effective_max_active_enemies()
		if active_cap > 0:
			cap_text = str(active_cap)
	var player: PlayerBase = _get_front_player()
	var player_text: String = "无"
	if player != null:
		player_text = "%s 生命 %.0f / 能量 %.0f" % [
			player.player_id,
			player.health_component.current_health if player.health_component != null else 0.0,
			player.energy
		]
	_runtime_label.text = "波次：%s | 剩余时间：%s | 敌人数：%d / %s | 前台角色：%s" % [
		wave_text,
		wave_time_text,
		enemy_count,
		cap_text,
		player_text
	]
	if _temp_tag_label != null:
		_temp_tag_label.text = _format_temp_tags(BondManager.get_temp_tags())

func _reset_intensity_session_state() -> void:
	_kill_event_times.clear()
	_intensity_history.clear()
	_current_intensity_score = 0.0
	_current_intensity_breakdown = {}
	_last_session_kills = Global.session_kills if Global != null else 0
	_wave_profile_index = -1
	_wave_profile_elapsed = 0.0
	_wave_profile_score_sum = 0.0
	_wave_profile_peak_time = 0.0
	_wave_profile_idle_time = 0.0
	_summary_visible_until_msec = 0

func _track_recent_kills() -> void:
	if Global == null:
		return
	var current_kills: int = int(Global.session_kills)
	if current_kills < _last_session_kills:
		_kill_event_times.clear()
		_last_session_kills = current_kills
		return
	if current_kills > _last_session_kills:
		var now_seconds: float = Time.get_ticks_msec() / 1000.0
		for i: int in range(current_kills - _last_session_kills):
			_kill_event_times.append(now_seconds)
		_last_session_kills = current_kills
	_prune_old_kill_events()

func _prune_old_kill_events() -> void:
	var now_seconds: float = Time.get_ticks_msec() / 1000.0
	while not _kill_event_times.is_empty() and now_seconds - float(_kill_event_times[0]) > INTENSITY_KILL_WINDOW:
		_kill_event_times.pop_front()

func _refresh_intensity_snapshot() -> void:
	_prune_old_kill_events()
	var snapshot: Dictionary = _compute_intensity_snapshot()
	_current_intensity_score = float(snapshot.get("score", 0.0))
	_current_intensity_breakdown = snapshot
	var now_seconds: float = Time.get_ticks_msec() / 1000.0
	var wave_index: int = -1
	var spawner: Spawner = _get_spawner()
	if spawner != null:
		wave_index = spawner.wave_index
	_intensity_history.append({
		"time": now_seconds,
		"score": _current_intensity_score,
		"wave": wave_index,
	})
	while not _intensity_history.is_empty() and now_seconds - float(_intensity_history[0].get("time", now_seconds)) > INTENSITY_HISTORY_WINDOW:
		_intensity_history.pop_front()
	_update_wave_profile(_current_intensity_score)
	_refresh_intensity_ui()

func _compute_intensity_snapshot() -> Dictionary:
	var player: PlayerBase = _get_front_player()
	if player == null or player.health_component == null:
		return {
			"score": 0.0,
			"survival": 0.0,
			"swarm": 0.0,
			"energy": 0.0,
			"kills": 0.0,
			"nearby_enemies": 0,
			"kill_count": 0,
		}

	var health_ratio: float = 0.0
	if player.health_component.max_health > 0.0:
		health_ratio = clamp(float(player.health_component.current_health) / float(player.health_component.max_health), 0.0, 1.0)
	var survival_score: float = clamp((1.0 - health_ratio) / 0.8, 0.0, 1.0) * 40.0

	var nearby_enemy_count: int = _count_nearby_alive_enemies(player.global_position, INTENSITY_NEARBY_RADIUS)
	var swarm_score: float = clamp(float(nearby_enemy_count) / 30.0, 0.0, 1.0) * 30.0

	var energy_ratio: float = 1.0
	if player.max_energy > 0.0:
		energy_ratio = clamp(float(player.energy) / float(player.max_energy), 0.0, 1.0)
	var energy_score: float = (1.0 - energy_ratio) * 15.0

	var kill_count: int = _kill_event_times.size()
	var kill_score: float = clamp(float(kill_count) / 10.0, 0.0, 1.0) * 15.0

	return {
		"score": clamp(survival_score + swarm_score + energy_score + kill_score, 0.0, 100.0),
		"survival": survival_score,
		"swarm": swarm_score,
		"energy": energy_score,
		"kills": kill_score,
		"nearby_enemies": nearby_enemy_count,
		"kill_count": kill_count,
	}

func _count_nearby_alive_enemies(center: Vector2, radius: float) -> int:
	var radius_sq: float = radius * radius
	var count: int = 0
	for enemy_variant in get_tree().get_nodes_in_group("enemies"):
		if not (enemy_variant is Enemy):
			continue
		var enemy: Enemy = enemy_variant as Enemy
		if enemy == null or not is_instance_valid(enemy) or enemy.is_dead:
			continue
		if enemy.global_position.distance_squared_to(center) <= radius_sq:
			count += 1
	return count

func _update_wave_profile(score: float) -> void:
	var spawner: Spawner = _get_spawner()
	if spawner == null or spawner.wave_timer == null or spawner.wave_timer.is_stopped() or Global.game_paused:
		return
	if _wave_profile_index != spawner.wave_index:
		_wave_profile_index = spawner.wave_index
		_wave_profile_elapsed = 0.0
		_wave_profile_score_sum = 0.0
		_wave_profile_peak_time = 0.0
		_wave_profile_idle_time = 0.0
	_wave_profile_elapsed += INTENSITY_SAMPLE_INTERVAL
	_wave_profile_score_sum += score * INTENSITY_SAMPLE_INTERVAL
	if score >= INTENSITY_PEAK_THRESHOLD:
		_wave_profile_peak_time += INTENSITY_SAMPLE_INTERVAL
	if score <= INTENSITY_IDLE_THRESHOLD:
		_wave_profile_idle_time += INTENSITY_SAMPLE_INTERVAL

func _refresh_intensity_ui() -> void:
	if _intensity_score_label == null or _intensity_breakdown_label == null:
		return
	var score_color: Color = _get_intensity_score_color(_current_intensity_score)
	_intensity_score_label.text = "%.0f / 100" % _current_intensity_score
	_intensity_score_label.modulate = score_color
	if _intensity_graph != null:
		_intensity_graph.set_samples(_intensity_history)
	var nearby_enemies: int = int(_current_intensity_breakdown.get("nearby_enemies", 0))
	var kill_count: int = int(_current_intensity_breakdown.get("kill_count", 0))
	_intensity_breakdown_label.text = "生存压力 %.0f / 40\n围剿压迫 %.0f / 30 (%d)\n资源枯竭 %.0f / 15\n杀戮吞吐 %.0f / 15 (%d/2秒)" % [
		float(_current_intensity_breakdown.get("survival", 0.0)),
		float(_current_intensity_breakdown.get("swarm", 0.0)),
		nearby_enemies,
		float(_current_intensity_breakdown.get("energy", 0.0)),
		float(_current_intensity_breakdown.get("kills", 0.0)),
		kill_count
	]

func _get_intensity_score_color(score: float) -> Color:
	if score >= 70.0:
		return Color(1.0, 0.35, 0.35, 1.0)
	if score >= 30.0:
		return Color(1.0, 0.82, 0.28, 1.0)
	return Color(0.42, 1.0, 0.58, 1.0)

func _on_spawner_wave_completed(wave_number: int) -> void:
	var average_intensity: float = 0.0
	var peak_ratio: float = 0.0
	var idle_ratio: float = 0.0
	if _wave_profile_elapsed > 0.0:
		average_intensity = _wave_profile_score_sum / _wave_profile_elapsed
		peak_ratio = (_wave_profile_peak_time / _wave_profile_elapsed) * 100.0
		idle_ratio = (_wave_profile_idle_time / _wave_profile_elapsed) * 100.0
	var summary_text: String = "Wave %d | 平均强度 %.1f | 高潮 %.0f%% | 垃圾时间 %.0f%%" % [
		wave_number,
		average_intensity,
		peak_ratio,
		idle_ratio
	]
	print("[IntensityProfiler] %s" % summary_text)
	if _intensity_summary_label != null:
		_intensity_summary_label.text = summary_text
		_intensity_summary_label.visible = true
	_summary_visible_until_msec = Time.get_ticks_msec() + 5000
	_wave_profile_index = -1
	_wave_profile_elapsed = 0.0
	_wave_profile_score_sum = 0.0
	_wave_profile_peak_time = 0.0
	_wave_profile_idle_time = 0.0

func _update_summary_visibility() -> void:
	if _intensity_summary_label == null:
		return
	if _summary_visible_until_msec <= 0:
		_intensity_summary_label.visible = false
		return
	_intensity_summary_label.visible = Time.get_ticks_msec() <= _summary_visible_until_msec

func _ensure_spawner_connection() -> void:
	var spawner: Spawner = _get_spawner()
	var current_ref: Variant = _connected_spawner_ref.get_ref() if _connected_spawner_ref != null else null
	if current_ref != null and current_ref == spawner:
		return
	if current_ref != null and is_instance_valid(current_ref):
		var old_spawner: Spawner = current_ref as Spawner
		if old_spawner.wave_completed.is_connected(_on_spawner_wave_completed):
			old_spawner.wave_completed.disconnect(_on_spawner_wave_completed)
	_connected_spawner_ref = null
	if spawner == null:
		return
	if not spawner.wave_completed.is_connected(_on_spawner_wave_completed):
		spawner.wave_completed.connect(_on_spawner_wave_completed)
	_connected_spawner_ref = weakref(spawner)

func _format_temp_tags(tags: Dictionary) -> String:
	if tags.is_empty():
		return "当前调试标签：无"
	var entries: Array[Dictionary] = []
	for tag_variant: Variant in tags.keys():
		var tag: String = str(tag_variant)
		var count: int = int(tags.get(tag_variant, 0))
		var config_variant: Variant = BondManager.bond_configs.get(tag, {})
		var config: Dictionary = config_variant if config_variant is Dictionary else {}
		entries.append({
			"tag": tag,
			"count": count,
			"bond_type": str(config.get("bond_type", "")),
			"display_name": str(config.get("display_name", tag))
		})
	entries.sort_custom(_sort_temp_tag_entries)
	var lines: Array[String] = ["当前调试标签："]
	for entry: Dictionary in entries:
		var display_name: String = str(entry.get("display_name", entry.get("tag", "")))
		var tag: String = str(entry.get("tag", ""))
		var bond_type: String = _get_bond_type_label(str(entry.get("bond_type", "")))
		var count: int = int(entry.get("count", 0))
		lines.append("- %s｜%s x%d" % [bond_type, display_name, count])
		lines.append("  ID: %s" % tag)
	return "\n".join(lines)

func _sort_temp_tag_entries(a: Dictionary, b: Dictionary) -> bool:
	var a_order: int = _get_bond_type_sort_order(str(a.get("bond_type", "")))
	var b_order: int = _get_bond_type_sort_order(str(b.get("bond_type", "")))
	if a_order != b_order:
		return a_order < b_order
	return str(a.get("display_name", "")).naturalnocasecmp_to(str(b.get("display_name", ""))) < 0

func _get_bond_type_label(bond_type: String) -> String:
	match bond_type:
		"origin":
			return "身世"
		"mastery":
			return "职能"
		"tactic":
			return "战术"
		_:
			return "未知"

func _display_status(message: String) -> void:
	if _status_label != null:
		_status_label.text = "状态：%s" % message

func _get_selected_tag() -> String:
	if _bond_option == null:
		return ""
	var index: int = _bond_option.selected
	if index < 0 or index >= _bond_option_tags.size():
		return ""
	return _bond_option_tags[index]

func _on_add_selected_tag_pressed() -> void:
	var tag: String = _get_selected_tag()
	if tag.is_empty():
		_display_status("未选择羁绊标签")
		return
	BondManager.add_temp_tag(tag)
	_refresh_runtime_info()
	_display_status("已注入临时羁绊标签：%s" % tag)

func _on_add_selected_tag_x6_pressed() -> void:
	var tag: String = _get_selected_tag()
	if tag.is_empty():
		_display_status("未选择羁绊标签")
		return
	for i: int in range(6):
		BondManager.add_temp_tag(tag)
	_refresh_runtime_info()
	_display_status("已为 %s 注入 6 层临时标签" % tag)

func _on_clear_temp_tags_pressed() -> void:
	BondManager.clear_temp_tags()
	_refresh_runtime_info()
	_display_status("已清空所有临时标签")

func _on_spawn_basic_pack_pressed() -> void:
	var spawner: Spawner = _get_spawner()
	if spawner == null:
		_display_status("未找到刷怪器")
		return
	var count: int = spawner.spawn_debug_basic_pack(_get_spawn_anchor(), 10)
	_refresh_runtime_info()
	_display_status("已生成 %d 只基础怪" % count)

func _on_spawn_elite_pressed() -> void:
	var spawner: Spawner = _get_spawner()
	if spawner == null:
		_display_status("未找到刷怪器")
		return
	var elite_id: String = _get_selected_elite_id()
	var enemy: Enemy = spawner.force_spawn_elite(elite_id, _get_spawn_anchor())
	_refresh_runtime_info()
	_display_status("精英怪生成：%s (%s)" % [("成功" if enemy != null else "失败"), elite_id])

func _on_spawn_training_enemy_pressed() -> void:
	var spawner: Spawner = _get_spawner()
	if spawner == null:
		_display_status("未找到刷怪器")
		return
	var enemy_id: String = _get_selected_training_enemy_id()
	var enemy: Enemy = spawner.spawn_debug_training_enemy_by_id(enemy_id, _get_spawn_anchor())
	_refresh_runtime_info()
	_display_status("教学敌人生成：%s (%s)" % [("成功" if enemy != null else "失败"), enemy_id])

func _on_spawn_dummy_pressed() -> void:
	var spawner: Spawner = _get_spawner()
	if spawner == null:
		_display_status("未找到刷怪器")
		return
	var enemy: Enemy = spawner.spawn_debug_training_dummy(_get_spawn_anchor())
	_refresh_runtime_info()
	_display_status("木桩生成：%s" % ("成功" if enemy != null else "失败"))

func _on_spawn_boss_pressed() -> void:
	var spawner: Spawner = _get_spawner()
	if spawner == null:
		_display_status("未找到刷怪器")
		return
	var boss_id: String = _get_selected_boss_id()
	var enemy: Enemy = spawner.spawn_debug_boss_by_id(_get_spawn_anchor(), boss_id)
	_refresh_runtime_info()
	_display_status("Boss 生成：%s (%s)" % [("成功" if enemy != null else "失败"), boss_id])

func _on_clear_enemies_pressed() -> void:
	var spawner: Spawner = _get_spawner()
	if spawner == null:
		_display_status("未找到刷怪器")
		return
	spawner.clear_enemies(false)
	_refresh_runtime_info()
	_display_status("已清空场上敌人")

func _on_reset_cooldowns_pressed() -> void:
	var player: PlayerBase = _get_front_player()
	if player == null:
		_display_status("未找到前台角色")
		return
	if player.has_method("reset_dash_cooldown"):
		player.reset_dash_cooldown()
	if player.has_method("reset_skill_e_cooldown"):
		player.reset_skill_e_cooldown()
	for property_name: String in [
		"_e_cooldown_remaining",
		"_gravity_well_cooldown_remaining",
		"_f_sequence_timer",
		"_overdrive_timer",
		"_death_metal_timer"
	]:
		if property_name in player:
			player.set(property_name, 0.0)
	_display_status("前台角色冷却已重置")

func _on_fill_energy_pressed() -> void:
	var player: PlayerBase = _get_front_player()
	if player == null:
		_display_status("未找到前台角色")
		return
	player.energy = player.max_energy
	player.update_ui_signals()
	_display_status("前台角色能量已补满")

func _on_time_scale_changed(value: float) -> void:
	Engine.time_scale = clamp(value, 0.1, 2.0)
	if _time_scale_value_label != null:
		_time_scale_value_label.text = "%.2fx" % Engine.time_scale

func _on_reset_time_scale_pressed() -> void:
	_time_scale_slider.value = 1.0
	_on_time_scale_changed(1.0)
	_display_status("时间流速已恢复为 1.0")

func _ensure_auto_player_controller() -> void:
	if _auto_player_controller != null and is_instance_valid(_auto_player_controller):
		return
	_auto_player_controller = AUTO_PLAYER_CONTROLLER_SCRIPT.new()
	_auto_player_controller.name = "AutoPlayerController"
	add_child(_auto_player_controller)
	if not _auto_player_controller.status_changed.is_connected(_on_auto_player_status_changed):
		_auto_player_controller.status_changed.connect(_on_auto_player_status_changed)

func _refresh_auto_player_ui() -> void:
	if _auto_player_controller == null:
		return
	if _auto_player_toggle != null:
		_auto_player_toggle.set_pressed_no_signal(_auto_player_controller.enabled)
	if _auto_player_status_label != null:
		_auto_player_status_label.text = _auto_player_controller.get_status_text()
	if _auto_player_monitor_panel != null:
		_auto_player_monitor_panel.visible = _auto_player_controller.enabled
	if _auto_player_monitor_label != null:
		var snapshot: Dictionary = _auto_player_controller.get_debug_snapshot()
		var mode_text: String = str(snapshot.get("movement_mode", "idle"))
		var draw_text: String = "ON" if bool(snapshot.get("draw_active", false)) else "OFF"
		var target_text: String = str(snapshot.get("target_id", ""))
		if target_text.is_empty():
			target_text = "--"
		var player_text: String = str(snapshot.get("player_id", ""))
		if player_text.is_empty():
			player_text = "--"
		var overdrive_scale: float = float(snapshot.get("overdrive_scale", 1.0))
		var pace_text: String = "%.1fx" % overdrive_scale if overdrive_scale > 1.0 else "1.0x"
		_auto_player_monitor_label.text = "前台: %s\n目标: %s\n行为: %s | 画线: %s\n近身威胁: %d | 节奏: %s\nHP %.0f%% | EN %.0f%% | Dash %.1fs" % [
			player_text,
			target_text,
			mode_text,
			draw_text,
			int(snapshot.get("nearby_enemy_count", 0)),
			pace_text,
			float(snapshot.get("health_ratio", 0.0)) * 100.0,
			float(snapshot.get("energy_ratio", 0.0)) * 100.0,
			float(snapshot.get("dash_cooldown", 0.0))
		]

func _on_auto_player_toggled(button_pressed: bool) -> void:
	_ensure_auto_player_controller()
	if button_pressed:
		_auto_player_controller.enable()
		_refresh_auto_player_ui()
		_display_status("AI 代打已接管正式输入")
		_set_overlay_visible(false)
		return
	_auto_player_controller.disable()
	_refresh_auto_player_ui()
	_display_status("AI 代打已关闭，输入已归还玩家")

func _on_auto_player_overdrive_pressed() -> void:
	_ensure_auto_player_controller()
	_auto_player_controller.start_overdrive(5.0)
	_refresh_auto_player_ui()
	_display_status("AI 极速测试已启动：5.0x")
	_set_overlay_visible(false)

func _on_auto_player_status_changed(message: String) -> void:
	if _auto_player_status_label != null:
		_auto_player_status_label.text = message
	_refresh_auto_player_ui()

func _on_apply_wave_override_pressed() -> void:
	var spawner: Spawner = _get_spawner()
	if spawner == null:
		_display_status("未找到刷怪器")
		return
	spawner.set_debug_wave_time_override(float(_wave_time_spinbox.value), _wave_lock_toggle.button_pressed)
	_refresh_runtime_info()
	_display_status("波次时间覆盖已应用：%.0f 秒%s" % [
		_wave_time_spinbox.value,
		"（已锁定）" if _wave_lock_toggle.button_pressed else ""
	])

func _on_clear_wave_override_pressed() -> void:
	var spawner: Spawner = _get_spawner()
	if spawner == null:
		_display_status("未找到刷怪器")
		return
	spawner.clear_debug_wave_time_override()
	_refresh_runtime_info()
	_display_status("波次时间覆盖已清除")

func _on_spawn_rate_changed(value: float) -> void:
	var clamped_value: float = clamp(value, 0.1, 5.0)
	_update_spawn_rate_label(clamped_value)
	var spawner: Spawner = _get_spawner()
	if spawner != null:
		spawner.set_debug_spawn_interval_multiplier(clamped_value)

func _update_spawn_rate_label(value: float) -> void:
	if _spawn_rate_value_label != null:
		_spawn_rate_value_label.text = "%.1fx" % value

func _on_max_enemy_changed(value: float) -> void:
	var spawner: Spawner = _get_spawner()
	if spawner == null:
		return
	spawner.set_debug_max_active_enemies_override(int(round(value)))
	_refresh_runtime_info()

func _on_reset_enemy_cap_pressed() -> void:
	_max_enemy_spinbox.value = 0.0
	_on_max_enemy_changed(0.0)
	_display_status("同屏上限覆盖已清除")

func _on_skip_wave_pressed() -> void:
	var spawner: Spawner = _get_spawner()
	if spawner == null:
		_display_status("未找到刷怪器")
		return
	_run_with_overlay_pause_released(Callable(spawner, "go_to_next_wave"))
	_refresh_runtime_info()
	_display_status("已强制跳转到下一波")

func _apply_player_state_toggles() -> void:
	var player: PlayerBase = _get_front_player()
	if _infinite_energy_toggle != null and _infinite_energy_toggle.button_pressed and player != null:
		if player.energy < player.max_energy:
			player.energy = player.max_energy
			player.update_ui_signals()

	if _invincible_toggle == null:
		return
	if not _invincible_toggle.button_pressed:
		_clear_invincible_override()
		return
	if player == null:
		return
	var last_player_variant: Variant = _last_invincible_player_ref.get_ref() if _last_invincible_player_ref != null else null
	if last_player_variant != null and is_instance_valid(last_player_variant) and last_player_variant != player:
		_set_player_invincible(last_player_variant, false)
	_set_player_invincible(player, true)
	_last_invincible_player_ref = weakref(player)

func _set_player_invincible(player_variant: Variant, enabled: bool) -> void:
	if player_variant == null or not is_instance_valid(player_variant):
		return
	if not (player_variant is PlayerBase):
		return
	var player: PlayerBase = player_variant as PlayerBase
	if player.health_component == null or not is_instance_valid(player.health_component):
		return
	player.health_component.is_invincible = enabled

func _clear_invincible_override() -> void:
	if _last_invincible_player_ref == null:
		return
	var last_player_variant: Variant = _last_invincible_player_ref.get_ref()
	if last_player_variant != null and is_instance_valid(last_player_variant):
		_set_player_invincible(last_player_variant, false)
	_last_invincible_player_ref = null

func _get_front_player() -> PlayerBase:
	if Global == null:
		return null
	if is_instance_valid(Global.player):
		return Global.player
	return null

func _get_spawn_anchor() -> Vector2:
	var player: PlayerBase = _get_front_player()
	if player != null:
		return player.global_position
	return Vector2.ZERO

func _get_spawner() -> Spawner:
	var arena_node: Node = get_tree().get_first_node_in_group("arena")
	if arena_node == null or not is_instance_valid(arena_node):
		return null
	var spawner_node: Node = arena_node.get_node_or_null("Spawner")
	if spawner_node == null or not is_instance_valid(spawner_node):
		return null
	if spawner_node is Spawner:
		return spawner_node as Spawner
	return null

func _populate_elite_ids() -> void:
	if _elite_option == null:
		return
	var spawner: Spawner = _get_spawner()
	var previous_id: String = _get_selected_elite_id()
	_elite_option.clear()
	_elite_option_ids.clear()
	if spawner == null:
		_elite_option.add_item("未找到刷怪器")
		_elite_option.disabled = true
		return
	_elite_option.disabled = false
	var ids: Array[String] = spawner.get_debug_force_spawn_elite_ids()
	for elite_id: String in ids:
		_elite_option.add_item(elite_id)
		_elite_option_ids.append(elite_id)
	if _elite_option_ids.is_empty():
		_elite_option.add_item("无可用精英")
		_elite_option.disabled = true
		return
	var selected_index: int = _elite_option_ids.find(previous_id)
	if selected_index < 0:
		selected_index = 0
	_elite_option.select(selected_index)

func _get_selected_elite_id() -> String:
	if _elite_option == null or _elite_option_ids.is_empty():
		return "siege_behemoth"
	var selected_index: int = clamp(_elite_option.selected, 0, _elite_option_ids.size() - 1)
	return _elite_option_ids[selected_index]

func _populate_training_enemy_ids() -> void:
	if _training_option == null:
		return
	var spawner: Spawner = _get_spawner()
	var previous_id: String = _get_selected_training_enemy_id()
	_training_option.clear()
	_training_option_ids.clear()
	if spawner == null:
		_training_option.add_item("未找到刷怪器")
		_training_option.disabled = true
		return
	_training_option.disabled = false
	var ids: Array[String] = spawner.get_debug_training_enemy_ids()
	for enemy_id: String in ids:
		_training_option.add_item(enemy_id)
		_training_option_ids.append(enemy_id)
	if _training_option_ids.is_empty():
		_training_option.add_item("无可用教学敌人")
		_training_option.disabled = true
		return
	var selected_index: int = _training_option_ids.find(previous_id)
	if selected_index < 0:
		selected_index = 0
	_training_option.select(selected_index)

func _get_selected_training_enemy_id() -> String:
	if _training_option == null or _training_option_ids.is_empty():
		return "line_dummy"
	var selected_index: int = clamp(_training_option.selected, 0, _training_option_ids.size() - 1)
	return _training_option_ids[selected_index]

func _populate_boss_ids() -> void:
	if _boss_option == null:
		return
	var spawner: Spawner = _get_spawner()
	var previous_id: String = _get_selected_boss_id()
	_boss_option.clear()
	_boss_option_ids.clear()
	if spawner == null:
		_boss_option.add_item("未找到刷怪器")
		_boss_option.disabled = true
		return
	_boss_option.disabled = false
	var ids: Array[String] = spawner.get_debug_force_spawn_boss_ids()
	for boss_id: String in ids:
		_boss_option.add_item(boss_id)
		_boss_option_ids.append(boss_id)
	if _boss_option_ids.is_empty():
		_boss_option.add_item("无可用 Boss")
		_boss_option.disabled = true
		return
	var selected_index: int = _boss_option_ids.find(previous_id)
	if selected_index < 0:
		selected_index = 0
	_boss_option.select(selected_index)

func _get_selected_boss_id() -> String:
	if _boss_option == null or _boss_option_ids.is_empty():
		return "boss_enemy"
	var selected_index: int = clamp(_boss_option.selected, 0, _boss_option_ids.size() - 1)
	return _boss_option_ids[selected_index]

func _run_with_overlay_pause_released(action: Callable) -> void:
	var resume_overlay_pause: bool = visible
	if resume_overlay_pause:
		PauseService.release_pause(PAUSE_SOURCE, get_tree())
	action.call()
	if resume_overlay_pause and visible:
		PauseService.request_pause(PAUSE_SOURCE, get_tree())
