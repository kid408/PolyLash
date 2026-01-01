extends Node2D
# 飘字类
class_name FloatingText

# 飘字文本框
@onready var value_label: Label = $ValueLabel

# 设置飘字文字和颜色 并播放动画
func setup(value:String,color:Color) -> void:
	value_label.text = value
	modulate = color
	scale = Vector2.ZERO
	
	# 随机弧形角度
	rotation = deg_to_rad(randf_range(-10,10))
	# 更大的随机缩放（1.2-2.0倍）
	var random_scale := randf_range(1.2, 2.0)
	
	# 简单动画，适合做随机动画
	var tween := create_tween()
	
	# 修改 随机缩放 parallel 表示并行执行
	tween.parallel().tween_property(self,"scale",random_scale*Vector2.ONE,0.5)
	# 修改 随机位置（向上飘得更高）
	tween.parallel().tween_property(self,"global_position",global_position+Vector2.UP*30,0.5)
	
	# 等待0.5秒（停留时间）
	tween.tween_interval(0.5)
	
	# 渐隐消失（1秒）
	tween.parallel().tween_property(self,"scale",random_scale*Vector2.ONE*0.8,1.0)
	tween.parallel().tween_property(self,"modulate:a",0.0,1.0)
	
	# 等待动画播放完毕
	await tween.finished
	# 销毁动画
	queue_free()
	
