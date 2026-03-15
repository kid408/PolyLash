extends SkillQBase
class_name SkillRuneblazerQ

var wall_contact_damage: int = 15
var flame_wall_width: float = 18.0
var scorch_damage_amp: float = 0.25

var vent_spacing: float = 170.0
var vent_duration: float = 4.8
var vent_interval: float = 0.3
var vent_damage: int = 12
var vent_slow_value: float = 0.38

var fire_sea_damage: int = 40
var fire_sea_duration: float = 5.0
var burn_dot_value: float = 10.0
var burn_tick_interval: float = 0.5
var rain_pulse_count: int = 7
var rain_pulse_interval: float = 0.24
var rain_pulse_damage: int = 20
var reverse_wave_count: int = 4
var reverse_wave_interval: float = 0.14
var reverse_wave_damage: int = 13
var outer_wildfire_count: int = 7
var outer_wildfire_interval: float = 0.22
var outer_wildfire_damage: int = 19
var outer_wildfire_inner_ratio: float = 1.06
var outer_wildfire_outer_ratio: float = 1.48
var flame_lance_step_distance: float = 48.0
var flame_lance_tick_interval: float = 0.05
var flame_lance_hit_radius: float = 54.0
var flame_lance_damage: int = 17
var backdraft_delay: float = 0.2
var backdraft_step_count: int = 5
var backdraft_pull: float = 26.0
var collapse_strike_count: int = 6
var collapse_strike_interval: float = 0.16
var collapse_strike_damage: int = 22

const NEW_PYRO_META_CENTER: String = "runeblazer_fire_center"
const NEW_PYRO_META_RADIUS: String = "runeblazer_fire_radius"
const NEW_PYRO_META_EXPIRE_MSEC: String = "runeblazer_fire_expire_msec"

var _vent_points: Array[Vector2] = []

func _enter_planning_mode() -> void:
	_vent_points.clear()
	super._enter_planning_mode()

func _spawn_line_effect(start: Vector2, end: Vector2) -> void:
	SkillEffectManager.create_wall_effect({
		"start": start,
		"end": end,
		"width": flame_wall_width,
		"duration": _get_line_duration(),
		"block_enemies": true,
		"block_bullets": false,
		"contact_damage": wall_contact_damage,
		"contact_interval": 0.4,
		"color": Color(1.0, 0.42, 0.1, 0.85)
	})

	SkillEffectManager.create_debuff_zone({
		"start": start,
		"end": end,
		"width": 20.0,
		"duration": _get_line_duration(),
		"debuff_type": "damage_amp",
		"debuff_value": scorch_damage_amp,
		"debuff_duration": 2.0,
		"tick_interval": 0.4,
		"color": Color(1.0, 0.5, 0.18, 0.32)
	})

	var dir: Vector2 = (end - start).normalized()
	if dir.length_squared() <= 0.0001:
		dir = Vector2.RIGHT
	_spawn_vents_along_segment(start, end, dir)
	_spawn_reverse_flame_wave(start, end)
	_launch_flame_lance(start, end, dir)

func _spawn_area_effect(polygon: PackedVector2Array) -> void:
	if polygon.size() < 3:
		return
	SkillEffectManager.create_area_effect({
		"polygon": polygon,
		"damage": fire_sea_damage,
		"damage_interval": 0.35,
		"duration": fire_sea_duration,
		"color": Color(1.0, 0.32, 0.0, 0.5)
	})

	SkillEffectManager.create_debuff_zone({
		"polygon": polygon,
		"duration": fire_sea_duration,
		"debuff_type": "poison",
		"debuff_value": burn_dot_value,
		"debuff_duration": 2.5,
		"tick_interval": burn_tick_interval,
		"color": Color(1.0, 0.45, 0.0, 0.26)
	})

	_spawn_fire_rain(polygon)
	_spawn_outer_wildfire_ring(polygon)
	_spawn_collapse_ignition(polygon)
	_cache_fire_window(polygon, fire_sea_duration)

func _spawn_vents_along_segment(start: Vector2, end: Vector2, dir: Vector2) -> void:
	var seg: Vector2 = end - start
	var length: float = seg.length()
	if length <= 1.0:
		_deploy_vent_if_needed(start, dir)
		return
	var unit_dir: Vector2 = seg / length
	var spacing: float = float(max(60.0, vent_spacing))
	var cursor: float = 0.0
	while cursor <= length:
		_deploy_vent_if_needed(start + unit_dir * cursor, dir)
		cursor += spacing
	if fmod(length, spacing) > 20.0:
		_deploy_vent_if_needed(end, dir)

func _deploy_vent_if_needed(pos: Vector2, dir: Vector2) -> void:
	if _vent_points.is_empty():
		_vent_points.append(pos)
		_spawn_flame_vent(pos, dir)
		return
	var last_pos: Vector2 = _vent_points[_vent_points.size() - 1]
	if last_pos.distance_to(pos) < vent_spacing:
		return
	_vent_points.append(pos)
	_spawn_flame_vent(pos, dir)

func _spawn_flame_vent(pos: Vector2, dir: Vector2) -> void:
	var vent: Node2D = Node2D.new()
	vent.name = "NewPyroFlameVent"
	vent.global_position = pos
	add_child(vent)
	vent.add_to_group("player_skill_effects")

	var elapsed: float = 0.0
	var pulse_index: int = 0
	var timer: Timer = Timer.new()
	timer.wait_time = float(max(0.08, vent_interval))
	timer.one_shot = false
	vent.add_child(timer)
	timer.timeout.connect(func() -> void:
		if not is_instance_valid(vent):
			return
		elapsed += timer.wait_time
		if elapsed >= vent_duration:
			timer.stop()
			vent.queue_free()
			return
		_emit_vent_flame(vent.global_position, dir, pulse_index)
		pulse_index += 1
	)
	timer.start()

	spawn_skill_vfx(pos, Color(1.0, 0.55, 0.22, 0.74), 0.3)

func _emit_vent_flame(center: Vector2, dir: Vector2, pulse_index: int) -> void:
	var side: Vector2 = Vector2(-dir.y, dir.x)
	if side.length_squared() <= 0.0001:
		side = Vector2.UP
	var use_left: bool = (pulse_index % 2 == 0)
	var flame_dir: Vector2 = side
	if not use_left:
		flame_dir = -side
	var start: Vector2 = center
	var end: Vector2 = center + flame_dir * 130.0
	SkillEffectManager.create_line_effect({
		"start": start,
		"end": end,
		"width": 14.0,
		"damage": 0,
		"damage_interval": 0.2,
		"duration": 0.18,
		"color": Color(1.0, 0.62, 0.22, 0.9)
	})
	_apply_line_burst_damage(start, end, 12.0, vent_damage)

func _spawn_reverse_flame_wave(start: Vector2, finish: Vector2) -> void:
	var wave_total: int = int(max(1, reverse_wave_count))
	var wave_index: int = 0
	var host: Node2D = Node2D.new()
	host.name = "NewPyroReverseWaveHost"
	add_child(host)

	_emit_reverse_flame_wave(start, finish, wave_index, wave_total)
	wave_index += 1

	var timer: Timer = Timer.new()
	timer.wait_time = max(0.08, reverse_wave_interval)
	timer.one_shot = false
	host.add_child(timer)
	timer.timeout.connect(func() -> void:
		if not is_instance_valid(host):
			return
		if wave_index >= wave_total:
			timer.stop()
			host.queue_free()
			return
		_emit_reverse_flame_wave(start, finish, wave_index, wave_total)
		wave_index += 1
	)
	timer.start()

func _launch_flame_lance(start: Vector2, finish: Vector2, dir: Vector2) -> void:
	var seg: Vector2 = finish - start
	var length: float = seg.length()
	if length <= 1.0:
		return
	var move_dir: Vector2 = dir.normalized()
	if move_dir.length_squared() <= 0.001:
		move_dir = seg / length
	var host: Node2D = Node2D.new()
	host.name = "NewPyroFlameLanceHost"
	add_child(host)

	var step_total: int = int(max(2.0, ceil(length / max(12.0, flame_lance_step_distance))))
	var step_index: int = 0
	var timer: Timer = Timer.new()
	timer.wait_time = max(0.03, flame_lance_tick_interval)
	timer.one_shot = false
	host.add_child(timer)
	timer.timeout.connect(func() -> void:
		if not is_instance_valid(host):
			return
		if step_index > step_total:
			timer.stop()
			host.queue_free()
			_spawn_backdraft_recall(finish, start, move_dir)
			return
		_emit_flame_lance_tick(start, finish, step_index, step_total, move_dir)
		step_index += 1
	)
	timer.start()

func _spawn_backdraft_recall(from_pos: Vector2, to_pos: Vector2, move_dir: Vector2) -> void:
	var tree: SceneTree = get_tree()
	if tree == null:
		return
	tree.create_timer(max(0.05, backdraft_delay)).timeout.connect(func() -> void:
		if not is_inside_tree():
			return
		var host: Node2D = Node2D.new()
		host.name = "NewPyroBackdraftHost"
		add_child(host)
		var pulse_total: int = int(max(1, backdraft_step_count))
		var pulse_index: int = 0
		var timer: Timer = Timer.new()
		timer.wait_time = max(0.06, reverse_wave_interval * 0.9)
		timer.one_shot = false
		host.add_child(timer)
		timer.timeout.connect(func() -> void:
			if not is_instance_valid(host):
				return
			if pulse_index >= pulse_total:
				timer.stop()
				host.queue_free()
				return
			_emit_backdraft_pulse(from_pos, to_pos, pulse_index, pulse_total, move_dir)
			pulse_index += 1
		)
		timer.start()
	)

func _emit_flame_lance_tick(
	start: Vector2,
	finish: Vector2,
	index: int,
	total: int,
	move_dir: Vector2
) -> void:
	var t: float = float(index) / float(max(1, total))
	var prev_t: float = float(max(0, index - 1)) / float(max(1, total))
	var current: Vector2 = start.lerp(finish, t)
	var previous: Vector2 = start.lerp(finish, prev_t)
	SkillEffectManager.create_line_effect({
		"start": previous,
		"end": current,
		"width": 17.0,
		"damage": 0,
		"damage_interval": 0.2,
		"duration": 0.12,
		"color": Color(1.15, 0.72, 0.3, 0.96)
	})
	_apply_radius_hit(current, flame_lance_hit_radius, flame_lance_damage, 0.75)
	_apply_forward_push(current, flame_lance_hit_radius * 1.3, move_dir, 20.0)
	if index == total:
		spawn_skill_vfx(current, Color(1.2, 0.72, 0.3, 0.92), 0.45)

func _emit_backdraft_pulse(
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
	var start: Vector2 = center - tangent * 82.0
	var end: Vector2 = center + tangent * 82.0
	SkillEffectManager.create_line_effect({
		"start": start,
		"end": end,
		"width": 15.0,
		"damage": 0,
		"damage_interval": 0.2,
		"duration": 0.16,
		"color": Color(1.2, 0.84, 0.44, 0.94)
	})
	_apply_line_burst_damage(start, end, 14.0, reverse_wave_damage + 4)
	_apply_pull(center, flame_lance_hit_radius * 1.6, backdraft_pull)
	_apply_radius_hit(center, flame_lance_hit_radius * 0.8, max(1, reverse_wave_damage), 0.55)

func _emit_reverse_flame_wave(start: Vector2, finish: Vector2, index: int, total: int) -> void:
	var t: float = 0.0
	if total > 1:
		t = float(index) / float(total - 1)
	var center: Vector2 = finish.lerp(start, t)
	var dir: Vector2 = start - finish
	if dir.length_squared() <= 0.001:
		dir = Vector2.RIGHT
	else:
		dir = dir.normalized()
	var side: Vector2 = Vector2(-dir.y, dir.x)
	var seg_start: Vector2 = center - side * 70.0
	var seg_end: Vector2 = center + side * 70.0
	SkillEffectManager.create_line_effect({
		"start": seg_start,
		"end": seg_end,
		"width": 14.0,
		"damage": 0,
		"damage_interval": 0.2,
		"duration": 0.14,
		"color": Color(1.0, 0.72, 0.32, 0.88)
	})
	_apply_line_burst_damage(seg_start, seg_end, 12.0, reverse_wave_damage)

func _spawn_fire_rain(polygon: PackedVector2Array) -> void:
	var center: Vector2 = _polygon_center(polygon)
	var radius: float = _polygon_radius(polygon, center)
	var pulse_total: int = int(max(1, rain_pulse_count))
	var pulse_index: int = 0
	var host: Node2D = Node2D.new()
	host.name = "NewPyroFireRain"
	add_child(host)

	_emit_fire_rain_pulse(center, radius, pulse_index)
	pulse_index += 1

	var timer: Timer = Timer.new()
	timer.wait_time = float(max(0.08, rain_pulse_interval))
	timer.one_shot = false
	host.add_child(timer)
	timer.timeout.connect(func() -> void:
		if not is_instance_valid(host):
			return
		if pulse_index >= pulse_total:
			timer.stop()
			host.queue_free()
			return
		_emit_fire_rain_pulse(center, radius, pulse_index)
		pulse_index += 1
	)
	timer.start()

func _emit_fire_rain_pulse(center: Vector2, radius: float, index: int) -> void:
	var angle: float = TAU * float(index) / float(max(1, rain_pulse_count))
	var hit_center: Vector2 = center + Vector2.RIGHT.rotated(angle) * (radius * 0.55)
	var hit_poly: PackedVector2Array = _build_circle_polygon(hit_center, 80.0, 14)
	SkillEffectManager.create_area_effect({
		"polygon": hit_poly,
		"damage": rain_pulse_damage,
		"damage_interval": 0.1,
		"duration": 0.24,
		"color": Color(1.0, 0.48, 0.12, 0.4)
	})
	SkillEffectManager.create_debuff_zone({
		"polygon": hit_poly,
		"duration": 1.6,
		"debuff_type": "slow",
		"debuff_value": vent_slow_value,
		"debuff_duration": 1.0,
		"tick_interval": 0.3,
		"color": Color(0.95, 0.4, 0.08, 0.18)
	})

func _spawn_outer_wildfire_ring(polygon: PackedVector2Array) -> void:
	var center: Vector2 = _polygon_center(polygon)
	var radius: float = _polygon_radius(polygon, center)
	var pulse_total: int = int(max(1, outer_wildfire_count))
	var pulse_index: int = 0
	var host: Node2D = Node2D.new()
	host.name = "NewPyroOuterWildfireHost"
	add_child(host)

	_emit_outer_wildfire_pulse(center, radius, pulse_index, pulse_total)
	pulse_index += 1

	var timer: Timer = Timer.new()
	timer.wait_time = float(max(0.08, outer_wildfire_interval))
	timer.one_shot = false
	host.add_child(timer)
	timer.timeout.connect(func() -> void:
		if not is_instance_valid(host):
			return
		if pulse_index >= pulse_total:
			timer.stop()
			host.queue_free()
			return
		_emit_outer_wildfire_pulse(center, radius, pulse_index, pulse_total)
		pulse_index += 1
	)
	timer.start()

func _spawn_collapse_ignition(polygon: PackedVector2Array) -> void:
	var center: Vector2 = _polygon_center(polygon)
	var radius: float = _polygon_radius(polygon, center)
	var pulse_total: int = int(max(1, collapse_strike_count))
	var pulse_index: int = 0
	var host: Node2D = Node2D.new()
	host.name = "NewPyroCollapseIgnitionHost"
	add_child(host)

	var timer: Timer = Timer.new()
	timer.wait_time = float(max(0.08, collapse_strike_interval))
	timer.one_shot = false
	host.add_child(timer)
	timer.timeout.connect(func() -> void:
		if not is_instance_valid(host):
			return
		if pulse_index >= pulse_total:
			timer.stop()
			host.queue_free()
			return
		_emit_collapse_strike(center, radius, pulse_index, pulse_total)
		pulse_index += 1
	)
	timer.start()

func _emit_collapse_strike(center: Vector2, radius: float, index: int, total: int) -> void:
	var angle: float = TAU * float(index) / float(max(1, total))
	var dir: Vector2 = Vector2.RIGHT.rotated(angle)
	var start: Vector2 = center + dir * radius * 1.32
	var end: Vector2 = center - dir * radius * 0.1
	SkillEffectManager.create_line_effect({
		"start": start,
		"end": end,
		"width": 18.0,
		"damage": 0,
		"damage_interval": 0.2,
		"duration": 0.18,
		"color": Color(1.25, 0.92, 0.55, 0.92)
	})
	_apply_line_burst_damage(start, end, 15.0, collapse_strike_damage)
	_apply_radius_hit(center + dir * radius * 0.3, flame_lance_hit_radius, max(1, collapse_strike_damage - 5), 0.6)

func _emit_outer_wildfire_pulse(center: Vector2, radius: float, index: int, total: int) -> void:
	var angle: float = TAU * float(index) / float(max(1, total))
	var facing: Vector2 = Vector2.RIGHT.rotated(angle)
	var tangent: Vector2 = Vector2(-facing.y, facing.x)
	var band_center: Vector2 = center + facing * radius * 1.24
	var half_len: float = radius * 0.42
	var start: Vector2 = band_center - tangent * half_len
	var end: Vector2 = band_center + tangent * half_len
	SkillEffectManager.create_line_effect({
		"start": start,
		"end": end,
		"width": 16.0,
		"damage": 0,
		"damage_interval": 0.2,
		"duration": 0.16,
		"color": Color(1.0, 0.74, 0.35, 0.92)
	})
	_apply_outer_wildfire_band(
		center,
		radius * max(1.02, outer_wildfire_inner_ratio),
		radius * max(1.14, outer_wildfire_outer_ratio),
		facing,
		cos(deg_to_rad(20.0)),
		outer_wildfire_damage
	)

func _apply_outer_wildfire_band(
	center: Vector2,
	inner_radius: float,
	outer_radius: float,
	facing: Vector2,
	dot_min: float,
	damage: int
) -> void:
	var enemies: Array = get_tree().get_nodes_in_group("enemies")
	var safe_facing: Vector2 = facing.normalized()
	for enemy_obj: Variant in enemies:
		if enemy_obj == null or not is_instance_valid(enemy_obj):
			continue
		if not (enemy_obj is Node2D):
			continue
		var enemy: Node2D = enemy_obj
		var offset: Vector2 = enemy.global_position - center
		var dist: float = offset.length()
		if dist < inner_radius or dist > outer_radius:
			continue
		if dist <= 0.001:
			continue
		var dir_norm: Vector2 = offset / dist
		if dir_norm.dot(safe_facing) < dot_min:
			continue
		_apply_damage(enemy, max(1, damage))
		_apply_status(enemy, "burn", 1.6, max(2.0, float(damage) * 0.32), 1, 0.5)
		_apply_status(enemy, "slow", 0.8, vent_slow_value, 1, 0.1)

func _apply_radius_hit(center: Vector2, radius: float, damage: int, slow_scale: float) -> void:
	var enemies: Array = get_tree().get_nodes_in_group("enemies")
	for enemy_obj: Variant in enemies:
		if enemy_obj == null or not is_instance_valid(enemy_obj):
			continue
		if not (enemy_obj is Node2D):
			continue
		var enemy: Node2D = enemy_obj
		if enemy.global_position.distance_to(center) > radius:
			continue
		_apply_damage(enemy, max(1, damage))
		_apply_status(enemy, "burn", 1.4, max(2.0, float(damage) * 0.28), 1, 0.5)
		_apply_status(enemy, "slow", 0.8, vent_slow_value * slow_scale, 1, 0.1)

func _apply_forward_push(center: Vector2, radius: float, dir: Vector2, push_amount: float) -> void:
	var safe_dir: Vector2 = dir.normalized()
	if safe_dir.length_squared() <= 0.001:
		return
	var enemies: Array = get_tree().get_nodes_in_group("enemies")
	for enemy_obj: Variant in enemies:
		if enemy_obj == null or not is_instance_valid(enemy_obj):
			continue
		if not (enemy_obj is Node2D):
			continue
		var enemy: Node2D = enemy_obj
		if enemy.global_position.distance_to(center) > radius:
			continue
		enemy.global_position += safe_dir * push_amount

func _apply_pull(center: Vector2, radius: float, pull_amount: float) -> void:
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

func _apply_line_burst_damage(start: Vector2, end: Vector2, hit_radius: float, damage: int) -> void:
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
		_apply_damage(enemy, damage)
		_apply_status(enemy, "slow", 0.8, vent_slow_value, 1, 0.1)

func _build_circle_polygon(center: Vector2, radius: float, segments: int) -> PackedVector2Array:
	var points: PackedVector2Array = PackedVector2Array()
	var segment_count: int = int(max(8, segments))
	for i: int in range(segment_count):
		var ang: float = TAU * float(i) / float(segment_count)
		points.append(center + Vector2.RIGHT.rotated(ang) * radius)
	return points

func _cache_fire_window(polygon: PackedVector2Array, duration: float) -> void:
	if not is_instance_valid(skill_owner):
		return
	var center: Vector2 = _polygon_center(polygon)
	var radius: float = _polygon_radius(polygon, center)
	var expire_msec: int = Time.get_ticks_msec() + int(round(float(max(0.2, duration)) * 1000.0))
	skill_owner.set_meta(NEW_PYRO_META_CENTER, center)
	skill_owner.set_meta(NEW_PYRO_META_RADIUS, radius)
	skill_owner.set_meta(NEW_PYRO_META_EXPIRE_MSEC, expire_msec)

func _polygon_center(polygon: PackedVector2Array) -> Vector2:
	if polygon.is_empty():
		return Vector2.ZERO
	var center: Vector2 = Vector2.ZERO
	for point: Vector2 in polygon:
		center += point
	return center / float(polygon.size())

func _polygon_radius(polygon: PackedVector2Array, center: Vector2) -> float:
	var radius: float = 0.0
	for point: Vector2 in polygon:
		radius = float(max(radius, center.distance_to(point)))
	return float(max(8.0, radius))

func _apply_damage(enemy: Node2D, amount: int) -> void:
	if not enemy.has_node("HealthComponent"):
		return
	var hc: Node = enemy.get_node("HealthComponent")
	if hc != null and hc.has_method("take_damage"):
		hc.call("take_damage", max(1, amount))

func _apply_status(enemy: Node2D, status_name: String, duration: float, value: float, stacks: int = 1, tick_interval: float = 0.6) -> void:
	if enemy.has_method("apply_status"):
		var safe_duration: float = float(max(0.1, duration))
		var safe_stacks: int = int(max(1, stacks))
		var safe_tick_interval: float = float(max(0.05, tick_interval))
		enemy.call("apply_status", status_name, safe_duration, value, safe_stacks, safe_tick_interval)

func _get_line_color() -> Color:
	return Color(1.0, 0.42, 0.1, 1.0)

func _get_closure_color() -> Color:
	return Color(1.0, 0.3, 0.0, 1.0)

