extends SkillBase
class_name SkillMinePath

## ==============================================================================
## 工兵Q技能 - 布雷路径
## ==============================================================================
## 
## 功能说明:
## - 按住Q进入规划模式（子弹时间）
## - **按住鼠标左键在屏幕上连续划线**
##   - 以玩家坐标为起点
##   - 鼠标移动时实时绘制线段
##   - **每10像素消耗1点能量**
##   - **检测线段交叉**
##   - **如果形成封闭空间，线段变红色**
## - 松开鼠标左键，划线结束
## - 右键：清除所有路径并返还能量
## - 松开Q：执行冲刺序列，沿路径布雷
## - 路径闭合时在区域内密集布雷
## - 地雷触发后爆炸造成范围伤害
## 
## 使用方法:
##   - 按住Q进入规划模式
##   - 按住鼠标左键连续划线
##   - 松开鼠标左键结束划线
##   - 松开Q执行冲刺并布雷
## 
## ==============================================================================

# ==============================================================================
# 技能参数（从CSV加载）
# ==============================================================================

## 每10像素消耗的能量（基础值）
var energy_per_10px: float = 1.0

## 能量递增阈值距离（像素）
var energy_threshold_distance: float = 1800.0

## 能量递增系数
var energy_scale_multiplier: float = 0.001

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

## 每隔多少像素记录一个路径点
const POINT_INTERVAL: float = 10.0

# ==============================================================================
# 运行时状态
# ==============================================================================

## 是否处于规划模式
var is_planning: bool = false

## 是否正在划线
var is_drawing: bool = false

## 上一个记录的点
var last_point: Vector2 = Vector2.ZERO

## 累计距离（用于判断是否达到10像素）
var accumulated_distance: float = 0.0

## 路径点列表（用于绘制和冲刺）
var path_points: Array[Vector2] = []

## 路径线段列表（用于交叉检测）
var path_segments: Array[Dictionary] = []

## 是否有封闭空间
var has_closure: bool = false

## 当前冲刺目标索引
var current_target_index: int = 0

## 当前是否布雷
var current_lay_mines: bool = false

## 路径历史（用于闭合检测）
var path_history: Array[Vector2] = []

## 待填充的多边形（支持多区域）
var pending_polygons: Array[PackedVector2Array] = []

## 已画的总距离（用于能量递增计算）
var total_distance_drawn: float = 0.0

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
		# 检测鼠标左键按下 - 开始或继续划线
		if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
			if not is_drawing:
				# 开始划线
				is_drawing = true
			
			# 获取鼠标位置
			var mouse_pos = skill_owner.get_global_mouse_position()
			var distance = last_point.distance_to(mouse_pos)
			
			# 如果鼠标移动距离太小，跳过本帧
			if distance < 1.0:
				return
			
			# 计算需要添加多少个点
			var points_to_add = int(distance / POINT_INTERVAL)
			
			# 沿着鼠标轨迹添加点
			for i in range(points_to_add):
				# 计算当前能量消耗（动态递增）
				var current_energy_cost = _calculate_current_energy_cost()
				
				# 检查能量是否足够
				if skill_owner.energy >= current_energy_cost:
					# 消耗能量
					skill_owner.consume_energy(current_energy_cost)
					
					# 更新总距离
					total_distance_drawn += POINT_INTERVAL
					
					# 沿着 last_point 到 mouse_pos 的方向前进 POINT_INTERVAL
					var direction = (mouse_pos - last_point).normalized()
					var new_point = last_point + direction * POINT_INTERVAL
					
					# 添加路径点
					path_points.append(new_point)
					
					# 创建线段
					var segment = {
						"start": last_point,
						"end": new_point
					}
					path_segments.append(segment)
					
					# 检测线段交叉
					_check_intersection_and_closure()
					
					# 更新状态
					last_point = new_point
				else:
					# 能量不足
					is_drawing = false
					Global.spawn_floating_text(skill_owner.global_position, "No Energy!", Color.RED)
					break
		else:
			# 鼠标左键松开
			if is_drawing:
				is_drawing = false
				accumulated_distance = 0.0
		
		# 右键：清除所有路径
		if Input.is_action_just_pressed("click_right"):
			_clear_all_points()

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
	is_drawing = false
	accumulated_distance = 0.0
	has_closure = false
	total_distance_drawn = 0.0
	
	# 清空路径数据
	path_points.clear()
	path_segments.clear()
	
	# 设置起点为玩家位置
	var start_pos = skill_owner.global_position
	path_points.append(start_pos)
	last_point = start_pos
	
	Engine.time_scale = 0.1

## 退出规划模式并开始冲刺
func _exit_planning_mode_and_dash() -> void:
	is_planning = false
	is_charging = false
	is_drawing = false
	Engine.time_scale = 1.0
	
	if path_points.size() > 1:
		# 在松开Q键时进行最终的闭合检测
		_perform_final_closure_check()
		
		# 根据 has_closure 标志决定是否闭合
		pending_polygons.clear()
		
		if has_closure:
			# 闭环：区域布雷
			Global.spawn_floating_text(skill_owner.global_position, "LOCKING...", Color.RED)
			# 查找所有闭合多边形（支持8字形等多区域）
			var polygons = _find_all_closing_polygons()
			if polygons.size() > 0:
				pending_polygons = polygons
			# 闭环时不沿途布雷，只跑路
			current_lay_mines = false
		else:
			# 未闭环：沿途布雷
			current_lay_mines = true
		
		_start_dash_sequence()
	else:
		_clear_all_points()

## 执行最终的闭合检测（松开Q键时调用）
func _perform_final_closure_check() -> void:
	# 不管实时检测结果如何，都重新检查一次
	# 重置标志
	has_closure = false
	
	if path_segments.size() < 3:
		return
	
	# 检查任意两条不相邻的线段是否相交
	for i in range(path_segments.size()):
		for j in range(i + 2, path_segments.size()):
			var seg1 = path_segments[i]
			var seg2 = path_segments[j]
			
			if _segments_intersect(seg1, seg2):
				print("[SkillMinePath] >>> 检测到线段交叉！线段 %d 和 %d <<<" % [i, j])
				has_closure = true
				return
	
	# 检查距离闭合：终点是否接近起点或路径中的其他点
	if path_points.size() >= 3:
		var last_point = path_points[path_points.size() - 1]
		
		# 检查是否接近起点
		if last_point.distance_to(path_points[0]) < close_threshold:
			print("[SkillMinePath] >>> 检测到距离闭合（接近起点）<<<")
			has_closure = true
			return
		
		# 检查是否接近路径中的其他点（排除最后20个点）
		var check_until = max(0, path_points.size() - 20)
		for i in range(check_until):
			if last_point.distance_to(path_points[i]) < close_threshold:
				print("[SkillMinePath] >>> 检测到距离闭合（接近点 %d）<<<" % i)
				has_closure = true
				return

## 检测线段交叉和封闭空间（实时检测，用于视觉反馈）
func _check_intersection_and_closure() -> void:
	# 如果已经检测到闭合，不再重复检测
	if has_closure:
		return
	
	# 需要至少3条线段才能形成闭合
	if path_segments.size() < 3:
		return
	
	# 检查最新线段是否与之前的线段相交（跳过相邻线段）
	var latest_seg = path_segments[path_segments.size() - 1]
	
	# 只检查最新线段与之前的非相邻线段
	for i in range(path_segments.size() - 2):
		var old_seg = path_segments[i]
		
		if _segments_intersect(latest_seg, old_seg):
			print("[SkillMinePath] >>> 实时检测到线段交叉！线段 %d 和最新线段 <<<" % i)
			has_closure = true
			return
	
	# 检查距离闭合：当前点是否接近起点（排除最近的点）
	if path_points.size() >= 20:
		var current_point = path_points[path_points.size() - 1]
		if current_point.distance_to(path_points[0]) < close_threshold:
			print("[SkillMinePath] >>> 实时检测到距离闭合（接近起点）<<<")
			has_closure = true
			return

## 检测两条线段是否相交
func _segments_intersect(seg1: Dictionary, seg2: Dictionary) -> bool:
	var p1 = seg1["start"]
	var p2 = seg1["end"]
	var p3 = seg2["start"]
	var p4 = seg2["end"]
	
	var intersection = Geometry2D.segment_intersects_segment(p1, p2, p3, p4)
	return intersection != null

## 清除所有路径点
func _clear_all_points() -> void:
	# 计算已消耗的总能量（需要积分计算）
	var total_consumed_energy = _calculate_total_consumed_energy()
	
	# 返还能量
	if skill_owner and total_consumed_energy > 0:
		skill_owner.energy += total_consumed_energy
		skill_owner.update_ui_signals()
	
	# 清空数据
	path_points.clear()
	path_segments.clear()
	has_closure = false
	accumulated_distance = 0.0
	total_distance_drawn = 0.0
	
	# 重置起点
	if skill_owner:
		var start_pos = skill_owner.global_position
		path_points.append(start_pos)
		last_point = start_pos

## 计算当前能量消耗（动态递增）
func _calculate_current_energy_cost() -> float:
	if total_distance_drawn <= energy_threshold_distance:
		# 基础阶段
		return energy_per_10px
	else:
		# 递增阶段
		var excess_distance = total_distance_drawn - energy_threshold_distance
		var multiplier = 1.0 + excess_distance * energy_scale_multiplier
		return energy_per_10px * multiplier

## 计算已消耗的总能量（用于返还）
func _calculate_total_consumed_energy() -> float:
	var total = 0.0
	var distance = 0.0
	
	# 从起点开始，每10像素计算一次
	while distance < total_distance_drawn:
		if distance <= energy_threshold_distance:
			total += energy_per_10px
		else:
			var excess = distance - energy_threshold_distance
			var multiplier = 1.0 + excess * energy_scale_multiplier
			total += energy_per_10px * multiplier
		
		distance += POINT_INTERVAL
	
	return total

## 更新规划路径的视觉效果（每帧调用）
func _update_visuals() -> void:
	line_2d.clear_points()
	
	if path_points.is_empty() and not is_planning:
		return
	
	if not skill_owner:
		return
	
	# 绘制已确认的路径点
	for p in path_points:
		line_2d.add_point(p)
	
	# 如果正在划线，添加到鼠标的预览线
	if is_planning and is_drawing:
		var mouse_pos = skill_owner.get_global_mouse_position()
		line_2d.add_point(mouse_pos)
	
	# 颜色判断：根据封闭状态和能量递增设置颜色
	if has_closure:
		line_2d.default_color = Color(1.0, 0.2, 0.2, 0.8)  # 闭合提示（红色）
	elif is_planning and skill_owner and skill_owner.energy < _calculate_current_energy_cost():
		line_2d.default_color = Color(0.5, 0.5, 0.5, 0.5)
	elif is_planning and total_distance_drawn > energy_threshold_distance:
		# 超过阈值，颜色渐变提示（金黄 -> 深橙色）
		var excess_ratio = (total_distance_drawn - energy_threshold_distance) / energy_threshold_distance
		excess_ratio = clamp(excess_ratio, 0.0, 1.0)
		var base_color = Color(1.0, 0.8, 0.0, 0.8)  # 金黄
		var warning_color = Color(1.0, 0.4, 0.0, 0.8)  # 深橙色
		line_2d.default_color = base_color.lerp(warning_color, excess_ratio * 0.5)
	else:
		line_2d.default_color = Color(1.0, 0.8, 0.0, 0.8)  # 正常规划（金黄）

# ==============================================================================
# 冲刺执行
# ==============================================================================

## 开始冲刺序列
func _start_dash_sequence() -> void:
	if path_points.size() < 2 or not skill_owner:
		return
	
	is_dashing = true
	is_executing = true
	current_target_index = 1
	
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
	
	# 开始冷却
	start_cooldown()

## 处理冲刺移动
func _process_dashing_movement(delta: float) -> void:
	if not skill_owner or current_target_index >= path_points.size():
		return
	
	# 恢复时间流速
	Engine.time_scale = 1.0
	
	var target = path_points[current_target_index]
	
	# 向目标移动
	skill_owner.position = skill_owner.position.move_toward(target, dash_speed * delta)
	
	# 检查是否到达目标
	if skill_owner.position.distance_to(target) < 5.0:
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
	current_target_index += 1
	if current_target_index >= path_points.size():
		_end_dash_sequence()

## 结束冲刺序列
func _end_dash_sequence() -> void:
	is_dashing = false
	is_executing = false
	
	# 检查是否有闭环区域需要填充（支持多区域）
	if pending_polygons.size() > 0:
		Global.spawn_floating_text(skill_owner.global_position, "MINE FIELD!", Color.RED)
		Global.on_camera_shake.emit(10.0, 0.2)
		
		# 一次性显示所有遮罩（同步动画）
		PolygonUtils.show_closure_masks(pending_polygons, Color(1.0, 0.9, 0.0, 0.7), get_tree(), 0.6)
		
		# 为每个闭合区域填充地雷
		for polygon in pending_polygons:
			_fill_mines_in_polygon_no_mask(polygon)
		
		pending_polygons.clear()
	
	# 清理线条
	line_2d.clear_points()
	path_points.clear()
	path_segments.clear()
	path_history.clear()
	current_target_index = 0
	has_closure = false
	
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
	
	print("[SkillMinePath] _fill_mines_segment: 从 %s 到 %s, 距离: %.0f, 地雷数: %d" % [from, to, dist, count])
	
	for i in range(count):
		var t = float(i) / float(max(1, count))
		var pos = from.lerp(to, t)
		_spawn_mine(pos)
	_spawn_mine(to)

## 在多边形区域内填充地雷
func _fill_mines_in_polygon(polygon: PackedVector2Array) -> void:
	if polygon.is_empty():
		return
	
	print("[SkillMinePath] >>> 触发地雷区域！多边形点数: %d <<<" % polygon.size())
	
	# 创建闭合遮罩视觉效果
	_create_mine_closure_mask(polygon)
	
	_fill_mines_in_polygon_no_mask(polygon)

## 在多边形区域内填充地雷（不显示遮罩，用于多区域同步显示）
func _fill_mines_in_polygon_no_mask(polygon: PackedVector2Array) -> void:
	if polygon.is_empty():
		return
	
	print("[SkillMinePath] >>> 触发地雷区域！多边形点数: %d <<<" % polygon.size())
	
	var rect = Rect2(polygon[0], Vector2.ZERO)
	for p in polygon:
		rect = rect.expand(p)
	
	print("[SkillMinePath] 扫描区域: %s" % rect)
	
	var step = max(10.0, mine_area_density)
	var mine_count = 0
	var x = rect.position.x
	while x < rect.end.x:
		var y = rect.position.y
		while y < rect.end.y:
			var scan_pos = Vector2(x, y)
			if Geometry2D.is_point_in_polygon(scan_pos, polygon):
				var offset = Vector2(randf_range(-5, 5), randf_range(-5, 5))
				_spawn_mine(scan_pos + offset)
				mine_count += 1
			y += step
		x += step
	
	print("[SkillMinePath] 生成地雷数量: %d" % mine_count)

## 创建地雷闭合遮罩视觉效果 - 使用公共工具类
func _create_mine_closure_mask(polygon: PackedVector2Array) -> void:
	var polygons: Array[PackedVector2Array] = [polygon]
	PolygonUtils.show_closure_masks(polygons, Color(1.0, 0.9, 0.0, 0.7), get_tree(), 0.6)

## 生成单个地雷
func _spawn_mine(pos: Vector2) -> void:
	print("[SkillMinePath] _spawn_mine 被调用，位置: %s" % pos)
	
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
	print("[SkillMinePath] 地雷已添加到场景: %s" % mine.name)
	
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

## 查找所有闭合多边形（支持8字形等多区域）- 使用公共工具类
func _find_all_closing_polygons() -> Array[PackedVector2Array]:
	return PolygonUtils.find_all_closing_polygons(path_points, close_threshold)

## 查找闭合多边形（保留兼容性）
func _find_closing_polygon(points: Array[Vector2]) -> PackedVector2Array:
	var polygons = PolygonUtils.find_all_closing_polygons(points, close_threshold)
	if polygons.size() > 0:
		return polygons[0]
	return PackedVector2Array()

## 清理资源
func cleanup() -> void:
	if is_instance_valid(line_2d):
		line_2d.queue_free()
	
	is_planning = false
	is_dashing = false
	is_drawing = false
	path_points.clear()
	path_segments.clear()
	path_history.clear()
	pending_polygons.clear()
	current_target_index = 0
	has_closure = false
	accumulated_distance = 0.0
	total_distance_drawn = 0.0
	Engine.time_scale = 1.0
