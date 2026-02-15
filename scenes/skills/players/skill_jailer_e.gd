extends SkillBase
class_name SkillJailerE

## ==============================================================================
## 狱警E技能 - 扇形盾击
## ==============================================================================
## 
## 功能说明:
## - 按E键在角色前方扇形范围内产生盾击效果
## - 击退扇形范围内的敌人
## 
## ==============================================================================

# ==============================================================================
# 技能参数（从CSV加载）
# ==============================================================================

## 击退力度
var knockback_force: float = 600.0

## 扇形范围半径
var fan_radius: float = 200.0

## 扇形角度（度）
var fan_angle: float = 90.0

# ==============================================================================
# 技能执行
# ==============================================================================

## 盾击伤害
var bash_damage: int = 40

## 执行技能
func execute() -> void:
	if not consume_energy():
		if skill_owner:
			Global.spawn_floating_text(skill_owner.global_position, "No Energy!", Color.RED)
		return

	# 获取角色朝向（面向鼠标方向）
	var facing_dir = (skill_owner.get_global_mouse_position() - skill_owner.global_position).normalized()

	var half_angle_rad = deg_to_rad(fan_angle / 2.0)

	# 扇形范围击退并伤害
	var enemies = get_tree().get_nodes_in_group("enemies")
	var hit_count = 0
	for enemy in enemies:
		if is_instance_valid(enemy):
			var to_enemy = enemy.global_position - skill_owner.global_position
			var dist = to_enemy.length()
			if dist < fan_radius and dist > 0:
				var angle_to_enemy = facing_dir.angle_to(to_enemy.normalized())
				if abs(angle_to_enemy) <= half_angle_rad:
					# 造成伤害
					if enemy.has_node("HealthComponent"):
						enemy.get_node("HealthComponent").take_damage(bash_damage)
					# 击退
					var dir = to_enemy.normalized()
					enemy.global_position += dir * knockback_force * 0.1
					# 施加短暂眩晕
					if enemy.has_method("apply_status"):
						enemy.apply_status("stun", 0.5, 0.0)
					hit_count += 1

	print("[SkillJailerE] 盾击命中 %d 个敌人, 伤害: %d" % [hit_count, bash_damage])
	spawn_skill_vfx(skill_owner.global_position, Color(0.9, 0.8, 0.2, 0.8), 0.7)
	Global.on_camera_shake.emit(8.0, 0.2)
	Global.spawn_floating_text(skill_owner.global_position, "SHIELD BASH!", Color(0.9, 0.8, 0.2))
	start_cooldown()
