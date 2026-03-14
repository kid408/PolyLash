extends SkillBase
class_name SkillGooE

var devour_radius: float = 150.0
var heal_amount: int = 30

const GOO_META_CENTER: String = "goo_pool_center"
const GOO_META_RADIUS: String = "goo_pool_radius"
const GOO_META_EXPIRE_MSEC: String = "goo_pool_expire_msec"
const GOO_E_META_CENTER: String = "goo_e_devour_center"
const GOO_E_META_RADIUS: String = "goo_e_devour_radius"
const GOO_E_META_EXPIRE_MSEC: String = "goo_e_devour_expire_msec"
const GOO_E_META_SPLIT: String = "goo_e_devour_split"

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
	var center: Vector2 = skill_owner.global_position

	var window_data: Array = _get_goo_window(center, final_radius)
	var synergy_used: bool = bool(window_data[0])
	if synergy_used and window_data.size() > 1 and window_data[1] is Vector2:
		center = window_data[1]
	if synergy_used and window_data.size() > 2:
		final_radius = max(final_radius, float(window_data[2]) * 0.9)
		acid_damage = int(round(float(acid_damage) * 1.14))

	var devour_center: Vector2 = center
	var devour_radius: float = final_radius * 0.72
	var devour_split: int = 1

	var target: Node2D = _pick_nearest_enemy(center, final_radius)
	if target == null:
		var fallback_count: int = 2 + (1 if synergy_used else 0)
		_spawn_acid_burst(center, final_radius * 0.7, acid_damage, duration_amp, fallback_count)
		_record_devour_window(center, final_radius * 0.7, fallback_count)
		Global.spawn_floating_text(skill_owner.global_position, "NO PREY", Color(0.72, 0.85, 0.6))
		start_cooldown()
		return

	_apply_damage(target, 9999)
	_heal_owner(final_heal)
	Global.spawn_floating_text(target.global_position, "DEVOUR", Color(0.45, 0.95, 0.32))

	var burst_count: int = 2 if not is_f_window_active() else 3
	if synergy_used:
		burst_count += 1
		_refund_q_cooldown(1.0)
	_apply_status(target, "slow", 1.2 * duration_amp, 0.38, 1, 0.1)
	_spawn_acid_burst(target.global_position, final_radius * 0.85, acid_damage, duration_amp, burst_count)
	devour_center = target.global_position
	devour_radius = final_radius * 0.85
	devour_split = burst_count
	_record_devour_window(devour_center, devour_radius, devour_split)

	spawn_skill_vfx(target.global_position, Color(0.4, 0.9, 0.35, 0.82), 0.72)
	Global.on_camera_shake.emit(8.4, 0.18)
	start_cooldown()

func _spawn_acid_burst(center: Vector2, radius: float, damage: int, duration_amp: float, count: int) -> void:
	for i: int in range(count):
		var angle: float = randf_range(0.0, TAU)
		var dist: float = radius * (0.35 + 0.35 * randf())
		var pos: Vector2 = center + Vector2(cos(angle), sin(angle)) * dist
		var delay: float = 0.12 * float(i)
		var timer: SceneTreeTimer = get_tree().create_timer(delay)
		timer.timeout.connect(_on_acid_burst_timeout.bind(pos, radius * 0.42, damage, duration_amp))

func _on_acid_burst_timeout(center: Vector2, radius: float, damage: int, duration_amp: float) -> void:
	var hit: int = 0
	for enemy: Node2D in _get_enemies_in_radius(center, radius):
		_apply_damage(enemy, damage)
		_apply_status(enemy, "poison", 2.2 * duration_amp, max(1.0, float(damage) * 0.38), 1, 0.7)
		_apply_status(enemy, "slow", 1.0 * duration_amp, 0.34, 1, 0.1)
		hit += 1
	if hit > 0:
		Global.spawn_floating_text(center, "ACID x%d" % hit, Color(0.5, 0.95, 0.38))
	spawn_skill_vfx(center, Color(0.45, 0.95, 0.35, 0.75), 0.60)

func _get_goo_window(default_center: Vector2, default_radius: float) -> Array:
	var data: Array = [false, default_center, default_radius]
	if not is_instance_valid(skill_owner):
		return data
	if not skill_owner.has_meta(GOO_META_EXPIRE_MSEC):
		return data
	var expire_msec: int = int(skill_owner.get_meta(GOO_META_EXPIRE_MSEC, 0))
	if Time.get_ticks_msec() > expire_msec:
		return data
	var center_val: Variant = skill_owner.get_meta(GOO_META_CENTER, default_center)
	var radius_val: Variant = skill_owner.get_meta(GOO_META_RADIUS, default_radius)
	if not (center_val is Vector2):
		return data
	data[0] = true
	data[1] = center_val
	data[2] = max(default_radius, float(radius_val))
	return data

func _record_devour_window(center: Vector2, radius: float, split: int) -> void:
	if not is_instance_valid(skill_owner):
		return
	var safe_split: int = clampi(split, 1, 6)
	var expire_msec: int = Time.get_ticks_msec() + 2100 + safe_split * 140
	skill_owner.set_meta(GOO_E_META_CENTER, center)
	skill_owner.set_meta(GOO_E_META_RADIUS, max(70.0, radius))
	skill_owner.set_meta(GOO_E_META_SPLIT, safe_split)
	skill_owner.set_meta(GOO_E_META_EXPIRE_MSEC, expire_msec)

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

func _pick_nearest_enemy(center: Vector2, radius: float) -> Node2D:
	var nearest: Node2D = null
	var best_dist: float = radius
	for enemy: Node2D in _get_enemies_in_radius(center, radius):
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
