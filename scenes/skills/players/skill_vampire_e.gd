extends SkillBase
class_name SkillVampireE

## ==============================================================================
## 血族E技能 - 吸血
## ==============================================================================
## 
## 功能说明:
## - 按E键吸取附近敌人的生命值并恢复自身
## - 对范围内所有敌人造成伤害，按治疗比例恢复自身HP
## 
## ==============================================================================

# ==============================================================================
# 血族E技能专属参数（从CSV加载）
# ==============================================================================

## 吸血范围
var drain_radius: float = 200.0

## 吸血伤害
var drain_damage: int = 40

## 治疗比例（50%）
var heal_percent: float = 0.5

# ==============================================================================
# 技能执行
# ==============================================================================

## 执行技能
func execute() -> void:
	if not consume_energy():
		if skill_owner:
			Global.spawn_floating_text(skill_owner.global_position, "No Energy!", Color.RED)
		return

	var total_drained: int = 0

	# 吸取范围内所有敌人的HP
	var enemies = get_tree().get_nodes_in_group("enemies")
	for enemy in enemies:
		if not is_instance_valid(enemy):
			continue
		var dist = skill_owner.global_position.distance_to(enemy.global_position)
		if dist > drain_radius:
			continue

		# 造成伤害
		if enemy.has_node("HealthComponent"):
			enemy.health_component.take_damage(drain_damage)
		total_drained += drain_damage

	# 恢复自身HP
	if skill_owner and skill_owner.has_node("HealthComponent") and total_drained > 0:
		var heal_amount = int(total_drained * heal_percent)
		var hc = skill_owner.health_component
		hc.current_health = min(hc.current_health + heal_amount, hc.max_health)
		hc.on_health_changed.emit(hc.current_health, hc.max_health)
		Global.spawn_floating_text(skill_owner.global_position, "+%d HP" % heal_amount, Color(0.7, 0.1, 0.1))

	Global.on_camera_shake.emit(6.0, 0.2)
	spawn_skill_vfx(skill_owner.global_position, Color(0.7, 0.1, 0.1, 0.8), 0.7)
	Global.spawn_floating_text(skill_owner.global_position, "DRAIN!", Color(0.7, 0.1, 0.1))
	start_cooldown()
