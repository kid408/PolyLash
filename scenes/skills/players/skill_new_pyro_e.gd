extends SkillBase
class_name SkillNewPyroE

## ==============================================================================
## 新火法E技能 - 火焰环
## ==============================================================================
## 
## 功能说明:
## - 按E键在角色周围产生火焰环效果
## - 击退附近敌人
## 
## ==============================================================================

# ==============================================================================
# 技能参数（从CSV加载）
# ==============================================================================

## 击退力度
var knockback_force: float = 600.0

## 爆炸半径
var explosion_radius: float = 160.0

# ==============================================================================
# 技能执行
# ==============================================================================

## 爆炸伤害
var explosion_damage: int = 45

## 执行技能
func execute() -> void:
	if not consume_energy():
		if skill_owner:
			Global.spawn_floating_text(skill_owner.global_position, "No Energy!", Color.RED)
		return

	print("[SkillNewPyroE] ✅ 火焰环执行! 位置: %s, 半径: %.0f" % [skill_owner.global_position, explosion_radius])

	# 击退并伤害附近敌人
	var enemies = get_tree().get_nodes_in_group("enemies")
	var hit_count = 0
	for enemy in enemies:
		if is_instance_valid(enemy):
			var dist = skill_owner.global_position.distance_to(enemy.global_position)
			if dist < explosion_radius:
				# 造成伤害
				if enemy.has_node("HealthComponent"):
					enemy.get_node("HealthComponent").take_damage(explosion_damage)
				# 击退
				var dir = (enemy.global_position - skill_owner.global_position).normalized()
				enemy.global_position += dir * knockback_force * 0.1
				hit_count += 1

	print("[SkillNewPyroE] 命中 %d 个敌人, 伤害: %d" % [hit_count, explosion_damage])

	# 视觉爆炸效果
	spawn_skill_vfx(skill_owner.global_position, Color(1.0, 0.4, 0.1, 0.8), 0.8)
	Global.on_camera_shake.emit(8.0, 0.2)
	Global.spawn_floating_text(skill_owner.global_position, "FIRE RING!", Color(1.0, 0.4, 0.1))
	start_cooldown()
