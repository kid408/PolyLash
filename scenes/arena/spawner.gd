extends Node2D
class_name Spawner

const DEBUG_VERBOSE := false

# 内部类定义
# 内部类定义
# 内部类定义

class EliteSpawner:
	var wave_id: String
	var spawn_config
	var spawn_count: int = 0
	var next_spawn_time: float = 0.0
	var elite_config
	
	func _init(wave_id: String, config) -> void:
		self.wave_id = wave_id
		self.spawn_config = config
		self.elite_config = EliteConfigManager.get_elite_config(config.elite_id)
		

		next_spawn_time = randf_range(config.spawn_interval_min, config.spawn_interval_max)
	
	func update(delta: float) -> bool:
		"""更新精英刷怪计时器，返回是否应生成精英。"""
		if not spawn_config.enabled:
			return false
		
		if spawn_count >= spawn_config.max_spawn_count:
			return false
		
		next_spawn_time -= delta
		if next_spawn_time <= 0:
			spawn_count += 1

			next_spawn_time = randf_range(spawn_config.spawn_interval_min, spawn_config.spawn_interval_max)
			return true
		
		return false
	
	func get_elite_scene_path() -> String:
		"""Return the scene path for this elite enemy."""
		return elite_config.scene_path
	
	func get_elite_id() -> String:
		"""获取精英敌人 ID。"""
		return spawn_config.elite_id
	
	func is_complete() -> bool:
		"""Return true when this elite spawner finished all quotas."""
		return spawn_count >= spawn_config.max_spawn_count

# 信号定义
# 信号定义
# 信号定义
# 信号定义
# 信号定义
# 信号定义
# 信号定义
# 信号定义
# 信号定义
# 信号定义
# 信号定义
# 信号定义
# 信号定义
# 信号定义
# 信号定义
# 信号定义
# 信号定义
# 信号定义
# 信号定义
# 信号定义
# 信号定义
# 信号定义
# 信号定义

# 信号定义
# 信号定义
# 信号定义

signal wave_completed(wave_number: int)

# 字段定义
# 字段定义
# 字段定义

@export var spawn_area_size:= Vector2(1000,500)
@export_group("Ring Spawn")
@export var spawn_ring_inner_padding: float = 180.0
@export var spawn_ring_thickness: float = 220.0
@export var spawn_ring_vertical_scale: float = 0.82
@export_group("Test Overrides")
@export var spawn_interval: float = 0.0
@export var max_enemies_on_screen: int = 0

# 字段定义
# 字段定义
# 字段定义

# 字段定义
# 字段定义
# 字段定义

@onready var spawn_timer: Timer = get_node("SpawnTimer")
@onready var wave_timer: Timer = get_node("WaveTimer")

# 字段定义
# 字段定义
# 字段定义

var wave_index := 1
var current_wave_config: Dictionary = {}
var current_wave_units: Array = []
var spawned_enemies:Array[Enemy] = []
var max_waves: int = 10
var _skip_wave_key_pressed: bool = false

# 字段定义
var elite_spawners: Array = []
var elite_spawn_timer: Timer = null

# 字段定义
var enemy_health_per_wave: float = 10.0
var enemy_damage_per_wave: float = 2.0
# 字段定义
const PEAK_WAVES := [5, 10, 15, 20]
const ROLE_CAPS := {
	"shooter": 0.22,
	"charger": 0.15,
	"denier": 0.18
}
const AFFIX_POOL := ["Swift", "Titan", "Vamp", "Split"]
const SYNERGY_TEST_WAVE_TIME_DEFAULT: float = 999.0
const AUTO_SHOW_WAVE_TIME_DEFAULT: float = 999.0

var _director_enabled: bool = false
var enemy_speed_scale: float = 1.0
var _enemy_v2: Dictionary = {}
var _wave_v2: Dictionary = {}
var _wave_units_v2: Dictionary = {}
var _director_budget_total: float = 0.0
var _director_budget_spent: float = 0.0
var _director_role_spawned: Dictionary = {}
var _director_total_spawned: int = 0
var _current_director_wave_id: String = ""
var _is_peak_wave: bool = false
var _last_wave_pressure_score: float = 0.0
var _director_allow_early_finish: bool = false

# 函数：reset_spawner
# 函数：reset_spawner
# 函数：reset_spawner

# 函数：reset_spawner
# 函数：reset_spawner
# 函数：reset_spawner

func reset_spawner() -> void:
	"""Reset spawner state and restart from wave 1."""
	if DEBUG_VERBOSE: print("[Spawner] 正在重置刷怪器...")
	
	# 条件判断
	if spawn_timer:
		spawn_timer.stop()
	if wave_timer:
		wave_timer.stop()
	if elite_spawn_timer:
		elite_spawn_timer.stop()
	

	wave_index = 1
	

	elite_spawners.clear()
	

	current_wave_config.clear()
	current_wave_units.clear()
	_last_wave_pressure_score = 0.0
	
	if DEBUG_VERBOSE: print("[Spawner] reset complete")
	

	start_wave()

func _ready() -> void:
	"""
	初始化刷怪器并加载配置。
	如果存在待恢复战斗状态，则不自动开始第 1 波。
	"""
	_load_config_from_csv()
	_init_elite_spawn_timer()
	
	# 条件判断
	if not Global.pending_battle_state.is_empty():
		if DEBUG_VERBOSE: print("[Spawner] detected pending battle state, skip auto start wave 1")
		return
	
	start_wave()

func _load_config_from_csv() -> void:
	"""
	从配置表加载刷怪相关参数。
	"""
	# 字段定义
	var spawn_width = ConfigManager.get_map_setting("spawn_area_width", 1000.0)
	var spawn_height = ConfigManager.get_map_setting("spawn_area_height", 500.0)
	spawn_area_size = Vector2(spawn_width, spawn_height)
	

	max_waves = int(ConfigManager.get_game_setting("max_waves", 10))
	enemy_health_per_wave = ConfigManager.get_game_setting("enemy_health_per_wave", 10.0)
	enemy_damage_per_wave = ConfigManager.get_game_setting("enemy_damage_per_wave", 2.0)
	enemy_speed_scale = ConfigManager.get_game_setting("enemy_speed_scale", 1.0)
	_director_allow_early_finish = bool(ConfigManager.get_game_setting("director_early_finish_enabled", false))
	_load_director_configs()
	
	if DEBUG_VERBOSE: print("[Spawner] 加载配置: spawn_area=%s, max_waves=%d, health_per_wave=%.1f, damage_per_wave=%.1f, enemy_speed_scale=%.2f" % [
		spawn_area_size, max_waves, enemy_health_per_wave, enemy_damage_per_wave, enemy_speed_scale
	])

func _load_director_configs() -> void:
	_enemy_v2 = ConfigRepository.load_enemy_v2_configs()
	_wave_v2 = ConfigRepository.load_wave_v2_configs()
	_wave_units_v2 = ConfigRepository.load_wave_units_v2_grouped()
	_director_enabled = not _enemy_v2.is_empty() and not _wave_units_v2.is_empty()
	if DEBUG_VERBOSE: print("[Spawner][Director] 配置: enemy=%d wave=%d wave_units=%d enabled=%s" % [
		_enemy_v2.size(),
		_wave_v2.size(),
		_wave_units_v2.size(),
		str(_director_enabled)
	])

func _prepare_director_for_wave() -> void:
	_director_allow_early_finish = bool(ConfigManager.get_game_setting("director_early_finish_enabled", false))
	_current_director_wave_id = _get_director_wave_id_for_index(wave_index)
	if _current_director_wave_id.is_empty():
		_current_director_wave_id = _get_wave_id_for_index(wave_index)
	_is_peak_wave = PEAK_WAVES.has(wave_index)
	_director_budget_spent = 0.0
	_director_total_spawned = 0
	_director_role_spawned.clear()

	_director_budget_total = 9999.0
	if _director_enabled:
		_director_budget_total = _calc_wave_budget(wave_index)
		var wave_cfg = _wave_v2.get(_current_director_wave_id, {})
		var budget_mul := float(wave_cfg.get("budget_multiplier", 1.0))
		_director_budget_total *= max(0.1, budget_mul)
		if _is_peak_wave:
			_director_budget_total *= 1.15
		var timed_budget_floor: float = _calc_timed_budget_floor(wave_cfg)
		if timed_budget_floor > _director_budget_total:
			_director_budget_total = timed_budget_floor
		_enforce_monotonic_wave_pressure(wave_cfg)
		var peak_event := str(wave_cfg.get("peak_event", ""))
		if DEBUG_VERBOSE: print("[Spawner][Director] wave=%d id=%s budget=%.1f pressure=%.3f peak=%s event=%s" % [
			wave_index, _current_director_wave_id, _director_budget_total, _last_wave_pressure_score, str(_is_peak_wave), peak_event
		])
	if _is_skill_synergy_test_mode():
		_director_budget_total = max(_director_budget_total, 999999.0)
		_director_allow_early_finish = false
func _calc_wave_budget(w: int) -> float:
	var wf := float(w)
	return 28.0 + 6.0 * wf + 0.8 * wf * wf

func _calc_timed_budget_floor(wave_cfg: Dictionary) -> float:
	var wave_time: float = _get_wave_time_for_director_cfg(wave_cfg)
	var avg_interval: float = _get_spawn_interval_avg_for_director_cfg(wave_cfg)
	var expected_spawn_count: float = wave_time / max(0.05, avg_interval)
	var avg_cost: float = _estimate_avg_enemy_cost_for_wave()
	# 返回结果
	return expected_spawn_count * avg_cost * 0.92
func _get_wave_time_for_director_cfg(wave_cfg: Dictionary) -> float:
	var fallback_wave_time := float(current_wave_config.get("wave_time", 20.0))
	return max(1.0, float(wave_cfg.get("wave_time", fallback_wave_time)))

func _get_spawn_interval_avg_for_director_cfg(wave_cfg: Dictionary) -> float:
	var spawn_type := str(wave_cfg.get("spawn_type", "RANDOM"))
	var fixed_t := float(wave_cfg.get("fixed_spawn_time", current_wave_config.get("fixed_spawn_time", 1.0)))
	var min_t := float(wave_cfg.get("spawn_interval_min", current_wave_config.get("min_spawn_time", 0.8)))
	var max_t := float(wave_cfg.get("spawn_interval_max", current_wave_config.get("max_spawn_time", 1.5)))
	if spawn_type == "FIXED":
		return max(0.05, fixed_t)
	return max(0.05, (min_t + max_t) * 0.5)

func _calc_wave_pressure_score_for_budget(budget: float, wave_time: float, avg_spawn_interval: float) -> float:
	return budget / max(1.0, wave_time) / max(0.05, avg_spawn_interval)

func _enforce_monotonic_wave_pressure(wave_cfg: Dictionary) -> void:
	var wave_time: float = _get_wave_time_for_director_cfg(wave_cfg)
	var avg_interval: float = _get_spawn_interval_avg_for_director_cfg(wave_cfg)
	var current_score: float = _calc_wave_pressure_score_for_budget(_director_budget_total, wave_time, avg_interval)
	if _last_wave_pressure_score > 0.0 and current_score <= _last_wave_pressure_score:
		var target_score: float = _last_wave_pressure_score * 1.03
		var target_budget: float = target_score * wave_time * avg_interval
		if target_budget > _director_budget_total:
			if DEBUG_VERBOSE: print("[Spawner][Director] monotonic adjust: wave=%d budget %.1f -> %.1f" % [
				wave_index, _director_budget_total, target_budget
			])
			_director_budget_total = target_budget
			current_score = target_score
	_last_wave_pressure_score = current_score

func _get_director_enemy_data() -> Dictionary:
	var source_units: Array = current_wave_units
	if _wave_units_v2.has(_current_director_wave_id):
		source_units = _wave_units_v2[_current_director_wave_id]

	var weighted_pool: Array = []
	var weights: Array[float] = []
	for unit_variant in source_units:
		if not (unit_variant is Dictionary):
			continue
		var unit: Dictionary = unit_variant
		var enemy_id: String = str(unit.get("enemy_id", "")).strip_edges()
		var scene_path: String = str(unit.get("enemy_scene", "")).strip_edges()
		if enemy_id.is_empty() or scene_path.is_empty():
			continue
		var v2: Dictionary = _enemy_v2.get(enemy_id, {})
		var role: String = str(v2.get("role", "runner")).to_lower()
		var cost: float = float(v2.get("cost", 3.0))
		var weight: float = max(0.01, float(unit.get("weight", 1.0)))

		if _director_budget_spent + cost > _director_budget_total:
			continue
		if not _allow_role_spawn(role):
			continue

		var candidate: Dictionary = unit.duplicate(true)
		candidate["role"] = role
		candidate["cost"] = cost
		candidate["hp"] = float(v2.get("hp", 0.0))
		candidate["speed"] = float(v2.get("speed", 0.0))
		candidate["damage"] = float(v2.get("damage", 0.0))
		weighted_pool.append(candidate)
		weights.append(weight)

	if weighted_pool.is_empty():
		return {}

	var rng := RandomNumberGenerator.new()
	var idx: int = rng.rand_weighted(weights)
	if idx < 0 or idx >= weighted_pool.size():
		return {}
	return weighted_pool[idx]
func _estimate_avg_enemy_cost_for_wave() -> float:
	var source_units: Array = current_wave_units
	if _wave_units_v2.has(_current_director_wave_id):
		source_units = _wave_units_v2[_current_director_wave_id]

	var total_weight: float = 0.0
	var weighted_cost_sum: float = 0.0
	for unit_variant in source_units:
		if not (unit_variant is Dictionary):
			continue
		var unit: Dictionary = unit_variant
		var enemy_id: String = str(unit.get("enemy_id", "")).strip_edges()
		if enemy_id.is_empty():
			continue
		var weight: float = max(0.01, float(unit.get("weight", 1.0)))
		var v2: Dictionary = _enemy_v2.get(enemy_id, {})
		var cost: float = float(v2.get("cost", 3.0))
		weighted_cost_sum += cost * weight
		total_weight += weight

	if total_weight <= 0.0:
		return 3.0
	return clamp(weighted_cost_sum / total_weight, 1.0, 10.0)
func _allow_role_spawn(role: String) -> bool:
	if role.is_empty() or not ROLE_CAPS.has(role):
		return true
	if _director_total_spawned < 6:
		return true
	var cap := float(ROLE_CAPS.get(role, 1.0))
	var current_role_count := int(_director_role_spawned.get(role, 0))
	var next_ratio := float(current_role_count + 1) / float(_director_total_spawned + 1)
	return next_ratio <= cap

# 函数：_init_elite_spawn_timer
# 函数：_init_elite_spawn_timer
# 函数：_init_elite_spawn_timer

func _init_elite_spawn_timer() -> void:
	"""

	"""

	elite_spawn_timer = Timer.new()
	elite_spawn_timer.wait_time = 0.1
	elite_spawn_timer.timeout.connect(_on_elite_spawn_timer_timeout)
	add_child(elite_spawn_timer)

# 函数：_process
# 函数：_process
# 函数：_process

func _process(delta: float) -> void:
	"""

	
	璇存槑:




	"""
	# 条件判断
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
	
	# 字段定义
	# 字段定义
	var skip_pressed: bool = Input.is_physical_key_pressed(KEY_SLASH) or Input.is_physical_key_pressed(KEY_KP_DIVIDE)
	if skip_pressed:
		if not _skip_wave_key_pressed:
			_skip_wave_key_pressed = true
			go_to_next_wave()
	else:
		_skip_wave_key_pressed = false

	_try_finish_wave_when_budget_drained()

# 函数：find_wave_data
# 函数：find_wave_data
# 函数：find_wave_data

func find_wave_data() -> bool:
	"""

	


	"""
	# 循环处理
	for wave_id in ConfigManager.wave_configs.keys():
		var config = ConfigManager.get_wave_config(wave_id)
		var from_wave = config.get("from_wave", 1)
		var to_wave = config.get("to_wave", 1)
		
		if wave_index >= from_wave and wave_index <= to_wave:
			current_wave_config = config
			current_wave_units = ConfigManager.get_wave_units(wave_id)
			if DEBUG_VERBOSE: print("[Spawner] 匹配到波次配置: ", wave_id, " (Wave ", from_wave, "-", to_wave, ")")
			if DEBUG_VERBOSE: print("[Spawner] 当前可刷敌人条目: ", current_wave_units.size())
			return true
	
	if DEBUG_VERBOSE: print("[Spawner] Warning: no config found for wave ", wave_index)
	return false

func start_wave() -> void:
	"""

	
	娴佺▼:




	"""
	if not find_wave_data():
		printerr("[Spawner] 错误：找不到当前波次配置")
		spawn_timer.stop()
		wave_timer.stop()
		return

	_prepare_director_for_wave()
		
	var wave_time = current_wave_config.get("wave_time", 20.0)
	if _director_enabled and _wave_v2.has(_current_director_wave_id):
		wave_time = float(_wave_v2[_current_director_wave_id].get("wave_time", wave_time))
	if _is_skill_synergy_test_mode():
		wave_time = _get_skill_synergy_wave_time(float(wave_time))
	wave_timer.wait_time = wave_time
	wave_timer.start()
	
	if DEBUG_VERBOSE: print("[Spawner] start wave ", wave_index, " - duration: ", wave_time, "s")
	set_spawn_timer()
	_init_elite_spawners_for_wave()

func update_enemies_new_wave() -> void:
	"""

	
	璇存槑:



	"""
	# 占位实现
	# 占位实现
	pass

func _init_elite_spawners_for_wave() -> void:
	"""

	"""

	elite_spawners.clear()
	
	# 字段定义
	var wave_id = _get_wave_id_for_index(wave_index)
	if wave_id == "":
		return
	
	# 字段定义
	var spawn_configs = EliteConfigManager.get_elite_spawn_configs(wave_id)
	
	for config in spawn_configs:
		if config.enabled:
			var spawner = EliteSpawner.new(wave_id, config)
			elite_spawners.append(spawner)
			if DEBUG_VERBOSE: print("[Spawner] 初始化精英刷怪器: %s (间隔 %.1f-%.1fs, 上限 %d)" % [
				config.elite_id, config.spawn_interval_min, config.spawn_interval_max, config.max_spawn_count
			])
	
	# 条件判断
	if not elite_spawners.is_empty():
		if elite_spawn_timer.is_stopped():
			elite_spawn_timer.start()

func _get_wave_id_for_index(index: int) -> String:
	"""

	"""
	# 兼容旧配置分段（用于精英配置等依赖旧 wave_id 的系统）
	for wave_id in ConfigManager.wave_configs.keys():
		var config = ConfigManager.get_wave_config(wave_id)
		var from_wave = config.get("from_wave", 1)
		var to_wave = config.get("to_wave", 1)
		
		if index >= from_wave and index <= to_wave:
			return wave_id
	
	return ""

func _get_director_wave_id_for_index(index: int) -> String:
	# 导演系统优先匹配 v2 配置，并选择“范围最窄”的条目（单波次优先）。
	if _wave_v2.is_empty():
		return ""

	var best_wave_id := ""
	var best_span := 1_000_000
	for wave_id in _wave_v2.keys():
		var cfg_variant: Variant = _wave_v2.get(wave_id, {})
		if not (cfg_variant is Dictionary):
			continue
		var cfg: Dictionary = cfg_variant
		var from_wave: int = int(cfg.get("from_wave", 1))
		var to_wave: int = int(cfg.get("to_wave", from_wave))
		if index < from_wave or index > to_wave:
			continue
		var span: int = max(0, to_wave - from_wave)
		if span < best_span:
			best_span = span
			best_wave_id = String(wave_id)

	return best_wave_id

func clear_enemies(grant_kill_rewards: bool = false) -> void:
	"""

	
	璇存槑:



	"""
	if spawned_enemies.size() > 0:
		for enemy : Enemy in spawned_enemies:
			if is_instance_valid(enemy):
				if grant_kill_rewards:
					enemy.destroy_enemy()
				elif enemy.has_method("despawn_for_wave_end"):
					enemy.call("despawn_for_wave_end")
				else:
					enemy.queue_free()
	spawned_enemies.clear()
	
	# 条件判断
	if elite_spawn_timer:
		elite_spawn_timer.stop()
	elite_spawners.clear()
	_cleanup_wave_end_residuals()

func _cleanup_wave_end_residuals() -> void:
	# Wave-end cleanup: remove pickups, enemy residual effects, and stray projectiles.
	_queue_free_group_nodes("items")
	_queue_free_group_nodes("coins")
	_queue_free_group_nodes("projectiles")
	_queue_free_group_nodes("elite_projectiles")
	_queue_free_group_nodes("player_skill_effects")
	_queue_free_group_nodes("enemy_effects")

func _queue_free_group_nodes(group_name: String) -> void:
	var nodes: Array = get_tree().get_nodes_in_group(group_name)
	for node in nodes:
		if is_instance_valid(node):
			node.queue_free()

func _count_alive_enemies() -> int:
	var alive: int = 0
	var valid_refs: Array[Enemy] = []
	for enemy: Enemy in spawned_enemies:
		if not is_instance_valid(enemy):
			continue
		valid_refs.append(enemy)
		if not enemy.is_queued_for_deletion():
			alive += 1
	spawned_enemies = valid_refs
	return alive

func _try_finish_wave_when_budget_drained() -> void:
	if not _director_enabled:
		return
	if not _director_allow_early_finish:
		return
	if Global.game_paused:
		return
	if wave_timer.is_stopped():
		return
	if not spawn_timer.is_stopped():
		return
	if _director_budget_spent < _director_budget_total:
		return
	if _count_alive_enemies() > 0:
		return

	if DEBUG_VERBOSE: print("[Spawner][Director] budget drained and no enemies alive, finishing wave early")
	wave_timer.stop()
	_on_wave_timer_timeout()

# 函数：set_spawn_timer
# 函数：set_spawn_timer
# 函数：set_spawn_timer

func set_spawn_timer() -> void:
	"""

	
	璇存槑:



	"""
	var spawn_type = current_wave_config.get("spawn_type", "RANDOM")
	var min_t = current_wave_config.get("min_spawn_time", 0.8)
	var max_t = current_wave_config.get("max_spawn_time", 1.5)
	var fixed_time = current_wave_config.get("fixed_spawn_time", 1.0)
	if spawn_interval > 0.0:
		spawn_type = "FIXED"
		fixed_time = spawn_interval
	if _director_enabled and _wave_v2.has(_current_director_wave_id):
		var cfg = _wave_v2[_current_director_wave_id]
		spawn_type = str(cfg.get("spawn_type", spawn_type))
		min_t = float(cfg.get("spawn_interval_min", min_t))
		max_t = float(cfg.get("spawn_interval_max", max_t))
		fixed_time = float(cfg.get("fixed_spawn_time", fixed_time))
	
	if spawn_type == "FIXED":
		spawn_timer.wait_time = fixed_time
	else:
		spawn_timer.wait_time = randf_range(min_t, max_t)
	var spawn_rate_mult: float = _get_skill_synergy_spawn_rate_multiplier()
	if spawn_rate_mult > 1.0:
		spawn_timer.wait_time = max(0.01, spawn_timer.wait_time / spawn_rate_mult)

	# 始终重启计时器，确保新的间隔（含压测倍率）立即生效。
	if not spawn_timer.is_stopped():
		spawn_timer.stop()
	spawn_timer.start()

func _is_skill_synergy_test_mode() -> bool:
	var synergy_mode: bool = Global.has_meta("skill_synergy_test_mode_active") and bool(Global.get_meta("skill_synergy_test_mode_active"))
	var auto_show_mode: bool = Global.has_meta("qef_auto_show_mode_active") and bool(Global.get_meta("qef_auto_show_mode_active"))
	return synergy_mode or auto_show_mode

func _get_skill_synergy_wave_time(default_wave_time: float) -> float:
	if not _is_skill_synergy_test_mode():
		return default_wave_time
	if Global.has_meta("qef_auto_show_mode_active") and bool(Global.get_meta("qef_auto_show_mode_active")):
		var auto_wave_meta: Variant = Global.get_meta("qef_auto_show_wave_time", AUTO_SHOW_WAVE_TIME_DEFAULT)
		return max(1.0, float(auto_wave_meta))
	var wave_time_meta: Variant = Global.get_meta("skill_synergy_test_wave_time", SYNERGY_TEST_WAVE_TIME_DEFAULT)
	var wave_time_value: float = float(wave_time_meta)
	return max(1.0, wave_time_value)

func _get_skill_synergy_spawn_rate_multiplier() -> float:
	if not _is_skill_synergy_test_mode():
		return 1.0
	if Global.has_meta("qef_auto_show_mode_active") and bool(Global.get_meta("qef_auto_show_mode_active")):
		var auto_spawn_meta: Variant = Global.get_meta("qef_auto_show_spawn_rate_mul", 1.0)
		return max(1.0, float(auto_spawn_meta))
	var spawn_mult_meta: Variant = Global.get_meta("skill_synergy_test_spawn_rate_mul", 1.0)
	var spawn_mult: float = float(spawn_mult_meta)
	return max(1.0, spawn_mult)

func spawn_debug_enemy_burst(
	anchor: Vector2,
	forward_dir: Vector2,
	count: int = 6,
	forward_offset: float = 120.0,
	spread_radius: float = 120.0
) -> int:
	var spawned: int = 0
	if count <= 0:
		return 0
	var dir: Vector2 = forward_dir.normalized()
	if dir.length_squared() <= 0.001:
		dir = Vector2.RIGHT
	var center: Vector2 = anchor + dir * max(0.0, forward_offset)

	for i: int in range(count):
		var angle: float = TAU * float(i) / float(max(1, count))
		var radius_scale: float = 0.62 + 0.38 * randf()
		var pos: Vector2 = center + Vector2(cos(angle), sin(angle)) * spread_radius * radius_scale
		var enemy: Enemy = _spawn_debug_enemy_at(pos)
		if enemy != null and is_instance_valid(enemy):
			spawned += 1
	return spawned

func _spawn_debug_enemy_at(spawn_pos: Vector2) -> Enemy:
	var enemy_data: Dictionary = {}
	if _director_enabled:
		enemy_data = _get_director_enemy_data()
	if enemy_data.is_empty():
		enemy_data = get_random_enemy_data()
	if enemy_data.is_empty():
		return null

	var enemy_scene_path: String = str(enemy_data.get("enemy_scene", "")).strip_edges()
	var enemy_id: String = str(enemy_data.get("enemy_id", "basic_enemy")).strip_edges()
	if enemy_scene_path.is_empty():
		return null

	var enemy_scene: PackedScene = load(enemy_scene_path) as PackedScene
	if enemy_scene == null:
		return null

	var enemy_instance: Enemy = enemy_scene.instantiate() as Enemy
	if enemy_instance == null:
		return null

	enemy_instance.global_position = spawn_pos
	enemy_instance.enemy_id = enemy_id

	if _director_enabled:
		if enemy_data.has("hp"):
			var base_hp: float = float(enemy_data.get("hp", 0.0))
			if base_hp > 0.0:
				enemy_instance.health = base_hp
		if enemy_data.has("speed"):
			var base_speed: float = float(enemy_data.get("speed", 0.0))
			if base_speed > 0.0:
				enemy_instance.speed = base_speed
		if enemy_data.has("damage"):
			var base_damage: float = float(enemy_data.get("damage", 0.0))
			if base_damage > 0.0:
				enemy_instance.damage = base_damage

	if "speed" in enemy_instance and enemy_speed_scale > 0.0:
		enemy_instance.speed *= enemy_speed_scale
	if "health" in enemy_instance:
		enemy_instance.health += (wave_index - 1) * enemy_health_per_wave
	if "damage" in enemy_instance:
		enemy_instance.damage += (wave_index - 1) * enemy_damage_per_wave

	get_parent().add_child(enemy_instance)
	spawned_enemies.append(enemy_instance)
	return enemy_instance

func get_random_spawn_position() -> Vector2:
	"""

	

	- Vector2: 鍦ㄧ帺瀹跺懆鍥寸殑闅忔満浣嶇疆
	
	璇存槑:
	- 鍦ㄧ帺瀹跺懆鍥翠竴瀹氳寖鍥村唴闅忔満鐢熸垚
	- 濡傛灉鐜╁涓嶅瓨鍦紝浣跨敤鍘熺偣浣滀负涓績

	- 鐢熸垚浣嶇疆琚檺鍒跺湪鍚堢悊鐨勫睆骞曡寖鍥村唴
	"""
	var center_pos = Vector2.ZERO
	
	# 条件判断
	if is_instance_valid(Global.player):
		center_pos = Global.player.global_position
	
	# 字段定义
	# 字段定义
	# 字段定义
	# 字段定义
	var random_x := randf_range(-spawn_area_size.x / 2.0, spawn_area_size.x / 2.0)
	var random_y := randf_range(0, spawn_area_size.y)
	
	var spawn_pos = center_pos + Vector2(random_x, random_y)
	
	# 字段定义
	# 字段定义
	# 字段定义
	
	# 字段定义
	# 字段定义
	var min_y = center_pos.y - 200.0
	var max_y = center_pos.y + spawn_area_size.y + 200.0
	
	spawn_pos.y = clamp(spawn_pos.y, min_y, max_y)
	
	if DEBUG_VERBOSE: print("[Spawner] 出生点计算: center=%s, offset=(%.1f, %.1f), result=%s" % [center_pos, random_x, random_y, spawn_pos])
	
	return spawn_pos

func _get_ring_spawn_position() -> Vector2:
	var center_pos := Vector2.ZERO
	if is_instance_valid(Global.player):
		center_pos = Global.player.global_position

	var viewport_world_size := spawn_area_size
	var camera_node := get_tree().get_first_node_in_group("camera") as Camera2D
	if camera_node != null:
		viewport_world_size = get_viewport().get_visible_rect().size * camera_node.zoom

	var vertical_scale: float = max(0.2, spawn_ring_vertical_scale)
	var half_world: Vector2 = viewport_world_size * 0.5
	var inner_radii := Vector2(
		half_world.x + spawn_ring_inner_padding,
		half_world.y * vertical_scale + spawn_ring_inner_padding * vertical_scale
	)
	var outer_radii := inner_radii + Vector2(
		spawn_ring_thickness,
		spawn_ring_thickness * vertical_scale
	)

	var angle: float = randf_range(0.0, TAU)
	var radii := Vector2(
		randf_range(inner_radii.x, outer_radii.x),
		randf_range(inner_radii.y, outer_radii.y)
	)
	var offset := Vector2(cos(angle) * radii.x, sin(angle) * radii.y)
	var spawn_pos := center_pos + offset

	if DEBUG_VERBOSE:
		print("[Spawner] ring spawn: center=%s angle=%.2f radii=%s result=%s" % [center_pos, angle, radii, spawn_pos])

	return spawn_pos

func spawn_enemy() -> void:
	"""

	
	娴佺▼:
	1. 浠庢尝娆￠厤缃腑闅忔満閫夋嫨鏁屼汉鍦烘櫙锛堝熀浜庢潈閲嶏級
	2. 鍦ㄩ殢鏈轰綅缃疄渚嬪寲鏁屼汉

	4. 娣诲姞鍒板満鏅爲
	5. 璁板綍鍒板凡鐢熸垚鍒楄〃

	"""
	if _is_spawn_cap_reached():
		return
	if current_wave_units.is_empty():
		if DEBUG_VERBOSE: print("[Spawner] 警告：当前波次没有敌人配置")
		return
	
	# 字段定义
	var enemy_data: Dictionary = {}
	if _director_enabled:
		enemy_data = _get_director_enemy_data()
		if enemy_data.is_empty():
			if _director_budget_spent >= _director_budget_total:
				if not _director_allow_early_finish and not wave_timer.is_stopped():
					# 字段定义
					var avg_cost: float = _estimate_avg_enemy_cost_for_wave()
					_director_budget_total = _director_budget_spent + max(1.0, avg_cost)
					enemy_data = _get_director_enemy_data()
					if enemy_data.is_empty():
						enemy_data = get_random_enemy_data()
				else:
					if DEBUG_VERBOSE: print("[Spawner][Director] budget drained: wave=%d spent=%.1f/%.1f" % [
						wave_index, _director_budget_spent, _director_budget_total
					])
					spawn_timer.stop()
					_try_finish_wave_when_budget_drained()
					return
			if enemy_data.is_empty():
				enemy_data = get_random_enemy_data()
	else:
		enemy_data = get_random_enemy_data()
	
	if enemy_data.is_empty():
		if DEBUG_VERBOSE: print("[Spawner] 错误：无法获取敌人数据")
		return
	
	var enemy_scene_path = enemy_data.get("enemy_scene", "")
	var enemy_id = enemy_data.get("enemy_id", "basic_enemy")
	
	var enemy_scene = load(enemy_scene_path) as PackedScene
	if not enemy_scene:
		if DEBUG_VERBOSE: print("[Spawner] 错误：无法加载敌人场景: %s" % enemy_scene_path)
		return
	
	var spawn_pos = _get_ring_spawn_position()
	var enemy_instance = enemy_scene.instantiate() as Enemy
	enemy_instance.global_position = spawn_pos
	enemy_instance.enemy_id = enemy_id
	if DEBUG_VERBOSE: print("[Spawner] 生成敌人: enemy_id=%s, pos=%s" % [enemy_id, spawn_pos])
	
	if _director_enabled:
		if enemy_data.has("hp"):
			var base_hp := float(enemy_data.get("hp", 0.0))
			if base_hp > 0.0:
				enemy_instance.health = base_hp
		if enemy_data.has("speed"):
			var base_speed := float(enemy_data.get("speed", 0.0))
			if base_speed > 0.0:
				enemy_instance.speed = base_speed
		if enemy_data.has("damage"):
			var base_damage := float(enemy_data.get("damage", 0.0))
			if base_damage > 0.0:
				enemy_instance.damage = base_damage

	# 条件判断
	if "speed" in enemy_instance and enemy_speed_scale > 0.0:
		enemy_instance.speed *= enemy_speed_scale
	if "health" in enemy_instance:
		enemy_instance.health += (wave_index - 1) * enemy_health_per_wave
	if "damage" in enemy_instance:
		enemy_instance.damage += (wave_index - 1) * enemy_damage_per_wave

	if _director_enabled:
		var role := str(enemy_data.get("role", "runner")).to_lower()
		var cost := float(enemy_data.get("cost", 3.0))
		_director_budget_spent += cost
		_director_total_spawned += 1
		_director_role_spawned[role] = int(_director_role_spawned.get(role, 0)) + 1
		if DEBUG_VERBOSE: print("[Spawner][Director] Spawn wave=%d enemy=%s role=%s cost=%.1f budget=%.1f/%.1f" % [
			wave_index, enemy_id, role, cost, _director_budget_spent, _director_budget_total
		])

	get_parent().add_child(enemy_instance)
	spawned_enemies.append(enemy_instance)

	# 条件判断
	# 条件判断
	if _director_enabled and _is_peak_wave and randf() < 0.22:
		var affix = AFFIX_POOL[randi() % AFFIX_POOL.size()]
		if enemy_instance.has_method("apply_elite_affix"):
			enemy_instance.call_deferred("apply_elite_affix", affix)

	set_spawn_timer()

func get_random_enemy_data() -> Dictionary:
	"""

	

	- Dictionary: {enemy_scene: "...", enemy_id: "...", weight: 1.0}
	"""
	if current_wave_units.is_empty():
		return {}
	
	# 字段定义
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
	
	# 字段定义
	var rng = RandomNumberGenerator.new()
	var index = rng.rand_weighted(weights)
	
	return enemies[index]

# 函数：spawn_elite
# 函数：spawn_elite
# 函数：spawn_elite

func spawn_elite(spawner: EliteSpawner) -> void:
	"""

	"""
	if _is_spawn_cap_reached():
		return
	var scene_path = spawner.get_elite_scene_path()
	var elite_id = spawner.get_elite_id()
	
	# 字段定义
	var scene = load(scene_path)
	if scene == null:
		if DEBUG_VERBOSE: print("[Spawner] 错误：无法加载精英敌人场景: %s" % scene_path)
		return
	
	# 字段定义
	var elite = scene.instantiate()
	

	elite.global_position = get_random_spawn_position()
	
	# 字段定义
	var wave_id = _get_wave_id_for_index(wave_index)
	var wave_config = EliteConfigManager.get_elite_for_wave(wave_id, elite_id)
	if wave_config:
		if elite.has_method("set_initial_stage"):
			elite.set_initial_stage(wave_config.initial_stage)
		if elite.has_method("set_allow_evolution"):
			elite.set_allow_evolution(wave_config.allow_evolution)
	

	get_parent().add_child(elite)
	spawned_enemies.append(elite)
	
	if DEBUG_VERBOSE: print("[Spawner] 生成精英敌人: %s (初始阶段 %d)" % [elite_id, wave_config.initial_stage if wave_config else 1])

# 函数：get_wave_text
# 函数：get_wave_text
# 函数：get_wave_text

func get_wave_text() -> String:
	"""

	


	"""
	return "Wave %s" % wave_index
	
func get_wave_timer_text() -> String:
	"""

	

	- String: 鍓╀綑绉掓暟锛屽 "45"
	"""
	return str(max(0,int(wave_timer.time_left)))

# 函数：_on_spawn_timer_timeout
# 函数：_on_spawn_timer_timeout
# 函数：_on_spawn_timer_timeout

func _on_spawn_timer_timeout() -> void:
	"""

	
	璇存槑:


	"""
	if current_wave_config.is_empty() or wave_timer.is_stopped():
		spawn_timer.stop()
		return
	if _is_spawn_cap_reached():
		set_spawn_timer()
		return
		
	spawn_enemy()

func _is_spawn_cap_reached() -> bool:
	if max_enemies_on_screen <= 0:
		return false
	return _count_alive_enemies() >= max_enemies_on_screen

func _on_elite_spawn_timer_timeout() -> void:
	"""

	
	璇存槑:


	"""
	if wave_timer.is_stopped() or elite_spawners.is_empty():
		elite_spawn_timer.stop()
		return
	
	for spawner in elite_spawners:
		if spawner.update(0.1):
			spawn_elite(spawner)


func go_to_next_wave() -> void:
	"""

	
	娴佺▼:
	1. 鍋滄鎵拷鏈夎鏃跺櫒



	5. 鍙戝嚭 wave_completed 淇″彿锛堣Е鍙戝晢搴楋級
	"""
	if Global.game_paused:
		return
	
	if DEBUG_VERBOSE: print("[Spawner] 手动跳过当前波次 (wave=%d)" % wave_index)
	

	spawn_timer.stop()
	wave_timer.stop()
	

	clear_enemies()
	update_enemies_new_wave()
	
	# 条件判断
	if wave_index >= max_waves:
		if DEBUG_VERBOSE: print("[Spawner] 已到达最大波次 %d，结束游戏" % max_waves)
		_end_game()
		return
	
	# 条件判断
	if _director_enabled:
		if DEBUG_VERBOSE: print("[Spawner][Director] 波次结算: wave=%d budget=%.1f/%.1f spawned=%d roles=%s" % [
			wave_index, _director_budget_spent, _director_budget_total, _director_total_spawned, str(_director_role_spawned)
		])
	if DEBUG_VERBOSE: print("[Spawner] 波次 %d 完成，发出 wave_completed 信号" % wave_index)
	wave_completed.emit(wave_index)
	
	# 函数：_on_wave_timer_timeout

func _on_wave_timer_timeout() -> void:
	"""

	
	娴佺▼:
	1. 鍋滄鏁屼汉鐢熸垚





	"""
	spawn_timer.stop()
	clear_enemies()
	update_enemies_new_wave()
	
	# 条件判断
	if wave_index >= max_waves:
		if DEBUG_VERBOSE: print("[Spawner] 已到达最大波次 %d，结束游戏" % max_waves)
		_end_game()
		return
	
	# 条件判断
	if _director_enabled:
		if DEBUG_VERBOSE: print("[Spawner][Director] 波次结算: wave=%d budget=%.1f/%.1f spawned=%d roles=%s" % [
			wave_index, _director_budget_spent, _director_budget_total, _director_total_spawned, str(_director_role_spawned)
		])
	if DEBUG_VERBOSE: print("[Spawner] 波次 %d 完成，发出 wave_completed 信号" % wave_index)
	wave_completed.emit(wave_index)
	
	# 函数：_end_game

# 函数：_end_game
# 函数：_end_game
# 函数：_end_game

func _end_game() -> void:
	"""

	
	娴佺▼:
	1. 閸嬫粍顒涢幍鈧張?Timer

	3. 鏄剧ず鑳滃埄淇℃伅
	4. 绛夊緟3绉掑悗閲嶆柊鍔犺浇鍦烘櫙
	"""

	spawn_timer.stop()
	wave_timer.stop()
	

	clear_enemies()
	

	Global.spawn_floating_text(Vector2(960, 540), "Victory!", Color.GOLD)
	var telemetry: Node = get_node_or_null("/root/RunTelemetryService")
	if telemetry and telemetry.has_method("end_run"):
		telemetry.call("end_run", true, "victory")
	
	if DEBUG_VERBOSE: print("[Spawner] game complete - finished %d waves" % max_waves)
	

	await get_tree().create_timer(3.0).timeout
	get_tree().reload_current_scene()

# 函数：pause_spawning
# 函数：pause_spawning
# 函数：pause_spawning

func pause_spawning() -> void:
	"""暂停刷怪（商店打开时）。"""
	if DEBUG_VERBOSE: print("[Spawner] 暂停刷怪")
	
	if spawn_timer:
		spawn_timer.paused = true
	if wave_timer:
		wave_timer.paused = true
	if elite_spawn_timer:
		elite_spawn_timer.paused = true

func resume_spawning() -> void:
	"""Resume spawning flow after shop closes."""
	if DEBUG_VERBOSE: print("[Spawner] 恢复刷怪")
	
	if spawn_timer:
		spawn_timer.paused = false
	if wave_timer:
		wave_timer.paused = false
	if elite_spawn_timer:
		elite_spawn_timer.paused = false
	

	start_next_wave()

func start_next_wave() -> void:
	"""开始下一波（由商店关闭后触发）。"""
	wave_index += 1
	
	if wave_index > max_waves:
		if DEBUG_VERBOSE: print("[Spawner] 所有波次已完成")
		_end_game()
		return
	
	if DEBUG_VERBOSE: print("[Spawner] start wave %d" % wave_index)
	Global.spawn_floating_text(Vector2(960, 540), "第%d波开始！" % wave_index, Color.CYAN)
	start_wave()
