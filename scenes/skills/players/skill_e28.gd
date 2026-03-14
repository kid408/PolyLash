# Auto-generated dedicated E profile skill (mode: execute_calibrate).
extends "res://scenes/skills/players/skill_e_proto.gd"

const MODE_ID: String = "execute_calibrate"

func _ready() -> void:
	e_profile_id = 28
	super._ready()

func execute() -> void:
	execute_with_mode(MODE_ID)
