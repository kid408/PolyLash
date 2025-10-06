extends Node2D
class_name FloatingText

@onready var value_label: Label = $ValueLabel

func setup(value:String,color:Color) -> void:
	value_label.text = value
	modulate = color
	scale = Vector2.ZERO
	
	# 随机弧形角度
	rotation = deg_to_rad(randf_range(-10,10))
	# 随机缩放
	var random_scale := randf_range(0.8,1.6)
	
	# 简单动画，适合做随机动画
	var tween := create_tween()
	
	# 修改 随机缩放 parallel 表示按顺序执行
	tween.parallel().tween_property(self,"scale",random_scale*Vector2.ONE,0.4)
	# 修改 随机位置
	tween.parallel().tween_property(self,"global_position",global_position+Vector2.UP*15,0.4)
	
	# 等待5秒
	tween.tween_interval(0.5)
	
	# 缩放变回去
	tween.parallel().tween_property(self,"scale",Vector2.ZERO,0.4)
	# 添加颜色动画
	tween.parallel().tween_property(self,"modulate:a",0.0,0.4)
	
	# 等待动画播放完毕
	await tween.finished
	# 销毁动画
	queue_free()
	
