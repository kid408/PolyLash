extends SkillDrawingBase
class_name SkillTeslaQ

var arc_damage: int = 28
var arc_stun_duration: float = 0.6
var arc_interval: float = 0.4
var return_arc_ratio: float = 0.78

var capacitor_spacing: float = 170.0
var capacitor_duration: float = 4.8
var capacitor_interval: float = 0.3
var capacitor_radius: float = 240.0
var capacitor_tick_damage: int = 12

var field_damage: int = 36
var field_duration: float = 4.8
var field_damage_amp: float = 0.25
var lattice_sweep_count: int = 6
var lattice_interval: float = 0.22
var lattice_damage: int = 24
var bolt_lance_step_distance: float = 50.0
var bolt_lance_tick_interval: float = 0.05
var bolt_lance_hit_radius: float = 52.0
var bolt_lance_damage: int = 16
var bolt_lance_push: float = 14.0
var bolt_recall_delay: float = 0.2
var bolt_recall_count: int = 5
var bolt_recall_damage: int = 20
var bolt_recall_pull: float = 20.0
var field_reel_count: int = 5
var field_reel_interval: float = 0.16
var field_reel_damage: int = 20

const TESLA_META_CENTER: String = "tesla_field_center"
const TESLA_META_RADIUS: String = "tesla_field_radius"
const TESLA_META_EXPIRE_MSEC: String = "tesla_field_expire_msec"

var _capacitor_points: Array[Vector2] = []

func _enter_planning_mode() -> void:
	_capacitor_points.clear()
	super._enter_planning_mode()

func _spawn_line_effect(start: Vector2, end: Vector2) -> void:
	var duration: float = _get_line_duration()
	SkillEffectManager.create_debuff_zone({
		"start": start,
		"end": end,
		"width": 22.0,
		"damage": arc_damage,
		"damage_interval": arc_interval,
		"duration": duration,
		"debuff_type": "freeze",
		"debuff_value": 0.0,
		"debuff_duration": arc_stun_duration,
		"tick_interval": arc_interval,
		"color": Color(0.3, 0.72, 1.0, 0.9)
	})

	SkillEffectManager.create_debuff_zone({
		"start": end,
		"end": start,
		"width": 18.0,
		"damage": int(max(1, round(float(arc_damage) * return_arc_ratio))),
		"damage_interval": 0.28,
		"duration": float(max(0.3, duration * 0.58)),
		"debuff_type": "damage_amp",
		"debuff_value": 0.12,
		"debuff_duration": 0.9,
		"tick_interval": 0.28,
		"color": Color(0.42, 0.8, 1.0, 0.58)
	})

	_launch_bolt_lance(start, end)
	_spawn_capacitors_along_segment(start, end)

func _spawn_area_effect(polygon: PackedVector2Array) -> void:
	if polygon.size() < 3:
		return
	SkillEffectManager.create_area_effect({
		"polygon": polygon,
		"damage": field_damage,
		"damage_interval": 0.4,
		"duration": field_duration,
		"color": Color(0.2, 0.5, 1.0, 0.52)
	})

	SkillEffectManager.create_debuff_zone({
		"polygon": polygon,
		"duration": field_duration,
		"debuff_type": "damage_amp",
		"debuff_value": field_damage_amp,
		"debuff_duration": field_duration,
		"tick_interval": 0.65,
		"color": Color(0.28, 0.6, 1.0, 0.22)
	})

	SkillEffectManager.create_debuff_zone({
		"polygon": polygon,
		"duration": field_duration,
		"debuff_type": "slow",
		"debuff_value": 0.28,
		"debuff_duration": 1.0,
		"tick_interval": 0.35,
		"color": Color(0.2, 0.46, 0.9, 0.16)
	})

	_spawn_lattice_sweeps(polygon)
	_spawn_field_reel(polygon)
	_cache_tesla_field(polygon, field_duration)

func _launch_bolt_lance(start: Vector2, finish: Vector2) -> void:
	var seg: Vector2 = finish - start
	var length: float = seg.length()
	if length <= 1.0:
		return
	var move_dir: Vector2 = seg / length
	var host: Node2D = Node2D.new()
	host.name = "TeslaBoltLanceHost"
	add_child(host)

	var step_total: int = int(max(2.0, ceil(length / max(12.0, bolt_lance_step_distance))))
	var step_index: int = 0
	var timer: Timer = Timer.new()
	timer.wait_time = max(0.03, bolt_lance_tick_interval)
	timer.one_shot = false
	host.add_child(timer)
	timer.timeout.connect(func() -> void:
		if not is_instance_valid(host):
			return
		if step_index > step_total:
			timer.stop()
			host.queue_free()
			_spawn_bolt_recall(finish, start, move_dir)
			return
		_emit_bolt_lance_tick(start, finish, step_index, step_total, move_dir)
		step_index += 1
	)
	timer.start()

func _spawn_bolt_recall(from_pos: Vector2, to_pos: Vector2, move_dir: Vector2) -> void:
	var tree: SceneTree = get_tree()
	if tree == null:
		return
	tree.create_timer(max(0.05, bolt_recall_delay)).timeout.connect(func() -> void:
		if not is_inside_tree():
			return
		var host: Node2D = Node2D.new()
		host.name = "TeslaBoltRecallHost"
		add_child(host)
		var pulse_total: int = int(max(1, bolt_recall_count))
		var pulse_index: int = 0
		var timer: Timer = Timer.new()
		timer.wait_time = max(0.06, bolt_lance_tick_interval * 1.6)
		timer.one_shot = false
		host.add_child(timer)
		timer.timeout.connect(func() -> void:
			if not is_instance_valid(host):
				return
			if pulse_index >= pulse_total:
				timer.stop()
				host.queue_free()
				return
			_emit_bolt_recall_tick(from_pos, to_pos, pulse_index, pulse_total, move_dir)
			pulse_index += 1
		)
		timer.start()
	)

func _emit_bolt_lance_tick(start: Vector2, finish: Vector2, index: int, total: int, move_dir: Vector2) -> void:
	var t: float = float(index) / float(max(1, total))
	var prev_t: float = float(max(0, index - 1)) / float(max(1, total))
	var current: Vector2 = start.lerp(finish, t)
	var previous: Vector2 = start.lerp(finish, prev_t)
	SkillEffectManager.create_line_effect({
		"start": previous,
		"end": current,
		"width": 12.0,
		"damage": 0,
		"damage_interval": 0.2,
		"duration": 0.12,
		"color": Color(0.72, 0.98, 1.0, 0.9)
	})
	_apply_radius_bolt_damage(current, bolt_lance_hit_radius, bolt_lance_damage)
	_apply_direction_push(current, bolt_lance_hit_radius * 1.18, move_dir, bolt_lance_push)

func _emit_bolt_recall_tick(
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
	var start: Vector2 = center - tangent * 72.0
	var end: Vector2 = center + tangent * 72.0
	SkillEffectManager.create_line_effect({
		"start": start,
		"end": end,
		"width": 12.0,
		"damage": 0,
		"damage_interval": 0.2,
		"duration": 0.16,
		"color": Color(0.82, 1.0, 1.0, 0.92)
	})
	_apply_line_burst_damage(start, end, 11.0, bolt_recall_damage)
	_apply_pull_to_point(center, bolt_lance_hit_radius * 1.55, bolt_recall_pull)

func _spawn_field_reel(polygon: PackedVector2Array) -> void:
	var center: Vector2 = _polygon_center(polygon)
	var radius: float = _polygon_radius(polygon, center)
	var sweep_total: int = int(max(1, field_reel_count))
	var sweep_index: int = 0
	var host: Node2D = Node2D.new()
	host.name = "TeslaFieldReelHost"
	add_child(host)

	var timer: Timer = Timer.new()
	timer.wait_time = max(0.08, field_reel_interval)
	timer.one_shot = false
	host.add_child(timer)
	timer.timeout.connect(func() -> void:
		if not is_instance_valid(host):
			return
		if sweep_index >= sweep_total:
			timer.stop()
			host.queue_free()
			return
		_emit_field_reel(center, radius, sweep_index, sweep_total)
		sweep_index += 1
	)
	timer.start()

func _emit_field_reel(center: Vector2, radius: float, index: int, total: int) -> void:
	var angle: float = TAU * float(index) / float(max(1, total))
	var dir: Vector2 = Vector2.RIGHT.rotated(angle)
	var start: Vector2 = center + dir * radius * 1.3
	var end: Vector2 = center - dir * radius * 0.08
	SkillEffectManager.create_line_effect({
		"start": start,
		"end": end,
		"width": 13.0,
		"damage": 0,
		"damage_interval": 0.2,
		"duration": 0.18,
		"color": Color(0.78, 1.0, 1.0, 0.9)
	})
	_apply_line_burst_damage(start, end, 11.0, field_reel_damage)
	_apply_pull_to_point(center, radius * 1.02, bolt_recall_pull * 0.55)

func _spawn_capacitors_along_segment(start: Vector2, end: Vector2) -> void:
	var seg: Vector2 = end - start
	var length: float = seg.length()
	if length <= 1.0:
		_deploy_capacitor_if_needed(start)
		return
	var dir: Vector2 = seg / length
	var spacing: float = float(max(64.0, capacitor_spacing))
	var cursor: float = 0.0
	while cursor <= length:
		_deploy_capacitor_if_needed(start + dir * cursor)
		cursor += spacing
	if fmod(length, spacing) > 20.0:
		_deploy_capacitor_if_needed(end)

func _deploy_capacitor_if_needed(pos: Vector2) -> void:
	if _capacitor_points.is_empty():
		_capacitor_points.append(pos)
		_spawn_capacitor(pos)
		return
	var last_pos: Vector2 = _capacitor_points[_capacitor_points.size() - 1]
	if last_pos.distance_to(pos) < capacitor_spacing:
		return
	_capacitor_points.append(pos)
	_spawn_capacitor(pos)

func _spawn_capacitor(pos: Vector2) -> void:
	var cap: Node2D = Node2D.new()
	cap.name = "TeslaCapacitor"
	cap.global_position = pos
	add_child(cap)
	cap.add_to_group("player_skill_effects")

	var elapsed: float = 0.0
	var timer: Timer = Timer.new()
	timer.wait_time = float(max(0.08, capacitor_interval))
	timer.one_shot = false
	cap.add_child(timer)
	timer.timeout.connect(func() -> void:
		if not is_instance_valid(cap):
			return
		elapsed += timer.wait_time
		if elapsed >= capacitor_duration:
			timer.stop()
			cap.queue_free()
			return
		_emit_capacitor_arc(cap.global_position)
	)
	timer.start()

	spawn_skill_vfx(pos, Color(0.44, 0.84, 1.0, 0.78), 0.3)

func _emit_capacitor_arc(center: Vector2) -> void:
	var target: Node2D = _find_nearest_enemy(center, capacitor_radius)
	if target == null:
		return
	SkillEffectManager.create_line_effect({
		"start": center,
		"end": target.global_position,
		"width": 8.0,
		"damage": 0,
		"damage_interval": 0.2,
		"duration": 0.16,
		"color": Color(0.56, 0.9, 1.0, 0.9)
	})
	_apply_damage(target, capacitor_tick_damage)
	_apply_status(target, "freeze", arc_stun_duration * 0.8, 0.0, 1, 0.1)

func _spawn_lattice_sweeps(polygon: PackedVector2Array) -> void:
	var center: Vector2 = _polygon_center(polygon)
	var radius: float = _polygon_radius(polygon, center)
	var sweep_total: int = int(max(1, lattice_sweep_count))
	var sweep_index: int = 0
	var host: Node2D = Node2D.new()
	host.name = "TeslaLatticeSweeps"
	add_child(host)

	_emit_lattice_sweep(center, radius, sweep_index)
	sweep_index += 1

	var timer: Timer = Timer.new()
	timer.wait_time = float(max(0.08, lattice_interval))
	timer.one_shot = false
	host.add_child(timer)
	timer.timeout.connect(func() -> void:
		if not is_instance_valid(host):
			return
		if sweep_index >= sweep_total:
			timer.stop()
			host.queue_free()
			return
		_emit_lattice_sweep(center, radius, sweep_index)
		sweep_index += 1
	)
	timer.start()

func _emit_lattice_sweep(center: Vector2, radius: float, index: int) -> void:
	var angle: float = TAU * float(index) / float(max(1, lattice_sweep_count))
	var dir: Vector2 = Vector2.RIGHT.rotated(angle)
	var start: Vector2 = center + dir * (radius + 70.0)
	var end: Vector2 = center - dir * (radius + 24.0)
	SkillEffectManager.create_line_effect({
		"start": start,
		"end": end,
		"width": 18.0,
		"damage": 0,
		"damage_interval": 0.2,
		"duration": 0.2,
		"color": Color(0.6, 0.92, 1.0, 0.9)
	})
	_apply_line_burst_damage(start, end, 12.0, lattice_damage)

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
		_apply_status(enemy, "freeze", arc_stun_duration, 0.0, 1, 0.1)

func _apply_radius_bolt_damage(center: Vector2, radius: float, damage: int) -> void:
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
		_apply_status(enemy, "freeze", arc_stun_duration * 0.8, 0.0, 1, 0.1)

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

func _find_nearest_enemy(center: Vector2, range_radius: float) -> Node2D:
	var enemies: Array = get_tree().get_nodes_in_group("enemies")
	var best_enemy: Node2D = null
	var best_dist: float = range_radius + 0.001
	for enemy_obj: Variant in enemies:
		if enemy_obj == null or not is_instance_valid(enemy_obj):
			continue
		if not (enemy_obj is Node2D):
			continue
		var enemy: Node2D = enemy_obj
		var dist: float = enemy.global_position.distance_to(center)
		if dist > range_radius:
			continue
		if dist < best_dist:
			best_dist = dist
			best_enemy = enemy
	return best_enemy

func _cache_tesla_field(polygon: PackedVector2Array, duration: float) -> void:
	if not is_instance_valid(skill_owner):
		return
	var center: Vector2 = _polygon_center(polygon)
	var radius: float = _polygon_radius(polygon, center)
	var expire_msec: int = Time.get_ticks_msec() + int(round(float(max(0.2, duration)) * 1000.0))
	skill_owner.set_meta(TESLA_META_CENTER, center)
	skill_owner.set_meta(TESLA_META_RADIUS, radius)
	skill_owner.set_meta(TESLA_META_EXPIRE_MSEC, expire_msec)

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
	return Color(0.3, 0.7, 1.0, 1.0)

func _get_closure_color() -> Color:
	return Color(0.2, 0.5, 1.0, 1.0)
