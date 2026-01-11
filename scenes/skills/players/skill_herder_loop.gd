extends SkillBase
class_name SkillHerderLoop

## ==============================================================================
## 牧羊人Q技能 - 画圈几何击杀
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
## - 松开Q：执行冲刺序列
## - 路径闭合时触发几何击杀（秒杀圈内敌人）
## - 根据击杀数量给予不同奖励
## 
## 使用方法:
##   - 按住Q进入规划模式
##   - 按住鼠标左键连续划线
##   - 松开鼠标左键结束划线
##   - 松开Q执行冲刺
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
var energy_scale_multiplier: float = 0.0005

## 冲刺速度（基础值）
var dash_speed: float = 2000.0

## 动态冲刺速度（运行时计算）
var dynamic_dash_speed: float = 2000.0

## 冲刺基础伤害
var dash_base_damage: int = 10

## 击退力度
var dash_knockback: float = 2.0

## 闭合判定阈值
var close_threshold: float = 60.0

## 每隔多少像素记录一个路径点
const POINT_INTERVAL: float = 10.0

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

## 保存的交叉信息（用于查找闭合多边形）
var saved_intersection_i: int = -1  # 交叉线段的起始索引

## 当前冲刺目标索引
var current_target_index: int = 0

## 路径历史（用于闭合检测）
var path_history: Array[Vector2] = []

## 已画的总距离（用于能量递增计算）
var total_distance_drawn: float = 0.0

## 是否正在执行几何击杀
var is_executing_kill: bool = false

## 是否正在冲刺
var is_dashing: bool = false

## 保存的闭合多边形（用于执行阶段）- 支持多个闭合区域
var saved_polygons: Array[PackedVector2Array] = []

## 是否已显示能量不足提示（防止重复提示）
var has_shown_no_energy: bool = false

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
		# 检测鼠标左键按下 - 开始或继续划线
		if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
			if not is_drawing:
				# 开始划线
				is_drawing = true
				has_shown_no_energy = false  # ✅ 开始新的划线时重置能量不足提示标志
			
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
					
					# 检测线段交叉和封闭空间
					_check_intersection_and_closure()
					
					# 更新状态
					last_point = new_point
				else:
					# 能量不足，停止划线
					if not has_shown_no_energy:
						has_shown_no_energy = true
						Global.spawn_floating_text(skill_owner.global_position, "No Energy!", Color.RED)
					is_drawing = false
					break
		else:
			# 鼠标左键松开，结束划线
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
	has_shown_no_energy = false  # ✅ 重置能量不足提示标志
	
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
		print("[SkillHerderLoop] >>> 退出规划模式 <<<")
		print("[SkillHerderLoop] has_closure在退出时: %s" % has_closure)
		
		# ✅ 如果检测到闭合，立即保存所有多边形
		if has_closure:
			saved_polygons = _find_all_closing_polygons(path_points)
			print("[SkillHerderLoop] >>> 保存 %d 个闭合多边形 <<<" % saved_polygons.size())
			for i in range(saved_polygons.size()):
				print("[SkillHerderLoop]   多边形 %d: %d 个点" % [i + 1, saved_polygons[i].size()])
		
		_start_dash_sequence()
	else:
		_clear_all_points()

## 执行最终的闭合检测（松开Q键时调用）
func _perform_final_closure_check() -> void:
	# 不管实时检测结果如何，都重新检查一次
	# 重置标志
	has_closure = false
	saved_intersection_i = -1
	
	if path_segments.size() < 3:
		return
	
	# 检查任意两条不相邻的线段是否相交
	for i in range(path_segments.size()):
		for j in range(i + 2, path_segments.size()):
			var seg1 = path_segments[i]
			var seg2 = path_segments[j]
			
			if _segments_intersect(seg1, seg2):
				print("[SkillHerderLoop] >>> 最终检测到线段交叉！线段 %d 和 %d <<<" % [i, j])
				has_closure = true
				saved_intersection_i = i  # ✅ 保存第一个交叉线段的索引
				return
	
	# 检查距离闭合：终点是否接近起点或路径中的其他点
	if path_points.size() >= 3:
		var last_point = path_points[path_points.size() - 1]
		
		# 检查是否接近起点
		if last_point.distance_to(path_points[0]) < close_threshold:
			print("[SkillHerderLoop] >>> 最终检测到距离闭合（接近起点）<<<")
			has_closure = true
			saved_intersection_i = -1  # 距离闭合，不是线段交叉
			return
		
		# 检查是否接近路径中的其他点（排除最后20个点）
		var check_until = max(0, path_points.size() - 20)
		for i in range(check_until):
			if last_point.distance_to(path_points[i]) < close_threshold:
				print("[SkillHerderLoop] >>> 最终检测到距离闭合（接近点 %d）<<<" % i)
				has_closure = true
				saved_intersection_i = -1  # 距离闭合，不是线段交叉
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
			print("[SkillHerderLoop] >>> 实时检测到线段交叉！线段 %d 和最新线段 <<<" % i)
			has_closure = true
			saved_intersection_i = i  # ✅ 保存交叉线段的索引
			return
	
	# 检查距离闭合：当前点是否接近起点（排除最近的点）
	if path_points.size() >= 20:
		var current_point = path_points[path_points.size() - 1]
		if current_point.distance_to(path_points[0]) < close_threshold:
			print("[SkillHerderLoop] >>> 实时检测到距离闭合（接近起点）<<<")
			has_closure = true
			saved_intersection_i = -1  # 距离闭合，不是线段交叉
			return

## 检测两条线段是否相交
func _segments_intersect(seg1: Dictionary, seg2: Dictionary) -> bool:
	var p1 = seg1["start"]
	var p2 = seg1["end"]
	var p3 = seg2["start"]
	var p4 = seg2["end"]
	
	# 使用Godot内置的线段相交检测
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
	saved_polygons.clear()  # ✅ 清空保存的多边形数组
	saved_intersection_i = -1  # ✅ 清空保存的交叉信息
	
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
	# 1. 基础清理
	if path_points.is_empty() and not is_planning:
		line_2d.clear_points()
		return
	
	line_2d.clear_points()
	
	if not skill_owner:
		return
	
	# 2. 绘制已确认的路径点
	for p in path_points:
		line_2d.add_point(p)
	
	# 3. 如果正在划线，添加到鼠标的预览线
	if is_planning and is_drawing:
		var mouse_pos = skill_owner.get_global_mouse_position()
		line_2d.add_point(mouse_pos)
	
	# 4. 颜色判断：根据封闭状态和能量递增设置颜色
	var final_color = Color.WHITE
	
	# 优先级1：如果已经检测到闭合，保持红色（最高优先级）
	if has_closure:
		final_color = Color(1.0, 0.2, 0.2, 1.0)
	# 优先级2：能量不足，变灰（只在未闭合时）
	elif is_planning and skill_owner and skill_owner.energy < _calculate_current_energy_cost():
		final_color = Color(0.5, 0.5, 0.5, 0.5)
	# 优先级3：超过阈值，颜色渐变提示（只在未闭合且能量足够时）
	elif is_planning and total_distance_drawn > energy_threshold_distance:
		var excess_ratio = (total_distance_drawn - energy_threshold_distance) / energy_threshold_distance
		excess_ratio = clamp(excess_ratio, 0.0, 1.0)
		final_color = Color.WHITE.lerp(Color.ORANGE, excess_ratio * 0.5)
	# 优先级4：正常白色
	else:
		final_color = Color(1.0, 1.0, 1.0, 0.5)
	
	line_2d.default_color = final_color

# ==============================================================================
# 冲刺执行
# ==============================================================================

## 开始冲刺序列
func _start_dash_sequence() -> void:
	if path_points.size() < 2 or not skill_owner:
		return
	
	print("[SkillHerderLoop] ========== 开始冲刺 ==========")
	print("[SkillHerderLoop] has_closure: %s, path_points: %d" % [has_closure, path_points.size()])
	
	# ✅ 计算动态冲刺速度
	_calculate_dynamic_dash_speed()
	
	is_dashing = true
	is_executing = true
	is_executing_kill = false  # 重置几何击杀标志
	current_target_index = 1  # 从第二个点开始（第一个点是起点）
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
	
	# 播放音效（只播放一次）
	Global.play_player_dash()
	
	# 开始冷却
	start_cooldown()

## 计算动态冲刺速度
func _calculate_dynamic_dash_speed() -> void:
	# 计算总路径长度
	var total_path_length = total_distance_drawn
	
	# 基础速度
	var base_speed = dash_speed
	var speed_multiplier = 1.0
	
	# 根据路径长度计算速度倍数
	if total_path_length < 500.0:
		# 短路径：使用基础速度
		speed_multiplier = 1.0
		print("[SkillHerderLoop] 短路径 (%.0f px): 使用基础速度" % total_path_length)
	elif total_path_length < 1000.0:
		# 中等路径：1.2-1.5倍速度
		var ratio = (total_path_length - 500.0) / 500.0  # 0-1
		speed_multiplier = 1.2 + ratio * 0.3  # 1.2-1.5
		print("[SkillHerderLoop] 中等路径 (%.0f px): %.1fx 速度" % [total_path_length, speed_multiplier])
	elif total_path_length < 1500.0:
		# 长路径：1.5-2.0倍速度
		var ratio = (total_path_length - 1000.0) / 500.0  # 0-1
		speed_multiplier = 1.5 + ratio * 0.5  # 1.5-2.0
		print("[SkillHerderLoop] 长路径 (%.0f px): %.1fx 速度" % [total_path_length, speed_multiplier])
	else:
		# 超长路径：2.0-3.0倍速度
		var ratio = min((total_path_length - 1500.0) / 1000.0, 1.0)  # 0-1，最大1
		speed_multiplier = 2.0 + ratio * 1.0  # 2.0-3.0
		print("[SkillHerderLoop] 超长路径 (%.0f px): %.1fx 速度" % [total_path_length, speed_multiplier])
	
	# 应用速度倍数
	dynamic_dash_speed = base_speed * speed_multiplier
	
	# 显示速度提示
	if speed_multiplier > 1.2:
		var speed_text = "SPEED x%.1f" % speed_multiplier
		Global.spawn_floating_text(skill_owner.global_position, speed_text, Color.CYAN)
	
	print("[SkillHerderLoop] 动态冲刺速度: %.0f (基础: %.0f, 倍数: %.1fx)" % [dynamic_dash_speed, base_speed, speed_multiplier])

## 处理冲刺移动
func _process_dashing_movement(delta: float) -> void:
	if not skill_owner or current_target_index >= path_points.size():
		return
	
	# 恢复时间流速
	Engine.time_scale = 1.0
	
	var target = path_points[current_target_index]
	var distance_to_target = skill_owner.position.distance_to(target)
	
	# ✅ 使用动态冲刺速度
	skill_owner.position = skill_owner.position.move_toward(target, dynamic_dash_speed * delta)
	
	# 检查是否到达目标
	if skill_owner.position.distance_to(target) < 5.0:
		_on_reach_target_point()

## 到达目标点
func _on_reach_target_point() -> void:
	if not skill_owner:
		return
	
	path_history.append(skill_owner.global_position)
	
	# 继续下一个目标或结束
	current_target_index += 1
	if current_target_index >= path_points.size():
		_end_dash_sequence()

## 结束冲刺序列
func _end_dash_sequence() -> void:
	print("[SkillHerderLoop] ========== 结束冲刺 ==========")
	print("[SkillHerderLoop] has_closure: %s, path_history: %d" % [has_closure, path_history.size()])
	
	# 冲刺结束后才检查闭合并触发几何击杀
	if has_closure and not is_executing_kill:
		print("[SkillHerderLoop] >>> 开始检查闭合多边形 <<<")
		_check_and_trigger_intersection()
	else:
		if not has_closure:
			print("[SkillHerderLoop] !!! 未检测到闭合，跳过几何击杀 !!!")
		if is_executing_kill:
			print("[SkillHerderLoop] !!! 已在执行击杀，跳过 !!!")
	
	# 不需要等待几何击杀动画 - tween是独立的，不应该阻塞游戏逻辑
	
	is_dashing = false
	is_executing = false
	is_executing_kill = false  # 重置几何击杀标志
	
	# 清理线条和数据
	line_2d.clear_points()
	path_points.clear()
	path_segments.clear()
	path_history.clear()
	current_target_index = 0
	has_closure = false
	saved_polygons.clear()  # ✅ 清空保存的多边形数组
	saved_intersection_i = -1  # ✅ 清空保存的交叉信息
	
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
# 闭环检测与几何击杀
# ==============================================================================

## 查找所有闭合多边形（支持8字形等多个闭合区域）
func _find_all_closing_polygons(points: Array[Vector2]) -> Array[PackedVector2Array]:
	print("[SkillHerderLoop] >>> _find_all_closing_polygons 开始 <<<")
	print("[SkillHerderLoop] 输入点数: %d" % points.size())
	
	var result: Array[PackedVector2Array] = []
	
	if points.size() < 3:
		print("[SkillHerderLoop] !!! 点数不足3，返回空数组 !!!")
		return result
	
	var last_point = points[points.size() - 1]
	var last_segment_start = points[points.size() - 2]
	print("[SkillHerderLoop] 最后一个点: %s" % last_point)
	print("[SkillHerderLoop] 倒数第二个点: %s" % last_segment_start)
	print("[SkillHerderLoop] 起点: %s" % points[0])
	print("[SkillHerderLoop] close_threshold: %.1f" % close_threshold)
	
	# ✅ 新算法：基于连通性的区域分割
	print("[SkillHerderLoop] >>> 使用新的连通性算法 <<<")
	
	# 1. 收集所有交叉点
	var all_intersections: Array[Dictionary] = []
	print("[SkillHerderLoop] 检查所有线段对...")
	for j in range(points.size() - 1, 2, -1):  # 从后往前
		for i in range(j - 2):  # 检查之前的线段（跳过相邻）
			var seg1_start = points[i]
			var seg1_end = points[i + 1]
			var seg2_start = points[j - 1]
			var seg2_end = points[j]
			
			var intersection = Geometry2D.segment_intersects_segment(
				seg1_start, seg1_end, seg2_start, seg2_end
			)
			
			if intersection:
				print("[SkillHerderLoop] ★★★ 找到线段交叉！线段 %d-%d 和 线段 %d-%d ★★★" % [i, i+1, j-1, j])
				print("[SkillHerderLoop] 交点位置: %s" % intersection)
				all_intersections.append({
					"i": i,
					"j": j,
					"point": intersection,
					"seg1_start": i,
					"seg1_end": i + 1,
					"seg2_start": j - 1,
					"seg2_end": j
				})
	
	# 2. 优先检查简单的距离闭合（用户画的完整形状）
	var distance_to_start = last_point.distance_to(points[0])
	if distance_to_start < close_threshold:
		print("[SkillHerderLoop] ★★★ 找到距离闭合（接近起点）！距离: %.1f ★★★" % distance_to_start)
		var poly = PackedVector2Array()
		
		# 返回所有点，形成完整的闭合区域
		for j in range(points.size()):
			poly.append(points[j])
		
		# ✅ 不需要再添加起点，因为已经很接近了
		# 但如果距离大于5像素，添加起点确保闭合
		if distance_to_start > 5.0:
			poly.append(points[0])
			print("[SkillHerderLoop] 添加起点作为结束点以确保多边形闭合")
		
		print("[SkillHerderLoop] 添加多边形（距离闭合），点数: %d" % poly.size())
		result.append(poly)
	# 3. 如果有交叉点但没有距离闭合，使用区域分割算法
	elif all_intersections.size() > 0:
		print("[SkillHerderLoop] 找到 %d 个交叉点，开始区域分割" % all_intersections.size())
		result = _extract_regions_by_connectivity(points, all_intersections)
	else:
		# 4. 检查单个闭合区域（圆形、半圆等）
		print("[SkillHerderLoop] >>> 检查单个闭合区域（无交叉点）<<<")
		result = _extract_single_closure_region(points)
	
	print("[SkillHerderLoop] 总共找到 %d 个闭合多边形" % result.size())
	
	# ✅ 打印所有多边形的详细信息
	for i in range(result.size()):
		var poly = result[i]
		var center = _calculate_polygon_center(poly)
		var area = abs(_calculate_polygon_area(poly))
		print("[SkillHerderLoop] 多边形 %d: 中心=(%.1f, %.1f), 面积=%.1f, 点数=%d" % [i + 1, center.x, center.y, area, poly.size()])
	
	return result

## 基于连通性的区域提取算法（拓扑图方法）
func _extract_regions_by_connectivity(points: Array[Vector2], intersections: Array[Dictionary]) -> Array[PackedVector2Array]:
	print("[SkillHerderLoop] >>> 开始拓扑图区域提取 <<<")
	
	# 构建交叉点图
	var graph = _build_intersection_graph(points, intersections)
	if graph.nodes.size() == 0:
		print("[SkillHerderLoop] !!! 图构建失败，回退到简化算法 !!!")
		return _extract_regions_generic(points, intersections)
	
	# 查找所有最小环路
	var cycles = _find_minimal_cycles(graph)
	print("[SkillHerderLoop] 找到 %d 个环路" % cycles.size())
	
	# 将环路转换为多边形
	var result: Array[PackedVector2Array] = []
	for i in range(cycles.size()):
		var cycle = cycles[i]
		var polygon = _cycle_to_polygon(cycle, graph, points)
		
		if _validate_polygon(polygon):
			result.append(polygon)
			print("[SkillHerderLoop] ✓ 添加有效多边形 %d (点数: %d)" % [i + 1, polygon.size()])
		else:
			print("[SkillHerderLoop] ✗ 跳过无效多边形 %d" % (i + 1))
	
	# 如果拓扑方法失败，回退到简化算法
	if result.size() == 0:
		print("[SkillHerderLoop] !!! 拓扑方法未找到有效区域，回退到简化算法 !!!")
		result = _extract_regions_generic(points, intersections)
	
	print("[SkillHerderLoop] 拓扑提取完成，共 %d 个多边形" % result.size())
	return result

## ✅ 新增：提取单个闭合区域（支持圆形、半圆等无交叉点的形状）
func _extract_single_closure_region(points: Array[Vector2]) -> Array[PackedVector2Array]:
	print("[SkillHerderLoop] >>> 提取单个闭合区域 <<<")
	
	var result: Array[PackedVector2Array] = []
	
	if points.size() < 10:  # 至少需要10个点才能形成有意义的闭合区域
		print("[SkillHerderLoop] !!! 点数不足10，无法形成单个闭合区域 !!!")
		return result
	
	var last_point = points[points.size() - 1]
	var start_point = points[0]
	
	# 检查多种闭合条件
	var is_closed = false
	var closure_type = ""
	var closure_start_idx = 0  # 闭合起始点索引
	
	# 1. 距离闭合：终点接近起点
	var distance_to_start = last_point.distance_to(start_point)
	if distance_to_start < close_threshold:
		is_closed = true
		closure_type = "距离闭合（接近起点）"
		closure_start_idx = 0
	
	# 2. 路径闭合：终点接近路径中的早期点
	if not is_closed:
		var check_range = min(20, points.size() / 4)  # 检查前1/4的点
		for i in range(1, check_range):
			if last_point.distance_to(points[i]) < close_threshold:
				is_closed = true
				closure_type = "距离闭合（接近点%d）" % i
				closure_start_idx = i
				break
	
	# 3. 几何闭合：检查路径是否形成封闭形状（基于面积）
	if not is_closed:
		var poly = PackedVector2Array()
		for p in points:
			poly.append(p)
		poly.append(start_point)  # 强制闭合
		
		var area = abs(_calculate_polygon_area(poly))
		var perimeter = _calculate_polygon_perimeter(poly)
		
		# 使用等周比判断是否为合理的闭合形状
		if area > 200.0 and perimeter > 0:
			var compactness = (4.0 * PI * area) / (perimeter * perimeter)
			if compactness > 0.1:  # 相对紧凑的形状
				is_closed = true
				closure_type = "几何闭合（紧凑度: %.2f）" % compactness
				closure_start_idx = 0
	
	if is_closed:
		print("[SkillHerderLoop] ★★★ 检测到单个闭合区域：%s ★★★" % closure_type)
		
		# ✅ 从闭合起始点开始提取多边形，确保形状正确
		var poly = PackedVector2Array()
		for i in range(closure_start_idx, points.size()):
			poly.append(points[i])
		
		# 确保闭合：添加起始点
		if poly.size() > 0 and poly[poly.size() - 1].distance_to(poly[0]) > 5.0:
			poly.append(poly[0])
		
		var area = abs(_calculate_polygon_area(poly))
		print("[SkillHerderLoop] 单个闭合区域面积: %.1f, 点数: %d" % [area, poly.size()])
		
		if area > 100.0 and poly.size() >= 4:  # 使用相同的面积要求
			result.append(poly)
			print("[SkillHerderLoop] ✅ 添加单个闭合区域（面积: %.1f, 点数: %d）" % [area, poly.size()])
		else:
			print("[SkillHerderLoop] ✗ 单个闭合区域无效: 面积=%.1f, 点数=%d" % [area, poly.size()])
	else:
		print("[SkillHerderLoop] !!! 未检测到单个闭合区域 !!!")
	
	print("[SkillHerderLoop] 单个闭合区域提取完成，共 %d 个区域" % result.size())
	return result

## 计算多边形周长
func _calculate_polygon_perimeter(poly: PackedVector2Array) -> float:
	if poly.size() < 2:
		return 0.0
	
	var perimeter = 0.0
	for i in range(poly.size() - 1):
		perimeter += poly[i].distance_to(poly[i + 1])
	
	return perimeter

## 构建交叉点图（简化版，专注于相邻交叉点连接）
func _build_intersection_graph(points: Array[Vector2], intersections: Array[Dictionary]) -> Dictionary:
	print("[SkillHerderLoop] >>> 构建交叉点图（简化版）<<<")
	
	var graph = {
		"nodes": [],  # Array[Dictionary] - 图节点（交叉点）
		"edges": [],  # Array[Dictionary] - 图边（路径段）
		"adjacency": {}  # Dictionary - 邻接表
	}
	
	if intersections.size() < 2:
		print("[SkillHerderLoop] !!! 交叉点不足2个，无法构建图 !!!")
		return graph
	
	# 1. 创建节点（交叉点）
	var node_id = 0
	for intersection in intersections:
		var pos = intersection["point"]
		var node = {
			"id": node_id,
			"position": pos,
			"intersection_data": intersection
		}
		graph.nodes.append(node)
		graph.adjacency[node_id] = []
		
		print("[SkillHerderLoop] 创建节点 %d: %s [%d,%d]" % [node_id, pos, intersection["i"], intersection["j"]])
		node_id += 1
	
	# 2. ✅ 修复：简化的边创建，确保实际创建边
	var sorted_intersections = intersections.duplicate()
	sorted_intersections.sort_custom(func(a, b): return a["i"] < b["i"])
	
	var edge_id = 0
	# ✅ 连接相邻的交叉点
	for i in range(sorted_intersections.size() - 1):
		var current_node_id = i
		var next_node_id = i + 1
		
		# ✅ 直接创建邻接关系，不依赖复杂的路径段提取
		graph.adjacency[current_node_id].append(next_node_id)
		graph.adjacency[next_node_id].append(current_node_id)
		
		var edge = {
			"id": edge_id,
			"start_node": current_node_id,
			"end_node": next_node_id
		}
		graph.edges.append(edge)
		
		print("[SkillHerderLoop] ✅ 创建边 %d: 节点%d <-> 节点%d" % [edge_id, current_node_id, next_node_id])
		edge_id += 1
	
	# 3. ✅ 如果有3个或更多交叉点，连接首尾形成环
	if intersections.size() >= 3:
		var first_node_id = 0
		var last_node_id = intersections.size() - 1
		
		graph.adjacency[last_node_id].append(first_node_id)
		graph.adjacency[first_node_id].append(last_node_id)
		
		var edge = {
			"id": edge_id,
			"start_node": last_node_id,
			"end_node": first_node_id
		}
		graph.edges.append(edge)
		
		print("[SkillHerderLoop] ✅ 创建闭合边 %d: 节点%d <-> 节点%d" % [edge_id, last_node_id, first_node_id])
		edge_id += 1
	
	print("[SkillHerderLoop] ✅ 图构建完成: %d 个节点, %d 条边" % [graph.nodes.size(), graph.edges.size()])
	
	# ✅ 验证邻接表
	for node_key in graph.adjacency:
		var neighbors = graph.adjacency[node_key]
		print("[SkillHerderLoop] 节点 %d 的邻居: %s" % [node_key, neighbors])
	
	return graph

## 简化的路径段提取
func _extract_path_segment_simple(points: Array[Vector2], intersection1: Dictionary, intersection2: Dictionary) -> Array[Vector2]:
	var segment: Array[Vector2] = []
	
	var start_idx = intersection1["i"]
	var end_idx = intersection2["i"]
	
	# 确保索引顺序正确
	if start_idx > end_idx:
		var temp = start_idx
		start_idx = end_idx
		end_idx = temp
	
	# 提取路径段
	for i in range(start_idx, min(end_idx + 1, points.size())):
		segment.append(points[i])
	
	return segment

## 提取路径段
func _extract_path_segment(points: Array[Vector2], start_point: Vector2, end_point: Vector2) -> Array[Vector2]:
	var segment: Array[Vector2] = []
	
	# 找到起点和终点在路径中的索引
	var start_idx = -1
	var end_idx = -1
	
	for i in range(points.size()):
		if points[i].distance_to(start_point) < 5.0:
			start_idx = i
		if points[i].distance_to(end_point) < 5.0:
			end_idx = i
	
	if start_idx != -1 and end_idx != -1 and start_idx < end_idx:
		for i in range(start_idx, end_idx + 1):
			segment.append(points[i])
	
	return segment

## 查找最小环路
func _find_minimal_cycles(graph: Dictionary) -> Array[Array]:
	print("[SkillHerderLoop] >>> 查找最小环路 <<<")
	
	var cycles: Array[Array] = []
	var visited_edges = {}
	
	# 对每个节点进行DFS查找环路
	for start_node in graph.nodes:
		var node_id = start_node["id"]
		var cycle = _dfs_find_cycle(graph, node_id, node_id, [], visited_edges)
		
		if cycle.size() >= 3:  # 至少3个节点才能形成环路
			cycles.append(cycle)
			print("[SkillHerderLoop] 找到环路: %s" % [cycle])
	
	# 按面积排序，优先处理小环路
	cycles.sort_custom(func(a, b): 
		var area_a = _estimate_cycle_area(a, graph)
		var area_b = _estimate_cycle_area(b, graph)
		return area_a < area_b
	)
	
	print("[SkillHerderLoop] 总共找到 %d 个环路" % cycles.size())
	return cycles

## DFS查找环路
func _dfs_find_cycle(graph: Dictionary, start_node: int, current_node: int, path: Array, visited_edges: Dictionary) -> Array:
	if path.size() > 0 and current_node == start_node:
		# 找到环路
		return path.duplicate()
	
	if path.size() > 10:  # 防止过长的路径
		return []
	
	var neighbors = graph.adjacency.get(current_node, [])
	for neighbor in neighbors:
		var edge_key = str(min(current_node, neighbor)) + "-" + str(max(current_node, neighbor))
		
		if visited_edges.has(edge_key):
			continue
		
		if path.size() > 2 and neighbor == start_node:
			# 找到回到起点的路径
			var new_path = path.duplicate()
			new_path.append(neighbor)
			return new_path
		
		if neighbor not in path:
			visited_edges[edge_key] = true
			var new_path = path.duplicate()
			new_path.append(current_node)
			
			var result = _dfs_find_cycle(graph, start_node, neighbor, new_path, visited_edges)
			if result.size() > 0:
				return result
			
			visited_edges.erase(edge_key)
	
	return []

## 估算环路面积
func _estimate_cycle_area(cycle: Array, graph: Dictionary) -> float:
	if cycle.size() < 3:
		return 0.0
	
	var points: Array[Vector2] = []
	for node_id in cycle:
		if node_id < graph.nodes.size():
			points.append(graph.nodes[node_id]["position"])
	
	return _calculate_polygon_area(PackedVector2Array(points))

## 将环路转换为多边形
func _cycle_to_polygon(cycle: Array, graph: Dictionary, original_points: Array[Vector2]) -> PackedVector2Array:
	var polygon = PackedVector2Array()
	
	if cycle.size() < 3:
		return polygon
	
	# 将环路节点转换为坐标点
	for i in range(cycle.size()):
		var node_id = cycle[i]
		if node_id < graph.nodes.size():
			var node_pos = graph.nodes[node_id]["position"]
			polygon.append(node_pos)
			
			# 添加节点间的路径点
			if i < cycle.size() - 1:
				var next_node_id = cycle[i + 1]
				if next_node_id < graph.nodes.size():
					var next_pos = graph.nodes[next_node_id]["position"]
					var path_segment = _extract_path_segment(original_points, node_pos, next_pos)
					
					# 添加中间点（跳过起点和终点）
					for j in range(1, path_segment.size() - 1):
						polygon.append(path_segment[j])
	
	return polygon

## 通用区域提取算法（稳定版备选方案）- 修复8字形问题
func _extract_regions_generic(points: Array[Vector2], intersections: Array[Dictionary]) -> Array[PackedVector2Array]:
	print("[SkillHerderLoop] >>> 使用稳定版通用区域提取算法（8字形修复版v4）<<<")
	
	var result: Array[PackedVector2Array] = []
	
	if intersections.size() < 2:
		# 只有一个交叉点，使用原来的逻辑
		if intersections.size() == 1:
			var intersection = intersections[0]
			var idx_i = intersection["i"]
			var idx_j = intersection["j"]
			var intersection_point = intersection["point"]
			
			var poly = PackedVector2Array()
			poly.append(intersection_point)
			# 不包含idx_j，因为它在交叉段上
			for k in range(idx_i + 1, idx_j):
				if k < points.size():
					poly.append(points[k])
			# 不需要再添加intersection_point，Polygon2D会自动闭合
			
			var area = abs(_calculate_polygon_area(poly))
			print("[SkillHerderLoop] 单交叉点区域: 点数=%d, 面积=%.1f" % [poly.size(), area])
			if area > 100.0 and poly.size() >= 3:
				result.append(poly)
		return result
	
	# ✅ 8字形修复v4：按i索引排序交叉点
	var sorted_intersections = intersections.duplicate()
	sorted_intersections.sort_custom(func(a, b): return a["i"] < b["i"])
	
	print("[SkillHerderLoop] 排序后的交叉点（按i升序）: %s" % str(sorted_intersections.map(func(x): return "[%d,%d]" % [x["i"], x["j"]])))
	
	# ✅ 对于8字形（2个交叉点），提取两个独立的闭合区域
	# 8字形路径示意（画一个8）：
	#   起点 -> [0...i1] -> 交叉点1 -> [i1+1...i2] -> 交叉点2 -> [i2+1...j2] -> 交叉点2 -> [j2+1...j1] -> 交叉点1 -> [j1+1...终点]
	# 
	# 两个闭合区域：
	# 区域1（上圈）: 交叉点1 -> 路径[i1+1...i2] -> 交叉点2 -> 路径[j2+1...j1] -> 交叉点1
	# 区域2（下圈）: 交叉点2 -> 路径[i2+1...j2] -> 交叉点2
	
	if intersections.size() == 2:
		var int1 = sorted_intersections[0]  # 第一个交叉点（i较小）
		var int2 = sorted_intersections[1]  # 第二个交叉点（i较大）
		
		var i1 = int1["i"]
		var j1 = int1["j"]
		var point1 = int1["point"]
		
		var i2 = int2["i"]
		var j2 = int2["j"]
		var point2 = int2["point"]
		
		print("[SkillHerderLoop] 8字形检测: 交叉点1=[%d,%d], 交叉点2=[%d,%d]" % [i1, j1, i2, j2])
		
		# 检查是否是8字形结构: i1 < i2 < j2 < j1
		if i1 < i2 and i2 < j2 and j2 < j1:
			print("[SkillHerderLoop] ✅ 确认为8字形结构，提取两个独立区域")
			print("[SkillHerderLoop] 路径总点数: %d" % points.size())
			
			# ✅ 区域1（上圈/外圈）: 
			# 交叉点1 -> 路径[i1+1...i2-1] -> 交叉点2 -> 路径[j2+1...j1-1] -> 交叉点1
			# 注意：不包含i2和j1，因为这些点在交叉段上，交叉点已经代表了这个位置
			var poly1 = PackedVector2Array()
			poly1.append(point1)
			print("[SkillHerderLoop] 区域1: 添加交叉点1 %s" % str(point1))
			
			# 从i1+1到i2-1的点（不包含i2，因为i2在交叉段上）
			print("[SkillHerderLoop] 区域1: 添加路径点 [%d...%d]" % [i1 + 1, i2 - 1])
			for k in range(i1 + 1, i2):  # 不包含i2
				if k < points.size():
					poly1.append(points[k])
			
			poly1.append(point2)
			print("[SkillHerderLoop] 区域1: 添加交叉点2 %s" % str(point2))
			
			# 从j2+1到j1-1的点（不包含j1，因为j1在交叉段上）
			print("[SkillHerderLoop] 区域1: 添加路径点 [%d...%d]" % [j2 + 1, j1 - 1])
			for k in range(j2 + 1, j1):  # 不包含j1
				if k < points.size():
					poly1.append(points[k])
			
			# 不需要再添加point1，因为Polygon2D会自动闭合
			# poly1.append(point1)
			
			var area1 = abs(_calculate_polygon_area(poly1))
			print("[SkillHerderLoop] 区域1（上圈）: 点数=%d, 面积=%.1f" % [poly1.size(), area1])
			print("[SkillHerderLoop] 区域1 所有点: %s" % str(poly1))
			
			if area1 > 100.0 and poly1.size() >= 3:
				result.append(poly1)
				print("[SkillHerderLoop] ✓ 添加区域1")
			else:
				print("[SkillHerderLoop] ✗ 区域1面积太小(%.1f)或点数不足，跳过" % area1)
			
			# ✅ 区域2（下圈/内圈）: 交叉点2 -> 路径[i2+1...j2-1] -> 交叉点2
			# 注意：不包含j2，因为j2在交叉段上
			var poly2 = PackedVector2Array()
			poly2.append(point2)
			print("[SkillHerderLoop] 区域2: 添加交叉点2 %s" % str(point2))
			print("[SkillHerderLoop] 区域2: 添加路径点 [%d...%d]" % [i2 + 1, j2 - 1])
			for k in range(i2 + 1, j2):  # 不包含j2
				if k < points.size():
					poly2.append(points[k])
			# 不需要再添加point2，因为Polygon2D会自动闭合
			# poly2.append(point2)
			
			var area2 = abs(_calculate_polygon_area(poly2))
			print("[SkillHerderLoop] 区域2（下圈）: 点数=%d, 面积=%.1f" % [poly2.size(), area2])
			print("[SkillHerderLoop] 区域2 所有点: %s" % str(poly2))
			
			if area2 > 100.0 and poly2.size() >= 3:
				result.append(poly2)
				print("[SkillHerderLoop] ✓ 添加区域2")
			else:
				print("[SkillHerderLoop] ✗ 区域2面积太小(%.1f)或点数不足，跳过" % area2)
		else:
			# 不是标准8字形，可能是其他交叉形状（如两个独立的交叉）
			print("[SkillHerderLoop] ⚠️ 非标准8字形结构 (i1=%d, i2=%d, j2=%d, j1=%d)" % [i1, i2, j2, j1])
			print("[SkillHerderLoop] 尝试为每个交叉点单独创建闭合区域")
			
			# ✅ 为每个交叉点单独创建闭合区域
			for intersection in intersections:
				var idx_i = intersection["i"]
				var idx_j = intersection["j"]
				var intersection_point = intersection["point"]
				
				var poly = PackedVector2Array()
				poly.append(intersection_point)
				# 不包含idx_j，因为它在交叉段上
				for k in range(idx_i + 1, idx_j):
					if k < points.size():
						poly.append(points[k])
				# 不需要再添加intersection_point，Polygon2D会自动闭合
				
				var area = abs(_calculate_polygon_area(poly))
				print("[SkillHerderLoop] 独立区域 [%d,%d]: 点数=%d, 面积=%.1f" % [idx_i, idx_j, poly.size(), area])
				
				if area > 100.0 and poly.size() >= 3:
					# 检查是否与已有区域重叠太多
					var dominated = false
					for existing in result:
						var existing_area = abs(_calculate_polygon_area(existing))
						if area > existing_area * 0.9 and area < existing_area * 1.1:
							dominated = true
							break
					
					if not dominated:
						result.append(poly)
						print("[SkillHerderLoop] ✓ 添加独立区域 [%d,%d]" % [idx_i, idx_j])
	else:
		# 多于2个交叉点，使用更复杂的逻辑
		print("[SkillHerderLoop] 多交叉点(%d个)，使用分段提取" % intersections.size())
		result = _extract_regions_multi_intersection(points, sorted_intersections)
	
	print("[SkillHerderLoop] 稳定版通用提取完成，共 %d 个区域" % result.size())
	return result

## 多交叉点区域提取
func _extract_regions_multi_intersection(points: Array[Vector2], sorted_intersections: Array[Dictionary]) -> Array[PackedVector2Array]:
	var result: Array[PackedVector2Array] = []
	
	print("[SkillHerderLoop] >>> 多交叉点区域提取（简化版v2）<<<")
	print("[SkillHerderLoop] 交叉点数: %d" % sorted_intersections.size())
	
	# 对于多个交叉点，每个交叉点都形成一个独立的闭合区域
	# 但需要避免重叠：使用相邻交叉点来分割区域
	
	for i in range(sorted_intersections.size()):
		var current = sorted_intersections[i]
		var idx_i = current["i"]
		var idx_j = current["j"]
		var point_current = current["point"]
		
		print("[SkillHerderLoop] 处理交叉点 %d: [%d,%d]" % [i + 1, idx_i, idx_j])
		
		var poly = PackedVector2Array()
		poly.append(point_current)
		
		# 查找下一个交叉点（如果存在且在当前范围内）
		var next_intersection: Dictionary = {}
		if i + 1 < sorted_intersections.size():
			var candidate = sorted_intersections[i + 1]
			# 检查下一个交叉点是否在当前交叉点的范围内
			if candidate["i"] > idx_i and candidate["j"] < idx_j:
				next_intersection = candidate
		
		if not next_intersection.is_empty():
			# 有下一个交叉点，提取当前交叉点到下一个交叉点之间的区域
			var next_i = next_intersection["i"]
			var next_j = next_intersection["j"]
			var point_next = next_intersection["point"]
			
			# 区域: current -> 路径[i+1...next_i-1] -> next -> 路径[next_j+1...j-1] -> current
			# 不包含next_i和idx_j，因为它们在交叉段上
			for k in range(idx_i + 1, next_i):
				if k < points.size():
					poly.append(points[k])
			
			poly.append(point_next)
			
			# 从next_j+1到idx_j-1的点
			for k in range(next_j + 1, idx_j):
				if k < points.size():
					poly.append(points[k])
			
			print("[SkillHerderLoop] 区域 %d: 外圈 [%d,%d] -> [%d,%d]" % [i + 1, idx_i, idx_j, next_i, next_j])
		else:
			# 没有下一个交叉点，或者下一个不在范围内，直接提取完整区域
			# 不包含idx_j，因为它在交叉段上
			for k in range(idx_i + 1, idx_j):
				if k < points.size():
					poly.append(points[k])
			
			print("[SkillHerderLoop] 区域 %d: 完整区域 [%d,%d]" % [i + 1, idx_i, idx_j])
		
		# 不需要再添加point_current，Polygon2D会自动闭合
		
		var area = abs(_calculate_polygon_area(poly))
		print("[SkillHerderLoop] 区域 %d: 点数=%d, 面积=%.1f" % [i + 1, poly.size(), area])
		
		if area > 100.0 and poly.size() >= 3:
			result.append(poly)
			print("[SkillHerderLoop] ✓ 添加区域 %d" % (i + 1))
		else:
			print("[SkillHerderLoop] ✗ 跳过区域 %d (面积太小或点数不足)" % (i + 1))
	
	return result



## 移除重叠的区域（改进版）
func _remove_overlapping_regions(regions: Array[PackedVector2Array]) -> Array[PackedVector2Array]:
	print("[SkillHerderLoop] >>> 开始移除重叠区域（改进版）<<<")
	
	var filtered: Array[PackedVector2Array] = []
	
	# 按面积从小到大排序，优先保留小区域
	var sorted_indices: Array[int] = []
	for i in range(regions.size()):
		sorted_indices.append(i)
	
	sorted_indices.sort_custom(func(a, b):
		var area_a = abs(_calculate_polygon_area(regions[a]))
		var area_b = abs(_calculate_polygon_area(regions[b]))
		return area_a < area_b
	)
	
	var used_centers: Array[Vector2] = []
	
	for idx in sorted_indices:
		var region = regions[idx]
		var area = abs(_calculate_polygon_area(region))
		var center = _calculate_polygon_center(region)
		var should_keep = true
		
		# 检查这个区域的中心是否与已添加区域的中心太接近
		for used_center in used_centers:
			var distance = center.distance_to(used_center)
			if distance < 50.0:  # 如果中心点距离小于50像素，认为是重叠
				print("[SkillHerderLoop] 区域 %d 中心与已有区域太接近 (距离: %.1f)，跳过" % [idx + 1, distance])
				should_keep = false
				break
		
		# 检查是否被更大的区域完全包含
		if should_keep:
			for i in range(filtered.size()):
				var other = filtered[i]
				var other_area = abs(_calculate_polygon_area(other))
				
				# 如果当前区域的中心在另一个区域内，且面积差异很大，可能是包含关系
				if Geometry2D.is_point_in_polygon(center, other):
					# 检查面积比例
					var area_ratio = area / other_area if other_area > 0 else 0
					if area_ratio > 0.8:  # 面积相近，可能是同一个区域
						print("[SkillHerderLoop] 区域 %d 与已有区域面积相近且中心重叠，跳过" % (idx + 1))
						should_keep = false
						break
		
		if should_keep:
			filtered.append(region)
			used_centers.append(center)
			print("[SkillHerderLoop] ✓ 保留区域 %d (面积: %.1f, 中心: (%.1f, %.1f))" % [idx + 1, area, center.x, center.y])
		else:
			print("[SkillHerderLoop] ✗ 跳过重复区域 %d" % (idx + 1))
	
	print("[SkillHerderLoop] 过滤后剩余 %d 个区域" % filtered.size())
	return filtered

## 检查两个多边形是否相似（用于去重）
func _polygons_are_similar(poly1: PackedVector2Array, poly2: PackedVector2Array) -> bool:
	if abs(poly1.size() - poly2.size()) > 5:  # 点数差异太大
		return false
	
	var area1 = abs(_calculate_polygon_area(poly1))
	var area2 = abs(_calculate_polygon_area(poly2))
	
	if area1 == 0.0 or area2 == 0.0:
		return false
	
	var area_ratio = area1 / area2
	# 如果面积相似（比例在0.8-1.2之间），认为是重复的
	return area_ratio > 0.8 and area_ratio < 1.2

## 查找闭合多边形（兼容旧接口，返回第一个）
func _find_closing_polygon(points: Array[Vector2]) -> PackedVector2Array:
	var all_polygons = _find_all_closing_polygons(points)
	if all_polygons.size() > 0:
		return all_polygons[0]
	return PackedVector2Array()

## 检查并触发闭合
func _check_and_trigger_intersection() -> void:
	if is_executing_kill:
		return
	
	# ✅ 优先使用保存的多边形数组
	var polygons_to_use: Array[PackedVector2Array] = []
	
	if saved_polygons.size() > 0:
		polygons_to_use = saved_polygons
		print("[SkillHerderLoop] >>> 使用保存的 %d 个多边形 <<<" % polygons_to_use.size())
	else:
		# 如果没有保存的多边形，尝试从path_history查找（兜底）
		print("[SkillHerderLoop] !!! 使用path_history查找多边形（兜底）!!!")
		polygons_to_use = _find_all_closing_polygons(path_history)
	
	if polygons_to_use.size() > 0:
		print("[SkillHerderLoop] ★★★ 找到 %d 个闭合多边形！★★★" % polygons_to_use.size())
		is_executing_kill = true  # 立即设置标志，防止重复触发
		_trigger_geometry_kill_multiple(polygons_to_use)
		# 清空历史和保存的多边形
		path_history.clear()
		saved_polygons.clear()

## 触发多个几何击杀（支持8字形等多闭合区域）
func _trigger_geometry_kill_multiple(polygons: Array[PackedVector2Array]) -> void:
	print("[SkillHerderLoop] >>> 触发 %d 个几何击杀区域！<<<" % polygons.size())
	
	# ✅ 收集所有遮罩节点，用于同步动画
	var mask_nodes: Array[Dictionary] = []
	
	# 为每个多边形创建遮罩和执行伤害
	for i in range(polygons.size()):
		var polygon_points = polygons[i]
		print("[SkillHerderLoop] >>> 处理多边形 %d/%d，点数: %d <<<" % [i + 1, polygons.size(), polygon_points.size()])
		
		# 为每个遮罩设置不同的z-index，确保都能看到
		var z_offset = i * 2
		
		# 创建视觉遮罩
		var mask_result = _create_geometry_mask_visual(polygon_points, z_offset)
		mask_nodes.append(mask_result)
		
		# 执行几何伤害（不触发camera shake，统一在后面触发一次）
		_perform_geometry_damage_no_shake(polygon_points)
	
	# 播放音效和camera shake（只执行一次）
	Global.play_loop_kill_impact()
	Global.on_camera_shake.emit(20.0, 0.5)
	
	# ✅ 同步动画所有遮罩
	_animate_masks_sync(mask_nodes)

## 执行几何伤害（不触发camera shake，用于多区域情况）
func _perform_geometry_damage_no_shake(polygon_points: PackedVector2Array) -> void:
	var enemies = get_tree().get_nodes_in_group("enemies")
	
	for enemy in enemies:
		if not is_instance_valid(enemy):
			continue
		
		var enemy_pos = enemy.global_position
		var is_inside = Geometry2D.is_point_in_polygon(enemy_pos, polygon_points)
		
		if not is_inside:
			continue
		
		# 检查免疫类型
		var type_val = enemy.get("enemy_type")
		if type_val != null and type_val == 3:
			Global.spawn_floating_text(enemy.global_position, "IMMUNE!", Color.GRAY)
			continue
		
		# 击杀敌人
		if enemy.has_method("destroy_enemy"):
			enemy.destroy_enemy()

## 同步动画多个遮罩（同时显示，同时消失）
func _animate_masks_sync(mask_nodes: Array[Dictionary]) -> void:
	if mask_nodes.is_empty():
		return
	
	print("[SkillHerderLoop] >>> 同步动画 %d 个遮罩 <<<" % mask_nodes.size())
	
	# 创建一个主tween来控制所有遮罩
	var tween = get_tree().create_tween()
	tween.set_parallel(true)  # 并行执行
	
	# ✅ 淡入：所有遮罩同时从0到0.8（0.15秒）
	for mask_data in mask_nodes:
		var mask_node = mask_data["node"]
		if is_instance_valid(mask_node):
			tween.tween_property(mask_node, "color:a", 0.8, 0.15).from(0.0)
	
	# 切换到串行模式执行后续动画
	tween.set_parallel(false)
	
	# ✅ 闪光效果
	tween.tween_callback(func():
		for mask_data in mask_nodes:
			var mask_node = mask_data["node"]
			if is_instance_valid(mask_node):
				mask_node.color = Color(2, 2, 2, 1)
	)
	
	# 保持闪光0.08秒
	tween.tween_interval(0.08)
	
	# ✅ 恢复到原始颜色
	tween.set_parallel(true)
	for mask_data in mask_nodes:
		var mask_node = mask_data["node"]
		var design_color = mask_data["design_color"]
		if is_instance_valid(mask_node):
			var original_color = design_color
			original_color.a = 0.8
			tween.tween_property(mask_node, "color", original_color, 0.05)
	
	tween.set_parallel(false)
	
	# ✅ 保持显示0.6秒（缩短显示时间）
	tween.tween_interval(0.6)
	
	# ✅ 淡出：所有遮罩同时消失（0.2秒）
	tween.set_parallel(true)
	for mask_data in mask_nodes:
		var mask_node = mask_data["node"]
		if is_instance_valid(mask_node):
			tween.tween_property(mask_node, "color:a", 0.0, 0.2)
	
	tween.set_parallel(false)
	
	# ✅ 清理所有遮罩
	tween.tween_callback(func():
		for mask_data in mask_nodes:
			var mask_node = mask_data["node"]
			if is_instance_valid(mask_node):
				mask_node.queue_free()
	)

## 触发单个几何击杀（保留用于单区域情况）
func _trigger_geometry_kill_single(polygon_points: PackedVector2Array, z_offset: int = 0) -> void:
	print("[SkillHerderLoop] >>> 触发单个几何击杀！多边形点数: %d, z_offset: %d <<<" % [polygon_points.size(), z_offset])
	print("[SkillHerderLoop] 多边形前3个点: %s" % [polygon_points.slice(0, min(3, polygon_points.size()))])
	
	# 创建视觉遮罩
	var mask_result = _create_geometry_mask_visual(polygon_points, z_offset)
	var mask_node = mask_result["node"]
	var design_color = mask_result["design_color"]
	
	# 播放音效
	Global.play_loop_kill_impact()
	
	# 立即执行几何伤害
	_perform_geometry_damage(polygon_points)
	
	# 创建tween动画
	var tween = get_tree().create_tween()
	tween.set_parallel(false)
	
	# 淡入：0.15秒从0到0.8
	tween.tween_property(mask_node, "color:a", 0.8, 0.15).from(0.0)
	
	# 使用保存的设计颜色
	var original_color = design_color
	original_color.a = 0.8
	
	# 闪光
	tween.tween_callback(func(): 
		if is_instance_valid(mask_node):
			mask_node.color = Color(2, 2, 2, 1)
	)
	
	# 保持闪光0.08秒
	tween.tween_interval(0.08)
	
	# 恢复到原始颜色
	tween.tween_property(mask_node, "color", original_color, 0.05)
	
	# ✅ 保持显示0.6秒（缩短显示时间）
	tween.tween_interval(0.6)
	
	# 淡出：0.2秒
	tween.tween_property(mask_node, "color:a", 0.0, 0.2)
	
	# 清理
	tween.tween_callback(func():
		if is_instance_valid(mask_node):
			mask_node.queue_free()
	)

## 几何击杀闪光
func _on_geometry_kill_flash(mask_node: Polygon2D) -> void:
	if is_instance_valid(mask_node):
		mask_node.color = Color(2, 2, 2, 1)

## 几何击杀完成
func _on_geometry_kill_complete(mask_node: Polygon2D) -> void:
	if is_instance_valid(mask_node):
		mask_node.queue_free()

## 执行几何伤害
func _perform_geometry_damage(polygon_points: PackedVector2Array) -> void:
	print("[SkillHerderLoop] >>> 执行几何伤害 <<<")
	print("[SkillHerderLoop] 多边形点数: %d" % polygon_points.size())
	
	Global.on_camera_shake.emit(20.0, 0.5)
	
	var enemies = get_tree().get_nodes_in_group("enemies")
	print("[SkillHerderLoop] 场景中敌人总数: %d" % enemies.size())
	
	var kill_count = 0
	var checked_count = 0
	var in_polygon_count = 0
	
	for enemy in enemies:
		if not is_instance_valid(enemy):
			continue
		
		checked_count += 1
		
		var enemy_pos = enemy.global_position
		var is_inside = Geometry2D.is_point_in_polygon(enemy_pos, polygon_points)
		
		if not is_inside:
			continue
		
		in_polygon_count += 1
		print("[SkillHerderLoop] 敌人在多边形内: %s, 位置: %s" % [enemy.name, enemy_pos])
		
		# 检查免疫类型
		var type_val = enemy.get("enemy_type")
		if type_val != null and type_val == 3:
			Global.spawn_floating_text(enemy.global_position, "IMMUNE!", Color.GRAY)
			print("[SkillHerderLoop] 敌人免疫: %s" % enemy.name)
			continue
		
		# 击杀敌人
		if enemy.has_method("destroy_enemy"):
			print("[SkillHerderLoop] 击杀敌人: %s" % enemy.name)
			enemy.destroy_enemy()
			kill_count += 1
		else:
			print("[SkillHerderLoop] !!! 敌人没有destroy_enemy方法: %s" % enemy.name)
	
	print("[SkillHerderLoop] 检查了 %d 个敌人, 多边形内 %d 个, 击杀 %d 个" % [checked_count, in_polygon_count, kill_count])
	
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
		var energy_refund = energy_cost * 0.8 * path_history.size()
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
		var energy_refund = energy_cost * 0.5 * path_history.size()
		if energy_refund > 0 and skill_owner.has_method("gain_energy"):
			skill_owner.gain_energy(energy_refund)
		Global.spawn_floating_text(skill_owner.global_position, "PERFECT!", Color(1.0, 1.0, 0.0))
		Global.on_camera_shake.emit(10.0, 0.2)

## 创建几何遮罩视觉效果
func _create_geometry_mask_visual(points: PackedVector2Array, z_offset: int = 0) -> Dictionary:
	print("[SkillHerderLoop] >>> 创建几何遮罩，点数: %d, z_offset: %d <<<" % [points.size(), z_offset])
	print("[SkillHerderLoop] 多边形范围检查:")
	
	# 计算多边形的边界框
	if points.size() > 0:
		var min_x = points[0].x
		var max_x = points[0].x
		var min_y = points[0].y
		var max_y = points[0].y
		
		for p in points:
			min_x = min(min_x, p.x)
			max_x = max(max_x, p.x)
			min_y = min(min_y, p.y)
			max_y = max(max_y, p.y)
		
		print("[SkillHerderLoop] X范围: %.1f 到 %.1f (宽度: %.1f)" % [min_x, max_x, max_x - min_x])
		print("[SkillHerderLoop] Y范围: %.1f 到 %.1f (高度: %.1f)" % [min_y, max_y, max_y - min_y])
		print("[SkillHerderLoop] 中心点: (%.1f, %.1f)" % [(min_x + max_x) / 2, (min_y + max_y) / 2])
		
		# ✅ 打印多边形的前几个点，用于调试重叠问题
		var preview_count = min(5, points.size())
		print("[SkillHerderLoop] 遮罩%d 原始多边形前%d个点: %s" % [z_offset, preview_count, points.slice(0, preview_count)])
	
	# ✅ 确保多边形点顺序正确（逆时针方向）
	var processed_points = _ensure_ccw_winding(points)
	
	# ✅ 打印处理后的前几个点
	if processed_points.size() > 0:
		var preview_count2 = min(5, processed_points.size())
		print("[SkillHerderLoop] 遮罩%d CCW处理后前%d个点: %s" % [z_offset, preview_count2, processed_points.slice(0, preview_count2)])
	
	# ✅ 简化多边形，移除过于接近的点，避免渲染问题
	processed_points = _simplify_polygon(processed_points)
	
	print("[SkillHerderLoop] 处理后多边形点数: %d" % processed_points.size())
	
	# ✅ 验证多边形有效性
	if not _validate_polygon(processed_points):
		print("[SkillHerderLoop] ⚠️ 遮罩%d 多边形验证失败，尝试使用原始点" % z_offset)
		# 尝试直接使用原始点（移除首尾重复）
		processed_points = PackedVector2Array()
		for i in range(points.size()):
			if i == points.size() - 1 and points.size() > 1:
				if points[0].distance_to(points[i]) < 5.0:
					continue  # 跳过与首点重复的尾点
			processed_points.append(points[i])
		print("[SkillHerderLoop] 使用原始点（移除首尾重复）: %d 个点" % processed_points.size())
	
	var poly_node = Polygon2D.new()
	poly_node.polygon = processed_points
	
	# ✅ 为不同的遮罩使用明显不同的颜色，便于区分
	var mask_color = geometry_mask_color
	if z_offset > 0:
		# 使用更明显的颜色差异
		match z_offset:
			2:
				mask_color = Color(0.0, 0.8, 1.0, 0.7)  # 明亮蓝色
			4:
				mask_color = Color(1.0, 0.8, 0.0, 0.7)  # 明亮黄色
			6:
				mask_color = Color(0.8, 0.0, 1.0, 0.7)  # 明亮紫色
			8:
				mask_color = Color(0.0, 1.0, 0.4, 0.7)  # 明亮绿色
			_:
				mask_color = Color(1.0, 0.4, 0.8, 0.7)  # 明亮粉色
	
	print("[SkillHerderLoop] 遮罩%d 分配的颜色: %s" % [z_offset, mask_color])
	
	poly_node.color = mask_color
	
	# ✅ 保存设计时的颜色（包含正确的alpha），然后设置初始透明
	var design_color = mask_color  # 保存设计时的完整颜色
	poly_node.color.a = 0.0  # 设置初始透明
	
	print("[SkillHerderLoop] 遮罩%d 设置后的颜色: %s" % [z_offset, poly_node.color])
	print("[SkillHerderLoop] 遮罩%d 保存的设计颜色: %s" % [z_offset, design_color])
	
	# ✅ 确保每个遮罩有足够大的z-index差异
	poly_node.z_index = 1000 + z_offset * 50  # 增加到50的间隔
	poly_node.top_level = true  # ✅ 使用全局坐标，不受父节点影响
	
	# ✅ 使用更明显的命名
	poly_node.name = "GeometryMask_%d" % z_offset
	
	# ✅ 添加到场景根节点，确保可见性
	var scene_root = get_tree().current_scene
	scene_root.add_child(poly_node)
	
	print("[SkillHerderLoop] 遮罩节点已添加到场景: %s" % scene_root.name)
	print("[SkillHerderLoop] 遮罩颜色: %s" % mask_color)
	print("[SkillHerderLoop] 遮罩z_index: %d" % poly_node.z_index)
	print("[SkillHerderLoop] 遮罩初始alpha: %.2f" % poly_node.color.a)
	print("[SkillHerderLoop] 遮罩top_level: %s" % poly_node.top_level)
	print("[SkillHerderLoop] 遮罩visible: %s" % poly_node.visible)
	print("[SkillHerderLoop] 遮罩名称: %s" % poly_node.name)
	
	# ✅ 统计当前场景中的遮罩数量
	var mask_count = 0
	for child in scene_root.get_children():
		if child.name.begins_with("GeometryMask_"):
			mask_count += 1
	print("[SkillHerderLoop] 当前场景中遮罩总数: %d" % mask_count)
	
	return {
		"node": poly_node,
		"design_color": design_color
	}

## ✅ 确保多边形点为逆时针方向（Godot Polygon2D需要）
func _ensure_ccw_winding(points: PackedVector2Array) -> PackedVector2Array:
	if points.size() < 3:
		return points
	
	# ✅ 首先移除首尾重复点（闭合多边形的特征）
	var working_points = PackedVector2Array()
	for p in points:
		working_points.append(p)
	
	# 检查首尾是否重复
	if working_points.size() > 1:
		var first = working_points[0]
		var last = working_points[working_points.size() - 1]
		if first.distance_to(last) < 5.0:  # 如果首尾点很接近
			# 移除最后一个点
			var temp = PackedVector2Array()
			for i in range(working_points.size() - 1):
				temp.append(working_points[i])
			working_points = temp
			print("[SkillHerderLoop] 移除首尾重复点，剩余 %d 个点" % working_points.size())
	
	if working_points.size() < 3:
		return points
	
	# 计算有符号面积，判断方向
	var signed_area = 0.0
	var n = working_points.size()
	for i in range(n):
		var j = (i + 1) % n
		signed_area += (working_points[j].x - working_points[i].x) * (working_points[j].y + working_points[i].y)
	
	print("[SkillHerderLoop] 多边形有符号面积: %.2f (正=顺时针, 负=逆时针)" % signed_area)
	
	# 如果面积为正，说明是顺时针，需要反转
	if signed_area > 0:
		print("[SkillHerderLoop] 多边形为顺时针，反转为逆时针")
		var reversed_points = PackedVector2Array()
		for i in range(working_points.size() - 1, -1, -1):
			reversed_points.append(working_points[i])
		return reversed_points
	
	return working_points

## ✅ 简化多边形，移除过于接近的点
func _simplify_polygon(points: PackedVector2Array) -> PackedVector2Array:
	if points.size() < 4:
		return points
	
	var simplified = PackedVector2Array()
	var min_distance = 3.0  # 最小点间距
	
	simplified.append(points[0])
	
	for i in range(1, points.size()):
		var last_point = simplified[simplified.size() - 1]
		if points[i].distance_to(last_point) >= min_distance:
			simplified.append(points[i])
	
	# 确保最后一个点不与第一个点重复
	if simplified.size() > 1:
		var first = simplified[0]
		var last = simplified[simplified.size() - 1]
		if first.distance_to(last) < min_distance:
			# 移除最后一个点
			var temp = PackedVector2Array()
			for i in range(simplified.size() - 1):
				temp.append(simplified[i])
			simplified = temp
	
	print("[SkillHerderLoop] 简化多边形: %d -> %d 个点" % [points.size(), simplified.size()])
	
	# ✅ 验证简化后的多边形是否有效
	if simplified.size() >= 3:
		var area = abs(_calculate_polygon_area(simplified))
		print("[SkillHerderLoop] 简化后多边形面积: %.1f" % area)
		if area < 10.0:
			print("[SkillHerderLoop] ⚠️ 警告：简化后多边形面积过小，可能是退化多边形")
			# 打印所有点用于调试
			print("[SkillHerderLoop] 简化后所有点: %s" % str(simplified))
	
	return simplified

## ✅ 验证多边形是否有效（非退化）
func _validate_polygon(points: PackedVector2Array) -> bool:
	if points.size() < 3:
		print("[SkillHerderLoop] 多边形无效：点数不足 (%d)" % points.size())
		return false
	
	# 检查是否有重复点（除了首尾）
	for i in range(points.size()):
		for j in range(i + 2, points.size()):
			if i == 0 and j == points.size() - 1:
				continue  # 跳过首尾点比较
			if points[i].distance_to(points[j]) < 2.0:
				print("[SkillHerderLoop] 多边形无效：点 %d 和点 %d 重复" % [i, j])
				return false
	
	# 检查面积
	var area = abs(_calculate_polygon_area(points))
	if area < 50.0:
		print("[SkillHerderLoop] 多边形无效：面积过小 (%.1f)" % area)
		return false
	
	return true

# ==============================================================================
# 辅助方法
# ==============================================================================

## 计算多边形面积（使用Shoelace公式，改进版）
func _calculate_polygon_area(poly: PackedVector2Array) -> float:
	if poly.size() < 3:
		return 0.0
	
	var area = 0.0
	var n = poly.size()
	
	# 使用改进的Shoelace公式
	for i in range(n):
		var j = (i + 1) % n
		area += (poly[i].x * poly[j].y) - (poly[j].x * poly[i].y)
	
	area = abs(area) / 2.0
	
	# 如果面积仍然为0，尝试计算边界框面积作为备选
	if area < 0.1 and poly.size() >= 3:
		var min_x = poly[0].x
		var max_x = poly[0].x
		var min_y = poly[0].y
		var max_y = poly[0].y
		
		for p in poly:
			min_x = min(min_x, p.x)
			max_x = max(max_x, p.x)
			min_y = min(min_y, p.y)
			max_y = max(max_y, p.y)
		
		var bbox_area = (max_x - min_x) * (max_y - min_y)
		if bbox_area > area:
			area = bbox_area * 0.5  # 使用边界框面积的一半作为估算
	
	return area

## 计算多边形中心点（质心）
func _calculate_polygon_center(poly: PackedVector2Array) -> Vector2:
	if poly.size() == 0:
		return Vector2.ZERO
	
	var center = Vector2.ZERO
	for p in poly:
		center += p
	
	return center / poly.size()

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
	is_drawing = false
	is_executing_kill = false
	path_points.clear()
	path_segments.clear()
	path_history.clear()
	current_target_index = 0
	has_closure = false
	accumulated_distance = 0.0
	total_distance_drawn = 0.0
	dynamic_dash_speed = dash_speed  # ✅ 重置动态速度
	Engine.time_scale = 1.0

## 打印调试信息
func print_debug_info() -> void:
	print("[SkillHerderLoop] 调试信息:")
	print("  - is_planning: %s" % is_planning)
	print("  - is_drawing: %s" % is_drawing)
	print("  - is_dashing: %s" % is_dashing)
	print("  - path_points: %d" % path_points.size())
	print("  - path_segments: %d" % path_segments.size())
	print("  - path_history: %d" % path_history.size())
	print("  - has_closure: %s" % has_closure)
	print("  - total_distance_drawn: %.0f" % total_distance_drawn)
	print("  - current_energy_cost: %.2f" % _calculate_current_energy_cost())
	print("  - energy_per_10px: %.1f" % energy_per_10px)
	print("  - energy_threshold_distance: %.0f" % energy_threshold_distance)
	print("  - energy_scale_multiplier: %.4f" % energy_scale_multiplier)
	print("  - dash_speed: %.0f" % dash_speed)
