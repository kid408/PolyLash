extends SceneTree

func _init() -> void:
	var targets: Array[String] = [
		"res://scripts/qef/core/colossus_skill_utils.gd",
		"res://scripts/qef/colossus/colossus_q_base.gd",
		"res://scripts/qef/colossus/colossus_e_base.gd",
		"res://scenes/skills/players/skill_butcher_q.gd",
		"res://scenes/skills/players/skill_glacier_q.gd",
		"res://scenes/skills/players/skill_jailer_q.gd",
		"res://scenes/skills/players/skill_blacksmith_q.gd",
		"res://scenes/skills/players/skill_paladin_q.gd",
		"res://scenes/skills/players/skill_breachmarshal_q.gd",
		"res://scenes/skills/players/skill_hexwarden_q.gd",
		"res://scenes/skills/players/skill_executioner_q.gd",
		"res://scenes/skills/players/skill_butcher_e.gd",
		"res://scenes/skills/players/skill_glacier_e.gd",
		"res://scenes/skills/players/skill_jailer_e.gd",
		"res://scenes/skills/players/skill_blacksmith_e.gd",
		"res://scenes/skills/players/skill_paladin_e.gd",
		"res://scenes/skills/players/skill_breachmarshal_e.gd",
		"res://scenes/skills/players/skill_hexwarden_e.gd",
		"res://scenes/skills/players/skill_executioner_e.gd",
	]
	for path: String in targets:
		print("[tmp_load_colossus] loading %s" % path)
		var script_obj := load(path)
		print("[tmp_load_colossus] result=%s" % str(script_obj))
		if script_obj is GDScript:
			var instance: Variant = script_obj.new()
			print("[tmp_load_colossus] instance=%s" % str(instance))
	quit()
