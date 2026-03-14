# Auto-generated dedicated E profile skill (mode: mine_detonate).
extends "res://scenes/skills/players/skill_e_proto.gd"

const MODE_ID: String = "mine_detonate"

func _ready() -> void:
	e_profile_id = 5
	super._ready()

func execute() -> void:
	execute_with_mode(MODE_ID)
