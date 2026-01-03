extends SkillBase
class_name SkillStormEye

## ==============================================================================
## 御风者E技能 - 暴风眼
## ==============================================================================
## 
## 功能说明:
## - 按E键在玩家位置生成范围暴风眼
## - 对范围内敌人造成持续伤害
## - 强力吸附敌人到中心
## - 带有视觉特效和音效
## 
## 使用方法:
##   - 按E键释放
## 
## ==============================================================================

# ==============================================================================
# 技能参数（从CSV加载）
# ==============================================================================

## 暴风眼半径
var storm_eye_radius: float = 140.0

## 暴风眼伤害
var storm_eye_damage: int = 35

## 暴风眼吸附力度
var storm_eye_pull_force: float = 500.0

## 暴风眼持续时间
var storm_eye_duration: float = 3.0

## 伤害tick间隔
var damage_tick_interval: float = 0.5

## 物理tick间隔
var physics_tick_interval: float = 0.05

# ==============================================================================
# 生命周期
# ==============================================================================

func _ready() -> void:
	super._ready()

# ==============================================================================
# 技能执行
# ==============================================================================

## 执行技能
func execute() -> void:
	if not consume_energy():
		if skill_owner:
			Global.spawn_floating_text(skill_owner.global_position, "No Energy!", Color.RED)
		return
	
	if not skill_owner:
		return
	
	# 相机震动
	Global.on_camera_shake.emit(8.0, 0.2)
	
	# 生成暴风眼
	call_deferred("_spawn_storm_eye", skill_owner.global_position)
	
	# 开始冷却
	start_cooldown()

# ==============================================================================
# 暴风眼生成
# ==============================================================================

## 生成暴风眼
func _spawn_storm_eye(center_pos: Vector2) -> void:
	var area = Area2D.new()
	area.global_position = center_pos
	area.collision_mask = 2
	area.monitorable = false
	area.monitoring = true
	
	# 碰撞形状
	var col = CollisionShape2D.new()
	var shape = CircleShape2D.new()
	shape.radius = storm_eye_radius
	col.shape = shape
	area.add_child(col)
	
	# 视觉效果（圆形多边形）
	var vis = Polygon2D.new()
	var points = PackedVector2Array()
	var steps = 32
	for i in range(steps):
		var angle = i * TAU / steps
		points.append(Vector2(cos(angle), sin(angle)) * storm_eye_radius)
	
	vis.polygon = points
	vis.color = Color(0.1, 1.2, 1.2, 0.4)
	vis.z_index = 5
	area.add_child(vis)
	
	get_tree().current_scene.add_child(area)
	Global.spawn_floating_text(center_pos, "VORTEX!", Color.CYAN)
	
	# 缩放动画
	vis.scale = Vector2.ZERO
	var tween = area.create_tween()
	tween.tween_property(vis, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_BACK)
	
	# 物理Tick（吸向中心）
	var timer = Timer.new()
	timer.wait_time = physics_tick_interval
	timer.autostart = true
	area.add_child(timer)
	timer.timeout.connect(_on_storm_zone_tick.bind(area, center_pos))
	
	# 伤害Tick
	var dmg_timer = Timer.new()
	dmg_timer.wait_time = damage_tick_interval
	dmg_timer.autostart = true
	area.add_child(dmg_timer)
	dmg_timer.timeout.connect(_on_damage_tick.bind(area, storm_eye_damage))
	
	# 寿命
	var life = get_tree().create_timer(storm_eye_duration)
	life.timeout.connect(_on_object_expired.bind(area, vis))

# ==============================================================================
# 回调函数
# ==============================================================================

## 暴风眼物理效果：将敌人吸附到中心点
func _on_storm_zone_tick(area_ref: Area2D, center: Vector2) -> void:
	if not is_instance_valid(area_ref) or area_ref.is_queued_for_deletion():
		return
	
	var targets = area_ref.get_overlapping_bodies() + area_ref.get_overlapping_areas()
	var dt = physics_tick_interval
	
	for t in targets:
		var enemy = null
		if t.is_in_group("enemies"):
			enemy = t
		elif t.owner and t.owner.is_in_group("enemies"):
			enemy = t.owner
		
		if is_instance_valid(enemy):
			var dir = (center - enemy.global_position).normalized()
			enemy.global_position += dir * storm_eye_pull_force * dt

## 伤害tick
func _on_damage_tick(area_ref: Area2D, amount: int) -> void:
	if not is_instance_valid(area_ref) or area_ref.is_queued_for_deletion():
		return
	
	var targets = area_ref.get_overlapping_bodies() + area_ref.get_overlapping_areas()
	for t in targets:
		var enemy = null
		if t.is_in_group("enemies"):
			enemy = t
		elif t.owner and t.owner.is_in_group("enemies"):
			enemy = t.owner
		
		if enemy and enemy.has_node("HealthComponent"):
			enemy.health_component.take_damage(amount)

## 对象过期
func _on_object_expired(area_ref: Area2D, visual_ref: Node) -> void:
	if is_instance_valid(area_ref):
		if is_instance_valid(visual_ref):
			var tween = area_ref.create_tween()
			tween.tween_property(visual_ref, "modulate:a", 0.0, 0.3)
			tween.tween_callback(func():
				if is_instance_valid(area_ref):
					area_ref.queue_free()
			)
		else:
			area_ref.queue_free()
