# Auto-generated dedicated E profile skill (mode: hook_pull).
extends "res://scenes/skills/players/skill_e_proto.gd"

const MODE_ID: String = "hook_pull"

func _ready() -> void:
	e_profile_id = 1
	super._ready()

func execute() -> void:
	execute_with_mode(MODE_ID)
