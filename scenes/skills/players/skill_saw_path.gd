extends SkillBase
class_name SkillSawPath

## ==============================================================================
## 屠夫Q技能 - 锯条路径
## ==============================================================================
## 
## 功能说明:
## - 按住Q进入规划模式（子弹时间）
## - 左键：向鼠标方向延伸固定距离添加路径点
## - 右键：撤销最后一个路径点
## - 松开Q：发射锯条
## - 闭合状态（线段相交）：捕获并拉扯敌人，钉在终点8秒
## - 非闭合状态：击退敌人，到达终点立即消失
## 
## ==============================================================================

# ==============================================================================
# 技能参数（从CSV加载）
# ==============================================================================

## 每段锯条的固定长度
var fixed_segment_length: float = 400.0

## 锯条飞行速度
var saw_fly_speed: float = 1100.0

## 锯条伤害（闭合状态）
var saw_damage_tick: int = 3

## 锯条伤害（非闭合状态）
var saw_damage_open: int = 1

## 链条控制半径（闭合状态）
var chain_radius: float = 250.0

## 锯条最大飞行距离
var saw_max_distance: float = 900.0

## 锯条旋转速度（闭合状态）
var saw_rotation_speed: float = 25.0

## 锯条击退力度（非闭合状态）
var saw_push_force: float = 1000.0

# ==============================================================================
# 视觉配置
# ==============================================================================

## 规划线条颜色（未闭合）
var planning_color_normal: Color = Color(1.0, 1.0, 1.0, 0.5)

## 规划线条颜色（已闭合）
var planning_color_closed: Color = Color(1.0, 0.0, 0.0, 1.0)

## 锯条颜色
var saw_color: Color = Color(0.8, 0.2, 0.2, 0.8)

# ==============================================================================
# 运行时状态
# ==============================================================================

## 是否处于规划模式
var is_planning: bool = false

## 路径是否已闭合（线段相交）
var is_path_closed: bool = false

## 已确认的路径点
var path_points: Array[Vector2] = []

## 当前激活的锯条
var active_saw: Node2D = null

# ==============================================================================
# 节点引用
# ==============================================================================

## 用于绘制规划路径的Line2D
var line_2d: Line2D

# ==============================================================================
# 生命周期
# ==============================================================================

func _ready() -> void:
	super._ready()
	
	# 创建Line2D用于绘制规划路径
	line_2d = Line2D.new()
	line_2d.name = "SawPathLine"
	line_2d.top_level = true
	line_2d.width = 6.0
	line_2d.z_index = 100
	line_2d.global_position = Vector2.ZERO
	
	if skill_owner:
		skill_owner.add_child(line_2d)

func _process(delta: float) -> void:
	super._process(delta)
	
	# 规划模式：起点跟随玩家
	if is_planning and not path_points.is_empty():
		path_points[0] = skill_owner.global_position
	
	# 更新规划路径的视觉效果
	_update_planning_visuals()

# ==============================================================================
# 技能执行
# ==============================================================================

## 蓄力技能（持续按住Q）
func charge(delta: float) -> void:
	# 如果已有激活的锯条，再按Q就手动消失
	if is_instance_valid(active_saw) and not is_planning:
		if active_saw.has_method("manual_dismiss"):
			active_saw.manual_dismiss()
		active_saw = null
		if skill_owner:
			Global.spawn_floating_text(skill_owner.global_position, "Dismissed!", Color.YELLOW)
		return
	
	# 进入规划模式
	if not is_planning:
		_enter_planning_mode()
	
	# 左键：添加路径点
	if Input.is_action_just_pressed("click_left"):
		_handle_add_point()
	
	# 右键：撤销路径点
	if Input.is_action_just_pressed("click_right"):
		_undo_last_point()

## 释放技能（松开Q）
func release() -> void:
	if is_planning:
		_launch_saw_construct()

# ==============================================================================
# 规划模式
# ==============================================================================

## 进入规划模式
func _enter_planning_mode() -> void:
	is_planning = true
	is_charging = true
	is_path_closed = false
	
	# 子弹时间
	Engine.time_scale = 0.1
	
	# 清空路径
	path_points.clear()
	line_2d.clear_points()
	
	# 添加起点
	if skill_owner:
		path_points.append(skill_owner.global_position)

## 添加路径点
func _handle_add_point() -> void:
	# 已闭合则禁止继续添加点
	if is_path_closed:
		if skill_owner:
			Global.spawn_floating_text(skill_owner.get_global_mouse_position(), "LOCKED!", Color.RED)
		return
	
	if path_points.is_empty() or not skill_owner:
		return
	
	var start_pos = path_points.back()
	var mouse_pos = skill_owner.get_global_mouse_position()
	
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
				break
	
	# 扣除能量并添加点
	if consume_energy():
		path_points.append(next_pos)
		if not is_path_closed:
			Global.spawn_floating_text(next_pos, "Node", Color.WHITE)
	else:
		if skill_owner:
			Global.spawn_floating_text(skill_owner.global_position, "No Energy!", Color.RED)

## 撤销最后一个路径点
func _undo_last_point() -> void:
	if path_points.size() > 1:
		path_points.pop_back()
		is_path_closed = false
		
		# 返还能量
		if skill_owner and skill_owner.has_method("gain_energy"):
			skill_owner.energy += energy_cost
			skill_owner.update_ui_signals()

## 发射锯条
func _launch_saw_construct() -> void:
	is_planning = false
	is_charging = false
	
	# 恢复时间流速
	Engine.time_scale = 1.0
	
	# 清空规划线
	line_2d.clear_points()
	
	# 至少需要2个点
	if path_points.size() < 2:
		path_points.clear()
		return
	
	# 清除旧锯条
	if is_instance_valid(active_saw):
		active_saw.queue_free()
		active_saw = null
	
	print("[SkillSawPath] 发射", "闭合" if is_path_closed else "开放", "锯条")
	
	# 计算飞行方向
	var fly_dir = (path_points[1] - path_points[0]).normalized()
	
	# 创建锯条投射物
	var saw = SawProjectile.new()
	saw.name = "Saw_" + str(Time.get_ticks_msec())
	
	# 添加到场景树
	if skill_owner:
		skill_owner.get_parent().add_child(saw)
		saw.global_position = skill_owner.global_position
		saw.setup(path_points, is_path_closed, fly_dir, skill_owner)
	
	active_saw = saw
	
	# 相机震动
	Global.on_camera_shake.emit(5.0, 0.2)
	
	# 清空路径
	path_points.clear()
	is_path_closed = false
	
	# 开始冷却
	start_cooldown()

## 更新规划路径的视觉效果
func _update_planning_visuals() -> void:
	if not is_planning:
		if line_2d:
			line_2d.clear_points()
		return
	
	line_2d.global_position = Vector2.ZERO
	line_2d.clear_points()
	
	if path_points.is_empty():
		return
	
	# 绘制已确认的点
	for p in path_points:
		line_2d.add_point(p)
	
	# 绘制预览线（不参与闭合检测）
	if not is_path_closed and skill_owner:
		var last_point = path_points.back()
		var mouse_pos = skill_owner.get_global_mouse_position()
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
# 辅助方法
# ==============================================================================

## 检查玩家是否可以移动
func can_move() -> bool:
	return not is_planning

## 清理资源
func cleanup() -> void:
	# 清理Line2D
	if is_instance_valid(line_2d):
		line_2d.queue_free()
	
	# 清理激活的锯条
	if is_instance_valid(active_saw):
		active_saw.queue_free()
	
	# 恢复时间流速
	if is_planning:
		Engine.time_scale = 1.0

## 打印调试信息
func print_debug_info() -> void:
	print("[SkillSawPath] 调试信息:")
	print("  - is_planning: %s" % is_planning)
	print("  - is_path_closed: %s" % is_path_closed)
	print("  - path_points: %d" % path_points.size())
	print("  - fixed_segment_length: %.0f" % fixed_segment_length)
	print("  - saw_fly_speed: %.0f" % saw_fly_speed)
	print("  - energy_cost: %.0f" % energy_cost)
