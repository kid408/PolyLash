extends SkillQBase
class_name SkillSingularistQ

var pull_force: float = 280.0
var pull_damage: int = 18
var suction_damage_amp: float = 0.2

var anchor_spacing: float = 170.0
var anchor_duration: float = 4.8
var anchor_interval: float = 0.32
var anchor_radius: float = 160.0
var anchor_pulse_damage: int = 11
var anchor_pull_force: float = 34.0
var anchor_push_force: float = 28.0

var vortex_force: float = 460.0
var vortex_damage: int = 30
var vortex_duration: float = 4.8
var orbit_cut_count: int = 7
var orbit_cut_interval: float = 0.22
var orbit_cut_damage: int = 22
var orbit_cut_width: float = 24.0
var outer_shear_count: int = 6
var outer_shear_interval: float = 0.2
var outer_shear_damage: int = 18
var outer_shear_band_inner_ratio: float = 1.04
var outer_shear_band_outer_ratio: float = 1.42
var probe_step_distance: float = 50.0
var probe_tick_interval: float = 0.05
var probe_hit_radius: float = 56.0
var probe_line_damage: int = 18
var probe_push: float = 18.0
var probe_recall_delay: float = 0.2
var probe_recall_count: int = 5
var probe_recall_damage: int = 22
var probe_recall_pull: float = 30.0
var closure_counterflow_count: int = 6
var closure_counterflow_interval: float = 0.16
var closure_counterflow_damage: int = 20

const VACUUM_META_CENTER: String = "singularist_vortex_center"
const VACUUM_META_RADIUS: String = "singularist_vortex_radius"
const VACUUM_META_EXPIRE_MSEC: String = "singularist_vortex_expire_msec"

var _anchor_points: Array[Vector2] = []

func _enter_planning_mode() -> void:
	_anchor_points.clear()
	super._enter_planning_mode()

func _spawn_line_effect(start: Vector2, end: Vector2) -> void:
	SkillEffectManager.create_area_effect({
		"polygon": _line_to_polygon(start, end, 26.0),
		"damage": pull_damage,
		"damage_interval": 0.55,
		"duration": _get_line_duration(),
		"color": Color(0.4, 0.2, 0.6, 0.54),
		"pull_to_center": true,
		"pull_force": pull_force
	})

	SkillEffectManager.create_debuff_zone({
		"start": start,
		"end": end,
		"width": 20.0,
		"duration": _get_line_duration(),
		"debuff_type": "damage_amp",
		"debuff_value": suction_damage_amp,
		"debuff_duration": 2.0,
		"tick_interval": 0.55,
		"color": Color(0.35, 0.2, 0.55, 0.22)
	})

	_launch_singularist_probe(start, end)
	_spawn_anchors_along_segment(start, end)

func _spawn_area_effect(polygon: PackedVector2Array) -> void:
	if polygon.size() < 3:
		return
	SkillEffectManager.create_area_effect({
		"polygon": polygon,
		"damage": vortex_damage,
		"damage_interval": 0.35,
		"duration": vortex_duration,
		"color": Color(0.3, 0.15, 0.5, 0.45),
		"pull_to_center": true,
		"pull_force": vortex_force
	})

	SkillEffectManager.create_debuff_zone({
		"polygon": polygon,
		"duration": vortex_duration,
		"debuff_type": "slow",
		"debuff_value": 0.45,
		"debuff_duration": 1.6,
		"tick_interval": 0.35,
		"color": Color(0.26, 0.12, 0.45, 0.2)
	})

	_spawn_orbit_cuts(polygon)
	_spawn_outer_shear_ring(polygon)
	_spawn_counterflow_jets(polygon)
	_cache_vortex_window(polygon, vortex_duration)

func _launch_singularist_probe(start: Vector2, finish: Vector2) -> void:
	var seg: Vector2 = finish - start
	var length: float = seg.length()
	if length <= 1.0:
		return
	var move_dir: Vector2 = seg / length
	var host: Node2D = Node2D.new()
	host.name = "VacuumProbeHost"
	add_child(host)

	var step_total: int = int(max(2.0, ceil(length / max(12.0, probe_step_distance))))
	var step_index: int = 0
	var timer: Timer = Timer.new()
	timer.wait_time = max(0.03, probe_tick_interval)
	timer.one_shot = false
	host.add_child(timer)
	timer.timeout.connect(func() -> void:
		if not is_instance_valid(host):
			return
		if step_index > step_total:
			timer.stop()
			host.queue_free()
			_spawn_probe_recall(finish, start, move_dir)
			return
		_emit_probe_tick(start, finish, step_index, step_total, move_dir)
		step_index += 1
	)
	timer.start()

func _spawn_probe_recall(from_pos: Vector2, to_pos: Vector2, move_dir: Vector2) -> void:
	var tree: SceneTree = get_tree()
	if tree == null:
		return
	tree.create_timer(max(0.05, probe_recall_delay)).timeout.connect(func() -> void:
		if not is_inside_tree():
			return
		var host: Node2D = Node2D.new()
		host.name = "VacuumProbeRecallHost"
		add_child(host)
		var pulse_total: int = int(max(1, probe_recall_count))
		var pulse_index: int = 0
		var timer: Timer = Timer.new()
		timer.wait_time = max(0.06, probe_tick_interval * 1.7)
		timer.one_shot = false
		host.add_child(timer)
		timer.timeout.connect(func() -> void:
			if not is_instance_valid(host):
				return
			if pulse_index >= pulse_total:
				timer.stop()
				host.queue_free()
				return
			_emit_probe_recall_tick(from_pos, to_pos, pulse_index, pulse_total, move_dir)
			pulse_index += 1
		)
		timer.start()
	)

func _emit_probe_tick(start: Vector2, finish: Vector2, index: int, total: int, move_dir: Vector2) -> void:
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
		"color": Color(0.76, 0.56, 0.98, 0.92)
	})
	_apply_radius_damage_and_slow(current, probe_hit_radius, probe_line_damage)
	_apply_forward_push(current, probe_hit_radius * 1.2, move_dir, probe_push)

func _emit_probe_recall_tick(
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
		"width": 13.0,
		"damage": 0,
		"damage_interval": 0.2,
		"duration": 0.16,
		"color": Color(0.92, 0.72, 1.0, 0.92)
	})
	_apply_line_burst_damage(start, end, 13.0, probe_recall_damage)
	_apply_pull_to_point(center, probe_hit_radius * 1.6, probe_recall_pull)

func _spawn_counterflow_jets(polygon: PackedVector2Array) -> void:
	var center: Vector2 = _polygon_center(polygon)
	var radius: float = _polygon_radius(polygon, center)
	var jet_total: int = int(max(1, closure_counterflow_count))
	var jet_index: int = 0
	var host: Node2D = Node2D.new()
	host.name = "VacuumCounterflowJetsHost"
	add_child(host)

	var timer: Timer = Timer.new()
	timer.wait_time = max(0.08, closure_counterflow_interval)
	timer.one_shot = false
	host.add_child(timer)
	timer.timeout.connect(func() -> void:
		if not is_instance_valid(host):
			return
		if jet_index >= jet_total:
			timer.stop()
			host.queue_free()
			return
		_emit_counterflow_jet(center, radius, jet_index, jet_total)
		jet_index += 1
	)
	timer.start()

func _emit_counterflow_jet(center: Vector2, radius: float, index: int, total: int) -> void:
	var angle: float = TAU * float(index) / float(max(1, total))
	var facing: Vector2 = Vector2.RIGHT.rotated(angle)
	var start: Vector2 = center + facing * radius * 1.34
	var end: Vector2 = center - facing * radius * 0.15
	SkillEffectManager.create_line_effect({
		"start": start,
		"end": end,
		"width": 15.0,
		"damage": 0,
		"damage_interval": 0.2,
		"duration": 0.2,
		"color": Color(0.88, 0.62, 1.0, 0.88)
	})
	_apply_line_burst_damage(start, end, 14.0, closure_counterflow_damage)
	_apply_pull_to_point(center, radius * 1.05, probe_recall_pull * 0.55)
	_apply_radius_damage_and_slow(center, radius * 0.25, int(max(1, closure_counterflow_damage * 0.25)))

func _spawn_anchors_along_segment(start: Vector2, end: Vector2) -> void:
	var seg: Vector2 = end - start
	var length: float = seg.length()
	if length <= 1.0:
		_deploy_anchor_if_needed(start)
		return
	var dir: Vector2 = seg / length
	var spacing: float = float(max(60.0, anchor_spacing))
	var cursor: float = 0.0
	while cursor <= length:
		_deploy_anchor_if_needed(start + dir * cursor)
		cursor += spacing
	if fmod(length, spacing) > 20.0:
		_deploy_anchor_if_needed(end)

func _deploy_anchor_if_needed(pos: Vector2) -> void:
	if _anchor_points.is_empty():
		_anchor_points.append(pos)
		_spawn_anchor(pos)
		return
	var last_pos: Vector2 = _anchor_points[_anchor_points.size() - 1]
	if last_pos.distance_to(pos) < anchor_spacing:
		return
	_anchor_points.append(pos)
	_spawn_anchor(pos)

func _spawn_anchor(pos: Vector2) -> void:
	var anchor: Node2D = Node2D.new()
	anchor.name = "VacuumAnchor"
	anchor.global_position = pos
	add_child(anchor)
	anchor.add_to_group("player_skill_effects")

	var elapsed: float = 0.0
	var pulse_index: int = 0
	var timer: Timer = Timer.new()
	timer.wait_time = float(max(0.08, anchor_interval))
	timer.one_shot = false
	anchor.add_child(timer)
	timer.timeout.connect(func() -> void:
		if not is_instance_valid(anchor):
			return
		elapsed += timer.wait_time
		if elapsed >= anchor_duration:
			timer.stop()
			anchor.queue_free()
			return
		var pull_phase: bool = (pulse_index % 2 == 0)
		_process_anchor_pulse(anchor.global_position, pull_phase)
		pulse_index += 1
	)
	timer.start()

	spawn_skill_vfx(pos, Color(0.5, 0.3, 0.7, 0.74), 0.28)

func _process_anchor_pulse(center: Vector2, pull_phase: bool) -> void:
	var enemies: Array = get_tree().get_nodes_in_group("enemies")
	for enemy_obj: Variant in enemies:
		if enemy_obj == null or not is_instance_valid(enemy_obj):
			continue
		if not (enemy_obj is Node2D):
			continue
		var enemy: Node2D = enemy_obj
		if enemy.global_position.distance_to(center) > anchor_radius:
			continue
		var dir: Vector2 = (center - enemy.global_position).normalized()
		if dir.length_squared() <= 0.0001:
			dir = Vector2.RIGHT
		if pull_phase:
			enemy.global_position += dir * anchor_pull_force
			_apply_status(enemy, "slow", 0.8, 0.5, 1, 0.1)
		else:
			enemy.global_position -= dir * anchor_push_force
			_apply_status(enemy, "fear", 0.45, 1.0, 1, 0.2)
		_apply_damage(enemy, anchor_pulse_damage)

func _spawn_orbit_cuts(polygon: PackedVector2Array) -> void:
	var center: Vector2 = _polygon_center(polygon)
	var radius: float = _polygon_radius(polygon, center)
	var cut_total: int = int(max(1, orbit_cut_count))
	var cut_index: int = 0
	var host: Node2D = Node2D.new()
	host.name = "VacuumOrbitCuts"
	add_child(host)

	_emit_orbit_cut(center, radius, cut_index)
	cut_index += 1

	var timer: Timer = Timer.new()
	timer.wait_time = float(max(0.08, orbit_cut_interval))
	timer.one_shot = false
	host.add_child(timer)
	timer.timeout.connect(func() -> void:
		if not is_instance_valid(host):
			return
		if cut_index >= cut_total:
			timer.stop()
			host.queue_free()
			return
		_emit_orbit_cut(center, radius, cut_index)
		cut_index += 1
	)
	timer.start()

func _emit_orbit_cut(center: Vector2, radius: float, index: int) -> void:
	var angle: float = TAU * float(index) / float(max(1, orbit_cut_count))
	var dir: Vector2 = Vector2.RIGHT.rotated(angle)
	var start: Vector2 = center + dir * (radius + 74.0)
	var end: Vector2 = center - dir * (radius * 0.45)
	SkillEffectManager.create_line_effect({
		"start": start,
		"end": end,
		"width": orbit_cut_width,
		"damage": 0,
		"damage_interval": 0.2,
		"duration": 0.2,
		"color": Color(0.6, 0.36, 0.82, 0.9)
	})
	_apply_line_burst_damage(start, end, orbit_cut_width * 0.5, orbit_cut_damage)

func _spawn_outer_shear_ring(polygon: PackedVector2Array) -> void:
	var center: Vector2 = _polygon_center(polygon)
	var radius: float = _polygon_radius(polygon, center)
	var shear_total: int = int(max(1, outer_shear_count))
	var shear_index: int = 0
	var host: Node2D = Node2D.new()
	host.name = "VacuumOuterShearRing"
	add_child(host)

	_emit_outer_shear(center, radius, shear_index, shear_total)
	shear_index += 1

	var timer: Timer = Timer.new()
	timer.wait_time = float(max(0.08, outer_shear_interval))
	timer.one_shot = false
	host.add_child(timer)
	timer.timeout.connect(func() -> void:
		if not is_instance_valid(host):
			return
		if shear_index >= shear_total:
			timer.stop()
			host.queue_free()
			return
		_emit_outer_shear(center, radius, shear_index, shear_total)
		shear_index += 1
	)
	timer.start()

func _emit_outer_shear(center: Vector2, radius: float, index: int, total: int) -> void:
	var angle: float = TAU * float(index) / float(max(1, total))
	var facing: Vector2 = Vector2.RIGHT.rotated(angle)
	var tangent: Vector2 = Vector2(-facing.y, facing.x)
	var band_center: Vector2 = center + facing * radius * 1.22
	var half_len: float = radius * 0.42
	var start: Vector2 = band_center - tangent * half_len
	var end: Vector2 = band_center + tangent * half_len
	SkillEffectManager.create_line_effect({
		"start": start,
		"end": end,
		"width": orbit_cut_width * 0.86,
		"damage": 0,
		"damage_interval": 0.2,
		"duration": 0.16,
		"color": Color(0.82, 0.55, 1.0, 0.86)
	})
	_apply_outer_band_sector_damage(
		center,
		radius * max(1.01, outer_shear_band_inner_ratio),
		radius * max(1.12, outer_shear_band_outer_ratio),
		facing,
		0.62,
		outer_shear_damage
	)

func _apply_outer_band_sector_damage(
	center: Vector2,
	inner_radius: float,
	outer_radius: float,
	facing: Vector2,
	sector_dot_min: float,
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
		var to_enemy: Vector2 = enemy.global_position - center
		var dist: float = to_enemy.length()
		if dist < inner_radius or dist > outer_radius:
			continue
		if dist <= 0.001:
			continue
		var dir_norm: Vector2 = to_enemy / dist
		if dir_norm.dot(safe_facing) < sector_dot_min:
			continue
		_apply_damage(enemy, max(1, damage))
		_apply_status(enemy, "slow", 0.9, 0.44, 1, 0.1)
		_apply_status(enemy, "fear", 0.45, 1.0, 1, 0.2)
		enemy.global_position += dir_norm * anchor_push_force * 0.34

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
		_apply_status(enemy, "slow", 0.9, 0.52, 1, 0.1)

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
		_apply_status(enemy, "slow", 0.9, 0.5, 1, 0.1)

func _apply_forward_push(center: Vector2, radius: float, dir: Vector2, force: float) -> void:
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

func _line_to_polygon(start: Vector2, end: Vector2, width: float) -> PackedVector2Array:
	var vec: Vector2 = end - start
	if vec.length() < 0.001:
		return PackedVector2Array([start, start + Vector2.RIGHT, start + Vector2(1.0, 1.0)])
	var perp: Vector2 = vec.normalized().rotated(PI / 2.0) * width * 0.5
	var polygon: PackedVector2Array = PackedVector2Array()
	polygon.append(start + perp)
	polygon.append(end + perp)
	polygon.append(end - perp)
	polygon.append(start - perp)
	return polygon

func _cache_vortex_window(polygon: PackedVector2Array, duration: float) -> void:
	if not is_instance_valid(skill_owner):
		return
	var center: Vector2 = _polygon_center(polygon)
	var radius: float = _polygon_radius(polygon, center)
	var expire_msec: int = Time.get_ticks_msec() + int(round(float(max(0.2, duration)) * 1000.0))
	skill_owner.set_meta(VACUUM_META_CENTER, center)
	skill_owner.set_meta(VACUUM_META_RADIUS, radius)
	skill_owner.set_meta(VACUUM_META_EXPIRE_MSEC, expire_msec)

func _polygon_center(polygon: PackedVector2Array) -> Vector2:
	if polygon.is_empty():
		return Vector2.ZERO
	var center: Vector2 = Vector2.ZERO
	for p: Vector2 in polygon:
		center += p
	return center / float(polygon.size())

func _polygon_radius(polygon: PackedVector2Array, center: Vector2) -> float:
	var radius: float = 0.0
	for p: Vector2 in polygon:
		radius = float(max(radius, center.distance_to(p)))
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
	return Color(0.4, 0.2, 0.6, 1.0)

func _get_closure_color() -> Color:
	return Color(0.3, 0.15, 0.5, 1.0)

func _build_q_asset_payload(
	is_closed_path: bool,
	segment_count: int,
	polygon_count: int,
	center: Vector2,
	radius: float
) -> Dictionary:
	var payload := super._build_q_asset_payload(is_closed_path, segment_count, polygon_count, center, radius)
	payload["points"] = path_points.duplicate()
	payload["anchor_points"] = _anchor_points.duplicate()
	if path_points.size() >= 2:
		payload["path_start"] = path_points[0]
		payload["path_end"] = path_points[path_points.size() - 1]
	return payload

