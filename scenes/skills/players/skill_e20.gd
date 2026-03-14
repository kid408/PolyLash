# Auto-generated dedicated E profile skill (mode: lure_signal).
extends "res://scenes/skills/players/skill_e_proto.gd"

const MODE_ID: String = "lure_signal"

func _ready() -> void:
	e_profile_id = 20
	super._ready()

func execute() -> void:
	execute_with_mode(MODE_ID)
