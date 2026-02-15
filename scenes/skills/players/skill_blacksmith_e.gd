extends SkillBase
class_name SkillBlacksmithE

## ==============================================================================
## 铁匠E技能 - 重置Q技能冷却
## ==============================================================================
## 
## 功能说明:
## - 按E键重置当前角色的Q技能冷却时间
## - 通过 SkillManager 访问Q技能并调用 reset_cooldown()
## 
## ==============================================================================

# ==============================================================================
# 技能执行
# ==============================================================================

## 执行技能
func execute() -> void:
	if not consume_energy():
		if skill_owner:
			Global.spawn_floating_text(skill_owner.global_position, "No Energy!", Color.RED)
		return

	# 通过 SkillManager 获取Q技能并重置冷却
	var q_skill_reset = false
	if skill_owner:
		var skill_manager = skill_owner.get_node_or_null("SkillManager")
		if skill_manager and skill_manager.has_skill("q"):
			var q_skill = skill_manager.get_skill("q")
			if q_skill and is_instance_valid(q_skill):
				q_skill.reset_cooldown()
				q_skill_reset = true

	if q_skill_reset:
		Global.spawn_floating_text(skill_owner.global_position, "COOLDOWN RESET!", Color(0.9, 0.5, 0.1))
	else:
		Global.spawn_floating_text(skill_owner.global_position, "NO Q SKILL!", Color.YELLOW)

	Global.on_camera_shake.emit(5.0, 0.15)
	start_cooldown()
