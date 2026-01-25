extends Enemy
class_name EnemyElites

# ==============================================================================
# 精英敌人通用基类
# ==============================================================================
# 所有精英敌人都继承此类，实现通用的吞噬和升级逻辑
# 子类只需要实现阶段特定的能力

# ==============================================================================
# 内部变量
# ==============================================================================

var current_stage: int = 1  # 1-5
var mobs_eaten_count: int = 0
var eat_timer: float = 0.0
var eating_area: Area2D = null
var eating_detection_shape: CollisionShape2D = null

# 奖励值 (单独跟踪)
var xp_value: int = 50
var gold_value: int = 10

# 阶段特定的计时器
var stage2_shoot_timer: float = 0.0
var stage3_aoe_timer: float = 0.0
var is_stage3_immune: bool = false  # 第3阶段击退免疫标志

# 吞噬暂停用于视觉反馈
var eating_pause_timer: float = 0.0
var is_eating_paused: bool = false

# 从配置加载的参数
var eat_detection_radius: float = 200.0
var eat_cooldown: float = 2.0
var eat_heal_percent: float = 0.1
var eat_max_hp_increase: float = 1.05
var eat_damage_increase: float = 1.03
var base_xp_value: int = 50
var base_gold_value: int = 10
var reward_scale_per_stage: float = 2.0
var eating_pause_duration: float = 0.1

# ==============================================================================
# 生命周期
# ==============================================================================

func _ready() -> void:
	super._ready()
	
	# 设置敌人类型
	enemy_type = EnemyType.NORMAL
	
	# 确保从一开始就启用移动
	can_move = true
	
	# 从配置加载参数
	_load_ability_config()
	
	# 初始化吞噬检测区域
	_setup_eating_detection()
	
	# 初始化阶段能力计时器 - 由子类在 _ready() 中设置
	# stage2_shoot_timer 和 stage3_aoe_timer 由子类初始化
	
	# 初始化奖励值
	_update_reward_values()

func _process(delta: float) -> void:
	# 处理吞噬暂停用于视觉反馈
	if is_eating_paused:
		eating_pause_timer -= delta
		if eating_pause_timer <= 0:
			is_eating_paused = false
			can_move = true  # 吞噬暂停后重新启用移动
	
	# 调用父类的 process 用于移动和 AI
	super._process(delta)
	
	# 更新吞噬冷却
	if eat_timer > 0:
		eat_timer -= delta
	else:
		_try_eat_nearby_enemy()
	
	# 阶段特定的行为（由子类实现）
	_update_stage_behavior(delta)

# ==============================================================================
# 配置加载
# ==============================================================================

func _load_ability_config() -> void:
	"""从配置加载能力参数"""
	var ability_config = EliteConfigManager.get_elite_ability_config(enemy_id)
	if ability_config:
		eat_detection_radius = ability_config.eat_detection_radius
		eat_cooldown = ability_config.eat_cooldown
		eat_heal_percent = ability_config.eat_heal_percent
		eat_max_hp_increase = ability_config.eat_max_hp_increase
		eat_damage_increase = ability_config.eat_damage_increase
		base_xp_value = ability_config.base_xp_value
		base_gold_value = ability_config.base_gold_value
		reward_scale_per_stage = ability_config.reward_scale_per_stage
		eating_pause_duration = ability_config.eating_pause_duration
	else:
		push_warning("[EnemyElites] No ability config found for %s, using defaults" % enemy_id)

# ==============================================================================
# 吞噬检测设置
# ==============================================================================

func _setup_eating_detection() -> void:
	"""创建用于检测附近敌人的 Area2D"""
	eating_area = Area2D.new()
	eating_area.name = "EatingDetectionArea"
	add_child(eating_area)
	
	# 创建碰撞形状
	eating_detection_shape = CollisionShape2D.new()
	var circle_shape = CircleShape2D.new()
	circle_shape.radius = eat_detection_radius
	eating_detection_shape.shape = circle_shape
	eating_area.add_child(eating_detection_shape)
	
	# 设置碰撞层 (仅检测敌人)
	eating_area.collision_layer = 0
	eating_area.collision_mask = 4  # 假设敌人在第4层

# ==============================================================================
# 吞噬机制
# ==============================================================================

func _try_eat_nearby_enemy() -> void:
	"""检测并吞噬附近的敌人"""
	if eating_area == null:
		return
	
	var nearby_enemies = eating_area.get_overlapping_areas()
	if nearby_enemies.is_empty():
		return
	
	# 找到有效的敌人来吞噬 (不是自己，不是玩家)
	var victim: Node2D = null
	for area in nearby_enemies:
		var parent = area.get_parent()
		if parent is Enemy and parent != self and not parent.is_dead:
			victim = parent
			break
	
	if victim == null:
		return
	
	# 吞噬受害者
	_eat_enemy(victim)
	eat_timer = eat_cooldown

func _eat_enemy(victim: Enemy) -> void:
	"""处理吞噬敌人"""
	# 增加吞噬计数
	mobs_eaten_count += 1
	
	# 治疗这个敌人
	var heal_amount = int(health * eat_heal_percent)
	health_component.heal(heal_amount)
	
	# 增加最大生命值和伤害
	health = int(health * eat_max_hp_increase)
	damage = int(damage * eat_damage_increase)
	
	# 移除受害者
	victim.queue_free()
	
	# 添加吞噬暂停用于视觉反馈 (咀嚼效果)
	_trigger_eating_pause()
	
	# 检查进化
	_check_evolution()

func _check_evolution() -> void:
	"""检查这个敌人是否应该进化到下一阶段"""
	if current_stage >= 5:
		return  # 已经在最大阶段

	# 从配置中获取下一阶段的进化配置
	var next_evolution = EliteConfigManager.get_evolution_stage(enemy_id, current_stage + 1)
	if next_evolution == null:
		return
	
	# 检查是否吞噬了足够的敌人来进化到下一阶段
	var threshold = next_evolution.eat_count_per_stage
	if mobs_eaten_count >= threshold:
		_evolve_to_stage(current_stage + 1)

func _evolve_to_stage(new_stage: int) -> void:
	"""进化到新阶段并更新视觉和属性"""
	if new_stage <= current_stage or new_stage > 5:
		return
	
	current_stage = new_stage
	
	# 确保移动能力启用
	can_move = true
	is_eating_paused = false
	eating_pause_timer = 0.0
	
	# 更新视觉
	_update_visual_for_stage(new_stage)
	
	# 从 EliteConfigManager 获取进化配置
	var evolution_config = EliteConfigManager.get_evolution_stage(enemy_id, new_stage)
	if evolution_config:
		# 应用配置中的属性倍数
		var old_health = health
		var old_damage = damage
		var old_speed = speed
		
		health = int(health * evolution_config.health_multiplier)
		damage = int(damage * evolution_config.damage_multiplier)
		speed = speed * evolution_config.speed_multiplier
		
		# 用新的最大生命值更新 health_component
		if health_component:
			health_component.max_health = health
			# 进化时治疗到满血
			health_component.current_health = health
	else:
		# 如果找不到配置，回退到旧逻辑
		var stage_multiplier = pow(1.2, new_stage - 1)
		health = int(health * stage_multiplier)
		damage = int(damage * stage_multiplier)
		
		if health_component:
			health_component.max_health = health
			health_component.current_health = health
	
	# 应用阶段特定的效果（由子类实现）
	_apply_stage_effects(new_stage)
	
	# 更新奖励值
	_update_reward_values()

func _update_visual_for_stage(stage: int) -> void:
	"""更新给定阶段的精灵和缩放"""
	if stage < 1 or stage > 5:
		return
	
	# 从配置加载精灵
	var sprite_path = EliteConfigManager.get_sprite_path_for_stage(enemy_id, stage)
	if sprite_path == "":
		return
	
	var sprite_texture = load(sprite_path)
	if not sprite_texture:
		push_error("[EnemyElites] Failed to load sprite from: %s" % sprite_path)
		return
	
	# 更新精灵纹理
	var sprite_node = visuals.get_node_or_null("Sprite")
	if not sprite_node:
		sprite_node = visuals.get_node_or_null("Sprite2D")
	
	if sprite_node:
		sprite_node.texture = sprite_texture
	else:
		push_error("[EnemyElites] Sprite node not found in Visuals!")
		return
	
	# 从配置获取缩放倍数
	var scale_multiplier = EliteConfigManager.get_scale_multiplier_for_stage(enemy_id, stage)
	
	# 计算目标缩放 (考虑 Visuals 的基础缩放 0.5)
	var base_visual_scale = 0.5
	var target_scale = scale_multiplier * base_visual_scale
	
	# 直接设置缩放，不使用 Tween 动画 (避免闪烁)
	visuals.scale = Vector2(target_scale, target_scale)

func _update_reward_values() -> void:
	"""根据当前阶段缩放 XP 和金币奖励"""
	var stage_multiplier = pow(reward_scale_per_stage, current_stage - 1)
	xp_value = int(base_xp_value * stage_multiplier)
	gold_value = int(base_gold_value * stage_multiplier)

# ==============================================================================
# 移动和速度管理
# ==============================================================================

func _trigger_eating_pause() -> void:
	"""吞噬时触发短暂暂停用于视觉反馈"""
	is_eating_paused = true
	eating_pause_timer = eating_pause_duration
	can_move = false  # 吞噬暂停期间禁用移动

# ==============================================================================
# 覆盖击退以实现第3阶段免疫
# ==============================================================================

func apply_knockback(knock_dir: Vector2, knock_power: float) -> void:
	"""覆盖击退以实现第3阶段免疫"""
	# 第3阶段免疫击退
	if is_stage3_immune:
		return
	
	# 否则，使用父类的击退逻辑
	super.apply_knockback(knock_dir, knock_power)

# ==============================================================================
# 覆盖死亡以显示最终阶段
# ==============================================================================

func destroy_enemy() -> void:
	"""覆盖以在死亡时显示阶段信息"""
	super.destroy_enemy()

# ==============================================================================
# 虚函数 - 由子类实现
# ==============================================================================

func _update_stage_behavior(delta: float) -> void:
	"""更新阶段特定的行为 - 由子类实现"""
	pass

func _apply_stage_effects(stage: int) -> void:
	"""应用阶段特定的效果 - 由子类实现"""
	pass

# ==============================================================================
# 调试/工具
# ==============================================================================

func get_stage_info() -> Dictionary:
	"""返回当前阶段信息"""
	return {
		"stage": current_stage,
		"mobs_eaten": mobs_eaten_count,
		"health": health,
		"damage": damage,
		"xp_value": xp_value,
		"gold_value": gold_value
	}
