extends Node2D
class_name Spawner

# ============================================================================
# 精英敌人生成器类
# ============================================================================

class EliteSpawner:
	var wave_id: String
	var spawn_config  # EliteSpawnConfig
	var spawn_count: int = 0
	var next_spawn_time: float = 0.0
	var elite_config  # EliteConfig
	
	func _init(wave_id: String, config) -> void:
		self.wave_id = wave_id
		self.spawn_config = config
		self.elite_config = EliteConfigManager.get_elite_config(config.elite_id)
		
		# 初始化下一次生成时间
		next_spawn_time = randf_range(config.spawn_interval_min, config.spawn_interval_max)
	
	func update(delta: float) -> bool:
		"""更新生成器，返回是否应该生成精英敌人"""
		if not spawn_config.enabled:
			return false
		
		if spawn_count >= spawn_config.max_spawn_count:
			return false
		
		next_spawn_time -= delta
		if next_spawn_time <= 0:
			spawn_count += 1
			# 重新计算下一次生成时间
			next_spawn_time = randf_range(spawn_config.spawn_interval_min, spawn_config.spawn_interval_max)
			return true
		
		return false
	
	func get_elite_scene_path() -> String:
		"""获取精英敌人的场景路径"""
		return elite_config.scene_path
	
	func get_elite_id() -> String:
		"""获取精英敌人ID"""
		return spawn_config.elite_id
	
	func is_complete() -> bool:
		"""检查是否已完成所有生成"""
		return spawn_count >= spawn_config.max_spawn_count

# ============================================================================
# 波次生成器 - 管理敌人波次生成系统
# ============================================================================
# 
# 功能说明:
# - 管理游戏的波次系统（共10波）
# - 根据波次配置生成敌人
# - 每波结束后自动进入下一波
# - 完成所有波次后游戏胜利
# 
# 工作流程:
# 1. 开始新波次，启动波次计时器和生成计时器
# 2. 定期生成敌人（固定间隔或随机间隔）
# 3. 敌人在玩家附近随机生成
# 4. 波次时间结束，清除所有敌人
# 5. 增强敌人属性（生命值、伤害）
# 6. 进入下一波或结束游戏
# 
# 暂停机制:
# - 当 Global.game_paused = true 时，所有 Timer 暂停
# - 选择完宝箱属性后，Timer 从暂停位置继续
# 
# ============================================================================

# ============================================================================
# 信号
# ============================================================================

signal wave_completed(wave_number: int)  # 波次完成信号（用于触发商店）

# ============================================================================
# 导出变量（在编辑器中配置）
# ============================================================================

@export var spawn_area_size:= Vector2(1000,500)  # 从CSV加载

# 注意：波次配置现在从CSV加载，不再使用.tres资源
# @export var waves_data: Array[WaveData]          # 已废弃
# @export var enemy_collection: Array[UnitStats]   # 已废弃

# ============================================================================
# 节点引用
# ============================================================================

@onready var spawn_timer: Timer = get_node("SpawnTimer")    # 敌人生成计时器
@onready var wave_timer: Timer = get_node("WaveTimer")      # 波次计时器

# ============================================================================
# 波次状态
# ============================================================================

var wave_index := 1                               # 当前波次（从1开始）
var current_wave_config: Dictionary = {}          # 当前波次配置（从CSV加载）
var current_wave_units: Array = []                # 当前波次的敌人配置
var spawned_enemies:Array[Enemy] = []             # 已生成的敌人列表
var max_waves: int = 10                           # 从CSV加载
var _l_key_pressed: bool = false                  # L键防抖标志

# 精英敌人生成器
var elite_spawners: Array = []                    # 精英敌人生成器列表
var elite_spawn_timer: Timer = null               # 精英敌人生成计时器

# 敌人属性增强（从CSV加载）
var enemy_health_per_wave: float = 10.0           # 每波增加的生命值
var enemy_damage_per_wave: float = 2.0            # 每波增加的伤害

# ============================================================================
# 初始化
# ============================================================================

# ==============================================================================
# 初始化和重置
# ==============================================================================

func reset_spawner() -> void:
	"""重置生成器到初始状态"""
	print("[Spawner] 重置生成器...")
	
	# 停止所有计时器
	if spawn_timer:
		spawn_timer.stop()
	if wave_timer:
		wave_timer.stop()
	if elite_spawn_timer:
		elite_spawn_timer.stop()
	
	# 重置波次索引
	wave_index = 1
	
	# 清空精英生成器
	elite_spawners.clear()
	
	# 重置当前波次配置
	current_wave_config.clear()
	current_wave_units.clear()
	
	print("[Spawner] 生成器重置完成")
	
	# 重新启动第一波
	start_wave()

func _ready() -> void:
	"""
	初始化生成器，从CSV加载配置，开始第一波
	"""
	_load_config_from_csv()
	_init_elite_spawn_timer()
	start_wave()

func _load_config_from_csv() -> void:
	"""
	从CSV加载配置参数
	"""
	# 从map_config加载生成区域大小
	var spawn_width = ConfigManager.get_map_setting("spawn_area_width", 1000.0)
	var spawn_height = ConfigManager.get_map_setting("spawn_area_height", 500.0)
	spawn_area_size = Vector2(spawn_width, spawn_height)
	
	# 从game_config加载波次相关参数
	max_waves = int(ConfigManager.get_game_setting("max_waves", 10))
	enemy_health_per_wave = ConfigManager.get_game_setting("enemy_health_per_wave", 10.0)
	enemy_damage_per_wave = ConfigManager.get_game_setting("enemy_damage_per_wave", 2.0)
	
	print("[Spawner] 从CSV加载配置: spawn_area=%s, max_waves=%d, health_per_wave=%.1f, damage_per_wave=%.1f" % [
		spawn_area_size, max_waves, enemy_health_per_wave, enemy_damage_per_wave
	])

# ============================================================================
# 精英敌人生成器初始化
# ============================================================================

func _init_elite_spawn_timer() -> void:
	"""
	初始化精英敌人生成计时器
	"""
	# 创建精英敌人生成计时器
	elite_spawn_timer = Timer.new()
	elite_spawn_timer.wait_time = 0.1  # 每0.1秒检查一次
	elite_spawn_timer.timeout.connect(_on_elite_spawn_timer_timeout)
	add_child(elite_spawn_timer)

# ============================================================================
# 暂停机制
# ============================================================================

func _process(delta: float) -> void:
	"""
	每帧更新，处理游戏暂停和输入
	
	说明:
	- 当游戏暂停时，暂停所有 Timer
	- 游戏恢复时，Timer 从暂停位置继续
	- 这样可以确保选择宝箱属性时，波次倒计时真正暂停
	- 按L键可以跳过当前波次（用于测试）
	"""
	# 游戏暂停时，暂停Timer
	if Global.game_paused:
		if not spawn_timer.is_paused():
			spawn_timer.set_paused(true)
		if not wave_timer.is_paused():
			wave_timer.set_paused(true)
		if elite_spawn_timer and not elite_spawn_timer.is_paused():
			elite_spawn_timer.set_paused(true)
	else:
		if spawn_timer.is_paused():
			spawn_timer.set_paused(false)
		if wave_timer.is_paused():
			wave_timer.set_paused(false)
		if elite_spawn_timer and elite_spawn_timer.is_paused():
			elite_spawn_timer.set_paused(false)
	
	# 按L键进入下一波（用于测试）
	# 使用 is_physical_key_pressed 配合防抖机制
	if Input.is_physical_key_pressed(KEY_L):
		if not _l_key_pressed:
			_l_key_pressed = true
			go_to_next_wave()
	else:
		_l_key_pressed = false

# ============================================================================
# 波次管理
# ============================================================================

func find_wave_data() -> bool:
	"""
	查找当前波次的配置数据（从CSV）
	
	返回:
	- bool: 是否找到有效配置
	"""
	# 遍历所有波次配置，找到包含当前波次的配置
	for wave_id in ConfigManager.wave_configs.keys():
		var config = ConfigManager.get_wave_config(wave_id)
		var from_wave = config.get("from_wave", 1)
		var to_wave = config.get("to_wave", 1)
		
		if wave_index >= from_wave and wave_index <= to_wave:
			current_wave_config = config
			current_wave_units = ConfigManager.get_wave_units(wave_id)
			print("[Spawner] 找到波次配置: ", wave_id, " (波次 ", from_wave, "-", to_wave, ")")
			print("[Spawner] 敌人种类数: ", current_wave_units.size())
			return true
	
	print("[Spawner] 警告: 未找到波次 ", wave_index, " 的配置")
	return false

func start_wave() -> void:
	"""
	开始新的波次
	
	流程:
	1. 从CSV查找波次配置
	2. 启动波次计时器
	3. 设置敌人生成计时器
	4. 初始化精英敌人生成器
	"""
	if not find_wave_data():
		printerr("[Spawner] 错误: 无法找到波次配置")
		spawn_timer.stop()
		wave_timer.stop()
		return
		
	var wave_time = current_wave_config.get("wave_time", 20.0)
	wave_timer.wait_time = wave_time
	wave_timer.start()
	
	print("[Spawner] 开始波次 ", wave_index, " - 时长: ", wave_time, "秒")
	set_spawn_timer()
	_init_elite_spawners_for_wave()

func update_enemies_new_wave() -> void:
	"""
	更新敌人属性（每波递增）
	
	说明:
	- 每波结束后，敌人的生命值和伤害都会增加
	- 增加量在spawner中配置（enemy_health_per_wave, enemy_damage_per_wave）
	- 注意：这个函数现在不做任何事，因为敌人属性在生成时动态计算
	"""
	# 不再需要修改UnitStats资源
	# 敌人属性增强在spawn_enemy()中动态计算
	pass

func _init_elite_spawners_for_wave() -> void:
	"""
	为当前波次初始化精英敌人生成器
	"""
	# 清空旧的生成器
	elite_spawners.clear()
	
	# 获取当前波次的波次ID
	var wave_id = _get_wave_id_for_index(wave_index)
	if wave_id == "":
		return
	
	# 获取该波次的精英敌人生成配置
	var spawn_configs = EliteConfigManager.get_elite_spawn_configs(wave_id)
	
	for config in spawn_configs:
		if config.enabled:
			var spawner = EliteSpawner.new(wave_id, config)
			elite_spawners.append(spawner)
			print("[Spawner] 创建精英敌人生成器: %s (间隔%.1f-%.1fs, 最多%d个)" % [
				config.elite_id, config.spawn_interval_min, config.spawn_interval_max, config.max_spawn_count
			])
	
	# 启动精英敌人生成计时器
	if not elite_spawners.is_empty():
		if elite_spawn_timer.is_stopped():
			elite_spawn_timer.start()

func _get_wave_id_for_index(index: int) -> String:
	"""
	根据波次索引获取波次ID
	"""
	# 遍历所有波次配置，找到包含当前波次的配置
	for wave_id in ConfigManager.wave_configs.keys():
		var config = ConfigManager.get_wave_config(wave_id)
		var from_wave = config.get("from_wave", 1)
		var to_wave = config.get("to_wave", 1)
		
		if index >= from_wave and index <= to_wave:
			return wave_id
	
	return ""

func clear_enemies() -> void:
	"""
	清除所有敌人
	
	说明:
	- 波次结束时调用
	- 销毁所有已生成的敌人
	- 停止精英敌人生成计时器
	"""
	if spawned_enemies.size() > 0:
		for enemy : Enemy in spawned_enemies:
			if is_instance_valid(enemy):
				enemy.destroy_enemy()
	spawned_enemies.clear()
	
	# 停止精英敌人生成计时器
	if elite_spawn_timer:
		elite_spawn_timer.stop()
	elite_spawners.clear()

# ============================================================================
# 敌人生成
# ============================================================================

func set_spawn_timer() -> void:
	"""
	设置敌人生成计时器
	
	说明:
	- 根据波次配置的生成类型设置间隔
	- FIXED: 固定间隔
	- RANDOM: 随机间隔（在最小和最大值之间）
	"""
	var spawn_type = current_wave_config.get("spawn_type", "RANDOM")
	
	if spawn_type == "FIXED":
		var fixed_time = current_wave_config.get("fixed_spawn_time", 1.0)
		spawn_timer.wait_time = fixed_time
	else:  # RANDOM
		var min_t = current_wave_config.get("min_spawn_time", 0.8)
		var max_t = current_wave_config.get("max_spawn_time", 1.5)
		spawn_timer.wait_time = randf_range(min_t, max_t)
		
	if spawn_timer.is_stopped():
		spawn_timer.start()

func get_random_spawn_position() -> Vector2:
	"""
	获取随机生成位置（在玩家附近）
	
	返回:
	- Vector2: 在玩家周围的随机位置
	
	说明:
	- 在玩家周围一定范围内随机生成
	- 如果玩家不存在，使用原点作为中心
	- 只在玩家前方生成（避免屏幕外）
	- 生成位置被限制在合理的屏幕范围内
	"""
	var center_pos = Vector2.ZERO
	
	# 如果玩家存在，使用玩家位置作为中心
	if is_instance_valid(Global.player):
		center_pos = Global.player.global_position
	
	# 在玩家周围随机生成，但只在正面范围内（避免屏幕外）
	# spawn_area_size = (1000, 500)
	# X范围: -500 到 +500 (相对玩家)
	# Y范围: 0 到 +500 (只在玩家前方)
	var random_x := randf_range(-spawn_area_size.x / 2.0, spawn_area_size.x / 2.0)
	var random_y := randf_range(0, spawn_area_size.y)
	
	var spawn_pos = center_pos + Vector2(random_x, random_y)
	
	# 【修复】不使用camera_view_range进行clamping，因为那会导致敌人生成在屏幕外
	# 相反，我们直接限制在spawn_area_size定义的范围内
	# 这确保敌人总是在玩家周围的合理范围内
	
	# 额外的安全检查：确保Y坐标不会太极端
	# 如果玩家在屏幕顶部附近，确保敌人不会生成在屏幕上方太远的地方
	var min_y = center_pos.y - 200.0  # 允许在玩家上方200像素
	var max_y = center_pos.y + spawn_area_size.y + 200.0  # 允许在玩家下方超过spawn_area_size 200像素
	
	spawn_pos.y = clamp(spawn_pos.y, min_y, max_y)
	
	print("[Spawner] 生成位置计算: 玩家=", center_pos, " 随机偏移=(", random_x, ",", random_y, ") 最终位置=", spawn_pos)
	
	return spawn_pos

func spawn_enemy() -> void:
	"""
	生成一个敌人
	
	流程:
	1. 从波次配置中随机选择敌人场景（基于权重）
	2. 在随机位置实例化敌人
	3. 应用波次增强（生命值、伤害）
	4. 添加到场景树
	5. 记录到已生成列表
	6. 重新设置生成计时器
	"""
	if current_wave_units.is_empty():
		print("[Spawner] 警告: 当前波次没有敌人配置")
		return
	
	# 根据权重随机选择敌人
	var enemy_data = get_random_enemy_data()
	if enemy_data.is_empty():
		print("[Spawner] 错误: 无法获取敌人数据")
		return
	
	var enemy_scene_path = enemy_data.get("enemy_scene", "")
	var enemy_id = enemy_data.get("enemy_id", "basic_enemy")
	
	var enemy_scene = load(enemy_scene_path) as PackedScene
	if not enemy_scene:
		print("[Spawner] 错误: 无法加载敌人场景: ", enemy_scene_path)
		return
	
	var spawn_pos = get_random_spawn_position()
	var enemy_instance = enemy_scene.instantiate() as Enemy
	enemy_instance.global_position = spawn_pos
	enemy_instance.enemy_id = enemy_id
	print("[Spawner] 生成敌人，enemy_id = ", enemy_id, " 位置: ", spawn_pos)
	
	# 应用波次增强（敌人现在使用直接属性）
	if "health" in enemy_instance:
		enemy_instance.health += (wave_index - 1) * enemy_health_per_wave
	if "damage" in enemy_instance:
		enemy_instance.damage += (wave_index - 1) * enemy_damage_per_wave
	
	get_parent().add_child(enemy_instance)
	spawned_enemies.append(enemy_instance)
	
	set_spawn_timer()

func get_random_enemy_data() -> Dictionary:
	"""
	根据权重随机选择敌人数据
	
	返回:
	- Dictionary: {enemy_scene: "...", enemy_id: "...", weight: 1.0}
	"""
	if current_wave_units.is_empty():
		return {}
	
	# 收集所有敌人和权重
	var enemies: Array[Dictionary] = []
	var weights: Array[float] = []
	
	for unit in current_wave_units:
		var scene_path = unit.get("enemy_scene", "")
		var enemy_id = unit.get("enemy_id", "basic_enemy")
		var weight = unit.get("weight", 1.0)
		
		if scene_path != "":
			enemies.append(unit)
			weights.append(weight)
	
	if enemies.is_empty():
		return {}
	
	# 根据权重随机选择
	var rng = RandomNumberGenerator.new()
	var index = rng.rand_weighted(weights)
	
	return enemies[index]

# ============================================================================
# 精英敌人生成
# ============================================================================

func spawn_elite(spawner: EliteSpawner) -> void:
	"""
	生成一个精英敌人
	"""
	var scene_path = spawner.get_elite_scene_path()
	var elite_id = spawner.get_elite_id()
	
	# 加载场景
	var scene = load(scene_path)
	if scene == null:
		print("[Spawner] 错误：无法加载精英敌人场景: %s" % scene_path)
		return
	
	# 创建实例
	var elite = scene.instantiate()
	
	# 设置初始位置
	elite.global_position = get_random_spawn_position()
	
	# 设置初始属性
	var wave_id = _get_wave_id_for_index(wave_index)
	var wave_config = EliteConfigManager.get_elite_for_wave(wave_id, elite_id)
	if wave_config:
		if elite.has_method("set_initial_stage"):
			elite.set_initial_stage(wave_config.initial_stage)
		if elite.has_method("set_allow_evolution"):
			elite.set_allow_evolution(wave_config.allow_evolution)
	
	# 添加到场景
	get_parent().add_child(elite)
	spawned_enemies.append(elite)
	
	print("[Spawner] 生成精英敌人: %s (阶段%d)" % [elite_id, wave_config.initial_stage if wave_config else 1])

# ============================================================================
# UI 辅助方法
# ============================================================================

func get_wave_text() -> String:
	"""
	获取波次显示文本
	
	返回:
	- String: 格式化的波次文本，如 "Wave 3"
	"""
	return "Wave %s" % wave_index
	
func get_wave_timer_text() -> String:
	"""
	获取波次倒计时文本
	
	返回:
	- String: 剩余秒数，如 "45"
	"""
	return str(max(0,int(wave_timer.time_left)))

# ============================================================================
# 信号回调
# ============================================================================

func _on_spawn_timer_timeout() -> void:
	"""
	生成计时器超时回调
	
	说明:
	- 如果波次已结束，停止生成
	- 否则生成一个敌人
	"""
	if current_wave_config.is_empty() or wave_timer.is_stopped():
		spawn_timer.stop()
		return
		
	spawn_enemy()

func _on_elite_spawn_timer_timeout() -> void:
	"""
	精英敌人生成计时器超时回调
	
	说明:
	- 更新所有精英敌人生成器
	- 如果生成器返回true，则生成精英敌人
	"""
	if wave_timer.is_stopped() or elite_spawners.is_empty():
		elite_spawn_timer.stop()
		return
	
	for spawner in elite_spawners:
		if spawner.update(0.1):  # 0.1秒是计时器间隔
			spawn_elite(spawner)


func go_to_next_wave() -> void:
	"""
	进入下一波（用于测试）- 按 L 键触发
	
	流程:
	1. 停止所有计时器
	2. 清除所有敌人
	3. 增强敌人属性
	4. 检查是否达到最大波次
	5. 发出 wave_completed 信号（触发商店）
	"""
	if Global.game_paused:
		return
	
	print("[Spawner] 跳过当前波次 (当前波次: %d)" % wave_index)
	
	# 停止计时器
	spawn_timer.stop()
	wave_timer.stop()
	
	# 清除敌人并增强属性
	clear_enemies()
	update_enemies_new_wave()
	
	# 检查是否达到最大波次
	if wave_index >= max_waves:
		print("[Spawner] 达到最大波次 %d，游戏结束！" % max_waves)
		_end_game()
		return
	
	# 发出波次完成信号（触发商店显示）
	print("[Spawner] 波次 %d 完成（L键跳过），发出 wave_completed 信号" % wave_index)
	wave_completed.emit(wave_index)
	
	# 注意：不要立即开始下一波，等待商店关闭后调用 start_next_wave()

func _on_wave_timer_timeout() -> void:
	"""
	波次计时器超时回调
	
	流程:
	1. 停止敌人生成
	2. 清除所有敌人
	3. 增强敌人属性
	4. 检查是否达到最大波次
	5. 发出波次完成信号（触发商店）
	6. 等待商店关闭后再开始下一波
	"""
	spawn_timer.stop()
	clear_enemies()
	update_enemies_new_wave()
	
	# 检查是否达到最大波次
	if wave_index >= max_waves:
		print("[Spawner] 达到最大波次 %d，游戏结束！" % max_waves)
		_end_game()
		return
	
	# 发出波次完成信号（触发商店显示）
	print("[Spawner] 波次 %d 完成，发出 wave_completed 信号" % wave_index)
	wave_completed.emit(wave_index)
	
	# 注意：不要立即开始下一波，等待商店关闭后调用 start_next_wave()

# ============================================================================
# 游戏结束
# ============================================================================

func _end_game() -> void:
	"""
	结束游戏（胜利）
	
	流程:
	1. 停止所有 Timer
	2. 清除所有敌人
	3. 显示胜利信息
	4. 等待3秒后重新加载场景
	"""
	# 停止所有Timer
	spawn_timer.stop()
	wave_timer.stop()
	
	# 清除所有敌人
	clear_enemies()
	
	# 显示胜利信息
	Global.spawn_floating_text(Vector2(960, 540), "胜利！", Color.GOLD)
	
	print("[Spawner] 游戏结束 - 完成 %d 波" % max_waves)
	
	# 等待3秒后重新加载场景
	await get_tree().create_timer(3.0).timeout
	get_tree().reload_current_scene()

# ============================================================================
# 商店系统集成
# ============================================================================

func pause_spawning() -> void:
	"""暂停生成（商店打开时）"""
	print("[Spawner] 暂停生成")
	
	if spawn_timer:
		spawn_timer.paused = true
	if wave_timer:
		wave_timer.paused = true
	if elite_spawn_timer:
		elite_spawn_timer.paused = true

func resume_spawning() -> void:
	"""恢复生成（商店关闭时）"""
	print("[Spawner] 恢复生成")
	
	if spawn_timer:
		spawn_timer.paused = false
	if wave_timer:
		wave_timer.paused = false
	if elite_spawn_timer:
		elite_spawn_timer.paused = false
	
	# 开始下一波
	start_next_wave()

func start_next_wave() -> void:
	"""开始下一波（从商店系统调用）"""
	wave_index += 1
	
	if wave_index > max_waves:
		print("[Spawner] 所有波次完成！")
		_end_game()
		return
	
	print("[Spawner] 开始第 %d 波" % wave_index)
	Global.spawn_floating_text(Vector2(960, 540), "第 %d 波开始！" % wave_index, Color.CYAN)
	start_wave()
