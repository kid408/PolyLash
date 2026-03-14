extends Node2D
class_name MeatStake

var target_pos: Vector2 = Vector2.ZERO
var player_ref: Node2D = null
var is_landed: bool = false
var chained_enemies: Array[WeakRef] = []
var speed: float = 0.0
var visual_sprite: Polygon2D = null

func setup(_target_pos: Vector2, _player: Node2D) -> void:
	target_pos = _target_pos
	player_ref = _player
	speed = _get_player_float("stake_throw_speed", 1200.0)
	add_to_group("projectiles")
	add_to_group("player_skill_effects")

	visual_sprite = Polygon2D.new()
	visual_sprite.polygon = PackedVector2Array([
		Vector2(0, -20),
		Vector2(10, 10),
		Vector2(0, 30),
		Vector2(-10, 10)
	])
	visual_sprite.color = Color(0.2, 0.2, 0.2, 1.0)
	add_child(visual_sprite)

	var timer: Timer = Timer.new()
	timer.wait_time = _get_player_float("stake_duration", 6.0)
	timer.one_shot = true
	timer.timeout.connect(queue_free)
	timer.autostart = true
	add_child(timer)

func _process(delta: float) -> void:
	if not is_landed:
		_process_flying(delta)
		return
	_update_chains()
	queue_redraw()

func _process_flying(delta: float) -> void:
	var dist: float = global_position.distance_to(target_pos)
	if dist < 8.0:
		_land()
		return

	var move_step: float = min(dist, speed * delta)
	var dir: Vector2 = (target_pos - global_position).normalized()
	global_position += dir * move_step
	if is_instance_valid(visual_sprite):
		visual_sprite.rotation += 10.0 * delta

	var enemies: Array = get_tree().get_nodes_in_group("enemies")
	for enemy_obj: Variant in enemies:
		if enemy_obj == null or not is_instance_valid(enemy_obj):
			continue
		if not (enemy_obj is Node2D):
			continue
		var enemy: Node2D = enemy_obj
		if global_position.distance_to(enemy.global_position) < 60.0:
			enemy.global_position = enemy.global_position.lerp(global_position, min(1.0, 8.0 * delta))

func _land() -> void:
	is_landed = true
	if is_instance_valid(visual_sprite):
		visual_sprite.rotation = 0.0
		visual_sprite.scale = Vector2(1.5, 1.5)
	Global.on_camera_shake.emit(8.0, 0.16)
	Global.spawn_floating_text(global_position, "THUD!", Color.GRAY)

	var radius: float = _get_player_float("chain_radius", 250.0)
	var enemies: Array = get_tree().get_nodes_in_group("enemies")
	for enemy_obj: Variant in enemies:
		if enemy_obj == null or not is_instance_valid(enemy_obj):
			continue
		if not (enemy_obj is Node2D):
			continue
		var enemy: Node2D = enemy_obj
		if global_position.distance_to(enemy.global_position) <= radius:
			_chain_enemy(enemy)

func _chain_enemy(enemy: Node2D) -> void:
	for enemy_ref: WeakRef in chained_enemies:
		if enemy_ref.get_ref() == enemy:
			return
	chained_enemies.append(weakref(enemy))
	Global.spawn_floating_text(enemy.global_position, "CHAINED", Color(1.0, 0.25, 0.25))

	var impact_damage: int = int(round(_get_player_float("stake_impact_damage", 20.0)))
	if enemy.has_node("HealthComponent"):
		enemy.get_node("HealthComponent").take_damage(max(1, impact_damage))

func _update_chains() -> void:
	if not is_instance_valid(player_ref):
		queue_free()
		return

	var radius: float = _get_player_float("chain_radius", 250.0)
	var valid_refs: Array[WeakRef] = []
	for enemy_ref: WeakRef in chained_enemies:
		var enemy_obj: Variant = enemy_ref.get_ref()
		if enemy_obj == null or not is_instance_valid(enemy_obj):
			continue
		if not (enemy_obj is Node2D):
			continue
		var enemy: Node2D = enemy_obj
		valid_refs.append(enemy_ref)
		var dist: float = global_position.distance_to(enemy.global_position)
		if dist > radius and dist > 0.001:
			var dir: Vector2 = (enemy.global_position - global_position).normalized()
			enemy.global_position = global_position + dir * radius

	chained_enemies = valid_refs

func _draw() -> void:
	if not is_landed:
		return
	if not is_instance_valid(player_ref):
		return
	var chain_col: Color = _get_player_color("chain_color", Color(0.3, 0.1, 0.1, 0.8))
	for enemy_ref: WeakRef in chained_enemies:
		var enemy_obj: Variant = enemy_ref.get_ref()
		if enemy_obj == null or not is_instance_valid(enemy_obj):
			continue
		if not (enemy_obj is Node2D):
			continue
		var enemy: Node2D = enemy_obj
		draw_line(Vector2.ZERO, to_local(enemy.global_position), chain_col, 2.0)

func _get_player_float(property_name: String, default_value: float) -> float:
	if is_instance_valid(player_ref) and (property_name in player_ref):
		return float(player_ref.get(property_name))
	return default_value

func _get_player_color(property_name: String, default_value: Color) -> Color:
	if is_instance_valid(player_ref) and (property_name in player_ref):
		var value: Variant = player_ref.get(property_name)
		if value is Color:
			return value
	return default_value
