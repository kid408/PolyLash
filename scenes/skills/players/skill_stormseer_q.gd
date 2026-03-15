extends SkillQBase
class_name SkillStormseerQ

var speed_boost_value: float = 0.55
var buff_duration: float = 4.0
var pull_damage: int = 24
var pull_force: float = 360.0
var area_duration: float = 5.5
var wind_cut_damage: int = 14
var storm_slow_value: float = 0.35
var gate_spacing: float = 170.0
var gate_radius: float = 96.0
var gate_duration: float = 4.6
var gate_pulse_interval: float = 0.28
var gate_push_strength: float = 44.0
var gate_pulse_damage: int = 11
var orbit_slash_count: int = 7
var orbit_slash_interval: float = 0.22
var orbit_slash_damage: int = 20
var orbit_slash_width: float = 26.0
var lance_step_distance: float = 52.0
var lance_tick_interval: float = 0.05
var lance_hit_radius: float = 56.0
var lance_line_damage: int = 18
var lance_push: float = 22.0
var lance_recall_delay: float = 0.2
var lance_recall_count: int = 5
var lance_recall_damage: int = 22
var lance_recall_pull: float = 28.0
var closure_backspin_count: int = 6
var closure_backspin_interval: float = 0.16
var closure_backspin_damage: int = 20

const STORMSEER_META_CENTER: String = "stormseer_eye_center"
const STORMSEER_META_RADIUS: String = "stormseer_eye_radius"
const STORMSEER_META_EXPIRE_MSEC: String = "stormseer_eye_expire_msec"

var _gate_points: Array[Vector2] = []

func _enter_planning_mode() -> void:
	_gate_points.clear()
	super._enter_planning_mode()

func _spawn_line_effect(start: Vector2, end: Vector2) -> void:
	SkillEffectManager.create_buff_zone({
		"start": start,
		"end": end,
		"width": 48.0,
		"duration": _get_line_duration(),
		"buff_type": "speed_boost",
		"buff_value": speed_boost_value,
		"tick_interval": 0.45,
		"color": Color(0.3, 0.9, 0.8, 0.5)
	})

	SkillEffectManager.create_debuff_zone({
		"start": start,
		"end": end,
		"width": 20.0,
		"duration": _get_line_duration(),
		"debuff_type": "slow",
		"debuff_value": storm_slow_value,
		"debuff_duration": 1.6,
		"tick_interval": 0.45,
		"damage": wind_cut_damage,
		"damage_interval": 0.45,
		"color": Color(0.26, 0.82, 0.76, 0.25)
	})

	var dir: Vector2 = (end - start).normalized()
	if dir.length_squared() <= 0.0001:
		dir = Vector2.RIGHT
	_launch_storm_lance(start, end, dir)
	_deploy_gate_if_needed(start, dir)
	_deploy_gate_if_needed(end, dir)
	_spawn_line_wind_cut(start, end)

func _spawn_area_effect(polygon: PackedVector2Array) -> void:
	if polygon.size() < 3:
		return

	SkillEffectManager.create_area_effect({
		"polygon": polygon,
		"damage": pull_damage,
		"damage_interval": 0.4,
		"duration": area_duration,
		"color": Color(0.2, 0.8, 0.7, 0.5),
		"pull_to_center": true,
		"pull_force": pull_force
	})

	SkillEffectManager.create_debuff_zone({
		"polygon": polygon,
		"duration": area_duration,
		"debuff_type": "slow",
		"debuff_value": float(min(0.7, storm_slow_value + 0.2)),
		"debuff_duration": 1.5,
		"tick_interval": 0.4,
		"color": Color(0.18, 0.65, 0.62, 0.2)
	})

	_spawn_orbit_slashes(polygon)
	_spawn_closure_backspin(polygon)
	_cache_stormseer_window(polygon, area_duration)

func _launch_storm_lance(start: Vector2, finish: Vector2, move_dir: Vector2) -> void:
	var seg: Vector2 = finish - start
	var length: float = seg.length()
	if length <= 1.0:
		return
	var safe_move_dir: Vector2 = move_dir.normalized()
	if safe_move_dir.length_squared() <= 0.0001:
		safe_move_dir = Vector2.RIGHT
	var host: Node2D = Node2D.new()
	host.name = "TempestStormLanceHost"
	add_child(host)

	var step_total: int = int(max(2.0, ceil(length / max(12.0, lance_step_distance))))
	var step_index: int = 0
	var timer: Timer = Timer.new()
	timer.wait_time = max(0.03, lance_tick_interval)
	timer.one_shot = false
	host.add_child(timer)
	timer.timeout.connect(func() -> void:
		if not is_instance_valid(host):
			return
		if step_index > step_total:
			timer.stop()
			host.queue_free()
			_spawn_lance_recall(finish, start, safe_move_dir)
			return
		_emit_storm_lance_tick(start, finish, step_index, step_total, safe_move_dir)
		step_index += 1
	)
	timer.start()

func _spawn_lance_recall(from_pos: Vector2, to_pos: Vector2, move_dir: Vector2) -> void:
	var tree: SceneTree = get_tree()
	if tree == null:
		return
	tree.create_timer(max(0.05, lance_recall_delay)).timeout.connect(func() -> void:
		if not is_inside_tree():
			return
		var host: Node2D = Node2D.new()
		host.name = "TempestStormLanceRecallHost"
		add_child(host)
		var pulse_total: int = int(max(1, lance_recall_count))
		var pulse_index: int = 0
		var timer: Timer = Timer.new()
		timer.wait_time = max(0.06, lance_tick_interval * 1.6)
		timer.one_shot = false
		host.add_child(timer)
		timer.timeout.connect(func() -> void:
			if not is_instance_valid(host):
				return
			if pulse_index >= pulse_total:
				timer.stop()
				host.queue_free()
				return
			_emit_lance_recall_tick(from_pos, to_pos, pulse_index, pulse_total, move_dir)
			pulse_index += 1
		)
		timer.start()
	)

func _emit_storm_lance_tick(start: Vector2, finish: Vector2, index: int, total: int, move_dir: Vector2) -> void:
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
		"color": Color(0.58, 1.0, 0.92, 0.93)
	})
	_apply_radius_damage_and_slow(current, lance_hit_radius, lance_line_damage)
	_apply_direction_push(current, lance_hit_radius * 1.18, move_dir, lance_push)

func _emit_lance_recall_tick(
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
		"width": 13.0,
		"damage": 0,
		"damage_interval": 0.2,
		"duration": 0.16,
		"color": Color(0.82, 1.0, 0.96, 0.92)
	})
	_apply_line_burst_damage(start, end, 12.0, lance_recall_damage, false)
	_apply_pull_to_point(center, lance_hit_radius * 1.6, lance_recall_pull)

func _spawn_closure_backspin(polygon: PackedVector2Array) -> void:
	var center: Vector2 = _calculate_polygon_center(polygon)
	var radius: float = _polygon_radius(polygon, center)
	var spin_total: int = int(max(1, closure_backspin_count))
	var spin_index: int = 0
	var host: Node2D = Node2D.new()
	host.name = "TempestClosureBackspinHost"
	add_child(host)

	var timer: Timer = Timer.new()
	timer.wait_time = max(0.08, closure_backspin_interval)
	timer.one_shot = false
	host.add_child(timer)
	timer.timeout.connect(func() -> void:
		if not is_instance_valid(host):
			return
		if spin_index >= spin_total:
			timer.stop()
			host.queue_free()
			return
		_emit_closure_backspin(center, radius, spin_index, spin_total)
		spin_index += 1
	)
	timer.start()

func _emit_closure_backspin(center: Vector2, radius: float, index: int, total: int) -> void:
	var angle: float = TAU * float(index) / float(max(1, total))
	var facing: Vector2 = Vector2.RIGHT.rotated(angle)
	var tangent: Vector2 = Vector2(-facing.y, facing.x)
	var ring_center: Vector2 = center + facing * radius * 1.12
	var start: Vector2 = ring_center - tangent * radius * 0.44
	var end: Vector2 = ring_center + tangent * radius * 0.44
	SkillEffectManager.create_line_effect({
		"start": start,
		"end": end,
		"width": orbit_slash_width * 0.78,
		"damage": 0,
		"damage_interval": 0.2,
		"duration": 0.2,
		"color": Color(0.68, 1.0, 0.95, 0.9)
	})
	_apply_line_burst_damage(start, end, 13.0, closure_backspin_damage, false)
	_apply_pull_to_point(center, radius * 1.02, lance_recall_pull * 0.6)
	_apply_radius_damage_and_slow(center, radius * 0.24, int(max(1, closure_backspin_damage * 0.25)))

func _spawn_line_wind_cut(start: Vector2, end: Vector2) -> void:
	SkillEffectManager.create_line_effect({
		"start": start,
		"end": end,
		"width": 10.0,
		"damage": 0,
		"damage_interval": 0.2,
		"duration": 0.2,
		"color": Color(0.4, 0.95, 0.86, 0.8)
	})
	_apply_line_burst_damage(start, end, 18.0, gate_pulse_damage, false)

func _deploy_gate_if_needed(pos: Vector2, dir: Vector2) -> void:
	if _gate_points.is_empty():
		_gate_points.append(pos)
		_spawn_stream_gate(pos, dir)
		return
	var last_pos: Vector2 = _gate_points[_gate_points.size() - 1]
	if last_pos.distance_to(pos) < gate_spacing:
		return
	_gate_points.append(pos)
	_spawn_stream_gate(pos, dir)

func _spawn_stream_gate(center: Vector2, dir: Vector2) -> void:
	var gate: Node2D = Node2D.new()
	gate.name = "TempestStreamGate"
	gate.global_position = center
	add_child(gate)
	gate.add_to_group("player_skill_effects")

	var elapsed: float = 0.0
	var timer: Timer = Timer.new()
	timer.wait_time = max(0.08, gate_pulse_interval)
	timer.one_shot = false
	gate.add_child(timer)
	timer.timeout.connect(func() -> void:
		if not is_instance_valid(gate):
			return
		elapsed += timer.wait_time
		if elapsed >= gate_duration:
			timer.stop()
			gate.queue_free()
			return
		_emit_gate_pulse(gate.global_position, dir)
	)
	timer.start()

	spawn_skill_vfx(center, Color(0.44, 0.95, 0.85, 0.72), 0.34)

func _emit_gate_pulse(center: Vector2, dir: Vector2) -> void:
	var side: Vector2 = Vector2(-dir.y, dir.x)
	var start: Vector2 = center - side * gate_radius * 0.75
	var end: Vector2 = center + side * gate_radius * 0.75
	SkillEffectManager.create_line_effect({
		"start": start,
		"end": end,
		"width": 12.0,
		"damage": 0,
		"damage_interval": 0.2,
		"duration": 0.18,
		"color": Color(0.45, 0.95, 0.86, 0.82)
	})
	var enemies: Array = get_tree().get_nodes_in_group("enemies")
	for enemy_obj: Variant in enemies:
		if enemy_obj == null or not is_instance_valid(enemy_obj):
			continue
		if not (enemy_obj is Node2D):
			continue
		var enemy: Node2D = enemy_obj
		if enemy.global_position.distance_to(center) > gate_radius:
			continue
		enemy.global_position += dir * gate_push_strength
		_apply_damage(enemy, gate_pulse_damage)
		_apply_status(enemy, "slow", 0.9, float(storm_slow_value + 0.05), 1, 0.1)

func _spawn_orbit_slashes(polygon: PackedVector2Array) -> void:
	var center: Vector2 = _calculate_polygon_center(polygon)
	var radius: float = _polygon_radius(polygon, center)
	var slash_total: int = int(max(1, orbit_slash_count))
	var slash_index: int = 0
	var host: Node2D = Node2D.new()
	host.name = "TempestOrbitSlashes"
	add_child(host)

	_fire_orbit_slash(center, radius, slash_index, slash_total)
	slash_index += 1

	var timer: Timer = Timer.new()
	timer.wait_time = max(0.08, orbit_slash_interval)
	timer.one_shot = false
	host.add_child(timer)
	timer.timeout.connect(func() -> void:
		if not is_instance_valid(host):
			return
		if slash_index >= slash_total:
			timer.stop()
			host.queue_free()
			return
		_fire_orbit_slash(center, radius, slash_index, slash_total)
		slash_index += 1
	)
	timer.start()

func _fire_orbit_slash(center: Vector2, radius: float, index: int, total: int) -> void:
	var angle: float = TAU * float(index) / float(max(1, total))
	var dir: Vector2 = Vector2.RIGHT.rotated(angle)
	var start: Vector2 = center + dir * (radius + 84.0)
	var end: Vector2 = center - dir * (radius * 0.45)
	SkillEffectManager.create_line_effect({
		"start": start,
		"end": end,
		"width": orbit_slash_width,
		"damage": 0,
		"damage_interval": 0.2,
		"duration": 0.2,
		"color": Color(0.5, 0.98, 0.9, 0.9)
	})
	_apply_line_burst_damage(start, end, orbit_slash_width * 0.5, orbit_slash_damage, true)

func _apply_line_burst_damage(start: Vector2, end: Vector2, hit_radius: float, damage: int, pull_to_center: bool) -> void:
	var center: Vector2 = start.lerp(end, 0.5)
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
		_apply_status(enemy, "slow", 0.9, float(storm_slow_value + 0.08), 1, 0.1)
		if pull_to_center:
			var pull_dir: Vector2 = (center - enemy.global_position).normalized()
			enemy.global_position += pull_dir * 24.0

func _apply_radius_damage_and_slow(center: Vector2, radius: float, damage: int) -> void:
	var enemies: Array = get_tree().get_nodes_in_group("enemies")
	for enemy_obj: Variant in enemies:
		if enemy_obj == null or not is_instance_valid(enemy_obj):
			continue
		if not (enemy_obj is Node2D):
			continue
		var enemy: Node2D = enemy_obj
		if enemy.global_position.distance_to(center) > radius:
			continue
		_apply_damage(enemy, damage)
		_apply_status(enemy, "slow", 0.9, float(storm_slow_value + 0.06), 1, 0.1)

func _apply_direction_push(center: Vector2, radius: float, dir: Vector2, force: float) -> void:
	var safe_dir: Vector2 = dir.normalized()
	if safe_dir.length_squared() <= 0.0001:
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
		enemy.global_position += safe_dir * force

func _apply_pull_to_point(center: Vector2, radius: float, force: float) -> void:
	var enemies: Array = get_tree().get_nodes_in_group("enemies")
	for enemy_obj: Variant in enemies:
		if enemy_obj == null or not is_instance_valid(enemy_obj):
			continue
		if not (enemy_obj is Node2D):
			continue
		var enemy: Node2D = enemy_obj
		var dist: float = enemy.global_position.distance_to(center)
		if dist > radius:
			continue
		var pull_dir: Vector2 = (center - enemy.global_position).normalized()
		enemy.global_position += pull_dir * force

func _cache_stormseer_window(polygon: PackedVector2Array, duration: float) -> void:
	if not is_instance_valid(skill_owner):
		return
	var center: Vector2 = _calculate_polygon_center(polygon)
	var radius: float = _polygon_radius(polygon, center)
	var expire_msec: int = Time.get_ticks_msec() + int(round(max(0.2, duration) * 1000.0))
	skill_owner.set_meta(STORMSEER_META_CENTER, center)
	skill_owner.set_meta(STORMSEER_META_RADIUS, radius)
	skill_owner.set_meta(STORMSEER_META_EXPIRE_MSEC, expire_msec)

func _polygon_radius(polygon: PackedVector2Array, center: Vector2) -> float:
	var radius: float = 0.0
	for point: Vector2 in polygon:
		radius = float(max(radius, center.distance_to(point)))
	return float(max(18.0, radius))

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
	return Color(0.3, 0.9, 0.8, 1.0)

func _get_closure_color() -> Color:
	return Color(0.2, 0.8, 0.7, 1.0)

