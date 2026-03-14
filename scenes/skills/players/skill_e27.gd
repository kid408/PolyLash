# Auto-generated dedicated E profile skill (mode: thermal_break).
extends "res://scenes/skills/players/skill_e_proto.gd"

const MODE_ID: String = "thermal_break"

func _ready() -> void:
	e_profile_id = 27
	super._ready()

func execute() -> void:
	execute_with_mode(MODE_ID)
