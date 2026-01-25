extends Area2D
class_name ExplosionArea

## ==============================================================================
## 爆炸区域效果 - 用于武器爆炸伤害
## ==============================================================================
## 
## 使用方式：
##   var explosion = ExplosionArea.create(position, damage, radius, owner)
##   get_tree().root.add_child(explosion)
## 
## ==============================================================================

# 爆炸参数
var explosion_damage: float = 0.0
var explosion_radius: float = 100.0
var explosion_owner: Node = null

# 视觉效果
var particles: CPUParticles2D = null
var sprite: Sprite2D = null
var collision_shape: CollisionShape2D = null

## 静态工厂方法
static func create(pos: Vector2, damage: float, radius: float, owner_node: Node = null) -> ExplosionArea:
	var explosion = ExplosionArea.new()
	explosion.global_position = pos
	explosion.explosion_damage = damage
	explosion.explosion_radius = radius
	explosion.explosion_owner = owner_node
	return explosion

## 设置方法（推荐使用）
func setup(damage: float, radius: float, owner_node: Node = null) -> void:
	"""设置爆炸参数
	
	Args:
		damage: 爆炸伤害
		radius: 爆炸半径
		owner_node: 伤害来源（玩家）
	"""
	explosion_damage = damage
	explosion_radius = radius
	explosion_owner = owner_node

func _ready() -> void:
	# 使用 call_deferred 设置碰撞层级，避免物理查询冲突
	call_deferred("_setup_collision")
	
	# 创建视觉效果
	_create_visual_effects()
	
	# 播放音效
	Global.play_player_explosion()
	
	# 等待物理系统准备好
	await get_tree().physics_frame
	await get_tree().physics_frame
	
	# 造成伤害
	_deal_damage()
	
	# 等待视觉效果播放完毕
	await get_tree().create_timer(0.5).timeout
	
	# 销毁自己
	queue_free()

func _setup_collision() -> void:
	"""设置碰撞检测（延迟调用）"""
	# 设置碰撞层级
	collision_layer = 0
	collision_mask = 8  # 检测敌人的 hurtbox (layer 4 = 2^3 = 8)
	
	# 创建碰撞形状
	collision_shape = CollisionShape2D.new()
	var circle = CircleShape2D.new()
	circle.radius = explosion_radius
	collision_shape.shape = circle
	add_child(collision_shape)

func _create_visual_effects() -> void:
	"""创建爆炸视觉效果"""
	# 创建粒子效果
	particles = CPUParticles2D.new()
	particles.emitting = true
	particles.one_shot = true
	particles.amount = 30
	particles.lifetime = 0.5
	particles.explosiveness = 1.0
	
	# 粒子属性
	particles.direction = Vector2.ZERO
	particles.spread = 180.0
	particles.gravity = Vector2(0, 200)
	particles.initial_velocity_min = 100.0
	particles.initial_velocity_max = 300.0
	particles.scale_amount_min = 2.0
	particles.scale_amount_max = 4.0
	
	# 颜色渐变（橙色到红色）
	var gradient = Gradient.new()
	gradient.add_point(0.0, Color(1.0, 0.8, 0.2, 1.0))  # 亮橙色
	gradient.add_point(0.5, Color(1.0, 0.3, 0.0, 0.8))  # 橙红色
	gradient.add_point(1.0, Color(0.3, 0.0, 0.0, 0.0))  # 暗红色透明
	particles.color_ramp = gradient
	
	add_child(particles)
	
	# 创建闪光效果
	sprite = Sprite2D.new()
	sprite.modulate = Color(1.0, 0.6, 0.2, 0.8)
	sprite.scale = Vector2(explosion_radius / 50.0, explosion_radius / 50.0)
	
	# 使用简单的圆形纹理（如果有的话）
	# 如果没有纹理，可以用 ColorRect 或者不显示
	add_child(sprite)
	
	# 闪光动画
	var tween = create_tween()
	tween.tween_property(sprite, "scale", Vector2.ZERO, 0.3).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(sprite, "modulate:a", 0.0, 0.3)

func _deal_damage() -> void:
	"""对范围内的敌人造成伤害"""
	var hit_enemies: Array[Node] = []
	
	# 获取所有重叠的区域
	var overlapping_areas = get_overlapping_areas()
	
	print("[ExplosionArea] 检测到 %d 个重叠区域" % overlapping_areas.size())
	
	for i in range(overlapping_areas.size()):
		var area = overlapping_areas[i]
		
		# 检查是否是敌人的 hurtbox
		if not area.is_in_group("hurtbox"):
			continue
		
		var enemy = area.get_parent()
		if not enemy or not is_instance_valid(enemy):
			print("[ExplosionArea] ⚠️ 区域 %d: 父节点无效" % (i + 1))
			continue
		
		print("[ExplosionArea] 区域 %d: %s -> 父节点: %s (类型: %s)" % [i + 1, area.name, enemy.name, enemy.get_class()])
		
		# 避免重复伤害
		if enemy in hit_enemies:
			continue
		
		# 不伤害自己的主人（如果是玩家发出的）
		if explosion_owner and enemy == explosion_owner:
			continue
		
		# 造成伤害
		if enemy.has_method("take_damage"):
			enemy.take_damage(explosion_damage)
			hit_enemies.append(enemy)
			print("[ExplosionArea]   ✅ 造成伤害: %.1f -> %s" % [explosion_damage, enemy.name])
		elif enemy.has_method("_on_hurtbox_component_on_damaged"):
			# 备用方案：通过 hurtbox 信号
			print("[ExplosionArea]   ⚠️ 使用备用伤害方案")
			# 创建一个临时 hitbox 来触发伤害
			var temp_hitbox = HitboxComponent.new()
			temp_hitbox.damage = explosion_damage
			temp_hitbox.critical = false
			temp_hitbox.knockback_power = 0.0
			temp_hitbox.source = explosion_owner
			enemy._on_hurtbox_component_on_damaged(temp_hitbox)
			temp_hitbox.queue_free()
			hit_enemies.append(enemy)
			print("[ExplosionArea]   ✅ 造成伤害(备用): %.1f -> %s" % [explosion_damage, enemy.name])
		else:
			print("[ExplosionArea]   ❌ 没有伤害方法: %s" % enemy.name)
	
	print("[ExplosionArea] 共击中 %d 个敌人" % hit_enemies.size())
	
	# 相机震动
	if hit_enemies.size() > 0:
		var shake_intensity = min(hit_enemies.size() * 2.0, 10.0)
		Global.on_camera_shake.emit(shake_intensity, 0.1)
