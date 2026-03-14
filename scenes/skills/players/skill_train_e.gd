extends SkillBase
class_name SkillTrainE

var blind_radius: float = 200.0
var blind_duration: float = 2.5

const RAIL_META_CENTER: String = "train_rail_center"
const RAIL_META_RADIUS: String = "train_rail_radius"
const RAIL_META_EXPIRE_MSEC: String = "train_rail_expire_msec"

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

	var window_data: Array = _get_rail_window(center, lane_len)
	var synergy_used: bool = bool(window_data[0])
	if synergy_used and window_data.size() > 1 and window_data[1] is Vector2:
		center = window_data[1]
	if synergy_used and window_data.size() > 2:
		lane_len = max(lane_len, float(window_data[2]) * 0.95)
		lane_width *= 1.10
		front_damage = int(round(float(front_damage) * 1.12))
		rear_damage = int(round(float(rear_damage) * 1.16))

	var front_hits: int = 0
	for enemy: Node2D in _get_enemies_in_radius(center, lane_len):
		if not _is_in_lane(enemy.global_position, center, aim_dir, lane_len, lane_width):
			continue
		_apply_damage(enemy, front_damage)
		_apply_status(enemy, "silence", final_blind, 0.0, 1, 0.1)
		_apply_status(enemy, "slow", 1.0 * duration_amp, 0.28, 1, 0.1)
		if synergy_used:
			_apply_status(enemy, "marked", 1.2, 0.18, 1, 0.3)
		_knock_enemy(enemy, center - aim_dir * 40.0, 180.0)
		front_hits += 1

	var rear_center: Vector2 = center - aim_dir * min(80.0, lane_len * 0.35)
	var timer: SceneTreeTimer = get_tree().create_timer(0.22 if not is_f_window_active() else 0.16)
	timer.timeout.connect(_on_rear_wave_timeout.bind(rear_center, aim_dir, lane_len * 0.78, lane_width * 0.9, rear_damage, duration_amp, synergy_used))

	spawn_skill_vfx(center, Color(0.92, 0.9, 0.78, 0.7), 0.78)
	if front_hits > 0:
		Global.spawn_floating_text(center, "HORN x%d" % front_hits, Color(0.95, 0.9, 0.75))
	else:
		Global.spawn_floating_text(center, "HORN", Color(0.95, 0.9, 0.75))
	Global.on_camera_shake.emit(8.6, 0.18)
	start_cooldown()

func _on_rear_wave_timeout(center: Vector2, aim_dir: Vector2, lane_len: float, lane_width: float, damage: int, duration_amp: float, synergy_used: bool) -> void:
	var hit: int = 0
	for enemy: Node2D in _get_enemies_in_radius(center, lane_len):
		if not _is_in_lane(enemy.global_position, center, -aim_dir, lane_len, lane_width):
			continue
		_apply_damage(enemy, damage)
		_apply_status(enemy, "slow", 1.2 * duration_amp, 0.34, 1, 0.1)
		if synergy_used:
			_apply_status(enemy, "fear", 0.55, 1.0, 1, 0.2)
		_knock_enemy(enemy, center + aim_dir * 35.0, 220.0)
		hit += 1
	if hit > 0 and is_instance_valid(skill_owner):
		if synergy_used:
			_refund_q_cooldown(1.1)
		Global.spawn_floating_text(skill_owner.global_position, "AFTERSHOCK x%d" % hit, Color(1.0, 0.88, 0.65))

func _get_rail_window(default_center: Vector2, default_radius: float) -> Array:
	var data: Array = [false, default_center, default_radius]
	if not is_instance_valid(skill_owner):
		return data
	if not skill_owner.has_meta(RAIL_META_EXPIRE_MSEC):
		return data
	var expire_msec: int = int(skill_owner.get_meta(RAIL_META_EXPIRE_MSEC, 0))
	if Time.get_ticks_msec() > expire_msec:
		return data
	var center_val: Variant = skill_owner.get_meta(RAIL_META_CENTER, default_center)
	var radius_val: Variant = skill_owner.get_meta(RAIL_META_RADIUS, default_radius)
	if not (center_val is Vector2):
		return data
	data[0] = true
	data[1] = center_val
	data[2] = max(default_radius, float(radius_val))
	return data

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
