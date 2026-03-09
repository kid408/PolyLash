extends SkillBase
class_name SkillMedicE

## ==============================================================================
## 军医E技能 - 吸血Buff
## ==============================================================================
## 
## 功能说明:
## - 按E键为当前角色提供5秒的生命偷取Buff
## - 通过 meta 设置 lifesteal_bonus，持续时间结束后自动移除
## 
## ==============================================================================

# ==============================================================================
# 军医E技能专属参数（从CSV加载）
# ==============================================================================

## 吸血持续时间
var lifesteal_duration: float = 5.0

## 吸血比例（30%）
var lifesteal_value: float = 0.3

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

	var damage_amp: float = get_e_damage_amp(0.2, 0.22)
	var duration_amp: float = get_e_duration_amp(0.4)
	var final_lifesteal: float = lifesteal_value * (1.0 + (damage_amp - 1.0) * 0.55)
	var final_duration: float = lifesteal_duration * duration_amp

	# 为 skill_owner 添加吸血 Buff
	skill_owner.set_meta("lifesteal_bonus", final_lifesteal)
	# 创建计时器，持续时间结束后移除
	var owner_ref: WeakRef = weakref(skill_owner)
	var timer: SceneTreeTimer = get_tree().create_timer(final_duration)
	timer.timeout.connect(_on_lifesteal_timeout.bind(owner_ref))

	if is_f_window_active() and skill_owner.has_node("HealthComponent"):
		var hc = skill_owner.get_node("HealthComponent")
		var burst_heal: float = float(hc.max_health) * 0.12
		hc.heal(burst_heal)
		Global.spawn_floating_text(skill_owner.global_position, "+%d" % int(round(burst_heal)), Color(0.55, 1.0, 0.72))
		if skill_owner.has_method("gain_energy"):
			skill_owner.gain_energy(18.0)

	Global.spawn_floating_text(skill_owner.global_position, "LIFESTEAL!", Color(0.4, 1.0, 0.5))
	start_cooldown()

func _on_lifesteal_timeout(owner_ref: WeakRef) -> void:
	var owner = owner_ref.get_ref() if owner_ref != null else null
	if owner and is_instance_valid(owner):
		owner.remove_meta("lifesteal_bonus")
