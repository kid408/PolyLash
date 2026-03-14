# Auto-generated dedicated E profile skill (mode: smoke_cover).
extends "res://scenes/skills/players/skill_e_proto.gd"

const MODE_ID: String = "smoke_cover"

func _ready() -> void:
	e_profile_id = 22
	super._ready()

func execute() -> void:
	execute_with_mode(MODE_ID)
