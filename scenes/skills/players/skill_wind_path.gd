extends SkillBase
class_name SkillWindPath

## ==============================================================================
## 御风者Q技能 - 风墙与暴风区域
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
## - 松开Q：执行冲刺序列，沿路径生成风墙（物理吸附+伤害）
## - 路径闭合时生成暴风区域（强力聚怪+伤害）
## - 根据圈内敌人数量给予不同奖励
## 
## 使用方法:
##   - 按住Q进入规划模式
##   - 按住鼠标左键连续划线
##   - 松开鼠标左键结束划线
##   - 松开Q执行冲刺并生成风墙
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
var energy_scale_multiplier: float = 0.0006

## 风墙吸附力度
var wind_wall_pull_force: float = 350.0

## 风墙伤害
var wind_wall_damage: int = 15

## 风墙持续时间
var wind_wall_duration: float = 3.0

## 风墙宽度
var wind_wall_width: float = 24.0

## 风墙效果半径
var wind_wall_effect_radius: float = 120.0

## 暴风区域伤害
var storm_zone_damage: int = 30

## 暴风区域吸附力度
var storm_zone_pull_force: float = 400.0

## 暴风区域持续时间
var storm_zone_duration: float = 3.0

## 冲刺速度
var dash_speed: float = 1200.0

## 冲刺基础伤害
var dash_base_damage: int = 10

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

## 路径历史（用于闭合检测）
var path_history: Array[Vector2] = []

## 已画的总距离（用于能量递增计算）
var total_distance_drawn: float = 0.0

## 是否正在冲刺
var is_dashing: bool = false

## 是否已显示能量不足提示（防止重复弹出）
var has_shown_no_energy_hint: bool = false

# ==============================================================================
# 节点引用
# ==============================================================================

## 用于绘制规划路径的Line2D
var line_2d: Line2D

var collision: CollisionShape2D
var dash_hitbox: Node
var trail: Node
var visuals: Node2D

## 跟踪所有生成的效果节点（风墙、暴风区域等）
var spawned_effects: Array[Node] = []

# ==============================================================================
# 生命周期
# ==============================================================================

func _ready() -> void:
	super._ready()
	
	if skill_owner:
		# 创建Line2D用于绘制规划路径
		line_2d = Line2D.new()
		line_2d.name = "WindPlanningLine"
		line_2d.width = 4.0
		skill_owner.add_child(line_2d)
		line_2d.top_level = true
		line_2d.clear_points()
		line_2d.default_color = Color(0.2, 1.5, 1.5, 1.0)  # 高亮青色
		
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
					# 能量不足 - 只弹一次提示
					is_drawing = false
					if not has_shown_no_energy_hint:
						has_shown_no_energy_hint = true
						Global.spawn_floating_text(skill_owner.global_position, "No Energy!", Color.RED)
					break
		else:
			# 鼠标左键松开
			if is_drawing:
				is_drawing = false
		
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
	has_shown_no_energy_hint = false  # 重置能量提示标志
	
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
				print("[SkillWindPath] >>> 检测到线段交叉！线段 %d 和 %d <<<" % [i, j])
				has_closure = true
				return
	
	# 检查距离闭合：终点是否接近起点或路径中的其他点
	if path_points.size() >= 3:
		var last_point = path_points[path_points.size() - 1]
		
		# 检查是否接近起点
		if last_point.distance_to(path_points[0]) < close_threshold:
			print("[SkillWindPath] >>> 检测到距离闭合（接近起点）<<<")
			has_closure = true
			return
		
		# 检查是否接近路径中的其他点（排除最后20个点）
		var check_until = max(0, path_points.size() - 20)
		for i in range(check_until):
			if last_point.distance_to(path_points[i]) < close_threshold:
				print("[SkillWindPath] >>> 检测到距离闭合（接近点 %d）<<<" % i)
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
			print("[SkillWindPath] >>> 实时检测到线段交叉！线段 %d 和最新线段 <<<" % i)
			has_closure = true
			return
	
	# 检查距离闭合：当前点是否接近起点（排除最近的点）
	if path_points.size() >= 20:
		var current_point = path_points[path_points.size() - 1]
		if current_point.distance_to(path_points[0]) < close_threshold:
			print("[SkillWindPath] >>> 实时检测到距离闭合（接近起点）<<<")
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
		line_2d.default_color = Color(2.0, 0.1, 0.1, 1.0)  # 闭合提示（高亮红）
	elif is_planning and skill_owner and skill_owner.energy < _calculate_current_energy_cost():
		line_2d.default_color = Color(0.5, 0.5, 0.5, 0.5)
	elif is_planning and total_distance_drawn > energy_threshold_distance:
		# 超过阈值，颜色渐变提示（青色 -> 深青色）
		var excess_ratio = (total_distance_drawn - energy_threshold_distance) / energy_threshold_distance
		excess_ratio = clamp(excess_ratio, 0.0, 1.0)
		var base_color = Color(0.2, 1.5, 1.5, 1.0)  # 高亮青
		var warning_color = Color(0.1, 0.8, 1.2, 1.0)  # 深青色
		line_2d.default_color = base_color.lerp(warning_color, excess_ratio * 0.5)
	else:
		line_2d.default_color = Color(0.2, 1.5, 1.5, 1.0)  # 正常规划（高亮青）

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
	
	# 生成风墙
	_spawn_wind_wall(previous_pos, skill_owner.global_position)
	
	# 不在这里检查闭合，等到整个路径完成后再一次性检测
	# _check_and_trigger_intersection()
	
	# 继续下一个目标或结束
	current_target_index += 1
	if current_target_index >= path_points.size():
		_end_dash_sequence()

## 结束冲刺序列
func _end_dash_sequence() -> void:
	# 在整个路径完成后，一次性检测所有闭合区域
	_check_and_trigger_intersection()
	
	is_dashing = false
	is_executing = false
	
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
# 风系技能生成
# ==============================================================================

## 生成风墙
func _spawn_wind_wall(start: Vector2, end: Vector2) -> void:
	var area = Area2D.new()
	area.position = start
	area.collision_mask = 2
	area.monitorable = false
	area.monitoring = true
	
	var vec = end - start
	var length = vec.length()
	var angle = vec.angle()
	
	# 碰撞形状（包含效果半径）
	var col = CollisionShape2D.new()
	var shape = RectangleShape2D.new()
	shape.size = Vector2(length, wind_wall_width + wind_wall_effect_radius * 2)
	col.shape = shape
	col.position = Vector2(length / 2.0, 0)
	col.rotation = angle
	area.add_child(col)
	
	# 视觉效果
	var vis_line = Line2D.new()
	vis_line.add_point(Vector2.ZERO)
	vis_line.add_point(end - start)
	vis_line.width = wind_wall_width
	vis_line.default_color = Color(0.2, 1.5, 1.5, 0.8)
	vis_line.begin_cap_mode = Line2D.LINE_CAP_ROUND
	vis_line.end_cap_mode = Line2D.LINE_CAP_ROUND
	area.add_child(vis_line)
	
	get_tree().current_scene.add_child(area)
	
	# 跟踪生成的效果节点
	spawned_effects.append(area)
	
	# 物理Tick（吸附逻辑）
	var timer = Timer.new()
	timer.wait_time = 0.05
	timer.autostart = true
	area.add_child(timer)
	timer.timeout.connect(_on_wind_wall_tick.bind(area, start, end))
	
	# 伤害Tick
	var dmg_timer = Timer.new()
	dmg_timer.wait_time = 0.5
	dmg_timer.autostart = true
	area.add_child(dmg_timer)
	dmg_timer.timeout.connect(_on_damage_tick.bind(area, wind_wall_damage))
	
	# 寿命
	var life = get_tree().create_timer(wind_wall_duration)
	life.timeout.connect(_on_object_expired.bind(area, vis_line))

## 生成暴风区域
func _spawn_storm_zone(points: PackedVector2Array) -> void:
	if points.size() < 3:
		return
	
	print("[SkillWindPath] >>> 触发暴风区域！多边形点数: %d <<<" % points.size())
	
	Global.on_camera_shake.emit(10.0, 0.3)
	
	# 先显示红色遮罩
	_create_wind_closure_mask(points)
	
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
	
	# 跟踪生成的效果节点
	spawned_effects.append(area)
	
	Global.spawn_floating_text(points[0], "STORM!", Color.CYAN)
	
	# 淡入动画
	var tween = area.create_tween()
	tween.tween_property(vis_poly, "color", Color(0.2, 1.2, 1.2, 0.5), 0.2).set_trans(Tween.TRANS_QUAD)
	
	# 计算中心点
	var center = Vector2.ZERO
	for p in points:
		center += p
	center /= points.size()
	
	# 物理Tick（吸向中心）
	var timer = Timer.new()
	timer.wait_time = 0.05
	timer.autostart = true
	area.add_child(timer)
	timer.timeout.connect(_on_storm_zone_tick.bind(area, center))
	
	# 伤害Tick
	var dmg_timer = Timer.new()
	dmg_timer.wait_time = 0.5
	dmg_timer.autostart = true
	area.add_child(dmg_timer)
	dmg_timer.timeout.connect(_on_damage_tick.bind(area, storm_zone_damage))
	
	# 寿命
	var life = get_tree().create_timer(storm_zone_duration)
	life.timeout.connect(_on_object_expired.bind(area, vis_poly))
	
	# 画圈奖励
	await get_tree().process_frame
	_apply_circle_rewards(area, points)

## 创建风暴闭合遮罩 - 使用公共工具类
func _create_wind_closure_mask(points: PackedVector2Array) -> void:
	var polygons: Array[PackedVector2Array] = [points]
	PolygonUtils.show_closure_masks(polygons, Color(0.3, 0.8, 1.0, 0.7), get_tree(), 0.6)

# ==============================================================================
# 闭环检测
# ==============================================================================

## 查找所有闭合多边形（支持8字形等多区域）- 使用公共工具类
func _find_all_closing_polygons() -> Array[PackedVector2Array]:
	return PolygonUtils.find_all_closing_polygons(path_history, close_threshold)

## 查找闭合多边形（保留兼容性）
func _find_closing_polygon(points: Array[Vector2]) -> PackedVector2Array:
	var polygons = PolygonUtils.find_all_closing_polygons(points, close_threshold)
	if polygons.size() > 0:
		return polygons[0]
	return PackedVector2Array()

## 检查并触发闭合（支持多区域）
func _check_and_trigger_intersection() -> void:
	# 直接检测所有闭合区域，不依赖 has_closure 标志
	var polygons = _find_all_closing_polygons()
	if polygons.size() > 0:
		print("[SkillWindPath] >>> 检测到 %d 个闭合区域 <<<" % polygons.size())
		
		# Camera shake（只触发一次）
		Global.on_camera_shake.emit(10.0, 0.3)
		
		# 一次性显示所有遮罩（同步动画）
		PolygonUtils.show_closure_masks(polygons, Color(0.3, 0.8, 1.0, 0.7), get_tree(), 0.6)
		
		# 为每个闭合区域生成风暴区（不再单独显示遮罩）
		for polygon_points in polygons:
			_spawn_storm_zone_no_mask(polygon_points)
		
		# 清空历史，避免重复触发
		if path_history.size() > 0:
			var last = path_history.back()
			path_history.clear()
			path_history.append(last)
		
		# 标记已处理
		has_closure = false

## 生成暴风区域（不显示遮罩，用于多区域同步显示）
func _spawn_storm_zone_no_mask(points: PackedVector2Array) -> void:
	if points.size() < 3:
		return
	
	print("[SkillWindPath] >>> 触发暴风区域！多边形点数: %d <<<" % points.size())
	
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
	
	# 跟踪生成的效果节点
	spawned_effects.append(area)
	
	Global.spawn_floating_text(points[0], "STORM!", Color.CYAN)
	
	# 淡入动画
	var tween = area.create_tween()
	tween.tween_property(vis_poly, "color", Color(0.2, 1.2, 1.2, 0.5), 0.2).set_trans(Tween.TRANS_QUAD)
	
	# 计算中心点
	var center = Vector2.ZERO
	for p in points:
		center += p
	center /= points.size()
	
	# 物理Tick（吸向中心）
	var timer = Timer.new()
	timer.wait_time = 0.05
	timer.autostart = true
	area.add_child(timer)
	timer.timeout.connect(_on_storm_zone_tick.bind(area, center))
	
	# 伤害Tick
	var dmg_timer = Timer.new()
	dmg_timer.wait_time = 0.5
	dmg_timer.autostart = true
	area.add_child(dmg_timer)
	dmg_timer.timeout.connect(_on_damage_tick.bind(area, storm_zone_damage))
	
	# 寿命
	var life = get_tree().create_timer(storm_zone_duration)
	life.timeout.connect(_on_object_expired.bind(area, vis_poly))
	
	# 画圈奖励
	await get_tree().process_frame
	_apply_circle_rewards(area, points)

# ==============================================================================
# 回调函数
# ==============================================================================

## 风墙物理效果：将敌人吸附到线段上
func _on_wind_wall_tick(area_ref: Area2D, start: Vector2, end: Vector2) -> void:
	if not is_instance_valid(area_ref) or area_ref.is_queued_for_deletion():
		return
	
	var targets = area_ref.get_overlapping_bodies() + area_ref.get_overlapping_areas()
	var dt = 0.05
	
	for t in targets:
		var enemy = null
		if t.is_in_group("enemies"):
			enemy = t
		elif t.owner and t.owner.is_in_group("enemies"):
			enemy = t.owner
		
		if is_instance_valid(enemy):
			var closest_point = Geometry2D.get_closest_point_to_segment(enemy.global_position, start, end)
			var dist = enemy.global_position.distance_to(closest_point)
			
			if dist > 5.0:
				var dir = (closest_point - enemy.global_position).normalized()
				enemy.global_position += dir * wind_wall_pull_force * dt

## 暴风区域物理效果：将敌人吸附到中心点
func _on_storm_zone_tick(area_ref: Area2D, center: Vector2) -> void:
	if not is_instance_valid(area_ref) or area_ref.is_queued_for_deletion():
		return
	
	var targets = area_ref.get_overlapping_bodies() + area_ref.get_overlapping_areas()
	var dt = 0.05
	
	for t in targets:
		var enemy = null
		if t.is_in_group("enemies"):
			enemy = t
		elif t.owner and t.owner.is_in_group("enemies"):
			enemy = t.owner
		
		if is_instance_valid(enemy):
			var dir = (center - enemy.global_position).normalized()
			enemy.global_position += dir * storm_zone_pull_force * dt

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
		# 从跟踪列表中移除
		var idx = spawned_effects.find(area_ref)
		if idx >= 0:
			spawned_effects.remove_at(idx)
		
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
	Global.spawn_floating_text(skill_owner.global_position, "TRAPPED x%d" % enemies_in_circle, Color.CYAN)
	
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
	# 清理Line2D
	if is_instance_valid(line_2d):
		line_2d.queue_free()
	
	# 清理所有生成的效果节点（风墙、暴风区域等）
	for effect in spawned_effects:
		if is_instance_valid(effect):
			effect.queue_free()
	spawned_effects.clear()
	
	# 重置状态
	is_planning = false
	is_dashing = false
	is_drawing = false
	has_shown_no_energy_hint = false
	path_points.clear()
	path_segments.clear()
	path_history.clear()
	current_target_index = 0
	has_closure = false
	accumulated_distance = 0.0
	total_distance_drawn = 0.0
	Engine.time_scale = 1.0
