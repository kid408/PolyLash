extends SkillBase
class_name SkillFirePath

## ==============================================================================
## 烈焰者Q技能 - 火线与火海
## ==============================================================================
## 
## 功能说明:
## - 按住Q进入规划模式（子弹时间）
## - 左键：向鼠标方向延伸固定距离添加火线路径点
## - 右键：撤销最后一个路径点
## - 松开Q：执行冲刺序列，沿路径生成火线
## - 路径闭合时生成火海（区域持续伤害）
## - 根据圈内敌人数量给予不同奖励
## 
## 使用方法:
##   - 按住Q进入规划模式
##   - 左键添加火线路径点
##   - 松开Q执行冲刺并生成火线
## 
## ==============================================================================

# ==============================================================================
# 技能参数（从CSV加载）
# ==============================================================================

## 每段冲刺的固定距离
var fixed_segment_length: float = 300.0

## 火线伤害
var fire_line_damage: int = 20

## 火线持续时间
var fire_line_duration: float = 5.0

## 火线宽度
var fire_line_width: float = 24.0

## 火海伤害
var fire_sea_damage: int = 40

## 火海持续时间
var fire_sea_duration: float = 5.0

## 冲刺速度
var dash_speed: float = 1200.0

## 冲刺基础伤害
var dash_base_damage: int = 10

## 击退力度
var dash_knockback: float = 2.0

## 闭合判定阈值
var close_threshold: float = 60.0

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
		line_2d.name = "FirePlanningLine"
		line_2d.width = 4.0
		skill_owner.add_child(line_2d)
		line_2d.top_level = true
		line_2d.clear_points()
		line_2d.default_color = Color(2.0, 1.0, 0.3, 1.0)  # 高亮金橙色
		
		# 获取节点引用
		collision = skill_owner.get_node_or_null("CollisionShape2D")
		dash_hitbox = skill_owner.get_node_or_null("DashHitbox")
		trail = skill_owner.get_node_or_null("%Trail")
		visuals = skill_owner.get_node_or_null("Visuals")
		
		# 从skill_owner读取参数
		if "close_threshold" in skill_owner:
			close_threshold = skill_owner.close_threshold
		
		if "dash_base_damage" in skill_owner:
			dash_base_damage = skill_owner.dash_base_damage

func _process(delta: float) -> void:
	super._process(delta)
	
	# 强制维持子弹时间
	if is_planning and Engine.time_scale > 0.2:
		Engine.time_scale = 0.1
	
	# 处理冲刺移动
	if is_dashing:
		_process_dashing_movement(delta)
	
	# 每帧更新视觉效果
	_update_visuals()

# ==============================================================================
# 技能执行
# ==============================================================================

## 蓄力技能（持续按住Q）
func charge(delta: float) -> void:
	if not is_planning:
		_enter_planning_mode()
	
	if is_planning:
		# 左键：添加火线路径点
		if Input.is_action_just_pressed("click_left"):
			if _try_add_path_segment():
				Global.spawn_floating_text(skill_owner.get_global_mouse_position(), "MARK", Color(1.5, 0.8, 0.2))
		
		# 右键：撤销路径点
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
	
	if dash_queue.size() > 0:
		_start_dash_sequence()
	else:
		line_2d.clear_points()
		dash_queue.clear()
		path_history.clear()

## 尝试添加路径段
func _try_add_path_segment() -> bool:
	if consume_energy():
		_add_path_point(skill_owner.get_global_mouse_position())
		return true
	else:
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

## 撤销最后一个点
func _undo_last_point() -> void:
	if dash_queue.size() > 0:
		dash_queue.pop_back()
		
		# 返还能量
		if skill_owner and skill_owner.has_method("gain_energy"):
			skill_owner.energy += energy_cost
			skill_owner.update_ui_signals()

## 更新规划路径的视觉效果（每帧调用）
func _update_visuals() -> void:
	line_2d.clear_points()
	
	if dash_queue.is_empty() and not is_planning:
		return
	
	if not skill_owner:
		return
	
	# 构建已确认的点集
	var confirmed_points: Array[Vector2] = []
	confirmed_points.append(skill_owner.global_position)
	confirmed_points.append_array(dash_queue)
	
	# 绘制已确认的点
	for p in confirmed_points:
		line_2d.add_point(p)
	
	# 颜色判断：检查是否形成闭环
	var poly = _find_closing_polygon(confirmed_points)
	
	if poly.size() > 0:
		line_2d.default_color = Color(2.0, 0.1, 0.1, 1.0)  # 闭合提示（高亮红）
	elif skill_owner and skill_owner.energy < energy_cost:
		line_2d.default_color = Color(0.5, 0.5, 0.5, 0.5)
	else:
		line_2d.default_color = Color(2.0, 1.0, 0.3, 1.0)  # 正常规划（高亮金）
	
	# 绘制预览线段（如果正在规划）
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
		return
	
	is_dashing = true
	is_executing = true
	
	# 清空历史路径，确保每次Q技能使用都是独立的
	path_history.clear()
	path_history.append(skill_owner.global_position)
	
	# 启动拖尾特效
	if trail and trail.has_method("start_trail"):
		trail.start_trail()
	
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
	
	# 开始冷却
	start_cooldown()

## 处理冲刺移动
func _process_dashing_movement(delta: float) -> void:
	if not skill_owner or current_target == Vector2.ZERO:
		return
	
	# 恢复时间流速
	Engine.time_scale = 1.0
	
	# 向目标移动
	skill_owner.position = skill_owner.position.move_toward(current_target, dash_speed * delta)
	
	# 检查是否到达目标
	if skill_owner.position.distance_to(current_target) < 10.0:
		_on_reach_target_point()

## 到达目标点
func _on_reach_target_point() -> void:
	if not skill_owner:
		return
	
	var previous_pos = path_history.back()
	path_history.append(skill_owner.global_position)
	
	# 生成火线
	_spawn_fire_line(previous_pos, skill_owner.global_position)
	
	# 检查闭合
	_check_and_trigger_intersection()
	
	# 继续下一个目标或结束
	if dash_queue.size() > 0:
		current_target = dash_queue.pop_front()
	else:
		_end_dash_sequence()

## 结束冲刺序列
func _end_dash_sequence() -> void:
	# 最后再检查一次闭合
	_check_and_trigger_intersection()
	
	is_dashing = false
	is_executing = false
	
	# 清理线条
	line_2d.clear_points()
	dash_queue.clear()
	path_history.clear()
	current_target = Vector2.ZERO
	
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

# ==============================================================================
# 火焰技能生成
# ==============================================================================

## 生成火线
func _spawn_fire_line(start: Vector2, end: Vector2) -> void:
	var area = Area2D.new()
	area.position = start
	area.collision_mask = 2
	area.monitorable = false
	area.monitoring = true
	
	var vec = end - start
	var length = vec.length()
	var angle = vec.angle()
	
	# 碰撞形状
	var col = CollisionShape2D.new()
	var shape = RectangleShape2D.new()
	shape.size = Vector2(length, fire_line_width)
	col.shape = shape
	col.position = Vector2(length / 2.0, 0)
	col.rotation = angle
	area.add_child(col)
	
	# 视觉效果
	var vis_line = Line2D.new()
	vis_line.add_point(Vector2.ZERO)
	vis_line.add_point(end - start)
	vis_line.width = fire_line_width
	vis_line.default_color = Color(2.0, 1.2, 0.4, 0.9)
	vis_line.begin_cap_mode = Line2D.LINE_CAP_ROUND
	vis_line.end_cap_mode = Line2D.LINE_CAP_ROUND
	area.add_child(vis_line)
	
	get_tree().current_scene.add_child(area)
	
	# 伤害逻辑
	var timer = Timer.new()
	timer.wait_time = 0.5
	timer.autostart = true
	area.add_child(timer)
	timer.timeout.connect(_on_damage_tick.bind(area, fire_line_damage))
	
	# 寿命
	var life = get_tree().create_timer(fire_line_duration)
	life.timeout.connect(_on_object_expired.bind(area, vis_line))

## 生成火海
func _spawn_fire_sea(points: PackedVector2Array) -> void:
	if points.size() < 3:
		return
	
	Global.on_camera_shake.emit(15.0, 0.4)
	
	var area = Area2D.new()
	area.collision_mask = 2
	area.monitorable = false
	area.monitoring = true
	
	# 碰撞形状
	var col = CollisionPolygon2D.new()
	col.polygon = points
	area.add_child(col)
	
	# 视觉效果
	var vis_poly = Polygon2D.new()
	vis_poly.polygon = points
	vis_poly.color = Color(1.0, 1.0, 1.0, 0.0)
	vis_poly.z_index = 10
	area.add_child(vis_poly)
	
	get_tree().current_scene.add_child(area)
	Global.spawn_floating_text(points[0], "INFERNO!", Color(2.0, 1.0, 0.0))
	
	# 淡入动画
	var tween = area.create_tween()
	tween.tween_property(vis_poly, "color", Color(1.5, 0.7, 0.2, 0.6), 0.2).set_trans(Tween.TRANS_QUAD)
	
	# 伤害逻辑
	var timer = Timer.new()
	timer.wait_time = 0.3
	timer.autostart = true
	area.add_child(timer)
	timer.timeout.connect(_on_damage_tick.bind(area, fire_sea_damage))
	
	# 寿命
	var life = get_tree().create_timer(fire_sea_duration)
	life.timeout.connect(_on_object_expired.bind(area, vis_poly))
	
	# 画圈奖励
	await get_tree().process_frame
	_apply_circle_rewards(area, points)

# ==============================================================================
# 闭环检测
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
	var polygon_points = _find_closing_polygon(path_history)
	if polygon_points.size() > 0:
		_spawn_fire_sea(polygon_points)
		# 清空历史，避免重复触发
		var last = path_history.back()
		path_history.clear()
		path_history.append(last)

# ==============================================================================
# 回调函数
# ==============================================================================

## 伤害tick
func _on_damage_tick(area_ref: Area2D, amount: int) -> void:
	if not is_instance_valid(area_ref) or area_ref.is_queued_for_deletion():
		return
	
	var targets = area_ref.get_overlapping_bodies() + area_ref.get_overlapping_areas()
	for t in targets:
		var enemy = null
		if t.is_in_group("enemies"):
			enemy = t
		elif t.owner and t.owner.is_in_group("enemies"):
			enemy = t.owner
		
		if enemy and enemy.has_node("HealthComponent"):
			enemy.health_component.take_damage(amount)

## 对象过期
func _on_object_expired(area_ref: Area2D, visual_ref: Node) -> void:
	if is_instance_valid(area_ref):
		if is_instance_valid(visual_ref):
			var tween = area_ref.create_tween()
			tween.tween_property(visual_ref, "modulate:a", 0.0, 0.3)
			tween.tween_callback(func():
				if is_instance_valid(area_ref):
					area_ref.queue_free()
			)
		else:
			area_ref.queue_free()

## 画圈奖励
func _apply_circle_rewards(area_ref: Area2D, polygon: PackedVector2Array) -> void:
	if not is_instance_valid(area_ref) or not skill_owner:
		return
	
	# 计算圈内敌人数量
	var enemies_in_circle = 0
	var enemies = get_tree().get_nodes_in_group("enemies")
	for enemy in enemies:
		if is_instance_valid(enemy) and Geometry2D.is_point_in_polygon(enemy.global_position, polygon):
			enemies_in_circle += 1
	
	if enemies_in_circle <= 0:
		return
	
	# 显示击杀数量
	Global.spawn_floating_text(skill_owner.global_position, "BURNING x%d" % enemies_in_circle, Color.ORANGE)
	
	# 小圈奖励 (1-2个怪)
	if enemies_in_circle >= 1 and enemies_in_circle <= 2:
		var energy_refund = energy_cost * 0.8 * 2
		if energy_refund > 0 and skill_owner.has_method("gain_energy"):
			skill_owner.gain_energy(energy_refund)
		Global.spawn_floating_text(skill_owner.global_position, "GOOD!", Color(0.5, 1.0, 0.5))
	
	# 大圈奖励 (10+个怪)
	elif enemies_in_circle >= 10:
		# 增加护甲
		if "armor" in skill_owner and "max_armor" in skill_owner:
			if skill_owner.armor < skill_owner.max_armor:
				skill_owner.armor = min(skill_owner.armor + 3, skill_owner.max_armor)
				if skill_owner.has_signal("armor_changed"):
					skill_owner.armor_changed.emit(skill_owner.armor)
		
		# 恢复生命
		if skill_owner.has_node("HealthComponent"):
			var health_component = skill_owner.get_node("HealthComponent")
			if health_component.current_health < health_component.max_health:
				var heal_amount = 15
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
		var energy_refund = energy_cost * 0.5 * 2
		if energy_refund > 0 and skill_owner.has_method("gain_energy"):
			skill_owner.gain_energy(energy_refund)
		Global.spawn_floating_text(skill_owner.global_position, "PERFECT!", Color(1.0, 1.0, 0.0))

## 清理资源
func cleanup() -> void:
	if is_instance_valid(line_2d):
		line_2d.queue_free()
	
	is_planning = false
	is_dashing = false
	dash_queue.clear()
	path_history.clear()
	current_target = Vector2.ZERO
	Engine.time_scale = 1.0
