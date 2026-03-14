extends SkillDrawingBase
class_name SkillJailerQ

var wall_contact_damage: int = 22
var wall_width: float = 16.0
var wall_duration: float = 6.5
var prison_slow_value: float = 0.58
var prison_fear_duration: float = 0.6
var shackle_spacing: float = 170.0
var shackle_duration: float = 4.8
var shackle_check_interval: float = 0.2
var shackle_bind_radius: float = 128.0
var shackle_sense_radius: float = 170.0
var shackle_tick_damage: int = 9
var lockdown_sweep_count: int = 6
var lockdown_sweep_interval: float = 0.24
var lockdown_sweep_damage: int = 16
var lockdown_sweep_width: float = 24.0
var shackle_lance_step_distance: float = 50.0
var shackle_lance_tick_interval: float = 0.05
var shackle_lance_hit_radius: float = 54.0
var shackle_lance_damage: int = 16
var shackle_lance_push: float = 18.0
var shackle_recall_delay: float = 0.2
var shackle_recall_count: int = 5
var shackle_recall_damage: int = 20
var shackle_recall_pull: float = 30.0
var lockdown_reel_count: int = 5
var lockdown_reel_interval: float = 0.16
var lockdown_reel_damage: int = 20

const PRISON_META_CENTER: String = "jailer_prison_center"
const PRISON_META_RADIUS: String = "jailer_prison_radius"
const PRISON_META_EXPIRE_MSEC: String = "jailer_prison_expire_msec"

var _shackle_points: Array[Vector2] = []

func _enter_planning_mode() -> void:
	_shackle_points.clear()
	super._enter_planning_mode()

func _spawn_line_effect(start: Vector2, end: Vector2) -> void:
	SkillEffectManager.create_wall_effect({
		"start": start,
		"end": end,
		"width": wall_width,
		"duration": _get_line_duration(),
		"block_enemies": true,
		"block_bullets": false,
		"contact_damage": wall_contact_damage,
		"contact_interval": 0.42,
		"color": Color(0.92, 0.8, 0.2, 0.75)
	})

	_launch_shackle_lance(start, end)
	_deploy_shackle_if_needed(start)
	_deploy_shackle_if_needed(end)

func _spawn_area_effect(polygon: PackedVector2Array) -> void:
	var point_count: int = polygon.size()
	if point_count < 3:
		return

	for i: int in range(point_count):
		var p0: Vector2 = polygon[i]
		var p1: Vector2 = polygon[(i + 1) % point_count]
		SkillEffectManager.create_wall_effect({
			"start": p0,
			"end": p1,
			"width": wall_width,
			"duration": wall_duration,
			"block_enemies": true,
			"block_bullets": false,
			"contact_damage": wall_contact_damage,
			"contact_interval": 0.42,
			"color": Color(0.92, 0.8, 0.2, 0.72)
		})

	SkillEffectManager.create_debuff_zone({
		"polygon": polygon,
		"duration": wall_duration,
		"debuff_type": "slow",
		"debuff_value": prison_slow_value,
		"debuff_duration": 1.8,
		"tick_interval": 0.45,
		"color": Color(0.88, 0.75, 0.16, 0.22)
	})

	SkillEffectManager.create_debuff_zone({
		"polygon": polygon,
		"duration": wall_duration,
		"debuff_type": "fear",
		"debuff_value": 1.0,
		"debuff_duration": prison_fear_duration,
		"tick_interval": 1.2,
		"color": Color(0.82, 0.65, 0.12, 0.18)
	})

	_spawn_lockdown_sweeps(polygon)
	_spawn_lockdown_reel(polygon)
	_cache_prison_window(polygon, wall_duration)

func _launch_shackle_lance(start: Vector2, finish: Vector2) -> void:
	var seg: Vector2 = finish - start
	var length: float = seg.length()
	if length <= 1.0:
		return
	var move_dir: Vector2 = seg / length
	var host: Node2D = Node2D.new()
	host.name = "JailerShackleLanceHost"
	add_child(host)

	var step_total: int = int(max(2.0, ceil(length / max(12.0, shackle_lance_step_distance))))
	var step_index: int = 0
	var timer: Timer = Timer.new()
	timer.wait_time = max(0.03, shackle_lance_tick_interval)
	timer.one_shot = false
	host.add_child(timer)
	timer.timeout.connect(func() -> void:
		if not is_instance_valid(host):
			return
		if step_index > step_total:
			timer.stop()
			host.queue_free()
			_spawn_shackle_recall(finish, start, move_dir)
			return
		_emit_shackle_lance_tick(start, finish, step_index, step_total, move_dir)
		step_index += 1
	)
	timer.start()

func _spawn_shackle_recall(from_pos: Vector2, to_pos: Vector2, move_dir: Vector2) -> void:
	var tree: SceneTree = get_tree()
	if tree == null:
		return
	tree.create_timer(max(0.05, shackle_recall_delay)).timeout.connect(func() -> void:
		if not is_inside_tree():
			return
		var host: Node2D = Node2D.new()
		host.name = "JailerShackleRecallHost"
		add_child(host)
		var pulse_total: int = int(max(1, shackle_recall_count))
		var pulse_index: int = 0
		var timer: Timer = Timer.new()
		timer.wait_time = max(0.06, shackle_lance_tick_interval * 1.6)
		timer.one_shot = false
		host.add_child(timer)
		timer.timeout.connect(func() -> void:
			if not is_instance_valid(host):
				return
			if pulse_index >= pulse_total:
				timer.stop()
				host.queue_free()
				return
			_emit_shackle_recall_tick(from_pos, to_pos, pulse_index, pulse_total, move_dir)
			pulse_index += 1
		)
		timer.start()
	)

func _emit_shackle_lance_tick(start: Vector2, finish: Vector2, index: int, total: int, move_dir: Vector2) -> void:
	var t: float = float(index) / float(max(1, total))
	var prev_t: float = float(max(0, index - 1)) / float(max(1, total))
	var current: Vector2 = start.lerp(finish, t)
	var previous: Vector2 = start.lerp(finish, prev_t)
	SkillEffectManager.create_line_effect({
		"start": previous,
		"end": current,
		"width": 13.0,
		"damage": 0,
		"damage_interval": 0.2,
		"duration": 0.12,
		"color": Color(1.0, 0.9, 0.4, 0.9)
	})
	_apply_radius_damage_and_bind(current, shackle_lance_hit_radius, shackle_lance_damage)
	_apply_direction_push(current, shackle_lance_hit_radius * 1.2, move_dir, shackle_lance_push)

func _emit_shackle_recall_tick(
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
	var start: Vector2 = center - tangent * 76.0
	var end: Vector2 = center + tangent * 76.0
	SkillEffectManager.create_line_effect({
		"start": start,
		"end": end,
		"width": 13.0,
		"damage": 0,
		"damage_interval": 0.2,
		"duration": 0.16,
		"color": Color(1.0, 0.95, 0.55, 0.92)
	})
	_apply_line_burst_damage(start, end, 12.0, shackle_recall_damage)
	_apply_pull_to_point(center, shackle_lance_hit_radius * 1.7, shackle_recall_pull)

func _spawn_lockdown_reel(polygon: PackedVector2Array) -> void:
	var center: Vector2 = _polygon_center(polygon)
	var radius: float = _polygon_radius(polygon, center)
	var sweep_total: int = int(max(1, lockdown_reel_count))
	var sweep_index: int = 0
	var host: Node2D = Node2D.new()
	host.name = "JailerLockdownReelHost"
	add_child(host)

	var timer: Timer = Timer.new()
	timer.wait_time = max(0.08, lockdown_reel_interval)
	timer.one_shot = false
	host.add_child(timer)
	timer.timeout.connect(func() -> void:
		if not is_instance_valid(host):
			return
		if sweep_index >= sweep_total:
			timer.stop()
			host.queue_free()
			return
		_emit_lockdown_reel(center, radius, sweep_index, sweep_total)
		sweep_index += 1
	)
	timer.start()

func _emit_lockdown_reel(center: Vector2, radius: float, index: int, total: int) -> void:
	var angle: float = TAU * float(index) / float(max(1, total))
	var dir: Vector2 = Vector2.RIGHT.rotated(angle)
	var start: Vector2 = center + dir * radius * 1.36
	var end: Vector2 = center - dir * radius * 0.05
	SkillEffectManager.create_line_effect({
		"start": start,
		"end": end,
		"width": lockdown_sweep_width * 0.75,
		"damage": 0,
		"damage_interval": 0.2,
		"duration": 0.18,
		"color": Color(1.0, 0.92, 0.52, 0.9)
	})
	_apply_line_burst_damage(start, end, lockdown_sweep_width * 0.48, lockdown_reel_damage)
	_apply_pull_to_point(center, radius * 1.04, shackle_recall_pull * 0.62)

func _deploy_shackle_if_needed(pos: Vector2) -> void:
	if _shackle_points.is_empty():
		_shackle_points.append(pos)
		_spawn_shackle_post(pos)
		return
	var last_pos: Vector2 = _shackle_points[_shackle_points.size() - 1]
	if last_pos.distance_to(pos) < shackle_spacing:
		return
	_shackle_points.append(pos)
	_spawn_shackle_post(pos)

func _spawn_shackle_post(pos: Vector2) -> void:
	var post: Node2D = Node2D.new()
	post.name = "JailerShacklePost"
	post.global_position = pos
	add_child(post)
	post.add_to_group("player_skill_effects")

	var elapsed: float = 0.0
	var timer: Timer = Timer.new()
	timer.wait_time = max(0.08, shackle_check_interval)
	timer.one_shot = false
	post.add_child(timer)
	timer.timeout.connect(func() -> void:
		if not is_instance_valid(post):
			return
		elapsed += timer.wait_time
		if elapsed >= shackle_duration:
			timer.stop()
			post.queue_free()
			return
		_process_shackle_post(post.global_position)
	)
	timer.start()

	spawn_skill_vfx(pos, Color(0.96, 0.82, 0.3, 0.76), 0.34)

func _process_shackle_post(center: Vector2) -> void:
	var enemies: Array = get_tree().get_nodes_in_group("enemies")
	for enemy_obj: Variant in enemies:
		if enemy_obj == null or not is_instance_valid(enemy_obj):
			continue
		if not (enemy_obj is Node2D):
			continue
		var enemy: Node2D = enemy_obj
		var dist: float = enemy.global_position.distance_to(center)
		if dist > shackle_sense_radius:
			continue
		_apply_damage(enemy, shackle_tick_damage)
		_apply_status(enemy, "slow", 0.9, float(min(0.9, prison_slow_value + 0.1)), 1, 0.1)
		if dist <= shackle_bind_radius:
			continue
		var dir: Vector2 = (enemy.global_position - center).normalized()
		enemy.global_position = center + dir * shackle_bind_radius
		_apply_status(enemy, "fear", prison_fear_duration * 0.45, 1.0, 1, 0.2)

func _spawn_lockdown_sweeps(polygon: PackedVector2Array) -> void:
	var center: Vector2 = _polygon_center(polygon)
	var radius: float = _polygon_radius(polygon, center)
	var sweep_total: int = int(max(1, lockdown_sweep_count))
	var sweep_index: int = 0
	var host: Node2D = Node2D.new()
	host.name = "JailerLockdownSweeps"
	add_child(host)

	_emit_lockdown_sweep(center, radius, sweep_index, sweep_total)
	sweep_index += 1

	var timer: Timer = Timer.new()
	timer.wait_time = max(0.08, lockdown_sweep_interval)
	timer.one_shot = false
	host.add_child(timer)
	timer.timeout.connect(func() -> void:
		if not is_instance_valid(host):
			return
		if sweep_index >= sweep_total:
			timer.stop()
			host.queue_free()
			return
		_emit_lockdown_sweep(center, radius, sweep_index, sweep_total)
		sweep_index += 1
	)
	timer.start()

func _emit_lockdown_sweep(center: Vector2, radius: float, index: int, total: int) -> void:
	var angle: float = TAU * float(index) / float(max(1, total))
	var dir: Vector2 = Vector2.RIGHT.rotated(angle)
	var start: Vector2 = center + dir * (radius + 70.0)
	var end: Vector2 = center - dir * (radius + 24.0)
	SkillEffectManager.create_line_effect({
		"start": start,
		"end": end,
		"width": lockdown_sweep_width,
		"damage": 0,
		"damage_interval": 0.2,
		"duration": 0.2,
		"color": Color(0.95, 0.82, 0.32, 0.9)
	})
	_apply_line_burst_damage(start, end, lockdown_sweep_width * 0.52, lockdown_sweep_damage)

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
		_apply_status(enemy, "slow", 1.0, float(min(0.92, prison_slow_value + 0.08)), 1, 0.1)
		_apply_status(enemy, "fear", prison_fear_duration, 1.0, 1, 0.2)

func _apply_radius_damage_and_bind(center: Vector2, radius: float, damage: int) -> void:
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
		_apply_damage(enemy, damage)
		_apply_status(enemy, "slow", 0.9, float(min(0.9, prison_slow_value + 0.08)), 1, 0.1)
		if dist > shackle_bind_radius * 0.7:
			var dir: Vector2 = (enemy.global_position - center).normalized()
			enemy.global_position = center + dir * shackle_bind_radius * 0.7

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

func _cache_prison_window(polygon: PackedVector2Array, duration: float) -> void:
	if not is_instance_valid(skill_owner):
		return
	var center: Vector2 = _polygon_center(polygon)
	var radius: float = _polygon_radius(polygon, center)
	var expire_msec: int = Time.get_ticks_msec() + int(round(max(0.2, duration) * 1000.0))
	skill_owner.set_meta(PRISON_META_CENTER, center)
	skill_owner.set_meta(PRISON_META_RADIUS, radius)
	skill_owner.set_meta(PRISON_META_EXPIRE_MSEC, expire_msec)

func _polygon_center(polygon: PackedVector2Array) -> Vector2:
	if polygon.is_empty():
		return Vector2.ZERO
	var center: Vector2 = Vector2.ZERO
	for point: Vector2 in polygon:
		center += point
	return center / float(polygon.size())

func _polygon_radius(polygon: PackedVector2Array, center: Vector2) -> float:
	var radius: float = 0.0
	for point: Vector2 in polygon:
		radius = float(max(radius, center.distance_to(point)))
	return float(max(20.0, radius))

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
	return Color(0.92, 0.8, 0.2, 1.0)

func _get_closure_color() -> Color:
	return Color(0.9, 0.8, 0.2, 1.0)
