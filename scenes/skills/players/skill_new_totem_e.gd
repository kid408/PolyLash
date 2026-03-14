extends SkillBase
class_name SkillNewTotemE

const BASE_PULSE_RADIUS: float = 155.0
const BASE_PULSE_DAMAGE: int = 34

const TOTEM_META_CENTER: String = "new_totem_field_center"
const TOTEM_META_RADIUS: String = "new_totem_field_radius"
const TOTEM_META_EXPIRE_MSEC: String = "new_totem_field_expire_msec"

func execute() -> void:
	if not consume_energy():
		if is_instance_valid(skill_owner):
			Global.spawn_floating_text(skill_owner.global_position, "No Energy!", Color.RED)
		return
	if not is_instance_valid(skill_owner):
		return

	var damage_amp: float = get_e_damage_amp(0.26, 0.34)
	var duration_amp: float = get_e_duration_amp(0.36)
	var pulse_radius: float = BASE_PULSE_RADIUS * (1.0 + (duration_amp - 1.0) * 0.40)
	var pulse_damage: int = max(1, int(round(float(BASE_PULSE_DAMAGE) * damage_amp)))
	var pulse_count: int = 2 if not is_f_window_active() else 3
	var pulse_gap: float = 0.16 if not is_f_window_active() else 0.12
	var pulse_center: Vector2 = skill_owner.global_position

	var window_data: Array = _get_totem_window(pulse_center, pulse_radius)
	var synergy_used: bool = bool(window_data[0])
	if synergy_used and window_data.size() > 1 and window_data[1] is Vector2:
		pulse_center = window_data[1]
	if synergy_used and window_data.size() > 2:
		pulse_radius = max(pulse_radius, float(window_data[2]) * 0.9)
		pulse_damage = int(round(float(pulse_damage) * 1.15))
		pulse_count += 1

	if SkillEffectManager != null and SkillEffectManager.has_method("command_summons"):
		SkillEffectManager.command_summons("skill_new_totem_q", "self_destruct")

	for i: int in range(pulse_count):
		var delay: float = pulse_gap * float(i)
		var timer: SceneTreeTimer = get_tree().create_timer(delay)
		timer.timeout.connect(
			_on_resonance_pulse_timeout.bind(
				pulse_center,
				pulse_radius * (0.78 + 0.10 * float(i)),
				int(round(float(pulse_damage) * (0.86 + 0.10 * float(i)))),
				duration_amp,
				i == pulse_count - 1,
				synergy_used
			)
		)

	if skill_owner.has_method("gain_energy"):
		skill_owner.gain_energy(3.0 if not is_f_window_active() else 4.8)

	if synergy_used:
		_refund_q_cooldown(1.1)
		Global.spawn_floating_text(skill_owner.global_position, "TOTEM RESONANCE+", Color(0.62, 0.55, 1.0))
	else:
		Global.spawn_floating_text(skill_owner.global_position, "TOTEM RESONANCE", Color(0.62, 0.55, 1.0))
	Global.on_camera_shake.emit(8.2, 0.16)
	start_cooldown()

func _on_resonance_pulse_timeout(center: Vector2, radius: float, damage: int, duration_amp: float, is_last: bool, synergy_used: bool) -> void:
	var hit: int = 0
	for enemy: Node2D in _get_enemies_in_radius(center, radius):
		_apply_damage(enemy, damage)
		_apply_status(enemy, "marked", 1.4, 0.2, 1, 0.3)
		_apply_status(enemy, "slow", 1.0 * duration_amp, 0.28, 1, 0.1)
		if is_last:
			_apply_status(enemy, "stun", 0.28, 0.0, 1, 0.1)
		elif synergy_used:
			_apply_status(enemy, "curse", 1.0 * duration_amp, 8.0, 1, 0.7)
		hit += 1
	if hit > 0:
		var color: Color = Color(0.62, 0.58, 1.0)
		var text: String = "PULSE x%d" % hit
		if is_last:
			text = "OVERLOAD x%d" % hit
		Global.spawn_floating_text(center, text, color)
	spawn_skill_vfx(center, Color(0.62, 0.55, 1.0, 0.78), 0.68)

func _get_totem_window(default_center: Vector2, default_radius: float) -> Array:
	var data: Array = [false, default_center, default_radius]
	if not is_instance_valid(skill_owner):
		return data
	if not skill_owner.has_meta(TOTEM_META_EXPIRE_MSEC):
		return data
	var expire_msec: int = int(skill_owner.get_meta(TOTEM_META_EXPIRE_MSEC, 0))
	if Time.get_ticks_msec() > expire_msec:
		return data
	var center_val: Variant = skill_owner.get_meta(TOTEM_META_CENTER, default_center)
	var radius_val: Variant = skill_owner.get_meta(TOTEM_META_RADIUS, default_radius)
	if not (center_val is Vector2):
		return data
	data[0] = true
	data[1] = center_val
	data[2] = max(default_radius, float(radius_val))
	return data

func _refund_q_cooldown(seconds: float) -> void:
	if seconds <= 0.0 or not is_instance_valid(skill_owner):
		return
	var skill_manager: Node = skill_owner.get_node_or_null("SkillManager")
	if skill_manager == null or not ("skill_slots" in skill_manager):
		return
	var slots: Dictionary = skill_manager.skill_slots
	if not slots.has("q"):
		return
	var q_skill_obj: Variant = slots.get("q")
	if q_skill_obj == null or not (q_skill_obj is SkillBase):
		return
	var q_skill: SkillBase = q_skill_obj
	var remaining: float = q_skill.get_cooldown_remaining()
	if remaining <= 0.0:
		return
	q_skill.set_cooldown_remaining(max(0.0, remaining - seconds))

func _get_enemies_in_radius(center: Vector2, radius: float) -> Array:
	var result: Array = []
	for enemy_obj: Variant in get_tree().get_nodes_in_group("enemies"):
		if enemy_obj == null or not is_instance_valid(enemy_obj):
			continue
		if not (enemy_obj is Node2D):
			continue
		var enemy_node: Node2D = enemy_obj
		if center.distance_to(enemy_node.global_position) <= radius:
			result.append(enemy_node)
	return result

func _apply_damage(enemy: Node, amount: int) -> void:
	if not is_instance_valid(enemy):
		return
	if enemy.has_node("HealthComponent"):
		var hc: Node = enemy.get_node("HealthComponent")
		if hc and hc.has_method("take_damage"):
			hc.take_damage(max(1, amount))

func _apply_status(enemy: Node, status_name: String, duration: float, value: float, stacks: int = 1, tick_interval: float = 0.6) -> void:
	if not is_instance_valid(enemy):
		return
	if enemy.has_method("apply_status"):
		enemy.apply_status(status_name, max(0.1, duration), value, max(1, stacks), max(0.05, tick_interval))
