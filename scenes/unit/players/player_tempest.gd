extends PlayerBase
class_name PlayerTempest

# ==============================================================================
# 1. 风暴使者专属设置
# ==============================================================================
@export_group("Tempest Settings (Left Click)")
@export var vortex_pull_strength: float = 300.0 # 左键旋风吸力
@export var vortex_duration: float = 2.0        # 左键旋风持续时间
@export var vortex_radius: float = 180.0        # 左键旋风范围

@export_group("Storm Zone (Q Skill)")
# 【修改】默认半径改大，超过左键
@export var storm_radius: float = 250.0         
@export var storm_duration: float = 6.0         
# 【新增】Q技能每0.2秒造成的伤害
@export var storm_damage_per_tick: int = 15     
# 【新增】Q技能的牵引速度 (拽人的力度)
@export var storm_pull_speed: float = 200.0     
@export var lightning_damage: int = 80          # 冲刺触发的额外闪电伤害
@export var lightning_bounce_range: float = 200.0 

@export_group("Gale Blast / Tornado (E Skill)")
@export var tornado_duration: float = 3.0       
@export var tornado_radius: float = 250.0       
@export var tornado_damage_per_tick: int = 20   
@export var tornado_push_force: float = 200.0   

@export_group("Dash Settings")
@export var dash_base_damage: int = 20

@export_group("Skill Costs")
@export var cost_dash: float = 15.0
@export var cost_zone: float = 40.0
@export var cost_blast: float = 30.0

# ==============================================================================
# 2. 运行时变量
# ==============================================================================
var active_storm_zone: Area2D = null

func _ready() -> void:
	super._ready()
	
	# 确保 trail 引用正确
	if not trail:
		trail = %Trail if has_node("%Trail") else null
	
	print(">>> 风暴使者就绪 | Q范围:%.1f | E范围:%.1f" % [storm_radius, tornado_radius])

func _process_subclass(delta: float) -> void:
	if is_dashing:
		position = position.move_toward(dash_target, dash_speed * delta)
		if position.distance_to(dash_target) < 10.0:
			_end_dash()

# ==============================================================================
# 3. 输入技能实现
# ==============================================================================

# --- 左键: 风眼冲刺 ---
func use_dash() -> void:
	if is_dashing or not consume_energy(cost_dash): return
	
	var start_pos = global_position
	var mouse_pos = get_global_mouse_position()
	var dir = (mouse_pos - start_pos).normalized()
	dash_target = start_pos + dir * dash_distance
	
	_spawn_vortex(start_pos)
	
	is_dashing = true
	collision.set_deferred("disabled", true)
	if trail: trail.start_trail()
	
	dash_hitbox.set_deferred("monitorable", true)
	dash_hitbox.set_deferred("monitoring", true)
	dash_hitbox.setup(20, false, 0.0, self) 
	
	Global.play_player_dash()

func _end_dash() -> void:
	is_dashing = false
	collision.set_deferred("disabled", false)
	dash_hitbox.set_deferred("monitorable", false)
	dash_hitbox.set_deferred("monitoring", false)
	if trail: trail.stop()
	
	# 冲刺结束触发闪电链
	if is_instance_valid(active_storm_zone):
		if global_position.distance_to(active_storm_zone.global_position) < storm_radius:
			_trigger_chain_lightning_aoe()

# --- Q技能: 台风眼 (核心修复: 伤害+强吸力) ---
func charge_skill_q(delta: float) -> void:
	pass

func release_skill_q() -> void:
	if not consume_energy(cost_zone): return
	
	if is_instance_valid(active_storm_zone):
		active_storm_zone.queue_free()
	
	# 生成风暴圈
	active_storm_zone = _create_storm_zone(get_global_mouse_position())
	Global.spawn_floating_text(get_global_mouse_position(), "STORM ZONE", Color.CYAN)
	Global.on_camera_shake.emit(5.0, 0.5) # 稍微震动一下表示生成了

# --- E技能: 狂风龙卷 ---
func use_skill_e() -> void:
	if not consume_energy(cost_blast): return
	
	Global.on_camera_shake.emit(10.0, 0.2)
	Global.spawn_floating_text(global_position, "TORNADO!", Color.WHITE)
	Global.play_sfx(preload("res://assets/audio/magical_explosion.wav"), 1.0, 1.5)
	
	_spawn_tornado(global_position)

# ==============================================================================
# 4. 核心对象生成
# ==============================================================================

# 生成左键旋风
func _spawn_vortex(pos: Vector2) -> void:
	var vortex = Area2D.new()
	vortex.global_position = pos
	vortex.collision_mask = 2 # Enemy
	vortex.monitorable = false
	vortex.monitoring = true
	
	var col = CollisionShape2D.new()
	var shape = CircleShape2D.new()
	shape.radius = vortex_radius
	col.shape = shape
	vortex.add_child(col)
	
	# 视觉
	var vis = Polygon2D.new()
	var points = PackedVector2Array()
	for i in range(16): points.append(Vector2(cos(i*TAU/16), sin(i*TAU/16)) * vortex_radius)
	vis.polygon = points
	vis.color = Color(0.0, 0.8, 1.0, 0.3)
	vortex.add_child(vis)
	
	var tween = vortex.create_tween().set_loops()
	tween.tween_property(vis, "rotation", -TAU, 1.0).as_relative()
	
	get_tree().current_scene.add_child(vortex)
	
	# 吸附逻辑
	var pull_timer = Timer.new()
	pull_timer.wait_time = 0.05
	pull_timer.autostart = true
	vortex.add_child(pull_timer)
	
	pull_timer.timeout.connect(func():
		if not is_instance_valid(vortex): return
		var targets = vortex.get_overlapping_bodies() + vortex.get_overlapping_areas()
		for t in targets:
			var enemy = _get_enemy_from_target(t)
			if enemy:
				var dir = (pos - enemy.global_position).normalized()
				enemy.global_position += dir * vortex_pull_strength * 0.05
	)
	
	get_tree().create_timer(vortex_duration).timeout.connect(vortex.queue_free)

# 生成 Q 技能风暴圈 (核心修改)
func _create_storm_zone(center: Vector2) -> Area2D:
	var zone = Area2D.new()
	zone.global_position = center
	zone.collision_mask = 2 + 8 # Enemy + Projectile
	zone.monitorable = false
	zone.monitoring = true
	
	var col = CollisionShape2D.new()
	var shape = CircleShape2D.new()
	shape.radius = storm_radius # 使用更大的半径
	col.shape = shape
	zone.add_child(col)
	
	# 视觉 (加深颜色，显得更有威力)
	var vis = Polygon2D.new()
	var points = PackedVector2Array()
	for i in range(32): points.append(Vector2(cos(i*TAU/32), sin(i*TAU/32)) * storm_radius)
	vis.polygon = points
	vis.color = Color(0.0, 0.3, 0.8, 0.3) # 深蓝色风暴
	zone.add_child(vis)
	
	# 边框
	var line = Line2D.new()
	line.points = points
	line.add_point(points[0])
	line.width = 3.0
	line.default_color = Color(0.2, 0.8, 1.0, 0.9)
	vis.add_child(line)
	
	get_tree().current_scene.add_child(zone)
	
	# 反弹逻辑 (Projectile)
	zone.area_entered.connect(func(area):
		if area.is_in_group("projectiles") or area.get("direction") != null:
			if area.get("is_enemy_projectile") == true: 
				area.direction = -area.direction 
				area.rotation += PI
				area.set("is_enemy_projectile", false)
				area.collision_mask = 2 
				Global.spawn_floating_text(area.global_position, "REFLECT!", Color.CYAN)
	)
	
	# 【核心修复】伤害 + 强力牵引逻辑
	var effect_timer = Timer.new()
	effect_timer.wait_time = 0.1 # 高频刷新 (0.1秒一次)
	effect_timer.autostart = true
	zone.add_child(effect_timer)
	
	effect_timer.timeout.connect(func():
		if not is_instance_valid(zone): return
		var targets = zone.get_overlapping_bodies() + zone.get_overlapping_areas()
		
		# 计数器用于每0.2秒造成伤害 (0.1 * 2)
		# 简单的 trick: 通过时间戳判断是否造成伤害
		var should_damage = int(Time.get_ticks_msec() / 200) % 2 == 0 
		
		for t in targets:
			var enemy = _get_enemy_from_target(t)
			if enemy:
				# 1. 强力牵引 (使用 move_toward)
				# storm_pull_speed 决定吸力大小，delta 模拟约 0.1
				var old_pos = enemy.global_position
				enemy.global_position = old_pos.move_toward(center, storm_pull_speed * 0.1)
				
				# 2. 造成伤害 (如果到了伤害跳数)
				# 另外为了防止每帧都伤，这里使用简单的概率或计数，或者给敌人加无敌帧
				# 简单起见：每次 Timer 触发都造成小额伤害
				if enemy.has_node("HealthComponent"):
					# 这里造成的是每0.1秒的伤害，所以数值要除以频率，或者用 storm_damage_per_tick
					enemy.health_component.take_damage(storm_damage_per_tick * 0.5) 
	)
	
	get_tree().create_timer(storm_duration).timeout.connect(zone.queue_free)
	return zone

# E技能龙卷风
func _spawn_tornado(pos: Vector2) -> void:
	var tornado = Area2D.new()
	tornado.global_position = pos
	tornado.collision_mask = 2 
	tornado.monitorable = false
	tornado.monitoring = true
	
	var col = CollisionShape2D.new()
	var shape = CircleShape2D.new()
	shape.radius = tornado_radius
	col.shape = shape
	tornado.add_child(col)
	
	var vis = Polygon2D.new()
	var points = PackedVector2Array()
	for i in range(16):
		var r = tornado_radius if i % 2 == 0 else tornado_radius * 0.7
		points.append(Vector2(cos(i*TAU/16), sin(i*TAU/16)) * r)
	vis.polygon = points
	vis.color = Color(0.8, 0.9, 1.0, 0.4)
	tornado.add_child(vis)
	
	get_tree().current_scene.add_child(tornado)
	
	var tween = tornado.create_tween().set_loops()
	tween.tween_property(vis, "rotation", TAU, 0.5).as_relative()
	
	var tick_timer = Timer.new()
	tick_timer.wait_time = 0.2 
	tick_timer.autostart = true
	tornado.add_child(tick_timer)
	
	tick_timer.timeout.connect(func():
		if not is_instance_valid(tornado): return
		var targets = tornado.get_overlapping_bodies() + tornado.get_overlapping_areas()
		for t in targets:
			var enemy = _get_enemy_from_target(t)
			if enemy:
				if enemy.has_node("HealthComponent"):
					enemy.health_component.take_damage(tornado_damage_per_tick)
				
				# 持续推开
				var push_dir = (enemy.global_position - pos).normalized()
				enemy.global_position += push_dir * tornado_push_force * 0.1
	)
	
	get_tree().create_timer(tornado_duration).timeout.connect(_on_tornado_expired.bind(tornado, vis))

func _on_tornado_expired(tornado: Area2D, vis: Polygon2D) -> void:
	if is_instance_valid(tornado):
		var end_tween = tornado.create_tween()
		end_tween.tween_property(vis, "scale", Vector2.ZERO, 0.3)
		end_tween.tween_callback(_cleanup_visual_node.bind(tornado))

# 辅助：获取 Enemy 节点
func _get_enemy_from_target(target: Node) -> Node2D:
	if target.is_in_group("enemies"): return target
	if target.owner and target.owner.is_in_group("enemies"): return target.owner
	return null

# ==============================================================================
# 5. 闪电链逻辑 (Buff)
# ==============================================================================

func _trigger_chain_lightning_aoe() -> void:
	var center = global_position
	var enemies = get_tree().get_nodes_in_group("enemies")
	var first_target: Node2D = null
	var min_dist = 9999.0
	
	for e in enemies:
		var d = e.global_position.distance_to(center)
		if d < 300.0 and d < min_dist:
			min_dist = d
			first_target = e
			
	if first_target:
		_chain_lightning_recursive(first_target, 3, [])

func _chain_lightning_recursive(current: Node2D, bounces_left: int, hit_list: Array) -> void:
	if bounces_left <= 0 or not is_instance_valid(current): return
	hit_list.append(current)
	
	if current.has_node("HealthComponent"):
		current.health_component.take_damage(lightning_damage)
		Global.spawn_floating_text(current.global_position, "ZAP!", Color.YELLOW)
	
	var next_target: Node2D = null
	var min_dist = lightning_bounce_range
	var enemies = get_tree().get_nodes_in_group("enemies")
	
	for e in enemies:
		if e in hit_list or not is_instance_valid(e): continue
		var d = e.global_position.distance_to(current.global_position)
		if d < min_dist:
			min_dist = d
			next_target = e
	
	if next_target:
		_draw_lightning(current.global_position, next_target.global_position)
		get_tree().create_timer(0.1).timeout.connect(func():
			_chain_lightning_recursive(next_target, bounces_left - 1, hit_list)
		)

func _draw_lightning(start: Vector2, end: Vector2) -> void:
	var line = Line2D.new()
	line.width = 3.0
	line.default_color = Color(1, 1, 0.2, 1)
	line.add_point(start)
	var mid = (start + end) / 2 + Vector2(randf_range(-20, 20), randf_range(-20, 20))
	line.add_point(mid)
	line.add_point(end)
	get_tree().current_scene.add_child(line)
	var tw = line.create_tween()
	tw.tween_property(line, "modulate:a", 0.0, 0.2)
	tw.tween_callback(_cleanup_visual_node.bind(line))

func _cleanup_visual_node(node: Node) -> void:
	if is_instance_valid(node):
		node.queue_free()
