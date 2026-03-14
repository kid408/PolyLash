# Auto-generated dedicated E profile skill (mode: rift_catalyst).
extends "res://scenes/skills/players/skill_e_proto.gd"

const MODE_ID: String = "rift_catalyst"

func _ready() -> void:
	e_profile_id = 32
	super._ready()

func execute() -> void:
	execute_with_mode(MODE_ID)
