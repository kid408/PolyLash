extends SkillQBase
class_name SkillBreachmarshalQ

var rail_width: float = 32.0
var dash_damage: int = 48
var back_damage: int = 34
var dash_hit_radius: float = 18.0

var signal_spacing: float = 180.0
var signal_duration: float = 4.8
var signal_interval: float = 0.38
var signal_radius: float = 170.0
var signal_tick_damage: int = 10

var yard_duration: float = 5.6
var yard_sweep_count: int = 6
var yard_sweep_interval: float = 0.26
var yard_sweep_damage: int = 28
var yard_fear_duration: float = 0.65
var engine_step_distance: float = 52.0
var engine_tick_interval: float = 0.05
var engine_hit_radius: float = 56.0
var engine_front_damage: int = 20
var engine_push_force: float = 28.0
var engine_recall_delay: float = 0.2
var engine_recall_count: int = 5
var engine_recall_damage: int = 22
var engine_recall_pull: float = 26.0
var closure_switch_count: int = 6
var closure_switch_interval: float = 0.16
var closure_switch_damage: int = 24

const RAIL_META_CENTER: String = "breachmarshal_rail_center"
const RAIL_META_RADIUS: String = "breachmarshal_rail_radius"
const RAIL_META_EXPIRE_MSEC: String = "breachmarshal_rail_expire_msec"

var _signal_points: Array[Vector2] = []

func _enter_planning_mode() -> void:
	_signal_points.clear()
	super._enter_planning_mode()

func _spawn_line_effect(start: Vector2, end: Vector2) -> void:
	_spawn_breachmarshal_pass(start, end, 0.12, rail_width, dash_damage)
	_spawn_breachmarshal_pass(end, start, 0.44, rail_width * 0.82, back_damage)
	_launch_engine_probe(start, end)
	_spawn_signals_along_segment(start, end)

func _spawn_area_effect(polygon: PackedVector2Array) -> void:
	if polygon.size() < 3:
		return

	SkillEffectManager.create_debuff_zone({
		"polygon": polygon,
		"duration": yard_duration,
		"debuff_type": "fear",
		"debuff_value": 1.0,
		"debuff_duration": yard_fear_duration,
		"tick_interval": 0.95,
		"color": Color(0.46, 0.46, 0.6, 0.22)
	})

	_spawn_yard_crossing_passes(polygon)
	_spawn_switchback_reflux(polygon)
	_cache_rail_window(polygon, yard_duration)

func _launch_engine_probe(start: Vector2, finish: Vector2) -> void:
	var seg: Vector2 = finish - start
	var length: float = seg.length()
	if length <= 1.0:
		return
	var move_dir: Vector2 = seg / length
	var host: Node2D = Node2D.new()
	host.name = "TrainEngineProbeHost"
	add_child(host)

	var step_total: int = int(max(2.0, ceil(length / max(12.0, engine_step_distance))))
	var step_index: int = 0
	var timer: Timer = Timer.new()
	timer.wait_time = max(0.03, engine_tick_interval)
	timer.one_shot = false
	host.add_child(timer)
	timer.timeout.connect(func() -> void:
		if not is_instance_valid(host):
			return
		if step_index > step_total:
			timer.stop()
			host.queue_free()
			_spawn_engine_recall(finish, start, move_dir)
			return
		_emit_engine_probe_tick(start, finish, step_index, step_total, move_dir)
		step_index += 1
	)
	timer.start()

func _spawn_engine_recall(from_pos: Vector2, to_pos: Vector2, move_dir: Vector2) -> void:
	var tree: SceneTree = get_tree()
	if tree == null:
		return
	tree.create_timer(max(0.05, engine_recall_delay)).timeout.connect(func() -> void:
		if not is_inside_tree():
			return
		var host: Node2D = Node2D.new()
		host.name = "TrainEngineRecallHost"
		add_child(host)
		var pulse_total: int = int(max(1, engine_recall_count))
		var pulse_index: int = 0
		var timer: Timer = Timer.new()
		timer.wait_time = max(0.06, engine_tick_interval * 1.6)
		timer.one_shot = false
		host.add_child(timer)
		timer.timeout.connect(func() -> void:
			if not is_instance_valid(host):
				return
			if pulse_index >= pulse_total:
				timer.stop()
				host.queue_free()
				return
			_emit_engine_recall_tick(from_pos, to_pos, pulse_index, pulse_total, move_dir)
			pulse_index += 1
		)
		timer.start()
	)

func _emit_engine_probe_tick(start: Vector2, finish: Vector2, index: int, total: int, move_dir: Vector2) -> void:
	var t: float = float(index) / float(max(1, total))
	var prev_t: float = float(max(0, index - 1)) / float(max(1, total))
	var current: Vector2 = start.lerp(finish, t)
	var previous: Vector2 = start.lerp(finish, prev_t)
	SkillEffectManager.create_line_effect({
		"start": previous,
		"end": current,
		"width": 14.0,
		"damage": 0,
		"damage_interval": 0.2,
		"duration": 0.12,
		"color": Color(0.9, 0.9, 1.0, 0.94)
	})
	_apply_radius_damage_and_fear(current, engine_hit_radius, engine_front_damage)
	_apply_direction_push(current, engine_hit_radius * 1.2, move_dir, engine_push_force)

func _emit_engine_recall_tick(
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
		"width": 12.0,
		"damage": 0,
		"damage_interval": 0.2,
		"duration": 0.16,
		"color": Color(1.0, 0.96, 0.92, 0.9)
	})
	_apply_line_burst_damage(start, end, 12.0, engine_recall_damage)
	_apply_pull_to_point(center, engine_hit_radius * 1.6, engine_recall_pull)

func _spawn_switchback_reflux(polygon: PackedVector2Array) -> void:
	var center: Vector2 = _calculate_polygon_center(polygon)
	var radius: float = _polygon_radius(polygon, center)
	var sweep_total: int = int(max(1, closure_switch_count))
	var sweep_index: int = 0
	var host: Node2D = Node2D.new()
	host.name = "TrainSwitchbackRefluxHost"
	add_child(host)

	var timer: Timer = Timer.new()
	timer.wait_time = max(0.08, closure_switch_interval)
	timer.one_shot = false
	host.add_child(timer)
	timer.timeout.connect(func() -> void:
		if not is_instance_valid(host):
			return
		if sweep_index >= sweep_total:
			timer.stop()
			host.queue_free()
			return
		_emit_switchback_reflux(center, radius, sweep_index, sweep_total)
		sweep_index += 1
	)
	timer.start()

func _emit_switchback_reflux(center: Vector2, radius: float, index: int, total: int) -> void:
	var angle: float = TAU * float(index) / float(max(1, total))
	var facing: Vector2 = Vector2.RIGHT.rotated(angle)
	var tangent: Vector2 = Vector2(-facing.y, facing.x)
	var center_a: Vector2 = center + facing * radius * 0.98
	var center_b: Vector2 = center - facing * radius * 0.98
	var start: Vector2 = center_a - tangent * radius * 0.36
	var end: Vector2 = center_b + tangent * radius * 0.36
	SkillEffectManager.create_line_effect({
		"start": start,
		"end": end,
		"width": rail_width * 0.72,
		"damage": 0,
		"damage_interval": 0.2,
		"duration": 0.2,
		"color": Color(0.9, 0.88, 0.96, 0.9)
	})
	_apply_line_burst_damage(start, end, 14.0, closure_switch_damage)
	_apply_pull_to_point(center, radius * 1.05, engine_recall_pull * 0.6)

func _spawn_breachmarshal_pass(start: Vector2, end: Vector2, delay_sec: float, width: float, damage: int) -> void:
	var tree: SceneTree = get_tree()
	if tree == null:
		return
	var timer: SceneTreeTimer = tree.create_timer(float(max(0.0, delay_sec)))
	timer.timeout.connect(func() -> void:
		SkillEffectManager.create_line_effect({
			"start": start,
			"end": end,
			"width": width,
			"damage": 0,
			"damage_interval": 0.2,
			"duration": 0.22,
			"color": Color(0.72, 0.72, 0.84, 0.9)
		})
		_apply_line_burst_damage(start, end, dash_hit_radius, damage)
		_apply_line_push(start, end, 36.0)
	)

func _spawn_signals_along_segment(start: Vector2, end: Vector2) -> void:
	var seg: Vector2 = end - start
	var length: float = seg.length()
	if length <= 1.0:
		_deploy_signal_if_needed(start)
		return
	var dir: Vector2 = seg / length
	var spacing: float = float(max(64.0, signal_spacing))
	var cursor: float = 0.0
	while cursor <= length:
		_deploy_signal_if_needed(start + dir * cursor)
		cursor += spacing
	if fmod(length, spacing) > 20.0:
		_deploy_signal_if_needed(end)

func _deploy_signal_if_needed(pos: Vector2) -> void:
	if _signal_points.is_empty():
		_signal_points.append(pos)
		_spawn_signal_post(pos)
		return
	var last_pos: Vector2 = _signal_points[_signal_points.size() - 1]
	if last_pos.distance_to(pos) < signal_spacing:
		return
	_signal_points.append(pos)
	_spawn_signal_post(pos)

func _spawn_signal_post(pos: Vector2) -> void:
	var post: Node2D = Node2D.new()
	post.name = "TrainSignalPost"
	post.global_position = pos
	add_child(post)
	post.add_to_group("player_skill_effects")

	var elapsed: float = 0.0
	var timer: Timer = Timer.new()
	timer.wait_time = float(max(0.08, signal_interval))
	timer.one_shot = false
	post.add_child(timer)
	timer.timeout.connect(func() -> void:
		if not is_instance_valid(post):
			return
		elapsed += timer.wait_time
		if elapsed >= signal_duration:
			timer.stop()
			post.queue_free()
			return
		_process_signal_tick(post.global_position)
	)
	timer.start()

	spawn_skill_vfx(pos, Color(0.76, 0.76, 0.9, 0.74), 0.3)

func _process_signal_tick(center: Vector2) -> void:
	var target: Node2D = _find_nearest_enemy(center, signal_radius)
	if target == null:
		return
	_apply_damage(target, signal_tick_damage)
	_apply_status(target, "fear", yard_fear_duration * 0.5, 1.0, 1, 0.2)
	_apply_status(target, "slow", 0.8, 0.45, 1, 0.1)

func _spawn_yard_crossing_passes(polygon: PackedVector2Array) -> void:
	var center: Vector2 = _calculate_polygon_center(polygon)
	var radius: float = _polygon_radius(polygon, center)
	var sweep_total: int = int(max(1, yard_sweep_count))
	var sweep_index: int = 0
	var host: Node2D = Node2D.new()
	host.name = "TrainYardCrossing"
	add_child(host)

	_emit_yard_pass(center, radius, sweep_index)
	sweep_index += 1

	var timer: Timer = Timer.new()
	timer.wait_time = float(max(0.08, yard_sweep_interval))
	timer.one_shot = false
	host.add_child(timer)
	timer.timeout.connect(func() -> void:
		if not is_instance_valid(host):
			return
		if sweep_index >= sweep_total:
			timer.stop()
			host.queue_free()
			return
		_emit_yard_pass(center, radius, sweep_index)
		sweep_index += 1
	)
	timer.start()

func _emit_yard_pass(center: Vector2, radius: float, index: int) -> void:
	var angle: float = TAU * float(index) / float(max(1, yard_sweep_count))
	var dir: Vector2 = Vector2.RIGHT.rotated(angle)
	var start: Vector2 = center + dir * (radius + 80.0)
	var end: Vector2 = center - dir * (radius + 32.0)
	SkillEffectManager.create_line_effect({
		"start": start,
		"end": end,
		"width": rail_width * 0.9,
		"damage": 0,
		"damage_interval": 0.2,
		"duration": 0.24,
		"color": Color(0.82, 0.82, 0.94, 0.88)
	})
	_apply_line_burst_damage(start, end, dash_hit_radius, yard_sweep_damage)
	_apply_line_push(start, end, 48.0)

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
		_apply_status(enemy, "fear", yard_fear_duration, 1.0, 1, 0.2)

func _apply_line_push(start: Vector2, end: Vector2, force: float) -> void:
	var dir: Vector2 = (end - start).normalized()
	if dir.length_squared() <= 0.0001:
		return
	var enemies: Array = get_tree().get_nodes_in_group("enemies")
	for enemy_obj: Variant in enemies:
		if enemy_obj == null or not is_instance_valid(enemy_obj):
			continue
		if not (enemy_obj is Node2D):
			continue
		var enemy: Node2D = enemy_obj
		var closest: Vector2 = Geometry2D.get_closest_point_to_segment(enemy.global_position, start, end)
		if enemy.global_position.distance_to(closest) > dash_hit_radius:
			continue
		enemy.global_position += dir * force

func _apply_radius_damage_and_fear(center: Vector2, radius: float, damage: int) -> void:
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
		_apply_status(enemy, "fear", yard_fear_duration * 0.8, 1.0, 1, 0.2)

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

func _cache_rail_window(polygon: PackedVector2Array, duration: float) -> void:
	if not is_instance_valid(skill_owner):
		return
	var center: Vector2 = _calculate_polygon_center(polygon)
	var radius: float = _polygon_radius(polygon, center)
	var expire_msec: int = Time.get_ticks_msec() + int(round(float(max(0.2, duration)) * 1000.0))
	skill_owner.set_meta(RAIL_META_CENTER, center)
	skill_owner.set_meta(RAIL_META_RADIUS, radius)
	skill_owner.set_meta(RAIL_META_EXPIRE_MSEC, expire_msec)

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
	return Color(0.6, 0.6, 0.7, 1.0)

func _get_closure_color() -> Color:
	return Color(0.5, 0.5, 0.6, 1.0)

func _build_q_asset_payload(
	is_closed_path: bool,
	segment_count: int,
	polygon_count: int,
	center: Vector2,
	radius: float
) -> Dictionary:
	var payload := super._build_q_asset_payload(is_closed_path, segment_count, polygon_count, center, radius)
	payload["points"] = path_points.duplicate()
	if path_points.size() >= 2:
		payload["path_start"] = path_points[0]
		payload["path_end"] = path_points[path_points.size() - 1]
	payload["rail_width"] = rail_width
	return payload

