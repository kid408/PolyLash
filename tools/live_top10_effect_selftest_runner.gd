extends "res://tools/top10_effect_selftest_runner.gd"

func _init() -> void:
	printerr("[live_top10_effect_selftest] init")
	call_deferred("_run")

func _run() -> void:
	printerr("[live_top10_effect_selftest] run")
	var passed: bool = true
	await process_frame

	if _global_node() == null or _debug_switcher_node() == null or _config_manager_node() == null:
		_results.append({
			"kind": "bootstrap",
			"passed": false,
			"reason": "autoload_missing",
		})
		_write_summary(false)
		quit(1)
		return

	_reset_global_session()

	for role_id: String in TEST_ROLES:
		var result: Dictionary = await _validate_role(role_id)
		_results.append(result)
		passed = passed and bool(result.get("passed", false))
		printerr("[live_top10_effect_selftest] role=%s passed=%s" % [role_id, result.get("passed", false)])

	_leave_test_mode_if_needed()
	printerr("[live_top10_effect_selftest] finished passed=%s results=%d" % [passed, _results.size()])
	_write_summary(passed)
	quit(0 if passed else 1)
