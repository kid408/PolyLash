extends Control
## 主菜单按钮列表 - 左侧垂直排列，支持 CONTINUE 条件显示和悬停信息卡片
## 按钮通过 menu_button.tscn 预制体动态创建
## 键盘焦点导航：自动聚焦第一个可见按钮 + 上下方向键

# 菜单动作信号，供 MainMenuRoot 处理
signal menu_action(action: String)

# 按钮预制体
const MENU_BUTTON_SCENE = preload("res://scenes/ui/main_menu/menu_button.tscn")

# CONTINUE 按钮样式
const CONTINUE_FONT_SIZE := 47  # 36 * 1.3 ≈ 47
const CONTINUE_COLOR := Color("#4CAF50")
const NORMAL_FONT_SIZE := 36

# 信息卡片颜色
const CARD_BG_COLOR := Color("#222222")
const CARD_TEXT_COLOR := Color("#FFFFFF")
const CARD_SUB_TEXT_COLOR := Color("#AAAAAA")

# 按钮定义：[显示文本, 动作标识, 是否为 CONTINUE]
const BUTTON_DEFS: Array = [
	["继续游戏", "continue", true],
	["新游戏", "new_game", false],
	["加载存档", "load_game", false],
	["图鉴", "compendium", false],
	["设置", "settings", false],
	["致谢", "credits", false],
	["退出", "quit", false],
]

# 节点引用
@onready var button_container: VBoxContainer = $ButtonContainer
@onready var continue_info_card: PanelContainer = $ContinueInfoCard
@onready var card_portrait_1: TextureRect = $ContinueInfoCard/CardMargin/CardVBox/CardHeader/CardPortraits/CardPortrait1
@onready var card_portrait_2: TextureRect = $ContinueInfoCard/CardMargin/CardVBox/CardHeader/CardPortraits/CardPortrait2
@onready var card_portrait_3: TextureRect = $ContinueInfoCard/CardMargin/CardVBox/CardHeader/CardPortraits/CardPortrait3
@onready var card_name_label: Label = $ContinueInfoCard/CardMargin/CardVBox/CardHeader/CardNameLabel
@onready var card_floor_label: Label = $ContinueInfoCard/CardMargin/CardVBox/CardFloorLabel
@onready var card_time_label: Label = $ContinueInfoCard/CardMargin/CardVBox/CardTimeLabel

# 按钮实例列表
var _buttons: Array = []
var _continue_button: Button = null
var _card_portrait_slots: Array[TextureRect] = []

func _ready() -> void:
	_card_portrait_slots = [card_portrait_1, card_portrait_2, card_portrait_3]

	# 隐藏信息卡片
	continue_info_card.visible = false
	# 构建菜单按钮
	_build_menu_buttons()
	# 延迟一帧设置焦点，确保按钮已就绪
	await get_tree().process_frame
	_focus_first_visible_button()


# ============================================================================
# 按钮构建
# ============================================================================

func _build_menu_buttons() -> void:
	"""根据定义列表动态创建菜单按钮"""
	# 清空现有按钮
	for child in button_container.get_children():
		child.queue_free()
	_buttons.clear()
	_continue_button = null

	var has_save := SaveManager.has_any_save()

	for def in BUTTON_DEFS:
		var label_text: String = def[0]
		var action: String = def[1]
		var is_continue: bool = def[2]

		# CONTINUE 按钮仅在有存档时显示
		if is_continue and not has_save:
			continue

		var btn: Button = MENU_BUTTON_SCENE.instantiate()
		button_container.add_child(btn)
		btn.setup(label_text, action)

		# CONTINUE 按钮特殊样式：1.3倍字体 + 绿色文字
		if is_continue:
			_continue_button = btn
			btn.add_theme_font_size_override("font_size", CONTINUE_FONT_SIZE)
			btn.add_theme_color_override("font_color", CONTINUE_COLOR)
			# 连接悬停信号显示信息卡片
			btn.mouse_entered.connect(_on_continue_hover_enter)
			btn.mouse_exited.connect(_on_continue_hover_exit)
			btn.focus_entered.connect(_on_continue_hover_enter)
			btn.focus_exited.connect(_on_continue_hover_exit)

		# 连接按钮动作信号
		btn.button_action.connect(_on_button_action)
		_buttons.append(btn)

	# 设置按钮之间的焦点邻居（上下方向键导航）
	_setup_focus_neighbors()


# ============================================================================
# 焦点导航
# ============================================================================

func _setup_focus_neighbors() -> void:
	"""设置按钮之间的上下焦点邻居，实现键盘导航"""
	for i in range(_buttons.size()):
		var btn: Button = _buttons[i]
		# 上方邻居：循环到最后一个
		var prev_idx := (i - 1) if i > 0 else (_buttons.size() - 1)
		# 下方邻居：循环到第一个
		var next_idx := (i + 1) if i < _buttons.size() - 1 else 0

		btn.focus_neighbor_top = _buttons[prev_idx].get_path()
		btn.focus_neighbor_bottom = _buttons[next_idx].get_path()
		# 禁止左右焦点跳转
		btn.focus_neighbor_left = btn.get_path()
		btn.focus_neighbor_right = btn.get_path()


func _focus_first_visible_button() -> void:
	"""自动聚焦第一个可见按钮"""
	if _buttons.size() > 0:
		_buttons[0].grab_focus()


# ============================================================================
# CONTINUE 悬停信息卡片
# ============================================================================

func _on_continue_hover_enter() -> void:
	"""悬停 CONTINUE 按钮时显示最近存档的摘要信息卡片"""
	var slot_index := SaveManager.get_most_recent_slot()
	if slot_index < 0:
		return

	var data := SaveManager.get_slot_data(slot_index)
	if data.is_empty():
		return

	# 填充三人缩略图（优先 selected_players，回退 leader_id）
	var player_ids := _extract_saved_player_ids(data)
	_update_continue_portraits(player_ids)
	card_name_label.text = _build_team_name_text(player_ids)

	# 进度显示按 game_state 分支，避免失败后仍显示旧波次。
	var game_state: String = str(data.get("game_state", "in_progress"))
	if game_state == "character_selection":
		card_floor_label.text = "角色准备中"
	elif game_state == "in_battle" and data.has("battle_state"):
		var battle_state: Dictionary = data.get("battle_state", {})
		var floor_num_battle: int = int(battle_state.get("current_floor", data.get("current_floor", 1)))
		var wave_num_battle: int = int(battle_state.get("current_wave", data.get("current_wave", 1)))
		card_floor_label.text = "第%d层 - 波次%d" % [floor_num_battle, wave_num_battle]
	else:
		var floor_num: int = int(data.get("current_floor", 1))
		var wave_num: int = int(data.get("current_wave", 1))
		card_floor_label.text = "第%d层 - 波次%d" % [floor_num, wave_num]

	# 游戏时长
	var play_seconds: int = int(data.get("play_time_seconds", 0))
	card_time_label.text = SaveManager.format_play_time(play_seconds)

	continue_info_card.visible = true


func _on_continue_hover_exit() -> void:
	"""离开 CONTINUE 按钮时隐藏信息卡片"""
	continue_info_card.visible = false

func _update_continue_portraits(player_ids: Array[String]) -> void:
	for i in range(_card_portrait_slots.size()):
		var slot = _card_portrait_slots[i]
		if i < player_ids.size():
			var tex := _load_player_portrait(player_ids[i])
			slot.texture = tex
			slot.visible = tex != null
			slot.tooltip_text = _get_player_display_name(player_ids[i])
		else:
			slot.texture = null
			slot.visible = false
			slot.tooltip_text = ""

func _build_team_name_text(player_ids: Array[String]) -> String:
	if player_ids.is_empty():
		return "未知队伍"
	var names: Array[String] = []
	for pid in player_ids:
		names.append(_get_player_display_name(pid))
	return " / ".join(names)

func _extract_saved_player_ids(data: Dictionary) -> Array[String]:
	var result: Array[String] = []
	var selected_players = data.get("selected_players", [])
	if selected_players is Array:
		for entry in selected_players:
			var pid := ""
			if entry is Dictionary:
				pid = str(entry.get("player_id", "")).strip_edges()
			elif entry is String:
				pid = str(entry).strip_edges()
			if pid == "":
				continue
			result.append(pid)
			if result.size() >= _card_portrait_slots.size():
				return result

	var leader_id := str(data.get("leader_id", "")).strip_edges()
	if result.is_empty() and leader_id != "":
		result.append(leader_id)
	return result

func _load_player_portrait(player_id: String) -> Texture2D:
	var visual := ConfigManager.get_player_visual(player_id)
	var sprite_path := str(visual.get("sprite_path", "")).strip_edges()
	if sprite_path == "" or not ResourceLoader.exists(sprite_path):
		return null
	return load(sprite_path) as Texture2D

func _get_player_display_name(player_id: String) -> String:
	var config := ConfigManager.get_player_config(player_id)
	return str(config.get("display_name", player_id))


# ============================================================================
# 按钮动作处理
# ============================================================================

func _on_button_action(action: String) -> void:
	"""转发按钮动作信号给 MainMenuRoot"""
	menu_action.emit(action)


# ============================================================================
# 外部刷新接口
# ============================================================================

func refresh() -> void:
	"""刷新菜单状态（存档变化后调用）"""
	_build_menu_buttons()
	await get_tree().process_frame
	_focus_first_visible_button()
