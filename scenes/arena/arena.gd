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
@onready var exit_dialog: ExitConfirmDialog = %ExitConfirmDialog
@onready var shop_panel = $GameUI/ShopPanel  # 商店面板

# 预加载结算界面
const GAME_OVER_SCENE = preload("res://scenes/ui/game_over/game_over_screen.tscn")

var current_chest: ChestSimple = null  # 保存当前打开的宝箱引用
var game_over_screen: GameOverScreen = null  # 结算界面实例

# 波次奖励系统
var wave_reward_system: Node = null
var wave_reward_panel: WaveRewardPanel = null
# 记录当前完成的波次号，用于奖励面板关闭后继续显示商店
var _pending_shop_wave: int = -1

# UI 弹窗栈机制 - 确保多个弹窗不会重叠显示
var ui_panel_stack: Array[Control] = []
# 万能鬼牌选择面板
var wildcard_panel: WildcardPanel = null

func _ready() -> void:
	print("[Arena] _ready() 开始")
	
	# 只在重新进入时重置游戏状态（不是第一次进入）
	# 检查是否已经有敌人存在（表示这不是第一次进入）
	if get_tree().get_nodes_in_group("enemies").size() > 0:
		_reset_game_state()
	
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
	
	# 连接玩家死亡信号（通过健康组件）
	# 注意：需要在玩家初始化后连接
	
	# 连接退出对话框信号
	if exit_dialog:
		exit_dialog.confirmed.connect(_on_exit_confirmed)
		exit_dialog.cancelled.connect(_on_exit_cancelled)
	
	# 连接商店信号
	if shop_panel:
		shop_panel.next_wave_requested.connect(_on_shop_next_wave_requested)
		print("[Arena] 商店面板已连接")
	
	# 初始化波次奖励系统
	_init_wave_reward_system()
	
	# 连接 Spawner 的波次完成信号
	if spawner:
		spawner.wave_completed.connect(_on_wave_completed)
		print("[Arena] Spawner 波次完成信号已连接")
	
	print("[Arena] 准备初始化玩家...")
	# 初始化玩家（如果从选择界面进入）- 使用 await 确保完成
	await _init_player_from_selection()
	print("[Arena] 玩家初始化完成")
	
	# 初始化小队 HUD
	_init_squad_hud()
	
	# 初始化羁绊 HUD
	_init_bond_hud()
	
	# 重置局内数据
	Global.reset_session_data()
	
	# 连接玩家的 XP 和 Gold 信号
	_connect_player_signals()

# ==============================================================================
# 游戏状态重置
# ==============================================================================

func _reset_game_state() -> void:
	"""重置所有游戏状态 - 每次进入 arena 都是新游戏"""
	print("[Arena] 重置游戏状态...")
	
	# 清理所有敌人
	for enemy in get_tree().get_nodes_in_group("enemies"):
		enemy.queue_free()
	
	# 清理所有投射物
	for projectile in get_tree().get_nodes_in_group("projectiles"):
		projectile.queue_free()
	
	# 清理所有物品
	for item in get_tree().get_nodes_in_group("items"):
		item.queue_free()
	
	# 清理所有宝箱
	for chest in get_tree().get_nodes_in_group("chests"):
		chest.queue_free()
	
	# 重置 Spawner
	if spawner:
		spawner.reset_spawner()
	
	# 重置 ChestManager
	if chest_manager:
		chest_manager.reset_chest_manager()
	
	print("[Arena] 游戏状态重置完成")

# ==============================================================================
# 宝箱系统
# ==============================================================================

func _on_chest_opened(chest: ChestSimple) -> void:
	print("[Arena] Chest opened signal received, chest tier: %d" % chest.get_tier())
	SoundManager.play("chest_open")
	
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
		# 连接死亡信号
		if Global.player.health_component:
			if Global.player.health_component.on_unit_died.is_connected(_on_player_died):
				Global.player.health_component.on_unit_died.disconnect(_on_player_died)
			Global.player.health_component.on_unit_died.connect(_on_player_died)
			print("[Arena] 玩家死亡信号已连接")
		
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

func _on_player_died() -> void:
	"""玩家死亡回调（通过信号触发）"""
	print("[Arena] ========== 收到玩家死亡信号 ==========")
	_show_game_over_screen()

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

# 初始化羁绊 HUD
func _init_bond_hud() -> void:
	"""动态创建并添加羁绊 HUD（添加到 GameUI 节点下）"""
	print("[Arena] ===== _init_bond_hud() 开始 =====")
	
	# 获取 GameUI 节点
	var game_ui = get_node_or_null("GameUI")
	if not game_ui:
		printerr("[Arena] ❌ 错误: 找不到 GameUI 节点")
		return
	
	print("[Arena] ✅ 找到 GameUI 节点: %s" % game_ui.get_path())
	
	# 检查是否已经存在 BondHUD
	var existing_bond_hud = game_ui.get_node_or_null("BondHUD")
	if existing_bond_hud:
		print("[Arena] BondHUD 已存在，跳过创建")
		return
	
	# 加载 BondHUD 场景
	var bond_hud_scene = load("res://scenes/ui/bond_hud/bond_hud.tscn")
	if not bond_hud_scene:
		printerr("[Arena] ❌ 错误: 无法加载 BondHUD 场景")
		return
	
	print("[Arena] ✅ BondHUD 场景加载成功")
	
	# 实例化 BondHUD
	var bond_hud = bond_hud_scene.instantiate()
	if not bond_hud:
		printerr("[Arena] ❌ 错误: 无法实例化 BondHUD")
		return
	
	print("[Arena] ✅ BondHUD 实例化成功")
	
	# 添加到 GameUI 节点下（Screen Space）
	game_ui.add_child(bond_hud)
	
	print("[Arena] ✅ BondHUD 已添加到 GameUI")
	print("[Arena] BondHUD 路径: %s" % bond_hud.get_path())
	print("[Arena] BondHUD 可见性: %s" % bond_hud.visible)
	
	# 等待一帧确保节点准备完毕
	await get_tree().process_frame
	
	# 触发 BondManager 重新计算羁绊（使用当前队伍）
	if Global.selected_player_ids.size() > 0:
		print("[Arena] 触发 BondManager 重新计算羁绊...")
		print("[Arena] 当前队伍: %s" % str(Global.selected_player_ids))
		BondManager.recalculate_active_bonds(Global.selected_player_ids)
		print("[Arena] ✅ 羁绊计算完成")
	else:
		print("[Arena] ⚠️ 警告: 没有选择角色，无法计算羁绊")
	
	print("[Arena] ===== _init_bond_hud() 完成 =====")


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
	
	print("[Arena] 创建角色: %s" % player_id)
	var new_player = PlayerFactory.create_player(player_id)
	if not new_player:
		printerr("[Arena] 无法创建角色: %s" % player_id)
		return
	
	# 确保 player_id 被正确设置（防止脚本加载时丢失）
	if new_player.player_id != player_id:
		print("[Arena] 警告: player_id 不匹配，重新设置: %s -> %s" % [new_player.player_id, player_id])
		new_player.player_id = player_id
	
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
	print("[Arena] ===== 角色切换开始 =====")
	print("[Arena] 收到角色切换请求: %s" % player_id)
	
	if not is_instance_valid(player):
		print("[Arena] 当前玩家无效，尝试直接生成")
		# 尝试在默认位置生成
		_spawn_player(player_id, Vector2(500, 300))
		print("[Arena] ===== 角色切换结束 =====")
		return
	
	var old_pos = player.global_position
	var old_player_id = player.player_id if "player_id" in player else "unknown"
	print("[Arena] 当前玩家: %s" % old_player_id)
	print("[Arena] 当前玩家位置: %s" % old_pos)
	
	# P4-2: 图形继承（突击型 Lv.2）
	# 检查是否激活图形继承羁绊
	var should_inherit_ink = BondManager.has_mechanic("ink_inherit")
	
	if should_inherit_ink:
		print("[Arena] [P4-2] 图形继承激活，保留旧角色的画图效果")
		# 不清理技能效果，让它们继续存在
	else:
		# 正常情况：不清理技能效果（这是默认行为）
		print("[Arena] 不清理旧玩家的技能效果（默认行为）")
	
	# 注意：无论是否有图形继承羁绊，我们都不清理技能效果
	# 因为当前架构已经设计为技能效果独立于角色存在
	# 图形继承羁绊的主要作用是：新角色可以引爆旧图形时造成额外伤害
	# 这部分逻辑在 SkillDrawingBase 中实现
	
	# 销毁当前角色
	print("[Arena] 调用 player.queue_free()")
	player.queue_free()
	player = null
	
	# 等待一帧确保旧角色被销毁
	print("[Arena] 等待一帧...")
	await get_tree().process_frame
	print("[Arena] 等待完成，开始生成新角色")
	
	# 生成新角色
	_spawn_player(player_id, old_pos)
	print("[Arena] ===== 角色切换结束 =====")

func _input(event: InputEvent) -> void:
	# ESC 键打开退出确认对话框
	if event.is_action_pressed("ui_cancel"):
		# 检查对话框是否已显示
		if exit_dialog and not exit_dialog.visible:
			_show_exit_dialog()
			get_viewport().set_input_as_handled()
	# Tab 键循环切换角色
	elif event.is_action_pressed("switch_player"):
		_try_switch_to_next()
		get_viewport().set_input_as_handled()
	# 1-2-3 键精准切换角色
	elif event.is_action_pressed("switch_player_1"):
		_try_switch_to_index(0)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("switch_player_2"):
		_try_switch_to_index(1)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("switch_player_3"):
		_try_switch_to_index(2)
		get_viewport().set_input_as_handled()

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

# 循环切换到下一个存活的角色（Tab 键）
func _try_switch_to_next() -> void:
	var squad_size = Global.selected_player_ids.size()
	if squad_size == 0:
		return
	
	var current_index = Global.current_player_index
	var attempts = 0
	
	# 尝试找到下一个存活的角色（最多尝试 squad_size 次）
	while attempts < squad_size:
		var next_index = (current_index + 1 + attempts) % squad_size
		
		# 尝试切换到下一个角色
		if Global.switch_to_player_by_index(next_index):
			# 切换成功
			return
		
		attempts += 1
	
	# 所有角色都无法切换（可能都死亡了）
	_play_invalid_switch_sound()

func _play_invalid_switch_sound() -> void:
	# 播放拒绝音效 - 使用现有的音效或静默
	# 如果有 ui_reject.wav 则播放，否则使用 player_shatter 的变体
	SoundManager.play("ui_error")

# ============================================================================
# 退出确认对话框
# ============================================================================

func _show_exit_dialog() -> void:
	"""显示退出确认对话框"""
	if exit_dialog:
		exit_dialog.show_dialog()

func _on_exit_confirmed() -> void:
	"""玩家确认退出游戏"""
	print("[Arena] 玩家确认退出游戏")
	# 清理所有残留的精英投射物
	_cleanup_all_projectiles()
	# 重置全局状态（包括武器商店购买记录）
	Global.reset_selection()
	Global.reset_session_data()
	# 返回到选择界面
	get_tree().change_scene_to_file("res://scenes/ui/selection_panel/selection_panel.tscn")

func _on_exit_cancelled() -> void:
	"""玩家取消退出"""
	print("[Arena] 玩家取消退出")
	# 对话框已在脚本中恢复游戏状态

# ============================================================================
# 商店系统
# ============================================================================

func _on_wave_completed(wave_number: int) -> void:
	"""波次完成，检查是否触发奖励，然后显示商店"""
	print("[Arena] 波次 %d 完成" % wave_number)
	SoundManager.play("wave_complete")
	
	# 暂停敌人生成
	if spawner:
		spawner.pause_spawning()
	
	# 检查是否触发波次奖励
	if wave_reward_system and wave_reward_system.check_wave_reward(wave_number):
		print("[Arena] 波次 %d 触发三选一奖励" % wave_number)
		_pending_shop_wave = wave_number
		var options = wave_reward_system.generate_reward_options()
		if wave_reward_panel:
			wave_reward_panel.show_rewards(options)
		return
	
	# 没有奖励，直接显示商店
	_show_shop_for_wave(wave_number)

func _on_shop_next_wave_requested() -> void:
	"""商店关闭，开始下一波"""
	print("[Arena] 商店关闭，开始下一波")
	SoundManager.play("shop_close")
	SoundManager.play("wave_start")
	
	# 恢复敌人生成
	if spawner:
		spawner.resume_spawning()

# ============================================================================
# 波次奖励系统
# ============================================================================

func _init_wave_reward_system() -> void:
	"""初始化波次奖励系统、UI 和万能鬼牌面板"""
	# 创建 WaveRewardSystem
	var wrs_script = load("res://scenes/arena/wave_reward_system.gd")
	if wrs_script:
		wave_reward_system = wrs_script.new()
		wave_reward_system.name = "WaveRewardSystem"
		add_child(wave_reward_system)
		print("[Arena] WaveRewardSystem 已创建")
	else:
		printerr("[Arena] 无法加载 WaveRewardSystem 脚本")
		return
	
	# 创建 WaveRewardPanel 并添加到 GameUI（CanvasLayer）
	var game_ui = get_node_or_null("GameUI")
	if game_ui:
		wave_reward_panel = WaveRewardPanel.new()
		wave_reward_panel.name = "WaveRewardPanel"
		wave_reward_panel.wave_reward_system = wave_reward_system
		wave_reward_panel.reward_chosen.connect(_on_wave_reward_chosen)
		game_ui.add_child(wave_reward_panel)
		print("[Arena] WaveRewardPanel 已添加到 GameUI")
		
		# 创建 WildcardPanel 并添加到 GameUI
		wildcard_panel = WildcardPanel.new()
		wildcard_panel.name = "WildcardPanel"
		wildcard_panel.wildcard_assigned.connect(_on_wildcard_assigned)
		game_ui.add_child(wildcard_panel)
		print("[Arena] WildcardPanel 已添加到 GameUI")
	else:
		printerr("[Arena] 找不到 GameUI 节点，无法添加 WaveRewardPanel")
	
	# 监听万能鬼牌分配请求信号
	EmblemManager.wildcard_assignment_requested.connect(_on_wildcard_requested)

func _on_wave_reward_chosen(_reward_data: Dictionary) -> void:
	"""波次奖励选择完成，继续显示商店"""
	print("[Arena] 波次奖励已选择，继续显示商店")
	if _pending_shop_wave >= 0:
		# 奖励面板已恢复游戏暂停，商店会重新暂停
		_show_shop_for_wave(_pending_shop_wave)
		_pending_shop_wave = -1

func _show_shop_for_wave(wave_number: int) -> void:
	"""显示商店面板"""
	if shop_panel:
		SoundManager.play("shop_open")
		shop_panel.show_shop(wave_number + 1)
	else:
		printerr("[Arena] 错误: 找不到 ShopPanel 节点")
		if spawner:
			spawner.resume_spawning()

# ============================================================================
# UI 弹窗栈机制
# ============================================================================

func push_panel(panel: Control) -> void:
	"""将面板压入栈，隐藏当前栈顶面板"""
	if not ui_panel_stack.is_empty():
		ui_panel_stack.back().hide()
	ui_panel_stack.append(panel)
	panel.show()
	get_tree().paused = true

func pop_panel() -> void:
	"""弹出栈顶面板，恢复上一个面板或解除暂停"""
	if ui_panel_stack.is_empty():
		return
	var top = ui_panel_stack.pop_back()
	top.hide()
	if ui_panel_stack.is_empty():
		get_tree().paused = false  # 栈空，恢复游戏
	else:
		ui_panel_stack.back().show()  # 恢复上一个面板

# ============================================================================
# 万能鬼牌信号处理
# ============================================================================

func _on_wildcard_requested(emblem_data: Dictionary) -> void:
	"""EmblemManager 发出万能鬼牌分配请求，push WildcardPanel"""
	print("[Arena] 收到万能鬼牌分配请求")
	if wildcard_panel:
		wildcard_panel.show_wildcard_selection(emblem_data)
		push_panel(wildcard_panel)

func _on_wildcard_assigned() -> void:
	"""WildcardPanel 选择完毕，pop 面板"""
	print("[Arena] 万能鬼牌分配完成")
	pop_panel()
	# 触发羁绊重算
	if Global.selected_player_ids.size() > 0:
		BondManager.recalculate_active_bonds(Global.selected_player_ids)

# ============================================================================
# 游戏结算系统
# ============================================================================

func _show_game_over_screen() -> void:
	"""显示游戏结算界面"""
	print("[Arena] ========== 显示游戏结算界面 ==========")
	print("[Arena] Global.is_game_over: %s" % Global.is_game_over)
	print("[Arena] Global.player 有效: %s" % is_instance_valid(Global.player))
	
	# 清理所有残留的精英投射物
	_cleanup_all_projectiles()
	
	# 防止重复显示
	if game_over_screen:
		print("[Arena] 结算界面已存在，跳过")
		return
	
	SoundManager.play("game_over")
	
	# 实例化结算界面
	print("[Arena] 实例化结算界面...")
	game_over_screen = GAME_OVER_SCENE.instantiate()
	add_child(game_over_screen)
	print("[Arena] 结算界面已添加到场景树")
	
	# 收集统计数据
	var stats_data = {
		"kills": Global.session_kills,
		"gold": Global.session_gold
	}
	
	print("[Arena] 结算数据 - 击杀: %d, 金币: %d" % [stats_data.kills, stats_data.gold])
	
	# 设置数据并显示
	game_over_screen.set_stats(stats_data)
	game_over_screen.show_screen()
	print("[Arena] ========== 结算界面显示完成 ==========")

func _cleanup_all_projectiles() -> void:
	"""清理所有残留在根节点上的精英投射物"""
	var cleaned = 0
	for group_name in ["elite_projectiles", "projectiles"]:
		var nodes = get_tree().get_nodes_in_group(group_name)
		for node in nodes:
			if is_instance_valid(node):
				node.queue_free()
				cleaned += 1
	if cleaned > 0:
		print("[Arena] 清理了 %d 个残留投射物" % cleaned)

func _notification(what: int) -> void:
	# 场景树退出时也清理投射物
	if what == NOTIFICATION_PREDELETE or what == NOTIFICATION_EXIT_TREE:
		if is_inside_tree():
			_cleanup_all_projectiles()
