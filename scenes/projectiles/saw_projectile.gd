extends Node2D
class_name SawProjectile

var shape_points: Array[Vector2] = []
var is_closed: bool = false
var fly_dir: Vector2
var player_ref: Node2D 

# 飞行阶段
var is_landed: bool = false
var target_pos: Vector2
var speed: float = 0.0

# 固定阶段
var chained_enemies: Array = []
var chain_radius: float = 0.0
var tick_timer: float = 0.0
var lifetime_timer: Timer

# 视觉
var visual_poly: Polygon2D
var visual_line: Line2D

func setup(_points: Array[Vector2], _closed: bool, _dir: Vector2, _player: Node2D):
	shape_points = _points.duplicate()
	is_closed = _closed
	fly_dir = _dir
	player_ref = _player
	
	# 计算目标位置（飞行终点）
	var max_distance = 900.0
	if "saw_max_distance" in player_ref:
		max_distance = player_ref.saw_max_distance
	target_pos = shape_points[0] + fly_dir * max_distance
	
	# 设置速度
	speed = player_ref.saw_fly_speed if "saw_fly_speed" in player_ref else 1100.0
	
	# 设置链条半径（闭合时使用）
	chain_radius = player_ref.chain_radius if "chain_radius" in player_ref else 250.0
	
	z_index = 60
	
	# 计算中心点用于本地坐标
	var center = Vector2.ZERO
	if not shape_points.is_empty():
		for p in shape_points: 
			center += p
		center /= shape_points.size()
	
	var local_points = PackedVector2Array()
	for p in shape_points:
		local_points.append(p - center)
	
	# 创建填充多边形
	visual_poly = Polygon2D.new()
	visual_poly.polygon = local_points
	add_child(visual_poly)
	
	# 创建轮廓线
	visual_line = Line2D.new()
	visual_line.points = local_points
	visual_line.width = 4.0
	add_child(visual_line)
	
	# 根据闭合状态设置视觉
	if is_closed:
		visual_poly.visible = true
		visual_poly.color = Color(0.8, 0.1, 0.1, 0.8)
		visual_line.closed = true
		visual_line.default_color = Color(1.0, 0.6, 0.6, 1.0)
		visual_line.width = 6.0
	else:
		visual_poly.visible = false
		visual_line.closed = false
		visual_line.default_color = Color(1.0, 1.0, 1.0, 0.9)
		visual_line.width = 8.0
		look_at(global_position + fly_dir)
	
	# 创建生命周期计时器（只有闭合状态才需要8秒）
	if is_closed:
		lifetime_timer = Timer.new()
		lifetime_timer.wait_time = 8.0
		lifetime_timer.one_shot = true
		lifetime_timer.timeout.connect(_on_lifetime_end)
		add_child(lifetime_timer)
	else:
		# 非闭合状态不需要计时器，飞到终点就消失
		lifetime_timer = null

func _process(delta: float) -> void:
	if not is_instance_valid(player_ref):
		queue_free()
		return
	
	if not is_landed:
		_process_flying(delta)
	else:
		_process_chaining(delta)
		queue_redraw()

func _process_flying(delta: float) -> void:
	# 飞行到目标位置
	var dist = global_position.distance_to(target_pos)
	if dist < 10.0:
		_land()
		return
	
	var move_step = speed * delta
	if move_step > dist: 
		move_step = dist
	
	# 先移动锯条
	var old_pos = global_position
	global_position += fly_dir * move_step
	
	# 飞行时旋转（如果闭合）
	if is_closed:
		rotation += (player_ref.saw_rotation_speed if "saw_rotation_speed" in player_ref else 25.0) * delta
	
	# 处理敌人
	var enemies = get_tree().get_nodes_in_group("enemies")
	
	if is_closed:
		# 闭合状态：拉扯敌人
		for e in enemies:
			if not is_instance_valid(e): continue
			if not _is_enemy_inside(e): continue
			
			# 拉到锯条中心
			e.global_position = global_position
			
			# 添加到链接列表
			var already_chained = false
			for ref in chained_enemies:
				if ref.get_ref() == e:
					already_chained = true
					break
			
			if not already_chained:
				chained_enemies.append(weakref(e))
				Global.spawn_floating_text(e.global_position, "CAUGHT!", Color.RED)
	else:
		# 非闭合状态：像刮板一样推着敌人走
		_push_enemies_like_blade(old_pos, global_position, delta)
	
	# 飞行时造成伤害
	_damage_enemies_in_path(delta)

func _push_enemies_like_blade(old_pos: Vector2, new_pos: Vector2, delta: float) -> void:
	"""非闭合状态：像刮板一样推着敌人走"""
	var enemies = get_tree().get_nodes_in_group("enemies")
	# ✅ 减小检测半径，从200改为80
	var push_radius = player_ref.saw_push_radius if "saw_push_radius" in player_ref else 80.0
	
	# 获取锯条的所有线段（全局坐标）
	var poly_global = []
	for p in visual_line.points:
		poly_global.append(to_global(p))
	
	if poly_global.size() < 2:
		print("[SawProjectile] 警告：线段数量不足")
		return
	
	var pushed_count = 0
	
	for e in enemies:
		if not is_instance_valid(e): continue
		
		# 检查敌人是否在锯条附近
		var is_near_blade = false
		var closest_point = Vector2.ZERO
		var min_dist = push_radius
		
		# 检查每条线段
		for i in range(poly_global.size() - 1):
			var p1 = poly_global[i]
			var p2 = poly_global[i+1]
			var close_p = Geometry2D.get_closest_point_to_segment(e.global_position, p1, p2)
			var d = e.global_position.distance_to(close_p)
			
			if d < min_dist:
				min_dist = d
				closest_point = close_p
				is_near_blade = true
		
		if is_near_blade:
			pushed_count += 1
			
			# 计算推力方向：主要是飞行方向
			var push_dir = fly_dir
			
			# 强力推动敌人（持续推动，不是瞬间击退）
			var push_strength = speed * 2.0  # 增大推力
			var push_vec = push_dir * push_strength * delta
			e.global_position += push_vec
			
			# 调试输出
			#if pushed_count == 1:  # 只输出第一个敌人，避免刷屏
			#	print("[SawProjectile] 推动敌人: 距离=", min_dist, " 推力=", push_vec.length())
	
	#if pushed_count > 0:
	#	print("[SawProjectile] 本帧推动了 ", pushed_count, " 个敌人")

func _damage_enemies_in_path(delta: float) -> void:
	tick_timer -= delta
	if tick_timer > 0: 
		return
	tick_timer = 0.1
	
	var enemies = get_tree().get_nodes_in_group("enemies")
	for e in enemies:
		if not is_instance_valid(e): 
			continue
		if not _is_enemy_inside(e): 
			continue
		
		if e.has_node("HealthComponent"):
			# 根据闭合状态使用不同伤害
			var damage = 3  # 默认闭合伤害
			if is_closed:
				damage = player_ref.saw_damage_tick if "saw_damage_tick" in player_ref else 3
			else:
				damage = player_ref.saw_damage_open if "saw_damage_open" in player_ref else 1
			
			var health_before = e.health_component.current_health
			e.health_component.take_damage(damage)
			
			# 调试：检查是否杀死敌人
			if health_before > 0 and e.health_component.current_health <= 0:
				print("[SawProjectile] ===== 杀死敌人 =====")
				print("  敌人名称: ", e.name)
				print("  敌人位置: ", e.global_position)
				print("  是否有death_vfx_scene: ", "death_vfx_scene" in e)
				if "death_vfx_scene" in e:
					print("  death_vfx_scene值: ", e.death_vfx_scene)

func _land() -> void:
	is_landed = true
	rotation = 0
	
	Global.on_camera_shake.emit(10.0, 0.2)
	
	# 【修复】非闭合状态：飞到终点就消失
	if not is_closed:
		Global.spawn_floating_text(global_position, "IMPACT!", Color.WHITE)
		queue_free()
		return
	
	# 闭合状态：钉在那里
	Global.spawn_floating_text(global_position, "LOCKED!", Color.RED)
	
	# 创建闭合遮罩视觉效果
	_create_butcher_closure_mask()
	
	# 闭合状态：扫描并链接范围内的所有敌人
	var enemies = get_tree().get_nodes_in_group("enemies")
	for e in enemies:
		if not is_instance_valid(e): 
			continue
		
		# 使用更大的范围检测（chain_radius）
		if global_position.distance_to(e.global_position) < chain_radius:
			_chain_enemy(e)
		# 或者检查是否在闭合区域内
		elif _is_enemy_inside(e):
			_chain_enemy(e)
	
	# 启动生命周期计时器（只有闭合状态才有）
	if lifetime_timer:
		lifetime_timer.start()

func _chain_enemy(enemy: Node2D) -> void:
	# 检查是否已经链接
	for ref in chained_enemies:
		if ref.get_ref() == enemy: 
			return
	
	chained_enemies.append(weakref(enemy))
	Global.spawn_floating_text(enemy.global_position, "TRAPPED!", Color.RED)
	
	# 初始伤害
	if enemy.has_node("HealthComponent"):
		var damage = player_ref.stake_impact_damage if "stake_impact_damage" in player_ref else 20
		enemy.health_component.take_damage(damage)

func _process_chaining(delta: float) -> void:
	if not is_closed:
		return
	
	# 持续伤害
	tick_timer -= delta
	var can_damage = tick_timer <= 0
	if can_damage: 
		tick_timer = 0.5  # 每0.5秒造成伤害
	
	# 【关键修复】持续扫描新敌人进入范围
	var enemies = get_tree().get_nodes_in_group("enemies")
	for e in enemies:
		if not is_instance_valid(e): 
			continue
		
		# 检查是否已经链接
		var already_chained = false
		for ref in chained_enemies:
			if ref.get_ref() == e:
				already_chained = true
				break
		
		# 如果未链接且在范围内，添加链接
		if not already_chained:
			if global_position.distance_to(e.global_position) < chain_radius or _is_enemy_inside(e):
				_chain_enemy(e)
	
	# 更新已链接的敌人
	var valid_chains = []
	for ref in chained_enemies:
		var e = ref.get_ref()
		if is_instance_valid(e):
			valid_chains.append(ref)
			
			# 强制拉扯到范围内（参考E技能）
			if global_position.distance_to(e.global_position) > chain_radius:
				var dir = (e.global_position - global_position).normalized()
				e.global_position = global_position + dir * chain_radius
			
			# 持续伤害
			if can_damage and e.has_node("HealthComponent"):
				var damage = player_ref.saw_damage_tick if "saw_damage_tick" in player_ref else 3
				var health_before = e.health_component.current_health
				e.health_component.take_damage(damage)
				
				# 调试：检查是否杀死敌人
				if health_before > 0 and e.health_component.current_health <= 0:
					print("[SawProjectile] ===== 持续伤害杀死敌人 =====")
					print("  敌人名称: ", e.name)
					print("  敌人位置: ", e.global_position)
	
	chained_enemies = valid_chains

func _draw() -> void:
	if not is_landed or not is_closed: 
		return
	
	# 绘制链条线（参考E技能）
	var chain_color = player_ref.chain_color if "chain_color" in player_ref else Color(0.8, 0.2, 0.2, 0.8)
	for ref in chained_enemies:
		var e = ref.get_ref()
		if is_instance_valid(e):
			draw_line(Vector2.ZERO, to_local(e.global_position), chain_color, 2.0)

func _is_enemy_inside(enemy: Node2D) -> bool:
	var poly_global = []
	for p in visual_line.points:
		poly_global.append(to_global(p))
	
	if is_closed:
		if poly_global.size() < 3: 
			return false
		return Geometry2D.is_point_in_polygon(enemy.global_position, PackedVector2Array(poly_global))
	else:
		# 开放状态：线段检测
		# ✅ 减小检测半径，从200改为80，与push_radius保持一致
		var hit_radius = player_ref.saw_hit_radius if "saw_hit_radius" in player_ref else 80.0
		for i in range(poly_global.size() - 1):
			var p1 = poly_global[i]
			var p2 = poly_global[i+1]
			var closest = Geometry2D.get_closest_point_to_segment(enemy.global_position, p1, p2)
			if enemy.global_position.distance_to(closest) < hit_radius:
				return true
		return false

func _on_lifetime_end() -> void:
	# 8秒后自动消失
	queue_free()

func manual_dismiss() -> void:
	# 玩家手动按Q消失
	queue_free()

func _check_dismember(enemy: Node2D) -> void:
	if not "active_stake" in player_ref or not is_instance_valid(player_ref.active_stake):
		return
	var stake = player_ref.active_stake
	var chain_index = -1
	for i in range(stake.chained_enemies.size()):
		if stake.chained_enemies[i].get_ref() == enemy:
			chain_index = i
			break
	if chain_index != -1:
		Global.play_loop_kill_impact() 
		Global.spawn_floating_text(enemy.global_position, "DISMEMBER!", Color.RED)
		Global.on_camera_shake.emit(15.0, 0.2)
		if enemy.has_node("HealthComponent"):
			var damage = player_ref.dismember_damage if "dismember_damage" in player_ref else 200
			enemy.health_component.take_damage(damage)
		stake.chained_enemies.remove_at(chain_index)

## 创建屠夫闭合遮罩视觉效果
func _create_butcher_closure_mask() -> void:
	# 获取全局坐标的多边形点
	var poly_global = PackedVector2Array()
	for p in visual_line.points:
		poly_global.append(to_global(p))
	
	if poly_global.size() < 3:
		return
	
	var mask = Polygon2D.new()
	mask.polygon = poly_global
	mask.color = Color(1.0, 0.0, 0.0, 0.0)  # 红色
	mask.z_index = 100
	get_tree().current_scene.add_child(mask)
	
	# 动画序列：淡入 -> 闪光 -> 淡出
	var tween = create_tween()
	tween.tween_property(mask, "color:a", 0.7, 0.15)  # 淡入
	tween.tween_property(mask, "color", Color(2.0, 0.5, 0.5, 1.0), 0.1)  # 闪光
	tween.tween_property(mask, "color:a", 0.0, 0.3)  # 淡出
	tween.tween_callback(func():
		if is_instance_valid(mask):
			mask.queue_free()
	)
