extends Node2D
class_name BloodTrailRuntime

const SAMPLE_INTERVAL: float = 10.0
const OPEN_FLY_DISTANCE: float = 260.0
const OPEN_FLY_SPEED: float = 1100.0
const OPEN_PUSH_RADIUS: float = 120.0
const OPEN_CONTACT_RADIUS: float = 80.0
const OPEN_FIRST_HIT_RATIO: float = 0.35
const OPEN_CONTACT_RATIO: float = 0.12
const OPEN_LAND_TICK_RATIO: float = 0.15
const OPEN_LAND_DURATION: float = 3.2
const OPEN_TETHER_RADIUS: float = 300.0
const OPEN_PUSH_SPEED: float = 1200.0
const OPEN_INWARD_SPEED: float = 180.0
const CLOSED_ROTATION_SPEED_DEG: float = 540.0
const CLOSED_CENTER_SPEED: float = 1400.0
const CLOSED_FLY_DAMAGE_RATIO: float = 0.18
const CLOSED_LAND_DAMAGE_RATIO: float = 0.45
const CLOSED_LAND_DISMEMBER_RATIO: float = 2.40
const CLOSED_LAND_DURATION: float = 6.7
const CLOSED_MIN_TETHER_RADIUS: float = 300.0
const DAMAGE_TICK_INTERVAL: float = 0.32
const EPSILON: float = 0.001

var shape_points: Array[Vector2] = []
var local_points: PackedVector2Array = PackedVector2Array()
var is_closed: bool = false
var fly_dir: Vector2 = Vector2.RIGHT
var player_ref: Node2D = null

var is_landed: bool = false
var is_runtime_active: bool = false
var target_pos: Vector2 = Vector2.ZERO
var speed: float = OPEN_FLY_SPEED

var chained_enemies: Array[WeakRef] = []
var chain_radius: float = OPEN_TETHER_RADIUS
var tick_timer: float = 0.0
var lifetime_timer: Timer = null

var visual_poly: Polygon2D = null
var visual_line: Line2D = null

var saw_rotation_speed: float = CLOSED_ROTATION_SPEED_DEG
var saw_push_radius: float = OPEN_PUSH_RADIUS
var saw_push_force_value: float = OPEN_PUSH_SPEED
var saw_damage_tick: int = 0
var saw_damage_open: int = 0
var saw_contact_interval: float = DAMAGE_TICK_INTERVAL
var saw_area_interval: float = DAMAGE_TICK_INTERVAL
var stake_impact_damage: int = 0
var chain_color: Color = Color(0.8, 0.2, 0.2, 0.8)
var saw_hit_radius: float = OPEN_CONTACT_RADIUS
var saw_fly_speed: float = OPEN_FLY_SPEED
var closure_duration: float = CLOSED_LAND_DURATION
var dismember_damage: int = 0

var _launch_origin: Vector2 = Vector2.ZERO
var _anchor_center: Vector2 = Vector2.ZERO
var _current_rotation: float = 0.0
var _flight_travelled: float = 0.0
var _flight_contact_timers: Dictionary = {}
var _flight_first_hit_ids: Dictionary = {}
var _influence_ids: Dictionary = {}
var _landing_damage_timers: Dictionary = {}
var _closed_flight_damage_timers: Dictionary = {}
var _chain_target_ids: Dictionary = {}
var _stake_transfer_centers: Dictionary = {}
var _closed_landing_burst_ids: Dictionary = {}
var _landing_capture_locked: bool = false
var _landing_duration: float = OPEN_LAND_DURATION

func setup(
	_points: Array[Vector2],
	_closed: bool,
	_dir: Vector2,
	_player: Node2D,
	_launch_distance: float = OPEN_FLY_DISTANCE,
	_chain_radius_override: float = -1.0
) -> void:
	shape_points = _points.duplicate()
	is_closed = _closed and shape_points.size() >= 3
	fly_dir = _dir.normalized()
	if fly_dir.length_squared() <= EPSILON:
		fly_dir = Vector2.RIGHT
	player_ref = _player

	add_to_group("projectiles")
	add_to_group("player_skill_effects")

	_read_owner_compatibility_values()

	_launch_origin = _get_player_origin()
	_anchor_center = _launch_origin
	target_pos = _launch_origin + fly_dir * max(1.0, _launch_distance)
	speed = saw_fly_speed
	_current_rotation = 0.0
	_flight_travelled = 0.0
	is_landed = false
	is_runtime_active = true
	_landing_capture_locked = not is_closed
	_landing_duration = closure_duration if is_closed else OPEN_LAND_DURATION
	chain_radius = _resolve_chain_radius(_chain_radius_override)

	_rebuild_local_points()
	_build_visuals()
	_apply_runtime_transform()
	_setup_lifetime_timer()

func _read_owner_compatibility_values() -> void:
	if not is_instance_valid(player_ref):
		return
	if "saw_rotation_speed" in player_ref:
		saw_rotation_speed = float(player_ref.get("saw_rotation_speed"))
	if "saw_push_force" in player_ref:
		saw_push_force_value = float(player_ref.get("saw_push_force"))
	if "saw_push_radius" in player_ref:
		saw_push_radius = float(player_ref.get("saw_push_radius"))
	elif "saw_hit_radius" in player_ref:
		saw_push_radius = max(OPEN_PUSH_RADIUS, float(player_ref.get("saw_hit_radius")) * 1.4)
	if "saw_contact_interval" in player_ref:
		saw_contact_interval = float(player_ref.get("saw_contact_interval"))
	if "saw_area_interval" in player_ref:
		saw_area_interval = float(player_ref.get("saw_area_interval"))
	if "stake_impact_damage" in player_ref:
		stake_impact_damage = int(player_ref.get("stake_impact_damage"))
	if "chain_color" in player_ref:
		chain_color = player_ref.get("chain_color")
	if "saw_hit_radius" in player_ref:
		saw_hit_radius = float(player_ref.get("saw_hit_radius"))
	if "saw_fly_speed" in player_ref:
		saw_fly_speed = float(player_ref.get("saw_fly_speed"))
	if "closure_duration" in player_ref:
		closure_duration = float(player_ref.get("closure_duration"))
	if "dismember_damage" in player_ref:
		dismember_damage = int(player_ref.get("dismember_damage"))

func _resolve_chain_radius(chain_radius_override: float) -> float:
	var resolved := OPEN_TETHER_RADIUS
	if chain_radius_override > 0.0:
		resolved = chain_radius_override
	elif is_instance_valid(player_ref) and "chain_radius" in player_ref:
		resolved = float(player_ref.get("chain_radius"))
	if is_closed:
		return max(max(CLOSED_MIN_TETHER_RADIUS, resolved), _get_closed_shape_radius())
	return max(OPEN_TETHER_RADIUS, resolved)

func _rebuild_local_points() -> void:
	local_points = PackedVector2Array()
	if shape_points.is_empty():
		shape_points = [
			_launch_origin,
			_launch_origin + fly_dir * SAMPLE_INTERVAL
		]
	if is_closed:
		var center := _calculate_points_center(shape_points)
		for point in shape_points:
			local_points.append(point - center)
	else:
		var start_point := shape_points[0]
		for point in shape_points:
			local_points.append(point - start_point)

func _build_visuals() -> void:
	if is_instance_valid(visual_poly):
		visual_poly.queue_free()
	if is_instance_valid(visual_line):
		visual_line.queue_free()

	visual_poly = Polygon2D.new()
	visual_poly.visible = is_closed
	visual_poly.color = Color(0.82, 0.15, 0.15, 0.78) if is_closed else Color(0.0, 0.0, 0.0, 0.0)
	if is_closed:
		visual_poly.polygon = local_points
	add_child(visual_poly)

	visual_line = Line2D.new()
	visual_line.closed = is_closed
	visual_line.default_color = chain_color
	visual_line.width = 8.0 if not is_closed else 6.0
	visual_line.points = local_points
	add_child(visual_line)

func _setup_lifetime_timer() -> void:
	if is_instance_valid(lifetime_timer):
		lifetime_timer.queue_free()
	lifetime_timer = Timer.new()
	lifetime_timer.one_shot = true
	lifetime_timer.wait_time = max(0.1, _landing_duration)
	lifetime_timer.timeout.connect(_on_lifetime_end)
	add_child(lifetime_timer)

func _process(delta: float) -> void:
	if not is_runtime_active:
		return
	if not is_landed:
		_process_flight(delta)
	else:
		_process_landed(delta)
	queue_redraw()

func _process_flight(delta: float) -> void:
	var remaining: float = OPEN_FLY_DISTANCE - _flight_travelled
	if remaining <= EPSILON:
		_land()
		return

	var step: float = min(remaining, speed * delta)
	_flight_travelled += step
	_anchor_center = _launch_origin + fly_dir * _flight_travelled
	if is_closed:
		_current_rotation += deg_to_rad(saw_rotation_speed) * delta
	_apply_runtime_transform()

	if is_closed:
		_process_closed_flight(delta)
	else:
		_process_open_flight(delta)

	if _flight_travelled >= OPEN_FLY_DISTANCE - EPSILON:
		_land()

func _process_open_flight(delta: float) -> void:
	var world_points := _get_world_polyline_points()
	var enemies := _get_valid_enemy_targets()
	for enemy in enemies:
		if not _is_enemy_alive(enemy):
			continue
		var target_id := _get_target_id(enemy)
		var info := _get_polyline_distance_info(enemy.global_position, world_points)
		if info.distance <= OPEN_PUSH_RADIUS:
			_register_influence(enemy)
			if not _flight_first_hit_ids.has(target_id):
				_flight_first_hit_ids[target_id] = true
				_deal_damage(enemy, _get_base_damage() * OPEN_FIRST_HIT_RATIO)
			_apply_open_flight_motion(enemy, info.closest_point, delta)
		else:
			_flight_contact_timers.erase(target_id)
			if info.distance > OPEN_PUSH_RADIUS:
				continue

		if info.distance <= OPEN_CONTACT_RADIUS:
			_register_influence(enemy)
			_accumulate_interval_damage(enemy, _flight_contact_timers, delta, DAMAGE_TICK_INTERVAL, OPEN_CONTACT_RATIO)
		else:
			_flight_contact_timers.erase(target_id)

	_cleanup_invalid_runtime_targets()

func _process_closed_flight(delta: float) -> void:
	var world_polygon := _get_world_polygon_points()
	var enemies := _get_valid_enemy_targets()
	for enemy in enemies:
		if not _is_enemy_alive(enemy):
			continue
		var target_id := _get_target_id(enemy)
		if _is_point_in_polygon_even_odd(enemy.global_position, world_polygon):
			_register_influence(enemy)
			_apply_closed_flight_motion(enemy, delta)
			_accumulate_interval_damage(enemy, _closed_flight_damage_timers, delta, DAMAGE_TICK_INTERVAL, CLOSED_FLY_DAMAGE_RATIO)
		else:
			_closed_flight_damage_timers.erase(target_id)

	_cleanup_invalid_runtime_targets()

func _apply_open_flight_motion(enemy: Node2D, closest_point: Vector2, delta: float) -> void:
	if enemy == null or not is_instance_valid(enemy):
		return
	var forward_step := fly_dir * OPEN_PUSH_SPEED * delta
	var inward_step := Vector2.ZERO
	var to_line := closest_point - enemy.global_position
	if to_line.length_squared() > EPSILON:
		inward_step = to_line.normalized() * OPEN_INWARD_SPEED * delta
	enemy.global_position += forward_step + inward_step

func _apply_closed_flight_motion(enemy: Node2D, delta: float) -> void:
	if enemy == null or not is_instance_valid(enemy):
		return
	var to_center := _anchor_center - enemy.global_position
	if to_center.length_squared() <= EPSILON:
		return
	enemy.global_position += to_center.normalized() * CLOSED_CENTER_SPEED * delta

func _land() -> void:
	is_landed = true
	_landing_damage_timers.clear()

	if is_closed:
		_land_closed()
	else:
		_land_open()

	Global.on_camera_shake.emit(8.0 if not is_closed else 10.0, 0.18 if not is_closed else 0.22)
	if is_instance_valid(lifetime_timer):
		lifetime_timer.wait_time = max(0.1, _landing_duration)
		lifetime_timer.start()

func _land_open() -> void:
	_anchor_center = global_position
	_apply_runtime_transform()
	_capture_open_landing_targets()

func _land_closed() -> void:
	_current_rotation = rotation
	_anchor_center = global_position
	_apply_runtime_transform()
	_capture_closed_landing_targets()
	_create_butcher_closure_mask()

func _capture_open_landing_targets() -> void:
	var captured := _collect_open_landing_targets()
	_replace_chain_targets(captured)
	for target in captured:
		_landing_damage_timers[_get_target_id(target)] = 0.0

func _capture_closed_landing_targets() -> void:
	var captured := _collect_closed_landing_targets()
	_replace_chain_targets(captured)
	for target in captured:
		var target_id := _get_target_id(target)
		_landing_damage_timers[target_id] = 0.0
		if not _closed_landing_burst_ids.has(target_id):
			_closed_landing_burst_ids[target_id] = true
			_deal_damage(target, _get_base_damage() * CLOSED_LAND_DISMEMBER_RATIO)
	if not captured.is_empty():
		Global.spawn_floating_text(_anchor_center, "DISMEMBER!", Color(1.2, 0.3, 0.3))

func _collect_open_landing_targets() -> Array[Node2D]:
	var result: Array[Node2D] = []
	var seen: Dictionary = {}
	var enemies := _get_valid_enemy_targets()
	for enemy in enemies:
		if not _is_enemy_alive(enemy):
			continue
		var target_id := _get_target_id(enemy)
		if _stake_transfer_centers.has(target_id):
			continue
		var distance := enemy.global_position.distance_to(_anchor_center)
		var influenced := _influence_ids.has(target_id)
		if (influenced and distance <= max(chain_radius, OPEN_TETHER_RADIUS)) or distance <= OPEN_PUSH_RADIUS:
			if seen.has(target_id):
				continue
			seen[target_id] = true
			result.append(enemy)
	return result

func _collect_closed_landing_targets() -> Array[Node2D]:
	var result: Array[Node2D] = []
	var seen: Dictionary = {}
	var world_polygon := _get_world_polygon_points()
	var enemies := _get_valid_enemy_targets()
	for enemy in enemies:
		if not _is_enemy_alive(enemy):
			continue
		var target_id := _get_target_id(enemy)
		if _stake_transfer_centers.has(target_id):
			continue
		var distance := enemy.global_position.distance_to(_anchor_center)
		var inside := _is_point_in_polygon_even_odd(enemy.global_position, world_polygon)
		var influenced := _influence_ids.has(target_id)
		if influenced or inside or distance <= OPEN_PUSH_RADIUS:
			if seen.has(target_id):
				continue
			seen[target_id] = true
			result.append(enemy)
	return result

func _process_landed(delta: float) -> void:
	_cleanup_invalid_runtime_targets()
	if is_closed:
		_process_closed_landed(delta)
	else:
		_process_open_landed(delta)

func _process_open_landed(delta: float) -> void:
	_apply_landed_tether_and_damage(delta)

func _process_closed_landed(delta: float) -> void:
	_capture_closed_post_landing_targets()
	_apply_landed_tether_and_damage(delta)

func _capture_closed_post_landing_targets() -> void:
	var world_polygon := _get_world_polygon_points()
	for enemy in _get_valid_enemy_targets():
		if not _is_enemy_alive(enemy):
			continue
		var target_id := _get_target_id(enemy)
		if _chain_target_ids.has(target_id):
			continue
		if _stake_transfer_centers.has(target_id):
			continue
		var distance := enemy.global_position.distance_to(_anchor_center)
		var inside := _is_point_in_polygon_even_odd(enemy.global_position, world_polygon)
		if inside or distance <= OPEN_PUSH_RADIUS:
			_register_chain_target(enemy)
			_landing_damage_timers[target_id] = 0.0

func _apply_landed_tether_and_damage(delta: float) -> void:
	var live_targets := get_chain_targets()
	var landed_damage_ratio := CLOSED_LAND_DAMAGE_RATIO if is_closed else OPEN_LAND_TICK_RATIO
	var landed_radius := chain_radius
	for target in live_targets:
		if not _is_enemy_alive(target):
			remove_chain_target(target, false)
			continue
		_clamp_target_to_radius(target, landed_radius)
		_accumulate_interval_damage(target, _landing_damage_timers, delta, DAMAGE_TICK_INTERVAL, landed_damage_ratio)

func _clamp_target_to_radius(target: Node2D, radius: float) -> void:
	if target == null or not is_instance_valid(target):
		return
	var offset := target.global_position - _anchor_center
	var distance := offset.length()
	if distance <= radius or distance <= EPSILON:
		return
	var outward := offset / distance
	target.global_position = _anchor_center + outward * radius
	_zero_outward_velocity(target, outward)

func _zero_outward_velocity(target: Node2D, outward: Vector2) -> void:
	if target == null or not is_instance_valid(target):
		return
	if "velocity" in target:
		var velocity_var: Variant = target.get("velocity")
		if velocity_var is Vector2:
			var velocity: Vector2 = velocity_var
			var outward_speed: float = max(0.0, velocity.dot(outward))
			if outward_speed > 0.0:
				target.set("velocity", velocity - outward * outward_speed)
	if "external_force" in target:
		var force_var: Variant = target.get("external_force")
		if force_var is Vector2:
			var force: Vector2 = force_var
			var outward_force: float = max(0.0, force.dot(outward))
			if outward_force > 0.0:
				target.set("external_force", force - outward * outward_force)

func _accumulate_interval_damage(
	target: Node2D,
	timer_store: Dictionary,
	delta: float,
	interval: float,
	damage_ratio: float
) -> void:
	if target == null or not is_instance_valid(target):
		return
	if interval <= EPSILON:
		return
	var target_id := _get_target_id(target)
	var timer: float = float(timer_store.get(target_id, 0.0)) + max(0.0, delta)
	while timer >= interval:
		timer -= interval
		_deal_damage(target, _get_base_damage() * damage_ratio)
	timer_store[target_id] = timer

func _cleanup_invalid_runtime_targets() -> void:
	var valid_ids: Dictionary = {}
	var valid_chain: Array[WeakRef] = []
	for chain_ref in chained_enemies:
		if chain_ref == null:
			continue
		var enemy_var: Variant = chain_ref.get_ref()
		if enemy_var == null or not is_instance_valid(enemy_var) or not (enemy_var is Node2D):
			continue
		var enemy := enemy_var as Node2D
		var target_id := _get_target_id(enemy)
		valid_chain.append(chain_ref)
		valid_ids[target_id] = true
	chained_enemies = valid_chain
	_chain_target_ids.clear()
	for chain_ref in chained_enemies:
		var enemy_var: Variant = chain_ref.get_ref()
		if enemy_var == null or not is_instance_valid(enemy_var) or not (enemy_var is Node2D):
			continue
		_chain_target_ids[_get_target_id(enemy_var)] = chain_ref

	var valid_influence: Dictionary = {}
	for target_id in _influence_ids.keys():
		var ref: Variant = _influence_ids.get(target_id)
		if ref == null or not (ref is WeakRef):
			continue
		var enemy_var: Variant = ref.get_ref()
		if enemy_var == null or not is_instance_valid(enemy_var) or not (enemy_var is Node2D):
			continue
		valid_influence[target_id] = ref
		valid_ids[target_id] = true
	_influence_ids = valid_influence

	_purge_id_map(_flight_contact_timers, valid_ids)
	_purge_id_map(_flight_first_hit_ids, valid_ids)
	_purge_id_map(_closed_flight_damage_timers, valid_ids)
	_purge_id_map(_landing_damage_timers, valid_ids)
	_purge_id_map(_closed_landing_burst_ids, valid_ids)
	_purge_id_map(_stake_transfer_centers, valid_ids)

func _register_influence(target: Node2D) -> void:
	if target == null or not is_instance_valid(target):
		return
	var target_id := _get_target_id(target)
	if not _influence_ids.has(target_id):
		_influence_ids[target_id] = weakref(target)

func _register_chain_target(target: Node2D) -> void:
	if target == null or not is_instance_valid(target):
		return
	var target_id := _get_target_id(target)
	if _chain_target_ids.has(target_id):
		return
	var ref: WeakRef = weakref(target)
	_chain_target_ids[target_id] = ref
	chained_enemies.append(ref)
	_register_influence(target)

func _replace_chain_targets(targets: Array[Node2D]) -> void:
	chained_enemies.clear()
	_chain_target_ids.clear()
	for target in targets:
		_register_chain_target(target)

func _get_valid_enemy_targets() -> Array[Node2D]:
	var result: Array[Node2D] = []
	var tree := get_tree()
	if tree == null:
		return result
	for enemy_var: Variant in tree.get_nodes_in_group("enemies"):
		if enemy_var == null or not is_instance_valid(enemy_var) or not (enemy_var is Node2D):
			continue
		result.append(enemy_var as Node2D)
	return result

func _is_enemy_alive(enemy: Node2D) -> bool:
	if enemy == null or not is_instance_valid(enemy):
		return false
	var health := enemy.get_node_or_null("HealthComponent")
	if health != null and "current_health" in health:
		return float(health.get("current_health")) > 0.0
	return true

func _get_target_id(target: Node2D) -> int:
	return int(target.get_instance_id()) if target != null and is_instance_valid(target) else 0

func _get_base_damage() -> float:
	if not is_instance_valid(player_ref):
		return 10.0
	if "damage" in player_ref:
		return max(1.0, float(player_ref.get("damage")))
	return 10.0

func _get_player_origin() -> Vector2:
	if is_instance_valid(player_ref):
		return player_ref.global_position
	return global_position

func _get_closed_shape_radius() -> float:
	var max_radius := 0.0
	var center := _calculate_points_center(shape_points)
	for point in shape_points:
		max_radius = max(max_radius, point.distance_to(center))
	return max_radius

func _calculate_points_center(points: Array[Vector2]) -> Vector2:
	if points.is_empty():
		return Vector2.ZERO
	var center := Vector2.ZERO
	for point in points:
		center += point
	return center / float(points.size())

func _get_world_polyline_points() -> PackedVector2Array:
	var points := PackedVector2Array()
	for point in local_points:
		points.append(to_global(point))
	return points

func _get_world_polygon_points() -> PackedVector2Array:
	return _get_world_polyline_points()

func _get_polyline_distance_info(query_point: Vector2, polyline: PackedVector2Array) -> Dictionary:
	var result := {
		"closest_point": query_point,
		"distance": INF,
	}
	if polyline.size() < 2:
		return result
	var best_point := query_point
	var best_distance := INF
	for i in range(polyline.size() - 1):
		var p1 := polyline[i]
		var p2 := polyline[i + 1]
		var closest := Geometry2D.get_closest_point_to_segment(query_point, p1, p2)
		var dist := query_point.distance_to(closest)
		if dist < best_distance:
			best_distance = dist
			best_point = closest
	result["closest_point"] = best_point
	result["distance"] = best_distance
	return result

func _is_point_in_polygon_even_odd(point: Vector2, polygon: PackedVector2Array) -> bool:
	if polygon.size() < 3:
		return false
	var inside := false
	for i in range(polygon.size()):
		var a: Vector2 = polygon[i]
		var b: Vector2 = polygon[(i + 1) % polygon.size()]
		if _is_point_on_segment(point, a, b):
			return true
		var intersects := ((a.y > point.y) != (b.y > point.y))
		if intersects:
			var x_intersection: float = (b.x - a.x) * (point.y - a.y) / max(absf(b.y - a.y), EPSILON) + a.x
			if point.x < x_intersection:
				inside = not inside
	return inside

func _is_point_on_segment(point: Vector2, a: Vector2, b: Vector2) -> bool:
	var closest := Geometry2D.get_closest_point_to_segment(point, a, b)
	return point.distance_to(closest) <= 0.75

func _apply_runtime_transform() -> void:
	global_position = _anchor_center
	rotation = _current_rotation if is_closed else 0.0

func _deal_damage(enemy: Node2D, amount: float) -> void:
	if enemy == null or not is_instance_valid(enemy):
		return
	var target_amount: float = max(1.0, amount)
	var health := enemy.get_node_or_null("HealthComponent")
	if health != null and health.has_method("take_damage"):
		health.call("take_damage", target_amount)

func _draw() -> void:
	if not is_runtime_active:
		return
	for chain_ref in chained_enemies:
		var enemy_var: Variant = chain_ref.get_ref() if chain_ref != null else null
		if enemy_var == null or not is_instance_valid(enemy_var) or not (enemy_var is Node2D):
			continue
		var enemy := enemy_var as Node2D
		draw_line(Vector2.ZERO, to_local(enemy.global_position), chain_color, 2.0)

func get_runtime_snapshot() -> Dictionary:
	return {
		"active": is_butcher_runtime_active(),
		"state": "landed_closed" if is_landed and is_closed else ("landed_open" if is_landed else ("flying_closed" if is_closed else "flying_open")),
		"is_closed": is_closed,
		"is_landed": is_landed,
		"anchor_center": get_anchor_center(),
		"center": get_anchor_center(),
		"flight_origin": _launch_origin,
		"flight_travelled": _flight_travelled,
		"flight_distance": OPEN_FLY_DISTANCE,
		"target_pos": target_pos,
		"chain_radius": chain_radius,
		"chain_targets": get_chain_targets(),
		"influenced_targets": _collect_influenced_targets(),
		"stake_transfers": _collect_stake_transfer_snapshot(),
		"shape_points": shape_points.duplicate(),
		"local_points": local_points,
		"world_points": _get_world_polyline_points(),
		"rotation_degrees": rad_to_deg(_current_rotation),
		"duration": _landing_duration,
	}

func get_anchor_center() -> Vector2:
	return _anchor_center

func get_chain_targets() -> Array:
	var result: Array = []
	var valid_refs: Array[WeakRef] = []
	for chain_ref in chained_enemies:
		if chain_ref == null:
			continue
		var enemy_var: Variant = chain_ref.get_ref()
		if enemy_var == null or not is_instance_valid(enemy_var) or not (enemy_var is Node2D):
			continue
		valid_refs.append(chain_ref)
		result.append(enemy_var)
	chained_enemies = valid_refs
	_rebuild_chain_id_cache()
	return result

func remove_chain_target(target: Node2D, keep_influence: bool = true) -> bool:
	if target == null or not is_instance_valid(target):
		return false
	var target_id := _get_target_id(target)
	var removed := _erase_chain_target_id(target_id)
	_landing_damage_timers.erase(target_id)
	_flight_contact_timers.erase(target_id)
	_closed_flight_damage_timers.erase(target_id)
	_closed_landing_burst_ids.erase(target_id)
	if not keep_influence:
		_influence_ids.erase(target_id)
		_stake_transfer_centers.erase(target_id)
	return removed

func transfer_target_to_stake(target: Node2D, stake_center: Vector2) -> bool:
	if target == null or not is_instance_valid(target):
		return false
	var target_id := _get_target_id(target)
	_stake_transfer_centers[target_id] = stake_center
	remove_chain_target(target, true)
	if target.has_meta("butcher_stake_center"):
		target.set_meta("butcher_stake_center", stake_center)
	else:
		target.set_meta("butcher_stake_center", stake_center)
	return true

func is_butcher_runtime_active() -> bool:
	return is_runtime_active and is_inside_tree() and not is_queued_for_deletion()

func manual_dismiss() -> void:
	_finish_runtime()

func _on_lifetime_end() -> void:
	_finish_runtime()

func _finish_runtime() -> void:
	if not is_runtime_active:
		if is_instance_valid(lifetime_timer):
			lifetime_timer.queue_free()
		queue_free()
		return
	is_runtime_active = false
	if is_instance_valid(lifetime_timer):
		lifetime_timer.queue_free()
	queue_free()

func _collect_influenced_targets() -> Array:
	var result: Array = []
	for target_id in _influence_ids.keys():
		var ref: Variant = _influence_ids.get(target_id)
		var enemy_var: Variant = ref.get_ref() if ref is WeakRef else null
		if enemy_var == null or not is_instance_valid(enemy_var) or not (enemy_var is Node2D):
			continue
		result.append(enemy_var)
	return result

func _collect_stake_transfer_snapshot() -> Dictionary:
	var snapshot: Dictionary = {}
	for target_id in _stake_transfer_centers.keys():
		snapshot[target_id] = _stake_transfer_centers[target_id]
	return snapshot

func _rebuild_chain_id_cache() -> void:
	_chain_target_ids.clear()
	for chain_ref in chained_enemies:
		if chain_ref == null:
			continue
		var enemy_var: Variant = chain_ref.get_ref()
		if enemy_var == null or not is_instance_valid(enemy_var) or not (enemy_var is Node2D):
			continue
		_chain_target_ids[_get_target_id(enemy_var)] = chain_ref

func _erase_chain_target_id(target_id: int) -> bool:
	var removed := false
	var filtered: Array[WeakRef] = []
	for chain_ref in chained_enemies:
		if chain_ref == null:
			continue
		var enemy_var: Variant = chain_ref.get_ref()
		if enemy_var == null or not is_instance_valid(enemy_var) or not (enemy_var is Node2D):
			continue
		if _get_target_id(enemy_var) == target_id:
			removed = true
			continue
		filtered.append(chain_ref)
	chained_enemies = filtered
	_chain_target_ids.erase(target_id)
	return removed

func _purge_id_map(store: Dictionary, valid_ids: Dictionary) -> void:
	for key in store.keys():
		if not valid_ids.has(key):
			store.erase(key)

func _create_butcher_closure_mask() -> void:
	var polygon := _get_world_polygon_points()
	if polygon.size() < 3:
		return
	var polygons: Array[PackedVector2Array] = [polygon]
	PolygonUtils.show_closure_masks(polygons, Color(1.0, 0.12, 0.12, 0.68), get_tree(), 0.45)

func _cleanup_on_tree_exit() -> void:
	is_runtime_active = false
