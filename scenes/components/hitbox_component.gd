extends Area2D
class_name HitboxComponent

const DEBUG_VERBOSE := false
const COMBAT_EVENT_TYPES := preload("res://scenes/components/combat_event_types.gd")

signal on_hit_hurtbox(hurtbox: HurtboxComponent)

var damage: float = 1.0
var critical: bool = false
var knockback_power: float = 0.0
var source: Node2D = null
var damage_type: int = COMBAT_EVENT_TYPES.DamageType.DIRECT
var is_shared_damage: bool = false

func _ready() -> void:
	if not area_entered.is_connected(_on_area_entered):
		area_entered.connect(_on_area_entered)

func enable() -> void:
	monitoring = true
	monitorable = true

func disable() -> void:
	monitoring = false
	monitorable = false

func setup(
	new_damage: float,
	new_critical: bool,
	knockback: float,
	new_source: Node2D,
	new_damage_type: int = COMBAT_EVENT_TYPES.DamageType.DIRECT,
	new_is_shared_damage: bool = false
) -> void:
	damage = new_damage
	critical = new_critical
	knockback_power = knockback
	source = new_source
	damage_type = COMBAT_EVENT_TYPES.normalize_damage_type(new_damage_type)
	is_shared_damage = new_is_shared_damage

func build_damage_payload(extra_payload: Dictionary = {}) -> Dictionary:
	var payload: Dictionary = {
		"source": source,
		"critical": critical,
		"damage_type": damage_type,
		"is_shared_damage": is_shared_damage,
		"knockback_power": knockback_power,
	}
	if is_instance_valid(source):
		payload["source_position"] = source.global_position
	for key_variant: Variant in extra_payload.keys():
		payload[key_variant] = extra_payload[key_variant]
	return payload

func _on_area_entered(area: Area2D) -> void:
	if area is HurtboxComponent:
		on_hit_hurtbox.emit(area as HurtboxComponent)
