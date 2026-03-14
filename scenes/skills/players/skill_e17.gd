# Auto-generated dedicated E profile skill (mode: phase_swap).
extends "res://scenes/skills/players/skill_e_proto.gd"

const MODE_ID: String = "phase_swap"

func _ready() -> void:
	e_profile_id = 17
	super._ready()

func execute() -> void:
	execute_with_mode(MODE_ID)
