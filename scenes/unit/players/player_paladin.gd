extends PlayerBase
class_name PlayerPaladin

## ==============================================================================
## 圣骑士 - 使用技能系统
## ==============================================================================

var skill_manager: SkillManager

func _ready() -> void:
	super._ready()
	skill_manager = SkillManager.new(self)
	skill_manager.debug_mode = false
	add_child(skill_manager)
	skill_manager.load_skills_from_config("paladin")

func _handle_input(delta: float) -> void:
	move_dir = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if can_move():
		var current_speed = speed
		if has_meta("buff_speed_boost"):
			current_speed *= (1.0 + get_meta("buff_speed_boost"))
		position += move_dir * current_speed * delta
	
	if not skill_manager:
		return
	
	if Input.is_action_just_pressed("skill_f"):
		if ultimate_skill:
			ultimate_skill.try_activate()
		else:
			Global.spawn_floating_text(global_position, "大招未实现", Color.GRAY)
		return
	
	if Input.is_action_just_pressed("skill_e"):
		skill_manager.execute_skill("e")
		return
	
	if Input.is_action_pressed("skill_q"):
		skill_manager.charge_skill("q", delta)
		return
	elif Input.is_action_just_released("skill_q"):
		skill_manager.release_skill("q")
		return
	
	if Input.is_action_just_pressed("click_left"):
		skill_manager.execute_skill("lmb")
