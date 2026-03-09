extends SkillBase
class_name SkillBlacksmithE

## ==============================================================================
## 铁匠E技能 - 重置Q技能冷却
## ==============================================================================
## 
## 功能说明:
## - 按E键重置当前角色的Q技能冷却时间
## - 通过 SkillManager 访问Q技能并调用 reset_cooldown()
## 
## ==============================================================================

# ==============================================================================
# 技能执行
# ==============================================================================

## 执行技能
func execute() -> void:
	if not consume_energy():
		if skill_owner:
			Global.spawn_floating_text(skill_owner.global_position, "No Energy!", Color.RED)
		return
	if not skill_owner:
		return

	# 通过 SkillManager 获取Q技能并重置冷却
	var q_skill_reset = false
	var skill_manager = skill_owner.get_node_or_null("SkillManager")
	if skill_manager and skill_manager.has_skill("q"):
		var q_skill = skill_manager.get_skill("q")
		if q_skill and is_instance_valid(q_skill):
			q_skill.reset_cooldown()
			q_skill_reset = true

	if is_f_window_active():
		var heat_amp: float = get_e_damage_amp(0.25, 0.35)
		var had_attack_meta: bool = skill_owner.has_meta("attack_boost")
		var old_attack_meta: float = float(skill_owner.get_meta("attack_boost")) if had_attack_meta else 0.0
		var overheat_boost: float = 0.22 + (heat_amp - 1.0) * 0.55
		skill_owner.set_meta("attack_boost", old_attack_meta + overheat_boost)
		var owner_ref: WeakRef = weakref(skill_owner)
		var overheat_duration: float = 3.2 * get_e_duration_amp(0.35)
		get_tree().create_timer(overheat_duration).timeout.connect(
			_on_overheat_timeout.bind(owner_ref, had_attack_meta, old_attack_meta)
		)
		Global.spawn_floating_text(skill_owner.global_position, "OVERHEAT!", Color(1.0, 0.55, 0.2))

	if q_skill_reset:
		Global.spawn_floating_text(skill_owner.global_position, "COOLDOWN RESET!", Color(0.9, 0.5, 0.1))
	else:
		Global.spawn_floating_text(skill_owner.global_position, "NO Q SKILL!", Color.YELLOW)

	Global.on_camera_shake.emit(5.0, 0.15)
	start_cooldown()

func _on_overheat_timeout(owner_ref: WeakRef, had_attack_meta: bool, old_attack_meta: float) -> void:
	var owner = owner_ref.get_ref() if owner_ref != null else null
	if owner == null or not is_instance_valid(owner):
		return
	if had_attack_meta:
		owner.set_meta("attack_boost", old_attack_meta)
	elif owner.has_meta("attack_boost"):
		owner.remove_meta("attack_boost")
