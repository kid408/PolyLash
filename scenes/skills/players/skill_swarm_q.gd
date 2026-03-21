extends SkillQBase
class_name SkillSwarmQ

var beetle_damage: int = 32
var beetle_interval: float = 0.8
var beetle_duration: float = 5.5

var nest_spacing: float = 165.0
var nest_duration: float = 4.8
var nest_interval: float = 0.34
var nest_spawn_count: int = 1

var turret_damage: int = 18
var turret_count: int = 3
var turret_duration: float = 2.0

var brood_slow_value: float = 0.35
var brood_heal_duration: float = 2.0
var heal_value: int = 3
var command_pulse_count: int = 6
var command_interval: float = 0.24
var command_damage: int = 20
var brood_lance_step_distance: float = 52.0
var brood_lance_tick_interval: float = 0.05
var brood_lance_hit_radius: float = 54.0
var brood_lance_damage: int = 14
var brood_lance_push: float = 14.0
var brood_recall_delay: float = 0.2
var brood_recall_count: int = 5
var brood_recall_damage: int = 18
var brood_recall_pull: float = 18.0
var brood_reel_count: int = 5
var brood_reel_interval: float = 0.16
var brood_reel_damage: int = 18

const BROOD_META_CENTER: String = "swarm_brood_center"
const BROOD_META_RADIUS: String = "swarm_brood_radius"
const BROOD_META_EXPIRE_MSEC: String = "swarm_brood_expire_msec"

var _nest_points: Array[Vector2] = []

func _init() -> void:
	base_line_duration = 3.0
	q_asset_duration_open = 3.0
	q_asset_duration_closed = 2.0

func _enter_planning_mode() -> void:
	_nest_points.clear()
	super._enter_planning_mode()

func _spawn_line_effect(start: Vector2, end: Vector2) -> void:
	SkillEffectManager.create_debuff_zone({
		"start": start,
		"end": end,
		"width": 18.0,
		"duration": _get_line_duration(),
		"debuff_type": "slow",
		"debuff_value": brood_slow_value,
		"debuff_duration": 1.6,
		"tick_interval": 0.5,
		"color": Color(0.45, 0.38, 0.1, 0.24)
	})

	_launch_brood_lance(start, end)
	_spawn_nests_along_segment(start, end)

func _spawn_area_effect(polygon: PackedVector2Array) -> void:
	if polygon.size() < 3:
		return
	var center: Vector2 = _calculate_polygon_center(polygon)
	for i: int in range(turret_count):
		var angle: float = TAU * float(i) / float(max(turret_count, 1))
		var pos: Vector2 = center + Vector2.RIGHT.rotated(angle) * 55.0
		SkillEffectManager.create_summon({
			"position": pos,
			"summon_type": "turret",
			"duration": turret_duration,
			"damage": turret_damage,
			"attack_interval": 0.9,
			"attack_range": 220.0,
			"max_count": 6,
			"owner_skill_id": "skill_swarm_q",
			"color": Color(0.4, 0.3, 0.0)
		})

	SkillEffectManager.create_buff_zone({
		"polygon": polygon,
		"duration": brood_heal_duration,
		"buff_type": "heal",
		"buff_value": float(heal_value),
		"tick_interval": 0.6,
		"color": Color(0.5, 0.6, 0.2, 0.3)
	})

	SkillEffectManager.create_buff_zone({
		"polygon": polygon,
		"duration": brood_heal_duration,
		"buff_type": "attack_boost",
		"buff_value": 0.2,
		"tick_interval": 0.6,
		"color": Color(0.55, 0.48, 0.16, 0.18)
	})

	_spawn_command_pulses(polygon, center)
	_spawn_brood_reel(polygon)
	_cache_brood_window(polygon, brood_heal_duration)

func _launch_brood_lance(start: Vector2, finish: Vector2) -> void:
	var seg: Vector2 = finish - start
	var length: float = seg.length()
	if length <= 1.0:
		return
	var move_dir: Vector2 = seg / length
	var host: Node2D = Node2D.new()
	host.name = "SwarmBroodLanceHost"
	add_child(host)

	var step_total: int = int(max(2.0, ceil(length / max(12.0, brood_lance_step_distance))))
	var step_index: int = 0
	var timer: Timer = Timer.new()
	timer.wait_time = max(0.03, brood_lance_tick_interval)
	timer.one_shot = false
	host.add_child(timer)
	timer.timeout.connect(func() -> void:
		if not is_instance_valid(host):
			return
		if step_index > step_total:
			timer.stop()
			host.queue_free()
			_spawn_brood_recall(finish, start, move_dir)
			return
		_emit_brood_lance_tick(start, finish, step_index, step_total, move_dir)
		step_index += 1
	)
	timer.start()

func _spawn_brood_recall(from_pos: Vector2, to_pos: Vector2, move_dir: Vector2) -> void:
	var tree: SceneTree = get_tree()
	if tree == null:
		return
	tree.create_timer(max(0.05, brood_recall_delay)).timeout.connect(func() -> void:
		if not is_inside_tree():
			return
		var host: Node2D = Node2D.new()
		host.name = "SwarmBroodRecallHost"
		add_child(host)
		var pulse_total: int = int(max(1, brood_recall_count))
		var pulse_index: int = 0
		var timer: Timer = Timer.new()
		timer.wait_time = max(0.06, brood_lance_tick_interval * 1.6)
		timer.one_shot = false
		host.add_child(timer)
		timer.timeout.connect(func() -> void:
			if not is_instance_valid(host):
				return
			if pulse_index >= pulse_total:
				timer.stop()
				host.queue_free()
				return
			_emit_brood_recall_tick(from_pos, to_pos, pulse_index, pulse_total, move_dir)
			pulse_index += 1
		)
		timer.start()
	)

func _emit_brood_lance_tick(start: Vector2, finish: Vector2, index: int, total: int, move_dir: Vector2) -> void:
	var t: float = float(index) / float(max(1, total))
	var prev_t: float = float(max(0, index - 1)) / float(max(1, total))
	var current: Vector2 = start.lerp(finish, t)
	var previous: Vector2 = start.lerp(finish, prev_t)
	SkillEffectManager.create_line_effect({
		"start": previous,
		"end": current,
		"width": 12.0,
		"damage": 0,
		"damage_interval": 0.2,
		"duration": 0.12,
		"color": Color(0.72, 0.64, 0.3, 0.86)
	})
	_apply_radius_brood_damage(current, brood_lance_hit_radius, brood_lance_damage)
	_apply_direction_push(current, brood_lance_hit_radius * 1.18, move_dir, brood_lance_push)
	_spawn_beetle_at(current)

func _emit_brood_recall_tick(
	from_pos: Vector2,
	to_pos: Vector2,
	index: int,
	total: int,
	move_dir: Vector2
) -> void:
	var t: float = 0.0
	if total > 1:
		t = float(index) / float(total - 1)
	var center: Vector2 = from_pos.lerp(to_pos, t)
	var tangent: Vector2 = Vector2(-move_dir.y, move_dir.x)
	if tangent.length_squared() <= 0.001:
		tangent = Vector2.UP
	var start: Vector2 = center - tangent * 70.0
	var end: Vector2 = center + tangent * 70.0
	SkillEffectManager.create_line_effect({
		"start": start,
		"end": end,
		"width": 12.0,
		"damage": 0,
		"damage_interval": 0.2,
		"duration": 0.16,
		"color": Color(0.8, 0.72, 0.4, 0.9)
	})
	_apply_line_burst_damage(start, end, 11.0, brood_recall_damage)
	_apply_pull_to_point(center, brood_lance_hit_radius * 1.55, brood_recall_pull)

func _spawn_brood_reel(polygon: PackedVector2Array) -> void:
	var center: Vector2 = _calculate_polygon_center(polygon)
	var radius: float = _polygon_radius(polygon, center)
	var sweep_total: int = int(max(1, brood_reel_count))
	var sweep_index: int = 0
	var host: Node2D = Node2D.new()
	host.name = "SwarmBroodReelHost"
	add_child(host)

	var timer: Timer = Timer.new()
	timer.wait_time = max(0.08, brood_reel_interval)
	timer.one_shot = false
	host.add_child(timer)
	timer.timeout.connect(func() -> void:
		if not is_instance_valid(host):
			return
		if sweep_index >= sweep_total:
			timer.stop()
			host.queue_free()
			return
		_emit_brood_reel(center, radius, sweep_index, sweep_total)
		sweep_index += 1
	)
	timer.start()

func _emit_brood_reel(center: Vector2, radius: float, index: int, total: int) -> void:
	var angle: float = TAU * float(index) / float(max(1, total))
	var dir: Vector2 = Vector2.RIGHT.rotated(angle)
	var start: Vector2 = center + dir * radius * 1.3
	var end: Vector2 = center - dir * radius * 0.08
	SkillEffectManager.create_line_effect({
		"start": start,
		"end": end,
		"width": 13.0,
		"damage": 0,
		"damage_interval": 0.2,
		"duration": 0.18,
		"color": Color(0.76, 0.68, 0.36, 0.88)
	})
	_apply_line_burst_damage(start, end, 11.0, brood_reel_damage)
	_apply_pull_to_point(center, radius * 1.02, brood_recall_pull * 0.55)

func _spawn_nests_along_segment(start: Vector2, end: Vector2) -> void:
	var seg: Vector2 = end - start
	var length: float = seg.length()
	if length <= 1.0:
		_deploy_nest_if_needed(start)
		return
	var dir: Vector2 = seg / length
	var spacing: float = float(max(60.0, nest_spacing))
	var cursor: float = 0.0
	while cursor <= length:
		_deploy_nest_if_needed(start + dir * cursor)
		cursor += spacing
	if fmod(length, spacing) > 20.0:
		_deploy_nest_if_needed(end)

func _deploy_nest_if_needed(pos: Vector2) -> void:
	if _nest_points.is_empty():
		_nest_points.append(pos)
		_spawn_nest(pos)
		return
	var last_pos: Vector2 = _nest_points[_nest_points.size() - 1]
	if last_pos.distance_to(pos) < nest_spacing:
		return
	_nest_points.append(pos)
	_spawn_nest(pos)

func _spawn_nest(pos: Vector2) -> void:
	var nest: Node2D = Node2D.new()
	nest.name = "SwarmNest"
	nest.global_position = pos
	add_child(nest)
	nest.add_to_group("player_skill_effects")

	var elapsed: float = 0.0
	var timer: Timer = Timer.new()
	timer.wait_time = float(max(0.08, nest_interval))
	timer.one_shot = false
	nest.add_child(timer)
	timer.timeout.connect(func() -> void:
		if not is_instance_valid(nest):
			return
		elapsed += timer.wait_time
		if elapsed >= nest_duration:
			timer.stop()
			nest.queue_free()
			return
		for i: int in range(nest_spawn_count):
			_spawn_beetle_at(nest.global_position)
	)
	timer.start()

	spawn_skill_vfx(pos, Color(0.56, 0.46, 0.16, 0.74), 0.28)

func _spawn_command_pulses(polygon: PackedVector2Array, center: Vector2) -> void:
	var radius: float = _polygon_radius(polygon, center)
	var pulse_total: int = int(max(1, command_pulse_count))
	var pulse_index: int = 0
	var host: Node2D = Node2D.new()
	host.name = "SwarmCommandPulses"
	add_child(host)

	_emit_command_pulse(center, radius, pulse_index)
	pulse_index += 1

	var timer: Timer = Timer.new()
	timer.wait_time = float(max(0.08, command_interval))
	timer.one_shot = false
	host.add_child(timer)
	timer.timeout.connect(func() -> void:
		if not is_instance_valid(host):
			return
		if pulse_index >= pulse_total:
			timer.stop()
			host.queue_free()
			return
		_emit_command_pulse(center, radius, pulse_index)
		pulse_index += 1
	)
	timer.start()

func _emit_command_pulse(center: Vector2, radius: float, index: int) -> void:
	var target: Node2D = _find_nearest_enemy(center, radius + 120.0)
	if target == null:
		return
	var angle: float = TAU * float(index) / float(max(1, command_pulse_count))
	var origin: Vector2 = center + Vector2.RIGHT.rotated(angle) * (radius + 64.0)
	SkillEffectManager.create_line_effect({
		"start": origin,
		"end": target.global_position,
		"width": 10.0,
		"damage": 0,
		"damage_interval": 0.2,
		"duration": 0.18,
		"color": Color(0.62, 0.54, 0.2, 0.88)
	})
	_apply_damage(target, command_damage)
	_apply_status(target, "slow", 0.9, brood_slow_value, 1, 0.1)

func _apply_line_burst_damage(start: Vector2, end: Vector2, hit_radius: float, damage: int) -> void:
	var enemies: Array = get_tree().get_nodes_in_group("enemies")
	for enemy_obj: Variant in enemies:
		if enemy_obj == null or not is_instance_valid(enemy_obj):
			continue
		if not (enemy_obj is Node2D):
			continue
		var enemy: Node2D = enemy_obj
		var closest: Vector2 = Geometry2D.get_closest_point_to_segment(enemy.global_position, start, end)
		if enemy.global_position.distance_to(closest) > hit_radius:
			continue
		_apply_damage(enemy, damage)
		_apply_status(enemy, "slow", 0.9, brood_slow_value, 1, 0.1)

func _apply_radius_brood_damage(center: Vector2, radius: float, damage: int) -> void:
	var enemies: Array = get_tree().get_nodes_in_group("enemies")
	for enemy_obj: Variant in enemies:
		if enemy_obj == null or not is_instance_valid(enemy_obj):
			continue
		if not (enemy_obj is Node2D):
			continue
		var enemy: Node2D = enemy_obj
		if enemy.global_position.distance_to(center) > radius:
			continue
		_apply_damage(enemy, damage)
		_apply_status(enemy, "slow", 0.9, brood_slow_value, 1, 0.1)

func _apply_direction_push(center: Vector2, radius: float, dir: Vector2, force: float) -> void:
	var safe_dir: Vector2 = dir.normalized()
	if safe_dir.length_squared() <= 0.0001:
		return
	var enemies: Array = get_tree().get_nodes_in_group("enemies")
	for enemy_obj: Variant in enemies:
		if enemy_obj == null or not is_instance_valid(enemy_obj):
			continue
		if not (enemy_obj is Node2D):
			continue
		var enemy: Node2D = enemy_obj
		if enemy.global_position.distance_to(center) > radius:
			continue
		enemy.global_position += safe_dir * force

func _apply_pull_to_point(center: Vector2, radius: float, force: float) -> void:
	var enemies: Array = get_tree().get_nodes_in_group("enemies")
	for enemy_obj: Variant in enemies:
		if enemy_obj == null or not is_instance_valid(enemy_obj):
			continue
		if not (enemy_obj is Node2D):
			continue
		var enemy: Node2D = enemy_obj
		var dist: float = enemy.global_position.distance_to(center)
		if dist > radius:
			continue
		var pull_dir: Vector2 = (center - enemy.global_position).normalized()
		enemy.global_position += pull_dir * force

func _cache_brood_window(polygon: PackedVector2Array, duration: float) -> void:
	if not is_instance_valid(skill_owner):
		return
	var center: Vector2 = _calculate_polygon_center(polygon)
	var radius: float = _polygon_radius(polygon, center)
	var expire_msec: int = Time.get_ticks_msec() + int(round(float(max(0.2, duration)) * 1000.0))
	skill_owner.set_meta(BROOD_META_CENTER, center)
	skill_owner.set_meta(BROOD_META_RADIUS, radius)
	skill_owner.set_meta(BROOD_META_EXPIRE_MSEC, expire_msec)

func _polygon_radius(polygon: PackedVector2Array, center: Vector2) -> float:
	var radius: float = 0.0
	for point: Vector2 in polygon:
		radius = float(max(radius, center.distance_to(point)))
	return float(max(18.0, radius))

func _spawn_beetle_at(pos: Vector2) -> void:
	SkillEffectManager.create_summon({
		"position": pos,
		"summon_type": "beetle",
		"duration": beetle_duration,
		"damage": beetle_damage,
		"attack_interval": 0.45,
		"attack_range": 90.0,
		"max_count": 12,
		"owner_skill_id": "skill_swarm_q",
		"color": Color(0.5, 0.4, 0.1)
	})

func _find_nearest_enemy(center: Vector2, range_radius: float) -> Node2D:
	var enemies: Array = get_tree().get_nodes_in_group("enemies")
	var best_enemy: Node2D = null
	var best_dist: float = range_radius + 0.001
	for enemy_obj: Variant in enemies:
		if enemy_obj == null or not is_instance_valid(enemy_obj):
			continue
		if not (enemy_obj is Node2D):
			continue
		var enemy: Node2D = enemy_obj
		var dist: float = enemy.global_position.distance_to(center)
		if dist > range_radius:
			continue
		if dist < best_dist:
			best_dist = dist
			best_enemy = enemy
	return best_enemy

func _apply_damage(enemy: Node2D, amount: int) -> void:
	if not enemy.has_node("HealthComponent"):
		return
	var hc: Node = enemy.get_node("HealthComponent")
	if hc != null and hc.has_method("take_damage"):
		hc.call("take_damage", max(1, amount))

func _apply_status(enemy: Node2D, status_name: String, duration: float, value: float, stacks: int = 1, tick_interval: float = 0.6) -> void:
	if enemy.has_method("apply_status"):
		var safe_duration: float = float(max(0.1, duration))
		var safe_stacks: int = int(max(1, stacks))
		var safe_tick_interval: float = float(max(0.05, tick_interval))
		enemy.call("apply_status", status_name, safe_duration, value, safe_stacks, safe_tick_interval)

func _get_line_color() -> Color:
	return Color(0.5, 0.4, 0.1, 1.0)

func _get_closure_color() -> Color:
	return Color(0.4, 0.3, 0.0, 1.0)

