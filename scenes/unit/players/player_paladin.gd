extends PlayerBase
class_name PlayerPaladin

## ==============================================================================
## 圣卫 - 使用技能系统
## ==============================================================================

var skill_manager: SkillManager

func _ready() -> void:
	super._ready()
	skill_manager = SkillManager.new(self)
	skill_manager.debug_mode = false
	add_child(skill_manager)
	skill_manager.load_skills_from_config("paladin")

