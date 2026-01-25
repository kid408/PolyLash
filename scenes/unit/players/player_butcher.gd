extends PlayerBase
class_name PlayerButcher

## ==============================================================================
## 屠夫角色 - 使用肉桩和锯条控制战场
## ==============================================================================
## 
## 技能系统已重构为独立的技能类：
## - Q技能：SkillSawPath（锯条路径）
## - E技能：SkillMeatStake（肉桩投掷）
## - 左键：SkillDash（冲刺）
## 
## 所有技能通过SkillManager管理，配置从CSV加载
## 
## ==============================================================================

# ==============================================================================
# 配置参数（保留用于向后兼容，技能会从这里读取参数）
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
@export var saw_damage_open: int = 1            # 锯条伤害（非闭合状态）
@export var dismember_damage: int = 200         # 肢解伤害（锯条+肉桩组合技）
@export var saw_max_distance: float = 900.0     # 锯条最大飞行距离

@export_group("Visuals")
@export var chain_color: Color = Color(0.3, 0.1, 0.1, 0.8)      # 链条颜色
@export var saw_color: Color = Color(0.8, 0.2, 0.2, 0.8)        # 锯条颜色
@export var planning_color_normal: Color = Color(1.0, 1.0, 1.0, 0.5)  # 规划线条颜色（未闭合）
@export var planning_color_closed: Color = Color(1.0, 0.0, 0.0, 1.0)  # 规划线条颜色（已闭合）

# ==============================================================================
# 技能管理器
# ==============================================================================
var skill_manager: SkillManager

# ==============================================================================
# 向后兼容属性（供技能类访问）
# ==============================================================================
var active_stake: Node2D = null         # 当前激活的肉桩（供SkillMeatStake访问）
var active_saw: Node2D = null           # 当前激活的锯条（供SkillSawPath访问）

# ==============================================================================
# 初始化
# ==============================================================================
func _ready() -> void:
	super._ready()
	
	# 初始化技能管理器
	skill_manager = SkillManager.new(self)
	skill_manager.debug_mode = false  # 可以设置为true来调试
	add_child(skill_manager)
	skill_manager.load_skills_from_config("butcher")

# ==============================================================================
# 输入处理
# ==============================================================================
func _handle_input(delta: float) -> void:
	# 1. 移动逻辑
	move_dir = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if can_move():
		var current_speed = speed  # 直接使用 Unit 基类的 speed 属性
		position += move_dir * current_speed * delta
	
	# 2. 技能按键分发
	if not skill_manager:
		return
	
	# F键 - 大招（优先处理）
	if Input.is_action_just_pressed("skill_f") and ultimate_skill:
		print("[PlayerButcher] F键按下，尝试激活大招")
		ultimate_skill.try_activate()
		return
	
	# E技能（瞬发）
	if Input.is_action_just_pressed("skill_e"):
		skill_manager.execute_skill("e")
		return
	
	# Q技能（蓄力）
	if Input.is_action_pressed("skill_q"):
		skill_manager.charge_skill("q", delta)
		return
	elif Input.is_action_just_released("skill_q"):
		skill_manager.release_skill("q")
		return
	
	# 左键冲刺
	if Input.is_action_just_pressed("click_left"):
		skill_manager.execute_skill("lmb")

# ==============================================================================
# LineBreaker 切线逻辑
# ==============================================================================
## 尝试切断屠夫的锯条路径（由 LineBreaker 敌人调用）
func try_break_line(enemy_pos: Vector2, radius: float) -> void:
	# 获取 Q 技能（SkillSawPath）
	if not skill_manager:
		return
	
	var q_skill = skill_manager.get_skill("q")
	if not q_skill or q_skill.get_class() != "SkillSawPath":
		return
	
	# 如果没有在规划也没在冲刺，无需切断
	if not q_skill.is_planning and not q_skill.is_dashing:
		return
	
	# 检查路径点是否在敌人范围内
	var path_points = q_skill.path_points
	if path_points.is_empty():
		return
	
	# 倒序遍历，找到被切断的最早那个点
	for i in range(path_points.size()):
		var p = path_points[i]
		if p.distance_to(enemy_pos) < radius:
			# 视觉反馈
			Global.on_camera_shake.emit(5.0, 0.1)
			Global.spawn_floating_text(p, "SNAP!", Color.RED)
			
			# 截断数组，只保留被切断点之前的路径
			q_skill.path_points = q_skill.path_points.slice(0, i)
			
			# 同时截断路径段
			if i > 0:
				q_skill.path_segments = q_skill.path_segments.slice(0, i - 1)
			
			# 如果正在规划模式，更新视觉
			if q_skill.is_planning:
				q_skill._update_visuals()
			
			return
