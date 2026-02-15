extends SkillBase
class_name SkillExecutionerE

## ==============================================================================
## 处刑E技能 - 处决
## ==============================================================================
## 
## 功能说明:
## - 按E键处决范围内所有低血量敌人
## - 敌人HP低于阈值（最大HP的百分比）时立即击杀（9999伤害）
## - 显示 "EXECUTE!" 浮动文字
## 
## ==============================================================================

# ==============================================================================
# 技能参数（从CSV加载）
# ==============================================================================

## 处刑范围
var execute_radius: float = 200.0

## 处刑血量阈值（最大HP的百分比，0.2 = 20%）
var execute_threshold: float = 0.2

# ==============================================================================
# 技能执行
# ==============================================================================

## 执行技能
func execute() -> void:
	if not consume_energy():
		if skill_owner:
			Global.spawn_floating_text(skill_owner.global_position, "No Energy!", Color.RED)
		return

	var executed_count: int = 0
	var owner_pos: Vector2 = skill_owner.global_position

	var enemies = get_tree().get_nodes_in_group("enemies")
	for enemy in enemies:
		if not is_instance_valid(enemy):
			continue
		var dist = owner_pos.distance_to(enemy.global_position)
		if dist > execute_radius:
			continue

		# 检查敌人HP是否低于阈值
		var current_hp: float = 0.0
		var max_hp: float = 1.0
		if enemy.has_node("HealthComponent"):
			current_hp = enemy.health_component.current_health
			max_hp = enemy.health_component.max_health
		elif "hp" in enemy and "max_hp" in enemy:
			current_hp = enemy.hp
			max_hp = enemy.max_hp

		if max_hp > 0 and current_hp <= max_hp * execute_threshold:
			# 处决：造成9999伤害（即死）
			if enemy.has_node("HealthComponent"):
				enemy.health_component.take_damage(9999)
			elif enemy.has_method("take_damage"):
				enemy.take_damage(9999)
			Global.spawn_floating_text(enemy.global_position, "EXECUTE!", Color(0.6, 0.1, 0.1))
			executed_count += 1

	if executed_count > 0:
		Global.on_camera_shake.emit(10.0, 0.25)
	else:
		Global.spawn_floating_text(owner_pos, "No Target!", Color.GRAY)

	start_cooldown()
