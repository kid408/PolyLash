extends SkillBase
class_name SkillMidasE

## ==============================================================================
## 炼金E技能 - 点金术
## ==============================================================================
## 
## 功能说明:
## - 按E键对最近的敌人施加点金术
## - 对单个最近敌人造成大量伤害并掉落金币
## 
## ==============================================================================

# ==============================================================================
# 技能参数（从CSV加载）
# ==============================================================================

## 点金伤害
var touch_damage: int = 200

## 点金范围
var touch_radius: float = 120.0

## 掉落金币数量
var gold_drop: int = 30

# ==============================================================================
# 技能执行
# ==============================================================================

## 执行技能
func execute() -> void:
	if not consume_energy():
		if skill_owner:
			Global.spawn_floating_text(skill_owner.global_position, "No Energy!", Color.RED)
		return

	# 找到最近的敌人
	var nearest_enemy: Node2D = null
	var nearest_dist: float = touch_radius
	var enemies = get_tree().get_nodes_in_group("enemies")
	for enemy in enemies:
		if is_instance_valid(enemy):
			var dist = skill_owner.global_position.distance_to(enemy.global_position)
			if dist < nearest_dist:
				nearest_dist = dist
				nearest_enemy = enemy

	if nearest_enemy:
		# 造成伤害
		if nearest_enemy.has_node("HealthComponent"):
			nearest_enemy.health_component.take_damage(touch_damage)
		elif nearest_enemy.has_method("take_damage"):
			nearest_enemy.take_damage(touch_damage)

		# 掉落金币
		Global.spawn_coin(nearest_enemy.global_position, gold_drop)

		spawn_skill_vfx(nearest_enemy.global_position, Color(0.9, 0.7, 0.1, 0.8), 0.6)
		Global.on_camera_shake.emit(6.0, 0.15)
		Global.spawn_floating_text(nearest_enemy.global_position, "GOLD TOUCH!", Color(0.9, 0.7, 0.1))
	else:
		Global.spawn_floating_text(skill_owner.global_position, "No Target!", Color.GRAY)

	start_cooldown()
