extends Area2D
class_name EnergyOrb

const FORCE_PICKUP_DISTANCE: float = 18.0

@export var energy_amount: float = 6.0
@export var pickup_range: float = 150.0
@export var magnet_speed: float = 900.0
@export var launch_speed_min: float = 110.0
@export var launch_speed_max: float = 180.0
@export var launch_drag: float = 720.0
@export var settle_velocity: float = 10.0
@export var pulse_speed: float = 5.5
@export var pulse_scale: float = 0.08

var is_collected: bool = false
var is_magnetized: bool = false
var velocity: Vector2 = Vector2.ZERO
var _pulse_time: float = 0.0
var _base_core_scale: Vector2 = Vector2.ONE
var _base_glow_scale: Vector2 = Vector2.ONE

@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var glow: Polygon2D = $Glow
@onready var core: Polygon2D = $Core

func _ready() -> void:
	if not is_in_group("items"):
		add_to_group("items")
	if not is_in_group("energy_orbs"):
		add_to_group("energy_orbs")

	collision_layer = 0
	collision_mask = 1

	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)
	if not area_entered.is_connected(_on_area_entered):
		area_entered.connect(_on_area_entered)

	_base_core_scale = core.scale
	_base_glow_scale = glow.scale

	if velocity.length_squared() <= 0.001:
		velocity = _build_random_launch_velocity()

	_play_spawn_pop()

func setup(amount: float, launch_velocity: Vector2 = Vector2.ZERO) -> void:
	energy_amount = max(1.0, amount)
	velocity = launch_velocity if launch_velocity.length_squared() > 0.001 else _build_random_launch_velocity()

func _physics_process(delta: float) -> void:
	if Global.game_paused or is_collected:
		return

	_update_pulse(delta)

	if not is_instance_valid(Global.player):
		_move_ballistic(delta)
		return

	var player_node: Node2D = Global.player
	var player_pos: Vector2 = player_node.global_position
	var distance: float = global_position.distance_to(player_pos)

	if distance <= FORCE_PICKUP_DISTANCE:
		_collect_orb(player_node)
		return

	if distance <= pickup_range:
		is_magnetized = true

	if is_magnetized:
		var follow_speed: float = magnet_speed * (1.0 + clamp((pickup_range - distance) / max(1.0, pickup_range), 0.0, 1.0))
		global_position = global_position.move_toward(player_pos, follow_speed * delta)
	else:
		_move_ballistic(delta)

func _move_ballistic(delta: float) -> void:
	global_position += velocity * delta
	velocity = velocity.move_toward(Vector2.ZERO, launch_drag * delta)

func _update_pulse(delta: float) -> void:
	_pulse_time += delta * pulse_speed
	var wave: float = 1.0 + sin(_pulse_time) * pulse_scale
	if is_instance_valid(core):
		core.scale = _base_core_scale * wave
	if is_instance_valid(glow):
		glow.scale = _base_glow_scale * (1.0 + sin(_pulse_time + 0.7) * pulse_scale * 1.4)

func _play_spawn_pop() -> void:
	scale = Vector2(0.2, 0.2)
	var tween: Tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "rotation", randf_range(-0.24, 0.24), 0.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

func _build_random_launch_velocity() -> Vector2:
	var angle: float = randf_range(-PI, PI)
	var speed: float = randf_range(launch_speed_min, launch_speed_max)
	var direction: Vector2 = Vector2.RIGHT.rotated(angle)
	direction.y -= 0.35
	return direction.normalized() * speed

func _on_body_entered(body: Node2D) -> void:
	if _is_player_like(body):
		_collect_orb(body)

func _on_area_entered(area: Area2D) -> void:
	if _is_player_like(area):
		_collect_orb(area)
		return
	if area.owner != null and _is_player_like(area.owner):
		_collect_orb(area.owner)

func _is_player_like(node: Node) -> bool:
	if not is_instance_valid(node):
		return false
	if node.is_in_group("player"):
		return true
	return node.has_method("gain_energy")

func _collect_orb(player_node: Node) -> void:
	if is_collected or not is_instance_valid(player_node):
		return

	is_collected = true
	if player_node.has_method("gain_energy"):
		player_node.call("gain_energy", energy_amount)
	queue_free()
