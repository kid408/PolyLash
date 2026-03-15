extends PlayerBase
class_name PlayerWeaver

## ==============================================================================
## 织网者角色 - 使用蛛网控制和收割敌人
## ==============================================================================
## 
## 技能系统已重构为独立的技能类：
## - Q技能：SkillWebWeave（蛛网编织与收割）
## - E技能：SkillStunBomb（定身炸弹）
## - 左键：SkillDash（冲刺）
## 
## 所有技能通过SkillManager管理，配置从CSV加载
## 
## ==============================================================================

# ==============================================================================
# 配置参数（保留用于向后兼容，技能会从这里读取参数）
# ==============================================================================
@export_group("Weaver Settings")
@export var fixed_segment_length: float = 320.0                      # 每段蛛网的固定长度
@export var web_color_open: Color = Color(0.6, 0.8, 1.0, 0.8)       # 蓝色（未闭合）
@export var web_color_crossing: Color = Color(1.0, 0.5, 0.2, 0.9)   # 橙色/红色（已闭合/交叉）
@export var web_color_closed_fill: Color = Color(1.0, 0.2, 0.2, 0.3) # 红色填充（陷阱）
@export var auto_recall_delay: float = 8.0                           # 自动收网延迟

@export_group("Recall Settings")
@export var recall_fly_speed: float = 3.0      # 收网速度
@export var recall_damage: int = 40            # 收网伤害
@export var recall_execute_mult: float = 3.0   # 处决倍率（被困敌人）

@export_group("Stun Bomb Settings")
@export var stun_radius: float = 300.0         # 定身半径
@export var stun_duration: float = 2.5         # 定身时长
@export var stun_color: Color = Color(0.2, 0.8, 1.0, 0.5)  # 定身视觉颜色

# ==============================================================================
# 技能管理器
# ==============================================================================
var skill_manager: SkillManager

# ==============================================================================
# 向后兼容属性（供技能类访问）
# ==============================================================================
var trapped_enemies: Array = []                 # 被困敌人（WeakRef）- 供SkillStunBomb访问

# ==============================================================================
# 初始化
# ==============================================================================
func _ready() -> void:
	super._ready()
	
	# 初始化技能管理器
	skill_manager = SkillManager.new(self)
	skill_manager.debug_mode = false  # 可以设置为true来调试
	add_child(skill_manager)
	skill_manager.load_skills_from_config("weaver")

# ==============================================================================
# LineBreaker 切线逻辑
# ==============================================================================
## 尝试切断织网者的蛛网（由 LineBreaker 敌人调用）
func try_break_line(enemy_pos: Vector2, radius: float) -> void:
	# 获取 Q 技能（SkillWebWeave）
	if not skill_manager:
		return
	
	var q_skill = skill_manager.get_skill("q")
	if not q_skill or q_skill.get_class() != "SkillWebWeave":
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
			
			print("[PlayerWeaver] 蛛网被切断！从点 %d 处截断" % i)
			return
