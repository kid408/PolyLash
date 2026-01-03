extends SkillBase
class_name SkillDash

## ==============================================================================
## 通用冲刺技能 - 所有玩家共用
## ==============================================================================
## 
## 功能说明:
## - 向鼠标方向快速冲刺一段距离
## - 冲刺期间无敌（碰撞禁用）
## - 对路径上的敌人造成伤害和击退
## - 显示拖尾特效
## 
## 使用方法:
##   - 左键点击触发冲刺
##   - 自动朝向鼠标位置
## 
## ==============================================================================

# ==============================================================================
# 技能参数（从CSV加载）
# ==============================================================================

## 冲刺距离
var dash_distance: float = 400.0

## 冲刺速度
var dash_speed: float = 2000.0

## 冲刺伤害
var dash_damage: int = 20

## 击退力度
var dash_knockback: float = 2.0

# ==============================================================================
# 运行时状态
# ==============================================================================

## 是否正在冲刺
var is_dashing: bool = false

## 冲刺目标位置
var dash_target: Vector2 = Vector2.ZERO

## 冲刺起始位置
var dash_start_pos: Vector2 = Vector2.ZERO

# ==============================================================================
# 节点引用
# ==============================================================================

var collision: CollisionShape2D
var dash_hitbox: Node
var trail: Node

# ==============================================================================
# 生命周期
# ==============================================================================

func _ready() -> void:
	super._ready()
	
	# 获取节点引用
	if skill_owner:
		collision = skill_owner.get_node_or_null("CollisionShape2D")
		dash_hitbox = skill_owner.get_node_or_null("DashHitbox")
		trail = skill_owner.get_node_or_null("%Trail")
		
		if not collision:
			push_warning("[SkillDash] 警告: 未找到CollisionShape2D节点")
		if not dash_hitbox:
			push_warning("[SkillDash] 警告: 未找到DashHitbox节点")

func _process(delta: float) -> void:
	super._process(delta)
	
	# 处理冲刺移动
	if is_dashing:
		_process_dash_movement(delta)

# ==============================================================================
# 技能执行
# ==============================================================================

## 执行冲刺技能
func execute() -> void:
	# 检查是否可以执行
	if not can_execute():
		if is_on_cooldown:
			if skill_owner:
				Global.spawn_floating_text(skill_owner.global_position, "Cooldown!", Color.YELLOW)
		return
	
	# 检查是否已经在冲刺
	if is_dashing:
		return
	
	# 消耗能量
	if not consume_energy():
		if skill_owner:
			Global.spawn_floating_text(skill_owner.global_position, "No Energy!", Color.RED)
		return
	
	# 计算冲刺目标位置
	var mouse_pos = skill_owner.get_global_mouse_position()
	var dir = (mouse_pos - skill_owner.global_position).normalized()
	dash_start_pos = skill_owner.global_position
	dash_target = dash_start_pos + dir * dash_distance
	
	# 开始冲刺
	_start_dash()

## 开始冲刺
func _start_dash() -> void:
	is_dashing = true
	is_executing = true
	
	# 禁用碰撞（无敌）
	if collision:
		collision.set_deferred("disabled", true)
	
	# 启用冲刺伤害判定
	if dash_hitbox:
		dash_hitbox.set_deferred("monitorable", true)
		dash_hitbox.set_deferred("monitoring", true)
		
		# 设置伤害参数
		if dash_hitbox.has_method("setup"):
			dash_hitbox.setup(dash_damage, false, dash_knockback, skill_owner)
	
	# 启动拖尾特效
	if trail and trail.has_method("start_trail"):
		trail.start_trail()
	
	# 播放音效
	Global.play_player_dash()
	
	# 开始冷却
	start_cooldown()

## 处理冲刺移动
func _process_dash_movement(delta: float) -> void:
	if not skill_owner:
		_end_dash()
		return
	
	# 向目标位置移动
	skill_owner.position = skill_owner.position.move_toward(dash_target, dash_speed * delta)
	
	# 检查是否到达目标
	if skill_owner.position.distance_to(dash_target) < 10.0:
		_end_dash()

## 结束冲刺
func _end_dash() -> void:
	is_dashing = false
	is_executing = false
	
	# 恢复碰撞
	if collision:
		collision.set_deferred("disabled", false)
	
	# 禁用冲刺伤害判定
	if dash_hitbox:
		dash_hitbox.set_deferred("monitorable", false)
		dash_hitbox.set_deferred("monitoring", false)
	
	# 停止拖尾特效
	if trail and trail.has_method("stop"):
		trail.stop()
	
	# 调用完成回调
	_on_dash_complete()

## 冲刺完成回调（子类可重写）
func _on_dash_complete() -> void:
	# 子类可以在这里添加额外的逻辑
	pass

# ==============================================================================
# 辅助方法
# ==============================================================================

## 检查玩家是否可以移动
func can_move() -> bool:
	return not is_dashing

## 打印调试信息
func print_debug_info() -> void:
	print("[SkillDash] 调试信息:")
	print("  - is_dashing: %s" % is_dashing)
	print("  - dash_distance: %.0f" % dash_distance)
	print("  - dash_speed: %.0f" % dash_speed)
	print("  - dash_damage: %d" % dash_damage)
	print("  - energy_cost: %.0f" % energy_cost)
	print("  - cooldown_time: %.1f" % cooldown_time)
