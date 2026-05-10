extends Area2D
class_name PrismStun

@export var radius: float = 28.0
@export var lifetime: float = 2.0
@export var stun_duration: float = 1.0

@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var visual_ring: Line2D = $VisualRing

var owner_player: Node2D = null
var _remaining_lifetime: float = 0.0
var _hit_enemies: Dictionary = {}

func _ready() -> void:
	add_to_group("player_summoned_entity")
	_remaining_lifetime = lifetime
	_update_visuals()
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)

func _process(delta: float) -> void:
	_remaining_lifetime = max(0.0, _remaining_lifetime - delta)
	if is_instance_valid(visual_ring):
		var normalized_time: float = clamp(_remaining_lifetime / max(0.001, lifetime), 0.0, 1.0)
		visual_ring.modulate.a = 0.25 + normalized_time * 0.65
		visual_ring.width = lerp(2.0, 6.0, normalized_time)
	if _remaining_lifetime <= 0.0:
		queue_free()

func setup(source_player: Node2D, duration_value: float = 2.0, stun_duration_value: float = 1.0) -> void:
	owner_player = source_player
	lifetime = max(0.1, duration_value)
	stun_duration = max(0.1, stun_duration_value)
	_remaining_lifetime = lifetime
	_update_visuals()

func _update_visuals() -> void:
	if is_instance_valid(collision_shape) and collision_shape.shape is CircleShape2D:
		var circle_shape: CircleShape2D = collision_shape.shape as CircleShape2D
		circle_shape.radius = radius
	if is_instance_valid(visual_ring):
		var points: PackedVector2Array = PackedVector2Array()
		var segment_count: int = 20
		for index: int in range(segment_count):
			var angle: float = TAU * float(index) / float(segment_count)
			points.append(Vector2.RIGHT.rotated(angle) * radius)
		visual_ring.points = points

func _on_body_entered(body: Node) -> void:
	if body is Enemy:
		_apply_prism_effect(body as Enemy)

func _on_area_entered(area: Area2D) -> void:
	if area == null or not is_instance_valid(area):
		return
	var enemy_candidate: Node = area.get_parent()
	if enemy_candidate is Enemy:
		_apply_prism_effect(enemy_candidate as Enemy)

func _apply_prism_effect(enemy: Enemy) -> void:
	if enemy == null or not is_instance_valid(enemy) or enemy.is_dead:
		return
	var enemy_id: int = enemy.get_instance_id()
	if _hit_enemies.has(enemy_id):
		return
	_hit_enemies[enemy_id] = true
	enemy.apply_status("stun", stun_duration, 0.0, 1, 1.0)
	Global.spawn_floating_text(enemy.global_position, "PRISM", Color(0.72, 0.94, 1.0))
