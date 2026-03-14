# Auto-generated dedicated E profile skill (mode: blade_reap).
extends "res://scenes/skills/players/skill_e_proto.gd"

const MODE_ID: String = "blade_reap"

func _ready() -> void:
	e_profile_id = 24
	super._ready()

func execute() -> void:
	execute_with_mode(MODE_ID)
