extends SkillBase
class_name SkillTotem

## ==============================================================================
## 工兵E技能 - 图腾
## ==============================================================================
## 
## 功能说明:
## - 按E键在玩家位置生成图腾
## - 图腾嘲讽附近敌人
## - 图腾有生命值，被击毁后爆炸
## - 图腾持续一定时间后自动爆炸
## 
## 使用方法:
##   - 按E键释放
## 
## ==============================================================================

# ==============================================================================
# 技能参数（从CSV加载）
# ==============================================================================

## 图腾持续时间
var totem_duration: float = 8.0

## 图腾最大生命值
var totem_max_health: float = 200.0

## 图腾嘲讽范围
var totem_taunt_radius: float = 600.0

## 图腾爆炸半径
var totem_explosion_radius: float = 120.0

## 图腾爆炸伤害
var totem_explosion_damage: int = 150

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
	
	# 生成图腾
	var totem = _create_totem()
	totem.global_position = skill_owner.global_position
	get_tree().current_scene.add_child(totem)
	
	# 嘲讽附近敌人
	var enemies = get_tree().get_nodes_in_group("enemies")
	for e in enemies:
		if e.global_position.distance_to(skill_owner.global_position) < totem_taunt_radius:
			if e.has_method("set_taunt_target"):
				e.set_taunt_target(totem)
	
	Global.spawn_floating_text(skill_owner.global_position, "Taunt!", Color.GREEN)
	
	# 开始冷却
	start_cooldown()

# ==============================================================================
# 图腾创建
# ==============================================================================

## 创建图腾
func _create_totem() -> Area2D:
	var totem = Area2D.new()
	totem.add_to_group("player")
	
	# 碰撞形状
	var col = CollisionShape2D.new()
	var shape = CircleShape2D.new()
	shape.radius = 30.0
	col.shape = shape
	totem.add_child(col)
	
	# 视觉效果（三角形）
	var vis = Polygon2D.new()
	vis.polygon = [Vector2(0, -30), Vector2(20, 10), Vector2(-20, 10)]
	vis.color = Color.GREEN
	totem.add_child(vis)
	
	# 受伤盒
	var hurtbox = HurtboxComponent.new()
	var hb_col = CollisionShape2D.new()
	hb_col.shape = shape
	hurtbox.add_child(hb_col)
	hurtbox.collision_layer = 1
	totem.add_child(hurtbox)
	
	# 图腾状态
	var state = {"hp": totem_max_health}
	
	# 受伤回调
	hurtbox.on_damaged.connect(func(hitbox):
		if not is_instance_valid(totem):
			return
		state.hp -= hitbox.damage
		Global.spawn_floating_text(totem.global_position, str(hitbox.damage), Color.WHITE)
		
		# 受伤闪烁
		var tween = totem.create_tween()
		tween.tween_property(vis, "modulate", Color.RED, 0.1)
		tween.tween_property(vis, "modulate", Color.WHITE, 0.1)
		
		# 生命值耗尽，爆炸
		if state.hp <= 0:
			_explode_totem(totem)
	)
	
	# 持续时间定时器
	var timer = Timer.new()
	timer.wait_time = totem_duration
	timer.one_shot = true
	timer.autostart = true
	totem.add_child(timer)
	timer.timeout.connect(_on_totem_expired.bind(totem))
	
	return totem

# ==============================================================================
# 图腾爆炸
# ==============================================================================

## 图腾过期
func _on_totem_expired(totem: Node2D) -> void:
	if is_instance_valid(totem):
		_explode_totem(totem)

## 图腾爆炸
func _explode_totem(totem: Node2D) -> void:
	if not is_instance_valid(totem) or totem.is_queued_for_deletion():
		return
	
	# 对范围内敌人造成伤害
	var enemies = get_tree().get_nodes_in_group("enemies")
	var hit_count = 0
	
	for e in enemies:
		if not is_instance_valid(e):
			continue
		if e.global_position.distance_to(totem.global_position) < totem_explosion_radius:
			if e.has_node("HealthComponent"):
				e.health_component.take_damage(totem_explosion_damage)
				hit_count += 1
				if e.has_method("apply_knockback"):
					var dir = (e.global_position - totem.global_position).normalized()
					e.apply_knockback(dir, 300.0)
	
	if hit_count > 0:
		Global.on_camera_shake.emit(3.0, 0.1)
	
	# 爆炸视觉效果
	var flash = Polygon2D.new()
	var points = PackedVector2Array()
	for i in range(16):
		var angle = i * TAU / 16
		points.append(Vector2(cos(angle), sin(angle)) * totem_explosion_radius)
	flash.polygon = points
	flash.color = Color(1, 0.5, 0, 0.5)
	flash.global_position = totem.global_position
	get_tree().current_scene.add_child(flash)
	
	var tw = flash.create_tween()
	tw.tween_property(flash, "modulate:a", 0.0, 0.3)
	tw.tween_callback(func():
		if is_instance_valid(flash):
			flash.queue_free()
	)
	
	totem.queue_free()
