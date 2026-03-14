# Auto-generated dedicated E profile skill (mode: toxin_inject).
extends "res://scenes/skills/players/skill_e_proto.gd"

const MODE_ID: String = "toxin_inject"

func _ready() -> void:
	e_profile_id = 19
	super._ready()

func execute() -> void:
	execute_with_mode(MODE_ID)
