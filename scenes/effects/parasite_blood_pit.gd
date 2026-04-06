extends Node2D
class_name ParasiteBloodPit

@export var radius: float = 60.0
@export var duration: float = 3.0
@export var damage_taken_bonus: float = 0.15
@export var slow_ratio: float = 0.15

var _remaining_time: float = 0.0
var _source_key: String = ""
var _tracked_enemies: Dictionary = {}
var _fill: Polygon2D = null
var _ring: Line2D = null

func _ready() -> void:
	_remaining_time = duration
	_source_key = "pit_%s_%d" % [name, get_instance_id()]
	_ensure_visuals()
	_refresh_visuals()

func setup(pit_radius: float, pit_duration: float, bonus: float, slow: float) -> void:
	radius = pit_radius
	duration = pit_duration
	damage_taken_bonus = bonus
	slow_ratio = slow

func _process(delta: float) -> void:
	_remaining_time = max(0.0, _remaining_time - delta)
	_refresh_tracked_enemies()
	_animate_visuals(delta)
	if _remaining_time <= 0.0:
		_clear_tracked_enemies()
		queue_free()

func _ensure_visuals() -> void:
	if is_instance_valid(_fill) and is_instance_valid(_ring):
		return

	_fill = Polygon2D.new()
	_fill.name = "Fill"
	_fill.z_index = -2
	add_child(_fill)

	_ring = Line2D.new()
	_ring.name = "Ring"
	_ring.closed = true
	_ring.width = 6.0
	_ring.z_index = -1
	_ring.default_color = Color(0.55, 1.0, 0.48, 0.9)
	add_child(_ring)

func _refresh_visuals() -> void:
	if not is_instance_valid(_fill) or not is_instance_valid(_ring):
		return
	var polygon := PackedVector2Array([Vector2.ZERO])
	var ring_points := PackedVector2Array()
	var segments: int = 28
	for i in range(segments + 1):
		var angle := (float(i) / float(segments)) * TAU
		var point := Vector2.RIGHT.rotated(angle) * radius
		polygon.append(point)
		ring_points.append(point)
	_fill.polygon = polygon
	_fill.color = Color(0.24, 0.02, 0.04, 0.62)
	_ring.points = ring_points

func _animate_visuals(delta: float) -> void:
	if not is_instance_valid(_fill) or not is_instance_valid(_ring):
		return
	var life_ratio: float = 0.0 if duration <= 0.0 else (_remaining_time / duration)
	var pulse: float = 0.5 + 0.5 * sin((duration - _remaining_time) * 6.0)
	_fill.color.a = lerp(0.12, 0.62, life_ratio)
	_ring.default_color.a = lerp(0.18, 0.95, life_ratio) * lerp(0.78, 1.0, pulse)
	_ring.width = lerp(3.0, 7.0, pulse)

func _refresh_tracked_enemies() -> void:
	var current_inside: Dictionary = {}
	for enemy_node in get_tree().get_nodes_in_group("enemies"):
		if not (enemy_node is Enemy):
			continue
		var enemy := enemy_node as Enemy
		if not is_instance_valid(enemy) or enemy.is_dead:
			continue
		if global_position.distance_to(enemy.global_position) > radius:
			continue
		current_inside[enemy.get_instance_id()] = enemy
		if not _tracked_enemies.has(enemy.get_instance_id()):
			enemy.set_parasite_pit_presence(_source_key, true, damage_taken_bonus, slow_ratio)

	for enemy_id in _tracked_enemies.keys():
		if current_inside.has(enemy_id):
			continue
		var enemy: Enemy = _tracked_enemies[enemy_id]
		if is_instance_valid(enemy):
			enemy.set_parasite_pit_presence(_source_key, false, damage_taken_bonus, slow_ratio)

	_tracked_enemies = current_inside

func _clear_tracked_enemies() -> void:
	for enemy_id in _tracked_enemies.keys():
		var enemy: Enemy = _tracked_enemies[enemy_id]
		if is_instance_valid(enemy):
			enemy.set_parasite_pit_presence(_source_key, false, damage_taken_bonus, slow_ratio)
	_tracked_enemies.clear()
