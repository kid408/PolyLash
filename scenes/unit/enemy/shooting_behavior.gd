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
	
	if enemy == null:
		push_error("[ShootingBehavior] 错误: enemy 为 null!")
	if fire_pos == null:
		push_error("[ShootingBehavior] 错误: fire_pos 为 null!")
	
	# 确保节点能够处理 _process
	process_mode = PROCESS_MODE_INHERIT
	
func _process(delta: float) -> void:
	if Global.game_paused or enemy == null:
		return
	
	if current_cooldown > 0:
		current_cooldown -= delta
	else:
		shoot()
		current_cooldown = cooldown

func shoot() -> void:
	if not is_instance_valid(Global.player) or not is_instance_valid(enemy):
		return
	
	if projectile_scene == null or fire_pos == null:
		return
	
	enemy.can_move = false
	var direction := enemy.global_position.direction_to(Global.player.position)
	var start_angle := -arc_angle/2.0
	var angle_step:= arc_angle/float(projectile_count-1 if projectile_count > 1 else 1.0)
	
	for i in range (projectile_count):
		var projectile := projectile_scene.instantiate() as Projectile
		if projectile == null:
			continue
		
		get_tree().root.add_child(projectile)
		projectile.global_position = fire_pos.global_position
		
		var rotated_direction:= direction.rotated(deg_to_rad(start_angle + angle_step*i))
		var velocity:= rotated_direction*projectile_speed
		projectile.set_projectile(velocity, enemy.damage, false, 0, enemy)
	
	await  get_tree().create_timer(1).timeout
	enemy.can_move = true
