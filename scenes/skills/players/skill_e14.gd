# Auto-generated dedicated E profile skill (mode: rail_reverse).
extends "res://scenes/skills/players/skill_e_proto.gd"

const MODE_ID: String = "rail_reverse"

func _ready() -> void:
	e_profile_id = 14
	super._ready()

func execute() -> void:
	execute_with_mode(MODE_ID)
