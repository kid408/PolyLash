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
# 【重要】磁吸阈值。设得太大会导致还没连上就误判，设太小很难连。60-80比较合适。
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

# 【核心修复】斩杀执行锁。true时绝对禁止触发新的斩杀逻辑
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

var move_dir: Vector2 

# ==============================================================================
# 6. 初始化
# ==============================================================================
func _ready() -> void:
	super._ready()
	line_2d.top_level = true 
	line_2d.clear_points()
	
	fixed_dash_distance = 300.0 
	
	max_energy = 999.0
	max_charges = 999
	energy = max_energy 
	armor = max_armor
	update_ui_signals()
	
	if dash_cooldown_timer:
		dash_cooldown_timer.one_shot = true
	
	print(">>> 玩家就绪 | 算法统一 | 音效后置 <<<")

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
	current_state = State.HERDING
	trail.stop()
	visuals.modulate.a = 1.0
	collision.set_deferred("disabled", false)
	dash_hitbox.set_deferred("monitorable", false)
	dash_hitbox.set_deferred("monitoring", false)

# ==============================================================================
# 12. 几何闭环逻辑 (算法统一核心)
# ==============================================================================

# 【核心重构 1】通用几何检测函数
# 输入：待检测点(candidate_point)，历史路径(check_history)
# 输出：如果闭合，返回多边形点集；否则返回空数组
# 作用：视觉检测和实际运行检测都调用这个函数，保证逻辑绝对一致！
func find_closing_polygon(candidate_point: Vector2, check_history: Array[Vector2]) -> PackedVector2Array:
	if check_history.size() < 2: return PackedVector2Array()
	
	# 倒序遍历，找最近的闭合点
	for i in range(check_history.size() - 1):
		var old_pos = check_history[i]
		
		# 1. 磁吸检测
		if candidate_point.distance_to(old_pos) < close_threshold:
			var poly = PackedVector2Array()
			# 从旧点开始，一直加到最后
			for j in range(i, check_history.size()):
				poly.append(check_history[j])
			# 把当前点也加上
			poly.append(candidate_point) 
			return poly
			
		# 2. 交叉检测
		if i < check_history.size() - 1:
			var old_next = check_history[i+1]
			# 当前这笔画是: history的最后一个点 -> candidate_point
			var current_start = check_history.back()
			
			# 防止与相邻线段检测 (必然相交于端点)
			if old_next != current_start:
				var intersection = Geometry2D.segment_intersects_segment(current_start, candidate_point, old_pos, old_next)
				if intersection:
					var poly = PackedVector2Array()
					poly.append(intersection) # 交点作为起点
					for j in range(i + 1, check_history.size()):
						poly.append(check_history[j])
					poly.append(intersection) # 闭合回交点
					return poly
					
	return PackedVector2Array()

# 运行时检测 (由 _on_reach_target_point 调用)
func check_and_trigger_intersection() -> void:
	# 【Fix Bug 2】超级锁：如果正在斩杀，直接退出，防止声音重叠
	if is_executing_kill: return
	
	if path_history.size() < 2: return
	
	var current_point = path_history.back()
	# 构造一个排除掉当前点的临时历史 (为了套用通用函数)
	var history_to_check = path_history.slice(0, path_history.size() - 1)
	
	# 调用通用检测
	var polygon_points = find_closing_polygon(current_point, history_to_check)
	
	if polygon_points.size() > 0:
		trigger_geometry_kill(polygon_points)

func trigger_geometry_kill(polygon_points: PackedVector2Array):
	print(">>> 闭环确认！启动斩杀流程 <<<")
	
	# 【Fix Bug 2】立即上锁，动画结束前绝不开锁
	is_executing_kill = true
	
	# 生成遮罩 (立即添加)
	var mask_node = create_geometry_mask_visual(polygon_points)
	
	# 【Fix Bug 3】声音后置
	# 不在这里播放声音，防止“有声音无红圈”的情况
	# 声音将在 Tween 回调中，与红圈变亮同步播放
	
	var tween = create_tween()
	
	# 1. 变红预警 (0.2s)
	tween.tween_property(mask_node, "color:a", 0.8, 0.2).from(0.0)
	
	# 2. 伤害爆发 + 音效 (同步执行)
	tween.tween_callback(func(): 
		if is_instance_valid(mask_node): 
			mask_node.color = Color(2, 2, 2, 1) # 变亮
		
		# 【Fix Bug 3】在这里播放音效！
		# 只有红圈成功变亮了，才会响，解决“没斩杀也响”的问题
		Global.play_loop_kill_impact()
		
		# 执行伤害
		_perform_geometry_damage(polygon_points)
	)
	
	# 3. 停留
	tween.tween_interval(0.15)
	
	# 4. 淡出
	tween.tween_property(mask_node, "color", geometry_mask_color, 0.05)
	tween.tween_property(mask_node, "color:a", 0.0, 0.3)
	
	# 5. 解锁
	tween.tween_callback(func():
		is_executing_kill = false # 【解锁】
		if is_instance_valid(mask_node): mask_node.queue_free()
	)
	
	# 强制解锁保险 (防止Tween被意外杀掉导致死锁)
	get_tree().create_timer(2.0).timeout.connect(func():
		if is_executing_kill:
			is_executing_kill = false
	)

func _perform_geometry_damage(polygon_points: PackedVector2Array):
	Global.on_camera_shake.emit(20.0, 0.5) 
	Global.frame_freeze(0.15, 0.05)
	
	var enemies = get_tree().get_nodes_in_group("enemies")
	var kill_batch = 0
	for enemy in enemies:
		if not is_instance_valid(enemy): continue
		if Geometry2D.is_point_in_polygon(enemy.global_position, polygon_points):
			if enemy.has_node("HealthComponent"):
				enemy.health_component.take_damage(99999) 
				kill_batch += 1
				Global.spawn_floating_text(enemy.global_position, "LOOP KILL!", Color.GOLD)
	print(">>> 闭环伤害结束，击杀数: ", kill_batch)

# ==============================================================================
# 13. 视觉更新 (Fix Bug 1: 视觉与逻辑统一)
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
		
		# --- 变色逻辑 ---
		var final_color = Color.WHITE
		
		if energy < cost_per_segment:
			final_color = Color(0.5, 0.5, 0.5, 0.5)
		
		# 【核心重构】使用 check_and_trigger_intersection 同款逻辑进行检测
		# 只有当 dash_queue 中的线确实构成了闭环，才变红
		elif is_queue_closing_visual():
			final_color = Color(1.0, 0.0, 0.0, 1.0)
			
		line_2d.default_color = final_color
		line_2d.add_point(preview_pos)

# 视觉层检测：模拟 path_history + dash_queue 的组合
func is_queue_closing_visual() -> bool:
	# 构造一个“假设已经跑完所有点”的历史数组
	# 包含：当前真实位置 + 队列里所有已确认的点
	var simulated_history: Array[Vector2] = []
	simulated_history.append(global_position)
	simulated_history.append_array(dash_queue)
	
	if simulated_history.size() < 3: return false
	
	var last_point = simulated_history.back()
	var history_before_last = simulated_history.slice(0, simulated_history.size() - 1)
	
	# 调用那个【通用函数】，看能不能返回有效的多边形
	var poly = find_closing_polygon(last_point, history_before_last)
	
	# 如果数组不为空，说明形成闭环了 -> 变红
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
	get_tree().current_scene.add_child(poly_node) # 立即添加
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
