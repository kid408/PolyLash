extends Unit
class_name Enemy

# ==============================================================================
# 1. 核心属性配置
# ==============================================================================
@export_group("Movement")
@export var flock_push: float = 20.0 # 羊群推力
@export var stop_distance: float = 60.0 # 停止距离

@export_group("Visual & Effects")
@export var death_vfx_scene: PackedScene # 【这里】死亡特效预制体，请在Inspector里赋值！
const DEFAULT_EXPLOSION = preload("uid://dvfjoyutjx5jf") 

# ==============================================================================
# 2. 节点引用
# ==============================================================================
@onready var vision_area: Area2D = $VisionArea
@onready var knockback_timer: Timer = $KnockbackTimer
@onready var collision_shape: CollisionShape2D = $CollisionShape2D

# ==============================================================================
# 3. 逻辑变量
# ==============================================================================
var can_move: bool = true
var is_dead: bool = false
var knockback_dir: Vector2 = Vector2.ZERO
var knockback_power: float = 0.0

# ==============================================================================
# 4. 初始化
# ==============================================================================
func _ready() -> void:
	super._ready() 
	
	if not is_in_group("enemies"):
		add_to_group("enemies")
	
	if death_vfx_scene == null:
		death_vfx_scene = DEFAULT_EXPLOSION
	
	# 连接死亡信号
	health_component.on_unit_died.connect(destroy_enemy)

# ==============================================================================
# 5. 物理处理
# ==============================================================================
func _process(delta: float) -> void:
	if Global.game_paused: return
	if not can_move: return
	if not can_move_towards_player(): return
		
	var move_vec = get_move_direction() + (knockback_dir * knockback_power)
	position += move_vec * stats.speed * delta
	update_rotation()

# ==============================================================================
# 6. 移动逻辑
# ==============================================================================
func update_rotation() -> void:
	if not is_instance_valid(Global.player): return
	var player_pos := Global.player.global_position
	var moving_right := global_position.x < player_pos.x
	visuals.scale = Vector2(-0.5, 0.5) if moving_right else Vector2(0.5, 0.5)

func get_move_direction() -> Vector2:
	if not is_instance_valid(Global.player): return Vector2.ZERO
	var direction := global_position.direction_to(Global.player.position)
	for area: Node2D in vision_area.get_overlapping_areas():
		if area != self and area.is_inside_tree():
			var vector := global_position - area.global_position
			if vector.length() > 0:
				direction += flock_push * vector.normalized() / vector.length()
	return direction

func can_move_towards_player() -> bool:
	return is_instance_valid(Global.player) and \
		   global_position.distance_to(Global.player.global_position) > stop_distance

# ==============================================================================
# 7. 击退系统
# ==============================================================================
func apply_knockback(knock_dir: Vector2, knock_power: float) -> void:
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

# ==============================================================================
# 8. 受击与死亡
# ==============================================================================
func _on_hurtbox_component_on_damaged(hitbox: HitboxComponent) -> void:
	super._on_hurtbox_component_on_damaged(hitbox)
	
	if hitbox.knockback_power > 0:
		var dir := hitbox.source.global_position.direction_to(global_position)
		apply_knockback(dir, hitbox.knockback_power)
	
	if hitbox.source == Global.player: 
		Global.frame_freeze(0.1, 0.1) 
		Global.on_camera_shake.emit(3.0, 0.1)

# 死亡逻辑入口
func destroy_enemy() -> void:
	if is_dead: return
	is_dead = true
	can_move = false
	
	if collision_shape:
		collision_shape.set_deferred("disabled", true)
	
	if Global.player and Global.player.has_method("on_enemy_killed"):
		Global.player.on_enemy_killed(self)
	
	# 【这里】调用死亡特效生成函数
	spawn_explosion_safe()
	Global.on_camera_shake.emit(2.0, 0.1)
	
	# 尸体淡出
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(visuals, "modulate", Color.RED, 0.1)
	tween.tween_property(visuals, "modulate:a", 0.0, 0.3)
	tween.tween_property(visuals, "scale", Vector2.ZERO, 0.3)
	
	tween.chain().tween_callback(queue_free)

# 【这里】是死亡粒子特效的具体实现代码
func spawn_explosion_safe() -> void:
	if not death_vfx_scene:
		print(">>> 警告: death_vfx_scene 未赋值")
		return

	var vfx = death_vfx_scene.instantiate()
	vfx.global_position = global_position
	vfx.z_index = 100 
	
	# 添加到全局场景，确保显示
	get_tree().current_scene.call_deferred("add_child", vfx)
	
	# 绑定自毁
	var vfx_tween = vfx.create_tween()
	vfx_tween.tween_interval(2.0)
	vfx_tween.tween_callback(vfx.queue_free)
