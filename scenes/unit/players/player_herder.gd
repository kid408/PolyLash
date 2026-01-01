extends PlayerBase
class_name PlayerHerder

# ==============================================================================
# 牧羊人设置 (这些值现在完全由 Inspector 控制！)
# ==============================================================================
@export_group("Herder Settings")
@export var fixed_dash_distance: float = 600.0  # 默认值
@export var dash_base_damage: int = 10
@export var geometry_mask_color: Color = Color(1, 0.0, 0.0, 0.6)
# 新增：爆炸半径控制
@export var explosion_radius: float = 200.0

@export_group("Skill Costs")
# 注意：技能消耗现在从player_config.csv读取
# cost_per_segment使用skill_q_cost
# cost_explosion使用skill_e_cost

@onready var line_2d: Line2D = $Line2D
@export var explosion_vfx_scene: PackedScene 

var dash_queue: Array[Vector2] = []
var current_target: Vector2 = Vector2.ZERO
var is_planning: bool = false
var path_history: Array[Vector2] = []
var is_executing_kill: bool = false
var upgrades = {"closed_loop": true}

func _ready() -> void:
	super._ready()
	line_2d.top_level = true
	line_2d.clear_points()
	
	# 确保 trail 引用正确
	if not trail:
		trail = %Trail if has_node("%Trail") else null
	
	# ============================================================
	# 【检查点】现在这里只负责打印，绝对不修改数值！
	# ============================================================
	print("----------- 牧羊人数值确认 -----------")
	print("冲撞距离 (Editor值): ", fixed_dash_distance)
	print("Q技能消耗 (CSV值): ", skill_q_cost)
	print("E技能消耗 (CSV值): ", skill_e_cost)
	print("爆炸半径 (Editor值): ", explosion_radius)
	print("------------------------------------")

func _process_subclass(delta: float) -> void:
	if is_dashing:
		_process_dashing_movement(delta)
	
	_update_visuals()
	
	# ========================================================
	# 【核心修复】强制维持子弹时间 (防止被顿帧系统重置)
	# ========================================================
	if is_planning:
		# 如果当前速度大于 0.2 (比如变成了 1.0)，说明被误重置了，强制改回 0.1
		# 为什么不写 != 0.1？ 因为要允许比 0.1 更慢的顿帧 (0.05) 存在，不能打断打击感
		if Engine.time_scale > 0.2:
			Engine.time_scale = 0.1

# 左键: 冲刺/普攻
func use_dash() -> void:
	if is_planning:
		exit_planning_mode_and_dash()
	elif try_add_path_segment():
		start_dash_sequence()

# Q键: 画线 (注意这里是 Q !)
func charge_skill_q(delta: float) -> void:
	if not is_planning:
		enter_planning_mode()
	if Input.is_action_just_pressed("click_left"):
		try_add_path_segment()
	if Input.is_action_just_pressed("click_right"):
		undo_last_point()

func release_skill_q() -> void:
	if is_planning:
		exit_planning_mode_and_dash()

# E键: 爆炸
func use_skill_e() -> void:
	if not consume_energy(skill_e_cost): return
	
	Global.on_camera_shake.emit(10.0, 0.3)
	Global.play_player_explosion()
	
	# 使用变量控制半径
	create_explosion_range_visual(explosion_radius)
	
	var damage_amount = 100 
	var enemies = get_tree().get_nodes_in_group("enemies")
	for enemy in enemies:
		# 使用变量判断距离
		if global_position.distance_to(enemy.global_position) < explosion_radius:
			if enemy.has_method("apply_knockback"):
				var dir = (enemy.global_position - global_position).normalized()
				enemy.apply_knockback(dir, 500.0)
				if enemy.has_node("HealthComponent"):
					enemy.health_component.take_damage(damage_amount)
					Global.spawn_floating_text(enemy.global_position, str(damage_amount), Color.ORANGE)
	
	if armor < max_armor:
		armor += 1
		Global.spawn_floating_text(global_position, "+Armor", Color.CYAN)
		armor_changed.emit(armor)

# --- 内部逻辑 ---

func enter_planning_mode() -> void:
	is_planning = true
	Engine.time_scale = 0.1

func exit_planning_mode_and_dash() -> void:
	is_planning = false
	Engine.time_scale = 1.0
	if dash_queue.size() > 0:
		start_dash_sequence()

func try_add_path_segment() -> bool:
	if consume_energy(skill_q_cost):
		add_path_point(get_global_mouse_position())
		return true
	return false

func add_path_point(mouse_pos: Vector2) -> void:
	var start_pos = global_position
	if dash_queue.size() > 0:
		start_pos = dash_queue.back()
	var direction = (mouse_pos - start_pos).normalized()
	# 使用变量计算位置
	var final_pos = start_pos + (direction * fixed_dash_distance)
	dash_queue.append(final_pos)

func undo_last_point() -> void:
	if dash_queue.size() > 0:
		dash_queue.pop_back()
		energy += skill_q_cost
		update_ui_signals()

func start_dash_sequence() -> void:
	if dash_queue.is_empty(): return
	is_dashing = true
	path_history.clear()
	path_history.append(global_position)
	trail.start_trail()
	visuals.modulate.a = 0.5
	collision.set_deferred("disabled", true)
	dash_hitbox.set_deferred("monitorable", true)
	dash_hitbox.set_deferred("monitoring", true)
	dash_hitbox.setup(dash_base_damage, false, dash_knockback, self)
	Global.play_player_dash()
	current_target = dash_queue.pop_front()

func _process_dashing_movement(delta: float) -> void:
	Engine.time_scale = 1.0
	if current_target == Vector2.ZERO: return
	
	position = position.move_toward(current_target, dash_speed * delta)
	
	if position.distance_to(current_target) < 10.0:
		_on_reach_target_point()

func _on_reach_target_point() -> void:
	path_history.append(global_position)
	if upgrades["closed_loop"]:
		check_and_trigger_intersection()
	if dash_queue.size() > 0:
		current_target = dash_queue.pop_front()
	else:
		end_dash_sequence()

func end_dash_sequence() -> void:
	if upgrades["closed_loop"] and not is_executing_kill:
		check_and_trigger_intersection()
	is_dashing = false
	trail.stop()
	visuals.modulate.a = 1.0
	collision.set_deferred("disabled", false)
	dash_hitbox.set_deferred("monitorable", false)
	dash_hitbox.set_deferred("monitoring", false)

func can_move() -> bool:
	return not is_dashing

# --- 闭环核心逻辑 ---
func try_break_line(enemy_pos: Vector2, radius: float) -> void:
	if dash_queue.is_empty(): return
	for i in range(dash_queue.size()):
		var p = dash_queue[i]
		if p.distance_to(enemy_pos) < radius:
			Global.on_camera_shake.emit(5.0, 0.1)
			Global.spawn_floating_text(p, "SNAP!", Color.RED)
			dash_queue = dash_queue.slice(0, i)
			return

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

func check_and_trigger_intersection() -> void:
	if is_executing_kill: return
	var polygon_points = find_closing_polygon(path_history)
	if polygon_points.size() > 0:
		trigger_geometry_kill(polygon_points)

func trigger_geometry_kill(polygon_points: PackedVector2Array):
	is_executing_kill = true
	var mask_node = create_geometry_mask_visual(polygon_points)
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(mask_node, "color:a", 0.8, 0.2).from(0.0)
	tween.tween_callback(Global.play_loop_kill_impact)
	tween.set_parallel(false)
	tween.tween_callback(_on_geometry_kill_flash.bind(mask_node, polygon_points))
	tween.tween_interval(0.15)
	tween.tween_property(mask_node, "color", geometry_mask_color, 0.05)
	tween.tween_property(mask_node, "color:a", 0.0, 0.3)
	tween.tween_callback(_on_geometry_kill_complete.bind(mask_node))

func _on_geometry_kill_flash(mask_node: Polygon2D, polygon_points: PackedVector2Array) -> void:
	if is_instance_valid(mask_node):
		mask_node.color = Color(2, 2, 2, 1)
	_perform_geometry_damage(polygon_points)

func _on_geometry_kill_complete(mask_node: Polygon2D) -> void:
	is_executing_kill = false
	if is_instance_valid(mask_node):
		mask_node.queue_free()

func _perform_geometry_damage(polygon_points: PackedVector2Array):
	Global.on_camera_shake.emit(20.0, 0.5) 
	var enemies = get_tree().get_nodes_in_group("enemies")
	var kill_count = 0
	
	for enemy in enemies:
		if not is_instance_valid(enemy): continue
		if Geometry2D.is_point_in_polygon(enemy.global_position, polygon_points):
			var type_val = enemy.get("enemy_type")
			if type_val != null and type_val == 3: 
				Global.spawn_floating_text(enemy.global_position, "IMMUNE!", Color.GRAY)
				continue 
			if enemy.has_method("destroy_enemy"):
				enemy.destroy_enemy()
				# 移除单个击杀的飘字，改为在奖励中统一显示
				# Global.spawn_floating_text(enemy.global_position, "LOOP KILL!", Color.GOLD)
				kill_count += 1
	
	# 画圈奖励机制（会显示累积的奖励）
	_apply_circle_rewards(kill_count, polygon_points)

func _update_visuals() -> void:
	# 1. 基础清理
	if dash_queue.is_empty() and not is_planning:
		line_2d.clear_points()
		return
	
	line_2d.clear_points()
	
	# 2. 构建“已确认”的点集 (玩家位置 + 已经点下的冲刺点)
	var confirmed_points: Array[Vector2] = []
	confirmed_points.append(global_position)
	confirmed_points.append_array(dash_queue)
	
	# 3. 绘制已确认的点
	for p in confirmed_points:
		line_2d.add_point(p)
		
	# 4. 【核心修正】颜色判断仅基于“已确认的点”
	var final_color = Color.WHITE
	
	# 这里的 check 只有在 dash_queue 里的点真的构成了闭环时才会返回 true
	var poly = find_closing_polygon(confirmed_points)
	
	if poly.size() > 0:
		# 只有真的形成闭环了，才变红
		final_color = Color(1.0, 0.2, 0.2, 1.0) 
	elif energy < skill_q_cost:
		final_color = Color(0.5, 0.5, 0.5, 0.5)
		
	line_2d.default_color = final_color
	
	# 5. 最后绘制预览线段 (如果正在规划)
	# 这一段只是为了让玩家看到“下一段线去哪”，不参与上面的颜色判断
	if is_planning:
		var start = global_position
		if dash_queue.size() > 0: start = dash_queue.back()
		
		var mouse_dir = (get_global_mouse_position() - start).normalized()
		var preview_pos = start + (mouse_dir * fixed_dash_distance)
		
		line_2d.add_point(preview_pos)

func create_geometry_mask_visual(points: PackedVector2Array) -> Polygon2D:
	var poly_node = Polygon2D.new()
	poly_node.polygon = points
	poly_node.color = geometry_mask_color
	poly_node.color.a = 0.0 
	poly_node.z_index = 100 
	get_tree().current_scene.add_child(poly_node)
	return poly_node

func create_explosion_range_visual(radius: float) -> void:
	var circle_node = Polygon2D.new()
	var points = PackedVector2Array()
	for i in range(32):
		var angle = i * TAU / 32
		points.append(Vector2(cos(angle), sin(angle)) * radius)
	circle_node.polygon = points
	circle_node.color = geometry_mask_color
	circle_node.color.a = 0.6
	circle_node.z_index = 90
	circle_node.global_position = global_position
	get_tree().current_scene.add_child(circle_node)
	var tween = circle_node.create_tween()
	tween.tween_property(circle_node, "color:a", 0.0, 0.4)
	tween.tween_callback(_cleanup_visual_node.bind(circle_node))

func _cleanup_visual_node(node: Node2D) -> void:
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
	is_executing_kill = false
	dash_queue.clear()
	path_history.clear()
	current_target = Vector2.ZERO
	Engine.time_scale = 1.0
	
	print("[PlayerHerder] 技能效果已清理")

# 画圈奖励机制
func _apply_circle_rewards(kill_count: int, polygon: PackedVector2Array) -> void:
	if kill_count <= 0:
		return
	
	# 显示击杀数量
	Global.spawn_floating_text(global_position, "KILLED x%d" % kill_count, Color.GOLD)
	
	# 小圈奖励 (1-2个怪)
	if kill_count >= 1 and kill_count <= 2:
		# 返还80% Q技能能量
		var energy_refund = skill_q_cost * 0.8 * (dash_queue.size() + path_history.size())
		if energy_refund > 0:
			gain_energy(energy_refund)
			# 移除单独的能量飘字，改为在gain_energy中统一显示
		Global.spawn_floating_text(global_position, "GOOD!", Color(0.5, 1.0, 0.5))
		Global.on_camera_shake.emit(5.0, 0.1)
	
	# 大圈奖励 (10+个怪)
	elif kill_count >= 10:
		# 掉落临时Buff：增加5点护甲
		if armor < max_armor:
			armor = min(armor + 5, max_armor)
			armor_changed.emit(armor)
		
		# 恢复一些生命
		var heal_amount = 0
		if health_component.current_health < health_component.max_health:
			heal_amount = 20
			health_component.current_health = min(health_component.current_health + heal_amount, health_component.max_health)
			health_component.on_health_changed.emit(health_component.current_health, health_component.max_health)
		
		# 累积显示回血和回能量
		if heal_amount > 0:
			Global.spawn_floating_text(global_position, "+%d HP" % heal_amount, Color.GREEN)
		
		Global.spawn_floating_text(global_position, "DIVINE!", Color(2.0, 2.0, 0.0))
		Global.on_camera_shake.emit(15.0, 0.3)
	
	# 中圈奖励 (3-9个怪)
	else:
		# 返还50% Q技能能量
		var energy_refund = skill_q_cost * 0.5 * (dash_queue.size() + path_history.size())
		if energy_refund > 0:
			gain_energy(energy_refund)
			# 移除单独的能量飘字，改为在gain_energy中统一显示
		Global.spawn_floating_text(global_position, "PERFECT!", Color(1.0, 1.0, 0.0))
		Global.on_camera_shake.emit(10.0, 0.2)
