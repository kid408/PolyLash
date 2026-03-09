extends Area2D
class_name HitboxComponent

const DEBUG_VERBOSE := false

signal on_hit_hurtbox(hurtbox: HurtboxComponent)

var damage: float = 1.0
var critical: bool = false
var knockback_power: float = 0.0
var source: Node2D = null

func _ready() -> void:
	if not area_entered.is_connected(_on_area_entered):
		area_entered.connect(_on_area_entered)

func enable() -> void:
	monitoring = true
	monitorable = true

func disable() -> void:
	monitoring = false
	monitorable = false

func setup(new_damage: float, new_critical: bool, knockback: float, new_source: Node2D) -> void:
	damage = new_damage
	critical = new_critical
	knockback_power = knockback
	source = new_source

func _on_area_entered(area: Area2D) -> void:
	if area is HurtboxComponent:
		on_hit_hurtbox.emit(area as HurtboxComponent)
