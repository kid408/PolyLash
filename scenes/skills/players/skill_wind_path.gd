extends SkillDrawingBase
class_name SkillWindPath

# Core parameters from config/player/skill_params_wide.csv (skill_wind_path).
var wind_wall_pull_force: float = 350.0
var wind_wall_damage: int = 15
var storm_zone_damage: int = 30
var wind_wall_duration: float = 3.0
var wind_wall_width: float = 24.0
var wind_wall_effect_radius: float = 120.0
var storm_zone_pull_force: float = 400.0
var storm_zone_duration: float = 3.0

# Extra tuning for new drawing framework implementation.
var wind_cut_damage: int = 18
var storm_slow_value: float = 0.36
var return_gust_delay: float = 0.32
var return_damage_ratio: float = 1.25
var return_pull_force: float = 620.0
var storm_outer_push_force: float = 420.0
var storm_second_burst_delay: float = 0.38
var gale_spear_step_distance: float = 52.0
var gale_spear_tick_interval: float = 0.05
var gale_spear_hit_radius: float = 56.0
var gale_spear_damage: int = 18
var gale_spear_push: float = 22.0
var gale_recall_delay: float = 0.2
var gale_recall_count: int = 5
var gale_recall_damage: int = 20
var gale_recall_pull: float = 26.0
var storm_reel_count: int = 6
var storm_reel_interval: float = 0.16
var storm_reel_damage: int = 22
const WIND_ACTIVE_META: String = "wind_path_active_until_msec"

func _spawn_line_effect(start: Vector2, end: Vector2) -> void:
	var duration: float = max(_get_line_duration(), wind_wall_duration)
	_mark_wind_active(duration)
	SkillEffectManager.create_line_effect({
		"start": start,
		"end": end,
		"width": wind_wall_width,
		"damage": wind_wall_damage,
		"damage_interval": 0.28,
		"duration": duration,
		"color": Color(0.24, 1.38, 1.45, 0.88),
		"pull_to_line": true,
		"pull_force": wind_wall_pull_force,
		"pull_interval": 0.05
	})

	SkillEffectManager.create_debuff_zone({
		"start": start,
		"end": end,
		"width": wind_wall_width + 8.0,
		"duration": duration,
		"debuff_type": "slow",
		"debuff_value": storm_slow_value * 0.75,
		"debuff_duration": 1.0,
		"tick_interval": 0.35,
		"color": Color(0.22, 1.1, 1.2, 0.2)
	})

	_apply_wind_cut(start, end)
	_launch_gale_spear(start, end)
	var back_delay: float = max(0.08, return_gust_delay)
	get_tree().create_timer(back_delay).timeout.connect(
		_on_return_gust_timeout.bind(start, end, duration)
	)

func _spawn_area_effect(polygon: PackedVector2Array) -> void:
	if polygon.size() < 3:
		return

	var duration: float = max(2.8, storm_zone_duration)
	_mark_wind_active(duration + storm_second_burst_delay + 0.2)
	SkillEffectManager.create_area_effect({
		"polygon": polygon,
		"damage": storm_zone_damage,
		"damage_interval": 0.32,
		"duration": duration,
		"color": Color(0.18, 1.1, 1.15, 0.5),
		"pull_to_center": true,
		"pull_force": storm_zone_pull_force,
		"pull_interval": 0.05
	})

	SkillEffectManager.create_debuff_zone({
		"polygon": polygon,
		"duration": duration,
		"debuff_type": "slow",
		"debuff_value": storm_slow_value,
		"debuff_duration": 1.2,
		"tick_interval": 0.35,
		"color": Color(0.22, 1.0, 1.0, 0.22)
	})

	SkillEffectManager.create_debuff_zone({
		"polygon": polygon,
		"duration": duration,
		"debuff_type": "marked",
		"debuff_value": 0.14,
		"debuff_duration": 1.0,
		"tick_interval": 0.5,
		"color": Color(0.26, 1.1, 1.15, 0.15)
	})

	_apply_storm_burst(polygon)
	var center: Vector2 = _polygon_center(polygon)
	var radius: float = _max_distance_to_center(polygon, center)
	_spawn_storm_reel(center, radius)
	var second_delay: float = max(0.08, storm_second_burst_delay)
	get_tree().create_timer(second_delay).timeout.connect(
		_on_storm_second_burst_timeout.bind(PackedVector2Array(polygon))
	)

func _launch_gale_spear(start: Vector2, finish: Vector2) -> void:
	var seg: Vector2 = finish - start
	var length: float = seg.length()
	if length <= 1.0:
		return
	var move_dir: Vector2 = seg / length
	var host: Node2D = Node2D.new()
	host.name = "WindGaleSpearHost"
	add_child(host)

	var step_total: int = int(max(2.0, ceil(length / max(12.0, gale_spear_step_distance))))
	var step_index: int = 0
	var timer: Timer = Timer.new()
	timer.wait_time = max(0.03, gale_spear_tick_interval)
	timer.one_shot = false
	host.add_child(timer)
	timer.timeout.connect(func() -> void:
		if not is_instance_valid(host):
			return
		if step_index > step_total:
			timer.stop()
			host.queue_free()
			_spawn_gale_recall(finish, start, move_dir)
			return
		_emit_gale_spear_tick(start, finish, step_index, step_total, move_dir)
		step_index += 1
	)
	timer.start()

func _spawn_gale_recall(from_pos: Vector2, to_pos: Vector2, move_dir: Vector2) -> void:
	var tree: SceneTree = get_tree()
	if tree == null:
		return
	tree.create_timer(max(0.05, gale_recall_delay)).timeout.connect(func() -> void:
		if not is_inside_tree():
			return
		var host: Node2D = Node2D.new()
		host.name = "WindGaleRecallHost"
		add_child(host)
		var pulse_total: int = int(max(1, gale_recall_count))
		var pulse_index: int = 0
		var timer: Timer = Timer.new()
		timer.wait_time = max(0.06, storm_reel_interval * 0.8)
		timer.one_shot = false
		host.add_child(timer)
		timer.timeout.connect(func() -> void:
			if not is_instance_valid(host):
				return
			if pulse_index >= pulse_total:
				timer.stop()
				host.queue_free()
				return
			_emit_gale_recall_tick(from_pos, to_pos, pulse_index, pulse_total, move_dir)
			pulse_index += 1
		)
		timer.start()
	)

func _emit_gale_spear_tick(start: Vector2, finish: Vector2, index: int, total: int, move_dir: Vector2) -> void:
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
		"color": Color(0.72, 1.45, 1.52, 0.9)
	})
	_apply_radius_push_damage(current, gale_spear_hit_radius, gale_spear_damage, move_dir, gale_spear_push)

func _emit_gale_recall_tick(
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
	var start: Vector2 = center - tangent * 74.0
	var end: Vector2 = center + tangent * 74.0
	SkillEffectManager.create_line_effect({
		"start": start,
		"end": end,
		"width": 14.0,
		"damage": 0,
		"damage_interval": 0.2,
		"duration": 0.16,
		"color": Color(0.84, 1.52, 1.58, 0.92)
	})
	_apply_line_damage_and_pull(start, end, 12.0, gale_recall_damage, center, gale_recall_pull)

func _on_return_gust_timeout(start: Vector2, end: Vector2, duration: float) -> void:
	SkillEffectManager.create_line_effect({
		"start": end,
		"end": start,
		"width": max(14.0, wind_wall_width * 0.74),
		"damage": max(1, int(round(float(wind_wall_damage) * return_damage_ratio))),
		"damage_interval": 0.22,
		"duration": max(0.5, duration * 0.48),
		"color": Color(0.58, 1.35, 1.42, 0.84),
		"pull_to_line": true,
		"pull_force": max(wind_wall_pull_force, return_pull_force),
		"pull_interval": 0.045
	})
	_apply_return_cut(start, end)

func _on_storm_second_burst_timeout(polygon: PackedVector2Array) -> void:
	if polygon.size() < 3:
		return
	var center: Vector2 = _polygon_center(polygon)
	var hit_count: int = 0
	var enemies: Array = get_tree().get_nodes_in_group("enemies")
	for enemy_obj: Variant in enemies:
		if enemy_obj == null or not is_instance_valid(enemy_obj):
			continue
		if not (enemy_obj is Node2D):
			continue
		var enemy: Node2D = enemy_obj
		if not Geometry2D.is_point_in_polygon(enemy.global_position, polygon):
			continue
		var outward: Vector2 = (enemy.global_position - center).normalized()
		if outward == Vector2.ZERO:
			outward = Vector2.RIGHT
		if enemy.has_method("apply_knockback"):
			enemy.call("apply_knockback", outward, storm_outer_push_force)
		if enemy.has_node("HealthComponent"):
			var hc: Node = enemy.get_node("HealthComponent")
			if hc != null and hc.has_method("take_damage"):
				hc.call("take_damage", max(1, int(round(float(storm_zone_damage) * 0.66))))
		_apply_secondary_mark(enemy)
		hit_count += 1
	if hit_count > 0:
		Global.spawn_floating_text(center, "GALE PUSH", Color(0.72, 1.35, 1.45))
		spawn_skill_vfx(center, Color(0.62, 1.25, 1.35, 0.82), 0.52)
		Global.on_camera_shake.emit(5.8, 0.1)

func _spawn_storm_reel(center: Vector2, radius: float) -> void:
	var sweep_total: int = int(max(1, storm_reel_count))
	var sweep_index: int = 0
	var host: Node2D = Node2D.new()
	host.name = "WindStormReelHost"
	add_child(host)

	var timer: Timer = Timer.new()
	timer.wait_time = max(0.08, storm_reel_interval)
	timer.one_shot = false
	host.add_child(timer)
	timer.timeout.connect(func() -> void:
		if not is_instance_valid(host):
			return
		if sweep_index >= sweep_total:
			timer.stop()
			host.queue_free()
			return
		_emit_storm_reel(center, radius, sweep_index, sweep_total)
		sweep_index += 1
	)
	timer.start()

func _emit_storm_reel(center: Vector2, radius: float, index: int, total: int) -> void:
	var angle: float = TAU * float(index) / float(max(1, total))
	var dir: Vector2 = Vector2.RIGHT.rotated(angle)
	var start: Vector2 = center + dir * radius * 1.35
	var end: Vector2 = center - dir * radius * 0.1
	SkillEffectManager.create_line_effect({
		"start": start,
		"end": end,
		"width": max(14.0, wind_wall_width * 0.66),
		"damage": 0,
		"damage_interval": 0.2,
		"duration": 0.18,
		"color": Color(0.9, 1.58, 1.62, 0.9)
	})
	_apply_line_damage_and_pull(start, end, 12.0, storm_reel_damage, center, gale_recall_pull * 0.8)

func _apply_wind_cut(start: Vector2, end: Vector2) -> void:
	var cut_radius: float = max(20.0, wind_wall_effect_radius * 0.35)
	var damage: int = max(1, int(round(float(wind_cut_damage) * 0.7)))
	var enemies: Array = get_tree().get_nodes_in_group("enemies")
	for enemy_obj: Variant in enemies:
		if enemy_obj == null or not is_instance_valid(enemy_obj):
			continue
		if not (enemy_obj is Node2D):
			continue
		var enemy: Node2D = enemy_obj
		var closest: Vector2 = Geometry2D.get_closest_point_to_segment(enemy.global_position, start, end)
		if enemy.global_position.distance_to(closest) > cut_radius:
			continue
		if enemy.has_node("HealthComponent"):
			var hc: Node = enemy.get_node("HealthComponent")
			if hc != null and hc.has_method("take_damage"):
				hc.call("take_damage", damage)

func _apply_return_cut(start: Vector2, end: Vector2) -> void:
	var cut_radius: float = max(18.0, wind_wall_effect_radius * 0.4)
	var damage: int = max(1, int(round(float(wind_cut_damage) * return_damage_ratio)))
	var center: Vector2 = (start + end) * 0.5
	var enemies: Array = get_tree().get_nodes_in_group("enemies")
	for enemy_obj: Variant in enemies:
		if enemy_obj == null or not is_instance_valid(enemy_obj):
			continue
		if not (enemy_obj is Node2D):
			continue
		var enemy: Node2D = enemy_obj
		var closest: Vector2 = Geometry2D.get_closest_point_to_segment(enemy.global_position, end, start)
		if enemy.global_position.distance_to(closest) > cut_radius:
			continue
		if enemy.has_node("HealthComponent"):
			var hc: Node = enemy.get_node("HealthComponent")
			if hc != null and hc.has_method("take_damage"):
				hc.call("take_damage", damage)
		if enemy.has_method("apply_knockback"):
			var inward: Vector2 = (center - enemy.global_position).normalized()
			enemy.call("apply_knockback", inward, return_pull_force * 0.55)
		_apply_secondary_mark(enemy)

func _apply_radius_push_damage(center: Vector2, radius: float, damage: int, move_dir: Vector2, push_amount: float) -> void:
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
			enemy.call("apply_status", "slow", 0.8, storm_slow_value * 0.8, 1, 0.1)
		enemy.global_position += safe_dir * push_amount

func _apply_line_damage_and_pull(
	start: Vector2,
	end: Vector2,
	hit_radius: float,
	damage: int,
	pull_center: Vector2,
	pull_amount: float
) -> void:
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
		var offset: Vector2 = pull_center - enemy.global_position
		var dist: float = offset.length()
		if dist > 0.001:
			enemy.global_position += offset / dist * pull_amount
		_apply_secondary_mark(enemy)

func _apply_storm_burst(polygon: PackedVector2Array) -> void:
	var center: Vector2 = _polygon_center(polygon)
	var radius: float = _max_distance_to_center(polygon, center)
	var damage: int = max(1, wind_cut_damage)
	var hit_count: int = 0
	var enemies: Array = get_tree().get_nodes_in_group("enemies")
	for enemy_obj: Variant in enemies:
		if enemy_obj == null or not is_instance_valid(enemy_obj):
			continue
		if not (enemy_obj is Node2D):
			continue
		var enemy: Node2D = enemy_obj
		if enemy.global_position.distance_to(center) > radius:
			continue
		if not Geometry2D.is_point_in_polygon(enemy.global_position, polygon):
			continue
		if enemy.has_node("HealthComponent"):
			var hc: Node = enemy.get_node("HealthComponent")
			if hc != null and hc.has_method("take_damage"):
				hc.call("take_damage", damage)
		if enemy.has_method("apply_status"):
			enemy.call("apply_status", "slow", 0.9, storm_slow_value * 0.8)
		_apply_secondary_mark(enemy)
		hit_count += 1
	if hit_count > 0:
		Global.spawn_floating_text(center, "WIND BURST", Color(0.55, 1.25, 1.35))
		spawn_skill_vfx(center, Color(0.5, 1.2, 1.3, 0.85), 0.58)

func _apply_secondary_mark(enemy: Node2D) -> void:
	if enemy.has_method("apply_status"):
		enemy.call("apply_status", "marked", 1.05, 0.12, 1, 0.2)

func _polygon_center(polygon: PackedVector2Array) -> Vector2:
	if polygon.is_empty():
		return Vector2.ZERO
	var center: Vector2 = Vector2.ZERO
	for point: Vector2 in polygon:
		center += point
	return center / float(polygon.size())

func _max_distance_to_center(polygon: PackedVector2Array, center: Vector2) -> float:
	var max_dist: float = 0.0
	for point: Vector2 in polygon:
		max_dist = max(max_dist, center.distance_to(point))
	return max_dist

func _get_line_color() -> Color:
	return Color(0.28, 1.4, 1.5, 1.0)

func _get_closure_color() -> Color:
	return Color(0.6, 1.25, 1.3, 1.0)

func _mark_wind_active(duration: float) -> void:
	if not is_instance_valid(skill_owner):
		return
	var expire_msec: int = Time.get_ticks_msec() + int(round(max(0.2, duration) * 1000.0))
	skill_owner.set_meta(WIND_ACTIVE_META, expire_msec)
