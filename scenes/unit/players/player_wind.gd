extends PlayerBase
class_name PlayerWind

# ==============================================================================
# 1. 核心数值配置 (Inspector 可调)
# ==============================================================================
@export_group("Wind Settings")
@export var fixed_dash_distance: float = 300.0  
@export var dash_base_damage: int = 10          

@export_group("Wind Skills Stats")
# --- Q技能: 风墙 (物理拉扯 + 伤害) ---
@export var wind_wall_pull_force: float = 350.0 # 【加强】吸附力度
@export var wind_wall_damage: int = 15          # 【新增】风墙伤害/0.5秒
@export var wind_wall_duration: float = 3.0     
@export var wind_wall_width: float = 24.0       
@export var wind_wall_effect_radius: float = 120.0 # 有效吸附范围半径

# --- 闭环: 暴风领域 (强力聚怪 + 伤害) ---
@export var storm_zone_damage: int = 30         
@export var storm_zone_pull_force: float = 400.0 
@export var storm_zone_duration: float = 3.0    

# --- E技能: 暴风眼 (圆形吸怪 + 伤害) ---
@export var storm_eye_radius: float = 140.0     
@export var storm_eye_damage: int = 35          # 【新增】暴风眼伤害/0.5秒
@export var storm_eye_pull_force: float = 500.0 # 【加强】中心吸力极强
@export var storm_eye_duration: float = 3.0     

@export_group("Skill Costs")
# 注意：技能消耗现在从player_config.csv读取
# cost_per_segment使用skill_q_cost
# cost_storm_eye使用skill_e_cost
@export var cost_dash_normal: float = 10.0        

# ==============================================================================
# 2. 运行时变量
# ==============================================================================
@onready var line_2d: Line2D = $Line2D

var dash_queue: Array[Dictionary] = []      
var current_target: Vector2 = Vector2.ZERO
var current_is_wind_dash: bool = false   

var is_planning: bool = false            
var path_history: Array[Vector2] = []    
var upgrades = {"closed_loop": true}

func _ready() -> void:
	super._ready()
	line_2d.top_level = true
	line_2d.clear_points()
	# 颜色: 高亮青色/天蓝色
	line_2d.default_color = Color(0.2, 1.5, 1.5, 1.0) 
	
	# 确保 trail 引用正确
	if not trail:
		trail = %Trail if has_node("%Trail") else null
	
	print(">>> 御风者就绪 (PlayerWind - Physics Fixed)")

func can_move() -> bool:
	return not is_dashing

func _process_subclass(delta: float) -> void:
	if is_dashing:
		_process_dashing_movement(delta)
	
	_update_visuals()
	
	if is_planning:
		if Engine.time_scale > 0.2:
			Engine.time_scale = 0.1

# ==============================================================================
# 3. 输入处理逻辑
# ==============================================================================

func use_dash() -> void:
	if is_planning:
		return 
	else:
		if not is_dashing and consume_energy(cost_dash_normal):
			var mouse_pos = get_global_mouse_position()
			var dir = (mouse_pos - global_position).normalized()
			var target = global_position + dir * fixed_dash_distance
			
			add_dash_task(target, false) 
			start_dash_sequence()

func charge_skill_q(_delta: float) -> void:
	if not is_planning:
		enter_planning_mode()
	
	if Input.is_action_just_pressed("click_left"):
		if try_add_wind_path_segment():
			Global.spawn_floating_text(get_global_mouse_position(), "WIND", Color(0.2, 1.0, 1.0))
	
	if Input.is_action_just_pressed("click_right"):
		undo_last_point()

func release_skill_q() -> void:
	if is_planning:
		exit_planning_mode_and_dash()

func use_skill_e() -> void:
	if not consume_energy(skill_e_cost): return
	
	Global.on_camera_shake.emit(8.0, 0.2)
	call_deferred("_spawn_storm_eye", global_position)

# ==============================================================================
# 4. 冲刺与移动系统
# ==============================================================================

func enter_planning_mode() -> void:
	is_planning = true
	Engine.time_scale = 0.1 

func exit_planning_mode_and_dash() -> void:
	is_planning = false
	Engine.time_scale = 1.0 
	if dash_queue.size() > 0:
		start_dash_sequence()

func add_dash_task(pos: Vector2, is_wind: bool) -> void:
	dash_queue.append({
		"pos": pos,
		"is_wind": is_wind
	})

func try_add_wind_path_segment() -> bool:
	if consume_energy(skill_q_cost):
		var start_pos = global_position
		if dash_queue.size() > 0:
			start_pos = dash_queue.back()["pos"]
		
		var mouse_pos = get_global_mouse_position()
		var direction = (mouse_pos - start_pos).normalized()
		var final_pos = start_pos + (direction * fixed_dash_distance)
		
		add_dash_task(final_pos, true) 
		return true
	return false

func undo_last_point() -> void:
	if dash_queue.size() > 0:
		dash_queue.pop_back()
		energy += skill_q_cost
		update_ui_signals()

func try_break_line(enemy_pos: Vector2, radius: float) -> void:
	if dash_queue.is_empty(): return
	for i in range(dash_queue.size()):
		var task = dash_queue[i]
		if task["pos"].distance_to(enemy_pos) < radius:
			Global.on_camera_shake.emit(5.0, 0.1)
			Global.spawn_floating_text(task["pos"], "DISPERSED!", Color.CYAN)
			dash_queue = dash_queue.slice(0, i)
			return

func start_dash_sequence() -> void:
	if dash_queue.is_empty(): return
	
	is_dashing = true
	path_history.clear()
	path_history.append(global_position)
	
	if trail: trail.start_trail()
	visuals.modulate.a = 0.5
	
	collision.set_deferred("disabled", true)
	dash_hitbox.set_deferred("monitorable", true)
	dash_hitbox.set_deferred("monitoring", true)
	dash_hitbox.setup(dash_base_damage, false, dash_knockback, self)
	
	Global.play_player_dash()
	_pop_next_dash_target()

func _pop_next_dash_target() -> void:
	if dash_queue.size() > 0:
		var task = dash_queue.pop_front()
		current_target = task["pos"]
		current_is_wind_dash = task["is_wind"]
	else:
		end_dash_sequence()

func _process_dashing_movement(delta: float) -> void:
	Engine.time_scale = 1.0 
	if current_target == Vector2.ZERO: return
	
	position = position.move_toward(current_target, dash_speed * delta)
	
	if position.distance_to(current_target) < 10.0:
		_on_reach_target_point()

func _on_reach_target_point() -> void:
	var previous_pos = path_history.back()
	
	if current_is_wind_dash:
		path_history.append(global_position)
		call_deferred("_spawn_wind_wall", previous_pos, global_position)
		
		if upgrades["closed_loop"]:
			check_and_trigger_intersection()
	else:
		path_history.clear()
		path_history.append(global_position)
	
	_pop_next_dash_target()

func end_dash_sequence() -> void:
	if current_is_wind_dash and upgrades["closed_loop"]:
		check_and_trigger_intersection()
		
	is_dashing = false
	current_target = Vector2.ZERO
	if trail: trail.stop()
	visuals.modulate.a = 1.0
	collision.set_deferred("disabled", false)
	dash_hitbox.set_deferred("monitorable", false)
	dash_hitbox.set_deferred("monitoring", false)

# ==============================================================================
# 5. 风系技能生成器 (Wind Mechanics)
# ==============================================================================

# --- Q技能: 风墙 (吸附 + 伤害) ---
func _spawn_wind_wall(start: Vector2, end: Vector2) -> void:
	var area = Area2D.new()
	area.position = start 
	area.collision_mask = 2 
	area.monitorable = false
	area.monitoring = true
	
	var vec = end - start
	var length = vec.length()
	var angle = vec.angle()
	
	# 碰撞体范围包含效果半径，确保能吸到附近的怪
	var col = CollisionShape2D.new()
	var shape = RectangleShape2D.new()
	shape.size = Vector2(length, wind_wall_width + wind_wall_effect_radius * 2) 
	col.shape = shape
	col.position = Vector2(length / 2.0, 0)
	col.rotation = angle
	area.add_child(col)
	
	# 视觉
	var vis_line = Line2D.new()
	vis_line.add_point(Vector2.ZERO)
	vis_line.add_point(end - start)
	vis_line.width = wind_wall_width
	vis_line.default_color = Color(0.2, 1.5, 1.5, 0.8) 
	vis_line.begin_cap_mode = Line2D.LINE_CAP_ROUND
	vis_line.end_cap_mode = Line2D.LINE_CAP_ROUND
	area.add_child(vis_line)
	
	get_tree().current_scene.add_child(area)
	
	# 1. 物理 Tick (吸附逻辑)
	var timer = Timer.new()
	timer.wait_time = 0.05 
	timer.autostart = true
	area.add_child(timer)
	timer.timeout.connect(_on_wind_wall_tick.bind(area, start, end))
	
	# 2. 伤害 Tick (新增)
	var dmg_timer = Timer.new()
	dmg_timer.wait_time = 0.5
	dmg_timer.autostart = true
	area.add_child(dmg_timer)
	dmg_timer.timeout.connect(_on_damage_tick.bind(area, wind_wall_damage))
	
	# 3. 寿命
	var life = get_tree().create_timer(wind_wall_duration)
	life.timeout.connect(_on_object_expired.bind(area, vis_line))

# --- 闭环: 暴风领域 (吸向中心 + 伤害) ---
func check_and_trigger_intersection() -> void:
	var polygon_points = find_closing_polygon(path_history)
	if polygon_points.size() > 0:
		call_deferred("_spawn_storm_zone", polygon_points)
		var last = path_history.back()
		path_history.clear()
		path_history.append(last)

func _spawn_storm_zone(points: PackedVector2Array) -> void:
	if points.size() < 3: return
	
	Global.on_camera_shake.emit(10.0, 0.3)
	
	var area = Area2D.new()
	area.collision_mask = 2
	area.monitorable = false
	area.monitoring = true
	
	var col = CollisionPolygon2D.new()
	col.polygon = points
	area.add_child(col)
	
	var vis_poly = Polygon2D.new()
	vis_poly.polygon = points
	vis_poly.color = Color(1.0, 1.0, 1.0, 0.0) 
	vis_poly.z_index = 10 
	area.add_child(vis_poly)
	
	get_tree().current_scene.add_child(area)
	Global.spawn_floating_text(points[0], "STORM!", Color.CYAN)
	
	var tween = area.create_tween()
	tween.tween_property(vis_poly, "color", Color(0.2, 1.2, 1.2, 0.5), 0.2).set_trans(Tween.TRANS_QUAD)
	
	var center = Vector2.ZERO
	for p in points: center += p
	center /= points.size()
	
	# 物理 Tick
	var timer = Timer.new()
	timer.wait_time = 0.05
	timer.autostart = true
	area.add_child(timer)
	timer.timeout.connect(_on_storm_zone_tick.bind(area, center))
	
	# 伤害 Tick
	var dmg_timer = Timer.new()
	dmg_timer.wait_time = 0.5
	dmg_timer.autostart = true
	area.add_child(dmg_timer)
	dmg_timer.timeout.connect(_on_damage_tick.bind(area, storm_zone_damage))
	
	var life = get_tree().create_timer(storm_zone_duration)
	life.timeout.connect(_on_object_expired.bind(area, vis_poly))
	
	# 画圈奖励
	await get_tree().process_frame
	_apply_circle_rewards(area, points)

# --- E技能: 暴风眼 (吸向中心 + 伤害) ---
func _spawn_storm_eye(center_pos: Vector2) -> void:
	var area = Area2D.new()
	area.global_position = center_pos
	area.collision_mask = 2
	area.monitorable = false
	area.monitoring = true
	
	var col = CollisionShape2D.new()
	var shape = CircleShape2D.new()
	shape.radius = storm_eye_radius 
	col.shape = shape
	area.add_child(col)
	
	var vis = Polygon2D.new()
	var points = PackedVector2Array()
	var steps = 32
	for i in range(steps):
		var angle = i * TAU / steps
		points.append(Vector2(cos(angle), sin(angle)) * storm_eye_radius)
	
	vis.polygon = points
	vis.color = Color(0.1, 1.2, 1.2, 0.4) 
	vis.z_index = 5 
	area.add_child(vis)
	
	get_tree().current_scene.add_child(area)
	Global.spawn_floating_text(center_pos, "VORTEX!", Color.CYAN)
	
	vis.scale = Vector2.ZERO
	var tween = area.create_tween()
	tween.tween_property(vis, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_BACK)
	
	# 1. 物理 Tick (吸向中心)
	var timer = Timer.new()
	timer.wait_time = 0.05
	timer.autostart = true
	area.add_child(timer)
	timer.timeout.connect(_on_storm_zone_tick.bind(area, center_pos))
	
	# 2. 伤害 Tick (新增)
	var dmg_timer = Timer.new()
	dmg_timer.wait_time = 0.5
	dmg_timer.autostart = true
	area.add_child(dmg_timer)
	dmg_timer.timeout.connect(_on_damage_tick.bind(area, storm_eye_damage))
	
	var life = get_tree().create_timer(storm_eye_duration)
	life.timeout.connect(_on_object_expired.bind(area, vis))

# ==============================================================================
# 6. 回调函数 (物理与伤害 - 修复检测逻辑)
# ==============================================================================

# 风墙物理效果: 将敌人吸附到线段上
func _on_wind_wall_tick(area_ref, start: Vector2, end: Vector2) -> void:
	if not is_instance_valid(area_ref) or area_ref.is_queued_for_deletion():
		return
	
	# 【核心修复】同时检测 Bodies 和 Areas
	var targets = area_ref.get_overlapping_bodies() + area_ref.get_overlapping_areas()
	var dt = 0.05 
	
	for t in targets:
		var enemy = null
		if t.is_in_group("enemies"): enemy = t
		elif t.owner and t.owner.is_in_group("enemies"): enemy = t.owner
		
		# 确保敌人对象有效
		if is_instance_valid(enemy):
			var closest_point = Geometry2D.get_closest_point_to_segment(enemy.global_position, start, end)
			var dist = enemy.global_position.distance_to(closest_point)
			
			if dist > 5.0: 
				var dir = (closest_point - enemy.global_position).normalized()
				# 直接修改坐标模拟强力牵引
				enemy.global_position += dir * wind_wall_pull_force * dt

# 暴风区域/暴风眼物理效果: 将敌人吸附到中心点
func _on_storm_zone_tick(area_ref, center: Vector2) -> void:
	if not is_instance_valid(area_ref) or area_ref.is_queued_for_deletion():
		return
	
	# 【核心修复】同时检测 Bodies 和 Areas
	var targets = area_ref.get_overlapping_bodies() + area_ref.get_overlapping_areas()
	var dt = 0.05
	
	for t in targets:
		var enemy = null
		if t.is_in_group("enemies"): enemy = t
		elif t.owner and t.owner.is_in_group("enemies"): enemy = t.owner
		
		if is_instance_valid(enemy):
			var dir = (center - enemy.global_position).normalized()
			enemy.global_position += dir * storm_zone_pull_force * dt

# 伤害回调
func _on_damage_tick(area_ref, amount: int) -> void:
	if not is_instance_valid(area_ref) or area_ref.is_queued_for_deletion():
		return
	var targets = area_ref.get_overlapping_bodies() + area_ref.get_overlapping_areas()
	for t in targets:
		var enemy = null
		if t.is_in_group("enemies"): enemy = t
		elif t.owner and t.owner.is_in_group("enemies"): enemy = t.owner
		if enemy and enemy.has_node("HealthComponent"):
			enemy.health_component.take_damage(amount)

func _on_object_expired(area_ref, visual_ref) -> void:
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

func _cleanup_visual_node(node: Node) -> void:
	if is_instance_valid(node):
		node.queue_free()

# 清理所有技能效果（角色切换时调用）
func _cleanup_skill_effects() -> void:
	# 清理规划线
	if line_2d:
		line_2d.clear_points()
	
	# 重置状态
	is_planning = false
	is_dashing = false
	dash_queue.clear()
	path_history.clear()
	current_target = Vector2.ZERO
	Engine.time_scale = 1.0
	
	print("[PlayerWind] 技能效果已清理")

# 画圈奖励机制
func _apply_circle_rewards(area_ref: Area2D, polygon: PackedVector2Array) -> void:
	if not is_instance_valid(area_ref):
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
	Global.spawn_floating_text(global_position, "TRAPPED x%d" % enemies_in_circle, Color.CYAN)
	
	# 小圈奖励 (1-2个怪)
	if enemies_in_circle >= 1 and enemies_in_circle <= 2:
		var energy_refund = skill_q_cost * 0.8 * 2
		if energy_refund > 0:
			gain_energy(energy_refund)
		Global.spawn_floating_text(global_position, "GOOD!", Color(0.5, 1.0, 0.5))
	
	# 大圈奖励 (10+个怪)
	elif enemies_in_circle >= 10:
		if armor < max_armor:
			armor = min(armor + 3, max_armor)
			armor_changed.emit(armor)
		
		var heal_amount = 0
		if health_component.current_health < health_component.max_health:
			heal_amount = 15
			health_component.current_health = min(health_component.current_health + heal_amount, health_component.max_health)
			health_component.on_health_changed.emit(health_component.current_health, health_component.max_health)
		
		if heal_amount > 0:
			Global.spawn_floating_text(global_position, "+%d HP" % heal_amount, Color.GREEN)
		
		Global.spawn_floating_text(global_position, "DIVINE!", Color(2.0, 2.0, 0.0))
		Global.on_camera_shake.emit(15.0, 0.3)
	
	# 中圈奖励 (3-9个怪)
	else:
		var energy_refund = skill_q_cost * 0.5 * 2
		if energy_refund > 0:
			gain_energy(energy_refund)
		Global.spawn_floating_text(global_position, "PERFECT!", Color(1.0, 1.0, 0.0))

# ==============================================================================
# 7. 几何算法
# ==============================================================================

func find_closing_polygon(points: Array[Vector2]) -> PackedVector2Array:
	if points.size() < 3: return PackedVector2Array()
	var last_point = points.back()
	var last_segment_start = points[points.size() - 2]
	
	for i in range(points.size() - 2):
		var old_pos = points[i]
		
		if last_point.distance_to(old_pos) < close_threshold:
			var poly = PackedVector2Array()
			for j in range(i, points.size()): poly.append(points[j])
			return poly
		
		if i < points.size() - 2:
			var old_next = points[i+1]
			if old_next != last_segment_start:
				var intersection = Geometry2D.segment_intersects_segment(last_segment_start, last_point, old_pos, old_next)
				if intersection:
					var poly = PackedVector2Array()
					poly.append(intersection)
					for j in range(i + 1, points.size() - 1): poly.append(points[j])
					poly.append(intersection)
					return poly
	return PackedVector2Array()

func _update_visuals() -> void:
	line_2d.clear_points()
	
	if dash_queue.is_empty() and not is_planning:
		return
	
	var points_to_draw: Array[Vector2] = []
	points_to_draw.append(global_position)
	
	for task in dash_queue:
		if task["is_wind"]:
			points_to_draw.append(task["pos"])
	
	if points_to_draw.size() > 1:
		for p in points_to_draw:
			line_2d.add_point(p)
	
	var poly = find_closing_polygon(points_to_draw)
	
	if poly.size() > 0:
		line_2d.default_color = Color(2.0, 0.1, 0.1, 1.0) # 闭合提示 (高亮红)
	elif energy < skill_q_cost:
		line_2d.default_color = Color(0.5, 0.5, 0.5, 0.5)
	else:
		line_2d.default_color = Color(0.2, 1.5, 1.5, 1.0) 
	
	if is_planning:
		var start = global_position
		if dash_queue.size() > 0: 
			var last_task = dash_queue.back()
			if last_task["is_wind"]:
				start = last_task["pos"]
		
		var mouse_dir = (get_global_mouse_position() - start).normalized()
		var preview_pos = start + (mouse_dir * fixed_dash_distance)
		
		line_2d.add_point(preview_pos)
