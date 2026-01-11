extends Node2D
class_name Spawner

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

# 敌人属性增强（从CSV加载）
var enemy_health_per_wave: float = 10.0           # 每波增加的生命值
var enemy_damage_per_wave: float = 2.0            # 每波增加的伤害

# ============================================================================
# 初始化
# ============================================================================

func _ready() -> void:
	"""
	初始化生成器，从CSV加载配置，开始第一波
	"""
	_load_config_from_csv()
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
	else:
		if spawn_timer.is_paused():
			spawn_timer.set_paused(false)
		if wave_timer.is_paused():
			wave_timer.set_paused(false)
	
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

func clear_enemies() -> void:
	"""
	清除所有敌人
	
	说明:
	- 波次结束时调用
	- 销毁所有已生成的敌人
	"""
	if spawned_enemies.size() > 0:
		for enemy : Enemy in spawned_enemies:
			if is_instance_valid(enemy):
				enemy.destroy_enemy()
	spawned_enemies.clear()

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
	"""
	var center_pos = Vector2.ZERO
	
	# 如果玩家存在，使用玩家位置作为中心
	if is_instance_valid(Global.player):
		center_pos = Global.player.global_position
	
	# 在玩家周围随机生成
	var random_x := randf_range(-spawn_area_size.x, spawn_area_size.x)
	var random_y := randf_range(-spawn_area_size.y, spawn_area_size.y)
	
	return center_pos + Vector2(random_x, random_y)

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
	var enemy_scene_path = get_random_enemy_scene()
	if enemy_scene_path == "":
		print("[Spawner] 错误: 无法获取敌人场景")
		return
	
	var enemy_scene = load(enemy_scene_path) as PackedScene
	if not enemy_scene:
		print("[Spawner] 错误: 无法加载敌人场景: ", enemy_scene_path)
		return
	
	var spawn_pos = get_random_spawn_position()
	var enemy_instance = enemy_scene.instantiate() as Enemy
	enemy_instance.global_position = spawn_pos
	
	# 应用波次增强（如果敌人有stats）
	if enemy_instance.stats:
		enemy_instance.stats.health += (wave_index - 1) * enemy_health_per_wave
		enemy_instance.stats.damage += (wave_index - 1) * enemy_damage_per_wave
	
	get_parent().add_child(enemy_instance)
	spawned_enemies.append(enemy_instance)
	
	set_spawn_timer()

func get_random_enemy_scene() -> String:
	"""
	根据权重随机选择敌人场景
	
	返回:
	- String: 敌人场景路径
	"""
	if current_wave_units.is_empty():
		return ""
	
	# 收集所有敌人和权重
	var enemies: Array[String] = []
	var weights: Array[float] = []
	
	for unit in current_wave_units:
		var scene_path = unit.get("enemy_scene", "")
		var weight = unit.get("weight", 1.0)
		
		if scene_path != "":
			enemies.append(scene_path)
			weights.append(weight)
	
	if enemies.is_empty():
		return ""
	
	# 根据权重随机选择
	var rng = RandomNumberGenerator.new()
	var index = rng.rand_weighted(weights)
	
	return enemies[index]

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


func go_to_next_wave() -> void:
	"""
	进入下一波（用于测试）
	
	流程:
	1. 停止所有计时器
	2. 清除所有敌人
	3. 增强敌人属性
	4. 检查是否达到最大波次
	5. 如果是，结束游戏；否则立即进入下一波
	"""
	if Global.game_paused:
		return
	
	print("[Spawner] 进入下一波 (当前波次: %d)" % wave_index)
	
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
	
	# 立即进入下一波
	wave_index += 1
	Global.spawn_floating_text(Vector2(960, 540), "进入第 %d 波！" % wave_index, Color.CYAN)
	start_wave()

func _on_wave_timer_timeout() -> void:
	"""
	波次计时器超时回调
	
	流程:
	1. 停止敌人生成
	2. 清除所有敌人
	3. 增强敌人属性
	4. 检查是否达到最大波次
	5. 如果是，结束游戏；否则进入下一波
	"""
	spawn_timer.stop()
	clear_enemies()
	update_enemies_new_wave()
	
	# 检查是否达到最大波次
	if wave_index >= max_waves:
		print("[Spawner] 达到最大波次 %d，游戏结束！" % max_waves)
		_end_game()
		return
	
	# 进入下一波
	wave_index += 1
	
	# 短暂延迟后开始下一波
	await get_tree().create_timer(1.0).timeout
	start_wave()

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
