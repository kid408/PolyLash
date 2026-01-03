extends SkillBase
class_name SkillMeatStake

## ==============================================================================
## 屠夫E技能 - 肉桩投掷
## ==============================================================================
## 
## 功能说明:
## - 向鼠标位置投掷肉桩
## - 肉桩飞行时拉扯沿途敌人
## - 着陆后用链条控制范围内敌人
## - 持续6秒后消失
## 
## ==============================================================================

# ==============================================================================
# 技能参数（从CSV加载）
# ==============================================================================

## 链条控制半径
var chain_radius: float = 250.0

## 肉桩飞行速度
var stake_throw_speed: float = 1200.0

## 肉桩着陆伤害
var stake_impact_damage: int = 20

## 肉桩持续时间
var stake_duration: float = 6.0

## 最大投掷距离
var max_throw_distance: float = 800.0

# ==============================================================================
# 视觉配置
# ==============================================================================

## 链条颜色
var chain_color: Color = Color(0.3, 0.1, 0.1, 0.8)

# ==============================================================================
# 运行时状态
# ==============================================================================

## 当前激活的肉桩
var active_stake: Node2D = null

# ==============================================================================
# 生命周期
# ==============================================================================

func _ready() -> void:
	super._ready()

# ==============================================================================
# 技能执行
# ==============================================================================

## 执行技能（投掷肉桩）
func execute() -> void:
	# 检查是否可以执行
	if not can_execute():
		if is_on_cooldown and skill_owner:
			Global.spawn_floating_text(skill_owner.global_position, "Cooldown!", Color.YELLOW)
		return
	
	# 消耗能量
	if not consume_energy():
		if skill_owner:
			Global.spawn_floating_text(skill_owner.global_position, "No Energy!", Color.RED)
		return
	
	# 清除旧肉桩
	if is_instance_valid(active_stake):
		active_stake.queue_free()
		active_stake = null
	
	# 计算目标位置
	if not skill_owner:
		return
	
	var target_pos = skill_owner.get_global_mouse_position()
	var dir = (target_pos - skill_owner.global_position).normalized()
	var dist = min(skill_owner.global_position.distance_to(target_pos), max_throw_distance)
	var final_pos = skill_owner.global_position + dir * dist
	
	# 创建肉桩
	var stake = MeatStake.new()
	stake.setup(final_pos, skill_owner)
	
	# 设置肉桩参数
	_setup_stake_params(stake)
	
	# 添加到场景树
	skill_owner.get_parent().add_child(stake)
	stake.global_position = skill_owner.global_position
	
	active_stake = stake
	
	# 相机震动
	Global.on_camera_shake.emit(10.0, 0.2)
	
	# 开始冷却
	start_cooldown()

## 设置肉桩参数
func _setup_stake_params(stake: MeatStake) -> void:
	# 将技能参数传递给肉桩
	# 注意：MeatStake会从player_ref读取参数，所以我们需要确保skill_owner有这些属性
	
	# 如果skill_owner没有这些属性，我们需要临时添加
	if not "chain_radius" in skill_owner:
		skill_owner.set("chain_radius", chain_radius)
	if not "stake_throw_speed" in skill_owner:
		skill_owner.set("stake_throw_speed", stake_throw_speed)
	if not "stake_impact_damage" in skill_owner:
		skill_owner.set("stake_impact_damage", stake_impact_damage)
	if not "stake_duration" in skill_owner:
		skill_owner.set("stake_duration", stake_duration)
	if not "chain_color" in skill_owner:
		skill_owner.set("chain_color", chain_color)

# ==============================================================================
# 辅助方法
# ==============================================================================

## 清理资源
func cleanup() -> void:
	# 清理激活的肉桩
	if is_instance_valid(active_stake):
		active_stake.queue_free()
		active_stake = null

## 获取当前激活的肉桩
func get_active_stake() -> Node2D:
	return active_stake

## 检查是否有激活的肉桩
func has_active_stake() -> bool:
	return is_instance_valid(active_stake)

## 打印调试信息
func print_debug_info() -> void:
	print("[SkillMeatStake] 调试信息:")
	print("  - has_active_stake: %s" % has_active_stake())
	print("  - chain_radius: %.0f" % chain_radius)
	print("  - stake_throw_speed: %.0f" % stake_throw_speed)
	print("  - stake_impact_damage: %d" % stake_impact_damage)
	print("  - stake_duration: %.1f" % stake_duration)
	print("  - energy_cost: %.0f" % energy_cost)
	print("  - cooldown_time: %.1f" % cooldown_time)
