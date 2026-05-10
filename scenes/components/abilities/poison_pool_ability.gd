extends AbilityBase
class_name PoisonPoolAbility

## 毒池能力 - 死亡时在地面留下持续伤害区域
## 配置示例: poison_pool,毒池,0,0,999999,0,1,60,5,0.5,8

@export_group("Poison Pool Settings")
@export var pool_radius: float = 60.0  # 毒池半径
@export var pool_damage: float = 5.0  # 每次伤害
@export var pool_damage_interval: float = 0.5  # 伤害间隔
@export var pool_lifetime: float = 8.0  # 持续时间
@export var pool_color: Color = Color(0.2, 1.0, 0.2, 0.5)  # 毒池颜色

# ==============================================================================
# 初始化
# ==============================================================================
func _ready() -> void:
	super._ready()
	ability_id = "poison_pool"
	ability_name = "毒池"
	
	# 连接敌人死亡信号
	if owner_enemy and owner_enemy.has_signal("on_unit_died"):
		owner_enemy.health_component.on_unit_died.connect(_on_owner_died)

# ==============================================================================
# 能力实现
# ==============================================================================
func activate() -> void:
	"""激活能力 - 生成毒池"""
	if not is_instance_valid(owner_enemy):
		return
	
	_spawn_poison_pool(owner_enemy.global_position)
	ability_activated.emit()

func _on_owner_died() -> void:
	"""敌人死亡时触发"""
	activate()

func _spawn_poison_pool(pos: Vector2) -> void:
	"""在指定位置生成毒池"""
	var tree = Engine.get_main_loop() as SceneTree
	if tree == null or tree.current_scene == null:
		push_error("[PoisonPoolAbility] 无法获取场景树!")
		return
	
	var poison = Area2D.new()
	poison.name = "PoisonPool_" + str(Time.get_ticks_msec())
	poison.collision_layer = 0
	poison.collision_mask = 1
	poison.monitorable = false
	poison.monitoring = true
	
	# 碰撞体
	var col = CollisionShape2D.new()
	var shape = CircleShape2D.new()
	shape.radius = pool_radius
	col.shape = shape
	poison.add_child(col)
	
	# 视觉效果
	var vis = Polygon2D.new()
	vis.name = "PoisonVisual"
	var points = PackedVector2Array()
	var segments = 32
	
	for i in range(segments):
		var angle = float(i) * TAU / float(segments)
		var point = Vector2(cos(angle), sin(angle)) * pool_radius
		points.append(point)
	
	vis.polygon = points
	vis.color = pool_color
	vis.z_index = -1
	poison.add_child(vis)
	
	# 添加到场景
	tree.current_scene.add_child(poison)
	poison.global_position = pos
	
	# 伤害计时器
	var dmg_timer = Timer.new()
	dmg_timer.name = "DamageTimer"
	dmg_timer.wait_time = pool_damage_interval
	dmg_timer.one_shot = false
	poison.add_child(dmg_timer)
	
	dmg_timer.timeout.connect(func():
		if not is_instance_valid(poison):
			dmg_timer.stop()
			return
		
		var bodies = poison.get_overlapping_bodies()
		var areas = poison.get_overlapping_areas()
		var all_targets = bodies + areas
		
		for target in all_targets:
			var player_node = null
			
			if target.is_in_group("player"):
				player_node = target
			elif target.owner and target.owner.is_in_group("player"):
				player_node = target.owner
			
			if is_instance_valid(player_node) and player_node.has_method("take_damage"):
				player_node.take_damage(int(pool_damage), {
					"source": owner,
					"kind": "poison_pool",
					"damage_type": "DMG_DOT",
				})
				if Global.has_method("spawn_floating_text"):
					Global.spawn_floating_text(player_node.global_position, 
						"-" + str(int(pool_damage)), Color(0.5, 1.0, 0.5))
	)
	
	dmg_timer.start()
	
	# 生命计时器
	var life_timer = Timer.new()
	life_timer.name = "LifeTimer"
	life_timer.wait_time = pool_lifetime
	life_timer.one_shot = true
	poison.add_child(life_timer)
	
	life_timer.timeout.connect(func():
		if is_instance_valid(poison):
			var fade_tween = poison.create_tween()
			fade_tween.tween_property(vis, "color:a", 0.0, 0.5)
			fade_tween.finished.connect(func():
				if is_instance_valid(poison):
					poison.queue_free()
			)
	)
	
	life_timer.start()
	
	if Global.has_method("spawn_floating_text"):
		Global.spawn_floating_text(pos, "TOXIC!", Color(0.5, 1.0, 0.5))

# ==============================================================================
# 配置加载
# ==============================================================================
func setup(enemy: Node2D, config: Dictionary = {}) -> void:
	super.setup(enemy, config)
	
	if config.has("pool_radius"):
		pool_radius = float(config.pool_radius)
	if config.has("pool_damage"):
		pool_damage = float(config.pool_damage)
	if config.has("pool_damage_interval"):
		pool_damage_interval = float(config.pool_damage_interval)
	if config.has("pool_lifetime"):
		pool_lifetime = float(config.pool_lifetime)
	if config.has("pool_color_r") and config.has("pool_color_g") and config.has("pool_color_b"):
		pool_color = Color(
			float(config.pool_color_r),
			float(config.pool_color_g),
			float(config.pool_color_b),
			float(config.get("pool_color_a", 0.5))
		)

func get_config_template() -> Dictionary:
	var base = super.get_config_template()
	base.merge({
		"pool_radius": pool_radius,
		"pool_damage": pool_damage,
		"pool_damage_interval": pool_damage_interval,
		"pool_lifetime": pool_lifetime,
		"pool_color_r": pool_color.r,
		"pool_color_g": pool_color.g,
		"pool_color_b": pool_color.b,
		"pool_color_a": pool_color.a
	})
	return base
