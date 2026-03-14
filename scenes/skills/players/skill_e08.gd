# Auto-generated dedicated E profile skill (mode: reverse_wind).
extends "res://scenes/skills/players/skill_e_proto.gd"

const MODE_ID: String = "reverse_wind"

func _ready() -> void:
	e_profile_id = 8
	super._ready()

func execute() -> void:
	execute_with_mode(MODE_ID)
