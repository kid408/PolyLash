extends Enemy
class_name EnemyGeoLocksmith

const LOCK_COUNT: int = 3
const LOCK_RADIUS: float = 22.0
const LOCK_SPAWN_RADIUS: float = 150.0
const LOCK_RESPAWN_COOLDOWN: float = 10.0
const UNLOCK_TRUE_DAMAGE_RATIO: float = 0.5
const UNLOCK_STUN_DURATION: float = 3.0

var _shield_active: bool = false
var _lock_respawn_timer: float = 1.0
var _lock_nodes: Array[Node2D] = []
var _shield_ring: Line2D = null
var _lock_feedback_cooldown: float = 0.0

func _ready() -> void:
	super._ready()
	_setup_shield_visual()
	_spawn_lock_nodes()

func _process(delta: float) -> void:
	if Global.game_paused or is_dead:
		return
	super._process(delta)
	_lock_feedback_cooldown = max(0.0, _lock_feedback_cooldown - delta)
	if not _shield_active:
		_lock_respawn_timer = max(0.0, _lock_respawn_timer - delta)
		if _lock_respawn_timer <= 0.0:
			_spawn_lock_nodes()
	_refresh_shield_visual()

func preprocess_incoming_damage(raw_damage: float, payload: Dictionary = {}) -> Dictionary:
	var result: Dictionary = super.preprocess_incoming_damage(raw_damage, payload)
	var damage_value: float = float(result.get("damage", raw_damage))
	var processed_payload: Dictionary = result.get("payload", payload.duplicate(true))
	if not _shield_active:
		return {"damage": damage_value, "payload": processed_payload}
	if _lock_feedback_cooldown <= 0.0:
		_lock_feedback_cooldown = 0.18
		Global.spawn_floating_text(global_position + Vector2(0, -18), "LOCKED", Color(0.42, 1.0, 0.88))
	return {"damage": 0.0, "payload": processed_payload}

func on_player_draw_release(player: PlayerBase, release_data: Dictionary) -> void:
	if not _shield_active:
		return
	var points: PackedVector2Array = _extract_points(release_data.get("points", PackedVector2Array()))
	if points.size() < 2:
		return
	var last_segment_index: int = -1
	for lock_node in _lock_nodes:
		if lock_node == null or not is_instance_valid(lock_node):
			return
		var touched_segment: int = _find_touch_segment(points, lock_node.global_position, LOCK_RADIUS, last_segment_index + 1)
		if touched_segment < 0:
			return
		last_segment_index = touched_segment
	_on_unlock_success(player)

func _setup_shield_visual() -> void:
	_shield_ring = Line2D.new()
	_shield_ring.closed = true
	_shield_ring.antialiased = true
	_shield_ring.width = 6.0
	_shield_ring.default_color = Color(0.42, 1.0, 0.88, 0.84)
	_shield_ring.z_index = 6
	add_child(_shield_ring)
	var points: PackedVector2Array = PackedVector2Array()
	for index: int in range(24):
		var angle: float = TAU * float(index) / 24.0
		points.append(Vector2.RIGHT.rotated(angle) * 48.0)
	_shield_ring.points = points

func _spawn_lock_nodes() -> void:
	_clear_lock_nodes()
	_shield_active = true
	_lock_respawn_timer = LOCK_RESPAWN_COOLDOWN
	var base_angle: float = randf() * TAU
	for index: int in range(LOCK_COUNT):
		var angle: float = base_angle + TAU * float(index) / float(LOCK_COUNT)
		var root: Area2D = Area2D.new()
		root.monitoring = false
		root.monitorable = true
		root.position = Vector2.RIGHT.rotated(angle) * LOCK_SPAWN_RADIUS
		add_child(root)

		var collision_shape: CollisionShape2D = CollisionShape2D.new()
		var circle_shape: CircleShape2D = CircleShape2D.new()
		circle_shape.radius = LOCK_RADIUS
		collision_shape.shape = circle_shape
		root.add_child(collision_shape)

		var ring: Line2D = Line2D.new()
		ring.closed = true
		ring.antialiased = true
		ring.width = 4.0
		ring.default_color = Color(0.52, 1.0, 0.92, 0.95)
		var points: PackedVector2Array = PackedVector2Array()
		for point_index: int in range(18):
			var point_angle: float = TAU * float(point_index) / 18.0
			points.append(Vector2.RIGHT.rotated(point_angle) * LOCK_RADIUS)
		ring.points = points
		root.add_child(ring)

		var label: Label = Label.new()
		label.text = str(index + 1)
		label.position = Vector2(-6.0, -12.0)
		label.add_theme_font_size_override("font_size", 18)
		label.modulate = Color(0.92, 1.0, 0.98, 1.0)
		root.add_child(label)
		_lock_nodes.append(root)

func _clear_lock_nodes() -> void:
	for lock_node in _lock_nodes:
		if lock_node != null and is_instance_valid(lock_node):
			lock_node.queue_free()
	_lock_nodes.clear()

func _refresh_shield_visual() -> void:
	if _shield_ring == null:
		return
	_shield_ring.visible = _shield_active
	if not _shield_active:
		return
	var pulse: float = 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.009)
	_shield_ring.width = lerp(5.0, 8.0, pulse)
	_shield_ring.modulate = Color(1.0, 1.0, 1.0, lerp(0.58, 0.90, pulse))

func _extract_points(points_variant: Variant) -> PackedVector2Array:
	var points: PackedVector2Array = PackedVector2Array()
	if points_variant is PackedVector2Array:
		return points_variant
	if points_variant is Array:
		for point_variant in points_variant:
			if point_variant is Vector2:
				points.append(point_variant)
	return points

func _find_touch_segment(points: PackedVector2Array, center: Vector2, radius: float, start_segment: int) -> int:
	for segment_index: int in range(start_segment, points.size() - 1):
		var closest: Vector2 = Geometry2D.get_closest_point_to_segment(center, points[segment_index], points[segment_index + 1])
		if center.distance_to(closest) <= radius:
			return segment_index
	return -1

func _on_unlock_success(player: PlayerBase) -> void:
	_shield_active = false
	_clear_lock_nodes()
	_lock_respawn_timer = LOCK_RESPAWN_COOLDOWN
	var true_damage: float = max(1.0, float(health_component.max_health) * UNLOCK_TRUE_DAMAGE_RATIO)
	health_component.take_damage(true_damage, {
		"source": player,
		"kind": "geo_locksmith_unlock",
		"damage_type": COMBAT_EVENT_TYPES.DamageType.TRUE_DAMAGE,
		"true_damage": true,
	})
	apply_status("stun", UNLOCK_STUN_DURATION, 0.0, 1, 1.0)
	Global.spawn_floating_text(global_position, "UNLOCK", Color(0.62, 1.0, 0.90))
