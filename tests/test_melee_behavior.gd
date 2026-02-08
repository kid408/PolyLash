extends Node
## 测试 MeleeBehavior 动态 hitbox 系统

func _ready() -> void:
	print("========================================")
	print("测试 MeleeBehavior 动态 hitbox 系统")
	print("========================================")
	
	# 测试所有 shape_type
	test_shape_type("point", "punch_1")
	test_shape_type("line", "spear_1")
	test_shape_type("sector", "axe_1")
	test_shape_type("circle", "scimitar_1")
	
	print("========================================")
	print("测试完成！")
	print("========================================")

func test_shape_type(shape_type: String, weapon_id: String) -> void:
	print("\n--- 测试 shape_type: %s (weapon_id: %s) ---" % [shape_type, weapon_id])
	
	# 从 CSV 加载武器数据
	var stats = WeaponConfigLoader.get_weapon_stats(weapon_id)
	if not stats:
		printerr("错误: 无法加载武器 %s" % weapon_id)
		return
	
	print("✓ 武器数据加载成功")
	print("  - shape_type: %s" % stats.shape_type)
	print("  - max_range: %.1f" % stats.max_range)
	print("  - sector_angle: %.1f" % stats.sector_angle)
	print("  - param1: %s" % stats.param1)
	print("  - param2: %s" % stats.param2)
	
	# 创建 MeleeBehavior 实例
	var melee_behavior = MeleeBehavior.new()
	
	# 创建 HitboxComponent
	var hitbox = HitboxComponent.new()
	melee_behavior.hitbox = hitbox
	
	# 添加到场景树（必须在场景树中才能创建 Tween）
	add_child(melee_behavior)
	melee_behavior.add_child(hitbox)
	
	# 调用 setup_hitbox
	melee_behavior.setup_hitbox(stats)
	
	# 验证 shape 是否创建
	if melee_behavior.current_shape:
		print("✓ Shape 创建成功: %s" % melee_behavior.current_shape.get_class())
		
		# 检查 shape 类型
		if melee_behavior.current_shape is CollisionShape2D:
			var collision_shape = melee_behavior.current_shape as CollisionShape2D
			if collision_shape.shape:
				print("  - Shape 类型: %s" % collision_shape.shape.get_class())
				if collision_shape.shape is CircleShape2D:
					var circle = collision_shape.shape as CircleShape2D
					print("  - 半径: %.1f" % circle.radius)
				elif collision_shape.shape is RectangleShape2D:
					var rect = collision_shape.shape as RectangleShape2D
					print("  - 尺寸: %s" % str(rect.size))
		elif melee_behavior.current_shape is CollisionPolygon2D:
			var polygon = melee_behavior.current_shape as CollisionPolygon2D
			print("  - 多边形点数: %d" % polygon.polygon.size())
	else:
		printerr("✗ Shape 创建失败")
	
	# 清理
	melee_behavior.cleanup_old_shape()
	melee_behavior.queue_free()
	
	print("✓ 测试完成")
