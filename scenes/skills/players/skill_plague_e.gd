extends SkillBase
class_name SkillPlagueE

## ==============================================================================
## 瘟疫E技能 - 引爆毒素
## ==============================================================================
## 
## 功能说明:
## - 按E键引爆范围内所有中毒敌人身上的毒素层数
## - 造成基于层数的爆发伤害（每层 damage_per_stack 点伤害）
## 
## ==============================================================================

# ==============================================================================
# 技能参数（从CSV加载）
# ==============================================================================

## 引爆范围
var detonate_radius: float = 250.0

## 每层毒素引爆伤害
var damage_per_stack: int = 50

# ==============================================================================
# 技能执行
# ==============================================================================

## 执行技能
func execute() -> void:
	if not consume_energy():
		if skill_owner:
			Global.spawn_floating_text(skill_owner.global_position, "No Energy!", Color.RED)
		return

	var detonated_count: int = 0

	# 查找范围内所有中毒敌人并引爆毒素
	var enemies = get_tree().get_nodes_in_group("enemies")
	for enemy in enemies:
		if not is_instance_valid(enemy):
			continue
		var dist = skill_owner.global_position.distance_to(enemy.global_position)
		if dist > detonate_radius:
			continue

		# 检查敌人是否有中毒状态（优先使用 StatusComponent，回退到内置状态系统）
		var has_poison = false
		var stacks = 0
		if enemy.has_node("StatusComponent"):
			var status_comp: StatusComponent = enemy.get_node("StatusComponent")
			if status_comp.has_status("poison"):
				has_poison = true
				stacks = status_comp.get_status_stacks("poison")
				status_comp.remove_status("poison")
		elif enemy.has_method("has_status") and enemy.has_status("poison"):
			has_poison = true
			stacks = enemy.get_status_stacks("poison")
			# 移除毒素状态（已引爆）
			if enemy.has_method("_remove_status"):
				enemy._remove_status("poison")
			elif "active_statuses" in enemy:
				enemy.active_statuses.erase("poison")
		
		if not has_poison:
			continue

		# 计算伤害
		var total_damage = damage_per_stack * stacks

		# 造成伤害
		if enemy.has_node("HealthComponent"):
			enemy.get_node("HealthComponent").take_damage(total_damage)

		Global.spawn_floating_text(enemy.global_position, "DETONATE x%d!" % stacks, Color(0.4, 0.7, 0.1))
		detonated_count += 1

	if detonated_count > 0:
		Global.on_camera_shake.emit(6.0, 0.15)
		Global.spawn_floating_text(skill_owner.global_position, "PLAGUE BURST!", Color(0.4, 0.7, 0.1))
	else:
		Global.spawn_floating_text(skill_owner.global_position, "No Poison!", Color(0.6, 0.6, 0.6))

	start_cooldown()
