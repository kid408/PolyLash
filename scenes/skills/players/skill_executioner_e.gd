extends SkillEBase
class_name SkillExecutionerE

var execute_radius: float = 200.0
var execute_threshold: float = 0.2

const EXEC_META_CENTER: String = "executioner_zone_center"
const EXEC_META_RADIUS: String = "executioner_zone_radius"
const EXEC_META_EXPIRE_MSEC: String = "executioner_zone_expire_msec"

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
	var origin: Vector2 = skill_owner.global_position

	var window_data: Array = _get_execute_window(origin, final_radius)
	var synergy_used: bool = bool(window_data[0])
	if synergy_used and window_data.size() > 1 and window_data[1] is Vector2:
		origin = window_data[1]
	if synergy_used and window_data.size() > 2:
		final_radius = max(final_radius, float(window_data[2]) * 0.95)
		threshold = min(0.62, threshold + 0.08)
		fallback_damage = int(round(float(fallback_damage) * 1.12))

	var execute_refs: Array = []
	var marks: int = 0
	for enemy: Node2D in _get_enemies_in_radius(origin, final_radius):
		if _is_below_threshold(enemy, threshold):
			_apply_damage(enemy, 9999)
			Global.spawn_floating_text(enemy.global_position, "EXECUTE!", Color(1.0, 0.2, 0.2))
			execute_refs.append(weakref(enemy))
		else:
			_apply_damage(enemy, fallback_damage)
			_apply_status(enemy, "marked", 1.6, 0.24, 1, 0.3)
			if synergy_used:
				_apply_status(enemy, "slow", 1.2 * duration_amp, 0.30, 1, 0.1)
			marks += 1

	if not execute_refs.is_empty():
		var delay: float = 0.18
		if synergy_used:
			delay = 0.12
		var timer: SceneTreeTimer = get_tree().create_timer(delay)
		timer.timeout.connect(_on_guillotine_timeout.bind(origin, final_radius * 0.65, int(round(float(fallback_damage) * 1.35)), synergy_used))
		Global.spawn_floating_text(skill_owner.global_position, "GUILTY x%d" % execute_refs.size(), Color(1.0, 0.22, 0.22))
	elif marks > 0:
		Global.spawn_floating_text(skill_owner.global_position, "MARKED x%d" % marks, Color(1.0, 0.5, 0.4))
	else:
		Global.spawn_floating_text(skill_owner.global_position, "No Target!", Color(0.7, 0.7, 0.7))

	if synergy_used:
		_refund_q_cooldown(1.2)
	Global.on_camera_shake.emit(9.4, 0.20)
	start_cooldown()

func _on_guillotine_timeout(center: Vector2, radius: float, damage: int, synergy_used: bool) -> void:
	var hit: int = 0
	for enemy: Node2D in _get_enemies_in_radius(center, radius):
		if not (enemy.has_method("has_status") and enemy.has_status("marked")):
			continue
		_apply_damage(enemy, damage)
		_apply_status(enemy, "slow", 1.0, 0.34, 1, 0.1)
		if synergy_used:
			_apply_status(enemy, "fear", 0.5, 1.0, 1, 0.2)
		hit += 1
	if hit > 0 and is_instance_valid(skill_owner):
		spawn_skill_vfx(center, Color(1.0, 0.24, 0.24, 0.82), 0.72)
		Global.spawn_floating_text(skill_owner.global_position, "GUILLOTINE x%d" % hit, Color(1.0, 0.24, 0.24))

func _get_execute_window(default_center: Vector2, default_radius: float) -> Array:
	var data: Array = [false, default_center, default_radius]
	if not is_instance_valid(skill_owner):
		return data
	if not skill_owner.has_meta(EXEC_META_EXPIRE_MSEC):
		return data
	var expire_msec: int = int(skill_owner.get_meta(EXEC_META_EXPIRE_MSEC, 0))
	if Time.get_ticks_msec() > expire_msec:
		return data
	var center_val: Variant = skill_owner.get_meta(EXEC_META_CENTER, default_center)
	var radius_val: Variant = skill_owner.get_meta(EXEC_META_RADIUS, default_radius)
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

func _is_below_threshold(enemy: Node, threshold_value: float) -> bool:
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
	return current_hp <= max_hp * max(0.0, threshold_value)

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

