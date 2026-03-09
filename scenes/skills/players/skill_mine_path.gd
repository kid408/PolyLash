extends SkillDrawingBase
class_name SkillMinePath

# Core parameters from config/player/skill_params_wide.csv (skill_mine_path).
var mine_damage: int = 150
var mine_trigger_radius: float = 20.0
var mine_explosion_radius: float = 120.0
var mine_density_distance: float = 50.0
var mine_area_density: float = 60.0

# Extra tuning for new drawing framework implementation.
var mine_auto_explode_time: float = 5.0
var mine_inner_blast_ratio: float = 1.35
var mine_shock_slow_value: float = 0.45
var mine_shock_slow_duration: float = 1.6

func _spawn_line_effect(start: Vector2, end: Vector2) -> void:
	var spacing: float = max(18.0, mine_density_distance)
	_spawn_mines_on_segment(start, end, spacing, mine_auto_explode_time)

func _spawn_area_effect(polygon: PackedVector2Array) -> void:
	if polygon.size() < 3:
		return
	var spacing: float = max(22.0, mine_area_density)
	_spawn_mines_in_polygon(polygon, spacing)

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

func _on_mine_checker_timeout(checker: Timer, pos: Vector2, delay: float) -> void:
	if checker == null or not is_instance_valid(checker):
		return

	var elapsed: float = float(checker.get_meta("elapsed", 0.0)) + checker.wait_time
	checker.set_meta("elapsed", elapsed)

	if _has_enemy_near(pos, mine_trigger_radius):
		checker.stop()
		checker.queue_free()
		_explode_mine(pos)
		return

	if elapsed >= delay:
		checker.stop()
		checker.queue_free()
		_explode_mine(pos)

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
