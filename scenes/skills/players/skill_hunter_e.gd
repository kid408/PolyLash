extends SkillBase
class_name SkillHunterE

## ==============================================================================
## 猎人E技能 - 标记目标
## ==============================================================================
## 
## 功能说明:
## - 按E键标记范围内最近的敌人
## - 被标记的敌人受到的伤害增加（通过StatusComponent的marked状态）
## - 无目标时显示 "No Target!" 提示
## 
## ==============================================================================

# ==============================================================================
# 技能参数（从CSV加载）
# ==============================================================================

## 标记范围
var mark_radius: float = 300.0

## 标记持续时间
var mark_duration: float = 5.0

## 标记伤害放大比例（0.5 = 50%）
var mark_damage_amp: float = 0.5

# ==============================================================================
# 技能执行
# ==============================================================================

## 执行技能
func execute() -> void:
	if not consume_energy():
		if skill_owner:
			Global.spawn_floating_text(skill_owner.global_position, "No Energy!", Color.RED)
		return

	var owner_pos: Vector2 = skill_owner.global_position

	# 查找范围内最近的敌人
	var nearest_enemy: Node2D = null
	var nearest_dist: float = mark_radius

	var enemies = get_tree().get_nodes_in_group("enemies")
	for enemy in enemies:
		if is_instance_valid(enemy):
			var dist = owner_pos.distance_to(enemy.global_position)
			if dist < nearest_dist:
				nearest_dist = dist
				nearest_enemy = enemy

	if nearest_enemy:
		# 造成少量伤害
		if nearest_enemy.has_node("HealthComponent"):
			nearest_enemy.get_node("HealthComponent").take_damage(20)
		# 应用标记状态
		if nearest_enemy.has_method("apply_status"):
			nearest_enemy.apply_status("marked", mark_duration, mark_damage_amp, 1, 999.0)

		Global.on_camera_shake.emit(5.0, 0.15)
		Global.spawn_floating_text(nearest_enemy.global_position, "MARKED!", Color(0.2, 0.5, 0.2))
	else:
		Global.spawn_floating_text(owner_pos, "No Target!", Color.YELLOW)

	start_cooldown()
