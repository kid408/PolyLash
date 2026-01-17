extends EnemyElites
class_name EnemyGlutton

# ==============================================================================
# 吞噬者特定的能力配置
# ==============================================================================

# 第2阶段射击冷却
@export var stage2_shoot_cooldown: float = 2.0
# 第2阶段射击范围
@export var stage2_shoot_range: float = 300.0
# 第2阶段投射物速度
@export var stage2_projectile_speed: float = 200.0

# 第3阶段 AoE 范围
@export var stage3_aoe_radius: float = 150.0
# 第3阶段 AoE 伤害
@export var stage3_aoe_damage: float = 30.0
# 第3阶段 AoE 冷却
@export var stage3_aoe_cooldown: float = 3.0

# ==============================================================================
# 生命周期
# ==============================================================================

func _ready() -> void:
	super._ready()
	
	# 初始化 Glutton 特定的计时器
	stage2_shoot_timer = stage2_shoot_cooldown
	stage3_aoe_timer = stage3_aoe_cooldown
	
	print("[EnemyGlutton] 初始化完成，第2阶段冷却: %.1f秒，第3阶段冷却: %.1f秒" % [stage2_shoot_cooldown, stage3_aoe_cooldown])

# ==============================================================================
# 阶段特定的行为实现
# ==============================================================================

func _update_stage_behavior(delta: float) -> void:
	"""更新阶段特定的行为"""
	match current_stage:
		2:
			_update_stage2_behavior(delta)
		3:
			_update_stage3_behavior(delta)
		4:
			# 第4阶段继续进化，无特殊行为
			pass

func _apply_stage_effects(stage: int) -> void:
	"""应用阶段特定的效果"""
	match stage:
		2:
			# 第2阶段: 启用酸液投射物射击能力
			print("[EnemyGlutton] 进化到第2阶段：启用酸液投射物射击能力！")
			# 重置射击计时器，使其立即可以射击
			stage2_shoot_timer = 0.5
		
		3:
			# 第3阶段: 免疫击退，变红
			is_stage3_immune = true
			visuals.modulate = Color(1.5, 0.3, 0.3, 1.0)  # 红色色调
			print("[EnemyGlutton] 进化到第3阶段：启用击退免疫和AoE踩踏能力，变红！")
			# 重置AoE计时器
			stage3_aoe_timer = 0.5
		
		4:
			# 第4阶段: 继续进化，不死亡
			print("[EnemyGlutton] 进化到第4阶段：最终进化形态！")
		
		5:
			# 第5阶段: 最终形态
			print("[EnemyGlutton] 进化到第5阶段：终极形态！")

# ==============================================================================
# Stage 2 - 酸液投射物射击
# ==============================================================================

func _update_stage2_behavior(delta: float) -> void:
	"""第2阶段: 向玩家射击酸液投射物"""
	if not is_instance_valid(Global.player):
		return
	
	stage2_shoot_timer -= delta
	
	if stage2_shoot_timer <= 0:
		var distance_to_player = global_position.distance_to(Global.player.global_position)
		
		# 仅在玩家在范围内时射击
		if distance_to_player < stage2_shoot_range:
			_shoot_acid_projectile()
			stage2_shoot_timer = stage2_shoot_cooldown

func _shoot_acid_projectile() -> void:
	"""向玩家射击酸液投射物"""
	if not is_instance_valid(Global.player):
		print("[EnemyGlutton] 错误：玩家无效，无法射击投射物")
		return
	
	# 计算指向玩家的方向
	var direction = global_position.direction_to(Global.player.global_position)
	var damage = int(stats.damage * 0.5)
	
	print("[EnemyGlutton] 射击酸液投射物 - 方向: %v, 伤害: %d" % [direction, damage])
	
	# 创建投射物节点
	var projectile = Node2D.new()
	projectile.name = "AcidProjectile"
	projectile.global_position = global_position
	
	# 添加精灵
	var sprite = Sprite2D.new()
	sprite.texture = preload("res://assets/sprites/Projectiles/Projectile_enemy.png")
	sprite.modulate = Color.GREEN
	sprite.scale = Vector2(0.3, 0.3)
	projectile.add_child(sprite)
	
	# 添加碰撞检测
	var area = Area2D.new()
	area.name = "HitArea"
	var collision_shape = CollisionShape2D.new()
	var circle_shape = CircleShape2D.new()
	circle_shape.radius = 8.0
	collision_shape.shape = circle_shape
	area.add_child(collision_shape)
	projectile.add_child(area)
	
	# 设置投射物属性
	projectile.set_meta("damage", damage)
	projectile.set_meta("direction", direction)
	projectile.set_meta("speed", stage2_projectile_speed)
	
	# 标记为投射物
	projectile.add_to_group("projectiles")
	
	# 连接碰撞信号处理伤害
	var hit_once = false
	area.area_entered.connect(func(hit_area):
		if hit_once:
			return
		
		# 检查是否击中玩家
		if hit_area.is_in_group("hurtbox") and hit_area.get_parent() == Global.player:
			hit_once = true
			if Global.player.has_method("take_damage"):
				Global.player.take_damage(damage)
				print("[EnemyGlutton] 酸液投射物击中玩家，造成 %d 伤害！" % damage)
			projectile.queue_free()
			return
		
		# 检查是否击中其他敌人
		if hit_area.is_in_group("hurtbox"):
			var parent = hit_area.get_parent()
			if parent and parent != self and parent.has_method("take_damage"):
				hit_once = true
				parent.take_damage(damage)
				print("[EnemyGlutton] 酸液投射物击中敌人，造成 %d 伤害！" % damage)
				projectile.queue_free()
	)
	
	# 添加到场景
	get_tree().root.add_child(projectile)
	
	# 添加移动逻辑
	var tween = create_tween()
	tween.set_trans(Tween.TRANS_LINEAR)
	tween.set_ease(Tween.EASE_IN)
	
	# 移动投射物
	var target_pos = global_position + direction * stage2_shoot_range
	var travel_time = stage2_shoot_range / stage2_projectile_speed
	tween.tween_property(projectile, "global_position", target_pos, travel_time)
	
	# 自动销毁
	await tween.finished
	if is_instance_valid(projectile):
		projectile.queue_free()
	
	print("[EnemyGlutton] 第2阶段：酸液投射物已射出！")

# ==============================================================================
# Stage 3 - AoE 踩踏伤害
# ==============================================================================

func _update_stage3_behavior(delta: float) -> void:
	"""第3阶段: 执行 AoE 踩踏伤害"""
	stage3_aoe_timer -= delta
	
	if stage3_aoe_timer <= 0:
		print("[EnemyGlutton] 触发第3阶段AoE踩踏！计时器: %.2f" % stage3_aoe_timer)
		_perform_aoe_stomp()
		stage3_aoe_timer = stage3_aoe_cooldown

func _perform_aoe_stomp() -> void:
	"""在 Glutton 周围执行 AoE 踩踏伤害"""
	if not is_instance_valid(Global.player):
		print("[EnemyGlutton] 错误：玩家无效，无法执行AoE")
		return
	
	# 检查玩家是否在 AoE 范围内
	var distance_to_player = global_position.distance_to(Global.player.global_position)
	
	print("[EnemyGlutton] 第3阶段AoE检测 - 距离: %.1f, 范围: %.1f" % [distance_to_player, stage3_aoe_radius])
	
	if distance_to_player <= stage3_aoe_radius:
		# 对玩家造成伤害
		var damage = int(stage3_aoe_damage)
		if Global.player.has_method("take_damage"):
			Global.player.take_damage(damage)
			print("[EnemyGlutton] 第3阶段AoE踩踏击中玩家，造成 %d 伤害！" % damage)
			
			# 显示浮动文本反馈
			if Global.has_method("spawn_floating_text"):
				Global.spawn_floating_text(Global.player.global_position, "STOMP!", Color.RED)
		else:
			print("[EnemyGlutton] 警告：玩家没有 take_damage 方法")
	else:
		print("[EnemyGlutton] 玩家不在AoE范围内，无法造成伤害")
