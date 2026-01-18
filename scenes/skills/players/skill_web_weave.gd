extends SkillBase
class_name SkillWebWeave

## ==============================================================================
## 织网者Q技能 - 蛛网编织与收割（两阶段）
## ==============================================================================
## 
## 阶段一（编织）：
## - 按住Q进入规划模式（子弹时间）
## - **按住鼠标左键在屏幕上连续划线**
##   - 以玩家坐标为起点
##   - 鼠标移动时实时绘制线段
##   - **每10像素消耗1点能量**
##   - **检测线段交叉**
##   - **如果形成封闭空间，线段变红色**
## - 松开鼠标左键，划线结束
## - 右键：清除所有路径并返还能量
## - 松开Q：部署蛛网，滞留8秒
## - 线段相交形成闭合区域：定身敌人+易伤标记
## 
## 阶段二（收割）：
## - 再次按Q或8秒后自动触发
## - 蛛网收缩回玩家位置
## - 路径上的敌人受到伤害
## - 被困敌人受到处决伤害
## 
## ==============================================================================

# ==============================================================================
# 技能状态枚举
# ==============================================================================
enum SkillState { IDLE, PLANNING, WEAVE, RECALL }

# ==============================================================================
# 技能参数（从CSV加载）
# ==============================================================================

## 每10像素消耗的能量（基础值）
var energy_per_10px: float = 1.0

## 能量递增阈值距离（像素）
var energy_threshold_distance: float = 1800.0

## 能量递增系数
var energy_scale_multiplier: float = 0.0006

## 每隔多少像素记录一个路径点
const POINT_INTERVAL: float = 10.0

## 收网速度
var recall_fly_speed: float = 3.0

## 收网伤害
var recall_damage: int = 40

## 处决倍率（被困敌人）
var recall_execute_mult: float = 3.0

## 自动收网延迟
var auto_recall_delay: float = 8.0

## 闭合判定阈值
var close_threshold: float = 60.0

# ==============================================================================
# 视觉配置
# ==============================================================================

## 蛛网颜色（未闭合）
var web_color_open: Color = Color(0.6, 0.8, 1.0, 0.8)

## 蛛网颜色（已闭合/交叉）
var web_color_crossing: Color = Color(1.0, 0.5, 0.2, 0.9)

## 陷阱填充颜色
var web_color_closed_fill: Color = Color(1.0, 0.2, 0.2, 0.3)

# ==============================================================================
# 运行时状态
# ==============================================================================

## 当前技能状态
var skill_state: SkillState = SkillState.IDLE

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

## 已确认的路径点
var path_points: Array[Vector2] = []

## 路径线段列表（用于交叉检测）
var path_segments: Array[Dictionary] = []

## 是否有封闭空间
var has_closure: bool = false

## 激活的蛛网线条
var active_web_lines: Array[Line2D] = []

## 激活的陷阱多边形
var active_trap_polygons: Array[Polygon2D] = []

## 被困敌人（WeakRef）
var trapped_enemies: Array = []

## 收网对象
var recall_objects: Array = []

## 是否已显示能量不足提示（防止重复弹出）
var has_shown_no_energy_hint: bool = false

## 收网伤害历史
var hit_history: Dictionary = {}

## 当前蛛网计时器
var current_web_timer: float = 0.0

## 自动收网计时器
var auto_recall_timer: Timer = null

# ==============================================================================
# 节点引用
# ==============================================================================

## 用于绘制规划路径的Line2D
var line_2d: Line2D

## 蛛网容器
var web_container: Node2D

# ==============================================================================
# 生命周期
# ==============================================================================

func _ready() -> void:
	super._ready()
	
	# ✅ 创建蛛网容器，添加到场景根节点而不是玩家节点
	# 这样切换角色时，蛛网容器不会被删除
	web_container = Node2D.new()
	web_container.name = "WebContainer"
	web_container.top_level = true
	web_container.global_position = Vector2.ZERO
	
	# 添加到场景根节点
	if skill_owner:
		var scene_root = skill_owner.get_tree().current_scene
		if scene_root:
			scene_root.add_child(web_container)
			print("[SkillWebWeave] web_container 已添加到场景根节点")
		else:
			print("[SkillWebWeave] ⚠️ 警告：无法找到场景根节点")
	
	# 创建Line2D用于绘制规划路径
	line_2d = Line2D.new()
	line_2d.name = "WebPlanningLine"
	line_2d.top_level = true
	line_2d.width = 4.0
	
	if skill_owner:
		# ✅ 修复：确保Line2D添加到玩家节点，而不是skill_owner（可能是Area2D）
		var player_node = skill_owner
		if skill_owner is Area2D:
			player_node = skill_owner.get_parent()
		if player_node:
			player_node.add_child(line_2d)
			print("[SkillWebWeave] Line2D已添加到玩家节点: %s" % player_node.name)
		else:
			print("[SkillWebWeave] ⚠️ 警告：无法找到玩家节点，Line2D添加到skill_owner")
			skill_owner.add_child(line_2d)
	
	# ✅ 创建自动收网计时器，添加到 web_container 而不是技能节点
	# 这样切换角色时，Timer 不会被删除
	auto_recall_timer = Timer.new()
	auto_recall_timer.name = "AutoRecallTimer"
	auto_recall_timer.one_shot = true
	
	# ✅ 使用 lambda 函数连接信号，避免依赖技能节点
	# 捕获必要的引用（不捕获 owner，而是动态查找）
	var container_ref = web_container
	var fly_speed_val = recall_fly_speed
	var damage_val = recall_damage
	var execute_mult_val = recall_execute_mult
	
	auto_recall_timer.timeout.connect(func():
		print("[SkillWebWeave] ★★★ Timer 超时回调被触发 ★★★")
		print("[SkillWebWeave] container_ref 是否有效: %s" % is_instance_valid(container_ref))
		
		if not is_instance_valid(container_ref):
			print("[SkillWebWeave] container 无效，退出")
			return
		
		# ✅ 动态查找当前玩家
		var target: Vector2
		var current_player = container_ref.get_tree().get_first_node_in_group("player")
		if is_instance_valid(current_player):
			target = current_player.global_position
			print("[SkillWebWeave] 找到当前玩家，位置: %s" % target)
		else:
			target = container_ref.global_position
			print("[SkillWebWeave] 未找到玩家，使用 container 位置: %s" % target)
		
		print("[SkillWebWeave] 收网目标位置: %s" % target)
		
		# 计算收网时间
		var recall_time = 1.0 / fly_speed_val
		print("[SkillWebWeave] 收网时间: %.2f秒" % recall_time)
		
		# ✅ 收集线条数据（保存子节点的名称，而不是完整路径）
		var line_data_array = []
		var poly_names = []
		
		for child in container_ref.get_children():
			if child is Line2D and child.name != "WebPlanningLine":
				# 保存子节点名称（相对于 container）
				line_data_array.append({
					"p1": child.points[0],
					"p2": child.points[1],
					"name": NodePath(child.name)  # 转换为 NodePath
				})
			elif child is Polygon2D:
				poly_names.append(NodePath(child.name))  # 转换为 NodePath
		
		print("[SkillWebWeave] 找到 %d 条线，%d 个多边形" % [line_data_array.size(), poly_names.size()])
		
		if line_data_array.is_empty():
			print("[SkillWebWeave] 没有蛛网线条，跳过收网")
			return
		
		# 淡出陷阱多边形
		if not poly_names.is_empty():
			var t = container_ref.create_tween()
			for poly_name in poly_names:
				var poly = container_ref.get_node_or_null(poly_name)
				if is_instance_valid(poly):
					t.parallel().tween_property(poly, "modulate:a", 0.0, 0.3)
			t.tween_callback(func():
				for poly_name in poly_names:
					var poly = container_ref.get_node_or_null(poly_name)
					if is_instance_valid(poly):
						poly.queue_free()
			)
		
		# ✅ 创建伤害检测用的数据结构
		var hit_history_local = {}
		
		# ✅ 为每条线创建 Tween - 使用子节点名称动态查找
		for line_data in line_data_array:
			var line_name = line_data["name"]
			var p1_start = line_data["p1"]
			var p2_start = line_data["p2"]
			
			print("[SkillWebWeave] 处理线条: %s, p1=%s, p2=%s" % [line_name, p1_start, p2_start])
			
			# 创建 Tween
			var tween = container_ref.create_tween()
			tween.set_parallel(false)  # ✅ 改为串行，确保动画按顺序执行
			
			# 创建并行组：点1和点2同时移动，并在移动过程中检测碰撞
			tween.set_parallel(true)
			
			# 动画：点1移动到目标
			tween.tween_method(
				func(val: Vector2):
					var line = container_ref.get_node_or_null(line_name)
					if is_instance_valid(line):
						line.set_point_position(0, val),
				p1_start,
				target,
				recall_time
			)
			
			# 动画：点2移动到目标
			tween.tween_method(
				func(val: Vector2):
					var line = container_ref.get_node_or_null(line_name)
					if is_instance_valid(line):
						line.set_point_position(1, val),
				p2_start,
				target,
				recall_time
			)
			
			# ✅ 添加碰撞检测：使用一个虚拟的进度值来触发碰撞检测
			tween.tween_method(
				func(progress: float):
					# 计算当前线条的两个端点位置
					var curr_p1 = p1_start.lerp(target, progress)
					var curr_p2 = p2_start.lerp(target, progress)
					
					# 检测碰撞
					var enemies = container_ref.get_tree().get_nodes_in_group("enemies")
					for e in enemies:
						if not is_instance_valid(e):
							continue
						if e in hit_history_local:
							continue
						
						var close_p = Geometry2D.get_closest_point_to_segment(e.global_position, curr_p1, curr_p2)
						if e.global_position.distance_to(close_p) < 40.0:
							# 造成伤害
							var dmg = damage_val
							Global.spawn_floating_text(e.global_position, str(dmg), Color.WHITE)
							if e.has_node("HealthComponent"):
								e.health_component.take_damage(dmg)
							hit_history_local[e] = true,
				0.0,
				0.95,  # 只检测到95%的进度
				recall_time
			)
			
			# ✅ 回到串行模式
			tween.set_parallel(false)
			
			# 等待一半时间后开始淡出
			tween.tween_interval(recall_time * 0.5)
			
			# 动画：淡出
			tween.tween_method(
				func(val: float):
					var line = container_ref.get_node_or_null(line_name)
					if is_instance_valid(line):
						line.modulate.a = val,
				1.0,
				0.0,
				recall_time * 0.5
			)
			
			# ✅ 完成后删除 - 这个回调会在所有动画完成后执行
			tween.tween_callback(func():
				var line = container_ref.get_node_or_null(line_name)
				if is_instance_valid(line):
					print("[SkillWebWeave] 删除线条: %s" % line_name)
					line.queue_free()
			)
		
		print("[SkillWebWeave] 收网动画已启动，共 %d 条线" % line_data_array.size())
	)
	
	web_container.add_child(auto_recall_timer)
	print("[SkillWebWeave] 自动收网计时器已创建并添加到 web_container")

func _process(delta: float) -> void:
	super._process(delta)
	
	# 更新规划视觉
	_update_planning_visuals()
	
	# 处理收网物理
	_process_recall_physics(delta)
	
	# 编织阶段：检查是否手动触发收网
	if skill_state == SkillState.WEAVE:
		var manual_trigger = Input.is_action_just_pressed("skill_q")
		
		if manual_trigger:
			_start_recall()

# ==============================================================================
# 技能执行
# ==============================================================================

## 蓄力技能（持续按住Q）
func charge(delta: float) -> void:
	if skill_state == SkillState.RECALL:
		return
	
	if skill_state == SkillState.IDLE and not is_planning:
		_enter_planning_mode()
	
	if is_planning:
		# 检测鼠标左键按下 - 开始或继续划线
		if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
			if not is_drawing:
				# 开始划线 - 从鼠标位置开始
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
		_deploy_web()

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
	skill_state = SkillState.PLANNING
	
	# 子弹时间
	Engine.time_scale = 0.1
	
	# 如果已有蛛网，清理
	if skill_state == SkillState.WEAVE:
		_cleanup_webs()
	
	# 清空路径
	path_points.clear()
	path_segments.clear()
	line_2d.clear_points()
	
	# 添加起点为鼠标位置（而不是角色位置）
	if skill_owner:
		var start_pos = skill_owner.get_global_mouse_position()
		path_points.append(start_pos)
		last_point = start_pos

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
			print("[SkillWebWeave] >>> 实时检测到线段交叉！线段 %d 和最新线段 <<<" % i)
			has_closure = true
			return
	
	# 检查距离闭合：当前点是否接近起点（排除最近的点）
	if path_points.size() >= 20:
		var current_point = path_points[path_points.size() - 1]
		if current_point.distance_to(path_points[0]) < close_threshold:
			print("[SkillWebWeave] >>> 实时检测到距离闭合（接近起点）<<<")
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
	
	# 重置起点为鼠标位置（而不是角色位置）
	if skill_owner:
		var start_pos = skill_owner.get_global_mouse_position()
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

## 更新规划路径的视觉效果
func _update_planning_visuals() -> void:
	if not is_planning:
		if skill_state == SkillState.IDLE:
			line_2d.clear_points()
		return
	
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
	
	# 变色逻辑：根据封闭状态设置颜色
	if has_closure:
		line_2d.default_color = web_color_crossing
	else:
		line_2d.default_color = web_color_open

# ==============================================================================
# 蛛网部署
# ==============================================================================

## 部署蛛网到场景中
func _deploy_web() -> void:
	is_planning = false
	is_charging = false
	
	# 恢复时间流速
	Engine.time_scale = 1.0
	
	skill_state = SkillState.WEAVE
	current_web_timer = 0.0
	
	if path_points.size() < 2:
		skill_state = SkillState.IDLE
		_cleanup_webs()
		return
	
	# 在松开Q键时进行最终的闭合检测
	_perform_final_closure_check()
	
	# 创建蛛网线条
	for i in range(path_points.size() - 1):
		_create_web_line(path_points[i], path_points[i + 1])
	
	# 只有闭合时才创建陷阱区域
	if has_closure:
		# 查找并创建闭合区域
		var calculated_polygons = _find_closed_loops_in_path()
		for poly in calculated_polygons:
			_create_trap_polygon(poly)
	
	# 清空路径
	path_points.clear()
	line_2d.clear_points()
	
	# ✅ 启动自动收网计时器
	if is_instance_valid(auto_recall_timer):
		auto_recall_timer.start(auto_recall_delay)
		print("[SkillWebWeave] ★★★ 自动收网计时器已启动 ★★★")
		print("[SkillWebWeave] 延迟时间: %.1f秒" % auto_recall_delay)
		print("[SkillWebWeave] Timer 父节点: %s" % auto_recall_timer.get_parent().name)
		print("[SkillWebWeave] web_container 父节点: %s" % (web_container.get_parent().name if web_container.get_parent() else "null"))
	else:
		print("[SkillWebWeave] ⚠️ 警告：auto_recall_timer 无效！")
	
	# 开始冷却
	start_cooldown()

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
				print("[SkillWebWeave] >>> 检测到线段交叉！线段 %d 和 %d <<<" % [i, j])
				has_closure = true
				return
	
	# 检查距离闭合：终点是否接近起点或路径中的其他点
	if path_points.size() >= 3:
		var last_point = path_points[path_points.size() - 1]
		
		# 检查是否接近起点
		if last_point.distance_to(path_points[0]) < close_threshold:
			print("[SkillWebWeave] >>> 检测到距离闭合（接近起点）<<<")
			has_closure = true
			return
		
		# 检查是否接近路径中的其他点（排除最后20个点）
		var check_until = max(0, path_points.size() - 20)
		for i in range(check_until):
			if last_point.distance_to(path_points[i]) < close_threshold:
				print("[SkillWebWeave] >>> 检测到距离闭合（接近点 %d）<<<" % i)
				has_closure = true
				return

## 查找路径中的闭合区域 - 使用公共工具类
func _find_closed_loops_in_path() -> Array[PackedVector2Array]:
	return PolygonUtils.find_all_closing_polygons(path_points, close_threshold)

## 创建蛛网线条
func _create_web_line(p1: Vector2, p2: Vector2) -> void:
	var l = Line2D.new()
	l.width = 4.0
	l.default_color = web_color_open
	l.add_point(p1)
	l.add_point(p2)
	web_container.add_child(l)
	active_web_lines.append(l)

## 创建陷阱多边形
func _create_trap_polygon(poly_pts: PackedVector2Array) -> void:
	var p = Polygon2D.new()
	p.polygon = poly_pts
	p.color = web_color_closed_fill
	web_container.add_child(p)
	active_trap_polygons.append(p)
	_apply_trap_logic(poly_pts)

## 应用陷阱逻辑：定身+易伤标记
func _apply_trap_logic(poly: PackedVector2Array) -> void:
	# 创建闭合遮罩视觉效果
	_create_weaver_closure_mask(poly)
	
	var enemies = get_tree().get_nodes_in_group("enemies")
	var count = 0
	
	for e in enemies:
		if not is_instance_valid(e):
			continue
		if not Geometry2D.is_point_in_polygon(e.global_position, poly):
			continue
		
		# 检查是否已被困
		var already = false
		for ref in trapped_enemies:
			if ref.get_ref() == e:
				already = true
				break
		
		if not already:
			trapped_enemies.append(weakref(e))
			Global.spawn_floating_text(e.global_position, "TRAPPED!", Color.RED)
			if "can_move" in e:
				e.can_move = false
			e.modulate = Color(1, 0.5, 0.5)
			count += 1
	
	if count > 0:
		Global.on_camera_shake.emit(3.0 * count, 0.2)

## 创建织网者闭合遮罩视觉效果 - 使用公共工具类
func _create_weaver_closure_mask(polygon: PackedVector2Array) -> void:
	var polygons: Array[PackedVector2Array] = [polygon]
	PolygonUtils.show_closure_masks(polygons, Color(0.8, 0.2, 0.8, 0.7), get_tree(), 0.6)

# ==============================================================================
# 收网阶段
# ==============================================================================

## 自动收网计时器超时回调
func _on_auto_recall_timeout() -> void:
	print("[SkillWebWeave] ★★★ 自动收网计时器超时，开始收网 ★★★")
	print("[SkillWebWeave] 当前 skill_state: %s" % skill_state)
	print("[SkillWebWeave] web_container 是否有效: %s" % is_instance_valid(web_container))
	print("[SkillWebWeave] skill_owner 是否有效: %s" % is_instance_valid(skill_owner))
	print("[SkillWebWeave] active_web_lines 数量: %d" % active_web_lines.size())
	
	# ✅ 直接在这里处理收网，不依赖其他函数
	if active_web_lines.is_empty():
		print("[SkillWebWeave] 没有蛛网线条，跳过收网")
		return
	
	# 准备收网数据
	var recall_data = []
	for line in active_web_lines:
		if is_instance_valid(line):
			recall_data.append({
				"line": line,
				"p1": line.points[0],
				"p2": line.points[1],
				"progress": 0.0
			})
	
	active_web_lines.clear()
	print("[SkillWebWeave] 准备收网，线条数量: %d" % recall_data.size())
	
	# 淡出陷阱多边形
	var t = create_tween()
	for poly in active_trap_polygons:
		if is_instance_valid(poly):
			t.parallel().tween_property(poly, "modulate:a", 0.0, 0.3)
	t.tween_callback(func():
		for poly in active_trap_polygons:
			if is_instance_valid(poly):
				poly.queue_free()
		active_trap_polygons.clear()
	)
	
	# ✅ 使用 Tween 来处理收网动画
	_start_recall_with_tween(recall_data)

## 使用 Tween 处理收网
func _start_recall_with_tween(recall_data: Array) -> void:
	print("[SkillWebWeave] 开始使用 Tween 处理收网")
	
	# 确定目标位置
	var target: Vector2
	if is_instance_valid(skill_owner):
		target = skill_owner.global_position
	elif is_instance_valid(web_container):
		target = web_container.global_position
	else:
		print("[SkillWebWeave] 无法确定收网目标，清理蛛网")
		_cleanup_webs()
		return
	
	print("[SkillWebWeave] 收网目标位置: %s" % target)
	
	# 计算收网时间
	var recall_time = 1.0 / recall_fly_speed  # fly_speed=3.0 -> time=0.33秒
	print("[SkillWebWeave] 收网时间: %.2f秒" % recall_time)
	
	# 为每条线创建 Tween
	var hit_history_local = {}
	var trapped_local = trapped_enemies.duplicate()
	
	for data in recall_data:
		var line: Line2D = data["line"]
		if not is_instance_valid(line):
			continue
		
		var p1_start = data["p1"]
		var p2_start = data["p2"]
		
		# 创建 Tween
		var tween = create_tween()
		tween.set_parallel(true)
		
		# 动画：点1移动到目标
		tween.tween_method(
			func(val: Vector2): line.set_point_position(0, val),
			p1_start,
			target,
			recall_time
		)
		
		# 动画：点2移动到目标
		tween.tween_method(
			func(val: Vector2): line.set_point_position(1, val),
			p2_start,
			target,
			recall_time
		)
		
		# 动画：淡出
		tween.tween_property(line, "modulate:a", 0.0, recall_time * 0.5).set_delay(recall_time * 0.5)
		
		# 完成后删除
		tween.tween_callback(func():
			if is_instance_valid(line):
				line.queue_free()
		)
	
	# 设置一个总的完成回调
	var final_tween = create_tween()
	final_tween.tween_interval(recall_time)
	final_tween.tween_callback(func():
		print("[SkillWebWeave] 收网完成")
		_cleanup_webs()
	)

## 开始收网
func _start_recall() -> void:
	if skill_state != SkillState.WEAVE:
		print("[SkillWebWeave] 当前状态不是WEAVE，无法收网: %s" % skill_state)
		return
	
	print("[SkillWebWeave] 开始收网")
	
	# ✅ 停止自动收网计时器（如果还在运行）
	if is_instance_valid(auto_recall_timer) and not auto_recall_timer.is_stopped():
		auto_recall_timer.stop()
		print("[SkillWebWeave] 停止自动收网计时器")
	
	skill_state = SkillState.RECALL
	hit_history.clear()
	recall_objects.clear()
	
	# 将所有线条加入收网列表
	for line in active_web_lines:
		if is_instance_valid(line):
			recall_objects.append({
				"line": line,
				"p1": line.points[0],
				"p2": line.points[1],
				"progress": 0.0
			})
	active_web_lines.clear()
	
	# 淡出陷阱多边形
	var t = create_tween()
	for poly in active_trap_polygons:
		if is_instance_valid(poly):
			t.parallel().tween_property(poly, "modulate:a", 0.0, 0.3)
	t.tween_callback(func():
		for poly in active_trap_polygons:
			if is_instance_valid(poly):
				poly.queue_free()
		active_trap_polygons.clear()
	)

## 处理收网物理
func _process_recall_physics(delta: float) -> void:
	if skill_state != SkillState.RECALL:
		return
	
	if recall_objects.is_empty():
		_cleanup_webs()
		return
	
	# ✅ 修复：如果 skill_owner 无效，使用 web_container 的位置作为目标
	var target: Vector2
	if is_instance_valid(skill_owner):
		target = skill_owner.global_position
	elif is_instance_valid(web_container):
		# 使用蛛网容器的位置（通常是场景中心）
		target = web_container.global_position
		print("[SkillWebWeave] skill_owner 无效，使用 web_container 位置作为收网目标: %s" % target)
	else:
		# 如果连容器都无效了，清理蛛网
		print("[SkillWebWeave] skill_owner 和 web_container 都无效，清理蛛网")
		_cleanup_webs()
		return
	
	var all_finished = true
	
	for obj in recall_objects:
		var line: Line2D = obj["line"]
		if not is_instance_valid(line):
			continue
		
		# 更新进度（线性插值，不使用缓动）
		obj["progress"] += delta * recall_fly_speed
		var t = clamp(obj["progress"], 0.0, 1.0)
		
		if t < 1.0:
			all_finished = false
		
		# 收缩线条
		var curr_p1 = obj["p1"].lerp(target, t)
		var curr_p2 = obj["p2"].lerp(target, t)
		line.set_point_position(0, curr_p1)
		line.set_point_position(1, curr_p2)
		
		# 检测碰撞（扩大检测范围到95%）
		if t < 0.95:
			_check_line_collision(curr_p1, curr_p2)
		
		# 淡出（延后淡出时机）
		if t > 0.9:
			line.modulate.a = 1.0 - (t - 0.9) * 10.0
	
	if all_finished:
		_cleanup_webs()

## 检查线条与敌人的碰撞
func _check_line_collision(p1: Vector2, p2: Vector2) -> void:
	var enemies = get_tree().get_nodes_in_group("enemies")
	for e in enemies:
		if not is_instance_valid(e):
			continue
		if e in hit_history:
			continue
		
		var close_p = Geometry2D.get_closest_point_to_segment(e.global_position, p1, p2)
		if e.global_position.distance_to(close_p) < 40.0:
			_apply_recall_damage(e)
			hit_history[e] = true

## 应用收网伤害
func _apply_recall_damage(enemy: Node2D) -> void:
	var dmg = recall_damage
	
	# 检查是否被困（处决伤害）
	var is_trapped = false
	for ref in trapped_enemies:
		if ref.get_ref() == enemy:
			is_trapped = true
			break
	
	if is_trapped:
		dmg = int(recall_damage * recall_execute_mult)
		Global.spawn_floating_text(enemy.global_position, "EXECUTE! %d" % dmg, Color(1, 0.2, 0.2))
	else:
		Global.spawn_floating_text(enemy.global_position, str(dmg), Color.WHITE)
	
	if enemy.has_node("HealthComponent"):
		enemy.health_component.take_damage(dmg)

## 清理所有蛛网
func _cleanup_webs() -> void:
	# 清理蛛网容器中的所有子节点（但保留 Timer）
	if is_instance_valid(web_container):
		for child in web_container.get_children():
			# ✅ 不要删除 Timer
			if child == auto_recall_timer:
				print("[SkillWebWeave] 保留 auto_recall_timer，不删除")
				continue
			child.queue_free()
	
	# 清空数组
	path_points.clear()
	active_web_lines.clear()
	active_trap_polygons.clear()
	recall_objects.clear()
	hit_history.clear()
	current_web_timer = 0.0
	
	# 释放被困敌人
	for ref in trapped_enemies:
		var e = ref.get_ref()
		if is_instance_valid(e):
			e.modulate = Color.WHITE
			if "can_move" in e:
				e.can_move = true
	trapped_enemies.clear()
	
	# 恢复时间流速
	if is_planning:
		Engine.time_scale = 1.0
		is_planning = false
	
	skill_state = SkillState.IDLE
	print("[SkillWebWeave] _cleanup_webs() 完成，skill_state 重置为 IDLE")

# ==============================================================================
# 辅助方法
# ==============================================================================

## 检查玩家是否可以移动
func can_move() -> bool:
	return not is_planning

## 清理资源
func cleanup() -> void:
	# 清理规划线
	if is_instance_valid(line_2d):
		line_2d.queue_free()
	
	# ✅ 只清理规划状态，不清理已部署的蛛网
	# 这样切换角色时，已部署的蛛网会继续存在并按照自己的生命周期消失
	print("[SkillWebWeave] 已部署的蛛网由自己的生命周期管理，无需手动清理")
	
	# 清空规划数据
	path_points.clear()
	path_segments.clear()
	
	# 重置规划状态
	is_planning = false
	is_drawing = false
	has_shown_no_energy_hint = false
	accumulated_distance = 0.0
	total_distance_drawn = 0.0
	
	# 恢复时间流速
	Engine.time_scale = 1.0
	
	# 如果在编织阶段，释放被困敌人
	if skill_state == SkillState.WEAVE:
		for ref in trapped_enemies:
			var e = ref.get_ref()
			if is_instance_valid(e):
				e.modulate = Color.WHITE
				if "can_move" in e:
					e.can_move = true
		trapped_enemies.clear()
	
	# ✅ 不要停止自动收网计时器
	# 让它继续运行，这样切换角色后蛛网还能自动收回
	print("[SkillWebWeave] 保留自动收网计时器，让蛛网按照自己的生命周期收回")
	
	# 如果在收网阶段，让收网继续进行
	# 不要中断收网过程
	print("[SkillWebWeave] cleanup() 完成，skill_state=%s" % skill_state)

## 打印调试信息
func print_debug_info() -> void:
	print("[SkillWebWeave] 调试信息:")
	print("  - skill_state: %s" % skill_state)
	print("  - is_planning: %s" % is_planning)
	print("  - is_drawing: %s" % is_drawing)
	print("  - path_points: %d" % path_points.size())
	print("  - path_segments: %d" % path_segments.size())
	print("  - trapped_enemies: %d" % trapped_enemies.size())
	print("  - total_distance_drawn: %.0f" % total_distance_drawn)
	print("  - current_energy_cost: %.2f" % _calculate_current_energy_cost())
	print("  - energy_per_10px: %.1f" % energy_per_10px)
	print("  - energy_threshold_distance: %.0f" % energy_threshold_distance)
	print("  - energy_scale_multiplier: %.4f" % energy_scale_multiplier)
	print("  - recall_fly_speed: %.1f" % recall_fly_speed)
