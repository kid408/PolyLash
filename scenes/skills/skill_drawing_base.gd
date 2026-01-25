extends SkillBase
class_name SkillDrawingBase

## ==============================================================================
## 画线技能基类 - 所有画线技能的中间基类
## ==============================================================================
## 
## 功能说明:
## - 统一管理画线技能的能量消耗逻辑（动态递增）
## - 统一管理规划模式、划线检测、闭合检测
## - 子类只需实现具体的视觉效果和执行逻辑
## 
## 使用方法:
##   1. 继承SkillDrawingBase（而不是SkillBase）
##   2. 实现 _spawn_line_effect() 和 _spawn_area_effect()
##   3. 可选：重写 _get_line_color() 自定义线条颜色
## 
## ==============================================================================

# ==============================================================================
# 画线技能通用参数（从CSV加载）
# ==============================================================================

## 每10像素消耗的能量（基础值）
var energy_per_10px: float = 1.0

## 能量递增阈值距离（像素）
var energy_threshold_distance: float = 1800.0

## 能量递增系数
var energy_scale_multiplier: float = 0.0005

## 闭合判定阈值
var close_threshold: float = 60.0

## 每隔多少像素记录一个路径点
const POINT_INTERVAL: float = 10.0

# ==============================================================================
# 画线技能运行时状态
# ==============================================================================

## 是否处于规划模式
var is_planning: bool = false

## 是否正在划线
var is_drawing: bool = false

## 上一个记录的点
var last_point: Vector2 = Vector2.ZERO

## 累计距离（用于判断是否达到10像素）
var accumulated_distance: float = 0.0

## 路径点列表（用于绘制和执行）
var path_points: Array[Vector2] = []

## 路径线段列表（用于交叉检测）
var path_segments: Array[Dictionary] = []

## 是否有封闭空间
var has_closure: bool = false

## 已画的总距离（用于能量递增计算）
var total_distance_drawn: float = 0.0

## 是否已显示能量不足提示（防止重复弹出）
var has_shown_no_energy_hint: bool = false

## 用于绘制规划路径的Line2D
var line_2d: Line2D

# ==============================================================================
# 虚函数接口（子类必须实现）
# ==============================================================================

## 生成线段效果（未闭合状态）
## @param start: 线段起点
## @param end: 线段终点
func _spawn_line_effect(start: Vector2, end: Vector2) -> void:
	push_warning("[SkillDrawingBase] _spawn_line_effect() 未实现: %s" % skill_id)

## 生成区域效果（闭合状态）
## @param polygon: 闭合多边形的点集
func _spawn_area_effect(polygon: PackedVector2Array) -> void:
	push_warning("[SkillDrawingBase] _spawn_area_effect() 未实现: %s" % skill_id)

## 获取规划线条颜色（子类可重写以自定义颜色）
## @return: 线条颜色
func _get_line_color() -> Color:
	# 默认白色，子类可重写
	return Color.WHITE

## 获取闭合提示颜色（子类可重写）
## @return: 闭合时的线条颜色
func _get_closure_color() -> Color:
	# 默认红色
	return Color(2.0, 0.1, 0.1, 1.0)

# ==============================================================================
# 生命周期
# ==============================================================================

func _ready() -> void:
	super._ready()
	
	if skill_owner:
		# 创建Line2D用于绘制规划路径
		line_2d = Line2D.new()
		line_2d.name = "DrawingPlanningLine"
		line_2d.width = 4.0
		
		# 确保Line2D添加到玩家节点
		var player_node = skill_owner
		if skill_owner is Area2D:
			player_node = skill_owner.get_parent()
		if player_node:
			player_node.add_child(line_2d)
		else:
			skill_owner.add_child(line_2d)
		
		line_2d.top_level = true
		line_2d.clear_points()
		line_2d.default_color = _get_line_color()

func _process(delta: float) -> void:
	super._process(delta)
	
	# 强制维持子弹时间
	if is_planning and Engine.time_scale > 0.2:
		Engine.time_scale = 0.1
	
	# 每帧更新视觉效果
	_update_visuals()

# ==============================================================================
# 技能执行（统一接口）
# ==============================================================================

## 蓄力技能（持续按住Q）
func charge(delta: float) -> void:
	if not is_planning:
		_enter_planning_mode()
	
	if is_planning:
		# 检测鼠标左键按下 - 开始或继续划线
		if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
			if not is_drawing:
				_start_drawing()
			
			_continue_drawing()
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
		_exit_planning_mode_and_execute()

# ==============================================================================
# 规划模式管理
# ==============================================================================

## 进入规划模式
func _enter_planning_mode() -> void:
	is_planning = true
	is_charging = true
	is_drawing = false
	accumulated_distance = 0.0
	has_closure = false
	total_distance_drawn = 0.0
	has_shown_no_energy_hint = false
	
	# 清空路径数据
	path_points.clear()
	path_segments.clear()
	
	# 设置起点为鼠标位置
	var start_pos = skill_owner.get_global_mouse_position()
	path_points.append(start_pos)
	last_point = start_pos
	
	Engine.time_scale = 0.1

## 退出规划模式并执行技能
func _exit_planning_mode_and_execute() -> void:
	is_planning = false
	is_charging = false
	is_drawing = false
	Engine.time_scale = 1.0
	
	if path_points.size() > 1:
		# 最终闭合检测
		_perform_final_closure_check()
		
		# 根据闭合状态生成效果
		if has_closure:
			_execute_closed_path()
		else:
			_execute_open_path()
		
		start_cooldown()
		_clear_all_points()
	else:
		_clear_all_points()

## 执行闭合路径
func _execute_closed_path() -> void:
	var polygons = PolygonUtils.find_all_closing_polygons(path_points, close_threshold)
	
	if polygons.size() > 0:
		print("[%s] 检测到 %d 个闭合区域" % [skill_id, polygons.size()])
		
		# 显示闭合遮罩（统一动画）
		var mask_color = _get_closure_color()
		mask_color.a = 0.7
		PolygonUtils.show_closure_masks(polygons, mask_color, get_tree(), 0.6)
		
		# 为每个闭合区域生成效果
		for polygon in polygons:
			_spawn_area_effect(polygon)

## 执行开放路径
func _execute_open_path() -> void:
	print("[%s] 生成开放路径效果，点数: %d" % [skill_id, path_points.size()])
	
	# 沿路径生成线段效果
	for i in range(path_points.size() - 1):
		_spawn_line_effect(path_points[i], path_points[i + 1])

# ==============================================================================
# 划线逻辑
# ==============================================================================

## 开始划线
func _start_drawing() -> void:
	is_drawing = true
	var mouse_pos = skill_owner.get_global_mouse_position()
	
	# 清空之前的路径，重新从鼠标位置开始
	path_points.clear()
	path_segments.clear()
	has_closure = false
	accumulated_distance = 0.0
	total_distance_drawn = 0.0
	
	path_points.append(mouse_pos)
	last_point = mouse_pos
	has_shown_no_energy_hint = false

## 继续划线
func _continue_drawing() -> void:
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
			
			# 沿着方向前进
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
			if not has_shown_no_energy_hint:
				has_shown_no_energy_hint = true
				Global.spawn_floating_text(skill_owner.global_position, "No Energy!", Color.RED)
			break

# ==============================================================================
# 能量消耗计算（核心逻辑）
# ==============================================================================

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

# ==============================================================================
# 闭合检测
# ==============================================================================

## 执行最终的闭合检测（松开Q键时调用）
func _perform_final_closure_check() -> void:
	has_closure = false
	
	if path_segments.size() < 3:
		return
	
	# 检查任意两条不相邻的线段是否相交
	for i in range(path_segments.size()):
		for j in range(i + 2, path_segments.size()):
			var seg1 = path_segments[i]
			var seg2 = path_segments[j]
			
			if _segments_intersect(seg1, seg2):
				has_closure = true
				return
	
	# 检查距离闭合
	if path_points.size() >= 3:
		var last_point_pos = path_points[path_points.size() - 1]
		
		# 检查是否接近起点
		if last_point_pos.distance_to(path_points[0]) < close_threshold:
			has_closure = true
			return
		
		# 检查是否接近路径中的其他点
		var check_until = max(0, path_points.size() - 20)
		for i in range(check_until):
			if last_point_pos.distance_to(path_points[i]) < close_threshold:
				has_closure = true
				return

## 检测线段交叉和封闭空间（实时检测，用于视觉反馈）
func _check_intersection_and_closure() -> void:
	if has_closure:
		return
	
	if path_segments.size() < 3:
		return
	
	# 检查最新线段是否与之前的线段相交
	var latest_seg = path_segments[path_segments.size() - 1]
	
	for i in range(path_segments.size() - 2):
		var old_seg = path_segments[i]
		
		if _segments_intersect(latest_seg, old_seg):
			has_closure = true
			return
	
	# 检查距离闭合
	if path_points.size() >= 20:
		var current_point = path_points[path_points.size() - 1]
		if current_point.distance_to(path_points[0]) < close_threshold:
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

# ==============================================================================
# 路径管理
# ==============================================================================

## 清除所有路径点
func _clear_all_points() -> void:
	# 计算已消耗的总能量
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
	
	# 重置起点为鼠标位置
	if skill_owner:
		var start_pos = skill_owner.get_global_mouse_position()
		path_points.append(start_pos)
		last_point = start_pos

# ==============================================================================
# 视觉效果
# ==============================================================================

## 更新规划路径的视觉效果（每帧调用）
func _update_visuals() -> void:
	if not is_instance_valid(line_2d):
		return
	
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
	
	# 颜色判断
	var final_color = _get_line_color()
	
	if has_closure:
		# 闭合提示
		final_color = _get_closure_color()
	elif is_planning and skill_owner and skill_owner.energy < _calculate_current_energy_cost():
		# 能量不足
		final_color = Color(0.5, 0.5, 0.5, 0.5)
	elif is_planning and total_distance_drawn > energy_threshold_distance:
		# 超过阈值，颜色渐变提示
		var excess_ratio = (total_distance_drawn - energy_threshold_distance) / energy_threshold_distance
		excess_ratio = clamp(excess_ratio, 0.0, 1.0)
		var base_color = _get_line_color()
		var warning_color = Color.ORANGE
		final_color = base_color.lerp(warning_color, excess_ratio * 0.5)
	
	line_2d.default_color = final_color

# ==============================================================================
# 清理
# ==============================================================================

## 清理资源
func cleanup() -> void:
	print("[%s] cleanup() 被调用" % skill_id)
	
	# 清理规划线
	if is_instance_valid(line_2d):
		line_2d.queue_free()
	
	# 重置状态
	is_planning = false
	is_drawing = false
	has_shown_no_energy_hint = false
	path_points.clear()
	path_segments.clear()
	accumulated_distance = 0.0
	total_distance_drawn = 0.0
	has_closure = false
	Engine.time_scale = 1.0
	
	print("[%s] cleanup() 结束" % skill_id)
