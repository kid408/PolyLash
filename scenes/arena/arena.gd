extends Node2D
class_name Arena

@export var player:PlayerBase
@export var normal_color:Color
@export var blockedl_color:Color
@export var critical_color:Color
@export var hp_color:Color

@onready var global_hud: GlobalHUD = %GlobalHUD
@onready var squad_hud: SquadHUD = %SquadHUD
@onready var spawner: Spawner = $Spawner
@onready var chest_manager: ChestManager = $ChestManager
@onready var upgrade_ui: UpgradeSelectionUI = $UpgradeSelectionUI
@onready var chest_indicator: ChestIndicator = $ChestIndicator

var current_chest: ChestSimple = null  # 保存当前打开的宝箱引用

func _ready() -> void:
	print("[Arena] _ready() 开始")
	# 将角色添加到全局变量中
	#Global.player = player
	# 闪避飘字信号 Unit类 _on_hurtbox_component_on_damaged 调用
	Global.on_create_block_text.connect(_on_create_block_text)
	# 伤害飘字信号
	Global.on_create_damage_text.connect(_on_create_damage_text)
	
	# 连接宝箱系统
	if chest_manager:
		chest_manager.chest_opened.connect(_on_chest_opened)
	
	# 连接升级选择信号
	if upgrade_ui:
		upgrade_ui.upgrade_selected.connect(_on_upgrade_selected)
	
	# 设置宝箱指示器
	if chest_indicator and chest_manager:
		chest_indicator.set_chest_manager(chest_manager)
	
	# 连接角色切换信号
	Global.on_player_switch_requested.connect(_on_player_switch_requested)
	
	print("[Arena] 准备初始化玩家...")
	# 初始化玩家（如果从选择界面进入）- 使用 await 确保完成
	await _init_player_from_selection()
	print("[Arena] 玩家初始化完成")
	
	# 初始化小队 HUD
	_init_squad_hud()
	
	# 重置局内数据
	Global.reset_session_data()
	
	# 连接玩家的 XP 和 Gold 信号
	_connect_player_signals()

func _on_chest_opened(chest: ChestSimple) -> void:
	print("[Arena] Chest opened signal received, chest tier: %d" % chest.get_tier())
	
	# 保存宝箱引用
	current_chest = chest
	
	if not upgrade_ui:
		printerr("[Arena] UpgradeSelectionUI not found!")
		return
	
	print("[Arena] Showing upgrade UI")
	# 显示升级选择UI
	upgrade_ui.show_upgrades(chest.get_tier())

func _on_upgrade_selected(attribute_id: String) -> void:
	print("[Arena] Upgrade selected: %s" % attribute_id)
	
	# 隐藏宝箱
	if is_instance_valid(current_chest):
		current_chest.hide_chest()
		current_chest = null

func _process(delta: float) -> void:
	if Global.game_paused: return
	# 更新 Global HUD 波次信息
	if global_hud and spawner and not spawner.spawn_timer.is_stopped():
		global_hud.set_wave_text(spawner.get_wave_text())
		global_hud.set_wave_time_text(spawner.get_wave_timer_text())

# 创建具体飘字数据
func create_floating_text(unit: Node2D) -> FloatingText:
	var instance := Global.FLOATING_TEXT_SCENE.instantiate() as FloatingText
	# 添加到场景中
	get_tree().root.add_child(instance)
	# 随机位置 TAU 360 度旋转
	var random_pos := randf_range(0,TAU) * 35
	# 生成位置
	var spawn_pos := unit.global_position + Vector2.RIGHT.rotated(random_pos)
	
	instance.global_position = spawn_pos
	
	return instance
	
# 创建闪避飘字
func _on_create_block_text(unit:Node2D) -> void:
	var text := create_floating_text(unit)
	text.setup("闪!",blockedl_color)
	

# 创建伤害飘字
func _on_create_damage_text(uinit:Node2D,hitbox:HitboxComponent) -> void:
	var text := create_floating_text(uinit)
	var color := critical_color if hitbox.critical else normal_color
	text.setup(str(hitbox.damage),color)

# 连接玩家的 XP 和 Gold 信号
func _connect_player_signals() -> void:
	# 等待一帧确保玩家已初始化
	await get_tree().process_frame
	
	if is_instance_valid(Global.player):
		# 先断开旧连接（如果存在）
		if Global.player.has_signal("xp_changed"):
			if Global.player.xp_changed.is_connected(_on_player_xp_changed):
				Global.player.xp_changed.disconnect(_on_player_xp_changed)
			Global.player.xp_changed.connect(_on_player_xp_changed)
		if Global.player.has_signal("gold_changed"):
			if Global.player.gold_changed.is_connected(_on_player_gold_changed):
				Global.player.gold_changed.disconnect(_on_player_gold_changed)
			Global.player.gold_changed.connect(_on_player_gold_changed)
		
		# 同步玩家本地变量与全局值（角色切换后保持一致）
		Global.player.xp = Global.session_xp
		Global.player.gold = DataManager.get_total_gold()
		
		# 初始化显示 - 使用全局值而非玩家实例值
		_update_xp_display(Global.session_xp)
		_update_gold_display(DataManager.get_total_gold())

func _on_player_xp_changed(current: int) -> void:
	# XP 已经由 player_base.add_xp() 更新到 Global.session_xp
	# GlobalHUD 通过信号自动更新，这里不需要额外处理
	pass

func _on_player_gold_changed(current: int) -> void:
	# Gold 已经由 player_base.add_gold() 更新到 DataManager
	# 直接更新 GlobalHUD 显示
	_update_gold_display(DataManager.get_total_gold())

func _update_xp_display(value: int) -> void:
	# GlobalHUD 通过 Global.on_session_xp_changed 信号自动更新
	# 这里仅作为初始化时的备用调用
	if global_hud:
		global_hud.update_xp(value)

func _update_gold_display(value: int) -> void:
	if global_hud:
		global_hud.update_gold(value)

# 初始化小队 HUD
func _init_squad_hud() -> void:
	if squad_hud and Global.selected_player_ids.size() > 0:
		var player_ids: Array[String] = []
		for id in Global.selected_player_ids:
			player_ids.append(id)
		squad_hud.init_squad(player_ids)
		print("[Arena] 小队 HUD 初始化完成")


# ============================================================================
# 角色选择系统
# ============================================================================

func _init_player_from_selection() -> void:
	"""从选择界面初始化玩家"""
	print("[Arena] _init_player_from_selection 开始")
	print("[Arena] selected_player_ids: %s" % str(Global.selected_player_ids))
	print("[Arena] selected_player_weapons: %s" % str(Global.selected_player_weapons))
	
	# 如果没有选择角色，使用场景中默认的玩家
	if Global.selected_player_ids.size() == 0:
		print("[Arena] 没有选择角色，使用默认玩家")
		if player:
			Global.player = player
		return
	
	# 移除场景中默认的玩家
	if player:
		var old_pos = player.global_position
		print("[Arena] 移除默认玩家，位置: %s" % old_pos)
		player.queue_free()
		player = null
		
		# 生成第一个选择的角色
		var first_player_id = Global.selected_player_ids[0]
		print("[Arena] 准备生成第一个角色: %s" % first_player_id)
		
		# 等待一帧确保旧玩家被销毁
		await get_tree().process_frame
		
		_spawn_player(first_player_id, old_pos)
	else:
		print("[Arena] 场景中没有默认玩家，直接生成选择的角色")
		var first_player_id = Global.selected_player_ids[0]
		_spawn_player(first_player_id, Vector2(500, 300))

func _spawn_player(player_id: String, spawn_pos: Vector2) -> void:
	"""生成指定角色"""
	print("[Arena] _spawn_player 开始: player_id=%s, pos=%s" % [player_id, spawn_pos])
	print("[Arena] Global.selected_player_weapons = %s" % str(Global.selected_player_weapons))
	
	var visual_config = ConfigManager.get_player_visual(player_id)
	print("[Arena] visual_config: %s" % str(visual_config))
	
	var scene_path = visual_config.get("scene_path", "")
	
	if scene_path == "":
		printerr("[Arena] 未找到角色场景路径: %s" % player_id)
		return
	
	print("[Arena] 加载场景: %s" % scene_path)
	var player_scene = load(scene_path) as PackedScene
	if not player_scene:
		printerr("[Arena] 无法加载角色场景: %s" % scene_path)
		return
	
	var new_player = player_scene.instantiate() as PlayerBase
	if not new_player:
		printerr("[Arena] 实例化角色失败: %s" % player_id)
		return
	
	# 重要：在 add_child 之前设置 player_id（这样 _ready 中会使用正确的 ID）
	new_player.player_id = player_id
	print("[Arena] 设置 player_id: %s" % player_id)
	
	new_player.global_position = spawn_pos
	add_child(new_player)
	
	# 恢复角色状态
	Global.restore_player_state(new_player)
	
	# 更新引用
	player = new_player
	Global.player = new_player
	
	# 重新连接信号
	_connect_player_signals()
	
	print("[Arena] 生成角色成功: %s 在位置 %s" % [player_id, spawn_pos])

func _on_player_switch_requested(player_id: String) -> void:
	"""处理角色切换请求"""
	print("[Arena] 收到角色切换请求: %s" % player_id)
	
	if not is_instance_valid(player):
		print("[Arena] 当前玩家无效，尝试直接生成")
		# 尝试在默认位置生成
		_spawn_player(player_id, Vector2(500, 300))
		return
	
	var old_pos = player.global_position
	print("[Arena] 当前玩家位置: %s" % old_pos)
	
	# 清理旧玩家的技能效果
	if player.has_method("_cleanup_skill_effects"):
		player._cleanup_skill_effects()
	
	# 销毁当前角色
	player.queue_free()
	player = null
	
	# 等待一帧确保旧角色被销毁
	await get_tree().process_frame
	
	# 生成新角色
	_spawn_player(player_id, old_pos)

func _input(event: InputEvent) -> void:
	# 1-2-3 键精准切换角色
	if event.is_action_pressed("switch_player_1"):
		_try_switch_to_index(0)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("switch_player_2"):
		_try_switch_to_index(1)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("switch_player_3"):
		_try_switch_to_index(2)
		get_viewport().set_input_as_handled()
	
	# 移除 TAB 键切换逻辑 - 不再响应 switch_player action

# 尝试切换到指定索引的角色
func _try_switch_to_index(index: int) -> void:
	if Global.selected_player_ids.size() == 0:
		return
	
	if not Global.switch_to_player_by_index(index):
		# 切换失败，检查原因
		if Global.is_player_dead(index):
			# 播放无效音效
			_play_invalid_switch_sound()
			# UI 抖动由 SquadHUD 通过信号处理

func _play_invalid_switch_sound() -> void:
	# 播放拒绝音效 - 使用现有的音效或静默
	# 如果有 ui_reject.wav 则播放，否则使用 player_shatter 的变体
	Global.play_sfx(Global.sfx_player_shatter, 1.5, 1.8, -15.0)
