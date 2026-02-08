extends Area2D
# 受击盒组件
class_name HurtboxComponent
# 收到伤害信号
signal on_damaged(hitbox:HitboxComponent)

func _ready() -> void:
	# 添加到 hurtbox 组，用于爆炸效果检测
	add_to_group("hurtbox")
	
	# 连接 area_entered 信号
	if not area_entered.is_connected(_on_area_entered):
		area_entered.connect(_on_area_entered)

func _on_area_entered(area: Area2D) -> void:
	# 只处理 HitboxComponent，忽略其他 Area2D（包括其他 HurtboxComponent）
	if not area is HitboxComponent:
		return
	
	var hitbox = area as HitboxComponent
	
	# 调试日志：记录伤害来源
	var attacker_name = "未知"
	var weapon_name = "未知"
	
	if hitbox.source and is_instance_valid(hitbox.source):
		attacker_name = hitbox.source.name
	
	if hitbox.get_parent():
		weapon_name = hitbox.get_parent().name
	
	print("[HurtboxComponent] ========== 受到攻击！==========")
	print("[HurtboxComponent] 受击者: %s" % get_parent().name)
	print("[HurtboxComponent] 受击者位置: ", global_position)
	print("[HurtboxComponent] 攻击者: %s" % attacker_name)
	print("[HurtboxComponent] 武器: %s" % weapon_name)
	print("[HurtboxComponent] 伤害: %.1f" % hitbox.damage)
	print("[HurtboxComponent] 暴击: %s" % ("是" if hitbox.critical else "否"))
	
	on_damaged.emit(hitbox)
