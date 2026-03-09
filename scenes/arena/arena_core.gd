extends Node2D
class_name ArenaCore

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
@onready var pause_menu: PauseMenu = null  # 暂停菜单（动态创建）

# 预加载结算界面和暂停菜单
const GAME_OVER_SCENE = preload("res://scenes/ui/game_over/game_over_screen.tscn")
const PAUSE_MENU_SCENE = preload("res://scenes/ui/pause_menu/pause_menu.tscn")
const WAVE_REWARD_PANEL_SCENE = preload("res://scenes/ui/wave_reward/wave_reward_panel.tscn")
const WILDCARD_PANEL_SCENE = preload("res://scenes/ui/wildcard/wildcard_panel.tscn")
const ENABLE_LEGACY_CHEST_SYSTEM: bool = false

var current_chest: ChestSimple = null  # 保存当前打开的宝箱引用
var game_over_screen: GameOverScreen = null  # 结算界面实例

# 波次奖励系统
var wave_reward_system: Node = null
var wave_reward_panel: WaveRewardPanel = null
# 流程编排控制器
var battle_flow_controller: BattleFlowController = null

# UI 弹窗栈机制 - 确保多个弹窗不会重叠显示
var ui_panel_stack: Array[Control] = []
# 万能鬼牌选择面板
var wildcard_panel: WildcardPanel = null

# 初始化保护标志 - 防止初始化期间产生飘字
var _arena_initialized: bool = false
var _pending_levelup_rewards: Array[Dictionary] = []

func _ready() -> void:
	print("[Arena] _ready() 开始")
	
	# 确保 Arena 在 "arena" 组中
	if not is_in_group("arena"):
		add_to_group("arena")
		print("[Arena] 已添加到 arena 组")
	
	# 清理上一局残留在 root 节点上的飘字（FloatingText 被添加到 root，跨场景不会自动销毁）
	_cleanup_stale_floating_texts()
	
	# 只在重新进入时重置游戏状态（不是第一次进入）
	# 检查是否已经有敌人存在（表示这不是第一次进入）
	# 注意：重新开始游戏时会调用 reload_current_scene()，不会触发这个逻辑
	var existing_enemies = get_tree().get_nodes_in_group("enemies")
	if existing_enemies.size() > 0:
		print("[Arena] 检测到残留敌人，执行清理")
		_reset_game_state()
	
	# 将角色添加到全局变量中
	#Global.player = player
	# 先断开旧连接（防止跨场景重复连接）
	if Global.on_create_block_text.is_connected(_on_create_block_text):
		Global.on_create_block_text.disconnect(_on_create_block_text)
	if Global.on_create_damage_text.is_connected(_on_create_damage_text):
		Global.on_create_damage_text.disconnect(_on_create_damage_text)
	# 闪避飘字信号 Unit类 _on_hurtbox_component_on_damaged 调用
	Global.on_create_block_text.connect(_on_create_block_text)
	# 伤害飘字信号
	Global.on_create_damage_text.connect(_on_create_damage_text)
	
	# 配置战利品流程（旧宝箱流程 / 波末战利品流程）
	_setup_loot_flow_mode()

	# 连接成长系统升级事件（XP 升级触发三选一）
	var progression: Node = get_node_or_null("/root/ProgressionManager")
	if progression and progression.has_signal("level_up"):
		var level_up_callable: Callable = Callable(self, "_on_progression_level_up")
		if progression.is_connected("level_up", level_up_callable):
			progression.disconnect("level_up", level_up_callable)
		progression.connect("level_up", level_up_callable)
	
	# 连接角色切换信号
	Global.on_player_switch_requested.connect(_on_player_switch_requested)
	
	# 连接玩家死亡信号（通过健康组件）
	# 注意：需要在玩家初始化后连接
	
	# 连接退出对话框信号
	if exit_dialog:
		exit_dialog.confirmed.connect(_on_exit_confirmed)
		exit_dialog.cancelled.connect(_on_exit_cancelled)
	
	# 初始化暂停菜单
	_init_pause_menu()
	
	# 连接商店信号
	if shop_panel:
		shop_panel.next_wave_requested.connect(_on_shop_next_wave_requested)
		print("[Arena] 商店面板已连接")
	
	# 初始化波次奖励系统
	_init_wave_reward_system()
	_init_battle_flow_controller()
	
	# 连接 Spawner 的波次完成信号
	if spawner:
		spawner.wave_completed.connect(_on_wave_completed)
		print("[Arena] Spawner 波次完成信号已连接")
	
	print("[Arena] 准备初始化玩家...")
	# 初始化玩家（如果从选择界面进入）- 使用 await 确保完成
	await _init_player_from_selection()
	print("[Arena] 玩家初始化完成")
	
	# 检查是否需要恢复战斗状态
	if not Global.pending_battle_state.is_empty():
		print("[Arena] 检测到待恢复的战斗状态")
		await _restore_battle_state()
		Global.pending_battle_state = {}  # 清除待恢复状态
	else:
		# 只有在不恢复战斗状态时才重置局内数据
		Global.reset_session_data()

	_pending_levelup_rewards.clear()
	
	# 初始化小队 HUD
	_init_squad_hud()
	_start_run_telemetry()
	
	# 初始化羁绊 HUD
	_init_bond_hud()
	
	# 连接玩家的 XP 和 Gold 信号
	_connect_player_signals()
	
	# 标记初始化完成 - 此后飘字正常显示
	_arena_initialized = true
	print("[Arena] _ready() 完成，飘字保护已解除")

func _init_battle_flow_controller() -> void:
	battle_flow_controller = BattleFlowController.new()
	battle_flow_controller.setup(spawner, shop_panel, wave_reward_system, wave_reward_panel)
	print("[Arena] BattleFlowController 已初始化")

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

func _cleanup_stale_floating_texts() -> void:
	"""清理残留在 root 节点上的飘字实例
	create_floating_text() 将飘字添加到 get_tree().root，
	这些节点不会随场景切换自动销毁，切换存档后可能残留。"""
	var cleaned := 0
	for child in get_tree().root.get_children():
		if child is FloatingText:
			child.queue_free()
			cleaned += 1
	if cleaned > 0:
		print("[Arena] 清理了 %d 个残留飘字" % cleaned)

func _setup_loot_flow_mode() -> void:
	if upgrade_ui and not upgrade_ui.upgrade_selected.is_connected(_on_upgrade_selected):
		upgrade_ui.upgrade_selected.connect(_on_upgrade_selected)

	if ENABLE_LEGACY_CHEST_SYSTEM:
		if chest_manager and not chest_manager.chest_opened.is_connected(_on_chest_opened):
			chest_manager.chest_opened.connect(_on_chest_opened)
		if chest_indicator and chest_manager:
			chest_indicator.set_chest_manager(chest_manager)
		return

	print("[Arena] 已启用波末战利品模式，禁用旧宝箱流程")

	if chest_indicator:
		chest_indicator.visible = false
		chest_indicator.set_process(false)

	if upgrade_ui:
		upgrade_ui.visible = false
		upgrade_ui.set_process(false)

	if chest_manager:
		for chest in get_tree().get_nodes_in_group("chests"):
			chest.queue_free()
		chest_manager.set_process(false)
		chest_manager.set_physics_process(false)
		chest_manager.visible = false

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

	# 消费下一条等级升级奖励（如有）
	_try_show_pending_levelup_upgrade()

func record_enemy_wave_loot_drop(enemy_id: String, is_elite: bool) -> void:
	if not wave_reward_system:
		return
	if wave_reward_system.has_method("record_enemy_drop"):
		var wave_number := spawner.wave_index if spawner else 1
		wave_reward_system.record_enemy_drop(enemy_id, is_elite, wave_number)

func _process(delta: float) -> void:
	if Global.game_paused: return

	_try_show_pending_levelup_upgrade()
	
	# 更新 Global HUD 波次信息
	if global_hud and spawner and spawner.wave_timer and not spawner.wave_timer.is_stopped():
		global_hud.set_wave_text(spawner.get_wave_text())
		global_hud.set_wave_time_text(spawner.get_wave_timer_text())

func _on_progression_level_up(level: int, reward_tier: int, total_xp: int) -> void:
	_pending_levelup_rewards.append({
		"level": level,
		"tier": reward_tier,
		"xp": total_xp
	})
	_try_show_pending_levelup_upgrade()

func _try_show_pending_levelup_upgrade() -> void:
	if _pending_levelup_rewards.is_empty():
		return
	if Global.game_paused:
		return
	if not wave_reward_system:
		return
	if not wave_reward_system.has_method("show_levelup_reward"):
		return

	var reward_data: Dictionary = _pending_levelup_rewards.pop_front()
	wave_reward_system.show_levelup_reward(
		int(reward_data.get("tier", 1)),
		int(reward_data.get("level", 1)),
		int(reward_data.get("xp", 0))
	)

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
	if not _arena_initialized:
		return
	var text := create_floating_text(unit)
	text.setup("闪!",blockedl_color)
	

# 创建伤害飘字
func _on_create_damage_text(uinit:Node2D,hitbox:HitboxComponent) -> void:
	if not _arena_initialized:
		return
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
	_finish_run_telemetry(false, "player_died")
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
		
		# 将羁绊属性加成应用到当前玩家
		if is_instance_valid(Global.player) and Global.player.has_method("apply_bond_stat_modifiers"):
			Global.player.apply_bond_stat_modifiers()
			print("[Arena] ✅ 羁绊属性已应用到玩家")
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

	# 新开局启用波次招募模式：开局仅1人上场，后续波次再招募扩编。
	# 读取存档恢复战斗时不改动队伍，保持存档状态。
	if Global.pending_battle_state.is_empty():
		Global.enter_wave_recruit_mode()
	
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

	var resonance_service: Node = get_node_or_null("/root/ResonanceRuntimeService")
	if resonance_service and resonance_service.has_method("on_player_activated"):
		resonance_service.call("on_player_activated", new_player)
	
	print("[Arena] 生成角色成功: %s 在位置 %s" % [player_id, spawn_pos])

func _on_player_switch_requested(player_id: String) -> void:
	"""处理角色切换请求"""
	print("[Arena] ===== 角色切换开始 =====")
	print("[Arena] 收到角色切换请求: %s" % player_id)
	_reset_bullet_time_state()
	
	# 角色切换前自动保存进度
	_auto_save_progress("character_switch")
	
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

	if player.has_method("_force_deactivate_ultimate_on_exit"):
		player.call("_force_deactivate_ultimate_on_exit")

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
	
	# 重新应用羁绊属性加成到新角色
	if is_instance_valid(Global.player) and Global.player.has_method("apply_bond_stat_modifiers"):
		# 重新计算羁绊（角色切换可能影响标签统计）
		BondManager.recalculate_active_bonds(Global.selected_player_ids)
		Global.player.apply_bond_stat_modifiers()
		print("[Arena] ✅ 角色切换后羁绊属性已重新应用")
	
	print("[Arena] ===== 角色切换结束 =====")

func _auto_save_progress(trigger: String) -> void:
	if Global.has_meta("qef_test_mode_active") and bool(Global.get_meta("qef_test_mode_active")):
		print("[Arena] 跳过自动保存（QEF测试模式）: %s" % trigger)
		return

	var slot_index: int = Global.current_save_slot
	if slot_index < 0:
		return
	
	print("[Arena] 自动保存进度: %s" % trigger)
	var wave_number := spawner.wave_index if spawner else 1
	var ok := false
	if battle_flow_controller:
		ok = battle_flow_controller.auto_save_progress(slot_index, wave_number, trigger)
	else:
		ok = SaveFacade.save_progress(slot_index, {
			"trigger": trigger,
			"current_wave": wave_number
		})
	if ok:
		print("[Arena] 自动保存完成: 槽位 %d, 触发: %s" % [slot_index, trigger])
	else:
		push_warning("[Arena] 自动保存失败: 槽位 %d, 触发: %s" % [slot_index, trigger])

func _start_run_telemetry() -> void:
	var telemetry: Node = get_node_or_null("/root/RunTelemetryService")
	if not telemetry:
		return
	if telemetry.has_method("begin_run"):
		telemetry.call("begin_run", Global.selected_player_ids, Global.selected_player_weapons)

func _record_wave_telemetry(wave_number: int) -> void:
	var telemetry: Node = get_node_or_null("/root/RunTelemetryService")
	if not telemetry:
		return
	if telemetry.has_method("record_wave_completed"):
		telemetry.call("record_wave_completed", wave_number)

func _finish_run_telemetry(cleared: bool, reason: String) -> void:
	var telemetry: Node = get_node_or_null("/root/RunTelemetryService")
	if not telemetry:
		return
	if telemetry.has_method("end_run"):
		telemetry.call("end_run", cleared, reason)

func _input(event: InputEvent) -> void:
	# ESC 键打开暂停菜单
	if event.is_action_pressed("ui_cancel"):
		# 检查暂停菜单是否已显示
		if pause_menu and not pause_menu.is_visible_menu:
			_show_pause_menu()
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

func _init_pause_menu() -> void:
	"""初始化暂停菜单"""
	var game_ui = get_node_or_null("GameUI")
	if not game_ui:
		printerr("[Arena] 找不到 GameUI 节点")
		return
	
	# 创建暂停菜单
	pause_menu = PAUSE_MENU_SCENE.instantiate()
	pause_menu.name = "PauseMenu"
	game_ui.add_child(pause_menu)
	
	# 连接信号
	pause_menu.resume_requested.connect(_on_pause_resume)
	pause_menu.restart_requested.connect(_on_pause_restart)
	pause_menu.end_run_requested.connect(_on_pause_end_run)
	pause_menu.codex_requested.connect(_on_pause_codex)
	pause_menu.settings_requested.connect(_on_pause_settings)
	pause_menu.return_to_menu_requested.connect(_on_pause_return_to_menu)
	
	print("[Arena] 暂停菜单已初始化")

func _show_pause_menu() -> void:
	"""显示暂停菜单"""
	if pause_menu:
		pause_menu.show_menu()

func _on_pause_resume() -> void:
	"""继续游戏"""
	print("[Arena] 继续游戏")
	# 暂停菜单已经恢复了游戏状态

func _on_pause_restart() -> void:
	"""重新开始当前关卡"""
	print("[Arena] 重新开始当前关卡")
	_finish_run_telemetry(false, "restart")
	PauseService.clear_all(get_tree())
	# 清理所有残留的投射物
	_cleanup_all_projectiles()
	# 重置全局会话数据
	Global.reset_session_data()
	# 清除待恢复的战斗状态（如果有）
	Global.pending_battle_state = {}
	# 重新加载场景（场景的 _ready() 会自动初始化所有内容）
	get_tree().reload_current_scene()

func _on_pause_end_run() -> void:
	"""结束本轮游戏 - 返回角色选择界面"""
	print("[Arena] 结束本轮游戏，返回角色选择界面")
	_finish_run_telemetry(false, "end_run")
	prepare_run_exit_cleanup()
	# 清理所有残留的投射物
	_cleanup_all_projectiles()
	# 清除战斗状态（不保存）
	Global.reset_selection()
	Global.reset_session_data()
	# 清除存档槽位中的战斗状态
	if Global.current_save_slot >= 0:
		if battle_flow_controller:
			battle_flow_controller.clear_battle_state(Global.current_save_slot)
		else:
			SaveFacade.clear_battle_state(Global.current_save_slot)
	# 返回角色选择界面
	get_tree().change_scene_to_file("res://scenes/ui/selection_panel/selection_panel.tscn")

func _on_pause_codex() -> void:
	"""打开图鉴"""
	print("[Arena] 打开图鉴（待实现）")
	# TODO: 实现图鉴界面

func _on_pause_settings() -> void:
	"""打开设置"""
	print("[Arena] 打开设置（待实现）")
	# TODO: 实现设置界面

func _on_pause_return_to_menu() -> void:
	"""返回主菜单 - 保存完整战斗状态"""
	print("[Arena] 返回主菜单，保存完整战斗状态")
	_finish_run_telemetry(false, "return_to_menu")
	# 保存完整的战斗状态
	_save_full_battle_state()
	prepare_run_exit_cleanup()
	# 清理所有残留的投射物
	_cleanup_all_projectiles()
	# 重置全局状态（但不清除存档槽位）
	Global.reset_selection()
	Global.reset_session_data()
	# 返回主菜单
	get_tree().change_scene_to_file("res://scenes/ui/main_menu/main_menu_root.tscn")

func _save_full_battle_state() -> void:
	"""保存完整的战斗状态到存档"""
	var slot_index: int = Global.current_save_slot
	if slot_index < 0:
		print("[Arena] 没有选择存档槽位，跳过保存")
		return
	
	print("[Arena] 保存完整战斗状态到槽位 %d" % slot_index)
	var wave_number := spawner.wave_index if spawner else 1
	var ok := false
	if battle_flow_controller:
		ok = battle_flow_controller.save_full_battle_state(slot_index, wave_number)
	else:
		ok = SaveFacade.save_battle_snapshot(slot_index, {
			"trigger": "return_to_menu",
			"current_wave": wave_number
		})
	if ok:
		print("[Arena] 完整战斗状态已保存")
	else:
		push_warning("[Arena] 完整战斗状态保存失败: 槽位 %d" % slot_index)

func _restore_battle_state() -> void:
	"""恢复完整的战斗状态"""
	print("[Arena] 开始恢复战斗状态...")
	BattleStateManager.restore_battle_state(Global.pending_battle_state)
	print("[Arena] 战斗状态恢复完成")

func _show_exit_dialog() -> void:
	"""显示退出确认对话框"""
	if exit_dialog:
		exit_dialog.show_dialog()

func _on_exit_confirmed() -> void:
	"""玩家确认退出游戏"""
	print("[Arena] 玩家确认退出游戏")
	_finish_run_telemetry(false, "exit_to_menu")
	prepare_run_exit_cleanup()
	# 清理所有残留的精英投射物
	_cleanup_all_projectiles()
	# 保存当前进度到存档槽位
	_save_progress_before_exit()
	# 重置全局状态（包括武器商店购买记录）
	# 注意：重置 current_save_slot，让玩家回到主菜单而不是存档选择界面
	Global.reset_selection()
	Global.reset_session_data()
	Global.current_save_slot = -1  # 重置存档槽位
	# 清除角色选择缓存，确保回到主菜单时不会自动加载
	_clear_selection_cache()
	_clear_weapon_cache()
	# 返回到主菜单（而不是角色选择界面）
	get_viewport().set_input_as_handled()
	get_tree().change_scene_to_file("res://scenes/ui/main_menu/main_menu_root.tscn")

func _on_exit_cancelled() -> void:
	"""玩家取消退出"""
	print("[Arena] 玩家取消退出")
	# 对话框已在脚本中恢复游戏状态

func _save_progress_before_exit() -> void:
	"""退出前保存当前进度到存档槽位，并同步选角缓存"""
	var slot_index: int = Global.current_save_slot
	if slot_index < 0:
		print("[Arena] 没有选择存档槽位，跳过保存")
		return
	
	var wave_number := spawner.wave_index if spawner else 1
	var ok := false
	if battle_flow_controller:
		ok = battle_flow_controller.save_progress_before_exit(slot_index, wave_number)
	else:
		ok = SaveFacade.save_progress(slot_index, {
			"trigger": "exit_to_menu",
			"current_wave": wave_number
		})
	if ok:
		print("[Arena] 进度已保存到槽位 %d" % slot_index)
	else:
		push_warning("[Arena] 退出前保存失败: 槽位 %d" % slot_index)
	
	# 同步角色选择缓存和武器缓存，确保回到 SelectionPanel 时数据一致
	_sync_selection_cache_from_global()

func _build_save_data() -> Dictionary:
	"""构建完整的存档数据
	
	Returns:
		存档数据字典
	"""
	var data: Dictionary = {
		# 基础进度
		"current_wave": spawner.wave_index if spawner else 1,
		"current_floor": 1,
		"play_time_seconds": 0,  # TODO: 实现游戏时间统计
		"game_state": "in_progress",
		
		# 角色数据
		"selected_players": _save_player_data(),
		"leader_id": Global.selected_player_ids[0] if Global.selected_player_ids.size() > 0 else "",
		"current_player_index": Global.current_player_index,
		
		# 队伍状态
		"player_states": Global.player_states.duplicate(true),
		
		# 金币和经验
		"gold": DataManager.get_total_gold(),
		"session_xp": Global.session_xp,
		"session_kills": Global.session_kills,
		"session_gold": Global.session_gold,
		
		# 羁绊数据
		"bond_summary": BondManager.get_bond_summary(),
		"bond_counts": BondManager.current_bond_counts.duplicate(true),
		
		# 装备数据
		"equipment": _get_equipment_data(),
		
		# 仓库数据
		"warehouse": _get_warehouse_data(),
		
		# 升级数据
		"upgrades": DataManager.save_data.upgrades.duplicate(true),
		
		# 徽章数据
		"emblems": EmblemManager.serialize(),
		
		# 修改器数据
		"modifiers": ModifierManager.serialize(),
	}
	
	return data

func _get_equipment_data() -> Dictionary:
	"""获取装备数据
	
	Returns:
		装备数据字典
	"""
	var equipment_data: Dictionary = {}
	for pid in Global.selected_player_ids:
		var item_data = EquipmentManager.get_equipped_item_data(pid)
		if not item_data.is_empty():
			equipment_data[pid] = item_data
	return equipment_data

func _get_warehouse_data() -> Dictionary:
	"""获取仓库数据
	
	Returns:
		仓库数据字典
	"""
	return {
		"items": WarehouseManager.get_all_items(),
		"capacity": WarehouseManager.get_capacity()
	}

func _save_player_data() -> Array:
	"""保存所有角色的数据
	
	Returns:
		角色数据数组
	"""
	var players_data: Array = []
	
	for pid in Global.selected_player_ids:
		var state = Global.get_player_state(pid)
		var weapon_type = Global.selected_player_weapons.get(pid, "")
		
		players_data.append({
			"player_id": pid,
			"weapon_type": weapon_type,
			"health": state.get("health", 100),
			"max_health": state.get("max_health", 100),
			"energy": state.get("energy", 100),
			"max_energy": state.get("max_energy", 100),
			"armor": state.get("armor", 0),
			"is_dead": state.get("health", 100) <= 0,
		})
	
	return players_data

func _sync_selection_cache_from_global() -> void:
	"""将当前 Global 的角色/武器数据写入 SelectionPanel 的缓存文件"""
	if battle_flow_controller:
		battle_flow_controller.sync_selection_cache()
	else:
		SaveFacade.sync_selection_cache_from_runtime()
	print("[Arena] 已同步角色/武器缓存")

func _clear_selection_cache() -> void:
	"""清除角色选择缓存文件"""
	if battle_flow_controller:
		battle_flow_controller.clear_selection_cache_files()
	else:
		SaveFacade.clear_selection_cache_files()
	print("[Arena] 已清除角色选择缓存")

func _clear_weapon_cache() -> void:
	"""清除武器选择缓存文件"""
	if battle_flow_controller:
		battle_flow_controller.clear_selection_cache_files()
	else:
		SaveFacade.clear_selection_cache_files()
	print("[Arena] 已清除武器选择缓存")

# ============================================================================
# 商店系统
# ============================================================================

func _on_wave_completed(wave_number: int) -> void:
	"""波次完成，检查是否触发奖励，然后显示商店"""
	_reset_bullet_time_state()
	print("[Arena] 波次 %d 完成" % wave_number)
	_cleanup_wave_end_player_effects()
	Global.refill_squad_after_wave()
	_record_wave_telemetry(wave_number)
	if battle_flow_controller:
		battle_flow_controller.on_wave_completed(wave_number)
		return

	SoundManager.play("wave_complete")
	
	# 暂停敌人生成
	if spawner:
		spawner.pause_spawning()
	
	# 检查是否触发波次奖励
	if wave_reward_system and wave_reward_system.check_wave_reward(wave_number):
		print("[Arena] 波次 %d 触发三选一奖励" % wave_number)
		var options = wave_reward_system.generate_reward_options()
		if wave_reward_panel:
			wave_reward_panel.show_rewards(options)
		return
	
	# 没有奖励，直接显示商店
	_show_shop_for_wave(wave_number)

func _cleanup_wave_end_player_effects() -> void:
	# Wave-end cleanup for active player runtime effects.
	if not is_instance_valid(Global.player):
		_cleanup_wave_end_global_skill_effects()
		return
	var player_node: Node = Global.player
	if player_node.has_method("_cancel_active_planning_skills"):
		player_node.call("_cancel_active_planning_skills", false)
	if player_node.has_method("_force_deactivate_ultimate_on_exit"):
		player_node.call("_force_deactivate_ultimate_on_exit")
	if player_node.has_method("_cleanup_skill_effects"):
		player_node.call("_cleanup_skill_effects")
	_cleanup_wave_end_global_skill_effects()

func _cleanup_wave_end_global_skill_effects() -> void:
	# Cleanup global skill effects managed by autoloads and ad-hoc scene nodes.
	if SkillEffectManager and SkillEffectManager.has_method("clear_all_effects"):
		SkillEffectManager.clear_all_effects()

	for node in get_tree().get_nodes_in_group("player_skill_effects"):
		if is_instance_valid(node):
			node.queue_free()

	var current_scene: Node = get_tree().current_scene
	if not is_instance_valid(current_scene):
		return

	# 清理 SkillDrawingBase 的永久围栏缓存与节点。
	if current_scene.has_meta("active_cages"):
		var active_cages_raw: Variant = current_scene.get_meta("active_cages")
		if active_cages_raw is Array:
			var active_cages: Array = active_cages_raw
			for cage in active_cages:
				if is_instance_valid(cage):
					cage.queue_free()
		current_scene.remove_meta("active_cages")

	for child in current_scene.get_children():
		if not is_instance_valid(child):
			continue
		var node_name: String = String(child.name)
		if node_name.begins_with("ClosureMask_") or node_name == "MaskLifecycleManager" or node_name == "PermanentCage":
			child.queue_free()

func _on_shop_next_wave_requested() -> void:
	"""商店关闭，开始下一波"""
	_reset_bullet_time_state()
	print("[Arena] 商店关闭，开始下一波")
	if battle_flow_controller:
		var slot_index := Global.current_save_slot
		var wave_number := spawner.wave_index if spawner else 1
		battle_flow_controller.on_shop_next_wave_requested(slot_index, wave_number)
		return

	SoundManager.play("shop_close")
	SoundManager.play("wave_start")
	
	# 商店关闭时自动保存进度（Brotato 风格）
	_auto_save_progress("shop_closed")
	
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
		wave_reward_panel = WAVE_REWARD_PANEL_SCENE.instantiate() as WaveRewardPanel
		if wave_reward_panel == null:
			wave_reward_panel = WaveRewardPanel.new()
		wave_reward_panel.name = "WaveRewardPanel"
		wave_reward_panel.wave_reward_system = wave_reward_system
		wave_reward_panel.reward_chosen.connect(_on_wave_reward_chosen)
		game_ui.add_child(wave_reward_panel)
		print("[Arena] WaveRewardPanel 已添加到 GameUI")
		
		# 创建 WildcardPanel 并添加到 GameUI
		wildcard_panel = WILDCARD_PANEL_SCENE.instantiate() as WildcardPanel
		if wildcard_panel == null:
			wildcard_panel = WildcardPanel.new()
		wildcard_panel.name = "WildcardPanel"
		wildcard_panel.wildcard_assigned.connect(_on_wildcard_assigned)
		game_ui.add_child(wildcard_panel)
		print("[Arena] WildcardPanel 已添加到 GameUI")
	else:
		printerr("[Arena] 找不到 GameUI 节点，无法添加 WaveRewardPanel")
	
	# 监听万能鬼牌分配请求信号
	EmblemManager.wildcard_assignment_requested.connect(_on_wildcard_requested)

func _on_wave_reward_chosen(reward_data: Dictionary) -> void:
	"""波次奖励选择完成，继续显示商店"""
	_after_wave_reward_chosen(reward_data)
	print("[Arena] 波次奖励已选择，继续显示商店")
	if battle_flow_controller:
		battle_flow_controller.on_wave_reward_chosen(reward_data)
		return

func _after_wave_reward_chosen(reward_data: Dictionary) -> void:
	var reward_type: String = str(reward_data.get("type", ""))
	if reward_type != "recruit" and reward_type != "recruit_replace":
		return

	# 招募后刷新小队槽位，立即可见 1->2->3 的扩编结果
	_init_squad_hud()
	for i in range(Global.selected_player_ids.size()):
		Global.notify_squad_state_changed(i)

	# 招募会改变队伍标签，给当前激活角色重新套用羁绊加成
	if is_instance_valid(Global.player) and Global.player.has_method("apply_bond_stat_modifiers"):
		Global.player.apply_bond_stat_modifiers()
		print("[Arena] 招募后已刷新 HUD 与羁绊属性")

func _show_shop_for_wave(wave_number: int) -> void:
	"""显示商店面板"""
	if battle_flow_controller:
		battle_flow_controller.show_shop_for_wave(wave_number)
		return

	if shop_panel:
		SoundManager.play("shop_open")
		shop_panel.show_shop(wave_number + 1)
	else:
		printerr("[Arena] 错误: 找不到 ShopPanel 节点")
		if spawner:
			spawner.resume_spawning()

func _reset_bullet_time_state() -> void:
	"""兜底重置子弹时间与Q规划状态，避免切波/切场景后残留慢速"""
	Engine.time_scale = 1.0
	if is_instance_valid(player):
		var sm = player.get_node_or_null("SkillManager")
		if sm and sm.has_method("force_cancel_planning_skills"):
			sm.call("force_cancel_planning_skills", false)

# ============================================================================
# UI 弹窗栈机制
# ============================================================================

func push_panel(panel: Control) -> void:
	"""将面板压入栈，隐藏当前栈顶面板"""
	if not ui_panel_stack.is_empty():
		ui_panel_stack.back().hide()
	ui_panel_stack.append(panel)
	panel.show()
	PauseService.request_pause("ui_panel:%s" % panel.name, get_tree())

func pop_panel() -> void:
	"""弹出栈顶面板，恢复上一个面板或解除暂停"""
	if ui_panel_stack.is_empty():
		return
	var top = ui_panel_stack.pop_back()
	top.hide()
	PauseService.release_pause("ui_panel:%s" % top.name, get_tree())
	if not ui_panel_stack.is_empty():
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
	_cleanup_wave_end_player_effects()
	
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
	
	# 结算局内货币：按规则发放局外碎片，run_gold 清零
	var settlement = MetaProgressService.settle_from_run(RunStateService.get_session_gold())

	# 收集统计数据
	var stats_data = {
		"kills": Global.session_kills,
		"soul_shard": int(settlement.get("soul_shard_gain", 0)),
		"run_gold": int(settlement.get("run_gold_before", 0))
	}
	
	print("[Arena] 结算数据 - 击杀: %d, 获得碎片: %d, run_gold结算前: %d" % [
		stats_data.kills,
		stats_data.soul_shard,
		stats_data.run_gold
	])
	
	# 设置数据并显示
	game_over_screen.set_stats(stats_data)
	game_over_screen.show_screen()
	_save_progress_on_run_failed()
	print("[Arena] ========== 结算界面显示完成 ==========")

func _save_progress_on_run_failed() -> void:
	# Persist failed-run state so main-menu slot info stays consistent.
	var slot_index: int = Global.current_save_slot
	if slot_index < 0:
		return

	var wave_number: int = spawner.wave_index if spawner else 1

	# 失败后槽位与返回选角都只保留开局角色（队长）。
	var leader_id: String = ""
	if Global.has_method("get_leader_player_id"):
		leader_id = str(Global.get_leader_player_id())
	if leader_id.is_empty() and Global.selected_player_ids.size() > 0:
		leader_id = str(Global.selected_player_ids[0])

	var leader_weapon: String = str(Global.selected_player_weapons.get(leader_id, ""))
	if not leader_id.is_empty() and leader_weapon.is_empty():
		var weapon_types: Array[String] = ConfigManager.get_player_available_weapon_types(leader_id)
		if weapon_types.size() > 0:
			leader_weapon = weapon_types[0]

	var backup_ids: Array[String] = Global.selected_player_ids.duplicate()
	var backup_weapons: Dictionary = Global.selected_player_weapons.duplicate(true)
	if not leader_id.is_empty():
		Global.selected_player_ids.clear()
		Global.selected_player_ids.append(leader_id)
		Global.selected_player_weapons.clear()
		if not leader_weapon.is_empty():
			Global.selected_player_weapons[leader_id] = leader_weapon

	var save_ok: bool = SaveFacade.save_progress(slot_index, {
		"trigger": "run_failed",
		# 失败后回到选角，槽位显示应归位到局外状态。
		"current_floor": 1,
		"current_wave": 1,
		"last_failed_wave": wave_number,
		"game_state": "character_selection",
		"battle_state": {}
	})
	var clear_ok: bool = SaveFacade.clear_battle_state(slot_index)

	# 恢复运行时队伍数据（避免影响本局结算界面展示与后续逻辑）。
	Global.selected_player_ids = backup_ids
	Global.selected_player_weapons = backup_weapons

	if save_ok and clear_ok:
		print("[Arena] 失败结算进度已保存: slot=%d wave=%d" % [slot_index, wave_number])
	else:
		push_warning("[Arena] 失败结算进度保存异常: slot=%d save=%s clear=%s" % [
			slot_index,
			str(save_ok),
			str(clear_ok)
		])

func _cleanup_all_projectiles() -> void:
	"""清理所有残留在根节点上的精英投射物"""
	var cleaned = 0
	for group_name in ["elite_projectiles", "projectiles", "player_skill_effects"]:
		var nodes = get_tree().get_nodes_in_group(group_name)
		for node in nodes:
			if is_instance_valid(node):
				node.queue_free()
				cleaned += 1
	if cleaned > 0:
		print("[Arena] 清理了 %d 个残留投射物" % cleaned)

func prepare_run_exit_cleanup() -> void:
	"""结束战局前清理运行态，避免技能状态/红色视觉残留到下个界面。"""
	Engine.time_scale = 1.0
	PauseService.clear_all(get_tree())
	_cleanup_stale_floating_texts()
	_cleanup_wave_end_global_skill_effects()

	if is_instance_valid(Global.player):
		var p: Node = Global.player
		if p.has_method("_cancel_active_planning_skills"):
			p.call("_cancel_active_planning_skills", false)
		if p.has_method("_force_deactivate_ultimate_on_exit"):
			p.call("_force_deactivate_ultimate_on_exit")
		if p.has_method("_cleanup_skill_effects"):
			p.call("_cleanup_skill_effects")

		var status_component: Node = p.get_node_or_null("StatusComponent")
		if is_instance_valid(status_component) and status_component.has_method("clear_all_statuses"):
			status_component.call("clear_all_statuses")

		var visuals: CanvasItem = p.get_node_or_null("Visuals") as CanvasItem
		if is_instance_valid(visuals):
			visuals.modulate = Color.WHITE

func _notification(what: int) -> void:
	# 场景树退出时也清理投射物
	if what == NOTIFICATION_PREDELETE or what == NOTIFICATION_EXIT_TREE:
		Engine.time_scale = 1.0
		if is_inside_tree():
			_cleanup_all_projectiles()

