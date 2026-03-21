extends "res://tools/qef_acceptance_runner.gd"

func _init() -> void:
	printerr("[live_qef_acceptance] init")
	call_deferred("_run")

func _run() -> void:
	printerr("[live_qef_acceptance] run")
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

	var coverage_result: Dictionary = _validate_role_coverage()
	_results.append(coverage_result)
	passed = passed and bool(coverage_result.get("passed", false))

	for role_id: String in CORE_ROLES:
		var core_result: Dictionary = await _validate_core_role(role_id)
		_results.append(core_result)
		passed = passed and bool(core_result.get("passed", false))
		printerr("[live_qef_acceptance] core role=%s passed=%s" % [role_id, core_result.get("passed", false)])

	for role_id: String in RECORD_REPLAY_ROLES:
		var replay_result: Dictionary = await _validate_record_replay_feedback(role_id)
		_results.append(replay_result)
		passed = passed and bool(replay_result.get("passed", false))
		printerr("[live_qef_acceptance] replay role=%s passed=%s" % [role_id, replay_result.get("passed", false)])

	_leave_test_mode_if_needed()
	printerr("[live_qef_acceptance] finished passed=%s results=%d" % [passed, _results.size()])
	_write_summary(passed)
	quit(0 if passed else 1)
