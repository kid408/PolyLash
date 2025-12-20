extends Unit
class_name Enemy

# 羊群效应，彼此保持距離
@export var flock_push := 20.0
# 视觉区域
@onready var vision_area: Area2D = $VisionArea
@onready var knockback_timer: Timer = $KnockbackTimer
@export var death_vfx_scene: PackedScene
const EXPLOSION = preload("uid://dvfjoyutjx5jf")

var can_move := true
var is_dead: bool = false

var knockback_dir:Vector2
var knockback_power:float

func _ready() -> void:
	super._ready()
	if not is_in_group("enemies"):
		add_to_group("enemies")
	if death_vfx_scene == null:
		death_vfx_scene = EXPLOSION
	# 【新增】连接死亡信号
	# 这样无论是撞击还是绞杀，只要血量归零，都会触发 destroy_enemy
	health_component.on_unit_died.connect(destroy_enemy)
		
func _process(delta: float) -> void:
	if Global.game_paused: return
	
	if not can_move:
		return
		
	if not can_move_towards_player():
		return
		
	position += (get_move_direction()+knockback_dir*knockback_power) * stats.speed * delta
	update_rotation()

# 更新朝向
func update_rotation() -> void:
	if not is_instance_valid(Global.player):
		return
	var player_pos := Global.player.global_position
	var moving_right := global_position.x < player_pos.x
	# -0.5 和 0.5 控制翻转朝向
	visuals.scale = Vector2(-0.5,0.5) if moving_right else Vector2(0.5,0.5)

# 移动方向
func get_move_direction() -> Vector2:
	if not is_instance_valid(Global.player):
		return Vector2.ZERO
	
	# 获得玩家方向
	var direction := global_position.direction_to(Global.player.position)
	# 可视区域内相同类型的单元羊群效应
	for area: Node2D in vision_area.get_overlapping_areas():
		if area != self and area.is_inside_tree():
			var vector := global_position - area.global_position
			direction += flock_push * vector.normalized()/vector.length()
			
	return direction
			

# 是否可以移动到玩家，距离60个像素，防止和玩家重叠
func can_move_towards_player() -> bool:
	return is_instance_valid(Global.player) and\
	global_position.distance_to(Global.player.global_position) > 60

func apply_knockback(knock_dir :Vector2,knock_power:float) -> void:
	knockback_dir = knock_dir
	knockback_power = knock_power
	if knockback_timer.time_left >0:
		knockback_timer.stop()
		reset_knockback()
		
	knockback_timer.start()

func reset_knockback() -> void:
	knockback_dir = Vector2.ZERO
	knockback_power = 0.0

func destroy_enemy() -> void:
	# 1. 【绝对防御】如果已经死过一次了，立刻停止，防止逻辑重复执行
	if is_dead: 
		return
	
	# 标记为已死
	is_dead = true
	# 停止移动
	can_move = false
	
	# 2. 物理层清理 (立刻执行)
	# 禁用碰撞，防止尸体挡住玩家
	$CollisionShape2D.set_deferred("disabled", true)
	# 如果有 hurtbox，也要禁用，防止鞭尸
	# $HurtboxComponent.set_deferred("monitorable", false)
	# $HurtboxComponent.set_deferred("monitoring", false)
	
	# 3. 游戏逻辑层清理
	if Global.player:
		Global.player.on_enemy_killed(self)
	
	# 4. 视觉层反馈
	spawn_explosion()
	Global.on_camera_shake.emit(2.0, 0.1)
	
	print(">>> 敌人开始死亡流程: ", name)

	# 5. 【关键修复】使用 Tween 并在回调中销毁
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(visuals, "modulate", Color.RED, 0.1)
	tween.tween_property(visuals, "modulate:a", 0.0, 0.3) # 变透明
	tween.tween_property(visuals, "scale", Vector2.ZERO, 0.3) # 缩小
	
	# 【核心修改】不要用 await tween.finished
	# 直接把 queue_free 绑在 tween 的结束回调上
	# 这样只要 tween 跑完，它必死无疑
	tween.chain().tween_callback(func():
		print(">>> Tween结束，销毁对象: ", name)
		queue_free()
	)
	
	# 6. 【双重保险 / 强制垃圾回收】
	# 万一（我是说万一）Tween 还没跑完，节点就被挪出树了或者卡住了，
	# 我们创建一个与场景树绑定的计时器，1秒后不管三七二十一，强制销毁它。
	# 这能彻底解决内存泄露问题。
	get_tree().create_timer(1.0).timeout.connect(func():
		if is_instance_valid(self):
			print(">>> 触发强制回收保险: ", name)
			queue_free()
	)

# 把特效逻辑拆出来，保持整洁
func spawn_explosion() -> void:
	if death_vfx_scene:
		var vfx = death_vfx_scene.instantiate()
		vfx.global_position = global_position
		
		# 【关键修复】强制把特效放到最上层
		# Z-Index 决定了渲染顺序。普通单位通常是 0。
		# 设为 100 保证它盖在尸体、地板、墙壁上面
		vfx.z_index = 100 
		
		# 加到当前场景根节点，而不是加到敌人身上
		# 这样敌人 queue_free 后，特效还在
		get_tree().current_scene.add_child(vfx) 
	else:
		print("警告: death_vfx_scene 未赋值!")
		
func _on_knockback_timer_timeout() -> void:
	reset_knockback()

func _on_hurtbox_component_on_damaged(hitbox: HitboxComponent) -> void:
	# 1. 父类处理扣血 (这会减少 health_component.current_health)
	super._on_hurtbox_component_on_damaged(hitbox)
	
	# 2. 击退逻辑
	if hitbox.knockback_power > 0:
		var dir := hitbox.source.global_position.direction_to(global_position)
		apply_knockback(dir, hitbox.knockback_power)
	
	# 3. 顿帧逻辑 (保持不变)
	if hitbox.source is Player:
		Global.frame_freeze(0.1, 0.1) 
		Global.on_camera_shake.emit(3.0, 0.1)
