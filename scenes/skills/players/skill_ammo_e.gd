extends SkillBase
class_name SkillAmmoE

## ==============================================================================
## 弹药E技能 - 能量补给
## ==============================================================================
## 
## 功能说明:
## - 按E键立即将当前角色的能量恢复至满值
## - energy_cost 为 0（免费技能），但有冷却时间
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

	# 恢复能量至满值
	if "energy" in skill_owner:
		skill_owner.energy = skill_owner.max_energy

	if is_f_window_active():
		var had_cd_buff: bool = skill_owner.has_meta("buff_cooldown_reduction")
		var old_cd_buff: float = float(skill_owner.get_meta("buff_cooldown_reduction")) if had_cd_buff else 0.0
		var cd_buff: float = clamp(old_cd_buff + 0.18, 0.0, 0.85)
		skill_owner.set_meta("buff_cooldown_reduction", cd_buff)

		var owner_ref: WeakRef = weakref(skill_owner)
		var overclock_duration: float = 2.6 * get_e_duration_amp(0.3)
		get_tree().create_timer(overclock_duration).timeout.connect(
			_on_overclock_timeout.bind(owner_ref, had_cd_buff, old_cd_buff)
		)
		Global.spawn_floating_text(skill_owner.global_position, "OVERCLOCK!", Color(0.5, 0.95, 0.45))

	Global.spawn_floating_text(skill_owner.global_position, "RESUPPLY!", Color(0.3, 0.6, 0.2))
	start_cooldown()

func _on_overclock_timeout(owner_ref: WeakRef, had_cd_buff: bool, old_cd_buff: float) -> void:
	var owner = owner_ref.get_ref() if owner_ref != null else null
	if owner == null or not is_instance_valid(owner):
		return
	if had_cd_buff:
		owner.set_meta("buff_cooldown_reduction", old_cd_buff)
	elif owner.has_meta("buff_cooldown_reduction"):
		owner.remove_meta("buff_cooldown_reduction")
