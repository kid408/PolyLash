extends Node
class_name AbilityBase

## 能力组件基类
## 所有敌人特殊能力都继承此类，实现可配置化

# ==============================================================================
# 信号
# ==============================================================================
signal ability_activated
signal ability_finished
signal ability_cooldown_started(duration: float)

# ==============================================================================
# 配置属性
# ==============================================================================
@export_group("Basic Settings")
@export var ability_id: String = ""  # 能力ID，用于配置识别
@export var ability_name: String = ""  # 能力显示名称
@export var cooldown: float = 3.0  # 冷却时间
@export var auto_activate: bool = true  # 是否自动激活

@export_group("Activation Conditions")
@export var min_distance: float = 0.0  # 最小激活距离
@export var max_distance: float = 999999.0  # 最大激活距离
@export var health_threshold: float = 0.0  # 生命值阈值（0-1）

# ==============================================================================
# 运行时变量
# ==============================================================================
var owner_enemy: Node2D = null  # 拥有此能力的敌人
var cooldown_timer: float = 0.0
var is_active: bool = false
var is_ready: bool = true

# ==============================================================================
# 生命周期
# ==============================================================================
func _ready() -> void:
	set_process(false)  # 默认不处理，由子类决定

func _process(delta: float) -> void:
	if cooldown_timer > 0:
		cooldown_timer -= delta
		if cooldown_timer <= 0:
			is_ready = true

# ==============================================================================
# 核心接口（子类必须实现）
# ==============================================================================
func activate() -> void:
	"""激活能力（子类实现具体逻辑）"""
	push_error("[AbilityBase] activate() 必须在子类中实现！")

func deactivate() -> void:
	"""停用能力（可选实现）"""
	is_active = false

# ==============================================================================
# 通用方法
# ==============================================================================
func can_activate() -> bool:
	"""检查是否可以激活"""
	if not is_ready or is_active:
		return false
	
	if not is_instance_valid(owner_enemy):
		return false
	
	# 检查距离条件（优先使用嘲讽目标）
	var dist_target = Global.player
	if "override_target" in owner_enemy and is_instance_valid(owner_enemy.override_target):
		dist_target = owner_enemy.override_target
	if is_instance_valid(dist_target):
		var distance = owner_enemy.global_position.distance_to(dist_target.global_position)
		if distance < min_distance or distance > max_distance:
			return false
	
	# 检查生命值条件
	if health_threshold > 0 and owner_enemy.has_node("HealthComponent"):
		var health_comp = owner_enemy.get_node("HealthComponent")
		var health_percent = float(health_comp.current_health) / float(health_comp.max_health)
		if health_percent > health_threshold:
			return false
	
	return true

func start_cooldown() -> void:
	"""开始冷却"""
	cooldown_timer = cooldown
	is_ready = false
	ability_cooldown_started.emit(cooldown)

func try_activate() -> bool:
	"""尝试激活能力"""
	if not can_activate():
		return false
	
	is_active = true
	activate()
	ability_activated.emit()
	return true

func setup(enemy: Node2D, config: Dictionary = {}) -> void:
	"""初始化能力（从配置加载）"""
	owner_enemy = enemy
	
	# 从配置加载参数
	if config.has("cooldown"):
		cooldown = float(config.cooldown)
	if config.has("min_distance"):
		min_distance = float(config.min_distance)
	if config.has("max_distance"):
		max_distance = float(config.max_distance)
	if config.has("health_threshold"):
		health_threshold = float(config.health_threshold)
	if config.has("auto_activate"):
		auto_activate = bool(config.auto_activate)

func get_config_template() -> Dictionary:
	"""返回配置模板（用于工具生成）"""
	return {
		"ability_id": ability_id,
		"ability_name": ability_name,
		"cooldown": cooldown,
		"min_distance": min_distance,
		"max_distance": max_distance,
		"health_threshold": health_threshold,
		"auto_activate": auto_activate
	}
