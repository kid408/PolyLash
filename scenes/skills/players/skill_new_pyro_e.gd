extends SkillBase
class_name SkillNewPyroE

var knockback_force: float = 600.0
var explosion_radius: float = 160.0
var explosion_damage: int = 45
const NEW_PYRO_META_CENTER: String = "new_pyro_fire_center"
const NEW_PYRO_META_RADIUS: String = "new_pyro_fire_radius"
const NEW_PYRO_META_EXPIRE_MSEC: String = "new_pyro_fire_expire_msec"

func execute() -> void:
	if not consume_energy():
		if is_instance_valid(skill_owner):
			Global.spawn_floating_text(skill_owner.global_position, "No Energy!", Color.RED)
		return
	if not is_instance_valid(skill_owner):
		return

	var damage_amp: float = get_e_damage_amp(0.30, 0.36)
	var duration_amp: float = get_e_duration_amp(0.36)
	var final_radius: float = explosion_radius * (1.0 + (duration_amp - 1.0) * 0.36)
	var base_damage: int = max(1, int(round(float(explosion_damage) * damage_amp)))
	var base_burn_duration: float = 2.0 * duration_amp
	var base_burn_value: float = 8.0 * damage_amp
	var base_knockback: float = knockback_force * (1.0 + (duration_amp - 1.0) * 0.30)
	var synergy_bonus: bool = _is_fire_window_active()
	var rune_count: int = 2 if not is_f_window_active() else 3
	if synergy_bonus:
		rune_count += 1
		base_damage = max(base_damage, int(round(float(base_damage) * 1.18)))

	var aim_dir: Vector2 = _get_aim_direction()
	var spread: float = 0.42
	for i in range(rune_count):
		var ratio: float = 0.5 if rune_count <= 1 else float(i) / float(rune_count - 1)
		var angle: float = lerp(-spread, spread, ratio)
		var dir: Vector2 = aim_dir.rotated(angle)
		var pos: Vector2 = skill_owner.global_position + dir * (76.0 + 54.0 * float(i))
		var delay: float = 0.12 + 0.09 * float(i)
		var timer: SceneTreeTimer = get_tree().create_timer(delay)
		timer.timeout.connect(
			_on_rune_detonate_timeout.bind(
				pos,
				final_radius * (0.52 + 0.08 * float(i)),
				base_damage + int(round(float(base_damage) * 0.12 * float(i))),
				base_burn_duration,
				base_burn_value,
				base_knockback,
				i == rune_count - 1 and rune_count >= 3
			)
		)
		spawn_skill_vfx(pos, Color(1.0, 0.4, 0.16, 0.4), 0.35)

	if synergy_bonus:
		_trigger_firefield_echo(base_damage, duration_amp)

	Global.spawn_floating_text(skill_owner.global_position, "RUNE IGNITE!", Color(1.0, 0.45, 0.2))
	Global.on_camera_shake.emit(7.5, 0.16)
	start_cooldown()

func _on_rune_detonate_timeout(
	center: Vector2,
	radius: float,
	damage: int,
	burn_duration: float,
	burn_value: float,
	knockback: float,
	is_final_wave: bool
) -> void:
	var hit_count: int = 0
	for enemy in _get_enemies_in_radius(center, radius):
		_apply_damage(enemy, damage)
		_apply_status(enemy, "burn", burn_duration, burn_value, 1, 0.7)
		_knock_enemy(enemy, center, knockback)
		if is_final_wave:
			_apply_status(enemy, "marked", 1.3, 0.18)
		hit_count += 1

	if hit_count > 0:
		var text: String = "RUNE!"
		if is_final_wave:
			text = "INFERNO!"
		Global.spawn_floating_text(center, text, Color(1.0, 0.56, 0.24))
	spawn_skill_vfx(center, Color(1.0, 0.45, 0.2, 0.85), 0.72)

func _get_aim_direction() -> Vector2:
	if not is_instance_valid(skill_owner):
		return Vector2.RIGHT
	var dir: Vector2 = skill_owner.get_global_mouse_position() - skill_owner.global_position
	if dir.length_squared() <= 0.01:
		return Vector2.RIGHT
	return dir.normalized()

func _get_enemies_in_radius(center: Vector2, radius: float) -> Array:
	var result: Array = []
	var enemies: Array = get_tree().get_nodes_in_group("enemies")
	for enemy in enemies:
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

func _apply_status(enemy: Node, status_name: String, duration: float, value: float, stacks: int = 1, tick_interval: float = 0.5) -> void:
	if not is_instance_valid(enemy):
		return
	if enemy.has_method("apply_status"):
		enemy.apply_status(status_name, max(0.1, duration), value, max(1, stacks), max(0.05, tick_interval))

func _knock_enemy(enemy: Node, center: Vector2, power: float) -> void:
	if not is_instance_valid(enemy):
		return
	if enemy.has_method("apply_knockback") and enemy is Node2D:
		var enemy_node: Node2D = enemy
		var dir: Vector2 = center.direction_to(enemy_node.global_position)
		enemy.apply_knockback(dir, power)
		return
	if enemy is Node2D:
		var enemy_node2: Node2D = enemy
		var push_dir: Vector2 = center.direction_to(enemy_node2.global_position)
		enemy_node2.global_position += push_dir * power * 0.02

func _is_fire_window_active() -> bool:
	if not is_instance_valid(skill_owner):
		return false
	if not skill_owner.has_meta(NEW_PYRO_META_EXPIRE_MSEC):
		return false
	var expire_msec: int = int(skill_owner.get_meta(NEW_PYRO_META_EXPIRE_MSEC, 0))
	return Time.get_ticks_msec() <= expire_msec

func _trigger_firefield_echo(base_damage: int, duration_amp: float) -> void:
	if not is_instance_valid(skill_owner):
		return
	var center_val: Variant = skill_owner.get_meta(NEW_PYRO_META_CENTER, skill_owner.global_position)
	var radius_val: Variant = skill_owner.get_meta(NEW_PYRO_META_RADIUS, explosion_radius)
	if not (center_val is Vector2):
		return
	var center: Vector2 = center_val
	var radius: float = max(30.0, float(radius_val) * 0.55)
	var echo_damage: int = max(1, int(round(float(base_damage) * 0.56)))
	var hit_count: int = 0
	for enemy in _get_enemies_in_radius(center, radius):
		_apply_damage(enemy, echo_damage)
		_apply_status(enemy, "burn", 1.6 * duration_amp, max(1.0, float(echo_damage) * 0.38), 1, 0.5)
		hit_count += 1
	if hit_count > 0:
		Global.spawn_floating_text(center, "FIELD ECHO x%d" % hit_count, Color(1.0, 0.56, 0.22))
		spawn_skill_vfx(center, Color(1.0, 0.5, 0.2, 0.78), 0.6)
