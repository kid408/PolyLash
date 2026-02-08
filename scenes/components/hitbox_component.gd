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

func _ready() -> void:
	# 确保 area_entered 信号已连接
	if not area_entered.is_connected(_on_area_entered):
		area_entered.connect(_on_area_entered)

# 启用检测
func enable() -> void:
	# 【修复】立即启用，不使用 set_deferred
	# set_deferred 会延迟到下一帧，导致短时间攻击时碰撞检测来不及生效
	monitoring = true
	monitorable = true
	
	# 调试：列出所有子节点
	print("[HitboxComponent] Hitbox 启用 - ", get_parent().name if get_parent() else "未知")
	print("[HitboxComponent] monitoring: ", monitoring)
	print("[HitboxComponent] monitorable: ", monitorable)
	print("[HitboxComponent] 子节点数量: ", get_child_count())
	for i in range(get_child_count()):
		var child = get_child(i)
		print("[HitboxComponent]   - 子节点 ", i, ": ", child.name, " (", child.get_class(), ")")
		if child is CollisionShape2D:
			print("[HitboxComponent]     - disabled: ", child.disabled)
			print("[HitboxComponent]     - shape: ", child.shape)
			print("[HitboxComponent]     - position: ", child.position)
			print("[HitboxComponent]     - global_position: ", child.global_position)
	
# 关闭检测
func disable()-> void:
	# 【修复】立即禁用，不使用 set_deferred
	monitoring = false
	monitorable = false
	print("[HitboxComponent] Hitbox 禁用 - ", get_parent().name if get_parent() else "未知")
	print("[HitboxComponent] monitoring: ", monitoring)
	print("[HitboxComponent] monitorable: ", monitorable)
	
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
		print("[HitboxComponent] ========== 检测到碰撞！==========")
		print("[HitboxComponent] 攻击方: ", get_parent().name if get_parent() else "未知")
		print("[HitboxComponent] 攻击方位置: ", global_position)
		print("[HitboxComponent] 受击方: ", area.get_parent().name if area.get_parent() else "未知")
		print("[HitboxComponent] 受击方位置: ", area.global_position)
		print("[HitboxComponent] 伤害: ", damage)
		print("[HitboxComponent] 发射者: ", source.name if source else "无")
		on_hit_hurtbox.emit(area)
