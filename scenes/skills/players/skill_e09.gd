# Auto-generated dedicated E profile skill (mode: ballistic_tune).
extends "res://scenes/skills/players/skill_e_proto.gd"

const MODE_ID: String = "ballistic_tune"

func _ready() -> void:
	e_profile_id = 9
	super._ready()

func execute() -> void:
	execute_with_mode(MODE_ID)
