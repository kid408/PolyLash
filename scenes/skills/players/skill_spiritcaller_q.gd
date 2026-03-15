extends SkillQBase
class_name SkillSpiritcallerQ

var totem_damage: int = 24
var totem_duration: float = 10.0
var chain_damage: int = 18
var slow_value: float = 0.52

var relay_spacing: float = 170.0
var relay_interval: float = 0.36
var relay_radius: float = 230.0
var relay_tick_damage: int = 12

var quake_damage: int = 40
var quake_duration: float = 4.5
var overload_damage_amp: float = 0.24
var overload_pulse_count: int = 6
var overload_pulse_interval: float = 0.24
var overload_pulse_damage: int = 22
var relay_lance_step_distance: float = 50.0
var relay_lance_tick_interval: float = 0.05
var relay_lance_hit_radius: float = 54.0
var relay_lance_damage: int = 16
var relay_lance_push: float = 16.0
var relay_recall_delay: float = 0.2
var relay_recall_count: int = 5
var relay_recall_damage: int = 20
var relay_recall_pull: float = 20.0
var overload_reel_count: int = 5
var overload_reel_interval: float = 0.16
var overload_reel_damage: int = 20

const TOTEM_META_CENTER: String = "spiritcaller_field_center"
const TOTEM_META_RADIUS: String = "spiritcaller_field_radius"
const TOTEM_META_EXPIRE_MSEC: String = "spiritcaller_field_expire_msec"

var _relay_points: Array[Vector2] = []

func _enter_planning_mode() -> void:
	_relay_points.clear()
	super._enter_planning_mode()

func _spawn_line_effect(start: Vector2, end: Vector2) -> void:
	_spawn_relays_along_segment(start, end)
	_launch_relay_lance(start, end)
	SkillEffectManager.create_line_effect({
		"start": start,
		"end": end,
		"width": 10.0,
		"damage": chain_damage,
		"damage_interval": 0.4,
		"duration": _get_line_duration(),
		"color": Color(0.7, 0.4, 1.0, 0.65)
	})

func _spawn_area_effect(polygon: PackedVector2Array) -> void:
	if polygon.size() < 3:
		return

	SkillEffectManager.create_area_effect({
		"polygon": polygon,
		"damage": quake_damage,
		"damage_interval": 0.45,
		"duration": quake_duration,
		"color": Color(0.5, 0.2, 0.7, 0.45)
	})
	SkillEffectManager.create_debuff_zone({
		"polygon": polygon,
		"duration": quake_duration,
		"debuff_type": "slow",
		"debuff_value": slow_value,
		"debuff_duration": 1.8,
		"tick_interval": 0.45,
		"color": Color(0.4, 0.2, 0.6, 0.3)
	})
	SkillEffectManager.create_debuff_zone({
		"polygon": polygon,
		"duration": quake_duration,
		"debuff_type": "damage_amp",
		"debuff_value": overload_damage_amp,
		"debuff_duration": quake_duration,
		"tick_interval": 0.75,
		"color": Color(0.6, 0.3, 0.9, 0.2)
	})

	_spawn_overload_pulses(polygon)
	_spawn_overload_reel(polygon)
	_cache_totem_window(polygon, quake_duration)

func _launch_relay_lance(start: Vector2, finish: Vector2) -> void:
	var seg: Vector2 = finish - start
	var length: float = seg.length()
	if length <= 1.0:
		return
	var move_dir: Vector2 = seg / length
	var host: Node2D = Node2D.new()
	host.name = "NewTotemRelayLanceHost"
	add_child(host)

	var step_total: int = int(max(2.0, ceil(length / max(12.0, relay_lance_step_distance))))
	var step_index: int = 0
	var timer: Timer = Timer.new()
	timer.wait_time = max(0.03, relay_lance_tick_interval)
	timer.one_shot = false
	host.add_child(timer)
	timer.timeout.connect(func() -> void:
		if not is_instance_valid(host):
			return
		if step_index > step_total:
			timer.stop()
			host.queue_free()
			_spawn_relay_recall(finish, start, move_dir)
			return
		_emit_relay_lance_tick(start, finish, step_index, step_total, move_dir)
		step_index += 1
	)
	timer.start()

func _spawn_relay_recall(from_pos: Vector2, to_pos: Vector2, move_dir: Vector2) -> void:
	var tree: SceneTree = get_tree()
	if tree == null:
		return
	tree.create_timer(max(0.05, relay_recall_delay)).timeout.connect(func() -> void:
		if not is_inside_tree():
			return
		var host: Node2D = Node2D.new()
		host.name = "NewTotemRelayRecallHost"
		add_child(host)
		var pulse_total: int = int(max(1, relay_recall_count))
		var pulse_index: int = 0
		var timer: Timer = Timer.new()
		timer.wait_time = max(0.06, relay_lance_tick_interval * 1.6)
		timer.one_shot = false
		host.add_child(timer)
		timer.timeout.connect(func() -> void:
			if not is_instance_valid(host):
				return
			if pulse_index >= pulse_total:
				timer.stop()
				host.queue_free()
				return
			_emit_relay_recall_tick(from_pos, to_pos, pulse_index, pulse_total, move_dir)
			pulse_index += 1
		)
		timer.start()
	)

func _emit_relay_lance_tick(start: Vector2, finish: Vector2, index: int, total: int, move_dir: Vector2) -> void:
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
		"color": Color(0.86, 0.62, 1.0, 0.9)
	})
	_apply_radius_relay_damage(current, relay_lance_hit_radius, relay_lance_damage)
	_apply_direction_push(current, relay_lance_hit_radius * 1.18, move_dir, relay_lance_push)

func _emit_relay_recall_tick(
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
		"width": 12.0,
		"damage": 0,
		"damage_interval": 0.2,
		"duration": 0.16,
		"color": Color(0.92, 0.74, 1.0, 0.92)
	})
	_apply_line_burst_damage(start, end, 11.0, relay_recall_damage)
	_apply_pull_to_point(center, relay_lance_hit_radius * 1.55, relay_recall_pull)

func _spawn_overload_reel(polygon: PackedVector2Array) -> void:
	var center: Vector2 = _calculate_polygon_center(polygon)
	var radius: float = _polygon_radius(polygon, center)
	var sweep_total: int = int(max(1, overload_reel_count))
	var sweep_index: int = 0
	var host: Node2D = Node2D.new()
	host.name = "NewTotemOverloadReelHost"
	add_child(host)

	var timer: Timer = Timer.new()
	timer.wait_time = max(0.08, overload_reel_interval)
	timer.one_shot = false
	host.add_child(timer)
	timer.timeout.connect(func() -> void:
		if not is_instance_valid(host):
			return
		if sweep_index >= sweep_total:
			timer.stop()
			host.queue_free()
			return
		_emit_overload_reel(center, radius, sweep_index, sweep_total)
		sweep_index += 1
	)
	timer.start()

func _emit_overload_reel(center: Vector2, radius: float, index: int, total: int) -> void:
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
		"color": Color(0.86, 0.7, 1.0, 0.9)
	})
	_apply_line_burst_damage(start, end, 11.0, overload_reel_damage)
	_apply_pull_to_point(center, radius * 1.02, relay_recall_pull * 0.55)

func _spawn_relays_along_segment(start: Vector2, end: Vector2) -> void:
	var seg: Vector2 = end - start
	var length: float = seg.length()
	if length <= 1.0:
		_deploy_relay_if_needed(start)
		return
	var dir: Vector2 = seg / length
	var spacing: float = float(max(64.0, relay_spacing))
	var cursor: float = 0.0
	while cursor <= length:
		_deploy_relay_if_needed(start + dir * cursor)
		cursor += spacing
	if fmod(length, spacing) > 20.0:
		_deploy_relay_if_needed(end)

func _deploy_relay_if_needed(pos: Vector2) -> void:
	if _relay_points.is_empty():
		_relay_points.append(pos)
		_spawn_relay(pos)
		return
	var last_pos: Vector2 = _relay_points[_relay_points.size() - 1]
	if last_pos.distance_to(pos) < relay_spacing:
		return
	_relay_points.append(pos)
	_spawn_relay(pos)

func _spawn_relay(pos: Vector2) -> void:
	var relay: Node2D = Node2D.new()
	relay.name = "NewTotemRelay"
	relay.global_position = pos
	add_child(relay)
	relay.add_to_group("player_skill_effects")

	SkillEffectManager.create_summon({
		"position": pos,
		"summon_type": "turret",
		"duration": totem_duration,
		"damage": totem_damage,
		"attack_interval": 1.15,
		"attack_range": 220.0,
		"max_count": 6,
		"owner_skill_id": "skill_spiritcaller_q",
		"color": Color(0.6, 0.3, 0.8)
	})

	var elapsed: float = 0.0
	var timer: Timer = Timer.new()
	timer.wait_time = float(max(0.08, relay_interval))
	timer.one_shot = false
	relay.add_child(timer)
	timer.timeout.connect(func() -> void:
		if not is_instance_valid(relay):
			return
		elapsed += timer.wait_time
		if elapsed >= totem_duration:
			timer.stop()
			relay.queue_free()
			return
		_emit_relay_chain(relay.global_position)
	)
	timer.start()

	spawn_skill_vfx(pos, Color(0.72, 0.42, 0.95, 0.76), 0.32)

func _emit_relay_chain(center: Vector2) -> void:
	var target: Node2D = _find_nearest_enemy(center, relay_radius)
	if target == null:
		return
	SkillEffectManager.create_line_effect({
		"start": center,
		"end": target.global_position,
		"width": 8.0,
		"damage": 0,
		"damage_interval": 0.2,
		"duration": 0.16,
		"color": Color(0.75, 0.5, 1.0, 0.9)
	})
	_apply_damage(target, relay_tick_damage)
	_apply_status(target, "slow", 0.9, slow_value, 1, 0.1)

func _spawn_overload_pulses(polygon: PackedVector2Array) -> void:
	var center: Vector2 = _calculate_polygon_center(polygon)
	var radius: float = _polygon_radius(polygon, center)
	var pulse_total: int = int(max(1, overload_pulse_count))
	var pulse_index: int = 0
	var host: Node2D = Node2D.new()
	host.name = "NewTotemOverloadPulses"
	add_child(host)

	_emit_overload_pulse(center, radius, pulse_index)
	pulse_index += 1

	var timer: Timer = Timer.new()
	timer.wait_time = float(max(0.08, overload_pulse_interval))
	timer.one_shot = false
	host.add_child(timer)
	timer.timeout.connect(func() -> void:
		if not is_instance_valid(host):
			return
		if pulse_index >= pulse_total:
			timer.stop()
			host.queue_free()
			return
		_emit_overload_pulse(center, radius, pulse_index)
		pulse_index += 1
	)
	timer.start()

func _emit_overload_pulse(center: Vector2, radius: float, index: int) -> void:
	var angle: float = TAU * float(index) / float(max(1, overload_pulse_count))
	var start: Vector2 = center + Vector2.RIGHT.rotated(angle) * (radius + 70.0)
	var end: Vector2 = center
	SkillEffectManager.create_line_effect({
		"start": start,
		"end": end,
		"width": 14.0,
		"damage": 0,
		"damage_interval": 0.2,
		"duration": 0.2,
		"color": Color(0.82, 0.6, 1.0, 0.88)
	})
	_apply_line_burst_damage(start, end, 12.0, overload_pulse_damage)

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
		_apply_status(enemy, "marked", 1.0, overload_damage_amp, 1, 0.3)

func _apply_radius_relay_damage(center: Vector2, radius: float, damage: int) -> void:
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
		_apply_status(enemy, "slow", 0.9, slow_value, 1, 0.1)

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

func _cache_totem_window(polygon: PackedVector2Array, duration: float) -> void:
	if not is_instance_valid(skill_owner):
		return
	var center: Vector2 = _calculate_polygon_center(polygon)
	var radius: float = _polygon_radius(polygon, center)
	var expire_msec: int = Time.get_ticks_msec() + int(round(float(max(0.2, duration)) * 1000.0))
	skill_owner.set_meta(TOTEM_META_CENTER, center)
	skill_owner.set_meta(TOTEM_META_RADIUS, radius)
	skill_owner.set_meta(TOTEM_META_EXPIRE_MSEC, expire_msec)

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
	return Color(0.6, 0.3, 0.8, 1.0)

func _get_closure_color() -> Color:
	return Color(0.5, 0.2, 0.7, 1.0)

