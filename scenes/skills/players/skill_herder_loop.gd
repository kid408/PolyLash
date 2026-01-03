extends SkillBase
class_name SkillHerderLoop

## ==============================================================================
## 牧羊人Q技能 - 画圈几何击杀
## ==============================================================================
## 
## 功能说明:
## - 按住Q进入规划模式（子弹时间）
## - 左键：向鼠标方向延伸固定距离添加冲刺点
## - 右键：撤销最后一个冲刺点
## - 松开Q：执行冲刺序列
## - 路径闭合时触发几何击杀（秒杀圈内敌人）
## - 根据击杀数量给予不同奖励
## 
## 使用方法:
##   - 按住Q进入规划模式
##   - 左键添加冲刺点
##   - 松开Q执行冲刺
## 
## ==============================================================================

# ==============================================================================
# 技能参数（从CSV加载）
# ==============================================================================

## 每段冲刺的固定距离
var fixed_segment_length: float = 600.0

## 冲刺速度
var dash_speed: float = 2000.0

## 冲刺基础伤害
var dash_base_damage: int = 10

## 击退力度
var dash_knockback: float = 2.0

## 闭合判定阈值
var close_threshold: float = 60.0

# ==============================================================================
# 视觉配置
# ==============================================================================

## 几何遮罩颜色
var geometry_mask_color: Color = Color(1, 0.0, 0.0, 0.6)

## 规划线条颜色（正常）
var planning_color_normal: Color = Color(1.0, 1.0, 1.0, 0.5)

## 规划线条颜色（闭合）
var planning_color_closed: Color = Color(1.0, 0.2, 0.2, 1.0)

# ==============================================================================
# 运行时状态
# ==============================================================================

## 是否处于规划模式
var is_planning: bool = false

## 冲刺队列
var dash_queue: Array[Vector2] = []

## 当前冲刺目标
var current_target: Vector2 = Vector2.ZERO

## 路径历史（用于闭合检测）
var path_history: Array[Vector2] = []

## 是否正在执行几何击杀
var is_executing_kill: bool = false

## 是否正在冲刺
var is_dashing: bool = false

# ==============================================================================
# 节点引用
# ==============================================================================

## 用于绘制规划路径的Line2D
var line_2d: Line2D

var collision: CollisionShape2D
var dash_hitbox: Node
var trail: Node
var visuals: Node2D

# ==============================================================================
# 生命周期
# ==============================================================================

func _ready() -> void:
	super._ready()
	
	if skill_owner:
		# 创建Line2D用于绘制规划路径
		line_2d = Line2D.new()
		line_2d.name = "HerderPlanningLine"
		line_2d.width = 4.0
		skill_owner.add_child(line_2d)
		# 关键：设置为top_level，这样Line2D使用全局坐标，不受父节点变换影响
		line_2d.top_level = true
		line_2d.clear_points()
		
		# 获取节点引用
		collision = skill_owner.get_node_or_null("CollisionShape2D")
		dash_hitbox = skill_owner.get_node_or_null("DashHitbox")
		trail = skill_owner.get_node_or_null("%Trail")
		visuals = skill_owner.get_node_or_null("Visuals")
		
		# 从skill_owner读取参数（CSV中没有的参数）
		if "close_threshold" in skill_owner:
			close_threshold = skill_owner.close_threshold
		
		if "geometry_mask_color" in skill_owner:
			geometry_mask_color = skill_owner.geometry_mask_color
		
		# 如果CSV中有dash_base_damage，使用它；否则从owner读取
		if dash_base_damage == 10 and "dash_base_damage" in skill_owner:
			dash_base_damage = skill_owner.dash_base_damage

func _process(delta: float) -> void:
	super._process(delta)
	
	# 强制维持子弹时间
	if is_planning and Engine.time_scale > 0.2:
		Engine.time_scale = 0.1
	
	# 处理冲刺移动
	if is_dashing:
		_process_dashing_movement(delta)
	
	# 每帧更新视觉效果（关键！）
	_update_visuals()

# ==============================================================================
# 技能执行
# ==============================================================================

## 蓄力技能（持续按住Q）
func charge(delta: float) -> void:
	if not is_planning:
		_enter_planning_mode()
	
	if is_planning:
		# 左键：添加冲刺点
		if Input.is_action_just_pressed("click_left"):
			_try_add_path_segment()
		
		# 右键：撤销冲刺点
		if Input.is_action_just_pressed("click_right"):
			_undo_last_point()

## 释放技能（松开Q）
func release() -> void:
	if is_planning:
		_exit_planning_mode_and_dash()

# ==============================================================================
# 规划模式
# ==============================================================================

## 进入规划模式
func _enter_planning_mode() -> void:
	is_planning = true
	is_charging = true
	Engine.time_scale = 0.1

## 退出规划模式并开始冲刺
func _exit_planning_mode_and_dash() -> void:
	is_planning = false
	is_charging = false
	Engine.time_scale = 1.0
	
	print("[SkillHerderLoop] 退出规划模式, dash_queue.size=", dash_queue.size())
	
	if dash_queue.size() > 0:
		print("[SkillHerderLoop] 开始冲刺序列")
		_start_dash_sequence()
	else:
		print("[SkillHerderLoop] dash_queue为空，清理")
		line_2d.clear_points()
		dash_queue.clear()
		path_history.clear()

## 尝试添加路径段
func _try_add_path_segment() -> bool:
	print("[SkillHerderLoop] _try_add_path_segment() - 当前能量:", skill_owner.energy if skill_owner else 0, " 需要:", energy_cost)
	
	if consume_energy():
		print("[SkillHerderLoop] 能量消耗成功")
		_add_path_point(skill_owner.get_global_mouse_position())
		return true
	else:
		print("[SkillHerderLoop] 能量不足")
		if skill_owner:
			Global.spawn_floating_text(skill_owner.global_position, "No Energy!", Color.RED)
		return false

## 添加路径点
func _add_path_point(mouse_pos: Vector2) -> void:
	if not skill_owner:
		return
	
	var start_pos = skill_owner.global_position
	if dash_queue.size() > 0:
		start_pos = dash_queue.back()
	
	var direction = (mouse_pos - start_pos).normalized()
	var final_pos = start_pos + (direction * fixed_segment_length)
	
	dash_queue.append(final_pos)
	
	print("[SkillHerderLoop] 路径点已添加:")
	print("  起点:", start_pos)
	print("  终点:", final_pos)
	print("  fixed_segment_length:", fixed_segment_length)
	print("  实际距离:", start_pos.distance_to(final_pos))
	print("  dash_queue.size:", dash_queue.size())

## 撤销最后一个点
func _undo_last_point() -> void:
	if dash_queue.size() > 0:
		dash_queue.pop_back()
		print("[SkillHerderLoop] 撤销路径点, 剩余:", dash_queue.size())
		
		# 返还能量
		if skill_owner and skill_owner.has_method("gain_energy"):
			skill_owner.energy += energy_cost
			skill_owner.update_ui_signals()

## 更新规划路径的视觉效果（每帧调用）
func _update_visuals() -> void:
	# 1. 基础清理
	if dash_queue.is_empty() and not is_planning:
		line_2d.clear_points()
		return
	
	line_2d.clear_points()
	
	if not skill_owner:
		return
	
	# 2. 构建"已确认"的点集 (玩家位置 + 已经点下的冲刺点)
	var confirmed_points: Array[Vector2] = []
	confirmed_points.append(skill_owner.global_position)
	confirmed_points.append_array(dash_queue)
	
	# 3. 绘制已确认的点
	for p in confirmed_points:
		line_2d.add_point(p)
	
	# 4. 颜色判断：检查是否形成闭环
	var final_color = Color.WHITE
	var poly = _find_closing_polygon(confirmed_points)
	
	if poly.size() > 0:
		# 形成闭环，变红
		final_color = Color(1.0, 0.2, 0.2, 1.0)
	elif skill_owner and skill_owner.energy < energy_cost:
		# 能量不足，变灰
		final_color = Color(0.5, 0.5, 0.5, 0.5)
	
	line_2d.default_color = final_color
	
	# 5. 绘制预览线段（如果正在规划）
	if is_planning and skill_owner:
		var start = skill_owner.global_position
		if dash_queue.size() > 0:
			start = dash_queue.back()
		
		var mouse_dir = (skill_owner.get_global_mouse_position() - start).normalized()
		var preview_pos = start + (mouse_dir * fixed_segment_length)
		
		line_2d.add_point(preview_pos)

# ==============================================================================
# 冲刺执行
# ==============================================================================

## 开始冲刺序列
func _start_dash_sequence() -> void:
	if dash_queue.is_empty() or not skill_owner:
		print("[SkillHerderLoop] _start_dash_sequence() 失败 - dash_queue为空或skill_owner为null")
		return
	
	print("[SkillHerderLoop] _start_dash_sequence() 开始")
	print("  dash_queue.size:", dash_queue.size())
	print("  dash_speed:", dash_speed)
	
	is_dashing = true
	is_executing = true
	path_history.clear()
	path_history.append(skill_owner.global_position)
	
	# 启动拖尾特效
	if trail and trail.has_method("start_trail"):
		trail.start_trail()
		print("[SkillHerderLoop] 拖尾特效已启动")
	
	# 设置视觉效果
	if visuals:
		visuals.modulate.a = 0.5
	
	# 禁用碰撞
	if collision:
		collision.set_deferred("disabled", true)
	
	# 启用冲刺伤害判定
	if dash_hitbox:
		dash_hitbox.set_deferred("monitorable", true)
		dash_hitbox.set_deferred("monitoring", true)
		
		if dash_hitbox.has_method("setup"):
			dash_hitbox.setup(dash_base_damage, false, dash_knockback, skill_owner)
	
	# 播放音效
	Global.play_player_dash()
	
	# 设置第一个目标
	current_target = dash_queue.pop_front()
	print("[SkillHerderLoop] 第一个目标:", current_target)
	print("[SkillHerderLoop] 当前位置:", skill_owner.global_position)
	print("[SkillHerderLoop] 距离:", skill_owner.global_position.distance_to(current_target))
	
	# 开始冷却
	start_cooldown()

## 处理冲刺移动
func _process_dashing_movement(delta: float) -> void:
	if not skill_owner or current_target == Vector2.ZERO:
		return
	
	# 恢复时间流速
	Engine.time_scale = 1.0
	
	var old_pos = skill_owner.position
	# 向目标移动
	skill_owner.position = skill_owner.position.move_toward(current_target, dash_speed * delta)
	var moved_distance = old_pos.distance_to(skill_owner.position)
	
	# 每秒打印一次调试信息
	if Engine.get_frames_drawn() % 60 == 0:
		print("[SkillHerderLoop] 冲刺中 - 位置:", skill_owner.position, " 目标:", current_target, " 距离:", skill_owner.position.distance_to(current_target), " 移动:", moved_distance)
	
	# 检查是否到达目标
	if skill_owner.position.distance_to(current_target) < 10.0:
		print("[SkillHerderLoop] 到达目标点")
		_on_reach_target_point()

## 到达目标点
func _on_reach_target_point() -> void:
	if not skill_owner:
		return
	
	path_history.append(skill_owner.global_position)
	print("[SkillHerderLoop] 到达目标点, path_history.size:", path_history.size(), " dash_queue.size:", dash_queue.size())
	
	# 检查闭合
	_check_and_trigger_intersection()
	
	# 继续下一个目标或结束
	if dash_queue.size() > 0:
		current_target = dash_queue.pop_front()
		print("[SkillHerderLoop] 下一个目标:", current_target)
	else:
		print("[SkillHerderLoop] 所有目标完成，结束冲刺")
		_end_dash_sequence()

## 结束冲刺序列
func _end_dash_sequence() -> void:
	print("[SkillHerderLoop] _end_dash_sequence() 开始")
	
	# 最后再检查一次闭合
	if not is_executing_kill:
		_check_and_trigger_intersection()
	
	is_dashing = false
	is_executing = false
	
	# 清理线条（关键！）
	line_2d.clear_points()
	dash_queue.clear()
	path_history.clear()
	current_target = Vector2.ZERO
	
	print("[SkillHerderLoop] 状态已清理")
	
	# 停止拖尾特效
	if trail and trail.has_method("stop"):
		trail.stop()
	
	# 恢复视觉效果
	if visuals:
		visuals.modulate.a = 1.0
	
	# 恢复碰撞
	if collision:
		collision.set_deferred("disabled", false)
	
	# 禁用冲刺伤害判定
	if dash_hitbox:
		dash_hitbox.set_deferred("monitorable", false)
		dash_hitbox.set_deferred("monitoring", false)
	
	print("[SkillHerderLoop] _end_dash_sequence() 完成")

# ==============================================================================
# 闭环检测与几何击杀
# ==============================================================================

## 查找闭合多边形
func _find_closing_polygon(points: Array[Vector2]) -> PackedVector2Array:
	if points.size() < 3:
		return PackedVector2Array()
	
	var last_point = points.back()
	var last_segment_start = points[points.size() - 2]
	
	for i in range(points.size() - 2):
		var old_pos = points[i]
		
		# 检查距离闭合
		if last_point.distance_to(old_pos) < close_threshold:
			var poly = PackedVector2Array()
			for j in range(i, points.size()):
				poly.append(points[j])
			return poly
		
		# 检查线段相交
		if i < points.size() - 2:
			var old_next = points[i + 1]
			if old_next != last_segment_start:
				var intersection = Geometry2D.segment_intersects_segment(
					last_segment_start, last_point, old_pos, old_next
				)
				if intersection:
					var poly = PackedVector2Array()
					poly.append(intersection)
					for j in range(i + 1, points.size() - 1):
						poly.append(points[j])
					poly.append(intersection)
					return poly
	
	return PackedVector2Array()

## 检查并触发闭合
func _check_and_trigger_intersection() -> void:
	if is_executing_kill:
		return
	
	var polygon_points = _find_closing_polygon(path_history)
	if polygon_points.size() > 0:
		_trigger_geometry_kill(polygon_points)

## 触发几何击杀
func _trigger_geometry_kill(polygon_points: PackedVector2Array) -> void:
	is_executing_kill = true
	
	# 创建视觉遮罩
	var mask_node = _create_geometry_mask_visual(polygon_points)
	
	# 动画序列
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(mask_node, "color:a", 0.8, 0.2).from(0.0)
	tween.tween_callback(Global.play_loop_kill_impact)
	tween.set_parallel(false)
	tween.tween_callback(_on_geometry_kill_flash.bind(mask_node, polygon_points))
	tween.tween_interval(0.15)
	tween.tween_property(mask_node, "color", geometry_mask_color, 0.05)
	tween.tween_property(mask_node, "color:a", 0.0, 0.3)
	tween.tween_callback(_on_geometry_kill_complete.bind(mask_node))

## 几何击杀闪光
func _on_geometry_kill_flash(mask_node: Polygon2D, polygon_points: PackedVector2Array) -> void:
	if is_instance_valid(mask_node):
		mask_node.color = Color(2, 2, 2, 1)
	_perform_geometry_damage(polygon_points)

## 几何击杀完成
func _on_geometry_kill_complete(mask_node: Polygon2D) -> void:
	is_executing_kill = false
	if is_instance_valid(mask_node):
		mask_node.queue_free()

## 执行几何伤害
func _perform_geometry_damage(polygon_points: PackedVector2Array) -> void:
	Global.on_camera_shake.emit(20.0, 0.5)
	
	var enemies = get_tree().get_nodes_in_group("enemies")
	var kill_count = 0
	
	for enemy in enemies:
		if not is_instance_valid(enemy):
			continue
		
		if not Geometry2D.is_point_in_polygon(enemy.global_position, polygon_points):
			continue
		
		# 检查免疫类型
		var type_val = enemy.get("enemy_type")
		if type_val != null and type_val == 3:
			Global.spawn_floating_text(enemy.global_position, "IMMUNE!", Color.GRAY)
			continue
		
		# 击杀敌人
		if enemy.has_method("destroy_enemy"):
			enemy.destroy_enemy()
			kill_count += 1
	
	# 应用奖励
	_apply_circle_rewards(kill_count, polygon_points)

## 应用画圈奖励
func _apply_circle_rewards(kill_count: int, polygon: PackedVector2Array) -> void:
	if kill_count <= 0 or not skill_owner:
		return
	
	# 显示击杀数量
	Global.spawn_floating_text(skill_owner.global_position, "KILLED x%d" % kill_count, Color.GOLD)
	
	# 小圈奖励 (1-2个怪)
	if kill_count >= 1 and kill_count <= 2:
		# 返还80% Q技能能量
		var energy_refund = energy_cost * 0.8 * (dash_queue.size() + path_history.size())
		if energy_refund > 0 and skill_owner.has_method("gain_energy"):
			skill_owner.gain_energy(energy_refund)
		Global.spawn_floating_text(skill_owner.global_position, "GOOD!", Color(0.5, 1.0, 0.5))
		Global.on_camera_shake.emit(5.0, 0.1)
	
	# 大圈奖励 (10+个怪)
	elif kill_count >= 10:
		# 增加护甲
		if "armor" in skill_owner and "max_armor" in skill_owner:
			if skill_owner.armor < skill_owner.max_armor:
				skill_owner.armor = min(skill_owner.armor + 5, skill_owner.max_armor)
				if skill_owner.has_signal("armor_changed"):
					skill_owner.armor_changed.emit(skill_owner.armor)
		
		# 恢复生命
		if skill_owner.has_node("HealthComponent"):
			var health_component = skill_owner.get_node("HealthComponent")
			if health_component.current_health < health_component.max_health:
				var heal_amount = 20
				health_component.current_health = min(
					health_component.current_health + heal_amount,
					health_component.max_health
				)
				health_component.on_health_changed.emit(
					health_component.current_health,
					health_component.max_health
				)
				Global.spawn_floating_text(skill_owner.global_position, "+%d HP" % heal_amount, Color.GREEN)
		
		Global.spawn_floating_text(skill_owner.global_position, "DIVINE!", Color(2.0, 2.0, 0.0))
		Global.on_camera_shake.emit(15.0, 0.3)
	
	# 中圈奖励 (3-9个怪)
	else:
		# 返还50% Q技能能量
		var energy_refund = energy_cost * 0.5 * (dash_queue.size() + path_history.size())
		if energy_refund > 0 and skill_owner.has_method("gain_energy"):
			skill_owner.gain_energy(energy_refund)
		Global.spawn_floating_text(skill_owner.global_position, "PERFECT!", Color(1.0, 1.0, 0.0))
		Global.on_camera_shake.emit(10.0, 0.2)

## 创建几何遮罩视觉效果
func _create_geometry_mask_visual(points: PackedVector2Array) -> Polygon2D:
	var poly_node = Polygon2D.new()
	poly_node.polygon = points
	poly_node.color = geometry_mask_color
	poly_node.color.a = 0.0
	poly_node.z_index = 100
	get_tree().current_scene.add_child(poly_node)
	return poly_node

# ==============================================================================
# 辅助方法
# ==============================================================================

## 检查玩家是否可以移动
func can_move() -> bool:
	return not is_dashing

## 清理资源
func cleanup() -> void:
	# 清理Line2D
	if is_instance_valid(line_2d):
		line_2d.queue_free()
	
	# 重置状态
	is_planning = false
	is_dashing = false
	is_executing_kill = false
	dash_queue.clear()
	path_history.clear()
	current_target = Vector2.ZERO
	Engine.time_scale = 1.0

## 打印调试信息
func print_debug_info() -> void:
	print("[SkillHerderLoop] 调试信息:")
	print("  - is_planning: %s" % is_planning)
	print("  - is_dashing: %s" % is_dashing)
	print("  - dash_queue: %d" % dash_queue.size())
	print("  - path_history: %d" % path_history.size())
	print("  - fixed_segment_length: %.0f" % fixed_segment_length)
	print("  - dash_speed: %.0f" % dash_speed)
	print("  - energy_cost: %.0f" % energy_cost)
