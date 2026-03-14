extends SkillDrawingBase
class_name SkillPaladinQ

var wall_width: float = 16.0
var wall_duration: float = 6.0
var reflect_contact_damage: int = 10

var beacon_spacing: float = 170.0
var beacon_duration: float = 4.8
var beacon_interval: float = 0.34
var beacon_radius: float = 220.0
var beacon_smite_damage: int = 12
var beacon_heal_value: int = 2

var heal_value: int = 3
var buff_duration: float = 5.0
var sanctuary_attack_boost: float = 0.3
var sanctuary_damage_amp: float = 0.2
var sanctuary_slow: float = 0.2
var judgement_pulse_count: int = 6
var judgement_interval: float = 0.24
var judgement_damage: int = 22
var holy_lance_step_distance: float = 50.0
var holy_lance_tick_interval: float = 0.05
var holy_lance_hit_radius: float = 54.0
var holy_lance_damage: int = 16
var holy_lance_push: float = 18.0
var holy_recall_delay: float = 0.2
var holy_recall_count: int = 5
var holy_recall_damage: int = 20
var holy_recall_pull: float = 22.0
var sanctuary_reel_count: int = 5
var sanctuary_reel_interval: float = 0.16
var sanctuary_reel_damage: int = 22

const SANCTUARY_META_CENTER: String = "paladin_sanctuary_center"
const SANCTUARY_META_RADIUS: String = "paladin_sanctuary_radius"
const SANCTUARY_META_EXPIRE_MSEC: String = "paladin_sanctuary_expire_msec"

var _beacon_points: Array[Vector2] = []

func _enter_planning_mode() -> void:
	_beacon_points.clear()
	super._enter_planning_mode()

func _spawn_line_effect(start: Vector2, end: Vector2) -> void:
	var duration: float = float(max(wall_duration, _get_line_duration()))
	SkillEffectManager.create_wall_effect({
		"start": start,
		"end": end,
		"width": wall_width,
		"duration": duration,
		"block_enemies": false,
		"block_bullets": true,
		"reflect_bullets": true,
		"contact_damage": reflect_contact_damage,
		"contact_interval": 0.6,
		"color": Color(1.0, 0.85, 0.3, 0.75)
	})

	_launch_holy_lance(start, end)
	_spawn_beacons_along_segment(start, end)

func _spawn_area_effect(polygon: PackedVector2Array) -> void:
	if polygon.size() < 3:
		return
	SkillEffectManager.create_buff_zone({
		"polygon": polygon,
		"duration": buff_duration,
		"buff_type": "heal",
		"buff_value": float(heal_value),
		"tick_interval": 0.45,
		"color": Color(1.0, 0.92, 0.5, 0.45)
	})

	SkillEffectManager.create_buff_zone({
		"polygon": polygon,
		"duration": buff_duration,
		"buff_type": "attack_boost",
		"buff_value": sanctuary_attack_boost,
		"tick_interval": 0.5,
		"color": Color(1.0, 0.88, 0.35, 0.32)
	})

	SkillEffectManager.create_debuff_zone({
		"polygon": polygon,
		"duration": buff_duration,
		"debuff_type": "damage_amp",
		"debuff_value": sanctuary_damage_amp,
		"debuff_duration": buff_duration,
		"tick_interval": 0.8,
		"color": Color(0.95, 0.75, 0.25, 0.25)
	})

	SkillEffectManager.create_debuff_zone({
		"polygon": polygon,
		"duration": buff_duration,
		"debuff_type": "slow",
		"debuff_value": sanctuary_slow,
		"debuff_duration": 1.0,
		"tick_interval": 0.4,
		"color": Color(0.95, 0.8, 0.32, 0.16)
	})

	_spawn_judgement_pulses(polygon)
	_spawn_sanctuary_reel(polygon)
	_cache_sanctuary_window(polygon, buff_duration)

func _launch_holy_lance(start: Vector2, finish: Vector2) -> void:
	var seg: Vector2 = finish - start
	var length: float = seg.length()
	if length <= 1.0:
		return
	var move_dir: Vector2 = seg / length
	var host: Node2D = Node2D.new()
	host.name = "PaladinHolyLanceHost"
	add_child(host)

	var step_total: int = int(max(2.0, ceil(length / max(12.0, holy_lance_step_distance))))
	var step_index: int = 0
	var timer: Timer = Timer.new()
	timer.wait_time = max(0.03, holy_lance_tick_interval)
	timer.one_shot = false
	host.add_child(timer)
	timer.timeout.connect(func() -> void:
		if not is_instance_valid(host):
			return
		if step_index > step_total:
			timer.stop()
			host.queue_free()
			_spawn_holy_recall(finish, start, move_dir)
			return
		_emit_holy_lance_tick(start, finish, step_index, step_total, move_dir)
		step_index += 1
	)
	timer.start()

func _spawn_holy_recall(from_pos: Vector2, to_pos: Vector2, move_dir: Vector2) -> void:
	var tree: SceneTree = get_tree()
	if tree == null:
		return
	tree.create_timer(max(0.05, holy_recall_delay)).timeout.connect(func() -> void:
		if not is_inside_tree():
			return
		var host: Node2D = Node2D.new()
		host.name = "PaladinHolyRecallHost"
		add_child(host)
		var pulse_total: int = int(max(1, holy_recall_count))
		var pulse_index: int = 0
		var timer: Timer = Timer.new()
		timer.wait_time = max(0.06, holy_lance_tick_interval * 1.6)
		timer.one_shot = false
		host.add_child(timer)
		timer.timeout.connect(func() -> void:
			if not is_instance_valid(host):
				return
			if pulse_index >= pulse_total:
				timer.stop()
				host.queue_free()
				return
			_emit_holy_recall_tick(from_pos, to_pos, pulse_index, pulse_total, move_dir)
			pulse_index += 1
		)
		timer.start()
	)

func _emit_holy_lance_tick(start: Vector2, finish: Vector2, index: int, total: int, move_dir: Vector2) -> void:
	var t: float = float(index) / float(max(1, total))
	var prev_t: float = float(max(0, index - 1)) / float(max(1, total))
	var current: Vector2 = start.lerp(finish, t)
	var previous: Vector2 = start.lerp(finish, prev_t)
	SkillEffectManager.create_line_effect({
		"start": previous,
		"end": current,
		"width": 13.0,
		"damage": 0,
		"damage_interval": 0.2,
		"duration": 0.12,
		"color": Color(1.0, 0.95, 0.56, 0.92)
	})
	_apply_radius_smite(current, holy_lance_hit_radius, holy_lance_damage)
	_apply_direction_push(current, holy_lance_hit_radius * 1.18, move_dir, holy_lance_push)

func _emit_holy_recall_tick(
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
		"color": Color(1.0, 0.98, 0.68, 0.92)
	})
	_apply_line_burst_damage(start, end, 12.0, holy_recall_damage)
	_apply_pull_to_point(center, holy_lance_hit_radius * 1.55, holy_recall_pull)

func _spawn_sanctuary_reel(polygon: PackedVector2Array) -> void:
	var center: Vector2 = _polygon_center(polygon)
	var radius: float = _polygon_radius(polygon, center)
	var sweep_total: int = int(max(1, sanctuary_reel_count))
	var sweep_index: int = 0
	var host: Node2D = Node2D.new()
	host.name = "PaladinSanctuaryReelHost"
	add_child(host)

	var timer: Timer = Timer.new()
	timer.wait_time = max(0.08, sanctuary_reel_interval)
	timer.one_shot = false
	host.add_child(timer)
	timer.timeout.connect(func() -> void:
		if not is_instance_valid(host):
			return
		if sweep_index >= sweep_total:
			timer.stop()
			host.queue_free()
			return
		_emit_sanctuary_reel(center, radius, sweep_index, sweep_total)
		sweep_index += 1
	)
	timer.start()

func _emit_sanctuary_reel(center: Vector2, radius: float, index: int, total: int) -> void:
	var angle: float = TAU * float(index) / float(max(1, total))
	var dir: Vector2 = Vector2.RIGHT.rotated(angle)
	var start: Vector2 = center + dir * radius * 1.34
	var end: Vector2 = center - dir * radius * 0.08
	SkillEffectManager.create_line_effect({
		"start": start,
		"end": end,
		"width": 14.0,
		"damage": 0,
		"damage_interval": 0.2,
		"duration": 0.18,
		"color": Color(1.0, 0.95, 0.6, 0.9)
	})
	_apply_line_burst_damage(start, end, 12.0, sanctuary_reel_damage)
	_apply_pull_to_point(center, radius * 1.02, holy_recall_pull * 0.55)

func _spawn_beacons_along_segment(start: Vector2, end: Vector2) -> void:
	var seg: Vector2 = end - start
	var length: float = seg.length()
	if length <= 1.0:
		_deploy_beacon_if_needed(start)
		return
	var dir: Vector2 = seg / length
	var spacing: float = float(max(64.0, beacon_spacing))
	var cursor: float = 0.0
	while cursor <= length:
		_deploy_beacon_if_needed(start + dir * cursor)
		cursor += spacing
	if fmod(length, spacing) > 20.0:
		_deploy_beacon_if_needed(end)

func _deploy_beacon_if_needed(pos: Vector2) -> void:
	if _beacon_points.is_empty():
		_beacon_points.append(pos)
		_spawn_beacon(pos)
		return
	var last_pos: Vector2 = _beacon_points[_beacon_points.size() - 1]
	if last_pos.distance_to(pos) < beacon_spacing:
		return
	_beacon_points.append(pos)
	_spawn_beacon(pos)

func _spawn_beacon(pos: Vector2) -> void:
	var beacon: Node2D = Node2D.new()
	beacon.name = "PaladinBeacon"
	beacon.global_position = pos
	add_child(beacon)
	beacon.add_to_group("player_skill_effects")

	var elapsed: float = 0.0
	var timer: Timer = Timer.new()
	timer.wait_time = float(max(0.08, beacon_interval))
	timer.one_shot = false
	beacon.add_child(timer)
	timer.timeout.connect(func() -> void:
		if not is_instance_valid(beacon):
			return
		elapsed += timer.wait_time
		if elapsed >= beacon_duration:
			timer.stop()
			beacon.queue_free()
			return
		_process_beacon_tick(beacon.global_position)
	)
	timer.start()

	spawn_skill_vfx(pos, Color(1.0, 0.9, 0.45, 0.76), 0.3)

func _process_beacon_tick(center: Vector2) -> void:
	_heal_owner(beacon_heal_value)
	var target: Node2D = _find_nearest_enemy(center, beacon_radius)
	if target == null:
		return
	SkillEffectManager.create_line_effect({
		"start": center,
		"end": target.global_position,
		"width": 8.0,
		"damage": 0,
		"damage_interval": 0.2,
		"duration": 0.16,
		"color": Color(1.0, 0.9, 0.5, 0.9)
	})
	_apply_damage(target, beacon_smite_damage)
	_apply_status(target, "marked", 1.0, sanctuary_damage_amp, 1, 0.3)

func _spawn_judgement_pulses(polygon: PackedVector2Array) -> void:
	var center: Vector2 = _polygon_center(polygon)
	var radius: float = _polygon_radius(polygon, center)
	var pulse_total: int = int(max(1, judgement_pulse_count))
	var pulse_index: int = 0
	var host: Node2D = Node2D.new()
	host.name = "PaladinJudgementPulses"
	add_child(host)

	_emit_judgement_pulse(center, radius, pulse_index)
	pulse_index += 1

	var timer: Timer = Timer.new()
	timer.wait_time = float(max(0.08, judgement_interval))
	timer.one_shot = false
	host.add_child(timer)
	timer.timeout.connect(func() -> void:
		if not is_instance_valid(host):
			return
		if pulse_index >= pulse_total:
			timer.stop()
			host.queue_free()
			return
		_emit_judgement_pulse(center, radius, pulse_index)
		pulse_index += 1
	)
	timer.start()

func _emit_judgement_pulse(center: Vector2, radius: float, index: int) -> void:
	var angle: float = TAU * float(index) / float(max(1, judgement_pulse_count))
	var start: Vector2 = center + Vector2.RIGHT.rotated(angle) * (radius + 72.0)
	var end: Vector2 = center
	SkillEffectManager.create_line_effect({
		"start": start,
		"end": end,
		"width": 16.0,
		"damage": 0,
		"damage_interval": 0.2,
		"duration": 0.2,
		"color": Color(1.0, 0.94, 0.6, 0.88)
	})
	_apply_line_burst_damage(start, end, 12.0, judgement_damage)

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
		_apply_status(enemy, "slow", 0.8, sanctuary_slow, 1, 0.1)

func _apply_radius_smite(center: Vector2, radius: float, damage: int) -> void:
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
		_apply_status(enemy, "marked", 1.0, sanctuary_damage_amp * 0.5, 1, 0.3)

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

func _heal_owner(amount: int) -> void:
	if amount <= 0:
		return
	if not is_instance_valid(skill_owner):
		return
	var hc: Node = skill_owner.get_node_or_null("HealthComponent")
	if hc == null:
		return
	if hc.has_method("heal"):
		hc.call("heal", amount)
		return
	var max_health: int = int(hc.get("max_health"))
	var current_health: int = int(hc.get("current_health"))
	var new_health: int = int(min(max_health, current_health + amount))
	hc.set("current_health", new_health)

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

func _cache_sanctuary_window(polygon: PackedVector2Array, duration: float) -> void:
	if not is_instance_valid(skill_owner):
		return
	var center: Vector2 = _polygon_center(polygon)
	var radius: float = _polygon_radius(polygon, center)
	var expire_msec: int = Time.get_ticks_msec() + int(round(float(max(0.2, duration)) * 1000.0))
	skill_owner.set_meta(SANCTUARY_META_CENTER, center)
	skill_owner.set_meta(SANCTUARY_META_RADIUS, radius)
	skill_owner.set_meta(SANCTUARY_META_EXPIRE_MSEC, expire_msec)

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
	return Color(1.0, 0.85, 0.3, 1.0)

func _get_closure_color() -> Color:
	return Color(1.0, 0.9, 0.4, 1.0)
