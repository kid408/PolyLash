extends Panel
class_name SelectionPanel

const ARENA_SCENE_PATH := "res://scenes/arena/arena.tscn"
const MAIN_MENU_SCENE_PATH := "res://scenes/ui/main_menu/main_menu_root.tscn"
const MAX_SELECTED_PLAYERS := 3

const COLOR_BG_BASE := Color("0D1117")
const COLOR_BG_PANEL := Color(0.09, 0.11, 0.13, 0.90)
const COLOR_ACCENT := Color("00F0FF")
const COLOR_WARNING := Color("FF4655")
const COLOR_TEXT_PRIMARY := Color("E6EDF3")
const COLOR_TEXT_SECONDARY := Color("8B949E")
const COLOR_BORDER := Color("30363D")
const COLOR_PANEL_DARK := Color("11161D")

const CLASS_GROUP_ORDER: Array[String] = ["vanguard", "anomaly", "sentinel", "harmony"]
const CLASS_GROUP_TITLES := {
	"vanguard": "【锋芒】",
	"anomaly": "【术理】",
	"sentinel": "【御阵】",
	"harmony": "【协律】",
}
const CLASS_GROUP_SHORT := {
	"vanguard": "锋芒",
	"anomaly": "术理",
	"sentinel": "御阵",
	"harmony": "协律",
}
const CLASS_GROUP_ALIASES := {
	"sentinel": "sentinel",
	"御阵": "sentinel",
	"vanguard": "vanguard",
	"锋芒": "vanguard",
	"mystic": "anomaly",
	"anomaly": "anomaly",
	"术理": "anomaly",
	"harmony": "harmony",
	"协律": "harmony",
}
const DISPLAY_CLASS_BY_PLAYER := {
	"minimalist": "vanguard",
	"arc": "vanguard",
	"collapse": "anomaly",
	"parasite": "anomaly",
	"joule": "sentinel",
	"phalanx": "sentinel",
	"silk": "harmony",
	"overtone": "harmony",
}
const PLAYER_CODE_NAMES := {
	"minimalist": "ZANTETSU",
	"collapse": "COLLAPSAR",
	"parasite": "HEMOMANCER",
	"joule": "JOULE",
	"arc": "ARC",
	"silk": "SILK",
	"overtone": "OVERTONE",
	"phalanx": "PHALANX",
}
const DEFAULT_WEAPON_BY_PLAYER := {
	"minimalist": "sword",
	"collapse": "laser",
	"parasite": "punch",
	"joule": "shotgun",
	"phalanx": "shotgun",
	"silk": "wand",
	"arc": "laser",
	"overtone": "wand",
}
const DEFAULT_DASH_COST_BY_PLAYER := {
	"minimalist": 5.0,
	"collapse": 5.0,
	"parasite": 5.0,
	"joule": 5.0,
	"arc": 5.0,
	"silk": 5.0,
	"overtone": 5.0,
	"phalanx": 5.0,
}
const RADAR_PRESETS := {
	"minimalist": {"burst": 1.0, "control": 0.24},
	"collapse": {"burst": 0.84, "control": 0.92},
	"parasite": {"burst": 0.55, "control": 0.88},
	"joule": {"burst": 0.70, "control": 0.86},
	"arc": {"burst": 0.86, "control": 0.56},
	"silk": {"burst": 0.58, "control": 0.80},
	"overtone": {"burst": 0.62, "control": 0.95},
	"phalanx": {"burst": 0.76, "control": 0.90},
}
const SKILL_ROWS := [
	{"key": "skill_unclosed", "badge": "右键", "title": "未闭合结算"},
	{"key": "skill_closed", "badge": "闭合", "title": "闭合结算"},
	{"key": "skill_e", "badge": "E", "title": "技能 E"},
	{"key": "skill_f", "badge": "F", "title": "技能 F"},
]
const CYAN_TERMS := [
	"灵魂链接", "真实伤害", "绝对霸体", "护盾", "黑洞", "减速", "牵引", "持续伤害",
	"动能墙", "肉体炮弹", "斥力屏障", "动能弹球机", "冲刺", "无敌", "吸附", "击退",
	"爆炸", "回蓝", "焦油线", "地雷", "毒液", "寄生", "鼓面", "音波墙", "闭合圈", "奇点"
]
const WARNING_TERMS := [
	"强制翻倍", "剧烈坍缩", "毁灭性", "秒杀", "绝对无敌", "无法摆脱", "核爆", "撕裂", "肢解"
]

@onready var title_label: Label = $MarginContainer/RootVBox/HeaderRow/HeaderLabel
@onready var subtitle_label: Label = $MarginContainer/RootVBox/HeaderRow/SubHeaderLabel
@onready var left_panel: PanelContainer = $MarginContainer/RootVBox/Body/LeftPanel
@onready var center_panel: PanelContainer = $MarginContainer/RootVBox/Body/CenterPanel
@onready var right_panel: PanelContainer = $MarginContainer/RootVBox/Body/RightPanel
@onready var tab_bar: HBoxContainer = $MarginContainer/RootVBox/Body/LeftPanel/MarginContainer/LeftContent/TabBar
@onready var character_grid: GridContainer = $MarginContainer/RootVBox/Body/LeftPanel/MarginContainer/LeftContent/CharacterScroll/CharacterGrid
@onready var squad_title: Label = $MarginContainer/RootVBox/Body/LeftPanel/MarginContainer/LeftContent/SquadTitle
@onready var squad_hint: Label = $MarginContainer/RootVBox/Body/LeftPanel/MarginContainer/LeftContent/SquadHint
@onready var selected_list: HBoxContainer = $MarginContainer/RootVBox/Body/LeftPanel/MarginContainer/LeftContent/SelectedList
@onready var synergy_title: Label = $MarginContainer/RootVBox/Body/LeftPanel/MarginContainer/LeftContent/SynergyTitle
@onready var synergy_list: VBoxContainer = $MarginContainer/RootVBox/Body/LeftPanel/MarginContainer/LeftContent/SynergyList
@onready var player_ico: TextureRect = $MarginContainer/RootVBox/Body/CenterPanel/MarginContainer/CenterContent/HeroStage/PlayerIco
@onready var portrait_fade: TextureRect = $MarginContainer/RootVBox/Body/CenterPanel/MarginContainer/CenterContent/HeroStage/PortraitFade
@onready var watermark_label: Label = $MarginContainer/RootVBox/Body/CenterPanel/MarginContainer/CenterContent/HeroStage/WatermarkLabel
@onready var player_name_label: Label = $MarginContainer/RootVBox/Body/CenterPanel/MarginContainer/CenterContent/HeroStage/HeroHeader/PlayerName
@onready var player_ties_label: Label = $MarginContainer/RootVBox/Body/CenterPanel/MarginContainer/CenterContent/HeroStage/HeroHeader/PlayerTies
@onready var bond_icons_container: HBoxContainer = $MarginContainer/RootVBox/Body/CenterPanel/MarginContainer/CenterContent/HeroStage/HeroHeader/BondIconsContainer
@onready var player_signature_label: Label = $MarginContainer/RootVBox/Body/CenterPanel/MarginContainer/CenterContent/SignatureBar/SignatureLabel
@onready var radar_chart: SelectionRadarChart = $MarginContainer/RootVBox/Body/CenterPanel/MarginContainer/CenterContent/StatsPanel/MarginContainer/StatsRow/RadarColumn/RadarCenter/RadarChart
@onready var player_description: MarginContainer = $MarginContainer/RootVBox/Body/CenterPanel/MarginContainer/CenterContent/StatsPanel/MarginContainer/StatsRow/StatsColumn/PlayerDescription
@onready var stats_grid: GridContainer = $MarginContainer/RootVBox/Body/CenterPanel/MarginContainer/CenterContent/StatsPanel/MarginContainer/StatsRow/StatsColumn/PlayerDescription/StatsGrid
@onready var experience_title: Label = $MarginContainer/RootVBox/Body/RightPanel/MarginContainer/RightContent/DetailScroll/DetailContent/ExperienceCard/MarginContainer/ExperienceContent/ExperienceTitle
@onready var experience_goal_label: RichTextLabel = $MarginContainer/RootVBox/Body/RightPanel/MarginContainer/RightContent/DetailScroll/DetailContent/ExperienceCard/MarginContainer/ExperienceContent/ExperienceGoal
@onready var skill_title: Label = $MarginContainer/RootVBox/Body/RightPanel/MarginContainer/RightContent/DetailScroll/DetailContent/SkillTitle
@onready var skill_list: VBoxContainer = $MarginContainer/RootVBox/Body/RightPanel/MarginContainer/RightContent/DetailScroll/DetailContent/SkillList
@onready var weapon_title: Label = $MarginContainer/RootVBox/Body/RightPanel/MarginContainer/RightContent/DetailScroll/DetailContent/WeaponTitle
@onready var weapon_container: GridContainer = $MarginContainer/RootVBox/Body/RightPanel/MarginContainer/RightContent/DetailScroll/DetailContent/WeaponContainer
@onready var continue_button: Button = $MarginContainer/RootVBox/Body/RightPanel/MarginContainer/RightContent/ActionBar/Continue
@onready var warehouse_button: Button = $MarginContainer/RootVBox/Body/RightPanel/MarginContainer/RightContent/ActionBar/WarehouseButton
@onready var exit_dialog: ExitConfirmDialog = $ExitConfirmDialog
@onready var hover_timer: Timer = $HoverTimer
@onready var tooltip_panel: PanelContainer = $TooltipPanel
@onready var tooltip_name_label: Label = $TooltipPanel/MarginContainer/TooltipContent/TooltipName
@onready var tooltip_class_label: Label = $TooltipPanel/MarginContainer/TooltipContent/TooltipClass

var _role_entries: Array[Dictionary] = []
var _grouped_roles: Dictionary = {}
var _selected_players: Array[Dictionary] = []
var _preview_player_id := ""
var _preview_weapon_type := ""
var _active_class_group := "vanguard"
var _hovered_player_id := ""
var _player_buttons: Dictionary = {}
var _tab_buttons: Dictionary = {}
var _selected_slot_buttons: Array[SelectedSlotButton] = []
var _player_weapon_cache: Dictionary = {}
var _glow_phase := 0.0
var _stats_label_font: Font
var _stats_value_font: Font

func _ready() -> void:
	_apply_theme()
	_configure_static_texts()
	_connect_signals()
	_load_roles()
	_generate_tabs()
	_generate_selected_slots()
	_rebuild_character_grid()
	_clear_player_info()
	_clear_weapon_cards()
	_restore_previous_selection()
	if _selected_players.is_empty():
		_restore_initial_preview()
	_refresh_synergy_summary()
	_update_continue_button_state()
	set_process(true)

func _process(delta: float) -> void:
	_glow_phase += delta * 3.0
	_update_avatar_glow()
	if tooltip_panel.visible or not _hovered_player_id.is_empty():
		_position_tooltip()

func _apply_theme() -> void:
	add_theme_stylebox_override("panel", _make_panel_style(COLOR_BG_BASE, COLOR_BORDER, 0))
	for panel in [left_panel, center_panel, right_panel]:
		panel.add_theme_stylebox_override("panel", _make_panel_style(COLOR_BG_PANEL, COLOR_BORDER, 14))

	var experience_card: PanelContainer = $MarginContainer/RootVBox/Body/RightPanel/MarginContainer/RightContent/DetailScroll/DetailContent/ExperienceCard
	experience_card.add_theme_stylebox_override("panel", _make_panel_style(COLOR_PANEL_DARK, COLOR_ACCENT, 14, 1, 4))

	var stats_panel: PanelContainer = $MarginContainer/RootVBox/Body/CenterPanel/MarginContainer/CenterContent/StatsPanel
	stats_panel.add_theme_stylebox_override("panel", _make_panel_style(COLOR_PANEL_DARK, COLOR_BORDER, 12))

	var hero_backdrop: PanelContainer = $MarginContainer/RootVBox/Body/CenterPanel/MarginContainer/CenterContent/HeroStage/PortraitBackdrop
	hero_backdrop.add_theme_stylebox_override("panel", _make_panel_style(Color(0.11, 0.14, 0.18, 0.95), COLOR_BORDER, 16))

	var tooltip_style := _make_panel_style(Color(0.05, 0.07, 0.09, 0.95), COLOR_BORDER, 10, 1, 3)
	tooltip_panel.add_theme_stylebox_override("panel", tooltip_style)
	tooltip_panel.visible = false

	var fade_gradient := Gradient.new()
	fade_gradient.offsets = PackedFloat32Array([0.0, 0.65, 1.0])
	fade_gradient.colors = PackedColorArray([
		Color(0.0, 0.0, 0.0, 0.0),
		Color(0.05, 0.07, 0.10, 0.20),
		COLOR_BG_PANEL,
	])
	var fade_texture := GradientTexture1D.new()
	fade_texture.gradient = fade_gradient
	portrait_fade.texture = fade_texture

	radar_chart.set_palette(COLOR_BORDER, COLOR_ACCENT, Color(0.0, 0.94, 1.0, 0.35), COLOR_TEXT_PRIMARY)

	title_label.add_theme_font_size_override("font_size", 36)
	title_label.add_theme_color_override("font_color", COLOR_TEXT_PRIMARY)
	subtitle_label.add_theme_font_size_override("font_size", 14)
	subtitle_label.add_theme_color_override("font_color", COLOR_TEXT_SECONDARY)

	for label in [squad_title, synergy_title, experience_title, skill_title, weapon_title]:
		label.add_theme_font_size_override("font_size", 22)
		label.add_theme_color_override("font_color", COLOR_TEXT_PRIMARY)

	for label in [squad_hint, player_ties_label, tooltip_class_label]:
		label.add_theme_font_size_override("font_size", 14)
		label.add_theme_color_override("font_color", COLOR_TEXT_SECONDARY)

	player_name_label.add_theme_font_size_override("font_size", 30)
	player_name_label.add_theme_color_override("font_color", COLOR_ACCENT)
	watermark_label.add_theme_font_size_override("font_size", 120)
	watermark_label.add_theme_color_override("font_color", Color(0.0, 0.94, 1.0, 0.07))
	player_signature_label.add_theme_font_size_override("font_size", 18)
	player_signature_label.add_theme_color_override("font_color", Color(0.90, 0.93, 0.95, 0.72))
	player_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	player_ties_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	player_signature_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tooltip_name_label.add_theme_font_size_override("font_size", 20)
	tooltip_name_label.add_theme_color_override("font_color", COLOR_TEXT_PRIMARY)

	experience_goal_label.bbcode_enabled = true
	experience_goal_label.fit_content = true
	experience_goal_label.add_theme_font_size_override("normal_font_size", 16)
	experience_goal_label.add_theme_color_override("default_color", COLOR_TEXT_PRIMARY)
	_ensure_stats_fonts()

	_style_action_button(continue_button, COLOR_ACCENT, COLOR_BG_BASE, COLOR_ACCENT)
	_style_action_button(warehouse_button, COLOR_BORDER, COLOR_TEXT_PRIMARY, COLOR_BG_PANEL)

func _configure_static_texts() -> void:
	title_label.text = "角色选择"
	subtitle_label.text = "构建三人小队，确认武器，然后进入正式 Arena 战斗"
	squad_title.text = "战术编队"
	squad_hint.text = "点击头像预览，点击槽位加入小队；也可以直接拖拽头像。"
	synergy_title.text = "职能统计"
	experience_title.text = "体验目标"
	skill_title.text = "机制说明"
	weapon_title.text = "武器选择"
	continue_button.text = "进入战斗"
	warehouse_button.text = "返回主菜单"

func _connect_signals() -> void:
	if not continue_button.pressed.is_connected(_on_continue_pressed):
		continue_button.pressed.connect(_on_continue_pressed)
	if not warehouse_button.pressed.is_connected(_on_back_pressed):
		warehouse_button.pressed.connect(_on_back_pressed)
	if not hover_timer.timeout.is_connected(_on_hover_timer_timeout):
		hover_timer.timeout.connect(_on_hover_timer_timeout)
	if exit_dialog != null:
		if not exit_dialog.confirmed.is_connected(_on_exit_confirmed):
			exit_dialog.confirmed.connect(_on_exit_confirmed)
		if not exit_dialog.cancelled.is_connected(_on_exit_cancelled):
			exit_dialog.cancelled.connect(_on_exit_cancelled)

func _load_roles() -> void:
	_role_entries.clear()
	_grouped_roles.clear()
	for group_key in CLASS_GROUP_ORDER:
		_grouped_roles[group_key] = []

	for config_variant: Dictionary in ConfigManager.get_enabled_players():
		var player_id: String = str(config_variant.get("player_id", "")).strip_edges()
		if player_id.is_empty():
			continue
		var config := config_variant.duplicate(true)
		_role_entries.append(config)
		var group_key := _resolve_config_class_group(config)
		(_grouped_roles[group_key] as Array).append(config)

	_seed_default_weapon_cache()

func _seed_default_weapon_cache() -> void:
	for config: Dictionary in _role_entries:
		var player_id: String = str(config.get("player_id", ""))
		if not _player_weapon_cache.has(player_id):
			_player_weapon_cache[player_id] = _resolve_default_weapon(player_id)

func _generate_tabs() -> void:
	for child in tab_bar.get_children():
		child.queue_free()
	_tab_buttons.clear()

	for group_key in CLASS_GROUP_ORDER:
		var button := Button.new()
		button.focus_mode = Control.FOCUS_NONE
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.custom_minimum_size = Vector2(0, 42)
		button.text = str(CLASS_GROUP_TITLES.get(group_key, group_key))
		button.pressed.connect(_on_class_tab_pressed.bind(group_key))
		tab_bar.add_child(button)
		_tab_buttons[group_key] = button

	_refresh_tab_states()

func _generate_selected_slots() -> void:
	for child in selected_list.get_children():
		child.queue_free()
	_selected_slot_buttons.clear()

	for i in range(MAX_SELECTED_PLAYERS):
		var slot_button := SelectedSlotButton.new()
		slot_button.custom_minimum_size = Vector2(88, 88)
		slot_button.focus_mode = Control.FOCUS_NONE
		slot_button.clip_text = true
		slot_button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		slot_button.expand_icon = true
		slot_button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		slot_button.setup(i)
		slot_button.player_dropped.connect(_on_player_dropped)
		slot_button.remove_requested.connect(_on_selected_slot_remove_requested)
		slot_button.pressed.connect(_on_selected_slot_pressed.bind(i))
		_style_slot_button(slot_button, false)
		selected_list.add_child(slot_button)
		_selected_slot_buttons.append(slot_button)

func _rebuild_character_grid() -> void:
	for child in character_grid.get_children():
		child.queue_free()
	_player_buttons.clear()

	var entries: Array = _grouped_roles.get(_active_class_group, [])
	for config_variant in entries:
		var config: Dictionary = config_variant
		var player_id: String = str(config.get("player_id", ""))
		var button := PlayerSelectButton.new()
		button.custom_minimum_size = Vector2(96, 96)
		button.focus_mode = Control.FOCUS_NONE
		button.text = ""
		button.tooltip_text = ""
		button.setup(player_id, _resolve_default_weapon(player_id))
		button.pressed.connect(_on_player_button_pressed.bind(player_id))
		button.mouse_entered.connect(_on_avatar_mouse_entered.bind(player_id))
		button.mouse_exited.connect(_on_avatar_mouse_exited.bind(player_id))

		var visual_config: Dictionary = ConfigManager.get_player_visual(player_id)
		var sprite_path: String = str(visual_config.get("sprite_path", "")).strip_edges()
		if not sprite_path.is_empty() and ResourceLoader.exists(sprite_path):
			button.icon = load(sprite_path)
		button.expand_icon = true
		button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER

		_style_player_button(button, player_id)
		character_grid.add_child(button)
		_player_buttons[player_id] = button

func _restore_initial_preview() -> void:
	if _role_entries.is_empty():
		return
	_preview_player(str(_role_entries[0].get("player_id", "")))

func _restore_previous_selection() -> void:
	var restored_ids: Array[String] = []
	var restored_weapons: Dictionary = {}

	if not Global.selected_player_ids.is_empty():
		restored_ids = Global.selected_player_ids.duplicate()
		restored_weapons = Global.selected_player_weapons.duplicate(true)
	elif Global.has_method("get_selection_preset"):
		var preset: Dictionary = Global.get_selection_preset()
		var preset_ids_var: Variant = preset.get("player_ids", [])
		if preset_ids_var is Array:
			for raw_id in preset_ids_var:
				var player_id: String = str(raw_id).strip_edges()
				if not player_id.is_empty():
					restored_ids.append(player_id)
		var preset_weapons_var: Variant = preset.get("player_weapons", {})
		if preset_weapons_var is Dictionary:
			restored_weapons = (preset_weapons_var as Dictionary).duplicate(true)

	if restored_ids.is_empty():
		return

	for key in restored_weapons.keys():
		var player_id: String = str(key).strip_edges()
		if not player_id.is_empty():
			_player_weapon_cache[player_id] = str(restored_weapons.get(key, "")).strip_edges()

	_selected_players.clear()
	var slot_index := 0
	for player_id in restored_ids:
		if slot_index >= MAX_SELECTED_PLAYERS:
			break
		if ConfigManager.get_player_config(player_id).is_empty():
			continue
		_selected_players.append({
			"player_id": player_id,
			"slot_index": slot_index,
			"weapon_type": str(_player_weapon_cache.get(player_id, _resolve_default_weapon(player_id))),
		})
		slot_index += 1

	_sort_selected_players()
	_refresh_all_selected_slots()
	if not _selected_players.is_empty():
		_preview_player(str(_selected_players[0].get("player_id", "")))
	else:
		_refresh_player_button_states()

func _preview_player(player_id: String) -> void:
	var config := ConfigManager.get_player_config(player_id)
	if config.is_empty():
		_clear_player_info()
		return

	_preview_player_id = player_id
	_preview_weapon_type = str(_player_weapon_cache.get(player_id, _resolve_default_weapon(player_id)))
	var target_group := _resolve_config_class_group(config)
	if target_group != _active_class_group:
		_active_class_group = target_group
		_refresh_tab_states()
		_rebuild_character_grid()

	var visual_config := ConfigManager.get_player_visual(player_id)
	var portrait_path: String = str(config.get("portrait_sprite_path", "")).strip_edges()
	var sprite_path: String = portrait_path if (not portrait_path.is_empty() and ResourceLoader.exists(portrait_path)) else str(visual_config.get("sprite_path", "")).strip_edges()
	player_ico.texture = load(sprite_path) if (not sprite_path.is_empty() and ResourceLoader.exists(sprite_path)) else null

	player_name_label.text = _get_player_display_name(player_id)
	watermark_label.text = "%s  %s" % [_get_player_display_name(player_id), str(PLAYER_CODE_NAMES.get(player_id, player_id.to_upper()))]
	player_ties_label.text = _build_ties_text(config)
	player_signature_label.text = "// %s //" % _get_player_intro_value(player_id, "signature", "等待一条新的战场轨迹。")
	_refresh_bond_icons(config)
	_populate_stats_list(config)
	experience_goal_label.text = _semantic_highlight(_get_player_intro_value(player_id, "experience_goal", str(config.get("description", ""))))
	_rebuild_skill_cards(player_id)
	radar_chart.set_values(_build_radar_values(config, player_id))

	_refresh_weapon_cards(player_id)
	_refresh_player_button_states()

func _build_ties_text(config: Dictionary) -> String:
	var origin_name := _resolve_bond_name(str(config.get("origin_tag", "")))
	var mastery_name := _resolve_bond_name(str(config.get("mastery_tag", "")))
	var tactic_name := _resolve_bond_name(str(config.get("tactic_tag", "")))
	return "%s / %s / %s" % [origin_name, mastery_name, tactic_name]

func _resolve_bond_name(tag: String) -> String:
	if tag.is_empty():
		return "-"
	if BondUILoader != null and BondUILoader.has_method("get_bond_display_name"):
		return str(BondUILoader.get_bond_display_name(tag))
	return tag

func _refresh_bond_icons(config: Dictionary) -> void:
	for child in bond_icons_container.get_children():
		child.queue_free()
	if BondUILoader == null:
		return
	var team_player_ids: Array[String] = []
	for entry in _selected_players:
		team_player_ids.append(str(entry.get("player_id", "")))
	BondUILoader.update_bond_icons(
		bond_icons_container,
		str(config.get("origin_tag", "")),
		str(config.get("mastery_tag", "")),
		str(config.get("tactic_tag", "")),
		team_player_ids
	)

func _populate_stats_list(config: Dictionary) -> void:
	_clear_stats_list()
	var player_id := str(config.get("player_id", ""))
	var stat_rows: Array[Array] = [
		["生命值", str(int(config.get("health", 0)))],
		["生命恢复 / 秒", _format_number(config.get("health_regen", 0.0))],
		["最大护甲", str(int(config.get("max_armor", 0)))],
		["移动速度", str(int(config.get("base_speed", 0)))],
		["最大能量", str(int(config.get("max_energy", 0)))],
		["初始能量", str(int(config.get("initial_energy", 0)))],
		["能量恢复 / 秒", _format_number(config.get("energy_regen", 0.0))],
		["拒止(Q)消耗", _format_number(config.get("skill_q_cost", 0.0))],
		["冲刺(Dash)消耗", _format_number(_get_player_dash_cost(player_id))],
		["技能(E)消耗", _format_number(config.get("skill_e_cost", 0.0))],
		["终极技(F)消耗", _format_number(_get_player_f_cost(player_id))],
	]
	for row_data in stat_rows:
		_add_stat_row(str(row_data[0]), str(row_data[1]))

func _clear_stats_list() -> void:
	for child in stats_grid.get_children():
		child.queue_free()

func _populate_stats_placeholder() -> void:
	_clear_stats_list()
	var placeholder_rows := [
		"生命值",
		"生命恢复 / 秒",
		"最大护甲",
		"移动速度",
		"最大能量",
		"初始能量",
		"能量恢复 / 秒",
		"拒止(Q)消耗",
		"冲刺(Dash)消耗",
		"技能(E)消耗",
		"终极技(F)消耗",
	]
	for label_text in placeholder_rows:
		_add_stat_row(str(label_text), "--")

func _add_stat_row(label_text: String, value_text: String) -> void:
	var label := Label.new()
	label.size_flags_horizontal = 1
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	label.text = label_text
	label.add_theme_font_override("font", _stats_label_font)
	label.add_theme_font_size_override("font_size", 16)
	label.add_theme_color_override("font_color", COLOR_TEXT_SECONDARY)
	label.add_theme_constant_override("outline_size", 0)
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0))
	stats_grid.add_child(label)

	var value := Label.new()
	value.size_flags_horizontal = 1
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	value.text = value_text
	value.add_theme_font_override("font", _stats_value_font)
	value.add_theme_font_size_override("font_size", 16)
	value.add_theme_color_override("font_color", COLOR_TEXT_PRIMARY)
	value.add_theme_constant_override("outline_size", 0)
	value.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0))
	stats_grid.add_child(value)

func _get_player_dash_cost(player_id: String) -> float:
	if player_id.is_empty():
		return 5.0
	return float(DEFAULT_DASH_COST_BY_PLAYER.get(player_id, 5.0))

func _get_player_f_cost(player_id: String) -> float:
	if player_id.is_empty():
		return 0.0
	var ult_config := ConfigManager.get_player_ult_config(player_id)
	if ult_config.is_empty():
		return 0.0
	return float(ult_config.get("energy_cost", 0.0))

func _ensure_stats_fonts() -> void:
	if _stats_label_font != null and _stats_value_font != null:
		return

	var label_font := SystemFont.new()
	label_font.font_names = PackedStringArray([
		"Noto Sans SC",
		"Source Han Sans SC",
		"Microsoft YaHei UI",
		"Microsoft YaHei",
		"Segoe UI",
		"Arial",
	])
	label_font.font_weight = 400
	_stats_label_font = label_font

	var value_font := SystemFont.new()
	value_font.font_names = PackedStringArray([
		"Roboto Mono",
		"Consolas",
		"DIN Alternate",
		"Bahnschrift",
		"Noto Sans SC",
		"Microsoft YaHei UI",
	])
	value_font.font_weight = 600
	_stats_value_font = value_font

func _rebuild_skill_cards(player_id: String) -> void:
	for child in skill_list.get_children():
		child.queue_free()

	for row in SKILL_ROWS:
		var card := PanelContainer.new()
		card.add_theme_stylebox_override("panel", _make_panel_style(COLOR_PANEL_DARK, COLOR_BORDER, 12))
		card.custom_minimum_size = Vector2(0, 110)

		var margin := MarginContainer.new()
		margin.add_theme_constant_override("margin_left", 14)
		margin.add_theme_constant_override("margin_top", 14)
		margin.add_theme_constant_override("margin_right", 14)
		margin.add_theme_constant_override("margin_bottom", 14)
		card.add_child(margin)

		var row_box := HBoxContainer.new()
		row_box.add_theme_constant_override("separation", 12)
		margin.add_child(row_box)

		var badge_panel := PanelContainer.new()
		badge_panel.custom_minimum_size = Vector2(52, 52)
		badge_panel.add_theme_stylebox_override("panel", _make_panel_style(COLOR_ACCENT, COLOR_ACCENT, 8))
		row_box.add_child(badge_panel)

		var badge := Label.new()
		badge.text = str(row.get("badge", ""))
		badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		badge.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		badge.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		badge.size_flags_vertical = Control.SIZE_EXPAND_FILL
		badge.add_theme_font_size_override("font_size", 18)
		badge.add_theme_color_override("font_color", COLOR_BG_BASE)
		badge_panel.add_child(badge)

		var text_box := VBoxContainer.new()
		text_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		text_box.add_theme_constant_override("separation", 6)
		row_box.add_child(text_box)

		var title := Label.new()
		title.text = str(row.get("title", ""))
		title.add_theme_font_size_override("font_size", 18)
		title.add_theme_color_override("font_color", COLOR_TEXT_PRIMARY)
		text_box.add_child(title)

		var body := RichTextLabel.new()
		body.bbcode_enabled = true
		body.fit_content = true
		body.scroll_active = false
		body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		body.add_theme_font_size_override("normal_font_size", 15)
		body.add_theme_color_override("default_color", COLOR_TEXT_PRIMARY)
		body.text = _semantic_highlight(_get_player_intro_value(player_id, str(row.get("key", "")), "暂无说明"))
		text_box.add_child(body)

		skill_list.add_child(card)

func _refresh_weapon_cards(player_id: String) -> void:
	_clear_weapon_cards()
	var weapon_types: Array[String] = ConfigManager.get_player_available_weapon_types(player_id)
	var selected_weapon: String = str(_player_weapon_cache.get(player_id, _resolve_default_weapon(player_id)))

	if weapon_types.is_empty():
		var empty_label := Label.new()
		empty_label.text = "当前角色未配置武器。"
		empty_label.add_theme_color_override("font_color", COLOR_TEXT_SECONDARY)
		weapon_container.add_child(empty_label)
		return

	weapon_container.columns = mini(3, max(1, weapon_types.size()))
	for weapon_type in weapon_types:
		var weapon_config := ConfigManager.get_weapon_by_type_level(weapon_type, 1)
		var card := Button.new()
		card.custom_minimum_size = Vector2(120, 96)
		card.focus_mode = Control.FOCUS_NONE
		card.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		card.text = ""
		card.tooltip_text = _get_weapon_display_name(weapon_type)
		card.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		card.expand_icon = true
		card.pressed.connect(_on_weapon_selected.bind(player_id, weapon_type))

		var icon_path: String = str(weapon_config.get("icon_path_template", "")).strip_edges()
		if not icon_path.is_empty() and ResourceLoader.exists(icon_path):
			card.icon = load(icon_path)

		_style_weapon_card(card, weapon_type == selected_weapon)
		weapon_container.add_child(card)

func _clear_weapon_cards() -> void:
	for child in weapon_container.get_children():
		child.queue_free()

func _resolve_default_weapon(player_id: String) -> String:
	var cached: String = str(_player_weapon_cache.get(player_id, "")).strip_edges()
	if not cached.is_empty():
		return cached

	var preferred: String = str(DEFAULT_WEAPON_BY_PLAYER.get(player_id, "")).strip_edges()
	var weapon_types: Array[String] = ConfigManager.get_player_available_weapon_types(player_id)
	if not preferred.is_empty() and weapon_types.has(preferred):
		return preferred
	if not weapon_types.is_empty():
		return weapon_types[0]
	return preferred

func _get_weapon_display_name(weapon_type: String) -> String:
	var weapon_config := ConfigManager.get_weapon_by_type_level(weapon_type, 1)
	var template: String = str(weapon_config.get("display_name_template", "")).strip_edges()
	if not template.is_empty():
		return template.replace("%d", "").replace("(级)", "").replace("（级）", "").strip_edges()
	return weapon_type

func _on_weapon_selected(player_id: String, weapon_type: String) -> void:
	_player_weapon_cache[player_id] = weapon_type
	if player_id == _preview_player_id:
		_preview_weapon_type = weapon_type
		_refresh_weapon_cards(player_id)
	for i in range(_selected_players.size()):
		if str(_selected_players[i].get("player_id", "")) == player_id:
			_selected_players[i]["weapon_type"] = weapon_type
	_refresh_all_selected_slots()
	_persist_current_selection()

func _on_player_button_pressed(player_id: String) -> void:
	_preview_player(player_id)

func _on_class_tab_pressed(group_key: String) -> void:
	if _active_class_group == group_key:
		return
	_active_class_group = group_key
	_refresh_tab_states()
	_rebuild_character_grid()
	_refresh_player_button_states()

func is_player_selected(player_id: String) -> bool:
	for entry in _selected_players:
		if str(entry.get("player_id", "")) == player_id:
			return true
	return false

func _find_selected_player_index(player_id: String) -> int:
	for i in range(_selected_players.size()):
		if str(_selected_players[i].get("player_id", "")) == player_id:
			return i
	return -1

func _find_selected_slot_index(slot_index: int) -> int:
	for i in range(_selected_players.size()):
		if int(_selected_players[i].get("slot_index", -1)) == slot_index:
			return i
	return -1

func _sort_selected_players() -> void:
	_selected_players.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a.get("slot_index", 0)) < int(b.get("slot_index", 0))
	)

func _on_selected_slot_pressed(slot_index: int) -> void:
	var occupied_index: int = _find_selected_slot_index(slot_index)
	if occupied_index >= 0:
		_preview_player(str(_selected_players[occupied_index].get("player_id", "")))
		return
	if not _preview_player_id.is_empty():
		_add_player_to_selected(_preview_player_id, slot_index)

func _on_selected_slot_remove_requested(slot_index: int) -> void:
	var occupied_index: int = _find_selected_slot_index(slot_index)
	if occupied_index >= 0:
		_remove_player_from_selected(occupied_index)

func _on_player_dropped(slot_index: int, player_id: String, weapon_type: String) -> void:
	_player_weapon_cache[player_id] = weapon_type if not weapon_type.is_empty() else _resolve_default_weapon(player_id)
	_add_player_to_selected(player_id, slot_index)
	_preview_player(player_id)

func _add_player_to_selected(player_id: String, slot_index: int = 0) -> void:
	if player_id.is_empty():
		return
	slot_index = clampi(slot_index, 0, MAX_SELECTED_PLAYERS - 1)

	var existing_player_index: int = _find_selected_player_index(player_id)
	if existing_player_index >= 0:
		_selected_players[existing_player_index]["slot_index"] = slot_index
		_selected_players[existing_player_index]["weapon_type"] = str(_player_weapon_cache.get(player_id, _resolve_default_weapon(player_id)))
	else:
		var existing_slot_index: int = _find_selected_slot_index(slot_index)
		if existing_slot_index >= 0:
			_selected_players.remove_at(existing_slot_index)
		elif _selected_players.size() >= MAX_SELECTED_PLAYERS:
			return

		_selected_players.append({
			"player_id": player_id,
			"slot_index": slot_index,
			"weapon_type": str(_player_weapon_cache.get(player_id, _resolve_default_weapon(player_id))),
		})

	_sort_selected_players()
	_refresh_all_selected_slots()
	_refresh_player_button_states()
	_refresh_synergy_summary()
	_update_continue_button_state()
	_persist_current_selection()

func _remove_player_from_selected(index: int) -> void:
	if index < 0 or index >= _selected_players.size():
		return
	_selected_players.remove_at(index)
	_sort_selected_players()
	_refresh_all_selected_slots()
	_refresh_player_button_states()
	_refresh_synergy_summary()
	_update_continue_button_state()
	_persist_current_selection()

func _refresh_all_selected_slots() -> void:
	for i in range(_selected_slot_buttons.size()):
		_clear_selected_slot_display(i)
	for entry in _selected_players:
		_update_selected_slot_display(int(entry.get("slot_index", 0)), str(entry.get("player_id", "")))

func _update_selected_slot_display(slot_index: int, player_id: String) -> void:
	if slot_index < 0 or slot_index >= _selected_slot_buttons.size():
		return
	var btn := _selected_slot_buttons[slot_index]
	var visual_config := ConfigManager.get_player_visual(player_id)
	btn.text = ""
	btn.tooltip_text = "%s | 武器: %s" % [_get_player_display_name(player_id), _get_weapon_display_name(str(_player_weapon_cache.get(player_id, "")))]
	var sprite_path: String = str(visual_config.get("sprite_path", "")).strip_edges()
	btn.icon = load(sprite_path) if (not sprite_path.is_empty() and ResourceLoader.exists(sprite_path)) else null
	_style_slot_button(btn, true)

func _clear_selected_slot_display(slot_index: int) -> void:
	if slot_index < 0 or slot_index >= _selected_slot_buttons.size():
		return
	var btn := _selected_slot_buttons[slot_index]
	btn.text = ""
	btn.icon = null
	btn.tooltip_text = "点击当前槽位，放入正在预览的角色。"
	_style_slot_button(btn, false)

func _refresh_player_button_states() -> void:
	for player_id in _player_buttons.keys():
		_style_player_button(_player_buttons[player_id], str(player_id))

func _refresh_tab_states() -> void:
	for group_key in _tab_buttons.keys():
		var button: Button = _tab_buttons[group_key]
		var active := str(group_key) == _active_class_group
		var style := _make_panel_style(Color(0, 0, 0, 0), COLOR_ACCENT if active else Color(0, 0, 0, 0), 0, 0)
		style.border_width_bottom = 2 if active else 0
		button.add_theme_stylebox_override("normal", style)
		button.add_theme_stylebox_override("hover", style)
		button.add_theme_stylebox_override("pressed", style)
		button.add_theme_font_size_override("font_size", 18)
		button.add_theme_color_override("font_color", COLOR_ACCENT if active else COLOR_TEXT_SECONDARY)

func _refresh_synergy_summary() -> void:
	for child in synergy_list.get_children():
		child.queue_free()

	if _selected_players.is_empty():
		var empty_label := Label.new()
		empty_label.text = "当前未编入角色"
		empty_label.add_theme_color_override("font_color", COLOR_TEXT_SECONDARY)
		synergy_list.add_child(empty_label)
		return

	var counts := {}
	for group_key in CLASS_GROUP_ORDER:
		counts[group_key] = 0

	for entry in _selected_players:
		var config := ConfigManager.get_player_config(str(entry.get("player_id", "")))
		var group_key := _resolve_config_class_group(config)
		counts[group_key] = int(counts.get(group_key, 0)) + 1

	for group_key in CLASS_GROUP_ORDER:
		var label := Label.new()
		label.text = "%s  %d/%d" % [CLASS_GROUP_TITLES[group_key], int(counts[group_key]), MAX_SELECTED_PLAYERS]
		label.add_theme_font_size_override("font_size", 16)
		label.add_theme_color_override("font_color", COLOR_TEXT_PRIMARY if int(counts[group_key]) > 0 else COLOR_TEXT_SECONDARY)
		synergy_list.add_child(label)

func _resolve_class_group(raw_tag: String) -> String:
	var tag: String = raw_tag.strip_edges()
	if CLASS_GROUP_ALIASES.has(tag):
		return str(CLASS_GROUP_ALIASES[tag])
	return "sentinel"

func _resolve_config_class_group(config: Dictionary) -> String:
	var player_id: String = str(config.get("player_id", "")).strip_edges()
	if DISPLAY_CLASS_BY_PLAYER.has(player_id):
		return str(DISPLAY_CLASS_BY_PLAYER[player_id])
	return _resolve_class_group(str(config.get("mastery_tag", "")))

func _update_continue_button_state() -> void:
	continue_button.disabled = _selected_players.is_empty() and _preview_player_id.is_empty()

func _clear_player_info() -> void:
	player_ico.texture = null
	player_name_label.text = "选择角色"
	watermark_label.text = "SELECT  OPERATIVE"
	player_ties_label.text = ""
	player_signature_label.text = "// 在左侧切换职能标签，并悬停头像查看角色信息。 //"
	for child in bond_icons_container.get_children():
		child.queue_free()
	_populate_stats_placeholder()
	experience_goal_label.text = "选择角色后，这里会显示该角色的体验目标与战斗定位。"
	for child in skill_list.get_children():
		child.queue_free()
	radar_chart.set_values([0.5, 0.5, 0.5, 0.5, 0.5, 0.5])

func _on_continue_pressed() -> void:
	if _selected_players.is_empty() and not _preview_player_id.is_empty():
		_add_player_to_selected(_preview_player_id, 0)
	if _selected_players.is_empty():
		return

	_sort_selected_players()
	var player_ids: Array[String] = []
	var player_weapons: Dictionary = {}
	for entry in _selected_players:
		var player_id: String = str(entry.get("player_id", ""))
		player_ids.append(player_id)
		player_weapons[player_id] = str(entry.get("weapon_type", _resolve_default_weapon(player_id)))

	if Global.has_method("save_selection_preset"):
		Global.save_selection_preset(player_ids, player_weapons, player_ids[0] if not player_ids.is_empty() else "")
	Global.reset_selection()
	Global.selected_player_ids = player_ids
	Global.leader_player_id = player_ids[0] if not player_ids.is_empty() else ""
	Global.current_player_index = 0
	Global.selected_player_weapons = player_weapons
	get_tree().change_scene_to_file(ARENA_SCENE_PATH)

func _on_back_pressed() -> void:
	if exit_dialog != null:
		exit_dialog.show_dialog("返回主菜单？")
	else:
		get_tree().change_scene_to_file(MAIN_MENU_SCENE_PATH)

func _on_exit_confirmed() -> void:
	if not _selected_players.is_empty() and Global.has_method("save_selection_preset"):
		_sort_selected_players()
		var player_ids: Array[String] = []
		var player_weapons: Dictionary = {}
		for entry in _selected_players:
			var player_id: String = str(entry.get("player_id", ""))
			player_ids.append(player_id)
			player_weapons[player_id] = str(entry.get("weapon_type", _resolve_default_weapon(player_id)))
		Global.save_selection_preset(player_ids, player_weapons, player_ids[0] if not player_ids.is_empty() else "")
	Global.reset_selection()
	get_tree().change_scene_to_file(MAIN_MENU_SCENE_PATH)

func _persist_current_selection() -> void:
	if not Global.has_method("save_selection_preset"):
		return
	_sort_selected_players()
	var player_ids: Array[String] = []
	var player_weapons: Dictionary = {}
	for entry in _selected_players:
		var player_id: String = str(entry.get("player_id", "")).strip_edges()
		if player_id.is_empty():
			continue
		player_ids.append(player_id)
		player_weapons[player_id] = str(entry.get("weapon_type", _resolve_default_weapon(player_id))).strip_edges()
	Global.save_selection_preset(player_ids, player_weapons, player_ids[0] if not player_ids.is_empty() else "")

func _on_exit_cancelled() -> void:
	pass

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_on_back_pressed()
		get_viewport().set_input_as_handled()

func _on_avatar_mouse_entered(player_id: String) -> void:
	_hovered_player_id = player_id
	hover_timer.start()

func _on_avatar_mouse_exited(player_id: String) -> void:
	if _hovered_player_id == player_id:
		_hovered_player_id = ""
	hover_timer.stop()
	_hide_tooltip()

func _on_hover_timer_timeout() -> void:
	if _hovered_player_id.is_empty():
		return
	_show_tooltip(_hovered_player_id)

func _show_tooltip(player_id: String) -> void:
	var config := ConfigManager.get_player_config(player_id)
	tooltip_name_label.text = _get_player_display_name(player_id)
	tooltip_class_label.text = str(CLASS_GROUP_SHORT.get(_resolve_config_class_group(config), "未知职能"))
	tooltip_panel.modulate.a = 0.0
	tooltip_panel.visible = true
	_position_tooltip()
	var tween := create_tween()
	tween.tween_property(tooltip_panel, "modulate:a", 1.0, 0.12)

func _hide_tooltip() -> void:
	tooltip_panel.visible = false

func _position_tooltip() -> void:
	if not tooltip_panel.visible and _hovered_player_id.is_empty():
		return
	var mouse_pos: Vector2 = get_viewport().get_mouse_position() + Vector2(15, 15)
	var panel_size: Vector2 = tooltip_panel.size if tooltip_panel.size != Vector2.ZERO else tooltip_panel.get_combined_minimum_size()
	var viewport_rect: Rect2 = get_viewport_rect()
	var pos := mouse_pos
	if pos.x + panel_size.x > viewport_rect.size.x - 12.0:
		pos.x = viewport_rect.size.x - panel_size.x - 12.0
	if pos.y + panel_size.y > viewport_rect.size.y - 12.0:
		pos.y = viewport_rect.size.y - panel_size.y - 12.0
	tooltip_panel.position = pos

func _get_player_display_name(player_id: String) -> String:
	return _get_player_intro_value(player_id, "display_name", str(ConfigManager.get_player_config(player_id).get("display_name", player_id)))

func _get_player_intro_value(player_id: String, key: String, fallback: String = "") -> String:
	var intro := ConfigManager.get_player_intro(player_id)
	return str(intro.get(key, fallback)).strip_edges()

func _build_radar_values(config: Dictionary, player_id: String) -> Array:
	var health_score := clampf(inverse_lerp(100.0, 260.0, float(config.get("health", 100.0))), 0.0, 1.0)
	var speed_score := clampf(inverse_lerp(260.0, 520.0, float(config.get("base_speed", 260.0))), 0.0, 1.0)
	var energy_score := clampf(inverse_lerp(100.0, 220.0, float(config.get("max_energy", 100.0))), 0.0, 1.0)
	var regen_score := clampf(inverse_lerp(0.8, 18.0, float(config.get("energy_regen", 0.8))), 0.0, 1.0)
	var preset: Dictionary = RADAR_PRESETS.get(player_id, {"burst": 0.6, "control": 0.6})
	return [
		health_score,
		speed_score,
		energy_score,
		regen_score,
		float(preset.get("burst", 0.6)),
		float(preset.get("control", 0.6)),
	]

func _semantic_highlight(text: String) -> String:
	var result := text
	result = _highlight_action_tokens(result)
	result = _highlight_numeric_tokens(result)
	for term in CYAN_TERMS:
		result = result.replace(term, "[color=#00F0FF]%s[/color]" % term)
	for term in WARNING_TERMS:
		result = result.replace(term, "[color=#FF4655]%s[/color]" % term)
	return result

func _highlight_action_tokens(text: String) -> String:
	var result := text
	var replacements := {
		"右键": "[b][color=#E6EDF3][右键][/color][/b]",
		"左键": "[b][color=#E6EDF3][左键][/color][/b]",
		"Dash": "[b][color=#E6EDF3][Dash][/color][/b]",
		"Space": "[b][color=#E6EDF3][Space][/color][/b]",
		"Q": "[b][color=#E6EDF3][Q][/color][/b]",
		"E": "[b][color=#E6EDF3][E][/color][/b]",
		"F": "[b][color=#E6EDF3][F][/color][/b]",
	}
	for key in replacements.keys():
		result = result.replace(key, str(replacements[key]))
	return result

func _highlight_numeric_tokens(text: String) -> String:
	var regex := RegEx.new()
	regex.compile("(\\d+(?:\\.\\d+)?%|\\d+(?:\\.\\d+)?px|\\d+(?:\\.\\d+)?s|\\d+(?:\\.\\d+)?)")
	var matches := regex.search_all(text)
	var result := text
	for i in range(matches.size() - 1, -1, -1):
		var m: RegExMatch = matches[i]
		var value := m.get_string()
		result = result.substr(0, m.get_start()) + "[color=#00F0FF]%s[/color]" % value + result.substr(m.get_end())
	return result

func _make_panel_style(bg_color: Color, border_color: Color, radius: int, border_width: int = 1, left_border_width: int = -1) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg_color
	style.set_corner_radius_all(radius)
	style.set_border_width_all(border_width)
	style.border_color = border_color
	if left_border_width >= 0:
		style.border_width_left = left_border_width
	return style

func _style_action_button(button: Button, border_color: Color, font_color: Color, bg_color: Color) -> void:
	button.add_theme_font_size_override("font_size", 20)
	button.add_theme_color_override("font_color", font_color)
	var normal := _make_panel_style(bg_color, border_color, 12, 2)
	var hover := _make_panel_style(bg_color.lightened(0.08), border_color, 12, 2)
	var pressed := _make_panel_style(bg_color.darkened(0.08), border_color, 12, 2)
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", pressed)
	button.add_theme_stylebox_override("disabled", _make_panel_style(Color(0.12, 0.12, 0.12, 0.7), COLOR_BORDER, 12, 2))

func _style_player_button(button: Button, player_id: String) -> void:
	var is_focus := player_id == _preview_player_id
	var is_selected := is_player_selected(player_id)
	var alpha := 0.7
	var border_width := 1
	var border_color := COLOR_BORDER
	if is_selected:
		alpha = 1.0
		border_width = 2
		border_color = COLOR_ACCENT
	elif is_focus:
		alpha = 0.92
		border_width = 1
		border_color = COLOR_TEXT_SECONDARY
	var style := _make_panel_style(Color(0.08, 0.10, 0.12, alpha), border_color, 12, border_width)
	button.add_theme_stylebox_override("normal", style)
	button.add_theme_stylebox_override("hover", _make_panel_style(Color(0.10, 0.13, 0.16, min(1.0, alpha + 0.12)), border_color, 12, border_width))
	button.add_theme_stylebox_override("pressed", _make_panel_style(Color(0.06, 0.08, 0.10, 1.0), border_color, 12, border_width))
	button.modulate = Color(1.0, 1.0, 1.0, alpha)

func _update_avatar_glow() -> void:
	for player_id in _player_buttons.keys():
		var button: Button = _player_buttons[player_id]
		if str(player_id) == _preview_player_id:
			var pulse := 0.88 + 0.12 * ((sin(_glow_phase) + 1.0) * 0.5)
			button.self_modulate = Color(1.0, 1.0, 1.0, pulse)
		else:
			button.self_modulate = Color.WHITE

func _style_slot_button(button: Button, occupied: bool) -> void:
	var bg_color := Color(0.08, 0.10, 0.12, 1.0) if not occupied else Color(0.05, 0.16, 0.18, 1.0)
	var border_color := COLOR_BORDER if not occupied else COLOR_ACCENT
	var font_color := COLOR_TEXT_SECONDARY if not occupied else COLOR_TEXT_PRIMARY
	button.add_theme_stylebox_override("normal", _make_panel_style(bg_color, border_color, 12, 2))
	button.add_theme_stylebox_override("hover", _make_panel_style(bg_color.lightened(0.05), border_color, 12, 2))
	button.add_theme_stylebox_override("pressed", _make_panel_style(bg_color.darkened(0.05), border_color, 12, 2))
	button.add_theme_color_override("font_color", font_color)
	button.add_theme_font_size_override("font_size", 18)

func _style_weapon_card(button: Button, is_selected: bool) -> void:
	var bg_color := Color(0.08, 0.10, 0.12, 1.0)
	var border_color := COLOR_BORDER
	if is_selected:
		bg_color = Color(0.18, 0.14, 0.08, 1.0)
		border_color = Color(0.95, 0.84, 0.43, 1.0)
	button.add_theme_stylebox_override("normal", _make_panel_style(bg_color, border_color, 12, 2))
	button.add_theme_stylebox_override("hover", _make_panel_style(bg_color.lightened(0.05), border_color, 12, 2))
	button.add_theme_stylebox_override("pressed", _make_panel_style(bg_color.darkened(0.05), border_color, 12, 2))
	button.add_theme_color_override("font_color", COLOR_TEXT_PRIMARY)
	button.add_theme_font_size_override("font_size", 15)

func _format_number(value: Variant) -> String:
	if value is int:
		return str(value)
	var float_value := float(value)
	if is_equal_approx(float_value, round(float_value)):
		return str(int(round(float_value)))
	return "%.1f" % float_value
