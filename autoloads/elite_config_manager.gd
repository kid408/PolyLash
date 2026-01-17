extends Node

# ==============================================================================
# 精英敌人配置管理器
# ==============================================================================
# 负责加载和管理精英敌人的配置，包括：
# - 精英敌人的基础属性
# - 进化阶段的属性倍数
# - 波次中的精英敌人生成配置

# ==============================================================================
# 配置数据结构
# ==============================================================================

class EliteConfig:
	var elite_id: String
	var display_name: String
	var scene_path: String
	var base_health: int
	var base_damage: int
	var base_armor: float
	var base_speed: float
	# 注意：进化阶段数量现在从 elite_evolution_config.csv 中读取
	
	func _to_string() -> String:
		return "EliteConfig(%s: %s)" % [elite_id, display_name]

class EliteAbilityConfig:
	"""精英敌人的通用能力配置"""
	var elite_id: String
	var eat_detection_radius: float
	var eat_cooldown: float
	var eat_heal_percent: float
	var eat_max_hp_increase: float
	var eat_damage_increase: float
	var base_xp_value: int
	var base_gold_value: int
	var reward_scale_per_stage: float
	var eating_pause_duration: float
	
	func _to_string() -> String:
		return "EliteAbilityConfig(%s)" % [elite_id]

class EvolutionStage:
	var elite_id: String
	var stage: int
	var health_multiplier: float
	var damage_multiplier: float
	var armor_multiplier: float
	var speed_multiplier: float
	var eat_count_per_stage: int  # 该阶段需要吞噬的敌人数
	var sprite_path: String       # 该阶段的精灵图片路径
	var scale_multiplier: float   # 该阶段的体型倍数
	var description: String
	
	func _to_string() -> String:
		return "EvolutionStage(%s Stage %d)" % [elite_id, stage]

class WaveEliteConfig:
	var wave_id: String
	var elite_id: String
	var spawn_count: int
	var spawn_weight: float
	var initial_stage: int
	var allow_evolution: bool
	
	func _to_string() -> String:
		return "WaveEliteConfig(%s: %s x%d)" % [wave_id, elite_id, spawn_count]

class EliteSpawnConfig:
	var wave_id: String
	var elite_id: String
	var spawn_interval_min: float  # 最小生成间隔（秒）
	var spawn_interval_max: float  # 最大生成间隔（秒）
	var max_spawn_count: int       # 最大生成数量
	var enabled: bool              # 是否启用
	
	func _to_string() -> String:
		return "EliteSpawnConfig(%s: %s, 间隔%.1f-%.1fs, 最多%d个)" % [
			wave_id, elite_id, spawn_interval_min, spawn_interval_max, max_spawn_count
		]

# ==============================================================================
# 内部变量
# ==============================================================================

var elite_configs: Dictionary = {}  # elite_id -> EliteConfig
var elite_ability_configs: Dictionary = {}  # elite_id -> EliteAbilityConfig
var evolution_stages: Dictionary = {}  # elite_id -> Array[EvolutionStage]
var wave_elite_configs: Dictionary = {}  # wave_id -> Array[WaveEliteConfig]
var elite_spawn_configs: Dictionary = {}  # wave_id -> Array[EliteSpawnConfig]

# ==============================================================================
# 初始化
# ==============================================================================

func _ready() -> void:
	_load_elite_configs()
	_load_evolution_stages()
	_load_wave_elite_configs()
	_load_elite_spawn_configs()
	print("[EliteConfigManager] 初始化完成")
	
	# 打印所有加载的配置用于调试
	print_all_configs()

func reload_all_configs() -> void:
	"""强制重新加载所有配置（用于调试）"""
	print("\n[EliteConfigManager] 强制重新加载所有配置...")
	elite_configs.clear()
	elite_ability_configs.clear()
	evolution_stages.clear()
	wave_elite_configs.clear()
	elite_spawn_configs.clear()
	
	_load_elite_configs()
	_load_evolution_stages()
	_load_wave_elite_configs()
	_load_elite_spawn_configs()
	
	print("[EliteConfigManager] 重新加载完成")
	print_all_configs()

# ==============================================================================
# 加载配置
# ==============================================================================

func _load_elite_configs() -> void:
	"""加载精英敌人基础配置和能力配置"""
	var csv_path = "res://config/enemy/elite_enemies_config.csv"
	var file = FileAccess.open(csv_path, FileAccess.READ)
	
	if file == null:
		print("[EliteConfigManager] 错误：无法打开 %s" % csv_path)
		return
	
	var header: PackedStringArray = []
	var line_count = 0
	
	while not file.eof_reached():
		var line = file.get_line().strip_edges()
		if line.is_empty() or line.begins_with("-1"):
			continue
		
		line_count += 1
		var parts = line.split(",")
		
		if line_count == 1:
			header = parts
			continue
		
		if parts.size() < header.size():
			continue
		
		var config = EliteConfig.new()
		config.elite_id = parts[0]
		config.display_name = parts[1]
		config.scene_path = parts[2]
		config.base_health = int(parts[3])
		config.base_damage = int(parts[4])
		config.base_armor = float(parts[5])
		config.base_speed = float(parts[6])
		
		elite_configs[config.elite_id] = config
		
		# 同时加载能力配置
		var ability_config = EliteAbilityConfig.new()
		ability_config.elite_id = parts[0]
		ability_config.eat_detection_radius = float(parts[7])
		ability_config.eat_cooldown = float(parts[8])
		ability_config.eat_heal_percent = float(parts[9])
		ability_config.eat_max_hp_increase = float(parts[10])
		ability_config.eat_damage_increase = float(parts[11])
		ability_config.base_xp_value = int(parts[12])
		ability_config.base_gold_value = int(parts[13])
		ability_config.reward_scale_per_stage = float(parts[14])
		ability_config.eating_pause_duration = float(parts[15])
		
		elite_ability_configs[ability_config.elite_id] = ability_config
		
		print("[EliteConfigManager] 加载精英敌人: %s" % config)
		print("[EliteConfigManager] 加载精英能力配置: %s" % ability_config)

func _load_evolution_stages() -> void:
	"""加载进化阶段配置"""
	var csv_path = "res://config/enemy/elite_evolution_config.csv"
	var file = FileAccess.open(csv_path, FileAccess.READ)
	
	if file == null:
		print("[EliteConfigManager] 错误：无法打开 %s" % csv_path)
		return
	
	var header: PackedStringArray = []
	var line_count = 0
	
	while not file.eof_reached():
		var line = file.get_line().strip_edges()
		if line.is_empty() or line.begins_with("-1"):
			continue
		
		line_count += 1
		var parts = line.split(",")
		
		if line_count == 1:
			header = parts
			continue
		
		if parts.size() < header.size():
			continue
		
		var elite_id = parts[0]
		var stage = EvolutionStage.new()
		stage.elite_id = elite_id
		stage.stage = int(parts[1])
		stage.health_multiplier = float(parts[2])
		stage.damage_multiplier = float(parts[3])
		stage.armor_multiplier = float(parts[4])
		stage.speed_multiplier = float(parts[5])
		stage.eat_count_per_stage = int(parts[6])
		stage.sprite_path = parts[7] if parts.size() > 7 else ""
		stage.scale_multiplier = float(parts[8]) if parts.size() > 8 else 1.0
		stage.description = parts[9] if parts.size() > 9 else ""
		
		if not evolution_stages.has(elite_id):
			evolution_stages[elite_id] = []
		
		evolution_stages[elite_id].append(stage)
		print("[EliteConfigManager] 加载进化阶段: %s" % stage)

func _load_wave_elite_configs() -> void:
	"""加载波次中的精英敌人配置"""
	var csv_path = "res://config/wave/elite_wave_config.csv"
	var file = FileAccess.open(csv_path, FileAccess.READ)
	
	if file == null:
		print("[EliteConfigManager] 错误：无法打开 %s" % csv_path)
		return
	
	var header: PackedStringArray = []
	var line_count = 0
	
	while not file.eof_reached():
		var line = file.get_line().strip_edges()
		if line.is_empty() or line.begins_with("-1"):
			continue
		
		line_count += 1
		var parts = line.split(",")
		
		if line_count == 1:
			header = parts
			continue
		
		if parts.size() < header.size():
			continue
		
		var wave_id = parts[0]
		var config = WaveEliteConfig.new()
		config.wave_id = wave_id
		config.elite_id = parts[1]
		config.spawn_count = int(parts[2])
		config.spawn_weight = float(parts[3])
		config.initial_stage = int(parts[4])
		config.allow_evolution = parts[5].to_lower() == "true"
		
		if not wave_elite_configs.has(wave_id):
			wave_elite_configs[wave_id] = []
		
		wave_elite_configs[wave_id].append(config)
		print("[EliteConfigManager] 加载波次精英配置: %s" % config)

func _load_elite_spawn_configs() -> void:
	"""加载精英敌人生成配置（包含生成间隔和数量）"""
	var csv_path = "res://config/wave/elite_spawn_config.csv"
	var file = FileAccess.open(csv_path, FileAccess.READ)
	
	if file == null:
		print("[EliteConfigManager] 错误：无法打开 %s" % csv_path)
		return
	
	var header: PackedStringArray = []
	var line_count = 0
	
	while not file.eof_reached():
		var line = file.get_line().strip_edges()
		if line.is_empty() or line.begins_with("-1"):
			continue
		
		line_count += 1
		var parts = line.split(",")
		
		if line_count == 1:
			header = parts
			continue
		
		if parts.size() < header.size():
			continue
		
		var wave_id = parts[0]
		var config = EliteSpawnConfig.new()
		config.wave_id = wave_id
		config.elite_id = parts[1]
		config.spawn_interval_min = float(parts[2])
		config.spawn_interval_max = float(parts[3])
		config.max_spawn_count = int(parts[4])
		config.enabled = parts[5].to_lower() == "true"
		
		if not elite_spawn_configs.has(wave_id):
			elite_spawn_configs[wave_id] = []
		
		elite_spawn_configs[wave_id].append(config)
		print("[EliteConfigManager] 加载精英生成配置: %s" % config)

# ==============================================================================
# 查询接口
# ==============================================================================

func get_elite_config(elite_id: String) -> EliteConfig:
	"""获取精英敌人的基础配置"""
	if elite_configs.has(elite_id):
		return elite_configs[elite_id]
	
	print("[EliteConfigManager] 警告：找不到精英敌人配置: %s" % elite_id)
	return null

func get_elite_ability_config(elite_id: String) -> EliteAbilityConfig:
	"""获取精英敌人的通用能力配置"""
	if elite_ability_configs.has(elite_id):
		return elite_ability_configs[elite_id]
	
	print("[EliteConfigManager] 警告：找不到精英敌人能力配置: %s" % elite_id)
	return null

func get_evolution_stage(elite_id: String, stage: int) -> EvolutionStage:
	"""获取特定阶段的进化配置"""
	if not evolution_stages.has(elite_id):
		print("[EliteConfigManager] 警告：找不到精英敌人的进化配置: %s" % elite_id)
		return null
	
	var stages = evolution_stages[elite_id]
	for s in stages:
		if s.stage == stage:
			return s
	
	print("[EliteConfigManager] 警告：找不到进化阶段: %s Stage %d" % [elite_id, stage])
	return null

func get_all_evolution_stages(elite_id: String) -> Array:
	"""获取精英敌人的所有进化阶段"""
	if evolution_stages.has(elite_id):
		return evolution_stages[elite_id]
	
	return []

func get_wave_elite_configs(wave_id: String) -> Array:
	"""获取波次中的所有精英敌人配置"""
	if wave_elite_configs.has(wave_id):
		return wave_elite_configs[wave_id]
	
	return []

func get_elite_for_wave(wave_id: String, elite_id: String) -> WaveEliteConfig:
	"""获取特定波次中特定精英敌人的配置"""
	var configs = get_wave_elite_configs(wave_id)
	for config in configs:
		if config.elite_id == elite_id:
			return config
	
	return null

func get_elite_spawn_configs(wave_id: String) -> Array:
	"""获取波次中的所有精英敌人生成配置"""
	if elite_spawn_configs.has(wave_id):
		return elite_spawn_configs[wave_id]
	
	return []

func get_elite_spawn_config(wave_id: String, elite_id: String) -> EliteSpawnConfig:
	"""获取特定波次中特定精英敌人的生成配置"""
	var configs = get_elite_spawn_configs(wave_id)
	for config in configs:
		if config.elite_id == elite_id:
			return config
	
	return null

func get_enabled_elite_spawns_for_wave(wave_id: String) -> Array:
	"""获取波次中所有启用的精英敌人生成配置"""
	var configs = get_elite_spawn_configs(wave_id)
	var enabled_configs: Array = []
	
	for config in configs:
		if config.enabled:
			enabled_configs.append(config)
	
	return enabled_configs

# ==============================================================================
# 计算接口
# ==============================================================================

func calculate_evolved_stats(elite_id: String, stage: int, base_stats: Dictionary) -> Dictionary:
	"""根据进化阶段计算敌人的属性"""
	var evolution = get_evolution_stage(elite_id, stage)
	if evolution == null:
		return base_stats
	
	var evolved_stats = base_stats.duplicate()
	evolved_stats["health"] = int(base_stats.get("health", 0) * evolution.health_multiplier)
	evolved_stats["damage"] = int(base_stats.get("damage", 0) * evolution.damage_multiplier)
	evolved_stats["armor"] = base_stats.get("armor", 0) * evolution.armor_multiplier
	evolved_stats["speed"] = base_stats.get("speed", 0) * evolution.speed_multiplier
	
	return evolved_stats

func get_evolution_threshold(elite_id: String, stage: int) -> int:
	"""获取进化到指定阶段需要吃掉的敌人数量"""
	# 现在直接调用 get_eat_count_for_stage
	return get_eat_count_for_stage(elite_id, stage)

func get_eat_count_for_stage(elite_id: String, stage: int) -> int:
	"""获取该阶段需要吞噬的敌人数量"""
	var evolution = get_evolution_stage(elite_id, stage)
	if evolution == null:
		return -1
	
	return evolution.eat_count_per_stage

func get_sprite_path_for_stage(elite_id: String, stage: int) -> String:
	"""获取该阶段的精灵图片路径"""
	var evolution = get_evolution_stage(elite_id, stage)
	if evolution == null:
		return ""
	
	return evolution.sprite_path

func get_scale_multiplier_for_stage(elite_id: String, stage: int) -> float:
	"""获取该阶段的体型倍数"""
	var evolution = get_evolution_stage(elite_id, stage)
	if evolution == null:
		return 1.0
	
	return evolution.scale_multiplier

# ==============================================================================
# 调试接口
# ==============================================================================

func print_all_configs() -> void:
	"""打印所有配置信息"""
	print("\n=== 精英敌人配置 ===")
	for elite_id in elite_configs:
		var config = elite_configs[elite_id]
		print("  %s: %s (血量%d, 伤害%d, 护甲%.1f, 速度%.1f)" % [
			elite_id, config.display_name, config.base_health, 
			config.base_damage, config.base_armor, config.base_speed
		])
	
	print("\n=== 进化阶段配置 ===")
	for elite_id in evolution_stages:
		print("  %s:" % elite_id)
		for stage in evolution_stages[elite_id]:
			print("    Stage %d: 血量x%.2f, 伤害x%.2f, 护甲x%.2f, 速度x%.2f, 吞噬%d个敌人 - %s" % [
				stage.stage, stage.health_multiplier, stage.damage_multiplier,
				stage.armor_multiplier, stage.speed_multiplier, stage.eat_count_per_stage, stage.description
			])
	
	print("\n=== 波次精英配置 ===")
	for wave_id in wave_elite_configs:
		print("  %s:" % wave_id)
		for config in wave_elite_configs[wave_id]:
			print("    %s: 生成%d个, 权重%.1f, 初始阶段%d, 允许进化%s" % [
				config.elite_id, config.spawn_count, config.spawn_weight,
				config.initial_stage, config.allow_evolution
			])
	
	print("\n=== 精英生成配置 ===")
	for wave_id in elite_spawn_configs:
		print("  %s:" % wave_id)
		for config in elite_spawn_configs[wave_id]:
			var status = "启用" if config.enabled else "禁用"
			print("    %s: 生成间隔%.1f-%.1fs, 最多%d个 [%s]" % [
				config.elite_id, config.spawn_interval_min, config.spawn_interval_max,
				config.max_spawn_count, status
			])

func get_stats_info(elite_id: String) -> String:
	"""获取精英敌人的详细信息"""
	var config = get_elite_config(elite_id)
	if config == null:
		return "找不到配置: %s" % elite_id
	
	var info = "精英敌人: %s\n" % config.display_name
	info += "基础属性: 血量%d, 伤害%d, 护甲%.1f, 速度%.1f\n" % [
		config.base_health, config.base_damage, config.base_armor, config.base_speed
	]
	info += "进化阈值: "
	var all_stages = get_all_evolution_stages(elite_id)
	for stage in all_stages:
		info += "Stage%d=%d " % [stage.stage, stage.eat_count_per_stage]
	
	return info
