extends SkillDrawingBase
class_name SkillMinePathRefactored

var mine_damage: int = 168
var mine_trigger_radius: float = 26.0
var mine_explosion_radius: float = 126.0
var mine_density_distance: float = 44.0
var mine_area_density: float = 52.0
var mine_auto_explode_time: float = 4.6
var mine_inner_blast_ratio: float = 1.55
var mine_shock_slow_value: float = 0.48
var mine_shock_slow_duration: float = 1.8
var mine_shock_interval: float = 0.35

func _spawn_line_effect(start: Vector2, end: Vector2) -> void:
	var spacing: float = max(20.0, mine_density_distance)
	_spawn_mines_on_segment(start, end, spacing, mine_auto_explode_time)

func _spawn_area_effect(polygon: PackedVector2Array) -> void:
	if polygon.size() < 3:
		return

	var spacing: float = max(24.0, mine_area_density)
	_spawn_mines_in_polygon(polygon, spacing)

func _spawn_mines_on_segment(start: Vector2, end: Vector2, spacing: float, delay: float) -> void:
	var segment: Vector2 = end - start
	var length: float = segment.length()
	if length <= 1.0:
		_schedule_mine(start, delay)
		return

	var count: int = max(1, int(floor(length / spacing)))
	for i in range(count + 1):
		var t: float = float(i) / float(count)
		var pos: Vector2 = start.lerp(end, t)
		_schedule_mine(pos, delay)

func _spawn_mines_in_polygon(polygon: PackedVector2Array, spacing: float) -> void:
	var min_x: float = INF
	var min_y: float = INF
	var max_x: float = -INF
	var max_y: float = -INF
	for p in polygon:
		min_x = min(min_x, p.x)
		min_y = min(min_y, p.y)
		max_x = max(max_x, p.x)
		max_y = max(max_y, p.y)

	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	var x: float = min_x
	var spawn_count: int = 0
	while x <= max_x:
		var y: float = min_y
		while y <= max_y:
			var point: Vector2 = Vector2(x, y)
			if Geometry2D.is_point_in_polygon(point, polygon):
				var jitter: Vector2 = Vector2(rng.randf_range(-9.0, 9.0), rng.randf_range(-9.0, 9.0))
				var explode_delay: float = rng.randf_range(0.25, 1.8)
				_schedule_mine(point + jitter, explode_delay)
				spawn_count += 1
			y += spacing
		x += spacing

	if spawn_count > 0:
		Global.spawn_floating_text(_polygon_center(polygon), "MINEFIELD!", Color(1.15, 0.78, 0.2))
		SoundManager.play("skill_q_closure_generic")

func _schedule_mine(pos: Vector2, delay: float) -> void:
	var clamped_delay: float = max(0.2, delay)
	var marker_polygon: PackedVector2Array = _build_circle_polygon(pos, max(8.0, mine_trigger_radius), 12)
	SkillEffectManager.create_area_effect({
		"polygon": marker_polygon,
		"damage": 0,
		"duration": clamped_delay,
		"color": Color(1.0, 0.8, 0.2, 0.35),
		"z_index": 20,
		"fade_in_duration": 0.05,
		"fade_out_duration": 0.12
	})

	var checker: Timer = Timer.new()
	checker.wait_time = 0.12
	checker.one_shot = false
	checker.set_meta("elapsed", 0.0)
	SkillEffectManager.add_child(checker)
	checker.timeout.connect(_on_mine_checker_timeout.bind(checker, pos, clamped_delay))
	checker.start()

func _explode_mine(pos: Vector2) -> void:
	var radius: float = max(8.0, mine_explosion_radius)
	var explosion_polygon: PackedVector2Array = _build_circle_polygon(pos, radius, 20)
	SkillEffectManager.create_area_effect({
		"polygon": explosion_polygon,
		"damage": mine_damage,
		"damage_interval": 0.1,
		"duration": 0.2,
		"color": Color(1.22, 0.45, 0.1, 0.62),
		"z_index": 25,
		"fade_in_duration": 0.03,
		"fade_out_duration": 0.1
	})

	SkillEffectManager.create_debuff_zone({
		"polygon": explosion_polygon,
		"duration": mine_shock_slow_duration,
		"debuff_type": "slow",
		"debuff_value": mine_shock_slow_value,
		"debuff_duration": mine_shock_slow_duration,
		"tick_interval": mine_shock_interval,
		"color": Color(1.0, 0.68, 0.2, 0.24)
	})

	var hit_count: int = 0
	var enemies: Array = get_tree().get_nodes_in_group("enemies")
	for enemy in enemies:
		if not is_instance_valid(enemy):
			continue
		if not enemy.has_node("HealthComponent"):
			continue
		var distance: float = float(enemy.global_position.distance_to(pos))
		if distance > radius:
			continue

		var health_component = enemy.get_node("HealthComponent")
		var final_damage: float = float(mine_damage)
		if distance <= mine_trigger_radius * 1.8:
			final_damage *= mine_inner_blast_ratio
		health_component.take_damage(int(round(final_damage)))
		Global.spawn_floating_text(enemy.global_position, "MINE!", Color(1.4, 0.55, 0.15))
		hit_count += 1

	if hit_count > 0:
		Global.on_camera_shake.emit(6.0 + float(hit_count), 0.16)

func _has_enemy_near(pos: Vector2, radius: float) -> bool:
	var enemies: Array = get_tree().get_nodes_in_group("enemies")
	for enemy in enemies:
		if not is_instance_valid(enemy):
			continue
		if enemy.global_position.distance_to(pos) <= radius:
			return true
	return false

func _build_circle_polygon(center: Vector2, radius: float, segments: int) -> PackedVector2Array:
	var points := PackedVector2Array()
	var seg_count: int = max(3, segments)
	for i in range(seg_count):
		var t: float = float(i) / float(seg_count)
		var angle: float = TAU * t
		points.append(center + Vector2(cos(angle), sin(angle)) * radius)
	return points

func _polygon_center(polygon: PackedVector2Array) -> Vector2:
	if polygon.is_empty():
		return Vector2.ZERO
	var center: Vector2 = Vector2.ZERO
	for p in polygon:
		center += p
	return center / float(polygon.size())

func _get_line_color() -> Color:
	return Color(1.0, 0.78, 0.25, 1.0)

func _get_closure_color() -> Color:
	return Color(1.3, 0.45, 0.15, 1.0)

func _on_mine_checker_timeout(checker: Timer, pos: Vector2, clamped_delay: float) -> void:
	if not is_instance_valid(checker):
		return
	var elapsed: float = float(checker.get_meta("elapsed", 0.0))
	elapsed += checker.wait_time
	checker.set_meta("elapsed", elapsed)
	if _has_enemy_near(pos, mine_trigger_radius) or elapsed >= clamped_delay:
		checker.stop()
		checker.queue_free()
		_explode_mine(pos)
