extends Node

# ============================================================================
# 音效管理器 - 通过CSV配置管理所有游戏音效
# ============================================================================
# 
# 功能说明:
# - 通过 CSV 配置文件管理所有音效
# - 使用对象池技术优化性能，避免频繁创建/销毁节点
# - 支持音量和音调的随机变化，增加音效多样性
# - 安全处理音效文件不存在的情况，不会导致游戏崩溃
# 
# 工作原理:
# 1. 游戏启动时预加载所有音效文件
# 2. 创建固定数量的 AudioStreamPlayer 对象池
# 3. 播放音效时从对象池中循环取用
# 4. 音效播放完毕后自动回收到对象池
# 
# 使用方法:
#   # 方式1: 使用通用方法
#   SoundManager.play_sound("player_attack")
#   
#   # 方式2: 使用便捷方法
#   SoundManager.play_player_attack()
# 
# 配置方法:
#   在 config/sound_config.csv 中添加音效配置:
#   sound_id,sound_path,volume_db,min_pitch,max_pitch,description
#   my_sound,res://assets/audio/my_sound.wav,0.0,0.9,1.1,我的音效
# 
# 安全机制:
# - 如果音效文件不存在，只会在控制台输出警告
# - 不会导致游戏崩溃或中断
# - 音效会被跳过，游戏继续运行
# 
# ============================================================================

# ============================================================================
# 对象池配置
# ============================================================================

# 音效对象池大小
# 说明: 同时最多可以播放32个音效，超过则会覆盖最早的音效
const POOL_SIZE = 32

# 音效播放器对象池
var pool: Array[AudioStreamPlayer] = []

# 下一个使用的对象池索引（循环使用）
var next_idx = 0

# ============================================================================
# 音效缓存
# ============================================================================

# 音效资源缓存
# 格式: {sound_id: AudioStream, ...}
# 说明: 预加载所有音效，避免运行时加载造成卡顿
var sound_cache: Dictionary = {}

# ============================================================================
# 初始化
# ============================================================================

func _ready() -> void:
	"""
	Godot 生命周期函数，节点准备就绪时调用
	
	初始化流程:
	1. 创建对象池
	2. 预加载所有音效
	"""
	print("=== 音效管理器初始化 ===")
	
	# 初始化对象池
	for i in range(POOL_SIZE):
		var player = AudioStreamPlayer.new()
		add_child(player)
		pool.append(player)
	
	# 预加载所有音效
	_preload_sounds()
	
	print("=== 音效管理器初始化完成 ===")

func _preload_sounds() -> void:
	"""
	预加载所有音效文件
	
	说明:
	- 从 ConfigManager 读取音效配置
	- 尝试加载每个音效文件
	- 如果文件不存在或加载失败，缓存为 null
	- 不会因为单个音效加载失败而中断整个流程
	"""
	var sound_configs = ConfigManager.get_all_sound_configs()
	
	for sound_id in sound_configs.keys():
		var config = sound_configs[sound_id]
		var sound_path = config.get("sound_path", "")
		
		if sound_path == "" or not ResourceLoader.exists(sound_path):
			print("[SoundManager] 警告: 音效文件不存在或路径为空: %s (%s)" % [sound_id, sound_path])
			sound_cache[sound_id] = null
			continue
		
		var stream = load(sound_path)
		if stream:
			sound_cache[sound_id] = stream
			print("[SoundManager] 加载音效: %s -> %s" % [sound_id, sound_path])
		else:
			print("[SoundManager] 警告: 无法加载音效: %s (%s)" % [sound_id, sound_path])
			sound_cache[sound_id] = null

# ============================================================================
# 核心功能 - 音效播放
# ============================================================================

func play_sound(sound_id: String) -> void:
	"""
	播放音效（通过sound_id）
	
	参数:
	- sound_id: 音效ID（在 sound_config.csv 中定义）
	
	说明:
	- 从缓存中获取音效资源
	- 如果音效不存在，不会崩溃，只是不播放
	- 从配置中读取音量和音调设置
	- 调用内部播放函数
	
	示例:
	  SoundManager.play_sound("player_attack")
	"""
	var stream = sound_cache.get(sound_id, null)
	
	# 如果音效不存在，不崩溃，只是不播放
	if not stream:
		# print("[SoundManager] 音效未找到或未加载: %s" % sound_id)
		return
	
	var config = ConfigManager.get_sound_config(sound_id)
	if config.is_empty():
		print("[SoundManager] 警告: 音效配置未找到: %s" % sound_id)
		return
	
	var volume_db = config.get("volume_db", 0.0)
	var min_pitch = config.get("min_pitch", 1.0)
	var max_pitch = config.get("max_pitch", 1.0)
	
	_play_sfx(stream, min_pitch, max_pitch, volume_db)

func _play_sfx(stream: AudioStream, min_pitch: float, max_pitch: float, volume_db: float) -> void:
	"""
	内部播放函数
	
	参数:
	- stream: 音效资源
	- min_pitch: 最小音调
	- max_pitch: 最大音调
	- volume_db: 音量（分贝）
	
	说明:
	- 从对象池中循环取用播放器
	- 设置音效资源、音调、音量
	- 播放音效
	- 音调在 min_pitch 和 max_pitch 之间随机，增加变化感
	"""
	if not stream:
		return
	
	var player = pool[next_idx]
	next_idx = (next_idx + 1) % POOL_SIZE
	
	player.stream = stream
	player.pitch_scale = randf_range(min_pitch, max_pitch)
	player.volume_db = volume_db
	player.play()

# ============================================================================
# 便捷方法 - 玩家音效
# ============================================================================
# 说明: 这些方法提供更简洁的调用方式，内部调用 play_sound()

func play_player_attack() -> void:
	"""播放玩家普通攻击音效"""
	play_sound("player_attack")

func play_player_hit() -> void:
	"""播放玩家受击音效"""
	play_sound("player_hit")

func play_player_dash() -> void:
	"""播放玩家冲刺音效"""
	play_sound("player_dash")

func play_player_skill_q() -> void:
	"""播放玩家Q技能音效"""
	play_sound("player_skill_q")

func play_player_skill_e() -> void:
	"""播放玩家E技能音效"""
	play_sound("player_skill_e")

func play_player_death() -> void:
	"""播放玩家死亡音效"""
	play_sound("player_death")

# ============================================================================
# 便捷方法 - 敌人音效
# ============================================================================

func play_enemy_attack() -> void:
	"""播放敌人攻击音效"""
	play_sound("enemy_attack")

func play_enemy_death() -> void:
	"""播放敌人死亡音效"""
	play_sound("enemy_death")

func play_enemy_hit() -> void:
	"""播放敌人受击音效"""
	play_sound("enemy_hit")

# ============================================================================
# 兼容旧接口
# ============================================================================
# 说明: 为了兼容旧代码，保留这些方法

func play_enemy_pop() -> void:
	"""兼容旧接口 - 播放敌人死亡音效"""
	play_enemy_death()

func play_loop_kill_impact() -> void:
	"""兼容旧接口 - 播放连杀音效"""
	# 可以添加特殊的连杀音效
	play_sound("loop_kill")

func play_explosion() -> void:
	"""兼容旧接口 - 播放爆炸音效"""
	play_sound("player_explosion")
