extends Node
class_name StatusComponent

## ==============================================================================
## 状态组件 - Status Component
## ==============================================================================
## 
## 功能说明:
## - 管理单位的所有状态效果（Debuff/Buff）
## - 支持燃烧(Burn)、减速(Slow)、诅咒(Curse)等状态
## - 自动处理状态持续时间和叠加
## - 支持 P2-3 Debuff 延长机制
## - 支持 P2-4 诅咒叠加机制
## 
## ==============================================================================

# 状态数据结构
# {
#   "status_name": {
#     "duration": float,      # 剩余持续时间
#     "stacks": int,          # 叠加层数
#     "value": float,         # 效果值（伤害、减速比例等）
#     "tick_interval": float, # Tick 间隔（DoT 效果）
#     "tick_timer": float     # Tick 计时器
#   }
# }
var active_statuses: Dictionary = {}

# 拥有者引用
var owner_unit: Node2D = null

func _ready() -> void:
	# 获取父节点作为拥有者
	if get_parent():
		owner_unit = get_parent()
		print("[StatusComponent] 初始化，拥有者: %s" % owner_unit.name)

func _process(delta: float) -> void:
	if Global.game_paused:
		return
	
	# 更新所有状态
	_update_statuses(delta)

## 应用状态效果
## @param status_name: 状态名称（如 "burn", "slow", "curse"）
## @param duration: 持续时间（秒）
## @param value: 效果值（伤害、减速比例等）
## @param stacks: 叠加层数（默认1）
## @param tick_interval: Tick 间隔（DoT 效果，默认1秒）
func apply_status(status_name: String, duration: float, value: float = 0.0, stacks: int = 1, tick_interval: float = 1.0) -> void:
	# P2-3: Debuff 延长（咒术师 Lv.1）
	var final_duration = duration
	if BondManager.has_mechanic("debuff_duration"):
		var extension = BondManager.get_mechanic_value("debuff_duration")
		final_duration *= (1.0 + extension)
		print("[StatusComponent] [P2-3] Debuff 延长: %s, %.1f秒 -> %.1f秒 (+%.0f%%)" % [
			status_name,
			duration,
			final_duration,
			extension * 100
		])
	
	# 如果状态已存在，刷新持续时间并增加层数
	if active_statuses.has(status_name):
		var status = active_statuses[status_name]
		status.duration = max(status.duration, final_duration)  # 取最大持续时间
		status.stacks += stacks
		status.value = value  # 更新效果值
		print("[StatusComponent] 刷新状态: %s, 层数: %d, 持续时间: %.1f秒" % [
			status_name,
			status.stacks,
			status.duration
		])
	else:
		# 创建新状态
		active_statuses[status_name] = {
			"duration": final_duration,
			"stacks": stacks,
			"value": value,
			"tick_interval": tick_interval,
			"tick_timer": 0.0
		}
		print("[StatusComponent] 应用新状态: %s, 层数: %d, 持续时间: %.1f秒, 效果值: %.1f" % [
			status_name,
			stacks,
			final_duration,
			value
		])
		
		# 触发状态应用事件
		_on_status_applied(status_name)

## 移除状态
func remove_status(status_name: String) -> void:
	if active_statuses.has(status_name):
		active_statuses.erase(status_name)
		print("[StatusComponent] 移除状态: %s" % status_name)
		_on_status_removed(status_name)

## 检查是否有某个状态
func has_status(status_name: String) -> bool:
	return active_statuses.has(status_name)

## 获取状态层数
func get_status_stacks(status_name: String) -> int:
	if active_statuses.has(status_name):
		return active_statuses[status_name].stacks
	return 0

## 获取状态效果值
func get_status_value(status_name: String) -> float:
	if active_statuses.has(status_name):
		return active_statuses[status_name].value
	return 0.0

## 更新所有状态
func _update_statuses(delta: float) -> void:
	var statuses_to_remove: Array[String] = []
	
	for status_name in active_statuses.keys():
		var status = active_statuses[status_name]
		
		# 更新持续时间
		status.duration -= delta
		
		# 更新 Tick 计时器
		status.tick_timer += delta
		
		# 触发 Tick 效果
		if status.tick_timer >= status.tick_interval:
			status.tick_timer = 0.0
			_on_status_tick(status_name, status)
		
		# 检查是否过期
		if status.duration <= 0:
			statuses_to_remove.append(status_name)
	
	# 移除过期状态
	for status_name in statuses_to_remove:
		remove_status(status_name)

## 状态应用时的回调
func _on_status_applied(status_name: String) -> void:
	if not is_instance_valid(owner_unit):
		return
	
	match status_name:
		"burn":
			# 燃烧效果：视觉反馈
			_apply_burn_visual()
		"slow":
			# 减速效果：降低移动速度
			_apply_slow_effect()
		"curse":
			# 诅咒效果：视觉反馈
			_apply_curse_visual()

## 状态移除时的回调
func _on_status_removed(status_name: String) -> void:
	if not is_instance_valid(owner_unit):
		return
	
	match status_name:
		"burn":
			_remove_burn_visual()
		"slow":
			_remove_slow_effect()
		"curse":
			_remove_curse_visual()

## 状态 Tick 时的回调（DoT 效果）
func _on_status_tick(status_name: String, status: Dictionary) -> void:
	if not is_instance_valid(owner_unit):
		return
	
	match status_name:
		"burn":
			# 燃烧伤害
			_apply_burn_damage(status)
		"curse":
			# 诅咒伤害（基于层数）
			_apply_curse_damage(status)

## 应用燃烧伤害
func _apply_burn_damage(status: Dictionary) -> void:
	if not owner_unit.has_node("HealthComponent"):
		return
	
	var damage = int(status.value)
	owner_unit.get_node("HealthComponent").take_damage(damage)
	Global.spawn_floating_text(owner_unit.global_position, "BURN!", Color(1.0, 0.5, 0.0))

## 应用诅咒伤害（P2-4）
func _apply_curse_damage(status: Dictionary) -> void:
	if not owner_unit.has_node("HealthComponent"):
		return
	
	# 诅咒伤害 = 基础伤害 * 层数
	var base_damage = status.value
	var total_damage = int(base_damage * status.stacks)
	
	owner_unit.get_node("HealthComponent").take_damage(total_damage)
	Global.spawn_floating_text(owner_unit.global_position, "CURSE x%d!" % status.stacks, Color(0.5, 0.0, 0.5))
	
	print("[StatusComponent] [P2-4] 诅咒伤害: %d (基础%.1f x %d层)" % [
		total_damage,
		base_damage,
		status.stacks
	])

## 应用燃烧视觉效果
func _apply_burn_visual() -> void:
	if not owner_unit.has_node("Visuals"):
		return
	
	var visuals = owner_unit.get_node("Visuals")
	var tween = owner_unit.create_tween()
	tween.set_loops()
	tween.tween_property(visuals, "modulate", Color(2.0, 0.5, 0.0, 1.0), 0.3)
	tween.tween_property(visuals, "modulate", Color(1.0, 1.0, 1.0, 1.0), 0.3)

## 移除燃烧视觉效果
func _remove_burn_visual() -> void:
	if not owner_unit.has_node("Visuals"):
		return
	
	var visuals = owner_unit.get_node("Visuals")
	visuals.modulate = Color(1.0, 1.0, 1.0, 1.0)

## 应用减速效果
func _apply_slow_effect() -> void:
	if not "speed" in owner_unit:
		return
	
	var status = active_statuses["slow"]
	var slow_ratio = status.value  # 例如 0.5 = 减速 50%
	
	# 保存原始速度（如果还没保存）
	if not "original_speed" in owner_unit:
		owner_unit.set_meta("original_speed", owner_unit.speed)
	
	# 应用减速
	var original_speed = owner_unit.get_meta("original_speed")
	owner_unit.speed = original_speed * (1.0 - slow_ratio)
	
	print("[StatusComponent] 应用减速: %.0f -> %.0f (减速%.0f%%)" % [
		original_speed,
		owner_unit.speed,
		slow_ratio * 100
	])

## 移除减速效果
func _remove_slow_effect() -> void:
	if not "speed" in owner_unit:
		return
	
	# 恢复原始速度
	if "original_speed" in owner_unit:
		owner_unit.speed = owner_unit.get_meta("original_speed")
		owner_unit.remove_meta("original_speed")
		print("[StatusComponent] 移除减速，恢复速度: %.0f" % owner_unit.speed)

## 应用诅咒视觉效果
func _apply_curse_visual() -> void:
	if not owner_unit.has_node("Visuals"):
		return
	
	var visuals = owner_unit.get_node("Visuals")
	var tween = owner_unit.create_tween()
	tween.set_loops()
	tween.tween_property(visuals, "modulate", Color(0.5, 0.0, 0.5, 1.0), 0.5)
	tween.tween_property(visuals, "modulate", Color(1.0, 1.0, 1.0, 1.0), 0.5)

## 移除诅咒视觉效果
func _remove_curse_visual() -> void:
	if not owner_unit.has_node("Visuals"):
		return
	
	var visuals = owner_unit.get_node("Visuals")
	visuals.modulate = Color(1.0, 1.0, 1.0, 1.0)

## 清除所有状态（用于单位死亡时）
func clear_all_statuses() -> void:
	for status_name in active_statuses.keys():
		_on_status_removed(status_name)
	active_statuses.clear()
	print("[StatusComponent] 清除所有状态")
