# Auto-generated dedicated E profile skill (mode: chain_overload).
extends "res://scenes/skills/players/skill_e_proto.gd"

const MODE_ID: String = "chain_overload"

func _ready() -> void:
	e_profile_id = 18
	super._ready()

func execute() -> void:
	execute_with_mode(MODE_ID)
