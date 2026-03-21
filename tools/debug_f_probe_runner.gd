extends "res://tools/top10_effect_selftest_runner.gd"

const DEFAULT_ROLE_ID := "butcher"

func _init() -> void:
	printerr("[debug_f_probe] init")
	call_deferred("_run")

func _run() -> void:
	printerr("[debug_f_probe] run")
	await process_frame

	if _global_node() == null or _debug_switcher_node() == null or _config_manager_node() == null:
		printerr("[debug_f_probe] bootstrap failed")
		quit(1)
		return

	var role_id: String = OS.get_environment("QEF_DEBUG_ROLE").strip_edges().to_lower()
	if role_id.is_empty():
		role_id = DEFAULT_ROLE_ID
	printerr("[debug_f_probe] role=%s" % role_id)

	var player: Node2D = await _prepare_role_arena(role_id)
	if not is_instance_valid(player):
		printerr("[debug_f_probe] player not ready")
		quit(1)
		return

	var anchor: Vector2 = player.global_position
	await _reset_phase_state(player, anchor)
	_dump_state("before_f")

	var tap_ok: bool = await _tap_action("skill_f", 10, 2)
	printerr("[debug_f_probe] tap_ok=%s" % tap_ok)
	_dump_state("after_tap")

	await _wait_frames(8)
	_dump_state("after_8f")

	await _wait_frames(32)
	var final_state: Dictionary = _dump_state("after_40f")

	_deactivate_ultimate_if_needed()
	_leave_test_mode_if_needed()
	var qef_runtime: Dictionary = final_state.get("qef_runtime", {})
	var ultimate_snapshot: Dictionary = final_state.get("ultimate", {})
	var f_context: Dictionary = final_state.get("f_context", {})
	var passed: bool = (
		tap_ok
		and bool(qef_runtime.get("active", false))
		and bool(ultimate_snapshot.get("active", false))
		and not f_context.is_empty()
		and str(qef_runtime.get("role_id", qef_runtime.get("f_role_id", ""))).strip_edges() == role_id
	)
	printerr("[debug_f_probe] passed=%s" % passed)
	quit(0 if passed else 1)

func _dump_state(tag: String) -> Dictionary:
	var player_var: Variant = _global_node().get("player")
	if not (player_var is Node):
		printerr("[debug_f_probe] %s player missing" % tag)
		return {}
	var player_node: Node = player_var
	var runtime: Dictionary = {}
	var context: Dictionary = {}
	if player_node.has_method("get_skill_runtime_snapshot"):
		runtime = player_node.call("get_skill_runtime_snapshot")
	if player_node.has_method("get_skill_context_snapshot"):
		context = player_node.call("get_skill_context_snapshot")
	var ultimate_var: Variant = player_node.get("ultimate_skill")
	var ultimate_valid: bool = is_instance_valid(ultimate_var)
	printerr("[debug_f_probe] --- %s ---" % tag)
	printerr("[debug_f_probe] player_id=%s ultimate_valid=%s ultimate=%s" % [
		str(player_node.get("player_id")),
		ultimate_valid,
		str(ultimate_var)
	])
	printerr("[debug_f_probe] runtime=%s" % JSON.stringify(runtime))
	printerr("[debug_f_probe] context=%s" % JSON.stringify(context))
	return {
		"runtime": runtime,
		"context": context,
		"qef_runtime": runtime.get("qef_runtime", {}) if runtime.get("qef_runtime", {}) is Dictionary else {},
		"ultimate": runtime.get("ultimate", {}) if runtime.get("ultimate", {}) is Dictionary else {},
		"f_context": context.get("f_context", {}) if context.get("f_context", {}) is Dictionary else {},
	}
