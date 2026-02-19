extends Control

func _ready() -> void:
	# 显示 Logo，1.5秒后淡出过渡到 MainMenuRoot
	var tween = create_tween()
	tween.tween_interval(1.5)
	tween.tween_property(self, "modulate:a", 0.0, 0.5)
	tween.tween_callback(_go_to_main_menu)

func _go_to_main_menu() -> void:
	get_tree().change_scene_to_file("res://scenes/ui/main_menu/main_menu_root.tscn")
