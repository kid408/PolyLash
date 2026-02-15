extends SkillBase
class_name SkillTeslaE

## ==============================================================================
## 特斯拉E技能 - 沉默
## ==============================================================================
## 
## 功能说明:
## - 按E键对范围内敌人施加沉默状态，阻止敌人使用特殊技能
## 
## ==============================================================================

# ==============================================================================
# 技能参数（从CSV加载）
# ==============================================================================

## 沉默持续时间
var silence_duration: float = 3.0

## 沉默范围
var silence_radius: float = 200.0

# ==============================================================================
# 技能执行
# ==============================================================================

## 执行技能
func execute() -> void:
	if not consume_energy():
		if skill_owner:
			Global.spawn_floating_text(skill_owner.global_position, "No Energy!", Color.RED)
		return

	# 对范围内敌人施加沉默状态并造成伤害
	var enemies = get_tree().get_nodes_in_group("enemies")
	var hit_count = 0
	for enemy in enemies:
		if is_instance_valid(enemy):
			var dist = skill_owner.global_position.distance_to(enemy.global_position)
			if dist < silence_radius:
				# 造成伤害
				if enemy.has_node("HealthComponent"):
					enemy.get_node("HealthComponent").take_damage(30)
				# 施加沉默
				if enemy.has_method("apply_status"):
					enemy.apply_status("silence", silence_duration)
				hit_count += 1

	print("[SkillTeslaE] 沉默命中 %d 个敌人" % hit_count)
	spawn_skill_vfx(skill_owner.global_position, Color(0.3, 0.7, 1.0, 0.8), 0.7)
	Global.on_camera_shake.emit(6.0, 0.2)
	Global.spawn_floating_text(skill_owner.global_position, "SILENCE!", Color(0.3, 0.7, 1.0))
	start_cooldown()
