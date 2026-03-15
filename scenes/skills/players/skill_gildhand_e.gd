extends SkillEBase
class_name SkillGildhandE

var touch_damage: int = 200
var touch_radius: float = 120.0
var gold_drop: int = 30
var echo_damage_ratio: float = 0.52
var echo_mark_amp: float = 0.14

const MIDAS_META_CENTER: String = "gildhand_transmute_center"
const MIDAS_META_RADIUS: String = "gildhand_transmute_radius"
const MIDAS_META_EXPIRE_MSEC: String = "gildhand_transmute_expire_msec"
const MIDAS_E_META_CENTER: String = "gildhand_e_touch_center"
const MIDAS_E_META_RADIUS: String = "gildhand_e_touch_radius"
const MIDAS_E_META_EXPIRE_MSEC: String = "gildhand_e_touch_expire_msec"
const MIDAS_E_META_COINS: String = "gildhand_e_touch_coin_bonus"

func execute() -> void:
	if not can_execute():
		return
	if not consume_energy():
		if is_instance_valid(skill_owner):
			Global.spawn_floating_text(skill_owner.global_position, "No Energy!", Color.RED)
		return
	if not is_instance_valid(skill_owner):
		return

	var damage_amp: float = get_e_damage_amp(0.28, 0.34)
	var duration_amp: float = get_e_duration_amp(0.3)
	var final_radius: float = touch_radius * (1.0 + (duration_amp - 1.0) * 0.3)
	var final_damage: int = max(1, int(round(float(touch_damage) * damage_amp)))
	var final_gold: int = max(1, int(round(float(gold_drop) * (1.0 + (damage_amp - 1.0) * 0.6))))
	var transmute_active: bool = _is_transmute_window_active()
	if transmute_active:
		final_damage = max(final_damage, int(round(float(final_damage) * 1.18)))
		final_gold += 4

	var nearest_enemy: Node2D = _pick_nearest_enemy(skill_owner.global_position, final_radius)
	if nearest_enemy != null:
		_apply_damage(nearest_enemy, final_damage)
		_apply_status(nearest_enemy, "marked", 1.8 * duration_amp, 0.14, 1, 0.3)
		if is_f_window_active():
			_apply_status(nearest_enemy, "slow", 1.2 * duration_amp, 0.3, 1, 0.1)
		Global.spawn_coin(nearest_enemy.global_position, final_gold)

		spawn_skill_vfx(nearest_enemy.global_position, Color(0.9, 0.7, 0.1, 0.8), 0.6)
		Global.on_camera_shake.emit(6.0, 0.15)
		Global.spawn_floating_text(nearest_enemy.global_position, "GOLD TOUCH!", Color(0.9, 0.7, 0.1))
		if transmute_active:
			_trigger_transmute_echo(final_damage, duration_amp)
		_record_touch_window(nearest_enemy.global_position, final_radius * 0.8, max(1, int(round(float(final_gold) / 16.0))))
	else:
		_record_touch_window(skill_owner.global_position, final_radius * 0.6, 1)
		Global.spawn_floating_text(skill_owner.global_position, "No Target!", Color.GRAY)

	start_cooldown()

func _is_transmute_window_active() -> bool:
	if not is_instance_valid(skill_owner):
		return false
	if not skill_owner.has_meta(MIDAS_META_EXPIRE_MSEC):
		return false
	var expire_msec: int = int(skill_owner.get_meta(MIDAS_META_EXPIRE_MSEC, 0))
	return Time.get_ticks_msec() <= expire_msec

func _transmute_center_from_meta() -> Vector2:
	var center_val: Variant = skill_owner.get_meta(MIDAS_META_CENTER, skill_owner.global_position)
	if center_val is Vector2:
		return center_val
	return skill_owner.global_position

func _transmute_radius_from_meta() -> float:
	return max(40.0, float(skill_owner.get_meta(MIDAS_META_RADIUS, touch_radius)))

func _trigger_transmute_echo(base_damage: int, duration_amp: float) -> void:
	var center: Vector2 = _transmute_center_from_meta()
	var radius: float = _transmute_radius_from_meta() * 0.68
	var damage: int = max(1, int(round(float(base_damage) * echo_damage_ratio)))
	var hit_count: int = 0
	for enemy in _get_enemies_in_radius(center, radius):
		_apply_damage(enemy, damage)
		_apply_status(enemy, "marked", 1.0 * duration_amp, echo_mark_amp, 1, 0.3)
		hit_count += 1
	if hit_count > 0:
		Global.spawn_floating_text(center, "TRANSMUTE ECHO x%d" % hit_count, Color(1.0, 0.84, 0.28))
		spawn_skill_vfx(center, Color(0.95, 0.76, 0.2, 0.76), 0.58)

func _record_touch_window(center: Vector2, radius: float, coin_bonus: int) -> void:
	if not is_instance_valid(skill_owner):
		return
	var safe_bonus: int = clampi(coin_bonus, 1, 8)
	var expire_msec: int = Time.get_ticks_msec() + 2400 + safe_bonus * 120
	skill_owner.set_meta(MIDAS_E_META_CENTER, center)
	skill_owner.set_meta(MIDAS_E_META_RADIUS, max(70.0, radius))
	skill_owner.set_meta(MIDAS_E_META_COINS, safe_bonus)
	skill_owner.set_meta(MIDAS_E_META_EXPIRE_MSEC, expire_msec)

func _pick_nearest_enemy(center: Vector2, radius: float) -> Node2D:
	var nearest: Node2D = null
	var nearest_dist: float = radius
	for enemy_obj: Variant in get_tree().get_nodes_in_group("enemies"):
		if enemy_obj == null or not is_instance_valid(enemy_obj):
			continue
		if not (enemy_obj is Node2D):
			continue
		var enemy: Node2D = enemy_obj
		var dist: float = center.distance_to(enemy.global_position)
		if dist <= nearest_dist:
			nearest = enemy
			nearest_dist = dist
	return nearest

func _get_enemies_in_radius(center: Vector2, radius: float) -> Array:
	var result: Array = []
	for enemy_obj: Variant in get_tree().get_nodes_in_group("enemies"):
		if enemy_obj == null or not is_instance_valid(enemy_obj):
			continue
		if not (enemy_obj is Node2D):
			continue
		var enemy: Node2D = enemy_obj
		if center.distance_to(enemy.global_position) <= radius:
			result.append(enemy)
	return result

func _apply_damage(enemy: Node2D, amount: int) -> void:
	if enemy.has_node("HealthComponent"):
		var hc: Node = enemy.get_node("HealthComponent")
		if hc != null and hc.has_method("take_damage"):
			hc.call("take_damage", max(1, amount))

func _apply_status(enemy: Node2D, status_name: String, duration: float, value: float, stacks: int = 1, tick_interval: float = 0.6) -> void:
	if enemy.has_method("apply_status"):
		enemy.call("apply_status", status_name, max(0.1, duration), value, max(1, stacks), max(0.05, tick_interval))

