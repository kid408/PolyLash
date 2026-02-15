extends SkillBase
class_name SkillNewTotemE

## ==============================================================================
## 萨满E技能 - 引爆图腾
## ==============================================================================
## 
## 功能说明:
## - 按E键引爆场上所有图腾，对图腾周围敌人造成范围伤害
## - 调用 SkillEffectManager.command_summons("skill_new_totem_q", "self_destruct")
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

	# 引爆所有图腾
	SkillEffectManager.command_summons("skill_new_totem_q", "self_destruct")

	Global.on_camera_shake.emit(10.0, 0.3)
	Global.spawn_floating_text(skill_owner.global_position, "DETONATE!", Color(0.6, 0.3, 0.8))
	start_cooldown()
