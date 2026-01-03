extends PlayerBase
class_name PlayerHerder

## ==============================================================================
## 牧羊人角色 - 使用画圈几何击杀敌人
## ==============================================================================
## 
## 技能系统已重构为独立的技能类：
## - Q技能：SkillHerderLoop（画圈几何击杀）
## - E技能：SkillHerderExplosion（范围爆炸）
## - 左键：SkillDash（冲刺）
## 
## 所有技能通过SkillManager管理，配置从CSV加载
## 
## ==============================================================================

# ==============================================================================
# 配置参数（保留用于向后兼容，技能会从这里读取参数）
# ==============================================================================
@export_group("Herder Settings")
@export var fixed_segment_length: float = 600.0  # 每段冲刺的固定距离
@export var dash_base_damage: int = 10           # 冲刺基础伤害
@export var geometry_mask_color: Color = Color(1, 0.0, 0.0, 0.6)  # 几何遮罩颜色
@export var explosion_radius: float = 200.0      # 爆炸半径
@export var explosion_damage: int = 100          # 爆炸伤害
# 注意：close_threshold 已在 PlayerBase 中定义，不需要重复声明

# ==============================================================================
# 技能管理器
# ==============================================================================
var skill_manager: SkillManager

# ==============================================================================
# 初始化
# ==============================================================================
func _ready() -> void:
	super._ready()
	
	# 初始化技能管理器
	skill_manager = SkillManager.new(self)
	skill_manager.debug_mode = false  # 可以设置为true来调试
	add_child(skill_manager)
	skill_manager.load_skills_from_config("herder")

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
