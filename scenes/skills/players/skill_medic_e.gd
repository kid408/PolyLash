extends SkillBase
class_name SkillMedicE

## ==============================================================================
## 军医E技能 - 吸血Buff
## ==============================================================================
## 
## 功能说明:
## - 按E键为当前角色提供5秒的生命偷取Buff
## - 通过 meta 设置 lifesteal_bonus，持续时间结束后自动移除
## 
## ==============================================================================

# ==============================================================================
# 军医E技能专属参数（从CSV加载）
# ==============================================================================

## 吸血持续时间
var lifesteal_duration: float = 5.0

## 吸血比例（30%）
var lifesteal_value: float = 0.3

# ==============================================================================
# 技能执行
# ==============================================================================

## 执行技能
func execute() -> void:
	if not consume_energy():
		if skill_owner:
			Global.spawn_floating_text(skill_owner.global_position, "No Energy!", Color.RED)
		return

	# 为 skill_owner 添加吸血 Buff
	if skill_owner:
		skill_owner.set_meta("lifesteal_bonus", lifesteal_value)
		# 创建计时器，持续时间结束后移除
		var owner_ref = weakref(skill_owner)
		var timer = get_tree().create_timer(lifesteal_duration)
		timer.timeout.connect(func():
			var owner = owner_ref.get_ref()
			if owner and is_instance_valid(owner):
				owner.remove_meta("lifesteal_bonus")
		)

	Global.spawn_floating_text(skill_owner.global_position, "LIFESTEAL!", Color(0.4, 1.0, 0.5))
	start_cooldown()
