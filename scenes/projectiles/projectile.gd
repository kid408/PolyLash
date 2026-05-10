extends Node2D
class_name Projectile

@export var hitbox: HitboxComponent
@export var life_time: float = 5.0 # 子弹最大存活时间(秒)

var velocity: Vector2
var weapon_stats: WeaponStats = null  # 武器属性引用（用于爆炸效果）
var owner_unit: Node2D = null  # 发射者引用（用于爆炸伤害）

# 新增属性 - 动态子弹系统
var pierce_count: int = 0  # 穿透次数
var gravity: float = 0.0  # 重力效果
var homing_strength: float = 0.0  # 追踪强度
var effect_type: String = ""  # 效果类型（heal/buff/fire/ice等）
var param1: String = ""  # 通用参数1
var param2: String = ""  # 通用参数2（heal_multiplier）
var param3: String = ""  # 通用参数3（buff_duration/heal_range）
var hit_enemies: Array = []  # 已击中的敌人列表（用于穿透）

func _ready() -> void:
	if not is_in_group("projectiles"):
		add_to_group("projectiles")

	# 【核心修复】创建一个自我销毁的计时器
	# 这种方式最稳健，不管子弹飞哪去了，时间一到强制回收
	get_tree().create_timer(life_time).timeout.connect(queue_free)
	
	# 【双重保险】如果你场景里有 VisibleOnScreenNotifier2D，尝试代码连接
	# 防止你在编辑器里忘了连信号
	if has_node("VisibleOnScreenNotifier2D"):
		var notifier = $VisibleOnScreenNotifier2D
		if not notifier.screen_exited.is_connected(_on_screen_exited):
			notifier.screen_exited.connect(_on_screen_exited)

func _process(delta: float) -> void:
	if Global.game_paused: return
	
	# 应用重力效果
	if gravity > 0:
		velocity.y += gravity * delta
	
	# 应用追踪效果
	if homing_strength > 0:
		track_nearest_enemy(delta)
	
	position += velocity * delta
	
	# 更新旋转以匹配速度方向
	rotation = velocity.angle()

func set_projectile(velocity: Vector2, damage: float, critical: bool, knockback: float, unit: Node2D, stats: WeaponStats = null) -> void:
	self.velocity = velocity
	self.owner_unit = unit
	self.weapon_stats = stats
	rotation = velocity.angle()
	
	print("[Projectile] 子弹初始化:")
	print("  - 位置: ", global_position)
	print("  - 速度: ", velocity)
	print("  - 伤害: ", damage)
	print("  - 暴击: ", critical)
	print("  - 击退: ", knockback)
	print("  - 发射者: ", unit.name if unit else "无")
	
	if hitbox:
		hitbox.setup(damage, critical, knockback, unit)
		print("  - Hitbox 碰撞层: ", hitbox.collision_layer)
		print("  - Hitbox 碰撞掩码: ", hitbox.collision_mask)
	else:
		printerr("[Projectile] 警告: hitbox 为空！")

## 设置子弹参数（新增方法）
func setup(data: Dictionary) -> void:
	if data.has("pierce_count"):
		pierce_count = data["pierce_count"]
	if data.has("gravity"):
		gravity = data["gravity"]
	if data.has("homing_strength"):
		homing_strength = data["homing_strength"]
	if data.has("effect_type"):
		effect_type = data["effect_type"]
	if data.has("param1"):
		param1 = data["param1"]
	if data.has("param2"):
		param2 = data["param2"]
	if data.has("param3"):
		param3 = data["param3"]

# 统一销毁逻辑
func _on_screen_exited() -> void:
	queue_free()

# 对应你之前的 VisibleOnScreenNotifier2D 信号函数
# 建议去编辑器确认一下信号是否真的连上了
func _on_visible_on_screen_notifier_2d_screen_exited() -> void:
	queue_free()

func _on_hitbox_component_on_hit_hurtbox(hurtbox: HurtboxComponent) -> void:
	print("[Projectile] ========== 子弹命中！==========")
	print("[Projectile] 子弹位置: ", global_position)
	print("[Projectile] 目标: ", hurtbox.get_parent().name if hurtbox and hurtbox.get_parent() else "未知")
	print("[Projectile] 目标位置: ", hurtbox.global_position if hurtbox else "未知")
	
	# 穿透逻辑：检查是否已击中该敌人
	var enemy = hurtbox.get_parent()
	if enemy in hit_enemies:
		print("[Projectile] 已击中过该敌人，跳过")
		return  # 已击中过，跳过
	
	# 记录击中的敌人
	hit_enemies.append(enemy)
	
	# 应用效果
	apply_effect(enemy)
	
	# 检查是否需要生成爆炸效果（延迟调用以避免物理查询冲突）
	call_deferred("_spawn_explosion_if_needed")
	
	# 穿透逻辑：减少穿透次数
	if pierce_count > 0:
		pierce_count -= 1
		print("[Projectile] 穿透击中，剩余穿透次数: ", pierce_count)
		return  # 不销毁，继续飞行
	
	# 打中人也销毁（如果没有穿透）
	print("[Projectile] 子弹销毁")
	queue_free()


# ==============================================================================
# 爆炸效果系统
# ==============================================================================

func _spawn_explosion_if_needed() -> void:
	"""检查并生成爆炸效果（如果武器有爆炸属性）"""
	if not weapon_stats:
		return
	
	if weapon_stats.explosion_radius <= 0:
		return
	
	print("[Projectile] ✓ 生成爆炸: 伤害=%.1f, 半径=%.1f" % [weapon_stats.damage, weapon_stats.explosion_radius])
	
	# 加载爆炸场景
	var explosion_scene = load("res://scenes/vfx/explosion_area.tscn")
	if not explosion_scene:
		printerr("[Projectile] 错误: 无法加载爆炸场景")
		return
	
	# 实例化爆炸
	var explosion = explosion_scene.instantiate()
	
	# 【关键】先设置位置和参数，再添加到场景
	explosion.global_position = global_position
	
	# 【安全检查】确保 owner_unit 仍然有效
	var valid_owner = null
	if owner_unit and is_instance_valid(owner_unit):
		valid_owner = owner_unit
	else:
		print("[Projectile] ⚠️ owner_unit 已被释放，使用 null")
	
	# 计算爆炸伤害（基于武器伤害 + 玩家伤害）
	var base_damage = weapon_stats.damage
	
	# 添加玩家伤害加成
	if valid_owner and "damage" in valid_owner:
		base_damage += valid_owner.damage
	elif Global.player and is_instance_valid(Global.player) and "damage" in Global.player:
		base_damage += Global.player.damage
	
	var explosion_damage = base_damage * weapon_stats.explosion_damage_scale
	
	print("[Projectile] 爆炸伤害: %.1f (基础:%.1f × 倍率:%.1f)" % [explosion_damage, base_damage, weapon_stats.explosion_damage_scale])
	
	# 设置爆炸参数
	if explosion.has_method("setup"):
		explosion.setup(
			explosion_damage,
			weapon_stats.explosion_radius,
			valid_owner  # 使用验证后的 owner
		)
	
	# 【关键】最后才添加到场景树
	get_tree().root.add_child(explosion)

# ==============================================================================
# 效果系统
# ==============================================================================

## 应用效果（治疗/buff等）
func apply_effect(enemy: Node2D) -> void:
	if effect_type.is_empty():
		return
	
	match effect_type:
		"heal":
			apply_heal_effect()
		"buff":
			apply_buff_effect()
		"fire":
			apply_fire_effect(enemy)
		"ice":
			apply_ice_effect(enemy)
		"chain":
			apply_chain_effect(enemy)
		"poison":
			apply_poison_effect(enemy)
		"stun":
			apply_stun_effect(enemy)
		_:
			push_warning("[Projectile] 未知效果类型: ", effect_type)

## 应用治疗效果
func apply_heal_effect() -> void:
	var heal_multiplier = float(param2) if not param2.is_empty() else 0.5
	var heal_amount = hitbox.damage * heal_multiplier if hitbox else 0.0
	var heal_range = float(param3) if not param3.is_empty() else 0.0
	
	# 治疗玩家
	if is_instance_valid(Global.player) and Global.player.has_method("heal"):
		Global.player.heal(heal_amount)
		print("[Projectile] 治疗玩家: ", heal_amount)
	
	# 范围治疗队友
	if heal_range > 0:
		var allies = get_tree().get_nodes_in_group("allies")
		for ally in allies:
			if is_instance_valid(ally) and global_position.distance_to(ally.global_position) <= heal_range:
				if ally.has_method("heal"):
					ally.heal(heal_amount)
					print("[Projectile] 治疗队友: ", ally.name, " +", heal_amount)

## 应用 Buff 效果
func apply_buff_effect() -> void:
	var buff_duration = float(param3) if not param3.is_empty() else 5.0
	var buff_amount = hitbox.damage * 0.1 if hitbox else 0.0
	
	if is_instance_valid(Global.player) and Global.player.has_method("apply_damage_buff"):
		Global.player.apply_damage_buff(buff_amount, buff_duration)
		print("[Projectile] 应用伤害 buff: +", buff_amount, " 持续 ", buff_duration, "秒")

## 追踪最近的敌人
func track_nearest_enemy(delta: float) -> void:
	var enemies = get_tree().get_nodes_in_group("enemies")
	if enemies.size() == 0:
		return
	
	# 找到最近的敌人
	var nearest_enemy: Node2D = null
	var nearest_distance = INF
	
	for enemy in enemies:
		if not is_instance_valid(enemy):
			continue
		
		var distance = global_position.distance_to(enemy.global_position)
		if distance < nearest_distance:
			nearest_enemy = enemy
			nearest_distance = distance
	
	if nearest_enemy:
		# 计算朝向敌人的方向
		var direction_to_enemy = global_position.direction_to(nearest_enemy.global_position)
		var current_direction = velocity.normalized()
		
		# 平滑转向
		var new_direction = current_direction.lerp(direction_to_enemy, homing_strength * delta)
		velocity = new_direction.normalized() * velocity.length()

# ==============================================================================
# 额外效果系统（火/冰/链/毒/晕）
# ==============================================================================

## 应用燃烧效果
func apply_fire_effect(enemy: Node2D) -> void:
	if not is_instance_valid(enemy) or not enemy.has_method("apply_burn"):
		return
	
	var burn_damage_per_sec = float(param1) if not param1.is_empty() else hitbox.damage * 0.2
	var burn_duration = float(param2) if not param2.is_empty() else 3.0
	
	enemy.apply_burn(burn_damage_per_sec, burn_duration)
	print("[Projectile] 应用燃烧: ", burn_damage_per_sec, " 伤害/秒, 持续 ", burn_duration, "秒")

## 应用冰冻效果
func apply_ice_effect(enemy: Node2D) -> void:
	if not is_instance_valid(enemy) or not enemy.has_method("apply_slow"):
		return
	
	var slow_ratio = float(param1) if not param1.is_empty() else 0.5  # 减速 50%
	var slow_duration = float(param2) if not param2.is_empty() else 2.0
	
	enemy.apply_slow(slow_ratio, slow_duration)
	print("[Projectile] 应用减速: ", slow_ratio * 100, "%, 持续 ", slow_duration, "秒")

## 应用连锁效果
func apply_chain_effect(enemy: Node2D) -> void:
	if not is_instance_valid(enemy):
		return
	
	var chain_count = int(param1) if not param1.is_empty() else 3
	var chain_range = float(param2) if not param2.is_empty() else 200.0
	var chain_damage_ratio = float(param3) if not param3.is_empty() else 0.5
	
	# 找到附近的敌人进行连锁
	var enemies = get_tree().get_nodes_in_group("enemies")
	var chained_enemies = [enemy]  # 已连锁的敌人
	var current_target = enemy
	var current_damage = hitbox.damage if hitbox else 0.0
	
	for i in range(chain_count):
		var next_target = find_nearest_unchained_enemy(current_target, enemies, chained_enemies, chain_range)
		if not next_target:
			break
		
		# 对下一个目标造成递减伤害
		current_damage *= chain_damage_ratio
		if next_target.has_method("apply_modifier_damage"):
			next_target.apply_modifier_damage(current_damage, owner_unit, {
				"kind": "projectile_chain",
				"damage_type": "DMG_DIRECT",
			})
			print("[Projectile] 连锁攻击: ", next_target.name, " 伤害=", current_damage)
		elif next_target.has_method("take_damage"):
			next_target.take_damage(current_damage, {
				"source": owner_unit,
				"kind": "projectile_chain",
				"damage_type": "DMG_DIRECT",
			})
			print("[Projectile] 连锁攻击: ", next_target.name, " 伤害=", current_damage)
		
		# 创建视觉效果（可选）
		create_chain_visual(current_target.global_position, next_target.global_position)
		
		chained_enemies.append(next_target)
		current_target = next_target
	
	print("[Projectile] 连锁完成: 击中 ", chained_enemies.size(), " 个敌人")

## 找到最近的未连锁敌人
func find_nearest_unchained_enemy(from_target: Node2D, all_enemies: Array, chained: Array, max_range: float) -> Node2D:
	var nearest: Node2D = null
	var nearest_distance = INF
	
	for enemy in all_enemies:
		if not is_instance_valid(enemy) or enemy in chained:
			continue
		
		var distance = from_target.global_position.distance_to(enemy.global_position)
		if distance <= max_range and distance < nearest_distance:
			nearest = enemy
			nearest_distance = distance
	
	return nearest

## 创建连锁视觉效果
func create_chain_visual(from_pos: Vector2, to_pos: Vector2) -> void:
	# 创建一条闪电线（可选实现）
	var line = Line2D.new()
	line.add_point(from_pos)
	line.add_point(to_pos)
	line.width = 2.0
	line.default_color = Color(0.5, 0.8, 1.0, 0.8)  # 蓝白色
	get_tree().root.add_child(line)
	
	# 0.2 秒后自动删除
	get_tree().create_timer(0.2).timeout.connect(line.queue_free)

## 应用中毒效果
func apply_poison_effect(enemy: Node2D) -> void:
	if not is_instance_valid(enemy) or not enemy.has_method("apply_poison"):
		return
	
	var poison_damage_per_sec = float(param1) if not param1.is_empty() else hitbox.damage * 0.15
	var poison_duration = float(param2) if not param2.is_empty() else 5.0
	
	enemy.apply_poison(poison_damage_per_sec, poison_duration)
	print("[Projectile] 应用中毒: ", poison_damage_per_sec, " 伤害/秒, 持续 ", poison_duration, "秒")

## 应用眩晕效果
func apply_stun_effect(enemy: Node2D) -> void:
	if not is_instance_valid(enemy) or not enemy.has_method("apply_stun"):
		return
	
	var stun_duration = float(param1) if not param1.is_empty() else 1.5
	
	enemy.apply_stun(stun_duration)
	print("[Projectile] 应用眩晕: 持续 ", stun_duration, "秒")
