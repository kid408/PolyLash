extends PlayerBase
class_name PlayerPyro

## ==============================================================================
## 烈焰者 - 使用技能系统
## ==============================================================================

# ==============================================================================
# 配置参数（供技能类读取）
# ==============================================================================

@export_group("Pyro Settings")
@export var fire_line_damage: int = 20
@export var fire_line_duration: float = 5.0
@export var fire_line_width: float = 24.0
@export var fire_sea_damage: int = 40
@export var fire_sea_duration: float = 5.0
@export var fire_nova_radius: float = 140.0
@export var fire_nova_damage: int = 35
@export var fire_nova_duration: float = 3.0

# ==============================================================================
# 技能管理器
# ==============================================================================
var skill_manager: SkillManager

# ==============================================================================
# 生命周期
# ==============================================================================

func _ready() -> void:
	super._ready()
	
	# 初始化技能管理器
	skill_manager = SkillManager.new(self)
	skill_manager.debug_mode = false  # 可以设置为true来调试
	add_child(skill_manager)
	skill_manager.load_skills_from_config("pyro")

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
