extends PlayerBase
class_name PlayerButcherRefactored

# ==============================================================================
# 屠夫专属技能配置（从CSV无法配置的特殊数值）
# ==============================================================================
@export_group("Butcher Unique Skills")
@export var rift_damage_per_tick: int = 20
@export var rift_duration: float = 5.0
@export var kill_zone_radius: float = 250.0
@export var kill_zone_damage: int = 30
@export var kill_zone_duration: float = 8.0
@export var mine_damage: int = 200
@export var mine_trigger_radius: float = 30.0
@export var pull_force_damage: int = 50
@export var pull_width: float = 60.0

# ==============================================================================
# 运行时状态
# ==============================================================================
var active_rifts: Array[Area2D] = []
var active_kill_zone: Area2D = null

@onready var chain_container: Node2D = Node2D.new()

func _ready() -> void:
	# 设置玩家ID，基类会自动从CSV加载配置
	player_id = "butcher"
	super._ready()
	
	add_child(chain_container)
	chain_container.top_level = true
	print(">>> 屠夫（重构版）就绪")

func _process_subclass(delta: float) -> void:
	# 调用基类的冲刺处理
	super._process_subclass(delta)
	
	# 屠夫特有逻辑
	_update_chains()
	
	# 死斗场内加速
	if is_instance_valid(active_kill_zone):
		var dist = global_position.distance_to(active_kill_zone.global_position)
		if dist < kill_zone_radius:
			# 在死斗场内移动速度提升
			pass

# ==============================================================================
# 冲刺结束回调 - 生成裂痕
# ==============================================================================
func _on_dash_complete() -> void:
	_spawn_rift(dash_start_pos, global_position)

# ==============================================================================
# Q技能: 死亡角斗场
# ==============================================================================
func release_skill_q() -> void:
	if not consume_energy(skill_q_cost): 
		return
	
	if is_instance_valid(active_kill_zone):
		active_kill_zone.queue_free()
	
	var mouse_pos = get_global_mouse_position()
	active_kill_zone = _create_kill_zone(mouse_pos)
	
	Global.spawn_floating_text(mouse_pos, "KILL ZONE!", Color.DARK_RED)
	Global.on_camera_shake.emit(10.0, 0.3)

# ==============================================================================
# E技能: 回拉裂痕
# ==============================================================================
func use_skill_e() -> void:
	if active_rifts.is_empty(): 
		return
	if not consume_energy(skill_e_cost): 
		return
	
	Global.on_camera_shake.emit(8.0, 0.2)
	
	var rifts_to_pull = active_rifts.duplicate()
	active_rifts.clear()
	
	var all_enemies = get_tree().get_nodes_in_group("enemies")
	
	for rift in rifts_to_pull:
		if not is_instance_valid(rift): 
			continue
		
		for child in rift.get_children():
			if child is Timer: 
				child.stop()
		
		var start_p = rift.global_position
		var end_p = global_position
		
		for enemy in all_enemies:
			if not is_instance_valid(enemy): 
				continue
			
			var closest_point = Geometry2D.get_closest_point_to_segment(
				enemy.global_position, start_p, end_p
			)
			var dist = enemy.global_position.distance_to(closest_point)
			
			if dist < pull_width:
				var tween = create_tween()
				tween.tween_property(enemy, "global_position", global_position, 0.3)\
					.set_trans(Tween.TRANS_BACK)
				
				if enemy.has_node("HealthComponent"):
					enemy.health_component.take_damage(pull_force_damage)
					Global.spawn_floating_text(enemy.global_position, "RIP!", Color.RED)
		
		var rtween = create_tween()
		rtween.tween_property(rift, "global_position", global_position, 0.2)\
			.set_ease(Tween.EASE_IN)
		rtween.tween_property(rift, "scale", Vector2.ZERO, 0.1)
		rtween.tween_callback(rift.queue_free)

# ==============================================================================
# 裂痕系统
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
	damage_timer.timeout.connect(_on_rift_damage_tick.bind(rift))
	
	var life_timer = get_tree().create_timer(rift_duration)
	life_timer.timeout.connect(_on_rift_expired.bind(rift))

func _on_rift_damage_tick(rift) -> void:
	if not is_instance_valid(rift) or rift.is_queued_for_deletion(): 
		return
	
	var targets = rift.get_overlapping_bodies() + rift.get_overlapping_areas()
	for t in targets:
		var enemy = null
		if t.is_in_group("enemies"): 
			enemy = t
		elif t.owner and t.owner.is_in_group("enemies"): 
			enemy = t.owner
		
		if enemy and enemy.has_node("HealthComponent"):
			enemy.health_component.take_damage(rift_damage_per_tick)

func _on_rift_expired(rift) -> void:
	if is_instance_valid(rift):
		active_rifts.erase(rift)
		rift.queue_free()

# ==============================================================================
# 死斗场系统
# ==============================================================================
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
	for i in range(32): 
		points.append(
			Vector2(cos(i * TAU / 32), sin(i * TAU / 32)) * kill_zone_radius
		)
	vis.polygon = points
	vis.color = Color(0.5, 0.0, 0.0, 0.4)
	zone.add_child(vis)
	
	get_tree().current_scene.add_child(zone)
	
	var tick_timer = Timer.new()
	tick_timer.wait_time = 1.0
	tick_timer.autostart = true
	zone.add_child(tick_timer)
	tick_timer.timeout.connect(_on_kill_zone_tick.bind(zone))
	
	var life_timer = get_tree().create_timer(kill_zone_duration)
	life_timer.timeout.connect(_on_kill_zone_expired.bind(zone, vis))
	
	return zone

func _on_kill_zone_tick(zone) -> void:
	if not is_instance_valid(zone) or zone.is_queued_for_deletion(): 
		return
	
	var targets = zone.get_overlapping_bodies() + zone.get_overlapping_areas()
	for t in targets:
		var enemy = null
		if t.is_in_group("enemies"): 
			enemy = t
		elif t.owner and t.owner.is_in_group("enemies"): 
			enemy = t.owner
		
		if enemy and enemy.has_node("HealthComponent"):
			enemy.health_component.take_damage(kill_zone_damage)
			Global.spawn_floating_text(
				enemy.global_position, 
				str(kill_zone_damage), 
				Color.DARK_RED
			)

func _on_kill_zone_expired(zone, vis) -> void:
	if is_instance_valid(zone):
		var tw = zone.create_tween()
		if is_instance_valid(vis):
			tw.tween_property(vis, "modulate:a", 0.0, 0.5)
		tw.tween_callback(zone.queue_free)

# ==============================================================================
# 血肉地雷（死斗场内击杀敌人触发）
# ==============================================================================
func on_enemy_killed(enemy_unit: Unit) -> void:
	energy = min(energy + 2.0, max_energy)
	update_ui_signals()
	
	if is_instance_valid(active_kill_zone):
		var dist = enemy_unit.global_position.distance_to(
			active_kill_zone.global_position
		)
		if dist <= kill_zone_radius:
			call_deferred("_spawn_flesh_mine", enemy_unit.global_position)

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
	
	var vis = Polygon2D.new()
	vis.name = "Visual"
	var points = PackedVector2Array()
	for i in range(8): 
		points.append(
			Vector2(cos(i * TAU / 8), sin(i * TAU / 8)) * (mine_trigger_radius * 0.8)
		)
	vis.polygon = points
	vis.color = Color(0.6, 0.0, 0.0, 1.0)
	mine.add_child(vis)
	
	get_tree().current_scene.add_child(mine)
	Global.spawn_floating_text(pos, "FLESH!", Color.RED)
	
	mine.body_entered.connect(_on_mine_body_entered.bind(mine))
	mine.area_entered.connect(_on_mine_area_entered.bind(mine))

func _on_mine_body_entered(_body: Node2D, mine: Area2D) -> void:
	_explode_flesh_mine(mine)

func _on_mine_area_entered(area: Area2D, mine: Area2D) -> void:
	if (area.owner and area.owner.is_in_group("enemies")) or area.is_in_group("enemies"):
		_explode_flesh_mine(mine)

func _explode_flesh_mine(mine: Node2D) -> void:
	if not is_instance_valid(mine) or mine.is_queued_for_deletion():
		return
	
	mine.set_deferred("monitoring", false)
	
	Global.on_camera_shake.emit(8.0, 0.1)
	Global.spawn_floating_text(mine.global_position, "SPLAT!", Color.RED)
	
	var explosion_radius = 120.0
	var enemies = get_tree().get_nodes_in_group("enemies")
	
	for e in enemies:
		if is_instance_valid(e) and \
		   e.global_position.distance_to(mine.global_position) < explosion_radius:
			if e.has_node("HealthComponent"):
				e.health_component.take_damage(mine_damage)
	
	var flash = Polygon2D.new()
	if mine.has_node("Visual"):
		flash.polygon = mine.get_node("Visual").polygon
	else:
		var temp_points = PackedVector2Array()
		for i in range(8): 
			temp_points.append(
				Vector2(cos(i * TAU / 8), sin(i * TAU / 8)) * 20.0
			)
		flash.polygon = temp_points
	
	flash.global_position = mine.global_position
	flash.scale = Vector2(3, 3)
	flash.color = Color(1, 0, 0, 0.5)
	get_tree().current_scene.add_child(flash)
	
	var tw = flash.create_tween()
	tw.tween_property(flash, "modulate:a", 0.0, 0.2)
	tw.tween_callback(flash.queue_free)
	
	mine.queue_free()

# ==============================================================================
# 视觉效果
# ==============================================================================
func _update_chains() -> void:
	for c in chain_container.get_children(): 
		c.queue_free()
	if active_rifts.is_empty(): 
		return
	for rift in active_rifts:
		if is_instance_valid(rift):
			var line = Line2D.new()
			line.width = 2.0
			line.default_color = Color(0.5, 0.5, 0.5, 0.5)
			line.add_point(position)
			line.add_point(rift.global_position)
			chain_container.add_child(line)
