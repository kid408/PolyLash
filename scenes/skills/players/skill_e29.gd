# Auto-generated dedicated E profile skill (mode: tide_reverse).
extends "res://scenes/skills/players/skill_e_proto.gd"

const MODE_ID: String = "tide_reverse"

func _ready() -> void:
	e_profile_id = 29
	super._ready()

func execute() -> void:
	execute_with_mode(MODE_ID)
