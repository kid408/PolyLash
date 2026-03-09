extends "res://scenes/arena/arena_core.gd"
class_name Arena

func _on_progression_level_up(level: int, reward_tier: int, total_xp: int) -> void:
	super._on_progression_level_up(level, reward_tier, total_xp)
