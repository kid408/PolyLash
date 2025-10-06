extends Unit
class_name Enemy

# 羊群效应
@export var flock_push := 20.0
# 视觉区域
@onready var vision_area: Area2D = $VisionArea
@onready var knockback_timer: Timer = $KnockbackTimer


var can_move := true

var knockback_dir:Vector2

var knockback_power:float
	
func _process(delta: float) -> void:
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
	for area: Node2D in vision_area.get_overlapping_areas():
		if area != self and area.is_inside_tree():
			var vector := global_position - area.global_position
			direction += flock_push * vector.normalized()/vector.length()
			
	return direction
			

# 是否可以移动到玩家，距离60个像素，方式和玩家重叠
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

func _on_knockback_timer_timeout() -> void:
	reset_knockback()

func _on_hurtbox_component_on_damaged(hitbox: HitboxComponent) -> void:
	super._on_hurtbox_component_on_damaged(hitbox)
	
	if hitbox.knockback_power > 0:
		var dir := hitbox.source.global_position.direction_to(global_position)
		apply_knockback(dir,hitbox.knockback_power)
