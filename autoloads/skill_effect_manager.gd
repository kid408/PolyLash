extends Node

## ==============================================================================
## 技能效果生命周期管理器 - 统一管理所有技能的场景效果
## ==============================================================================
## 
## 功能说明:
## - 统一管理技能效果的生命周期（火海、风墙、锯条、地雷等）
## - 提供独立的伤害、物理效果、视觉效果管理
## - 不依赖技能实例，即使角色切换也能继续工作
## 
## 使用方法:
##   var effect_id = SkillEffectManager.create_area_effect({
##       "polygon": points,
##       "damage": 40,
##       "damage_interval": 0.3,
##       "duration": 5.0,
##       "color": Color.RED,
##       "pull_to_center": true,
##       "pull_force": 400.0
##   })
## 
## ==============================================================================

## 效果节点字典 {effect_id: effect_data}
var active_effects: Dictionary = {}

## 效果ID计数器
var next_effect_id: int = 0

# ==============================================================================
# 创建效果
# ==============================================================================

## 创建区域效果（多边形）
## @param config: 配置字典
##   - polygon: PackedVector2Array (必需)
##   - damage: int (可选，默认0)
##   - damage_interval: float (可选，默认0.5)
##   - duration: float (可选，默认5.0)
##   - color: Color (可选，默认白色)
##   - pull_to_center: bool (可选，默认false)
##   - pull_force: float (可选，默认0)
##   - pull_interval: float (可选，默认0.05)
##   - z_index: int (可选，默认10)
##   - fade_in_duration: float (可选，默认0.2)
##   - fade_out_duration: float (可选，默认0.3)
## @return: effect_id (用于后续操作)
func create_area_effect(config: Dictionary) -> int:
	var effect_id = next_effect_id
	next_effect_id += 1
	
	# 验证必需参数
	if not config.has("polygon"):
		push_error("[SkillEffectManager] 缺少必需参数: polygon")
		return -1
	
	var points: PackedVector2Array = config["polygon"]
	if points.size() < 3:
		push_error("[SkillEffectManager] 多边形点数不足: %d" % points.size())
		return -1
	
	# 创建 Area2D
	var area = Area2D.new()
	area.collision_mask = 2
	area.monitorable = false
	area.monitoring = true
	area.name = "SkillEffect_%d" % effect_id
	
	# 碰撞形状
	var col = CollisionPolygon2D.new()
	col.polygon = points
	area.add_child(col)
	
	# 视觉效果
	var vis_poly = Polygon2D.new()
	vis_poly.polygon = points
	vis_poly.color = Color(1.0, 1.0, 1.0, 0.0)
	vis_poly.z_index = config.get("z_index", 10)
	area.add_child(vis_poly)
	
	# 添加到场景
	get_tree().current_scene.add_child(area)
	
	# 保存效果数据
	var effect_data = {
		"area": area,
		"vis_poly": vis_poly,
		"config": config,
		"elapsed": 0.0,
		"phase": "fade_in"
	}
	active_effects[effect_id] = effect_data
	
	# 淡入动画
	var fade_in_duration = config.get("fade_in_duration", 0.2)
	var target_color = config.get("color", Color.WHITE)
	var tween = area.create_tween()
	tween.tween_property(vis_poly, "color", target_color, fade_in_duration).from(Color(target_color.r, target_color.g, target_color.b, 0.0))
	
	# 计算中心点（用于吸附效果）
	if config.get("pull_to_center", false):
		var center = Vector2.ZERO
		for p in points:
			center += p
		center /= points.size()
		effect_data["center"] = center
	
	# 启动效果管理
	_start_effect_lifecycle(effect_id)
	
	return effect_id

## 创建线段效果（火线、风墙等）
## @param config: 配置字典
##   - start: Vector2 (必需)
##   - end: Vector2 (必需)
##   - width: float (可选，默认24)
##   - damage: int (可选，默认0)
##   - damage_interval: float (可选，默认0.5)
##   - duration: float (可选，默认5.0)
##   - color: Color (可选，默认白色)
##   - pull_to_line: bool (可选，默认false)
##   - pull_force: float (可选，默认0)
## @return: effect_id
func create_line_effect(config: Dictionary) -> int:
	var effect_id = next_effect_id
	next_effect_id += 1
	
	# 验证必需参数
	if not config.has("start") or not config.has("end"):
		push_error("[SkillEffectManager] 缺少必需参数: start 或 end")
		return -1
	
	var start: Vector2 = config["start"]
	var end: Vector2 = config["end"]
	var width: float = config.get("width", 24.0)
	
	# 创建 Area2D
	var area = Area2D.new()
	area.position = start
	area.collision_mask = 2
	area.monitorable = false
	area.monitoring = true
	area.name = "SkillEffect_%d" % effect_id
	
	var vec = end - start
	var length = vec.length()
	var angle = vec.angle()
	
	# 碰撞形状
	var col = CollisionShape2D.new()
	var shape = RectangleShape2D.new()
	shape.size = Vector2(length, width)
	col.shape = shape
	col.position = Vector2(length / 2.0, 0)
	col.rotation = angle
	area.add_child(col)
	
	# 视觉效果
	var vis_line = Line2D.new()
	vis_line.add_point(Vector2.ZERO)
	vis_line.add_point(end - start)
	vis_line.width = width
	vis_line.default_color = config.get("color", Color.WHITE)
	vis_line.begin_cap_mode = Line2D.LINE_CAP_ROUND
	vis_line.end_cap_mode = Line2D.LINE_CAP_ROUND
	area.add_child(vis_line)
	
	# 添加到场景
	get_tree().current_scene.add_child(area)
	
	# 保存效果数据
	var effect_data = {
		"area": area,
		"vis_line": vis_line,
		"config": config,
		"elapsed": 0.0,
		"phase": "active",
		"start": start,
		"end": end
	}
	active_effects[effect_id] = effect_data
	
	# 启动效果管理
	_start_effect_lifecycle(effect_id)
	
	return effect_id

# ==============================================================================
# 生命周期管理
# ==============================================================================

## 启动效果生命周期管理
func _start_effect_lifecycle(effect_id: int) -> void:
	if not active_effects.has(effect_id):
		return
	
	var effect_data = active_effects[effect_id]
	var area = effect_data["area"]
	var config = effect_data["config"]
	
	# 创建管理 Timer
	var timer = Timer.new()
	timer.wait_time = 0.016  # ~60fps
	area.add_child(timer)
	
	timer.timeout.connect(func():
		_update_effect(effect_id, timer.wait_time)
	)
	
	timer.start()

## 更新效果
func _update_effect(effect_id: int, delta: float) -> void:
	if not active_effects.has(effect_id):
		return
	
	var effect_data = active_effects[effect_id]
	var area = effect_data["area"]
	var config = effect_data["config"]
	
	if not is_instance_valid(area):
		active_effects.erase(effect_id)
		return
	
	effect_data["elapsed"] += delta
	var duration = config.get("duration", 5.0)
	
	# 伤害 tick
	if config.get("damage", 0) > 0:
		if not effect_data.has("damage_timer"):
			effect_data["damage_timer"] = 0.0
		
		effect_data["damage_timer"] += delta
		var damage_interval = config.get("damage_interval", 0.5)
		
		if effect_data["damage_timer"] >= damage_interval:
			_apply_damage(area, config.get("damage", 0))
			effect_data["damage_timer"] = 0.0
	
	# 物理效果 tick
	if config.get("pull_to_center", false):
		if not effect_data.has("pull_timer"):
			effect_data["pull_timer"] = 0.0
		
		effect_data["pull_timer"] += delta
		var pull_interval = config.get("pull_interval", 0.05)
		
		if effect_data["pull_timer"] >= pull_interval:
			_apply_pull_to_center(area, effect_data["center"], config.get("pull_force", 0), pull_interval)
			effect_data["pull_timer"] = 0.0
	
	elif config.get("pull_to_line", false):
		if not effect_data.has("pull_timer"):
			effect_data["pull_timer"] = 0.0
		
		effect_data["pull_timer"] += delta
		var pull_interval = config.get("pull_interval", 0.05)
		
		if effect_data["pull_timer"] >= pull_interval:
			_apply_pull_to_line(area, effect_data["start"], effect_data["end"], config.get("pull_force", 0), pull_interval)
			effect_data["pull_timer"] = 0.0
	
	# 生命周期结束
	if effect_data["elapsed"] >= duration:
		_end_effect(effect_id)

## 应用伤害
func _apply_damage(area: Area2D, damage: int) -> void:
	if not is_instance_valid(area):
		return
	
	var targets = area.get_overlapping_bodies() + area.get_overlapping_areas()
	for t in targets:
		var enemy = null
		if t.is_in_group("enemies"):
			enemy = t
		elif t.owner and t.owner.is_in_group("enemies"):
			enemy = t.owner
		
		if enemy and enemy.has_node("HealthComponent"):
			enemy.health_component.take_damage(damage)

## 应用吸附到中心
func _apply_pull_to_center(area: Area2D, center: Vector2, force: float, dt: float) -> void:
	if not is_instance_valid(area):
		return
	
	var targets = area.get_overlapping_bodies() + area.get_overlapping_areas()
	for t in targets:
		var enemy = null
		if t.is_in_group("enemies"):
			enemy = t
		elif t.owner and t.owner.is_in_group("enemies"):
			enemy = t.owner
		
		if is_instance_valid(enemy):
			var dir = (center - enemy.global_position).normalized()
			enemy.global_position += dir * force * dt

## 应用吸附到线段
func _apply_pull_to_line(area: Area2D, start: Vector2, end: Vector2, force: float, dt: float) -> void:
	if not is_instance_valid(area):
		return
	
	var targets = area.get_overlapping_bodies() + area.get_overlapping_areas()
	for t in targets:
		var enemy = null
		if t.is_in_group("enemies"):
			enemy = t
		elif t.owner and t.owner.is_in_group("enemies"):
			enemy = t.owner
		
		if is_instance_valid(enemy):
			var closest_point = Geometry2D.get_closest_point_to_segment(enemy.global_position, start, end)
			var dist = enemy.global_position.distance_to(closest_point)
			
			if dist > 5.0:
				var dir = (closest_point - enemy.global_position).normalized()
				enemy.global_position += dir * force * dt

## 结束效果
func _end_effect(effect_id: int) -> void:
	if not active_effects.has(effect_id):
		return
	
	var effect_data = active_effects[effect_id]
	var area = effect_data["area"]
	var config = effect_data["config"]
	
	if not is_instance_valid(area):
		active_effects.erase(effect_id)
		return
	
	# 淡出动画
	var fade_out_duration = config.get("fade_out_duration", 0.3)
	
	if effect_data.has("vis_poly"):
		var vis_poly = effect_data["vis_poly"]
		if is_instance_valid(vis_poly):
			var tween = area.create_tween()
			tween.tween_property(vis_poly, "modulate:a", 0.0, fade_out_duration)
			tween.tween_callback(func():
				if is_instance_valid(area):
					area.queue_free()
				active_effects.erase(effect_id)
			)
			return
	
	if effect_data.has("vis_line"):
		var vis_line = effect_data["vis_line"]
		if is_instance_valid(vis_line):
			var tween = area.create_tween()
			tween.tween_property(vis_line, "modulate:a", 0.0, fade_out_duration)
			tween.tween_callback(func():
				if is_instance_valid(area):
					area.queue_free()
				active_effects.erase(effect_id)
			)
			return
	
	# 没有视觉元素，直接删除
	area.queue_free()
	active_effects.erase(effect_id)

# ==============================================================================
# 手动控制
# ==============================================================================

## 手动移除效果
func remove_effect(effect_id: int) -> void:
	if active_effects.has(effect_id):
		var effect_data = active_effects[effect_id]
		if is_instance_valid(effect_data["area"]):
			effect_data["area"].queue_free()
		active_effects.erase(effect_id)

## 清理所有效果
func clear_all_effects() -> void:
	for effect_id in active_effects.keys():
		remove_effect(effect_id)
