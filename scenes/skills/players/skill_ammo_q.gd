extends SkillDrawingBase
class_name SkillAmmoQ

var line_damage_amp: float = 0.22
var line_damage: int = 12
var supply_cooldown_reduction: float = 0.24
var supply_attack_boost: float = 0.25
var buff_duration: float = 5.0
var suppression_slow: float = 0.28
var closure_burst_damage: int = 26
var closure_mark_amp: float = 0.18
var supply_node_spacing: float = 170.0
var supply_node_radius: float = 108.0
var supply_node_duration: float = 5.2
var supply_node_heal: int = 3
var crossfire_shots: int = 5
var crossfire_interval: float = 0.28
var crossfire_damage: int = 18
var crossfire_width: float = 36.0
var convoy_pulse_count: int = 6
var convoy_pulse_interval: float = 0.16
var convoy_pulse_radius: float = 62.0
var convoy_pulse_damage: int = 14
var perimeter_barrage_count: int = 7
var perimeter_barrage_interval: float = 0.2
var perimeter_barrage_damage: int = 18
var perimeter_band_inner_ratio: float = 1.02
var perimeter_band_outer_ratio: float = 1.36
var supply_projectile_step_distance: float = 52.0
var supply_projectile_tick_interval: float = 0.05
var supply_projectile_hit_radius: float = 56.0
var supply_projectile_damage: int = 16
var supply_projectile_push: float = 22.0
var supply_recall_delay: float = 0.22
var supply_recall_pulse_count: int = 5
var supply_recall_damage: int = 17
var supply_recall_pull: float = 28.0
var closure_return_count: int = 6
var closure_return_interval: float = 0.18
var closure_return_damage: int = 19

const SUPPLY_META_CENTER: String = "ammo_supply_center"
const SUPPLY_META_RADIUS: String = "ammo_supply_radius"
const SUPPLY_META_EXPIRE_MSEC: String = "ammo_supply_expire_msec"

var _open_supply_nodes: Array[Vector2] = []

func _enter_planning_mode() -> void:
	_open_supply_nodes.clear()
	super._enter_planning_mode()

func _spawn_line_effect(start: Vector2, end: Vector2) -> void:
	var duration: float = _get_line_duration()
	SkillEffectManager.create_debuff_zone({
		"start": start,
		"end": end,
		"width": 22.0,
		"duration": duration,
		"debuff_type": "damage_amp",
		"debuff_value": line_damage_amp,
		"debuff_duration": 2.0,
		"tick_interval": 0.4,
		"damage": line_damage,
		"damage_interval": 0.4,
		"color": Color(0.25, 0.75, 0.95, 0.55)
	})

	SkillEffectManager.create_debuff_zone({
		"start": start,
		"end": end,
		"width": 18.0,
		"duration": duration,
		"debuff_type": "slow",
		"debuff_value": suppression_slow,
		"debuff_duration": 1.2,
		"tick_interval": 0.4,
		"color": Color(0.2, 0.62, 0.85, 0.22)
	})

	_spawn_link_suppression(start, end, duration)
	_spawn_supply_convoy(start, end)
	_launch_supply_projectile(start, end)
	_deploy_supply_node_if_needed(start)
	_deploy_supply_node_if_needed(end)

func _spawn_area_effect(polygon: PackedVector2Array) -> void:
	if polygon.size() < 3:
		return
	SkillEffectManager.create_buff_zone({
		"polygon": polygon,
		"duration": buff_duration,
		"buff_type": "cooldown_reduction",
		"buff_value": supply_cooldown_reduction,
		"tick_interval": 0.5,
		"color": Color(0.2, 0.55, 0.75, 0.45)
	})

	SkillEffectManager.create_buff_zone({
		"polygon": polygon,
		"duration": buff_duration,
		"buff_type": "attack_boost",
		"buff_value": supply_attack_boost,
		"tick_interval": 0.5,
		"color": Color(0.35, 0.8, 1.0, 0.25)
	})

	SkillEffectManager.create_debuff_zone({
		"polygon": polygon,
		"duration": buff_duration,
		"debuff_type": "damage_amp",
		"debuff_value": closure_mark_amp,
		"debuff_duration": 1.1,
		"tick_interval": 0.45,
		"color": Color(0.2, 0.62, 0.86, 0.18)
	})

	_apply_closure_burst(polygon, closure_burst_damage)
	_cache_supply_window(polygon, buff_duration)
	var center: Vector2 = _polygon_center(polygon)
	var radius: float = _polygon_radius(polygon, center)
	_spawn_crossfire(center, radius, max(2.0, buff_duration * 0.65))
	_spawn_perimeter_barrage(center, radius)
	_spawn_return_crossfire(center, radius)

func _spawn_link_suppression(start: Vector2, end: Vector2, duration: float) -> void:
	SkillEffectManager.create_line_effect({
		"start": start,
		"end": end,
		"width": 14.0,
		"damage": max(1, int(round(float(line_damage) * 0.75))),
		"damage_interval": 0.18,
		"duration": max(0.35, duration * 0.25),
		"color": Color(0.6, 0.9, 1.0, 0.55)
	})

func _spawn_supply_convoy(start: Vector2, finish: Vector2) -> void:
	var pulse_total: int = int(max(1, convoy_pulse_count))
	var pulse_index: int = 0
	var host: Node2D = Node2D.new()
	host.name = "AmmoSupplyConvoyHost"
	add_child(host)

	_emit_supply_convoy_pulse(start, finish, pulse_index, pulse_total)
	pulse_index += 1

	var timer: Timer = Timer.new()
	timer.wait_time = max(0.08, convoy_pulse_interval)
	timer.one_shot = false
	host.add_child(timer)
	timer.timeout.connect(func() -> void:
		if not is_instance_valid(host):
			return
		if pulse_index >= pulse_total:
			timer.stop()
			host.queue_free()
			return
		_emit_supply_convoy_pulse(start, finish, pulse_index, pulse_total)
		pulse_index += 1
	)
	timer.start()

func _launch_supply_projectile(start: Vector2, finish: Vector2) -> void:
	var seg: Vector2 = finish - start
	var length: float = seg.length()
	if length <= 1.0:
		return
	var move_dir: Vector2 = seg / length
	var host: Node2D = Node2D.new()
	host.name = "AmmoSupplyProjectileHost"
	add_child(host)

	var step_total: int = int(max(2.0, ceil(length / max(12.0, supply_projectile_step_distance))))
	var step_index: int = 0
	var timer: Timer = Timer.new()
	timer.wait_time = max(0.03, supply_projectile_tick_interval)
	timer.one_shot = false
	host.add_child(timer)
	timer.timeout.connect(func() -> void:
		if not is_instance_valid(host):
			return
		if step_index > step_total:
			timer.stop()
			host.queue_free()
			_spawn_supply_recall(finish, start, move_dir)
			return
		_emit_supply_projectile_tick(start, finish, step_index, step_total, move_dir)
		step_index += 1
	)
	timer.start()

func _spawn_supply_recall(from_pos: Vector2, to_pos: Vector2, move_dir: Vector2) -> void:
	var tree: SceneTree = get_tree()
	if tree == null:
		return
	tree.create_timer(max(0.05, supply_recall_delay)).timeout.connect(func() -> void:
		if not is_inside_tree():
			return
		var host: Node2D = Node2D.new()
		host.name = "AmmoSupplyRecallHost"
		add_child(host)
		var pulse_total: int = int(max(1, supply_recall_pulse_count))
		var pulse_index: int = 0
		var timer: Timer = Timer.new()
		timer.wait_time = max(0.06, convoy_pulse_interval * 0.9)
		timer.one_shot = false
		host.add_child(timer)
		timer.timeout.connect(func() -> void:
			if not is_instance_valid(host):
				return
			if pulse_index >= pulse_total:
				timer.stop()
				host.queue_free()
				return
			_emit_supply_recall_tick(from_pos, to_pos, pulse_index, pulse_total, move_dir)
			pulse_index += 1
		)
		timer.start()
	)

func _emit_supply_projectile_tick(
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
		"width": 18.0,
		"damage": 0,
		"damage_interval": 0.2,
		"duration": 0.14,
		"color": Color(0.72, 0.98, 1.12, 0.9)
	})
	_apply_radius_burst(current, supply_projectile_hit_radius, supply_projectile_damage)
	_apply_directional_push(current, supply_projectile_hit_radius * 1.2, move_dir, supply_projectile_push)
	if index == total:
		spawn_skill_vfx(current, Color(0.8, 1.0, 1.2, 0.86), 0.42)

func _emit_supply_recall_tick(
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
	var start: Vector2 = center - tangent * 52.0
	var end: Vector2 = center + tangent * 52.0
	SkillEffectManager.create_line_effect({
		"start": start,
		"end": end,
		"width": 14.0,
		"damage": 0,
		"damage_interval": 0.2,
		"duration": 0.16,
		"color": Color(0.85, 1.08, 1.2, 0.9)
	})
	_apply_radius_burst(center, supply_projectile_hit_radius * 0.9, supply_recall_damage)
	_apply_pull_to_center(center, supply_projectile_hit_radius * 1.4, supply_recall_pull)

func _spawn_return_crossfire(center: Vector2, radius: float) -> void:
	var shot_total: int = int(max(1, closure_return_count))
	var shot_index: int = 0
	var host: Node2D = Node2D.new()
	host.name = "AmmoClosureReturnHost"
	add_child(host)

	var timer: Timer = Timer.new()
	timer.wait_time = max(0.08, closure_return_interval)
	timer.one_shot = false
	host.add_child(timer)
	timer.timeout.connect(func() -> void:
		if not is_instance_valid(host):
			return
		if shot_index >= shot_total:
			timer.stop()
			host.queue_free()
			return
		_emit_return_crossfire(center, radius, shot_index, shot_total)
		shot_index += 1
	)
	timer.start()

func _emit_return_crossfire(center: Vector2, radius: float, index: int, total: int) -> void:
	var angle: float = TAU * float(index) / float(max(1, total))
	var dir: Vector2 = Vector2.RIGHT.rotated(angle)
	var start: Vector2 = center + dir * radius * 1.34
	var end: Vector2 = center - dir * radius * 0.2
	SkillEffectManager.create_line_effect({
		"start": start,
		"end": end,
		"width": crossfire_width * 0.72,
		"damage": 0,
		"damage_interval": 0.2,
		"duration": 0.16,
		"color": Color(0.82, 1.0, 1.18, 0.92)
	})
	_apply_line_burst_damage(start, end, crossfire_width * 0.48, closure_return_damage)
	_apply_pull_to_center(center, radius * 0.92, supply_recall_pull * 0.6)

func _emit_supply_convoy_pulse(start: Vector2, finish: Vector2, index: int, total: int) -> void:
	var t: float = 0.0
	if total > 1:
		t = float(index) / float(total - 1)
	var center: Vector2 = start.lerp(finish, t)
	var pulse_poly: PackedVector2Array = _build_circle_polygon(center, convoy_pulse_radius, 12)
	SkillEffectManager.create_area_effect({
		"polygon": pulse_poly,
		"damage": convoy_pulse_damage,
		"damage_interval": 0.12,
		"duration": 0.18,
		"color": Color(0.62, 0.92, 1.0, 0.36)
	})
	_apply_radius_burst(center, convoy_pulse_radius, convoy_pulse_damage)
	spawn_skill_vfx(center, Color(0.7, 0.95, 1.0, 0.62), 0.22)

func _deploy_supply_node_if_needed(pos: Vector2) -> void:
	if _open_supply_nodes.is_empty():
		_open_supply_nodes.append(pos)
		_spawn_supply_node(pos)
		return
	var last_pos: Vector2 = _open_supply_nodes[_open_supply_nodes.size() - 1]
	if last_pos.distance_to(pos) < supply_node_spacing:
		return
	_open_supply_nodes.append(pos)
	_spawn_supply_node(pos)

func _spawn_supply_node(center: Vector2) -> void:
	var polygon: PackedVector2Array = _build_circle_polygon(center, supply_node_radius, 14)
	SkillEffectManager.create_buff_zone({
		"polygon": polygon,
		"duration": supply_node_duration,
		"buff_type": "attack_boost",
		"buff_value": supply_attack_boost * 0.75,
		"tick_interval": 0.45,
		"color": Color(0.3, 0.76, 0.95, 0.34)
	})
	SkillEffectManager.create_buff_zone({
		"polygon": polygon,
		"duration": supply_node_duration,
		"buff_type": "cooldown_reduction",
		"buff_value": supply_cooldown_reduction * 0.75,
		"tick_interval": 0.45,
		"color": Color(0.18, 0.55, 0.82, 0.22)
	})
	SkillEffectManager.create_buff_zone({
		"polygon": polygon,
		"duration": supply_node_duration,
		"buff_type": "heal",
		"buff_value": float(supply_node_heal),
		"tick_interval": 0.5,
		"color": Color(0.55, 0.9, 1.0, 0.14)
	})
	SkillEffectManager.create_debuff_zone({
		"polygon": polygon,
		"duration": supply_node_duration,
		"debuff_type": "slow",
		"debuff_value": suppression_slow * 0.8,
		"debuff_duration": 0.9,
		"tick_interval": 0.35,
		"color": Color(0.2, 0.55, 0.8, 0.12)
	})
	spawn_skill_vfx(center, Color(0.48, 0.85, 1.0, 0.72), 0.42)

func _spawn_crossfire(center: Vector2, radius: float, duration: float) -> void:
	var max_shots: int = int(max(1, crossfire_shots))
	var shot_index: int = 0
	var live_until_msec: int = Time.get_ticks_msec() + int(round(max(0.25, duration) * 1000.0))
	var host: Node2D = Node2D.new()
	host.name = "AmmoCrossfireController"
	add_child(host)

	_fire_cross_pattern(center, radius, shot_index, max_shots)
	shot_index += 1

	var timer: Timer = Timer.new()
	timer.wait_time = max(0.08, crossfire_interval)
	timer.one_shot = false
	host.add_child(timer)
	timer.timeout.connect(func() -> void:
		if not is_instance_valid(host):
			return
		if shot_index >= max_shots or Time.get_ticks_msec() >= live_until_msec:
			timer.stop()
			host.queue_free()
			return
		_fire_cross_pattern(center, radius, shot_index, max_shots)
		shot_index += 1
	)
	timer.start()

func _fire_cross_pattern(center: Vector2, radius: float, index: int, total_shots: int) -> void:
	var angle: float = (TAU / float(max(1, total_shots))) * float(index)
	var dir: Vector2 = Vector2.RIGHT.rotated(angle)
	var perp: Vector2 = Vector2(-dir.y, dir.x)
	_fire_cross_line(center - dir * radius, center + dir * radius)
	_fire_cross_line(center - perp * radius, center + perp * radius)

func _spawn_perimeter_barrage(center: Vector2, radius: float) -> void:
	var barrage_total: int = int(max(1, perimeter_barrage_count))
	var barrage_index: int = 0
	var host: Node2D = Node2D.new()
	host.name = "AmmoPerimeterBarrageHost"
	add_child(host)

	_emit_perimeter_barrage(center, radius, barrage_index, barrage_total)
	barrage_index += 1

	var timer: Timer = Timer.new()
	timer.wait_time = max(0.08, perimeter_barrage_interval)
	timer.one_shot = false
	host.add_child(timer)
	timer.timeout.connect(func() -> void:
		if not is_instance_valid(host):
			return
		if barrage_index >= barrage_total:
			timer.stop()
			host.queue_free()
			return
		_emit_perimeter_barrage(center, radius, barrage_index, barrage_total)
		barrage_index += 1
	)
	timer.start()

func _emit_perimeter_barrage(center: Vector2, radius: float, index: int, total: int) -> void:
	var angle: float = TAU * float(index) / float(max(1, total))
	var facing: Vector2 = Vector2.RIGHT.rotated(angle)
	var tangent: Vector2 = Vector2(-facing.y, facing.x)
	var band_center: Vector2 = center + facing * radius * 1.20
	var half_len: float = radius * 0.40
	var start: Vector2 = band_center - tangent * half_len
	var end: Vector2 = band_center + tangent * half_len
	SkillEffectManager.create_line_effect({
		"start": start,
		"end": end,
		"width": crossfire_width * 0.7,
		"damage": 0,
		"damage_interval": 0.2,
		"duration": 0.14,
		"color": Color(0.76, 0.95, 1.0, 0.88)
	})
	_apply_perimeter_sector_damage(
		center,
		radius * max(1.01, perimeter_band_inner_ratio),
		radius * max(1.12, perimeter_band_outer_ratio),
		facing,
		cos(deg_to_rad(18.0)),
		perimeter_barrage_damage
	)

func _fire_cross_line(start: Vector2, end: Vector2) -> void:
	SkillEffectManager.create_line_effect({
		"start": start,
		"end": end,
		"width": crossfire_width,
		"damage": crossfire_damage,
		"damage_interval": 0.1,
		"duration": 0.35,
		"color": Color(0.6, 0.9, 1.0, 0.72)
	})
	_apply_line_burst_damage(start, end, crossfire_width * 0.52, crossfire_damage)

func _apply_line_burst_damage(start: Vector2, end: Vector2, hit_radius: float, damage: int) -> void:
	var enemies: Array = get_tree().get_nodes_in_group("enemies")
	var hit_count: int = 0
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
		_apply_status(enemy, "marked", 1.0, closure_mark_amp, 1, 0.2)
		hit_count += 1
	if hit_count > 0:
		var mid: Vector2 = start.lerp(end, 0.5)
		spawn_skill_vfx(mid, Color(0.66, 0.95, 1.0, 0.72), 0.38)

func _apply_radius_burst(center: Vector2, radius: float, damage: int) -> void:
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
		_apply_status(enemy, "marked", 1.0, closure_mark_amp, 1, 0.3)
		_apply_status(enemy, "slow", 0.8, suppression_slow * 0.92, 1, 0.1)

func _apply_directional_push(center: Vector2, radius: float, dir: Vector2, push_amount: float) -> void:
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

func _apply_pull_to_center(center: Vector2, radius: float, pull_amount: float) -> void:
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

func _apply_perimeter_sector_damage(
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
		_apply_status(enemy, "slow", 0.9, suppression_slow + 0.12, 1, 0.1)
		_apply_status(enemy, "marked", 1.0, closure_mark_amp * 0.8, 1, 0.3)
		enemy.global_position += dir_norm * 18.0

func _apply_closure_burst(polygon: PackedVector2Array, damage: int) -> void:
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
		_apply_damage(enemy, max(1, damage))
		_apply_status(enemy, "marked", 1.4, closure_mark_amp, 1, 0.3)
		hit_count += 1
	if hit_count > 0:
		var center: Vector2 = _polygon_center(polygon)
		Global.spawn_floating_text(center, "SUPPRESS x%d" % hit_count, Color(0.4, 0.88, 1.0))
		spawn_skill_vfx(center, Color(0.38, 0.8, 1.0, 0.8), 0.56)

func _cache_supply_window(polygon: PackedVector2Array, duration: float) -> void:
	if not is_instance_valid(skill_owner):
		return
	var center: Vector2 = _polygon_center(polygon)
	var radius: float = _polygon_radius(polygon, center)
	var expire_msec: int = Time.get_ticks_msec() + int(round(max(0.2, duration) * 1000.0))
	skill_owner.set_meta(SUPPLY_META_CENTER, center)
	skill_owner.set_meta(SUPPLY_META_RADIUS, radius)
	skill_owner.set_meta(SUPPLY_META_EXPIRE_MSEC, expire_msec)

func _build_circle_polygon(center: Vector2, radius: float, segments: int) -> PackedVector2Array:
	var points: PackedVector2Array = PackedVector2Array()
	var segment_count: int = segments
	if segment_count < 8:
		segment_count = 8
	for i: int in range(segment_count):
		var ang: float = TAU * float(i) / float(segment_count)
		points.append(center + Vector2.RIGHT.rotated(ang) * radius)
	return points

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
		radius = max(radius, center.distance_to(point))
	return max(8.0, radius)

func _apply_damage(enemy: Node2D, amount: int) -> void:
	if not enemy.has_node("HealthComponent"):
		return
	var hc: Node = enemy.get_node("HealthComponent")
	if hc != null and hc.has_method("take_damage"):
		hc.call("take_damage", max(1, amount))

func _apply_status(enemy: Node2D, status_name: String, duration: float, value: float, stacks: int = 1, tick_interval: float = 0.6) -> void:
	if enemy.has_method("apply_status"):
		enemy.call("apply_status", status_name, max(0.1, duration), value, max(1, stacks), max(0.05, tick_interval))

func _get_line_color() -> Color:
	return Color(0.25, 0.75, 0.95, 1.0)

func _get_closure_color() -> Color:
	return Color(0.2, 0.55, 0.75, 1.0)
