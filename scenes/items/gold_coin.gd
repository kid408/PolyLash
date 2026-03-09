extends Area2D
class_name GoldCoin

const DEBUG_VERBOSE := false
const FORCE_PICKUP_DISTANCE: float = 15.0

@export var gold_amount: int = 1

var pickup_range: float = 150.0
var magnet_speed: float = 800.0
var is_magnetized: bool = false
var is_collected: bool = false

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var collision: CollisionShape2D = $CollisionShape2D

func _ready() -> void:
	if not is_in_group("coins"):
		add_to_group("coins")
	if not is_in_group("items"):
		add_to_group("items")

	collision_layer = 0
	collision_mask = 1

	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)
	if not area_entered.is_connected(_on_area_entered):
		area_entered.connect(_on_area_entered)

	if sprite:
		sprite.play("default")

	_play_pop_animation()

func _process(delta: float) -> void:
	if Global.game_paused:
		return
	if is_collected:
		return
	if not is_instance_valid(Global.player):
		return

	var player_pickup: Variant = Global.player.get("pickup_range")
	if typeof(player_pickup) == TYPE_FLOAT or typeof(player_pickup) == TYPE_INT:
		pickup_range = float(player_pickup)

	var player_pos: Vector2 = Global.player.global_position
	var distance: float = global_position.distance_to(player_pos)

	if distance < FORCE_PICKUP_DISTANCE:
		_collect_coin(Global.player)
		return

	if distance < pickup_range:
		is_magnetized = true

	if is_magnetized:
		var direction: Vector2 = global_position.direction_to(player_pos)
		global_position += direction * magnet_speed * delta

func _play_pop_animation() -> void:
	scale = Vector2.ZERO
	var tween: Tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	var start_pos: Vector2 = global_position
	var jump_height: float = 30.0
	tween.tween_property(self, "global_position:y", start_pos.y - jump_height, 0.15).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.chain().tween_property(self, "global_position:y", start_pos.y, 0.15).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

func _on_body_entered(body: Node2D) -> void:
	if _is_player_like(body):
		_collect_coin(body)

func _on_area_entered(area: Area2D) -> void:
	if _is_player_like(area):
		_collect_coin(area)
		return
	if area.owner and _is_player_like(area.owner):
		_collect_coin(area.owner)

func _is_player_like(node: Node) -> bool:
	if not is_instance_valid(node):
		return false
	if node.is_in_group("player"):
		return true
	return node.has_method("add_gold")

func _collect_coin(player: Node) -> void:
	if is_collected:
		return
	if not is_instance_valid(player):
		return

	is_collected = true
	SoundManager.play("gold_pickup")

	if player.has_method("add_gold"):
		player.call("add_gold", gold_amount)

	queue_free()

func set_amount(amount: int) -> void:
	gold_amount = amount
