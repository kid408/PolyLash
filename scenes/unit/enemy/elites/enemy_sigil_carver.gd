extends Enemy
class_name EnemySigilCarver

const RING_RADIUS: float = 100.0
const RING_INTERVAL: float = 8.0
const RING_LIFETIME: float = 3.2
const AREA_TOLERANCE_RATIO: float = 0.35
const PERFECT_DAMAGE_RATIO: float = 5.0
const FAILURE_DAMAGE_RATIO: float = 1.4

var _ring_cooldown_remaining: float = 2.0
var _active_ring_root: Node2D = null
var _active_ring_center: Vector2 = Vector2.ZERO
var _active_ring_time_remaining: float = 0.0

func _ready() -> void:
	super._ready()

func _process(delta: float) -> void:
	if Global.game_paused or is_dead:
		return
	super._process(delta)
	if _active_ring_root != null and is_instance_valid(_active_ring_root):
		_active_ring_time_remaining = max(0.0, _active_ring_time_remaining - delta)
		_refresh_ring_visual()
		if _active_ring_time_remaining <= 0.0:
			_fail_ring()
		return
	_ring_cooldown_remaining = max(0.0, _ring_cooldown_remaining - delta)
	if _ring_cooldown_remaining <= 0.0:
		_spawn_ring()

func on_player_draw_release(player: PlayerBase, release_data: Dictionary) -> void:
	if _active_ring_root == null or not is_instance_valid(_active_ring_root):
		return
	if not bool(release_data.get("is_closed", false)):
		return
	var centroid_variant: Variant = release_data.get("centroid", Vector2.ZERO)
	var centroid: Vector2 = centroid_variant if centroid_variant is Vector2 else Vector2.ZERO
	var approx_area: float = float(release_data.get("approx_area", 0.0))
	if centroid.distance_to(_active_ring_center) > RING_RADIUS:
		return
	var ring_area: float = PI * RING_RADIUS * RING_RADIUS
	if ring_area <= 0.0:
		return
	if abs(approx_area - ring_area) / ring_area > AREA_TOLERANCE_RATIO:
		return
	_perfect_ring(player)

func _spawn_ring() -> void:
	_ring_cooldown_remaining = RING_INTERVAL
	_active_ring_time_remaining = RING_LIFETIME
	var player: PlayerBase = Global.player if is_instance_valid(Global.player) else null
	var center: Vector2 = global_position
	if player != null:
		center = player.global_position + Vector2.RIGHT.rotated(randf() * TAU) * randf_range(60.0, 140.0)
	_active_ring_center = center

	_active_ring_root = Node2D.new()
	_active_ring_root.top_level = true
	_active_ring_root.global_position = center
	_active_ring_root.z_index = 18
	get_tree().current_scene.add_child(_active_ring_root)

	var fill: Polygon2D = Polygon2D.new()
	fill.name = "Fill"
	fill.color = Color(1.0, 0.24, 0.38, 0.10)
	_active_ring_root.add_child(fill)

	var ring: Line2D = Line2D.new()
	ring.name = "Ring"
	ring.closed = true
	ring.antialiased = true
	ring.width = 6.0
	ring.default_color = Color(1.0, 0.42, 0.56, 0.92)
	_active_ring_root.add_child(ring)

	var points: PackedVector2Array = PackedVector2Array()
	for index: int in range(28):
		var angle: float = TAU * float(index) / 28.0
		points.append(Vector2.RIGHT.rotated(angle) * RING_RADIUS)
	fill.polygon = points
	ring.points = points
	Global.spawn_floating_text(center, "SIGIL", Color(1.0, 0.54, 0.62))

func _refresh_ring_visual() -> void:
	if _active_ring_root == null or not is_instance_valid(_active_ring_root):
		return
	var fill: Polygon2D = _active_ring_root.get_node_or_null("Fill") as Polygon2D
	var ring: Line2D = _active_ring_root.get_node_or_null("Ring") as Line2D
	if fill == null or ring == null:
		return
	var pulse: float = 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.010)
	var life_ratio: float = clamp(_active_ring_time_remaining / RING_LIFETIME, 0.0, 1.0)
	fill.color = Color(1.0, 0.24, 0.38, lerp(0.06, 0.18, pulse))
	ring.width = lerp(4.0, 10.0, 1.0 - life_ratio)
	ring.modulate = Color(1.0, 1.0, 1.0, lerp(0.58, 0.96, pulse))

func _perfect_ring(player: PlayerBase) -> void:
	for enemy_node in get_tree().get_nodes_in_group("enemies"):
		if not (enemy_node is Enemy):
			continue
		var enemy: Enemy = enemy_node as Enemy
		if enemy == null or not is_instance_valid(enemy) or enemy.is_dead:
			continue
		if enemy.global_position.distance_to(_active_ring_center) > RING_RADIUS:
			continue
		enemy.health_component.take_damage(max(1.0, player.damage * PERFECT_DAMAGE_RATIO), {
			"source": player,
			"kind": "sigil_carver_perfect",
			"damage_type": COMBAT_EVENT_TYPES.DamageType.TRUE_DAMAGE,
			"true_damage": true,
		})
	_clear_ring()
	Global.spawn_floating_text(_active_ring_center, "PERFECT", Color(1.0, 0.82, 0.62))

func _fail_ring() -> void:
	var player: PlayerBase = Global.player if is_instance_valid(Global.player) else null
	if player != null and player.global_position.distance_to(_active_ring_center) <= RING_RADIUS:
		player.take_damage(max(1.0, damage * FAILURE_DAMAGE_RATIO), {
			"source": self,
			"kind": "sigil_carver_fail",
			"damage_type": COMBAT_EVENT_TYPES.DamageType.AOE,
			"source_position": _active_ring_center,
		})
	_clear_ring()

func _clear_ring() -> void:
	if _active_ring_root != null and is_instance_valid(_active_ring_root):
		_active_ring_root.queue_free()
	_active_ring_root = null
	_active_ring_time_remaining = 0.0
