extends SkillBase
class_name SkillMinePath

## ==============================================================================
## 工兵Q技能 - 布雷路径
## ==============================================================================
## 
## 功能说明:
## - 按住Q进入规划模式（子弹时间）
## - 左键：向鼠标方向延伸固定距离添加路径点
## - 右键：撤销最后一个路径点
## - 松开Q：执行冲刺序列，沿路径布雷
## - 路径闭合时在区域内密集布雷
## - 地雷触发后爆炸造成范围伤害
## 
## 使用方法:
##   - 按住Q进入规划模式
##   - 左键添加路径点
##   - 松开Q执行冲刺并布雷
## 
## ==============================================================================

# ==============================================================================
# 技能参数（从CSV加载）
# ==============================================================================

## 每段冲刺的固定距离
var fixed_segment_length: float = 300.0

## 地雷伤害
var mine_damage: int = 150

## 地雷触发半径
var mine_trigger_radius: float = 20.0

## 地雷爆炸半径
var mine_explosion_radius: float = 120.0

## 线段布雷密度（距离）
var mine_density_distance: float = 50.0

## 区域布雷密度（距离）
var mine_area_density: float = 60.0

## 地雷自动爆炸时间
var mine_auto_explode_time: float = 5.0

## 冲刺速度
var dash_speed: float = 1200.0

## 冲刺基础伤害
var dash_base_damage: int = 20

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

## 当前是否布雷
var current_lay_mines: bool = false

## 路径历史（用于闭合检测）
var path_history: Array[Vector2] = []

## 待填充的多边形
var pending_polygon: PackedVector2Array = []

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
		line_2d.name = "MinePlanningLine"
		line_2d.width = 4.0
		skill_owner.add_child(line_2d)
		line_2d.top_level = true
		line_2d.clear_points()
		line_2d.default_color = Color(1.0, 0.8, 0.0, 0.8)  # 金黄色
		
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
		# 左键：添加路径点
		if Input.is_action_just_pressed("click_left"):
			if _try_add_path_segment():
				pass  # 静默添加
		
		# 右键：撤销路径点
		if Input.is_action_just_pressed("click_right"):
			_undo_last_point()

## 释放技能（松开Q）
func release() -> void:
	if is_planning:
		_execute_mine_deployment()

# ==============================================================================
# 规划模式
# ==============================================================================

## 进入规划模式
func _enter_planning_mode() -> void:
	is_planning = true
	is_charging = true
	Engine.time_scale = 0.1

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

## 执行地雷部署
func _execute_mine_deployment() -> void:
	is_planning = false
	is_charging = false
	Engine.time_scale = 1.0
	
	if dash_queue.is_empty():
		line_2d.clear_points()
		return
	
	pending_polygon.clear()
	
	# 构建完整路径用于检测闭合
	var full_path: Array[Vector2] = []
	full_path.append(skill_owner.global_position)
	full_path.append_array(dash_queue)
	
	var polygon = _find_closing_polygon(full_path)
	
	if polygon.size() > 0:
		# 闭环：区域布雷
		Global.spawn_floating_text(skill_owner.global_position, "LOCKING...", Color.RED)
		pending_polygon = polygon
		# 闭环时不沿途布雷，只跑路
		current_lay_mines = false
	else:
		# 未闭环：沿途布雷
		current_lay_mines = true
	
	_start_dash_sequence()

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
		line_2d.default_color = Color(1.0, 0.2, 0.2, 0.8)  # 闭合提示（红色）
	elif skill_owner and skill_owner.energy < energy_cost:
		line_2d.default_color = Color(0.5, 0.5, 0.5, 0.5)
	else:
		line_2d.default_color = Color(1.0, 0.8, 0.0, 0.8)  # 正常规划（金黄）
	
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
	
	# 清空历史路径
	path_history.clear()
	path_history.append(skill_owner.global_position)
	
	# 启动拖尾特效
	if trail and trail.has_method("start_trail"):
		trail.start_trail()
	
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
	
	# 只有当需要布雷时才沿途生成
	if current_lay_mines:
		_fill_mines_segment(previous_pos, skill_owner.global_position)
	
	# 继续下一个目标或结束
	if dash_queue.size() > 0:
		current_target = dash_queue.pop_front()
	else:
		_end_dash_sequence()

## 结束冲刺序列
func _end_dash_sequence() -> void:
	is_dashing = false
	is_executing = false
	
	# 检查是否有闭环区域需要填充
	if pending_polygon.size() > 0:
		Global.spawn_floating_text(skill_owner.global_position, "MINE FIELD!", Color.RED)
		Global.on_camera_shake.emit(10.0, 0.2)
		
		# 使用duplicate()复制数据，避免被清空
		_fill_mines_in_polygon(pending_polygon.duplicate())
		pending_polygon.clear()
	
	# 清理线条
	line_2d.clear_points()
	dash_queue.clear()
	path_history.clear()
	current_target = Vector2.ZERO
	
	# 停止拖尾特效
	if trail and trail.has_method("stop"):
		trail.stop()
	
	# 恢复碰撞
	if collision:
		collision.set_deferred("disabled", false)
	
	# 禁用冲刺伤害判定
	if dash_hitbox:
		dash_hitbox.set_deferred("monitorable", false)
		dash_hitbox.set_deferred("monitoring", false)

# ==============================================================================
# 地雷生成
# ==============================================================================

## 沿线段填充地雷
func _fill_mines_segment(from: Vector2, to: Vector2) -> void:
	var dist = from.distance_to(to)
	var count = int(dist / max(1.0, mine_density_distance))
	
	for i in range(count):
		var t = float(i) / float(max(1, count))
		var pos = from.lerp(to, t)
		call_deferred("_spawn_mine", pos)
	call_deferred("_spawn_mine", to)

## 在多边形区域内填充地雷
func _fill_mines_in_polygon(polygon: PackedVector2Array) -> void:
	if polygon.is_empty():
		return
	
	var rect = Rect2(polygon[0], Vector2.ZERO)
	for p in polygon:
		rect = rect.expand(p)
	
	var step = max(10.0, mine_area_density)
	var x = rect.position.x
	while x < rect.end.x:
		var y = rect.position.y
		while y < rect.end.y:
			var scan_pos = Vector2(x, y)
			if Geometry2D.is_point_in_polygon(scan_pos, polygon):
				var offset = Vector2(randf_range(-5, 5), randf_range(-5, 5))
				_spawn_mine(scan_pos + offset)
			y += step
		x += step

## 生成单个地雷
func _spawn_mine(pos: Vector2) -> void:
	var mine = Area2D.new()
	mine.global_position = pos
	mine.collision_mask = 2
	mine.monitorable = false
	mine.monitoring = true
	
	# 碰撞形状
	var col = CollisionShape2D.new()
	var shape = CircleShape2D.new()
	shape.radius = mine_trigger_radius
	col.shape = shape
	mine.add_child(col)
	
	# 视觉效果
	var vis = ColorRect.new()
	vis.color = Color(1, 0.2, 0.2)
	vis.size = Vector2(8, 8)
	vis.position = Vector2(-4, -4)
	mine.add_child(vis)
	
	get_tree().current_scene.add_child(mine)
	
	# 连接触发信号
	mine.area_entered.connect(_on_mine_trigger_area.bind(mine))
	mine.body_entered.connect(_on_mine_trigger_body.bind(mine))
	
	# 自动爆炸定时器
	var auto_explode_timer = Timer.new()
	auto_explode_timer.wait_time = mine_auto_explode_time
	auto_explode_timer.one_shot = true
	auto_explode_timer.autostart = true
	mine.add_child(auto_explode_timer)
	auto_explode_timer.timeout.connect(_explode_mine.bind(mine))

# ==============================================================================
# 地雷触发与爆炸
# ==============================================================================

## 地雷触发（Area）
func _on_mine_trigger_area(area: Area2D, mine: Area2D) -> void:
	if area.owner and area.owner.is_in_group("enemies"):
		_explode_mine(mine)
	elif area.is_in_group("enemies"):
		_explode_mine(mine)

## 地雷触发（Body）
func _on_mine_trigger_body(body: Node2D, mine: Area2D) -> void:
	if body.is_in_group("enemies"):
		_explode_mine(mine)

## 地雷爆炸
func _explode_mine(mine: Node2D) -> void:
	if not is_instance_valid(mine) or mine.is_queued_for_deletion():
		return
	
	mine.set_deferred("monitoring", false)
	
	# 对范围内敌人造成伤害
	var enemies = get_tree().get_nodes_in_group("enemies")
	var hit_count = 0
	
	for e in enemies:
		if not is_instance_valid(e):
			continue
		if e.global_position.distance_to(mine.global_position) < mine_explosion_radius:
			if e.has_node("HealthComponent"):
				e.health_component.take_damage(mine_damage)
				hit_count += 1
				if e.has_method("apply_knockback"):
					var dir = (e.global_position - mine.global_position).normalized()
					e.apply_knockback(dir, 300.0)
	
	if hit_count > 0:
		Global.on_camera_shake.emit(3.0, 0.1)
	
	# 爆炸视觉效果
	var flash = Polygon2D.new()
	var points = PackedVector2Array()
	for i in range(16):
		var angle = i * TAU / 16
		points.append(Vector2(cos(angle), sin(angle)) * mine_explosion_radius)
	flash.polygon = points
	flash.color = Color(1, 0.5, 0, 0.5)
	flash.global_position = mine.global_position
	get_tree().current_scene.add_child(flash)
	
	var tw = flash.create_tween()
	tw.tween_property(flash, "modulate:a", 0.0, 0.3)
	tw.tween_callback(func():
		if is_instance_valid(flash):
			flash.queue_free()
	)
	
	mine.queue_free()

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

## 清理资源
func cleanup() -> void:
	if is_instance_valid(line_2d):
		line_2d.queue_free()
	
	is_planning = false
	is_dashing = false
	dash_queue.clear()
	path_history.clear()
	pending_polygon.clear()
	current_target = Vector2.ZERO
	Engine.time_scale = 1.0
