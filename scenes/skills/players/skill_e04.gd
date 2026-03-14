# Auto-generated dedicated E profile skill (mode: heat_push).
extends "res://scenes/skills/players/skill_e_proto.gd"

const MODE_ID: String = "heat_push"

func _ready() -> void:
	e_profile_id = 4
	super._ready()

func execute() -> void:
	execute_with_mode(MODE_ID)
