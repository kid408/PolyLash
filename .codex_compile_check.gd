extends SceneTree

func _initialize() -> void:
	var scripts: Array[String] = [
		"res://scenes/skills/players/skill_dealer_q.gd",
		"res://scenes/skills/players/skill_dealer_e.gd",
		"res://scenes/skills/players/f_roles/skill_dealer_f.gd",
	]
	for script_path in scripts:
		var script_obj: Variant = load(script_path)
		if script_obj == null:
			push_error("Failed to load %s" % script_path)
			quit(1)
			return
		print("Loaded: %s" % script_path)
	quit(0)
