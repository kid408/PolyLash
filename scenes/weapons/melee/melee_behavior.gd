extends WeaponBehavior
class_name MeleeBehavior

@export var hitbox:HitboxComponent

# 当前 shape 引用（用于清理）
var current_shape: Node = null

func _ready() -> void:
	print("[MeleeBehavior] _ready() 被调用")
	
	# 如果 hitbox 没有通过 @export 设置，尝试从父节点获取
	if not hitbox:
		var parent = get_parent()
		if parent:
			hitbox = parent.get_node_or_null("HitboxComponent")
			print("[MeleeBehavior] 从父节点获取 hitbox: %s" % str(hitbox))
	
	print("[MeleeBehavior] hitbox = %s" % str(hitbox))
	
	# 连接近战命中信号以支持爆炸效果
	if hitbox:
		if hitbox.on_hit_hurtbox.is_connected(_on_melee_hit):
			print("[MeleeBehavior] ⚠️ 信号已连接，跳过")
		else:
			hitbox.on_hit_hurtbox.connect(_on_melee_hit)
			print("[MeleeBehavior] ✅ 成功连接 on_hit_hurtbox 信号")
	else:
		printerr("[MeleeBehavior] ❌ hitbox 为空，无法连接信号")

## 动态设置 hitbox 形状
## @param stats: 武器统计数据
func setup_hitbox(stats: WeaponStats) -> void:
	if not hitbox:
		printerr("[MeleeBehavior] 错误: hitbox 为空")
		return
	
	# 调试日志
	print("[MeleeBehavior] setup_hitbox 调用:")
	print("  - stats: ", stats)
	print("  - stats.max_range: ", stats.max_range if stats else "stats is null")
	print("  - stats.shape_type: ", stats.shape_type if stats else "stats is null")
	
	# 清理旧 shape
	cleanup_old_shape()
	
	var shape_type = stats.shape_type
	if shape_type.is_empty():
		shape_type = "point"  # 默认形状
	
	print("[MeleeBehavior] 创建 hitbox: ", shape_type)
	
	# 根据 shape_type 创建不同的 shape
	match shape_type:
		"point":
			_create_point_shape(stats)
		"line", "thrust":
			_create_line_shape(stats)
		"sector":
			_create_sector_shape(stats)
		"circle":
			_create_circle_shape(stats)
		_:
			push_warning("[MeleeBehavior] 未知的 shape_type: ", shape_type)
			_create_point_shape(stats)  # 默认使用 point

## 清理旧 shape
func cleanup_old_shape() -> void:
	if current_shape and is_instance_valid(current_shape):
		# 【修复】使用 free() 立即删除，而不是 queue_free() 延迟删除
		# 避免 CollisionShape2D 堆积导致碰撞检测失败
		hitbox.remove_child(current_shape)  # 先从父节点移除
		current_shape.free()  # 立即释放内存
		current_shape = null
		print("[MeleeBehavior] 清理旧 CollisionShape2D")

## 创建点形状（CircleShape2D）
func _create_point_shape(stats: WeaponStats) -> void:
	var collision_shape = CollisionShape2D.new()
	var circle = CircleShape2D.new()
	
	# radius = max_range/2 或 param1（如果 param1 > 0）
	var radius = stats.max_range / 2.0
	
	# 只有当 param1 不为空且大于 0 时才使用 param1
	if not stats.param1.is_empty() and float(stats.param1) > 0:
		radius = float(stats.param1)
		print("[MeleeBehavior] 使用 param1 作为 radius: ", radius)
	
	circle.radius = radius
	collision_shape.shape = circle
	collision_shape.disabled = false  # 确保启用
	
	# 【关键修复】将碰撞盒向前偏移到武器攻击范围的中心
	# 偏移距离 = max_range / 2（攻击范围的一半）
	var offset_x = stats.max_range / 2.0
	collision_shape.position = Vector2(offset_x, 0)
	
	print("[MeleeBehavior] 创建 CollisionShape2D:")
	print("  - 类型: CircleShape2D")
	print("  - 半径: ", radius)
	print("  - 位置偏移: ", collision_shape.position)
	print("  - disabled: ", collision_shape.disabled)
	print("  - 即将添加到: ", hitbox.name)
	
	hitbox.add_child(collision_shape)
	current_shape = collision_shape
	
	# 验证添加成功
	print("[MeleeBehavior] CollisionShape2D 添加后:")
	print("  - 父节点: ", collision_shape.get_parent().name if collision_shape.get_parent() else "无")
	print("  - 在场景树中: ", collision_shape.is_inside_tree())
	print("  - 本地位置: ", collision_shape.position)
	print("  - 全局位置: ", collision_shape.global_position)
	print("  - shape 有效: ", collision_shape.shape != null)
	
	print("[MeleeBehavior] 创建 hitbox: point - CircleShape2D (radius=", radius, ", offset=", offset_x, ")")

## 创建线形状（RectangleShape2D）
func _create_line_shape(stats: WeaponStats) -> void:
	var collision_shape = CollisionShape2D.new()
	var rect = RectangleShape2D.new()
	
	# extent = Vector2(max_range, param2 或 20)
	var width = stats.max_range
	var height = 20.0
	if not stats.param2.is_empty():
		height = float(stats.param2)
	
	rect.size = Vector2(width, height)
	collision_shape.shape = rect
	
	# 偏移到武器前方
	collision_shape.position = Vector2(width / 2.0, 0)
	
	hitbox.add_child(collision_shape)
	current_shape = collision_shape
	
	print("[MeleeBehavior] 创建 hitbox: line/thrust - RectangleShape2D (size=", rect.size, ")")

## 创建扇形形状（CollisionPolygon2D）
func _create_sector_shape(stats: WeaponStats) -> void:
	var collision_polygon = CollisionPolygon2D.new()
	
	# 角度 = sector_angle 或 param1
	var angle_deg = stats.sector_angle
	if angle_deg == 0.0 and not stats.param1.is_empty():
		angle_deg = float(stats.param1)
	if angle_deg == 0.0:
		angle_deg = 90.0  # 默认 90 度
	
	var radius = stats.max_range
	
	# 生成扇形点阵
	var points = generate_sector_polygon(angle_deg, radius)
	collision_polygon.polygon = points
	
	hitbox.add_child(collision_polygon)
	current_shape = collision_polygon
	
	print("[MeleeBehavior] 创建 hitbox: sector - CollisionPolygon2D (angle=", angle_deg, ", radius=", radius, ")")

## 创建圆形形状（CircleShape2D）
func _create_circle_shape(stats: WeaponStats) -> void:
	var collision_shape = CollisionShape2D.new()
	var circle = CircleShape2D.new()
	
	# radius = param1 或 max_range
	var radius = stats.max_range
	if not stats.param1.is_empty():
		radius = float(stats.param1)
	
	circle.radius = radius
	collision_shape.shape = circle
	
	hitbox.add_child(collision_shape)
	current_shape = collision_shape
	
	print("[MeleeBehavior] 创建 hitbox: circle - CircleShape2D (radius=", radius, ")")

## 生成扇形多边形点阵
## @param angle_deg: 扇形角度（度）
## @param radius: 扇形半径
## @return: 扇形点阵
func generate_sector_polygon(angle_deg: float, radius: float) -> PackedVector2Array:
	var points = PackedVector2Array()
	points.append(Vector2.ZERO)  # 中心点
	
	var segments = 16
	var start_angle = -angle_deg / 2.0
	var end_angle = angle_deg / 2.0
	
	for i in range(segments + 1):
		var t = float(i) / segments
		var current_angle = lerp(start_angle, end_angle, t)
		var rad = deg_to_rad(current_angle)
		var point = Vector2(cos(rad), sin(rad)) * radius
		points.append(point)
	
	return points

## 创建攻击 Tween 动画
## @param shape_type: 形状类型
## @return: Tween 对象（如果不需要动画则返回 null）
func create_attack_tween(shape_type: String):
	match shape_type:
		"sector", "circle":
			# 旋转动画
			var tween = create_tween()
			var rotation_amount = PI * 2  # 360 度旋转
			tween.tween_property(hitbox, "rotation", rotation_amount, weapon.data.stats.attack_duration)
			tween.tween_property(hitbox, "rotation", 0.0, weapon.data.stats.back_duration)
			return tween
		"line", "thrust":
			# 前冲动画
			var tween = create_tween()
			var thrust_distance = weapon.data.stats.max_range
			var original_pos = hitbox.position
			var thrust_pos = original_pos + Vector2(thrust_distance, 0)
			tween.tween_property(hitbox, "position", thrust_pos, weapon.data.stats.attack_duration)
			tween.tween_property(hitbox, "position", original_pos, weapon.data.stats.back_duration)
			return tween
		_:
			# 对于 "point" 等不需要额外动画的形状，返回 null
			return null

func execute_attack() -> void:
	weapon.is_attacking = true
	
	print("[MeleeBehavior] ========== 开始近战攻击 ==========")
	print("[MeleeBehavior] 武器名称: ", weapon.data.item_name if weapon.data else "未知")
	print("[MeleeBehavior] 武器位置: ", weapon.global_position)
	print("[MeleeBehavior] 武器旋转: ", rad_to_deg(weapon.rotation), "度")
	print("[MeleeBehavior] Sprite 位置: ", weapon.sprite.position)
	print("[MeleeBehavior] Sprite 全局位置: ", weapon.sprite.global_position)
	
	# 动态设置 hitbox 形状
	if weapon.data and weapon.data.stats:
		setup_hitbox(weapon.data.stats)
	
	# 增强打击感：攻击时轻微顿帧
	Global.frame_freeze(0.02, 0.5)
	
	# 指向性震动：根据武器朝向产生震动（减弱强度）
	var attack_direction = Vector2.RIGHT.rotated(weapon.rotation)
	Global.on_directional_shake.emit(attack_direction, 0.8)  # 从2.0降低到0.8
	
	var tween := create_tween()
	var shape_type = weapon.data.stats.shape_type if weapon.data.stats.shape_type else "point"
	
	# 根据武器类型设置不同的动画
	if shape_type == "sector":
		# 扇形武器：挥砍动画（从上往下挥）
		# 起始位置：适中幅度向后上方举起（调整后：减小幅度，优化角度）
		var start_offset = Vector2(weapon.atk_start_pos.x - 60, weapon.atk_start_pos.y - 100)
		var start_rotation = deg_to_rad(-110)  # 从-110度开始（适中角度）
		
		# 结束位置：适中幅度向前下方挥下（调整后：减小幅度，优化角度）
		var end_offset = Vector2(weapon.atk_start_pos.x + 140, weapon.atk_start_pos.y + 80)
		var end_rotation = deg_to_rad(110)  # 到+110度结束（适中角度）
		
		# 立即设置起始状态（跳过后坐力阶段）
		weapon.sprite.position = start_offset
		weapon.sprite.rotation = start_rotation
		
		# 短暂停顿（替代后坐力）
		tween.tween_interval(weapon.data.stats.recoil_duration)
		
		# 启用 Hitbox
		tween.tween_callback(func():
			hitbox.enable()
			var damage_value = get_damage()
			hitbox.setup(damage_value, critical, weapon.data.stats.knockback, weapon.get_parent())
			print("[MeleeBehavior] Hitbox 启用 - 挥砍开始")
		)
		
		# 挥砍动画（位置 + 旋转并行，使用EASE_IN_OUT创造弧形感）
		tween.tween_property(weapon.sprite, "position", end_offset, weapon.data.stats.attack_duration).set_ease(Tween.EASE_IN_OUT)
		tween.parallel().tween_property(weapon.sprite, "rotation", end_rotation, weapon.data.stats.attack_duration).set_ease(Tween.EASE_IN_OUT)
		
		print("[MeleeBehavior] 添加优化幅度挥砍动画: 从 ", rad_to_deg(start_rotation), "° 到 ", rad_to_deg(end_rotation), "°")
		print("[MeleeBehavior] 位置变化: 从 ", start_offset, " 到 ", end_offset)
		print("[MeleeBehavior] 总旋转角度: 220°, X轴移动: 200px, Y轴移动: 180px")
		print("[MeleeBehavior] 动画时长: ", weapon.data.stats.attack_duration, "秒（优化版本）")
		
		# 【关键修复】禁用 Hitbox（扇形武器在挥砍动画结束后）
		tween.tween_callback(func():
			hitbox.disable()
			print("[MeleeBehavior] Hitbox 禁用 - 挥砍动画结束")
		)
	
	elif shape_type == "circle":
		# 圆形武器：横扫动画（从左往右扫）
		var start_offset = Vector2(weapon.atk_start_pos.x - 30, weapon.atk_start_pos.y)
		var start_rotation = deg_to_rad(-90)  # 从左侧开始
		
		var end_offset = Vector2(weapon.atk_start_pos.x + 30, weapon.atk_start_pos.y)
		var end_rotation = deg_to_rad(90)  # 扫到右侧
		
		# 立即设置起始状态
		weapon.sprite.position = start_offset
		weapon.sprite.rotation = start_rotation
		
		# 短暂停顿
		tween.tween_interval(weapon.data.stats.recoil_duration)
		
		# 启用 Hitbox
		tween.tween_callback(func():
			hitbox.enable()
			var damage_value = get_damage()
			hitbox.setup(damage_value, critical, weapon.data.stats.knockback, weapon.get_parent())
			print("[MeleeBehavior] Hitbox 启用 - 横扫开始")
		)
		
		# 横扫动画
		tween.tween_property(weapon.sprite, "position", end_offset, weapon.data.stats.attack_duration).set_ease(Tween.EASE_OUT)
		tween.parallel().tween_property(weapon.sprite, "rotation", end_rotation, weapon.data.stats.attack_duration).set_ease(Tween.EASE_OUT)
		
		print("[MeleeBehavior] 添加横扫动画: 从 ", rad_to_deg(start_rotation), "° 到 ", rad_to_deg(end_rotation), "°")
		
		# 【关键修复】禁用 Hitbox（圆形武器在横扫动画结束后）
		tween.tween_callback(func():
			hitbox.disable()
			print("[MeleeBehavior] Hitbox 禁用 - 横扫动画结束")
		)
	
	else:
		# 其他武器：传统的后坐力 + 前进动画
		var recoil_pos := Vector2(weapon.atk_start_pos.x - weapon.data.stats.recoil, weapon.atk_start_pos.y)
		tween.tween_property(weapon.sprite, "position", recoil_pos, weapon.data.stats.recoil_duration)
		
		# 启用 Hitbox
		tween.tween_callback(func():
			hitbox.enable()
			var damage_value = get_damage()
			hitbox.setup(damage_value, critical, weapon.data.stats.knockback, weapon.get_parent())
			print("[MeleeBehavior] Hitbox 启用 - 攻击前进阶段开始")
		)
		
		# 前进动画
		var attack_pos := Vector2(weapon.atk_start_pos.x + weapon.data.stats.max_range, weapon.atk_start_pos.y)
		tween.tween_property(weapon.sprite, "position", attack_pos, weapon.data.stats.attack_duration)
		
		# 【关键修复】在攻击前进阶段结束时立即禁用 Hitbox（仅其他武器）
		tween.tween_callback(func():
			hitbox.disable()
			print("[MeleeBehavior] Hitbox 禁用 - 攻击前进阶段结束")
		)
	
	# 收回阶段（Hitbox 已禁用）
	# 恢复位置和旋转（并行执行）
	if shape_type == "sector" or shape_type == "circle":
		# 扇形和圆形武器：同时恢复位置和旋转
		tween.tween_property(weapon.sprite, "position", weapon.atk_start_pos, weapon.data.stats.back_duration).set_ease(Tween.EASE_OUT)
		tween.parallel().tween_property(weapon.sprite, "rotation", 0.0, weapon.data.stats.back_duration).set_ease(Tween.EASE_OUT)
		print("[MeleeBehavior] 收回: 恢复位置和旋转")
	else:
		# 其他武器：只恢复位置
		tween.tween_property(weapon.sprite, "position", weapon.atk_start_pos, weapon.data.stats.back_duration)
	
	tween.finished.connect(func():
		weapon.is_attacking = false
		critical = false
		print("[MeleeBehavior] 攻击结束")
	)


# ==============================================================================
# 爆炸效果系统
# ==============================================================================

func _on_melee_hit(hurtbox: HurtboxComponent) -> void:
	"""近战命中时触发，检查是否需要生成爆炸效果"""
	#print("[MeleeBehavior] ========== 近战命中！==========")
	#print("[MeleeBehavior] 武器: %s" % (weapon.name if weapon else "无"))
	#print("[MeleeBehavior] 目标: %s" % (hurtbox.get_parent().name if hurtbox and hurtbox.get_parent() else "无"))
	# 使用 call_deferred 避免物理查询冲突
	call_deferred("_spawn_explosion_if_needed", hurtbox)

func _spawn_explosion_if_needed(hurtbox: HurtboxComponent) -> void:
	"""检查并生成爆炸效果（如果武器有爆炸属性）"""
	if not weapon or not weapon.data or not weapon.data.stats:
		print("[MeleeBehavior] 武器数据无效，跳过爆炸检查")
		return
	
	print("[MeleeBehavior] 检查爆炸: explosion_radius = %.1f" % weapon.data.stats.explosion_radius)
	
	if weapon.data.stats.explosion_radius <= 0:
		print("[MeleeBehavior] 爆炸半径为0，不生成爆炸")
		return
	
	print("[MeleeBehavior] ✓ 生成爆炸效果！")
	
	# 加载爆炸场景
	var explosion_scene = load("res://scenes/vfx/explosion_area.tscn")
	if not explosion_scene:
		printerr("[MeleeBehavior] 错误: 无法加载爆炸场景")
		return
	
	# 实例化爆炸
	var explosion = explosion_scene.instantiate()
	
	# 【关键】先设置位置
	# 在被击中的敌人位置生成爆炸
	if hurtbox and is_instance_valid(hurtbox):
		explosion.global_position = hurtbox.global_position
		print("[MeleeBehavior] 爆炸位置: 敌人位置 (%.1f, %.1f)" % [hurtbox.global_position.x, hurtbox.global_position.y])
	else:
		explosion.global_position = weapon.global_position
		print("[MeleeBehavior] 爆炸位置: 武器位置（备用）")
	
	# 【安全检查】确保 weapon.get_parent() 仍然有效
	var valid_owner = null
	var parent = weapon.get_parent()
	if parent and is_instance_valid(parent):
		valid_owner = parent
	else:
		print("[MeleeBehavior] ⚠️ weapon.get_parent() 已被释放，使用 null")
	
	# 计算爆炸伤害（基于武器伤害 + 玩家伤害）
	var base_damage = weapon.data.stats.damage
	
	# 添加玩家伤害加成
	if valid_owner and "damage" in valid_owner:
		base_damage += valid_owner.damage
	elif Global.player and is_instance_valid(Global.player) and "damage" in Global.player:
		base_damage += Global.player.damage
	
	var explosion_damage = base_damage * weapon.data.stats.explosion_damage_scale
	
	print("[MeleeBehavior] 爆炸伤害: %.1f (基础:%.1f × 倍率:%.1f)" % [explosion_damage, base_damage, weapon.data.stats.explosion_damage_scale])
	
	# 设置爆炸参数
	if explosion.has_method("setup"):
		explosion.setup(
			explosion_damage,
			weapon.data.stats.explosion_radius,
			valid_owner  # 使用验证后的 owner
		)
	
	# 【关键】最后才添加到场景树
	get_tree().root.add_child(explosion)
