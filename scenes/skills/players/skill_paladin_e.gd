extends SkillBase
class_name SkillPaladinE

var taunt_radius: float = 250.0
var taunt_duration: float = 3.0
var smite_damage: int = 36
const SANCTUARY_META_CENTER: String = "paladin_sanctuary_center"
const SANCTUARY_META_RADIUS: String = "paladin_sanctuary_radius"
const SANCTUARY_META_EXPIRE_MSEC: String = "paladin_sanctuary_expire_msec"

func execute() -> void:
	if not consume_energy():
		if is_instance_valid(skill_owner):
			Global.spawn_floating_text(skill_owner.global_position, "No Energy!", Color.RED)
		return
	if not is_instance_valid(skill_owner):
		return

	var damage_amp: float = get_e_damage_amp(0.26, 0.32)
	var duration_amp: float = get_e_duration_amp(0.4)
	var final_radius: float = taunt_radius * (1.0 + (duration_amp - 1.0) * 0.35)
	var final_duration: float = taunt_duration * duration_amp
	var final_damage: int = max(1, int(round(25.0 * damage_amp)))
	var sanctuary_active: bool = _is_sanctuary_active()
	if sanctuary_active:
		final_radius = max(final_radius, _sanctuary_radius_from_meta() * 0.85)
		final_damage = max(final_damage, int(round(float(smite_damage) * damage_amp)))

	var hit_count: int = 0
	for enemy in _get_enemies_in_radius(skill_owner.global_position, final_radius):
		_apply_damage(enemy, final_damage)
		if enemy.has_method("set_taunt_target"):
			enemy.set_taunt_target(skill_owner)
			if enemy.has_method("apply_status"):
				enemy.apply_status("marked", final_duration, 0.12 * damage_amp, 1, 999.0)
			var enemy_ref: WeakRef = weakref(enemy)
			var timer: SceneTreeTimer = get_tree().create_timer(final_duration)
			timer.timeout.connect(_on_taunt_timeout.bind(enemy_ref))
		hit_count += 1

	if is_f_window_active() and "armor" in skill_owner and "max_armor" in skill_owner:
		skill_owner.armor = min(skill_owner.max_armor, skill_owner.armor + 1)
		if skill_owner.has_signal("armor_changed"):
			skill_owner.armor_changed.emit(skill_owner.armor)
		Global.spawn_floating_text(skill_owner.global_position, "AEGIS!", Color(1.0, 0.9, 0.5))
	elif sanctuary_active and "armor" in skill_owner and "max_armor" in skill_owner:
		skill_owner.armor = min(skill_owner.max_armor, skill_owner.armor + 1)
		if skill_owner.has_signal("armor_changed"):
			skill_owner.armor_changed.emit(skill_owner.armor)
		Global.spawn_floating_text(skill_owner.global_position, "SANCTUARY!", Color(1.0, 0.86, 0.4))

	if hit_count > 0:
		Global.spawn_floating_text(skill_owner.global_position, "TAUNT x%d" % hit_count, Color(1.0, 0.85, 0.3))
	else:
		Global.spawn_floating_text(skill_owner.global_position, "NO TARGET", Color(0.8, 0.75, 0.65))
	spawn_skill_vfx(skill_owner.global_position, Color(1.0, 0.85, 0.3, 0.8), 0.7)
	if sanctuary_active:
		_trigger_sanctuary_smite(final_damage, duration_amp)
	Global.on_camera_shake.emit(6.0, 0.2)
	start_cooldown()

func _on_taunt_timeout(enemy_ref: WeakRef) -> void:
	var enemy = enemy_ref.get_ref() if enemy_ref != null else null
	if enemy and is_instance_valid(enemy):
		enemy.override_target = null

func _get_enemies_in_radius(center: Vector2, radius: float) -> Array:
	var result: Array = []
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(enemy):
			continue
		if not (enemy is Node2D):
			continue
		var enemy_node: Node2D = enemy
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

func _is_sanctuary_active() -> bool:
	if not is_instance_valid(skill_owner):
		return false
	if not skill_owner.has_meta(SANCTUARY_META_EXPIRE_MSEC):
		return false
	var expire_msec: int = int(skill_owner.get_meta(SANCTUARY_META_EXPIRE_MSEC, 0))
	return Time.get_ticks_msec() <= expire_msec

func _sanctuary_center_from_meta() -> Vector2:
	var center_value: Variant = skill_owner.get_meta(SANCTUARY_META_CENTER, skill_owner.global_position)
	if center_value is Vector2:
		return center_value
	return skill_owner.global_position

func _sanctuary_radius_from_meta() -> float:
	return max(40.0, float(skill_owner.get_meta(SANCTUARY_META_RADIUS, taunt_radius)))

func _trigger_sanctuary_smite(base_damage: int, duration_amp: float) -> void:
	var center: Vector2 = _sanctuary_center_from_meta()
	var radius: float = _sanctuary_radius_from_meta() * 0.72
	var damage: int = max(1, int(round(float(base_damage) * 0.66)))
	var hit_count: int = 0
	for enemy in _get_enemies_in_radius(center, radius):
		_apply_damage(enemy, damage)
		if enemy.has_method("apply_status"):
			enemy.apply_status("marked", 1.1 * duration_amp, 0.16)
		hit_count += 1
	if hit_count > 0:
		Global.spawn_floating_text(center, "SMITE x%d" % hit_count, Color(1.0, 0.86, 0.42))
		spawn_skill_vfx(center, Color(1.0, 0.88, 0.35, 0.78), 0.58)
