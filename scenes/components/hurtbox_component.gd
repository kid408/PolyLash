extends Area2D
class_name HurtboxComponent

const DEBUG_VERBOSE := false

signal on_damaged(hitbox: HitboxComponent)

func _ready() -> void:
	add_to_group("hurtbox")
	if not area_entered.is_connected(_on_area_entered):
		area_entered.connect(_on_area_entered)

func _on_area_entered(area: Area2D) -> void:
	if not (area is HitboxComponent):
		return
	var hitbox: HitboxComponent = area as HitboxComponent
	on_damaged.emit(hitbox)
