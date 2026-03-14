# Auto-generated dedicated E profile skill (mode: time_echo).
extends "res://scenes/skills/players/skill_e_proto.gd"

const MODE_ID: String = "time_echo"

func _ready() -> void:
	e_profile_id = 12
	super._ready()

func execute() -> void:
	execute_with_mode(MODE_ID)
