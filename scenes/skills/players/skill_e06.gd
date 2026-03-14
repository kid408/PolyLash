# Auto-generated dedicated E profile skill (mode: frost_anchor).
extends "res://scenes/skills/players/skill_e_proto.gd"

const MODE_ID: String = "frost_anchor"

func _ready() -> void:
	e_profile_id = 6
	super._ready()

func execute() -> void:
	execute_with_mode(MODE_ID)
