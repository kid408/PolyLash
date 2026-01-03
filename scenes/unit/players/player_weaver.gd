extends PlayerBase
class_name PlayerWeaver

# ==============================================================================
# 织网者角色 - 使用蛛网控制和收割敌人
# ==============================================================================
# Q技能：编织蛛网（两阶段）
#   阶段一（编织）：
#     - 按住Q进入规划模式（子弹时间）
#     - 左键：向鼠标方向延伸固定距离添加路径点
#     - 右键：撤销最后一个路径点
#     - 松开Q：部署蛛网，滞留8秒
#     - 线段相交形成闭合区域：定身敌人+易伤标记（250%伤害）
#   阶段二（收割）：
#     - 再次按Q或8秒后自动触发
#     - 蛛网收缩回玩家位置
#     - 路径上的敌人受到伤害
#     - 被困敌人受到处决伤害（250%）
# E技能：定身炸弹
#   - 范围定身敌人2.5秒
# ==============================================================================

# ==============================================================================
# 配置参数
# ==============================================================================
enum SkillState { IDLE, PLANNING, WEAVE, RECALL }

@export_group("Weaver Settings")
@export var fixed_segment_length: float = 320.0                      # 每段蛛网的固定长度
@export var web_color_open: Color = Color(0.6, 0.8, 1.0, 0.8)       # 蓝色（未闭合）
@export var web_color_crossing: Color = Color(1.0, 0.5, 0.2, 0.9)   # 橙色/红色（已闭合/交叉）
@export var web_color_closed_fill: Color = Color(1.0, 0.2, 0.2, 0.3) # 红色填充（陷阱）
@export var auto_recall_delay: float = 8.0                           # 自动收网延迟

@export_group("Recall Settings")
@export var recall_fly_speed: float = 3.0      # 收网速度
@export var recall_damage: int = 40            # 收网伤害
@export var recall_execute_mult: float = 3.0   # 处决倍率（被困敌人）

@export_group("Stun Bomb Settings")
@export var stun_radius: float = 300.0         # 定身半径
@export var stun_duration: float = 2.5         # 定身时长
@export var stun_color: Color = Color(0.2, 0.8, 1.0, 0.5)  # 定身视觉颜色

# ==============================================================================
# 状态变量
# ==============================================================================
var skill_state: SkillState = SkillState.IDLE
var is_planning: bool = false 

var path_points: Array[Vector2] = []           # 已确认的路径点
var active_web_lines: Array[Line2D] = []       # 激活的蛛网线条
var active_trap_polygons: Array[Polygon2D] = [] # 激活的陷阱多边形
var trapped_enemies: Array = []                 # 被困敌人（WeakRef）

var recall_objects: Array = []                  # 收网对象
var hit_history: Dictionary = {}                # 收网伤害历史

var current_web_timer: float = 0.0              # 当前蛛网计时器

@onready var line_2d: Line2D = $Line2D if has_node("Line2D") else null
@onready var web_container: Node2D = Node2D.new()

# ==============================================================================
# 初始化
# ==============================================================================
func _ready() -> void:
	super._ready()
	
	# 从CSV加载技能配置
	_load_skill_config_from_csv()
	
	# 初始化蛛网容器
	add_child(web_container)
	web_container.top_level = true 
	web_container.global_position = Vector2.ZERO
	
	# 初始化Line2D用于绘制规划路径
	if not line_2d:
		line_2d = Line2D.new()
		line_2d.name = "Line2D"
		line_2d.width = 4.0
		line_2d.top_level = true 
		add_child(line_2d)
	else:
		line_2d.top_level = true
	
	print("[Weaver] Fixed Segment Length: ", fixed_segment_length)

func _load_skill_config_from_csv() -> void:
	"""从CSV加载技能配置参数"""
	var skills = ConfigManager.get_player_skills("weaver")
	if skills.is_empty():
		print("[PlayerWeaver] 警告：未找到技能配置，使用默认值")
		return
	
	# 加载所有技能参数
	if "fixed_segment_length" in skills: fixed_segment_length = skills["fixed_segment_length"]
	if "recall_fly_speed" in skills: recall_fly_speed = skills["recall_fly_speed"]
	if "recall_damage" in skills: recall_damage = skills["recall_damage"]
	if "recall_execute_mult" in skills: recall_execute_mult = skills["recall_execute_mult"]
	if "auto_recall_delay" in skills: auto_recall_delay = skills["auto_recall_delay"]
	if "stun_radius" in skills: stun_radius = skills["stun_radius"]
	if "stun_duration" in skills: stun_duration = skills["stun_duration"]
	
	# 加载蛛网颜色（未闭合状态）
	if "web_color_open_r" in skills and "web_color_open_g" in skills and "web_color_open_b" in skills and "web_color_open_a" in skills:
		web_color_open = Color(
			skills["web_color_open_r"],
			skills["web_color_open_g"],
			skills["web_color_open_b"],
			skills["web_color_open_a"]
		)
	
	print("[PlayerWeaver] 技能配置加载完成: 线段长度=", fixed_segment_length, " 收网速度=", recall_fly_speed)

# ==============================================================================
# 主循环
# ==============================================================================
func _process_subclass(delta: float) -> void:
	# 规划模式：子弹时间
	if is_planning:
		if Engine.time_scale > 0.2: 
			Engine.time_scale = 0.1
	
	_update_planning_visuals()
	_process_recall_physics(delta)
	
	# 处理冲刺
	if is_dashing:
		position = position.move_toward(dash_target, dash_speed * delta)
		if position.distance_to(dash_target) < 10.0:
			_end_dash()
	
	# 编织阶段：检查是否触发收网
	if skill_state == SkillState.WEAVE:
		current_web_timer += delta
		var manual_trigger = Input.is_action_just_pressed("skill_q")
		var auto_trigger = current_web_timer >= auto_recall_delay
		
		if manual_trigger or auto_trigger:
			start_recall()

# ==============================================================================
# Q技能：蛛网编织与收割
# ==============================================================================
func charge_skill_q(delta: float) -> void:
	if skill_state == SkillState.RECALL: return
	
	if skill_state == SkillState.IDLE and not is_planning:
		enter_planning_mode()
	
	if is_planning:
		if Input.is_action_just_pressed("click_left"):
			handle_add_point()
		if Input.is_action_just_pressed("click_right"):
			undo_last_point()

func release_skill_q() -> void:
	if is_planning:
		deploy_web()

func enter_planning_mode() -> void:
	is_planning = true
	skill_state = SkillState.PLANNING
	Engine.time_scale = 0.1
	
	# 如果已有蛛网，清理
	if skill_state == SkillState.WEAVE:
		cleanup_webs()
	
	path_points.clear()
	line_2d.clear_points()
	path_points.append(global_position)  # 起点

func handle_add_point() -> void:
	if path_points.is_empty(): return
	
	var start_pos = path_points.back()
	var mouse_pos = get_global_mouse_position()
	
	# 计算延伸点（固定距离）
	var direction = (mouse_pos - start_pos).normalized()
	if start_pos.distance_to(mouse_pos) < 1.0:
		direction = Vector2.RIGHT 
	
	var final_pos = start_pos + (direction * fixed_segment_length)
	
	if consume_energy(skill_q_cost):
		path_points.append(final_pos)
	else:
		Global.spawn_floating_text(global_position, "No Energy!", Color.RED)

func undo_last_point() -> void:
	if path_points.size() > 1:
		path_points.pop_back()
		energy += skill_q_cost
		update_ui_signals()

func _update_planning_visuals() -> void:
	if not is_planning:
		if skill_state == SkillState.IDLE: 
			line_2d.clear_points()
		return
	
	line_2d.clear_points()
	
	if path_points.is_empty(): return
	
	# 绘制已确认的点
	for p in path_points:
		line_2d.add_point(p)
	
	# 绘制预览点
	var last_point = path_points.back()
	var mouse_pos = get_global_mouse_position()
	var direction = (mouse_pos - last_point).normalized()
	if last_point.distance_to(mouse_pos) < 1.0: 
		direction = Vector2.RIGHT
	var preview_pos = last_point + (direction * fixed_segment_length)
	
	line_2d.add_point(preview_pos)
	
	# 变色逻辑：只检查已确认的点是否相交
	if check_confirmed_points_loop():
		line_2d.default_color = web_color_crossing
	else:
		line_2d.default_color = web_color_open

func check_confirmed_points_loop() -> bool:
	"""检查已确认的点集中是否存在线段相交"""
	if path_points.size() < 4: return false
	
	var count = path_points.size()
	var new_p1 = path_points[count - 2]
	var new_p2 = path_points[count - 1]
	
	# 检查最新线段是否与之前的线段相交
	for i in range(count - 3): 
		var old_p1 = path_points[i]
		var old_p2 = path_points[i+1]
		
		var res = Geometry2D.segment_intersects_segment(old_p1, old_p2, new_p1, new_p2)
		if res != null:
			return true
	
	return false

# ==============================================================================
# 蛛网部署
# ==============================================================================
func deploy_web() -> void:
	"""部署蛛网到场景中"""
	is_planning = false
	Engine.time_scale = 1.0
	skill_state = SkillState.WEAVE
	current_web_timer = 0.0 
	
	if path_points.size() < 2:
		skill_state = SkillState.IDLE
		cleanup_webs()
		return

	# 创建蛛网线条
	for i in range(path_points.size() - 1):
		create_web_line(path_points[i], path_points[i+1])
	
	# 查找并创建闭合区域
	var calculated_polygons = find_closed_loops_in_path()
	for poly in calculated_polygons:
		create_trap_polygon(poly)
	
	path_points.clear()
	line_2d.clear_points()

func find_closed_loops_in_path() -> Array[PackedVector2Array]:
	"""查找路径中的闭合区域"""
	var polygons: Array[PackedVector2Array] = []
	var count = path_points.size()
	if count < 3: return []
	
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

func create_web_line(p1: Vector2, p2: Vector2) -> void:
	"""创建蛛网线条"""
	var l = Line2D.new()
	l.width = 4.0
	l.default_color = web_color_open
	l.add_point(p1)
	l.add_point(p2)
	web_container.add_child(l)
	active_web_lines.append(l)

func create_trap_polygon(poly_pts: PackedVector2Array) -> void:
	"""创建陷阱多边形"""
	var p = Polygon2D.new()
	p.polygon = poly_pts
	p.color = web_color_closed_fill
	web_container.add_child(p)
	active_trap_polygons.append(p)
	apply_trap_logic(poly_pts)

func apply_trap_logic(poly: PackedVector2Array) -> void:
	"""应用陷阱逻辑：定身+易伤标记"""
	var enemies = get_tree().get_nodes_in_group("enemies")
	var count = 0
	
	for e in enemies:
		if not is_instance_valid(e): continue
		if not Geometry2D.is_point_in_polygon(e.global_position, poly): continue
		
		# 检查是否已被困
		var already = false
		for ref in trapped_enemies:
			if ref.get_ref() == e: 
				already = true
				break
		
		if not already:
			trapped_enemies.append(weakref(e))
			Global.spawn_floating_text(e.global_position, "TRAPPED!", Color.RED)
			if "can_move" in e: e.can_move = false
			e.modulate = Color(1, 0.5, 0.5)
			count += 1
	
	if count > 0:
		Global.on_camera_shake.emit(3.0 * count, 0.2)

# ==============================================================================
# 收网阶段
# ==============================================================================
func start_recall() -> void:
	"""开始收网"""
	if skill_state != SkillState.WEAVE: return
	
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
			if is_instance_valid(poly): poly.queue_free()
		active_trap_polygons.clear()
	)

func _process_recall_physics(delta: float) -> void:
	"""处理收网物理"""
	if skill_state != SkillState.RECALL: return
	
	if recall_objects.is_empty():
		cleanup_webs()
		return
	
	var target = global_position
	var all_finished = true
	
	for obj in recall_objects:
		var line: Line2D = obj["line"]
		if not is_instance_valid(line): continue
		
		# 更新进度
		obj["progress"] += delta * recall_fly_speed
		var t = clamp(obj["progress"], 0.0, 1.0)
		# 使用线性插值，不使用缓动，保持匀速收缩
		# t = t * t  # 移除平方缓动，改为线性
		
		if t < 1.0: all_finished = false
		
		# 收缩线条
		var curr_p1 = obj["p1"].lerp(target, t)
		var curr_p2 = obj["p2"].lerp(target, t)
		line.set_point_position(0, curr_p1)
		line.set_point_position(1, curr_p2)
		
		# 检测碰撞（扩大检测范围到95%，增加命中机会）
		if t < 0.95: 
			check_line_collision(curr_p1, curr_p2)
		
		# 淡出（延后淡出时机，让线条更明显）
		if t > 0.9: 
			line.modulate.a = 1.0 - (t - 0.9) * 10.0
	
	if all_finished:
		cleanup_webs()

func check_line_collision(p1: Vector2, p2: Vector2) -> void:
	"""检查线条与敌人的碰撞"""
	var enemies = get_tree().get_nodes_in_group("enemies")
	for e in enemies:
		if not is_instance_valid(e): continue
		if e in hit_history: continue 
		
		var close_p = Geometry2D.get_closest_point_to_segment(e.global_position, p1, p2)
		if e.global_position.distance_to(close_p) < 40.0:
			apply_recall_damage(e)
			hit_history[e] = true

func apply_recall_damage(enemy: Node2D) -> void:
	"""应用收网伤害"""
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

func cleanup_webs() -> void:
	"""清理所有蛛网"""
	for child in web_container.get_children(): 
		child.queue_free()
	
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
			if "can_move" in e: e.can_move = true
	trapped_enemies.clear()
	
	skill_state = SkillState.IDLE

# ==============================================================================
# E技能：定身炸弹
# ==============================================================================
func use_skill_e() -> void:
	if is_planning: return 
	if not consume_energy(skill_e_cost): return
	
	Global.on_camera_shake.emit(8.0, 0.3)
	create_stun_visual(stun_radius)
	
	var enemies = get_tree().get_nodes_in_group("enemies")
	var hit_count = 0
	
	for enemy in enemies:
		if not is_instance_valid(enemy): continue
		if global_position.distance_to(enemy.global_position) < stun_radius:
			_apply_stun_effect(enemy)
			hit_count += 1
			
	if hit_count > 0:
		Global.spawn_floating_text(global_position, "FREEZE! x%d" % hit_count, Color.CYAN)

func _apply_stun_effect(enemy: Node2D) -> void:
	"""应用定身效果"""
	var enemy_ref = weakref(enemy)
	
	if "can_move" in enemy:
		enemy.can_move = false
	enemy.modulate = Color(0.3, 0.3, 1.0) 
	
	# 定时恢复
	get_tree().create_timer(stun_duration).timeout.connect(func():
		var e = enemy_ref.get_ref()
		if e:
			if "can_move" in e:
				# 检查是否仍被蛛网困住
				var is_still_trapped = false
				for ref in trapped_enemies:
					if ref.get_ref() == e:
						is_still_trapped = true
						break
				
				if not is_still_trapped:
					e.can_move = true
					e.modulate = Color.WHITE
				else:
					e.modulate = Color(1, 0.5, 0.5)
	)

func create_stun_visual(radius: float) -> void:
	"""创建定身视觉效果"""
	var poly = Polygon2D.new()
	var points = PackedVector2Array()
	for i in range(32):
		var angle = i * TAU / 32
		points.append(Vector2(cos(angle), sin(angle)) * radius)
	poly.polygon = points
	poly.color = stun_color
	poly.z_index = 80
	poly.global_position = global_position
	get_tree().current_scene.add_child(poly)
	
	var t = poly.create_tween()
	t.tween_property(poly, "scale", Vector2(1.1, 1.1), 0.1)
	t.tween_property(poly, "color:a", 0.0, 0.5)
	t.tween_callback(poly.queue_free)

# ==============================================================================
# 冲刺技能
# ==============================================================================
func use_dash() -> void:
	if is_planning: return
	if is_dashing or not consume_energy(dash_cost): return
	
	var dir = (get_global_mouse_position() - global_position).normalized()
	dash_target = position + dir * dash_distance 
	is_dashing = true
	collision.set_deferred("disabled", true) 
	Global.play_player_dash()

func _end_dash() -> void:
	is_dashing = false
	collision.set_deferred("disabled", false)
