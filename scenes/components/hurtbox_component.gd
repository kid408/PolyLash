extends Area2D
# 受击盒组件
class_name HurtboxComponent
# 收到伤害信号
signal on_damaged(hitbox:HitboxComponent)

func _on_area_entered(area: Area2D) -> void:
	# 如果和伤害盒碰撞
	if area is HitboxComponent:
		on_damaged.emit(area)
