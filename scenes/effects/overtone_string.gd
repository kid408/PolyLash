extends Node2D
class_name OvertoneString

@export var lifetime: float = 10.0
@export var slow_half_width: float = 24.0
@export var slow_move_speed_multiplier: float = 0.90
@export var pluck_cooldown: float = 0.5
@export var max_plucks: int = 3
@export var sonic_boom_range: float = 250.0
@export var sonic_boom_damage_ratio: float = 1.2
@export var frenzy_frequency: float = 2.0
@export var retune_shift_distance: float = 150.0
@export var retune_drag_distance: float = 50.0
@export var rebound_wall_visual_fade: float = 0.18
@export var vibration_duration: float = 0.20
@export var vibration_amplitude: float = 18.0
@export var vibration_frequency: float = 6.0

var owner_player: PlayerBase = null
var source_attack: float = 40.0
var path_points: PackedVector2Array = PackedVector2Array()

var _outer_line: Line2D = null
var _inner_line: Line2D = null
var _remaining_lifetime: float = 0.0
var _pluck_cooldown_remaining: float = 0.0
var _frenzy_active: bool = false
var _frenzy_timer: float = 0.0
var _pluck_count: int = 0
var _last_player_positions: Dictionary = {}
var _vibration_timer: float = 0.0
var _vibration_seed: float = 0.0

func setup(player_node: PlayerBase, points: PackedVector2Array, attack_value: float, custom_lifetime: float = 10.0, frenzy_active: bool = false) -> void:
	owner_player = player_node
	path_points = points.duplicate()
	source_attack = max(1.0, attack_value)
	_remaining_lifetime = max(0.1, custom_lifetime)
	_frenzy_active = frenzy_active
	_frenzy_timer = 0.0

func _ready() -> void:
	add_to_group("overtone_strings")
	add_to_group("player_summoned_entity")
	_rebuild_visuals()
	_refresh_visuals()

func _process(delta: float) -> void:
	if path_points.size() < 2:
		queue_free()
		return

	_remaining_lifetime = max(0.0, _remaining_lifetime - delta)
	if _remaining_lifetime <= 0.0:
		queue_free()
		return

	if _pluck_cooldown_remaining > 0.0:
		_pluck_cooldown_remaining = max(0.0, _pluck_cooldown_remaining - delta)
	if _vibration_timer > 0.0:
		_vibration_timer = max(0.0, _vibration_timer - delta)

	if _frenzy_active and frenzy_frequency > 0.0:
		_frenzy_timer -= delta
		while _frenzy_timer <= 0.0:
			_frenzy_timer += 1.0 / frenzy_frequency
			_fire_frenzy_bursts()

	_apply_soft_slow()
	_detect_player_crossings()
	_refresh_visuals()

func set_frenzy_active(active: bool) -> void:
	_frenzy_active = active
	_frenzy_timer = 0.0

func retune_around_player(player_position: Vector2) -> void:
	var old_points: PackedVector2Array = path_points.duplicate()
	var string_center: Vector2 = _get_polyline_center()
	var to_player: Vector2 = player_position - string_center
	if to_player.length_squared() <= 0.0001:
		return
	var offset: Vector2 = to_player
	for i: int in range(path_points.size()):
		path_points[i] = path_points[i] + offset
	_pull_scraped_enemies(old_points, path_points, player_position)
	_refresh_visuals()

func translate_by_offset(offset: Vector2, player_position: Vector2) -> void:
	if offset.length_squared() <= 0.0001:
		return
	var old_points: PackedVector2Array = path_points.duplicate()
	for i: int in range(path_points.size()):
		path_points[i] = path_points[i] + offset
	_pull_scraped_enemies(old_points, path_points, player_position)
	_refresh_visuals()

func get_string_center() -> Vector2:
	return _get_polyline_center()

func _apply_soft_slow() -> void:
	var modifier_id: String = "overtone_string_slow_%d" % get_instance_id()
	for enemy_node: Node in get_tree().get_nodes_in_group("enemies"):
		if not (enemy_node is Enemy):
			continue
		var enemy: Enemy = enemy_node as Enemy
		if enemy == null or not is_instance_valid(enemy) or enemy.is_dead:
			continue
		if _distance_to_polyline(enemy.global_position, path_points) > slow_half_width:
			continue
		if enemy.has_method("apply_move_speed_modifier"):
			enemy.apply_move_speed_modifier(
				modifier_id,
				slow_move_speed_multiplier,
				0.20,
				CombatModifierComponent.STACK_REFRESH,
				owner_player,
				{"kind": "overtone_string_slow"}
			)

func _detect_player_crossings() -> void:
	for player_node: Node in get_tree().get_nodes_in_group("player"):
		if not (player_node is PlayerBase):
			continue
		var player: PlayerBase = player_node as PlayerBase
		if player == null or not is_instance_valid(player):
			continue

		var player_key: int = player.get_instance_id()
		var current_position: Vector2 = player.global_position
		if not _last_player_positions.has(player_key):
			_last_player_positions[player_key] = current_position
			continue

		var previous_position: Vector2 = _last_player_positions[player_key]
		_last_player_positions[player_key] = current_position
		if previous_position.distance_squared_to(current_position) <= 0.001:
			continue
		if _pluck_cooldown_remaining > 0.0:
			continue

		var crossing: Dictionary = _find_crossing(previous_position, current_position)
		if not bool(crossing.get("hit", false)):
			continue

		var movement_direction: Vector2 = (current_position - previous_position).normalized()
		if movement_direction.length_squared() <= 0.0001:
			continue
		_trigger_pluck(crossing.get("point", current_position), movement_direction)

func _find_crossing(from_pos: Vector2, to_pos: Vector2) -> Dictionary:
	var result: Dictionary = {
		"hit": false,
		"point": Vector2.ZERO,
	}
	for i: int in range(path_points.size() - 1):
		var segment_start: Vector2 = path_points[i]
		var segment_end: Vector2 = path_points[i + 1]
		var hit_variant: Variant = Geometry2D.segment_intersects_segment(from_pos, to_pos, segment_start, segment_end)
		if hit_variant == null or not (hit_variant is Vector2):
			continue
		result["hit"] = true
		result["point"] = hit_variant
		return result
	return result

func _trigger_pluck(_origin: Vector2, direction: Vector2) -> void:
	_pluck_cooldown_remaining = pluck_cooldown
	_pluck_count += 1
	_start_vibration()
	var rebound_direction: Vector2 = (-direction).normalized()
	_spawn_rebound_wall_visual(rebound_direction)
	var hit_enemies: Array = _apply_rebound_wall_damage(rebound_direction, "space")
	if is_instance_valid(owner_player) and not hit_enemies.is_empty():
		owner_player.notify_front_skill_damage("space", hit_enemies, {
			"skill_id": "draw_overtone",
			"source": "overtone_string_pluck",
		})
	if _pluck_count >= max_plucks:
		queue_free()

func _fire_frenzy_bursts() -> void:
	if path_points.size() < 2:
		return
	if _pluck_cooldown_remaining > 0.0:
		return

	var midpoint_data: Dictionary = _sample_midpoint()
	var tangent: Vector2 = midpoint_data.get("tangent", Vector2.RIGHT)
	var normal: Vector2 = Vector2(-tangent.y, tangent.x).normalized()
	if normal.length_squared() <= 0.0001:
		normal = Vector2.UP

	_pluck_cooldown_remaining = pluck_cooldown
	_pluck_count += 1
	_start_vibration()
	var hit_enemies: Array = []
	hit_enemies.append_array(_apply_rebound_wall_damage(normal, "f"))
	hit_enemies.append_array(_apply_rebound_wall_damage(-normal, "f"))
	_spawn_rebound_wall_visual(normal)
	_spawn_rebound_wall_visual(-normal)

	if is_instance_valid(owner_player) and not hit_enemies.is_empty():
		owner_player.notify_front_skill_damage("f", _dedupe_enemy_array(hit_enemies), {
			"skill_id": "f_overtone",
			"source": "death_metal_rhapsody",
		})

	if _pluck_count >= max_plucks:
		queue_free()

func _apply_rebound_wall_damage(direction: Vector2, source_slot: String) -> Array:
	var hit_enemies: Array = []
	var wall_offset: Vector2 = direction.normalized() * sonic_boom_range
	if wall_offset.length_squared() <= 0.0001:
		return hit_enemies
	for enemy_node: Node in get_tree().get_nodes_in_group("enemies"):
		if not (enemy_node is Enemy):
			continue
		var enemy: Enemy = enemy_node as Enemy
		if enemy == null or not is_instance_valid(enemy) or enemy.is_dead:
			continue
		if not _is_point_in_rebound_wall(enemy.global_position, wall_offset):
			continue
		enemy.apply_modifier_damage(
			source_attack * sonic_boom_damage_ratio,
			owner_player,
			{
				"kind": "overtone_sonic_boom",
				"source_slot": source_slot,
				"damage_type": "DMG_AOE",
				"skill_slot": "q" if source_slot == "space" else source_slot,
				"space_skill_mode": "open" if source_slot == "space" else "",
			}
		)
		if enemy.has_method("set_flash_material"):
			enemy.set_flash_material()
		hit_enemies.append(enemy)
	return hit_enemies

func _is_point_in_rebound_wall(point: Vector2, wall_offset: Vector2) -> bool:
	for i: int in range(path_points.size() - 1):
		var a: Vector2 = path_points[i]
		var b: Vector2 = path_points[i + 1]
		var quad: PackedVector2Array = PackedVector2Array([
			a,
			b,
			b + wall_offset,
			a + wall_offset,
		])
		if Geometry2D.is_point_in_polygon(point, quad):
			return true
		if point.distance_to(a) <= sonic_boom_range or point.distance_to(b) <= sonic_boom_range:
			var closest_a: Vector2 = Geometry2D.get_closest_point_to_segment(point, a, a + wall_offset)
			var closest_b: Vector2 = Geometry2D.get_closest_point_to_segment(point, b, b + wall_offset)
			if point.distance_to(closest_a) <= 18.0 or point.distance_to(closest_b) <= 18.0:
				return true
	return false

func _sample_midpoint() -> Dictionary:
	var total_length: float = 0.0
	for i: int in range(path_points.size() - 1):
		total_length += path_points[i].distance_to(path_points[i + 1])
	var target_length: float = total_length * 0.5
	var consumed: float = 0.0
	for i: int in range(path_points.size() - 1):
		var a: Vector2 = path_points[i]
		var b: Vector2 = path_points[i + 1]
		var segment_length: float = a.distance_to(b)
		if consumed + segment_length < target_length:
			consumed += segment_length
			continue
		var weight: float = 0.0 if segment_length <= 0.001 else (target_length - consumed) / segment_length
		return {
			"position": a.lerp(b, clamp(weight, 0.0, 1.0)),
			"tangent": (b - a).normalized(),
		}
	return {
		"position": path_points[int(path_points.size() / 2)],
		"tangent": (path_points[path_points.size() - 1] - path_points[0]).normalized(),
	}

func _pull_scraped_enemies(old_points: PackedVector2Array, new_points: PackedVector2Array, player_position: Vector2) -> void:
	var scrape_radius: float = slow_half_width + retune_shift_distance * 0.5
	for enemy_node: Node in get_tree().get_nodes_in_group("enemies"):
		if not (enemy_node is Enemy):
			continue
		var enemy: Enemy = enemy_node as Enemy
		if enemy == null or not is_instance_valid(enemy) or enemy.is_dead:
			continue
		var old_distance: float = _distance_to_polyline(enemy.global_position, old_points)
		var new_distance: float = _distance_to_polyline(enemy.global_position, new_points)
		if min(old_distance, new_distance) > scrape_radius:
			continue
		var to_player: Vector2 = player_position - enemy.global_position
		if to_player.length_squared() <= 0.0001:
			continue
		enemy.global_position += to_player.normalized() * min(retune_drag_distance, to_player.length())
		if enemy.has_method("set_flash_material"):
			enemy.set_flash_material()

func _distance_to_polyline(point: Vector2, points: PackedVector2Array) -> float:
	if points.size() < 2:
		return INF
	var best_distance: float = INF
	for i: int in range(points.size() - 1):
		var closest: Vector2 = Geometry2D.get_closest_point_to_segment(point, points[i], points[i + 1])
		best_distance = min(best_distance, point.distance_to(closest))
	return best_distance

func _get_polyline_center() -> Vector2:
	if path_points.is_empty():
		return global_position
	var total: Vector2 = Vector2.ZERO
	for point: Vector2 in path_points:
		total += point
	return total / float(path_points.size())

func _dedupe_enemy_array(hit_enemies: Array) -> Array:
	var result: Array = []
	var ids: Dictionary = {}
	for enemy_variant: Variant in hit_enemies:
		if not (enemy_variant is Enemy):
			continue
		var enemy: Enemy = enemy_variant as Enemy
		if enemy == null or not is_instance_valid(enemy):
			continue
		var enemy_id: int = enemy.get_instance_id()
		if ids.has(enemy_id):
			continue
		ids[enemy_id] = true
		result.append(enemy)
	return result

func _rebuild_visuals() -> void:
	if _outer_line == null:
		_outer_line = Line2D.new()
		_outer_line.top_level = true
		_outer_line.joint_mode = Line2D.LINE_JOINT_ROUND
		_outer_line.begin_cap_mode = Line2D.LINE_CAP_ROUND
		_outer_line.end_cap_mode = Line2D.LINE_CAP_ROUND
		_outer_line.antialiased = true
		_outer_line.z_index = 26
		add_child(_outer_line)
	if _inner_line == null:
		_inner_line = Line2D.new()
		_inner_line.top_level = true
		_inner_line.joint_mode = Line2D.LINE_JOINT_ROUND
		_inner_line.begin_cap_mode = Line2D.LINE_CAP_ROUND
		_inner_line.end_cap_mode = Line2D.LINE_CAP_ROUND
		_inner_line.antialiased = true
		_inner_line.z_index = 27
		add_child(_inner_line)

func _refresh_visuals() -> void:
	if _outer_line == null or _inner_line == null:
		return
	var visual_points: PackedVector2Array = _build_vibrated_points()
	_outer_line.points = visual_points
	_inner_line.points = visual_points
	var pulse: float = 0.5 + 0.5 * sin((Time.get_ticks_msec() / 1000.0) * 5.0)
	_outer_line.width = lerp(18.0, 22.0, pulse)
	_inner_line.width = lerp(6.0, 10.0, pulse)
	_outer_line.default_color = Color(0.92, 0.70, 0.18, 0.42)
	_inner_line.default_color = Color(1.0, 0.96, 0.76, 0.95)

func _build_vibrated_points() -> PackedVector2Array:
	if path_points.size() < 2 or _vibration_timer <= 0.0:
		return path_points
	var result: PackedVector2Array = PackedVector2Array()
	var normalized_time: float = 1.0 - (_vibration_timer / max(0.001, vibration_duration))
	var amplitude_scale: float = sin(normalized_time * PI) * vibration_amplitude
	for i: int in range(path_points.size()):
		var point: Vector2 = path_points[i]
		var tangent: Vector2 = Vector2.RIGHT
		if i == 0:
			tangent = (path_points[1] - path_points[0]).normalized()
		elif i == path_points.size() - 1:
			tangent = (path_points[i] - path_points[i - 1]).normalized()
		else:
			tangent = (path_points[i + 1] - path_points[i - 1]).normalized()
		if tangent.length_squared() <= 0.0001:
			tangent = Vector2.RIGHT
		var normal: Vector2 = Vector2(-tangent.y, tangent.x)
		var along_ratio: float = float(i) / float(max(1, path_points.size() - 1))
		var wave: float = sin((_vibration_seed + along_ratio * vibration_frequency + normalized_time * 18.0) * TAU)
		result.append(point + normal * wave * amplitude_scale)
	return result

func _start_vibration() -> void:
	_vibration_timer = vibration_duration
	_vibration_seed = randf()

func _spawn_rebound_wall_visual(direction: Vector2) -> void:
	var wall_offset: Vector2 = direction.normalized() * sonic_boom_range
	if wall_offset.length_squared() <= 0.0001:
		return
	var root: Node2D = Node2D.new()
	root.top_level = true
	root.z_index = 30

	for i: int in range(path_points.size() - 1):
		var a: Vector2 = path_points[i]
		var b: Vector2 = path_points[i + 1]
		var quad: PackedVector2Array = PackedVector2Array([
			a,
			b,
			b + wall_offset,
			a + wall_offset,
		])
		var fill: Polygon2D = Polygon2D.new()
		fill.polygon = quad
		fill.color = Color(1.0, 0.82, 0.34, 0.14)
		root.add_child(fill)

	var start_line: Line2D = Line2D.new()
	start_line.points = path_points
	start_line.width = 10.0
	start_line.default_color = Color(1.0, 0.95, 0.72, 0.95)
	start_line.joint_mode = Line2D.LINE_JOINT_ROUND
	start_line.begin_cap_mode = Line2D.LINE_CAP_ROUND
	start_line.end_cap_mode = Line2D.LINE_CAP_ROUND
	start_line.antialiased = true
	root.add_child(start_line)

	var end_points: PackedVector2Array = PackedVector2Array()
	for point: Vector2 in path_points:
		end_points.append(point + wall_offset)
	var end_line: Line2D = Line2D.new()
	end_line.points = end_points
	end_line.width = 18.0
	end_line.default_color = Color(1.0, 0.70, 0.22, 0.52)
	end_line.joint_mode = Line2D.LINE_JOINT_ROUND
	end_line.begin_cap_mode = Line2D.LINE_CAP_ROUND
	end_line.end_cap_mode = Line2D.LINE_CAP_ROUND
	end_line.antialiased = true
	root.add_child(end_line)

	get_tree().current_scene.add_child(root)

	var tween: Tween = root.create_tween()
	tween.set_parallel(true)
	tween.tween_property(root, "modulate:a", 0.0, rebound_wall_visual_fade)
	tween.finished.connect(root.queue_free)
