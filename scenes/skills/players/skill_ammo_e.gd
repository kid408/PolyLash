extends SkillBase
class_name SkillAmmoE

var barrage_damage: int = 34
var barrage_radius: float = 180.0
var barrage_mark_amp: float = 0.2
var overclock_cd_buff: float = 0.18
var overclock_duration: float = 2.6

const SUPPLY_META_CENTER: String = "ammo_supply_center"
const SUPPLY_META_RADIUS: String = "ammo_supply_radius"
const SUPPLY_META_EXPIRE_MSEC: String = "ammo_supply_expire_msec"

func execute() -> void:
	if not can_execute():
		return
	if not consume_energy():
		if is_instance_valid(skill_owner):
			Global.spawn_floating_text(skill_owner.global_position, "No Energy!", Color.RED)
		return
	if not is_instance_valid(skill_owner):
		return

	var damage_amp: float = get_e_damage_amp(0.28, 0.30)
	var duration_amp: float = get_e_duration_amp(0.35)

	_refill_energy()
	var overclock_bonus: float = overclock_cd_buff * (1.0 + (duration_amp - 1.0) * 0.45)
	_apply_overclock(overclock_bonus, overclock_duration * duration_amp)

	var synergy_used: bool = _trigger_supply_barrage(damage_amp, duration_amp)
	if synergy_used:
		Global.spawn_floating_text(skill_owner.global_position, "RESUPPLY + BARRAGE", Color(0.45, 0.85, 1.0))
		Global.on_camera_shake.emit(7.0, 0.14)
	else:
		Global.spawn_floating_text(skill_owner.global_position, "RESUPPLY", Color(0.3, 0.6, 0.2))

	start_cooldown()

func _refill_energy() -> void:
	if not is_instance_valid(skill_owner):
		return
	if "energy" in skill_owner and "max_energy" in skill_owner:
		skill_owner.energy = skill_owner.max_energy

func _apply_overclock(cd_buff: float, duration: float) -> void:
	if not is_instance_valid(skill_owner):
		return
	var had_cd_buff: bool = skill_owner.has_meta("buff_cooldown_reduction")
	var old_cd_buff: float = float(skill_owner.get_meta("buff_cooldown_reduction")) if had_cd_buff else 0.0
	var next_cd_buff: float = clamp(old_cd_buff + cd_buff, 0.0, 0.85)
	skill_owner.set_meta("buff_cooldown_reduction", next_cd_buff)
	var owner_ref: WeakRef = weakref(skill_owner)
	get_tree().create_timer(max(0.1, duration)).timeout.connect(
		_on_overclock_timeout.bind(owner_ref, had_cd_buff, old_cd_buff)
	)

func _on_overclock_timeout(owner_ref: WeakRef, had_cd_buff: bool, old_cd_buff: float) -> void:
	var owner: Variant = owner_ref.get_ref() if owner_ref != null else null
	if owner == null or not is_instance_valid(owner):
		return
	if had_cd_buff:
		owner.set_meta("buff_cooldown_reduction", old_cd_buff)
	elif owner.has_meta("buff_cooldown_reduction"):
		owner.remove_meta("buff_cooldown_reduction")

func _trigger_supply_barrage(damage_amp: float, duration_amp: float) -> bool:
	if not is_instance_valid(skill_owner):
		return false
	if not skill_owner.has_meta(SUPPLY_META_EXPIRE_MSEC):
		return false
	var expire_msec: int = int(skill_owner.get_meta(SUPPLY_META_EXPIRE_MSEC, 0))
	if Time.get_ticks_msec() > expire_msec:
		return false
	var center_value: Variant = skill_owner.get_meta(SUPPLY_META_CENTER, Vector2.ZERO)
	var radius_value: Variant = skill_owner.get_meta(SUPPLY_META_RADIUS, barrage_radius)
	if not (center_value is Vector2):
		return false

	var center: Vector2 = center_value
	var radius: float = max(40.0, float(radius_value))
	var final_damage: int = max(1, int(round(float(barrage_damage) * damage_amp)))
	var hit_count: int = 0
	for enemy_obj: Variant in get_tree().get_nodes_in_group("enemies"):
		if enemy_obj == null or not is_instance_valid(enemy_obj):
			continue
		if not (enemy_obj is Node2D):
			continue
		var enemy: Node2D = enemy_obj
		if enemy.global_position.distance_to(center) > radius:
			continue
		_apply_damage(enemy, final_damage)
		_apply_status(enemy, "marked", 1.2 * duration_amp, barrage_mark_amp, 1, 0.3)
		_apply_status(enemy, "slow", 0.9 * duration_amp, 0.26, 1, 0.1)
		hit_count += 1

	if hit_count > 0:
		spawn_skill_vfx(center, Color(0.42, 0.82, 1.0, 0.82), 0.7)
		Global.spawn_floating_text(center, "BARRAGE x%d" % hit_count, Color(0.45, 0.9, 1.0))
		_refund_q_cooldown(1.4)
		return true
	return false

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

func _apply_damage(enemy: Node2D, amount: int) -> void:
	if not enemy.has_node("HealthComponent"):
		return
	var hc: Node = enemy.get_node("HealthComponent")
	if hc != null and hc.has_method("take_damage"):
		hc.call("take_damage", max(1, amount))

func _apply_status(enemy: Node2D, status_name: String, duration: float, value: float, stacks: int = 1, tick_interval: float = 0.6) -> void:
	if enemy.has_method("apply_status"):
		enemy.call("apply_status", status_name, max(0.1, duration), value, max(1, stacks), max(0.05, tick_interval))
