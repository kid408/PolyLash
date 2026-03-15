extends SkillQBase
class_name SkillMinePath

var mine_damage: int = 150
var mine_trigger_radius: float = 20.0
var mine_explosion_radius: float = 120.0
var mine_density_distance: float = 50.0
var mine_area_density: float = 60.0

var mine_auto_explode_time: float = 5.0
var mine_inner_blast_ratio: float = 1.35
var mine_shock_slow_value: float = 0.45
var mine_shock_slow_duration: float = 1.6
var fuse_step_distance: float = 52.0
var fuse_tick_interval: float = 0.05
var fuse_hit_damage: int = 26
var fuse_hit_radius: float = 58.0
var fuse_push: float = 18.0
var fuse_recall_delay: float = 0.22
var fuse_recall_count: int = 5
var fuse_recall_damage: int = 32
var fuse_recall_pull: float = 26.0
var perimeter_chain_count: int = 6
var perimeter_chain_interval: float = 0.17
var perimeter_chain_damage: int = 30

var _pending_mines: Dictionary = {}

func _spawn_line_effect(start: Vector2, end: Vector2) -> void:
	var spacing: float = max(18.0, mine_density_distance)
	_spawn_mines_on_segment(start, end, spacing, mine_auto_explode_time)
	_launch_fuse_runner(start, end)

func _spawn_area_effect(polygon: PackedVector2Array) -> void:
	if polygon.size() < 3:
		return
	var spacing: float = max(22.0, mine_area_density)
	_spawn_mines_in_polygon(polygon, spacing)
	_spawn_perimeter_chain(polygon)

func _spawn_mines_on_segment(start: Vector2, end: Vector2, spacing: float, delay: float) -> void:
	var segment: Vector2 = end - start
	var length: float = segment.length()
	if length <= 1.0:
		_schedule_mine(start, delay)
		return

	var count: int = max(1, int(floor(length / spacing)))
	for i: int in range(count + 1):
		var t: float = float(i) / float(count)
		var pos: Vector2 = start.lerp(end, t)
		_schedule_mine(pos, delay)

func _spawn_mines_in_polygon(polygon: PackedVector2Array, spacing: float) -> void:
	var min_x: float = INF
	var min_y: float = INF
	var max_x: float = -INF
	var max_y: float = -INF
	for point: Vector2 in polygon:
		min_x = min(min_x, point.x)
		min_y = min(min_y, point.y)
		max_x = max(max_x, point.x)
		max_y = max(max_y, point.y)

	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	var x: float = min_x
	var spawn_count: int = 0
	while x <= max_x:
		var y: float = min_y
		while y <= max_y:
			var point: Vector2 = Vector2(x, y)
			if Geometry2D.is_point_in_polygon(point, polygon):
				var jitter: Vector2 = Vector2(rng.randf_range(-10.0, 10.0), rng.randf_range(-10.0, 10.0))
				var delay: float = rng.randf_range(0.35, 1.9)
				_schedule_mine(point + jitter, delay)
				spawn_count += 1
			y += spacing
		x += spacing

	if spawn_count > 0:
		Global.spawn_floating_text(_polygon_center(polygon), "MINEFIELD!", Color(1.2, 0.8, 0.24))
		SoundManager.play("skill_q_closure_generic")

func _launch_fuse_runner(start: Vector2, finish: Vector2) -> void:
	var seg: Vector2 = finish - start
	var length: float = seg.length()
	if length <= 1.0:
		return
	var move_dir: Vector2 = seg / length
	var host: Node2D = Node2D.new()
	host.name = "SapperFuseRunnerHost"
	add_child(host)

	var step_total: int = int(max(2.0, ceil(length / max(12.0, fuse_step_distance))))
	var step_index: int = 0
	var timer: Timer = Timer.new()
	timer.wait_time = max(0.03, fuse_tick_interval)
	timer.one_shot = false
	host.add_child(timer)
	timer.timeout.connect(func() -> void:
		if not is_instance_valid(host):
			return
		if step_index > step_total:
			timer.stop()
			host.queue_free()
			_spawn_fuse_recall(finish, start, move_dir)
			return
		_emit_fuse_tick(start, finish, step_index, step_total, move_dir)
		step_index += 1
	)
	timer.start()

func _spawn_fuse_recall(from_pos: Vector2, to_pos: Vector2, move_dir: Vector2) -> void:
	var tree: SceneTree = get_tree()
	if tree == null:
		return
	tree.create_timer(max(0.05, fuse_recall_delay)).timeout.connect(func() -> void:
		if not is_inside_tree():
			return
		var host: Node2D = Node2D.new()
		host.name = "SapperFuseRecallHost"
		add_child(host)
		var pulse_total: int = int(max(1, fuse_recall_count))
		var pulse_index: int = 0
		var timer: Timer = Timer.new()
		timer.wait_time = max(0.06, perimeter_chain_interval * 0.75)
		timer.one_shot = false
		host.add_child(timer)
		timer.timeout.connect(func() -> void:
			if not is_instance_valid(host):
				return
			if pulse_index >= pulse_total:
				timer.stop()
				host.queue_free()
				return
			_emit_fuse_recall_tick(from_pos, to_pos, pulse_index, pulse_total, move_dir)
			pulse_index += 1
		)
		timer.start()
	)

func _emit_fuse_tick(start: Vector2, finish: Vector2, index: int, total: int, move_dir: Vector2) -> void:
	var t: float = float(index) / float(max(1, total))
	var prev_t: float = float(max(0, index - 1)) / float(max(1, total))
	var current: Vector2 = start.lerp(finish, t)
	var previous: Vector2 = start.lerp(finish, prev_t)
	SkillEffectManager.create_line_effect({
		"start": previous,
		"end": current,
		"width": 14.0,
		"damage": 0,
		"damage_interval": 0.2,
		"duration": 0.12,
		"color": Color(1.2, 0.9, 0.35, 0.9)
	})
	_apply_radius_blast(current, fuse_hit_radius, fuse_hit_damage, move_dir, fuse_push)
	_detonate_nearby_pending_mines(current, mine_trigger_radius * 1.9, 1)

func _emit_fuse_recall_tick(
	from_pos: Vector2,
	to_pos: Vector2,
	index: int,
	total: int,
	move_dir: Vector2
) -> void:
	var t: float = 0.0
	if total > 1:
		t = float(index) / float(total - 1)
	var center: Vector2 = from_pos.lerp(to_pos, t)
	var tangent: Vector2 = Vector2(-move_dir.y, move_dir.x)
	if tangent.length_squared() <= 0.001:
		tangent = Vector2.UP
	var start: Vector2 = center - tangent * 70.0
	var end: Vector2 = center + tangent * 70.0
	SkillEffectManager.create_line_effect({
		"start": start,
		"end": end,
		"width": 14.0,
		"damage": 0,
		"damage_interval": 0.2,
		"duration": 0.16,
		"color": Color(1.25, 0.96, 0.5, 0.92)
	})
	_apply_line_radius_damage(start, end, 12.0, fuse_recall_damage)
	_detonate_nearby_pending_mines(center, mine_trigger_radius * 2.3, 2)
	_apply_pull_to_point(center, fuse_hit_radius * 1.5, fuse_recall_pull)

func _spawn_perimeter_chain(polygon: PackedVector2Array) -> void:
	var point_count: int = polygon.size()
	if point_count < 2:
		return
	var chain_total: int = int(max(1, perimeter_chain_count))
	var chain_index: int = 0
	var host: Node2D = Node2D.new()
	host.name = "SapperPerimeterChainHost"
	add_child(host)

	var timer: Timer = Timer.new()
	timer.wait_time = max(0.08, perimeter_chain_interval)
	timer.one_shot = false
	host.add_child(timer)
	timer.timeout.connect(func() -> void:
		if not is_instance_valid(host):
			return
		if chain_index >= chain_total:
			timer.stop()
			host.queue_free()
			return
		_emit_perimeter_chain_tick(polygon, chain_index)
		chain_index += 1
	)
	timer.start()

func _emit_perimeter_chain_tick(polygon: PackedVector2Array, chain_index: int) -> void:
	var point_count: int = polygon.size()
	if point_count < 2:
		return
	var edge_index: int = chain_index % point_count
	var start: Vector2 = polygon[edge_index]
	var end: Vector2 = polygon[(edge_index + 1) % point_count]
	SkillEffectManager.create_line_effect({
		"start": start,
		"end": end,
		"width": 13.0,
		"damage": 0,
		"damage_interval": 0.2,
		"duration": 0.18,
		"color": Color(1.2, 0.98, 0.58, 0.9)
	})
	_apply_line_radius_damage(start, end, 12.0, perimeter_chain_damage)
	var mid: Vector2 = start.lerp(end, 0.5)
	_detonate_nearby_pending_mines(mid, mine_explosion_radius * 0.55, 2)

func _detonate_nearby_pending_mines(center: Vector2, radius: float, max_count: int) -> int:
	var keys: Array = _pending_mines.keys()
	var detonated: int = 0
	for key_var: Variant in keys:
		var key: int = int(key_var)
		var payload_var: Variant = _pending_mines.get(key, null)
		if not (payload_var is Dictionary):
			continue
		var payload: Dictionary = payload_var
		var mine_pos: Vector2 = payload.get("pos", Vector2.ZERO)
		if mine_pos.distance_to(center) > radius:
			continue
		var checker_ref_var: Variant = payload.get("checker", null)
		if checker_ref_var is WeakRef:
			var checker_obj: Variant = checker_ref_var.get_ref()
			if checker_obj != null and is_instance_valid(checker_obj) and checker_obj is Timer:
				var checker: Timer = checker_obj
				checker.stop()
				checker.queue_free()
		_pending_mines.erase(key)
		_explode_mine(mine_pos)
		detonated += 1
		if detonated >= max_count:
			break
	return detonated

func _apply_radius_blast(center: Vector2, radius: float, damage: int, move_dir: Vector2, push_amount: float) -> void:
	var safe_dir: Vector2 = move_dir.normalized()
	if safe_dir.length_squared() <= 0.001:
		safe_dir = Vector2.RIGHT
	var enemies: Array = get_tree().get_nodes_in_group("enemies")
	for enemy_obj: Variant in enemies:
		if enemy_obj == null or not is_instance_valid(enemy_obj):
			continue
		if not (enemy_obj is Node2D):
			continue
		var enemy: Node2D = enemy_obj
		if enemy.global_position.distance_to(center) > radius:
			continue
		if enemy.has_node("HealthComponent"):
			var hc: Node = enemy.get_node("HealthComponent")
			if hc != null and hc.has_method("take_damage"):
				hc.call("take_damage", max(1, damage))
		if enemy.has_method("apply_status"):
			enemy.call("apply_status", "slow", mine_shock_slow_duration * 0.6, mine_shock_slow_value, 1, 0.1)
		enemy.global_position += safe_dir * push_amount

func _apply_line_radius_damage(start: Vector2, end: Vector2, hit_radius: float, damage: int) -> void:
	var enemies: Array = get_tree().get_nodes_in_group("enemies")
	for enemy_obj: Variant in enemies:
		if enemy_obj == null or not is_instance_valid(enemy_obj):
			continue
		if not (enemy_obj is Node2D):
			continue
		var enemy: Node2D = enemy_obj
		var closest: Vector2 = Geometry2D.get_closest_point_to_segment(enemy.global_position, start, end)
		if enemy.global_position.distance_to(closest) > hit_radius:
			continue
		if enemy.has_node("HealthComponent"):
			var hc: Node = enemy.get_node("HealthComponent")
			if hc != null and hc.has_method("take_damage"):
				hc.call("take_damage", max(1, damage))
		if enemy.has_method("apply_status"):
			enemy.call("apply_status", "marked", 1.0, 0.14, 1, 0.2)

func _apply_pull_to_point(center: Vector2, radius: float, pull_amount: float) -> void:
	var enemies: Array = get_tree().get_nodes_in_group("enemies")
	for enemy_obj: Variant in enemies:
		if enemy_obj == null or not is_instance_valid(enemy_obj):
			continue
		if not (enemy_obj is Node2D):
			continue
		var enemy: Node2D = enemy_obj
		var offset: Vector2 = center - enemy.global_position
		var dist: float = offset.length()
		if dist > radius or dist <= 0.001:
			continue
		enemy.global_position += offset / dist * pull_amount

func _schedule_mine(pos: Vector2, delay: float) -> void:
	var clamped_delay: float = max(0.2, delay)
	var marker_radius: float = max(8.0, mine_trigger_radius)
	var marker_polygon: PackedVector2Array = _build_circle_polygon(pos, marker_radius, 12)
	SkillEffectManager.create_area_effect({
		"polygon": marker_polygon,
		"damage": 0,
		"duration": clamped_delay,
		"color": Color(1.0, 0.82, 0.22, 0.34),
		"z_index": 20,
		"fade_in_duration": 0.05,
		"fade_out_duration": 0.12
	})

	var checker: Timer = Timer.new()
	checker.wait_time = 0.12
	checker.one_shot = false
	checker.set_meta("elapsed", 0.0)
	add_child(checker)
	checker.timeout.connect(_on_mine_checker_timeout.bind(checker, pos, clamped_delay))
	checker.start()

	var checker_id: int = checker.get_instance_id()
	_pending_mines[checker_id] = {"pos": pos, "checker": weakref(checker)}

func _on_mine_checker_timeout(checker: Timer, pos: Vector2, delay: float) -> void:
	if checker == null or not is_instance_valid(checker):
		return

	var elapsed: float = float(checker.get_meta("elapsed", 0.0)) + checker.wait_time
	checker.set_meta("elapsed", elapsed)
	var checker_id: int = checker.get_instance_id()

	if _has_enemy_near(pos, mine_trigger_radius):
		checker.stop()
		checker.queue_free()
		_pending_mines.erase(checker_id)
		_explode_mine(pos)
		return

	if elapsed >= delay:
		checker.stop()
		checker.queue_free()
		_pending_mines.erase(checker_id)
		_explode_mine(pos)

func remote_detonate_all() -> int:
	var keys: Array = _pending_mines.keys()
	var detonated: int = 0
	for key_var: Variant in keys:
		var key: int = int(key_var)
		var payload_var: Variant = _pending_mines.get(key, {})
		if not (payload_var is Dictionary):
			_pending_mines.erase(key)
			continue
		var payload: Dictionary = payload_var
		var pos: Vector2 = payload.get("pos", Vector2.ZERO)
		var checker_ref_var: Variant = payload.get("checker", null)
		if checker_ref_var is WeakRef:
			var checker_obj: Variant = checker_ref_var.get_ref()
			if checker_obj != null and is_instance_valid(checker_obj) and checker_obj is Timer:
				var checker: Timer = checker_obj
				checker.stop()
				checker.queue_free()
		_pending_mines.erase(key)
		_explode_mine(pos)
		detonated += 1
	return detonated

func get_pending_mine_count() -> int:
	return _pending_mines.size()

func _has_enemy_near(pos: Vector2, radius: float) -> bool:
	var enemies: Array = get_tree().get_nodes_in_group("enemies")
	for enemy_obj: Variant in enemies:
		if enemy_obj == null or not is_instance_valid(enemy_obj):
			continue
		if not (enemy_obj is Node2D):
			continue
		var enemy: Node2D = enemy_obj
		if enemy.global_position.distance_to(pos) <= radius:
			return true
	return false

func _explode_mine(pos: Vector2) -> void:
	var enemies: Array = get_tree().get_nodes_in_group("enemies")
	var hit_count: int = 0
	for enemy_obj: Variant in enemies:
		if enemy_obj == null or not is_instance_valid(enemy_obj):
			continue
		if not (enemy_obj is Node2D):
			continue
		var enemy: Node2D = enemy_obj
		var distance: float = enemy.global_position.distance_to(pos)
		if distance > mine_explosion_radius:
			continue

		var final_damage: int = mine_damage
		if distance <= mine_explosion_radius * 0.45:
			final_damage = int(round(float(mine_damage) * mine_inner_blast_ratio))

		if enemy.has_node("HealthComponent"):
			var hc: Node = enemy.get_node("HealthComponent")
			if hc != null and hc.has_method("take_damage"):
				hc.call("take_damage", max(1, final_damage))
		if enemy.has_method("apply_status"):
			enemy.call("apply_status", "slow", mine_shock_slow_duration, mine_shock_slow_value)
			enemy.call("apply_status", "marked", 1.1, 0.1)
		hit_count += 1

	var blast_polygon: PackedVector2Array = _build_circle_polygon(pos, mine_explosion_radius, 18)
	SkillEffectManager.create_area_effect({
		"polygon": blast_polygon,
		"damage": 0,
		"duration": 0.22,
		"color": Color(1.0, 0.75, 0.22, 0.5),
		"z_index": 22
	})

	spawn_skill_vfx(pos, Color(1.2, 0.76, 0.22, 0.9), 0.62)
	if hit_count > 0:
		Global.spawn_floating_text(pos, "BOOM x%d" % hit_count, Color(1.25, 0.85, 0.3))
		Global.on_camera_shake.emit(4.5 + float(hit_count) * 0.25, 0.1)

func _build_circle_polygon(center: Vector2, radius: float, segments: int) -> PackedVector2Array:
	var points: PackedVector2Array = PackedVector2Array()
	var seg_count: int = max(6, segments)
	for i: int in range(seg_count):
		var angle: float = TAU * float(i) / float(seg_count)
		points.append(center + Vector2(cos(angle), sin(angle)) * radius)
	return points

func _polygon_center(polygon: PackedVector2Array) -> Vector2:
	if polygon.is_empty():
		return Vector2.ZERO
	var center: Vector2 = Vector2.ZERO
	for point: Vector2 in polygon:
		center += point
	return center / float(polygon.size())

func _get_line_color() -> Color:
	return Color(1.0, 0.85, 0.22, 1.0)

func _get_closure_color() -> Color:
	return Color(1.0, 0.62, 0.18, 1.0)

func cleanup() -> void:
	var keys: Array = _pending_mines.keys()
	for key_var: Variant in keys:
		var key: int = int(key_var)
		var payload_var: Variant = _pending_mines.get(key, {})
		if not (payload_var is Dictionary):
			continue
		var payload: Dictionary = payload_var
		var checker_ref_var: Variant = payload.get("checker", null)
		if checker_ref_var is WeakRef:
			var checker_obj: Variant = checker_ref_var.get_ref()
			if checker_obj != null and is_instance_valid(checker_obj) and checker_obj is Timer:
				var checker: Timer = checker_obj
				checker.stop()
				checker.queue_free()
	_pending_mines.clear()
	super.cleanup()

