extends Node

const DEBUG_VERBOSE := false

# 闪避文字
signal on_create_block_text(unit:Node2D)
# 伤害数文字
signal on_create_damage_text(unit:Node2D,hitbox:HitboxComponent)

# --- 新增信号 ---
signal on_camera_shake(intensity: float, duration: float)
signal on_directional_shake(direction: Vector2, strength: float)  # 新增：指向性震动
signal on_player_switch_requested(player_id: String)  # 角色切换请求

# --- HUD 小队系统信号 ---
signal on_session_xp_changed(current: int)  # 局内 XP 变化
signal on_active_character_changed(index: int)  # 激活角色变化
signal on_switch_rejected(index: int, reason: String)  # 切换被拒绝
signal on_squad_state_changed(index: int, state: Dictionary)  # 角色状态变化
signal on_f_runtime_changed(player_id: String, f_runtime: Dictionary)
signal on_f_pack_count_changed(player_id: String, unopened_count: int)

const FLASH_MATERIAL = preload("uid://coi4nu8ohpgeo")
const FLOATING_TEXT_SCENE = preload("uid://cp86d6q6156la")

# 等级类型
enum UpgradeTier{
	COMMON,
	RARE,
	EPIC,
	LEGENDARY
}

var player:PlayerBase
var game_paused:= false

# ============================================================================
# 角色选择系统
# ============================================================================

# 当前存档槽位索引（-1 表示未选择）
var current_save_slot: int = -1

# 待恢复的战斗状态（从主菜单加载时使用）
var pending_battle_state: Dictionary = {}

# 已选角色ID列表（从选择界面传入）
var selected_player_ids: Array[String] = []
var leader_player_id: String = ""
var last_selected_player_ids: Array[String] = []
var last_leader_player_id: String = ""

# 波次招募模式：后备队（开局仅1人上场，后续波次招募扩编）
const RECRUIT_TRIGGER_WAVES: Array[int] = [3, 7]
const MAX_ACTIVE_SQUAD_SIZE: int = 3
var reserve_player_ids: Array[String] = []

# ============================================================================
# P4-1: 角色切换冷却系统 (Vanguard Lv.1)
# ============================================================================

# 切换冷却相关
var switch_cooldown_timer: float = 0.0  # 当前冷却计时器
var base_switch_cooldown: float = 0.2  # 基础切换冷却时间（秒），用于输入防抖
var is_switch_on_cooldown: bool = false  # 是否处于冷却中

# 切换协同窗口（切换后首个Q/E技能增强）
var switch_synergy_window_duration: float = 2.0
var switch_synergy_timer: float = 0.0
var switch_synergy_active: bool = false
var switch_synergy_consumed: bool = false
var switch_synergy_player_id: String = ""

# 已选角色武器配置 {player_id: weapon_type}
var selected_player_weapons: Dictionary = {}
var last_selected_player_weapons: Dictionary = {}

# 当前激活角色索引
var current_player_index: int = 0

# 角色状态存储（独立血量和能量 + 切人冷却快照）
# 格式: {player_id: {
#   health, max_health, energy, max_energy, armor, health_regen, energy_regen,
#   skill_cooldowns, bench_enter_time, last_activated_time
# }}
var player_states: Dictionary = {}

# 是否游戏结束
var is_game_over: bool = false

# ============================================================================
# 局内数据 (Session Data) - 每局重置
# ============================================================================
var session_xp: int = 0  # 局内经验值，每局重置
var session_kills: int = 0  # 局内击杀数，每局重置
var session_gold: int = 0  # 局内获得金币，每局重置

# 最近一次作画快照（用于 mirror_draw）
var recent_draw_snapshots: Dictionary = {}
var _last_mirror_draw_time: float = -999.0

const PLAYER_SELECTION_CACHE_PATH := "user://player_selection_cache.json"
const PLAYER_WEAPON_CACHE_PATH := "user://player_weapon_cache.json"

func _ready() -> void:
	# 设置全局 Tooltip 样式
	_setup_tooltip_theme()

func _setup_tooltip_theme() -> void:
	"""设置全局 Tooltip 主题样式（深色背景 + 暖白字体）"""
	# 获取现有主题或创建新主题
	var theme = get_tree().root.theme
	if theme == null:
		theme = Theme.new()
	
	# TooltipPanel 背景样式
	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color = Color(0.06, 0.06, 0.08, 0.98)
	panel_style.set_corner_radius_all(6)
	panel_style.set_border_width_all(1)
	panel_style.border_color = Color(0.55, 0.48, 0.2, 0.8)
	panel_style.content_margin_left = 10
	panel_style.content_margin_top = 6
	panel_style.content_margin_right = 10
	panel_style.content_margin_bottom = 6
	panel_style.shadow_color = Color(0, 0, 0, 0.5)
	panel_style.shadow_size = 4
	theme.set_stylebox("panel", "TooltipPanel", panel_style)
	
	# TooltipLabel 字体颜色和大小
	theme.set_color("font_color", "TooltipLabel", Color(0.93, 0.9, 0.82, 1))
	theme.set_font_size("font_size", "TooltipLabel", 16)
	
	# 应用到场景树根节点
	get_tree().root.theme = theme
	if DEBUG_VERBOSE: print("[Global] 全局 Tooltip 主题已设置")

func _process(delta: float) -> void:
	# P4-1: 处理切换冷却计时器
	if is_switch_on_cooldown:
		switch_cooldown_timer -= delta
		if switch_cooldown_timer <= 0:
			is_switch_on_cooldown = false
			switch_cooldown_timer = 0.0
			if DEBUG_VERBOSE: print("[Global] [P4-1] 切换冷却结束")

	# 切换协同窗口计时
	if switch_synergy_active and not switch_synergy_consumed:
		switch_synergy_timer -= delta
		if switch_synergy_timer <= 0:
			_clear_switch_synergy()

	_update_f_runtime_states(delta)
	# 更新未激活角色的恢复
	_update_inactive_players_regen(delta)

func _update_f_runtime_states(delta: float) -> void:
	if delta <= 0.0 or game_paused or is_game_over:
		return

	var active_player_id: String = ""
	if is_instance_valid(player):
		active_player_id = player.player_id

	for player_id_var in player_states.keys():
		var player_id: String = str(player_id_var)
		if player_id.is_empty():
			continue
		var runtime: Dictionary = get_player_f_runtime(player_id)
		if not bool(runtime.get("active", false)):
			continue
		if player_id == active_player_id:
			continue
		var time_left: float = max(0.0, float(runtime.get("time_left", 0.0)) - delta)
		runtime["time_left"] = time_left
		if time_left <= 0.0:
			runtime = _build_default_f_runtime(player_id)
		set_player_f_runtime(player_id, runtime, false)

# 更新未激活角色的恢复
func _update_inactive_players_regen(delta: float) -> void:
	if is_game_over or game_paused:
		return
	
	var active_player_id = ""
	if is_instance_valid(player):
		active_player_id = player.player_id
	
	for player_id in selected_player_ids:
		# 跳过当前激活的角色（激活角色由自身处理恢复）
		if player_id == active_player_id:
			continue
		
		# 跳过没有状态记录的角色
		if not player_states.has(player_id):
			continue
		
		var state = player_states[player_id]
		
		# 跳过已死亡的角色
		if state.get("health", 0) <= 0:
			continue
		
		# 使用配置的恢复速度
		var energy_regen = state.get("energy_regen", 0.5)  # 从 player_config.csv 读取
		var health_regen = state.get("health_regen", 0.0)  # 从 player_config.csv 读取
		
		# 能量恢复
		var max_energy = state.get("max_energy", 999)
		state.energy = min(state.energy + energy_regen * delta, max_energy)
		
		# 血量恢复（只有配置了 health_regen > 0 的角色才会回血）
		if health_regen > 0:
			var max_health = state.get("max_health", 100)
			state.health = min(state.health + health_regen * delta, max_health)
		
		player_states[player_id] = state
		

# 是否暴击
func get_chance_sucess(chance:float) -> bool:
	# 从0~1之间随机
	var random := randf_range(0,1.0)
	if random < chance:
		return true
	return false


# --- 新增：顿帧系统 (Hitstop) ---
# duration: 停顿持续的真实时间 (秒)
# time_scale: 停顿时的速度 (0.05 通常效果最好，接近静止但不是死机)
func frame_freeze(duration: float, time_scale: float = 0.05) -> void:
	if Engine.time_scale < 1.0: return # 防止连续触发导致卡死
	
	Engine.time_scale = time_scale
	
	# 创建一个忽略 TimeScale 的计时器，确保按真实时间恢复
	await get_tree().create_timer(duration * time_scale, true, false, true).timeout
	
	Engine.time_scale = 1.0

# 敌人受击反馈分层（轻击 / 重击 / 精英受击）
func apply_enemy_hit_feedback(damage: float, is_critical: bool, is_elite_target: bool) -> void:
	if is_elite_target:
		_play_sound_with_fallback("enemy_hit_elite", "crit_hit")
		frame_freeze(0.05, 0.18)
		on_camera_shake.emit(5.8, 0.14)
		return

	var heavy_threshold: float = 22.0
	var is_heavy_hit: bool = is_critical or damage >= heavy_threshold
	if is_heavy_hit:
		_play_sound_with_fallback("enemy_hit_heavy", "crit_hit")
		frame_freeze(0.03, 0.22)
		on_camera_shake.emit(3.8, 0.09)
	else:
		_play_sound_with_fallback("enemy_hit_light", "enemy_hit")
		frame_freeze(0.015, 0.25)
		on_camera_shake.emit(1.8, 0.05)

# 敌人击杀反馈分层（普通击杀 / 精英击杀）
func apply_enemy_kill_feedback(is_elite_target: bool) -> void:
	if is_elite_target:
		_play_sound_with_fallback("enemy_kill_elite", "enemy_death")
		frame_freeze(0.07, 0.17)
		on_camera_shake.emit(6.8, 0.22)
	else:
		_play_sound_with_fallback("enemy_death", "enemy_death")
		frame_freeze(0.04, 0.30)
		on_camera_shake.emit(3.0, 0.12)

func _play_sound_with_fallback(sound_id: String, fallback_id: String) -> void:
	if SoundManager and SoundManager.has_method("has_sound"):
		if SoundManager.has_sound(sound_id):
			SoundManager.play(sound_id)
			return
	SoundManager.play(fallback_id)
	

func spawn_floating_text(pos: Vector2, value: String, color: Color) -> void:
	if not FLOATING_TEXT_SCENE:
		return
	if _is_validation_test_mode_active():
		return
	call_deferred("_spawn_floating_text", pos, value, color)
		

func _is_validation_test_mode_active() -> bool:
	return (
		(has_meta("qef_test_mode_active") and bool(get_meta("qef_test_mode_active")))
		or (has_meta("skill_synergy_test_mode_active") and bool(get_meta("skill_synergy_test_mode_active")))
	)


func _spawn_floating_text(pos: Vector2, value: String, color: Color) -> void:
	# 延后一帧创建，避开场景切换/节点装配期间的 add_child 冲突
	var tree := get_tree()
	if tree == null:
		return
	var scene := tree.current_scene
	if not is_instance_valid(scene):
		return
	var text_instance = FLOATING_TEXT_SCENE.instantiate()
	scene.add_child(text_instance)

	# 随机偏移位置（在主角四周）
	var random_offset = Vector2(randf_range(-40, 40), randf_range(-40, 40))
	text_instance.global_position = pos + random_offset

	text_instance.setup(value, color)



# ============================================================================
# 角色选择系统方法
# ============================================================================

# 初始化角色状态（从选择界面调用）
func init_player_states() -> void:
	player_states.clear()
	is_game_over = false
	var now_sec := _now_seconds()
	
	for player_id in selected_player_ids:
		var config = ConfigManager.get_player_config(player_id)
		if config.is_empty():
			continue
		
		player_states[player_id] = {
			"health": float(config.get("health", 100)),
			"max_health": float(config.get("health", 100)),
			"energy": float(config.get("initial_energy", 500)),
			"max_energy": float(config.get("max_energy", 999)),
			"armor": int(config.get("max_armor", 3)),
			"health_regen": float(config.get("health_regen", 0.0)),
			"energy_regen": float(config.get("energy_regen", 0.5)),
			"base_speed": float(config.get("base_speed", config.get("speed", 200))),
			"speed": float(config.get("base_speed", config.get("speed", 200))),
			"skill_cooldowns": {},
			"f_runtime": _build_default_f_runtime(player_id),
			"bench_enter_time": 0.0,
			"last_activated_time": now_sec
		}
	
	if DEBUG_VERBOSE: print("[Global] 初始化 %d 个角色状态" % player_states.size())

func is_wave_recruit_mode_enabled() -> bool:
	var raw_value = ConfigManager.get_game_setting("enable_wave_recruit_mode", 1)
	return int(raw_value) == 1

func enter_wave_recruit_mode() -> void:
	"""进入波次招募模式：仅保留首位角色上场，其余进入后备队。"""
	if not is_wave_recruit_mode_enabled():
		reserve_player_ids.clear()
		return
	if selected_player_ids.size() <= 0:
		reserve_player_ids.clear()
		return
	if selected_player_ids.size() > 1:
		# 正式选人界面已支持 3 人整队进场，此时保留整队逻辑用于后台/切人测试。
		reserve_player_ids.clear()
		for player_id in selected_player_ids:
			_ensure_selected_weapon_for_player(str(player_id))
		leader_player_id = get_leader_player_id()
		return

	# 每次进入新战局都根据当前选择重建后备队，避免沿用旧局残留
	var original_ids: Array[String] = selected_player_ids.duplicate()
	var first_player_id: String = str(original_ids[0])
	leader_player_id = first_player_id

	var preferred_reserve_ids: Array[String] = []
	for i in range(1, original_ids.size()):
		preferred_reserve_ids.append(str(original_ids[i]))

	selected_player_ids = [first_player_id]
	current_player_index = 0
	_ensure_selected_weapon_for_player(first_player_id)
	_rebuild_recruit_pool(preferred_reserve_ids)

	if DEBUG_VERBOSE: print("[Global] 波次招募模式启用: active=%s reserve=%s" % [
		str(selected_player_ids),
		str(reserve_player_ids)
	])

func get_leader_player_id() -> String:
	if not leader_player_id.is_empty():
		return leader_player_id
	if not selected_player_ids.is_empty():
		return str(selected_player_ids[0])
	return ""

func should_offer_recruit_for_wave(wave_number: int) -> bool:
	if not is_wave_recruit_mode_enabled():
		return false
	if reserve_player_ids.is_empty():
		_rebuild_recruit_pool()
	if reserve_player_ids.is_empty():
		return false
	return _is_recruit_wave(wave_number)

func _is_recruit_wave(wave_number: int) -> bool:
	var first_wave: int = int(ConfigManager.get_game_setting("recruit_first_wave", 3))
	var interval: int = int(ConfigManager.get_game_setting("recruit_wave_interval", 2))
	if interval > 0:
		return wave_number >= first_wave and ((wave_number - first_wave) % interval == 0)
	return RECRUIT_TRIGGER_WAVES.has(wave_number)

func get_recruit_candidates(max_count: int = 3) -> Array[Dictionary]:
	var candidates: Array[Dictionary] = []
	if reserve_player_ids.is_empty():
		_rebuild_recruit_pool()
	if reserve_player_ids.is_empty():
		return candidates

	var ids: Array[String] = reserve_player_ids.duplicate()
	ids.shuffle()
	var count: int = min(max(1, max_count), ids.size())

	for i in range(count):
		var player_id: String = ids[i]
		var config: Dictionary = ConfigManager.get_player_config(player_id)
		var visual: Dictionary = ConfigManager.get_player_visual(player_id)
		var display_name: String = str(config.get("display_name", player_id))
		var ties: String = str(config.get("ties", ""))
		var desc: String = "加入小队并解锁切换位"
		if not ties.is_empty():
			desc = "%s（%s）" % [desc, ties]

		candidates.append({
			"player_id": player_id,
			"display_name": display_name,
			"description": desc,
			"icon_path": str(visual.get("sprite_path", ""))
		})

	return candidates

func recruit_player(player_id: String) -> bool:
	if player_id.is_empty():
		return false
	if not reserve_player_ids.has(player_id):
		return false
	if selected_player_ids.size() >= MAX_ACTIVE_SQUAD_SIZE:
		return false

	reserve_player_ids.erase(player_id)
	if not selected_player_ids.has(player_id):
		selected_player_ids.append(player_id)
	_ensure_selected_weapon_for_player(player_id)

	if not player_states.has(player_id):
		player_states[player_id] = _build_default_player_state(player_id)

	# 招募后重算羁绊
	BondManager.recalculate_active_bonds(selected_player_ids)

	# 通知 HUD 刷新新增槽位状态
	var new_index := selected_player_ids.find(player_id)
	if new_index >= 0:
		var state = get_player_state(player_id)
		emit_signal("on_squad_state_changed", new_index, state)

	if DEBUG_VERBOSE: print("[Global] 招募成功: %s, active=%s, reserve=%s" % [
		player_id,
		str(selected_player_ids),
		str(reserve_player_ids)
	])
	return true

func replace_player(out_player_id: String, in_player_id: String) -> bool:
	"""满员时执行替换招募：将在场角色移入后备，并用后备角色替换其位置。"""
	if out_player_id.is_empty() or in_player_id.is_empty():
		return false
	if out_player_id == in_player_id:
		return false
	if not selected_player_ids.has(out_player_id):
		return false
	if out_player_id == get_leader_player_id():
		push_warning("[Global] 禁止替换队长: %s" % out_player_id)
		return false
	if not reserve_player_ids.has(in_player_id):
		return false

	var out_index: int = selected_player_ids.find(out_player_id)
	if out_index < 0:
		return false

	# 替换 active 队列
	selected_player_ids[out_index] = in_player_id
	reserve_player_ids.erase(in_player_id)
	if not reserve_player_ids.has(out_player_id):
		reserve_player_ids.append(out_player_id)
	_ensure_selected_weapon_for_player(in_player_id)

	# 新角色状态兜底
	if not player_states.has(in_player_id):
		player_states[in_player_id] = _build_default_player_state(in_player_id)

	# 若替换的是当前出战角色，立即切换实例
	var replacing_current: bool = current_player_index == out_index
	if replacing_current:
		save_current_player_state()
		current_player_index = out_index
		emit_signal("on_player_switch_requested", in_player_id)
	else:
		var state: Dictionary = get_player_state(in_player_id)
		emit_signal("on_squad_state_changed", out_index, state)

	BondManager.recalculate_active_bonds(selected_player_ids)
	emit_signal("on_active_character_changed", current_player_index)

	if DEBUG_VERBOSE: print("[Global] 替换招募成功: out=%s in=%s, active=%s, reserve=%s" % [
		out_player_id,
		in_player_id,
		str(selected_player_ids),
		str(reserve_player_ids)
	])
	return true

func _ensure_selected_weapon_for_player(player_id: String) -> void:
	if player_id.is_empty():
		return

	var selected_weapon: String = str(selected_player_weapons.get(player_id, ""))
	if not selected_weapon.is_empty():
		return

	var weapon_types: Array[String] = ConfigManager.get_player_available_weapon_types(player_id)
	if weapon_types.is_empty():
		push_warning("[Global] no available weapon for player: %s" % player_id)
		return

	selected_player_weapons[player_id] = weapon_types[0]

func _rebuild_recruit_pool(preferred_ids: Array[String] = []) -> void:
	var rebuilt: Array[String] = []

	# 优先放入玩家开局预选但未上场的角色
	for pid in preferred_ids:
		var player_id := str(pid)
		if _is_valid_recruit_pool_member(player_id) and not rebuilt.has(player_id):
			rebuilt.append(player_id)

	# 再补齐全局启用角色池（排除已在场角色）
	for player_id in _get_all_enabled_player_ids():
		if _is_valid_recruit_pool_member(player_id) and not rebuilt.has(player_id):
			rebuilt.append(player_id)

	reserve_player_ids = rebuilt

func _is_valid_recruit_pool_member(player_id: String) -> bool:
	if player_id.is_empty():
		return false
	if selected_player_ids.has(player_id):
		return false
	var cfg: Dictionary = ConfigManager.get_player_config(player_id)
	if cfg.is_empty():
		return false
	return int(cfg.get("enabled", 0)) == 1

func _get_all_enabled_player_ids() -> Array[String]:
	var ids: Array[String] = []
	if ConfigManager == null:
		return ids
	if not ConfigManager.has_method("get_enabled_players"):
		return ids

	var enabled_players_raw: Variant = ConfigManager.get_enabled_players()
	if not (enabled_players_raw is Array):
		return ids

	for entry in enabled_players_raw:
		if not (entry is Dictionary):
			continue
		var cfg: Dictionary = entry
		var player_id: String = str(cfg.get("player_id", ""))
		if player_id.is_empty():
			continue
		if ids.has(player_id):
			continue
		ids.append(player_id)

	return ids

func _now_seconds() -> float:
	return float(Time.get_ticks_msec()) / 1000.0

# 保存当前角色状态
func save_current_player_state() -> void:
	if not is_instance_valid(player):
		return
	
	var player_id = player.player_id
	if not player_states.has(player_id):
		player_states[player_id] = {}
	var old_state: Dictionary = player_states[player_id]
	var skill_snapshot: Dictionary = {}
	if player.has_method("get_skill_cooldowns_snapshot"):
		skill_snapshot = player.get_skill_cooldowns_snapshot()
	
	player_states[player_id] = {
		"health": player.health_component.current_health,
		"max_health": player.health_component.max_health,
		"energy": player.energy,
		"max_energy": player.max_energy,
		"armor": player.armor,
		"health_regen": player.health_regen if "health_regen" in player else old_state.get("health_regen", 0.0),
		"energy_regen": player.energy_regen if "energy_regen" in player else old_state.get("energy_regen", 0.5),
		"base_speed": player.base_speed if "base_speed" in player else old_state.get("base_speed", 200.0),
		"speed": player.speed if "speed" in player else old_state.get("speed", 200.0),
		"skill_cooldowns": skill_snapshot,
		"f_runtime": _capture_player_f_runtime(player_id, old_state.get("f_runtime", _build_default_f_runtime(player_id))),
		"bench_enter_time": old_state.get("bench_enter_time", 0.0),
		"last_activated_time": old_state.get("last_activated_time", _now_seconds())
	}

func set_player_skill_cooldown_snapshot(player_id: String, snapshot: Dictionary) -> void:
	if player_id.is_empty():
		return
	if not player_states.has(player_id):
		player_states[player_id] = {}
	var state: Dictionary = player_states[player_id]
	state["skill_cooldowns"] = snapshot.duplicate(true)
	player_states[player_id] = state

func get_player_skill_cooldown_snapshot(player_id: String) -> Dictionary:
	if player_id.is_empty() or not player_states.has(player_id):
		return {}
	var state = player_states[player_id]
	var snapshot = state.get("skill_cooldowns", {})
	if snapshot is Dictionary:
		return (snapshot as Dictionary).duplicate(true)
	return {}

func mark_player_sent_to_bench(player_id: String, skill_snapshot: Dictionary = {}) -> void:
	if player_id.is_empty():
		return
	if not player_states.has(player_id):
		player_states[player_id] = {}
	var state: Dictionary = player_states[player_id]
	var snapshot := skill_snapshot
	if snapshot.is_empty() and is_instance_valid(player) and player.player_id == player_id and player.has_method("get_skill_cooldowns_snapshot"):
		snapshot = player.get_skill_cooldowns_snapshot()
	state["skill_cooldowns"] = snapshot.duplicate(true)
	state["bench_enter_time"] = _now_seconds()
	player_states[player_id] = state

func consume_bench_elapsed(player_id: String) -> float:
	if player_id.is_empty() or not player_states.has(player_id):
		return 0.0
	var state: Dictionary = player_states[player_id]
	var enter_time: float = float(state.get("bench_enter_time", 0.0))
	if enter_time <= 0.0:
		return 0.0
	var elapsed: float = max(0.0, _now_seconds() - enter_time)
	state["bench_enter_time"] = 0.0
	player_states[player_id] = state
	return elapsed

func mark_player_activated(player_id: String) -> void:
	if player_id.is_empty():
		return
	if not player_states.has(player_id):
		player_states[player_id] = {}
	var state: Dictionary = player_states[player_id]
	state["last_activated_time"] = _now_seconds()
	player_states[player_id] = state

func get_bench_cooldown_speed_multiplier(player_id: String) -> float:
	var multiplier := 1.0
	if BondManager and BondManager.has_mechanic("bench_cd_reduce"):
		multiplier += max(0.0, BondManager.get_mechanic_value("bench_cd_reduce"))
	multiplier += _get_equipment_bench_cd_bonus(player_id)
	return max(0.0, multiplier)

func _get_equipment_bench_cd_bonus(player_id: String) -> float:
	if player_id.is_empty() or not EquipmentManager:
		return 0.0
	var item_data := EquipmentManager.get_equipped_item_data(player_id)
	if item_data.is_empty():
		return 0.0
	var bonus := 0.0
	var modifiers = item_data.get("modifiers", [])
	for modifier in modifiers:
		if not (modifier is Dictionary):
			continue
		if str(modifier.get("type", "")).strip_edges() == "bench_cd_reduce_pct":
			bonus += float(modifier.get("value", 0.0))
	return max(0.0, bonus)

# 切换到下一个角色
func switch_to_next_player() -> void:
	if DEBUG_VERBOSE: print("[Global] switch_to_next_player 调用")
	if DEBUG_VERBOSE: print("[Global] selected_player_ids.size() = %d" % selected_player_ids.size())
	
	if selected_player_ids.size() <= 1:
		if DEBUG_VERBOSE: print("[Global] 只有一个或没有角色，无法切换")
		return
	
	if is_game_over:
		if DEBUG_VERBOSE: print("[Global] 游戏已结束，无法切换")
		return
	
	# 1. 保存当前角色状态并标记切出
	var old_player_id := get_current_player_id()
	save_current_player_state()
	mark_player_sent_to_bench(old_player_id)
	
	# 2. 计算下一个角色索引（循环）
	current_player_index = (current_player_index + 1) % selected_player_ids.size()
	
	# 3. 获取下一个角色ID
	var next_player_id = selected_player_ids[current_player_index]
	mark_player_activated(next_player_id)
	_apply_switch_reset(next_player_id)
	
	if DEBUG_VERBOSE: print("[Global] 切换到角色: %s (索引 %d)" % [next_player_id, current_player_index])
	
	# 4. 通知Arena生成新角色
	# 这里发出信号，由Arena处理实际的角色切换
	if DEBUG_VERBOSE: print("[Global] 发出 on_player_switch_requested 信号")
	emit_signal("on_player_switch_requested", next_player_id)

# 获取当前角色ID
func get_current_player_id() -> String:
	if current_player_index >= 0 and current_player_index < selected_player_ids.size():
		return selected_player_ids[current_player_index]
	return ""

# 获取角色状态
func get_player_state(player_id: String) -> Dictionary:
	return player_states.get(player_id, {})

# 恢复角色状态到实例
func restore_player_state(player_instance: PlayerBase) -> void:
	var player_id = player_instance.player_id
	
	# 安全检查：确保 player_id 不为空
	if player_id.is_empty():
		if DEBUG_VERBOSE: print("[Global] 警告: restore_player_state 中 player_id 为空，跳过恢复")
		return
	
	if not player_states.has(player_id):
		if DEBUG_VERBOSE: print("[Global] 警告: 未找到角色状态: %s" % player_id)
		return
	
	var state: Dictionary = player_states[player_id]
	player_instance.health_component.current_health = state.get("health", 100)
	player_instance.health_component.max_health = state.get("max_health", 100)
	player_instance.energy = state.get("energy", 500)
	player_instance.max_energy = state.get("max_energy", 999)
	player_instance.armor = state.get("armor", 3)
	if "energy_regen" in player_instance:
		player_instance.energy_regen = state.get("energy_regen", player_instance.energy_regen)
	if "base_speed" in player_instance:
		player_instance.base_speed = state.get("base_speed", player_instance.base_speed)
	if "speed" in player_instance:
		player_instance.speed = state.get("speed", player_instance.speed)

	var cooldown_snapshot_raw: Variant = state.get("skill_cooldowns", {})
	var cooldown_snapshot: Dictionary = cooldown_snapshot_raw if cooldown_snapshot_raw is Dictionary else {}
	if not cooldown_snapshot.is_empty() and player_instance.has_method("queue_restore_skill_cooldowns"):
		var bench_elapsed: float = consume_bench_elapsed(player_id)
		var bench_speed_multiplier: float = get_bench_cooldown_speed_multiplier(player_id)
		player_instance.queue_restore_skill_cooldowns(cooldown_snapshot, bench_elapsed, bench_speed_multiplier)

	var f_runtime: Dictionary = get_player_f_runtime(player_id)
	if not f_runtime.is_empty() and bool(f_runtime.get("active", false)):
		player_instance.set_meta("f_runtime_profile", f_runtime.duplicate(true))
		if is_instance_valid(player_instance.ultimate_skill) and player_instance.ultimate_skill.has_method("resume_from_runtime"):
			player_instance.ultimate_skill.call("resume_from_runtime", f_runtime)
	else:
		if player_instance.has_meta("f_runtime_profile"):
			player_instance.remove_meta("f_runtime_profile")

	if DEBUG_VERBOSE: print("[Global] 恢复角色状态: %s (血量: %d/%d)" % [player_id, player_instance.health_component.current_health, player_instance.health_component.max_health])

# 波次结束后回满当前小队资源（生命/能量/护甲）并重置当前角色技能冷却
func refill_squad_after_wave() -> void:
	if selected_player_ids.is_empty():
		return

	for i in range(selected_player_ids.size()):
		var player_id: String = selected_player_ids[i]
		if player_id.is_empty():
			continue

		if not player_states.has(player_id):
			player_states[player_id] = _build_default_player_state(player_id)

		var state_raw: Variant = player_states.get(player_id, {})
		var state: Dictionary = state_raw if state_raw is Dictionary else _build_default_player_state(player_id)
		var max_health: float = float(state.get("max_health", state.get("health", 100.0)))
		var max_energy: float = float(state.get("max_energy", state.get("energy", 0.0)))
		var config: Dictionary = ConfigManager.get_player_config(player_id)
		var max_armor: int = int(config.get("max_armor", state.get("armor", 0)))

		if max_health <= 0.0:
			max_health = 100.0
		if max_energy < 0.0:
			max_energy = 0.0

		state["health"] = max_health
		state["energy"] = max_energy
		state["armor"] = max_armor
		state["skill_cooldowns"] = {}
		player_states[player_id] = state
		notify_squad_state_changed(i)

	if is_instance_valid(player):
		var active_id: String = player.player_id
		var active_index: int = selected_player_ids.find(active_id)
		if active_index >= 0:
			var active_state: Dictionary = get_player_state_by_index(active_index)
			if player.health_component:
				player.health_component.max_health = float(active_state.get("max_health", player.health_component.max_health))
				player.health_component.current_health = float(active_state.get("health", player.health_component.max_health))
			player.max_energy = float(active_state.get("max_energy", player.max_energy))
			player.energy = float(active_state.get("energy", player.max_energy))
			player.armor = int(active_state.get("armor", player.armor))
			_reset_active_player_cooldowns(player)
			if player.has_method("update_ui_signals"):
				player.update_ui_signals()

	if DEBUG_VERBOSE: print("[Global] 波次结算回满完成: %d 名角色" % selected_player_ids.size())

func _reset_active_player_cooldowns(player_instance: PlayerBase) -> void:
	if not is_instance_valid(player_instance):
		return
	if not player_instance.has_method("get_skill_cooldowns_snapshot"):
		return
	if not player_instance.has_method("queue_restore_skill_cooldowns"):
		return

	var snapshot_raw: Variant = player_instance.get_skill_cooldowns_snapshot()
	if not (snapshot_raw is Dictionary):
		return
	var snapshot: Dictionary = snapshot_raw
	if snapshot.is_empty():
		return

	var reset_snapshot: Dictionary = {}
	for slot in snapshot.keys():
		var saved_raw: Variant = snapshot.get(slot, {})
		if not (saved_raw is Dictionary):
			continue
		var saved: Dictionary = saved_raw
		reset_snapshot[slot] = {
			"skill_id": str(saved.get("skill_id", "")),
			"is_on_cooldown": false,
			"remaining": 0.0
		}

	if reset_snapshot.is_empty():
		return

	player_instance.queue_restore_skill_cooldowns(reset_snapshot, 0.0, 1.0)

# 游戏结束
func game_over() -> void:
	if is_game_over:
		return
	
	is_game_over = true
	_clear_switch_synergy()
	if DEBUG_VERBOSE: print("[Global] 游戏结束!")
	
	# 暂停游戏（统一入口）
	PauseService.request_pause("global_game_over")
	
	# 结算界面由 Arena._on_player_died() -> _show_game_over_screen() 处理
	# 不再自动重载场景

# 重置选择数据（用于返回主菜单时）
func reset_selection() -> void:
	selected_player_ids.clear()
	leader_player_id = ""
	reserve_player_ids.clear()
	selected_player_weapons.clear()
	player_states.clear()
	recent_draw_snapshots.clear()
	current_player_index = 0
	is_game_over = false
	_clear_switch_synergy()

func save_selection_preset(player_ids: Array[String], player_weapons: Dictionary, leader_id: String = "") -> void:
	last_selected_player_ids = player_ids.duplicate()
	last_selected_player_weapons = player_weapons.duplicate(true)
	last_leader_player_id = leader_id if not leader_id.is_empty() else (player_ids[0] if not player_ids.is_empty() else "")
	_write_selection_cache_files(last_selected_player_ids, last_selected_player_weapons)
	_persist_selection_preset_to_save_slot(last_selected_player_ids, last_selected_player_weapons, last_leader_player_id)

func clear_selection_preset() -> void:
	last_selected_player_ids.clear()
	last_selected_player_weapons.clear()
	last_leader_player_id = ""
	_write_selection_cache_files([], {})

func get_selection_preset() -> Dictionary:
	if last_selected_player_ids.is_empty():
		_load_selection_preset_from_disk()
	return {
		"player_ids": last_selected_player_ids.duplicate(),
		"player_weapons": last_selected_player_weapons.duplicate(true),
		"leader_player_id": last_leader_player_id
	}
	
	# 重置武器商店购买记录（购买的武器仅本局生效）
	DataManager.reset_weapon_shop()

func _write_selection_cache_files(player_ids: Array[String], player_weapons: Dictionary) -> void:
	var selection_cache: Array[Dictionary] = []
	for i: int in range(player_ids.size()):
		var player_id: String = str(player_ids[i]).strip_edges()
		if player_id.is_empty():
			continue
		selection_cache.append({
			"player_id": player_id,
			"weapon_type": str(player_weapons.get(player_id, "")).strip_edges(),
			"slot_index": i,
		})

	var selection_file: FileAccess = FileAccess.open(PLAYER_SELECTION_CACHE_PATH, FileAccess.WRITE)
	if selection_file != null:
		selection_file.store_string(JSON.stringify(selection_cache))
		selection_file.close()

	var weapon_cache: Dictionary = {}
	for player_id_var: Variant in player_weapons.keys():
		var player_id: String = str(player_id_var).strip_edges()
		if player_id.is_empty():
			continue
		var weapon_type: String = str(player_weapons.get(player_id_var, "")).strip_edges()
		if weapon_type.is_empty():
			continue
		weapon_cache[player_id] = weapon_type

	var weapon_file: FileAccess = FileAccess.open(PLAYER_WEAPON_CACHE_PATH, FileAccess.WRITE)
	if weapon_file != null:
		weapon_file.store_string(JSON.stringify(weapon_cache))
		weapon_file.close()

func _load_selection_preset_from_disk() -> void:
	var restored_ids: Array[String] = []
	var restored_weapons: Dictionary = {}

	if FileAccess.file_exists(PLAYER_SELECTION_CACHE_PATH):
		var selection_file: FileAccess = FileAccess.open(PLAYER_SELECTION_CACHE_PATH, FileAccess.READ)
		if selection_file != null:
			var selection_json: String = selection_file.get_as_text()
			selection_file.close()
			var selection_parse: Variant = JSON.parse_string(selection_json)
			if selection_parse is Array:
				var sorted_entries: Array = (selection_parse as Array).duplicate()
				sorted_entries.sort_custom(func(a: Variant, b: Variant) -> bool:
					var a_slot: int = int((a as Dictionary).get("slot_index", 0)) if a is Dictionary else 0
					var b_slot: int = int((b as Dictionary).get("slot_index", 0)) if b is Dictionary else 0
					return a_slot < b_slot
				)
				for entry_var: Variant in sorted_entries:
					if not (entry_var is Dictionary):
						continue
					var entry: Dictionary = entry_var
					var player_id: String = str(entry.get("player_id", "")).strip_edges()
					if player_id.is_empty():
						continue
					restored_ids.append(player_id)
					var weapon_type: String = str(entry.get("weapon_type", "")).strip_edges()
					if not weapon_type.is_empty():
						restored_weapons[player_id] = weapon_type

	if FileAccess.file_exists(PLAYER_WEAPON_CACHE_PATH):
		var weapon_file: FileAccess = FileAccess.open(PLAYER_WEAPON_CACHE_PATH, FileAccess.READ)
		if weapon_file != null:
			var weapon_json: String = weapon_file.get_as_text()
			weapon_file.close()
			var weapon_parse: Variant = JSON.parse_string(weapon_json)
			if weapon_parse is Dictionary:
				for key_var: Variant in (weapon_parse as Dictionary).keys():
					var player_id: String = str(key_var).strip_edges()
					if player_id.is_empty():
						continue
					restored_weapons[player_id] = str((weapon_parse as Dictionary).get(key_var, "")).strip_edges()

	last_selected_player_ids = restored_ids
	last_selected_player_weapons = restored_weapons
	last_leader_player_id = restored_ids[0] if not restored_ids.is_empty() else ""

func _persist_selection_preset_to_save_slot(player_ids: Array[String], player_weapons: Dictionary, leader_id: String) -> void:
	if current_save_slot < 0:
		return

	var serialized_players: Array[Dictionary] = []
	for player_id in player_ids:
		var normalized_id: String = str(player_id).strip_edges()
		if normalized_id.is_empty():
			continue
		serialized_players.append({
			"player_id": normalized_id,
			"weapon_type": str(player_weapons.get(normalized_id, "")).strip_edges(),
		})

	if SaveManager.is_slot_empty(current_save_slot):
		if serialized_players.is_empty():
			return
		SaveFacade.create_new_slot_save(current_save_slot, leader_id, serialized_players)
		return

	SaveManager.save_game_progress(current_save_slot, {
		"selected_players": serialized_players,
		"leader_id": leader_id,
		"current_player_index": 0,
		"game_state": "character_selection",
	})

# ============================================================================
# 局内数据管理 (Session Data)
# ============================================================================

# 添加局内经验值
func add_session_xp(amount: int) -> void:
	var progression: Node = get_node_or_null("/root/ProgressionManager")
	if progression and progression.has_method("add_xp"):
		progression.call("add_xp", amount)
	else:
		RunStateService.add_run_xp(amount)

# 添加局内击杀数
func add_session_kill() -> void:
	session_kills += 1

# 添加局内金币记录
func add_session_gold(amount: int) -> void:
	RunStateService.add_session_gold(amount)

# 重置局内数据（新游戏时调用）
func reset_session_data() -> void:
	RunStateService.reset_session_state()
	var progression: Node = get_node_or_null("/root/ProgressionManager")
	if progression and progression.has_method("reset_run_progress"):
		progression.call("reset_run_progress")
	_clear_switch_synergy()
	recent_draw_snapshots.clear()
	PauseService.clear_all()
	if DEBUG_VERBOSE: print("[Global] 局内数据已重置")

func cache_recent_draw_path(player_id: String, points: Array, closed_shape: bool) -> void:
	if player_id.is_empty() or points.size() < 2:
		return
	var cached_points: Array = []
	for p in points:
		if p is Vector2:
			cached_points.append(p)
	if cached_points.size() < 2:
		return
	recent_draw_snapshots[player_id] = {
		"points": cached_points,
		"closed": closed_shape,
		"timestamp": _now_seconds()
	}

func get_recent_draw_path(player_id: String) -> Dictionary:
	if player_id.is_empty() or not recent_draw_snapshots.has(player_id):
		return {}
	var snapshot = recent_draw_snapshots[player_id]
	return snapshot.duplicate(true) if snapshot is Dictionary else {}

func trigger_mirror_draw_from_player(source_player_id: String, mirror_pivot: Vector2, base_damage: float) -> int:
	if source_player_id.is_empty():
		return 0
	if not BondManager or not BondManager.has_mechanic("mirror_draw"):
		return 0

	var now := _now_seconds()
	if now - _last_mirror_draw_time < 0.25:
		return 0

	var snapshot = get_recent_draw_path(source_player_id)
	if snapshot.is_empty():
		return 0
	var points_raw = snapshot.get("points", [])
	if not (points_raw is Array) or points_raw.size() < 2:
		return 0

	var points: Array = points_raw
	var damage_scale: float = max(0.2, float(BondManager.get_mechanic_value("mirror_draw")))
	var final_damage: int = max(1, int(round(base_damage * damage_scale)))
	var hit_count := 0

	var enemies = get_tree().get_nodes_in_group("enemies")
	for enemy in enemies:
		if not is_instance_valid(enemy) or not enemy.has_node("HealthComponent"):
			continue
		var enemy_pos: Vector2 = enemy.global_position
		if _is_point_near_mirrored_path(enemy_pos, points, mirror_pivot, 36.0):
			var health_comp = enemy.get_node("HealthComponent")
			health_comp.take_damage(final_damage)
			hit_count += 1
			spawn_floating_text(enemy_pos, "MIRROR!", Color(0.7, 1.8, 2.0))

	if hit_count > 0:
		_last_mirror_draw_time = now
		SoundManager.play("bond_trigger_generic")
		spawn_floating_text(mirror_pivot, "Mirror Draw x%d" % hit_count, Color(0.6, 1.7, 2.0))

	return hit_count

func _is_point_near_mirrored_path(point: Vector2, points: Array, pivot: Vector2, radius: float) -> bool:
	if points.size() < 2:
		return false
	for i in range(1, points.size()):
		var p1 = _mirror_point(points[i - 1], pivot)
		var p2 = _mirror_point(points[i], pivot)
		var closest = Geometry2D.get_closest_point_to_segment(point, p1, p2)
		if point.distance_to(closest) <= radius:
			return true
	return false

func _mirror_point(p: Vector2, pivot: Vector2) -> Vector2:
	return (pivot * 2.0) - p

# ============================================================================
# 金币生成系统 (Gold Spawn System)
# ============================================================================

# 金币场景预加载
const GOLD_COIN_SCENE = preload("res://scenes/items/gold_coin.tscn")
const ENERGY_ORB_SCENE = preload("res://scenes/items/energy_orb.tscn")

## 生成金币实体
## @param pos: 生成位置
## @param amount: 金币数量
func spawn_coin(pos: Vector2, amount: int = 1) -> void:
	if not GOLD_COIN_SCENE:
		printerr("[Global] 错误: 金币场景未加载")
		return
	
	var tree = Engine.get_main_loop() as SceneTree
	if not tree or not tree.current_scene:
		printerr("[Global] 错误: 无法获取场景树")
		return
	
	# 创建金币实例
	var coin = GOLD_COIN_SCENE.instantiate()
	coin.set_amount(amount)
	coin.global_position = pos
	
	# 添加到场景
	tree.current_scene.call_deferred("add_child", coin)
	
	#print("[Global] 生成金币: %d at (%.0f, %.0f)" % [amount, pos.x, pos.y])

func spawn_energy_orb(pos: Vector2, amount: float = 1.0, launch_velocity: Vector2 = Vector2.ZERO) -> void:
	if not ENERGY_ORB_SCENE:
		printerr("[Global] 错误: 能量球场景未加载")
		return

	var tree = Engine.get_main_loop() as SceneTree
	if not tree or not tree.current_scene:
		printerr("[Global] 错误: 无法获取场景树")
		return

	var orb = ENERGY_ORB_SCENE.instantiate()
	orb.global_position = pos
	if orb.has_method("setup"):
		orb.setup(amount, launch_velocity)

	tree.current_scene.call_deferred("add_child", orb)

# ============================================================================
# 小队切换系统 (1-2-3 键精准切换)
# ============================================================================

# 通过索引切换角色（1-2-3 键）
func switch_to_player_by_index(index: int) -> bool:
	if DEBUG_VERBOSE: print("[Global] switch_to_player_by_index 调用, index=%d" % index)

	var synergy_test_mode: bool = has_meta("skill_synergy_test_mode_active") and bool(get_meta("skill_synergy_test_mode_active"))
	
	# P4-1: 检查切换冷却
	if is_switch_on_cooldown and not synergy_test_mode:
		if DEBUG_VERBOSE: print("[Global] [P4-1] 切换防抖中，剩余 %.2f 秒" % switch_cooldown_timer)
		SoundManager.play("char_switch_fail")
		if is_instance_valid(player):
			spawn_floating_text(player.global_position, "Switch Lock: %.2fs" % switch_cooldown_timer, Color.ORANGE)
		return false
	if synergy_test_mode:
		is_switch_on_cooldown = false
		switch_cooldown_timer = 0.0
	
	# 1. 检查索引有效性
	if index < 0 or index >= selected_player_ids.size():
		push_warning("[Global] 无效的角色索引: %d" % index)
		return false
	
	# 2. 自我屏蔽检查 - 如果已经是当前角色，忽略
	if index == current_player_index:
		if DEBUG_VERBOSE: print("[Global] 已经是当前角色，忽略切换")
		return false
	
	# 3. 游戏结束检查
	if is_game_over:
		if DEBUG_VERBOSE: print("[Global] 游戏已结束，无法切换")
		return false
	
	# 4. 死亡检查
	var target_player_id = selected_player_ids[index]
	if not player_states.has(target_player_id):
		player_states[target_player_id] = _build_default_player_state(target_player_id)
	var state_variant: Variant = player_states.get(target_player_id, {})
	var state: Dictionary = state_variant if state_variant is Dictionary else _build_default_player_state(target_player_id)
	var health: float = float(state.get("health", state.get("max_health", 0.0)))
	
	if health <= 0.0 and not synergy_test_mode:
		if DEBUG_VERBOSE: print("[Global] 目标角色已死亡: %s" % target_player_id)
		SoundManager.play("char_switch_fail")
		emit_signal("on_switch_rejected", index, "dead")
		return false
	if health <= 0.0 and synergy_test_mode:
		var max_health: float = float(state.get("max_health", 100.0))
		state["health"] = max(1.0, max_health)
		player_states[target_player_id] = state
	
	# 5. 保存当前角色状态并标记切出
	var old_player_id := get_current_player_id()
	save_current_player_state()
	mark_player_sent_to_bench(old_player_id)
	
	# 6. 执行切换
	current_player_index = index
	mark_player_activated(target_player_id)
	_apply_switch_reset(target_player_id)
	
	if DEBUG_VERBOSE: print("[Global] 切换到角色: %s (索引 %d)" % [target_player_id, index])
	
	# 角色切换成功音效
	SoundManager.play("char_switch_success")
	
	# P4-1: 启动切换冷却
	if not synergy_test_mode:
		_start_switch_cooldown()
	_start_switch_synergy(target_player_id)
	
	# 7. 发出信号
	emit_signal("on_player_switch_requested", target_player_id)
	emit_signal("on_active_character_changed", index)
	
	return true

func _apply_switch_reset(player_id: String) -> void:
	if player_id.is_empty():
		return
	if not BondManager or not BondManager.has_mechanic("switch_reset"):
		return

	var snapshot: Dictionary = get_player_skill_cooldown_snapshot(player_id)
	if snapshot.is_empty():
		return

	for slot in snapshot.keys():
		var saved: Variant = snapshot.get(slot, {})
		if not (saved is Dictionary):
			continue
		var slot_state: Dictionary = saved
		slot_state["is_on_cooldown"] = false
		slot_state["remaining"] = 0.0
		snapshot[slot] = slot_state

	set_player_skill_cooldown_snapshot(player_id, snapshot)

# P4-1: 启动切换冷却（应用突击型羁绊加成）
func _start_switch_cooldown() -> void:
	"""启动切换冷却，应用突击型羁绊减少"""
	var cooldown = base_switch_cooldown
	
	# 检查突击型羁绊 - 切换冷却减少
	if BondManager.has_mechanic("switch_cd_reduce"):
		var reduction = BondManager.get_mechanic_value("switch_cd_reduce")
		cooldown = base_switch_cooldown * (1.0 - reduction)
		if DEBUG_VERBOSE: print("[Global] [P4-1] 切换防抖缩减: %.2f秒 -> %.2f秒 (减少%.0f%%)" % [
			base_switch_cooldown,
			cooldown,
			reduction * 100
		])

	# 近零CD框架下保留极小防抖，防止同帧误触多次切换
	cooldown = max(0.08, cooldown)
	
	switch_cooldown_timer = cooldown
	is_switch_on_cooldown = true
	if DEBUG_VERBOSE: print("[Global] [P4-1] 切换防抖开始: %.2f秒" % cooldown)

func _start_switch_synergy(player_id: String) -> void:
	"""切换后开启协同窗口：2秒内首个Q/E技能获得一次性增益。"""
	switch_synergy_active = true
	switch_synergy_consumed = false
	switch_synergy_timer = switch_synergy_window_duration
	switch_synergy_player_id = player_id

	if is_instance_valid(player):
		spawn_floating_text(player.global_position, "Switch Combo Ready", Color(0.6, 1.8, 1.6))

func _clear_switch_synergy() -> void:
	switch_synergy_active = false
	switch_synergy_consumed = false
	switch_synergy_timer = 0.0
	switch_synergy_player_id = ""

func try_consume_switch_synergy(owner: Node2D, slot: String) -> Dictionary:
	"""尝试消费切换协同窗口。
	返回:
	- {}: 不生效
	- {cooldown_reduction, energy_refund_ratio, min_refund}: 生效参数
	"""
	if not switch_synergy_active or switch_synergy_consumed:
		return {}

	# 只强化首个主动技能，避免普攻触发
	if slot != "q" and slot != "e":
		return {}

	if not is_instance_valid(owner):
		return {}
	var owner_player_id := String(owner.get("player_id"))
	if owner_player_id.is_empty():
		return {}
	if owner_player_id != switch_synergy_player_id:
		return {}

	switch_synergy_consumed = true
	switch_synergy_active = false
	switch_synergy_timer = 0.0

	SoundManager.play("bond_trigger_generic")
	spawn_floating_text(owner.global_position, "Switch Combo!", Color(0.5, 2.0, 1.2))

	return {
		"cooldown_reduction": 0.25,
		"energy_refund_ratio": 0.50,
		"min_refund": 8.0
	}

# P4-1: 获取当前切换冷却剩余时间
func get_switch_cooldown_remaining() -> float:
	"""获取切换冷却剩余时间
	
	Returns:
		剩余时间（秒），0表示无冷却
	"""
	if is_switch_on_cooldown:
		return switch_cooldown_timer
	return 0.0

# P4-1: 检查是否可以切换
func can_switch_character() -> bool:
	"""检查是否可以切换角色
	
	Returns:
		是否可以切换
	"""
	return not is_switch_on_cooldown

# 检查角色是否死亡
func is_player_dead(index: int) -> bool:
	if index < 0 or index >= selected_player_ids.size():
		return true
	var player_id = selected_player_ids[index]
	var state = player_states.get(player_id, {})
	return state.get("health", 0) <= 0

# 获取角色状态（通过索引）
func get_player_state_by_index(index: int) -> Dictionary:
	if index < 0 or index >= selected_player_ids.size():
		return {}
	var player_id = selected_player_ids[index]
	if not player_states.has(player_id):
		player_states[player_id] = _build_default_player_state(player_id)
		push_warning("[Global] 角色状态缺失，已补建: %s" % player_id)
	return player_states[player_id]

func _build_default_player_state(player_id: String) -> Dictionary:
	var config: Dictionary = ConfigManager.get_player_config(player_id)
	var now_sec: float = _now_seconds()
	var default_health: float = float(config.get("health", 100.0))
	var default_energy: float = float(config.get("initial_energy", 500.0))
	var default_max_energy: float = float(config.get("max_energy", 999.0))
	var default_speed: float = float(config.get("base_speed", config.get("speed", 200.0)))
	return {
		"health": default_health,
		"max_health": default_health,
		"energy": default_energy,
		"max_energy": default_max_energy,
		"armor": int(config.get("max_armor", 3)),
		"health_regen": float(config.get("health_regen", 0.0)),
		"energy_regen": float(config.get("energy_regen", 0.5)),
		"base_speed": default_speed,
		"speed": default_speed,
		"skill_cooldowns": {},
		"f_runtime": _build_default_f_runtime(player_id),
		"bench_enter_time": 0.0,
		"last_activated_time": now_sec
	}

func _build_default_f_runtime(player_id: String = "") -> Dictionary:
	return {
		"owner_player_id": player_id,
		"active": false,
		"time_left": 0.0,
		"duration": 0.0,
		"window_seq": 0,
		"mode_name": "",
		"f_role_id": player_id,
		"ult_id": "",
		"q_line_amp": 1.0,
		"q_closure_amp": 1.0,
		"internal_cd": 0.0,
		"special_1": 0.0,
		"special_2": 0.0,
		"special_3": 0.0,
		"line_events": 0,
		"closure_events": 0,
		"tick_events": 0,
		"active_pickup_count": 0,
		"unopened_count": 0,
		"slot_e": _build_default_f_slot("e"),
		"slot_q": _build_default_f_slot("q_close"),
		"utility_buff": {},
		"utility_buff_list": [],
		"jackpot_linked": false
	}

func _build_default_f_slot(target_slot: String = "") -> Dictionary:
	return {
		"active": false,
		"reward_id": "",
		"display_name": "",
		"rarity": "",
		"target_slot": target_slot,
		"behavior_tags": [],
		"payload": {},
		"link_group_id": "",
		"source_pack_id": "",
		"source_type": "",
		"loaded_window_seq": 0
	}

func _capture_player_f_runtime(player_id: String, fallback_runtime: Variant = {}) -> Dictionary:
	var runtime: Dictionary = _build_default_f_runtime(player_id)
	if fallback_runtime is Dictionary:
		runtime.merge((fallback_runtime as Dictionary).duplicate(true), true)
	if is_instance_valid(player) and player.player_id == player_id and player.has_meta("f_runtime_profile"):
		var raw_profile: Variant = player.get_meta("f_runtime_profile", {})
		if raw_profile is Dictionary:
			runtime.merge((raw_profile as Dictionary).duplicate(true), true)
	runtime["owner_player_id"] = player_id
	return runtime

func set_player_f_runtime(player_id: String, runtime: Dictionary, emit_state_changed: bool = true) -> void:
	if player_id.is_empty():
		return
	if not player_states.has(player_id):
		player_states[player_id] = _build_default_player_state(player_id)
	var state: Dictionary = player_states[player_id]
	var normalized: Dictionary = _build_default_f_runtime(player_id)
	normalized.merge(runtime.duplicate(true), true)
	normalized["owner_player_id"] = player_id
	state["f_runtime"] = normalized
	player_states[player_id] = state
	on_f_runtime_changed.emit(player_id, normalized.duplicate(true))
	on_f_pack_count_changed.emit(player_id, int(normalized.get("unopened_count", 0)))
	if emit_state_changed:
		var index: int = selected_player_ids.find(player_id)
		if index >= 0:
			emit_signal("on_squad_state_changed", index, state)

func clear_player_f_runtime(player_id: String, emit_state_changed: bool = true) -> void:
	set_player_f_runtime(player_id, _build_default_f_runtime(player_id), emit_state_changed)

func get_player_f_runtime(player_id: String) -> Dictionary:
	if player_id.is_empty():
		return {}
	if not player_states.has(player_id):
		player_states[player_id] = _build_default_player_state(player_id)
	var state: Dictionary = player_states[player_id]
	var runtime_var: Variant = state.get("f_runtime", {})
	if runtime_var is Dictionary:
		var runtime: Dictionary = _build_default_f_runtime(player_id)
		runtime.merge((runtime_var as Dictionary).duplicate(true), true)
		return runtime
	return _build_default_f_runtime(player_id)

func set_player_f_slot(player_id: String, slot_name: String, slot_payload: Dictionary) -> void:
	if player_id.is_empty():
		return
	var runtime: Dictionary = get_player_f_runtime(player_id)
	var target_key: String = "slot_e" if slot_name == "e" else ("slot_q" if slot_name == "q" or slot_name == "q_close" else "")
	if target_key.is_empty():
		return
	var normalized_slot: Dictionary = _build_default_f_slot(slot_name)
	normalized_slot.merge(slot_payload.duplicate(true), true)
	normalized_slot["active"] = true
	runtime[target_key] = normalized_slot
	set_player_f_runtime(player_id, runtime)

func consume_player_f_slot(player_id: String, slot_name: String) -> Dictionary:
	if player_id.is_empty():
		return {}
	var runtime: Dictionary = get_player_f_runtime(player_id)
	var target_key: String = "slot_e" if slot_name == "e" else ("slot_q" if slot_name == "q" or slot_name == "q_close" else "")
	if target_key.is_empty():
		return {}
	var slot_var: Variant = runtime.get(target_key, {})
	var slot_payload: Dictionary = slot_var.duplicate(true) if slot_var is Dictionary else {}
	runtime[target_key] = _build_default_f_slot(slot_name)
	set_player_f_runtime(player_id, runtime)
	return slot_payload

# 获取角色ID（通过索引）
func get_player_id_by_index(index: int) -> String:
	if index < 0 or index >= selected_player_ids.size():
		return ""
	return selected_player_ids[index]

# 通知角色状态变化（供外部调用）
func notify_squad_state_changed(index: int) -> void:
	if index < 0 or index >= selected_player_ids.size():
		return
	var state = get_player_state_by_index(index)
	emit_signal("on_squad_state_changed", index, state)
