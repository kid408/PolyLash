extends SkillBase
class_name SkillTrainE

## ==============================================================================
## 火车王E技能 - 致盲汽笛
## ==============================================================================
## 
## 功能说明:
## - 按E键发出汽笛声，致盲范围内所有敌人
## - 使用 "silence" 状态作为致盲代理（阻止敌人使用特殊技能）
## 
## ==============================================================================

# ==============================================================================
# 火车王E技能专属参数（从CSV加载）
# ==============================================================================

## 致盲范围
var blind_radius: float = 200.0

## 致盲持续时间
var blind_duration: float = 2.5

# ==============================================================================
# 技能执行
# ==============================================================================

## 执行技能
func execute() -> void:
	if not consume_energy():
		if skill_owner:
			Global.spawn_floating_text(skill_owner.global_position, "No Energy!", Color.RED)
		return

	# 致盲并伤害范围内所有敌人
	var enemies = get_tree().get_nodes_in_group("enemies")
	var hit_count = 0
	for enemy in enemies:
		if is_instance_valid(enemy):
			var dist = skill_owner.global_position.distance_to(enemy.global_position)
			if dist < blind_radius:
				# 造成伤害
				if enemy.has_node("HealthComponent"):
					enemy.get_node("HealthComponent").take_damage(30)
				# 致盲
				if enemy.has_method("apply_status"):
					enemy.apply_status("silence", blind_duration, 0.0)
				hit_count += 1

	print("[SkillTrainE] 致盲命中 %d 个敌人" % hit_count)
	spawn_skill_vfx(skill_owner.global_position, Color(0.9, 0.9, 1.0, 0.8), 0.7)
	Global.on_camera_shake.emit(8.0, 0.2)
	Global.spawn_floating_text(skill_owner.global_position, "FLASHBANG!", Color(0.6, 0.6, 0.7))
	start_cooldown()
