extends Area2D
class_name AssistParasiteResidue

var radius: float = 50.0
var lifetime: float = 1.0
var slow_ratio: float = 0.20
var slow_duration: float = 2.0

var _life_timer: float = 0.0
var _ring: Line2D = null
var _fill: Polygon2D = null

func setup(effect_radius: float, effect_lifetime: float, effect_slow_ratio: float, effect_slow_duration: float) -> void:
	radius = effect_radius
	lifetime = effect_lifetime
	slow_ratio = effect_slow_ratio
	slow_duration = effect_slow_duration
	_life_timer = lifetime
	_rebuild_visual()

func _ready() -> void:
	add_to_group("player_skill_effects")
	collision_layer = 0
	collision_mask = 0
	_life_timer = lifetime
	_rebuild_visual()

func _process(delta: float) -> void:
	_life_timer -= delta
	if _life_timer <= 0.0:
		queue_free()
		return
	_apply_light_parasite()
	_update_visual(delta)

func _apply_light_parasite() -> void:
	for enemy_node in get_tree().get_nodes_in_group("enemies"):
		if not (enemy_node is Enemy):
			continue
		var enemy: Enemy = enemy_node as Enemy
		if not is_instance_valid(enemy) or enemy.is_dead:
			continue
		if enemy.global_position.distance_to(global_position) > radius:
			continue
		enemy.apply_status("slow", slow_duration, slow_ratio, 1, 1.0)

func _rebuild_visual() -> void:
	if _fill == null:
		_fill = Polygon2D.new()
		_fill.color = Color(0.38, 0.92, 0.46, 0.18)
		_fill.z_index = 20
		add_child(_fill)
	if _ring == null:
		_ring = Line2D.new()
		_ring.closed = true
		_ring.width = 5.0
		_ring.default_color = Color(0.66, 1.0, 0.72, 0.28)
		_ring.z_index = 21
		_ring.antialiased = true
		add_child(_ring)

	var points: PackedVector2Array = PackedVector2Array()
	for i in range(25):
		var angle: float = (float(i) / 24.0) * TAU
		points.append(Vector2.RIGHT.rotated(angle) * radius)
	_fill.polygon = points
	_ring.points = points

func _update_visual(delta: float) -> void:
	if _ring == null or _fill == null:
		return
	var normalized_time: float = 1.0 - (_life_timer / max(0.001, lifetime))
	var pulse: float = 0.5 + 0.5 * sin((normalized_time + delta) * TAU * 3.0)
	_ring.width = lerp(4.0, 7.0, pulse)
	_ring.modulate = Color(1.0, 1.0, 1.0, lerp(0.12, 0.28, 1.0 - normalized_time))
	_fill.modulate = Color(1.0, 1.0, 1.0, lerp(0.08, 0.18, 1.0 - normalized_time))