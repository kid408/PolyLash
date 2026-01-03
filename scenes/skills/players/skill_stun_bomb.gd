extends SkillBase
class_name SkillStunBomb

## ==============================================================================
## 织网者E技能 - 定身炸弹
## ==============================================================================
## 
## 功能说明:
## - 在玩家位置释放范围定身效果
## - 定身范围内的所有敌人
## - 定身持续一定时间
## - 显示视觉效果和震屏
## 
## 使用方法:
##   - 按E键触发
##   - 自动影响范围内所有敌人
## 
## ==============================================================================

# ==============================================================================
# 技能参数（从CSV加载）
# ==============================================================================

## 定身半径
var stun_radius: float = 300.0

## 定身持续时间
var stun_duration: float = 2.5

# ==============================================================================
# 视觉配置
# ==============================================================================

## 定身视觉颜色
var stun_color: Color = Color(0.2, 0.8, 1.0, 0.5)

# ==============================================================================
# 生命周期
# ==============================================================================

func _ready() -> void:
	super._ready()

# ==============================================================================
# 技能执行
# ==============================================================================

## 执行定身炸弹技能
func execute() -> void:
	# 检查是否可以执行
	if not can_execute():
		if is_on_cooldown:
			if skill_owner:
				Global.spawn_floating_text(skill_owner.global_position, "Cooldown!", Color.YELLOW)
		return
	
	# 消耗能量
	if not consume_energy():
		if skill_owner:
			Global.spawn_floating_text(skill_owner.global_position, "No Energy!", Color.RED)
		return
	
	# 执行定身效果
	_perform_stun()
	
	# 开始冷却
	start_cooldown()

## 执行定身效果
func _perform_stun() -> void:
	if not skill_owner:
		return
	
	# 震屏效果
	Global.on_camera_shake.emit(8.0, 0.3)
	
	# 创建视觉效果
	_create_stun_visual(stun_radius)
	
	# 查找并定身范围内的敌人
	var enemies = get_tree().get_nodes_in_group("enemies")
	var hit_count = 0
	
	for enemy in enemies:
		if not is_instance_valid(enemy):
			continue
		
		# 检查距离
		if skill_owner.global_position.distance_to(enemy.global_position) < stun_radius:
			_apply_stun_effect(enemy)
			hit_count += 1
	
	# 显示命中提示
	if hit_count > 0:
		Global.spawn_floating_text(skill_owner.global_position, "FREEZE! x%d" % hit_count, Color.CYAN)

## 应用定身效果到单个敌人
func _apply_stun_effect(enemy: Node2D) -> void:
	var enemy_ref = weakref(enemy)
	
	# 禁用移动
	if "can_move" in enemy:
		enemy.can_move = false
	
	# 改变颜色（蓝色表示冰冻）
	enemy.modulate = Color(0.3, 0.3, 1.0)
	
	# 定时恢复
	get_tree().create_timer(stun_duration).timeout.connect(func():
		var e = enemy_ref.get_ref()
		if is_instance_valid(e):
			# 检查是否仍被蛛网困住
			var is_still_trapped = _check_if_trapped(e)
			
			if not is_still_trapped:
				# 完全恢复
				if "can_move" in e:
					e.can_move = true
				e.modulate = Color.WHITE
			else:
				# 仍被困，恢复为陷阱颜色
				e.modulate = Color(1, 0.5, 0.5)
	)

## 检查敌人是否被蛛网困住
func _check_if_trapped(enemy: Node2D) -> bool:
	# 尝试从skill_owner获取trapped_enemies列表
	if skill_owner and "trapped_enemies" in skill_owner:
		for ref in skill_owner.trapped_enemies:
			if ref.get_ref() == enemy:
				return true
	
	return false

## 创建定身视觉效果
func _create_stun_visual(radius: float) -> void:
	if not skill_owner:
		return
	
	# 创建多边形表示范围
	var poly = Polygon2D.new()
	var points = PackedVector2Array()
	
	# 生成圆形多边形
	for i in range(32):
		var angle = i * TAU / 32
		points.append(Vector2(cos(angle), sin(angle)) * radius)
	
	poly.polygon = points
	poly.color = stun_color
	poly.z_index = 80
	poly.global_position = skill_owner.global_position
	
	# 添加到场景
	get_tree().current_scene.add_child(poly)
	
	# 动画效果
	var t = poly.create_tween()
	t.tween_property(poly, "scale", Vector2(1.1, 1.1), 0.1)
	t.tween_property(poly, "color:a", 0.0, 0.5)
	t.tween_callback(poly.queue_free)

# ==============================================================================
# 辅助方法
# ==============================================================================

## 打印调试信息
func print_debug_info() -> void:
	print("[SkillStunBomb] 调试信息:")
	print("  - stun_radius: %.0f" % stun_radius)
	print("  - stun_duration: %.1f" % stun_duration)
	print("  - energy_cost: %.0f" % energy_cost)
	print("  - cooldown_time: %.1f" % cooldown_time)
