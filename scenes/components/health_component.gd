extends Node
# 健康组件
class_name HealthComponent

# 收到伤害信号
signal on_unit_hit
# 死亡信号
signal on_unit_died
# 生命值变回信号
signal on_health_changed(current:float,max:float)
# 最大生命值
var max_health:= 1.0:
	set(value):
		max_health = value
		# 当最大生命值改变时，发送信号更新UI
		on_health_changed.emit(current_health, max_health)
		
# 当前生命值
var current_health := 1.0:
	set(value):
		current_health = value
		# 当当前生命值改变时，发送信号更新UI
		on_health_changed.emit(current_health, max_health)

# 设置生命值数据
func setup(stats:UnitStats) -> void:
	max_health = stats.health
	current_health = max_health
	on_health_changed.emit(current_health,max_health)

# 受到伤害 从unit脚本调用过来
func take_damage(value:float) -> void:
	# 这里的判断加个容错，或者干脆去掉，依赖下面的计算
	if current_health <= 0: return 
	
	current_health -= value
	
	# 【修改】强制归零逻辑
	# 避免出现 0.000001 血量的情况
	if current_health < 0.01: 
		current_health = 0
	
	on_unit_hit.emit()
	on_health_changed.emit(current_health, max_health)
	
	# 只要归零，就触发死亡
	if current_health == 0:
		on_unit_died.emit()
		die()

# 增加生命
func heal(amount:float):
	if current_health <= 0 :
		return
	current_health += amount
	current_health = min(current_health,max_health)

# 死亡，销毁角色
func die() -> void:
	# 【删除】原来的 owner.queue_free()
	# 这里什么都不用做，或者留空，完全依赖 on_unit_died 信号
	pass
		
	
