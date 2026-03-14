# Auto-generated dedicated E profile skill (mode: medic_barrier).
extends "res://scenes/skills/players/skill_e_proto.gd"

const MODE_ID: String = "medic_barrier"

func _ready() -> void:
	e_profile_id = 11
	super._ready()

func execute() -> void:
	execute_with_mode(MODE_ID)
