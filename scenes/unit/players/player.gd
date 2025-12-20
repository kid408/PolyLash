extends Unit
class_name Player

# ==============================================================================
# 1. 信号定义 (Signals)
# ==============================================================================
signal energy_changed(current, max_val) # UI信号：能量变化
signal armor_changed(current)           # UI信号：护甲变化

# ==============================================================================
# 2. 核心属性配置 (Export Variables)
# ==============================================================================
@export_group("Stats (基础属性)")
@export var max_energy: float = 100.0   # 最大能量
@export var energy_regen: float = 0.5   # 能量恢复速度
@export var max_armor: int = 3          # 最大护甲

@export_group("Dash Settings (冲刺配置)")
# 【强制设定】代码中会强制覆盖此值，以代码为准
@export var fixed_dash_distance: float = 300.0 
@export var max_charges: int = 99       # 最大连冲次数
@export var dash_speed: float = 1800.0  # 冲刺速度 (已调快)
@export var slow_motion_scale: float = 0.1 # 规划时的慢动作倍率
@export var dash_base_damage: int = 10  # 基础撞击伤害
@export var dash_knockback: float = 2.0 # 撞击击退力
@export var geometry_mask_color: Color = Color(1, 0.0, 0.0, 0.6) # 绞杀红圈颜色
@export var close_threshold: float = 80.0 # 闭环判定距离（磁吸阈值）

@export_group("Skill Costs (技能消耗)")
@export var cost_per_segment: float = 0.3 # Q技能消耗
@export var cost_explosion: float = 0.5   # E技能消耗

# ==============================================================================
# 3. 节点引用 (Node References)
# ==============================================================================
@onready var dash_hitbox: HitboxComponent = $DashHitbox
@onready var collision: CollisionShape2D = $CollisionShape2D
@onready var trail: Trail = %Trail         # 拖尾
@onready var line_2d: Line2D = $Line2D     # 画线
@onready var dash_cooldown_timer: Timer = $DashCooldwnTimer 

# ==============================================================================
# 4. 状态与变量 (Variables)
# ==============================================================================
enum State { HERDING, DASHING } 
var current_state = State.HERDING # 当前状态

var energy: float = 0.0          # 当前能量
var armor: int = 0               # 当前护甲
var dash_queue: Array[Vector2] = [] # 冲刺队列
var current_target: Vector2 = Vector2.ZERO # 当前目标点
var is_planning: bool = false    # 是否规划中
var kill_count: int = 0          # 击杀数

# --- 闭环核心变量 ---
var path_history: Array[Vector2] = [] # 路径历史记录
var current_art_score: float = 1.0    # 艺术分

# --- 技能开关 ---
var upgrades = {
	"poison_trail": false,
	"closed_loop": true,
	"electric_wall": false,
	"mine": false,
	"decoy": false,
	"cd_reduction": false,
	"corpse_bowling": false
}

# ==============================================================================
# 5. 资源预加载
# ==============================================================================
@export_group("Skill Scenes (技能预制体)")
@export var poison_cloud_scene: PackedScene
@export var mine_scene: PackedScene
@export var decoy_scene: PackedScene
@export var explosion_vfx_scene: PackedScene 

var move_dir: Vector2 

# ==============================================================================
# 6. 初始化 (Init)
# ==============================================================================
func _ready() -> void:
	super._ready()
	line_2d.top_level = true 
	line_2d.clear_points()
	
	# 【强制覆盖】无视编辑器设置，锁定代码手感数值
	fixed_dash_distance = 300.0 
	
	# 测试数值
	max_energy = 999.0
	max_charges = 999
	energy = max_energy 
	armor = max_armor
	update_ui_signals()
	
	if dash_cooldown_timer:
		dash_cooldown_timer.one_shot = true
	
	print(">>> 玩家就绪 | 闭环预警提示已实装(变红) <<<")

# ==============================================================================
# 7. 主循环 (Process)
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
	# E 技能
	if Input.is_action_just_pressed("skill_e"): 
		if energy >= cost_explosion:
			perform_explosion()
		else:
			Global.spawn_floating_text(global_position, "No Energy!", Color.RED)

	# Q 技能 / 左键
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
	
	spawn_temp_vfx(explosion_vfx_scene, global_position, 2.0)
	
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

func exit_planning_mode_and_dash() -> void:
	is_planning = false
	Engine.time_scale = 1.0 
	if dash_queue.size() > 0:
		start_dash_sequence()

func add_path_point(mouse_pos: Vector2) -> void:
	var start_pos = global_position
	if dash_queue.size() > 0:
		start_pos = dash_queue.back()
	
	# 800.0 距离
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
# 12. 几何闭环逻辑
# ==============================================================================
func check_and_trigger_intersection() -> void:
	if path_history.size() < 3: return
	
	var current_pos = path_history[-1]      
	var previous_pos = path_history[-2]     
	
	for i in range(path_history.size() - 2):
		var old_pos = path_history[i]
		
		# 磁吸检测
		var dist = current_pos.distance_to(old_pos)
		if dist < close_threshold:
			var polygon_points = PackedVector2Array()
			for j in range(i, path_history.size()):
				polygon_points.append(path_history[j])
			trigger_geometry_kill(polygon_points)
			return 

		# 交叉检测
		if i < path_history.size() - 2:
			var old_next = path_history[i+1]
			var intersection = Geometry2D.segment_intersects_segment(previous_pos, current_pos, old_pos, old_next)
			if intersection:
				var polygon_points = PackedVector2Array()
				polygon_points.append(intersection)
				for j in range(i + 1, path_history.size() - 1):
					polygon_points.append(path_history[j])
				polygon_points.append(intersection) 
				trigger_geometry_kill(polygon_points)
				return

func trigger_geometry_kill(polygon_points: PackedVector2Array):
	print(">>> 触发闭环！生成遮罩... <<<")
	var mask_node = create_geometry_mask_visual(polygon_points)
	var tween = create_tween()
	tween.tween_property(mask_node, "color:a", 0.8, 0.2).from(0.0)
	tween.tween_callback(func(): 
		if is_instance_valid(mask_node): 
			mask_node.color = Color(2, 2, 2, 1)
		_perform_geometry_damage(polygon_points)
	)
	tween.tween_interval(0.15)
	tween.tween_property(mask_node, "color", geometry_mask_color, 0.05)
	tween.tween_property(mask_node, "color:a", 0.0, 0.3)
	tween.tween_callback(func():
		if is_instance_valid(mask_node): mask_node.queue_free()
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

func create_geometry_mask_visual(points: PackedVector2Array) -> Polygon2D:
	var poly_node = Polygon2D.new()
	poly_node.polygon = points
	poly_node.color = geometry_mask_color
	poly_node.color.a = 0.0 
	poly_node.z_index = 100 
	get_tree().current_scene.call_deferred("add_child", poly_node)
	return poly_node

# ==============================================================================
# 13. 【核心新增】闭环预判与视觉更新
# ==============================================================================

# 更新画线与变色逻辑
func _update_visuals() -> void:
	if dash_queue.is_empty() and not is_planning:
		line_2d.clear_points()
		return
	
	# 画出已规划的线 (白色/默认色)
	line_2d.clear_points()
	line_2d.add_point(global_position)
	for p in dash_queue:
		line_2d.add_point(p)
	
	# 画出当前鼠标指向的“预测线”
	if is_planning:
		var start = global_position
		if dash_queue.size() > 0: start = dash_queue.back()
		
		# 计算预测终点
		var mouse_dir = (get_global_mouse_position() - start).normalized()
		var preview_pos = start + (mouse_dir * fixed_dash_distance)
		
		# --- 颜色逻辑判定 ---
		if energy < cost_per_segment:
			# 1. 没蓝了：变灰/暗红
			line_2d.default_color = Color(0.5, 0.5, 0.5, 0.5)
		elif is_preview_loop_closing(preview_pos):
			# 2. 【新增】检测到闭环：变红！(提示必杀)
			line_2d.default_color = Color(1.0, 0.0, 0.0, 1.0) 
		else:
			# 3. 正常规划：白色
			line_2d.default_color = Color.WHITE
			
		line_2d.add_point(preview_pos)

# 检测：如果加上 preview_end_pos 这个点，是否会形成闭环？
func is_preview_loop_closing(preview_end_pos: Vector2) -> bool:
	# 构造一个虚拟的“完整路径点集”
	# 包含：主角当前位置 -> 队列里的所有点
	var check_points: Array[Vector2] = []
	check_points.append(global_position)
	check_points.append_array(dash_queue)
	
	# 至少要有2个点（加上新的预览点就是3个点），才能形成三角形/闭环
	if check_points.size() < 2: 
		return false
		
	var current_start = check_points.back()
	
	# 遍历历史点，检查“磁吸”和“交叉”
	# 我们跳过最后1个点(current_start)，因为线是从那里发出的
	for i in range(check_points.size() - 1):
		var old_pos = check_points[i]
		
		# 1. 磁吸检测 (Magnetic Close)
		# 如果预测点离某个旧点很近 -> 视为闭环
		if preview_end_pos.distance_to(old_pos) < close_threshold:
			return true
			
		# 2. 交叉检测 (Intersection)
		# 只有当 i+1 存在时才能构成线段
		if i < check_points.size() - 1:
			var old_next = check_points[i+1]
			# 检查：(current_start -> preview_end_pos) 是否撞上了 (old_pos -> old_next)
			# 排除相邻线段（因为相邻线段端点重合，会被数学判定为相交）
			if old_next != current_start:
				var intersection = Geometry2D.segment_intersects_segment(current_start, preview_end_pos, old_pos, old_next)
				if intersection:
					return true
					
	return false

# ==============================================================================
# 14. 辅助功能 (Safe VFX)
# ==============================================================================

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
	print(">>> [击杀] 敌人阵亡 | 总击杀: %d <<<" % kill_count)
	energy = min(energy + 0.25, max_energy)
	update_ui_signals()
	
	if upgrades["cd_reduction"] and dash_cooldown_timer:
		var new_time = dash_cooldown_timer.time_left - 0.5
		dash_cooldown_timer.start(max(0.1, new_time))
	
	if upgrades["corpse_bowling"]:
		spawn_corpse_bullet(enemy_unit.global_position)

func spawn_corpse_bullet(pos: Vector2):
	pass

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
