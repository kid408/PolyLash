extends PlayerBase
class_name PlayerButcher

# ==============================================================================
# 1. 屠夫专属设置
# ==============================================================================
@export_group("Butcher Settings")
@export var rift_damage_per_tick: int = 20    # 裂痕持续伤害
@export var rift_duration: float = 5.0        # 裂痕存活时间
@export var kill_zone_radius: float = 250.0   # 死斗场半径
@export var kill_zone_damage: int = 30        # 死斗场秒伤
@export var kill_zone_duration: float = 8.0   
@export var mine_damage: int = 200            # 血肉地雷伤害
@export var mine_trigger_radius: float = 30.0 # 地雷触发半径
@export var pull_force_damage: int = 50       # E技能拉扯伤害
@export var pull_width: float = 60.0          # 【新增】E技能拉扯的判定宽度

@export_group("Dash Settings")
@export var dash_distance: float = 400.0      
@export var dash_speed: float = 2000.0        

@export_group("Skill Costs")
@export var cost_dash: float = 10.0
@export var cost_kill_zone: float = 50.0
@export var cost_ripcord: float = 30.0

# ==============================================================================
# 2. 运行时变量
# ==============================================================================
var active_rifts: Array[Area2D] = []   
var active_kill_zone: Area2D = null    
var is_dashing: bool = false
var dash_target: Vector2 = Vector2.ZERO
var dash_start_pos: Vector2 = Vector2.ZERO

@onready var chain_container: Node2D = Node2D.new()
@onready var trail: Trail = %Trail

func _ready() -> void:
	super._ready()
	add_child(chain_container)
	chain_container.top_level = true 
	print(">>> 屠夫就绪 (Ripcord Fixed)")

func _process_subclass(delta: float) -> void:
	if is_dashing:
		position = position.move_toward(dash_target, dash_speed * delta)
		if position.distance_to(dash_target) < 10.0:
			_end_dash()
	
	_update_chains()

func _handle_input(delta: float) -> void:
	var speed_multiplier = 1.0
	if is_instance_valid(active_kill_zone):
		var dist = global_position.distance_to(active_kill_zone.global_position)
		if dist < kill_zone_radius:
			speed_multiplier = 1.6 
	
	super._handle_input(delta * speed_multiplier)

# ==============================================================================
# 3. 输入技能实现
# ==============================================================================

# --- 左键: 电锯冲袭 ---
func use_dash() -> void:
	if is_dashing or not consume_energy(cost_dash): return
	
	var mouse_pos = get_global_mouse_position()
	var dir = (mouse_pos - global_position).normalized()
	dash_start_pos = global_position
	dash_target = dash_start_pos + dir * dash_distance
	
	is_dashing = true
	collision.set_deferred("disabled", true)
	if trail: trail.start_trail()
	Global.play_player_dash()

func _end_dash() -> void:
	is_dashing = false
	collision.set_deferred("disabled", false)
	if trail: trail.stop()
	_spawn_rift(dash_start_pos, global_position)

# --- Q技能: 死亡角斗场 ---
func charge_skill_q(delta: float) -> void:
	pass

func release_skill_q() -> void:
	if not consume_energy(cost_kill_zone): return
	
	if is_instance_valid(active_kill_zone):
		active_kill_zone.queue_free()
	
	var mouse_pos = get_global_mouse_position()
	active_kill_zone = _create_kill_zone(mouse_pos)
	
	Global.spawn_floating_text(mouse_pos, "KILL ZONE!", Color.DARK_RED)
	Global.on_camera_shake.emit(10.0, 0.3)

# --- E技能: 回拉 (核心修复) ---
func use_skill_e() -> void:
	if active_rifts.is_empty(): return
	if not consume_energy(cost_ripcord): return
	
	Global.on_camera_shake.emit(8.0, 0.2)
	
	var rifts_to_pull = active_rifts.duplicate()
	active_rifts.clear()
	
	# 获取全场敌人一次，优化性能
	var all_enemies = get_tree().get_nodes_in_group("enemies")
	
	for rift in rifts_to_pull:
		if not is_instance_valid(rift): continue
		
		var start_p = rift.global_position
		var end_p = global_position # 拉向玩家
		
		# 1. 【修复】使用几何计算检测路径上的敌人
		# 这种方式比物理射线更宽容，像一个宽激光扫过
		for enemy in all_enemies:
			if not is_instance_valid(enemy): continue
			
			# 计算敌人到[裂痕->玩家]连线的距离
			var closest_point = Geometry2D.get_closest_point_to_segment(enemy.global_position, start_p, end_p)
			var dist = enemy.global_position.distance_to(closest_point)
			
			if dist < pull_width:
				# 2. 拉扯效果
				var tween = create_tween()
				tween.tween_property(enemy, "global_position", global_position, 0.3).set_trans(Tween.TRANS_BACK)
				
				# 造成伤害
				if enemy.has_node("HealthComponent"):
					enemy.health_component.take_damage(pull_force_damage)
					Global.spawn_floating_text(enemy.global_position, "RIP!", Color.RED)

		# 3. 裂痕视觉飞回并销毁
		var rtween = create_tween()
		rtween.tween_property(rift, "global_position", global_position, 0.2).set_ease(Tween.EASE_IN)
		rtween.tween_property(rift, "scale", Vector2.ZERO, 0.1) 
		rtween.tween_callback(rift.queue_free)

# ==============================================================================
# 4. 核心对象生成
# ==============================================================================

func _spawn_rift(start: Vector2, end: Vector2) -> void:
	var rift = Area2D.new()
	rift.global_position = start
	rift.collision_mask = 2
	rift.monitorable = false
	rift.monitoring = true
	
	var col = CollisionShape2D.new()
	var shape = SegmentShape2D.new()
	shape.a = Vector2.ZERO
	shape.b = end - start
	col.shape = shape
	rift.add_child(col)
	
	var line = Line2D.new()
	line.add_point(Vector2.ZERO)
	line.add_point(end - start)
	line.width = 16.0
	line.default_color = Color(0.8, 0.1, 0.1, 0.8)
	line.begin_cap_mode = Line2D.LINE_CAP_ROUND
	line.end_cap_mode = Line2D.LINE_CAP_ROUND
	rift.add_child(line)
	
	get_tree().current_scene.add_child(rift)
	active_rifts.append(rift)
	
	var damage_timer = Timer.new()
	damage_timer.wait_time = 0.5
	damage_timer.autostart = true
	rift.add_child(damage_timer)
	
	damage_timer.timeout.connect(func():
		if not is_instance_valid(rift): return
		var targets = rift.get_overlapping_bodies() + rift.get_overlapping_areas()
		for t in targets:
			var enemy = null
			if t.is_in_group("enemies"): enemy = t
			elif t.owner and t.owner.is_in_group("enemies"): enemy = t.owner
			
			if enemy and enemy.has_node("HealthComponent"):
				enemy.health_component.take_damage(rift_damage_per_tick)
	)
	
	get_tree().create_timer(rift_duration).timeout.connect(func():
		if is_instance_valid(rift):
			active_rifts.erase(rift)
			rift.queue_free()
	)

func _create_kill_zone(center_pos: Vector2) -> Area2D:
	var zone = Area2D.new()
	zone.global_position = center_pos
	zone.collision_mask = 2
	zone.monitorable = false
	zone.monitoring = true
	
	var col = CollisionShape2D.new()
	var shape = CircleShape2D.new()
	shape.radius = kill_zone_radius
	col.shape = shape
	zone.add_child(col)
	
	var vis = Polygon2D.new()
	var points = PackedVector2Array()
	for i in range(32): points.append(Vector2(cos(i*TAU/32), sin(i*TAU/32)) * kill_zone_radius)
	vis.polygon = points
	vis.color = Color(0.5, 0.0, 0.0, 0.4)
	zone.add_child(vis)
	
	get_tree().current_scene.add_child(zone)
	
	var tick_timer = Timer.new()
	tick_timer.wait_time = 1.0
	tick_timer.autostart = true
	zone.add_child(tick_timer)
	
	tick_timer.timeout.connect(func():
		if not is_instance_valid(zone): return
		var targets = zone.get_overlapping_bodies() + zone.get_overlapping_areas()
		for t in targets:
			var enemy = null
			if t.is_in_group("enemies"): enemy = t
			elif t.owner and t.owner.is_in_group("enemies"): enemy = t.owner
			
			if enemy and enemy.has_node("HealthComponent"):
				enemy.health_component.take_damage(kill_zone_damage)
				Global.spawn_floating_text(enemy.global_position, str(kill_zone_damage), Color.DARK_RED)
	)
	
	var life_timer = get_tree().create_timer(kill_zone_duration)
	life_timer.timeout.connect(func(): 
		if is_instance_valid(zone): 
			var tw = zone.create_tween()
			tw.tween_property(vis, "modulate:a", 0.0, 0.5)
			tw.tween_callback(zone.queue_free)
	)
	
	return zone

# ==============================================================================
# 5. 血肉地雷逻辑
# ==============================================================================

func on_enemy_killed(enemy_unit: Unit) -> void:
	energy = min(energy + 2.0, max_energy)
	update_ui_signals()
	
	if is_instance_valid(active_kill_zone):
		var dist = enemy_unit.global_position.distance_to(active_kill_zone.global_position)
		if dist <= kill_zone_radius:
			_spawn_flesh_mine(enemy_unit.global_position)

func _spawn_flesh_mine(pos: Vector2) -> void:
	var mine = Area2D.new()
	mine.global_position = pos
	mine.collision_mask = 2
	mine.monitorable = false
	mine.monitoring = true
	
	var col = CollisionShape2D.new()
	col.shape = CircleShape2D.new()
	col.shape.radius = mine_trigger_radius
	mine.add_child(col)
	
	# 【修复1】显式命名 Visual 节点
	var vis = Polygon2D.new()
	vis.name = "Visual" 
	var points = PackedVector2Array()
	for i in range(8): points.append(Vector2(cos(i*TAU/8), sin(i*TAU/8)) * (mine_trigger_radius * 0.8))
	vis.polygon = points
	vis.color = Color(0.6, 0.0, 0.0, 1.0)
	mine.add_child(vis)
	
	get_tree().current_scene.add_child(mine)
	Global.spawn_floating_text(pos, "FLESH!", Color.RED)
	
	mine.body_entered.connect(func(body): _explode_flesh_mine(mine))
	mine.area_entered.connect(func(area): 
		if area.owner and area.owner.is_in_group("enemies"):
			_explode_flesh_mine(mine)
		elif area.is_in_group("enemies"):
			_explode_flesh_mine(mine)
	)

func _explode_flesh_mine(mine: Node2D) -> void:
	if not is_instance_valid(mine) or mine.is_queued_for_deletion(): return
	
	Global.on_camera_shake.emit(8.0, 0.1)
	Global.spawn_floating_text(mine.global_position, "SPLAT!", Color.RED)
	
	var explosion_radius = 120.0
	var enemies = get_tree().get_nodes_in_group("enemies")
	
	for e in enemies:
		if e.global_position.distance_to(mine.global_position) < explosion_radius:
			if e.has_node("HealthComponent"):
				e.health_component.take_damage(mine_damage)
	
	# 【修复2】安全获取 Polygon 数据
	var flash = Polygon2D.new()
	if mine.has_node("Visual"):
		flash.polygon = mine.get_node("Visual").polygon
	else:
		# 兜底：如果找不到Visual，画个默认圆
		var temp_points = PackedVector2Array()
		for i in range(8): temp_points.append(Vector2(cos(i*TAU/8), sin(i*TAU/8)) * 20.0)
		flash.polygon = temp_points
		
	flash.global_position = mine.global_position
	flash.scale = Vector2(3, 3)
	flash.color = Color(1, 0, 0, 0.5)
	get_tree().current_scene.add_child(flash)
	
	var tw = flash.create_tween()
	tw.tween_property(flash, "modulate:a", 0.0, 0.2)
	tw.tween_callback(flash.queue_free)
	
	mine.queue_free()

func _update_chains() -> void:
	for c in chain_container.get_children(): c.queue_free()
	if active_rifts.is_empty(): return
	for rift in active_rifts:
		if is_instance_valid(rift):
			var line = Line2D.new()
			line.width = 2.0
			line.default_color = Color(0.5, 0.5, 0.5, 0.5)
			line.add_point(position)
			line.add_point(rift.global_position)
			chain_container.add_child(line)
