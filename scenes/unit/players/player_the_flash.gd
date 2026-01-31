extends PlayerBase
class_name PlayerTheFlash

## ==============================================================================
## 闪电侠 - 使用技能系统
## ==============================================================================

# ==============================================================================
# 配置参数（供技能类读取）
# ==============================================================================

@export_group("闪电侠 Settings")
# 在这里添加角色特定的参数
# 例如：
# @export var special_damage: int = 50
# @export var special_duration: float = 3.0

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
	skill_manager.debug_mode = false
	add_child(skill_manager)
	skill_manager.load_skills_from_config("the_flash")

# ==============================================================================
# 输入处理
# ==============================================================================
func _handle_input(delta: float) -> void:
	# 1. 移动逻辑
	move_dir = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if can_move():
		var current_speed = speed
		position += move_dir * current_speed * delta
	
	# 2. 技能按键分发
	if not skill_manager:
		return
	
	# F键 - 大招
	if Input.is_action_just_pressed("skill_f"):
		if ultimate_skill:
			ultimate_skill.try_activate()
		else:
			Global.spawn_floating_text(global_position, "大招未实现", Color.GRAY)
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
	
	# 左键技能
	if Input.is_action_just_pressed("click_left"):
		skill_manager.execute_skill("lmb")

# ==============================================================================
# 自定义逻辑（可选）
# ==============================================================================

# 在这里添加角色特定的方法
# 例如：
# func on_special_event() -> void:
#     print("[PlayerTheFlash] 触发特殊事件")
