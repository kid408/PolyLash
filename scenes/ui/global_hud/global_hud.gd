extends Control
class_name GlobalHUD

const DEBUG_VERBOSE := false

# UI 节点引用
@onready var vbox_container: VBoxContainer = $VBoxContainer
@onready var resource_container: HBoxContainer = $VBoxContainer/ResourceContainer
@onready var wave_label: Label = $VBoxContainer/WaveContainer/WaveLabel
@onready var wave_time_label: Label = $VBoxContainer/WaveContainer/WaveTimeLabel
@onready var xp_label: Label = $VBoxContainer/ResourceContainer/XPLabel
@onready var gold_label: Label = $VBoxContainer/ResourceContainer/GoldLabel

# 颜色配置
const XP_COLOR: Color = Color(0.7, 0.5, 1.0)  # 紫色
const GOLD_COLOR: Color = Color(1.0, 0.85, 0.0)  # 金黄色
const TIMER_NORMAL_COLOR: Color = Color.WHITE
const TIMER_URGENT_COLOR: Color = Color(1.0, 0.3, 0.3)  # 红色（紧急）
const DANGER_COLOR_LV1: Color = Color(1.00, 0.75, 0.25)
const DANGER_COLOR_LV2: Color = Color(1.00, 0.40, 0.20)
const DANGER_COLOR_LV3: Color = Color(1.00, 0.15, 0.15)

var danger_label: Label = null
var _danger_show_token: int = 0
var level_label: Label = null
var xp_progress: ProgressBar = null
var boss_shell: PanelContainer = null
var boss_content: VBoxContainer = null
var boss_panel: VBoxContainer = null
var boss_name_label: Label = null
var boss_mechanic_label: Label = null
var boss_phase_label: Label = null
var boss_health_bar: ProgressBar = null
var boss_health_bar_overlay: Control = null
var boss_phase_track: RichTextLabel = null
var boss_banner_label: Label = null
var _boss_banner_token: int = 0
var _boss_warning_boss_id: int = 0
var _boss_warning_phase: int = 0
var _boss_warning_active: bool = false
var _boss_shell_accent: Color = Color(0.00, 0.94, 1.0)
var _boss_shell_is_final: bool = false

func _ready() -> void:
	# 连接 Global 信号
	Global.on_session_xp_changed.connect(_on_session_xp_changed)
	var progression: Node = get_node_or_null("/root/ProgressionManager")
	if progression and progression.has_signal("progression_changed"):
		var progression_changed_cb: Callable = Callable(self, "_on_progression_changed")
		if not progression.is_connected("progression_changed", progression_changed_cb):
			progression.connect("progression_changed", progression_changed_cb)
	
	# 连接 DataManager 局内金币信号
	if DataManager.has_signal("run_gold_changed"):
		DataManager.run_gold_changed.connect(_on_gold_changed)
		if DEBUG_VERBOSE: print("[GlobalHUD] 已连接 DataManager.run_gold_changed 信号")
	elif DataManager.has_signal("gold_changed"):
		DataManager.gold_changed.connect(_on_gold_changed)
		if DEBUG_VERBOSE: print("[GlobalHUD] 已连接 DataManager.gold_changed 信号(兼容)")
	
	# 设置资源标签颜色
	if xp_label:
		xp_label.add_theme_color_override("font_color", XP_COLOR)
	if gold_label:
		gold_label.add_theme_color_override("font_color", GOLD_COLOR)

	_ensure_progress_widgets()
	_ensure_boss_widgets()
	
	# 初始化显示
	if progression and progression.has_method("get_current_level"):
		_on_progression_changed(
			int(progression.call("get_current_level")),
			int(progression.call("get_xp_in_level")),
			int(progression.call("get_xp_to_next_level")),
			int(progression.call("get_total_xp"))
		)
	else:
		update_xp(RunStateService.get_run_xp())
	update_gold(RunStateService.get_run_gold())
	_ensure_danger_label()
	_ensure_boss_banner()

# 更新波次显示
func update_wave(wave_number: int, wave_time: float) -> void:
	if wave_label:
		wave_label.text = "Wave %d" % wave_number
	if wave_time_label:
		wave_time_label.text = "%d" % int(wave_time)

# 更新波次文本（直接设置）- 添加分隔符格式
func set_wave_text(text: String) -> void:
	if wave_label:
		wave_label.text = text

# 更新波次时间文本（直接设置）- 简化为秒数显示
func set_wave_time_text(text: String) -> void:
	if wave_time_label:
		var seconds = int(text) if text.is_valid_int() else 0
		wave_time_label.text = "| %ds" % seconds
		
		# 紧急状态：时间 < 10 秒时变红
		if seconds < 10 and seconds > 0:
			wave_time_label.add_theme_color_override("font_color", TIMER_URGENT_COLOR)
		else:
			wave_time_label.add_theme_color_override("font_color", TIMER_NORMAL_COLOR)

# 更新 XP 显示
func update_xp(current_xp: int) -> void:
	if xp_label:
		var progression: Node = get_node_or_null("/root/ProgressionManager")
		if progression and progression.has_method("get_xp_in_level"):
			var cur: int = int(progression.call("get_xp_in_level"))
			var need: int = max(1, int(progression.call("get_xp_to_next_level")))
			xp_label.text = "XP: %d/%d" % [cur, need]
		else:
			xp_label.text = "XP: %d" % current_xp

# 更新金币显示
func update_gold(total_gold: int) -> void:
	if gold_label:
		gold_label.text = "Gold: %d" % total_gold

# 信号处理
func _on_session_xp_changed(current: int) -> void:
	update_xp(current)

func _on_gold_changed(new_gold: int) -> void:
	"""金币变化时更新显示"""
	if DEBUG_VERBOSE: print("[GlobalHUD] 收到金币变化信号: new_gold=%d" % new_gold)
	update_gold(new_gold)

func _ensure_progress_widgets() -> void:
	if not resource_container or not vbox_container:
		return

	if level_label == null:
		level_label = Label.new()
		level_label.name = "LevelLabel"
		level_label.text = "LV 1"
		level_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		level_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		level_label.add_theme_font_size_override("font_size", 20)
		level_label.add_theme_color_override("font_color", Color(1.0, 0.95, 0.6))
		resource_container.add_child(level_label)
		resource_container.move_child(level_label, 0)

	if xp_progress == null:
		xp_progress = ProgressBar.new()
		xp_progress.name = "XPProgress"
		xp_progress.custom_minimum_size = Vector2(420, 14)
		xp_progress.show_percentage = false
		xp_progress.max_value = 100.0
		xp_progress.value = 0.0
		vbox_container.add_child(xp_progress)
		vbox_container.move_child(xp_progress, 1)

func _ensure_boss_widgets() -> void:
	if boss_panel != null and is_instance_valid(boss_panel):
		return

	boss_shell = PanelContainer.new()
	boss_shell.name = "BossPanelShell"
	boss_shell.visible = false
	boss_shell.custom_minimum_size = Vector2(560.0, 0.0)
	boss_shell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	boss_shell.add_theme_stylebox_override("panel", _make_boss_shell_style())
	vbox_container.add_child(boss_shell)
	vbox_container.move_child(boss_shell, 2)

	boss_panel = VBoxContainer.new()
	boss_panel.name = "BossPanel"
	boss_panel.visible = true
	boss_panel.custom_minimum_size = Vector2(540.0, 0.0)
	boss_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	boss_panel.alignment = BoxContainer.ALIGNMENT_CENTER
	boss_panel.add_theme_constant_override("separation", 3)
	boss_shell.add_child(boss_panel)
	boss_content = boss_panel

	boss_name_label = Label.new()
	boss_name_label.name = "BossNameLabel"
	boss_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	boss_name_label.add_theme_font_size_override("font_size", 26)
	boss_name_label.add_theme_color_override("font_color", Color(0.96, 0.97, 1.0))
	boss_content.add_child(boss_name_label)

	boss_mechanic_label = Label.new()
	boss_mechanic_label.name = "BossMechanicLabel"
	boss_mechanic_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	boss_mechanic_label.add_theme_font_size_override("font_size", 15)
	boss_mechanic_label.add_theme_color_override("font_color", Color(0.55, 0.87, 1.0))
	boss_content.add_child(boss_mechanic_label)

	boss_phase_label = Label.new()
	boss_phase_label.name = "BossPhaseLabel"
	boss_phase_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	boss_phase_label.add_theme_font_size_override("font_size", 16)
	boss_phase_label.add_theme_color_override("font_color", Color(1.0, 0.82, 0.40))
	boss_content.add_child(boss_phase_label)

	boss_health_bar = ProgressBar.new()
	boss_health_bar.name = "BossHealthBar"
	boss_health_bar.custom_minimum_size = Vector2(540.0, 14.0)
	boss_health_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	boss_health_bar.show_percentage = false
	boss_health_bar.max_value = 100.0
	boss_health_bar.value = 100.0
	boss_content.add_child(boss_health_bar)
	boss_health_bar_overlay = Control.new()
	boss_health_bar_overlay.name = "BossHealthBarOverlay"
	boss_health_bar_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	boss_health_bar_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	boss_health_bar.add_child(boss_health_bar_overlay)

	boss_phase_track = RichTextLabel.new()
	boss_phase_track.name = "BossPhaseTrack"
	boss_phase_track.fit_content = true
	boss_phase_track.bbcode_enabled = true
	boss_phase_track.scroll_active = false
	boss_phase_track.mouse_filter = Control.MOUSE_FILTER_IGNORE
	boss_phase_track.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	boss_phase_track.add_theme_font_size_override("normal_font_size", 14)
	boss_content.add_child(boss_phase_track)
	_apply_boss_health_bar_style(Color(0.00, 0.94, 1.0))

func update_boss_status(boss: Node, wave_number: int = 0, peak_event: String = "") -> void:
	_ensure_boss_widgets()
	if boss == null or not is_instance_valid(boss):
		_hide_boss_panel()
		return
	if not boss.has_method("is_boss_enemy") or not bool(boss.call("is_boss_enemy")):
		_hide_boss_panel()
		return
	if bool(boss.get("is_dead")):
		_hide_boss_panel()
		return

	var boss_instance_id: int = boss.get_instance_id()
	var display_name: String = str(boss.get_meta("boss_display_name", str(boss.get("enemy_id"))))
	var mechanic_hint: String = str(boss.get_meta("boss_mechanic_hint", ""))
	var phase_no: int = int(boss.get("boss_current_phase"))
	var event_tag: String = str(boss.get_meta("boss_phase_event_tag", ""))
	var phase_thresholds: Array[Dictionary] = _extract_boss_phase_thresholds(boss)
	var health_component: Node = boss.get("health_component")
	var current_hp: float = 0.0
	var max_hp: float = 1.0
	var current_hp_ratio: float = 1.0
	if health_component != null and is_instance_valid(health_component):
		current_hp = float(health_component.get("current_health"))
		max_hp = max(1.0, float(health_component.get("max_health")))
	current_hp_ratio = clamp(current_hp / max_hp, 0.0, 1.0)
	var warning_info: Dictionary = _get_next_phase_warning_info(current_hp_ratio, phase_thresholds, phase_no)

	boss_panel.get_parent().visible = true
	boss_name_label.text = display_name if wave_number <= 0 else "[WAVE %d]  %s" % [wave_number, display_name]
	boss_mechanic_label.text = mechanic_hint if peak_event.is_empty() else "%s  |  %s" % [mechanic_hint, format_peak_event(peak_event)]
	boss_phase_label.text = "阶段 %d" % phase_no if event_tag.is_empty() else "阶段 %d · %s" % [phase_no, format_event_tag(event_tag)]
	boss_health_bar.max_value = max_hp
	boss_health_bar.value = clamp(current_hp, 0.0, max_hp)
	_update_boss_phase_markers(phase_thresholds, phase_no, warning_info)
	boss_phase_track.text = _build_phase_track_text(phase_no, phase_thresholds, warning_info)
	_apply_boss_visual_style(phase_no, peak_event)
	_process_boss_phase_warning(boss_instance_id, warning_info)

func show_boss_banner(title: String, subtitle: String = "", color: Color = Color(0.9, 0.95, 1.0), hold_time: float = 1.6, is_critical: bool = false) -> void:
	_ensure_boss_banner()
	_boss_banner_token += 1
	var token: int = _boss_banner_token
	boss_banner_label.text = title if subtitle.is_empty() else "%s\n%s" % [title, subtitle]
	boss_banner_label.add_theme_color_override("font_color", color)
	boss_banner_label.add_theme_font_size_override("font_size", 30 if is_critical else 24)
	boss_banner_label.visible = true
	boss_banner_label.modulate.a = 1.0
	boss_banner_label.scale = Vector2.ONE
	var tween: Tween = create_tween()
	tween.tween_property(boss_banner_label, "scale", Vector2(1.08, 1.08) if is_critical else Vector2(1.04, 1.04), 0.12)
	tween.tween_property(boss_banner_label, "scale", Vector2.ONE, 0.18 if is_critical else 0.16)
	_hide_boss_banner_later(token, hold_time)

func _on_progression_changed(level: int, xp_in_level: int, xp_to_next: int, _total_xp: int) -> void:
	if level_label:
		level_label.text = "LV %d" % level

	if xp_progress:
		xp_progress.max_value = float(max(1, xp_to_next))
		xp_progress.value = clamp(float(xp_in_level), 0.0, xp_progress.max_value)

	if xp_label:
		xp_label.text = "XP: %d/%d" % [xp_in_level, max(1, xp_to_next)]

func _ensure_danger_label() -> void:
	if danger_label and is_instance_valid(danger_label):
		return

	danger_label = Label.new()
	danger_label.name = "DangerLabel"
	danger_label.text = ""
	danger_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	danger_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	danger_label.anchor_left = 0.5
	danger_label.anchor_right = 0.5
	danger_label.anchor_top = 0.0
	danger_label.anchor_bottom = 0.0
	danger_label.offset_left = -260.0
	danger_label.offset_right = 260.0
	danger_label.offset_top = 86.0
	danger_label.offset_bottom = 122.0
	danger_label.visible = false
	danger_label.modulate = Color.WHITE
	danger_label.add_theme_font_size_override("font_size", 30)
	add_child(danger_label)

func _ensure_boss_banner() -> void:
	if boss_banner_label and is_instance_valid(boss_banner_label):
		return

	boss_banner_label = Label.new()
	boss_banner_label.name = "BossBannerLabel"
	boss_banner_label.text = ""
	boss_banner_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	boss_banner_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	boss_banner_label.anchor_left = 0.5
	boss_banner_label.anchor_right = 0.5
	boss_banner_label.anchor_top = 0.0
	boss_banner_label.anchor_bottom = 0.0
	boss_banner_label.offset_left = -320.0
	boss_banner_label.offset_right = 320.0
	boss_banner_label.offset_top = 122.0
	boss_banner_label.offset_bottom = 188.0
	boss_banner_label.visible = false
	boss_banner_label.add_theme_font_size_override("font_size", 24)
	add_child(boss_banner_label)

func show_health_danger(level: int, current: float, max_val: float, ratio: float) -> void:
	_ensure_danger_label()

	var hp_text := "%d/%d" % [int(current), int(max_val)]
	var percent := int(ratio * 100.0)
	var hold_time := 1.2

	match level:
		1:
			danger_label.text = "警告: 生命值危险 (%d%%)  %s" % [percent, hp_text]
			danger_label.add_theme_color_override("font_color", DANGER_COLOR_LV1)
			hold_time = 1.4
		2:
			danger_label.text = "危险: 生命值极低 (%d%%)  %s" % [percent, hp_text]
			danger_label.add_theme_color_override("font_color", DANGER_COLOR_LV2)
			hold_time = 1.8
		_:
			danger_label.text = "致命: 立即脱离战斗! (%d%%)  %s" % [percent, hp_text]
			danger_label.add_theme_color_override("font_color", DANGER_COLOR_LV3)
			hold_time = 2.3

	danger_label.visible = true
	danger_label.scale = Vector2.ONE
	var pulse = create_tween()
	pulse.tween_property(danger_label, "scale", Vector2(1.05, 1.05), 0.10)
	pulse.tween_property(danger_label, "scale", Vector2.ONE, 0.12)

	# 使用 token 防止旧的延迟隐藏请求覆盖新的高等级警告
	_danger_show_token += 1
	var token = _danger_show_token
	_hide_danger_later(token, hold_time)

func clear_health_danger() -> void:
	if not danger_label:
		return
	_danger_show_token += 1
	danger_label.visible = false
	danger_label.text = ""

func format_event_tag(event_tag: String) -> String:
	match event_tag.strip_edges().to_lower():
		"brood":
			return "群潮成形"
		"devour":
			return "吞噬提速"
		"frenzy":
			return "残血狂潮"
		"survey":
			return "空间观测"
		"cut":
			return "切割封锁"
		"invert":
			return "闭合反转"
		"fortify":
			return "装甲展开"
		"barrage":
			return "火力压制"
		"last_stand":
			return "终局推进"
		"teach":
			return "教学阶段"
		"summon_zone":
			return "召群压场"
		"finisher":
			return "收束爆发"
		_:
			return event_tag

func format_peak_event(peak_event: String) -> String:
	match peak_event.strip_edges().to_lower():
		"mid_boss":
			return "中期 Boss"
		"late_boss":
			return "后期 Boss"
		"final_boss":
			return "最终 Boss"
		_:
			return peak_event

func _hide_boss_panel() -> void:
	if boss_panel != null and boss_panel.get_parent() != null:
		boss_panel.get_parent().visible = false
	_clear_boss_warning_state()

func _make_boss_shell_style(accent: Color = Color(0.00, 0.94, 1.0), is_final: bool = false) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.08, 0.12, 0.88)
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.border_color = Color(0.16, 0.28, 0.34, 0.95).lerp(accent, 0.28 if not is_final else 0.45)
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6
	style.content_margin_left = 10
	style.content_margin_top = 8
	style.content_margin_right = 10
	style.content_margin_bottom = 8
	if is_final:
		style.bg_color = style.bg_color.lerp(Color(0.14, 0.04, 0.04, 0.92), 0.55)
		style.border_width_left = 2
		style.border_width_top = 2
		style.border_width_right = 2
		style.border_width_bottom = 2
	return style

func _make_progress_style(fill_color: Color, background_color: Color, border_color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background_color
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.border_color = border_color
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_left = 4
	style.corner_radius_bottom_right = 4
	if fill_color.a > 0.0:
		style.bg_color = fill_color
	return style

func _apply_boss_health_bar_style(fill_color: Color) -> void:
	if boss_health_bar == null:
		return
	boss_health_bar.add_theme_stylebox_override("background", _make_progress_style(Color(0.08, 0.12, 0.16, 1.0), Color(0.08, 0.12, 0.16, 1.0), Color(0.18, 0.26, 0.30, 1.0)))
	boss_health_bar.add_theme_stylebox_override("fill", _make_progress_style(fill_color, fill_color, Color(fill_color.r * 0.7, fill_color.g * 0.7, fill_color.b * 0.7, 1.0)))

func _apply_boss_visual_style(phase_no: int, peak_event: String) -> void:
	var accent: Color = Color(0.00, 0.94, 1.0)
	var is_final_boss: bool = peak_event.strip_edges().to_lower() == "final_boss"
	match phase_no:
		2:
			accent = Color(1.0, 0.78, 0.22)
		3:
			accent = Color(1.0, 0.34, 0.34)
	if is_final_boss:
		accent = accent.lerp(Color(1.0, 0.18, 0.18), 0.28)
	_boss_shell_accent = accent
	_boss_shell_is_final = is_final_boss
	boss_name_label.add_theme_color_override("font_color", accent.lightened(0.18))
	boss_mechanic_label.add_theme_color_override("font_color", accent.lerp(Color.WHITE, 0.35))
	boss_phase_label.add_theme_color_override("font_color", accent)
	_apply_boss_health_bar_style(accent)
	if not _boss_warning_active:
		_apply_boss_shell_warning_visual(0.0)

func _build_phase_track_text(current_phase: int, phase_thresholds: Array[Dictionary] = [], warning_info: Dictionary = {}) -> String:
	var segments: Array[String] = []
	var threshold_lookup: Dictionary = {}
	for threshold_entry_variant in phase_thresholds:
		if not (threshold_entry_variant is Dictionary):
			continue
		var threshold_entry: Dictionary = threshold_entry_variant
		threshold_lookup[int(threshold_entry.get("phase", 0))] = int(round(float(threshold_entry.get("ratio", 0.0)) * 100.0))
	for phase_no: int in [1, 2, 3]:
		var color: String = "#5B6B75"
		if phase_no < current_phase:
			color = "#8FA3AD"
		elif phase_no == current_phase:
			color = "#E6EDF3"
		if int(warning_info.get("phase", 0)) == phase_no:
			color = _warning_track_color(float(warning_info.get("strength", 0.0)))
		var label: String = "PHASE-%d" % phase_no
		if threshold_lookup.has(phase_no):
			label += " %d%%" % int(threshold_lookup[phase_no])
		if phase_no == current_phase:
			label = "[ %s ]" % label
		segments.append("[color=%s]%s[/color]" % [color, label])
	return "   ".join(segments)

func _extract_boss_phase_thresholds(boss: Node) -> Array[Dictionary]:
	var thresholds: Array[Dictionary] = []
	if boss == null or not is_instance_valid(boss):
		return thresholds
	var configs_variant: Variant = boss.get("boss_phase_configs")
	if not (configs_variant is Array):
		return thresholds
	for phase_cfg_variant in configs_variant:
		if not (phase_cfg_variant is Dictionary):
			continue
		var phase_cfg: Dictionary = phase_cfg_variant
		var phase_no: int = int(phase_cfg.get("phase", 0))
		if phase_no <= 1:
			continue
		thresholds.append({
			"phase": phase_no,
			"ratio": clamp(float(phase_cfg.get("trigger_hp_ratio", 0.0)), 0.0, 1.0),
		})
	thresholds.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a.get("phase", 0)) < int(b.get("phase", 0))
	)
	return thresholds

func _update_boss_phase_markers(phase_thresholds: Array[Dictionary], current_phase: int, warning_info: Dictionary = {}) -> void:
	if boss_health_bar_overlay == null or not is_instance_valid(boss_health_bar_overlay):
		return
	for child: Node in boss_health_bar_overlay.get_children():
		child.queue_free()
	for threshold_entry_variant in phase_thresholds:
		if not (threshold_entry_variant is Dictionary):
			continue
		var threshold_entry: Dictionary = threshold_entry_variant
		var phase_no: int = int(threshold_entry.get("phase", 0))
		var ratio: float = clamp(float(threshold_entry.get("ratio", 0.0)), 0.0, 1.0)
		var x_offset: float = lerpf(0.0, boss_health_bar.size.x, ratio)
		var marker := ColorRect.new()
		marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if int(warning_info.get("phase", 0)) == phase_no:
			marker.color = _warning_marker_color(float(warning_info.get("strength", 0.0)))
		else:
			marker.color = Color(0.92, 0.96, 1.0, 0.95) if phase_no > current_phase else Color(1.0, 0.78, 0.28, 0.92)
		marker.anchor_left = 0.0
		marker.anchor_right = 0.0
		marker.anchor_top = 0.0
		marker.anchor_bottom = 1.0
		marker.offset_left = x_offset - 1.0
		marker.offset_right = x_offset + 1.0
		marker.offset_top = 1.0
		marker.offset_bottom = -1.0
		boss_health_bar_overlay.add_child(marker)

func _get_next_phase_warning_info(current_hp_ratio: float, phase_thresholds: Array[Dictionary], current_phase: int) -> Dictionary:
	for threshold_entry_variant in phase_thresholds:
		if not (threshold_entry_variant is Dictionary):
			continue
		var threshold_entry: Dictionary = threshold_entry_variant
		var phase_no: int = int(threshold_entry.get("phase", 0))
		if phase_no <= current_phase:
			continue
		var threshold_ratio: float = clamp(float(threshold_entry.get("ratio", 0.0)), 0.0, 1.0)
		var distance_to_threshold: float = current_hp_ratio - threshold_ratio
		if distance_to_threshold < 0.0 or distance_to_threshold > 0.05:
			return {}
		var progress: float = 1.0 - clamp(distance_to_threshold / 0.05, 0.0, 1.0)
		var pulse: float = 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.018)
		var strength: float = clamp(progress * (0.65 + 0.35 * pulse), 0.0, 1.0)
		return {
			"phase": phase_no,
			"strength": strength,
		}
	return {}

func _process_boss_phase_warning(boss_instance_id: int, warning_info: Dictionary) -> void:
	if warning_info.is_empty():
		_clear_boss_warning_state()
		return
	var warning_phase: int = int(warning_info.get("phase", 0))
	var warning_strength: float = float(warning_info.get("strength", 0.0))
	_apply_boss_shell_warning_visual(warning_strength)
	if _boss_warning_boss_id == boss_instance_id and _boss_warning_phase == warning_phase and _boss_warning_active:
		return
	_boss_warning_boss_id = boss_instance_id
	_boss_warning_phase = warning_phase
	_boss_warning_active = true
	show_boss_banner("临界警报", "阶段 %d 即将到来" % warning_phase, _warning_marker_color(max(0.55, warning_strength)), 0.95, _boss_shell_is_final)
	if Engine.is_editor_hint():
		return
	SoundManager.play("enemy_charge_warning")

func _clear_boss_warning_state() -> void:
	if not _boss_warning_active:
		_apply_boss_shell_warning_visual(0.0)
		return
	_boss_warning_active = false
	_boss_warning_boss_id = 0
	_boss_warning_phase = 0
	_apply_boss_shell_warning_visual(0.0)

func _apply_boss_shell_warning_visual(strength: float) -> void:
	if boss_shell == null or not is_instance_valid(boss_shell):
		return
	var normalized_strength: float = clamp(strength, 0.0, 1.0)
	var style := _make_boss_shell_style(_boss_shell_accent, _boss_shell_is_final)
	if normalized_strength > 0.0:
		var pulse: float = 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.022)
		var blink: float = clamp(0.35 + normalized_strength * 0.65 * pulse, 0.0, 1.0)
		style.border_color = style.border_color.lerp(_warning_marker_color(blink), blink)
		style.bg_color = style.bg_color.lerp(Color(0.16, 0.05, 0.05, 0.94), (0.18 if not _boss_shell_is_final else 0.28) * normalized_strength)
	boss_shell.add_theme_stylebox_override("panel", style)

func _warning_marker_color(strength: float) -> Color:
	var base_color: Color = Color(1.0, 0.80, 0.24, 0.96)
	var alert_color: Color = Color(1.0, 0.22, 0.22, 1.0)
	return base_color.lerp(alert_color, clamp(strength, 0.0, 1.0))

func _warning_track_color(strength: float) -> String:
	var warning_color: Color = Color(1.0, 0.80, 0.24).lerp(Color(1.0, 0.30, 0.30), clamp(strength, 0.0, 1.0))
	return warning_color.to_html(false)

func _hide_boss_banner_later(token: int, hold_time: float) -> void:
	var timer := get_tree().create_timer(hold_time)
	timer.timeout.connect(func() -> void:
		if token != _boss_banner_token:
			return
		if boss_banner_label:
			boss_banner_label.visible = false
	)

func _hide_danger_later(token: int, hold_time: float) -> void:
	var timer := get_tree().create_timer(hold_time)
	timer.timeout.connect(func() -> void:
		if token != _danger_show_token:
			return
		if danger_label:
			danger_label.visible = false
	)

