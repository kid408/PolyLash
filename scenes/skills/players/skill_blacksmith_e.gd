extends SkillEBase
class_name SkillBlacksmithE

var forge_strike_damage: int = 46
var forge_strike_radius: float = 190.0
var forge_strike_angle_deg: float = 86.0
var forge_knockback: float = 520.0
var heat_to_damage_scale: float = 0.2
var heat_to_cdr_sec: float = 0.55

const FORGE_HEAT_META: String = "blacksmith_forge_heat"
const FORGE_WINDOW_META: String = "blacksmith_forge_window_msec"

func execute() -> void:
	if not can_execute():
		return
	if not consume_energy():
		if is_instance_valid(skill_owner):
			Global.spawn_floating_text(skill_owner.global_position, "No Energy!", Color.RED)
		return
	if not is_instance_valid(skill_owner):
		return

	var q_skill_reset: bool = _reset_q_cooldown()
	var heat: float = _consume_forge_heat()
	var damage_amp: float = get_e_damage_amp(0.24, 0.34)
	var duration_amp: float = get_e_duration_amp(0.3)

	var final_damage: int = max(1, int(round(float(forge_strike_damage) * damage_amp * (1.0 + heat * heat_to_damage_scale))))
	var final_radius: float = forge_strike_radius * (1.0 + (duration_amp - 1.0) * 0.35)
	var final_angle: float = forge_strike_angle_deg + heat * 6.0
	var hit_count: int = _cast_forge_cone(final_damage, final_radius, final_angle, forge_knockback)

	if q_skill_reset and heat > 0.0:
		_refund_q_cooldown(heat_to_cdr_sec * heat)

	if is_f_window_active():
		_apply_overheat_boost(0.2 + heat * 0.05, 2.8 * duration_amp)

	var text: String = "FORGE STRIKE x%d" % hit_count
	if q_skill_reset:
		text += " / Q RESET"
	Global.spawn_floating_text(skill_owner.global_position, text, Color(1.0, 0.55, 0.2))
	Global.on_camera_shake.emit(6.0 + heat * 0.8, 0.15)
	start_cooldown()

func _reset_q_cooldown() -> bool:
	var skill_manager: Node = skill_owner.get_node_or_null("SkillManager")
	if skill_manager == null:
		return false
	if not skill_manager.has_method("has_skill") or not skill_manager.call("has_skill", "q"):
		return false
	if not skill_manager.has_method("get_skill"):
		return false
	var q_skill_obj: Variant = skill_manager.call("get_skill", "q")
	if q_skill_obj == null or not is_instance_valid(q_skill_obj):
		return false
	if not (q_skill_obj is SkillBase):
		return false
	var q_skill: SkillBase = q_skill_obj
	q_skill.reset_cooldown()
	return true

func _consume_forge_heat() -> float:
	if not is_instance_valid(skill_owner):
		return 0.0
	if not skill_owner.has_meta(FORGE_HEAT_META):
		return 0.0
	var heat: float = float(skill_owner.get_meta(FORGE_HEAT_META, 0.0))
	var expire_msec: int = int(skill_owner.get_meta(FORGE_WINDOW_META, 0))
	if Time.get_ticks_msec() > expire_msec:
		heat = 0.0
	skill_owner.set_meta(FORGE_HEAT_META, 0.0)
	return max(0.0, heat)

func _cast_forge_cone(damage: int, radius: float, angle_deg: float, knockback: float) -> int:
	var origin: Vector2 = skill_owner.global_position
	var aim: Vector2 = skill_owner.get_global_mouse_position()
	var forward: Vector2 = (aim - origin).normalized()
	if forward == Vector2.ZERO:
		forward = Vector2.RIGHT.rotated(skill_owner.rotation)
	var cos_limit: float = cos(deg_to_rad(angle_deg * 0.5))
	var hit_count: int = 0
	for enemy_obj: Variant in get_tree().get_nodes_in_group("enemies"):
		if enemy_obj == null or not is_instance_valid(enemy_obj):
			continue
		if not (enemy_obj is Node2D):
			continue
		var enemy: Node2D = enemy_obj
		var vec: Vector2 = enemy.global_position - origin
		var dist: float = vec.length()
		if dist > radius or dist <= 0.1:
			continue
		var dir: Vector2 = vec / dist
		if forward.dot(dir) < cos_limit:
			continue
		_apply_damage(enemy, damage)
		if enemy.has_method("apply_status"):
			enemy.call("apply_status", "marked", 1.2, 0.18, 1, 0.3)
			enemy.call("apply_status", "slow", 0.9, 0.24, 1, 0.1)
		if enemy.has_method("apply_knockback"):
			enemy.call("apply_knockback", dir, knockback)
		hit_count += 1
	return hit_count

func _refund_q_cooldown(seconds: float) -> void:
	if seconds <= 0.0:
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

func _apply_overheat_boost(attack_delta: float, duration: float) -> void:
	var had_attack_meta: bool = skill_owner.has_meta("attack_boost")
	var old_attack_meta: float = float(skill_owner.get_meta("attack_boost")) if had_attack_meta else 0.0
	skill_owner.set_meta("attack_boost", old_attack_meta + attack_delta)
	var owner_ref: WeakRef = weakref(skill_owner)
	get_tree().create_timer(max(0.1, duration)).timeout.connect(
		_on_overheat_timeout.bind(owner_ref, had_attack_meta, old_attack_meta)
	)

func _on_overheat_timeout(owner_ref: WeakRef, had_attack_meta: bool, old_attack_meta: float) -> void:
	var owner_obj: Variant = owner_ref.get_ref() if owner_ref != null else null
	if owner_obj == null or not is_instance_valid(owner_obj):
		return
	var owner: Node = owner_obj
	if had_attack_meta:
		owner.set_meta("attack_boost", old_attack_meta)
	elif owner.has_meta("attack_boost"):
		owner.remove_meta("attack_boost")

func _apply_damage(enemy: Node2D, amount: int) -> void:
	if enemy.has_node("HealthComponent"):
		var hc: Node = enemy.get_node("HealthComponent")
		if hc != null and hc.has_method("take_damage"):
			hc.call("take_damage", max(1, amount))

