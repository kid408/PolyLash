extends Node2D
class_name AssistJouleFumes

const JOULE_TAR_UTILS := preload("res://scenes/effects/joule_tar_utils.gd")

var radius: float = 80.0
var lifetime: float = 2.0
var attack_value: float = 40.0
var tar_duration: float = 8.0
var tar_duration_max: float = 10.0
var tar_move_speed_multiplier: float = 0.7
var tar_skill_damage_taken_multiplier: float = 1.2
var tar_dot_ratio: float = 0.15
var tar_tick_interval: float = 0.5

var _life_timer: float = 0.0
var _ring: Line2D = null
var _fill: Polygon2D = null
var _tracked_inside: Dictionary = {}

func setup(
	effect_radius: float,
	effect_lifetime: float,
	source_attack: float,
	base_tar_duration: float = 8.0,
	max_tar_duration: float = 10.0
) -> void:
	radius = effect_radius
	lifetime = effect_lifetime
	attack_value = source_attack
	tar_duration = base_tar_duration
	tar_duration_max = max_tar_duration
	_life_timer = lifetime
	_rebuild_visual()

func _ready() -> void:
	add_to_group("player_skill_effects")
	add_to_group("player_summoned_entity")
	top_level = true
	_life_timer = lifetime
	_rebuild_visual()

func _process(delta: float) -> void:
	_life_timer = max(0.0, _life_timer - delta)
	if _life_timer <= 0.0:
		queue_free()
		return
	_apply_cloud()
	_update_visual()

func _apply_cloud() -> void:
	var still_inside: Dictionary = {}
	for enemy_node: Node in get_tree().get_nodes_in_group("enemies"):
		if not (enemy_node is Enemy):
			continue
		var enemy: Enemy = enemy_node as Enemy
		if not is_instance_valid(enemy) or enemy.is_dead:
			continue
		if enemy.global_position.distance_to(global_position) > radius:
			continue
		var enemy_id: int = enemy.get_instance_id()
		still_inside[enemy_id] = true
		if _tracked_inside.has(enemy_id):
			continue
		_tracked_inside[enemy_id] = true
		JOULE_TAR_UTILS.apply_tar(
			enemy,
			self,
			attack_value,
			false,
			tar_duration,
			tar_duration_max,
			tar_move_speed_multiplier,
			tar_skill_damage_taken_multiplier,
			tar_dot_ratio,
			tar_tick_interval
		)
	var expired_ids: Array[int] = []
	for enemy_id_variant: Variant in _tracked_inside.keys():
		var enemy_id: int = int(enemy_id_variant)
		if not still_inside.has(enemy_id):
			expired_ids.append(enemy_id)
	for enemy_id: int in expired_ids:
		_tracked_inside.erase(enemy_id)

func _rebuild_visual() -> void:
	if _fill == null:
		_fill = Polygon2D.new()
		_fill.color = Color(0.96, 0.54, 0.18, 0.14)
		_fill.z_index = 22
		add_child(_fill)
	if _ring == null:
		_ring = Line2D.new()
		_ring.closed = true
		_ring.width = 6.0
		_ring.default_color = Color(1.0, 0.76, 0.28, 0.64)
		_ring.z_index = 23
		_ring.antialiased = true
		add_child(_ring)
	var points: PackedVector2Array = PackedVector2Array()
	for i in range(25):
		var angle: float = (float(i) / 24.0) * TAU
		points.append(Vector2.RIGHT.rotated(angle) * radius)
	_fill.polygon = points
	_ring.points = points

func _update_visual() -> void:
	if _ring == null or _fill == null:
		return
	var normalized_time: float = 1.0 - (_life_timer / max(0.001, lifetime))
	var pulse: float = 0.5 + 0.5 * sin(normalized_time * TAU * 4.0)
	_ring.width = lerp(5.0, 9.0, pulse)
	_ring.modulate = Color(1.0, 1.0, 1.0, lerp(0.22, 0.64, 1.0 - normalized_time))
	_fill.modulate = Color(1.0, 1.0, 1.0, lerp(0.08, 0.18, 1.0 - normalized_time))
