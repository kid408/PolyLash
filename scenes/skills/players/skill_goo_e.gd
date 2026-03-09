extends SkillBase
class_name SkillGooE

var devour_radius: float = 150.0
var heal_amount: int = 30

func execute() -> void:
	if not consume_energy():
		if is_instance_valid(skill_owner):
			Global.spawn_floating_text(skill_owner.global_position, "No Energy!", Color.RED)
		return
	if not is_instance_valid(skill_owner):
		return

	var damage_amp: float = get_e_damage_amp(0.32, 0.30)
	var duration_amp: float = get_e_duration_amp(0.36)
	var final_radius: float = devour_radius * (1.0 + (duration_amp - 1.0) * 0.38)
	var final_heal: int = max(1, int(round(float(heal_amount) * damage_amp)))
	var acid_damage: int = max(1, int(round(34.0 * damage_amp)))
	var target: Node2D = _pick_nearest_enemy(skill_owner.global_position, final_radius)

	if target == null:
		_spawn_acid_burst(skill_owner.global_position, final_radius * 0.7, acid_damage, duration_amp, 2)
		Global.spawn_floating_text(skill_owner.global_position, "NO PREY", Color(0.72, 0.85, 0.6))
		start_cooldown()
		return

	_apply_damage(target, 9999)
	_heal_owner(final_heal)
	Global.spawn_floating_text(target.global_position, "DEVOUR", Color(0.45, 0.95, 0.32))

	var burst_count: int = 2 if not is_f_window_active() else 3
	_spawn_acid_burst(target.global_position, final_radius * 0.85, acid_damage, duration_amp, burst_count)

	spawn_skill_vfx(target.global_position, Color(0.4, 0.9, 0.35, 0.82), 0.72)
	Global.on_camera_shake.emit(8.4, 0.18)
	start_cooldown()

func _spawn_acid_burst(center: Vector2, radius: float, damage: int, duration_amp: float, count: int) -> void:
	for i in range(count):
		var angle: float = randf_range(0.0, TAU)
		var dist: float = radius * (0.35 + 0.35 * randf())
		var pos: Vector2 = center + Vector2(cos(angle), sin(angle)) * dist
		var delay: float = 0.12 * float(i)
		var timer: SceneTreeTimer = get_tree().create_timer(delay)
		timer.timeout.connect(_on_acid_burst_timeout.bind(pos, radius * 0.42, damage, duration_amp))

func _on_acid_burst_timeout(center: Vector2, radius: float, damage: int, duration_amp: float) -> void:
	var hit: int = 0
	for enemy in _get_enemies_in_radius(center, radius):
		_apply_damage(enemy, damage)
		_apply_status(enemy, "poison", 2.2 * duration_amp, max(1.0, float(damage) * 0.38), 1, 0.7)
		_apply_status(enemy, "slow", 1.0 * duration_amp, 0.34, 1, 0.1)
		hit += 1
	if hit > 0:
		Global.spawn_floating_text(center, "ACID x%d" % hit, Color(0.5, 0.95, 0.38))
	spawn_skill_vfx(center, Color(0.45, 0.95, 0.35, 0.75), 0.60)

func _pick_nearest_enemy(center: Vector2, radius: float) -> Node2D:
	var nearest: Node2D = null
	var best_dist: float = radius
	for enemy in _get_enemies_in_radius(center, radius):
		var dist: float = center.distance_to(enemy.global_position)
		if dist <= best_dist:
			best_dist = dist
			nearest = enemy
	return nearest

func _heal_owner(amount: int) -> void:
	if amount <= 0:
		return
	if not is_instance_valid(skill_owner):
		return
	if skill_owner.has_node("HealthComponent"):
		var hc: Node = skill_owner.get_node("HealthComponent")
		if hc and hc.has_method("heal"):
			hc.heal(float(amount))

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
