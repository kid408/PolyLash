extends SkillDrawingBase
class_name SkillVoodooQ

var curse_duration: float = 6.0
var curse_damage: int = 11
var pin_tick_damage: int = 14
var hex_fear_duration: float = 0.75
var hex_damage_amp: float = 0.22

var pin_spacing: float = 165.0
var pin_duration: float = 4.8
var pin_interval: float = 0.34
var pin_link_radius: float = 240.0
var pin_slow_value: float = 0.5

var ritual_duration: float = 5.0
var ritual_interval: float = 0.26
var ritual_pulse_count: int = 7
var ritual_damage: int = 24
var ritual_chain_radius: float = 180.0
var ritual_chain_targets: int = 3
var rebound_damage_ratio: float = 0.58
var rebound_width: float = 9.0
var outer_hex_count: int = 6
var outer_hex_interval: float = 0.24
var outer_hex_damage: int = 16
var outer_hex_inner_ratio: float = 1.05
var outer_hex_outer_ratio: float = 1.42
var hex_nail_step_distance: float = 50.0
var hex_nail_tick_interval: float = 0.05
var hex_nail_hit_radius: float = 50.0
var hex_nail_hit_damage: int = 16
var hex_nail_recall_delay: float = 0.24
var hex_nail_recall_count: int = 6
var hex_nail_recall_damage: int = 18
var hex_nail_pull: float = 24.0
var ritual_reflux_count: int = 5
var ritual_reflux_interval: float = 0.18
var ritual_reflux_damage: int = 20

const HEX_META_CENTER: String = "voodoo_hex_center"
const HEX_META_RADIUS: String = "voodoo_hex_radius"
const HEX_META_EXPIRE_MSEC: String = "voodoo_hex_expire_msec"

var _pin_points: Array[Vector2] = []

func _enter_planning_mode() -> void:
	_pin_points.clear()
	super._enter_planning_mode()

func _spawn_line_effect(start: Vector2, end: Vector2) -> void:
	SkillEffectManager.create_debuff_zone({
		"start": start,
		"end": end,
		"width": 24.0,
		"duration": _get_line_duration(),
		"debuff_type": "curse",
		"debuff_value": float(curse_damage),
		"debuff_duration": curse_duration,
		"tick_interval": 0.8,
		"color": Color(0.5, 0.1, 0.4, 0.62)
	})

	SkillEffectManager.create_debuff_zone({
		"start": start,
		"end": end,
		"width": 18.0,
		"duration": _get_line_duration(),
		"debuff_type": "fear",
		"debuff_value": 1.0,
		"debuff_duration": hex_fear_duration,
		"tick_interval": 1.1,
		"color": Color(0.44, 0.08, 0.35, 0.2)
	})

	_spawn_pins_along_segment(start, end)
	_launch_hex_nail(start, end)

func _spawn_area_effect(polygon: PackedVector2Array) -> void:
	if polygon.size() < 3:
		return

	SkillEffectManager.create_debuff_zone({
		"polygon": polygon,
		"duration": ritual_duration,
		"debuff_type": "damage_amp",
		"debuff_value": hex_damage_amp,
		"debuff_duration": ritual_duration,
		"tick_interval": 0.75,
		"color": Color(0.46, 0.1, 0.38, 0.2)
	})

	SkillEffectManager.create_debuff_zone({
		"polygon": polygon,
		"duration": ritual_duration,
		"debuff_type": "curse",
		"debuff_value": float(curse_damage),
		"debuff_duration": curse_duration,
		"tick_interval": 1.0,
		"color": Color(0.4, 0.05, 0.3, 0.28)
	})

	_spawn_ritual_pulses(polygon)
	_spawn_outer_hex_ring(polygon)
	_spawn_ritual_reflux(polygon)
	_cache_hex_window(polygon, ritual_duration)

func _spawn_pins_along_segment(start: Vector2, end: Vector2) -> void:
	var seg: Vector2 = end - start
	var length: float = seg.length()
	if length <= 1.0:
		_deploy_pin_if_needed(start)
		return
	var dir: Vector2 = seg / length
	var spacing: float = float(max(56.0, pin_spacing))
	var cursor: float = 0.0
	while cursor <= length:
		_deploy_pin_if_needed(start + dir * cursor)
		cursor += spacing
	if fmod(length, spacing) > 20.0:
		_deploy_pin_if_needed(end)

func _deploy_pin_if_needed(pos: Vector2) -> void:
	if _pin_points.is_empty():
		_pin_points.append(pos)
		_spawn_pin_node(pos)
		return
	var last_pos: Vector2 = _pin_points[_pin_points.size() - 1]
	if last_pos.distance_to(pos) < pin_spacing:
		return
	_pin_points.append(pos)
	_spawn_pin_node(pos)

func _spawn_pin_node(pos: Vector2) -> void:
	var pin: Node2D = Node2D.new()
	pin.name = "VoodooPinNode"
	pin.global_position = pos
	add_child(pin)
	pin.add_to_group("player_skill_effects")

	var elapsed: float = 0.0
	var timer: Timer = Timer.new()
	timer.wait_time = float(max(0.08, pin_interval))
	timer.one_shot = false
	pin.add_child(timer)
	timer.timeout.connect(func() -> void:
		if not is_instance_valid(pin):
			return
		elapsed += timer.wait_time
		if elapsed >= pin_duration:
			timer.stop()
			pin.queue_free()
			return
		_emit_pin_link(pin.global_position)
	)
	timer.start()

	spawn_skill_vfx(pos, Color(0.58, 0.14, 0.44, 0.74), 0.28)

func _launch_hex_nail(start: Vector2, finish: Vector2) -> void:
	var seg: Vector2 = finish - start
	var length: float = seg.length()
	if length <= 1.0:
		return
	var move_dir: Vector2 = seg / length
	var host: Node2D = Node2D.new()
	host.name = "VoodooHexNailHost"
	add_child(host)

	var step_total: int = int(max(2.0, ceil(length / max(12.0, hex_nail_step_distance))))
	var step_index: int = 0
	var timer: Timer = Timer.new()
	timer.wait_time = max(0.03, hex_nail_tick_interval)
	timer.one_shot = false
	host.add_child(timer)
	timer.timeout.connect(func() -> void:
		if not is_instance_valid(host):
			return
		if step_index > step_total:
			timer.stop()
			host.queue_free()
			_spawn_hex_nail_recall(finish, start, move_dir)
			return
		_emit_hex_nail_tick(start, finish, step_index, step_total, move_dir)
		step_index += 1
	)
	timer.start()

func _spawn_hex_nail_recall(from_pos: Vector2, to_pos: Vector2, move_dir: Vector2) -> void:
	var tree: SceneTree = get_tree()
	if tree == null:
		return
	tree.create_timer(max(0.05, hex_nail_recall_delay)).timeout.connect(func() -> void:
		if not is_inside_tree():
			return
		var host: Node2D = Node2D.new()
		host.name = "VoodooHexRecallHost"
		add_child(host)
		var pulse_total: int = int(max(1, hex_nail_recall_count))
		var pulse_index: int = 0
		var timer: Timer = Timer.new()
		timer.wait_time = max(0.06, outer_hex_interval * 0.85)
		timer.one_shot = false
		host.add_child(timer)
		timer.timeout.connect(func() -> void:
			if not is_instance_valid(host):
				return
			if pulse_index >= pulse_total:
				timer.stop()
				host.queue_free()
				return
			_emit_hex_recall_tick(from_pos, to_pos, pulse_index, pulse_total, move_dir)
			pulse_index += 1
		)
		timer.start()
	)

func _emit_hex_nail_tick(
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
		"width": 12.0,
		"damage": 0,
		"damage_interval": 0.2,
		"duration": 0.12,
		"color": Color(0.76, 0.28, 0.62, 0.92)
	})
	_apply_radius_curse(current, hex_nail_hit_radius, hex_nail_hit_damage, hex_fear_duration * 0.45)
	_apply_directional_drag(current, hex_nail_hit_radius * 1.2, move_dir, 12.0)
	if index == total:
		spawn_skill_vfx(current, Color(0.86, 0.34, 0.72, 0.88), 0.4)

func _emit_hex_recall_tick(
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
	var start: Vector2 = center - tangent * 64.0
	var end: Vector2 = center + tangent * 64.0
	SkillEffectManager.create_line_effect({
		"start": start,
		"end": end,
		"width": 12.0,
		"damage": 0,
		"damage_interval": 0.2,
		"duration": 0.16,
		"color": Color(0.88, 0.36, 0.74, 0.94)
	})
	_apply_line_burst_damage(start, end, 12.0, hex_nail_recall_damage)
	_apply_pull_to_point(center, hex_nail_hit_radius * 1.5, hex_nail_pull)
	_apply_radius_curse(center, hex_nail_hit_radius * 0.85, max(1, hex_nail_recall_damage - 4), hex_fear_duration * 0.4)

func _emit_pin_link(center: Vector2) -> void:
	var targets: Array[Node2D] = _find_two_nearest_enemies(center, pin_link_radius)
	if targets.size() == 0:
		return
	if targets.size() == 1:
		var single_target: Node2D = targets[0]
		_apply_damage(single_target, pin_tick_damage)
		_apply_status(single_target, "curse", curse_duration, float(curse_damage), 1, 0.8)
		_apply_status(single_target, "slow", 0.9, pin_slow_value, 1, 0.1)
		return

	var first_target: Node2D = targets[0]
	var second_target: Node2D = targets[1]
	SkillEffectManager.create_line_effect({
		"start": first_target.global_position,
		"end": second_target.global_position,
		"width": 8.0,
		"damage": 0,
		"damage_interval": 0.2,
		"duration": 0.16,
		"color": Color(0.62, 0.2, 0.5, 0.86)
	})
	_apply_damage(first_target, pin_tick_damage)
	_apply_damage(second_target, pin_tick_damage)
	_apply_status(first_target, "curse", curse_duration, float(curse_damage), 1, 0.8)
	_apply_status(second_target, "curse", curse_duration, float(curse_damage), 1, 0.8)
	_apply_status(first_target, "marked", 1.0, hex_damage_amp, 1, 0.3)
	_apply_status(second_target, "marked", 1.0, hex_damage_amp, 1, 0.3)

func _spawn_ritual_pulses(polygon: PackedVector2Array) -> void:
	var center: Vector2 = _calculate_polygon_center(polygon)
	var pulse_total: int = int(max(1, ritual_pulse_count))
	var pulse_index: int = 0
	var host: Node2D = Node2D.new()
	host.name = "VoodooRitualHost"
	add_child(host)

	_emit_ritual_pulse(polygon, center, pulse_index)
	pulse_index += 1

	var timer: Timer = Timer.new()
	timer.wait_time = float(max(0.08, ritual_interval))
	timer.one_shot = false
	host.add_child(timer)
	timer.timeout.connect(func() -> void:
		if not is_instance_valid(host):
			return
		if pulse_index >= pulse_total:
			timer.stop()
			host.queue_free()
			return
		_emit_ritual_pulse(polygon, center, pulse_index)
		pulse_index += 1
	)
	timer.start()

func _emit_ritual_pulse(polygon: PackedVector2Array, center: Vector2, index: int) -> void:
	var target: Node2D = _find_best_target_in_polygon(polygon, center)
	if target == null:
		return
	var angle: float = TAU * float(index) / float(max(1, ritual_pulse_count))
	var origin: Vector2 = center + Vector2.RIGHT.rotated(angle) * 68.0
	SkillEffectManager.create_line_effect({
		"start": origin,
		"end": target.global_position,
		"width": 10.0,
		"damage": 0,
		"damage_interval": 0.2,
		"duration": 0.2,
		"color": Color(0.72, 0.24, 0.56, 0.9)
	})
	_apply_damage(target, ritual_damage)
	_apply_status(target, "curse", curse_duration, float(curse_damage), 1, 0.8)
	_apply_status(target, "fear", hex_fear_duration, 1.0, 1, 0.2)
	_emit_hex_rebound(polygon, center, target, int(round(float(ritual_damage) * rebound_damage_ratio)))
	_chain_ritual_damage(target.global_position, target)

func _emit_hex_rebound(polygon: PackedVector2Array, center: Vector2, primary_target: Node2D, rebound_damage: int) -> void:
	var rebound_target: Node2D = _find_rebound_target_outside_polygon(polygon, center, primary_target)
	if rebound_target == null:
		return
	SkillEffectManager.create_line_effect({
		"start": primary_target.global_position,
		"end": rebound_target.global_position,
		"width": rebound_width,
		"damage": 0,
		"damage_interval": 0.2,
		"duration": 0.16,
		"color": Color(0.78, 0.3, 0.62, 0.86)
	})
	_apply_damage(rebound_target, max(1, rebound_damage))
	_apply_status(rebound_target, "curse", curse_duration * 0.7, float(curse_damage), 1, 0.8)
	_apply_status(rebound_target, "fear", hex_fear_duration * 0.8, 1.0, 1, 0.2)

func _spawn_outer_hex_ring(polygon: PackedVector2Array) -> void:
	var center: Vector2 = _calculate_polygon_center(polygon)
	var radius: float = _polygon_radius(polygon, center)
	var pulse_total: int = int(max(1, outer_hex_count))
	var pulse_index: int = 0
	var host: Node2D = Node2D.new()
	host.name = "VoodooOuterHexHost"
	add_child(host)

	_emit_outer_hex_pulse(center, radius, pulse_index, pulse_total)
	pulse_index += 1

	var timer: Timer = Timer.new()
	timer.wait_time = float(max(0.08, outer_hex_interval))
	timer.one_shot = false
	host.add_child(timer)
	timer.timeout.connect(func() -> void:
		if not is_instance_valid(host):
			return
		if pulse_index >= pulse_total:
			timer.stop()
			host.queue_free()
			return
		_emit_outer_hex_pulse(center, radius, pulse_index, pulse_total)
		pulse_index += 1
	)
	timer.start()

func _spawn_ritual_reflux(polygon: PackedVector2Array) -> void:
	var center: Vector2 = _calculate_polygon_center(polygon)
	var radius: float = _polygon_radius(polygon, center)
	var pulse_total: int = int(max(1, ritual_reflux_count))
	var pulse_index: int = 0
	var host: Node2D = Node2D.new()
	host.name = "VoodooRitualRefluxHost"
	add_child(host)

	var timer: Timer = Timer.new()
	timer.wait_time = max(0.08, ritual_reflux_interval)
	timer.one_shot = false
	host.add_child(timer)
	timer.timeout.connect(func() -> void:
		if not is_instance_valid(host):
			return
		if pulse_index >= pulse_total:
			timer.stop()
			host.queue_free()
			return
		_emit_ritual_reflux(polygon, center, radius, pulse_index, pulse_total)
		pulse_index += 1
	)
	timer.start()

func _emit_ritual_reflux(
	polygon: PackedVector2Array,
	center: Vector2,
	radius: float,
	index: int,
	total: int
) -> void:
	var target: Node2D = _find_any_outside_enemy(polygon, center, radius * 2.0)
	var start: Vector2
	if target != null:
		start = target.global_position
	else:
		var angle: float = TAU * float(index) / float(max(1, total))
		start = center + Vector2.RIGHT.rotated(angle) * radius * 1.5
	SkillEffectManager.create_line_effect({
		"start": start,
		"end": center,
		"width": rebound_width * 1.15,
		"damage": 0,
		"damage_interval": 0.2,
		"duration": 0.2,
		"color": Color(0.92, 0.42, 0.78, 0.92)
	})
	_apply_line_burst_damage(start, center, 12.0, ritual_reflux_damage)
	_apply_pull_to_point(center, radius * 1.05, hex_nail_pull * 0.8)

func _emit_outer_hex_pulse(center: Vector2, radius: float, index: int, total: int) -> void:
	var angle: float = TAU * float(index) / float(max(1, total))
	var facing: Vector2 = Vector2.RIGHT.rotated(angle)
	_apply_outer_hex_sector(
		center,
		radius * max(1.02, outer_hex_inner_ratio),
		radius * max(1.14, outer_hex_outer_ratio),
		facing,
		cos(deg_to_rad(20.0)),
		outer_hex_damage
	)

func _apply_outer_hex_sector(
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
		_apply_status(enemy, "curse", curse_duration * 0.7, float(curse_damage), 1, 0.8)
		_apply_status(enemy, "slow", 0.8, pin_slow_value * 0.7, 1, 0.1)
		enemy.global_position -= dir_norm * 18.0

func _apply_radius_curse(center: Vector2, radius: float, damage: int, fear_duration: float) -> void:
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
		_apply_status(enemy, "curse", curse_duration * 0.7, float(curse_damage), 1, 0.8)
		_apply_status(enemy, "slow", 0.8, pin_slow_value * 0.7, 1, 0.1)
		if fear_duration > 0.01:
			_apply_status(enemy, "fear", fear_duration, 1.0, 1, 0.2)

func _apply_directional_drag(center: Vector2, radius: float, dir: Vector2, drag_amount: float) -> void:
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
		enemy.global_position += safe_dir * drag_amount

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

func _chain_ritual_damage(center: Vector2, primary_target: Node2D) -> void:
	var chain_count: int = 0
	var enemies: Array = get_tree().get_nodes_in_group("enemies")
	for enemy_obj: Variant in enemies:
		if enemy_obj == null or not is_instance_valid(enemy_obj):
			continue
		if not (enemy_obj is Node2D):
			continue
		var enemy: Node2D = enemy_obj
		if enemy == primary_target:
			continue
		if enemy.global_position.distance_to(center) > ritual_chain_radius:
			continue
		SkillEffectManager.create_line_effect({
			"start": center,
			"end": enemy.global_position,
			"width": 7.0,
			"damage": 0,
			"damage_interval": 0.2,
			"duration": 0.16,
			"color": Color(0.66, 0.2, 0.5, 0.82)
		})
		_apply_damage(enemy, int(max(1, ritual_damage - 6)))
		_apply_status(enemy, "curse", curse_duration * 0.8, float(curse_damage), 1, 0.8)
		chain_count += 1
		if chain_count >= ritual_chain_targets:
			break

func _find_two_nearest_enemies(center: Vector2, range_radius: float) -> Array[Node2D]:
	var first_enemy: Node2D = null
	var second_enemy: Node2D = null
	var first_dist: float = range_radius + 0.001
	var second_dist: float = range_radius + 0.001
	var enemies: Array = get_tree().get_nodes_in_group("enemies")
	for enemy_obj: Variant in enemies:
		if enemy_obj == null or not is_instance_valid(enemy_obj):
			continue
		if not (enemy_obj is Node2D):
			continue
		var enemy: Node2D = enemy_obj
		var dist: float = enemy.global_position.distance_to(center)
		if dist > range_radius:
			continue
		if dist < first_dist:
			second_dist = first_dist
			second_enemy = first_enemy
			first_dist = dist
			first_enemy = enemy
		elif dist < second_dist:
			second_dist = dist
			second_enemy = enemy

	var result: Array[Node2D] = []
	if first_enemy != null:
		result.append(first_enemy)
	if second_enemy != null:
		result.append(second_enemy)
	return result

func _find_best_target_in_polygon(polygon: PackedVector2Array, center: Vector2) -> Node2D:
	var enemies: Array = get_tree().get_nodes_in_group("enemies")
	var best_enemy: Node2D = null
	var best_score: float = -1.0
	for enemy_obj: Variant in enemies:
		if enemy_obj == null or not is_instance_valid(enemy_obj):
			continue
		if not (enemy_obj is Node2D):
			continue
		var enemy: Node2D = enemy_obj
		if not Geometry2D.is_point_in_polygon(enemy.global_position, polygon):
			continue
		var hp_ratio: float = _get_enemy_hp_ratio(enemy)
		var dist: float = enemy.global_position.distance_to(center)
		var score: float = (1.0 - hp_ratio) * 1.7 + (1.0 / float(max(1.0, dist * 0.01)))
		if score > best_score:
			best_score = score
			best_enemy = enemy
	return best_enemy

func _find_rebound_target_outside_polygon(
	polygon: PackedVector2Array,
	center: Vector2,
	primary_target: Node2D
) -> Node2D:
	var enemies: Array = get_tree().get_nodes_in_group("enemies")
	var best_enemy: Node2D = null
	var best_score: float = -1.0
	var base_radius: float = _polygon_radius(polygon, center)
	var search_radius: float = base_radius * 1.9
	for enemy_obj: Variant in enemies:
		if enemy_obj == null or not is_instance_valid(enemy_obj):
			continue
		if not (enemy_obj is Node2D):
			continue
		var enemy: Node2D = enemy_obj
		if enemy == primary_target:
			continue
		if Geometry2D.is_point_in_polygon(enemy.global_position, polygon):
			continue
		var dist: float = enemy.global_position.distance_to(center)
		if dist > search_radius:
			continue
		var hp_ratio: float = _get_enemy_hp_ratio(enemy)
		var score: float = (1.0 - hp_ratio) * 1.5 + (dist / max(1.0, search_radius))
		if score > best_score:
			best_score = score
			best_enemy = enemy
	return best_enemy

func _find_any_outside_enemy(polygon: PackedVector2Array, center: Vector2, search_radius: float) -> Node2D:
	var best_enemy: Node2D = null
	var best_dist: float = search_radius + 1.0
	var enemies: Array = get_tree().get_nodes_in_group("enemies")
	for enemy_obj: Variant in enemies:
		if enemy_obj == null or not is_instance_valid(enemy_obj):
			continue
		if not (enemy_obj is Node2D):
			continue
		var enemy: Node2D = enemy_obj
		if Geometry2D.is_point_in_polygon(enemy.global_position, polygon):
			continue
		var dist: float = enemy.global_position.distance_to(center)
		if dist > search_radius:
			continue
		if dist < best_dist:
			best_dist = dist
			best_enemy = enemy
	return best_enemy

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
		_apply_damage(enemy, max(1, damage))
		_apply_status(enemy, "curse", curse_duration * 0.7, float(curse_damage), 1, 0.8)
		_apply_status(enemy, "slow", 0.8, pin_slow_value * 0.7, 1, 0.1)

func _get_enemy_hp_ratio(enemy: Node2D) -> float:
	if not enemy.has_node("HealthComponent"):
		return 1.0
	var hc: Node = enemy.get_node("HealthComponent")
	var current_hp: float = 0.0
	var max_hp: float = 0.0
	if "current_health" in hc:
		current_hp = float(hc.get("current_health"))
	if "max_health" in hc:
		max_hp = float(hc.get("max_health"))
	if max_hp <= 0.0:
		return 1.0
	return float(clamp(current_hp / max_hp, 0.0, 1.0))

func _cache_hex_window(polygon: PackedVector2Array, duration: float) -> void:
	if not is_instance_valid(skill_owner):
		return
	var center: Vector2 = _calculate_polygon_center(polygon)
	var radius: float = _polygon_radius(polygon, center)
	var expire_msec: int = Time.get_ticks_msec() + int(round(float(max(0.2, duration)) * 1000.0))
	skill_owner.set_meta(HEX_META_CENTER, center)
	skill_owner.set_meta(HEX_META_RADIUS, radius)
	skill_owner.set_meta(HEX_META_EXPIRE_MSEC, expire_msec)

func _polygon_radius(polygon: PackedVector2Array, center: Vector2) -> float:
	var radius: float = 0.0
	for point: Vector2 in polygon:
		radius = float(max(radius, center.distance_to(point)))
	return float(max(20.0, radius))

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
	return Color(0.5, 0.1, 0.4, 1.0)

func _get_closure_color() -> Color:
	return Color(0.4, 0.05, 0.3, 1.0)
