extends "res://tools/qef_acceptance_runner.gd"

func _init() -> void:
	printerr("[run_qef_acceptance] init")
	call_deferred("_run")

func _run() -> void:
	printerr("[run_qef_acceptance] run")
	await super._run()
