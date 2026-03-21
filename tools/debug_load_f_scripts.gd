extends SceneTree

const SkillScriptRegistry = preload("res://scripts/skills/skill_script_registry.gd")

func _init() -> void:
	var butcher_f_path: String = SkillScriptRegistry.resolve_ultimate_script_path("butcher", {
		"f_role_id": "butcher",
		"ult_id": "butcher_ult",
	})
	var targets: Array[String] = [
		"res://scenes/skills/skill_ultimate_base.gd",
		"res://scenes/skills/skill_f_base.gd",
		butcher_f_path,
		"res://tools/top10_effect_selftest_runner.gd",
		"res://tools/qef_acceptance_runner.gd",
		"res://tools/live_top10_effect_selftest_runner.gd",
		"res://tools/live_qef_acceptance_runner.gd",
		"res://tools/debug_validate_one_role.gd",
		"res://tools/manual_effect_selftest_runner.gd",
		"res://tools/debug_simple_ext_runner.gd",
	]
	for path: String in targets:
		print("[debug_load] loading %s" % path)
		var script_obj := load(path)
		print("[debug_load] result=%s" % str(script_obj))
	quit()
