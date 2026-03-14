extends SkillBase
class_name SkillJailerE

var knockback_force: float = 600.0
var fan_radius: float = 200.0
var fan_angle: float = 90.0
var bash_damage: int = 40

const PRISON_META_CENTER: String = "jailer_prison_center"
const PRISON_META_RADIUS: String = "jailer_prison_radius"
const PRISON_META_EXPIRE_MSEC: String = "jailer_prison_expire_msec"

func execute() -> void:
	if not consume_energy():
		if is_instance_valid(skill_owner):
			Global.spawn_floating_text(skill_owner.global_position, "No Energy!", Color.RED)
		return
	if not is_instance_valid(skill_owner):
		return

	var damage_amp: float = get_e_damage_amp(0.28, 0.34)
	var duration_amp: float = get_e_duration_amp(0.35)
	var final_radius: float = fan_radius * (1.0 + (duration_amp - 1.0) * 0.30)
	var final_angle: float = fan_angle * (1.0 + (0.12 if is_f_window_active() else 0.0))
	var final_knockback: float = knockback_force * (1.0 + (duration_amp - 1.0) * 0.34)
	var final_damage: int = max(1, int(round(float(bash_damage) * damage_amp)))
	var facing_dir: Vector2 = _get_aim_direction()
	var origin: Vector2 = skill_owner.global_position

	var window_data: Array = _get_prison_window(origin, final_radius)
	var synergy_used: bool = bool(window_data[0])
	if synergy_used and window_data.size() > 1 and window_data[1] is Vector2:
		origin = window_data[1]
	if synergy_used and window_data.size() > 2:
		final_radius = max(final_radius, float(window_data[2]) * 0.9)
		final_knockback *= 1.18
		final_damage = int(round(float(final_damage) * 1.15))

	var half_angle_rad: float = deg_to_rad(final_angle * 0.5)
	var targets: Array = []
	for enemy: Node2D in _get_enemies_in_radius(origin, final_radius):
		var to_enemy: Vector2 = enemy.global_position - origin
		if to_enemy.length_squared() <= 0.01:
			continue
		var angle: float = absf(facing_dir.angle_to(to_enemy.normalized()))
		if angle > half_angle_rad:
			continue
		_apply_damage(enemy, final_damage)
		_apply_status(enemy, "slow", 1.1 * duration_amp, 0.32, 1, 0.1)
		if synergy_used:
			_apply_status(enemy, "marked", 1.4, 0.18, 1, 0.3)
		_knock_enemy(enemy, origin, final_knockback)
		targets.append(weakref(enemy))

	if targets.is_empty():
		Global.spawn_floating_text(skill_owner.global_position, "No Target!", Color(0.8, 0.78, 0.7))
		start_cooldown()
		return

	var verdict_delay: float = 0.26 if not is_f_window_active() else 0.18
	if synergy_used:
		verdict_delay = max(0.1, verdict_delay - 0.06)
	var timer: SceneTreeTimer = get_tree().create_timer(verdict_delay)
	timer.timeout.connect(_on_verdict_timeout.bind(targets, final_damage, duration_amp, synergy_used))

	spawn_skill_vfx(origin + facing_dir * 48.0, Color(1.0, 0.85, 0.35, 0.75), 0.65)
	Global.on_camera_shake.emit(8.0, 0.15)
	if synergy_used:
		Global.spawn_floating_text(skill_owner.global_position, "LOCKDOWN+", Color(1.0, 0.86, 0.3))
	else:
		Global.spawn_floating_text(skill_owner.global_position, "LOCKDOWN", Color(1.0, 0.86, 0.3))
	start_cooldown()

func _on_verdict_timeout(target_refs: Array, base_damage: int, duration_amp: float, synergy_used: bool) -> void:
	var scale: float = 0.62 if not is_f_window_active() else 0.82
	if synergy_used:
		scale += 0.14
	var damage: int = max(1, int(round(float(base_damage) * scale)))
	var hit: int = 0
	for ref_obj: Variant in target_refs:
		var target: Variant = ref_obj.get_ref() if ref_obj != null else null
		if target == null or not is_instance_valid(target):
			continue
		_apply_damage(target, damage)
		_apply_status(target, "stun", 0.36 * duration_amp, 0.0, 1, 0.1)
		_apply_status(target, "marked", 1.3, 0.18, 1, 0.3)
		hit += 1
	if hit > 0 and is_instance_valid(skill_owner):
		if synergy_used:
			_refund_q_cooldown(1.2)
		Global.spawn_floating_text(skill_owner.global_position, "VERDICT x%d" % hit, Color(1.0, 0.75, 0.28))

func _get_prison_window(default_center: Vector2, default_radius: float) -> Array:
	var data: Array = [false, default_center, default_radius]
	if not is_instance_valid(skill_owner):
		return data
	if not skill_owner.has_meta(PRISON_META_EXPIRE_MSEC):
		return data
	var expire_msec: int = int(skill_owner.get_meta(PRISON_META_EXPIRE_MSEC, 0))
	if Time.get_ticks_msec() > expire_msec:
		return data
	var center_val: Variant = skill_owner.get_meta(PRISON_META_CENTER, default_center)
	var radius_val: Variant = skill_owner.get_meta(PRISON_META_RADIUS, default_radius)
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

func _apply_status(enemy: Node, status_name: String, duration: float, value: float, stacks: int = 1, tick_interval: float = 0.5) -> void:
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
