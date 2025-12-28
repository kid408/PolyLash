extends Node2D
class_name ChestManager

# ============================================================================
# 宝箱管理器 - 管理宝箱生成和持久化
# ============================================================================
# 
# 功能说明:
# - 预生成宝箱位置数据，避免运行时计算
# - 根据摄像机位置动态加载/卸载宝箱，优化性能
# - 根据波次配置动态生成新宝箱
# - 持久化宝箱状态（已打开的宝箱不会重复出现）
# 
# 工作原理:
# 1. 游戏开始时预生成一批宝箱位置
# 2. 根据摄像机位置，只实例化视野范围内的宝箱
# 3. 超出视野范围的宝箱会被卸载（但位置数据保留）
# 4. 定期检查玩家周围的宝箱数量，动态生成新宝箱
# 5. 已打开的宝箱会被标记，不会再次实例化
# 
# 性能优化:
# - 使用视野范围过滤，只加载可见的宝箱
# - 宝箱位置数据与实例分离，节省内存
# - 动态加载/卸载机制，避免同时存在大量宝箱
# 
# ============================================================================

# ============================================================================
# 信号
# ============================================================================

signal chest_opened(chest: ChestSimple)  # 宝箱打开信号，传递宝箱对象

# ============================================================================
# 场景引用
# ============================================================================

# 宝箱场景（使用简化版本）
const CHEST_SCENE = preload("res://scenes/items/chest_simple.tscn")

# ============================================================================
# 宝箱数据
# ============================================================================

# 预生成的宝箱位置数据
# 格式: [{id: int, position: Vector2, tier: int, is_opened: bool}, ...]
var chest_positions: Array[Dictionary] = []

# 已实例化的宝箱
# 格式: {chest_id: ChestSimple, ...}
var active_chests: Dictionary = {}

# 已打开的宝箱ID列表
var opened_chest_ids: Array[int] = []

# 下一个宝箱ID（自增）
var next_chest_id: int = 0

# ============================================================================
# 配置参数
# ============================================================================

var spawn_density: int = 3              # 宝箱生成密度
var spawn_radius: float = 2000.0        # 宝箱生成半径
var camera_view_range: float = 1500.0   # 摄像机视野范围

# ============================================================================
# 动态生成
# ============================================================================

var generation_timer: float = 0.0       # 生成计时器
var generation_interval: float = 5.0    # 生成间隔（秒）

# ============================================================================
# 波次信息
# ============================================================================

var current_wave: int = 1               # 当前波次

# ============================================================================
# 节点引用
# ============================================================================

@onready var camera: Camera2D = get_tree().get_first_node_in_group("camera")
@onready var spawner: Spawner = get_parent().get_node_or_null("Spawner")

func _ready() -> void:
	"""
	初始化宝箱管理器
	
	流程:
	1. 从配置中加载参数
	2. 预生成初始宝箱位置
	"""
	# 加载配置
	spawn_density = ConfigManager.get_map_setting("chest_spawn_density", 3)
	spawn_radius = ConfigManager.get_map_setting("chest_spawn_radius", 2000.0)
	
	# 预生成宝箱位置
	_generate_chest_positions()
	
	print("[ChestManager] 初始化完成 - 预生成 %d 个宝箱位置" % chest_positions.size())

func _process(delta: float) -> void:
	"""
	每帧更新
	
	功能:
	1. 更新当前波次
	2. 根据摄像机位置动态加载/卸载宝箱
	3. 定期检查并生成新宝箱
	"""
	if not camera:
		return
	
	# 更新当前波次
	if spawner and is_instance_valid(spawner):
		current_wave = spawner.wave_index
	
	# 根据摄像机位置动态加载/卸载宝箱
	_update_active_chests()
	
	# 动态生成新宝箱
	generation_timer += delta
	
	# 根据波次配置获取生成间隔
	var wave_config = ConfigManager.get_wave_chest_config(current_wave)
	var spawn_interval = wave_config.get("spawn_interval", 30.0)
	
	if generation_timer >= spawn_interval:
		generation_timer = 0.0
		if is_instance_valid(Global.player):
			_generate_new_chests_around_player(Global.player.global_position)

func _generate_chest_positions() -> void:
	"""
	生成初始宝箱位置
	
	说明:
	- 确保宝箱之间有最小距离（避免重叠）
	- 使用重试机制找到合适的位置
	"""
	var rng = RandomNumberGenerator.new()
	rng.randomize()
	
	# 获取当前波次的宝箱配置
	var wave_config = ConfigManager.get_wave_chest_config(current_wave)
	var min_tier = wave_config.get("min_tier", 1)
	var max_tier = wave_config.get("max_tier", 2)
	var chest_count = wave_config.get("chest_count", 3)
	
	# 宝箱之间的最小距离
	const MIN_DISTANCE_BETWEEN_CHESTS = 500.0
	const MAX_RETRIES = 20
	
	# 生成初始宝箱位置
	var chest_id = 0
	for i in range(chest_count):
		var pos = Vector2.ZERO
		var valid_position = false
		
		# 尝试找到一个不与其他宝箱重叠的位置
		for retry in range(MAX_RETRIES):
			# 在圆形区域内随机生成位置
			var angle = rng.randf_range(0, TAU)
			var distance = rng.randf_range(500, spawn_radius)
			pos = Vector2(cos(angle), sin(angle)) * distance
			
			# 检查与其他宝箱的距离
			valid_position = true
			for existing_chest in chest_positions:
				if pos.distance_to(existing_chest["position"]) < MIN_DISTANCE_BETWEEN_CHESTS:
					valid_position = false
					break
			
			if valid_position:
				break
		
		# 如果找到有效位置，添加宝箱
		if valid_position or chest_positions.is_empty():
			# 根据波次配置随机选择宝箱等级
			var selected_tier = rng.randi_range(min_tier, max_tier)
			
			chest_positions.append({
				"id": chest_id,
				"position": pos,
				"tier": selected_tier,
				"is_opened": false
			})
			
			chest_id += 1
	
	# 保存下一个宝箱ID
	next_chest_id = chest_id
	print("[ChestManager] 初始化完成 - 生成 %d 个宝箱（分散布局）" % chest_positions.size())

# 动态生成新宝箱
func _generate_new_chests_around_player(player_pos: Vector2) -> void:
	"""
	在玩家周围动态生成新宝箱
	
	说明:
	- 确保宝箱之间有最小距离
	- 避免宝箱重叠
	"""
	var rng = RandomNumberGenerator.new()
	rng.randomize()
	
	# 获取当前波次的宝箱配置
	var wave_config = ConfigManager.get_wave_chest_config(current_wave)
	var min_tier = wave_config.get("min_tier", 1)
	var max_tier = wave_config.get("max_tier", 2)
	var chest_count = wave_config.get("chest_count", 3)
	
	# 宝箱之间的最小距离
	const MIN_DISTANCE_BETWEEN_CHESTS = 500.0
	const MAX_RETRIES = 20
	
	# 检查玩家周围是否需要生成新宝箱
	var nearby_count = 0
	for chest_data in chest_positions:
		if chest_data["is_opened"]:
			continue
		var distance = player_pos.distance_to(chest_data["position"])
		if distance < spawn_radius * 2:
			nearby_count += 1
	
	# 如果周围宝箱太少，生成新的
	if nearby_count < chest_count:
		var to_generate = chest_count - nearby_count
		
		for i in range(to_generate):
			var pos = Vector2.ZERO
			var valid_position = false
			
			# 尝试找到一个不与其他宝箱重叠的位置
			for retry in range(MAX_RETRIES):
				# 在玩家周围随机生成
				var angle = rng.randf_range(0, TAU)
				var distance = rng.randf_range(spawn_radius * 0.5, spawn_radius * 1.5)
				pos = player_pos + Vector2(cos(angle), sin(angle)) * distance
				
				# 检查与其他宝箱的距离
				valid_position = true
				for existing_chest in chest_positions:
					if not existing_chest["is_opened"] and pos.distance_to(existing_chest["position"]) < MIN_DISTANCE_BETWEEN_CHESTS:
						valid_position = false
						break
				
				if valid_position:
					break
			
			# 如果找到有效位置，添加宝箱
			if valid_position:
				# 根据波次配置随机选择宝箱等级
				var selected_tier = rng.randi_range(min_tier, max_tier)
				
				chest_positions.append({
					"id": next_chest_id,
					"position": pos,
					"tier": selected_tier,
					"is_opened": false
				})
				
				print("[ChestManager] 动态生成新宝箱 ID:%d, 等级:%d (波次:%d)" % [next_chest_id, selected_tier, current_wave])
				next_chest_id += 1

func _update_active_chests() -> void:
	var camera_pos = camera.global_position
	
	# 遍历所有宝箱位置
	for chest_data in chest_positions:
		var chest_id = chest_data["id"]
		var chest_pos = chest_data["position"]
		var distance = camera_pos.distance_to(chest_pos)
		
		# 如果在视野范围内且未实例化
		if distance < camera_view_range and not active_chests.has(chest_id):
			_instantiate_chest(chest_data)
		
		# 如果超出视野范围且已实例化
		elif distance >= camera_view_range and active_chests.has(chest_id):
			_remove_chest(chest_id)

func _instantiate_chest(chest_data: Dictionary) -> void:
	var chest_id = chest_data["id"]
	var chest_pos = chest_data["position"]
	var chest_tier = chest_data["tier"]
	var is_opened = chest_data["is_opened"]
	
	# 如果已经打开，不再实例化
	if is_opened:
		return
	
	var chest = CHEST_SCENE.instantiate()
	if not chest:
		printerr("[ChestManager] 无法实例化宝箱场景")
		return
	
	chest.chest_tier = chest_tier
	chest.is_opened = is_opened
	chest.global_position = chest_pos
	chest.chest_opened.connect(_on_chest_opened.bind(chest_id))
	
	add_child(chest)
	active_chests[chest_id] = chest
	
	# print("[ChestManager] 实例化宝箱 ID:%d, 等级:%d, 位置:%v" % [chest_id, chest_tier, chest_pos])

func _remove_chest(chest_id: int) -> void:
	if not active_chests.has(chest_id):
		return
	
	var chest = active_chests[chest_id]
	if is_instance_valid(chest):
		chest.queue_free()
	
	active_chests.erase(chest_id)

func _on_chest_opened(chest: ChestSimple, chest_id: int) -> void:
	# 标记为已打开
	for chest_data in chest_positions:
		if chest_data["id"] == chest_id:
			chest_data["is_opened"] = true
			break
	
	opened_chest_ids.append(chest_id)
	
	# 发送信号给 Arena
	chest_opened.emit(chest)
	
	print("[ChestManager] 宝箱已打开 - ID: %d, 等级: %d" % [chest_id, chest.get_tier()])

func get_nearby_chests(player_pos: Vector2, max_count: int = 3) -> Array[Dictionary]:
	"""
	获取玩家附近的宝箱（用于指示器）
	
	参数:
	- player_pos: 玩家位置
	- max_count: 最大返回数量
	
	返回:
	- Array[Dictionary]: 宝箱信息数组，按距离排序
	  [{position: Vector2, tier: int, distance: float}, ...]
	
	说明:
	- 只返回未打开的宝箱
	- 按距离从近到远排序
	- 最多返回 max_count 个
	"""
	var nearby: Array[Dictionary] = []
	
	for chest_data in chest_positions:
		if chest_data["is_opened"]:
			continue
		
		var distance = player_pos.distance_to(chest_data["position"])
		nearby.append({
			"position": chest_data["position"],
			"tier": chest_data["tier"],
			"distance": distance
		})
	
	# 按距离排序
	nearby.sort_custom(func(a, b): return a["distance"] < b["distance"])
	
	# 返回最近的N个
	return nearby.slice(0, max_count)
