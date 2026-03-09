extends SkillBase
class_name SkillHunterE

var mark_radius: float = 300.0
var mark_duration: float = 5.0
var mark_damage_amp: float = 0.5
var snipe_delay: float = 0.2
var snipe_damage: int = 62

func execute() -> void:
	if not consume_energy():
		if skill_owner:
			Global.spawn_floating_text(skill_owner.global_position, "No Energy!", Color.RED)
		return
	if not is_instance_valid(skill_owner):
		return

	var owner_pos: Vector2 = skill_owner.global_position
	var damage_amp: float = get_e_damage_amp(0.28, 0.32)
	var duration_amp: float = get_e_duration_amp(0.4)
	var final_mark_duration: float = mark_duration * duration_amp
	var final_mark_amp: float = mark_damage_amp * (1.0 + (damage_amp - 1.0) * 0.55)
	var targets: Array = _pick_targets(owner_pos, mark_radius, 1 + (2 if is_f_window_active() else 0))
	if targets.is_empty():
		Global.spawn_floating_text(owner_pos, "No Target!", Color.YELLOW)
		start_cooldown()
		return

	var refs: Array = []
	for target in targets:
		if target == null or not is_instance_valid(target):
			continue
		refs.append(weakref(target))
		if target.has_method("apply_status"):
			target.apply_status("marked", final_mark_duration, final_mark_amp, 1, 999.0)
			target.apply_status("slow", 0.9 * duration_amp, 0.28)
		spawn_skill_vfx(target.global_position, Color(0.38, 0.76, 0.32, 0.72), 0.35)

	var delay: float = snipe_delay * (0.75 if is_f_window_active() else 1.0)
	var base_damage: int = max(1, int(round(float(snipe_damage) * damage_amp * (1.2 if is_f_window_active() else 1.0))))
	get_tree().create_timer(delay).timeout.connect(_on_snipe_timeout.bind(refs, base_damage, duration_amp))

	Global.on_camera_shake.emit(5.0, 0.15)
	Global.spawn_floating_text(owner_pos, "MARK x%d" % refs.size(), Color(0.25, 0.6, 0.25))
	start_cooldown()

func _on_snipe_timeout(target_refs: Array, base_damage: int, duration_amp: float) -> void:
	if not is_instance_valid(skill_owner):
		return
	var hit_count: int = 0
	for ref_obj in target_refs:
		var target = ref_obj.get_ref() if ref_obj != null else null
		if target == null or not is_instance_valid(target):
			continue
		if target.has_node("HealthComponent"):
			target.get_node("HealthComponent").take_damage(base_damage)
		if _is_low_hp_target(target, 0.2):
			if target.has_node("HealthComponent"):
				target.get_node("HealthComponent").take_damage(max(1, int(round(float(base_damage) * 0.9))))
			Global.spawn_floating_text(target.global_position, "EXECUTE!", Color(1.0, 0.3, 0.3))
		if target.has_method("apply_status"):
			target.apply_status("marked", 1.0 * duration_amp, 0.2)
		spawn_skill_vfx(target.global_position, Color(0.45, 0.88, 0.4, 0.8), 0.45)
		hit_count += 1
	if hit_count > 0:
		Global.spawn_floating_text(skill_owner.global_position, "SNIPE x%d" % hit_count, Color(0.35, 0.82, 0.35))

func _pick_targets(origin: Vector2, radius: float, count: int) -> Array:
	var targets: Array = []
	var enemies: Array = get_tree().get_nodes_in_group("enemies")
	for enemy in enemies:
		if enemy == null or not is_instance_valid(enemy):
			continue
		if not (enemy is Node2D):
			continue
		var enemy_node: Node2D = enemy
		if origin.distance_to(enemy_node.global_position) > radius:
			continue
		var inserted: bool = false
		var dist: float = origin.distance_to(enemy_node.global_position)
		for i in range(targets.size()):
			var current: Node2D = targets[i]
			var current_dist: float = origin.distance_to(current.global_position)
			if dist < current_dist:
				targets.insert(i, enemy_node)
				inserted = true
				break
		if not inserted:
			targets.append(enemy_node)
	if targets.size() > count:
		targets.resize(count)
	return targets

func _is_low_hp_target(target: Node, ratio: float) -> bool:
	if target == null or not is_instance_valid(target):
		return false
	if not target.has_node("HealthComponent"):
		return false
	var hc = target.get_node("HealthComponent")
	if hc == null:
		return false
	var max_health: float = float(hc.get("max_health"))
	if max_health <= 0.0:
		return false
	var current_health: float = float(hc.get("current_health"))
	return current_health <= max_health * max(0.0, ratio)
