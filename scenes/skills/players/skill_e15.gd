# Auto-generated dedicated E profile skill (mode: anchor_jump).
extends "res://scenes/skills/players/skill_e_proto.gd"

const MODE_ID: String = "anchor_jump"

func _ready() -> void:
	e_profile_id = 15
	super._ready()

func execute() -> void:
	execute_with_mode(MODE_ID)
