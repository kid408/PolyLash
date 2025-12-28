extends PlayerBase
class_name PlayerSapper

# ==============================================================================
# 1. 工兵核心设置 (Sapper Settings)
# ==============================================================================
@export_group("Mine Settings")
@export var mine_damage: int = 150            # 地雷伤害
@export var mine_trigger_radius: float = 20.0 # 触发半径
@export var mine_explosion_radius: float = 120.0 # 爆炸半径
@export var mine_density_distance: float = 50.0  # 线段布雷密度
@export var mine_area_density: float = 60.0      # 区域布雷密度

@export_group("Totem Settings")
@export var totem_duration: float = 8.0
@export var totem_max_health: float = 200.0 

@export_group("Dash Settings")
@export var fixed_dash_distance: float = 600.0
@export var dash_base_damage: int = 20

@export_group("Skill Costs")
@export var cost_per_segment: float = 10.0
@export var cost_totem: float = 40.0
@export var cost_dash: float = 10.0

# 引用
@onready var line_2d: Line2D = $Line2D

# 运行时状态
var is_planning: bool = false

# 队列: { "pos": Vector2, "lay_mines": bool }
var dash_queue: Array[Dictionary] = []      
var current_target: Vector2 = Vector2.ZERO
var current_lay_mines: bool = false 

var path_history: Array[Vector2] = []
var pending_polygon: PackedVector2Array = []

func _ready() -> void:
	super._ready()
	line_2d.top_level = true
	line_2d.clear_points()
	
	# 确保 trail 引用正确
	if not trail:
		trail = %Trail if has_node("%Trail") else null
	
	print(">>> 工兵就绪 (Area Mine Fix)")

func _process_subclass(delta: float) -> void:
	if is_planning and Engine.time_scale > 0.2:
		Engine.time_scale = 0.1
		
	if is_dashing:
		_process_dash_movement(delta)
		
	_update_visuals()

# ==============================================================================
# 2. 输入处理
# ==============================================================================

func use_dash() -> void:
	if is_planning:
		return
		
	if is_dashing or not consume_energy(cost_dash): return

	var mouse_pos = get_global_mouse_position()
	var dir = (mouse_pos - global_position).normalized()
	var target = global_position + dir * fixed_dash_distance
	
	add_dash_task(target, false) # 冲撞不布雷
	
	pending_polygon.clear()
	_start_dash_sequence()

func charge_skill_q(_delta: float) -> void:
	if not is_planning:
		is_planning = true
		Engine.time_scale = 0.1
		
	if Input.is_action_just_pressed("click_left"):
		if consume_energy(cost_per_segment):
			_add_path_point()
	
	if Input.is_action_just_pressed("click_right"):
		_undo_last_point()

func release_skill_q() -> void:
	if is_planning:
		_execute_mine_deployment()

func use_skill_e() -> void:
	if not consume_energy(cost_totem): return
	
	var totem = _create_totem_logic()
	totem.global_position = global_position
	get_tree().current_scene.add_child(totem)
	
	var enemies = get_tree().get_nodes_in_group("enemies")
	for e in enemies:
		if e.global_position.distance_to(global_position) < 600.0:
			if e.has_method("set_taunt_target"):
				e.set_taunt_target(totem)
	
	Global.spawn_floating_text(global_position, "Taunt!", Color.GREEN)

# ==============================================================================
# 3. 核心逻辑实现
# ==============================================================================

func add_dash_task(pos: Vector2, lay_mines: bool) -> void:
	dash_queue.append({
		"pos": pos,
		"lay_mines": lay_mines
	})

func _add_path_point() -> void:
	var mouse_pos = get_global_mouse_position()
	var start = global_position
	if not dash_queue.is_empty(): 
		start = dash_queue.back()["pos"]
	
	var dir = (mouse_pos - start).normalized()
	var final_pos = start + dir * fixed_dash_distance
	
	add_dash_task(final_pos, true)

func _undo_last_point() -> void:
	if not dash_queue.is_empty():
		dash_queue.pop_back()
		energy += cost_per_segment
		update_ui_signals()

# 部署地雷 (核心逻辑修正)
func _execute_mine_deployment() -> void:
	is_planning = false
	Engine.time_scale = 1.0
	
	if dash_queue.is_empty(): return
	
	pending_polygon.clear()
	
	# 构建路径用于检测
	var full_path: Array[Vector2] = []
	full_path.append(global_position)
	for task in dash_queue:
		full_path.append(task["pos"])
	
	var polygon = find_closing_polygon(full_path)
	
	if polygon.size() > 0:
		# --- 闭环: 区域布雷 ---
		Global.spawn_floating_text(global_position, "LOCKING...", Color.RED)
		pending_polygon = polygon 
		
		# 【关键修改】如果是闭环，取消沿途的布雷任务，只跑路
		# 这样玩家就不会看到“先生成线，再生成面”，而是“跑完圈，瞬间填满面”
		for i in range(dash_queue.size()):
			dash_queue[i]["lay_mines"] = false
			
	else:
		# --- 未闭环: 保持 lay_mines = true ---
		# 沿途布雷会由 _on_reach_target_point 处理
		pass
	
	_start_dash_sequence()

func _start_dash_sequence() -> void:
	if dash_queue.is_empty(): return
	
	is_dashing = true
	
	path_history.clear()
	path_history.append(global_position)
	
	if trail: trail.start_trail()
	collision.set_deferred("disabled", true)
	dash_hitbox.set_deferred("monitorable", true)
	dash_hitbox.set_deferred("monitoring", true)
	dash_hitbox.setup(dash_base_damage, false, 2.0, self)
	
	Global.play_player_dash()
	_pop_next_dash_target()

func _pop_next_dash_target() -> void:
	if dash_queue.size() > 0:
		var task = dash_queue.pop_front()
		current_target = task["pos"]
		current_lay_mines = task["lay_mines"]
	else:
		_end_dash()

func _process_dash_movement(delta: float) -> void:
	Engine.time_scale = 1.0
	if current_target == Vector2.ZERO: return
	
	position = position.move_toward(current_target, dash_speed * delta)
	
	if position.distance_to(current_target) < 10.0:
		_on_reach_target_point()

func _on_reach_target_point() -> void:
	var previous_pos = path_history.back()
	path_history.append(global_position)
	
	# 只有当任务要求布雷时才生成 (闭环时这里为 false，不会生成线)
	if current_lay_mines:
		call_deferred("_fill_mines_segment", previous_pos, global_position)
	
	_pop_next_dash_target()

func _end_dash() -> void:
	is_dashing = false
	
	# 检查是否有闭环区域需要填充
	if pending_polygon.size() > 0:
		Global.spawn_floating_text(global_position, "MINE FIELD!", Color.RED)
		Global.on_camera_shake.emit(10.0, 0.2)
		
		# 【核心修复】使用 duplicate() 复制数据
		# 因为 call_deferred 是下一帧执行，而 pending_polygon.clear() 是立即执行
		# 如果不复制，下一帧执行函数时数组已经是空的了
		call_deferred("_fill_mines_in_polygon", pending_polygon.duplicate())
		
		pending_polygon.clear()
	
	if trail: trail.stop()
	collision.set_deferred("disabled", false)
	dash_hitbox.set_deferred("monitorable", false)
	dash_hitbox.set_deferred("monitoring", false)

# ==============================================================================
# 4. 地雷生成逻辑
# ==============================================================================

func _fill_mines_segment(from: Vector2, to: Vector2) -> void:
	var dist = from.distance_to(to)
	var count = int(dist / max(1.0, mine_density_distance))
	
	for i in range(count):
		var t = float(i) / float(max(1, count))
		var pos = from.lerp(to, t)
		call_deferred("_spawn_mine", pos)
	call_deferred("_spawn_mine", to)

func _fill_mines_in_polygon(polygon: PackedVector2Array) -> void:
	if polygon.is_empty(): return
		
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

func _spawn_mine(pos: Vector2) -> void:
	var mine = Area2D.new()
	mine.global_position = pos
	mine.collision_mask = 2 
	mine.monitorable = false 
	mine.monitoring = true   
	
	var col = CollisionShape2D.new()
	var shape = CircleShape2D.new()
	shape.radius = mine_trigger_radius 
	col.shape = shape
	mine.add_child(col)
	
	var vis = ColorRect.new()
	vis.color = Color(1, 0.2, 0.2) 
	vis.size = Vector2(8, 8)
	vis.position = Vector2(-4, -4)
	mine.add_child(vis)
	
	get_tree().current_scene.add_child(mine)
	
	mine.area_entered.connect(_on_mine_trigger_area.bind(mine))
	mine.body_entered.connect(_on_mine_trigger_body.bind(mine))
	
	# 添加5秒自动爆炸定时器
	var auto_explode_timer = Timer.new()
	auto_explode_timer.wait_time = 5.0
	auto_explode_timer.one_shot = true
	auto_explode_timer.autostart = true
	mine.add_child(auto_explode_timer)
	auto_explode_timer.timeout.connect(_explode_mine.bind(mine))

func _on_mine_trigger_area(area: Area2D, mine: Area2D) -> void:
	if area.owner and area.owner.is_in_group("enemies"):
		_explode_mine(mine)
	elif area.is_in_group("enemies"):
		_explode_mine(mine)

func _on_mine_trigger_body(body: Node2D, mine: Area2D) -> void:
	if body.is_in_group("enemies"):
		_explode_mine(mine)

func _explode_mine(mine: Node2D) -> void:
	if not is_instance_valid(mine) or mine.is_queued_for_deletion(): 
		return
	
	mine.set_deferred("monitoring", false)
	
	var enemies = get_tree().get_nodes_in_group("enemies")
	var hit_count = 0
	
	for e in enemies:
		if not is_instance_valid(e): continue
		if e.global_position.distance_to(mine.global_position) < mine_explosion_radius:
			if e.has_node("HealthComponent"):
				e.health_component.take_damage(mine_damage) 
				hit_count += 1
				if e.has_method("apply_knockback"):
					var dir = (e.global_position - mine.global_position).normalized()
					e.apply_knockback(dir, 300.0)

	if hit_count > 0:
		Global.on_camera_shake.emit(3.0, 0.1)
	
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
	tw.tween_callback(_cleanup_visual_node.bind(flash))
	
	mine.queue_free()

func _cleanup_visual_node(node: Node) -> void:
	if is_instance_valid(node):
		node.queue_free()

# ==============================================================================
# 5. 图腾与辅助函数
# ==============================================================================

func _create_totem_logic() -> Area2D:
	var totem = Area2D.new()
	totem.add_to_group("player") 
	
	var col = CollisionShape2D.new()
	var shape = CircleShape2D.new()
	shape.radius = 30.0
	col.shape = shape
	totem.add_child(col)
	
	var vis = Polygon2D.new()
	vis.polygon = [Vector2(0, -30), Vector2(20, 10), Vector2(-20, 10)]
	vis.color = Color.GREEN
	totem.add_child(vis)
	
	var hurtbox = HurtboxComponent.new()
	var hb_col = CollisionShape2D.new()
	hb_col.shape = shape
	hurtbox.add_child(hb_col)
	hurtbox.collision_layer = 1 
	totem.add_child(hurtbox)
	
	var state = {"hp": totem_max_health}
	
	hurtbox.on_damaged.connect(func(hitbox):
		if not is_instance_valid(totem): return
		state.hp -= hitbox.damage
		Global.spawn_floating_text(totem.global_position, str(hitbox.damage), Color.WHITE)
		var tween = totem.create_tween()
		tween.tween_property(vis, "modulate", Color.RED, 0.1)
		tween.tween_property(vis, "modulate", Color.WHITE, 0.1)
		
		if state.hp <= 0:
			_explode_mine(totem)
	)
	
	var timer = Timer.new()
	timer.wait_time = totem_duration
	timer.one_shot = true
	timer.autostart = true
	totem.add_child(timer)
	
	timer.timeout.connect(_on_totem_expired.bind(totem))
	
	return totem

func _on_totem_expired(totem: Node2D) -> void:
	if is_instance_valid(totem):
		_explode_mine(totem)

func _update_visuals() -> void:
	line_2d.clear_points()
	
	if dash_queue.is_empty() and not is_planning:
		return
		
	var points_to_draw: Array[Vector2] = []
	points_to_draw.append(global_position)
	for task in dash_queue:
		points_to_draw.append(task["pos"])
	
	for p in points_to_draw:
		line_2d.add_point(p)
	
	if is_planning:
		var start = points_to_draw.back()
		var mouse = get_global_mouse_position()
		var dir = (mouse - start).normalized()
		var preview_pos = start + dir * fixed_dash_distance
		line_2d.add_point(preview_pos)
	
	var poly = find_closing_polygon(points_to_draw)
	
	if poly.size() > 0:
		line_2d.default_color = Color(1.0, 0.2, 0.2, 0.8)
	elif energy < cost_per_segment:
		line_2d.default_color = Color(0.5, 0.5, 0.5, 0.5)
	else:
		line_2d.default_color = Color(1.0, 0.8, 0.0, 0.8)

func find_closing_polygon(points: Array[Vector2]) -> PackedVector2Array:
	if points.size() < 3: return PackedVector2Array()

	var last_point = points.back()
	var last_segment_start = points[points.size() - 2]
	
	for i in range(points.size() - 2):
		var old_pos = points[i]
		
		if last_point.distance_to(old_pos) < close_threshold:
			var poly = PackedVector2Array()
			for j in range(i, points.size()):
				poly.append(points[j])
			return poly
			
		if i < points.size() - 2:
			var old_next = points[i+1]
			if old_next != last_segment_start:
				var intersection = Geometry2D.segment_intersects_segment(last_segment_start, last_point, old_pos, old_next)
				if intersection:
					var poly = PackedVector2Array()
					poly.append(intersection)
					for j in range(i + 1, points.size() - 1):
						poly.append(points[j])
					poly.append(intersection)
					return poly
					
	return PackedVector2Array()
