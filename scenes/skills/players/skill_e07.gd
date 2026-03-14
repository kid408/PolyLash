# Auto-generated dedicated E profile skill (mode: decoy_swap).
extends "res://scenes/skills/players/skill_e_proto.gd"

const MODE_ID: String = "decoy_swap"

func _ready() -> void:
	e_profile_id = 7
	super._ready()

func execute() -> void:
	execute_with_mode(MODE_ID)
