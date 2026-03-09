extends SkillBase
class_name SkillNewTempestE

var throw_force: float = 800.0
var throw_radius: float = 180.0
var stun_duration: float = 1.0
var throw_damage: int = 45

func execute() -> void:
	if not consume_energy():
		if is_instance_valid(skill_owner):
			Global.spawn_floating_text(skill_owner.global_position, "No Energy!", Color.RED)
		return
	if not is_instance_valid(skill_owner):
		return

	var damage_amp: float = get_e_damage_amp(0.30, 0.34)
	var duration_amp: float = get_e_duration_amp(0.36)
	var final_radius: float = throw_radius * (1.0 + (duration_amp - 1.0) * 0.35)
	var final_damage: int = max(1, int(round(float(throw_damage) * damage_amp)))
	var final_throw: float = throw_force * (1.0 + (duration_amp - 1.0) * 0.40)
	var final_stun: float = stun_duration * duration_amp

	var center: Vector2 = skill_owner.global_position
	var enemies: Array = _get_enemies_in_radius(center, final_radius)
	var hit_count: int = 0
	for enemy in enemies:
		_apply_damage(enemy, final_damage)
		_apply_status(enemy, "slow", 1.1 * duration_amp, 0.30, 1, 0.1)
		_apply_status(enemy, "stun", final_stun, 0.0, 1, 0.1)
		_knock_enemy(enemy, center, final_throw)
		hit_count += 1

	var aim_dir: Vector2 = _get_aim_direction()
	var pulse_center: Vector2 = center + aim_dir * min(final_radius * 0.56, 130.0)
	var pulse_delay: float = 0.20 if not is_f_window_active() else 0.14
	var timer: SceneTreeTimer = get_tree().create_timer(pulse_delay)
	timer.timeout.connect(
		_on_tempest_pulse_timeout.bind(
			pulse_center,
			final_radius * (0.62 if not is_f_window_active() else 0.74),
			max(1, int(round(float(final_damage) * (0.62 if not is_f_window_active() else 0.84)))),
			final_throw * 0.7,
			duration_amp
		)
	)

	if hit_count > 0:
		Global.spawn_floating_text(skill_owner.global_position, "UPDRAFT x%d" % hit_count, Color(0.46, 1.0, 0.9))
	else:
		Global.spawn_floating_text(skill_owner.global_position, "WIND STEP", Color(0.5, 0.9, 0.85))
	spawn_skill_vfx(center, Color(0.35, 0.92, 0.82, 0.78), 0.86)
	Global.on_camera_shake.emit(8.8, 0.18)
	start_cooldown()

func _on_tempest_pulse_timeout(center: Vector2, radius: float, damage: int, throw_power: float, duration_amp: float) -> void:
	var affected: int = 0
	for enemy in _get_enemies_in_radius(center, radius):
		_apply_damage(enemy, damage)
		_apply_status(enemy, "slow", 1.2 * duration_amp, 0.36, 1, 0.1)
		_apply_status(enemy, "marked", 1.3, 0.18, 1, 0.3)
		_knock_enemy(enemy, center, throw_power)
		affected += 1
	if affected > 0 and is_instance_valid(skill_owner):
		Global.spawn_floating_text(skill_owner.global_position, "TEMPEST x%d" % affected, Color(0.4, 0.95, 0.9))
	spawn_skill_vfx(center, Color(0.4, 0.96, 0.9, 0.82), 0.70)

func _get_aim_direction() -> Vector2:
	if not is_instance_valid(skill_owner):
		return Vector2.RIGHT
	var dir: Vector2 = skill_owner.get_global_mouse_position() - skill_owner.global_position
	if dir.length_squared() <= 0.01:
		return Vector2.RIGHT
	return dir.normalized()

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

func _knock_enemy(enemy: Node, center: Vector2, power: float) -> void:
	if not is_instance_valid(enemy):
		return
	if enemy.has_method("apply_knockback") and enemy is Node2D:
		var enemy_node: Node2D = enemy
		var dir: Vector2 = center.direction_to(enemy_node.global_position)
		enemy.apply_knockback(dir, power)
		return
	if enemy is Node2D:
		var enemy_node2: Node2D = enemy
		var push_dir: Vector2 = center.direction_to(enemy_node2.global_position)
		enemy_node2.global_position += push_dir * power * 0.02
