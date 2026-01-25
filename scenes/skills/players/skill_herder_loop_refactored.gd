extends SkillDrawingBase
class_name SkillHerderLoopRefactored

## ==============================================================================
## 牧羊人Q技能 - 画圈几何击杀（重构版）
## ==============================================================================
## 
## 功能说明:
## - 继承SkillDrawingBase，复用能量消耗和划线逻辑
## - 只需实现牧群特效的生成逻辑（线段伤害和几何击杀）
## - 能量消耗、闭合检测等由基类统一管理
## 
## ==============================================================================

# ==============================================================================
# 牧群技能专属参数（从CSV加载）
# ==============================================================================

## 冲刺速度（基础值）
var dash_speed: float = 2000.0

## 冲刺基础伤害
var dash_base_damage: int = 50

## 击退力度
var dash_knockback: float = 2.0

## 几何遮罩颜色
var geometry_mask_color: Color = Color(1, 0.0, 0.0, 0.6)

# ==============================================================================
# 实现基类虚函数
# ==============================================================================

## 生成牧群线段伤害效果（未闭合状态）
func _spawn_line_effect(start: Vector2, end: Vector2) -> void:
	# 创建伤害区域
	var area = Area2D.new()
	area.global_position = Vector2.ZERO
	area.collision_mask = 2
	area.monitorable = false
	area.monitoring = true
	
	# 视觉效果
	var line = Line2D.new()
	line.add_point(start)
	line.add_point(end)
	line.width = 12.0
	line.default_color = Color(1.0, 0.8, 0.2, 0.9)
	line.begin_cap_mode = Line2D.LINE_CAP_ROUND
	line.end_cap_mode = Line2D.LINE_CAP_ROUND
	area.add_child(line)
	
	get_tree().current_scene.add_child(area)
	
	# 立即检测伤害
	var enemies = get_tree().get_nodes_in_group("enemies")
	var hit_count = 0
	
	for enemy in enemies:
		if not is_instance_valid(enemy):
			continue
		
		var enemy_pos = enemy.global_position
		var closest_point = Geometry2D.get_closest_point_to_segment(enemy_pos, start, end)
		var distance = enemy_pos.distance_to(closest_point)
		
		if distance < 40.0:
			if enemy.has_node("HealthComponent"):
				enemy.health_component.take_damage(dash_base_damage)
				hit_count += 1
				Global.spawn_floating_text(enemy.global_position, str(dash_base_damage), Color.YELLOW)
	
	if hit_count > 0:
		Global.on_camera_shake.emit(3.0 * hit_count, 0.15)
	
	# 淡出动画后消失
	var tween = area.create_tween()
	tween.tween_property(line, "modulate:a", 0.0, 0.3)
	tween.tween_callback(func():
		if is_instance_valid(area):
			area.queue_free()
	)

## 生成几何击杀效果（闭合状态）
func _spawn_area_effect(polygon: PackedVector2Array) -> void:
	if polygon.size() < 3:
		return
	
	print("[SkillHerderLoop] 触发几何击杀！多边形点数: %d" % polygon.size())
	
	# 计算圈内敌人
	var enemies_in_circle = 0
	var enemies = get_tree().get_nodes_in_group("enemies")
	
	for enemy in enemies:
		if not is_instance_valid(enemy):
			continue
		
		if Geometry2D.is_point_in_polygon(enemy.global_position, polygon):
			enemies_in_circle += 1
			
			# 秒杀圈内敌人
			if enemy.has_node("HealthComponent"):
				enemy.health_component.take_damage(999999)
	
	if enemies_in_circle > 0:
		Global.spawn_floating_text(polygon[0], "HERDED x%d" % enemies_in_circle, Color.GOLD)
		Global.on_camera_shake.emit(10.0 * enemies_in_circle, 0.3)
		
		# 根据击杀数量给予奖励
		_apply_herder_rewards(enemies_in_circle)

## 获取规划线条颜色（牧群白色）
func _get_line_color() -> Color:
	return Color(1.0, 1.0, 1.0, 0.5)

## 获取闭合提示颜色（牧群红色）
func _get_closure_color() -> Color:
	return Color(1.0, 0.2, 0.2, 1.0)

# ==============================================================================
# 牧群奖励系统
# ==============================================================================

## 应用牧群奖励
func _apply_herder_rewards(kill_count: int) -> void:
	if not is_instance_valid(skill_owner):
		return
	
	# 小圈奖励 (1-2个怪)
	if kill_count >= 1 and kill_count <= 2:
		var energy_refund = energy_cost * 0.8 * 2
		if energy_refund > 0 and skill_owner.has_method("gain_energy"):
			skill_owner.gain_energy(energy_refund)
		Global.spawn_floating_text(skill_owner.global_position, "GOOD!", Color(0.5, 1.0, 0.5))
	
	# 大圈奖励 (10+个怪)
	elif kill_count >= 10:
		# 增加护甲
		if "armor" in skill_owner and "max_armor" in skill_owner:
			if skill_owner.armor < skill_owner.max_armor:
				skill_owner.armor = min(skill_owner.armor + 3, skill_owner.max_armor)
				if skill_owner.has_signal("armor_changed"):
					skill_owner.armor_changed.emit(skill_owner.armor)
		
		# 恢复生命
		if skill_owner.has_node("HealthComponent"):
			var health_component = skill_owner.get_node("HealthComponent")
			if health_component.current_health < health_component.max_health:
				var heal_amount = 15
				health_component.current_health = min(
					health_component.current_health + heal_amount,
					health_component.max_health
				)
				health_component.on_health_changed.emit(
					health_component.current_health,
					health_component.max_health
				)
				Global.spawn_floating_text(skill_owner.global_position, "+%d HP" % heal_amount, Color.GREEN)
		
		Global.spawn_floating_text(skill_owner.global_position, "DIVINE!", Color(2.0, 2.0, 0.0))
		Global.on_camera_shake.emit(15.0, 0.3)
	
	# 中圈奖励 (3-9个怪)
	else:
		var energy_refund = energy_cost * 0.5 * 2
		if energy_refund > 0 and skill_owner.has_method("gain_energy"):
			skill_owner.gain_energy(energy_refund)
		Global.spawn_floating_text(skill_owner.global_position, "PERFECT!", Color(1.0, 1.0, 0.0))
