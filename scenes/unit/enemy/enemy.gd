extends Unit
class_name Enemy

# ==============================================================================
# 1. 属性配置
# ==============================================================================
enum EnemyType {
	NORMAL,         # 0
	LINE_BREAKER,   # 1
	SHIELDED,       # 2
	SPIKED          # 3
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
	
	original_modulate = visuals.modulate
	
	# 如果是刺猬，默认开启冲锋
	if enemy_type == EnemyType.SPIKED:
		can_charge = true

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

	# 1. 硬壳龟反伤逻辑 (修复版)
	if enemy_type == EnemyType.SHIELDED and hitbox.source == Global.player:
		Global.spawn_floating_text(global_position, "BLOCK!", Color.CYAN)
		
		# 调用刚才在 Player 中修复的函数
		if Global.player.has_method("take_damage"):
			Global.player.take_damage(1) 
		
		if Global.player.has_method("apply_knockback_self"):
			var dir = global_position.direction_to(Global.player.global_position)
			Global.player.apply_knockback_self(dir * 300.0) # 减小反弹力度，从800.0改为300.0
			
		Global.on_camera_shake.emit(5.0, 0.2)
		return 

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
