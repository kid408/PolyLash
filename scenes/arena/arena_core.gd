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
@onready var boss_manager: BossManager = $BossManager
@onready var chest_manager: ChestManager = $ChestManager
@onready var upgrade_ui: UpgradeSelectionUI = $UpgradeSelectionUI
@onready var chest_indicator: ChestIndicator = $ChestIndicator
@onready var exit_dialog: ExitConfirmDialog = %ExitConfirmDialog
@onready var shop_panel = $GameUI/ShopPanel  # 鍟嗗簵闈㈡澘
@onready var pause_menu: PauseMenu = null  # 鏆傚仠鑿滃崟锛堝姩鎬佸垱寤猴級

# 棰勫姞杞界粨绠楃晫闈㈠拰鏆傚仠鑿滃崟
const GAME_OVER_SCENE = preload("res://scenes/ui/game_over/game_over_screen.tscn")
const PAUSE_MENU_SCENE = preload("res://scenes/ui/pause_menu/pause_menu.tscn")
const WAVE_REWARD_PANEL_SCENE = preload("res://scenes/ui/wave_reward/wave_reward_panel.tscn")
const WILDCARD_PANEL_SCENE = preload("res://scenes/ui/wildcard/wildcard_panel.tscn")
const ENABLE_LEGACY_CHEST_SYSTEM: bool = false

var current_chest: ChestSimple = null  # 淇濆瓨褰撳墠鎵撳紑鐨勫疂绠卞紩鐢?
var game_over_screen: GameOverScreen = null  # 缁撶畻鐣岄潰瀹炰緥

# 娉㈡濂栧姳绯荤粺
var wave_reward_system: Node = null
var wave_reward_panel: WaveRewardPanel = null
# 娴佺▼缂栨帓鎺у埗鍣?
var battle_flow_controller: BattleFlowController = null

# UI 寮圭獥鏍堟満鍒?- 纭繚澶氫釜寮圭獥涓嶄細閲嶅彔鏄剧ず
var ui_panel_stack: Array[Control] = []
# 涓囪兘楝肩墝閫夋嫨闈㈡澘
var wildcard_panel: WildcardPanel = null

# 鍒濆鍖栦繚鎶ゆ爣蹇?- 闃叉鍒濆鍖栨湡闂翠骇鐢熼瀛?
var _arena_initialized: bool = false
var _pending_levelup_rewards: Array[Dictionary] = []
var _last_boss_ui_id: int = 0
var _last_boss_ui_phase: int = -1

func _ready() -> void:
	# log removed during encoding cleanup
	
	# 纭繚 Arena 鍦?"arena" 缁勪腑
	if not is_in_group("arena"):
		add_to_group("arena")
		# log removed during encoding cleanup
	
	# 娓呯悊涓婁竴灞€娈嬬暀鍦?root 鑺傜偣涓婄殑椋樺瓧锛團loatingText 琚坊鍔犲埌 root锛岃法鍦烘櫙涓嶄細鑷姩閿€姣侊級
	_cleanup_stale_floating_texts()
	
	# 鍙湪閲嶆柊杩涘叆鏃堕噸缃父鎴忕姸鎬侊紙涓嶆槸绗竴娆¤繘鍏ワ級
	# 妫€鏌ユ槸鍚﹀凡缁忔湁鏁屼汉瀛樺湪锛堣〃绀鸿繖涓嶆槸绗竴娆¤繘鍏ワ級
	# 娉ㄦ剰锛氶噸鏂板紑濮嬫父鎴忔椂浼氳皟鐢?reload_current_scene()锛屼笉浼氳Е鍙戣繖涓€昏緫
	var existing_enemies = get_tree().get_nodes_in_group("enemies")
	if existing_enemies.size() > 0:
		# log removed during encoding cleanup
		_reset_game_state()
	
	# 灏嗚鑹叉坊鍔犲埌鍏ㄥ眬鍙橀噺涓?
	#Global.player = player
	# 鍏堟柇寮€鏃ц繛鎺ワ紙闃叉璺ㄥ満鏅噸澶嶈繛鎺ワ級
	if Global.on_create_block_text.is_connected(_on_create_block_text):
		Global.on_create_block_text.disconnect(_on_create_block_text)
	if Global.on_create_damage_text.is_connected(_on_create_damage_text):
		Global.on_create_damage_text.disconnect(_on_create_damage_text)
	# 闂伩椋樺瓧淇″彿 Unit绫?_on_hurtbox_component_on_damaged 璋冪敤
	Global.on_create_block_text.connect(_on_create_block_text)
	# 浼ゅ椋樺瓧淇″彿
	Global.on_create_damage_text.connect(_on_create_damage_text)
	
	# 閰嶇疆鎴樺埄鍝佹祦绋嬶紙鏃у疂绠辨祦绋?/ 娉㈡湯鎴樺埄鍝佹祦绋嬶級
	_setup_loot_flow_mode()

	# 杩炴帴鎴愰暱绯荤粺鍗囩骇浜嬩欢锛圶P 鍗囩骇瑙﹀彂涓夐€変竴锛?
	var progression: Node = get_node_or_null("/root/ProgressionManager")
	if progression and progression.has_signal("level_up"):
		var level_up_callable: Callable = Callable(self, "_on_progression_level_up")
		if progression.is_connected("level_up", level_up_callable):
			progression.disconnect("level_up", level_up_callable)
		progression.connect("level_up", level_up_callable)
	
	# 杩炴帴瑙掕壊鍒囨崲淇″彿
	Global.on_player_switch_requested.connect(_on_player_switch_requested)
	
	# 杩炴帴鐜╁姝讳骸淇″彿锛堥€氳繃鍋ュ悍缁勪欢锛?
	# 娉ㄦ剰锛氶渶瑕佸湪鐜╁鍒濆鍖栧悗杩炴帴
	
	# 杩炴帴閫€鍑哄璇濇淇″彿
	if exit_dialog:
		exit_dialog.confirmed.connect(_on_exit_confirmed)
		exit_dialog.cancelled.connect(_on_exit_cancelled)
	
	# 鍒濆鍖栨殏鍋滆彍鍗?
	_init_pause_menu()
	
	# 杩炴帴鍟嗗簵淇″彿
	if shop_panel:
		shop_panel.next_wave_requested.connect(_on_shop_next_wave_requested)
		# log removed during encoding cleanup
	
	# 鍒濆鍖栨尝娆″鍔辩郴缁?
	_init_wave_reward_system()
	_init_battle_flow_controller()
	
	# 杩炴帴 Spawner 鐨勬尝娆″畬鎴愪俊鍙?
	if spawner:
		spawner.wave_completed.connect(_on_wave_completed)
	if boss_manager and boss_manager.has_signal("boss_spawned"):
		boss_manager.boss_spawned.connect(_on_boss_spawned)
		# log removed during encoding cleanup
	
	print("[Arena] 鍑嗗鍒濆鍖栫帺瀹?..")
	# 鍒濆鍖栫帺瀹讹紙濡傛灉浠庨€夋嫨鐣岄潰杩涘叆锛? 浣跨敤 await 纭繚瀹屾垚
	await _init_player_from_selection()
	# log removed during encoding cleanup
	
	# 妫€鏌ユ槸鍚﹂渶瑕佹仮澶嶆垬鏂楃姸鎬?
	if not Global.pending_battle_state.is_empty():
		# log removed during encoding cleanup
		await _restore_battle_state()
		Global.pending_battle_state = {}  # 娓呴櫎寰呮仮澶嶇姸鎬?
	else:
		# 鍙湁鍦ㄤ笉鎭㈠鎴樻枟鐘舵€佹椂鎵嶉噸缃眬鍐呮暟鎹?
		Global.reset_session_data()

	_pending_levelup_rewards.clear()
	
	# 鍒濆鍖栧皬闃?HUD
	_init_squad_hud()
	_start_run_telemetry()
	
	# 鍒濆鍖栫緛缁?HUD
	_init_bond_hud()
	
	# 杩炴帴鐜╁鐨?XP 鍜?Gold 淇″彿
	_connect_player_signals()
	
	# 鏍囪鍒濆鍖栧畬鎴?- 姝ゅ悗椋樺瓧姝ｅ父鏄剧ず
	_arena_initialized = true
	print("[Arena] _ready() 瀹屾垚锛岄瀛椾繚鎶ゅ凡瑙ｉ櫎")

func _init_battle_flow_controller() -> void:
	battle_flow_controller = BattleFlowController.new()
	battle_flow_controller.setup(spawner, shop_panel, wave_reward_system, wave_reward_panel)
	print("[Arena] BattleFlowController 宸插垵濮嬪寲")

# ==============================================================================
# 娓告垙鐘舵€侀噸缃?
# ==============================================================================

func _reset_game_state() -> void:
	# 娓呯悊鎵€鏈夋晫浜?
	for enemy in get_tree().get_nodes_in_group("enemies"):
		enemy.queue_free()
	
	# 娓呯悊鎵€鏈夋姇灏勭墿
	for projectile in get_tree().get_nodes_in_group("projectiles"):
		projectile.queue_free()
	
	# 娓呯悊鎵€鏈夌墿鍝?
	for item in get_tree().get_nodes_in_group("items"):
		item.queue_free()
	
	# 娓呯悊鎵€鏈夊疂绠?
	for chest in get_tree().get_nodes_in_group("chests"):
		chest.queue_free()
	
	# 閲嶇疆 Spawner
	if spawner:
		spawner.reset_spawner()
	
	# 閲嶇疆 ChestManager
	if chest_manager:
		chest_manager.reset_chest_manager()

func _cleanup_stale_floating_texts() -> void:
	var cleaned := 0
	for child in get_tree().root.get_children():
		if child is FloatingText:
			child.queue_free()
			cleaned += 1

func _setup_loot_flow_mode() -> void:
	if upgrade_ui and not upgrade_ui.upgrade_selected.is_connected(_on_upgrade_selected):
		upgrade_ui.upgrade_selected.connect(_on_upgrade_selected)

	if ENABLE_LEGACY_CHEST_SYSTEM:
		if chest_manager and not chest_manager.chest_opened.is_connected(_on_chest_opened):
			chest_manager.chest_opened.connect(_on_chest_opened)
		if chest_indicator and chest_manager:
			chest_indicator.set_chest_manager(chest_manager)
		return

	print("[Arena] 宸插惎鐢ㄦ尝鏈垬鍒╁搧妯″紡锛岀鐢ㄦ棫瀹濈娴佺▼")

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
# 瀹濈绯荤粺
# ==============================================================================

func _on_chest_opened(chest: ChestSimple) -> void:
	print("[Arena] Chest opened signal received, chest tier: %d" % chest.get_tier())
	SoundManager.play("chest_open")
	
	# 淇濆瓨瀹濈寮曠敤
	current_chest = chest
	
	if not upgrade_ui:
		printerr("[Arena] UpgradeSelectionUI not found!")
		return
	
	print("[Arena] Showing upgrade UI")
	# 鏄剧ず鍗囩骇閫夋嫨UI
	upgrade_ui.show_upgrades(chest.get_tier())

func _on_upgrade_selected(attribute_id: String) -> void:
	print("[Arena] Upgrade selected: %s" % attribute_id)
	
	# 闅愯棌瀹濈
	if is_instance_valid(current_chest):
		current_chest.hide_chest()
		current_chest = null

	# 娑堣垂涓嬩竴鏉＄瓑绾у崌绾у鍔憋紙濡傛湁锛?
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
	
	# 鏇存柊 Global HUD 娉㈡淇℃伅
	if global_hud and spawner and spawner.wave_timer and not spawner.wave_timer.is_stopped():
		global_hud.set_wave_text(spawner.get_wave_text())
		global_hud.set_wave_time_text(spawner.get_wave_timer_text())
	_update_boss_hud()

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

# 鍒涘缓闂伩椋樺瓧
func _on_create_block_text(unit:Node2D) -> void:
	if not _arena_initialized:
		return
	Global.spawn_floating_text(unit.global_position, "BLOCK", blockedl_color)

# 鍒涘缓浼ゅ椋樺瓧
func _on_create_damage_text(uinit:Node2D,hitbox:HitboxComponent) -> void:
	if not _arena_initialized:
		return
	var color := critical_color if hitbox.critical else normal_color
	Global.spawn_floating_text(uinit.global_position, str(hitbox.damage), color)

# 杩炴帴鐜╁鐨?XP 鍜?Gold 淇″彿
func _connect_player_signals() -> void:
	# 绛夊緟涓€甯х‘淇濈帺瀹跺凡鍒濆鍖?
	await get_tree().process_frame
	
	if is_instance_valid(Global.player):
		# 杩炴帴姝讳骸淇″彿
		if Global.player.health_component:
			if Global.player.health_component.on_unit_died.is_connected(_on_player_died):
				Global.player.health_component.on_unit_died.disconnect(_on_player_died)
			Global.player.health_component.on_unit_died.connect(_on_player_died)
			# log removed during encoding cleanup
		
		# 鍏堟柇寮€鏃ц繛鎺ワ紙濡傛灉瀛樺湪锛?
		if Global.player.has_signal("xp_changed"):
			if Global.player.xp_changed.is_connected(_on_player_xp_changed):
				Global.player.xp_changed.disconnect(_on_player_xp_changed)
			Global.player.xp_changed.connect(_on_player_xp_changed)
		if Global.player.has_signal("gold_changed"):
			if Global.player.gold_changed.is_connected(_on_player_gold_changed):
				Global.player.gold_changed.disconnect(_on_player_gold_changed)
			Global.player.gold_changed.connect(_on_player_gold_changed)
		
		# 鍚屾鐜╁鏈湴鍙橀噺涓庡叏灞€鍊硷紙瑙掕壊鍒囨崲鍚庝繚鎸佷竴鑷达級
		Global.player.xp = Global.session_xp
		Global.player.gold = DataManager.get_total_gold()
		
		# 鍒濆鍖栨樉绀?- 浣跨敤鍏ㄥ眬鍊艰€岄潪鐜╁瀹炰緥鍊?
		_update_xp_display(Global.session_xp)
		_update_gold_display(DataManager.get_total_gold())

func _on_player_xp_changed(current: int) -> void:
	# XP 宸茬粡鐢?player_base.add_xp() 鏇存柊鍒?Global.session_xp
	# GlobalHUD 閫氳繃淇″彿鑷姩鏇存柊锛岃繖閲屼笉闇€瑕侀澶栧鐞?
	pass

func _on_player_gold_changed(current: int) -> void:
	# Gold 宸茬粡鐢?player_base.add_gold() 鏇存柊鍒?DataManager
	# 鐩存帴鏇存柊 GlobalHUD 鏄剧ず
	_update_gold_display(DataManager.get_total_gold())

func _on_player_died() -> void:
	print("[Arena] ========== 鏀跺埌鐜╁姝讳骸淇″彿 ==========")
	_finish_run_telemetry(false, "player_died")
	_show_game_over_screen()

func _update_xp_display(value: int) -> void:
	if global_hud:
		global_hud.update_xp(value)

func _update_gold_display(value: int) -> void:
	if global_hud:
		global_hud.update_gold(value)

func _init_squad_hud() -> void:
	if squad_hud and Global.selected_player_ids.size() > 0:
		var player_ids: Array[String] = []
		for id in Global.selected_player_ids:
			player_ids.append(id)
		squad_hud.init_squad(player_ids)
		print("[Arena] 灏忛槦 HUD 鍒濆鍖栧畬鎴?")

func _init_bond_hud() -> void:
	var game_ui = get_node_or_null("GameUI")
	if not game_ui:
		printerr("[Arena] 鎵句笉鍒?GameUI 鑺傜偣")
		return

	var existing_bond_hud = game_ui.get_node_or_null("BondHUD")
	if existing_bond_hud:
		return

	var bond_hud_scene = load("res://scenes/ui/bond_hud/bond_hud.tscn")
	if not bond_hud_scene:
		printerr("[Arena] 鏃犳硶鍔犺浇 BondHUD 鍦烘櫙")
		return

	var bond_hud = bond_hud_scene.instantiate()
	if not bond_hud:
		printerr("[Arena] 鏃犳硶瀹炰緥鍖?BondHUD")
		return

	bond_hud.name = "BondHUD"
	game_ui.add_child(bond_hud)

func _init_player_from_selection() -> void:
	print("[Arena] _init_player_from_selection 寮€濮?")
	print("[Arena] selected_player_ids: %s" % str(Global.selected_player_ids))
	print("[Arena] selected_player_weapons: %s" % str(Global.selected_player_weapons))

	if Global.pending_battle_state.is_empty() and not _is_synergy_test_active():
		Global.enter_wave_recruit_mode()

	if Global.selected_player_ids.size() == 0:
		print("[Arena] 娌℃湁閫夋嫨瑙掕壊锛屼娇鐢ㄩ粯璁ょ帺瀹?")
		if player:
			Global.player = player
		return

	if player:
		var old_pos = player.global_position
		print("[Arena] 绉婚櫎榛樿鐜╁锛屼綅缃? %s" % old_pos)
		player.queue_free()
		player = null
		var first_player_id = Global.selected_player_ids[0]
		print("[Arena] 鍑嗗鐢熸垚绗竴涓鑹? %s" % first_player_id)
		await get_tree().process_frame
		_spawn_player(first_player_id, old_pos)
	else:
		print("[Arena] 鍦烘櫙涓病鏈夐粯璁ょ帺瀹讹紝鐩存帴鐢熸垚閫夋嫨鐨勮鑹?")
		var first_player_id = Global.selected_player_ids[0]
		_spawn_player(first_player_id, Vector2(500, 300))

func _spawn_player(player_id: String, spawn_pos: Vector2) -> void:
	print("[Arena] _spawn_player 寮€濮? player_id=%s, pos=%s" % [player_id, spawn_pos])
	print("[Arena] Global.selected_player_weapons = %s" % str(Global.selected_player_weapons))
	
	var visual_config = ConfigManager.get_player_visual(player_id)
	print("[Arena] visual_config: %s" % str(visual_config))
	
	print("[Arena] 鍒涘缓瑙掕壊: %s" % player_id)
	var new_player = PlayerFactory.create_player(player_id)
	if not new_player:
		printerr("[Arena] 鏃犳硶鍒涘缓瑙掕壊: %s" % player_id)
		return
	
	# 纭繚 player_id 琚纭缃紙闃叉鑴氭湰鍔犺浇鏃朵涪澶憋級
	if new_player.player_id != player_id:
		print("[Arena] 璀﹀憡: player_id 涓嶅尮閰嶏紝閲嶆柊璁剧疆: %s -> %s" % [new_player.player_id, player_id])
		new_player.player_id = player_id
	
	new_player.global_position = spawn_pos
	add_child(new_player)
	
	# 鎭㈠瑙掕壊鐘舵€?
	Global.restore_player_state(new_player)
	
	# 鏇存柊寮曠敤
	player = new_player
	Global.player = new_player
	
	# 閲嶆柊杩炴帴淇″彿
	_connect_player_signals()

	var resonance_service: Node = get_node_or_null("/root/ResonanceRuntimeService")
	if resonance_service and resonance_service.has_method("on_player_activated"):
		resonance_service.call("on_player_activated", new_player)
	
	print("[Arena] 鐢熸垚瑙掕壊鎴愬姛: %s 鍦ㄤ綅缃?%s" % [player_id, spawn_pos])

func _on_player_switch_requested(player_id: String) -> void:
	print("[Arena] ===== 瑙掕壊鍒囨崲寮€濮?=====")
	print("[Arena] 鏀跺埌瑙掕壊鍒囨崲璇锋眰: %s" % player_id)
	_reset_bullet_time_state()
	
	# 瑙掕壊鍒囨崲鍓嶈嚜鍔ㄤ繚瀛樿繘搴?
	_auto_save_progress("character_switch")
	
	if not is_instance_valid(player):
		# log removed during encoding cleanup
		# 灏濊瘯鍦ㄩ粯璁や綅缃敓鎴?
		_spawn_player(player_id, Vector2(500, 300))
		print("[Arena] ===== 瑙掕壊鍒囨崲缁撴潫 =====")
		return
	
	var old_pos = player.global_position
	var old_player_id = player.player_id if "player_id" in player else "unknown"
	print("[Arena] 褰撳墠鐜╁: %s" % old_player_id)
	print("[Arena] 褰撳墠鐜╁浣嶇疆: %s" % old_pos)
	
	# P4-2: 鍥惧舰缁ф壙锛堢獊鍑诲瀷 Lv.2锛?
	# 妫€鏌ユ槸鍚︽縺娲诲浘褰㈢户鎵跨緛缁?
	var should_inherit_ink = BondManager.has_mechanic("ink_inherit")
	
	if should_inherit_ink:
		print("[Arena] [P4-2] 鍥惧舰缁ф壙婵€娲伙紝淇濈暀鏃ц鑹茬殑鐢诲浘鏁堟灉")
		# 涓嶆竻鐞嗘妧鑳芥晥鏋滐紝璁╁畠浠户缁瓨鍦?
	else:
		# 姝ｅ父鎯呭喌锛氫笉娓呯悊鎶€鑳芥晥鏋滐紙杩欐槸榛樿琛屼负锛?
		# log removed during encoding cleanup
		pass
	
	# 娉ㄦ剰锛氭棤璁烘槸鍚︽湁鍥惧舰缁ф壙缇佺粖锛屾垜浠兘涓嶆竻鐞嗘妧鑳芥晥鏋?
	# 鍥犱负褰撳墠鏋舵瀯宸茬粡璁捐涓烘妧鑳芥晥鏋滅嫭绔嬩簬瑙掕壊瀛樺湪
	# 鍥惧舰缁ф壙缇佺粖鐨勪富瑕佷綔鐢ㄦ槸锛氭柊瑙掕壊鍙互寮曠垎鏃у浘褰㈡椂閫犳垚棰濆浼ゅ
	# 杩欓儴鍒嗛€昏緫鍦?SkillDrawingBase 涓疄鐜?

	if is_instance_valid(player):
		var runtime_profile: Dictionary = {}
		if player.has_meta("f_runtime_profile"):
			var runtime_var: Variant = player.get_meta("f_runtime_profile", {})
			if runtime_var is Dictionary:
				runtime_profile = (runtime_var as Dictionary).duplicate(true)
		if not runtime_profile.is_empty() and bool(runtime_profile.get("active", false)):
			player.set_meta("preserve_f_runtime_on_exit", true)
		elif player.has_method("_force_deactivate_ultimate_on_exit"):
			player.call("_force_deactivate_ultimate_on_exit")

	# 閿€姣佸綋鍓嶈鑹?
	print("[Arena] 璋冪敤 player.queue_free()")
	player.queue_free()
	player = null
	
	# 绛夊緟涓€甯х‘淇濇棫瑙掕壊琚攢姣?
	print("[Arena] 绛夊緟涓€甯?..")
	await get_tree().process_frame
	print("[Arena] 绛夊緟瀹屾垚锛屽紑濮嬬敓鎴愭柊瑙掕壊")
	
	# 鐢熸垚鏂拌鑹?
	_spawn_player(player_id, old_pos)
	
	# 閲嶆柊搴旂敤缇佺粖灞炴€у姞鎴愬埌鏂拌鑹?
	if is_instance_valid(Global.player) and Global.player.has_method("apply_bond_stat_modifiers"):
		# 閲嶆柊璁＄畻缇佺粖锛堣鑹插垏鎹㈠彲鑳藉奖鍝嶆爣绛剧粺璁★級
		BondManager.recalculate_active_bonds(Global.selected_player_ids)
		Global.player.apply_bond_stat_modifiers()
		print("[Arena] 鉁?瑙掕壊鍒囨崲鍚庣緛缁婂睘鎬у凡閲嶆柊搴旂敤")
	
	print("[Arena] ===== 瑙掕壊鍒囨崲缁撴潫 =====")

func _auto_save_progress(trigger: String) -> void:
	if Global.has_meta("qef_test_mode_active") and bool(Global.get_meta("qef_test_mode_active")):
		print("[Arena] 璺宠繃鑷姩淇濆瓨锛圦EF娴嬭瘯妯″紡锛? %s" % trigger)
		return

	var slot_index: int = Global.current_save_slot
	if slot_index < 0:
		return
	
	print("[Arena] 鑷姩淇濆瓨杩涘害: %s" % trigger)
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
		print("[Arena] 鑷姩淇濆瓨瀹屾垚: 妲戒綅 %d, 瑙﹀彂: %s" % [slot_index, trigger])
	else:
		push_warning("[Arena] 鑷姩淇濆瓨澶辫触: 妲戒綅 %d, 瑙﹀彂: %s" % [slot_index, trigger])

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
	if event is InputEventKey:
		var key_event: InputEventKey = event
		if key_event.pressed and not key_event.echo:
			if key_event.keycode == KEY_TAB or key_event.physical_keycode == KEY_TAB:
				if _try_advance_synergy_group():
					get_viewport().set_input_as_handled()
					return

	# ESC 閿墦寮€鏆傚仠鑿滃崟
	if event.is_action_pressed("ui_cancel"):
		# 妫€鏌ユ殏鍋滆彍鍗曟槸鍚﹀凡鏄剧ず
		if pause_menu and not pause_menu.is_visible_menu:
			_show_pause_menu()
			get_viewport().set_input_as_handled()
	# Tab 閿惊鐜垏鎹㈣鑹?
	elif event.is_action_pressed("switch_player"):
		if _try_advance_synergy_group():
			get_viewport().set_input_as_handled()
			return
		_try_switch_to_next()
		get_viewport().set_input_as_handled()
	# 1-2-3 閿簿鍑嗗垏鎹㈣鑹?
	elif event.is_action_pressed("switch_player_1"):
		_try_switch_to_index(0)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("switch_player_2"):
		_try_switch_to_index(1)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("switch_player_3"):
		_try_switch_to_index(2)
		get_viewport().set_input_as_handled()

func _is_synergy_test_active() -> bool:
	if DebugSwitcher != null and is_instance_valid(DebugSwitcher):
		if DebugSwitcher.has_method("is_synergy_test_mode_enabled"):
			var mode_enabled_by_method: Variant = DebugSwitcher.call("is_synergy_test_mode_enabled")
			return bool(mode_enabled_by_method)
		var mode_enabled_by_prop: Variant = DebugSwitcher.get("synergy_test_mode_enabled")
		if mode_enabled_by_prop != null:
			return bool(mode_enabled_by_prop)
	if Global != null and Global.has_meta("skill_synergy_test_mode_active"):
		return bool(Global.get_meta("skill_synergy_test_mode_active"))
	return false

func _try_advance_synergy_group() -> bool:
	if not _is_synergy_test_active():
		return false
	if DebugSwitcher != null and is_instance_valid(DebugSwitcher) and DebugSwitcher.has_method("advance_synergy_group"):
		DebugSwitcher.call("advance_synergy_group")
		return true
	return false

# 灏濊瘯鍒囨崲鍒版寚瀹氱储寮曠殑瑙掕壊
func _try_switch_to_index(index: int) -> void:
	if Global.selected_player_ids.size() == 0:
		return
	
	if not Global.switch_to_player_by_index(index):
		# 鍒囨崲澶辫触锛屾鏌ュ師鍥?
		if Global.is_player_dead(index):
			# 鎾斁鏃犳晥闊虫晥
			_play_invalid_switch_sound()
			# UI 鎶栧姩鐢?SquadHUD 閫氳繃淇″彿澶勭悊

# 寰幆鍒囨崲鍒颁笅涓€涓瓨娲荤殑瑙掕壊锛圱ab 閿級
func _try_switch_to_next() -> void:
	if _try_advance_synergy_group():
		return
	var squad_size = Global.selected_player_ids.size()
	if squad_size == 0:
		return
	
	var current_index = Global.current_player_index
	var attempts = 0
	
	# 灏濊瘯鎵惧埌涓嬩竴涓瓨娲荤殑瑙掕壊锛堟渶澶氬皾璇?squad_size 娆★級
	while attempts < squad_size:
		var next_index = (current_index + 1 + attempts) % squad_size
		
		# 灏濊瘯鍒囨崲鍒颁笅涓€涓鑹?
		if Global.switch_to_player_by_index(next_index):
			# 鍒囨崲鎴愬姛
			return
		
		attempts += 1
	
	# 鎵€鏈夎鑹查兘鏃犳硶鍒囨崲锛堝彲鑳介兘姝讳骸浜嗭級
	_play_invalid_switch_sound()

func _play_invalid_switch_sound() -> void:
	# 鎾斁鎷掔粷闊虫晥 - 浣跨敤鐜版湁鐨勯煶鏁堟垨闈欓粯
	# 濡傛灉鏈?ui_reject.wav 鍒欐挱鏀撅紝鍚﹀垯浣跨敤 player_shatter 鐨勫彉浣?
	SoundManager.play("ui_error")

# ============================================================================
# 閫€鍑虹‘璁ゅ璇濇
# ============================================================================

func _init_pause_menu() -> void:
	var game_ui = get_node_or_null("GameUI")
	if not game_ui:
		printerr("[Arena] 鎵句笉鍒?GameUI 鑺傜偣")
		return

	var existing_pause_menu = game_ui.get_node_or_null("PauseMenu")
	if existing_pause_menu and existing_pause_menu is PauseMenu:
		pause_menu = existing_pause_menu as PauseMenu
	else:
		pause_menu = PAUSE_MENU_SCENE.instantiate()
		pause_menu.name = "PauseMenu"
		game_ui.add_child(pause_menu)

	if not pause_menu.resume_requested.is_connected(_on_pause_resume):
		pause_menu.resume_requested.connect(_on_pause_resume)
	if not pause_menu.restart_requested.is_connected(_on_pause_restart):
		pause_menu.restart_requested.connect(_on_pause_restart)
	if not pause_menu.end_run_requested.is_connected(_on_pause_end_run):
		pause_menu.end_run_requested.connect(_on_pause_end_run)
	if not pause_menu.codex_requested.is_connected(_on_pause_codex):
		pause_menu.codex_requested.connect(_on_pause_codex)
	if not pause_menu.settings_requested.is_connected(_on_pause_settings):
		pause_menu.settings_requested.connect(_on_pause_settings)
	if not pause_menu.return_to_menu_requested.is_connected(_on_pause_return_to_menu):
		pause_menu.return_to_menu_requested.connect(_on_pause_return_to_menu)

	print("[Arena] 鏆傚仠鑿滃崟宸插垵濮嬪寲")

func _show_pause_menu() -> void:
	if pause_menu:
		pause_menu.show_menu()

func _on_pause_resume() -> void:
	print("[Arena] 缁х画娓告垙")

func _on_pause_restart() -> void:
	print("[Arena] 閲嶆柊寮€濮嬪綋鍓嶅叧鍗?")
	_finish_run_telemetry(false, "restart")
	PauseService.clear_all(get_tree())
	_cleanup_all_projectiles()
	Global.reset_session_data()
	Global.pending_battle_state = {}
	get_tree().reload_current_scene()

func _on_pause_end_run() -> void:
	print("[Arena] 缁撴潫鏈疆娓告垙锛岃繑鍥炶鑹查€夋嫨鐣岄潰")
	_finish_run_telemetry(false, "end_run")
	prepare_run_exit_cleanup()
	# 娓呯悊鎵€鏈夋畫鐣欑殑鎶曞皠鐗?
	_cleanup_all_projectiles()
	# 娓呴櫎鎴樻枟鐘舵€侊紙涓嶄繚瀛橈級
	Global.reset_selection()
	Global.reset_session_data()
	# 娓呴櫎瀛樻。妲戒綅涓殑鎴樻枟鐘舵€?
	if Global.current_save_slot >= 0:
		if battle_flow_controller:
			battle_flow_controller.clear_battle_state(Global.current_save_slot)
		else:
			SaveFacade.clear_battle_state(Global.current_save_slot)
	# 杩斿洖瑙掕壊閫夋嫨鐣岄潰
	get_tree().change_scene_to_file("res://scenes/ui/selection_panel/selection_panel.tscn")

func _on_pause_codex() -> void:
	# log removed during encoding cleanup
	# TODO: 瀹炵幇鍥鹃壌鐣岄潰
	pass

func _on_pause_settings() -> void:
	# log removed during encoding cleanup
	# TODO: 瀹炵幇璁剧疆鐣岄潰
	pass

func _on_pause_return_to_menu() -> void:
	print("[Arena] 杩斿洖涓昏彍鍗曪紝淇濆瓨瀹屾暣鎴樻枟鐘舵€?")
	_finish_run_telemetry(false, "return_to_menu")
	_save_full_battle_state()
	prepare_run_exit_cleanup()
	_cleanup_all_projectiles()
	Global.reset_selection()
	Global.reset_session_data()
	get_tree().change_scene_to_file("res://scenes/ui/main_menu/main_menu_root.tscn")

func _save_full_battle_state() -> void:
	var slot_index: int = Global.current_save_slot
	if slot_index < 0:
		print("[Arena] 娌℃湁閫夋嫨瀛樻。妲戒綅锛岃烦杩囦繚瀛?")
		return

	print("[Arena] 淇濆瓨瀹屾暣鎴樻枟鐘舵€佸埌妲戒綅 %d" % slot_index)
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
		print("[Arena] 瀹屾暣鎴樻枟鐘舵€佸凡淇濆瓨")
	else:
		push_warning("[Arena] 瀹屾暣鎴樻枟鐘舵€佷繚瀛樺け璐? 妲戒綅 %d" % slot_index)

func _restore_battle_state() -> void:
	print("[Arena] 寮€濮嬫仮澶嶆垬鏂楃姸鎬?..")
	BattleStateManager.restore_battle_state(Global.pending_battle_state)
	print("[Arena] 鎴樻枟鐘舵€佹仮澶嶅畬鎴?")

func _show_exit_dialog() -> void:
	if exit_dialog:
		exit_dialog.show_dialog()

func _on_exit_confirmed() -> void:
	print("[Arena] 鐜╁纭閫€鍑烘父鎴?")
	_finish_run_telemetry(false, "exit_to_menu")
	prepare_run_exit_cleanup()
	_cleanup_all_projectiles()
	_save_progress_before_exit()
	Global.reset_selection()
	Global.reset_session_data()
	Global.current_save_slot = -1
	_clear_selection_cache()
	_clear_weapon_cache()
	get_viewport().set_input_as_handled()
	get_tree().change_scene_to_file("res://scenes/ui/main_menu/main_menu_root.tscn")

func _on_exit_cancelled() -> void:
	print("[Arena] 鐜╁鍙栨秷閫€鍑?")

func _save_progress_before_exit() -> void:
	var slot_index: int = Global.current_save_slot
	if slot_index < 0:
		# log removed during encoding cleanup
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
		print("[Arena] 杩涘害宸蹭繚瀛樺埌妲戒綅 %d" % slot_index)
	else:
		push_warning("[Arena] 閫€鍑哄墠淇濆瓨澶辫触: 妲戒綅 %d" % slot_index)
	
	# 鍚屾瑙掕壊閫夋嫨缂撳瓨鍜屾鍣ㄧ紦瀛橈紝纭繚鍥炲埌 SelectionPanel 鏃舵暟鎹竴鑷?
	_sync_selection_cache_from_global()

func _build_save_data() -> Dictionary:
	var data: Dictionary = {
		# 鍩虹杩涘害
		"current_wave": spawner.wave_index if spawner else 1,
		"current_floor": 1,
		"play_time_seconds": 0,  # TODO: 瀹炵幇娓告垙鏃堕棿缁熻
		"game_state": "in_progress",
		
		# 瑙掕壊鏁版嵁
		"selected_players": _save_player_data(),
		"leader_id": Global.selected_player_ids[0] if Global.selected_player_ids.size() > 0 else "",
		"current_player_index": Global.current_player_index,
		
		# 闃熶紞鐘舵€?
		"player_states": Global.player_states.duplicate(true),
		
		# 閲戝竵鍜岀粡楠?
		"gold": DataManager.get_total_gold(),
		"session_xp": Global.session_xp,
		"session_kills": Global.session_kills,
		"session_gold": Global.session_gold,
		
		# 缇佺粖鏁版嵁
		"bond_summary": BondManager.get_bond_summary(),
		"bond_counts": BondManager.current_bond_counts.duplicate(true),
		
		# 瑁呭鏁版嵁
		"equipment": _get_equipment_data(),
		
		# 浠撳簱鏁版嵁
		"warehouse": _get_warehouse_data(),
		
		# 鍗囩骇鏁版嵁
		"upgrades": DataManager.save_data.upgrades.duplicate(true),
		
		# 寰界珷鏁版嵁
		"emblems": EmblemManager.serialize(),
		
		# 淇敼鍣ㄦ暟鎹?
		"modifiers": ModifierManager.serialize(),
	}
	
	return data

func _get_equipment_data() -> Dictionary:
	var equipment_data: Dictionary = {}
	for pid in Global.selected_player_ids:
		var item_data = EquipmentManager.get_equipped_item_data(pid)
		if not item_data.is_empty():
			equipment_data[pid] = item_data
	return equipment_data

func _get_warehouse_data() -> Dictionary:
	return {
		"items": WarehouseManager.get_all_items(),
		"capacity": WarehouseManager.get_capacity()
	}

func _save_player_data() -> Array:
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
	if battle_flow_controller:
		battle_flow_controller.sync_selection_cache()
	else:
		SaveFacade.sync_selection_cache_from_runtime()

func _clear_selection_cache() -> void:
	if battle_flow_controller:
		battle_flow_controller.clear_selection_cache_files()
	else:
		SaveFacade.clear_selection_cache_files()

func _clear_weapon_cache() -> void:
	if battle_flow_controller:
		battle_flow_controller.clear_selection_cache_files()
	else:
		SaveFacade.clear_selection_cache_files()

func _on_wave_completed(wave_number: int) -> void:
	_reset_bullet_time_state()
	_cleanup_wave_end_player_effects()
	Global.refill_squad_after_wave()
	_record_wave_telemetry(wave_number)
	if battle_flow_controller:
		battle_flow_controller.on_wave_completed(wave_number)
		return

	SoundManager.play("wave_complete")
	if spawner:
		spawner.pause_spawning()

	if wave_reward_system and wave_reward_system.check_wave_reward(wave_number):
		var options = wave_reward_system.generate_reward_options()
		if wave_reward_panel:
			wave_reward_panel.show_rewards(options)
		return

	_show_shop_for_wave(wave_number)

func _cleanup_wave_end_player_effects() -> void:
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
	if SkillEffectManager and SkillEffectManager.has_method("clear_all_effects"):
		SkillEffectManager.clear_all_effects()

	for node in get_tree().get_nodes_in_group("player_skill_effects"):
		if is_instance_valid(node):
			node.queue_free()

	var current_scene: Node = get_tree().current_scene
	if not is_instance_valid(current_scene):
		return

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
	_reset_bullet_time_state()
	if battle_flow_controller:
		var slot_index := Global.current_save_slot
		var wave_number := spawner.wave_index if spawner else 1
		battle_flow_controller.on_shop_next_wave_requested(slot_index, wave_number)
		return

	SoundManager.play("shop_close")
	SoundManager.play("wave_start")
	_auto_save_progress("shop_closed")
	if spawner:
		spawner.resume_spawning()

# ============================================================================
# 娉㈡濂栧姳绯荤粺
# ============================================================================

func _init_wave_reward_system() -> void:
	var wrs_script = load("res://scenes/arena/wave_reward_system.gd")
	if wrs_script:
		wave_reward_system = wrs_script.new()
		wave_reward_system.name = "WaveRewardSystem"
		add_child(wave_reward_system)
	else:
		printerr("[Arena] Failed to load WaveRewardSystem")
		return

	var game_ui = get_node_or_null("GameUI")
	if game_ui:
		wave_reward_panel = WAVE_REWARD_PANEL_SCENE.instantiate() as WaveRewardPanel
		if wave_reward_panel == null:
			wave_reward_panel = WaveRewardPanel.new()
		wave_reward_panel.name = "WaveRewardPanel"
		wave_reward_panel.wave_reward_system = wave_reward_system
		wave_reward_panel.reward_chosen.connect(_on_wave_reward_chosen)
		game_ui.add_child(wave_reward_panel)

		wildcard_panel = WILDCARD_PANEL_SCENE.instantiate() as WildcardPanel
		if wildcard_panel == null:
			wildcard_panel = WildcardPanel.new()
		wildcard_panel.name = "WildcardPanel"
		wildcard_panel.wildcard_assigned.connect(_on_wildcard_assigned)
		game_ui.add_child(wildcard_panel)
	else:
		printerr("[Arena] Failed to find GameUI for wave reward panel")

	EmblemManager.wildcard_assignment_requested.connect(_on_wildcard_requested)

func _on_wave_reward_chosen(reward_data: Dictionary) -> void:
	_after_wave_reward_chosen(reward_data)
	if battle_flow_controller:
		battle_flow_controller.on_wave_reward_chosen(reward_data)
		return

func _after_wave_reward_chosen(reward_data: Dictionary) -> void:
	var reward_type: String = str(reward_data.get("type", ""))
	if reward_type != "recruit" and reward_type != "recruit_replace":
		return

	# 鎷涘嫙鍚庡埛鏂板皬闃熸Ы浣嶏紝绔嬪嵆鍙 1->2->3 鐨勬墿缂栫粨鏋?
	_init_squad_hud()
	for i in range(Global.selected_player_ids.size()):
		Global.notify_squad_state_changed(i)

	# 鎷涘嫙浼氭敼鍙橀槦浼嶆爣绛撅紝缁欏綋鍓嶆縺娲昏鑹查噸鏂板鐢ㄧ緛缁婂姞鎴?
	if is_instance_valid(Global.player) and Global.player.has_method("apply_bond_stat_modifiers"):
		Global.player.apply_bond_stat_modifiers()
		# log removed during encoding cleanup

func _show_shop_for_wave(wave_number: int) -> void:
	if battle_flow_controller:
		battle_flow_controller.show_shop_for_wave(wave_number)
		return

	if shop_panel:
		SoundManager.play("shop_open")
		shop_panel.show_shop(wave_number + 1)
	else:
		printerr("[Arena] 閿欒: 鎵句笉鍒?ShopPanel 鑺傜偣")
		if spawner:
			spawner.resume_spawning()

func _reset_bullet_time_state() -> void:
	Engine.time_scale = 1.0
	if is_instance_valid(player):
		var sm = player.get_node_or_null("SkillManager")
		if sm and sm.has_method("force_cancel_planning_skills"):
			sm.call("force_cancel_planning_skills", false)

func push_panel(panel: Control) -> void:
	if not ui_panel_stack.is_empty():
		ui_panel_stack.back().hide()
	ui_panel_stack.append(panel)
	panel.show()
	PauseService.request_pause("ui_panel:%s" % panel.name, get_tree())

func pop_panel() -> void:
	if ui_panel_stack.is_empty():
		return
	var top = ui_panel_stack.pop_back()
	top.hide()
	PauseService.release_pause("ui_panel:%s" % top.name, get_tree())
	if not ui_panel_stack.is_empty():
		ui_panel_stack.back().show()  # 鎭㈠涓婁竴涓潰鏉?

# ============================================================================
# 涓囪兘楝肩墝淇″彿澶勭悊
# ============================================================================

func _on_wildcard_requested(emblem_data: Dictionary) -> void:
	print("[Arena] 鏀跺埌涓囪兘楝肩墝鍒嗛厤璇锋眰")
	if wildcard_panel:
		wildcard_panel.show_wildcard_selection(emblem_data)
		push_panel(wildcard_panel)

func _on_wildcard_assigned() -> void:
	print("[Arena] 涓囪兘楝肩墝鍒嗛厤瀹屾垚")
	pop_panel()
	# 瑙﹀彂缇佺粖閲嶇畻
	if Global.selected_player_ids.size() > 0:
		BondManager.recalculate_active_bonds(Global.selected_player_ids)

# ============================================================================
# 娓告垙缁撶畻绯荤粺
# ============================================================================

func _show_game_over_screen() -> void:
	print("[Arena] ========== 鏄剧ず娓告垙缁撶畻鐣岄潰 ==========")
	print("[Arena] Global.is_game_over: %s" % Global.is_game_over)
	print("[Arena] Global.player 鏈夋晥: %s" % is_instance_valid(Global.player))
	_cleanup_wave_end_player_effects()
	
	# 娓呯悊鎵€鏈夋畫鐣欑殑绮捐嫳鎶曞皠鐗?
	_cleanup_all_projectiles()
	
	# 闃叉閲嶅鏄剧ず
	if game_over_screen:
		print("[Arena] 缁撶畻鐣岄潰宸插瓨鍦紝璺宠繃")
		return
	
	SoundManager.play("game_over")
	
	# 瀹炰緥鍖栫粨绠楃晫闈?
	print("[Arena] 瀹炰緥鍖栫粨绠楃晫闈?..")
	game_over_screen = GAME_OVER_SCENE.instantiate()
	add_child(game_over_screen)
	# log removed during encoding cleanup
	
	# 缁撶畻灞€鍐呰揣甯侊細鎸夎鍒欏彂鏀惧眬澶栫鐗囷紝run_gold 娓呴浂
	var settlement = MetaProgressService.settle_from_run(RunStateService.get_session_gold())

	# 鏀堕泦缁熻鏁版嵁
	var stats_data = {
		"kills": Global.session_kills,
		"soul_shard": int(settlement.get("soul_shard_gain", 0)),
		"run_gold": int(settlement.get("run_gold_before", 0))
	}
	
	print("[Arena] 缁撶畻鏁版嵁 - 鍑绘潃: %d, 鑾峰緱纰庣墖: %d, run_gold缁撶畻鍓? %d" % [
		stats_data.kills,
		stats_data.soul_shard,
		stats_data.run_gold
	])
	
	# 璁剧疆鏁版嵁骞舵樉绀?
	game_over_screen.set_stats(stats_data)
	game_over_screen.show_screen()
	_save_progress_on_run_failed()
	print("[Arena] ========== 缁撶畻鐣岄潰鏄剧ず瀹屾垚 ==========")

func _save_progress_on_run_failed() -> void:
	# Persist failed-run state so main-menu slot info stays consistent.
	var slot_index: int = Global.current_save_slot
	if slot_index < 0:
		return

	var wave_number: int = spawner.wave_index if spawner else 1

	var save_ok: bool = SaveFacade.save_progress(slot_index, {
		"trigger": "run_failed",
		# 澶辫触鍚庡洖鍒伴€夎锛屾Ы浣嶆樉绀哄簲褰掍綅鍒板眬澶栫姸鎬侊紝鍚屾椂淇濈暀褰撳墠瀹屾暣灏忛槦銆?		"current_floor": 1,
		"current_wave": 1,
		"last_failed_wave": wave_number,
		"game_state": "character_selection",
		"battle_state": {}
	})
	var clear_ok: bool = SaveFacade.clear_battle_state(slot_index)

	if save_ok and clear_ok:
		print("[Arena] 澶辫触缁撶畻杩涘害宸蹭繚瀛? slot=%d wave=%d" % [slot_index, wave_number])
	else:
		push_warning("[Arena] 澶辫触缁撶畻杩涘害淇濆瓨寮傚父: slot=%d save=%s clear=%s" % [
			slot_index,
			str(save_ok),
			str(clear_ok)
		])

func _cleanup_all_projectiles() -> void:
	var cleaned = 0
	for group_name in ["elite_projectiles", "projectiles", "player_skill_effects"]:
		var nodes = get_tree().get_nodes_in_group(group_name)
		for node in nodes:
			if is_instance_valid(node):
				node.queue_free()
				cleaned += 1
	if cleaned > 0:
		print("[Arena] 娓呯悊浜?%d 涓畫鐣欐姇灏勭墿" % cleaned)

func prepare_run_exit_cleanup() -> void:
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

func _on_boss_spawned(_boss: Node) -> void:
	_last_boss_ui_id = 0
	_last_boss_ui_phase = -1

func _update_boss_hud() -> void:
	pass
