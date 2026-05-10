extends Enemy
class_name EnemyMagController

const AURA_RADIUS: float = 400.0
const FEEDBACK_ICD: float = 0.35

var _aura_fill: Polygon2D = null
var _aura_ring: Line2D = null
var _feedback_cooldown: float = 0.0
var _screen_warning_layer: CanvasLayer = null
var _screen_warning_edges: Array[ColorRect] = []

func _ready() -> void:
	super._ready()
	_setup_aura_visuals()
	_setup_screen_warning()

func _process(delta: float) -> void:
	if Global.game_paused or is_dead:
		return
	super._process(delta)
	_feedback_cooldown = max(0.0, _feedback_cooldown - delta)
	_refresh_aura_visuals()
	_refresh_screen_warning()

func _exit_tree() -> void:
	if _screen_warning_layer != null and is_instance_valid(_screen_warning_layer):
		_screen_warning_layer.queue_free()

func modify_player_dash_direction(player: PlayerBase, requested_direction: Vector2) -> Dictionary:
	if player == null or not is_instance_valid(player):
		return {"direction": requested_direction}
	if player.global_position.distance_to(global_position) > AURA_RADIUS:
		return {"direction": requested_direction}
	if _feedback_cooldown <= 0.0:
		_feedback_cooldown = FEEDBACK_ICD
		Global.spawn_floating_text(player.global_position, "REVERSE", Color(0.42, 0.96, 1.0))
	return {"direction": -requested_direction}

func _setup_aura_visuals() -> void:
	_aura_fill = Polygon2D.new()
	_aura_fill.color = Color(0.18, 0.78, 1.0, 0.12)
	_aura_fill.z_index = 4
	add_child(_aura_fill)

	_aura_ring = Line2D.new()
	_aura_ring.closed = true
	_aura_ring.width = 5.0
	_aura_ring.default_color = Color(0.34, 0.92, 1.0, 0.82)
	_aura_ring.antialiased = true
	_aura_ring.z_index = 5
	add_child(_aura_ring)

	var points: PackedVector2Array = PackedVector2Array()
	for index: int in range(40):
		var angle: float = TAU * float(index) / 40.0
		points.append(Vector2.RIGHT.rotated(angle) * AURA_RADIUS)
	_aura_fill.polygon = points
	_aura_ring.points = points

func _refresh_aura_visuals() -> void:
	if _aura_fill == null or _aura_ring == null:
		return
	var player_inside: bool = _is_player_inside_aura()
	var pulse: float = 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.008)
	_aura_ring.width = lerp(4.0, 8.0, pulse)
	_aura_fill.color = Color(0.18, 0.78, 1.0, 0.10 if not player_inside else 0.18)
	_aura_ring.modulate = Color(1.0, 1.0, 1.0, lerp(0.60, 0.92, pulse))

func _setup_screen_warning() -> void:
	_screen_warning_layer = CanvasLayer.new()
	_screen_warning_layer.layer = 95
	get_tree().current_scene.add_child(_screen_warning_layer)
	_screen_warning_edges.clear()
	_add_warning_edge("Top", 0.0, 0.0, 1.0, 0.0, 0.0, 34.0, 0.0, 0.0)
	_add_warning_edge("Bottom", 0.0, 1.0, 1.0, 1.0, 0.0, 0.0, 0.0, -34.0)
	_add_warning_edge("Left", 0.0, 0.0, 0.0, 1.0, 0.0, 0.0, 34.0, 0.0)
	_add_warning_edge("Right", 1.0, 0.0, 1.0, 1.0, -34.0, 0.0, 0.0, 0.0)

func _refresh_screen_warning() -> void:
	if _screen_warning_edges.is_empty():
		return
	var alpha: float = 0.0
	if _is_player_inside_aura():
		var pulse: float = 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.010)
		alpha = lerp(0.08, 0.20, pulse)
	for edge: ColorRect in _screen_warning_edges:
		if edge == null or not is_instance_valid(edge):
			continue
		edge.color = Color(0.08, 0.54, 0.72, alpha)

func _add_warning_edge(
	name: String,
	anchor_left: float,
	anchor_top: float,
	anchor_right: float,
	anchor_bottom: float,
	offset_left: float,
	offset_top: float,
	offset_right: float,
	offset_bottom: float
) -> void:
	if _screen_warning_layer == null:
		return
	var edge: ColorRect = ColorRect.new()
	edge.name = name
	edge.anchor_left = anchor_left
	edge.anchor_top = anchor_top
	edge.anchor_right = anchor_right
	edge.anchor_bottom = anchor_bottom
	edge.offset_left = offset_left
	edge.offset_top = offset_top
	edge.offset_right = offset_right
	edge.offset_bottom = offset_bottom
	edge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	edge.color = Color(0.08, 0.54, 0.72, 0.0)
	_screen_warning_layer.add_child(edge)
	_screen_warning_edges.append(edge)

func _is_player_inside_aura() -> bool:
	var player: PlayerBase = Global.player if is_instance_valid(Global.player) else null
	if player == null:
		return false
	return player.global_position.distance_to(global_position) <= AURA_RADIUS
