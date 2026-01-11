extends SkillBase
class_name SkillSawPath

## ==============================================================================
## 屠夫Q技能 - 锯条路径
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
## - 松开Q：发射锯条
## - 闭合状态（线段相交）：捕获并拉扯敌人，钉在终点8秒
## - 非闭合状态：击退敌人，到达终点立即消失
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

## 每隔多少像素记录一个路径点
const POINT_INTERVAL: float = 10.0

## 锯条飞行速度
var saw_fly_speed: float = 1100.0

## 锯条伤害（闭合状态）
var saw_damage_tick: int = 3

## 锯条伤害（非闭合状态）
var saw_damage_open: int = 1

## 链条控制半径（闭合状态）
var chain_radius: float = 250.0

## 锯条最大飞行距离
var saw_max_distance: float = 900.0

## 锯条旋转速度（闭合状态）
var saw_rotation_speed: float = 25.0

## 锯条击退力度（非闭合状态）
var saw_push_force: float = 1000.0

## 闭合判定阈值
var close_threshold: float = 60.0

# ==============================================================================
# 视觉配置
# ==============================================================================

## 规划线条颜色（未闭合）
var planning_color_normal: Color = Color(1.0, 1.0, 1.0, 0.5)

## 规划线条颜色（已闭合）
var planning_color_closed: Color = Color(1.0, 0.0, 0.0, 1.0)

## 锯条颜色
var saw_color: Color = Color(0.8, 0.2, 0.2, 0.8)

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

## 已画的总距离（用于能量递增计算）
var total_distance_drawn: float = 0.0

## 路径是否已闭合（线段相交）
var is_path_closed: bool = false

## 是否已显示能量不足提示（防止重复弹出）
var has_shown_no_energy_hint: bool = false

## 已确认的路径点
var path_points: Array[Vector2] = []

## 路径线段列表（用于交叉检测）
var path_segments: Array[Dictionary] = []

## 当前激活的锯条
var active_saw: Node2D = null

# ==============================================================================
# 节点引用
# ==============================================================================

## 用于绘制规划路径的Line2D
var line_2d: Line2D

# ==============================================================================
# 生命周期
# ==============================================================================

func _ready() -> void:
	super._ready()
	
	# 创建Line2D用于绘制规划路径
	line_2d = Line2D.new()
	line_2d.name = "SawPathLine"
	line_2d.top_level = true
	line_2d.width = 6.0
	line_2d.z_index = 100
	line_2d.global_position = Vector2.ZERO
	
	if skill_owner:
		skill_owner.add_child(line_2d)

func _process(delta: float) -> void:
	super._process(delta)
	
	# 规划模式：起点跟随玩家
	if is_planning and not path_points.is_empty():
		path_points[0] = skill_owner.global_position
	
	# 更新规划路径的视觉效果
	_update_planning_visuals()

# ==============================================================================
# 技能执行
# ==============================================================================

## 蓄力技能（持续按住Q）
func charge(delta: float) -> void:
	# 如果已有激活的锯条，再按Q就手动消失
	if is_instance_valid(active_saw) and not is_planning:
		if active_saw.has_method("manual_dismiss"):
			active_saw.manual_dismiss()
		active_saw = null
		if skill_owner:
			Global.spawn_floating_text(skill_owner.global_position, "Dismissed!", Color.YELLOW)
		return
	
	# 进入规划模式
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
		_launch_saw_construct()

# ==============================================================================
# 规划模式
# ==============================================================================

## 进入规划模式
func _enter_planning_mode() -> void:
	is_planning = true
	is_charging = true
	is_drawing = false
	is_path_closed = false
	has_shown_no_energy_hint = false  # 重置能量提示标志
	accumulated_distance = 0.0
	total_distance_drawn = 0.0
	
	# 子弹时间
	Engine.time_scale = 0.1
	
	# 清空路径
	path_points.clear()
	path_segments.clear()
	line_2d.clear_points()
	
	# 添加起点
	if skill_owner:
		var start_pos = skill_owner.global_position
		path_points.append(start_pos)
		last_point = start_pos

## 检测线段交叉和封闭空间（实时检测，用于视觉反馈）
func _check_intersection_and_closure() -> void:
	# 如果已经检测到闭合，不再重复检测
	if is_path_closed:
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
			# print("[SkillSawPath] >>> 实时检测到线段交叉！线段 %d 和最新线段 <<<" % i)
			is_path_closed = true
			return
	
	# 检查距离闭合：当前点是否接近起点（排除最近的点）
	if path_points.size() >= 20:
		var current_point = path_points[path_points.size() - 1]
		if current_point.distance_to(path_points[0]) < close_threshold:
			# print("[SkillSawPath] >>> 实时检测到距离闭合（接近起点）<<<")
			is_path_closed = true
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
	is_path_closed = false
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

## 发射锯条
func _launch_saw_construct() -> void:
	is_planning = false
	is_charging = false
	
	# 恢复时间流速
	Engine.time_scale = 1.0
	
	# 清空规划线
	line_2d.clear_points()
	
	# 至少需要2个点
	if path_points.size() < 2:
		path_points.clear()
		return
	
	# 在松开Q键时进行最终的闭合检测
	_perform_final_closure_check()
	
	# 清除旧锯条
	if is_instance_valid(active_saw):
		active_saw.queue_free()
		active_saw = null
	
	# print("[SkillSawPath] ========== 发射锯条 ==========")
	# print("[SkillSawPath] is_path_closed: %s" % is_path_closed)
	# print("[SkillSawPath] path_points: %d" % path_points.size())
	# print("[SkillSawPath] path_segments: %d" % path_segments.size())
	
	# 如果是闭合状态，显示红色遮罩
	if is_path_closed and path_points.size() >= 3:
		# print("[SkillSawPath] >>> 触发闭合锯条！多边形点数: %d <<<" % path_points.size())
		var polygon = PackedVector2Array()
		for p in path_points:
			polygon.append(p)
		_create_butcher_closure_mask(polygon)
	# else:
		# print("[SkillSawPath] !!! 未闭合，发射开放锯条 !!!")
	
	# ✅ 计算飞行方向：从玩家位置指向路径中心
	var player_pos = skill_owner.global_position if skill_owner else path_points[0]
	
	# 计算路径的中心点
	var path_center = Vector2.ZERO
	for p in path_points:
		path_center += p
	path_center /= path_points.size()
	
	# 飞行方向：从玩家指向路径中心
	var fly_dir = (path_center - player_pos).normalized()
	
	# 如果路径中心和玩家位置太近，使用路径的整体方向
	if player_pos.distance_to(path_center) < 50.0:
		fly_dir = (path_points[path_points.size() - 1] - path_points[0]).normalized()
	
	# print("[SkillSawPath] 玩家位置: %s" % player_pos)
	# print("[SkillSawPath] 路径中心: %s" % path_center)
	# print("[SkillSawPath] 飞行方向: %s" % fly_dir)
	
	# 创建锯条投射物
	var saw = SawProjectile.new()
	saw.name = "Saw_" + str(Time.get_ticks_msec())
	
	# 添加到场景树
	if skill_owner:
		skill_owner.get_parent().add_child(saw)
		saw.global_position = skill_owner.global_position
		saw.setup(path_points, is_path_closed, fly_dir, skill_owner)
	
	active_saw = saw
	
	# 相机震动
	Global.on_camera_shake.emit(5.0, 0.2)
	
	# 清空路径
	path_points.clear()
	is_path_closed = false
	
	# 开始冷却
	start_cooldown()

## 执行最终的闭合检测（松开Q键时调用）
func _perform_final_closure_check() -> void:
	# 不管实时检测结果如何，都重新检查一次
	# 重置标志
	is_path_closed = false
	
	if path_segments.size() < 3:
		return
	
	# 检查任意两条不相邻的线段是否相交
	for i in range(path_segments.size()):
		for j in range(i + 2, path_segments.size()):
			var seg1 = path_segments[i]
			var seg2 = path_segments[j]
			
			if _segments_intersect(seg1, seg2):
				# print("[SkillSawPath] >>> 检测到线段交叉！线段 %d 和 %d <<<" % [i, j])
				is_path_closed = true
				return
	
	# 检查距离闭合：终点是否接近起点或路径中的其他点
	if path_points.size() >= 3:
		var last_point = path_points[path_points.size() - 1]
		
		# 检查是否接近起点
		if last_point.distance_to(path_points[0]) < close_threshold:
			# print("[SkillSawPath] >>> 检测到距离闭合（接近起点）<<<")
			is_path_closed = true
			return
		
		# 检查是否接近路径中的其他点（排除最后20个点）
		var check_until = max(0, path_points.size() - 20)
		for i in range(check_until):
			if last_point.distance_to(path_points[i]) < close_threshold:
				# print("[SkillSawPath] >>> 检测到距离闭合（接近点 %d）<<<" % i)
				is_path_closed = true
				return

## 更新规划路径的视觉效果
func _update_planning_visuals() -> void:
	if not is_planning:
		if line_2d:
			line_2d.clear_points()
		return
	
	line_2d.global_position = Vector2.ZERO
	line_2d.clear_points()
	
	if path_points.is_empty():
		return
	
	# 绘制已确认的点
	for p in path_points:
		line_2d.add_point(p)
	
	# 如果正在划线，添加到鼠标的预览线
	if is_drawing and skill_owner:
		var mouse_pos = skill_owner.get_global_mouse_position()
		line_2d.add_point(mouse_pos)
	
	# 颜色判断：根据封闭状态和能量递增设置颜色
	var final_color = Color.WHITE
	
	# 优先级1：如果已经检测到闭合，保持红色（最高优先级）
	if is_path_closed:
		final_color = planning_color_closed
		line_2d.width = 8.0
	# 优先级2：能量不足，变灰（只在未闭合时）
	elif is_planning and skill_owner and skill_owner.energy < _calculate_current_energy_cost():
		final_color = Color(0.5, 0.5, 0.5, 0.5)
		line_2d.width = 6.0
	# 优先级3：超过阈值，颜色渐变提示（只在未闭合且能量足够时）
	elif is_planning and total_distance_drawn > energy_threshold_distance:
		var excess_ratio = (total_distance_drawn - energy_threshold_distance) / energy_threshold_distance
		excess_ratio = clamp(excess_ratio, 0.0, 1.0)
		final_color = Color.WHITE.lerp(Color.ORANGE, excess_ratio * 0.5)
		line_2d.width = 6.0
	# 优先级4：正常白色
	else:
		final_color = planning_color_normal
		line_2d.width = 6.0
	
	line_2d.default_color = final_color

# ==============================================================================
# 辅助方法
# ==============================================================================

## 检查玩家是否可以移动
func can_move() -> bool:
	return not is_planning

## 创建屠夫闭合遮罩视觉效果 - 使用公共工具类
func _create_butcher_closure_mask(polygon: PackedVector2Array) -> void:
	var polygons: Array[PackedVector2Array] = [polygon]
	PolygonUtils.show_closure_masks(polygons, Color(1.0, 0.0, 0.0, 0.7), get_tree(), 0.6)

## 清理资源
func cleanup() -> void:
	# 清理Line2D
	if is_instance_valid(line_2d):
		line_2d.queue_free()
	
	# 清理激活的锯条
	if is_instance_valid(active_saw):
		active_saw.queue_free()
	
	# 恢复时间流速
	if is_planning:
		Engine.time_scale = 1.0

## 打印调试信息
func print_debug_info() -> void:
	print("[SkillSawPath] 调试信息:")
	print("  - is_planning: %s" % is_planning)
	print("  - is_drawing: %s" % is_drawing)
	print("  - is_path_closed: %s" % is_path_closed)
	print("  - path_points: %d" % path_points.size())
	print("  - path_segments: %d" % path_segments.size())
	print("  - total_distance_drawn: %.0f" % total_distance_drawn)
	print("  - current_energy_cost: %.2f" % _calculate_current_energy_cost())
	print("  - energy_per_10px: %.1f" % energy_per_10px)
	print("  - energy_threshold_distance: %.0f" % energy_threshold_distance)
	print("  - energy_scale_multiplier: %.4f" % energy_scale_multiplier)
	print("  - saw_fly_speed: %.0f" % saw_fly_speed)
