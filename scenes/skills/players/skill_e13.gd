# Auto-generated dedicated E profile skill (mode: counter_stance).
extends "res://scenes/skills/players/skill_e_proto.gd"

const MODE_ID: String = "counter_stance"

func _ready() -> void:
	e_profile_id = 13
	super._ready()

func execute() -> void:
	execute_with_mode(MODE_ID)
