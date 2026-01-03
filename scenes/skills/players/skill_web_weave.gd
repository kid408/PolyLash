extends SkillBase
class_name SkillWebWeave

## ==============================================================================
## 织网者Q技能 - 蛛网编织与收割（两阶段）
## ==============================================================================
## 
## 阶段一（编织）：
## - 按住Q进入规划模式（子弹时间）
## - 左键：向鼠标方向延伸固定距离添加路径点
## - 右键：撤销最后一个路径点
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

## 每段蛛网的固定长度
var fixed_segment_length: float = 320.0

## 收网速度
var recall_fly_speed: float = 3.0

## 收网伤害
var recall_damage: int = 40

## 处决倍率（被困敌人）
var recall_execute_mult: float = 3.0

## 自动收网延迟
var auto_recall_delay: float = 8.0

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

## 已确认的路径点
var path_points: Array[Vector2] = []

## 激活的蛛网线条
var active_web_lines: Array[Line2D] = []

## 激活的陷阱多边形
var active_trap_polygons: Array[Polygon2D] = []

## 被困敌人（WeakRef）
var trapped_enemies: Array = []

## 收网对象
var recall_objects: Array = []

## 收网伤害历史
var hit_history: Dictionary = {}

## 当前蛛网计时器
var current_web_timer: float = 0.0

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
	
	# 创建蛛网容器
	web_container = Node2D.new()
	web_container.name = "WebContainer"
	web_container.top_level = true
	web_container.global_position = Vector2.ZERO
	
	if skill_owner:
		skill_owner.add_child(web_container)
	
	# 创建Line2D用于绘制规划路径
	line_2d = Line2D.new()
	line_2d.name = "WebPlanningLine"
	line_2d.top_level = true
	line_2d.width = 4.0
	
	if skill_owner:
		skill_owner.add_child(line_2d)

func _process(delta: float) -> void:
	super._process(delta)
	
	# 更新规划视觉
	_update_planning_visuals()
	
	# 处理收网物理
	_process_recall_physics(delta)
	
	# 编织阶段：检查是否触发收网
	if skill_state == SkillState.WEAVE:
		current_web_timer += delta
		var manual_trigger = Input.is_action_just_pressed("skill_q")
		var auto_trigger = current_web_timer >= auto_recall_delay
		
		if manual_trigger or auto_trigger:
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
		# 左键：添加路径点
		if Input.is_action_just_pressed("click_left"):
			_handle_add_point()
		
		# 右键：撤销路径点
		if Input.is_action_just_pressed("click_right"):
			_undo_last_point()

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
	skill_state = SkillState.PLANNING
	
	# 子弹时间
	Engine.time_scale = 0.1
	
	# 如果已有蛛网，清理
	if skill_state == SkillState.WEAVE:
		_cleanup_webs()
	
	# 清空路径
	path_points.clear()
	line_2d.clear_points()
	
	# 添加起点
	if skill_owner:
		path_points.append(skill_owner.global_position)

## 添加路径点
func _handle_add_point() -> void:
	if path_points.is_empty() or not skill_owner:
		return
	
	var start_pos = path_points.back()
	var mouse_pos = skill_owner.get_global_mouse_position()
	
	# 计算延伸点（固定距离）
	var direction = (mouse_pos - start_pos).normalized()
	if start_pos.distance_to(mouse_pos) < 1.0:
		direction = Vector2.RIGHT
	
	var final_pos = start_pos + (direction * fixed_segment_length)
	
	# 消耗能量并添加点
	if consume_energy():
		path_points.append(final_pos)
	else:
		if skill_owner:
			Global.spawn_floating_text(skill_owner.global_position, "No Energy!", Color.RED)

## 撤销最后一个路径点
func _undo_last_point() -> void:
	if path_points.size() > 1:
		path_points.pop_back()
		
		# 返还能量
		if skill_owner and skill_owner.has_method("gain_energy"):
			skill_owner.energy += energy_cost
			skill_owner.update_ui_signals()

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
	
	# 绘制预览点
	if skill_owner:
		var last_point = path_points.back()
		var mouse_pos = skill_owner.get_global_mouse_position()
		var direction = (mouse_pos - last_point).normalized()
		if last_point.distance_to(mouse_pos) < 1.0:
			direction = Vector2.RIGHT
		var preview_pos = last_point + (direction * fixed_segment_length)
		
		line_2d.add_point(preview_pos)
	
	# 变色逻辑：检查是否相交
	if _check_confirmed_points_loop():
		line_2d.default_color = web_color_crossing
	else:
		line_2d.default_color = web_color_open

## 检查已确认的点集中是否存在线段相交
func _check_confirmed_points_loop() -> bool:
	if path_points.size() < 4:
		return false
	
	var count = path_points.size()
	var new_p1 = path_points[count - 2]
	var new_p2 = path_points[count - 1]
	
	# 检查最新线段是否与之前的线段相交
	for i in range(count - 3):
		var old_p1 = path_points[i]
		var old_p2 = path_points[i + 1]
		
		var res = Geometry2D.segment_intersects_segment(old_p1, old_p2, new_p1, new_p2)
		if res != null:
			return true
	
	return false

# 由于代码太长，我将在下一个append中继续添加剩余部分

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
	
	# 创建蛛网线条
	for i in range(path_points.size() - 1):
		_create_web_line(path_points[i], path_points[i + 1])
	
	# 查找并创建闭合区域
	var calculated_polygons = _find_closed_loops_in_path()
	for poly in calculated_polygons:
		_create_trap_polygon(poly)
	
	# 清空路径
	path_points.clear()
	line_2d.clear_points()
	
	# 开始冷却
	start_cooldown()

## 查找路径中的闭合区域
func _find_closed_loops_in_path() -> Array[PackedVector2Array]:
	var polygons: Array[PackedVector2Array] = []
	var count = path_points.size()
	if count < 3:
		return []
	
	for current_idx in range(count - 1):
		var curr_p1 = path_points[current_idx]
		var curr_p2 = path_points[current_idx + 1]
		
		for prev_idx in range(current_idx - 1):
			var prev_p1 = path_points[prev_idx]
			var prev_p2 = path_points[prev_idx + 1]
			
			var intersection = Geometry2D.segment_intersects_segment(
				prev_p1, prev_p2, curr_p1, curr_p2
			)
			
			if intersection != null:
				var poly = PackedVector2Array()
				poly.append(intersection)
				for k in range(prev_idx + 1, current_idx + 1):
					poly.append(path_points[k])
				poly.append(intersection)
				
				if poly.size() >= 3:
					polygons.append(poly)
	
	return polygons

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

# ==============================================================================
# 收网阶段
# ==============================================================================

## 开始收网
func _start_recall() -> void:
	if skill_state != SkillState.WEAVE:
		return
	
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
	
	if not skill_owner:
		_cleanup_webs()
		return
	
	var target = skill_owner.global_position
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
	# 清理蛛网容器中的所有子节点
	if is_instance_valid(web_container):
		for child in web_container.get_children():
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

# ==============================================================================
# 辅助方法
# ==============================================================================

## 检查玩家是否可以移动
func can_move() -> bool:
	return not is_planning

## 清理资源
func cleanup() -> void:
	_cleanup_webs()
	
	# 清理Line2D
	if is_instance_valid(line_2d):
		line_2d.queue_free()
	
	# 清理蛛网容器
	if is_instance_valid(web_container):
		web_container.queue_free()

## 打印调试信息
func print_debug_info() -> void:
	print("[SkillWebWeave] 调试信息:")
	print("  - skill_state: %s" % skill_state)
	print("  - is_planning: %s" % is_planning)
	print("  - path_points: %d" % path_points.size())
	print("  - trapped_enemies: %d" % trapped_enemies.size())
	print("  - fixed_segment_length: %.0f" % fixed_segment_length)
	print("  - recall_fly_speed: %.1f" % recall_fly_speed)
	print("  - energy_cost: %.0f" % energy_cost)
