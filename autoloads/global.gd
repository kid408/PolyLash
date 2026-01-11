extends Node

# 闪避文字
signal on_create_block_text(unit:Node2D)
# 伤害数文字
signal on_create_damage_text(unit:Node2D,hitbox:HitboxComponent)

# --- 新增信号 ---
signal on_camera_shake(intensity: float, duration: float)
signal on_directional_shake(direction: Vector2, strength: float)  # 新增：指向性震动
signal on_player_switch_requested(player_id: String)  # 角色切换请求

const FLASH_MATERIAL = preload("uid://coi4nu8ohpgeo")
const FLOATING_TEXT_SCENE = preload("uid://cp86d6q6156la")

# 预加载音效资源 (请你需要找相应的 .wav/.mp3 文件拖进去)
# 推荐去 freesound.org 搜: "squish", "pop", "glass shatter", "8bit explosion"
var sfx_enemy_pop = preload("res://assets/audio/pop_squish.wav") # 敌人死亡的噗啵声
var sfx_player_shatter = preload("res://assets/audio/glass_shatter.wav") # 玩家的破碎声
var sfx_loop_kill = preload("res://assets/audio/magic_chord.wav") # 闭环绞杀的特殊提示音
var sfx_player_dash = preload("res://assets/audio/dash.wav") # 冲撞声
var sfx_player_explosion = preload("res://assets/audio/magical_explosion.wav") # 爆炸声
# 声音对象池大小
const POOL_SIZE = 32
var pool: Array[AudioStreamPlayer] = []
var next_idx = 0

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

# 已选角色ID列表（从选择界面传入）
var selected_player_ids: Array[String] = []

# 已选角色武器配置 {player_id: weapon_type}
var selected_player_weapons: Dictionary = {}

# 当前激活角色索引
var current_player_index: int = 0

# 角色状态存储（独立血量和能量）
# 格式: {player_id: {health, max_health, energy, max_energy, armor, health_regen, energy_regen}}
var player_states: Dictionary = {}

# 是否游戏结束
var is_game_over: bool = false

func _ready() -> void:
	# 初始化对象池，防止频繁创建销毁音频节点
	for i in range(POOL_SIZE):
		var player = AudioStreamPlayer.new()
		add_child(player)
		pool.append(player)

func _process(delta: float) -> void:
	# 更新未激活角色的恢复
	_update_inactive_players_regen(delta)

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
		
		# 能量恢复
		var energy_regen = state.get("energy_regen", 0.5)
		state.energy = min(state.energy + energy_regen * delta, state.max_energy)
		
		# 血量恢复
		var health_regen = state.get("health_regen", 0.0)
		if health_regen > 0:
			state.health = min(state.health + health_regen * delta, state.max_health)
		
		player_states[player_id] = state
		
# 播放普通音效 (带音调随机，这很关键！)
func play_sfx(stream: AudioStream, min_pitch: float = 0.8, max_pitch: float = 1.2, volume_db: float = 0.0):
	if not stream: return
	
	var player = pool[next_idx]
	next_idx = (next_idx + 1) % POOL_SIZE
	
	player.stream = stream
	# 【核心】随机音调！
	# 让每次杀敌的声音都不一样，有的尖锐(小虫)，有的低沉(大虫)
	# 这会产生“爆米花”一样的丰富听感，超级解压！
	player.pitch_scale = randf_range(min_pitch, max_pitch)
	player.volume_db = volume_db
	player.play()
	
# 专门用于敌人的死亡音效接口
func play_enemy_death():
	# 音量稍微小一点，因为数量多
	play_sfx(sfx_enemy_pop, 0.9, 1.4, -10.0)

# 专门用于闭环绞杀的音效 (更有质感)
func play_loop_kill_impact():
	# 音调更低，更沉重，表示大量击杀
	play_sfx(sfx_loop_kill, 0.6, 0.8, 5.0)

# 玩家死亡音效
func play_player_death():
	# 不随机音调，保持严肃和震撼
	play_sfx(sfx_player_shatter, 1.0, 1.0, 5.0)

# 玩家冲撞音效
func play_player_dash():
	# 不随机音调，保持严肃和震撼
	play_sfx(sfx_player_dash,  1.0, 1.0, -2.0)
	
# 玩家爆炸音效
func play_player_explosion():
	# 不随机音调，保持严肃和震撼
	play_sfx(sfx_player_explosion,  1.0, 1.0, 2.0)
	
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
	

func spawn_floating_text(pos: Vector2, value: String, color: Color) -> void:
	if FLOATING_TEXT_SCENE:
		var text_instance = FLOATING_TEXT_SCENE.instantiate()
		# 添加到当前场景中
		get_tree().current_scene.add_child(text_instance)
		
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
			"energy_regen": float(config.get("energy_regen", 0.5))
		}
	
	print("[Global] 初始化 %d 个角色状态" % player_states.size())

# 保存当前角色状态
func save_current_player_state() -> void:
	if not is_instance_valid(player):
		return
	
	var player_id = player.player_id
	if not player_states.has(player_id):
		player_states[player_id] = {}
	
	player_states[player_id] = {
		"health": player.health_component.current_health,
		"max_health": player.health_component.max_health,
		"energy": player.energy,
		"max_energy": player.max_energy,
		"armor": player.armor,
		"health_regen": player_states[player_id].get("health_regen", 0.0),
		"energy_regen": player_states[player_id].get("energy_regen", 0.5)
	}

# 切换到下一个角色
func switch_to_next_player() -> void:
	print("[Global] switch_to_next_player 调用")
	print("[Global] selected_player_ids.size() = %d" % selected_player_ids.size())
	
	if selected_player_ids.size() <= 1:
		print("[Global] 只有一个或没有角色，无法切换")
		return
	
	if is_game_over:
		print("[Global] 游戏已结束，无法切换")
		return
	
	# 1. 保存当前角色状态
	save_current_player_state()
	
	# 2. 计算下一个角色索引（循环）
	current_player_index = (current_player_index + 1) % selected_player_ids.size()
	
	# 3. 获取下一个角色ID
	var next_player_id = selected_player_ids[current_player_index]
	
	print("[Global] 切换到角色: %s (索引 %d)" % [next_player_id, current_player_index])
	
	# 4. 通知Arena生成新角色
	# 这里发出信号，由Arena处理实际的角色切换
	print("[Global] 发出 on_player_switch_requested 信号")
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
	if not player_states.has(player_id):
		return
	
	var state = player_states[player_id]
	player_instance.health_component.current_health = state.get("health", 100)
	player_instance.health_component.max_health = state.get("max_health", 100)
	player_instance.energy = state.get("energy", 500)
	player_instance.max_energy = state.get("max_energy", 999)
	player_instance.armor = state.get("armor", 3)

# 游戏结束
func game_over() -> void:
	if is_game_over:
		return
	
	is_game_over = true
	print("[Global] 游戏结束!")
	
	# 暂停游戏
	game_paused = true
	
	# 可以在这里添加游戏结束UI显示逻辑
	# 或者重新加载场景
	await get_tree().create_timer(2.0).timeout
	get_tree().reload_current_scene()

# 重置选择数据（用于返回主菜单时）
func reset_selection() -> void:
	selected_player_ids.clear()
	selected_player_weapons.clear()
	player_states.clear()
	current_player_index = 0
	is_game_over = false
