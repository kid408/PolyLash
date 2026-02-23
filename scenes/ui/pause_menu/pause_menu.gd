extends CanvasLayer
class_name PauseMenu

signal resume_requested
signal restart_requested
signal end_run_requested
signal codex_requested
signal settings_requested
signal return_to_menu_requested

@onready var panel = $Panel
@onready var menu_container = $Panel/HBoxContainer/MenuContainer
@onready var status_container = $Panel/HBoxContainer/StatusContainer
@onready var stats_container = $Panel/HBoxContainer/StatsContainer

# 菜单按钮
@onready var continue_button = $Panel/HBoxContainer/MenuContainer/ContinueButton
@onready var restart_button = $Panel/HBoxContainer/MenuContainer/RestartButton
@onready var end_run_button = $Panel/HBoxContainer/MenuContainer/EndRunButton
@onready var codex_button = $Panel/HBoxContainer/MenuContainer/CodexButton
@onready var settings_button = $Panel/HBoxContainer/MenuContainer/SettingsButton
@onready var main_menu_button = $Panel/HBoxContainer/MenuContainer/MainMenuButton

# 状态显示
@onready var weapon_label = $Panel/HBoxContainer/StatusContainer/WeaponLabel
@onready var weapon_icon = $Panel/HBoxContainer/StatusContainer/WeaponIcon
@onready var item_label = $Panel/HBoxContainer/StatusContainer/ItemLabel
@onready var item_icon = $Panel/HBoxContainer/StatusContainer/ItemIcon
@onready var wave_label = $Panel/HBoxContainer/StatusContainer/WaveLabel

# 属性面板
@onready var stats_list = $Panel/HBoxContainer/StatsContainer/StatsList

var is_visible_menu: bool = false

func _ready() -> void:
	process_mode = PROCESS_MODE_ALWAYS
	
	# 连接按钮信号
	continue_button.pressed.connect(_on_continue_pressed)
	restart_button.pressed.connect(_on_restart_pressed)
	end_run_button.pressed.connect(_on_end_run_pressed)
	codex_button.pressed.connect(_on_codex_pressed)
	settings_button.pressed.connect(_on_settings_pressed)
	main_menu_button.pressed.connect(_on_main_menu_pressed)
	
	hide()

func show_menu() -> void:
	"""显示暂停菜单"""
	if is_visible_menu:
		return
	
	_update_status_display()
	_update_stats_display()
	
	show()
	is_visible_menu = true
	get_tree().paused = true
	SoundManager.play("ui_pause")

func hide_menu() -> void:
	"""隐藏暂停菜单"""
	if not is_visible_menu:
		return
	
	hide()
	is_visible_menu = false
	get_tree().paused = false

func _update_status_display() -> void:
	"""更新中间状态显示（武器、道具、波次）"""
	# 更新武器显示
	var weapon_count = Global.selected_player_weapons.size()
	weapon_label.text = "武器 (%d/2)" % weapon_count
	
	# 更新波次显示
	var arena = get_tree().get_first_node_in_group("arena")
	if arena and arena.spawner:
		wave_label.text = "第%d波" % arena.spawner.wave_index
	else:
		wave_label.text = "第1波"

func _update_stats_display() -> void:
	"""更新右侧属性面板"""
	if not is_instance_valid(Global.player):
		return
	
	# 清空现有列表
	for child in stats_list.get_children():
		child.queue_free()
	
	# 获取玩家属性
	var player = Global.player
	var stats = _get_player_stats(player)
	
	# 创建属性显示
	for stat in stats:
		var stat_label = Label.new()
		stat_label.text = "%s: %s" % [stat.name, stat.value]
		if stat.color:
			stat_label.add_theme_color_override("font_color", stat.color)
		stats_list.add_child(stat_label)

func _get_player_stats(player: PlayerBase) -> Array:
	"""获取玩家属性列表"""
	var stats = []
	
	# 基础属性 - 使用经验值代替等级
	var level_display = int(player.xp / 100) + 1  # 简单的等级计算
	stats.append({"name": "目前等级", "value": str(level_display), "color": null})
	
	if player.health_component:
		stats.append({"name": "最大生命值", "value": str(int(player.health_component.max_health)), "color": Color.GREEN})
		stats.append({"name": "生命再生", "value": "0", "color": null})
	
	# 伤害属性
	stats.append({"name": "%伤害", "value": "0", "color": null})
	stats.append({"name": "近战伤害", "value": "0", "color": null})
	stats.append({"name": "远程伤害", "value": "0", "color": null})
	stats.append({"name": "元素伤害", "value": "0", "color": null})
	
	# 暴击
	stats.append({"name": "%暴击率", "value": "0", "color": null})
	
	# 其他属性
	if "armor" in player:
		stats.append({"name": "护甲", "value": str(player.armor), "color": null})
	else:
		stats.append({"name": "护甲", "value": "0", "color": null})
	
	stats.append({"name": "%闪避", "value": "0", "color": null})
	
	# 速度
	var speed_percent = 0
	if "base_speed" in player and player.base_speed > 0:
		var current_speed = player.speed if "speed" in player else player.base_speed
		speed_percent = int((current_speed / player.base_speed - 1.0) * 100)
	stats.append({"name": "%速度", "value": str(speed_percent), "color": null})
	
	stats.append({"name": "幸运", "value": "0", "color": Color.GREEN})
	stats.append({"name": "收获", "value": "0", "color": null})
	
	return stats

func _on_continue_pressed() -> void:
	"""继续游戏"""
	SoundManager.play("ui_resume")
	hide_menu()
	resume_requested.emit()

func _on_restart_pressed() -> void:
	"""重新开始"""
	SoundManager.play("ui_click")
	hide_menu()
	restart_requested.emit()

func _on_end_run_pressed() -> void:
	"""结束本轮游戏 - 返回角色选择界面"""
	SoundManager.play("ui_click")
	hide_menu()
	end_run_requested.emit()

func _on_codex_pressed() -> void:
	"""打开图鉴"""
	SoundManager.play("ui_click")
	codex_requested.emit()

func _on_settings_pressed() -> void:
	"""打开设置"""
	SoundManager.play("ui_click")
	settings_requested.emit()

func _on_main_menu_pressed() -> void:
	"""返回主菜单 - 保存完整战斗状态"""
	SoundManager.play("ui_click")
	hide_menu()
	return_to_menu_requested.emit()

func _input(event: InputEvent) -> void:
	if not is_visible_menu:
		return
	
	# ESC 键继续游戏
	if event.is_action_pressed("ui_cancel"):
		_on_continue_pressed()
		get_viewport().set_input_as_handled()
