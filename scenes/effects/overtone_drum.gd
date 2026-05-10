extends Node2D
class_name OvertoneDrum

@export var lifetime: float = 3.0
@export var trigger_radius: float = 100.0
@export var stun_duration: float = 0.8
@export var damage_ratio: float = 3.0
@export var squad_energy_restore: float = 10.0
@export var knockback_distance: float = 90.0
@export var shockwave_expand_time: float = 0.10
@export var shockwave_return_time: float = 0.12

var owner_player: PlayerBase = null
var source_attack: float = 40.0
var polygon_points: PackedVector2Array = PackedVector2Array()
var centroid: Vector2 = Vector2.ZERO

var _fill: Polygon2D = null
var _border: Line2D = null
var _connected_players: Dictionary = {}
var _last_dash_positions: Dictionary = {}
var _remaining_lifetime: float = 0.0
var _dash_triggered: Dictionary = {}

func setup(player_node: PlayerBase, polygon: PackedVector2Array, center: Vector2, custom_lifetime: float = 3.0) -> void:
	owner_player = player_node
	if is_instance_valid(owner_player):
		source_attack = max(1.0, owner_player.damage)
	polygon_points = polygon.duplicate()
	centroid = center
	_remaining_lifetime = max(0.1, custom_lifetime)

func _ready() -> void:
	add_to_group("overtone_drums")
	add_to_group("player_summoned_entity")
	_rebuild_visuals()
	_refresh_visuals()

func _process(delta: float) -> void:
	_remaining_lifetime = max(0.0, _remaining_lifetime - delta)
	if _remaining_lifetime <= 0.0:
		queue_free()
		return
	_ensure_player_connections()
	_refresh_visuals()

func _ensure_player_connections() -> void:
	for player_node: Node in get_tree().get_nodes_in_group("player"):
		if not (player_node is PlayerBase):
			continue
		var player: PlayerBase = player_node as PlayerBase
		if player == null or not is_instance_valid(player):
			continue
		var player_key: int = player.get_instance_id()
		if _connected_players.has(player_key):
			continue
		player.dash_active.connect(_on_player_dash_active)
		player.dash_finished.connect(_on_player_dash_finished)
		_connected_players[player_key] = weakref(player)

func _on_player_dash_active(player_id: String, current_pos: Vector2, _direction: Vector2, _normalized_time: float) -> void:
	if polygon_points.size() < 3:
		return
	var dash_key: String = player_id
	var previous_pos: Vector2 = current_pos
	if _last_dash_positions.has(dash_key):
		previous_pos = _last_dash_positions[dash_key]
	_last_dash_positions[dash_key] = current_pos

	if bool(_dash_triggered.get(dash_key, false)):
		return
	if Geometry2D.is_point_in_polygon(current_pos, polygon_points) or _segment_intersects_polygon(previous_pos, current_pos):
		_dash_triggered[dash_key] = true
		_trigger_drum()

func _on_player_dash_finished(player_id: String, _end_pos: Vector2, _direction: Vector2) -> void:
	_last_dash_positions.erase(player_id)
	_dash_triggered.erase(player_id)

func _segment_intersects_polygon(from_pos: Vector2, to_pos: Vector2) -> bool:
	for i: int in range(polygon_points.size()):
		var a: Vector2 = polygon_points[i]
		var b: Vector2 = polygon_points[(i + 1) % polygon_points.size()]
		var hit_variant: Variant = Geometry2D.segment_intersects_segment(from_pos, to_pos, a, b)
		if hit_variant != null and hit_variant is Vector2:
			return true
	return false

func _trigger_drum() -> void:
	var shockwave_polygon: PackedVector2Array = _build_shockwave_polygon()
	_launch_enemies(shockwave_polygon)
	_restore_squad_energy(squad_energy_restore)
	if is_instance_valid(Global.player) and Global.player.has_method("reset_dash_cooldown"):
		Global.player.reset_dash_cooldown()
	_spawn_burst_visual(shockwave_polygon)
	Global.spawn_floating_text(centroid, "RESONANCE", Color(1.0, 0.88, 0.54))

func _launch_enemies(shockwave_polygon: PackedVector2Array) -> void:
	if shockwave_polygon.size() < 3:
		return
	for enemy_node: Node in get_tree().get_nodes_in_group("enemies"):
		if not (enemy_node is Enemy):
			continue
		var enemy: Enemy = enemy_node as Enemy
		if enemy == null or not is_instance_valid(enemy) or enemy.is_dead:
			continue
		if not Geometry2D.is_point_in_polygon(enemy.global_position, shockwave_polygon):
			continue
		enemy.apply_modifier_damage(
			source_attack * damage_ratio,
			owner_player,
			{
				"kind": "overtone_drum_roll",
				"source_slot": "space",
				"damage_type": "DMG_AOE",
				"skill_slot": "q",
				"space_skill_mode": "closed",
			}
		)
		enemy.apply_status("stun", stun_duration, 0.0, 1, 1.0)
		var push_direction: Vector2 = enemy.global_position - centroid
		if push_direction.length_squared() <= 0.0001:
			push_direction = Vector2.RIGHT.rotated(randf() * TAU)
		enemy.global_position += push_direction.normalized() * knockback_distance
		if enemy.has_method("set_flash_material"):
			enemy.set_flash_material()

func _build_shockwave_polygon() -> PackedVector2Array:
	var expanded_polygon: PackedVector2Array = PackedVector2Array()
	if polygon_points.size() < 3:
		return expanded_polygon
	for point: Vector2 in polygon_points:
		var offset: Vector2 = point - centroid
		var direction: Vector2 = offset.normalized()
		if direction.length_squared() <= 0.0001:
			direction = Vector2.RIGHT
		expanded_polygon.append(point + direction * trigger_radius)
	return expanded_polygon

func _restore_squad_energy(amount: float) -> void:
	if amount <= 0.0:
		return
	var active_player_id: String = Global.get_current_player_id() if Global.has_method("get_current_player_id") else ""
	for player_id_variant: Variant in Global.selected_player_ids:
		var player_id: String = str(player_id_variant).strip_edges()
		if player_id.is_empty():
			continue
		var state: Dictionary = Global.get_player_state(player_id)
		if state.is_empty():
			continue
		var max_energy_value: float = float(state.get("max_energy", amount))
		var current_energy_value: float = float(state.get("energy", 0.0))
		state["energy"] = min(max_energy_value, current_energy_value + amount)
		Global.player_states[player_id] = state
		var index: int = Global.selected_player_ids.find(player_id)
		if index >= 0:
			Global.notify_squad_state_changed(index)
		if player_id == active_player_id and is_instance_valid(Global.player):
			Global.player.energy = float(state.get("energy", Global.player.energy))
			Global.player.update_ui_signals()

func _rebuild_visuals() -> void:
	if _fill == null:
		_fill = Polygon2D.new()
		_fill.z_index = 24
		add_child(_fill)
	if _border == null:
		_border = Line2D.new()
		_border.closed = true
		_border.antialiased = true
		_border.z_index = 25
		add_child(_border)

func _refresh_visuals() -> void:
	if _fill == null or _border == null:
		return
	_fill.polygon = polygon_points
	_fill.color = Color(0.92, 0.72, 0.22, 0.18)
	_border.points = polygon_points
	var pulse: float = 0.5 + 0.5 * sin((Time.get_ticks_msec() / 1000.0) * 4.0)
	_border.width = lerp(7.0, 11.0, pulse)
	_border.default_color = Color(1.0, 0.96, 0.78, lerp(0.65, 0.92, pulse))

func _spawn_burst_visual(shockwave_polygon: PackedVector2Array) -> void:
	if shockwave_polygon.size() < 3:
		return
	var root: Node2D = Node2D.new()
	root.top_level = true
	root.global_position = centroid
	root.z_index = 28

	var base_local_polygon: PackedVector2Array = _polygon_to_local(polygon_points)
	var shockwave_local_polygon: PackedVector2Array = _polygon_to_local(shockwave_polygon)

	var fill: Polygon2D = Polygon2D.new()
	fill.polygon = base_local_polygon
	fill.color = Color(1.0, 0.86, 0.42, 0.18)
	fill.z_index = 0
	root.add_child(fill)

	var border: Line2D = Line2D.new()
	border.closed = true
	border.antialiased = true
	border.width = 12.0
	border.default_color = Color(1.0, 0.96, 0.82, 0.95)
	border.points = base_local_polygon
	border.z_index = 1
	root.add_child(border)

	get_tree().current_scene.add_child(root)
	var tween: Tween = root.create_tween()
	tween.tween_method(
		Callable(self, "_set_shockwave_visual_strength").bind(fill, border, base_local_polygon, shockwave_local_polygon),
		0.0,
		1.0,
		shockwave_expand_time
	)
	tween.tween_method(
		Callable(self, "_set_shockwave_visual_strength").bind(fill, border, base_local_polygon, shockwave_local_polygon),
		1.0,
		0.0,
		shockwave_return_time
	)
	tween.tween_property(root, "modulate:a", 0.0, 0.08)
	tween.finished.connect(root.queue_free)

func _polygon_to_local(points: PackedVector2Array) -> PackedVector2Array:
	var local_points: PackedVector2Array = PackedVector2Array()
	for point: Vector2 in points:
		local_points.append(point - centroid)
	return local_points

func _set_shockwave_visual_strength(strength: float, fill: Polygon2D, border: Line2D, base_polygon: PackedVector2Array, shockwave_polygon: PackedVector2Array) -> void:
	if not is_instance_valid(fill) or not is_instance_valid(border):
		return
	var clamped_strength: float = clamp(strength, 0.0, 1.0)
	var interpolated_polygon: PackedVector2Array = PackedVector2Array()
	var point_count: int = min(base_polygon.size(), shockwave_polygon.size())
	for index: int in range(point_count):
		interpolated_polygon.append(base_polygon[index].lerp(shockwave_polygon[index], clamped_strength))
	fill.polygon = interpolated_polygon
	border.points = interpolated_polygon
	fill.color = Color(1.0, 0.84, 0.36, lerp(0.16, 0.28, clamped_strength))
	border.width = lerp(10.0, 16.0, clamped_strength)
	border.default_color = Color(1.0, 0.96, 0.82, lerp(0.84, 1.0, clamped_strength))
