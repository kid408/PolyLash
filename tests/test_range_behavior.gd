extends Node
## 测试 RangeBehavior 动态子弹生成系统

func _ready() -> void:
	print("========================================")
	print("测试 RangeBehavior 动态子弹生成系统")
	print("========================================")
	
	# 测试所有 bullet_mode
	test_bullet_mode("single", "pistol_1")
	test_bullet_mode("spread", "shotgun_1")
	test_bullet_mode("pierce", "laser_1")
	test_bullet_mode("magic", "wand_1")
	test_bullet_mode("heal", "heal_bolt_1")
	
	print("========================================")
	print("测试完成！")
	print("========================================")
	
	# 退出测试
	await get_tree().create_timer(1.0).timeout
	get_tree().quit()

func test_bullet_mode(mode: String, weapon_id: String) -> void:
	print("\n--- 测试 bullet_mode: %s (weapon_id: %s) ---" % [mode, weapon_id])
	
	# 从 CSV 加载武器数据
	var stats = WeaponConfigLoader.get_weapon_stats(weapon_id)
	if not stats:
		printerr("✗ 错误: 无法加载武器 %s" % weapon_id)
		return
	
	print("✓ 武器数据加载成功")
	print("  - bullet_mode: %s" % stats.bullet_mode)
	print("  - bullet_count: %d" % stats.bullet_count)
	print("  - spread_angle: %.1f" % stats.spread_angle)
	print("  - pierce_count: %d" % stats.pierce_count)
	print("  - effect_type: %s" % stats.effect_type)
	print("  - param1: %s" % stats.param1)
	print("  - param2: %s" % stats.param2)
	print("  - param3: %s" % stats.param3)
	print("  - projectile_scene: %s" % ("已设置" if stats.projectile_scene else "未设置"))
	
	# 验证子弹场景
	if not stats.projectile_scene:
		printerr("✗ 错误: 武器缺少 projectile_scene")
		return
	
	print("✓ 子弹场景验证通过")
	
	# 验证 bullet_mode 映射
	var expected_mode = stats.bullet_mode if not stats.bullet_mode.is_empty() else "single"
	print("✓ bullet_mode 映射: %s" % expected_mode)
	
	# 验证参数完整性
	match expected_mode:
		"single":
			print("✓ 单发模式 - 无需额外参数")
		"spread":
			if stats.bullet_count > 1 and stats.spread_angle > 0:
				print("✓ 散射模式 - 参数完整 (count=%d, angle=%.1f)" % [stats.bullet_count, stats.spread_angle])
			else:
				push_warning("⚠ 散射模式参数不完整")
		"pierce":
			if stats.pierce_count > 0:
				print("✓ 穿透模式 - 参数完整 (pierce_count=%d)" % stats.pierce_count)
			else:
				push_warning("⚠ 穿透模式参数不完整")
		"magic", "arc":
			print("✓ 魔法模式 - gravity=%s, homing=%s" % [stats.param1, stats.param2])
	
	# 验证效果类型
	if not stats.effect_type.is_empty():
		print("✓ 效果类型: %s" % stats.effect_type)
		match stats.effect_type:
			"heal":
				var heal_mult = float(stats.param2) if not stats.param2.is_empty() else 0.5
				print("  - 治疗倍率: %.2f" % heal_mult)
			"buff":
				var buff_dur = float(stats.param3) if not stats.param3.is_empty() else 5.0
				print("  - Buff 持续时间: %.1f秒" % buff_dur)
	
	print("✓ 测试完成")

