extends SkillBase
class_name SkillNewTempestE

## ==============================================================================
## 新风暴E技能 - 龙卷风抛飞
## ==============================================================================
## 
## 功能说明:
## - 按E键在角色周围产生龙卷风效果
## - 将附近敌人抛向空中（大力击退 + 短暂眩晕）
## 
## ==============================================================================

# ==============================================================================
# 技能参数（从CSV加载）
# ==============================================================================

## 抛飞力度
var throw_force: float = 800.0

## 龙卷风范围
var throw_radius: float = 180.0

## 眩晕时间
var stun_duration: float = 1.0

# ==============================================================================
# 技能执行
# ==============================================================================

## 龙卷风伤害
var throw_damage: int = 45

## 执行技能
func execute() -> void:
	if not consume_energy():
		if skill_owner:
			Global.spawn_floating_text(skill_owner.global_position, "No Energy!", Color.RED)
		return

	# 抛飞并伤害附近敌人
	var enemies = get_tree().get_nodes_in_group("enemies")
	var hit_count = 0
	for enemy in enemies:
		if is_instance_valid(enemy):
			var dist = skill_owner.global_position.distance_to(enemy.global_position)
			if dist < throw_radius:
				# 造成伤害
				if enemy.has_node("HealthComponent"):
					enemy.get_node("HealthComponent").take_damage(throw_damage)
				# 抛飞
				var dir = (enemy.global_position - skill_owner.global_position).normalized()
				enemy.global_position += dir * throw_force * 0.1
				# 施加眩晕
				if enemy.has_method("apply_status"):
					enemy.apply_status("stun", stun_duration, 0.0)
				hit_count += 1

	print("[SkillNewTempestE] 龙卷风命中 %d 个敌人, 伤害: %d" % [hit_count, throw_damage])
	spawn_skill_vfx(skill_owner.global_position, Color(0.3, 0.9, 0.8, 0.8), 0.9)
	Global.on_camera_shake.emit(10.0, 0.3)
	Global.spawn_floating_text(skill_owner.global_position, "TORNADO!", Color(0.3, 0.9, 0.8))
	start_cooldown()
