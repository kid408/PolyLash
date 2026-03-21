extends "res://tools/top10_effect_selftest_runner.gd"

func _init() -> void:
	printerr("[debug_validate_one_role] init")
	call_deferred("_run")

func _run() -> void:
	printerr("[debug_validate_one_role] run")
	await process_frame
	printerr("[debug_validate_one_role] global=%s debug=%s config=%s" % [
		str(_global_node()),
		str(_debug_switcher_node()),
		str(_config_manager_node()),
	])
	var result: Dictionary = await _validate_role("butcher")
	printerr("[debug_validate_one_role] result=%s" % JSON.stringify(result))
	quit(0)
