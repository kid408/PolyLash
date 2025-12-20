extends Unit
class_name Player

# --- 核心配置 ---
@export_group("Dash Settings")
@export var fixed_dash_distance: float = 300.0
@export var max_charges: int = 10
@export var dash_speed: float = 1200.0
@export var dash_cooldown: float = 3.0
@export var slow_motion_scale: float = 0.1
@export var dash_damage: int = 10 
@export var dash_knockback:float = 2.0
@export var geometry_mask_color: Color = Color(1, 0.2, 0.2, 0.5) # 【新增】遮罩颜色

# --- 引用 ---
@onready var dash_hitbox: HitboxComponent = $DashHitbox
@onready var dash_cooldown_timer: Timer = $DashCooldwnTimer 
@onready var collision: CollisionShape2D = $CollisionShape2D
@onready var trail: Trail = %Trail
@onready var line_2d: Line2D = $Line2D

# --- 状态管理 ---
enum State { HERDING, DASHING }
var current_state = State.HERDING

# --- 逻辑变量 ---
var dash_queue: Array[Vector2] = []
var current_target: Vector2 = Vector2.ZERO
var is_planning: bool = false
# 是否可冲刺
var is_dashing := false
# --- 闭环核心变量 【新增】 ---
var path_history: Array[Vector2] = [] # 记录路径点用于生成多边形
var sequence_start_pos: Vector2       # 记录起跑点

# --- 升级标志位 ---
var upgrades = {
	"poison_trail": false,
	"closed_loop": false,     # 默认为 false，但在 ready 里会被我强制开启用于测试
	"electric_wall": false,
	"pinball": false,
	"corpse_bowling": false,
	"gravity_shock": false,
	"decoy": false,
	"mine": false,
	"cd_reduction": false
}

# 预加载技能场景
@export_group("Skill Scenes")
@export var poison_cloud_scene: PackedScene
@export var shockwave_scene: PackedScene
@export var mine_scene: PackedScene
@export var decoy_scene: PackedScene

# 移动位置
var move_dir:Vector2

func _ready() -> void:
	super._ready()
	line_2d.top_level = true 
	line_2d.clear_points()
	dash_cooldown_timer.one_shot = true
	
	# ==========================================
	# 【测试专用】强制开启闭环技能，方便你测试
	# 正式游戏时请注释掉这一行，改为由UI或升级触发
	upgrades["closed_loop"] = true 
	print(">>> 测试模式：闭环处决已开启 <<<")
	# ==========================================
	
	start_cooldown()

func _process(delta: float) -> void:
	if Global.game_paused: return
	
	if !is_dashing:
		move_dir = Input.get_vector("move_left","move_right","move_up","move_down")
		var current_velocity := move_dir * stats.speed


		position += current_velocity * delta
		# 最大活动范围
		position.x = clamp(position.x, -1000,1000)
		position.y = clamp(position.y,-1000,1000)
	
	match current_state:
		State.HERDING:
			_handle_herding_logic(delta)
		State.DASHING:
			is_dashing = true
			_handle_dashing_logic(delta)
	
	_update_visuals()
	update_rotation()

# --- 状态: 牧羊/规划期 ---
func _handle_herding_logic(_delta: float) -> void:
	_handle_planning_input()
	
	if dash_cooldown_timer.is_stopped() and dash_queue.size() > 0 and not is_planning:
		start_dash_sequence()
	
	position.x = clamp(position.x, -1000, 1000)
	position.y = clamp(position.y, -1000, 1000)
	
	anim_player.play("idle")

func _handle_planning_input() -> void:
	if Input.is_action_just_pressed("click_right"):
		reset_plan()
		return

	if dash_queue.size() >= max_charges:
		is_planning = false
		Engine.time_scale = 1.0
		return

	if Input.is_action_pressed("click_left"):
		is_planning = true
		Engine.time_scale = slow_motion_scale
	else:
		is_planning = false
		Engine.time_scale = 1.0
	
	if Input.is_action_just_released("click_left"):
		add_path_point(get_global_mouse_position())

func add_path_point(mouse_pos: Vector2) -> void:
	var start_pos = global_position
	if dash_queue.size() > 0:
		start_pos = dash_queue.back()
	
	var direction = (mouse_pos - start_pos).normalized()
	var final_pos = start_pos + (direction * fixed_dash_distance)
	
	dash_queue.append(final_pos)

# --- 状态: 冲刺执行期 ---
func _handle_dashing_logic(delta: float) -> void:
	Engine.time_scale = 1.0
	if current_target == Vector2.ZERO: return
	
	# 【技能：剧毒笔触】
	if upgrades["poison_trail"] and poison_cloud_scene:
		if Engine.get_frames_drawn() % 10 == 0: 
			var poison = poison_cloud_scene.instantiate()
			poison.global_position = global_position
			get_parent().add_child(poison)
	
	position = position.move_toward(current_target, dash_speed * delta)

	if position.distance_to(current_target) < 10.0:
		_on_reach_target_point()

func start_dash_sequence() -> void:
	if dash_queue.is_empty(): return
	
	current_state = State.DASHING
	
	# 初始化路径记录：存入起始点
	path_history.clear()
	path_history.append(global_position) 
	
	# 【技能：战术埋雷】
	if upgrades["mine"] and mine_scene:
		var mine = mine_scene.instantiate()
		mine.global_position = global_position
		get_parent().add_child(mine)
	
	trail.start_trail()
	visuals.modulate.a = 0.5
	collision.set_deferred("disabled", true)
	
	dash_hitbox.set_deferred("monitorable", true)
	dash_hitbox.set_deferred("monitoring", true)
	dash_hitbox.setup(dash_damage, false, dash_knockback, self)
	
	current_target = dash_queue.pop_front()

func _on_reach_target_point() -> void:
	# 1. 记录当前点
	path_history.append(global_position)
	
	# 2. 【核心】检测是否发生路径交叉 (技能：闭环处决)
	if upgrades["closed_loop"]:
		check_and_trigger_intersection()
		
	# 【技能：残影分身】
	if upgrades["decoy"] and decoy_scene:
		var decoy = decoy_scene.instantiate()
		decoy.global_position = global_position
		get_parent().call_deferred("add_child", decoy)

	if dash_queue.size() > 0:
		current_target = dash_queue.pop_front()
	else:
		end_dash_sequence()

func check_and_trigger_intersection() -> void:
	if path_history.size() < 4:
		return
		
	var current_end = path_history[-1]
	var current_start = path_history[-2]
	
	# 倒序遍历，寻找最近的闭环
	for i in range(path_history.size() - 3):
		var old_start = path_history[i]
		var old_end = path_history[i+1]
		
		var intersection = Geometry2D.segment_intersects_segment(current_start, current_end, old_start, old_end)
		
		if intersection:
			print(">>> 路径交叉检测成功！交点：", intersection)
			
			var polygon_points = PackedVector2Array()
			
			# 1. 放入交点
			polygon_points.append(intersection)
			
			# 2. 放入被圈住的历史点 (注意顺序：从 old_end 开始一直到 current_start)
			# 这些点就是圆圈本身
			for j in range(i + 1, path_history.size() - 1):
				polygon_points.append(path_history[j])
			
			# 3. 再次放入交点 (确保逻辑闭合，虽然 Geometry2D 不强制要求，但这样更稳)
			# 有些几何算法需要首尾相连
			# polygon_points.append(intersection) 
			
			trigger_geometry_kill(polygon_points)
			return
			
func end_dash_sequence() -> void:
	# 【删除】原来这里的 trigger_geometry_kill 调用删掉
	# 因为现在是在 _on_reach_target_point 里实时检测的
	
	current_state = State.HERDING
	trail.stop()
	visuals.modulate.a = 5.0
	collision.set_deferred("disabled", false)
	dash_hitbox.set_deferred("monitorable", false)
	dash_hitbox.set_deferred("monitoring", false)
	start_cooldown()
	is_dashing = false

# --- 【新增】闭环处决核心逻辑 ---
func trigger_geometry_kill(polygon_points: PackedVector2Array):
	print(">>> 1. 闭环预警！红圈生成... <<<")
	
	# 1. 创建看不见的遮罩
	var mask_node = create_geometry_mask_visual(polygon_points)
	
	# 2. 创建动画序列 (这是最关键的一步)
	var tween = create_tween()
	
	# --- 步骤 A: 预警阶段 (0.3秒) ---
	# 让颜色从透明变成半透明红色
	# 此时没有任何伤害产生
	tween.tween_property(mask_node, "color:a", 0.6, 0.3).from(0.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	
	# --- 步骤 B: 伤害结算 (紧接着步骤A完成) ---
	# tween_callback 会在上面的动画播放完的瞬间被调用
	tween.tween_callback(func(): 
		print(">>> 2. 动画播放完毕，执行绞杀！ <<<")
		
		# 视觉反馈：瞬间变成高亮白色 (闪光)
		if is_instance_valid(mask_node):
			mask_node.color = Color(2, 2, 2, 1) 
			
		# 逻辑反馈：执行扣血 (调用你原来的伤害函数)
		_perform_geometry_damage(polygon_points)
	)
	
	# --- 步骤 C: 停留一瞬间 (0.1秒) ---
	# 让玩家看清楚白光和死掉的敌人
	tween.tween_interval(0.1)
	
	# --- 步骤 D: 淡出消失 (0.3秒) ---
	tween.tween_property(mask_node, "color:a", 0.0, 0.3)
	
	# --- 步骤 E: 销毁节点 ---
	tween.tween_callback(mask_node.queue_free)

# 将伤害逻辑提取成一个单独的函数，保持代码整洁
func _perform_geometry_damage(polygon_points: PackedVector2Array):
	print(">>> BOOM! 深度调试结算开始 <<<")
	
	# --- 注入灵魂 1：核爆级震动 ---
	# 强度 20.0 (很强)，持续时间自然衰减
	Global.on_camera_shake.emit(20.0, 0.5) 
	
	# --- 注入灵魂 2：瞬间顿帧 ---
	# 0.15秒的强力卡顿，让玩家看清这一瞬间
	Global.frame_freeze(0.15, 0.05)
	
	var enemies = get_tree().get_nodes_in_group("enemies")
	print("1. 组内敌人总数: ", enemies.size())
	
	var kill_count = 0
	
	# 【调试绘制 1】画出数学判定的多边形轮廓 (绿色)
	# 即使红色遮罩有偏移，这个绿线代表了 Geometry2D 实际使用的范围
	var debug_poly = Line2D.new()
	debug_poly.points = polygon_points
	# 闭合它
	if polygon_points.size() > 0:
		debug_poly.add_point(polygon_points[0])
	debug_poly.width = 3
	debug_poly.default_color = Color.GREEN
	debug_poly.z_index = 100
	debug_poly.top_level = true
	get_tree().current_scene.add_child(debug_poly)
	# 2秒后删除
	get_tree().create_timer(2.0).timeout.connect(debug_poly.queue_free)

	for enemy in enemies:
		if not is_instance_valid(enemy): continue
		
		var e_pos = enemy.global_position
		
		# 【调试绘制 2】画出代码认为敌人所在的坐标 (蓝色圆点)
		var debug_dot = Polygon2D.new()
		var radius = 5.0
		# 画一个小圆
		var circle_points = PackedVector2Array()
		for i in range(8):
			var angle = i * TAU / 8
			circle_points.append(Vector2(cos(angle), sin(angle)) * radius)
		debug_dot.polygon = circle_points
		debug_dot.color = Color.BLUE
		debug_dot.global_position = e_pos
		debug_dot.z_index = 101
		debug_dot.top_level = true
		get_tree().current_scene.add_child(debug_dot)
		get_tree().create_timer(2.0).timeout.connect(debug_dot.queue_free)
		
		# 判定
		var is_inside = Geometry2D.is_point_in_polygon(e_pos, polygon_points)
		
		if is_inside:
			debug_dot.color = Color.MAGENTA # 如果判定在里面，蓝点变洋红色
			#print("  [√] 在内部: ", enemy.name, " 坐标: ", e_pos)
			
			if enemy.has_node("HealthComponent"):
				enemy.health_component.take_damage(99999)
				kill_count += 1
				Global.spawn_floating_text(enemy.global_position, "99999", Color(1, 0, 0)) # 红色暴击
		else:
			# 如果你在屏幕上看到这个怪明明在红圈里，但这里打印"在外部"
			# 且蓝点不在红圈里，那就是敌人中心点歪了
			# 且蓝点在红圈里，那就是 Geometry2D 算法边缘判定问题
			# print("  [x] 在外部: ", enemy.name, " 坐标: ", e_pos)
			pass
	
	print("2. 最终击杀数: ", kill_count)

# --- 【新增】生成遮罩特效 ---
func create_geometry_mask_visual(points: PackedVector2Array) -> Polygon2D:
	var poly_node = Polygon2D.new()
	poly_node.polygon = points
	
	# 初始状态：完全透明 (Alpha = 0)
	var start_color = geometry_mask_color
	start_color.a = 0.0 
	poly_node.color = start_color
	
	poly_node.z_index = 10 # 确保在最上层
	poly_node.global_position = Vector2.ZERO
	
	get_tree().current_scene.call_deferred("add_child", poly_node)
	
	return poly_node

func start_cooldown() -> void:
	dash_cooldown_timer.start(dash_cooldown)

func reset_plan() -> void:
	dash_queue.clear()
	Engine.time_scale = 1.0

func _update_visuals() -> void:
	if dash_queue.is_empty() and not is_planning:
		line_2d.clear_points()
		return
		
	line_2d.clear_points()
	line_2d.add_point(global_position)
	for p in dash_queue:
		line_2d.add_point(p)
		
	if is_planning and dash_queue.size() < max_charges:
		var start = global_position
		if dash_queue.size() > 0:
			start = dash_queue.back()
		var mouse_dir = (get_global_mouse_position() - start).normalized()
		var preview_pos = start + (mouse_dir * fixed_dash_distance)
		line_2d.add_point(preview_pos)

func update_rotation() -> void:
	var facing_dir = Vector2.ZERO
	if current_state == State.DASHING:
		facing_dir = current_target - position
	elif is_planning:
		facing_dir = get_global_mouse_position() - position
	if facing_dir.x != 0:
		visuals.scale.x = -0.5 if facing_dir.x > 0 else 0.5
		visuals.scale.y = 0.5

func on_enemy_killed(enemy_unit: Unit):
	if upgrades["cd_reduction"]:
		if not dash_cooldown_timer.is_stopped():
			var new_time = dash_cooldown_timer.time_left - 0.5
			dash_cooldown_timer.start(max(0.1, new_time))
	if upgrades["corpse_bowling"]:
		spawn_corpse_bullet(enemy_unit.global_position)

func spawn_corpse_bullet(pos: Vector2):
	pass
