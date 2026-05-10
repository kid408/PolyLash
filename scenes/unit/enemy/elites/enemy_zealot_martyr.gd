extends Enemy
class_name EnemyZealotMartyr

const COMBAT_EVENT_TYPES := preload("res://scenes/components/combat_event_types.gd")

const MAX_ZEALOT_STACKS: int = 3
const SPEED_PER_STACK: float = 0.15
const SCALE_PER_STACK: float = 0.10
const RESET_STATUS_NAMES: Array[String] = ["stun", "freeze", "root", "petrify"]

var _zealot_stacks: int = 0
var _base_visual_scale: Vector2 = Vector2.ONE
var _base_collision_scale: Vector2 = Vector2.ONE
var _base_vision_scale: Vector2 = Vector2.ONE
var _base_hurtbox_scale: Vector2 = Vector2.ONE
var _base_hitbox_scale: Vector2 = Vector2.ONE

@onready var _vision_shape: CollisionShape2D = get_node_or_null("VisionArea/CollisionShape2D")
@onready var _hurtbox_shape: CollisionShape2D = get_node_or_null("HurtboxComponent/CollisionShape2D")
@onready var _hitbox_shape: CollisionShape2D = get_node_or_null("HitboxComponent/CollisionShape2D")

func _ready() -> void:
	super._ready()
	_base_visual_scale = visuals.scale
	_base_collision_scale = collision_shape.scale if collision_shape != null else Vector2.ONE
	_base_vision_scale = _vision_shape.scale if _vision_shape != null else Vector2.ONE
	_base_hurtbox_scale = _hurtbox_shape.scale if _hurtbox_shape != null else Vector2.ONE
	_base_hitbox_scale = _hitbox_shape.scale if _hitbox_shape != null else Vector2.ONE
	_refresh_stack_visuals()

func _process(delta: float) -> void:
	if Global.game_paused or is_dead:
		return
	super._process(delta)
	if _zealot_stacks > 0 and _has_reset_control_status():
		_clear_zealot_stacks()

func _current_move_speed() -> float:
	var base_speed_value: float = super._current_move_speed()
	return base_speed_value * (1.0 + float(_zealot_stacks) * SPEED_PER_STACK)

func on_health_component_damage_applied(applied_damage: float, payload: Dictionary = {}) -> void:
	super.on_health_component_damage_applied(applied_damage, payload)
	if applied_damage <= 0.0:
		return
	var damage_type: int = COMBAT_EVENT_TYPES.normalize_damage_type(
		payload.get("damage_type", COMBAT_EVENT_TYPES.DamageType.DIRECT)
	)
	if damage_type == COMBAT_EVENT_TYPES.DamageType.TRUE_DAMAGE:
		_clear_zealot_stacks()
		return
	_add_zealot_stack()

func _add_zealot_stack() -> void:
	var previous_stacks: int = _zealot_stacks
	_zealot_stacks = min(MAX_ZEALOT_STACKS, _zealot_stacks + 1)
	if _zealot_stacks == previous_stacks:
		return
	_refresh_stack_visuals()
	if Global != null and Global.has_method("spawn_floating_text"):
		Global.spawn_floating_text(global_position + Vector2(0.0, -18.0), "RAGE %d" % _zealot_stacks, Color(1.0, 0.48, 0.34))

func _clear_zealot_stacks() -> void:
	if _zealot_stacks <= 0:
		return
	_zealot_stacks = 0
	_refresh_stack_visuals()
	if Global != null and Global.has_method("spawn_floating_text"):
		Global.spawn_floating_text(global_position + Vector2(0.0, -18.0), "CALM", Color(0.72, 0.94, 1.0))

func _refresh_stack_visuals() -> void:
	var scale_multiplier: float = 1.0 + float(_zealot_stacks) * SCALE_PER_STACK
	if visuals != null and is_instance_valid(visuals):
		visuals.scale = _base_visual_scale * scale_multiplier
	if collision_shape != null and is_instance_valid(collision_shape):
		collision_shape.scale = _base_collision_scale * scale_multiplier
	if _vision_shape != null and is_instance_valid(_vision_shape):
		_vision_shape.scale = _base_vision_scale * scale_multiplier
	if _hurtbox_shape != null and is_instance_valid(_hurtbox_shape):
		_hurtbox_shape.scale = _base_hurtbox_scale * scale_multiplier
	if _hitbox_shape != null and is_instance_valid(_hitbox_shape):
		_hitbox_shape.scale = _base_hitbox_scale * scale_multiplier

func _has_reset_control_status() -> bool:
	for status_name: String in RESET_STATUS_NAMES:
		if has_status(status_name):
			return true
	return false
