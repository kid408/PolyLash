extends SkillBase
class_name SkillJailerE

var knockback_force: float = 600.0
var fan_radius: float = 200.0
var fan_angle: float = 90.0
var bash_damage: int = 40

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

	var half_angle_rad: float = deg_to_rad(final_angle * 0.5)
	var targets: Array = []
	for enemy in _get_enemies_in_radius(skill_owner.global_position, final_radius):
		var to_enemy: Vector2 = (enemy as Node2D).global_position - skill_owner.global_position
		if to_enemy.length_squared() <= 0.01:
			continue
		var angle: float = absf(facing_dir.angle_to(to_enemy.normalized()))
		if angle > half_angle_rad:
			continue
		_apply_damage(enemy, final_damage)
		_apply_status(enemy, "slow", 1.1 * duration_amp, 0.32, 1, 0.1)
		_knock_enemy(enemy, skill_owner.global_position, final_knockback)
		targets.append(weakref(enemy))

	if targets.is_empty():
		Global.spawn_floating_text(skill_owner.global_position, "No Target!", Color(0.8, 0.78, 0.7))
		start_cooldown()
		return

	var verdict_delay: float = 0.26 if not is_f_window_active() else 0.18
	var timer: SceneTreeTimer = get_tree().create_timer(verdict_delay)
	timer.timeout.connect(_on_verdict_timeout.bind(targets, final_damage, duration_amp))

	spawn_skill_vfx(skill_owner.global_position + facing_dir * 48.0, Color(1.0, 0.85, 0.35, 0.75), 0.65)
	Global.on_camera_shake.emit(8.0, 0.15)
	Global.spawn_floating_text(skill_owner.global_position, "LOCKDOWN", Color(1.0, 0.86, 0.3))
	start_cooldown()

func _on_verdict_timeout(target_refs: Array, base_damage: int, duration_amp: float) -> void:
	var damage: int = max(1, int(round(float(base_damage) * (0.62 if not is_f_window_active() else 0.82))))
	var hit: int = 0
	for ref_obj in target_refs:
		var target = ref_obj.get_ref() if ref_obj != null else null
		if target == null or not is_instance_valid(target):
			continue
		_apply_damage(target, damage)
		_apply_status(target, "stun", 0.36 * duration_amp, 0.0, 1, 0.1)
		_apply_status(target, "marked", 1.3, 0.18, 1, 0.3)
		hit += 1
	if hit > 0 and is_instance_valid(skill_owner):
		Global.spawn_floating_text(skill_owner.global_position, "VERDICT x%d" % hit, Color(1.0, 0.75, 0.28))

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
