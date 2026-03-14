extends Node2D
class_name SawProjectile

var shape_points: Array[Vector2] = []
var is_closed: bool = false
var fly_dir: Vector2 = Vector2.RIGHT
var player_ref: Node2D = null

var is_landed: bool = false
var target_pos: Vector2 = Vector2.ZERO
var speed: float = 0.0

var chained_enemies: Array[WeakRef] = []
var chain_radius: float = 250.0
var tick_timer: float = 0.0
var lifetime_timer: Timer = null

var visual_poly: Polygon2D = null
var visual_line: Line2D = null

var saw_rotation_speed: float = 25.0
var saw_push_radius: float = 120.0
var saw_push_force_value: float = 1000.0
var saw_damage_tick: int = 3
var saw_damage_open: int = 1
var saw_contact_interval: float = 0.32
var saw_area_interval: float = 0.32
var stake_impact_damage: int = 20
var chain_color: Color = Color(0.8, 0.2, 0.2, 0.8)
var saw_hit_radius: float = 80.0
var saw_fly_speed: float = 1100.0
var closure_duration: float = 6.7
var dismember_damage: int = 72

func setup(
	_points: Array[Vector2],
	_closed: bool,
	_dir: Vector2,
	_player: Node2D,
	_launch_distance: float = 320.0,
	_chain_radius_override: float = -1.0
) -> void:
	shape_points = _points.duplicate()
	is_closed = _closed
	fly_dir = _dir.normalized()
	player_ref = _player

	add_to_group("projectiles")
	add_to_group("player_skill_effects")

	if "saw_rotation_speed" in player_ref:
		saw_rotation_speed = float(player_ref.get("saw_rotation_speed"))
	if "saw_push_force" in player_ref:
		saw_push_force_value = float(player_ref.get("saw_push_force"))
	if "saw_push_radius" in player_ref:
		saw_push_radius = float(player_ref.get("saw_push_radius"))
	elif "saw_hit_radius" in player_ref:
		saw_push_radius = max(90.0, float(player_ref.get("saw_hit_radius")) * 1.4)
	if "saw_damage_tick" in player_ref:
		saw_damage_tick = int(player_ref.get("saw_damage_tick"))
	if "saw_damage_open" in player_ref:
		saw_damage_open = int(player_ref.get("saw_damage_open"))
	if "saw_contact_interval" in player_ref:
		saw_contact_interval = float(player_ref.get("saw_contact_interval"))
	if "saw_area_interval" in player_ref:
		saw_area_interval = float(player_ref.get("saw_area_interval"))
	if "stake_impact_damage" in player_ref:
		stake_impact_damage = int(player_ref.get("stake_impact_damage"))
	if "chain_color" in player_ref:
		chain_color = player_ref.get("chain_color")
	if "saw_hit_radius" in player_ref:
		saw_hit_radius = float(player_ref.get("saw_hit_radius"))
	if "saw_fly_speed" in player_ref:
		saw_fly_speed = float(player_ref.get("saw_fly_speed"))
	if "closure_duration" in player_ref:
		closure_duration = float(player_ref.get("closure_duration"))
	if "dismember_damage" in player_ref:
		dismember_damage = int(player_ref.get("dismember_damage"))

	if _chain_radius_override > 0.0:
		chain_radius = _chain_radius_override
	elif "chain_radius" in player_ref:
		chain_radius = float(player_ref.get("chain_radius"))

	speed = saw_fly_speed
	z_index = 60

	if shape_points.size() < 2:
		shape_points = [global_position, global_position + fly_dir * 120.0]

	var launch_origin: Vector2 = global_position
	if launch_origin == Vector2.ZERO and is_instance_valid(player_ref):
		launch_origin = player_ref.global_position
	target_pos = launch_origin + fly_dir * max(40.0, _launch_distance)

	_build_visual()
	_setup_lifetime_timer()

func _build_visual() -> void:
	var local_points: PackedVector2Array = PackedVector2Array()
	if is_closed:
		var center: Vector2 = Vector2.ZERO
		for point: Vector2 in shape_points:
			center += point
		center /= float(shape_points.size())
		for point: Vector2 in shape_points:
			local_points.append(point - center)
	else:
		var start_point: Vector2 = shape_points[0]
		for point: Vector2 in shape_points:
			local_points.append(point - start_point)

	visual_poly = Polygon2D.new()
	visual_poly.polygon = local_points
	add_child(visual_poly)

	visual_line = Line2D.new()
	visual_line.points = local_points
	add_child(visual_line)

	if is_closed:
		visual_poly.visible = true
		visual_poly.color = Color(0.82, 0.15, 0.15, 0.78)
		visual_line.closed = true
		visual_line.default_color = Color(1.0, 0.6, 0.6, 1.0)
		visual_line.width = 6.0
	else:
		visual_poly.visible = false
		visual_line.closed = false
		visual_line.default_color = Color(1.0, 1.0, 1.0, 0.95)
		visual_line.width = 8.0

func _setup_lifetime_timer() -> void:
	lifetime_timer = Timer.new()
	lifetime_timer.one_shot = true
	lifetime_timer.wait_time = max(0.5, closure_duration) if is_closed else 3.2
	lifetime_timer.timeout.connect(_on_lifetime_end)
	add_child(lifetime_timer)

func _process(delta: float) -> void:
	if not is_landed:
		_process_flying(delta)
		return
	_process_chaining(delta)
	queue_redraw()

func _process_flying(delta: float) -> void:
	var dist: float = global_position.distance_to(target_pos)
	if dist <= 8.0:
		_land()
		return

	var move_step: float = min(dist, speed * delta)
	global_position += fly_dir * move_step

	if is_closed:
		rotation += saw_rotation_speed * delta
		_capture_inside_enemies()
	else:
		_push_enemies_like_blade(delta)

	_damage_enemies_in_path(delta)

func _push_enemies_like_blade(delta: float) -> void:
	var enemies: Array = get_tree().get_nodes_in_group("enemies")
	var poly_global: PackedVector2Array = _get_poly_global()
	if poly_global.size() < 2:
		return

	var push_strength: float = max(speed * 1.1, saw_push_force_value)
	for enemy_obj: Variant in enemies:
		if enemy_obj == null or not is_instance_valid(enemy_obj):
			continue
		if not (enemy_obj is Node2D):
			continue
		var enemy: Node2D = enemy_obj

		var near_blade: bool = false
		for i: int in range(poly_global.size() - 1):
			var p1: Vector2 = poly_global[i]
			var p2: Vector2 = poly_global[i + 1]
			var close_p: Vector2 = Geometry2D.get_closest_point_to_segment(enemy.global_position, p1, p2)
			if enemy.global_position.distance_to(close_p) <= saw_push_radius:
				near_blade = true
				break

		if not near_blade:
			continue

		_ensure_chained(enemy)
		enemy.global_position += fly_dir * push_strength * delta

		var toward_projectile: Vector2 = global_position - enemy.global_position
		enemy.global_position += toward_projectile * min(1.0, 3.2 * delta)

func _capture_inside_enemies() -> void:
	var enemies: Array = get_tree().get_nodes_in_group("enemies")
	for enemy_obj: Variant in enemies:
		if enemy_obj == null or not is_instance_valid(enemy_obj):
			continue
		if not (enemy_obj is Node2D):
			continue
		var enemy: Node2D = enemy_obj
		if not _is_enemy_inside(enemy):
			continue
		_ensure_chained(enemy)
		enemy.global_position = global_position

func _damage_enemies_in_path(delta: float) -> void:
	tick_timer -= delta
	if tick_timer > 0.0:
		return
	tick_timer = max(0.05, saw_contact_interval)

	var enemies: Array = get_tree().get_nodes_in_group("enemies")
	var damage: int = saw_damage_tick if is_closed else saw_damage_open
	for enemy_obj: Variant in enemies:
		if enemy_obj == null or not is_instance_valid(enemy_obj):
			continue
		if not (enemy_obj is Node2D):
			continue
		var enemy: Node2D = enemy_obj
		if not _is_enemy_inside(enemy):
			continue
		if enemy.has_node("HealthComponent"):
			enemy.get_node("HealthComponent").take_damage(max(1, damage))

func _land() -> void:
	is_landed = true
	if is_closed:
		rotation = 0.0
		_create_butcher_closure_mask()

	_capture_enemies_nearby()
	if is_closed:
		_apply_dismember_burst()
	Global.on_camera_shake.emit(8.0, 0.18)
	lifetime_timer.start()

func _capture_enemies_nearby() -> void:
	var enemies: Array = get_tree().get_nodes_in_group("enemies")
	for enemy_obj: Variant in enemies:
		if enemy_obj == null or not is_instance_valid(enemy_obj):
			continue
		if not (enemy_obj is Node2D):
			continue
		var enemy: Node2D = enemy_obj
		var close_enough: bool = global_position.distance_to(enemy.global_position) <= chain_radius * 1.15
		if close_enough or _is_enemy_inside(enemy):
			_ensure_chained(enemy)

func _ensure_chained(enemy: Node2D) -> void:
	for enemy_ref: WeakRef in chained_enemies:
		if enemy_ref.get_ref() == enemy:
			return
	chained_enemies.append(weakref(enemy))
	Global.spawn_floating_text(enemy.global_position, "TRAPPED!", Color(1.2, 0.35, 0.35))
	if enemy.has_node("HealthComponent"):
		enemy.get_node("HealthComponent").take_damage(max(1, stake_impact_damage))

func _process_chaining(delta: float) -> void:
	_capture_enemies_nearby()

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
		if dist > chain_radius and dist > 0.001:
			var dir: Vector2 = (enemy.global_position - global_position).normalized()
			enemy.global_position = global_position + dir * chain_radius

	chained_enemies = valid_refs

	tick_timer -= delta
	if tick_timer > 0.0:
		return
	tick_timer = max(0.08, saw_area_interval)

	var damage: int = saw_damage_tick if is_closed else saw_damage_open
	for enemy_ref: WeakRef in chained_enemies:
		var enemy_obj: Variant = enemy_ref.get_ref()
		if enemy_obj == null or not is_instance_valid(enemy_obj):
			continue
		if not (enemy_obj is Node2D):
			continue
		var enemy: Node2D = enemy_obj
		if enemy.has_node("HealthComponent"):
			enemy.get_node("HealthComponent").take_damage(max(1, damage))

func _draw() -> void:
	if not is_landed:
		return
	for enemy_ref: WeakRef in chained_enemies:
		var enemy_obj: Variant = enemy_ref.get_ref()
		if enemy_obj == null or not is_instance_valid(enemy_obj):
			continue
		if not (enemy_obj is Node2D):
			continue
		var enemy: Node2D = enemy_obj
		draw_line(Vector2.ZERO, to_local(enemy.global_position), chain_color, 2.0)

func _is_enemy_inside(enemy: Node2D) -> bool:
	var poly_global: PackedVector2Array = _get_poly_global()
	if is_closed:
		if poly_global.size() < 3:
			return false
		return Geometry2D.is_point_in_polygon(enemy.global_position, poly_global)

	for i: int in range(poly_global.size() - 1):
		var p1: Vector2 = poly_global[i]
		var p2: Vector2 = poly_global[i + 1]
		var closest: Vector2 = Geometry2D.get_closest_point_to_segment(enemy.global_position, p1, p2)
		if enemy.global_position.distance_to(closest) <= saw_hit_radius:
			return true
	return false

func _get_poly_global() -> PackedVector2Array:
	var poly_global: PackedVector2Array = PackedVector2Array()
	if not is_instance_valid(visual_line):
		return poly_global
	for point: Vector2 in visual_line.points:
		poly_global.append(to_global(point))
	return poly_global

func _on_lifetime_end() -> void:
	queue_free()

func manual_dismiss() -> void:
	queue_free()

func _apply_dismember_burst() -> void:
	if dismember_damage <= 0:
		return

	var hit_refs: Array[WeakRef] = []
	for enemy_ref: WeakRef in chained_enemies:
		var enemy_obj: Variant = enemy_ref.get_ref()
		if enemy_obj == null or not is_instance_valid(enemy_obj):
			continue
		if not (enemy_obj is Node2D):
			continue
		var enemy: Node2D = enemy_obj
		if enemy.has_node("HealthComponent"):
			enemy.get_node("HealthComponent").take_damage(max(1, dismember_damage))
			Global.spawn_floating_text(enemy.global_position, "DISMEMBER!", Color(1.2, 0.3, 0.3))
			hit_refs.append(enemy_ref)

	if not hit_refs.is_empty():
		Global.on_camera_shake.emit(10.0 + float(hit_refs.size()) * 0.35, 0.22)

func _create_butcher_closure_mask() -> void:
	var polygon: PackedVector2Array = _get_poly_global()
	if polygon.size() < 3:
		return
	var polygons: Array[PackedVector2Array] = [polygon]
	PolygonUtils.show_closure_masks(polygons, Color(1.0, 0.12, 0.12, 0.68), get_tree(), 0.45)
