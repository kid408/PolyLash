extends SkillBase
class_name SkillNewTempestE

var throw_force: float = 800.0
var throw_radius: float = 180.0
var stun_duration: float = 1.0
var throw_damage: int = 45

const TEMPEST_META_CENTER: String = "tempest_eye_center"
const TEMPEST_META_RADIUS: String = "tempest_eye_radius"
const TEMPEST_META_EXPIRE_MSEC: String = "tempest_eye_expire_msec"

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

	var window_data: Array = _get_tempest_window(center, final_radius)
	var synergy_used: bool = bool(window_data[0])
	if synergy_used and window_data.size() > 1 and window_data[1] is Vector2:
		center = window_data[1]
	if synergy_used and window_data.size() > 2:
		final_radius = max(final_radius, float(window_data[2]) * 0.95)
		final_throw *= 1.18
		final_damage = int(round(float(final_damage) * 1.14))
		final_stun *= 1.10

	var enemies: Array = _get_enemies_in_radius(center, final_radius)
	var hit_count: int = 0
	for enemy: Node2D in enemies:
		_apply_damage(enemy, final_damage)
		_apply_status(enemy, "slow", 1.1 * duration_amp, 0.30, 1, 0.1)
		_apply_status(enemy, "stun", final_stun, 0.0, 1, 0.1)
		if synergy_used:
			_apply_status(enemy, "marked", 1.2 * duration_amp, 0.18, 1, 0.3)
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

	if synergy_used:
		var return_delay: float = pulse_delay + 0.14
		var return_timer: SceneTreeTimer = get_tree().create_timer(return_delay)
		return_timer.timeout.connect(
			_on_return_gust_timeout.bind(
				center,
				final_radius * 0.78,
				max(1, int(round(float(final_damage) * 0.58))),
				final_throw * 0.55,
				duration_amp
			)
		)

	if hit_count > 0:
		if synergy_used:
			Global.spawn_floating_text(skill_owner.global_position, "UPDRAFT+ x%d" % hit_count, Color(0.46, 1.0, 0.9))
		else:
			Global.spawn_floating_text(skill_owner.global_position, "UPDRAFT x%d" % hit_count, Color(0.46, 1.0, 0.9))
	else:
		Global.spawn_floating_text(skill_owner.global_position, "WIND STEP", Color(0.5, 0.9, 0.85))
	spawn_skill_vfx(center, Color(0.35, 0.92, 0.82, 0.78), 0.86)
	Global.on_camera_shake.emit(8.8, 0.18)
	start_cooldown()

func _on_tempest_pulse_timeout(center: Vector2, radius: float, damage: int, throw_power: float, duration_amp: float) -> void:
	var affected: int = 0
	for enemy: Node2D in _get_enemies_in_radius(center, radius):
		_apply_damage(enemy, damage)
		_apply_status(enemy, "slow", 1.2 * duration_amp, 0.36, 1, 0.1)
		_apply_status(enemy, "marked", 1.3, 0.18, 1, 0.3)
		_knock_enemy(enemy, center, throw_power)
		affected += 1
	if affected > 0 and is_instance_valid(skill_owner):
		Global.spawn_floating_text(skill_owner.global_position, "TEMPEST x%d" % affected, Color(0.4, 0.95, 0.9))
	spawn_skill_vfx(center, Color(0.4, 0.96, 0.9, 0.82), 0.70)

func _on_return_gust_timeout(center: Vector2, radius: float, damage: int, throw_power: float, duration_amp: float) -> void:
	var hits: int = 0
	for enemy: Node2D in _get_enemies_in_radius(center, radius):
		_apply_damage(enemy, damage)
		_apply_status(enemy, "slow", 1.0 * duration_amp, 0.30, 1, 0.1)
		_knock_enemy(enemy, center, -throw_power)
		hits += 1
	if hits > 0 and is_instance_valid(skill_owner):
		_refund_q_cooldown(1.0)
		Global.spawn_floating_text(skill_owner.global_position, "RETURN GUST x%d" % hits, Color(0.36, 0.9, 0.88))
	spawn_skill_vfx(center, Color(0.35, 0.9, 0.85, 0.75), 0.62)

func _get_tempest_window(default_center: Vector2, default_radius: float) -> Array:
	var data: Array = [false, default_center, default_radius]
	if not is_instance_valid(skill_owner):
		return data
	if not skill_owner.has_meta(TEMPEST_META_EXPIRE_MSEC):
		return data
	var expire_msec: int = int(skill_owner.get_meta(TEMPEST_META_EXPIRE_MSEC, 0))
	if Time.get_ticks_msec() > expire_msec:
		return data
	var center_val: Variant = skill_owner.get_meta(TEMPEST_META_CENTER, default_center)
	var radius_val: Variant = skill_owner.get_meta(TEMPEST_META_RADIUS, default_radius)
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

func _get_aim_direction() -> Vector2:
	if not is_instance_valid(skill_owner):
		return Vector2.RIGHT
	var dir: Vector2 = skill_owner.get_global_mouse_position() - skill_owner.global_position
	if dir.length_squared() <= 0.01:
		return Vector2.RIGHT
	return dir.normalized()

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
