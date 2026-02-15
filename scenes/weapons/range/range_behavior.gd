extends WeaponBehavior
class_name RangeBehavior

@onready var muzzle: Marker2D = %Muzzle

func execute_attack() -> void:
	weapon.is_attacking = true
	
	print("[RangeBehavior] ========== 开始远程攻击 ==========")
	print("[RangeBehavior] 武器名称: ", weapon.data.item_name if weapon.data else "未知")
	print("[RangeBehavior] 武器位置: ", weapon.global_position)
	print("[RangeBehavior] 武器旋转: ", rad_to_deg(weapon.rotation), "度")
	print("[RangeBehavior] Muzzle 位置: ", muzzle.global_position if muzzle else "无枪口")
	
	# 增强打击感：射击时轻微顿帧和指向性震动
	Global.frame_freeze(0.01, 0.7)  # 减弱顿帧
	
	# 指向性震动：根据射击方向产生后坐力震动（减弱强度）
	var shoot_direction = Vector2.RIGHT.rotated(weapon.rotation)
	Global.on_directional_shake.emit(shoot_direction, 0.5)  # 从1.5降低到0.5
	
	create_projectiles()
	var tween := create_tween()
	var attack_pos:= Vector2(weapon.atk_start_pos.x - weapon.data.stats.recoil,weapon.atk_start_pos.y)
	tween.tween_property(weapon.sprite,"position",attack_pos,weapon.data.stats.recoil_duration)
	tween.tween_property(weapon.sprite,"position",weapon.atk_start_pos,weapon.data.stats.recoil_duration)
	
	await tween.finished
	
	weapon.is_attacking = false
	critical = false
	print("[RangeBehavior] 攻击结束")

## 动态子弹生成系统 - 根据 bullet_mode 生成不同类型的子弹
func create_projectiles() -> void:
	# 安全检查
	if not weapon or not weapon.data or not weapon.data.stats:
		printerr("[RangeBehavior] 错误: weapon 或 weapon.data 或 weapon.data.stats 为空")
		return
	
	if not weapon.data.stats.projectile_scene:
		printerr("[RangeBehavior] 错误: projectile_scene 为空 - 武器: ", weapon.data.item_name if weapon.data else "未知")
		return
	
	var stats = weapon.data.stats
	var bullet_mode = stats.bullet_mode if not stats.bullet_mode.is_empty() else "single"
	
	# 根据 bullet_mode 动态生成子弹
	match bullet_mode:
		"single":
			spawn_single_bullet()
		"spread":
			spawn_spread_bullets()
		"pierce":
			spawn_pierce_bullet()
		"magic", "arc":
			spawn_magic_bullet()
		_:
			# 默认：单发子弹
			spawn_single_bullet()
	
	# 日志输出
	var bullet_count = stats.bullet_count if bullet_mode == "spread" else 1
	print("[RangeBehavior] 发射 ", bullet_mode, " x", bullet_count)

## 生成单发直线子弹
func spawn_single_bullet() -> void:
	spawn_bullet_at_angle(0.0)

## 生成散射子弹
func spawn_spread_bullets() -> void:
	var stats = weapon.data.stats
	var count = stats.bullet_count
	var spread = stats.spread_angle
	
	for i in range(count):
		var angle_offset = 0.0
		if count > 1:
			# 均匀分布在 [-spread/2, spread/2] 范围内
			var t = float(i) / (count - 1)
			angle_offset = lerp(-spread / 2.0, spread / 2.0, t)
		
		spawn_bullet_at_angle(angle_offset)

## 生成穿透子弹
func spawn_pierce_bullet() -> void:
	var stats = weapon.data.stats
	var instance := stats.projectile_scene.instantiate() as Projectile
	get_tree().root.add_child(instance)
	instance.global_position = muzzle.global_position
	
	var velocity: Vector2 = Vector2.RIGHT.rotated(weapon.rotation) * stats.projectile_speed
	
	# 设置穿透属性
	if instance.has_method("setup"):
		instance.setup({
			"pierce_count": stats.pierce_count,
			"effect_type": stats.effect_type,
			"param1": stats.param1,
			"param2": stats.param2,
			"param3": stats.param3
		})
	
	instance.set_projectile(velocity, get_damage(), critical, stats.knockback, weapon.get_parent(), stats)

## 生成魔法/弧线子弹（带重力和追踪）
func spawn_magic_bullet() -> void:
	var stats = weapon.data.stats
	var instance := stats.projectile_scene.instantiate() as Projectile
	get_tree().root.add_child(instance)
	instance.global_position = muzzle.global_position
	
	var velocity: Vector2 = Vector2.RIGHT.rotated(weapon.rotation) * stats.projectile_speed
	
	# 设置魔法属性
	if instance.has_method("setup"):
		var gravity = float(stats.param1) if not stats.param1.is_empty() else 0.0
		var homing_strength = float(stats.param2) if not stats.param2.is_empty() else 0.0
		
		instance.setup({
			"gravity": gravity,
			"homing_strength": homing_strength,
			"effect_type": stats.effect_type,
			"param1": stats.param1,
			"param2": stats.param2,
			"param3": stats.param3
		})
	
	instance.set_projectile(velocity, get_damage(), critical, stats.knockback, weapon.get_parent(), stats)

## 在指定角度生成子弹（辅助函数）
func spawn_bullet_at_angle(angle_offset: float) -> void:
	var stats = weapon.data.stats
	var instance := stats.projectile_scene.instantiate() as Projectile
	get_tree().root.add_child(instance)
	instance.global_position = muzzle.global_position
	
	print("[RangeBehavior] 生成子弹:")
	print("  - 子弹场景: ", stats.projectile_scene.resource_path)
	print("  - 生成位置: ", muzzle.global_position)
	print("  - 角度偏移: ", angle_offset, "度")
	
	# 应用角度偏移
	var angle = weapon.rotation + deg_to_rad(angle_offset)
	var velocity: Vector2 = Vector2.RIGHT.rotated(angle) * stats.projectile_speed
	
	print("  - 速度: ", velocity)
	print("  - 伤害: ", get_damage())
	
	# 处理效果类型
	if instance.has_method("setup"):
		instance.setup({
			"effect_type": stats.effect_type,
			"param1": stats.param1,
			"param2": stats.param2,
			"param3": stats.param3
		})
	
	instance.set_projectile(velocity, get_damage(), critical, stats.knockback, weapon.get_parent(), stats)
