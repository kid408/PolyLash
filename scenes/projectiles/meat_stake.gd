# ==============================================================================
# 内部类：肉桩
# ==============================================================================
extends Node2D
class_name MeatStake

var target_pos: Vector2
var player_ref: PlayerButcher
var is_landed: bool = false
var chained_enemies: Array = []  # 被链接的敌人（WeakRef）
var speed: float = 0.0
var visual_sprite: Polygon2D

func setup(_target_pos: Vector2, _player: PlayerButcher):
	target_pos = _target_pos
	player_ref = _player
	speed = player_ref.stake_throw_speed
	
	# 创建视觉
	visual_sprite = Polygon2D.new()
	visual_sprite.polygon = PackedVector2Array([
		Vector2(0, -20), Vector2(10, 10), 
		Vector2(0, 30), Vector2(-10, 10)
	])
	visual_sprite.color = Color(0.2, 0.2, 0.2, 1)
	add_child(visual_sprite)
	
	# 创建生命周期计时器
	var timer = Timer.new()
	timer.wait_time = player_ref.stake_duration
	timer.one_shot = true
	timer.timeout.connect(queue_free)
	timer.autostart = true 
	add_child(timer)

func _process(delta: float) -> void:
	if not is_landed:
		_process_flying(delta)
	else:
		_update_chains()
		queue_redraw()

func _process_flying(delta: float) -> void:
	var dist = global_position.distance_to(target_pos)
	if dist < 10.0:
		_land()
		return
	
	# 移动
	var move_step = speed * delta
	if move_step > dist: move_step = dist
	var dir = (target_pos - global_position).normalized()
	global_position += dir * move_step
	visual_sprite.rotation += 10.0 * delta 
	
	# 飞行时拉扯沿途敌人
	var enemies = get_tree().get_nodes_in_group("enemies")
	for e in enemies:
		if not is_instance_valid(e): continue
		if global_position.distance_to(e.global_position) < 60.0:
			e.global_position = global_position

func _land() -> void:
	is_landed = true
	visual_sprite.rotation = 0 
	visual_sprite.scale = Vector2(1.5, 1.5)
	Global.on_camera_shake.emit(10.0, 0.2)
	Global.spawn_floating_text(global_position, "THUD!", Color.WEB_GRAY)
	
	# 链接范围内的敌人
	var radius = player_ref.chain_radius
	var enemies = get_tree().get_nodes_in_group("enemies")
	for e in enemies:
		if global_position.distance_to(e.global_position) < radius:
			_chain_enemy(e)

func _chain_enemy(enemy: Node2D) -> void:
	# 检查是否已链接
	for ref in chained_enemies:
		if ref.get_ref() == enemy: return
	
	chained_enemies.append(weakref(enemy))
	Global.spawn_floating_text(enemy.global_position, "CHAINED", Color.RED)
	
	if enemy.has_node("HealthComponent"):
		enemy.health_component.take_damage(player_ref.stake_impact_damage)

func _update_chains() -> void:
	# 检查player_ref是否有效
	if not is_instance_valid(player_ref):
		queue_free()
		return
	
	var valid_chains = []
	var radius = player_ref.chain_radius
	
	for ref in chained_enemies:
		var e = ref.get_ref()
		if is_instance_valid(e):
			valid_chains.append(ref)
			
			# 强制拉扯到范围内
			if global_position.distance_to(e.global_position) > radius:
				var dir = (e.global_position - global_position).normalized()
				e.global_position = global_position + dir * radius
	
	chained_enemies = valid_chains
	
func _draw() -> void:
	if not is_landed: return
	if not is_instance_valid(player_ref): return
	
	# 绘制链条线
	for ref in chained_enemies:
		var e = ref.get_ref()
		if is_instance_valid(e):
			draw_line(Vector2.ZERO, to_local(e.global_position), 
				player_ref.chain_color, 2.0)
