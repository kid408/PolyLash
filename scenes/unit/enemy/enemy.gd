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
# 特殊能力参数
# ==============================================================================

@export_group("Shooting Behavior (Shielded)")
@export var shoot_cooldown: float = 3.0
@export var projectile_count: int = 3
@export var projectile_arc_angle: float = 45.0
@export var projectile_speed: float = 1800.0

@export_group("Poison Pool (MineLayer)")
@export var pool_radius: float = 60.0
@export var pool_damage: float = 5.0
@export var pool_damage_interval: float = 0.5
@export var pool_lifetime: float = 8.0 

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
	
	# 停止动画播放，避免出生时的"发大再缩小"特效
	if anim_player:
		anim_player.stop()
	
	# 【视觉优化】预警红线
	warning_line = Line2D.new()
	warning_line.width = 30.0 # 【修改】非常宽，像一个长矩形区域
	warning_line.default_color = Color(1, 0.2, 0.2, 0.0) # 初始透明
	warning_line.begin_cap_mode = Line2D.LINE_CAP_ROUND
	warning_line.end_cap_mode = Line2D.LINE_CAP_ROUND
	warning_line.top_level = true # 必须顶级，不随怪物旋转
	add_child(warning_line)
	
	# 根据 enemy_id 设置敌人类型
	_set_enemy_type_from_id()
	
	# 应用CSV配置
	_apply_visual_from_config()  # 应用视觉配置（精灵、缩放、碰撞体等）
	_apply_color_from_config()   # 应用颜色配置
	_apply_behavior_from_config() # 应用行为配置
	
	original_modulate = visuals.modulate
	
	# 动态生成特殊节点
	_setup_special_nodes()
	
	# 如果是刺猬，默认开启冲锋
	if enemy_type == EnemyType.SPIKED:
		can_charge = true

# 根据 enemy_id 设置敌人类型
func _set_enemy_type_from_id() -> void:
	match enemy_id:
		"breaker_enemy":
			enemy_type = EnemyType.LINE_BREAKER
		"shielded_enemy":
			enemy_type = EnemyType.SHIELDED
		"spiked_enemy":
			enemy_type = EnemyType.SPIKED
		"mine_layer_enemy":
			enemy_type = EnemyType.MINE_LAYER
		_:
			enemy_type = EnemyType.NORMAL

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
			# print("[Enemy] 应用颜色配置: ", enemy_id, " -> ", color)

# 从CSV配置应用视觉属性（精灵、缩放、碰撞体等）
func _apply_visual_from_config() -> void:
	var visual_config = ConfigManager.get_enemy_visual(enemy_id)
	if visual_config.is_empty():
		#print("[Enemy] 警告: 找不到视觉配置 ", enemy_id)
		return
	
	#print("[Enemy] 应用视觉配置: ", enemy_id)
	
	# 设置精灵
	if visual_config.has("sprite_path"):
		var sprite_path = visual_config.get("sprite_path", "")
		if sprite_path != "" and sprite_path != null:
			var texture = load(sprite_path)
			if texture:
				# 尝试找到精灵节点（支持 Sprite 和 Sprite2D）
				var sprite_node = null
				if visuals.has_node("Sprite"):
					sprite_node = visuals.get_node("Sprite")
				elif visuals.has_node("Sprite2D"):
					sprite_node = visuals.get_node("Sprite2D")
				
				if sprite_node:
					sprite_node.texture = texture
					#print("[Enemy] 应用精灵: ", enemy_id, " -> ", sprite_path)
			#else:
				#print("[Enemy] 警告: 无法加载精灵 ", sprite_path)
	
	# 设置缩放（乘以基础缩放0.5，而不是覆盖）
	if visual_config.has("scale_x") and visual_config.has("scale_y"):
		var scale_x = visual_config.get("scale_x", 1.0)
		var scale_y = visual_config.get("scale_y", 1.0)
		if scale_x != null and scale_y != null:
			# 保持基础缩放0.5，乘以配置中的缩放值
			var base_scale = 0.5
			visuals.scale = Vector2(float(scale_x) * base_scale, float(scale_y) * base_scale)
			# print("[Enemy] 应用缩放: ", visuals.scale)
	
	# 设置偏移
	if visual_config.has("offset_x") and visual_config.has("offset_y"):
		var offset_x = visual_config.get("offset_x", 0.0)
		var offset_y = visual_config.get("offset_y", 0.0)
		if offset_x != null and offset_y != null:
			# 尝试找到精灵节点（支持 Sprite 和 Sprite2D）
			var sprite_node = null
			if visuals.has_node("Sprite"):
				sprite_node = visuals.get_node("Sprite")
			elif visuals.has_node("Sprite2D"):
				sprite_node = visuals.get_node("Sprite2D")
			
			if sprite_node:
				sprite_node.offset = Vector2(float(offset_x), float(offset_y))
	
	# 设置碰撞体半径
	if visual_config.has("collision_radius") and collision_shape:
		var radius = visual_config.get("collision_radius", 20.0)
		if radius != null and collision_shape.shape is CircleShape2D:
			collision_shape.shape.radius = float(radius)
			# print("[Enemy] 应用碰撞半径: ", radius)
	
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
					# print("[Enemy] 应用受击框: ", hitbox_shape.shape.size)
	
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
	
	# 加载基础行为参数
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
	
	# 加载特殊能力参数
	# ShootingBehavior 参数
	if config.has("shoot_cooldown"):
		shoot_cooldown = float(config.get("shoot_cooldown", 3.0))
	if config.has("projectile_count"):
		projectile_count = int(config.get("projectile_count", 3))
	if config.has("projectile_arc_angle"):
		projectile_arc_angle = float(config.get("projectile_arc_angle", 45.0))
	if config.has("projectile_speed"):
		projectile_speed = float(config.get("projectile_speed", 1800.0))
	
	# MineLayer 参数
	if config.has("pool_radius"):
		pool_radius = float(config.get("pool_radius", 60.0))
	if config.has("pool_damage"):
		pool_damage = float(config.get("pool_damage", 5.0))
	if config.has("pool_damage_interval"):
		pool_damage_interval = float(config.get("pool_damage_interval", 0.5))
	if config.has("pool_lifetime"):
		pool_lifetime = float(config.get("pool_lifetime", 8.0))
	
	#print("[Enemy] 应用行为配置: ", enemy_id)

# 动态生成特殊节点（根据敌人类型）
func _setup_special_nodes() -> void:
	match enemy_type:
		EnemyType.SHIELDED:
			_setup_shooting_behavior()
		EnemyType.SPIKED:
			_setup_charge_animation()
		EnemyType.MINE_LAYER:
			pass  # 毒池将在死亡时生成
		_:
			pass

# 为硬壳龟生成射击行为节点
func _setup_shooting_behavior() -> void:
	# 检查是否已存在
	if has_node("ShootingBehavior"):
		return
	
	# 创建 FirePos 标记
	var fire_pos = Marker2D.new()
	fire_pos.name = "FirePos"
	fire_pos.position = Vector2(0, -50)
	visuals.add_child(fire_pos)
	
	# 创建 ShootingBehavior 节点
	var shooting_behavior = Node2D.new()
	shooting_behavior.name = "ShootingBehavior"
	
	# 加载脚本
	var script = load("res://scenes/unit/enemy/shooting_behavior.gd")
	if script == null:
		push_error("[Enemy] 错误: 无法加载 shooting_behavior.gd 脚本")
		return
	
	shooting_behavior.set_script(script)
	
	# 设置属性（必须在脚本绑定后）
	shooting_behavior.enemy = self
	shooting_behavior.fire_pos = fire_pos
	shooting_behavior.projectile_scene = load("res://scenes/projectiles/projectile_enemy.tscn")
	
	# 应用配置参数
	shooting_behavior.cooldown = shoot_cooldown
	shooting_behavior.projectile_count = projectile_count
	shooting_behavior.arc_angle = projectile_arc_angle
	shooting_behavior.projectile_speed = projectile_speed
	
	# 添加到场景树
	add_child(shooting_behavior)
	
	# 手动调用 _ready()，因为脚本是动态绑定的
	if shooting_behavior.has_method("_ready"):
		shooting_behavior._ready()
	else:
		push_error("[Enemy] 错误: ShootingBehavior 没有 _ready() 方法")
	
	# 确保 _process 会被调用
	shooting_behavior.set_process(true)

# 为刺猬生成冲锋动画
func _setup_charge_animation() -> void:
	# 检查是否已存在
	if has_node("AnimationEffects"):
		return
	
	# 创建 AnimationPlayer
	var anim_player = AnimationPlayer.new()
	anim_player.name = "AnimationEffects"
	add_child(anim_player)
	
	# 创建动画库
	var anim_lib = AnimationLibrary.new()
	
	# 创建 RESET 动画
	var reset_anim = Animation.new()
	reset_anim.length = 0.001
	var track_idx = reset_anim.add_track(Animation.TYPE_VALUE)
	reset_anim.track_set_path(track_idx, "Visuals/Sprite:modulate")
	reset_anim.track_insert_key(track_idx, 0, Color(1, 1, 1, 1))
	anim_lib.add_animation(&"RESET", reset_anim)
	
	# 创建 charge 动画（闪烁红色）
	var charge_anim = Animation.new()
	charge_anim.length = 0.5
	track_idx = charge_anim.add_track(Animation.TYPE_VALUE)
	charge_anim.track_set_path(track_idx, "Visuals/Sprite:modulate")
	charge_anim.track_set_interpolation_type(track_idx, Animation.INTERPOLATION_LINEAR)
	
	var times = PackedFloat32Array([0, 0.1, 0.2, 0.3, 0.4])
	var colors = [
		Color(1, 1, 1, 1),
		Color(0.9529412, 0, 0.36862746, 1),
		Color(1, 1, 1, 1),
		Color(0.9529412, 0, 0.36862746, 1),
		Color(1, 1, 1, 1)
	]
	
	for i in range(times.size()):
		charge_anim.track_insert_key(track_idx, times[i], colors[i])
	
	anim_lib.add_animation(&"charge", charge_anim)
	
	# 设置动画库
	anim_player.add_animation_library("", anim_lib)

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
		return
	
	# 2. 检查玩家是否存在
	if not is_instance_valid(Global.player):
		return

	# 3. 检查距离
	var dist = global_position.distance_to(Global.player.global_position)

	# 如果距离小于停止距离 (例如贴脸了)，就不移动了
	if dist <= stop_distance:
		return
	
	# 4. 执行移动
	var move_vec = get_move_direction() + (knockback_dir * knockback_power)
		
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
	
	# 播放冲锋动画（如果是刺猬）
	if enemy_type == EnemyType.SPIKED and has_node("AnimationEffects"):
		var anim_player = get_node("AnimationEffects") as AnimationPlayer
		if anim_player:
			anim_player.play("charge")
	
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
	if not is_instance_valid(Global.player):
		return
	
	# 检查玩家是否有这个功能，再调用
	if Global.player.has_method("try_break_line"):
		Global.player.try_break_line(global_position, break_radius)

func update_rotation() -> void:
	if not is_instance_valid(Global.player): return
	var player_pos := Global.player.global_position
	var moving_right := global_position.x < player_pos.x
	# 只改变 X 轴的缩放（用于翻转精灵），保持 Y 轴的缩放不变
	# 保持 X 轴缩放的绝对值与 Y 轴相同，只改变符号
	var scale_magnitude = abs(visuals.scale.y)
	visuals.scale.x = -scale_magnitude if moving_right else scale_magnitude

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
	
	# 死亡时清理红线
	if warning_line:
		warning_line.queue_free()
	
	if collision_shape:
		collision_shape.set_deferred("disabled", true)
	
	# 地雷怪特殊效果：死后留毒池
	if enemy_type == EnemyType.MINE_LAYER:
		call_deferred("_spawn_poison_pool", global_position)
	
	# 给玩家奖励（能量、经验、金币）
	if is_instance_valid(Global.player):
		var enemy_config = ConfigManager.get_enemy_config(enemy_id)
		
		# 能量奖励
		if Global.player.has_method("gain_energy"):
			var energy_drop = enemy_config.get("energy_drop", 5)
			Global.player.gain_energy(energy_drop)
		
		# 经验奖励
		if Global.player.has_method("add_xp"):
			var xp_value = int(enemy_config.get("xp_value", 10))
			Global.player.add_xp(xp_value)
		
		# 金币奖励
		if Global.player.has_method("add_gold"):
			var gold_value = int(enemy_config.get("gold_value", 5))
			Global.player.add_gold(gold_value)
	
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
	# 安全检查：确保场景树可用
	var tree = Engine.get_main_loop() as SceneTree
	if tree == null or tree.current_scene == null:
		push_error("[MineLayer] 错误: 无法获取场景树!")
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
	
	# 视觉效果：完整的圆形毒池
	var vis = Polygon2D.new()
	vis.name = "PoisonVisual"
	var points = PackedVector2Array()
	var segments = 32
	
	# 生成圆形多边形点
	for i in range(segments):
		var angle = float(i) * TAU / float(segments)
		var point = Vector2(cos(angle), sin(angle)) * pool_radius
		points.append(point)
	
	# 设置多边形
	vis.polygon = points
	vis.color = Color(0.2, 1.0, 0.2, 0.5)
	vis.z_index = -1
	poison.add_child(vis)
	
	# 先添加到场景树
	tree.current_scene.add_child(poison)
	
	# 设置位置（在添加到场景后设置）
	poison.global_position = pos
	
	# 伤害计时器：按配置间隔伤害一次
	var dmg_timer = Timer.new()
	dmg_timer.name = "DamageTimer"
	dmg_timer.wait_time = pool_damage_interval
	dmg_timer.one_shot = false
	poison.add_child(dmg_timer)
	
	# 使用lambda函数，避免依赖Enemy实例
	dmg_timer.timeout.connect(func():
		if not is_instance_valid(poison) or poison.is_queued_for_deletion():
			dmg_timer.stop()
			return
		
		# 检测所有在毒池范围内的玩家
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
				player_node.take_damage(int(pool_damage))
				Global.spawn_floating_text(player_node.global_position, "-" + str(int(pool_damage)), Color(0.5, 1.0, 0.5))
	)
	
	dmg_timer.start()
	
	# 生命计时器：按配置时间后消失
	var life_timer = Timer.new()
	life_timer.name = "LifeTimer"
	life_timer.wait_time = pool_lifetime
	life_timer.one_shot = true
	poison.add_child(life_timer)
	
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
	
	Global.spawn_floating_text(pos, "TOXIC!", Color(0.5, 1.0, 0.5))
