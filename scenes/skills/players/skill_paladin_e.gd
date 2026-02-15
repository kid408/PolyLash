extends SkillBase
class_name SkillPaladinE

## ==============================================================================
## 圣骑士E技能 - 嘲讽
## ==============================================================================
## 
## 功能说明:
## - 按E键施放嘲讽效果，强制范围内敌人攻击当前角色
## - 通过设置 meta "taunt_target" 指向 skill_owner
## - 持续时间结束后自动移除嘲讽
## 
## ==============================================================================

# ==============================================================================
# 圣骑士E技能专属参数（从CSV加载）
# ==============================================================================

## 嘲讽范围
var taunt_radius: float = 250.0

## 嘲讽持续时间
var taunt_duration: float = 3.0

# ==============================================================================
# 技能执行
# ==============================================================================

## 执行技能
func execute() -> void:
	if not consume_energy():
		if skill_owner:
			Global.spawn_floating_text(skill_owner.global_position, "No Energy!", Color.RED)
		return

	# 嘲讽并伤害范围内所有敌人
	var enemies = get_tree().get_nodes_in_group("enemies")
	var hit_count = 0
	for enemy in enemies:
		if not is_instance_valid(enemy):
			continue
		var dist = skill_owner.global_position.distance_to(enemy.global_position)
		if dist < taunt_radius:
			# 造成伤害
			if enemy.has_node("HealthComponent"):
				enemy.get_node("HealthComponent").take_damage(25)
			# 嘲讽 - 使用 enemy 的 set_taunt_target 方法（设置 override_target）
			if enemy.has_method("set_taunt_target"):
				enemy.set_taunt_target(skill_owner)
				# 持续时间结束后清除嘲讽
				var e_ref = weakref(enemy)
				var timer = get_tree().create_timer(taunt_duration)
				timer.timeout.connect(func():
					var e = e_ref.get_ref()
					if e and is_instance_valid(e):
						e.override_target = null
				)
			hit_count += 1

	print("[SkillPaladinE] 嘲讽命中 %d 个敌人" % hit_count)
	spawn_skill_vfx(skill_owner.global_position, Color(1.0, 0.85, 0.3, 0.8), 0.7)
	Global.on_camera_shake.emit(6.0, 0.2)
	Global.spawn_floating_text(skill_owner.global_position, "TAUNT!", Color(1.0, 0.85, 0.3))
	start_cooldown()
