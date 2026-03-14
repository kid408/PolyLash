# Auto-generated dedicated E profile skill (mode: echo_amplify).
extends "res://scenes/skills/players/skill_e_proto.gd"

const MODE_ID: String = "echo_amplify"

func _ready() -> void:
	e_profile_id = 31
	super._ready()

func execute() -> void:
	execute_with_mode(MODE_ID)
