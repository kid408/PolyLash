extends SkillBase
class_name SkillNewTotemE

const BASE_PULSE_RADIUS: float = 155.0
const BASE_PULSE_DAMAGE: int = 34

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

	if SkillEffectManager != null and SkillEffectManager.has_method("command_summons"):
		SkillEffectManager.command_summons("skill_new_totem_q", "self_destruct")

	for i in range(pulse_count):
		var delay: float = pulse_gap * float(i)
		var timer: SceneTreeTimer = get_tree().create_timer(delay)
		timer.timeout.connect(
			_on_resonance_pulse_timeout.bind(
				skill_owner.global_position,
				pulse_radius * (0.78 + 0.10 * float(i)),
				int(round(float(pulse_damage) * (0.86 + 0.10 * float(i)))),
				duration_amp,
				i == pulse_count - 1
			)
		)

	if skill_owner.has_method("gain_energy"):
		skill_owner.gain_energy(3.0 if not is_f_window_active() else 4.8)

	Global.spawn_floating_text(skill_owner.global_position, "TOTEM RESONANCE", Color(0.62, 0.55, 1.0))
	Global.on_camera_shake.emit(8.2, 0.16)
	start_cooldown()

func _on_resonance_pulse_timeout(center: Vector2, radius: float, damage: int, duration_amp: float, is_last: bool) -> void:
	var hit: int = 0
	for enemy in _get_enemies_in_radius(center, radius):
		_apply_damage(enemy, damage)
		_apply_status(enemy, "marked", 1.4, 0.2, 1, 0.3)
		_apply_status(enemy, "slow", 1.0 * duration_amp, 0.28, 1, 0.1)
		if is_last:
			_apply_status(enemy, "stun", 0.28, 0.0, 1, 0.1)
		hit += 1
	if hit > 0:
		var color: Color = Color(0.62, 0.58, 1.0)
		var text: String = "PULSE x%d" % hit
		if is_last:
			text = "OVERLOAD x%d" % hit
		Global.spawn_floating_text(center, text, color)
	spawn_skill_vfx(center, Color(0.62, 0.55, 1.0, 0.78), 0.68)

func _get_enemies_in_radius(center: Vector2, radius: float) -> Array:
	var result: Array = []
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(enemy):
			continue
		if not (enemy is Node2D):
			continue
		var enemy_node: Node2D = enemy
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
