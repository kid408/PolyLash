# Auto-generated dedicated E profile skill (mode: bait_redeploy).
extends "res://scenes/skills/players/skill_e_proto.gd"

const MODE_ID: String = "bait_redeploy"

func _ready() -> void:
	e_profile_id = 26
	super._ready()

func execute() -> void:
	execute_with_mode(MODE_ID)
