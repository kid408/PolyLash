# Auto-generated dedicated E profile skill (mode: mark_explode).
extends "res://scenes/skills/players/skill_e_proto.gd"

const MODE_ID: String = "mark_explode"

func _ready() -> void:
	e_profile_id = 10
	super._ready()

func execute() -> void:
	execute_with_mode(MODE_ID)
