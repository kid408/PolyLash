extends SkillBase
class_name SkillTrainE

var blind_radius: float = 200.0
var blind_duration: float = 2.5

func execute() -> void:
	if not consume_energy():
		if is_instance_valid(skill_owner):
			Global.spawn_floating_text(skill_owner.global_position, "No Energy!", Color.RED)
		return
	if not is_instance_valid(skill_owner):
		return

	var damage_amp: float = get_e_damage_amp(0.24, 0.34)
	var duration_amp: float = get_e_duration_amp(0.34)
	var lane_len: float = blind_radius * (1.0 + (duration_amp - 1.0) * 0.38)
	var lane_width: float = blind_radius * (0.34 if not is_f_window_active() else 0.42)
	var front_damage: int = max(1, int(round(36.0 * damage_amp)))
	var rear_damage: int = max(1, int(round(float(front_damage) * (0.72 if not is_f_window_active() else 0.94))))
	var final_blind: float = blind_duration * duration_amp
	var aim_dir: Vector2 = _get_aim_direction()
	var center: Vector2 = skill_owner.global_position

	var front_hits: int = 0
	for enemy in _get_enemies_in_radius(center, lane_len):
		if not _is_in_lane(enemy.global_position, center, aim_dir, lane_len, lane_width):
			continue
		_apply_damage(enemy, front_damage)
		_apply_status(enemy, "silence", final_blind, 0.0, 1, 0.1)
		_apply_status(enemy, "slow", 1.0 * duration_amp, 0.28, 1, 0.1)
		_knock_enemy(enemy, center - aim_dir * 40.0, 180.0)
		front_hits += 1

	var rear_center: Vector2 = center - aim_dir * min(80.0, lane_len * 0.35)
	var timer: SceneTreeTimer = get_tree().create_timer(0.22 if not is_f_window_active() else 0.16)
	timer.timeout.connect(_on_rear_wave_timeout.bind(rear_center, aim_dir, lane_len * 0.78, lane_width * 0.9, rear_damage, duration_amp))

	spawn_skill_vfx(center, Color(0.92, 0.9, 0.78, 0.7), 0.78)
	if front_hits > 0:
		Global.spawn_floating_text(center, "HORN x%d" % front_hits, Color(0.95, 0.9, 0.75))
	else:
		Global.spawn_floating_text(center, "HORN", Color(0.95, 0.9, 0.75))
	Global.on_camera_shake.emit(8.6, 0.18)
	start_cooldown()

func _on_rear_wave_timeout(center: Vector2, aim_dir: Vector2, lane_len: float, lane_width: float, damage: int, duration_amp: float) -> void:
	var hit: int = 0
	for enemy in _get_enemies_in_radius(center, lane_len):
		if not _is_in_lane(enemy.global_position, center, -aim_dir, lane_len, lane_width):
			continue
		_apply_damage(enemy, damage)
		_apply_status(enemy, "slow", 1.2 * duration_amp, 0.34, 1, 0.1)
		_knock_enemy(enemy, center + aim_dir * 35.0, 220.0)
		hit += 1
	if hit > 0 and is_instance_valid(skill_owner):
		Global.spawn_floating_text(skill_owner.global_position, "AFTERSHOCK x%d" % hit, Color(1.0, 0.88, 0.65))

func _is_in_lane(point: Vector2, lane_center: Vector2, lane_dir: Vector2, lane_len: float, half_width: float) -> bool:
	var rel: Vector2 = point - lane_center
	var forward: float = rel.dot(lane_dir)
	if forward < -16.0 or forward > lane_len:
		return false
	var side: float = absf(rel.dot(lane_dir.orthogonal()))
	return side <= half_width

func _get_aim_direction() -> Vector2:
	if not is_instance_valid(skill_owner):
		return Vector2.RIGHT
	var dir: Vector2 = skill_owner.get_global_mouse_position() - skill_owner.global_position
	if dir.length_squared() <= 0.01:
		return Vector2.RIGHT
	return dir.normalized()

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
