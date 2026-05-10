extends Node2D
class_name PhalanxPinballArena

@export var lifetime: float = 4.0
@export var initial_speed: float = 1500.0
@export var collision_damage_ratio: float = 1.0
@export var pair_hit_icd: float = 0.05
@export var enemy_radius: float = 24.0

var owner_player: PlayerBase = null
var source_attack: float = 40.0
var polygon_points: PackedVector2Array = PackedVector2Array()
var centroid: Vector2 = Vector2.ZERO
var remaining_lifetime: float = 0.0
var max_bounces: int = 2
var remaining_bounces: int = 2

var _fill: Polygon2D = null
var _border: Line2D = null
var _tracked_enemies: Dictionary = {}
var _pair_hit_cooldowns: Dictionary = {}

func setup(player_node: PlayerBase, polygon: PackedVector2Array, center: Vector2, attack_value: float, custom_lifetime: float = 4.0, bounce_limit: int = 2, custom_damage_ratio: float = 1.0) -> void:
	owner_player = player_node
	polygon_points = polygon.duplicate()
	centroid = center
	source_attack = max(1.0, attack_value)
	remaining_lifetime = max(0.1, custom_lifetime)
	max_bounces = max(2, bounce_limit)
	remaining_bounces = max_bounces
	collision_damage_ratio = max(0.25, custom_damage_ratio)

func _ready() -> void:
	add_to_group("phalanx_pinball_arenas")
	add_to_group("player_summoned_entity")
	if polygon_points.size() < 3:
		queue_free()
		return
	_rebuild_visuals()
	_refresh_visuals()
	_capture_initial_enemies()

func _exit_tree() -> void:
	_release_all_enemies()

func _process(delta: float) -> void:
	if polygon_points.size() < 3:
		queue_free()
		return
	remaining_lifetime = max(0.0, remaining_lifetime - delta)
	if remaining_lifetime <= 0.0:
		queue_free()
		return
	_decay_pair_hit_cooldowns(delta)
	_simulate_pinball(delta)
	_refresh_visuals()

func _capture_initial_enemies() -> void:
	for enemy_node: Node in get_tree().get_nodes_in_group("enemies"):
		if not (enemy_node is Enemy):
			continue
		var enemy: Enemy = enemy_node as Enemy
		if enemy == null or not is_instance_valid(enemy) or enemy.is_dead:
			continue
		if not Geometry2D.is_point_in_polygon(enemy.global_position, polygon_points):
			continue
		var direction: Vector2 = enemy.global_position - centroid
		if direction.length_squared() <= 0.0001:
			direction = Vector2.RIGHT.rotated(randf() * TAU)
		enemy.set_phalanx_motion_locked(true)
		_tracked_enemies[enemy.get_instance_id()] = {
			"enemy_ref": weakref(enemy),
			"velocity": direction.normalized() * initial_speed,
			"wall_icd": 0.0,
		}

func _release_all_enemies() -> void:
	for entry_variant: Variant in _tracked_enemies.values():
		if not (entry_variant is Dictionary):
			continue
		var entry: Dictionary = entry_variant
		var enemy_ref_variant: Variant = entry.get("enemy_ref", null)
		if enemy_ref_variant == null or not (enemy_ref_variant is WeakRef):
			continue
		var enemy_variant: Variant = (enemy_ref_variant as WeakRef).get_ref()
		if enemy_variant == null or not is_instance_valid(enemy_variant) or not (enemy_variant is Enemy):
			continue
		var enemy: Enemy = enemy_variant as Enemy
		enemy.set_phalanx_motion_locked(false)
	_tracked_enemies.clear()

func _simulate_pinball(delta: float) -> void:
	var expired_ids: Array[int] = []
	for enemy_id_variant: Variant in _tracked_enemies.keys():
		var enemy_id: int = int(enemy_id_variant)
		var entry_variant: Variant = _tracked_enemies.get(enemy_id, {})
		if not (entry_variant is Dictionary):
			expired_ids.append(enemy_id)
			continue
		var entry: Dictionary = entry_variant
		var enemy_ref_variant: Variant = entry.get("enemy_ref", null)
		if enemy_ref_variant == null or not (enemy_ref_variant is WeakRef):
			expired_ids.append(enemy_id)
			continue
		var enemy_variant: Variant = (enemy_ref_variant as WeakRef).get_ref()
		if enemy_variant == null or not is_instance_valid(enemy_variant) or not (enemy_variant is Enemy):
			expired_ids.append(enemy_id)
			continue
		var enemy: Enemy = enemy_variant as Enemy
		if enemy.is_dead:
			expired_ids.append(enemy_id)
			continue

		var velocity: Vector2 = entry.get("velocity", Vector2.ZERO)
		var wall_icd: float = max(0.0, float(entry.get("wall_icd", 0.0)) - delta)
		var move_result: Dictionary = _move_enemy_inside_arena(enemy, velocity, delta)
		entry["velocity"] = move_result.get("velocity", velocity)
		entry["wall_icd"] = wall_icd
		if bool(move_result.get("wall_hit", false)) and wall_icd <= 0.0:
			var damage_amount: float = max(1.0, source_attack * collision_damage_ratio)
			enemy.apply_modifier_damage(damage_amount, owner_player, {
				"kind": "phalanx_pinball_wall",
				"damage_type": "DMG_DIRECT",
				"skill_slot": "q",
				"space_skill_mode": "closed",
			})
			if enemy.has_method("set_flash_material"):
				enemy.set_flash_material()
			entry["wall_icd"] = pair_hit_icd
			_consume_bounce()
		_tracked_enemies[enemy_id] = entry

	for enemy_id: int in expired_ids:
		var entry_variant: Variant = _tracked_enemies.get(enemy_id, {})
		if entry_variant is Dictionary:
			var entry: Dictionary = entry_variant
			var enemy_ref_variant: Variant = entry.get("enemy_ref", null)
			if enemy_ref_variant is WeakRef:
				var enemy_variant: Variant = (enemy_ref_variant as WeakRef).get_ref()
				if enemy_variant != null and is_instance_valid(enemy_variant) and enemy_variant is Enemy:
					(enemy_variant as Enemy).set_phalanx_motion_locked(false)
		_tracked_enemies.erase(enemy_id)

	_process_enemy_collisions()

func _move_enemy_inside_arena(enemy: Enemy, velocity: Vector2, delta: float) -> Dictionary:
	var result: Dictionary = {
		"velocity": velocity,
		"wall_hit": false,
	}
	var start_pos: Vector2 = enemy.global_position
	var desired_end: Vector2 = start_pos + velocity * delta
	if Geometry2D.is_point_in_polygon(desired_end, polygon_points):
		enemy.global_position = desired_end
		return result

	var hit_info: Dictionary = _find_polygon_intersection(start_pos, desired_end)
	if not bool(hit_info.get("hit", false)):
		enemy.global_position = start_pos
		result["velocity"] = -velocity
		result["wall_hit"] = true
		return result

	var hit_point: Vector2 = hit_info.get("point", start_pos)
	var normal: Vector2 = hit_info.get("normal", Vector2.UP)
	var reflected_velocity: Vector2 = velocity.bounce(normal).normalized() * initial_speed
	enemy.global_position = hit_point + reflected_velocity.normalized() * 6.0
	result["velocity"] = reflected_velocity
	result["wall_hit"] = true
	return result

func _find_polygon_intersection(from_pos: Vector2, to_pos: Vector2) -> Dictionary:
	var nearest_distance: float = INF
	var best_result: Dictionary = {"hit": false}
	for i: int in range(polygon_points.size()):
		var a: Vector2 = polygon_points[i]
		var b: Vector2 = polygon_points[(i + 1) % polygon_points.size()]
		var hit_variant: Variant = Geometry2D.segment_intersects_segment(from_pos, to_pos, a, b)
		if hit_variant == null or not (hit_variant is Vector2):
			continue
		var hit_point: Vector2 = hit_variant
		var distance_value: float = from_pos.distance_to(hit_point)
		if distance_value >= nearest_distance:
			continue
		nearest_distance = distance_value
		var tangent: Vector2 = (b - a).normalized()
		if tangent.length_squared() <= 0.0001:
			tangent = Vector2.RIGHT
		var normal: Vector2 = Vector2(-tangent.y, tangent.x).normalized()
		if (centroid - hit_point).dot(normal) < 0.0:
			normal = -normal
		best_result = {
			"hit": true,
			"point": hit_point,
			"normal": normal,
		}
	return best_result

func _process_enemy_collisions() -> void:
	var enemy_ids: Array[int] = []
	for enemy_id_variant: Variant in _tracked_enemies.keys():
		enemy_ids.append(int(enemy_id_variant))
	for i: int in range(enemy_ids.size()):
		for j: int in range(i + 1, enemy_ids.size()):
			var a_id: int = enemy_ids[i]
			var b_id: int = enemy_ids[j]
			var pair_key: String = _pair_key(a_id, b_id)
			if float(_pair_hit_cooldowns.get(pair_key, 0.0)) > 0.0:
				continue
			var enemy_a: Enemy = _resolve_tracked_enemy(a_id)
			var enemy_b: Enemy = _resolve_tracked_enemy(b_id)
			if enemy_a == null or enemy_b == null:
				continue
			var distance_value: float = enemy_a.global_position.distance_to(enemy_b.global_position)
			if distance_value > enemy_radius * 2.0:
				continue
			var collision_normal: Vector2 = (enemy_a.global_position - enemy_b.global_position).normalized()
			if collision_normal.length_squared() <= 0.0001:
				collision_normal = Vector2.RIGHT.rotated(randf() * TAU)
			var damage_amount: float = max(1.0, source_attack * collision_damage_ratio)
			enemy_a.apply_modifier_damage(damage_amount, owner_player, {
				"kind": "phalanx_pinball_enemy",
				"damage_type": "DMG_DIRECT",
				"skill_slot": "q",
				"space_skill_mode": "closed",
			})
			enemy_b.apply_modifier_damage(damage_amount, owner_player, {
				"kind": "phalanx_pinball_enemy",
				"damage_type": "DMG_DIRECT",
				"skill_slot": "q",
				"space_skill_mode": "closed",
			})
			enemy_a.global_position += collision_normal * 8.0
			enemy_b.global_position -= collision_normal * 8.0
			var entry_a: Dictionary = _tracked_enemies.get(a_id, {})
			var entry_b: Dictionary = _tracked_enemies.get(b_id, {})
			var velocity_a: Vector2 = entry_a.get("velocity", Vector2.ZERO)
			var velocity_b: Vector2 = entry_b.get("velocity", Vector2.ZERO)
			entry_a["velocity"] = velocity_a.bounce(collision_normal).normalized() * initial_speed
			entry_b["velocity"] = velocity_b.bounce(-collision_normal).normalized() * initial_speed
			_tracked_enemies[a_id] = entry_a
			_tracked_enemies[b_id] = entry_b
			_pair_hit_cooldowns[pair_key] = pair_hit_icd
			_consume_bounce()
			if enemy_a.has_method("set_flash_material"):
				enemy_a.set_flash_material()
			if enemy_b.has_method("set_flash_material"):
				enemy_b.set_flash_material()

func _resolve_tracked_enemy(enemy_id: int) -> Enemy:
	var entry_variant: Variant = _tracked_enemies.get(enemy_id, {})
	if not (entry_variant is Dictionary):
		return null
	var entry: Dictionary = entry_variant
	var enemy_ref_variant: Variant = entry.get("enemy_ref", null)
	if enemy_ref_variant == null or not (enemy_ref_variant is WeakRef):
		return null
	var enemy_variant: Variant = (enemy_ref_variant as WeakRef).get_ref()
	if enemy_variant == null or not is_instance_valid(enemy_variant) or not (enemy_variant is Enemy):
		return null
	return enemy_variant as Enemy

func _pair_key(a_id: int, b_id: int) -> String:
	var low: int = min(a_id, b_id)
	var high: int = max(a_id, b_id)
	return "%d:%d" % [low, high]

func _decay_pair_hit_cooldowns(delta: float) -> void:
	var expired_keys: Array[String] = []
	for key_variant: Variant in _pair_hit_cooldowns.keys():
		var key: String = str(key_variant)
		var remaining: float = max(0.0, float(_pair_hit_cooldowns.get(key, 0.0)) - delta)
		if remaining <= 0.0:
			expired_keys.append(key)
		else:
			_pair_hit_cooldowns[key] = remaining
	for key: String in expired_keys:
		_pair_hit_cooldowns.erase(key)

func _consume_bounce() -> void:
	remaining_bounces = max(0, remaining_bounces - 1)
	if remaining_bounces <= 0:
		queue_free()

func _rebuild_visuals() -> void:
	if _fill == null:
		_fill = Polygon2D.new()
		_fill.z_index = 22
		add_child(_fill)
	if _border == null:
		_border = Line2D.new()
		_border.closed = true
		_border.antialiased = true
		_border.z_index = 23
		add_child(_border)

func _refresh_visuals() -> void:
	if _fill == null or _border == null:
		return
	_fill.polygon = polygon_points
	_fill.color = Color(0.30, 0.60, 1.0, 0.16)
	_border.points = polygon_points
	var pulse: float = 0.5 + 0.5 * sin((Time.get_ticks_msec() / 1000.0) * 6.0)
	_border.width = lerp(8.0, 12.0, pulse)
	_border.default_color = Color(0.82, 0.94, 1.0, lerp(0.76, 1.0, pulse))
