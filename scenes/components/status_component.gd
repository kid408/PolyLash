extends Node
class_name StatusComponent

## ==============================================================================
## 状态组件 - Status Component
## ==============================================================================
## 
## 功能说明:
## - 管理单位的所有状态效果（Debuff/Buff）
## - 支持燃烧(Burn)、减速(Slow)、诅咒(Curse)等状态
## - 支持冰冻(Freeze)、沉默(Silence)、恐惧(Fear)、标记(Marked)、石化(Petrify)、中毒(Poison)
## - 自动处理状态持续时间和叠加
## - 支持 P2-3 Debuff 延长机制
## - 支持 P2-4 诅咒叠加机制
## - 支持状态优先级处理
## 
## ==============================================================================

# 状态优先级表（数值越高优先级越高）
const STATUS_PRIORITY = {
	"petrify": 5,   # 石化 - 最高优先级
	"freeze": 4,    # 冰冻
	"fear": 3,      # 恐惧
	"silence": 2,   # 沉默
	"slow": 1,      # 减速
	"burn": 0,      # 燃烧（DOT，不影响行动）
	"curse": 0,     # 诅咒（DOT，不影响行动）
	"poison": 0,    # 中毒（DOT，不影响行动）
	"marked": 0,    # 标记（不影响行动）
}

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

# 恐惧状态的施法者引用（用于计算逃跑方向）
var fear_caster: Node2D = null

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
## @param status_name: 状态名称（如 "burn", "slow", "curse", "freeze", "silence", "fear", "marked", "petrify", "poison"）
## @param duration: 持续时间（秒）
## @param value: 效果值（伤害、减速比例等）
## @param stacks: 叠加层数（默认1）
## @param tick_interval: Tick 间隔（DoT 效果，默认1秒）
## @param caster: 施法者引用（用于 fear 状态计算逃跑方向，可选）
func apply_status(status_name: String, duration: float, value: float = 0.0, stacks: int = 1, tick_interval: float = 1.0, caster: Node2D = null) -> void:
	# P2-3: Debuff 延长（咒术师 Lv.1）
	var final_duration = duration
	if BondManager.has_mechanic("abnormal_duration_scale") or BondManager.has_mechanic("debuff_duration"):
		var duration_scale = BondManager.get_mechanic_value("abnormal_duration_scale")
		if duration_scale <= 0.0:
			duration_scale = 1.0 + max(0.0, BondManager.get_mechanic_value("debuff_duration"))
		final_duration *= duration_scale
		print("[StatusComponent] [P2-3] Debuff 延长: %s, %.1f秒 -> %.1f秒 (+%.0f%%)" % [
			status_name,
			duration,
			final_duration,
			(duration_scale - 1.0) * 100
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
		if status_name == "fear" and caster != null:
			fear_caster = caster
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
			_apply_burn_visual()
		"slow":
			_apply_slow_effect()
		"curse":
			_apply_curse_visual()
		"freeze":
			_apply_freeze_effect()
		"silence":
			_apply_silence_effect()
		"fear":
			_apply_fear_effect()
		"marked":
			_apply_marked_effect()
		"petrify":
			_apply_petrify_effect()
		"poison":
			_apply_poison_effect()

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
		"freeze":
			_remove_freeze_effect()
		"silence":
			_remove_silence_effect()
		"fear":
			_remove_fear_effect()
		"marked":
			_remove_marked_effect()
		"petrify":
			_remove_petrify_effect()
		"poison":
			_remove_poison_effect()

## 状态 Tick 时的回调（DoT 效果）
func _on_status_tick(status_name: String, status: Dictionary) -> void:
	if not is_instance_valid(owner_unit):
		return
	
	match status_name:
		"burn":
			_apply_burn_damage(status)
		"curse":
			_apply_curse_damage(status)
		"poison":
			_apply_poison_damage(status)
		"fear":
			_update_fear_movement(status)

## 应用燃烧伤害
func _apply_burn_damage(status: Dictionary) -> void:
	if not owner_unit.has_node("HealthComponent"):
		return
	
	var damage = int(status.value)
	owner_unit.get_node("HealthComponent").take_damage(damage, {
		"source": self,
		"kind": "burn_status",
		"damage_type": "DMG_DOT",
	})
	Global.spawn_floating_text(owner_unit.global_position, "BURN!", Color(1.0, 0.5, 0.0))

## 应用诅咒伤害（P2-4）
func _apply_curse_damage(status: Dictionary) -> void:
	if not owner_unit.has_node("HealthComponent"):
		return
	
	# 诅咒伤害 = 基础伤害 * 层数
	var base_damage = status.value
	var total_damage = int(base_damage * status.stacks)
	
	owner_unit.get_node("HealthComponent").take_damage(total_damage, {
		"source": self,
		"kind": "curse_status",
		"damage_type": "DMG_DOT",
	})
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

## ============================================================================
## 冰冻状态 (Freeze) - 停止移动和攻击
## ============================================================================

func _apply_freeze_effect() -> void:
	# 保存原始移动状态
	if "can_move" in owner_unit:
		if not owner_unit.has_meta("original_can_move"):
			owner_unit.set_meta("original_can_move", owner_unit.can_move)
		owner_unit.can_move = false
	
	# 灰蓝色视觉
	if owner_unit.has_node("Visuals"):
		var visuals = owner_unit.get_node("Visuals")
		visuals.modulate = Color(0.5, 0.7, 1.0, 1.0)
	
	print("[StatusComponent] 冰冻效果：停止移动和攻击")

func _remove_freeze_effect() -> void:
	# 恢复移动状态
	if "can_move" in owner_unit:
		if owner_unit.has_meta("original_can_move"):
			owner_unit.can_move = owner_unit.get_meta("original_can_move")
			owner_unit.remove_meta("original_can_move")
		else:
			owner_unit.can_move = true
	
	# 恢复视觉（如果没有其他控制状态）
	_restore_visual_if_no_control_status()
	
	print("[StatusComponent] 移除冰冻效果")

## ============================================================================
## 沉默状态 (Silence) - 阻止特殊技能
## ============================================================================

func _apply_silence_effect() -> void:
	# 设置沉默标记
	owner_unit.set_meta("silenced", true)
	
	# 紫色视觉
	if owner_unit.has_node("Visuals"):
		var visuals = owner_unit.get_node("Visuals")
		visuals.modulate = Color(0.7, 0.3, 0.9, 1.0)
	
	print("[StatusComponent] 沉默效果：阻止特殊技能")

func _remove_silence_effect() -> void:
	owner_unit.remove_meta("silenced")
	_restore_visual_if_no_control_status()
	print("[StatusComponent] 移除沉默效果")

## ============================================================================
## 恐惧状态 (Fear) - 逃跑行为（远离施法者）
## ============================================================================

func _apply_fear_effect() -> void:
	# 保存原始移动状态
	if "can_move" in owner_unit and not owner_unit.has_meta("original_can_move"):
		owner_unit.set_meta("original_can_move", owner_unit.can_move)
	
	# 设置恐惧标记
	owner_unit.set_meta("feared", true)
	
	# 绿色视觉
	if owner_unit.has_node("Visuals"):
		var visuals = owner_unit.get_node("Visuals")
		visuals.modulate = Color(0.3, 0.9, 0.3, 1.0)
	
	print("[StatusComponent] 恐惧效果：逃跑行为")

func _remove_fear_effect() -> void:
	owner_unit.remove_meta("feared")
	fear_caster = null
	_restore_visual_if_no_control_status()
	print("[StatusComponent] 移除恐惧效果")

## 更新恐惧逃跑移动（每 tick 调用）
func _update_fear_movement(status: Dictionary) -> void:
	if not is_instance_valid(owner_unit):
		return
	if not "global_position" in owner_unit:
		return
	
	var flee_speed = status.value  # 逃跑速度
	var flee_dir: Vector2
	
	# 计算逃跑方向：远离施法者
	if is_instance_valid(fear_caster) and "global_position" in fear_caster:
		flee_dir = (owner_unit.global_position - fear_caster.global_position).normalized()
	else:
		# 无法确定施法者位置，使用随机方向
		flee_dir = Vector2(randf_range(-1, 1), randf_range(-1, 1)).normalized()
	
	# 应用逃跑移动
	owner_unit.global_position += flee_dir * flee_speed * status.tick_interval

## ============================================================================
## 标记状态 (Marked) - 受伤增加百分比
## ============================================================================

func _apply_marked_effect() -> void:
	# 设置标记元数据（伤害放大比例存储在 status.value 中）
	owner_unit.set_meta("marked", true)
	
	# 红色标记视觉
	if owner_unit.has_node("Visuals"):
		var visuals = owner_unit.get_node("Visuals")
		visuals.modulate = Color(1.5, 0.3, 0.3, 1.0)
	
	print("[StatusComponent] 标记效果：受伤增加")

func _remove_marked_effect() -> void:
	owner_unit.remove_meta("marked")
	_restore_visual_if_no_control_status()
	print("[StatusComponent] 移除标记效果")

## 获取标记伤害放大倍率
## 返回最终伤害乘数：1.0 + marked_value（例如 marked_value=0.5 则返回 1.5）
func get_marked_damage_multiplier() -> float:
	if active_statuses.has("marked"):
		return 1.0 + active_statuses["marked"].value
	return 1.0

## ============================================================================
## 石化状态 (Petrify) - 完全不可行动
## ============================================================================

func _apply_petrify_effect() -> void:
	# 保存原始移动状态
	if "can_move" in owner_unit:
		if not owner_unit.has_meta("original_can_move"):
			owner_unit.set_meta("original_can_move", owner_unit.can_move)
		owner_unit.can_move = false
	
	# 设置石化标记
	owner_unit.set_meta("petrified", true)
	
	# 灰色视觉
	if owner_unit.has_node("Visuals"):
		var visuals = owner_unit.get_node("Visuals")
		visuals.modulate = Color(0.5, 0.5, 0.5, 1.0)
	
	print("[StatusComponent] 石化效果：完全不可行动")

func _remove_petrify_effect() -> void:
	# 恢复移动状态
	if "can_move" in owner_unit:
		if owner_unit.has_meta("original_can_move"):
			owner_unit.can_move = owner_unit.get_meta("original_can_move")
			owner_unit.remove_meta("original_can_move")
		else:
			owner_unit.can_move = true
	
	owner_unit.remove_meta("petrified")
	_restore_visual_if_no_control_status()
	print("[StatusComponent] 移除石化效果")

## ============================================================================
## 中毒状态 (Poison) - DOT 伤害
## ============================================================================

func _apply_poison_effect() -> void:
	# 绿色视觉（深绿，与恐惧的亮绿区分）
	if owner_unit.has_node("Visuals"):
		var visuals = owner_unit.get_node("Visuals")
		var tween = owner_unit.create_tween()
		tween.set_loops()
		tween.tween_property(visuals, "modulate", Color(0.2, 0.8, 0.2, 1.0), 0.4)
		tween.tween_property(visuals, "modulate", Color(0.4, 1.0, 0.4, 1.0), 0.4)
	
	print("[StatusComponent] 中毒效果：持续伤害")

func _remove_poison_effect() -> void:
	_restore_visual_if_no_control_status()
	print("[StatusComponent] 移除中毒效果")

## 应用中毒伤害
func _apply_poison_damage(status: Dictionary) -> void:
	if not owner_unit.has_node("HealthComponent"):
		return
	
	var damage = int(status.value * status.stacks)
	owner_unit.get_node("HealthComponent").take_damage(damage, {
		"source": self,
		"kind": "poison_status",
		"damage_type": "DMG_DOT",
	})
	Global.spawn_floating_text(owner_unit.global_position, "POISON!", Color(0.2, 0.8, 0.2))

## ============================================================================
## 优先级处理
## ============================================================================

## 获取当前最高优先级的控制状态
## 只返回优先级 > 0 的状态（控制类状态）
## 返回状态名称字符串，无控制状态时返回空字符串
func get_active_control_status() -> String:
	var highest_priority: int = -1
	var highest_status: String = ""
	
	for status_name in active_statuses.keys():
		var priority = STATUS_PRIORITY.get(status_name, 0)
		if priority > highest_priority and priority > 0:
			highest_priority = priority
			highest_status = status_name
	
	return highest_status

## ============================================================================
## 视觉恢复辅助
## ============================================================================

## 当移除一个状态时，检查是否还有其他状态需要显示视觉效果
## 如果没有，恢复原始颜色
func _restore_visual_if_no_control_status() -> void:
	if not is_instance_valid(owner_unit):
		return
	if not owner_unit.has_node("Visuals"):
		return
	
	var visuals = owner_unit.get_node("Visuals")
	
	# 检查是否还有其他活跃状态需要显示视觉
	# 按优先级从高到低检查，显示最高优先级状态的颜色
	var control_status = get_active_control_status()
	if control_status != "":
		match control_status:
			"petrify":
				visuals.modulate = Color(0.5, 0.5, 0.5, 1.0)
			"freeze":
				visuals.modulate = Color(0.5, 0.7, 1.0, 1.0)
			"fear":
				visuals.modulate = Color(0.3, 0.9, 0.3, 1.0)
			"silence":
				visuals.modulate = Color(0.7, 0.3, 0.9, 1.0)
			"slow":
				visuals.modulate = Color(0.6, 0.8, 1.0, 1.0)
		return
	
	# 检查非控制状态
	if active_statuses.has("marked"):
		visuals.modulate = Color(1.5, 0.3, 0.3, 1.0)
		return
	if active_statuses.has("poison"):
		# poison 使用 tween 动画，不需要手动设置
		return
	if active_statuses.has("burn"):
		# burn 使用 tween 动画，不需要手动设置
		return
	if active_statuses.has("curse"):
		return
	
	# 没有任何状态，恢复原始颜色
	visuals.modulate = Color(1.0, 1.0, 1.0, 1.0)

## 清除所有状态（用于单位死亡时）
func clear_all_statuses() -> void:
	for status_name in active_statuses.keys():
		_on_status_removed(status_name)
	active_statuses.clear()
	print("[StatusComponent] 清除所有状态")
