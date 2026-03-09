extends SkillBase
class_name SkillPlagueE

var detonate_radius: float = 250.0
var damage_per_stack: int = 50

func execute() -> void:
	if not consume_energy():
		if is_instance_valid(skill_owner):
			Global.spawn_floating_text(skill_owner.global_position, "No Energy!", Color.RED)
		return
	if not is_instance_valid(skill_owner):
		return

	var damage_amp: float = get_e_damage_amp(0.28, 0.36)
	var duration_amp: float = get_e_duration_amp(0.36)
	var final_radius: float = detonate_radius * (1.0 + (duration_amp - 1.0) * 0.35)
	var per_stack_damage: int = max(1, int(round(float(damage_per_stack) * damage_amp)))
	var bloom_scale: float = 0.45 if not is_f_window_active() else 0.62

	var infected_refs: Array = []
	var total_hits: int = 0
	for enemy in _get_enemies_in_radius(skill_owner.global_position, final_radius):
		var stacks: int = _get_poison_stacks(enemy)
		if stacks <= 0:
			continue
		_clear_poison(enemy)
		var total_damage: int = max(1, stacks * per_stack_damage)
		_apply_damage(enemy, total_damage)
		_apply_status(enemy, "curse", 2.0 * duration_amp, max(1.0, float(total_damage) * 0.22), 1, 0.7)
		_apply_status(enemy, "slow", 1.0 * duration_amp, 0.26, 1, 0.1)
		infected_refs.append(weakref(enemy))
		total_hits += 1
		Global.spawn_floating_text((enemy as Node2D).global_position, "BLOOM x%d" % stacks, Color(0.52, 0.92, 0.25))

	if infected_refs.is_empty():
		Global.spawn_floating_text(skill_owner.global_position, "No Poison!", Color(0.7, 0.75, 0.65))
		start_cooldown()
		return

	var bloom_delay: float = 0.30 if not is_f_window_active() else 0.22
	var timer: SceneTreeTimer = get_tree().create_timer(bloom_delay)
	timer.timeout.connect(_on_bloom_timeout.bind(infected_refs, final_radius * 0.32, bloom_scale, duration_amp))

	Global.on_camera_shake.emit(7.8, 0.16)
	Global.spawn_floating_text(skill_owner.global_position, "PLAGUE BURST x%d" % total_hits, Color(0.45, 0.85, 0.2))
	start_cooldown()

func _on_bloom_timeout(target_refs: Array, bloom_radius: float, bloom_scale: float, duration_amp: float) -> void:
	var bloom_damage: int = max(1, int(round(30.0 * get_e_damage_amp(0.22, 0.30) * bloom_scale)))
	var exploded: int = 0
	for ref_obj in target_refs:
		var target = ref_obj.get_ref() if ref_obj != null else null
		if target == null or not is_instance_valid(target):
			continue
		if not (target is Node2D):
			continue
		var target_node: Node2D = target
		for enemy in _get_enemies_in_radius(target_node.global_position, bloom_radius):
			_apply_damage(enemy, bloom_damage)
			_apply_status(enemy, "poison", 2.2 * duration_amp, max(1.0, float(bloom_damage) * 0.35), 1, 0.7)
			_apply_status(enemy, "slow", 0.8, 0.22, 1, 0.1)
			exploded += 1
		spawn_skill_vfx(target_node.global_position, Color(0.48, 0.95, 0.32, 0.75), 0.52)

	if exploded > 0 and is_instance_valid(skill_owner):
		Global.spawn_floating_text(skill_owner.global_position, "SPREAD x%d" % exploded, Color(0.58, 0.95, 0.35))

func _get_poison_stacks(enemy: Node) -> int:
	if not is_instance_valid(enemy):
		return 0
	if enemy.has_node("StatusComponent"):
		var status_comp: Node = enemy.get_node("StatusComponent")
		if status_comp and status_comp.has_method("has_status") and status_comp.has_method("get_status_stacks"):
			if status_comp.has_status("poison"):
				return max(1, int(status_comp.get_status_stacks("poison")))
	if enemy.has_method("has_status") and enemy.has_method("get_status_stacks"):
		if enemy.has_status("poison"):
			return max(1, int(enemy.get_status_stacks("poison")))
	return 0

func _clear_poison(enemy: Node) -> void:
	if not is_instance_valid(enemy):
		return
	if enemy.has_node("StatusComponent"):
		var status_comp: Node = enemy.get_node("StatusComponent")
		if status_comp and status_comp.has_method("remove_status"):
			status_comp.remove_status("poison")
			return
	if enemy.has_method("_remove_status"):
		enemy._remove_status("poison")
	elif "active_statuses" in enemy:
		enemy.active_statuses.erase("poison")

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
