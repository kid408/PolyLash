# Auto-generated dedicated E profile skill (mode: blood_trade).
extends "res://scenes/skills/players/skill_e_proto.gd"

const MODE_ID: String = "blood_trade"

func _ready() -> void:
	e_profile_id = 16
	super._ready()

func execute() -> void:
	execute_with_mode(MODE_ID)
