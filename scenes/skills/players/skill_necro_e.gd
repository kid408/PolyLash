extends SkillBase
class_name SkillNecroE

## ==============================================================================
## 死灵E技能 - 恐惧尖啸
## ==============================================================================
## 
## 功能说明:
## - 按E键发出恐惧尖啸，对范围内敌人施加恐惧状态
## - 恐惧状态使敌人向远离施法者的方向逃跑
## 
## ==============================================================================

# ==============================================================================
# 死灵E技能专属参数（从CSV加载）
# ==============================================================================

## 恐惧范围
var fear_radius: float = 200.0

## 恐惧持续时间
var fear_duration: float = 3.0

# ==============================================================================
# 技能执行
# ==============================================================================

## 执行技能
func execute() -> void:
	if not consume_energy():
		if skill_owner:
			Global.spawn_floating_text(skill_owner.global_position, "No Energy!", Color.RED)
		return

	# 对范围内所有敌人施加恐惧状态并造成伤害
	var enemies = get_tree().get_nodes_in_group("enemies")
	var hit_count = 0
	for enemy in enemies:
		if is_instance_valid(enemy):
			var dist = skill_owner.global_position.distance_to(enemy.global_position)
			if dist < fear_radius:
				# 造成伤害
				if enemy.has_node("HealthComponent"):
					enemy.get_node("HealthComponent").take_damage(35)
				# 施加恐惧
				if enemy.has_method("apply_status"):
					enemy.apply_status("fear", fear_duration, 300.0)
				hit_count += 1

	print("[SkillNecroE] 恐惧命中 %d 个敌人" % hit_count)
	spawn_skill_vfx(skill_owner.global_position, Color(0.4, 0.1, 0.5, 0.8), 0.7)
	Global.on_camera_shake.emit(8.0, 0.2)
	Global.spawn_floating_text(skill_owner.global_position, "FEAR!", Color(0.4, 0.1, 0.5))
	start_cooldown()
