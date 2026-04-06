extends Control

@onready var title_screen: Control = $TitleScreen
@onready var main_menu: Control = $MainMenu
@onready var save_slot_panel: Control = $SaveSlotPanel
@onready var compendium_screen: Control = $CompendiumScreen
@onready var settings_panel: CanvasLayer = $SettingsPanel
@onready var credits_screen: Control = $CreditsScreen
@onready var confirm_dialog: ConfirmDialog = $ConfirmDialog

var current_screen: Control = null
var _is_transitioning: bool = false

func _ready() -> void:
	_hide_all()
	# 跳过标题界面，直接显示主菜单
	_show_screen(main_menu)
	# 连接主菜单动作信号
	if main_menu.has_signal("menu_action"):
		main_menu.menu_action.connect(_on_menu_action)
	# 连接存档槽位面板信号
	if save_slot_panel.has_signal("slot_selected"):
		save_slot_panel.slot_selected.connect(_on_save_slot_selected)
	if save_slot_panel.has_signal("back_pressed"):
		save_slot_panel.back_pressed.connect(_on_save_slot_back)
	# 连接设置面板关闭信号
	if settings_panel.has_signal("closed"):
		settings_panel.closed.connect(_on_settings_closed)
	# 连接图鉴界面返回信号
	if compendium_screen.has_signal("back_pressed"):
		compendium_screen.back_pressed.connect(_on_compendium_back)
	# 连接致谢界面返回信号
	if credits_screen.has_signal("back_pressed"):
		credits_screen.back_pressed.connect(_on_credits_back)

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		# 确认对话框可见时，由 ConfirmDialog 自身处理 ESC
		if confirm_dialog.is_visible_dialog:
			return
		# 主菜单界面按 ESC：弹出退出游戏确认框
		if current_screen == main_menu:
			confirm_dialog.show_dialog("确认退出游戏？", func(): get_tree().quit())
			get_viewport().set_input_as_handled()
			return
		# 子界面按 ESC：返回主菜单
		if current_screen != null and current_screen != title_screen:
			if settings_panel.is_visible_panel:
				close_settings()
			else:
				go_to_main_menu()
			get_viewport().set_input_as_handled()

func switch_to(screen: Control, transition: String = "fade") -> void:
	if _is_transitioning or screen == current_screen:
		return
	_is_transitioning = true

	var old_screen = current_screen
	var tween = create_tween()

	match transition:
		"slide":
			# Slide current screen left, new screen from right
			if old_screen:
				screen.position.x = get_viewport_rect().size.x
				screen.modulate.a = 1.0
				screen.visible = true
				tween.set_parallel(true)
				tween.tween_property(old_screen, "position:x", -get_viewport_rect().size.x, 0.3).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_CUBIC)
				tween.tween_property(screen, "position:x", 0.0, 0.3).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_CUBIC)
				tween.set_parallel(false)
				tween.tween_callback(func():
					old_screen.visible = false
					old_screen.position.x = 0.0
				)
			else:
				screen.modulate.a = 1.0
				screen.visible = true
		_:
			# Default: fade transition
			if old_screen:
				tween.tween_property(old_screen, "modulate:a", 0.0, 0.15)
				tween.tween_callback(func(): old_screen.visible = false)
			screen.modulate.a = 0.0
			screen.visible = true
			tween.tween_property(screen, "modulate:a", 1.0, 0.15)

	tween.tween_callback(func(): _is_transitioning = false)
	current_screen = screen

func _show_screen(screen: Control) -> void:
	screen.modulate.a = 1.0
	screen.visible = true
	current_screen = screen

func _hide_all() -> void:
	for child in get_children():
		if child is Control and child.name != "Background":
			child.visible = false
			child.modulate.a = 1.0

# --- Navigation methods ---

func go_to_main_menu() -> void:
	switch_to(main_menu, "fade")

func go_to_save_slots(mode: String) -> void:
	if save_slot_panel.has_method("setup"):
		save_slot_panel.setup(mode)
	switch_to(save_slot_panel, "slide")

func go_to_compendium() -> void:
	switch_to(compendium_screen, "slide")

func go_to_credits() -> void:
	switch_to(credits_screen, "slide")

func open_settings() -> void:
	# 设置面板是 CanvasLayer 弹窗，直接调用 show_panel
	if settings_panel.has_method("show_panel"):
		settings_panel.show_panel()
	else:
		settings_panel.show()

func close_settings() -> void:
	if settings_panel.has_method("_on_close"):
		settings_panel._on_close()
	else:
		settings_panel.hide()

# --- Title Screen transition ---

func _on_title_any_key_pressed() -> void:
	if _is_transitioning:
		return
	_is_transitioning = true
	# 播放标题界面过渡动画（Logo上移缩小）
	if title_screen.has_method("play_transition_out"):
		await title_screen.play_transition_out()
	# 过渡完成后切换到主菜单
	title_screen.visible = false
	_is_transitioning = false
	_show_screen(main_menu)

# --- 主菜单动作处理 ---

func _on_menu_action(action: String) -> void:
	match action:
		"continue":
			# 加载最近存档并跳转游戏场景
			var slot_index := SaveManager.get_most_recent_slot()
			if slot_index >= 0:
				var data := SaveManager.load_game_save(slot_index)
				if not data.is_empty():
					Global.current_save_slot = slot_index
					_restore_global_from_save(data)
					# 检查游戏状态，决定跳转到哪个场景
					var game_state = data.get("game_state", "in_progress")
					if game_state == "character_selection":
						# 返回角色选择界面
						get_tree().change_scene_to_file("res://scenes/ui/selection_panel/selection_panel.tscn")
					elif game_state == "in_battle" and data.has("battle_state"):
						# 恢复战斗状态
						Global.pending_battle_state = data["battle_state"]
						get_tree().change_scene_to_file("res://scenes/arena/arena.tscn")
					else:
						# 默认进入战斗场景
						get_tree().change_scene_to_file("res://scenes/arena/arena.tscn")
				else:
					print("[MainMenuRoot] CONTINUE: 槽位 %d 数据为空" % slot_index)
			else:
				print("[MainMenuRoot] CONTINUE: 没有可用存档")
		"new_game":
			go_to_save_slots("new_game")
		"load_game":
			go_to_save_slots("load")
		"compendium":
			go_to_compendium()
		"settings":
			open_settings()
		"credits":
			go_to_credits()
		"quit":
			# 显示退出确认对话框
			confirm_dialog.show_dialog("确认退出游戏？", func(): get_tree().quit())

# --- 存档槽位面板处理 ---

func _on_save_slot_selected(slot_index: int) -> void:
	match save_slot_panel.mode:
		"new_game":
			# 新游戏：重置所有进度数据，记录槽位后跳转角色选择界面
			print("[MainMenuRoot] NEW GAME: 选择槽位 %d，跳转角色选择" % slot_index)
			Global.current_save_slot = slot_index
			Global.reset_selection()
			Global.reset_session_data()
			# 重置金币到默认值
			DataManager.save_data.total_gold = DataManager._get_default_gold()
			DataManager.save_data.upgrades = {}
			DataManager.save_game()
			# 清空装备和仓库（局内仓库模式：开局为空）
			EquipmentManager.clear_all_equipment()
			WarehouseManager.reset_for_new_run()
			# 清除局内会话存档
			DataManager.clear_session_data()
			# 清除角色选择缓存，确保新游戏从空白开始
			_clear_selection_cache()
			_clear_weapon_cache()
			if Global.has_method("clear_selection_preset"):
				Global.clear_selection_preset()
			get_tree().change_scene_to_file("res://scenes/ui/selection_panel/selection_panel.tscn")
		"load":
			# 加载存档：读取数据后恢复到 Global，跳转游戏场景
			var data := SaveManager.load_game_save(slot_index)
			if data.is_empty():
				print("[MainMenuRoot] LOAD: 槽位 %d 数据为空" % slot_index)
				return
			print("[MainMenuRoot] LOAD: 加载槽位 %d" % slot_index)
			Global.current_save_slot = slot_index
			_restore_global_from_save(data)
			# 检查游戏状态
			var game_state = data.get("game_state", "in_progress")
			if game_state == "character_selection":
				get_tree().change_scene_to_file("res://scenes/ui/selection_panel/selection_panel.tscn")
			elif game_state == "in_battle" and data.has("battle_state"):
				Global.pending_battle_state = data["battle_state"]
				get_tree().change_scene_to_file("res://scenes/arena/arena.tscn")
			else:
				get_tree().change_scene_to_file("res://scenes/arena/arena.tscn")

func _on_save_slot_back() -> void:
	go_to_main_menu()

func _on_settings_closed() -> void:
	# 设置面板关闭后无需额外操作，面板自行隐藏
	pass

func _on_compendium_back() -> void:
	go_to_main_menu()

func _on_credits_back() -> void:
	go_to_main_menu()

# --- 存档数据恢复到 Global ---

func _clear_selection_cache() -> void:
	"""清除角色选择缓存文件，确保新游戏从空白开始"""
	var cache_path := "user://player_selection_cache.json"
	if FileAccess.file_exists(cache_path):
		var dir := DirAccess.open("user://")
		if dir:
			dir.remove("player_selection_cache.json")
			print("[MainMenuRoot] 已清除角色选择缓存")

func _clear_weapon_cache() -> void:
	"""清除武器选择缓存文件"""
	var weapon_cache_path := "user://player_weapon_cache.json"
	if FileAccess.file_exists(weapon_cache_path):
		var dir := DirAccess.open("user://")
		if dir:
			dir.remove("player_weapon_cache.json")
			print("[MainMenuRoot] 已清除武器选择缓存")

func _sync_selection_cache_from_global() -> void:
	"""将当前 Global 的角色/武器数据写入 SelectionPanel 的缓存文件"""
	var selection_cache: Array = []
	for i in range(Global.selected_player_ids.size()):
		var pid: String = Global.selected_player_ids[i]
		var wtype: String = Global.selected_player_weapons.get(pid, "")
		selection_cache.append({
			"player_id": pid,
			"weapon_type": wtype,
			"slot_index": i
		})
	
	var sel_file := FileAccess.open("user://player_selection_cache.json", FileAccess.WRITE)
	if sel_file:
		sel_file.store_string(JSON.stringify(selection_cache))
		sel_file.close()
		print("[MainMenuRoot] 已同步角色选择缓存: %s" % str(selection_cache))
	
	var weapon_cache: Dictionary = {}
	for pid in Global.selected_player_ids:
		var wtype: String = Global.selected_player_weapons.get(pid, "")
		if wtype != "":
			weapon_cache[pid] = wtype
	
	var wpn_file := FileAccess.open("user://player_weapon_cache.json", FileAccess.WRITE)
	if wpn_file:
		wpn_file.store_string(JSON.stringify(weapon_cache))
		wpn_file.close()
		print("[MainMenuRoot] 已同步武器选择缓存: %s" % str(weapon_cache))

func _restore_global_from_save(data: Dictionary) -> void:
	"""从存档数据恢复 Global 状态，用于继续游戏和加载存档"""
	Global.reset_selection()
	
	# 恢复已选角色列表
	var players_data: Array = data.get("selected_players", [])
	print("[MainMenuRoot] 存档 selected_players 数据: %s" % str(players_data))
	
	for p in players_data:
		if p is Dictionary:
			var pid: String = str(p.get("player_id", ""))
			if pid != "":
				Global.selected_player_ids.append(pid)
				var wtype: String = str(p.get("weapon_type", ""))
				if wtype != "":
					Global.selected_player_weapons[pid] = wtype
		elif p is String and p != "":
			Global.selected_player_ids.append(p)
	
	# 如果 selected_players 为空，尝试用 leader_id 作为唯一角色
	if Global.selected_player_ids.is_empty():
		var leader: String = str(data.get("leader_id", ""))
		if leader != "":
			Global.selected_player_ids.append(leader)
			print("[MainMenuRoot] 使用 leader_id 作为唯一角色: %s" % leader)
	
	# 恢复当前角色索引
	Global.current_player_index = int(data.get("current_player_index", 0))
	
	# 恢复角色状态
	var player_states = data.get("player_states", {})
	if not player_states.is_empty():
		Global.player_states = player_states.duplicate(true)
	else:
		Global.init_player_states()
	
	# 恢复金币
	var gold = int(data.get("gold", 0))
	if gold > 0:
		DataManager.save_data.total_gold = gold
	
	# 恢复局内数据
	Global.session_xp = int(data.get("session_xp", 0))
	Global.session_kills = int(data.get("session_kills", 0))
	Global.session_gold = int(data.get("session_gold", 0))
	
	# 恢复升级数据
	var upgrades = data.get("upgrades", {})
	if not upgrades.is_empty():
		DataManager.save_data.upgrades = upgrades.duplicate(true)
	
	# 恢复徽章数据
	var emblems_data = data.get("emblems", {})
	if not emblems_data.is_empty():
		EmblemManager.deserialize(emblems_data)
	
	# 恢复修改器数据
	var modifiers_data = data.get("modifiers", {})
	if not modifiers_data.is_empty():
		ModifierManager.deserialize(modifiers_data)
	
	# 恢复羁绊数据（使用 bond_counts 而不是 bond_summary）
	var bond_counts = data.get("bond_counts", {})
	if not bond_counts.is_empty():
		BondManager.restore_from_save(bond_counts)
	
	# 恢复装备数据
	var equipment_data = data.get("equipment", {})
	if not equipment_data.is_empty():
		EquipmentManager.restore_from_save(equipment_data)
	
	# 恢复仓库数据
	var warehouse_data = data.get("warehouse", {})
	if not warehouse_data.is_empty():
		WarehouseManager.restore_from_save(warehouse_data)
	
	# 同步选角缓存，确保 SelectionPanel 读取到正确数据
	_sync_selection_cache_from_global()
	
	print("[MainMenuRoot] 恢复 Global: 角色=%s, 武器=%s, 波次=%d" % [
		str(Global.selected_player_ids),
		str(Global.selected_player_weapons),
		int(data.get("current_wave", 1))
	])
