extends SkillBase
class_name SkillNecroE

var fear_radius: float = 200.0
var fear_duration: float = 3.0
var soul_brand_count: int = 3
var soul_reap_delay: float = 0.45
var soul_reap_damage: int = 38

func execute() -> void:
	if not consume_energy():
		if skill_owner:
			Global.spawn_floating_text(skill_owner.global_position, "No Energy!", Color.RED)
		return
	if not is_instance_valid(skill_owner):
		return

	var damage_amp: float = get_e_damage_amp(0.25, 0.3)
	var duration_amp: float = get_e_duration_amp(0.4)
	var final_radius: float = fear_radius * (1.0 + (duration_amp - 1.0) * 0.35)
	var final_fear_duration: float = fear_duration * duration_amp
	var final_damage: int = max(1, int(round(35.0 * damage_amp)))

	var enemies: Array = get_tree().get_nodes_in_group("enemies")
	var hit_count: int = 0
	for enemy in enemies:
		if enemy == null or not is_instance_valid(enemy):
			continue
		if not (enemy is Node2D):
			continue
		var enemy_node: Node2D = enemy
		if skill_owner.global_position.distance_to(enemy_node.global_position) > final_radius:
			continue
		if enemy_node.has_node("HealthComponent"):
			enemy_node.get_node("HealthComponent").take_damage(final_damage)
		if enemy_node.has_method("apply_status"):
			enemy_node.apply_status("fear", final_fear_duration, 300.0)
		hit_count += 1

	var brand_refs: Array = _collect_brand_targets(skill_owner.global_position, final_radius, soul_brand_count + (2 if is_f_window_active() else 0))
	_apply_soul_brands(brand_refs, duration_amp)
	var reap_damage: int = max(1, int(round(float(soul_reap_damage) * damage_amp * (1.2 if is_f_window_active() else 1.0))))
	var reap_delay: float = soul_reap_delay * (0.75 if is_f_window_active() else 1.0)
	get_tree().create_timer(reap_delay).timeout.connect(_on_soul_reap_timeout.bind(brand_refs, reap_damage, duration_amp))

	if is_f_window_active() and SkillEffectManager != null and SkillEffectManager.has_method("command_summons"):
		SkillEffectManager.command_summons("skill_necro_q", "focus_fire", _pick_nearest_enemy(skill_owner.global_position, final_radius, []))

	Global.spawn_floating_text(skill_owner.global_position, "FEAR x%d / BRAND x%d" % [hit_count, brand_refs.size()], Color(0.55, 0.2, 0.72))
	spawn_skill_vfx(skill_owner.global_position, Color(0.4, 0.1, 0.5, 0.8), 0.7)
	Global.on_camera_shake.emit(8.0, 0.2)
	start_cooldown()

func _collect_brand_targets(origin: Vector2, radius: float, count: int) -> Array:
	var refs: Array = []
	var enemies: Array = _sort_enemies_by_distance(_get_enemies_in_radius(origin, radius), origin)
	for i in range(min(count, enemies.size())):
		refs.append(weakref(enemies[i]))
	return refs

func _apply_soul_brands(refs: Array, duration_amp: float) -> void:
	for ref_obj in refs:
		var target = ref_obj.get_ref() if ref_obj != null else null
		if target == null or not is_instance_valid(target):
			continue
		if target.has_method("apply_status"):
			target.apply_status("curse", 2.2 * duration_amp, 10.0)
		spawn_skill_vfx(target.global_position, Color(0.68, 0.35, 0.85, 0.75), 0.35)

func _on_soul_reap_timeout(refs: Array, damage: int, duration_amp: float) -> void:
	var reap_hits: int = 0
	for ref_obj in refs:
		var target = ref_obj.get_ref() if ref_obj != null else null
		if target == null or not is_instance_valid(target):
			continue
		if target.has_node("HealthComponent"):
			target.get_node("HealthComponent").take_damage(damage)
		if target.has_method("apply_status"):
			target.apply_status("slow", 1.1 * duration_amp, 0.34)
		spawn_skill_vfx(target.global_position, Color(0.78, 0.3, 0.95, 0.85), 0.45)
		reap_hits += 1
	if reap_hits > 0 and is_instance_valid(skill_owner):
		Global.spawn_floating_text(skill_owner.global_position, "SOUL REAP x%d" % reap_hits, Color(0.82, 0.42, 1.0))

func _pick_nearest_enemy(origin: Vector2, radius: float, used: Array) -> Node2D:
	var nearest: Node2D = null
	var nearest_dist: float = radius
	var enemies: Array = _get_enemies_in_radius(origin, radius)
	for enemy in enemies:
		if used.has(enemy):
			continue
		if not is_instance_valid(enemy) or not (enemy is Node2D):
			continue
		var enemy_node: Node2D = enemy
		var dist: float = origin.distance_to(enemy_node.global_position)
		if dist <= nearest_dist:
			nearest = enemy_node
			nearest_dist = dist
	return nearest

func _get_enemies_in_radius(center: Vector2, radius: float) -> Array:
	var enemies: Array = []
	var all_enemies: Array = get_tree().get_nodes_in_group("enemies")
	for enemy in all_enemies:
		if enemy == null or not is_instance_valid(enemy):
			continue
		if not (enemy is Node2D):
			continue
		var enemy_node: Node2D = enemy
		if center.distance_to(enemy_node.global_position) <= radius:
			enemies.append(enemy_node)
	return enemies

func _sort_enemies_by_distance(enemies: Array, center: Vector2) -> Array:
	var sorted: Array = []
	for enemy in enemies:
		if not is_instance_valid(enemy) or not (enemy is Node2D):
			continue
		var enemy_node: Node2D = enemy
		var dist: float = enemy_node.global_position.distance_to(center)
		var inserted: bool = false
		for i in range(sorted.size()):
			var current: Node2D = sorted[i]
			if dist < current.global_position.distance_to(center):
				sorted.insert(i, enemy_node)
				inserted = true
				break
		if not inserted:
			sorted.append(enemy_node)
	return sorted
