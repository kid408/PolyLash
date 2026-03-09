extends SkillBase
class_name SkillExecutionerE

var execute_radius: float = 200.0
var execute_threshold: float = 0.2

func execute() -> void:
	if not consume_energy():
		if is_instance_valid(skill_owner):
			Global.spawn_floating_text(skill_owner.global_position, "No Energy!", Color.RED)
		return
	if not is_instance_valid(skill_owner):
		return

	var damage_amp: float = get_e_damage_amp(0.22, 0.42)
	var duration_amp: float = get_e_duration_amp(0.42)
	var final_radius: float = execute_radius * (1.0 + (duration_amp - 1.0) * 0.30)
	var threshold: float = clamp(execute_threshold * (1.0 + (0.2 if is_f_window_active() else 0.0)), 0.05, 0.52)
	var fallback_damage: int = max(1, int(round(86.0 * damage_amp)))

	var execute_refs: Array = []
	var marks: int = 0
	for enemy in _get_enemies_in_radius(skill_owner.global_position, final_radius):
		if _is_below_threshold(enemy, threshold):
			_apply_damage(enemy, 9999)
			Global.spawn_floating_text((enemy as Node2D).global_position, "EXECUTE!", Color(1.0, 0.2, 0.2))
			execute_refs.append(weakref(enemy))
		else:
			_apply_damage(enemy, fallback_damage)
			_apply_status(enemy, "marked", 1.6, 0.24, 1, 0.3)
			marks += 1

	if not execute_refs.is_empty():
		var timer: SceneTreeTimer = get_tree().create_timer(0.18)
		timer.timeout.connect(_on_guillotine_timeout.bind(skill_owner.global_position, final_radius * 0.65, int(round(float(fallback_damage) * 1.35))))
		Global.spawn_floating_text(skill_owner.global_position, "GUILTY x%d" % execute_refs.size(), Color(1.0, 0.22, 0.22))
	elif marks > 0:
		Global.spawn_floating_text(skill_owner.global_position, "MARKED x%d" % marks, Color(1.0, 0.5, 0.4))
	else:
		Global.spawn_floating_text(skill_owner.global_position, "No Target!", Color(0.7, 0.7, 0.7))

	Global.on_camera_shake.emit(9.4, 0.20)
	start_cooldown()

func _on_guillotine_timeout(center: Vector2, radius: float, damage: int) -> void:
	var hit: int = 0
	for enemy in _get_enemies_in_radius(center, radius):
		if not (enemy.has_method("has_status") and enemy.has_status("marked")):
			continue
		_apply_damage(enemy, damage)
		_apply_status(enemy, "slow", 1.0, 0.34, 1, 0.1)
		hit += 1
	if hit > 0 and is_instance_valid(skill_owner):
		spawn_skill_vfx(center, Color(1.0, 0.24, 0.24, 0.82), 0.72)
		Global.spawn_floating_text(skill_owner.global_position, "GUILLOTINE x%d" % hit, Color(1.0, 0.24, 0.24))

func _is_below_threshold(enemy: Node, threshold: float) -> bool:
	if not is_instance_valid(enemy):
		return false
	if not enemy.has_node("HealthComponent"):
		return false
	var hc: Node = enemy.get_node("HealthComponent")
	if hc == null:
		return false
	var max_hp: float = float(hc.get("max_health"))
	if max_hp <= 0.0:
		return false
	var current_hp: float = float(hc.get("current_health"))
	return current_hp <= max_hp * max(0.0, threshold)

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
