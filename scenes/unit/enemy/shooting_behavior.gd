extends Node2D
class_name ShootingBehavior

@export var enemy: Enemy
@export var fire_pos : Marker2D
@export var cooldown : = 3.0
@export var projectile_count :=3
@export var arc_angle:=45.0
@export var projectile_scene:PackedScene
@export var projectile_speed:= 1800.0

var current_cooldown := 0.0
var frame_count := 0

func _ready() -> void:
	current_cooldown = cooldown
	print("[ShootingBehavior] _ready() 调用")
	print("[ShootingBehavior] enemy = ", enemy)
	print("[ShootingBehavior] fire_pos = ", fire_pos)
	print("[ShootingBehavior] cooldown = ", cooldown)
	print("[ShootingBehavior] projectile_count = ", projectile_count)
	print("[ShootingBehavior] 节点名称: ", name)
	print("[ShootingBehavior] 节点父节点: ", get_parent().name if get_parent() else "无")
	print("[ShootingBehavior] 节点在场景树中: ", is_inside_tree())
	
	if enemy == null:
		print("[ShootingBehavior] 错误: enemy 为 null!")
	if fire_pos == null:
		print("[ShootingBehavior] 错误: fire_pos 为 null!")
	
	# 确保节点能够处理 _process
	process_mode = PROCESS_MODE_INHERIT
	print("[ShootingBehavior] process_mode 已设置为 INHERIT")
	
func _process(delta: float) -> void:
	frame_count += 1
	
	# 每帧都打印一次，看看是否被调用
	if frame_count <= 5 or frame_count % 30 == 0:
		print("[ShootingBehavior] _process 被调用! frame=", frame_count, " cooldown=", current_cooldown)
	
	if Global.game_paused: 
		return
	
	if enemy == null:
		if frame_count <= 3:
			print("[ShootingBehavior] 错误: enemy 为 null，无法射击")
		return
	
	if current_cooldown > 0:
		current_cooldown -= delta
	else:
		print("[ShootingBehavior] ★★★ 冷却完成，准备射击 ★★★")
		shoot()
		current_cooldown = cooldown

func shoot() -> void:
	print("[ShootingBehavior] shoot() 被调用")
	if not is_instance_valid(Global.player):
		print("[ShootingBehavior] 错误: Global.player 无效")
		return
	
	if not is_instance_valid(enemy):
		print("[ShootingBehavior] 错误: enemy 无效")
		return
	
	if projectile_scene == null:
		print("[ShootingBehavior] 错误: projectile_scene 为 null")
		return
	
	if fire_pos == null:
		print("[ShootingBehavior] 错误: fire_pos 为 null")
		return
	
	if enemy.stats == null:
		print("[ShootingBehavior] 错误: enemy.stats 为 null")
		return
	
	print("[ShootingBehavior] 开始射击，投射物数量: ", projectile_count)
	enemy.can_move = false
	var direction := enemy.global_position.direction_to(Global.player.position)
	# 计算开始角度
	var start_angle := -arc_angle/2.0
	# 弧形角度子弹分布
	var angle_step:= arc_angle/float(projectile_count-1 if projectile_count > 1 else 1.0)
	
	for i in range (projectile_count):
		var projectile := projectile_scene.instantiate() as Projectile
		if projectile == null:
			print("[ShootingBehavior] 错误: 无法实例化投射物")
			continue
		
		get_tree().root.add_child(projectile)
		projectile.global_position = fire_pos.global_position
		
		var rotated_direction:= direction.rotated(deg_to_rad(start_angle + angle_step*i))
		var velocity:= rotated_direction*projectile_speed
		projectile.set_projectile(velocity, enemy.stats.damage, false, 0, enemy)
		print("[ShootingBehavior] 投射物 ", i+1, " 已生成")
	
	print("[ShootingBehavior] 射击完成，生成了 ", projectile_count, " 个投射物")
	
	await  get_tree().create_timer(1).timeout
	enemy.can_move = true
