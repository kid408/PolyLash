# Auto-generated dedicated E profile skill (mode: suppression_order).
extends "res://scenes/skills/players/skill_e_proto.gd"

const MODE_ID: String = "suppression_order"

func _ready() -> void:
	e_profile_id = 23
	super._ready()

func execute() -> void:
	execute_with_mode(MODE_ID)
