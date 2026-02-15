extends SkillBase
class_name SkillAmmoE

## ==============================================================================
## 弹药E技能 - 能量补给
## ==============================================================================
## 
## 功能说明:
## - 按E键立即将当前角色的能量恢复至满值
## - energy_cost 为 0（免费技能），但有冷却时间
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

	# 恢复能量至满值
	if skill_owner and "energy" in skill_owner:
		skill_owner.energy = skill_owner.max_energy

	Global.spawn_floating_text(skill_owner.global_position, "RESUPPLY!", Color(0.3, 0.6, 0.2))
	start_cooldown()
