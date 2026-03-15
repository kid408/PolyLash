extends SkillQBase
class_name SkillBannerQ

var line_speed_boost: float = 0.28
var line_ignore_collision: float = 1.0
var defense_reduction: float = 0.35
var debuff_duration: float = 5.0
var fear_duration: float = 0.9
var rally_attack_boost: float = 0.16
var rally_tick_damage: int = 16
var banner_node_spacing: float = 180.0
var banner_node_radius: float = 92.0
var banner_node_duration: float = 4.2
var vanguard_charge_damage: int = 22
var vanguard_charge_width: float = 34.0
var closure_strike_count: int = 6
var closure_strike_interval: float = 0.26
var closure_strike_damage: int = 20
var banner_lance_step_distance: float = 50.0
var banner_lance_tick_interval: float = 0.05
var banner_lance_hit_radius: float = 56.0
var banner_lance_damage: int = 16
var banner_lance_push: float = 20.0
var banner_recall_delay: float = 0.2
var banner_recall_count: int = 5
var banner_recall_damage: int = 17
var banner_recall_pull: float = 24.0
var closure_return_count: int = 5
var closure_return_interval: float = 0.16
var closure_return_damage: int = 18

const RALLY_META_CENTER: String = "banner_rally_center"
const RALLY_META_RADIUS: String = "banner_rally_radius"
const RALLY_META_EXPIRE_MSEC: String = "banner_rally_expire_msec"

var _line_nodes: Array[Vector2] = []

func _enter_planning_mode() -> void:
	_line_nodes.clear()
	super._enter_planning_mode()

func _spawn_line_effect(start: Vector2, end: Vector2) -> void:
	var duration: float = _get_line_duration()
	SkillEffectManager.create_buff_zone({
		"start": start,
		"end": end,
		"width": 24.0,
		"duration": duration,
		"buff_type": "ignore_collision",
		"buff_value": line_ignore_collision,
		"tick_interval": 0.5,
		"color": Color(0.9, 0.2, 0.2, 0.5)
	})
	SkillEffectManager.create_buff_zone({
		"start": start,
		"end": end,
		"width": 24.0,
		"duration": duration,
		"buff_type": "speed_boost",
		"buff_value": line_speed_boost,
		"tick_interval": 0.5,
		"color": Color(1.0, 0.35, 0.25, 0.3)
	})
	SkillEffectManager.create_debuff_zone({
		"start": start,
		"end": end,
		"width": 18.0,
		"duration": duration,
		"debuff_type": "damage_amp",
		"debuff_value": defense_reduction * 0.55,
		"debuff_duration": 1.3,
		"tick_interval": 0.45,
		"damage": rally_tick_damage,
		"damage_interval": 0.45,
		"color": Color(0.95, 0.4, 0.25, 0.22)
	})

	_spawn_vanguard_charge(start, end)
	_launch_banner_lance(start, end)
	_deploy_banner_node_if_needed(start)
	_deploy_banner_node_if_needed(end)

func _spawn_area_effect(polygon: PackedVector2Array) -> void:
	if polygon.size() < 3:
		return
	SkillEffectManager.create_debuff_zone({
		"polygon": polygon,
		"duration": debuff_duration,
		"debuff_type": "damage_amp",
		"debuff_value": defense_reduction,
		"debuff_duration": debuff_duration,
		"tick_interval": 0.8,
		"color": Color(0.8, 0.1, 0.1, 0.4)
	})
	SkillEffectManager.create_debuff_zone({
		"polygon": polygon,
		"duration": debuff_duration,
		"debuff_type": "fear",
		"debuff_value": 1.0,
		"debuff_duration": fear_duration,
		"tick_interval": 1.1,
		"color": Color(0.9, 0.25, 0.2, 0.25)
	})
	SkillEffectManager.create_buff_zone({
		"polygon": polygon,
		"duration": debuff_duration,
		"buff_type": "attack_boost",
		"buff_value": rally_attack_boost,
		"tick_interval": 0.5,
		"color": Color(1.0, 0.45, 0.3, 0.18)
	})

	_spawn_closure_strikes(polygon)
	var center: Vector2 = _polygon_center(polygon)
	var radius: float = _polygon_radius(polygon, center)
	_spawn_closure_return_sweeps(center, radius)
	_cache_rally_window(polygon, debuff_duration)

func _spawn_vanguard_charge(start: Vector2, end: Vector2) -> void:
	SkillEffectManager.create_line_effect({
		"start": start,
		"end": end,
		"width": max(18.0, vanguard_charge_width * 0.46),
		"damage": 0,
		"damage_interval": 0.2,
		"duration": 0.22,
		"color": Color(1.0, 0.62, 0.4, 0.78)
	})
	_apply_line_burst_damage(start, end, vanguard_charge_width * 0.52, vanguard_charge_damage)

func _launch_banner_lance(start: Vector2, finish: Vector2) -> void:
	var seg: Vector2 = finish - start
	var length: float = seg.length()
	if length <= 1.0:
		return
	var move_dir: Vector2 = seg / length
	var host: Node2D = Node2D.new()
	host.name = "BannerLanceHost"
	add_child(host)

	var step_total: int = int(max(2.0, ceil(length / max(12.0, banner_lance_step_distance))))
	var step_index: int = 0
	var timer: Timer = Timer.new()
	timer.wait_time = max(0.03, banner_lance_tick_interval)
	timer.one_shot = false
	host.add_child(timer)
	timer.timeout.connect(func() -> void:
		if not is_instance_valid(host):
			return
		if step_index > step_total:
			timer.stop()
			host.queue_free()
			_spawn_banner_recall(finish, start, move_dir)
			return
		_emit_banner_lance_tick(start, finish, step_index, step_total, move_dir)
		step_index += 1
	)
	timer.start()

func _spawn_banner_recall(from_pos: Vector2, to_pos: Vector2, move_dir: Vector2) -> void:
	var tree: SceneTree = get_tree()
	if tree == null:
		return
	tree.create_timer(max(0.05, banner_recall_delay)).timeout.connect(func() -> void:
		if not is_inside_tree():
			return
		var host: Node2D = Node2D.new()
		host.name = "BannerRecallHost"
		add_child(host)
		var pulse_total: int = int(max(1, banner_recall_count))
		var pulse_index: int = 0
		var timer: Timer = Timer.new()
		timer.wait_time = max(0.06, closure_strike_interval * 0.7)
		timer.one_shot = false
		host.add_child(timer)
		timer.timeout.connect(func() -> void:
			if not is_instance_valid(host):
				return
			if pulse_index >= pulse_total:
				timer.stop()
				host.queue_free()
				return
			_emit_banner_recall_tick(from_pos, to_pos, pulse_index, pulse_total, move_dir)
			pulse_index += 1
		)
		timer.start()
	)

func _emit_banner_lance_tick(
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
		"width": 16.0,
		"damage": 0,
		"damage_interval": 0.2,
		"duration": 0.12,
		"color": Color(1.08, 0.72, 0.46, 0.94)
	})
	_apply_radius_damage(current, banner_lance_hit_radius, banner_lance_damage)
	_apply_directional_push(current, banner_lance_hit_radius * 1.25, move_dir, banner_lance_push)
	if index == total:
		spawn_skill_vfx(current, Color(1.12, 0.72, 0.5, 0.9), 0.4)

func _emit_banner_recall_tick(
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
		"color": Color(1.18, 0.82, 0.52, 0.92)
	})
	_apply_line_burst_damage(start, end, vanguard_charge_width * 0.45, banner_recall_damage)
	_apply_pull_to_point(center, banner_lance_hit_radius * 1.5, banner_recall_pull)

func _deploy_banner_node_if_needed(pos: Vector2) -> void:
	if _line_nodes.is_empty():
		_line_nodes.append(pos)
		_spawn_banner_node(pos)
		return
	var last_pos: Vector2 = _line_nodes[_line_nodes.size() - 1]
	if last_pos.distance_to(pos) < banner_node_spacing:
		return
	_line_nodes.append(pos)
	_spawn_banner_node(pos)

func _spawn_banner_node(center: Vector2) -> void:
	var polygon: PackedVector2Array = _build_circle_polygon(center, banner_node_radius, 14)
	SkillEffectManager.create_buff_zone({
		"polygon": polygon,
		"duration": banner_node_duration,
		"buff_type": "speed_boost",
		"buff_value": line_speed_boost * 0.8,
		"tick_interval": 0.4,
		"color": Color(1.0, 0.45, 0.35, 0.24)
	})
	SkillEffectManager.create_buff_zone({
		"polygon": polygon,
		"duration": banner_node_duration,
		"buff_type": "attack_boost",
		"buff_value": rally_attack_boost * 0.9,
		"tick_interval": 0.4,
		"color": Color(1.0, 0.52, 0.3, 0.16)
	})
	SkillEffectManager.create_debuff_zone({
		"polygon": polygon,
		"duration": banner_node_duration,
		"debuff_type": "fear",
		"debuff_value": 1.0,
		"debuff_duration": 0.55,
		"tick_interval": 1.05,
		"color": Color(0.95, 0.34, 0.24, 0.18)
	})
	spawn_skill_vfx(center, Color(1.0, 0.5, 0.35, 0.76), 0.36)

func _spawn_closure_strikes(polygon: PackedVector2Array) -> void:
	var center: Vector2 = _polygon_center(polygon)
	var radius: float = _polygon_radius(polygon, center)
	var strike_total: int = int(max(1, closure_strike_count))
	var strike_index: int = 0
	var host: Node2D = Node2D.new()
	host.name = "BannerClosureStrikes"
	add_child(host)

	_fire_closure_strike(center, radius, strike_index, strike_total)
	strike_index += 1

	var timer: Timer = Timer.new()
	timer.wait_time = max(0.08, closure_strike_interval)
	timer.one_shot = false
	host.add_child(timer)
	timer.timeout.connect(func() -> void:
		if not is_instance_valid(host):
			return
		if strike_index >= strike_total:
			timer.stop()
			host.queue_free()
			return
		_fire_closure_strike(center, radius, strike_index, strike_total)
		strike_index += 1
	)
	timer.start()

func _spawn_closure_return_sweeps(center: Vector2, radius: float) -> void:
	var sweep_total: int = int(max(1, closure_return_count))
	var sweep_index: int = 0
	var host: Node2D = Node2D.new()
	host.name = "BannerClosureReturnHost"
	add_child(host)

	var timer: Timer = Timer.new()
	timer.wait_time = max(0.08, closure_return_interval)
	timer.one_shot = false
	host.add_child(timer)
	timer.timeout.connect(func() -> void:
		if not is_instance_valid(host):
			return
		if sweep_index >= sweep_total:
			timer.stop()
			host.queue_free()
			return
		_emit_closure_return_sweep(center, radius, sweep_index, sweep_total)
		sweep_index += 1
	)
	timer.start()

func _emit_closure_return_sweep(center: Vector2, radius: float, index: int, total: int) -> void:
	var angle: float = TAU * float(index) / float(max(1, total))
	var dir: Vector2 = Vector2.RIGHT.rotated(angle)
	var start: Vector2 = center + dir * radius * 1.3
	var end: Vector2 = center - dir * radius * 0.15
	SkillEffectManager.create_line_effect({
		"start": start,
		"end": end,
		"width": max(14.0, vanguard_charge_width * 0.75),
		"damage": 0,
		"damage_interval": 0.2,
		"duration": 0.18,
		"color": Color(1.2, 0.86, 0.56, 0.9)
	})
	_apply_line_burst_damage(start, end, vanguard_charge_width * 0.5, closure_return_damage)
	_apply_pull_to_point(center, radius * 0.95, banner_recall_pull * 0.7)

func _fire_closure_strike(center: Vector2, radius: float, strike_index: int, strike_total: int) -> void:
	var angle: float = TAU * float(strike_index) / float(max(1, strike_total))
	var start: Vector2 = center + Vector2.RIGHT.rotated(angle) * (radius + 78.0)
	var end: Vector2 = center + Vector2.RIGHT.rotated(angle + PI) * (radius * 0.35)
	SkillEffectManager.create_line_effect({
		"start": start,
		"end": end,
		"width": vanguard_charge_width,
		"damage": 0,
		"damage_interval": 0.2,
		"duration": 0.24,
		"color": Color(1.0, 0.68, 0.42, 0.92)
	})
	_apply_line_burst_damage(start, end, vanguard_charge_width * 0.55, closure_strike_damage)

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
		_apply_status(enemy, "marked", 1.1, defense_reduction * 0.35, 1, 0.3)
		_apply_status(enemy, "fear", fear_duration * 0.6, 1.0, 1, 0.2)

func _apply_radius_damage(center: Vector2, radius: float, damage: int) -> void:
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
		_apply_status(enemy, "fear", fear_duration * 0.5, 1.0, 1, 0.2)

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

func _cache_rally_window(polygon: PackedVector2Array, duration: float) -> void:
	if not is_instance_valid(skill_owner):
		return
	var center: Vector2 = _polygon_center(polygon)
	var radius: float = _polygon_radius(polygon, center)
	var expire_msec: int = Time.get_ticks_msec() + int(round(max(0.2, duration) * 1000.0))
	skill_owner.set_meta(RALLY_META_CENTER, center)
	skill_owner.set_meta(RALLY_META_RADIUS, radius)
	skill_owner.set_meta(RALLY_META_EXPIRE_MSEC, expire_msec)

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
	return Color(0.9, 0.2, 0.2, 1.0)

func _get_closure_color() -> Color:
	return Color(0.8, 0.1, 0.1, 1.0)

