extends SkillBase
class_name SkillPlagueE

var detonate_radius: float = 250.0
var damage_per_stack: int = 50

const MIASMA_META_CENTER: String = "plague_miasma_center"
const MIASMA_META_RADIUS: String = "plague_miasma_radius"
const MIASMA_META_EXPIRE_MSEC: String = "plague_miasma_expire_msec"
const PLAGUE_E_META_CENTER: String = "plague_e_bloom_center"
const PLAGUE_E_META_RADIUS: String = "plague_e_bloom_radius"
const PLAGUE_E_META_EXPIRE_MSEC: String = "plague_e_bloom_expire_msec"
const PLAGUE_E_META_INTENSITY: String = "plague_e_bloom_intensity"

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

	var window_data: Array = _get_miasma_window(skill_owner.global_position, final_radius)
	var synergy_used: bool = bool(window_data[0])
	var detonate_center: Vector2 = window_data[1] if window_data.size() > 1 and window_data[1] is Vector2 else skill_owner.global_position
	var detonate_range: float = float(window_data[2]) if window_data.size() > 2 else final_radius
	if synergy_used:
		detonate_range = max(detonate_range, final_radius * 0.90)
		bloom_scale += 0.12

	var infected_refs: Array = []
	var total_hits: int = 0
	for enemy: Node2D in _get_enemies_in_radius(detonate_center, detonate_range):
		var stacks: int = _get_poison_stacks(enemy)
		if stacks <= 0:
			continue
		_clear_poison(enemy)
		var total_damage: int = max(1, stacks * per_stack_damage)
		if synergy_used:
			total_damage = int(round(float(total_damage) * 1.18))
		_apply_damage(enemy, total_damage)
		_apply_status(enemy, "curse", 2.0 * duration_amp, max(1.0, float(total_damage) * 0.22), 1, 0.7)
		_apply_status(enemy, "slow", 1.0 * duration_amp, 0.26, 1, 0.1)
		infected_refs.append(weakref(enemy))
		total_hits += 1
		Global.spawn_floating_text(enemy.global_position, "BLOOM x%d" % stacks, Color(0.52, 0.92, 0.25))

	if infected_refs.is_empty():
		if synergy_used:
			_seed_curse(detonate_center, detonate_range * 0.66, duration_amp)
			_record_bloom_window(detonate_center, detonate_range * 0.66, 1)
			Global.spawn_floating_text(skill_owner.global_position, "MIASMA SEED", Color(0.62, 0.92, 0.35))
		else:
			Global.spawn_floating_text(skill_owner.global_position, "No Poison!", Color(0.7, 0.75, 0.65))
		start_cooldown()
		return

	var bloom_delay: float = 0.30 if not is_f_window_active() else 0.22
	if synergy_used:
		bloom_delay = max(0.12, bloom_delay - 0.06)
	var timer: SceneTreeTimer = get_tree().create_timer(bloom_delay)
	timer.timeout.connect(_on_bloom_timeout.bind(infected_refs, detonate_range * 0.32, bloom_scale, duration_amp))

	if synergy_used:
		_refund_q_cooldown(1.2)
		Global.spawn_floating_text(skill_owner.global_position, "PLAGUE BURST+ x%d" % total_hits, Color(0.52, 0.94, 0.30))
	else:
		Global.spawn_floating_text(skill_owner.global_position, "PLAGUE BURST x%d" % total_hits, Color(0.45, 0.85, 0.2))
	_record_bloom_window(detonate_center, detonate_range, total_hits)
	Global.on_camera_shake.emit(7.8, 0.16)
	start_cooldown()

func _on_bloom_timeout(target_refs: Array, bloom_radius: float, bloom_scale: float, duration_amp: float) -> void:
	var bloom_damage: int = max(1, int(round(30.0 * get_e_damage_amp(0.22, 0.30) * bloom_scale)))
	var exploded: int = 0
	for ref_obj: Variant in target_refs:
		var target: Variant = ref_obj.get_ref() if ref_obj != null else null
		if target == null or not is_instance_valid(target):
			continue
		if not (target is Node2D):
			continue
		var target_node: Node2D = target
		for enemy: Node2D in _get_enemies_in_radius(target_node.global_position, bloom_radius):
			_apply_damage(enemy, bloom_damage)
			_apply_status(enemy, "poison", 2.2 * duration_amp, max(1.0, float(bloom_damage) * 0.35), 1, 0.7)
			_apply_status(enemy, "slow", 0.8, 0.22, 1, 0.1)
			exploded += 1
		spawn_skill_vfx(target_node.global_position, Color(0.48, 0.95, 0.32, 0.75), 0.52)

	if exploded > 0 and is_instance_valid(skill_owner):
		Global.spawn_floating_text(skill_owner.global_position, "SPREAD x%d" % exploded, Color(0.58, 0.95, 0.35))

func _seed_curse(center: Vector2, radius: float, duration_amp: float) -> void:
	for enemy: Node2D in _get_enemies_in_radius(center, radius):
		_apply_status(enemy, "curse", 1.8 * duration_amp, 8.0, 1, 0.7)
		_apply_status(enemy, "poison", 1.6 * duration_amp, 12.0, 1, 0.7)

func _record_bloom_window(center: Vector2, radius: float, intensity: int) -> void:
	if not is_instance_valid(skill_owner):
		return
	var safe_intensity: int = clampi(intensity, 1, 12)
	var expire_msec: int = Time.get_ticks_msec() + 2300 + safe_intensity * 90
	skill_owner.set_meta(PLAGUE_E_META_CENTER, center)
	skill_owner.set_meta(PLAGUE_E_META_RADIUS, max(80.0, radius))
	skill_owner.set_meta(PLAGUE_E_META_INTENSITY, safe_intensity)
	skill_owner.set_meta(PLAGUE_E_META_EXPIRE_MSEC, expire_msec)

func _get_miasma_window(default_center: Vector2, default_radius: float) -> Array:
	var data: Array = [false, default_center, default_radius]
	if not is_instance_valid(skill_owner):
		return data
	if not skill_owner.has_meta(MIASMA_META_EXPIRE_MSEC):
		return data
	var expire_msec: int = int(skill_owner.get_meta(MIASMA_META_EXPIRE_MSEC, 0))
	if Time.get_ticks_msec() > expire_msec:
		return data
	var center_val: Variant = skill_owner.get_meta(MIASMA_META_CENTER, default_center)
	var radius_val: Variant = skill_owner.get_meta(MIASMA_META_RADIUS, default_radius)
	if not (center_val is Vector2):
		return data
	data[0] = true
	data[1] = center_val
	data[2] = max(default_radius * 0.8, float(radius_val))
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
