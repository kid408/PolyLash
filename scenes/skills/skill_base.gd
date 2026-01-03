extends Node
class_name SkillBase

## ==============================================================================
## 技能基类 - 所有技能的抽象基类
## ==============================================================================
## 
## 功能说明:
## - 提供技能的通用接口和功能
## - 管理技能状态（就绪/冷却/执行中）
## - 处理能量消耗和冷却时间
## - 子类必须实现execute(), charge(), release()方法
## 
## 使用方法:
##   1. 继承SkillBase
##   2. 实现execute(), charge(), release()方法
##   3. 在owner中调用技能方法
## 
## ==============================================================================

# ==============================================================================
# 技能所有者和配置
# ==============================================================================

## 技能所有者（玩家或敌人）
var skill_owner: Node2D

## 技能唯一标识符
var skill_id: String = ""

## 能量消耗
var energy_cost: float = 0.0

## 冷却时间（秒）
var cooldown_time: float = 0.0

# ==============================================================================
# 运行时状态
# ==============================================================================

## 是否处于冷却中
var is_on_cooldown: bool = false

## 冷却计时器
var cooldown_timer: float = 0.0

## 是否正在蓄力
var is_charging: bool = false

## 是否正在执行
var is_executing: bool = false

# ==============================================================================
# 虚函数接口（子类必须实现）
# ==============================================================================

## 执行技能（瞬发技能）
## 用于E键、左键等瞬发技能
func execute() -> void:
	push_warning("[SkillBase] execute() 未实现: %s" % skill_id)

## 蓄力技能（持续按住）
## 用于Q键等需要蓄力的技能
## @param delta: 帧时间增量
func charge(delta: float) -> void:
	pass  # 默认实现为空，子类可选择性实现

## 释放技能（松开按键）
## 用于Q键等需要释放的技能
func release() -> void:
	pass  # 默认实现为空，子类可选择性实现

# ==============================================================================
# 通用功能
# ==============================================================================

## 检查技能是否可以执行
## @return: 如果可以执行返回true，否则返回false
func can_execute() -> bool:
	# 检查冷却状态
	if is_on_cooldown:
		return false
	
	# 检查能量
	if skill_owner and skill_owner.has_method("consume_energy"):
		return skill_owner.energy >= energy_cost
	
	return true

## 消耗能量
## @return: 如果成功消耗返回true，否则返回false
func consume_energy() -> bool:
	if skill_owner and skill_owner.has_method("consume_energy"):
		return skill_owner.consume_energy(energy_cost)
	return true

## 开始冷却
func start_cooldown() -> void:
	if cooldown_time > 0:
		is_on_cooldown = true
		cooldown_timer = cooldown_time

## 重置冷却
func reset_cooldown() -> void:
	is_on_cooldown = false
	cooldown_timer = 0.0

## 获取冷却剩余时间
## @return: 冷却剩余时间（秒）
func get_cooldown_remaining() -> float:
	return cooldown_timer if is_on_cooldown else 0.0

## 获取冷却进度（0-1）
## @return: 冷却进度，0表示冷却完成，1表示刚开始冷却
func get_cooldown_progress() -> float:
	if not is_on_cooldown or cooldown_time <= 0:
		return 0.0
	return cooldown_timer / cooldown_time

# ==============================================================================
# 生命周期
# ==============================================================================

func _ready() -> void:
	# 确保skill_owner已设置
	if not skill_owner:
		push_error("[SkillBase] 错误: skill_owner未设置 for skill %s" % skill_id)

func _process(delta: float) -> void:
	# 更新冷却计时器
	if is_on_cooldown:
		cooldown_timer -= delta
		if cooldown_timer <= 0:
			is_on_cooldown = false
			cooldown_timer = 0.0
			_on_cooldown_complete()

## 冷却完成回调（子类可重写）
func _on_cooldown_complete() -> void:
	pass

# ==============================================================================
# 调试和日志
# ==============================================================================

## 打印技能信息
func print_info() -> void:
	print("[SkillBase] 技能信息:")
	print("  - skill_id: %s" % skill_id)
	print("  - energy_cost: %.1f" % energy_cost)
	print("  - cooldown_time: %.1f" % cooldown_time)
	print("  - is_on_cooldown: %s" % is_on_cooldown)
	print("  - is_charging: %s" % is_charging)
	print("  - is_executing: %s" % is_executing)
