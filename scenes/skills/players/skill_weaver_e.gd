extends SkillBase
class_name SkillWeaverE

var stun_radius: float = 320.0
var stun_duration: float = 1.3

var bounce_count: int = 3
var bounce_range: float = 260.0
var bounce_damage: int = 24
var recall_delay: float = 0.28
var recall_damage_scale: float = 0.58
var execute_threshold_ratio: float = 0.34

func execute() -> void:
	if not can_execute():
		if is_on_cooldown and is_instance_valid(skill_owner):
			Global.spawn_floating_text(skill_owner.global_position, "Cooldown!", Color.YELLOW)
		return
	if not consume_energy():
		if is_instance_valid(skill_owner):
			Global.spawn_floating_text(skill_owner.global_position, "No Energy!", Color.RED)
		return
	if not is_instance_valid(skill_owner):
		return

	var damage_amp: float = get_e_damage_amp(0.42, 0.35)
	var duration_amp: float = get_e_duration_amp(0.35)
	var max_bounces: int = clamp(bounce_count + (1 if is_f_window_active() else 0), 1, 6)

	var used: Array[Node2D] = []
	var from_pos: Vector2 = skill_owner.global_position
	for i: int in range(max_bounces):
		var search_radius: float = stun_radius if i == 0 else bounce_range
		var target: Node2D = _pick_next_enemy(from_pos, search_radius, used)
		if target == null:
			break
		used.append(target)
		from_pos = target.global_position

		var hit_damage: int = max(
			1,
			int(round(float(bounce_damage) * (1.0 + float(i) * 0.15) * damage_amp))
		)
		_apply_damage(target, hit_damage)
		_apply_status(target, "stun", stun_duration * duration_amp, 0.0)
		_apply_status(target, "curse", 2.2 + float(i) * 0.35, 8.0 + float(i) * 2.2)
		spawn_skill_vfx(target.global_position, Color(0.48, 0.95, 1.25, 0.88), 0.52)

	if used.is_empty():
		Global.spawn_floating_text(skill_owner.global_position, "MISS", Color(0.8, 0.85, 1.0))
	else:
		_schedule_net_recall(used, damage_amp, duration_amp)
		Global.on_camera_shake.emit(4.5 + float(used.size()) * 0.5, 0.1)

	start_cooldown()

func _schedule_net_recall(used_targets: Array[Node2D], damage_amp: float, duration_amp: float) -> void:
	var refs: Array[WeakRef] = []
	for target: Node2D in used_targets:
		if target == null or not is_instance_valid(target):
			continue
		refs.append(weakref(target))
	if refs.size() <= 0:
		return
	var delay: float = recall_delay * (0.78 if is_f_window_active() else 1.0)
	get_tree().create_timer(delay).timeout.connect(
		_on_net_recall_timeout.bind(refs, damage_amp, duration_amp)
	)

func _on_net_recall_timeout(refs: Array[WeakRef], damage_amp: float, duration_amp: float) -> void:
	var base_recall_damage: int = max(1, int(round(float(bounce_damage) * recall_damage_scale * damage_amp)))
	var execute_hits: int = 0
	var hit_count: int = 0
	for ref_obj: WeakRef in refs:
		var target_var: Variant = ref_obj.get_ref() if ref_obj != null else null
		if target_var == null or not is_instance_valid(target_var):
			continue
		if not (target_var is Node2D):
			continue
		var enemy: Node2D = target_var
		var hp_ratio: float = _get_hp_ratio(enemy)
		var final_damage: int = base_recall_damage
		if hp_ratio <= execute_threshold_ratio:
			final_damage = int(round(float(base_recall_damage) * 1.7))
			execute_hits += 1
		else:
			hit_count += 1
		_apply_damage(enemy, max(1, final_damage))
		_apply_status(enemy, "slow", 1.0 * duration_amp, 0.36)
		_apply_status(enemy, "marked", 1.2, 0.18)
		spawn_skill_vfx(enemy.global_position, Color(0.65, 1.0, 1.35, 0.82), 0.42)

	if execute_hits > 0 or hit_count > 0 and is_instance_valid(skill_owner):
		Global.spawn_floating_text(
			skill_owner.global_position,
			"RECALL EXEC %d / HIT %d" % [execute_hits, hit_count],
			Color(0.65, 1.05, 1.35)
		)

func _pick_next_enemy(origin: Vector2, range_limit: float, used: Array[Node2D]) -> Node2D:
	if not is_inside_tree():
		return null
	var enemies: Array = get_tree().get_nodes_in_group("enemies")
	var nearest: Node2D = null
	var nearest_dist: float = range_limit
	for enemy_obj: Variant in enemies:
		if enemy_obj == null or not is_instance_valid(enemy_obj):
			continue
		if not (enemy_obj is Node2D):
			continue
		var enemy: Node2D = enemy_obj
		if used.has(enemy):
			continue
		var dist: float = origin.distance_to(enemy.global_position)
		if dist <= nearest_dist:
			nearest = enemy
			nearest_dist = dist
	return nearest

func _apply_damage(enemy: Node2D, amount: int) -> void:
	if enemy == null or not is_instance_valid(enemy):
		return
	if not enemy.has_node("HealthComponent"):
		return
	var hc: Node = enemy.get_node("HealthComponent")
	if hc != null and hc.has_method("take_damage"):
		hc.call("take_damage", amount)

func _apply_status(enemy: Node2D, status_type: String, duration: float, value: float) -> void:
	if enemy == null or not is_instance_valid(enemy):
		return
	if enemy.has_method("apply_status"):
		enemy.call("apply_status", status_type, duration, value)

func _get_hp_ratio(enemy: Node2D) -> float:
	if enemy == null or not is_instance_valid(enemy):
		return 1.0
	if not enemy.has_node("HealthComponent"):
		return 1.0
	var hc: Node = enemy.get_node("HealthComponent")
	if hc == null:
		return 1.0
	if not ("max_health" in hc and "current_health" in hc):
		return 1.0
	var max_hp: float = max(1.0, float(hc.get("max_health")))
	return float(hc.get("current_health")) / max_hp
