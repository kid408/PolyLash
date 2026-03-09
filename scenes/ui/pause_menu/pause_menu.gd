extends CanvasLayer
class_name PauseMenu

signal resume_requested
signal restart_requested
signal end_run_requested
signal codex_requested
signal settings_requested
signal return_to_menu_requested

const BASE_RESOLUTION := Vector2(1920, 1080)
const MIN_UI_SCALE := 0.72
const MAX_UI_SCALE := 1.10

@onready var panel: Panel = $Panel
@onready var root_hbox: HBoxContainer = $Panel/HBoxContainer
@onready var menu_container: VBoxContainer = $Panel/HBoxContainer/MenuContainer
@onready var status_container: VBoxContainer = $Panel/HBoxContainer/StatusContainer
@onready var stats_container: Panel = $Panel/HBoxContainer/StatsContainer

@onready var continue_button: Button = $Panel/HBoxContainer/MenuContainer/ContinueButton
@onready var restart_button: Button = $Panel/HBoxContainer/MenuContainer/RestartButton
@onready var end_run_button: Button = $Panel/HBoxContainer/MenuContainer/EndRunButton
@onready var codex_button: Button = $Panel/HBoxContainer/MenuContainer/CodexButton
@onready var settings_button: Button = $Panel/HBoxContainer/MenuContainer/SettingsButton
@onready var main_menu_button: Button = $Panel/HBoxContainer/MenuContainer/MainMenuButton

@onready var weapon_label: Label = $Panel/HBoxContainer/StatusContainer/WeaponLabel
@onready var weapon_icon: TextureRect = $Panel/HBoxContainer/StatusContainer/WeaponIcon
@onready var item_label: Label = $Panel/HBoxContainer/StatusContainer/ItemLabel
@onready var item_icon: TextureRect = $Panel/HBoxContainer/StatusContainer/ItemIcon
@onready var wave_label: Label = $Panel/HBoxContainer/StatusContainer/WaveLabel

@onready var stats_title: Label = $Panel/HBoxContainer/StatsContainer/StatsTitle
@onready var main_tab: Button = $Panel/HBoxContainer/StatsContainer/TabRow/MainTab
@onready var sub_tab: Button = $Panel/HBoxContainer/StatsContainer/TabRow/SubTab
@onready var stats_list: VBoxContainer = $Panel/HBoxContainer/StatsContainer/StatsList

@onready var run_info_label: Label = $Panel/BottomArea/RunInfoLabel
@onready var dot_before: Label = $Panel/BottomArea/WaveProgress/DotBefore
@onready var dot_current: Label = $Panel/BottomArea/WaveProgress/DotCurrent
@onready var dot_after: Label = $Panel/BottomArea/WaveProgress/DotAfter
@onready var mark_5: Label = $Panel/BottomArea/WaveNumberRow/Mark5
@onready var mark_10: Label = $Panel/BottomArea/WaveNumberRow/Mark10
@onready var mark_15: Label = $Panel/BottomArea/WaveNumberRow/Mark15
@onready var mark_20: Label = $Panel/BottomArea/WaveNumberRow/Mark20

var is_visible_menu: bool = false
var _ui_scale: float = 1.0
var _menu_buttons: Array[Button] = []

func _ready() -> void:
	process_mode = PROCESS_MODE_ALWAYS

	continue_button.pressed.connect(_on_continue_pressed)
	restart_button.pressed.connect(_on_restart_pressed)
	end_run_button.pressed.connect(_on_end_run_pressed)
	codex_button.pressed.connect(_on_codex_pressed)
	settings_button.pressed.connect(_on_settings_pressed)
	main_menu_button.pressed.connect(_on_main_menu_pressed)

	_menu_buttons = [
		continue_button,
		restart_button,
		end_run_button,
		codex_button,
		settings_button,
		main_menu_button,
	]

	var vp: Viewport = get_viewport()
	if vp and not vp.size_changed.is_connected(_on_viewport_size_changed):
		vp.size_changed.connect(_on_viewport_size_changed)

	_apply_responsive_layout()
	hide()

func _on_viewport_size_changed() -> void:
	_apply_responsive_layout()
	if is_visible_menu:
		_update_stats_display()

func show_menu() -> void:
	if is_visible_menu:
		return

	_apply_responsive_layout()
	_update_status_display()
	_update_stats_display()

	show()
	is_visible_menu = true
	PauseService.request_pause("pause_menu", get_tree())
	SoundManager.play("ui_pause")

func hide_menu() -> void:
	if not is_visible_menu:
		return

	hide()
	is_visible_menu = false
	PauseService.release_pause("pause_menu", get_tree())

func _apply_responsive_layout() -> void:
	var vp_size: Vector2 = get_viewport().get_visible_rect().size
	if vp_size.x <= 0 or vp_size.y <= 0:
		return

	_ui_scale = clamp(min(vp_size.x / BASE_RESOLUTION.x, vp_size.y / BASE_RESOLUTION.y), MIN_UI_SCALE, MAX_UI_SCALE)

	var margin_x: int = roundi(24.0 * _ui_scale)
	var margin_top: int = roundi(18.0 * _ui_scale)
	var bottom_reserved: int = roundi(104.0 * _ui_scale)
	root_hbox.offset_left = margin_x
	root_hbox.offset_right = -margin_x
	root_hbox.offset_top = margin_top
	root_hbox.offset_bottom = -bottom_reserved

	root_hbox.add_theme_constant_override("separation", roundi(20.0 * _ui_scale))
	menu_container.add_theme_constant_override("separation", roundi(10.0 * _ui_scale))
	status_container.add_theme_constant_override("separation", roundi(10.0 * _ui_scale))

	var button_h: int = roundi(58.0 * _ui_scale)
	var button_font: int = roundi(34.0 * _ui_scale)
	for b in _menu_buttons:
		b.custom_minimum_size = Vector2(0, button_h)
		b.add_theme_font_size_override("font_size", button_font)

	wave_label.add_theme_font_size_override("font_size", roundi(44.0 * _ui_scale))
	weapon_label.add_theme_font_size_override("font_size", roundi(30.0 * _ui_scale))
	item_label.add_theme_font_size_override("font_size", roundi(30.0 * _ui_scale))

	var icon_size: int = roundi(80.0 * _ui_scale)
	weapon_icon.custom_minimum_size = Vector2(icon_size, icon_size)
	item_icon.custom_minimum_size = Vector2(icon_size, icon_size)

	stats_title.add_theme_font_size_override("font_size", roundi(44.0 * _ui_scale))
	main_tab.add_theme_font_size_override("font_size", roundi(24.0 * _ui_scale))
	sub_tab.add_theme_font_size_override("font_size", roundi(24.0 * _ui_scale))

	run_info_label.add_theme_font_size_override("font_size", roundi(28.0 * _ui_scale))
	dot_before.add_theme_font_size_override("font_size", roundi(18.0 * _ui_scale))
	dot_current.add_theme_font_size_override("font_size", roundi(18.0 * _ui_scale))
	dot_after.add_theme_font_size_override("font_size", roundi(18.0 * _ui_scale))
	mark_5.add_theme_font_size_override("font_size", roundi(18.0 * _ui_scale))
	mark_10.add_theme_font_size_override("font_size", roundi(18.0 * _ui_scale))
	mark_15.add_theme_font_size_override("font_size", roundi(18.0 * _ui_scale))
	mark_20.add_theme_font_size_override("font_size", roundi(18.0 * _ui_scale))

func _update_status_display() -> void:
	var weapon_count: int = Global.selected_player_weapons.size()
	weapon_label.text = "武器 (%d/2)" % weapon_count

	var arena = get_tree().get_first_node_in_group("arena")
	if arena and arena.spawner:
		wave_label.text = "第%d波" % int(arena.spawner.wave_index)
	else:
		wave_label.text = "第1波"

func _update_stats_display() -> void:
	if not is_instance_valid(Global.player):
		return

	for child in stats_list.get_children():
		child.queue_free()

	var stats: Array[Dictionary] = _get_player_stats(Global.player)
	var stat_font: int = roundi(22.0 * _ui_scale)
	if stat_font < 14:
		stat_font = 14

	for stat in stats:
		var stat_label: Label = Label.new()
		stat_label.text = "%s: %s" % [stat.name, stat.value]
		stat_label.add_theme_font_size_override("font_size", stat_font)
		if stat.color != null:
			stat_label.add_theme_color_override("font_color", stat.color)
		stats_list.add_child(stat_label)

func _get_player_stats(player: PlayerBase) -> Array[Dictionary]:
	var stats: Array[Dictionary] = []

	var level_display: int = int(player.xp / 100) + 1
	stats.append({"name": "当前等级", "value": str(level_display), "color": Color(0.95, 0.95, 0.95)})

	if player.health_component:
		stats.append({"name": "最大生命值", "value": str(int(player.health_component.max_health)), "color": Color(0.16, 1.0, 0.3)})
		stats.append({"name": "生命再生", "value": "0", "color": null})
	else:
		stats.append({"name": "最大生命值", "value": "0", "color": Color(0.16, 1.0, 0.3)})
		stats.append({"name": "生命再生", "value": "0", "color": null})

	stats.append({"name": "%伤害", "value": "0", "color": null})
	stats.append({"name": "近战伤害", "value": "0", "color": null})
	stats.append({"name": "远程伤害", "value": "0", "color": null})
	stats.append({"name": "元素伤害", "value": "0", "color": null})
	stats.append({"name": "%暴击率", "value": "0", "color": null})

	var armor_val: int = int(_get_prop_number(player, "armor", 0.0))
	stats.append({"name": "护甲", "value": str(armor_val), "color": null})
	stats.append({"name": "%闪避", "value": "0", "color": null})

	var base_speed: float = _get_prop_number(player, "base_speed", 0.0)
	var speed_now: float = _get_prop_number(player, "speed", base_speed)
	var speed_percent: int = 0
	if base_speed > 0.0:
		speed_percent = int((speed_now / base_speed - 1.0) * 100.0)
	stats.append({"name": "%速度", "value": str(speed_percent), "color": null})

	stats.append({"name": "幸运", "value": "0", "color": Color(0.16, 1.0, 0.3)})
	stats.append({"name": "收获", "value": "0", "color": null})

	return stats

func _get_prop_number(obj: Object, prop: String, default_value: float = 0.0) -> float:
	var value = obj.get(prop)
	if value == null:
		return default_value
	if typeof(value) == TYPE_INT or typeof(value) == TYPE_FLOAT:
		return float(value)
	return default_value

func _on_continue_pressed() -> void:
	SoundManager.play("ui_resume")
	hide_menu()
	resume_requested.emit()

func _on_restart_pressed() -> void:
	SoundManager.play("ui_click")
	hide_menu()
	restart_requested.emit()

func _on_end_run_pressed() -> void:
	SoundManager.play("ui_click")
	hide_menu()
	end_run_requested.emit()

func _on_codex_pressed() -> void:
	SoundManager.play("ui_click")
	codex_requested.emit()

func _on_settings_pressed() -> void:
	SoundManager.play("ui_click")
	settings_requested.emit()

func _on_main_menu_pressed() -> void:
	SoundManager.play("ui_click")
	hide_menu()
	return_to_menu_requested.emit()

func _input(event: InputEvent) -> void:
	if not is_visible_menu:
		return

	if event.is_action_pressed("ui_cancel"):
		_on_continue_pressed()
		get_viewport().set_input_as_handled()
