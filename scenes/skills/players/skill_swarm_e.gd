extends SkillBase
class_name SkillSwarmE

## ==============================================================================
## 虫母E技能 - 集火指令
## ==============================================================================
## 
## 功能说明:
## - 按E键命令所有召唤物集火攻击最近的敌人
## - 调用 SkillEffectManager.command_summons("skill_swarm_q", "focus_fire")
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

	# 查找最近的敌人作为集火目标
	var nearest_enemy: Node2D = null
	var nearest_dist: float = INF
	var enemies = get_tree().get_nodes_in_group("enemies")
	for enemy in enemies:
		if is_instance_valid(enemy):
			var dist = skill_owner.global_position.distance_to(enemy.global_position)
			if dist < nearest_dist:
				nearest_dist = dist
				nearest_enemy = enemy

	# 命令所有召唤物集火
	SkillEffectManager.command_summons("skill_swarm_q", "focus_fire", nearest_enemy)

	Global.spawn_floating_text(skill_owner.global_position, "FOCUS FIRE!", Color(0.5, 0.4, 0.1))
	start_cooldown()
