extends Node2D
## 背景几何线条绘制节点 - 委托给父节点 TitleScreen 进行绘制

func _draw() -> void:
	var parent = get_parent()
	if parent and parent.has_method("_draw_lines"):
		parent._draw_lines()
