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

# ✅ 捕获的参数（不依赖 player_ref）
var saw_rotation_speed: float = 25.0
var saw_push_radius: float = 120.0
var saw_push_force_value: float = 1000.0
var saw_damage_tick: int = 3
var saw_damage_open: int = 1
var stake_impact_damage: int = 20
var chain_color: Color = Color(0.8, 0.2, 0.2, 0.8)
var saw_hit_radius: float = 80.0
var dismember_damage: int = 200
var saw_max_distance: float = 900.0
var saw_fly_speed: float = 1100.0
var captured_chain_radius: float = 250.0

func setup(
	_points: Array[Vector2],
	_closed: bool,
	_dir: Vector2,
	_player: Node2D,
	_max_distance: float = 900.0,
	_chain_radius_override: float = -1.0
):
	shape_points = _points.duplicate()
	is_closed = _closed
	fly_dir = _dir
	player_ref = _player
	
	print("[SawProjectile] ★★★ setup() 被调用 ★★★")
	print("[SawProjectile] 是否闭合: %s" % is_closed)
	print("[SawProjectile] 飞行方向: %s (角度: %.1f°)" % [fly_dir, rad_to_deg(fly_dir.angle())])
	print("[SawProjectile] 路径点数: %d" % shape_points.size())
	if shape_points.size() > 0:
		print("[SawProjectile] 路径起点: %s, 终点: %s" % [shape_points[0], shape_points[shape_points.size() - 1]])
	
	# ✅ 捕获所有参数，避免运行时依赖 player_ref
	saw_rotation_speed = _player.saw_rotation_speed if "saw_rotation_speed" in _player else 25.0
	if "saw_push_radius" in _player:
		saw_push_radius = float(_player.saw_push_radius)
	elif "saw_hit_radius" in _player:
		saw_push_radius = max(120.0, float(_player.saw_hit_radius) * 1.5)
	elif "saw_push_force" in _player:
		saw_push_radius = clamp(float(_player.saw_push_force) * 0.12, 100.0, 220.0)
	else:
		saw_push_radius = 120.0
	saw_damage_tick = _player.saw_damage_tick if "saw_damage_tick" in _player else 3
	saw_damage_open = _player.saw_damage_open if "saw_damage_open" in _player else 1
	saw_push_force_value = _player.saw_push_force if "saw_push_force" in _player else 1000.0
	stake_impact_damage = _player.stake_impact_damage if "stake_impact_damage" in _player else 20
	chain_color = _player.chain_color if "chain_color" in _player else Color(0.8, 0.2, 0.2, 0.8)
	saw_hit_radius = _player.saw_hit_radius if "saw_hit_radius" in _player else 80.0
	dismember_damage = _player.dismember_damage if "dismember_damage" in _player else 200
	saw_fly_speed = _player.saw_fly_speed if "saw_fly_speed" in _player else 1100.0
	if _chain_radius_override > 0.0:
		captured_chain_radius = _chain_radius_override
	else:
		captured_chain_radius = _player.chain_radius if "chain_radius" in _player else 250.0
	
	# 计算目标位置（飞行终点）
	var max_distance = _max_distance
	if "saw_max_distance" in _player and _max_distance == 900.0:
		# 只有在使用默认值时才从player读取
		max_distance = _player.saw_max_distance
	
	print("[SawProjectile] ★★★ 飞行距离参数: %.0f ★★★" % _max_distance)
	print("[SawProjectile] ★★★ 最终使用距离: %.0f ★★★" % max_distance)
	
	var launch_origin: Vector2 = global_position
	if launch_origin == Vector2.ZERO and is_instance_valid(player_ref):
		launch_origin = player_ref.global_position
	target_pos = launch_origin + fly_dir * max_distance
	
	print("[SawProjectile] 起点: %s" % shape_points[0])
	print("[SawProjectile] 目标位置: %s (距离: %.0f)" % [target_pos, max_distance])
	print("[SawProjectile] 计算距离验证: %.0f" % shape_points[0].distance_to(target_pos))
	
	# 使用捕获的参数
	speed = saw_fly_speed
	chain_radius = captured_chain_radius
	
	z_index = 60
	
	# ✅ 修复：对于未闭合状态，直接使用全局坐标作为本地坐标
	# 这样Line2D保持原始形状，不会因为Node2D旋转而变形
	var local_points = PackedVector2Array()
	
	if is_closed:
		# 闭合状态：计算中心点用于本地坐标（需要旋转）
		var center = Vector2.ZERO
		if not shape_points.is_empty():
			for p in shape_points: 
				center += p
			center /= shape_points.size()
		
		for p in shape_points:
			local_points.append(p - center)
	else:
		# 未闭合状态：使用相对于起点的坐标（不旋转）
		var start_point = shape_points[0]
		for p in shape_points:
			local_points.append(p - start_point)
	
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
		# 闭合状态：旋转锯条
		# rotation 会在 _process_flying 中更新
	else:
		visual_poly.visible = false
		visual_line.closed = false
		visual_line.default_color = Color(1.0, 1.0, 1.0, 0.9)
		visual_line.width = 8.0
		# ✅ 修复：未闭合状态下，不旋转Node2D
		# 这样Line2D保持原始形状，只改变飞行方向
	
	# 创建生命周期计时器
	lifetime_timer = Timer.new()
	lifetime_timer.one_shot = true
	lifetime_timer.timeout.connect(_on_lifetime_end)
	add_child(lifetime_timer)
	
	# 根据闭合状态设置计时器时长
	if is_closed:
		lifetime_timer.wait_time = 8.0  # 闭合状态：8秒
	else:
		lifetime_timer.wait_time = 5.0  # 未闭合状态：5秒（持续伤害时间）
	
	print("[SawProjectile] ★★★ setup() 完成 ★★★")

func _process(delta: float) -> void:
	# ✅ 不再依赖 player_ref 的有效性
	if not is_landed:
		_process_flying(delta)
	else:
		_process_chaining(delta)
		queue_redraw()

func _process_flying(delta: float) -> void:
	# 飞行到目标位置
	var dist = global_position.distance_to(target_pos)
	
	# 调试日志
	print("[SawProjectile] 飞行中: 当前位置=%s, 目标=%s, 距离=%.1f" % [global_position, target_pos, dist])
	
	if dist < 10.0:
		print("[SawProjectile] ★★★ 到达目标，调用 _land() ★★★")
		_land()
		return
	
	var move_step = speed * delta
	if move_step > dist: 
		move_step = dist
	
	# 先移动锯条
	var old_pos = global_position
	global_position += fly_dir * move_step
	
	# 飞行时旋转（只有闭合状态才旋转）
	if is_closed:
		rotation += saw_rotation_speed * delta
	# ✅ 未闭合状态：不旋转，保持原始形状
	
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
	# ✅ 使用捕获的参数
	var push_radius = saw_push_radius
	
	# 获取锯条的所有线段（全局坐标）
	var poly_global = []
	
	# 使用相对于起点的本地坐标，加上Node2D的全局位置
	for p in visual_line.points:
		poly_global.append(global_position + p)
	
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
			var push_strength = max(speed * 1.2, saw_push_force_value)
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
			var damage = saw_damage_tick if is_closed else saw_damage_open
			
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
	
	# 只有闭合状态才重置旋转
	if is_closed:
		rotation = 0
	
	Global.on_camera_shake.emit(10.0, 0.2)
	
	print("[SawProjectile] ★★★ 锯条着陆 ★★★")
	print("[SawProjectile] 着陆位置: %s" % global_position)
	print("[SawProjectile] 是否闭合: %s" % is_closed)
	print("[SawProjectile] 链条半径: %.0f" % chain_radius)
	print("[SawProjectile] 路径点数: %d" % shape_points.size())
	
	# 【修复】非闭合状态：飞到终点后持续伤害5秒再消失
	if not is_closed:
		Global.spawn_floating_text(global_position, "IMPACT!", Color.WHITE)
		print("[SawProjectile] 未闭合锯条着陆，位置: %s，启动生命周期计时器（5秒）" % global_position)
		
		# 未闭合状态：扫描并链接范围内的所有敌人（像"拴小狗"一样）
		var enemies = get_tree().get_nodes_in_group("enemies")
		print("[SawProjectile] 扫描敌人数量: %d" % enemies.size())
		for e in enemies:
			if not is_instance_valid(e): 
				continue
			
			var dist = global_position.distance_to(e.global_position)
			print("[SawProjectile] 敌人 %s 距离: %.0f (链条半径: %.0f)" % [e.name, dist, chain_radius])
			
			# 使用更大的范围检测（chain_radius）
			if dist < chain_radius * 1.2:
				print("[SawProjectile] ✅ 敌人 %s 在范围内，链接" % e.name)
				_chain_enemy(e)
			# 或者检查是否在线段范围内
			elif _is_enemy_inside(e):
				print("[SawProjectile] ✅ 敌人 %s 在线段范围内，链接" % e.name)
				_chain_enemy(e)
		
		print("[SawProjectile] 已链接敌人数量: %d" % chained_enemies.size())
		
		# 启动生命周期计时器（5秒后消失）
		if lifetime_timer:
			lifetime_timer.start()
			print("[SawProjectile] 生命周期计时器已启动（5秒）")
		return
	
	# 闭合状态：钉在那里
	Global.spawn_floating_text(global_position, "LOCKED!", Color.RED)
	print("[SawProjectile] 闭合锯条着陆，位置: %s，启动生命周期计时器（8秒）" % global_position)
	
	# 创建闭合遮罩视觉效果
	_create_butcher_closure_mask()
	
	# 闭合状态：扫描并链接范围内的所有敌人
	var enemies = get_tree().get_nodes_in_group("enemies")
	print("[SawProjectile] 扫描敌人数量: %d" % enemies.size())
	for e in enemies:
		if not is_instance_valid(e): 
			continue
		
		var dist = global_position.distance_to(e.global_position)
		print("[SawProjectile] 敌人 %s 距离: %.0f (链条半径: %.0f)" % [e.name, dist, chain_radius])
		
		# 使用更大的范围检测（chain_radius）
		if dist < chain_radius * 1.2:
			print("[SawProjectile] ✅ 敌人 %s 在范围内，链接" % e.name)
			_chain_enemy(e)
		# 或者检查是否在闭合区域内
		elif _is_enemy_inside(e):
			print("[SawProjectile] ✅ 敌人 %s 在闭合区域内，链接" % e.name)
			_chain_enemy(e)
	
	print("[SawProjectile] 已链接敌人数量: %d" % chained_enemies.size())
	
	# 启动生命周期计时器（只有闭合状态才有）
	if lifetime_timer:
		lifetime_timer.start()
		print("[SawProjectile] 生命周期计时器已启动（8秒）")


func _chain_enemy(enemy: Node2D) -> void:
	# 检查是否已经链接
	for ref in chained_enemies:
		if ref.get_ref() == enemy: 
			print("[SawProjectile] 敌人 %s 已经链接，跳过" % enemy.name)
			return
	
	chained_enemies.append(weakref(enemy))
	Global.spawn_floating_text(enemy.global_position, "TRAPPED!", Color.RED)
	print("[SawProjectile] ✅✅✅ 成功链接敌人: %s" % enemy.name)
	
	# 初始伤害
	if enemy.has_node("HealthComponent"):
		enemy.health_component.take_damage(stake_impact_damage)
		print("[SawProjectile] 对敌人 %s 造成初始伤害: %d" % [enemy.name, stake_impact_damage])


func _process_chaining(delta: float) -> void:
	# 持续伤害（闭合和未闭合都支持）
	tick_timer -= delta
	var can_damage = tick_timer <= 0
	if can_damage: 
		tick_timer = 0.5  # 每0.5秒造成伤害
	
	# 【关键修复】持续扫描新敌人进入范围
	var enemies = get_tree().get_nodes_in_group("enemies")
	
	if is_closed:
		# 闭合状态：链接敌人
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
				if global_position.distance_to(e.global_position) < chain_radius * 1.2 or _is_enemy_inside(e):
					print("[SawProjectile] 新敌人进入范围: %s" % e.name)
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
					print("[SawProjectile] 拉扯敌人 %s 到范围内" % e.name)
				
				# 持续伤害
				if can_damage and e.has_node("HealthComponent"):
					var health_before = e.health_component.current_health
					e.health_component.take_damage(saw_damage_tick)
					
					# 调试：检查是否杀死敌人
					if health_before > 0 and e.health_component.current_health <= 0:
						print("[SawProjectile] ===== 持续伤害杀死敌人 =====")
						print("  敌人名称: ", e.name)
						print("  敌人位置: ", e.global_position)
		
		chained_enemies = valid_chains
		
		if can_damage:
			print("[SawProjectile] 闭合状态持续伤害，当前链接敌人数: %d" % chained_enemies.size())
	else:
		# 未闭合状态：像"拴小狗"一样固定敌人在范围内
		# 扫描新敌人进入范围
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
				if global_position.distance_to(e.global_position) < chain_radius * 1.2 or _is_enemy_inside(e):
					print("[SawProjectile] 新敌人进入范围: %s" % e.name)
					_chain_enemy(e)
		
		# 更新已链接的敌人 - 固定在范围内
		var valid_chains = []
		for ref in chained_enemies:
			var e = ref.get_ref()
			if is_instance_valid(e):
				valid_chains.append(ref)
				
				# 强制固定到范围内（参考E技能）
				if global_position.distance_to(e.global_position) > chain_radius:
					var dir = (e.global_position - global_position).normalized()
					e.global_position = global_position + dir * chain_radius
					print("[SawProjectile] 固定敌人 %s 到范围内" % e.name)
				
				# 持续伤害
				if can_damage and e.has_node("HealthComponent"):
					e.health_component.take_damage(saw_damage_open)
		
		chained_enemies = valid_chains
		
		if can_damage:
			print("[SawProjectile] 未闭合状态持续伤害，当前链接敌人数: %d" % chained_enemies.size())


func _draw() -> void:
	if not is_landed or not is_closed: 
		return
	
	# 绘制链条线（参考E技能）
	for ref in chained_enemies:
		var e = ref.get_ref()
		if is_instance_valid(e):
			draw_line(Vector2.ZERO, to_local(e.global_position), chain_color, 2.0)

func _is_enemy_inside(enemy: Node2D) -> bool:
	var poly_global = []
	
	# 对于未闭合状态，使用相对于起点的本地坐标
	# 需要加上Node2D的全局位置来转换为全局坐标
	for p in visual_line.points:
		poly_global.append(global_position + p)
	
	if is_closed:
		if poly_global.size() < 3: 
			return false
		return Geometry2D.is_point_in_polygon(enemy.global_position, PackedVector2Array(poly_global))
	else:
		# 开放状态：线段检测
		# ✅ 使用捕获的参数
		for i in range(poly_global.size() - 1):
			var p1 = poly_global[i]
			var p2 = poly_global[i+1]
			var closest = Geometry2D.get_closest_point_to_segment(enemy.global_position, p1, p2)
			if enemy.global_position.distance_to(closest) < saw_hit_radius:
				return true
		return false

func _on_lifetime_end() -> void:
	# 8秒后自动消失
	print("[SawProjectile] 生命周期结束，锯条消失，位置: %s" % global_position)
	queue_free()

func manual_dismiss() -> void:
	# 玩家手动按Q消失
	queue_free()

func _check_dismember(enemy: Node2D) -> void:
	# ✅ 不再依赖 player_ref，这个功能可能需要重新设计或移除
	# 暂时保留空函数，避免调用时出错
	pass

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
