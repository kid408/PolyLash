extends PlayerBase
class_name PlayerSapper

# ==============================================================================
# 1. 工兵核心设置 (Sapper Settings)
# ==============================================================================
@export_group("Mine Settings")
@export var mine_damage: int = 150        # 地雷伤害
@export var mine_trigger_radius: float = 20.0 # 触发半径：敌人踩进这个范围才会炸
@export var mine_explosion_radius: float = 120.0 # 爆炸半径：爆炸后波及的范围
@export var mine_density_distance: float = 50.0  # 布雷密度：每隔多少像素放一颗

@export_group("Totem Settings")
@export var totem_duration: float = 8.0
@export var totem_max_health: float = 200.0 # 图腾血量

@export_group("Dash Settings")
@export var fixed_dash_distance: float = 600.0
@export var dash_speed: float = 1500.0
@export var dash_base_damage: int = 20

@export_group("Skill Costs")
@export var cost_per_segment: float = 10.0
@export var cost_totem: float = 40.0
@export var cost_dash: float = 10.0

# 引用
@onready var line_2d: Line2D = $Line2D
@onready var trail: Trail = %Trail

# 运行时状态
var is_dashing: bool = false
var is_planning: bool = false
var dash_queue: Array[Vector2] = []
var current_target: Vector2 = Vector2.ZERO

func _ready() -> void:
	super._ready()
	line_2d.top_level = true
	line_2d.clear_points()
	print(">>> 工兵就绪: 地雷伤害=%d, 爆炸范围=%.1f" % [mine_damage, mine_explosion_radius])

func _process_subclass(delta: float) -> void:
	# 状态保护
	if is_planning and Engine.time_scale > 0.2:
		Engine.time_scale = 0.1
		
	if is_dashing:
		_process_dash_movement(delta)
		
	_update_visuals()

# ==============================================================================
# 2. 输入处理
# ==============================================================================

# 左键: 紧急冲撞
func use_dash() -> void:
	if is_planning:
		_execute_mine_deployment()
		return
	if is_dashing or not consume_energy(cost_dash): return

	# 简单的直线冲刺
	var mouse_pos = get_global_mouse_position()
	var dir = (mouse_pos - global_position).normalized()
	dash_queue.clear()
	dash_queue.append(global_position + dir * fixed_dash_distance)
	
	_start_dash_sequence(false) # false = 不布雷

# Q键: 规划雷区
func charge_skill_q(delta: float) -> void:
	if not is_planning:
		is_planning = true
		Engine.time_scale = 0.1
		
	if Input.is_action_just_pressed("click_left"):
		if consume_energy(cost_per_segment):
			_add_path_point()
	
	if Input.is_action_just_pressed("click_right"):
		_undo_last_point()

# 松开Q: 部署雷区
func release_skill_q() -> void:
	if is_planning:
		_execute_mine_deployment()

# E键: 诱饵图腾
func use_skill_e() -> void:
	if not consume_energy(cost_totem): return
	
	# 生成图腾
	var totem = _create_totem_logic()
	totem.global_position = global_position
	get_tree().current_scene.add_child(totem)
	
	# 嘲讽周围
	var enemies = get_tree().get_nodes_in_group("enemies")
	for e in enemies:
		if e.global_position.distance_to(global_position) < 600.0:
			if e.has_method("set_taunt_target"):
				e.set_taunt_target(totem)
	
	Global.spawn_floating_text(global_position, "Taunt!", Color.GREEN)

# ==============================================================================
# 3. 核心逻辑实现
# ==============================================================================

func _add_path_point() -> void:
	var mouse_pos = get_global_mouse_position()
	var start = global_position
	if not dash_queue.is_empty(): start = dash_queue.back()
	var dir = (mouse_pos - start).normalized()
	dash_queue.append(start + dir * fixed_dash_distance)

func _undo_last_point() -> void:
	if not dash_queue.is_empty():
		dash_queue.pop_back()
		energy += cost_per_segment
		update_ui_signals()

# 部署地雷 (核心)
func _execute_mine_deployment() -> void:
	is_planning = false
	Engine.time_scale = 1.0
	
	if dash_queue.is_empty(): return
	
	var start = global_position
	for target_pos in dash_queue:
		_fill_mines_segment(start, target_pos)
		start = target_pos
	
	dash_queue.clear()

# 沿路径插值生成地雷
func _fill_mines_segment(from: Vector2, to: Vector2) -> void:
	var dist = from.distance_to(to)
	# 根据密度计算数量
	var count = int(dist / max(1.0, mine_density_distance))
	
	for i in range(count):
		var t = float(i) / float(max(1, count))
		var pos = from.lerp(to, t)
		call_deferred("_spawn_mine", pos)
	
	call_deferred("_spawn_mine", to)

# 冲刺移动逻辑
func _start_dash_sequence(drop_mines: bool) -> void:
	if dash_queue.is_empty(): return
	is_dashing = true
	if trail: trail.start_trail()
	collision.set_deferred("disabled", true)
	dash_hitbox.set_deferred("monitorable", true)
	dash_hitbox.set_deferred("monitoring", true)
	dash_hitbox.setup(dash_base_damage, false, 2.0, self)
	Global.play_player_dash()
	current_target = dash_queue.pop_front()

func _process_dash_movement(delta: float) -> void:
	Engine.time_scale = 1.0
	if current_target == Vector2.ZERO: return
	position = position.move_toward(current_target, dash_speed * delta)
	if position.distance_to(current_target) < 10.0:
		_end_dash()

func _end_dash() -> void:
	is_dashing = false
	if trail: trail.stop()
	collision.set_deferred("disabled", false)
	dash_hitbox.set_deferred("monitorable", false)
	dash_hitbox.set_deferred("monitoring", false)

# ==============================================================================
# 4. 地雷生成与爆炸逻辑 (重点修复)
# ==============================================================================

func _spawn_mine(pos: Vector2) -> void:
	var mine = Area2D.new()
	mine.global_position = pos
	# 确保能检测到敌人所在的层级 (通常是 Layer 2)
	mine.collision_mask = 2 
	mine.monitorable = false # 地雷本身不阻挡
	mine.monitoring = true   # 主动检测别人
	
	# 触发范围 (踩多近炸)
	var col = CollisionShape2D.new()
	var shape = CircleShape2D.new()
	shape.radius = mine_trigger_radius # 使用变量
	col.shape = shape
	mine.add_child(col)
	
	# 视觉表现
	var vis = ColorRect.new()
	vis.color = Color(1, 0.5, 0) # 橙色
	vis.size = Vector2(10, 10)
	vis.position = Vector2(-5, -5)
	mine.add_child(vis)
	
	get_tree().current_scene.add_child(mine)
	
	# 【核心修复】同时监听 area 和 body，防止漏检测
	# 情况1: 敌人有 Area2D (Hurtbox)
	mine.area_entered.connect(func(area):
		if area.owner and area.owner.is_in_group("enemies"):
			_explode_mine(mine)
		elif area.is_in_group("enemies"): # 兼容没有 owner 的简单结构
			_explode_mine(mine)
	)
	
	# 情况2: 敌人是 CharacterBody2D 本身
	mine.body_entered.connect(func(body):
		if body.is_in_group("enemies"):
			_explode_mine(mine)
	)

# 爆炸逻辑
func _explode_mine(mine: Node2D) -> void:
	# 防止重复爆炸 (因为可能有多个 Hitbox 同时进入)
	if not is_instance_valid(mine) or mine.is_queued_for_deletion(): 
		return
	
	# 1. 寻找爆炸范围内的所有受害者
	# 这里不用 area.get_overlapping，而是手动遍历更稳健
	var enemies = get_tree().get_nodes_in_group("enemies")
	var hit_count = 0
	
	for e in enemies:
		if not is_instance_valid(e): continue
		# 使用爆炸半径变量
		if e.global_position.distance_to(mine.global_position) < mine_explosion_radius:
			if e.has_node("HealthComponent"):
				e.health_component.take_damage(mine_damage) # 使用伤害变量
				hit_count += 1
				
				# 可选：给被炸的敌人施加击退
				if e.has_method("apply_knockback"):
					var dir = (e.global_position - mine.global_position).normalized()
					e.apply_knockback(dir, 300.0)

	if hit_count > 0:
		Global.spawn_floating_text(mine.global_position, "BOOM!", Color.ORANGE)
		Global.on_camera_shake.emit(5.0, 0.1)
	
	# TODO: 实例化一个真正的爆炸特效 Scene
	# var vfx = explosion_scene.instantiate() ...
	
	# 销毁地雷
	mine.queue_free()

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
	
	# 受击盒
	var hurtbox = HurtboxComponent.new()
	var hb_col = CollisionShape2D.new()
	hb_col.shape = shape
	hurtbox.add_child(hb_col)
	hurtbox.collision_layer = 1 
	totem.add_child(hurtbox)
	
	var current_hp = totem_max_health
	
	hurtbox.on_damaged.connect(func(hitbox):
		current_hp -= hitbox.damage
		Global.spawn_floating_text(totem.global_position, str(hitbox.damage), Color.WHITE)
		var tween = totem.create_tween()
		tween.tween_property(vis, "modulate", Color.RED, 0.1)
		tween.tween_property(vis, "modulate", Color.WHITE, 0.1)
		
		if current_hp <= 0:
			_explode_mine(totem)
	)
	
	var timer = Timer.new()
	timer.wait_time = totem_duration
	timer.one_shot = true
	timer.autostart = true
	totem.add_child(timer)
	timer.timeout.connect(func(): if is_instance_valid(totem): _explode_mine(totem))
	
	return totem

func _update_visuals() -> void:
	line_2d.clear_points()
	if is_planning:
		line_2d.add_point(global_position)
		for p in dash_queue: line_2d.add_point(p)
		
		var start = global_position
		if not dash_queue.is_empty(): start = dash_queue.back()
		var mouse = get_global_mouse_position()
		var dir = (mouse - start).normalized()
		line_2d.add_point(start + dir * fixed_dash_distance)
		
		if energy < cost_per_segment:
			line_2d.default_color = Color(0.5, 0.5, 0.5, 0.5)
		else:
			line_2d.default_color = Color(1, 0.8, 0, 0.8)

# 【你要求的函数】检测闭环多边形
# 虽然工兵现在的逻辑主要是不闭环的布雷，但如果你想做“闭环形成电网”，可以用这个
func find_closing_polygon(points: Array[Vector2]) -> PackedVector2Array:
	# 需要至少3个点
	if points.size() < 3: return PackedVector2Array()

	var last_point = points.back()
	var last_segment_start = points[points.size() - 2]
	# 闭合阈值，可以根据需要 export 出来，这里暂时写死 60
	var close_threshold = 60.0 
	
	for i in range(points.size() - 2):
		var old_pos = points[i]
		
		# 1. 首尾吸附检测
		if last_point.distance_to(old_pos) < close_threshold:
			var poly = PackedVector2Array()
			for j in range(i, points.size()):
				poly.append(points[j])
			return poly
			
		# 2. 线段交叉检测
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
