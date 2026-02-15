extends SkillBase
class_name SkillGlacierE

## ==============================================================================
## 冰河E技能 - 冰爆
## ==============================================================================
## 
## 功能说明:
## - 按E键在角色周围产生冰爆效果
## - 击退附近敌人并为角色添加临时护甲
## 
## ==============================================================================

# ==============================================================================
# 技能参数（从CSV加载）
# ==============================================================================

## 击退力度
var knockback_force: float = 500.0

## 护盾值
var shield_amount: int = 3

## 爆炸半径
var explosion_radius: float = 150.0

# ==============================================================================
# 技能执行
# ==============================================================================

## 冰爆伤害
var explosion_damage: int = 50

## 执行技能
func execute() -> void:
	if not consume_energy():
		if skill_owner:
			Global.spawn_floating_text(skill_owner.global_position, "No Energy!", Color.RED)
		return

	print("[SkillGlacierE] ✅ 冰爆执行! 位置: %s, 半径: %.0f" % [skill_owner.global_position, explosion_radius])

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
				# 施加短暂冰冻
				if enemy.has_method("apply_status"):
					enemy.apply_status("freeze", 1.0, 0.0)
				hit_count += 1

	print("[SkillGlacierE] 命中 %d 个敌人 (总敌人数: %d), 伤害: %d" % [hit_count, enemies.size(), explosion_damage])

	# 添加护甲
	if "armor" in skill_owner:
		skill_owner.armor = min(skill_owner.armor + shield_amount, skill_owner.max_armor)

	# 视觉爆炸效果
	spawn_skill_vfx(skill_owner.global_position, Color(0.5, 0.8, 1.0, 0.8), 0.8)
	Global.on_camera_shake.emit(8.0, 0.2)
	Global.spawn_floating_text(skill_owner.global_position, "ICE BURST!", Color(0.5, 0.8, 1.0))
	start_cooldown()
