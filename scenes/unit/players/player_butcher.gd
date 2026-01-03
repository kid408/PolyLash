extends PlayerBase
class_name PlayerButcher

# ==============================================================================
# 屠夫角色 - 使用肉桩和锯条控制战场
# ==============================================================================
# Q技能：绘制锯条路径
#   - 按住Q进入规划模式（子弹时间）
#   - 左键：向鼠标方向延伸固定距离添加路径点
#   - 右键：撤销最后一个路径点
#   - 松开Q：发射锯条
#   - 闭合状态（线段相交）：捕获并拉扯敌人，钉在终点8秒
#   - 非闭合状态：击退敌人，到达终点立即消失
# E技能：投掷肉桩
#   - 肉桩飞行时拉扯沿途敌人
#   - 着陆后用链条控制范围内敌人
#   - 持续6秒
# ==============================================================================

# ==============================================================================
# 配置参数
# ==============================================================================
@export_group("Butcher Settings")
@export var stake_duration: float = 6.0         # 肉桩持续时间
@export var chain_radius: float = 250.0         # 链条控制半径
@export var stake_throw_speed: float = 1200.0   # 肉桩飞行速度
@export var stake_impact_damage: int = 20       # 肉桩着陆伤害

@export_group("Saw Skills")
@export var fixed_segment_length: float = 400.0 # 每段锯条的固定长度
@export var saw_fly_speed: float = 1100.0       # 锯条飞行速度
@export var saw_rotation_speed: float = 25.0    # 锯条旋转速度（闭合状态）
@export var saw_push_force: float = 1000.0      # 锯条击退力度（非闭合状态）
@export var saw_damage_tick: int = 3            # 锯条伤害（闭合状态）
@export var saw_damage_open: int = 1            # 锯条伤害（非闭合状态，降低以便看到击退效果）
@export var dismember_damage: int = 200         # 肢解伤害（锯条+肉桩组合技）
@export var saw_max_distance: float = 900.0     # 锯条最大飞行距离

@export_group("Visuals")
@export var chain_color: Color = Color(0.3, 0.1, 0.1, 0.8)      # 链条颜色
@export var saw_color: Color = Color(0.8, 0.2, 0.2, 0.8)        # 锯条颜色
@export var planning_color_normal: Color = Color(1.0, 1.0, 1.0, 0.5)  # 规划线条颜色（未闭合）
@export var planning_color_closed: Color = Color(1.0, 0.0, 0.0, 1.0)  # 规划线条颜色（已闭合）

# ==============================================================================
# 状态变量
# ==============================================================================
var is_planning: bool = false           # 是否处于Q技能规划模式
var is_path_closed: bool = false        # 路径是否已闭合（线段相交）
var path_points: Array[Vector2] = []    # 已确认的路径点
var active_stake: Node2D = null         # 当前激活的肉桩
var active_saw: Node2D = null           # 当前激活的锯条

@onready var line_2d: Line2D = $Line2D if has_node("Line2D") else null

# ==============================================================================
# 初始化
# ==============================================================================
func _ready() -> void:
	super._ready()
	
	# 从CSV加载技能配置
	_load_skill_config_from_csv()
	
	# 初始化Line2D用于绘制规划路径
	if not line_2d:
		line_2d = Line2D.new()
		line_2d.name = "Line2D"
		add_child(line_2d)
	
	line_2d.top_level = true
	line_2d.width = 6.0
	line_2d.z_index = 100
	line_2d.global_position = Vector2.ZERO

func _load_skill_config_from_csv() -> void:
	"""从CSV加载技能配置参数"""
	var skills = ConfigManager.get_player_skills("butcher")
	if skills.is_empty():
		print("[PlayerButcher] 警告：未找到技能配置，使用默认值")
		return
	
	# 加载所有技能参数
	if "fixed_segment_length" in skills: fixed_segment_length = skills["fixed_segment_length"]
	if "stake_duration" in skills: stake_duration = skills["stake_duration"]
	if "chain_radius" in skills: chain_radius = skills["chain_radius"]
	if "stake_throw_speed" in skills: stake_throw_speed = skills["stake_throw_speed"]
	if "stake_impact_damage" in skills: stake_impact_damage = skills["stake_impact_damage"]
	if "saw_fly_speed" in skills: saw_fly_speed = skills["saw_fly_speed"]
	if "saw_rotation_speed" in skills: saw_rotation_speed = skills["saw_rotation_speed"]
	if "saw_push_force" in skills: saw_push_force = skills["saw_push_force"]
	if "saw_damage_tick" in skills: saw_damage_tick = skills["saw_damage_tick"]
	if "saw_damage_open" in skills: saw_damage_open = skills["saw_damage_open"]
	if "dismember_damage" in skills: dismember_damage = skills["dismember_damage"]
	if "saw_max_distance" in skills: saw_max_distance = skills["saw_max_distance"]
	
	print("[PlayerButcher] 技能配置加载完成: 线段长度=", fixed_segment_length, " 锯条速度=", saw_fly_speed)

# ==============================================================================
# 主循环
# ==============================================================================
func _process_subclass(delta: float) -> void:
	# 处理冲刺移动
	if is_dashing:
		_process_dashing_movement(delta)
		return 

	# 规划模式：子弹时间 + 起点跟随玩家
	if is_planning:
		if Engine.time_scale > 0.2: 
			Engine.time_scale = 0.1
		if not path_points.is_empty():
			path_points[0] = global_position
	
	# 更新规划路径的视觉效果
	_update_planning_visuals()

# ==============================================================================
# 冲刺技能
# ==============================================================================
func use_dash() -> void:
	if is_planning: return  # 规划模式下禁止冲刺
	if is_dashing or not consume_energy(dash_cost): return
	
	var dir = (get_global_mouse_position() - global_position).normalized()
	dash_target = position + dir * dash_distance 
	is_dashing = true
	collision.set_deferred("disabled", true) 
	Global.play_player_dash()

func _process_dashing_movement(delta: float) -> void:
	position = position.move_toward(dash_target, dash_speed * delta)
	
	# 冲刺时击退敌人
	var enemies = get_tree().get_nodes_in_group("enemies")
	for e in enemies:
		if global_position.distance_to(e.global_position) < 80:
			if e.has_method("apply_knockback"):
				var push_dir = (e.global_position - global_position).normalized()
				e.apply_knockback(push_dir, 800.0)
	
	# 到达目标位置
	if position.distance_to(dash_target) < 10.0:
		is_dashing = false
		collision.set_deferred("disabled", false)

# ==============================================================================
# Q技能：锯条规划与发射
# ==============================================================================
func charge_skill_q(delta: float) -> void:
	# 如果已有激活的锯条，再按Q就手动消失
	if is_instance_valid(active_saw) and not is_planning:
		if active_saw.has_method("manual_dismiss"):
			active_saw.manual_dismiss()
		active_saw = null
		Global.spawn_floating_text(global_position, "Dismissed!", Color.YELLOW)
		return
	
	# 进入规划模式
	if not is_planning:
		enter_planning_mode()
	
	# 左键：添加路径点
	if Input.is_action_just_pressed("click_left"):
		handle_add_point()
	
	# 右键：撤销路径点
	if Input.is_action_just_pressed("click_right"):
		undo_last_point()

func release_skill_q() -> void:
	if is_planning:
		launch_saw_construct()

func enter_planning_mode() -> void:
	is_planning = true
	is_path_closed = false
	Engine.time_scale = 0.1
	path_points.clear()
	line_2d.clear_points()
	path_points.append(global_position)  # 起点

func handle_add_point() -> void:
	# 已闭合则禁止继续添加点
	if is_path_closed:
		Global.spawn_floating_text(get_global_mouse_position(), "LOCKED!", Color.RED)
		return
		
	if path_points.is_empty(): return
	
	var start_pos = path_points.back()
	var mouse_pos = get_global_mouse_position()
	
	# 计算延伸点（固定距离）
	var dir = (mouse_pos - start_pos).normalized()
	var next_pos = start_pos + (dir * fixed_segment_length)
	
	# 检测线段相交（闭合判定）
	if path_points.size() >= 3:
		var new_line_start = path_points.back()
		var new_line_end = next_pos
		
		# 检查新线段是否与之前的线段相交
		for i in range(path_points.size() - 2):
			var old_line_start = path_points[i]
			var old_line_end = path_points[i + 1]
			
			var intersection = Geometry2D.segment_intersects_segment(
				old_line_start, old_line_end,
				new_line_start, new_line_end
			)
			
			if intersection != null:
				is_path_closed = true
				Global.spawn_floating_text(intersection, "CLOSED!", Color.RED)
				print("[Butcher] 线段相交闭合! 交点: ", intersection)
				break
	
	# 扣除能量并添加点（保持完整路径，不剪裁）
	if consume_energy(skill_q_cost):
		path_points.append(next_pos)
		if not is_path_closed:
			Global.spawn_floating_text(next_pos, "Node", Color.WHITE)
	else:
		Global.spawn_floating_text(global_position, "No Energy!", Color.RED)

func undo_last_point() -> void:
	if path_points.size() > 1:
		path_points.pop_back()
		is_path_closed = false
		energy += skill_q_cost
		update_ui_signals()

func launch_saw_construct() -> void:
	is_planning = false
	Engine.time_scale = 1.0
	line_2d.clear_points()
	
	# 至少需要2个点
	if path_points.size() < 2:
		path_points.clear()
		return

	# 清除旧锯条
	if is_instance_valid(active_saw):
		active_saw.queue_free()
		active_saw = null

	print("[Butcher] 发射", "闭合" if is_path_closed else "开放", "锯条")

	var fly_dir = (path_points[1] - path_points[0]).normalized()
	
	var saw = SawProjectile.new()
	saw.name = "Saw_" + str(Time.get_ticks_msec())
	get_parent().add_child(saw)
	saw.global_position = global_position
	saw.setup(path_points, is_path_closed, fly_dir, self)
	
	active_saw = saw
	
	Global.on_camera_shake.emit(5.0, 0.2)
	path_points.clear()
	is_path_closed = false

func _update_planning_visuals() -> void:
	if not is_planning: 
		if line_2d: line_2d.clear_points()
		return
	
	line_2d.global_position = Vector2.ZERO
	line_2d.clear_points()
	
	if path_points.is_empty(): return
	
	# 绘制已确认的点
	for p in path_points:
		line_2d.add_point(p)
	
	# 绘制预览线（不参与闭合检测）
	if not is_path_closed:
		var last_point = path_points.back()
		var mouse_pos = get_global_mouse_position()
		var dir = (mouse_pos - last_point).normalized()
		var preview_pos = last_point + (dir * fixed_segment_length)
		line_2d.add_point(preview_pos)
		
		# 预览线永远是正常颜色
		line_2d.default_color = planning_color_normal
		line_2d.width = 6.0
	else:
		# 已闭合：红色粗线
		line_2d.default_color = planning_color_closed
		line_2d.width = 8.0

# ==============================================================================
# E技能：肉桩投掷
# ==============================================================================
func use_skill_e() -> void:
	if not consume_energy(skill_e_cost): return
	
	# 清除旧肉桩
	if is_instance_valid(active_stake): 
		active_stake.queue_free()
	
	var target_pos = get_global_mouse_position()
	var dir = (target_pos - global_position).normalized()
	var dist = min(global_position.distance_to(target_pos), 800)
	var final_pos = global_position + dir * dist
	
	var stake = MeatStake.new()
	stake.setup(final_pos, self)
	get_parent().add_child(stake)
	stake.global_position = global_position
	active_stake = stake
	
	Global.on_camera_shake.emit(10.0, 0.2)
