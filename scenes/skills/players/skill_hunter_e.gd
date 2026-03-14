extends SkillBase
class_name SkillHunterE

var mark_radius: float = 300.0
var mark_duration: float = 5.0
var mark_damage_amp: float = 0.5
var snipe_delay: float = 0.2
var snipe_damage: int = 62

const TRAP_META_CENTER: String = "hunter_trap_center"
const TRAP_META_RADIUS: String = "hunter_trap_radius"
const TRAP_META_EXPIRE_MSEC: String = "hunter_trap_expire_msec"

func execute() -> void:
	if not consume_energy():
		if is_instance_valid(skill_owner):
			Global.spawn_floating_text(skill_owner.global_position, "No Energy!", Color.RED)
		return
	if not is_instance_valid(skill_owner):
		return

	var owner_pos: Vector2 = skill_owner.global_position
	var damage_amp: float = get_e_damage_amp(0.28, 0.32)
	var duration_amp: float = get_e_duration_amp(0.4)
	var final_mark_duration: float = mark_duration * duration_amp
	var final_mark_amp: float = mark_damage_amp * (1.0 + (damage_amp - 1.0) * 0.55)
	var final_radius: float = mark_radius

	var trap_data: Array = _get_trap_window(owner_pos, final_radius)
	var synergy_used: bool = bool(trap_data[0])
	if synergy_used and trap_data.size() > 1 and trap_data[1] is Vector2:
		owner_pos = trap_data[1]
	if synergy_used and trap_data.size() > 2:
		final_radius = max(final_radius, float(trap_data[2]) * 1.05)
		final_mark_amp += 0.08

	var target_count: int = 1 + (2 if is_f_window_active() else 0) + (1 if synergy_used else 0)
	var targets: Array = _pick_targets(owner_pos, final_radius, target_count)
	if targets.is_empty():
		Global.spawn_floating_text(owner_pos, "No Target!", Color.YELLOW)
		start_cooldown()
		return

	var refs: Array = []
	for target: Node2D in targets:
		if target == null or not is_instance_valid(target):
			continue
		refs.append(weakref(target))
		if target.has_method("apply_status"):
			target.apply_status("marked", final_mark_duration, final_mark_amp, 1, 0.3)
			target.apply_status("slow", 0.9 * duration_amp, 0.28, 1, 0.1)
		spawn_skill_vfx(target.global_position, Color(0.38, 0.76, 0.32, 0.72), 0.35)

	var delay: float = snipe_delay * (0.75 if is_f_window_active() else 1.0)
	if synergy_used:
		delay = max(0.08, delay - 0.05)
	var base_damage: int = max(1, int(round(float(snipe_damage) * damage_amp * (1.2 if is_f_window_active() else 1.0))))
	if synergy_used:
		base_damage = int(round(float(base_damage) * 1.12))
	get_tree().create_timer(delay).timeout.connect(_on_snipe_timeout.bind(refs, base_damage, duration_amp, synergy_used))

	if synergy_used:
		_refund_q_cooldown(1.0)
	Global.on_camera_shake.emit(5.0, 0.15)
	Global.spawn_floating_text(owner_pos, "MARK x%d" % refs.size(), Color(0.25, 0.6, 0.25))
	start_cooldown()

func _on_snipe_timeout(target_refs: Array, base_damage: int, duration_amp: float, synergy_used: bool) -> void:
	if not is_instance_valid(skill_owner):
		return
	var hit_count: int = 0
	for ref_obj: Variant in target_refs:
		var target: Variant = ref_obj.get_ref() if ref_obj != null else null
		if target == null or not is_instance_valid(target):
			continue
		if target.has_node("HealthComponent"):
			var hc: Node = target.get_node("HealthComponent")
			if hc != null and hc.has_method("take_damage"):
				hc.call("take_damage", base_damage)
		if _is_low_hp_target(target, 0.2 if not synergy_used else 0.26):
			if target.has_node("HealthComponent"):
				var hc2: Node = target.get_node("HealthComponent")
				if hc2 != null and hc2.has_method("take_damage"):
					hc2.call("take_damage", max(1, int(round(float(base_damage) * 0.9))))
			Global.spawn_floating_text(target.global_position, "EXECUTE!", Color(1.0, 0.3, 0.3))
		if target.has_method("apply_status"):
			target.apply_status("marked", 1.0 * duration_amp, 0.2, 1, 0.3)
		if synergy_used:
			target.apply_status("freeze", 0.45 * duration_amp, 0.0, 1, 0.1)
		spawn_skill_vfx(target.global_position, Color(0.45, 0.88, 0.4, 0.8), 0.45)
		hit_count += 1
	if hit_count > 0:
		Global.spawn_floating_text(skill_owner.global_position, "SNIPE x%d" % hit_count, Color(0.35, 0.82, 0.35))

func _get_trap_window(default_center: Vector2, default_radius: float) -> Array:
	var data: Array = [false, default_center, default_radius]
	if not is_instance_valid(skill_owner):
		return data
	if not skill_owner.has_meta(TRAP_META_EXPIRE_MSEC):
		return data
	var expire_msec: int = int(skill_owner.get_meta(TRAP_META_EXPIRE_MSEC, 0))
	if Time.get_ticks_msec() > expire_msec:
		return data
	var center_val: Variant = skill_owner.get_meta(TRAP_META_CENTER, default_center)
	var radius_val: Variant = skill_owner.get_meta(TRAP_META_RADIUS, default_radius)
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

func _pick_targets(origin: Vector2, radius: float, count: int) -> Array:
	var targets: Array = []
	var enemies: Array = get_tree().get_nodes_in_group("enemies")
	for enemy_obj: Variant in enemies:
		if enemy_obj == null or not is_instance_valid(enemy_obj):
			continue
		if not (enemy_obj is Node2D):
			continue
		var enemy_node: Node2D = enemy_obj
		if origin.distance_to(enemy_node.global_position) > radius:
			continue
		var inserted: bool = false
		var dist: float = origin.distance_to(enemy_node.global_position)
		for i: int in range(targets.size()):
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
	var hc: Node = target.get_node("HealthComponent")
	if hc == null:
		return false
	var max_health: float = float(hc.get("max_health"))
	if max_health <= 0.0:
		return false
	var current_health: float = float(hc.get("current_health"))
	return current_health <= max_health * max(0.0, ratio)
