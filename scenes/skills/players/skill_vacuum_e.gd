extends SkillBase
class_name SkillVacuumE

var vacuum_radius: float = 300.0
const VACUUM_META_CENTER: String = "vacuum_vortex_center"
const VACUUM_META_RADIUS: String = "vacuum_vortex_radius"
const VACUUM_META_EXPIRE_MSEC: String = "vacuum_vortex_expire_msec"

func execute() -> void:
	if not consume_energy():
		if is_instance_valid(skill_owner):
			Global.spawn_floating_text(skill_owner.global_position, "No Energy!", Color.RED)
		return
	if not is_instance_valid(skill_owner):
		return

	var duration_amp: float = get_e_duration_amp(0.36)
	var damage_amp: float = get_e_damage_amp(0.24, 0.32)
	var final_radius: float = vacuum_radius * (1.0 + (duration_amp - 1.0) * 0.42)
	var center: Vector2 = skill_owner.global_position
	var synergy_active: bool = _is_vortex_window_active()
	if synergy_active:
		center = _vortex_center_from_meta()
		final_radius = max(final_radius, _vortex_radius_from_meta() * 0.95)

	var collected: int = _pull_all_coins(center, final_radius)
	var sucked: int = 0
	for enemy in _get_enemies_in_radius(center, final_radius):
		_pull_enemy(enemy, center, 18.0 + 10.0 * duration_amp)
		_apply_status(enemy, "slow", 0.9 * duration_amp, 0.28, 1, 0.1)
		sucked += 1

	var burst_delay: float = 0.22 if not is_f_window_active() else 0.16
	var burst_damage: int = max(1, int(round(34.0 * damage_amp * (1.0 if not is_f_window_active() else 1.25))))
	if synergy_active:
		burst_damage = max(burst_damage, int(round(float(burst_damage) * 1.22)))
	var timer: SceneTreeTimer = get_tree().create_timer(burst_delay)
	timer.timeout.connect(_on_reverse_burst_timeout.bind(center, final_radius * 0.74, burst_damage, duration_amp))

	if collected > 0:
		Global.spawn_floating_text(center, "VACUUM x%d" % collected, Color(0.56, 0.42, 0.9))
	else:
		Global.spawn_floating_text(center, "VACUUM", Color(0.56, 0.42, 0.9))
	if sucked > 0:
		Global.spawn_floating_text(center + Vector2(0.0, -22.0), "SUCK x%d" % sucked, Color(0.72, 0.6, 1.0))
	Global.on_camera_shake.emit(6.4, 0.14)
	start_cooldown()

func _on_reverse_burst_timeout(center: Vector2, radius: float, damage: int, duration_amp: float) -> void:
	var hit: int = 0
	for enemy in _get_enemies_in_radius(center, radius):
		_apply_damage(enemy, damage)
		_apply_status(enemy, "slow", 1.0 * duration_amp, 0.34, 1, 0.1)
		_knock_enemy(enemy, center, 260.0 + 120.0 * duration_amp)
		hit += 1
	if hit > 0 and is_instance_valid(skill_owner):
		Global.spawn_floating_text(skill_owner.global_position, "REVERSE x%d" % hit, Color(0.88, 0.62, 1.0))
	spawn_skill_vfx(center, Color(0.7, 0.55, 1.0, 0.75), 0.78)

func _pull_all_coins(center: Vector2, radius: float) -> int:
	var count: int = 0
	var tree: SceneTree = get_tree()
	if tree == null or tree.current_scene == null:
		return count
	var coins: Array = _find_coins_recursive(tree.current_scene)
	for coin in coins:
		if coin == null or not is_instance_valid(coin):
			continue
		if not (coin is Node2D):
			continue
		if "is_collected" in coin and bool(coin.is_collected):
			continue
		if center.distance_to((coin as Node2D).global_position) > radius:
			continue
		coin.global_position = center
		if "is_magnetized" in coin:
			coin.is_magnetized = true
		count += 1
	return count

func _find_coins_recursive(node: Node) -> Array:
	var result: Array = []
	if node is GoldCoin:
		result.append(node)
	for child in node.get_children():
		result.append_array(_find_coins_recursive(child))
	return result

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

func _apply_status(enemy: Node, status_name: String, duration: float, value: float, stacks: int = 1, tick_interval: float = 0.6) -> void:
	if not is_instance_valid(enemy):
		return
	if enemy.has_method("apply_status"):
		enemy.apply_status(status_name, max(0.1, duration), value, max(1, stacks), max(0.05, tick_interval))

func _pull_enemy(enemy: Node, center: Vector2, distance: float) -> void:
	if not (enemy is Node2D):
		return
	var enemy_node: Node2D = enemy
	var diff: Vector2 = center - enemy_node.global_position
	if diff.length_squared() <= 1.0:
		return
	enemy_node.global_position += diff.normalized() * distance

func _knock_enemy(enemy: Node, center: Vector2, power: float) -> void:
	if enemy.has_method("apply_knockback") and enemy is Node2D:
		var enemy_node1: Node2D = enemy
		var dir: Vector2 = center.direction_to(enemy_node1.global_position)
		enemy.apply_knockback(dir, power)
		return
	if enemy is Node2D:
		var enemy_node2: Node2D = enemy
		var dir2: Vector2 = center.direction_to(enemy_node2.global_position)
		enemy_node2.global_position += dir2 * power * 0.02

func _is_vortex_window_active() -> bool:
	if not is_instance_valid(skill_owner):
		return false
	if not skill_owner.has_meta(VACUUM_META_EXPIRE_MSEC):
		return false
	var expire_msec: int = int(skill_owner.get_meta(VACUUM_META_EXPIRE_MSEC, 0))
	return Time.get_ticks_msec() <= expire_msec

func _vortex_center_from_meta() -> Vector2:
	var center_val: Variant = skill_owner.get_meta(VACUUM_META_CENTER, skill_owner.global_position)
	if center_val is Vector2:
		return center_val
	return skill_owner.global_position

func _vortex_radius_from_meta() -> float:
	return max(60.0, float(skill_owner.get_meta(VACUUM_META_RADIUS, vacuum_radius)))
