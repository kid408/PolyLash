# Auto-generated dedicated E profile skill (mode: gravity_boost).
extends "res://scenes/skills/players/skill_e_proto.gd"

const MODE_ID: String = "gravity_boost"

func _ready() -> void:
	e_profile_id = 21
	super._ready()

func execute() -> void:
	execute_with_mode(MODE_ID)
