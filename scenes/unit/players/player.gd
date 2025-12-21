extends Unit
class_name Player

# ==============================================================================
# 1. 信号定义
# ==============================================================================
signal energy_changed(current, max_val)
signal armor_changed(current)

# ==============================================================================
# 2. 核心属性
# ==============================================================================
@export_group("Stats")
@export var max_energy: float = 100.0
@export var energy_regen: float = 0.5
@export var max_armor: int = 3

@export_group("Dash Settings")
@export var fixed_dash_distance: float = 800.0 
@export var max_charges: int = 99
@export var dash_speed: float = 1800.0
@export var slow_motion_scale: float = 0.1
@export var dash_base_damage: int = 10
@export var dash_knockback: float = 2.0
@export var geometry_mask_color: Color = Color(1, 0.0, 0.0, 0.6)
@export var close_threshold: float = 60.0 

@export_group("Skill Costs")
@export var cost_per_segment: float = 0.3
@export var cost_explosion: float = 0.5

# ==============================================================================
# 3. 节点引用
# ==============================================================================
@onready var dash_hitbox: HitboxComponent = $DashHitbox
@onready var collision: CollisionShape2D = $CollisionShape2D
@onready var trail: Trail = %Trail
@onready var line_2d: Line2D = $Line2D
@onready var dash_cooldown_timer: Timer = $DashCooldwnTimer 

# ==============================================================================
# 4. 状态变量
# ==============================================================================
enum State { HERDING, DASHING } 
var current_state = State.HERDING

var energy: float = 0.0
var armor: int = 0
var dash_queue: Array[Vector2] = []
var current_target: Vector2 = Vector2.ZERO
var is_planning: bool = false
var kill_count: int = 0
var path_history: Array[Vector2] = []
var current_art_score: float = 1.0

# 斩杀执行锁
var is_executing_kill: bool = false 

var upgrades = {
	"poison_trail": false,
	"closed_loop": true,
	"electric_wall": false,
	"mine": false,
	"decoy": false,
	"cd_reduction": false,
	"corpse_bowling": false
}

@export_group("Skill Scenes")
@export var poison_cloud_scene: PackedScene
@export var mine_scene: PackedScene
@export var decoy_scene: PackedScene
@export var explosion_vfx_scene: PackedScene 

var external_force: Vector2 = Vector2.ZERO
var external_force_decay: float = 10.0 # 阻力，数值越大停得越快

var move_dir: Vector2 

# ==============================================================================
# 6. 初始化
# ==============================================================================
func _ready() -> void:
	super._ready()
	line_2d.top_level = true 
	line_2d.clear_points()
	
	fixed_dash_distance = 300.0 # 你的手感数值
	
	max_energy = 999.0
	max_charges = 999
	energy = max_energy 
	armor = max_armor
	update_ui_signals()
	
	if dash_cooldown_timer:
		dash_cooldown_timer.one_shot = true
	
	print(">>> 玩家就绪 | 循环依赖已修复 | 伤害逻辑正常 <<<")

# ==============================================================================
# 7. 主循环
# ==============================================================================
func _process(delta: float) -> void:
	if Global.game_paused: return
	
	match current_state:
		State.HERDING:
			_handle_herding_logic(delta) 
			_handle_movement(delta)      
		State.DASHING:
			_handle_dashing_logic(delta) 
	# 2. 【新增】应用外部击退力 (无论什么状态都能被击退)
	if external_force.length() > 10.0:
		position += external_force * delta
		# 线性衰减
		external_force = external_force.lerp(Vector2.ZERO, external_force_decay * delta)
	else:
		external_force = Vector2.ZERO
		
	_update_visuals()
	update_rotation()

# ==============================================================================
# 8. 移动控制
# ==============================================================================
func _handle_movement(delta: float) -> void:
	move_dir = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var speed_mod = 0.5 
	if is_planning: speed_mod = 0.2 
	
	position += move_dir * stats.speed * speed_mod * delta
	position.x = clamp(position.x, -1000, 1000)
	position.y = clamp(position.y, -1000, 1000)

# ==============================================================================
# 9. 技能输入
# ==============================================================================
func _handle_herding_logic(delta: float) -> void:
	if not is_planning and energy < max_energy:
		energy += energy_regen * delta
		update_ui_signals()
	_handle_skill_inputs()
	anim_player.play("idle")

func _handle_skill_inputs() -> void:
	if Input.is_action_just_pressed("skill_e"): 
		if energy >= cost_explosion:
			perform_explosion()
		else:
			Global.spawn_floating_text(global_position, "No Energy!", Color.RED)

	if Input.is_action_pressed("skill_q"): 
		if not is_planning:
			enter_planning_mode()
		if Input.is_action_just_pressed("click_left"):
			try_add_path_segment()
		if Input.is_action_just_pressed("click_right"):
			undo_last_point()
	else:
		if is_planning:
			exit_planning_mode_and_dash()
		elif Input.is_action_just_pressed("click_left"):
			if try_add_path_segment(): 
				start_dash_sequence()  

func try_add_path_segment() -> bool:
	if energy >= cost_per_segment:
		add_path_point(get_global_mouse_position())
		consume_energy(cost_per_segment)
		return true
	else:
		Global.on_camera_shake.emit(2.0, 0.1)
		return false

# ==============================================================================
# 10. 技能具体实现
# ==============================================================================

# E技能：爆炸
func perform_explosion() -> void:
	consume_energy(cost_explosion)
	Global.on_camera_shake.emit(10.0, 0.3)
	Global.play_player_explosion()
	
	spawn_temp_vfx(explosion_vfx_scene, global_position, 2.0)
	create_explosion_range_visual(200.0)
	
	var damage_amount = 100 
	var enemies = get_tree().get_nodes_in_group("enemies")
	for enemy in enemies:
		if global_position.distance_to(enemy.global_position) < 200.0:
			if enemy.has_method("apply_knockback"):
				var dir = (enemy.global_position - global_position).normalized()
				enemy.apply_knockback(dir, 500.0)
				if enemy.has_node("HealthComponent"):
					enemy.health_component.take_damage(damage_amount)
					Global.spawn_floating_text(enemy.global_position, str(damage_amount), Color.ORANGE)
	
	if armor < max_armor:
		armor += 1
		Global.spawn_floating_text(global_position, "+Armor", Color.CYAN)

# Q技能：规划
func enter_planning_mode() -> void:
	is_planning = true
	Engine.time_scale = slow_motion_scale 

# 松开Q键执行
func exit_planning_mode_and_dash() -> void:
	is_planning = false
	Engine.time_scale = 1.0 
	
	if dash_queue.size() > 0:
		start_dash_sequence()

func add_path_point(mouse_pos: Vector2) -> void:
	var start_pos = global_position
	if dash_queue.size() > 0:
		start_pos = dash_queue.back()
	var direction = (mouse_pos - start_pos).normalized()
	var final_pos = start_pos + (direction * fixed_dash_distance)
	dash_queue.append(final_pos)

func undo_last_point() -> void:
	if dash_queue.size() > 0:
		dash_queue.pop_back()
		energy += cost_per_segment 
		update_ui_signals()

# ==============================================================================
# 11. 冲刺流程
# ==============================================================================
func start_dash_sequence() -> void:
	if dash_queue.is_empty(): return
	
	current_state = State.DASHING
	current_art_score = calculate_art_score_final()
	
	path_history.clear()
	path_history.append(global_position) 
	
	if upgrades["mine"] and mine_scene:
		spawn_temp_vfx(mine_scene, global_position, 10.0)
	
	trail.start_trail()
	visuals.modulate.a = 0.5 
	collision.set_deferred("disabled", true) 
	
	dash_hitbox.set_deferred("monitorable", true)
	dash_hitbox.set_deferred("monitoring", true)
	dash_hitbox.setup(dash_base_damage * current_art_score, false, dash_knockback, self)
	
	Global.play_player_dash()
	current_target = dash_queue.pop_front()

func _handle_dashing_logic(delta: float) -> void:
	Engine.time_scale = 1.0 
	if current_target == Vector2.ZERO: return
	
	if upgrades["poison_trail"] and poison_cloud_scene:
		if Engine.get_frames_drawn() % 8 == 0: 
			spawn_temp_vfx(poison_cloud_scene, global_position, 3.0)
	
	position = position.move_toward(current_target, dash_speed * delta)

	if position.distance_to(current_target) < 10.0:
		_on_reach_target_point()

func _on_reach_target_point() -> void:
	path_history.append(global_position) 
	
	if upgrades["closed_loop"]:
		check_and_trigger_intersection()
		
	if upgrades["decoy"] and decoy_scene:
		spawn_temp_vfx(decoy_scene, global_position, 5.0)

	if dash_queue.size() > 0:
		current_target = dash_queue.pop_front()
	else:
		end_dash_sequence()

func end_dash_sequence() -> void:
	# 兜底检测
	if upgrades["closed_loop"] and not is_executing_kill:
		check_and_trigger_intersection()
	
	current_state = State.HERDING
	trail.stop()
	visuals.modulate.a = 1.0
	collision.set_deferred("disabled", false)
	dash_hitbox.set_deferred("monitorable", false)
	dash_hitbox.set_deferred("monitoring", false)

# ==============================================================================
# 12. 几何闭环逻辑 (核心修复区)
# ==============================================================================

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

func check_and_trigger_intersection() -> void:
	if is_executing_kill: return
	
	var polygon_points = find_closing_polygon(path_history)
	
	if polygon_points.size() > 0:
		trigger_geometry_kill(polygon_points)

func trigger_geometry_kill(polygon_points: PackedVector2Array):
	print(">>> 闭环确认！启动斩杀流程 <<<")
	
	is_executing_kill = true
	
	var mask_node = create_geometry_mask_visual(polygon_points)
	
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(mask_node, "color:a", 0.8, 0.2).from(0.0)
	tween.tween_callback(Global.play_loop_kill_impact)
	
	tween.set_parallel(false)
	tween.tween_callback(func(): 
		if is_instance_valid(mask_node): mask_node.color = Color(2, 2, 2, 1)
		_perform_geometry_damage(polygon_points)
	)
	
	tween.tween_interval(0.15)
	tween.tween_property(mask_node, "color", geometry_mask_color, 0.05)
	tween.tween_property(mask_node, "color:a", 0.0, 0.3)
	
	tween.tween_callback(func():
		is_executing_kill = false
		if is_instance_valid(mask_node): mask_node.queue_free()
	)
	
	get_tree().create_timer(3.0).timeout.connect(func():
		if is_executing_kill: is_executing_kill = false
	)

# ==============================================================================
# 核心修复区域：闭环绞杀逻辑
# ==============================================================================
func _perform_geometry_damage(polygon_points: PackedVector2Array):
	print("\n========== [DEBUG] 闭环绞杀计算开始 ==========")
	
	# 1. 检查多边形数据
	if polygon_points.size() < 3:
		print("[Error] 多边形点数不足 3 个，无法构成闭环！当前点数: ", polygon_points.size())
		return
	
	# 打印前3个点，检查坐标量级 (确认是否为 Global 坐标，例如应该是 (500, 300) 而不是 (0, 0))
	print("多边形顶点示例 (前3个): ", polygon_points.slice(0, 3))
	
	Global.on_camera_shake.emit(20.0, 0.5) 
	Global.frame_freeze(0.15, 0.05)
	
	# 2. 获取敌人列表
	var enemies = get_tree().get_nodes_in_group("enemies")
	print("检测到 'enemies' 组内单位数量: ", enemies.size())
	
	if enemies.size() == 0:
		print("[Warning] 没找到任何敌人！请检查 Enemy 脚本 _ready 中是否执行了 add_to_group('enemies')")
		return

	var kill_batch = 0
	
	# 3. 遍历检测
	for enemy in enemies:
		if not is_instance_valid(enemy): 
			continue
		
		var e_pos = enemy.global_position
		# 核心计算：点是否在多边形内
		var is_inside = Geometry2D.is_point_in_polygon(e_pos, polygon_points)
		
		# [DEBUG] 打印每个敌人的判定结果 (建议只在少量敌人时开启，为了不刷屏，只打印在圈内的或者前5个)
		# print("敌人: %s | 位置: %v | 在圈内: %s" % [enemy.name, e_pos, is_inside])
		
		if is_inside:
			print(">>> 命中敌人: %s (Type: %s)" % [enemy.name, enemy.get("enemy_type")])
			
			# 1. 获取敌人类型
			var type_val = enemy.get("enemy_type")
			
			# 2. 刺猬免疫逻辑 (SPIKED = 3)
			if type_val != null and type_val == 3: 
				print("    -> 刺猬免疫，跳过")
				Global.spawn_floating_text(enemy.global_position, "IMMUNE!", Color.GRAY)
				continue 
			
			# 3. 处决逻辑
			if enemy.has_method("destroy_enemy"):
				print("    -> 执行 destroy_enemy()")
				enemy.destroy_enemy() 
				kill_batch += 1
				Global.spawn_floating_text(enemy.global_position, "LOOP KILL!", Color.GOLD)
			elif enemy.has_node("HealthComponent"):
				print("    -> 执行 take_damage(99999)")
				enemy.health_component.take_damage(99999)
				kill_batch += 1
	
	print("========== [DEBUG] 结束，本次击杀总数: ", kill_batch, " ==========\n")


# ==============================================================================
# 13. 视觉更新
# ==============================================================================
func _update_visuals() -> void:
	if dash_queue.is_empty() and not is_planning:
		line_2d.clear_points()
		return
	
	line_2d.clear_points()
	line_2d.add_point(global_position)
	for p in dash_queue:
		line_2d.add_point(p)
	
	if is_planning:
		var start = global_position
		if dash_queue.size() > 0: start = dash_queue.back()
		
		var mouse_dir = (get_global_mouse_position() - start).normalized()
		var preview_pos = start + (mouse_dir * fixed_dash_distance)
		
		var final_color = Color.WHITE
		if energy < cost_per_segment:
			final_color = Color(0.5, 0.5, 0.5, 0.5)
		elif is_queue_closing_visual():
			final_color = Color(1.0, 0.0, 0.0, 1.0)
			
		line_2d.default_color = final_color
		line_2d.add_point(preview_pos)

func is_queue_closing_visual() -> bool:
	var check_points: Array[Vector2] = []
	check_points.append(global_position)
	check_points.append_array(dash_queue)
	
	var poly = find_closing_polygon(check_points)
	return poly.size() > 0

# ==============================================================================
# 14. 辅助与生命周期
# ==============================================================================

func create_geometry_mask_visual(points: PackedVector2Array) -> Polygon2D:
	var poly_node = Polygon2D.new()
	poly_node.polygon = points
	poly_node.color = geometry_mask_color
	poly_node.color.a = 0.0 
	poly_node.z_index = 100 
	get_tree().current_scene.add_child(poly_node)
	return poly_node

func create_explosion_range_visual(radius: float) -> void:
	var circle_points = PackedVector2Array()
	var steps = 32
	for i in range(steps):
		var angle = i * TAU / steps
		circle_points.append(Vector2(cos(angle), sin(angle)) * radius)
	var circle_node = Polygon2D.new()
	circle_node.polygon = circle_points
	circle_node.color = geometry_mask_color
	circle_node.color.a = 0.6
	circle_node.z_index = 90
	circle_node.global_position = global_position
	get_tree().current_scene.add_child(circle_node)
	var tween = circle_node.create_tween()
	tween.tween_property(circle_node, "color:a", 0.0, 0.4).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	tween.tween_callback(circle_node.queue_free)

func spawn_temp_vfx(scene: PackedScene, pos: Vector2, lifetime: float) -> void:
	if not scene: return
	var vfx = scene.instantiate()
	vfx.global_position = pos
	get_tree().current_scene.call_deferred("add_child", vfx)
	var timer_tween = vfx.create_tween()
	if timer_tween:
		timer_tween.tween_interval(lifetime)
		timer_tween.tween_callback(vfx.queue_free)

func on_enemy_killed(enemy_unit: Unit):
	kill_count += 1
	energy = min(energy + 0.25, max_energy)
	update_ui_signals()
	if upgrades["cd_reduction"] and dash_cooldown_timer:
		var new_time = dash_cooldown_timer.time_left - 0.5
		dash_cooldown_timer.start(max(0.1, new_time))
	if upgrades["corpse_bowling"]:
		spawn_corpse_bullet(enemy_unit.global_position)

func spawn_corpse_bullet(pos: Vector2): pass
func consume_energy(amount: float) -> void:
	energy -= amount
	update_ui_signals()
func update_ui_signals() -> void:
	energy_changed.emit(energy, max_energy)
func calculate_art_score_final() -> float:
	var segments = path_history.size() + dash_queue.size()
	return 1.0 + (segments * 0.1)
func update_rotation() -> void:
	var facing_dir = Vector2.ZERO
	if current_state == State.DASHING:
		facing_dir = current_target - position
	elif is_planning:
		facing_dir = get_global_mouse_position() - position
	elif move_dir != Vector2.ZERO:
		facing_dir = move_dir
	if facing_dir.x != 0:
		visuals.scale.x = -0.5 if facing_dir.x > 0 else 0.5

func die() -> void:
	Global.play_player_death()
	Engine.time_scale = 0.2
	spawn_death_particles()
	visuals.visible = false
	collision.set_deferred("disabled", true)
	dash_hitbox.set_deferred("monitorable", false)
	await get_tree().create_timer(1.0).timeout

func spawn_death_particles() -> void:
	var emitter = CPUParticles2D.new()
	emitter.emitting = false
	emitter.one_shot = true
	emitter.amount = 30
	emitter.lifetime = 2.0
	emitter.explosiveness = 1.0
	emitter.scale_amount_min = 4.0
	emitter.scale_amount_max = 8.0
	emitter.color = Color.WHITE
	emitter.direction = Vector2(0, -1)
	emitter.spread = 180.0
	emitter.gravity = Vector2(0, 800)
	emitter.initial_velocity_min = 200.0
	emitter.initial_velocity_max = 400.0
	emitter.global_position = global_position
	emitter.z_index = 100
	get_tree().current_scene.add_child(emitter)
	emitter.emitting = true

# 【新增】剪刀手切线逻辑
func try_break_line(enemy_pos: Vector2, radius: float) -> void:
	# 如果没在规划也没在冲刺队列中，无需切断
	if dash_queue.is_empty():
		return
	
	# 倒序遍历，找到被切断的最早那个点
	# 逻辑：如果敌人碰到了第3个点，那么第3个点及以后的所有点都失效
	for i in range(dash_queue.size()):
		var p = dash_queue[i]
		if p.distance_to(enemy_pos) < radius:
			Global.on_camera_shake.emit(5.0, 0.1)
			Global.spawn_floating_text(p, "SNAP!", Color.RED) # 提示线断了
			
			# 【剪刀手逻辑】
			# 截断数组，只保留被切断点之前的路径
			# slice(开始索引, 结束索引) 不包含结束索引
			dash_queue = dash_queue.slice(0, i)
			
			# 如果正在规划模式，更新视觉
			if is_planning:
				_update_visuals()
				
			return

# ==============================================================================
# 核心修复：受击逻辑 (护甲减伤 -> HealthComponent)
# ==============================================================================
func take_damage(raw_amount: float) -> void:
	# 1. 护甲减伤计算
	# 公式：每层护甲减少 20% 伤害 (3层 = 减伤60%)
	# 如果没有护甲，damage_multiplier 为 1.0 (全额伤害)
	var reduction_per_armor = 0.2
	var damage_multiplier = 1.0 - (clamp(armor, 0, max_armor) * reduction_per_armor)
	
	# 确保至少受到 1 点伤害，或者根据你的需求设定最小伤害
	var final_damage = raw_amount * damage_multiplier
	if final_damage < 1: final_damage = 1
	
	# 2. 视觉反馈
	if armor > 0:
		# 有护甲时的反馈（声音清脆一点）
		Global.spawn_floating_text(global_position, "-%d (Blocked)" % final_damage, Color.CYAN)
		# 扣除护甲 (逻辑：受到攻击掉1层)
		armor -= 1
		armor_changed.emit(armor)
		Global.spawn_floating_text(global_position, "Armor Crack!", Color.YELLOW)
	else:
		# 无护甲时的反馈（声音沉闷肉疼，字变大变红）
		Global.spawn_floating_text(global_position, "-%d !!" % final_damage, Color.RED)
		Global.on_camera_shake.emit(8.0, 0.2) # 没护甲震动更大
	
	# 3. 将计算后的最终伤害传给 HealthComponent
	# HealthComponent 会处理扣血、触发 on_health_changed 和 on_unit_died
	health_component.take_damage(final_damage)
	
	# 受击顿帧
	Global.frame_freeze(0.05, 0.1)

# 3. 【新增】被反伤/撞击时的接口
func apply_knockback_self(force: Vector2) -> void:
	external_force = force
	# 可以在这里加个简单的屏幕震动
	Global.on_camera_shake.emit(5.0, 0.1)
	
