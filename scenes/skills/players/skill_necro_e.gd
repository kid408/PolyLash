extends SkillBase
class_name SkillNecroE

var fear_radius: float = 200.0
var fear_duration: float = 3.0
var soul_brand_count: int = 3
var soul_reap_delay: float = 0.45
var soul_reap_damage: int = 38

const GRAVE_META_CENTER: String = "necro_grave_center"
const GRAVE_META_RADIUS: String = "necro_grave_radius"
const GRAVE_META_EXPIRE_MSEC: String = "necro_grave_expire_msec"

func execute() -> void:
	if not consume_energy():
		if is_instance_valid(skill_owner):
			Global.spawn_floating_text(skill_owner.global_position, "No Energy!", Color.RED)
		return
	if not is_instance_valid(skill_owner):
		return

	var damage_amp: float = get_e_damage_amp(0.25, 0.3)
	var duration_amp: float = get_e_duration_amp(0.4)
	var final_radius: float = fear_radius * (1.0 + (duration_amp - 1.0) * 0.35)
	var final_fear_duration: float = fear_duration * duration_amp
	var final_damage: int = max(1, int(round(35.0 * damage_amp)))
	var origin: Vector2 = skill_owner.global_position

	var window_data: Array = _get_grave_window(origin, final_radius)
	var synergy_used: bool = bool(window_data[0])
	if synergy_used and window_data.size() > 1 and window_data[1] is Vector2:
		origin = window_data[1]
	if synergy_used and window_data.size() > 2:
		final_radius = max(final_radius, float(window_data[2]) * 0.9)
		final_damage = int(round(float(final_damage) * 1.12))

	var hit_count: int = 0
	for enemy: Node2D in _get_enemies_in_radius(origin, final_radius):
		_apply_damage(enemy, final_damage)
		_apply_status(enemy, "fear", final_fear_duration, 300.0, 1, 0.1)
		if synergy_used:
			_apply_status(enemy, "curse", 1.8 * duration_amp, 9.0, 1, 0.7)
		hit_count += 1

	var extra_brand: int = 2 if is_f_window_active() else 0
	if synergy_used:
		extra_brand += 1
	var brand_refs: Array = _collect_brand_targets(origin, final_radius, soul_brand_count + extra_brand)
	_apply_soul_brands(brand_refs, duration_amp)
	var reap_damage: int = max(1, int(round(float(soul_reap_damage) * damage_amp * (1.2 if is_f_window_active() else 1.0))))
	if synergy_used:
		reap_damage = int(round(float(reap_damage) * 1.12))
	var reap_delay: float = soul_reap_delay * (0.75 if is_f_window_active() else 1.0)
	if synergy_used:
		reap_delay = max(0.12, reap_delay - 0.08)
	get_tree().create_timer(reap_delay).timeout.connect(_on_soul_reap_timeout.bind(brand_refs, reap_damage, duration_amp, synergy_used))

	if (is_f_window_active() or synergy_used) and SkillEffectManager != null and SkillEffectManager.has_method("command_summons"):
		SkillEffectManager.command_summons("skill_necro_q", "focus_fire", _pick_nearest_enemy(origin, final_radius, []))

	if synergy_used:
		_refund_q_cooldown(1.0)
		Global.spawn_floating_text(skill_owner.global_position, "FEAR x%d / BRAND+ x%d" % [hit_count, brand_refs.size()], Color(0.55, 0.2, 0.72))
	else:
		Global.spawn_floating_text(skill_owner.global_position, "FEAR x%d / BRAND x%d" % [hit_count, brand_refs.size()], Color(0.55, 0.2, 0.72))
	spawn_skill_vfx(origin, Color(0.4, 0.1, 0.5, 0.8), 0.7)
	Global.on_camera_shake.emit(8.0, 0.2)
	start_cooldown()

func _collect_brand_targets(origin: Vector2, radius: float, count: int) -> Array:
	var refs: Array = []
	var enemies: Array = _sort_enemies_by_distance(_get_enemies_in_radius(origin, radius), origin)
	for i: int in range(min(count, enemies.size())):
		refs.append(weakref(enemies[i]))
	return refs

func _apply_soul_brands(refs: Array, duration_amp: float) -> void:
	for ref_obj: Variant in refs:
		var target: Variant = ref_obj.get_ref() if ref_obj != null else null
		if target == null or not is_instance_valid(target):
			continue
		if target.has_method("apply_status"):
			target.apply_status("curse", 2.2 * duration_amp, 10.0, 1, 0.7)
		spawn_skill_vfx(target.global_position, Color(0.68, 0.35, 0.85, 0.75), 0.35)

func _on_soul_reap_timeout(refs: Array, damage: int, duration_amp: float, synergy_used: bool) -> void:
	var reap_hits: int = 0
	for ref_obj: Variant in refs:
		var target: Variant = ref_obj.get_ref() if ref_obj != null else null
		if target == null or not is_instance_valid(target):
			continue
		if target.has_node("HealthComponent"):
			var hc: Node = target.get_node("HealthComponent")
			if hc != null and hc.has_method("take_damage"):
				hc.call("take_damage", damage)
		if target.has_method("apply_status"):
			target.apply_status("slow", 1.1 * duration_amp, 0.34, 1, 0.1)
			if synergy_used:
				target.apply_status("marked", 1.2, 0.2, 1, 0.3)
		spawn_skill_vfx(target.global_position, Color(0.78, 0.3, 0.95, 0.85), 0.45)
		reap_hits += 1
	if reap_hits > 0 and is_instance_valid(skill_owner):
		Global.spawn_floating_text(skill_owner.global_position, "SOUL REAP x%d" % reap_hits, Color(0.82, 0.42, 1.0))

func _get_grave_window(default_center: Vector2, default_radius: float) -> Array:
	var data: Array = [false, default_center, default_radius]
	if not is_instance_valid(skill_owner):
		return data
	if not skill_owner.has_meta(GRAVE_META_EXPIRE_MSEC):
		return data
	var expire_msec: int = int(skill_owner.get_meta(GRAVE_META_EXPIRE_MSEC, 0))
	if Time.get_ticks_msec() > expire_msec:
		return data
	var center_val: Variant = skill_owner.get_meta(GRAVE_META_CENTER, default_center)
	var radius_val: Variant = skill_owner.get_meta(GRAVE_META_RADIUS, default_radius)
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

func _pick_nearest_enemy(origin: Vector2, radius: float, used: Array) -> Node2D:
	var nearest: Node2D = null
	var nearest_dist: float = radius
	var enemies: Array = _get_enemies_in_radius(origin, radius)
	for enemy: Node2D in enemies:
		if used.has(enemy):
			continue
		var dist: float = origin.distance_to(enemy.global_position)
		if dist <= nearest_dist:
			nearest = enemy
			nearest_dist = dist
	return nearest

func _get_enemies_in_radius(center: Vector2, radius: float) -> Array:
	var enemies: Array = []
	var all_enemies: Array = get_tree().get_nodes_in_group("enemies")
	for enemy_obj: Variant in all_enemies:
		if enemy_obj == null or not is_instance_valid(enemy_obj):
			continue
		if not (enemy_obj is Node2D):
			continue
		var enemy_node: Node2D = enemy_obj
		if center.distance_to(enemy_node.global_position) <= radius:
			enemies.append(enemy_node)
	return enemies

func _sort_enemies_by_distance(enemies: Array, center: Vector2) -> Array:
	var sorted: Array = []
	for enemy_obj: Variant in enemies:
		if enemy_obj == null or not is_instance_valid(enemy_obj):
			continue
		if not (enemy_obj is Node2D):
			continue
		var enemy_node: Node2D = enemy_obj
		var dist: float = enemy_node.global_position.distance_to(center)
		var inserted: bool = false
		for i: int in range(sorted.size()):
			var current: Node2D = sorted[i]
			if dist < current.global_position.distance_to(center):
				sorted.insert(i, enemy_node)
				inserted = true
				break
		if not inserted:
			sorted.append(enemy_node)
	return sorted

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
