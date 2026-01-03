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
# 输入处理
# ==============================================================================
func _handle_input(delta: float) -> void:
	# 1. 移动逻辑
	move_dir = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if can_move():
		var current_speed = base_speed 
		if stats != null:
			current_speed = stats.speed
		position += move_dir * current_speed * delta
	
	# 2. 技能按键分发
	if not skill_manager:
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
