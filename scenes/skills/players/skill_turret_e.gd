extends SkillBase
class_name SkillTurretE

## ==============================================================================
## 工程E技能 - 引爆炮塔
## ==============================================================================
## 
## 功能说明:
## - 按E键引爆场上所有炮塔，对炮塔周围敌人造成范围伤害
## - 调用 SkillEffectManager.command_summons("skill_turret_q", "self_destruct")
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

	# 引爆所有炮塔
	SkillEffectManager.command_summons("skill_turret_q", "self_destruct")

	Global.on_camera_shake.emit(10.0, 0.3)
	Global.spawn_floating_text(skill_owner.global_position, "DETONATE!", Color(0.4, 0.5, 0.3))
	start_cooldown()
