extends Node

# ============================================================================
# SoundManager - 独立音效管理自动加载节点
# ============================================================================
# CSV 驱动的音效管理系统，拥有独立的 AudioStreamPlayer 对象池
# 通过 sound_id 字符串作为唯一外部接口
# ============================================================================

# ============================================================================
# 常量
# ============================================================================
const POOL_SIZE: int = 32

const CSV_PATHS: Dictionary = {
	"ui": "res://config/audio/ui_sounds.csv",
	"combat": "res://config/audio/combat_sounds.csv",
	"skill": "res://config/audio/skill_sounds.csv",
	"environment": "res://config/audio/environment_sounds.csv"
}

# ============================================================================
# 内部数据
# ============================================================================

# 音频对象池
var _pool: Array[AudioStreamPlayer] = []
var _next_idx: int = 0

# 音效配置：sound_id → {sound_path, volume_db, min_pitch, max_pitch, cooldown, group, description}
var _sound_configs: Dictionary = {}

# 音频资源缓存：sound_path → AudioStream
var _audio_cache: Dictionary = {}

# 冷却追踪：sound_id → 上次播放时间（msec）
var _cooldown_tracker: Dictionary = {}

# 音效组映射：group → [sound_id, sound_id, ...]
var _group_map: Dictionary = {}

# end_time 追踪：player_index → end_time（秒）
var _end_time_tracker: Dictionary = {}

# ============================================================================
# 生命周期
# ============================================================================

func _ready() -> void:
	# 1. 初始化对象池
	_init_pool()
	
	# 2. 加载 CSV 配置
	_load_all_csv_configs()
	
	# 3. 预加载音频资源
	_preload_audio_resources()
	
	# 4. 构建音效组映射
	_build_group_map()
	
	# 5. 自动为所有按钮连接悬停音效
	get_tree().node_added.connect(_on_node_added)
	
	print("[SoundManager] 初始化完成: %d 条配置, %d 个音频缓存, %d 个音效组" % [
		_sound_configs.size(), _audio_cache.size(), _group_map.size()
	])

# ============================================================================
# 公开接口
# ============================================================================

## 播放音效（核心方法）
func play(sound_id: String) -> void:
	# 1. 检查 sound_id 是否存在
	if not _sound_configs.has(sound_id):
		push_warning("[SoundManager] 未知的 sound_id: %s" % sound_id)
		return
	
	var config = _sound_configs[sound_id]
	
	# 2. 检查开关
	if int(config.get("enabled", 1)) == 0:
		return
	
	# 3. 检查冷却
	var cooldown = float(config.get("cooldown", 0))
	if cooldown > 0:
		var now = Time.get_ticks_msec()
		var last_play = _cooldown_tracker.get(sound_id, 0)
		if (now - last_play) < cooldown * 1000:
			return  # 冷却中，忽略
		_cooldown_tracker[sound_id] = now
	
	# 4. 如果属于音效组，随机选取
	var actual_id = sound_id
	var group = str(config.get("group", ""))
	if group != "" and _group_map.has(group):
		var group_members = _group_map[group]
		actual_id = group_members[randi() % group_members.size()]
		config = _sound_configs[actual_id]
	
	# 5. 获取音频资源
	var sound_path = str(config.get("sound_path", ""))
	if not _audio_cache.has(sound_path):
		push_warning("[SoundManager] 音频未缓存: %s" % sound_path)
		return
	
	var stream = _audio_cache[sound_path]
	
	# 6. 播放
	var min_pitch = float(config.get("min_pitch", 1.0))
	var max_pitch = float(config.get("max_pitch", 1.0))
	var volume_db = float(config.get("volume_db", 0.0))
	var start_time = float(config.get("start_time", 0.0))
	var end_time = float(config.get("end_time", 0.0))
	
	_play_stream(stream, min_pitch, max_pitch, volume_db, start_time, end_time)

## 播放音效组中的随机音效
func play_group(group: String) -> void:
	if not _group_map.has(group):
		push_warning("[SoundManager] 未知的音效组: %s" % group)
		return
	
	var members = _group_map[group]
	var random_id = members[randi() % members.size()]
	play(random_id)

## 播放角色专属 Q 闭合音效
func play_character_q_closure(player_id: String) -> void:
	# 1. 从 ConfigManager 获取角色配置
	var config = ConfigManager.get_player_config(player_id)
	
	# 2. 检查开关
	if int(config.get("q_closure_sfx_enabled", 1)) == 0:
		return
	
	var sfx_path = str(config.get("q_closure_sfx", ""))
	
	# 3. 如果路径为空或文件未缓存，回退到通用音效
	if sfx_path == "" or not _audio_cache.has(sfx_path):
		play("skill_q_closure_generic")
		return
	
	# 4. 播放角色专属音效（音量从 CSV 读取）
	var stream = _audio_cache[sfx_path]
	var volume_db = float(config.get("q_closure_volume_db", 0.0))
	_play_stream(stream, 0.9, 1.1, volume_db)

## 分类播放（语义别名）
func play_ui(sound_id: String) -> void:
	play(sound_id)

func play_combat(sound_id: String) -> void:
	play(sound_id)

func play_skill(sound_id: String) -> void:
	play(sound_id)

func play_environment(sound_id: String) -> void:
	play(sound_id)

## 获取音效配置
func get_sound_config(sound_id: String) -> Dictionary:
	return _sound_configs.get(sound_id, {})

## 检查音效是否存在
func has_sound(sound_id: String) -> bool:
	return _sound_configs.has(sound_id)

# ============================================================================
# 内部方法
# ============================================================================

## 初始化对象池
func _init_pool() -> void:
	for i in range(POOL_SIZE):
		var audio_player = AudioStreamPlayer.new()
		add_child(audio_player)
		_pool.append(audio_player)

## 加载所有 CSV 配置
func _load_all_csv_configs() -> void:
	for category in CSV_PATHS:
		var path = CSV_PATHS[category]
		var configs = ConfigManager.load_csv_as_dict(path, "sound_id")
		
		# 合并到总配置
		for sound_id in configs:
			if _sound_configs.has(sound_id):
				push_warning("[SoundManager] 重复的 sound_id: %s (来自 %s)" % [sound_id, path])
			_sound_configs[sound_id] = configs[sound_id]

## 预加载音频资源
func _preload_audio_resources() -> void:
	# 预加载 CSV 中的音频
	for sound_id in _sound_configs:
		var config = _sound_configs[sound_id]
		var sound_path = str(config.get("sound_path", ""))
		
		if sound_path == "" or _audio_cache.has(sound_path):
			continue
		
		if not ResourceLoader.exists(sound_path):
			push_warning("[SoundManager] 音频文件不存在: %s (sound_id: %s)" % [sound_path, sound_id])
			continue
		
		var stream = load(sound_path)
		if stream:
			_audio_cache[sound_path] = stream
	
	# 预加载角色 Q 闭合音效
	for player_id in ConfigManager.player_configs:
		var config = ConfigManager.player_configs[player_id]
		var sfx_path = str(config.get("q_closure_sfx", ""))
		
		if sfx_path == "" or _audio_cache.has(sfx_path):
			continue
		
		if not ResourceLoader.exists(sfx_path):
			push_warning("[SoundManager] Q闭合音频不存在: %s (player: %s)" % [sfx_path, player_id])
			continue
		
		var stream = load(sfx_path)
		if stream:
			_audio_cache[sfx_path] = stream

## 构建音效组映射
func _build_group_map() -> void:
	for sound_id in _sound_configs:
		var config = _sound_configs[sound_id]
		var group = str(config.get("group", ""))
		
		if group == "":
			continue
		
		if not _group_map.has(group):
			_group_map[group] = []
		_group_map[group].append(sound_id)

## 内部播放方法
func _play_stream(stream: AudioStream, min_pitch: float, max_pitch: float, volume_db: float, start_time: float = 0.0, end_time: float = 0.0) -> void:
	var player_idx = _next_idx
	var audio_player = _pool[player_idx]
	_next_idx = (_next_idx + 1) % POOL_SIZE
	
	audio_player.stream = stream
	audio_player.pitch_scale = randf_range(min_pitch, max_pitch)
	audio_player.volume_db = volume_db
	audio_player.play(start_time)
	
	# 注册 end_time 追踪
	if end_time > start_time:
		_end_time_tracker[player_idx] = end_time
	elif _end_time_tracker.has(player_idx):
		_end_time_tracker.erase(player_idx)

## end_time 轮询检测
func _process(_delta: float) -> void:
	if _end_time_tracker.is_empty():
		return
	var to_remove: Array[int] = []
	for idx in _end_time_tracker:
		var player = _pool[idx]
		if not player.playing:
			to_remove.append(idx)
		elif player.get_playback_position() >= _end_time_tracker[idx]:
			player.stop()
			to_remove.append(idx)
	for idx in to_remove:
		_end_time_tracker.erase(idx)

## 自动为新加入场景树的按钮连接悬停音效
func _on_node_added(node: Node) -> void:
	if node is BaseButton:
		node.mouse_entered.connect(_on_button_hover)

func _on_button_hover() -> void:
	play("ui_hover")
