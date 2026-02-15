extends SkillBase
class_name SkillVoodooE

## ==============================================================================
## 巫毒E技能 - 自伤触发诅咒伤害
## ==============================================================================
## 
## 功能说明:
## - 按E键对自身造成伤害
## - 然后对地图上所有带 curse 状态的敌人造成等量诅咒伤害
## - 显示 "VOODOO!" 浮动文字和命中数量
## 
## ==============================================================================

# ==============================================================================
# 技能参数（从CSV加载）
# ==============================================================================

## 自伤值
var self_damage: int = 20

## 诅咒伤害
var curse_damage: int = 60

# ==============================================================================
# 技能执行
# ==============================================================================

## 执行技能
func execute() -> void:
	if not consume_energy():
		if skill_owner:
			Global.spawn_floating_text(skill_owner.global_position, "No Energy!", Color.RED)
		return

	# 1. 对自身造成伤害
	if skill_owner.has_node("HealthComponent"):
		skill_owner.get_node("HealthComponent").take_damage(self_damage)
	elif "hp" in skill_owner:
		skill_owner.hp = max(skill_owner.hp - self_damage, 1)

	# 2. 查找所有带 curse 状态的敌人并造成伤害
	var cursed_count: int = 0
	var enemies = get_tree().get_nodes_in_group("enemies")
	for enemy in enemies:
		if not is_instance_valid(enemy):
			continue
		# 检查敌人是否有诅咒状态（优先使用 StatusComponent，回退到内置状态系统）
		var has_curse = false
		if enemy.has_node("StatusComponent"):
			var status_comp: StatusComponent = enemy.get_node("StatusComponent")
			has_curse = status_comp.has_status("curse")
		elif enemy.has_method("has_status"):
			has_curse = enemy.has_status("curse")
		
		if not has_curse:
			continue

		# 对诅咒敌人造成伤害
		if enemy.has_node("HealthComponent"):
			enemy.get_node("HealthComponent").take_damage(curse_damage)
			Global.spawn_floating_text(enemy.global_position, "-%d" % curse_damage, Color(0.5, 0.1, 0.4))
		cursed_count += 1

	# 3. 显示浮动文字
	if cursed_count > 0:
		Global.on_camera_shake.emit(6.0, 0.15)
		Global.spawn_floating_text(skill_owner.global_position, "VOODOO! x%d" % cursed_count, Color(0.5, 0.1, 0.4))
	else:
		Global.spawn_floating_text(skill_owner.global_position, "No Cursed!", Color(0.6, 0.6, 0.6))

	start_cooldown()
