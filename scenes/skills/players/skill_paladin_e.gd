extends SkillBase
class_name SkillPaladinE

var taunt_radius: float = 250.0
var taunt_duration: float = 3.0

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

	if hit_count > 0:
		Global.spawn_floating_text(skill_owner.global_position, "TAUNT x%d" % hit_count, Color(1.0, 0.85, 0.3))
	else:
		Global.spawn_floating_text(skill_owner.global_position, "NO TARGET", Color(0.8, 0.75, 0.65))
	spawn_skill_vfx(skill_owner.global_position, Color(1.0, 0.85, 0.3, 0.8), 0.7)
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
