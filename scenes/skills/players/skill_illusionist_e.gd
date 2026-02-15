extends SkillBase
class_name SkillIllusionistE

## ==============================================================================
## 魔术师E技能 - 幻影交换
## ==============================================================================
## 
## 功能说明:
## - 按E键与最近的幻影分身交换位置
## - 如果没有幻影分身，显示 "No Phantom!" 提示
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

	# 查找最近的幻影分身
	var nearest_phantom: Node2D = null
	var nearest_dist: float = INF

	for eid in SkillEffectManager.active_effects.keys():
		var data = SkillEffectManager.active_effects[eid]
		if data.get("type") == "summon" and data.get("owner_skill_id") == "skill_illusionist_q":
			var node = data.get("node")
			if is_instance_valid(node):
				var dist = skill_owner.global_position.distance_to(node.global_position)
				if dist < nearest_dist:
					nearest_dist = dist
					nearest_phantom = node

	if nearest_phantom == null:
		Global.spawn_floating_text(skill_owner.global_position, "No Phantom!", Color.GRAY)
		start_cooldown()
		return

	# 交换位置
	var owner_pos = skill_owner.global_position
	var phantom_pos = nearest_phantom.global_position
	skill_owner.global_position = phantom_pos
	nearest_phantom.global_position = owner_pos

	Global.spawn_floating_text(skill_owner.global_position, "SWAP!", Color(0.7, 0.7, 0.9))
	start_cooldown()
