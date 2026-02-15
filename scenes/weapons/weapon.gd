extends Node2D
class_name Weapon

@onready var sprite: Sprite2D = $Sprite2D
@onready var hitbox_component: HitboxComponent = $HitboxComponent
@onready var cooldown_timer: Timer = $CooldownTimer
@onready var weapon_behavior: WeaponBehavior = $WeaponBehavior

# 碰撞形状（可能不存在，由 MeleeBehavior 动态创建）
var collision: CollisionShape2D

var data : ItemWeapon
var is_attacking := false
var atk_start_pos: Vector2
var targets:Array[Enemy]
var closest_target:Enemy
var weapon_spread:float

func _ready() -> void:
	# 设置武器贴图偏移，避免遮挡玩家脸部
	# 旧版本使用 Vector2(27, 0) 的偏移
	sprite.position = Vector2(27, 0)
	atk_start_pos = sprite.position
	
	# 确保 Sprite2D 可见并设置渲染层级
	sprite.visible = true
	sprite.z_index = 2  # 在玩家前面渲染 (玩家是 z_index=1)
	
	# 不设置初始 scale，让 update_visuals() 来处理
	
	print("[Weapon] _ready() - Sprite2D 初始化:")
	print("  - 可见性: ", sprite.visible)
	print("  - z_index: ", sprite.z_index)
	print("  - 缩放: ", sprite.scale)
	print("  - 位置: ", sprite.position)
	print("  - Sprite2D 全局位置: ", sprite.global_position)
	print("  - Weapon 全局位置: ", global_position)

func _process(delta: float) -> void:
	if Global.game_paused: return
	
	if not is_attacking:
		if targets.size() > 0:
			update_closest_target()
		else:
			closest_target = null
	
	rotate_to_target()
	update_visuals()
	
	if can_use_weapon():
		use_weapon()

func setup_weapon(data:ItemWeapon) -> void:
	self.data = data
	
	# 确保 weapon_behavior 有正确的 weapon 引用
	if weapon_behavior and not weapon_behavior.weapon:
		weapon_behavior.weapon = self
	
	# 验证数据完整性
	if not data:
		printerr("[Weapon] 错误: 武器数据为空")
		return
	
	if not data.stats:
		printerr("[Weapon] 错误: 武器数据缺少 stats - ", data.item_name)
		return
	
	# 尝试获取 CollisionShape2D（可能由 MeleeBehavior 动态创建）
	if not collision:
		collision = hitbox_component.get_node_or_null("CollisionShape2D")
	
	# 只有当 collision 存在时才设置检测范围
	if collision:
		# 确保 CollisionShape2D 有一个 shape（用于检测范围）
		if not collision.shape:
			collision.shape = CircleShape2D.new()
		
		# 设置检测范围
		if collision.shape is CircleShape2D:
			collision.shape.radius = data.stats.max_range
		elif collision.shape is RectangleShape2D:
			collision.shape.extents = Vector2(data.stats.max_range, data.stats.max_range)
	
	# ============================================================================
	# 场景复用系统 - 应用新字段
	# ============================================================================
	
	# 1. 应用主贴图（如果指定）
	if not data.stats.sprite_texture.is_empty():
		var texture_path = data.stats.sprite_texture
		if ResourceLoader.exists(texture_path):
			sprite.texture = load(texture_path)
			print("[Weapon] 加载贴图: ", texture_path)
			print("[Weapon] Sprite2D 可见性: ", sprite.visible)
			print("[Weapon] Sprite2D 位置: ", sprite.position)
			print("[Weapon] Sprite2D 缩放: ", sprite.scale)
			print("[Weapon] 贴图大小: ", sprite.texture.get_size() if sprite.texture else "null")
		else:
			push_warning("[Weapon] 贴图路径不存在: ", texture_path)
	else:
		printerr("[Weapon] 警告: sprite_texture 为空 - weapon_id: ", data.weapon_id)
	
	# 2. 应用动画帧（如果是 AnimatedSprite2D）
	# 注意：当前 sprite 是 Sprite2D，如果需要 AnimatedSprite2D 需要修改场景
	# if not data.stats.animation_frames_path.is_empty():
	# 	if sprite is AnimatedSprite2D:
	# 		var frames_path = data.stats.animation_frames_path
	# 		if ResourceLoader.exists(frames_path):
	# 			sprite.sprite_frames = load(frames_path)
	# 			print("[Weapon] 加载动画帧: ", frames_path)
	# 		else:
	# 			push_warning("[Weapon] 动画帧路径不存在: ", frames_path)
	
	# 3. 应用碰撞体偏移和缩放（仅当 collision 存在时）
	if collision:
		var hitbox_offset = data.stats.get_hitbox_offset()
		var hitbox_scale = data.stats.get_hitbox_scale()
		
		if hitbox_offset != Vector2.ZERO:
			collision.position = hitbox_offset
			print("[Weapon] 碰撞体偏移: ", hitbox_offset)
		
		if hitbox_scale != Vector2.ONE:
			collision.scale = hitbox_scale
			print("[Weapon] 碰撞体缩放: ", hitbox_scale)
	
	# 4. 对于远程武器，应用枪口偏移
	if data.type == ItemWeapon.WeaponType.RANGE:
		# 验证子弹场景
		if not data.stats.projectile_scene:
			printerr("[Weapon] 错误: 远程武器缺少 projectile_scene - ", data.item_name)
			return
		
		# 应用枪口偏移（假设有 Muzzle 节点）
		var muzzle_offset = data.stats.get_muzzle_offset()
		if muzzle_offset != Vector2.ZERO:
			# 尝试查找 Muzzle 节点（可能在 Sprite2D 下或直接在 Weapon 下）
			var muzzle = sprite.get_node_or_null("Muzzle")
			if not muzzle:
				muzzle = get_node_or_null("Muzzle")
			
			if muzzle:
				muzzle.position = muzzle_offset
				print("[Weapon] 枪口偏移: ", muzzle_offset)
			else:
				# 如果没有 Muzzle 节点，可以动态创建一个 Marker2D
				var new_muzzle = Marker2D.new()
				new_muzzle.name = "Muzzle"
				new_muzzle.position = muzzle_offset
				sprite.add_child(new_muzzle)
				print("[Weapon] 动态创建枪口节点，偏移: ", muzzle_offset)
	
	# 5. 打印调试信息
	print("[Weapon] 武器设置完成: ", data.item_name, " (", data.weapon_id, ")")
	print("  - 类型: ", "MELEE" if data.type == ItemWeapon.WeaponType.MELEE else "RANGE")
	print("  - 等级: ", data.level)
	print("  - 形状类型: ", data.stats.shape_type if not data.stats.shape_type.is_empty() else "未指定")
	print("  - 子弹模式: ", data.stats.bullet_mode if not data.stats.bullet_mode.is_empty() else "未指定")
	if collision:
		print("  - 碰撞体位置/缩放: ", collision.position, " / ", collision.scale)
	else:
		print("  - 碰撞体: 由 MeleeBehavior 动态创建")
	
	# 6. 记录 base_scene_path（用于调试，实际加载在实例化时处理）
	if not data.stats.base_scene_path.is_empty():
		print("  - 基础场景: ", data.stats.base_scene_path)

## 新增：从 weapon_id 直接设置武器（简化调用）
func setup_weapon_by_id(weapon_id: String) -> void:
	var weapon_data = ItemWeapon.create_from_csv(weapon_id)
	if weapon_data:
		setup_weapon(weapon_data)
	else:
		printerr("[Weapon] 错误: 无法创建武器 - ", weapon_id)
	
func use_weapon() -> void:
	calculate_spread()
	
	weapon_behavior.execute_attack()
	cooldown_timer.wait_time = data.stats.cooldown
	cooldown_timer.start()

func rotate_to_target() -> void:
	if is_attacking:
		rotation = get_custom_rotation_to_target()
	else:
		rotation = get_rotation_to_target()

func get_custom_rotation_to_target() -> float:
	if not closest_target or not is_instance_valid(closest_target):
		return rotation

	var rot := global_position.direction_to(closest_target.global_position).angle()
	return rot + weapon_spread
	

func get_rotation_to_target() -> float:
	if targets.size() == 0:
		return get_idle_rotation()
		
	var rot := global_position.direction_to(closest_target.global_position).angle()
	return rot 

func get_idle_rotation() -> float:
	if Global.player.is_facing_right():
		return 0
	else :
		return PI

# 更新手枪的旋转朝向问题
func update_visuals() -> void:
	# X 轴固定为 0.5，Y 轴根据旋转翻转
	sprite.scale.x = 0.5
	if abs(rotation) > PI /2:
		sprite.scale.y = -0.5
	else:
		sprite.scale.y = 0.5

# 计算武器选择朝向
func calculate_spread() -> void:
	# 【修复】每次射击重新计算散布，而不是累加
	weapon_spread = randf_range(-1 + data.stats.accuracy, 1 - data.stats.accuracy)
	rotation += weapon_spread
	
func update_closest_target() -> void:
	closest_target = get_closest_target()

func get_closest_target() -> Node2D:
	if targets.size() == 0:
		return null
	
	var closest_enemy: Enemy = targets[0]
	var closest_distance := global_position.distance_to(closest_enemy.global_position)
	
	for i in range(1, targets.size()):
		var target: Enemy = targets[i]
		# 安全检查：确保目标仍然有效
		if not is_instance_valid(target):
			continue
		
		var distance := global_position.distance_to(target.global_position)
		
		if distance < closest_distance:
			closest_enemy = target
			closest_distance = distance
	
	return closest_enemy


func can_use_weapon() -> bool:
	return cooldown_timer.is_stopped() and closest_target


func _on_range_area_2_area_entered(area: Area2D) -> void:
	# area 是敌人的 HurtboxComponent，需要获取其父节点（敌人）
	if area.get_parent() is Enemy:
		var enemy = area.get_parent() as Enemy
		targets.push_back(enemy)


func _on_range_area_2_area_exited(area: Area2D) -> void:
	# area 是敌人的 HurtboxComponent，需要获取其父节点（敌人）
	if area.get_parent() is Enemy:
		var enemy = area.get_parent() as Enemy
		targets.erase(enemy)
	if targets.size() == 0:
		closest_target = null


func _on_cooldown_timer_timeout() -> void:
	cooldown_timer.stop()
