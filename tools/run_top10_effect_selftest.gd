extends "res://tools/top10_effect_selftest_runner.gd"

func _init() -> void:
	printerr("[run_top10_effect_selftest] init")
	call_deferred("_run")

func _run() -> void:
	printerr("[run_top10_effect_selftest] run")
	await super._run()
