# Auto-generated dedicated E profile skill (mode: net_recall).
extends "res://scenes/skills/players/skill_e_proto.gd"

const MODE_ID: String = "net_recall"

func _ready() -> void:
	e_profile_id = 2
	super._ready()

func execute() -> void:
	execute_with_mode(MODE_ID)
