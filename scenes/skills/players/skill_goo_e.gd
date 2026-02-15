extends SkillBase
class_name SkillGooE

## ==============================================================================
## 软泥E技能 - 吞噬
## ==============================================================================
## 
## 功能说明:
## - 按E键吞噬最近的小型敌人（立即击杀）并恢复自身生命值
## - 查找范围内最近敌人，对其造成 9999 伤害（instant kill），然后治疗自身
## 
## ==============================================================================

# ==============================================================================
# 软泥E技能专属参数（从CSV加载）
# ==============================================================================

## 吞噬范围
var devour_radius: float = 150.0

## 吞噬治疗量
var heal_amount: int = 30

# ==============================================================================
# 技能执行
# ==============================================================================

## 执行技能
func execute() -> void:
	if not consume_energy():
		if skill_owner:
			Global.spawn_floating_text(skill_owner.global_position, "No Energy!", Color.RED)
		return

	# 查找范围内最近的敌人
	var nearest_enemy: Node2D = null
	var nearest_dist: float = INF
	var enemies = get_tree().get_nodes_in_group("enemies")
	for enemy in enemies:
		if is_instance_valid(enemy):
			var dist = skill_owner.global_position.distance_to(enemy.global_position)
			if dist <= devour_radius and dist < nearest_dist:
				nearest_dist = dist
				nearest_enemy = enemy

	if nearest_enemy == null:
		Global.spawn_floating_text(skill_owner.global_position, "No Target!", Color.YELLOW)
		start_cooldown()
		return

	# 吞噬：对敌人造成 9999 伤害（instant kill）
	if nearest_enemy.has_node("HealthComponent"):
		nearest_enemy.health_component.take_damage(9999)

	# 治疗自身
	if skill_owner.has_node("HealthComponent"):
		skill_owner.health_component.heal(heal_amount)
	elif "hp" in skill_owner:
		skill_owner.hp = min(skill_owner.hp + heal_amount, skill_owner.max_hp)

	Global.spawn_floating_text(skill_owner.global_position, "DEVOUR!", Color(0.3, 0.9, 0.2))
	Global.on_camera_shake.emit(8.0, 0.2)
	start_cooldown()
