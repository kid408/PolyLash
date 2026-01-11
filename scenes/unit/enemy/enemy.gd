extends Unit
class_name Enemy

# ==============================================================================
# 1. 属性配置
# ==============================================================================
enum EnemyType {
	NORMAL,         # 0
	LINE_BREAKER,   # 1
	SHIELDED,       # 2
	SPIKED,         # 3
	MINE_LAYER      # 4 - 新增：地雷怪，死后留毒池
}

enum AIState {
	CHASE,      # 正常追逐
	PREPARING,  # 预警阶段 (出红线)
	CHARGING,   # 冲锋阶段
	COOLDOWN    # 休息
}

@export var enemy_type: EnemyType = EnemyType.NORMAL

# 敌人ID，用于从CSV加载配置
@export var enemy_id: String = "basic_enemy"

@export_group("Movement")
@export var flock_push: float = 20.0 
@export var stop_distance: float = 60.0 

@export_group("Charge Settings")
@export var can_charge: bool = false       # 是否开启冲锋技能 (建议在Inspector给刺猬/硬壳龟勾选)
@export var charge_prep_time: float = 0.8  # 预警时间 (红线显示时间)
@export var charge_duration: float = 0.6   # 冲锋持续时间
@export var charge_speed_mult: float = 3.5 # 冲锋速度倍率
@export var charge_cooldown: float = 3.0   # 冷却时间

@export_group("Visual & Effects")
@export var death_vfx_scene: PackedScene 
const DEFAULT_EXPLOSION = preload("uid://dvfjoyutjx5jf") 

# ==============================================================================
# 2. 节点引用
# ==============================================================================
@onready var vision_area: Area2D = $VisionArea
@onready var knockback_timer: Timer = $KnockbackTimer
@onready var collision_shape: CollisionShape2D = $CollisionShape2D

# 【新增】预警线节点 (代码动态生成，免去手动添加)
var warning_line: Line2D 
# 【新增】当前攻击目标 (默认为 null，逻辑里会回滚到 Global.player)
var override_target: Node2D = null
# ==============================================================================
# 3. 逻辑变量
# ==============================================================================
var can_move: bool = true
var is_dead: bool = false
var knockback_dir: Vector2 = Vector2.ZERO
var knockback_power: float = 0.0
var break_radius: float = 40.0

# AI 状态
var current_ai_state: AIState = AIState.CHASE
var charge_vector: Vector2 = Vector2.ZERO # 冲锋方向
var ai_timer: float = 0.0 # 通用计时器
var original_modulate: Color 
# ==============================================================================
# 4. 初始化
# ==============================================================================
func _ready() -> void:
	super._ready() 
	if not is_in_group("enemies"):
		add_to_group("enemies")
	if death_vfx_scene == null:
		death_vfx_scene = DEFAULT_EXPLOSION
	health_component.on_unit_died.connect(destroy_enemy)
	
	# 【视觉优化】预警红线
	warning_line = Line2D.new()
	warning_line.width = 30.0 # 【修改】非常宽，像一个长矩形区域
	warning_line.default_color = Color(1, 0.2, 0.2, 0.0) # 初始透明
	warning_line.begin_cap_mode = Line2D.LINE_CAP_ROUND
	warning_line.end_cap_mode = Line2D.LINE_CAP_ROUND
	warning_line.top_level = true # 必须顶级，不随怪物旋转
	add_child(warning_line)
	
	# 应用CSV配置
	_apply_visual_from_config()  # 应用视觉配置（精灵、缩放、碰撞体等）
	_apply_color_from_config()   # 应用颜色配置
	_apply_behavior_from_config() # 应用行为配置
	
	original_modulate = visuals.modulate
	
	# 如果是刺猬，默认开启冲锋
	if enemy_type == EnemyType.SPIKED:
		can_charge = true

# 从CSV配置应用颜色
func _apply_color_from_config() -> void:
	var config = ConfigManager.get_enemy_config(enemy_id)
	if config.is_empty():
		return
	
	# 检查是否配置了颜色（color_r, color_g, color_b）
	if config.has("color_r") and config.has("color_g") and config.has("color_b"):
		var r = config.get("color_r", "")
		var g = config.get("color_g", "")
		var b = config.get("color_b", "")
		
		# 如果颜色值不为空，应用颜色
		if r != null and g != null and b != null:
			#var color = Color(float(r), float(g), float(b), 1)
			var color = Color(float(r), float(g), float(b), 1)
			visuals.modulate = color
			print("[Enemy] 应用颜色配置: ", enemy_id, " -> ", color)

# 从CSV配置应用视觉属性（精灵、缩放、碰撞体等）
func _apply_visual_from_config() -> void:
	var visual_config = ConfigManager.get_enemy_visual(enemy_id)
	if visual_config.is_empty():
		return
	
	print("[Enemy] 应用视觉配置: ", enemy_id)
	
	# 设置精灵
	if visual_config.has("sprite_path"):
		var sprite_path = visual_config.get("sprite_path", "")
		if sprite_path != "" and sprite_path != null:
			var texture = load(sprite_path)
			if texture and visuals.has_node("Sprite2D"):
				visuals.get_node("Sprite2D").texture = texture
				print("[Enemy] 应用精灵: ", sprite_path)
	
	# 设置缩放
	if visual_config.has("scale_x") and visual_config.has("scale_y"):
		var scale_x = visual_config.get("scale_x", 1.0)
		var scale_y = visual_config.get("scale_y", 1.0)
		if scale_x != null and scale_y != null:
			visuals.scale = Vector2(float(scale_x), float(scale_y))
			print("[Enemy] 应用缩放: ", visuals.scale)
	
	# 设置偏移
	if visual_config.has("offset_x") and visual_config.has("offset_y"):
		var offset_x = visual_config.get("offset_x", 0.0)
		var offset_y = visual_config.get("offset_y", 0.0)
		if offset_x != null and offset_y != null and visuals.has_node("Sprite2D"):
			visuals.get_node("Sprite2D").offset = Vector2(float(offset_x), float(offset_y))
	
	# 设置碰撞体半径
	if visual_config.has("collision_radius") and collision_shape:
		var radius = visual_config.get("collision_radius", 20.0)
		if radius != null and collision_shape.shape is CircleShape2D:
			collision_shape.shape.radius = float(radius)
			print("[Enemy] 应用碰撞半径: ", radius)
	
	# 设置受击框大小
	if visual_config.has("hitbox_width") and visual_config.has("hitbox_height"):
		var hitbox_width = visual_config.get("hitbox_width", 40.0)
		var hitbox_height = visual_config.get("hitbox_height", 40.0)
		if hitbox_width != null and hitbox_height != null:
			var hitbox = get_node_or_null("Hitbox")
			if hitbox:
				var hitbox_shape = hitbox.get_node_or_null("CollisionShape2D")
				if hitbox_shape and hitbox_shape.shape is RectangleShape2D:
					hitbox_shape.shape.size = Vector2(float(hitbox_width), float(hitbox_height))
					print("[Enemy] 应用受击框: ", hitbox_shape.shape.size)
	
	# 设置Z层级
	if visual_config.has("z_index"):
		var z = visual_config.get("z_index", 0)
		if z != null:
			z_index = int(z)
	
	# 设置颜色（从visual_config，覆盖enemy_config中的颜色）
	if visual_config.has("color_r") and visual_config.has("color_g") and visual_config.has("color_b"):
		var r = visual_config.get("color_r", 1.0)
		var g = visual_config.get("color_g", 1.0)
		var b = visual_config.get("color_b", 1.0)
		var a = visual_config.get("color_a", 1.0)
		if r != null and g != null and b != null:
			visuals.modulate = Color(float(r), float(g), float(b), float(a) if a != null else 1.0)

# 从CSV配置应用行为参数
func _apply_behavior_from_config() -> void:
	var config = ConfigManager.get_enemy_config(enemy_id)
	if config.is_empty():
		return
	
	# 加载行为参数
	if config.has("flock_push"):
		flock_push = float(config.get("flock_push", 20.0))
	if config.has("stop_distance"):
		stop_distance = float(config.get("stop_distance", 60.0))
	if config.has("charge_prep_time"):
		charge_prep_time = float(config.get("charge_prep_time", 0.8))
	if config.has("charge_duration"):
		charge_duration = float(config.get("charge_duration", 0.6))
	if config.has("charge_speed_mult"):
		charge_speed_mult = float(config.get("charge_speed_mult", 3.5))
	if config.has("charge_cooldown"):
		charge_cooldown = float(config.get("charge_cooldown", 3.0))
	if config.has("break_radius"):
		break_radius = float(config.get("break_radius", 40.0))
	if config.has("can_charge"):
		can_charge = int(config.get("can_charge", 0)) == 1
	
	print("[Enemy] 应用行为配置: ", enemy_id, " can_charge=", can_charge)

# ==============================================================================
# 5. 物理处理 (带状态机)
# ==============================================================================
func _process(delta: float) -> void:
	if Global.game_paused or is_dead: return
	
	# 剪刀手切线
	if enemy_type == EnemyType.LINE_BREAKER:
		_check_line_break()
	
	# 状态机逻辑
	match current_ai_state:
		AIState.CHASE:
			_state_chase(delta)
		AIState.PREPARING:
			_state_preparing(delta)
		AIState.CHARGING:
			_state_charging(delta)
		AIState.COOLDOWN:
			_state_cooldown(delta)

# --- 状态：追逐 (默认) ---
func _state_chase(delta: float) -> void:
	# 1. 检查能不能动
	if not can_move: 
		# print("敌人定身中...") # 太多log可以注释掉
		return
	
	# 2. 检查玩家是否存在
	if not is_instance_valid(Global.player):
		print("敌人待机: 找不到 Global.player")
		return

	# 3. 检查距离
	var dist = global_position.distance_to(Global.player.global_position)
	
	# [DEBUG] 每 60 帧打印一次状态，防止刷屏
	#if Engine.get_frames_drawn() % 60 == 0:
	#	print("[%s] 追逐中 | 距离玩家: %.1f | 停止阈值: %.1f" % [name, dist, stop_distance])

	# 如果距离小于停止距离 (例如贴脸了)，就不移动了
	if dist <= stop_distance:
		return
	
	# 4. 执行移动
	var move_vec = get_move_direction() + (knockback_dir * knockback_power)
	
	# [DEBUG] 检查移动向量
	# if move_vec == Vector2.ZERO and Engine.get_frames_drawn() % 60 == 0:
	# 	print("[%s] 移动向量为零! 可能由于 flock_push 抵消?" % name)
		
	position += move_vec * stats.speed * delta
	update_rotation()
	
	# 5. 冲锋判定
	if can_charge:
		if dist < 300.0 and dist > 100.0: 
			start_charge_sequence()

# --- 1. 触发冲锋序列 (生成红线) ---
func start_charge_sequence() -> void:
	current_ai_state = AIState.PREPARING
	ai_timer = charge_prep_time
	
	# 锁定冲锋方向 (归一化！)
	charge_vector = global_position.direction_to(Global.player.global_position).normalized()
	
	# 敌人变色提示
	var tween = create_tween()
	tween.tween_property(visuals, "modulate", Color(3.0, 0.5, 0.5, 1.0), 0.2) 
	
	# 绘制预警区域 (固定长度，例如 500px)
	var end_pos = global_position + (charge_vector * 500.0)
	
	warning_line.clear_points()
	warning_line.add_point(global_position)
	warning_line.add_point(end_pos)
	
	# 红线动画：半透明淡入 -> 变细一点点
	warning_line.default_color = Color(1, 0, 0, 0)
	warning_line.width = 40.0
	
	var line_tween = create_tween()
	# 0.2秒淡入到半透明 (0.3 alpha)
	line_tween.tween_property(warning_line, "default_color", Color(1, 0, 0, 0.3), 0.2)
	# 同时宽度稍微收缩，增加聚焦感
	line_tween.parallel().tween_property(warning_line, "width", 20.0, charge_prep_time)

# --- 2. 预警阶段 (停在原地，颤抖) ---
func _state_preparing(delta: float) -> void:
	ai_timer -= delta
	
	# 视觉震动
	visuals.position = Vector2(randf_range(-2, 2), randf_range(-2, 2))
	
	# 更新红线起点 (跟随怪物)，终点固定 (不追踪玩家了，这就是给玩家躲避的机会)
	if warning_line.points.size() > 1:
		warning_line.set_point_position(0, global_position)
	
	if ai_timer <= 0:
		enter_charge_state()

# --- 3. 进入冲锋 (动作切换) ---
func enter_charge_state() -> void:
	current_ai_state = AIState.CHARGING
	ai_timer = charge_duration
	
	# 恢复视觉
	visuals.position = Vector2.ZERO
	visuals.modulate = original_modulate
	
	# 隐藏红线
	warning_line.default_color = Color(1, 0, 0, 0)
	warning_line.clear_points()
	
	# 播放冲锋音效
	# Global.play_sfx(...)
	
# --- 4. 冲锋阶段 (沿直线位移) ---
func _state_charging(delta: float) -> void:
	ai_timer -= delta
	
	# 【核心修复】只沿着锁定的 charge_vector 移动，不进行任何寻路计算
	# 不使用 move_and_slide，直接修改 position，避免物理碰撞导致的奇怪滑步（如果是Area2D类型的单位）
	# 如果是 CharacterBody2D，请用 velocity = ... move_and_slide()
	
	position += charge_vector * stats.speed * charge_speed_mult * delta
	
	# 这里不更新朝向，保持冲锋时的霸体感
	
	if ai_timer <= 0:
		current_ai_state = AIState.COOLDOWN
		ai_timer = charge_cooldown

# --- 5. 冷却阶段 ---
func _state_cooldown(delta: float) -> void:
	ai_timer -= delta
	
	# 缓慢移动
	var move_vec = get_move_direction() * 0.2
	position += move_vec * stats.speed * delta
	update_rotation()
	
	if ai_timer <= 0:
		current_ai_state = AIState.CHASE

# ==============================================================================
# 原有辅助函数
# ==============================================================================
func _check_line_break() -> void:
	if Global.player:
		# 【修复】先检查玩家是否有这个功能，再调用
		# 这样以后做其他没有线的角色，也不会报错
		if Global.player.has_method("try_break_line"):
			Global.player.try_break_line(global_position, break_radius)

func update_rotation() -> void:
	if not is_instance_valid(Global.player): return
	var player_pos := Global.player.global_position
	var moving_right := global_position.x < player_pos.x
	visuals.scale = Vector2(-0.5, 0.5) if moving_right else Vector2(0.5, 0.5)

func get_move_direction() -> Vector2:
	# 1. 确定目标：如果有嘲讽目标且存活，就追嘲讽目标；否则追玩家
	var target_node = Global.player
	if is_instance_valid(override_target):
		target_node = override_target
	
	if not is_instance_valid(target_node): return Vector2.ZERO
	
	# 2. 计算方向
	var direction := global_position.direction_to(target_node.global_position)
	
	# 3. 群聚逻辑 (保持不变)
	for area: Node2D in vision_area.get_overlapping_areas():
		if area != self and area.is_inside_tree():
			var vector := global_position - area.global_position
			if vector.length() > 0:
				direction += flock_push * vector.normalized() / vector.length()
	return direction

func can_move_towards_player() -> bool:
	var target_node = Global.player
	if is_instance_valid(override_target):
		target_node = override_target
		
	# 【修复】将 stop_distance_distance 改为 stop_distance
	return is_instance_valid(target_node) and \
		   global_position.distance_to(target_node.global_position) > stop_distance

# 【新增】设置强制目标 (嘲讽接口)
func set_taunt_target(target: Node2D) -> void:
	override_target = target
	# 视觉反馈：变个颜色表示被嘲讽了
	var tween = create_tween()
	tween.tween_property(visuals, "modulate", Color.MAGENTA, 0.2)
	tween.tween_property(visuals, "modulate", Color.WHITE, 0.2)
	
# ==============================================================================
# 击退与受击 (保持之前的修复)
# ==============================================================================
func apply_knockback(knock_dir: Vector2, knock_power: float) -> void:
	# 冲锋期间免疫击退 (霸体)
	if current_ai_state == AIState.CHARGING: return
	
	knockback_dir = knock_dir
	knockback_power = knock_power
	if knockback_timer.time_left > 0:
		knockback_timer.stop()
		reset_knockback()
	knockback_timer.start()

func reset_knockback() -> void:
	knockback_dir = Vector2.ZERO
	knockback_power = 0.0

func _on_knockback_timer_timeout() -> void:
	reset_knockback()

func _on_hurtbox_component_on_damaged(hitbox: HitboxComponent) -> void:
	if is_dead: return

	# 1. 硬壳龟反伤逻辑 (修改为减伤而不是完全格挡)
	if enemy_type == EnemyType.SHIELDED and hitbox.source == Global.player:
		Global.spawn_floating_text(global_position, "SHIELD!", Color.CYAN)
		
		# 减少伤害到 30%
		hitbox.damage *= 0.3
		
		# 轻微反伤玩家
		if Global.player.has_method("take_damage"):
			Global.player.take_damage(1) 
		
		# 不再 return，继续执行正常伤害逻辑

	# 2. 正常伤害
	super._on_hurtbox_component_on_damaged(hitbox)
	
	if hitbox.knockback_power > 0:
		# 安全检查：确保 source 仍然有效
		if hitbox.source and is_instance_valid(hitbox.source):
			var dir := hitbox.source.global_position.direction_to(global_position)
			apply_knockback(dir, hitbox.knockback_power)
	
	# 增强打击感：敌人受击时的反馈
	# 安全检查：确保 source 和 Global.player 仍然有效
	if hitbox.source and is_instance_valid(hitbox.source) and hitbox.source == Global.player: 
		# 根据伤害大小调整顿帧强度
		var freeze_duration = clamp(hitbox.damage / 100.0, 0.02, 0.08)
		Global.frame_freeze(freeze_duration, 0.2) 
		Global.on_camera_shake.emit(2.0 + hitbox.damage / 20.0, 0.08)

func destroy_enemy() -> void:
	if is_dead: return
	is_dead = true
	can_move = false
	
	print("[Enemy] 敌人死亡: ", name, " 类型: ", enemy_type)
	
	# 死亡时清理红线
	if warning_line:
		warning_line.queue_free()
	
	if collision_shape:
		collision_shape.set_deferred("disabled", true)
	
	# 地雷怪特殊效果：死后留毒池
	if enemy_type == EnemyType.MINE_LAYER:
		print("[Enemy] 地雷怪死亡，准备生成毒池")
		call_deferred("_spawn_poison_pool", global_position)
	
	# 给玩家能量奖励
	if is_instance_valid(Global.player) and Global.player.has_method("gain_energy"):
		var enemy_config = ConfigManager.get_enemy_config(enemy_id)
		var energy_drop = enemy_config.get("energy_drop", 5)
		Global.player.gain_energy(energy_drop)
	
	if Global.player and Global.player.has_method("on_enemy_killed"):
		Global.player.on_enemy_killed(self)
	
	Global.play_enemy_death()
	spawn_explosion_safe()
	# 增强打击感：敌人死亡时的反馈
	Global.frame_freeze(0.04, 0.3)
	Global.on_camera_shake.emit(3.0, 0.12)
	
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(visuals, "modulate", Color.RED, 0.1)
	tween.tween_property(visuals, "modulate:a", 0.0, 0.3)
	tween.tween_property(visuals, "scale", Vector2.ZERO, 0.3)
	
	tween.chain().tween_callback(queue_free)

func spawn_explosion_safe() -> void:
	if not death_vfx_scene: return
	var vfx = death_vfx_scene.instantiate()
	vfx.global_position = global_position
	vfx.z_index = 100 
	get_tree().current_scene.call_deferred("add_child", vfx)
	var vfx_tween = vfx.create_tween()
	vfx_tween.tween_interval(2.0)
	vfx_tween.tween_callback(vfx.queue_free)

# 地雷怪死后生成毒池
func _spawn_poison_pool(pos: Vector2) -> void:
	print("[MineLayer] === 开始生成毒池 ===")
	print("[MineLayer] 生成毒池于位置: ", pos)
	
	var poison = Area2D.new()
	poison.global_position = pos
	poison.collision_layer = 0
	poison.collision_mask = 1
	poison.monitorable = false
	poison.monitoring = true
	poison.name = "PoisonPool_" + str(Time.get_ticks_msec())
	
	# 碰撞体
	var col = CollisionShape2D.new()
	var shape = CircleShape2D.new()
	shape.radius = 60.0
	col.shape = shape
	poison.add_child(col)
	print("[MineLayer] 碰撞体已添加，半径: 60")
	
	# 视觉效果：完整的圆形毒池
	var vis = Polygon2D.new()
	var points = PackedVector2Array()
	for i in range(32):  # 增加点数，确保是完整的圆
		var angle = i * TAU / 32
		points.append(Vector2(cos(angle), sin(angle)) * 60.0)
	vis.polygon = points
	vis.color = Color(0.2, 1.0, 0.2, 0.0)  # 初始透明
	vis.z_index = -1
	poison.add_child(vis)
	print("[MineLayer] 视觉效果已添加，点数: ", points.size())
	
	# 先添加到场景树，这样Timer才能正常工作
	get_tree().current_scene.add_child(poison)
	print("[MineLayer] 毒池已添加到场景，节点路径: ", poison.get_path())
	
	# 淡入效果
	var tween = poison.create_tween()
	tween.tween_property(vis, "color:a", 0.5, 0.3)
	print("[MineLayer] 淡入动画已启动")
	
	# 伤害计时器：每0.5秒伤害一次
	var dmg_timer = Timer.new()
	dmg_timer.name = "DamageTimer"
	dmg_timer.wait_time = 0.5
	dmg_timer.one_shot = false
	poison.add_child(dmg_timer)
	
	# 使用lambda函数，避免依赖Enemy实例
	# 使用Area2D的碰撞检测而不是距离检测
	dmg_timer.timeout.connect(func():
		if not is_instance_valid(poison) or poison.is_queued_for_deletion():
			dmg_timer.stop()
			return
		
		# 检测所有在毒池范围内的玩家（使用Area2D碰撞检测）
		var bodies = poison.get_overlapping_bodies()
		var areas = poison.get_overlapping_areas()
		var all_targets = bodies + areas
		
		for target in all_targets:
			var player_node = null
			
			# 检查是否是玩家或玩家的子节点
			if target.is_in_group("player"):
				player_node = target
			elif target.owner and target.owner.is_in_group("player"):
				player_node = target.owner
			
			# 对玩家造成伤害
			if is_instance_valid(player_node) and player_node.has_method("take_damage"):
				player_node.take_damage(5)
				Global.spawn_floating_text(player_node.global_position, "-5", Color(0.5, 1.0, 0.5))
	)
	
	dmg_timer.start()
	print("[MineLayer] 伤害计时器已启动，使用Area2D碰撞检测")
	
	# 生命计时器：8秒后消失
	var life_timer = Timer.new()
	life_timer.name = "LifeTimer"
	life_timer.wait_time = 8.0
	life_timer.one_shot = true
	poison.add_child(life_timer)
	
	# 使用lambda函数，避免依赖Enemy实例
	life_timer.timeout.connect(func():
		if is_instance_valid(poison):
			if is_instance_valid(vis):
				var fade_tween = poison.create_tween()
				fade_tween.tween_property(vis, "color:a", 0.0, 0.5)
				fade_tween.finished.connect(func():
					if is_instance_valid(poison):
						poison.queue_free()
				)
			else:
				poison.queue_free()
	)
	
	life_timer.start()
	print("[MineLayer] 生命计时器已启动，8秒后毒池将消失")
	
	Global.spawn_floating_text(pos, "TOXIC!", Color(0.5, 1.0, 0.5))
	print("[MineLayer] === 毒池生成完成 ===")
