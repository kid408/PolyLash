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

# 第4阶段冲撞配置
@export var stage4_charge_cooldown: float = 5.0
@export var stage4_charge_speed: float = 400.0
@export var stage4_charge_damage: float = 50.0
@export var stage4_warning_duration: float = 1.0

# 第5阶段八方向射击配置
@export var stage5_shoot_cooldown: float = 4.0
@export var stage5_projectile_speed: float = 250.0
@export var stage5_burst_count: int = 3
@export var stage5_burst_interval: float = 0.2

# ==============================================================================
# 生命周期
# ==============================================================================

func _ready() -> void:
	super._ready()
	
	# 初始化 Glutton 特定的计时器
	stage2_shoot_timer = stage2_shoot_cooldown
	stage3_aoe_timer = stage3_aoe_cooldown
	stage4_charge_timer = stage4_charge_cooldown
	stage5_shoot_timer = stage5_shoot_cooldown

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
			_update_stage4_behavior(delta)
		5:
			_update_stage5_behavior(delta)

func _apply_stage_effects(stage: int) -> void:
	"""应用阶段特定的效果"""
	match stage:
		2:
			# 第2阶段: 启用酸液投射物射击能力
			stage2_shoot_timer = 0.5
		
		3:
			# 第3阶段: 免疫击退，变红，启用AoE踩踏
			is_stage3_immune = true
			visuals.modulate = Color(1.5, 0.3, 0.3, 1.0)
			stage3_aoe_timer = 0.5
		
		4:
			# 第4阶段: 启用冲撞能力
			stage4_charge_timer = 1.0
			is_charging = false
		
		5:
			# 第5阶段: 启用八方向射击
			stage5_shoot_timer = 1.0

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

## 预加载标准敌人投射物场景（与普通敌人共用，确保碰撞层、信号链、反射全部一致）
var _enemy_projectile_scene: PackedScene = preload("res://scenes/projectiles/projectile_enemy.tscn")

func _shoot_acid_projectile() -> void:
	"""向玩家射击酸液投射物（复用标准 projectile_enemy.tscn）"""
	if not is_instance_valid(Global.player):
		return
	
	var direction = global_position.direction_to(Global.player.global_position)
	var projectile_damage = int(damage * 0.5)
	
	var projectile = _enemy_projectile_scene.instantiate() as Projectile
	projectile.global_position = global_position
	projectile.set_projectile(
		direction * stage2_projectile_speed,
		projectile_damage,
		false,  # critical
		0.0,    # knockback
		self
	)
	# 绿色酸液外观
	var sprite = projectile.get_node_or_null("Sprite2D")
	if sprite:
		sprite.modulate = Color.GREEN
		sprite.scale = Vector2(0.3, 0.3)
	
	projectile.add_to_group("elite_projectiles")
	get_tree().root.add_child(projectile)

# ==============================================================================
# Stage 3 - AoE 踩踏伤害
# ==============================================================================

func _update_stage3_behavior(delta: float) -> void:
	"""第3阶段: 执行 AoE 踩踏伤害"""
	stage3_aoe_timer -= delta
	
	if stage3_aoe_timer <= 0:
		_perform_aoe_stomp()
		stage3_aoe_timer = stage3_aoe_cooldown

func _perform_aoe_stomp() -> void:
	"""在 Glutton 周围执行 AoE 踩踏伤害"""
	# 创建视觉效果 - 红色圆圈
	var aoe_visual = Node2D.new()
	aoe_visual.global_position = global_position
	aoe_visual.z_index = 50
	get_tree().root.add_child(aoe_visual)
	
	# 添加圆形多边形
	var circle = Polygon2D.new()
	var points = PackedVector2Array()
	var segments = 32
	for i in range(segments):
		var angle = (i / float(segments)) * TAU
		points.append(Vector2(cos(angle), sin(angle)) * stage3_aoe_radius)
	circle.polygon = points
	circle.color = Color(1.0, 0.0, 0.0, 0.0)  # 初始透明
	aoe_visual.add_child(circle)
	
	# 动画：闪烁效果（tween 创建在 aoe_visual 上，不依赖精英节点）
	var tween = aoe_visual.create_tween()
	tween.tween_property(circle, "color:a", 0.6, 0.1)
	tween.tween_property(circle, "color:a", 0.0, 0.2)
	tween.tween_callback(func():
		if is_instance_valid(aoe_visual):
			aoe_visual.queue_free()
	)
	
	# 检测范围内的所有玩家（支持多角色）
	var players = get_tree().get_nodes_in_group("player")
	var hit_count = 0
	
	for player in players:
		if not is_instance_valid(player):
			continue
		
		var distance = global_position.distance_to(player.global_position)
		
		if distance <= stage3_aoe_radius:
			var damage = int(stage3_aoe_damage)
			if player.has_method("take_damage"):
				player.take_damage(damage, {"source": self, "kind": "glutton_aoe"})
				hit_count += 1
				
				# 显示浮动文本
				if Global.has_method("spawn_floating_text"):
					Global.spawn_floating_text(player.global_position, "STOMP! %d" % damage, Color.RED)
	
	if hit_count > 0:
		# 震屏效果
		if Global.has_signal("on_camera_shake"):
			Global.on_camera_shake.emit(5.0, 0.3)

# ==============================================================================
# Stage 4 - 冲撞攻击
# ==============================================================================

var stage4_charge_timer: float = 0.0
var is_charging: bool = false
var charge_target_pos: Vector2 = Vector2.ZERO
var glutton_charge_line: Line2D = null  # 改名避免与父类冲突

func _update_stage4_behavior(delta: float) -> void:
	"""第4阶段: 冲撞攻击"""
	if is_charging:
		return  # 正在冲撞中，不更新计时器
	
	stage4_charge_timer -= delta
	
	if stage4_charge_timer <= 0:
		_start_charge_attack()
		stage4_charge_timer = stage4_charge_cooldown

func _start_charge_attack() -> void:
	"""开始冲撞攻击"""
	var player = get_tree().get_first_node_in_group("player")
	if not is_instance_valid(player):
		return
	
	# 计算冲撞目标位置（玩家当前位置）
	charge_target_pos = player.global_position
	
	# 创建红色预警线
	glutton_charge_line = Line2D.new()
	glutton_charge_line.width = 8.0
	glutton_charge_line.default_color = Color(1.0, 0.0, 0.0, 0.8)
	glutton_charge_line.add_point(global_position)
	glutton_charge_line.add_point(charge_target_pos)
	glutton_charge_line.z_index = 100
	get_tree().root.add_child(glutton_charge_line)
	
	# 闪烁动画（tween 创建在 line 上，不依赖精英节点）
	var tween = glutton_charge_line.create_tween()
	tween.set_loops(int(stage4_warning_duration / 0.2))
	tween.tween_property(glutton_charge_line, "modulate:a", 0.3, 0.1)
	tween.tween_property(glutton_charge_line, "modulate:a", 1.0, 0.1)
	
	# 等待预警时间后执行冲撞
	await get_tree().create_timer(stage4_warning_duration).timeout
	
	if is_instance_valid(glutton_charge_line):
		glutton_charge_line.queue_free()
		glutton_charge_line = null
	
	_execute_charge()

func _execute_charge() -> void:
	"""执行冲撞"""
	if not is_instance_valid(self):
		return
	
	is_charging = true
	can_move = false  # 冲撞期间禁用普通移动
	
	var start_pos = global_position
	var direction = start_pos.direction_to(charge_target_pos)
	var distance = start_pos.distance_to(charge_target_pos)
	var charge_time = distance / stage4_charge_speed
	
	# 创建冲撞轨迹效果
	var trail = Line2D.new()
	trail.width = 6.0
	trail.default_color = Color(1.0, 0.5, 0.0, 0.6)
	trail.z_index = 50
	get_tree().root.add_child(trail)
	
	# 冲撞动画
	var tween = create_tween()
	tween.tween_property(self, "global_position", charge_target_pos, charge_time)
	
	# 在冲撞过程中检测碰撞
	var hit_targets = {}
	var check_timer = 0.0
	var check_interval = 0.05
	
	while check_timer < charge_time:
		await get_tree().create_timer(check_interval).timeout
		check_timer += check_interval
		
		if not is_instance_valid(self):
			break
		
		# 更新轨迹
		if is_instance_valid(trail):
			trail.add_point(global_position)
			if trail.get_point_count() > 20:
				trail.remove_point(0)
		
		# 检测碰撞
		var players = get_tree().get_nodes_in_group("player")
		for player in players:
			if not is_instance_valid(player) or player in hit_targets:
				continue
			
			var dist = global_position.distance_to(player.global_position)
			if dist < 50.0:  # 碰撞半径
				hit_targets[player] = true
				var damage = int(stage4_charge_damage)
				if player.has_method("take_damage"):
					player.take_damage(damage, {"source": self, "kind": "glutton_charge"})
					print("[EnemyGlutton] 冲撞击中玩家，造成 %d 伤害！" % damage)
					
					if Global.has_method("spawn_floating_text"):
						Global.spawn_floating_text(player.global_position, "CHARGE! %d" % damage, Color.ORANGE)
					
					# 震屏
					if Global.has_signal("on_camera_shake"):
						Global.on_camera_shake.emit(8.0, 0.2)
	
	# 冲撞结束
	is_charging = false
	can_move = true
	
	# 清理轨迹
	if is_instance_valid(trail):
		var fade_tween = trail.create_tween()
		fade_tween.tween_property(trail, "modulate:a", 0.0, 0.5)
		fade_tween.tween_callback(func(): 
			if is_instance_valid(trail):
				trail.queue_free()
		)
	
	print("[EnemyGlutton] 冲撞完成，击中 %d 个目标" % hit_targets.size())

# ==============================================================================
# Stage 5 - 八方向连续射击
# ==============================================================================

var stage5_shoot_timer: float = 0.0

func _update_stage5_behavior(delta: float) -> void:
	"""第5阶段: 八方向连续射击"""
	stage5_shoot_timer -= delta
	
	if stage5_shoot_timer <= 0:
		_shoot_eight_directions()
		stage5_shoot_timer = stage5_shoot_cooldown

func _shoot_eight_directions() -> void:
	"""向八个方向发射连续子弹"""
	print("[EnemyGlutton] ★★★ 八方向连续射击 ★★★")
	
	# 八个方向
	var directions = [
		Vector2.RIGHT,
		Vector2(1, 1).normalized(),
		Vector2.DOWN,
		Vector2(-1, 1).normalized(),
		Vector2.LEFT,
		Vector2(-1, -1).normalized(),
		Vector2.UP,
		Vector2(1, -1).normalized()
	]
	
	# 连续发射
	for burst in range(stage5_burst_count):
		for dir in directions:
			_shoot_projectile_in_direction(dir)
		
		# 等待下一轮
		if burst < stage5_burst_count - 1:
			await get_tree().create_timer(stage5_burst_interval).timeout
			if not is_instance_valid(self):
				return

func _shoot_projectile_in_direction(direction: Vector2) -> void:
	"""向指定方向发射投射物（复用标准 projectile_enemy.tscn）"""
	var projectile_damage = int(damage * 0.6)
	
	var projectile = _enemy_projectile_scene.instantiate() as Projectile
	projectile.global_position = global_position
	projectile.set_projectile(
		direction * stage5_projectile_speed,
		projectile_damage,
		false,  # critical
		0.0,    # knockback
		self
	)
	# 紫色外观
	var sprite = projectile.get_node_or_null("Sprite2D")
	if sprite:
		sprite.modulate = Color(1.0, 0.3, 1.0)
		sprite.scale = Vector2(0.4, 0.4)
	
	projectile.add_to_group("elite_projectiles")
	get_tree().root.add_child(projectile)

# ==============================================================================
# 死亡处理 - 清理所有投射物和特效
# ==============================================================================

func destroy_enemy() -> void:
	"""重写死亡处理，清理所有 Glutton 创建的投射物和特效"""
	# 清理冲撞预警线
	if is_instance_valid(glutton_charge_line):
		glutton_charge_line.queue_free()
		glutton_charge_line = null
	
	# 清理所有这个 Glutton 创建的投射物（标准 Projectile，通过 owner_unit 匹配）
	var projectiles = get_tree().get_nodes_in_group("elite_projectiles")
	for projectile in projectiles:
		if not is_instance_valid(projectile):
			continue
		if projectile is Projectile and projectile.owner_unit == self:
			projectile.queue_free()
	
	# 调用父类的死亡处理
	super.destroy_enemy()
