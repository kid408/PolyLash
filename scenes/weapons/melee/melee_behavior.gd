extends WeaponBehavior
class_name MeleeBehavior

@export var hitbox:HitboxComponent

func _ready() -> void:
	print("[MeleeBehavior] _ready() 被调用")
	print("[MeleeBehavior] hitbox = %s" % str(hitbox))
	
	# 连接近战命中信号以支持爆炸效果
	if hitbox:
		if hitbox.on_hit_hurtbox.is_connected(_on_melee_hit):
			print("[MeleeBehavior] ⚠️ 信号已连接，跳过")
		else:
			hitbox.on_hit_hurtbox.connect(_on_melee_hit)
			print("[MeleeBehavior] ✅ 成功连接 on_hit_hurtbox 信号")
	else:
		print("[MeleeBehavior] ❌ hitbox 为空，无法连接信号")

func execute_attack() -> void:
	weapon.is_attacking = true
	
	# 增强打击感：攻击时轻微顿帧
	Global.frame_freeze(0.02, 0.5)
	
	# 指向性震动：根据武器朝向产生震动（减弱强度）
	var attack_direction = Vector2.RIGHT.rotated(weapon.rotation)
	Global.on_directional_shake.emit(attack_direction, 0.8)  # 从2.0降低到0.8
	
	var tween := create_tween()
	
	var recoil_pos := Vector2(weapon.atk_start_pos.x - weapon.data.stats.recoil,weapon.atk_start_pos.y)
	tween.tween_property(weapon.sprite,"position",recoil_pos,weapon.data.stats.recoil_duration)
	
	hitbox.enable()
	hitbox.setup(get_damage(),critical,weapon.data.stats.knockback,weapon.get_parent())
	
	var attack_pos := Vector2(weapon.atk_start_pos.x + weapon.data.stats.max_range,weapon.atk_start_pos.y)
	
	tween.tween_property(weapon.sprite,"position",attack_pos,weapon.data.stats.attack_duration)
	
	tween.tween_property(weapon.sprite,"position",weapon.atk_start_pos,weapon.data.stats.back_duration)
	
	tween.finished.connect(func():
		hitbox.disable()
		weapon.is_attacking = false
		critical = false
	)


# ==============================================================================
# 爆炸效果系统
# ==============================================================================

func _on_melee_hit(hurtbox: HurtboxComponent) -> void:
	"""近战命中时触发，检查是否需要生成爆炸效果"""
	print("[MeleeBehavior] ========== 近战命中！==========")
	print("[MeleeBehavior] 武器: %s" % (weapon.name if weapon else "无"))
	print("[MeleeBehavior] 目标: %s" % (hurtbox.get_parent().name if hurtbox and hurtbox.get_parent() else "无"))
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
