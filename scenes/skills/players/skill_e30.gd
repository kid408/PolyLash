# Auto-generated dedicated E profile skill (mode: verdict_trigger).
extends "res://scenes/skills/players/skill_e_proto.gd"

const MODE_ID: String = "verdict_trigger"

func _ready() -> void:
	e_profile_id = 30
	super._ready()

func execute() -> void:
	execute_with_mode(MODE_ID)
