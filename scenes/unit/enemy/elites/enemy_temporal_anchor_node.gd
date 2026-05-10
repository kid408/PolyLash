extends Enemy
class_name EnemyTemporalAnchorNode

signal anchor_destroyed(anchor: EnemyTemporalAnchorNode)

var _remaining_time: float = 0.0
var _ring: Line2D = null
var _fill: Polygon2D = null

func _ready() -> void:
	super._ready()
	can_move = false
	speed = 0.0
	damage = 0.0
	if contact_hitbox != null and is_instance_valid(contact_hitbox):
		contact_hitbox.monitoring = false
		contact_hitbox.monitorable = false
	_build_visuals()

func _process(_delta: float) -> void:
	if Global.game_paused or is_dead:
		return
	_refresh_visuals()

func destroy_enemy() -> void:
	if is_dead:
		return
	is_dead = true
	can_move = false
	anchor_destroyed.emit(self)
	queue_free()

func set_remaining_time(value: float) -> void:
	_remaining_time = max(0.0, value)
	_refresh_visuals()

func _build_visuals() -> void:
	_fill = Polygon2D.new()
	_fill.z_index = 10
	add_child(_fill)

	_ring = Line2D.new()
	_ring.closed = true
	_ring.antialiased = true
	_ring.width = 6.0
	_ring.z_index = 11
	add_child(_ring)

	var points: PackedVector2Array = PackedVector2Array()
	for index: int in range(24):
		var angle: float = TAU * float(index) / 24.0
		points.append(Vector2.RIGHT.rotated(angle) * 24.0)
	_fill.polygon = points
	_ring.points = points
	_refresh_visuals()

func _refresh_visuals() -> void:
	if _fill == null or _ring == null:
		return
	var time_ratio: float = clamp(_remaining_time / 4.0, 0.0, 1.0)
	var pulse: float = 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.012)
	_fill.color = Color(0.48, 0.88, 1.0, lerp(0.10, 0.26, pulse))
	_ring.default_color = Color(0.86, 0.96, 1.0, lerp(0.52, 0.92, pulse))
	_ring.width = lerp(4.0, 9.0, 1.0 - time_ratio)
	_fill.scale = Vector2.ONE * lerp(0.85, 1.20, pulse)
