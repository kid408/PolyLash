extends Area2D
class_name HitboxComponent

signal on_hit_hurtbox(hurtbox:HurtboxComponent)

# 伤害
var damage := 1.0
# 暴击
var critical := false
# 击退
var knockback_power :=0.0
var source :Node2D

# 启用检测
func enable() -> void:
	set_deferred("monitoring",true)
	set_deferred("monitorable",true)
	
# 关闭检测
func disable()-> void:
	set_deferred("monitoring",false)
	set_deferred("monitorable",false)
	
# 设置数据
func setup(damage:float,critical:bool,knockback:float,source:Node2D) -> void:
	self.damage = damage
	self.critical = critical
	knockback_power = knockback
	self.source = source

# 检测到单位，发送信号
func _on_area_entered(area: Area2D) -> void:
	# 如果和受击盒碰撞
	if area is HurtboxComponent:
		on_hit_hurtbox.emit(area)
