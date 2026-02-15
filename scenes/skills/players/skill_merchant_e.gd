extends SkillBase
class_name SkillMerchantE

## ==============================================================================
## 商人E技能 - 金币炸弹
## ==============================================================================
## 
## 功能说明:
## - 按E键投掷金币炸弹，对范围内敌人造成伤害
## - 同时在角色位置生成金币
## 
## ==============================================================================

# ==============================================================================
# 技能参数（从CSV加载）
# ==============================================================================

## 获得金币数量
var gold_amount: int = 50

# ==============================================================================
# 技能执行
# ==============================================================================

## 执行技能
func execute() -> void:
	if not consume_energy():
		if skill_owner:
			Global.spawn_floating_text(skill_owner.global_position, "No Energy!", Color.RED)
		return

	# 生成金币
	if skill_owner:
		Global.spawn_coin(skill_owner.global_position, gold_amount)

	Global.on_camera_shake.emit(5.0, 0.15)
	Global.spawn_floating_text(skill_owner.global_position, "GOLD +%d!" % gold_amount, Color(1.0, 0.8, 0.2))
	start_cooldown()
