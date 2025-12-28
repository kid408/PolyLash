extends PlayerBase
class_name PlayerWeaver

# ==============================================================================
# 1. 织网者专属设置 (Inspector)
# ==============================================================================
@export_group("Weaver Settings")
@export var web_color: Color = Color(0.6, 0.8, 1.0, 0.8) # 连线颜色
@export var web_damage: int = 50       # 收网时的基础伤害
@export var cut_damage: int = 30       # 线段切割路径上敌人的伤害
@export var anchor_catch_radius: float = 80.0 # 冲刺时捕捉锚点的宽度

@export_group("Trap Settings (E Skill)")
@export var trap_trigger_radius: float = 20.0  # 触发半径：敌人踩多近才会炸 (建议小一点，模仿踩中中心)
@export var trap_effect_radius: float = 150.0  # 爆炸范围：炸开后禁锢周围多大范围的敌人
@export var trap_damage: int = 50              # 地雷伤害
@export var trap_pin_duration: float = 3.0     # 禁锢时间 (秒)

@export_group("Skill Costs")
@export var cost_dash: float = 15.0
@export var cost_weave: float = 30.0   # Q技能消耗
@export var cost_trap: float = 40.0    # E技能消耗

# ==============================================================================
# 2. 运行时变量
# ==============================================================================
var active_anchors: Array[Node2D] = []    # 存储被标记为锚点的敌人

# 连线绘制容器
@onready var web_line_container: Node2D = Node2D.new()

func _ready() -> void:
	super._ready()
	add_child(web_line_container)
	web_line_container.top_level = true
	print(">>> 织网者就绪 | 触发范围:%.1f | 禁锢范围:%.1f" % [trap_trigger_radius, trap_effect_radius])

func _process_subclass(delta: float) -> void:
	_clean_invalid_anchors()
	_update_web_visuals()
	
	if is_dashing:
		position = position.move_toward(dash_target, dash_speed * delta)
		if position.distance_to(dash_target) < 10.0:
			_end_dash()

# ==============================================================================
# 3. 输入技能实现
# ==============================================================================

# --- 左键: 吐丝冲刺 ---
func use_dash() -> void:
	if is_dashing or not consume_energy(cost_dash): return
	
	var mouse_pos = get_global_mouse_position()
	var dir = (mouse_pos - global_position).normalized()
	dash_target = position + dir * dash_distance
	
	is_dashing = true
	collision.set_deferred("disabled", true) 
	Global.play_player_dash()
	
	_scan_enemies_along_path(position, dash_target)

# --- Q技能: 收网 ---
func charge_skill_q(delta: float) -> void:
	pass

func release_skill_q() -> void:
	if active_anchors.size() < 2:
		Global.spawn_floating_text(global_position, "Need Anchors!", Color.GRAY)
		return
		
	if not consume_energy(cost_weave): return
	
	Global.on_camera_shake.emit(10.0, 0.2)
	Global.play_loop_kill_impact()
	
	# 多边形点集
	var poly_points: PackedVector2Array = []
	for anchor in active_anchors:
		poly_points.append(anchor.global_position)
	
	for i in range(active_anchors.size()):
		var current_enemy = active_anchors[i]
		var next_enemy = active_anchors[(i + 1) % active_anchors.size()]
		
		_apply_anchor_effect(current_enemy)
		_apply_cutting_damage(current_enemy.global_position, next_enemy.global_position)

	# 玩家增益
	if Geometry2D.is_point_in_polygon(global_position, poly_points):
		var has_shielded = false
		for anchor in active_anchors:
			if anchor.get("enemy_type") == 2: # SHIELDED
				has_shielded = true
				break
		
		if has_shielded:
			armor = min(armor + 1, max_armor)
			Global.spawn_floating_text(global_position, "Web Shield!", Color.CYAN)
			armor_changed.emit(armor)
		else:
			Global.spawn_floating_text(global_position, "Safe Zone", Color.GREEN)

	_clear_all_anchors()

# --- E技能: 蜘蛛地雷 (核心修改) ---
func use_skill_e() -> void:
	if not consume_energy(cost_trap): return
	
	var trap = _create_trap_object()
	trap.global_position = global_position
	get_tree().current_scene.add_child(trap)
	
	Global.spawn_floating_text(global_position, "Trap Set", Color.GREEN)

# ==============================================================================
# 4. 核心逻辑 (Helper Functions)
# ==============================================================================

func _end_dash() -> void:
	is_dashing = false
	collision.set_deferred("disabled", false)

func _scan_enemies_along_path(start: Vector2, end: Vector2) -> void:
	var enemies = get_tree().get_nodes_in_group("enemies")
	for enemy in enemies:
		if not is_instance_valid(enemy): continue
		var closest = Geometry2D.get_closest_point_to_segment(enemy.global_position, start, end)
		if enemy.global_position.distance_to(closest) < anchor_catch_radius:
			_add_anchor(enemy)

func _add_anchor(enemy: Node2D) -> void:
	if enemy in active_anchors: return
	active_anchors.append(enemy)
	Global.spawn_floating_text(enemy.global_position, "Caught!", Color.WEB_GRAY)
	
	var marker = Polygon2D.new()
	marker.polygon = [Vector2(-10,0), Vector2(0,-10), Vector2(10,0), Vector2(0,10)]
	marker.color = Color(1, 0.2, 0.2, 0.7)
	marker.name = "WebMarker"
	enemy.add_child(marker)

func _apply_anchor_effect(enemy: Node2D) -> void:
	var type = enemy.get("enemy_type")
	if type == 0: 
		if enemy.has_method("destroy_enemy"): enemy.destroy_enemy()
		energy = min(energy + 5.0, max_energy)
		update_ui_signals()
	elif type == 3: 
		if enemy.has_node("HealthComponent"):
			enemy.health_component.take_damage(web_damage * 2) 
		Global.spawn_floating_text(enemy.global_position, "Bleed!", Color.RED)

func _apply_cutting_damage(p1: Vector2, p2: Vector2) -> void:
	var enemies = get_tree().get_nodes_in_group("enemies")
	for enemy in enemies:
		if enemy in active_anchors: continue
		var closest = Geometry2D.get_closest_point_to_segment(enemy.global_position, p1, p2)
		if enemy.global_position.distance_to(closest) < 30.0:
			if enemy.has_node("HealthComponent"):
				enemy.health_component.take_damage(cut_damage)
				Global.spawn_floating_text(enemy.global_position, "Cut!", Color.ORANGE)

func _clear_all_anchors() -> void:
	for enemy in active_anchors:
		if is_instance_valid(enemy) and enemy.has_node("WebMarker"):
			enemy.get_node("WebMarker").queue_free()
	active_anchors.clear()

func _clean_invalid_anchors() -> void:
	active_anchors = active_anchors.filter(func(e): return is_instance_valid(e))

func _update_web_visuals() -> void:
	for c in web_line_container.get_children(): c.queue_free()
	if active_anchors.size() < 2: return
	for i in range(active_anchors.size()):
		var start_node = active_anchors[i]
		var end_node = active_anchors[(i + 1) % active_anchors.size()]
		var line = Line2D.new()
		line.width = 3.0
		line.default_color = web_color
		line.antialiased = true 
		line.add_point(start_node.global_position)
		line.add_point(end_node.global_position)
		web_line_container.add_child(line)

# ==============================================================================
# 5. 地雷逻辑 (核心修复：AOE 禁锢)
# ==============================================================================
func _create_trap_object() -> Area2D:
	var trap = Area2D.new()
	trap.collision_mask = 2 # Enemy Layer
	trap.monitorable = false
	trap.monitoring = true
	
	# 物理形状 (触发范围，可以设置得很小，模拟"踩中中心")
	var col = CollisionShape2D.new()
	var shape = CircleShape2D.new()
	shape.radius = trap_trigger_radius 
	col.shape = shape
	trap.add_child(col)
	
	# 视觉 (显示触发范围)
	var vis = Polygon2D.new()
	var points = PackedVector2Array()
	for i in range(8): points.append(Vector2(cos(i*TAU/8), sin(i*TAU/8)) * trap_trigger_radius)
	vis.polygon = points
	vis.color = Color(0.2, 1.0, 0.2, 0.5) 
	trap.add_child(vis)
	
	# 触发逻辑
	trap.body_entered.connect(func(body): _on_trap_triggered(trap))
	trap.area_entered.connect(func(area): 
		# 只要有敌人碰到触发区，就引爆
		if area.owner and area.owner.is_in_group("enemies"):
			_on_trap_triggered(trap)
		elif area.is_in_group("enemies"):
			_on_trap_triggered(trap)
	)
	
	return trap

# 陷阱触发处理 (AOE)
func _on_trap_triggered(trap: Node2D) -> void:
	if not is_instance_valid(trap) or trap.is_queued_for_deletion(): return
	
	print("地雷触发！范围爆炸！")
	Global.on_camera_shake.emit(5.0, 0.1)
	
	# TODO: [VFX] 这里生成一个巨大的爆炸网特效 (半径 = trap_effect_radius)
	_spawn_web_explosion_visual(trap.global_position)
	
	# 获取所有敌人
	var enemies = get_tree().get_nodes_in_group("enemies")
	var hit_count = 0
	
	for enemy in enemies:
		if not is_instance_valid(enemy): continue
		
		# 计算距离：如果敌人处于爆炸影响范围内
		if enemy.global_position.distance_to(trap.global_position) <= trap_effect_radius:
			hit_count += 1
			
			# 1. 变成锚点 (自动连线)
			if enemy not in active_anchors:
				_add_anchor(enemy)
			
			# 2. 造成伤害
			if enemy.has_node("HealthComponent"):
				enemy.health_component.take_damage(trap_damage)
			
			# 3. 禁锢 (修改 Enemy.can_move)
			if "can_move" in enemy:
				enemy.can_move = false
				Global.spawn_floating_text(enemy.global_position, "STUCK!", Color.YELLOW)
				
				# 恢复计时器 - 使用 WeakRef 避免引用已销毁的对象
				var timer = get_tree().create_timer(trap_pin_duration)
				var enemy_ref = weakref(enemy)
				timer.timeout.connect(func():
					var e = enemy_ref.get_ref()
					if e and is_instance_valid(e) and "can_move" in e:
						e.can_move = true
				)
	
	if hit_count > 0:
		Global.spawn_floating_text(trap.global_position, "WEB EXPLOSION!", Color.GREEN)
	
	trap.queue_free()

# 简单的爆炸视觉反馈
func _spawn_web_explosion_visual(pos: Vector2) -> void:
	var circle = Polygon2D.new()
	var points = PackedVector2Array()
	for i in range(16): points.append(Vector2(cos(i*TAU/16), sin(i*TAU/16)) * trap_effect_radius)
	circle.polygon = points
	circle.color = Color(0.6, 0.8, 1.0, 0.5) # 淡蓝网色
	circle.global_position = pos
	get_tree().current_scene.add_child(circle)
	
	var tween = circle.create_tween()
	tween.tween_property(circle, "scale", Vector2(1.2, 1.2), 0.1)
	tween.tween_property(circle, "modulate:a", 0.0, 0.2)
	tween.tween_callback(_cleanup_visual_node.bind(circle))

func _cleanup_visual_node(node: Node) -> void:
	if is_instance_valid(node):
		node.queue_free()

# 清理所有技能效果（角色切换时调用）
func _cleanup_skill_effects() -> void:
	# 清理所有锚点标记
	_clear_all_anchors()
	
	# 清理连线容器
	if web_line_container:
		for c in web_line_container.get_children():
			c.queue_free()
	
	print("[PlayerWeaver] 技能效果已清理")
