extends Node

# 闪避文字
signal on_create_block_text(unit:Node2D)
# 伤害数文字
signal on_create_damage_text(unit:Node2D,hitbox:HitboxComponent)

# --- 新增信号 ---
signal on_camera_shake(intensity: float, duration: float)

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

var player:Player
var game_paused:= false

func _ready() -> void:
	# 初始化对象池，防止频繁创建销毁音频节点
	for i in range(POOL_SIZE):
		var player = AudioStreamPlayer.new()
		add_child(player)
		pool.append(player)
		
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
		text_instance.global_position = pos
		text_instance.setup(value, color)
		
