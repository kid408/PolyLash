extends SkillBase
class_name SkillHerderExplosion

var explosion_radius: float = 220.0
var explosion_damage: int = 66
var explosion_knockback: float = 780.0
var cone_half_angle_deg: float = 44.0
var pen_pull_strength: float = 950.0
var pen_bonus_damage: int = 42
var execute_threshold_ratio: float = 0.30
var q_cooldown_refund_sec: float = 1.8
var pen_mark_amp: float = 0.18

const PEN_META_CENTER: String = "herder_pen_center"
const PEN_META_RADIUS: String = "herder_pen_radius"
const PEN_META_EXPIRE_MSEC: String = "herder_pen_expire_msec"

func execute() -> void:
	if not can_execute():
		return
	if not consume_energy():
		if is_instance_valid(skill_owner):
			Global.spawn_floating_text(skill_owner.global_position, "No Energy!", Color.RED)
		return
	if not is_instance_valid(skill_owner):
		return

	var origin: Vector2 = skill_owner.global_position
	var aim: Vector2 = skill_owner.get_global_mouse_position()
	var forward: Vector2 = (aim - origin).normalized()
	if forward == Vector2.ZERO:
		forward = Vector2.RIGHT.rotated(skill_owner.rotation)

	var cone_cos: float = cos(deg_to_rad(cone_half_angle_deg))
	var hit_count: int = 0
	var execute_count: int = 0

	var enemies: Array = get_tree().get_nodes_in_group("enemies")
	for enemy_obj: Variant in enemies:
		if enemy_obj == null or not is_instance_valid(enemy_obj):
			continue
		if not (enemy_obj is Node2D):
			continue
		var enemy: Node2D = enemy_obj
		var to_enemy: Vector2 = enemy.global_position - origin
		var distance: float = to_enemy.length()
		if distance > explosion_radius:
			continue
		var dir_to_enemy: Vector2 = to_enemy / max(1.0, distance)
		if forward.dot(dir_to_enemy) < cone_cos:
			continue

		var damage: int = explosion_damage
		var in_pen: bool = _is_enemy_in_recent_pen(enemy)
		if in_pen:
			damage += pen_bonus_damage
			_pull_to_pen_center(enemy, pen_pull_strength)
			_apply_status(enemy, "marked", 1.6, pen_mark_amp, 1, 0.35)
			var executed: bool = _try_execute_bonus(enemy, int(round(float(pen_bonus_damage) * 0.9)))
			if executed:
				execute_count += 1
		else:
			_push_away(enemy, forward, explosion_knockback)

		_apply_damage(enemy, damage)
		_apply_status(enemy, "slow", 0.8, 0.32, 1, 0.2)
		hit_count += 1

	if hit_count > 0:
		var label: String = "DRIVE x%d" % hit_count
		if execute_count > 0:
			label += " / EXEC %d" % execute_count
		Global.spawn_floating_text(origin, label, Color(1.2, 0.95, 0.35))
		spawn_skill_vfx(origin, Color(1.18, 0.88, 0.3, 0.85), 0.78)
		Global.on_camera_shake.emit(8.2 + float(execute_count) * 0.6, 0.16)
		_refund_q_cooldown(q_cooldown_refund_sec + float(execute_count) * 0.25)

	start_cooldown()

func _is_enemy_in_recent_pen(enemy: Node2D) -> bool:
	if not is_instance_valid(skill_owner):
		return false
	if not skill_owner.has_meta(PEN_META_EXPIRE_MSEC):
		return false
	var expire_msec: int = int(skill_owner.get_meta(PEN_META_EXPIRE_MSEC, 0))
	if Time.get_ticks_msec() > expire_msec:
		return false
	var center_value: Variant = skill_owner.get_meta(PEN_META_CENTER, Vector2.ZERO)
	var radius_value: Variant = skill_owner.get_meta(PEN_META_RADIUS, 0.0)
	if not (center_value is Vector2):
		return false
	var center: Vector2 = center_value
	var radius: float = max(1.0, float(radius_value))
	return enemy.global_position.distance_to(center) <= radius * 1.08

func _pull_to_pen_center(enemy: Node2D, strength: float) -> void:
	var center_value: Variant = skill_owner.get_meta(PEN_META_CENTER, Vector2.ZERO)
	if not (center_value is Vector2):
		return
	var center: Vector2 = center_value
	var pull_dir: Vector2 = (center - enemy.global_position).normalized()
	if enemy.has_method("apply_knockback"):
		enemy.call("apply_knockback", pull_dir, strength)
	else:
		enemy.global_position += pull_dir * 18.0

func _push_away(enemy: Node2D, forward: Vector2, strength: float) -> void:
	if enemy.has_method("apply_knockback"):
		enemy.call("apply_knockback", forward, strength)
	else:
		enemy.global_position += forward * 14.0

func _try_execute_bonus(enemy: Node2D, extra_damage: int) -> bool:
	if not enemy.has_node("HealthComponent"):
		return false
	var hc: Node = enemy.get_node("HealthComponent")
	if hc == null:
		return false
	if not ("max_health" in hc and "current_health" in hc):
		return false
	var max_hp: float = max(1.0, float(hc.get("max_health")))
	var hp_ratio: float = float(hc.get("current_health")) / max_hp
	if hp_ratio > execute_threshold_ratio:
		return false
	if hc.has_method("take_damage"):
		hc.call("take_damage", max(1, extra_damage))
	return true

func _apply_damage(enemy: Node2D, damage: int) -> void:
	if not enemy.has_node("HealthComponent"):
		return
	var hc: Node = enemy.get_node("HealthComponent")
	if hc != null and hc.has_method("take_damage"):
		hc.call("take_damage", max(1, damage))

func _apply_status(enemy: Node2D, status_name: String, duration: float, value: float, stacks: int = 1, tick_interval: float = 0.6) -> void:
	if enemy.has_method("apply_status"):
		enemy.call("apply_status", status_name, max(0.1, duration), value, max(1, stacks), max(0.05, tick_interval))

func _refund_q_cooldown(seconds: float) -> void:
	if seconds <= 0.0:
		return
	if not is_instance_valid(skill_owner):
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
