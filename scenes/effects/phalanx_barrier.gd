extends Node2D
class_name PhalanxBarrier

@export var lifetime: float = 8.0
@export var half_width: float = 18.0
@export var durability_hit_icd: float = 0.05
@export var enemy_touch_icd: float = 0.08
@export var bounce_speed: float = 1200.0
@export var bounce_distance: float = 150.0
@export var sweep_bounce_distance: float = 800.0
@export var bounce_duration: float = 0.25
@export var micro_stun_duration: float = 0.15
@export var ballistic_collision_damage_ratio: float = 3.5
@export var sweep_ballistic_collision_damage_ratio: float = 3.5
@export var sweep_speed: float = 2000.0
@export var sweep_travel_distance: float = 800.0
@export var sweep_extra_width: float = 16.0

var owner_player: PlayerBase = null
var source_attack: float = 40.0
var path_points: PackedVector2Array = PackedVector2Array()
var remaining_lifetime: float = 0.0
var max_durability: int = 2
var remaining_durability: int = 2
var infinite_durability: bool = false

var _outer_line: Line2D = null
var _inner_line: Line2D = null
var _enemy_touch_cooldowns: Dictionary = {}
var _enemy_last_positions: Dictionary = {}
var _durability_cooldown_remaining: float = 0.0
var _sweeping_active: bool = false
var _sweep_direction: Vector2 = Vector2.ZERO
var _sweep_remaining_distance: float = 0.0

func setup(player_node: PlayerBase, points: PackedVector2Array, attack_value: float, custom_lifetime: float, durability_count: int) -> void:
	owner_player = player_node
	path_points = points.duplicate()
	source_attack = max(1.0, attack_value)
	remaining_lifetime = max(0.1, custom_lifetime)
	max_durability = max(2, durability_count)
	remaining_durability = max_durability

func _ready() -> void:
	add_to_group("phalanx_barriers")
	add_to_group("player_summoned_entity")
	if path_points.size() < 2:
		queue_free()
		return
	_rebuild_visuals()
	_refresh_visuals()

func _process(delta: float) -> void:
	if path_points.size() < 2:
		queue_free()
		return
	remaining_lifetime = max(0.0, remaining_lifetime - delta)
	if remaining_lifetime <= 0.0:
		queue_free()
		return
	_decay_cooldowns(delta)
	if _sweeping_active:
		_process_sweep(delta)
	else:
		_process_enemy_contacts()
	_refresh_visuals()

func start_kinetic_launch(player_position: Vector2) -> void:
	_sweeping_active = true
	_sweep_direction = _resolve_launch_direction_away_from_player(player_position)
	_sweep_remaining_distance = sweep_travel_distance

func set_infinite_durability(active: bool) -> void:
	infinite_durability = active

func get_polyline_center() -> Vector2:
	if path_points.is_empty():
		return global_position
	var total: Vector2 = Vector2.ZERO
	for point: Vector2 in path_points:
		total += point
	return total / float(path_points.size())

func _process_enemy_contacts() -> void:
	for enemy_node: Node in get_tree().get_nodes_in_group("enemies"):
		if not (enemy_node is Enemy):
			continue
		var enemy: Enemy = enemy_node as Enemy
		if enemy == null or not is_instance_valid(enemy) or enemy.is_dead:
			continue
		var enemy_id: int = enemy.get_instance_id()
		var current_position: Vector2 = enemy.global_position
		var previous_position: Vector2 = current_position
		if _enemy_last_positions.has(enemy_id):
			previous_position = _enemy_last_positions[enemy_id]
		_enemy_last_positions[enemy_id] = current_position
		if float(_enemy_touch_cooldowns.get(enemy_id, 0.0)) > 0.0:
			continue

		var segment_data: Dictionary = _get_closest_segment_data(current_position)
		var closest_point: Vector2 = segment_data.get("closest_point", current_position)
		var distance_to_barrier: float = current_position.distance_to(closest_point)
		if distance_to_barrier > half_width:
			continue

		var incoming_direction: Vector2 = current_position - previous_position
		if incoming_direction.length_squared() <= 0.0001:
			incoming_direction = current_position - closest_point
		var normal: Vector2 = segment_data.get("normal", Vector2.UP)
		if incoming_direction.dot(normal) > 0.0:
			normal = -normal
		_trigger_ballistic(enemy, normal)
		_enemy_touch_cooldowns[enemy_id] = enemy_touch_icd

		if not infinite_durability and _durability_cooldown_remaining <= 0.0:
			remaining_durability -= 1
			_durability_cooldown_remaining = durability_hit_icd
			if remaining_durability <= 0:
				queue_free()
				return

func _process_sweep(delta: float) -> void:
	if _sweep_remaining_distance <= 0.0 or _sweep_direction.length_squared() <= 0.0001:
		queue_free()
		return
	var step_distance: float = min(_sweep_remaining_distance, sweep_speed * delta)
	var offset: Vector2 = _sweep_direction * step_distance
	for i: int in range(path_points.size()):
		path_points[i] += offset
	_sweep_remaining_distance = max(0.0, _sweep_remaining_distance - step_distance)
	_process_sweep_hits(_sweep_direction)
	if _sweep_remaining_distance <= 0.001:
		queue_free()

func _process_sweep_hits(launch_direction_hint: Vector2) -> void:
	for enemy_node: Node in get_tree().get_nodes_in_group("enemies"):
		if not (enemy_node is Enemy):
			continue
		var enemy: Enemy = enemy_node as Enemy
		if enemy == null or not is_instance_valid(enemy) or enemy.is_dead:
			continue
		var enemy_id: int = enemy.get_instance_id()
		if float(_enemy_touch_cooldowns.get(enemy_id, 0.0)) > 0.0:
			continue
		var segment_data: Dictionary = _get_closest_segment_data(enemy.global_position)
		var closest_point: Vector2 = segment_data.get("closest_point", enemy.global_position)
		if enemy.global_position.distance_to(closest_point) > half_width + sweep_extra_width:
			continue
		var launch_direction: Vector2 = launch_direction_hint
		if owner_player != null and is_instance_valid(owner_player):
			var away_from_player: Vector2 = enemy.global_position - owner_player.global_position
			if away_from_player.length_squared() > 0.0001:
				launch_direction = away_from_player.normalized()
		_trigger_ballistic(enemy, launch_direction, sweep_bounce_distance, sweep_speed, sweep_ballistic_collision_damage_ratio, false)
		_enemy_touch_cooldowns[enemy_id] = enemy_touch_icd

func _trigger_ballistic(enemy: Enemy, direction: Vector2, custom_distance: float = -1.0, custom_speed: float = -1.0, custom_damage_ratio: float = -1.0, stop_on_hit: bool = true) -> void:
	var resolved_distance: float = bounce_distance if custom_distance < 0.0 else custom_distance
	var resolved_speed: float = bounce_speed if custom_speed < 0.0 else custom_speed
	var resolved_damage_ratio: float = ballistic_collision_damage_ratio if custom_damage_ratio < 0.0 else custom_damage_ratio
	var resolved_duration: float = max(bounce_duration, resolved_distance / max(1.0, resolved_speed))
	enemy.apply_status("stun", micro_stun_duration, 0.0, 1, 1.0)
	enemy.apply_phalanx_ballistic(
		direction,
		resolved_speed,
		resolved_distance,
		resolved_duration,
		source_attack,
		resolved_damage_ratio,
		owner_player,
		10.0,
		stop_on_hit
	)
	if enemy.has_method("set_flash_material"):
		enemy.set_flash_material()

func _get_closest_segment_data(point: Vector2) -> Dictionary:
	var best_distance: float = INF
	var best_data: Dictionary = {
		"closest_point": point,
		"tangent": Vector2.RIGHT,
		"normal": Vector2.UP,
	}
	for i: int in range(path_points.size() - 1):
		var a: Vector2 = path_points[i]
		var b: Vector2 = path_points[i + 1]
		var closest_point: Vector2 = Geometry2D.get_closest_point_to_segment(point, a, b)
		var distance_value: float = point.distance_to(closest_point)
		if distance_value >= best_distance:
			continue
		best_distance = distance_value
		var tangent: Vector2 = (b - a).normalized()
		if tangent.length_squared() <= 0.0001:
			tangent = Vector2.RIGHT
		var normal: Vector2 = Vector2(-tangent.y, tangent.x).normalized()
		best_data = {
			"closest_point": closest_point,
			"tangent": tangent,
			"normal": normal,
		}
	return best_data

func _resolve_launch_direction_away_from_player(player_position: Vector2) -> Vector2:
	var segment_data: Dictionary = _get_closest_segment_data(player_position)
	var closest_point: Vector2 = segment_data.get("closest_point", get_polyline_center())
	var normal: Vector2 = segment_data.get("normal", Vector2.RIGHT)
	if (player_position - closest_point).dot(normal) > 0.0:
		normal = -normal
	if normal.length_squared() <= 0.0001:
		var center_direction: Vector2 = get_polyline_center() - player_position
		if center_direction.length_squared() > 0.0001:
			return center_direction.normalized()
		return Vector2.RIGHT
	return normal.normalized()

func _decay_cooldowns(delta: float) -> void:
	_durability_cooldown_remaining = max(0.0, _durability_cooldown_remaining - delta)
	var expired_ids: Array[int] = []
	for enemy_id_variant: Variant in _enemy_touch_cooldowns.keys():
		var enemy_id: int = int(enemy_id_variant)
		var remaining: float = max(0.0, float(_enemy_touch_cooldowns.get(enemy_id, 0.0)) - delta)
		if remaining <= 0.0:
			expired_ids.append(enemy_id)
		else:
			_enemy_touch_cooldowns[enemy_id] = remaining
	for enemy_id: int in expired_ids:
		_enemy_touch_cooldowns.erase(enemy_id)

func _rebuild_visuals() -> void:
	if _outer_line == null:
		_outer_line = Line2D.new()
		_outer_line.top_level = true
		_outer_line.joint_mode = Line2D.LINE_JOINT_ROUND
		_outer_line.begin_cap_mode = Line2D.LINE_CAP_ROUND
		_outer_line.end_cap_mode = Line2D.LINE_CAP_ROUND
		_outer_line.antialiased = true
		_outer_line.z_index = 25
		add_child(_outer_line)
	if _inner_line == null:
		_inner_line = Line2D.new()
		_inner_line.top_level = true
		_inner_line.joint_mode = Line2D.LINE_JOINT_ROUND
		_inner_line.begin_cap_mode = Line2D.LINE_CAP_ROUND
		_inner_line.end_cap_mode = Line2D.LINE_CAP_ROUND
		_inner_line.antialiased = true
		_inner_line.z_index = 26
		add_child(_inner_line)

func _refresh_visuals() -> void:
	if _outer_line == null or _inner_line == null:
		return
	var pulse: float = 0.5 + 0.5 * sin((Time.get_ticks_msec() / 1000.0) * 5.0)
	_outer_line.points = path_points
	_inner_line.points = path_points
	_outer_line.width = lerp(half_width * 2.0 + 10.0, half_width * 2.0 + 16.0, pulse)
	_inner_line.width = lerp(half_width * 2.0, half_width * 2.0 + 4.0, pulse)
	if _sweeping_active:
		_outer_line.default_color = Color(0.62, 0.90, 1.0, 0.34)
		_inner_line.default_color = Color(0.90, 0.98, 1.0, 0.98)
	else:
		_outer_line.default_color = Color(0.26, 0.62, 1.0, 0.24)
		_inner_line.default_color = Color(0.76, 0.92, 1.0, 0.96)
