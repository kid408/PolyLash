extends SkillEBase
class_name SkillBloodswornE

var drain_radius: float = 200.0
var drain_damage: int = 40
var heal_percent: float = 0.5

const BLOOD_META_CENTER: String = "bloodsworn_blood_pool_center"
const BLOOD_META_RADIUS: String = "bloodsworn_blood_pool_radius"
const BLOOD_META_EXPIRE_MSEC: String = "bloodsworn_blood_pool_expire_msec"
const VAMPIRE_E_META_CENTER: String = "bloodsworn_e_rite_center"
const VAMPIRE_E_META_RADIUS: String = "bloodsworn_e_rite_radius"
const VAMPIRE_E_META_EXPIRE_MSEC: String = "bloodsworn_e_rite_expire_msec"
const VAMPIRE_E_META_INTENSITY: String = "bloodsworn_e_rite_intensity"

func execute() -> void:
	if not consume_energy():
		if is_instance_valid(skill_owner):
			Global.spawn_floating_text(skill_owner.global_position, "No Energy!", Color.RED)
		return
	if not is_instance_valid(skill_owner):
		return

	var damage_amp: float = get_e_damage_amp(0.30, 0.36)
	var duration_amp: float = get_e_duration_amp(0.35)
	var final_radius: float = drain_radius * (1.0 + (duration_amp - 1.0) * 0.34)
	var base_damage: int = max(1, int(round(float(drain_damage) * damage_amp)))
	var heal_scale: float = heal_percent * (1.0 + (damage_amp - 1.0) * 0.45)

	var center: Vector2 = skill_owner.global_position
	var window_data: Array = _get_blood_window(center, final_radius)
	var synergy_used: bool = bool(window_data[0])
	if synergy_used and window_data.size() > 1 and window_data[1] is Vector2:
		center = window_data[1]
	if synergy_used and window_data.size() > 2:
		final_radius = max(final_radius, float(window_data[2]) * 0.9)
		base_damage = int(round(float(base_damage) * 1.16))
		heal_scale *= 1.18

	var rite_center: Vector2 = center
	var rite_radius: float = final_radius * 0.56
	var rite_intensity: int = 1

	var target: Node2D = _pick_priority_target(center, final_radius)
	if target != null:
		var to_target: Vector2 = target.global_position - skill_owner.global_position
		if to_target.length_squared() > 0.01:
			skill_owner.global_position += to_target.normalized() * min(90.0, to_target.length() * 0.45)
		_apply_damage(target, base_damage)
		_apply_status(target, "curse", 2.2 * duration_amp, max(1.0, float(base_damage) * 0.28), 1, 0.7)
		_apply_status(target, "marked", 1.4, 0.22, 1, 0.3)
		var healed: int = max(1, int(round(float(base_damage) * heal_scale)))
		_heal_owner(healed)
		Global.spawn_floating_text(target.global_position, "BITE!", Color(0.95, 0.25, 0.25))
		var nova_center: Vector2 = target.global_position
		if synergy_used:
			nova_center = (target.global_position + center) * 0.5
		rite_center = nova_center
		rite_radius = final_radius * (0.52 if not synergy_used else 0.72)
		rite_intensity = 2 if not synergy_used else 3
		if is_f_window_active() or synergy_used:
			var timer: SceneTreeTimer = get_tree().create_timer(0.18)
			timer.timeout.connect(
				_on_blood_nova_timeout.bind(
					nova_center,
					final_radius * (0.52 if not synergy_used else 0.72),
					int(round(float(base_damage) * (0.72 if not synergy_used else 0.84))),
					duration_amp
				)
			)
	else:
		var total_damage: int = 0
		for enemy: Node2D in _get_enemies_in_radius(center, final_radius):
			_apply_damage(enemy, base_damage)
			_apply_status(enemy, "curse", 1.6 * duration_amp, max(1.0, float(base_damage) * 0.22), 1, 0.7)
			total_damage += base_damage
		if total_damage > 0:
			var aoe_heal: int = max(1, int(round(float(total_damage) * heal_scale * 0.65)))
			_heal_owner(aoe_heal)
			rite_radius = final_radius * 0.74
			rite_intensity = 2
		else:
			Global.spawn_floating_text(skill_owner.global_position, "No Target!", Color(0.8, 0.7, 0.7))
			rite_intensity = 0

	if synergy_used:
		_refund_q_cooldown(1.0)
		Global.spawn_floating_text(skill_owner.global_position, "BLOOD RITE", Color(0.95, 0.32, 0.32))
	if rite_intensity > 0:
		if is_f_window_active():
			rite_intensity += 1
		_record_blood_rite_window(rite_center, rite_radius, rite_intensity)
	spawn_skill_vfx(center, Color(0.88, 0.2, 0.25, 0.8), 0.74)
	Global.on_camera_shake.emit(7.5, 0.14)
	start_cooldown()

func _on_blood_nova_timeout(center: Vector2, radius: float, damage: int, duration_amp: float) -> void:
	var hit: int = 0
	for enemy: Node2D in _get_enemies_in_radius(center, radius):
		_apply_damage(enemy, damage)
		_apply_status(enemy, "slow", 1.0 * duration_amp, 0.32, 1, 0.1)
		_apply_status(enemy, "curse", 1.4 * duration_amp, max(1.0, float(damage) * 0.24), 1, 0.7)
		hit += 1
	if hit > 0 and is_instance_valid(skill_owner):
		var heal_amount: int = max(1, int(round(float(damage) * float(hit) * heal_percent * 0.35)))
		_heal_owner(heal_amount)
		Global.spawn_floating_text(skill_owner.global_position, "BLOOD NOVA", Color(0.95, 0.28, 0.28))
	spawn_skill_vfx(center, Color(0.95, 0.22, 0.3, 0.82), 0.66)

func _get_blood_window(default_center: Vector2, default_radius: float) -> Array:
	var data: Array = [false, default_center, default_radius]
	if not is_instance_valid(skill_owner):
		return data
	if not skill_owner.has_meta(BLOOD_META_EXPIRE_MSEC):
		return data
	var expire_msec: int = int(skill_owner.get_meta(BLOOD_META_EXPIRE_MSEC, 0))
	if Time.get_ticks_msec() > expire_msec:
		return data
	var center_val: Variant = skill_owner.get_meta(BLOOD_META_CENTER, default_center)
	var radius_val: Variant = skill_owner.get_meta(BLOOD_META_RADIUS, default_radius)
	if not (center_val is Vector2):
		return data
	data[0] = true
	data[1] = center_val
	data[2] = max(default_radius, float(radius_val))
	return data

func _record_blood_rite_window(center: Vector2, radius: float, intensity: int) -> void:
	if not is_instance_valid(skill_owner):
		return
	var safe_intensity: int = clampi(intensity, 1, 8)
	var expire_msec: int = Time.get_ticks_msec() + 2200 + safe_intensity * 120
	skill_owner.set_meta(VAMPIRE_E_META_CENTER, center)
	skill_owner.set_meta(VAMPIRE_E_META_RADIUS, max(70.0, radius))
	skill_owner.set_meta(VAMPIRE_E_META_INTENSITY, safe_intensity)
	skill_owner.set_meta(VAMPIRE_E_META_EXPIRE_MSEC, expire_msec)

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

func _pick_priority_target(center: Vector2, radius: float) -> Node2D:
	var enemies: Array = _get_enemies_in_radius(center, radius)
	for enemy: Node2D in enemies:
		if enemy.has_method("has_status") and enemy.has_status("marked"):
			return enemy
	for enemy: Node2D in enemies:
		if enemy.has_method("has_status") and enemy.has_status("curse"):
			return enemy
	return enemies[0] if not enemies.is_empty() else null

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

func _heal_owner(amount: int) -> void:
	if amount <= 0:
		return
	if not is_instance_valid(skill_owner):
		return
	if skill_owner.has_node("HealthComponent"):
		var hc: Node = skill_owner.get_node("HealthComponent")
		if hc and hc.has_method("heal"):
			hc.heal(float(amount))

