extends SkillDrawingBase
class_name SkillGlacierQ

var wall_duration: float = 5.0
var wall_width: float = 16.0
var freeze_duration: float = 2.0
var frost_contact_damage: int = 12
var frost_contact_interval: float = 0.45

var shard_spacing: float = 170.0
var shard_duration: float = 4.8
var shard_interval: float = 0.3
var shard_trigger_radius: float = 120.0
var shard_blast_radius: float = 88.0
var shard_blast_damage: int = 16

var blizzard_duration: float = 5.6
var blizzard_damage: int = 20
var deep_slow: float = 0.62
var shatter_sweep_count: int = 6
var shatter_sweep_interval: float = 0.24
var shatter_sweep_damage: int = 18
var frost_lance_step_distance: float = 50.0
var frost_lance_tick_interval: float = 0.05
var frost_lance_hit_radius: float = 52.0
var frost_lance_damage: int = 16
var frost_lance_push: float = 14.0
var frost_recall_delay: float = 0.2
var frost_recall_count: int = 5
var frost_recall_damage: int = 20
var frost_recall_pull: float = 22.0
var frost_reel_count: int = 5
var frost_reel_interval: float = 0.16
var frost_reel_damage: int = 20
const GLACIER_ACTIVE_META: String = "glacier_zone_active_until_msec"

var _shard_points: Array[Vector2] = []

func _enter_planning_mode() -> void:
	_shard_points.clear()
	super._enter_planning_mode()

func _spawn_line_effect(start: Vector2, end: Vector2) -> void:
	var duration: float = float(max(wall_duration, _get_line_duration()))
	SkillEffectManager.create_wall_effect({
		"start": start,
		"end": end,
		"width": wall_width,
		"duration": duration,
		"block_enemies": true,
		"block_bullets": true,
		"contact_damage": frost_contact_damage,
		"contact_interval": frost_contact_interval,
		"color": Color(0.5, 0.8, 1.0, 0.7)
	})

	_launch_frost_lance(start, end)
	_spawn_shards_along_segment(start, end)

func _spawn_area_effect(polygon: PackedVector2Array) -> void:
	if polygon.size() < 3:
		return
	_mark_glacier_active(blizzard_duration + 0.4)

	SkillEffectManager.create_debuff_zone({
		"polygon": polygon,
		"duration": blizzard_duration,
		"debuff_type": "freeze",
		"debuff_value": 0.0,
		"debuff_duration": freeze_duration,
		"tick_interval": 1.15,
		"color": Color(0.35, 0.65, 1.0, 0.45)
	})

	SkillEffectManager.create_debuff_zone({
		"polygon": polygon,
		"duration": blizzard_duration,
		"debuff_type": "slow",
		"debuff_value": deep_slow,
		"debuff_duration": 1.8,
		"tick_interval": 0.35,
		"color": Color(0.45, 0.8, 1.0, 0.25)
	})

	SkillEffectManager.create_area_effect({
		"polygon": polygon,
		"damage": blizzard_damage,
		"damage_interval": 0.65,
		"duration": blizzard_duration,
		"color": Color(0.28, 0.58, 0.95, 0.2)
	})

	_spawn_shatter_sweeps(polygon)
	_spawn_frost_reel(polygon)

func _spawn_shards_along_segment(start: Vector2, end: Vector2) -> void:
	var seg: Vector2 = end - start
	var length: float = seg.length()
	if length <= 1.0:
		_deploy_shard_if_needed(start)
		return
	var dir: Vector2 = seg / length
	var spacing: float = float(max(56.0, shard_spacing))
	var cursor: float = 0.0
	while cursor <= length:
		_deploy_shard_if_needed(start + dir * cursor)
		cursor += spacing
	if fmod(length, spacing) > 20.0:
		_deploy_shard_if_needed(end)

func _deploy_shard_if_needed(pos: Vector2) -> void:
	if _shard_points.is_empty():
		_shard_points.append(pos)
		_spawn_ice_shard(pos)
		return
	var last_pos: Vector2 = _shard_points[_shard_points.size() - 1]
	if last_pos.distance_to(pos) < shard_spacing:
		return
	_shard_points.append(pos)
	_spawn_ice_shard(pos)

func _spawn_ice_shard(pos: Vector2) -> void:
	var shard: Node2D = Node2D.new()
	shard.name = "GlacierIceShard"
	shard.global_position = pos
	add_child(shard)
	shard.add_to_group("player_skill_effects")

	var elapsed: float = 0.0
	var exploded: bool = false
	var timer: Timer = Timer.new()
	timer.wait_time = float(max(0.08, shard_interval))
	timer.one_shot = false
	shard.add_child(timer)
	timer.timeout.connect(func() -> void:
		if not is_instance_valid(shard):
			return
		elapsed += timer.wait_time
		if elapsed >= shard_duration:
			timer.stop()
			shard.queue_free()
			return
		var target: Node2D = _find_nearest_enemy(shard.global_position, shard_trigger_radius)
		if target == null:
			return
		_apply_status(target, "slow", 0.9, deep_slow, 1, 0.1)
		if exploded:
			return
		exploded = true
		_trigger_shard_blast(shard.global_position)
	)
	timer.start()

	spawn_skill_vfx(pos, Color(0.62, 0.88, 1.0, 0.76), 0.3)

func _trigger_shard_blast(center: Vector2) -> void:
	var blast_poly: PackedVector2Array = _build_circle_polygon(center, shard_blast_radius, 16)
	SkillEffectManager.create_area_effect({
		"polygon": blast_poly,
		"damage": shard_blast_damage,
		"damage_interval": 0.1,
		"duration": 0.22,
		"color": Color(0.78, 0.95, 1.0, 0.4)
	})
	var enemies: Array = get_tree().get_nodes_in_group("enemies")
	for enemy_obj: Variant in enemies:
		if enemy_obj == null or not is_instance_valid(enemy_obj):
			continue
		if not (enemy_obj is Node2D):
			continue
		var enemy: Node2D = enemy_obj
		if enemy.global_position.distance_to(center) > shard_blast_radius:
			continue
		_apply_status(enemy, "freeze", freeze_duration * 0.75, 0.0, 1, 0.1)
		_apply_damage(enemy, shard_blast_damage)
	spawn_skill_vfx(center, Color(0.82, 0.98, 1.0, 0.84), 0.4)

func _spawn_shatter_sweeps(polygon: PackedVector2Array) -> void:
	var center: Vector2 = _calculate_polygon_center(polygon)
	var radius: float = _polygon_radius(polygon, center)
	var sweep_total: int = int(max(1, shatter_sweep_count))
	var sweep_index: int = 0
	var host: Node2D = Node2D.new()
	host.name = "GlacierShatterSweeps"
	add_child(host)

	_emit_shatter_sweep(center, radius, sweep_index)
	sweep_index += 1

	var timer: Timer = Timer.new()
	timer.wait_time = float(max(0.08, shatter_sweep_interval))
	timer.one_shot = false
	host.add_child(timer)
	timer.timeout.connect(func() -> void:
		if not is_instance_valid(host):
			return
		if sweep_index >= sweep_total:
			timer.stop()
			host.queue_free()
			return
		_emit_shatter_sweep(center, radius, sweep_index)
		sweep_index += 1
	)
	timer.start()

func _emit_shatter_sweep(center: Vector2, radius: float, index: int) -> void:
	var angle: float = TAU * float(index) / float(max(1, shatter_sweep_count))
	var dir: Vector2 = Vector2.RIGHT.rotated(angle)
	var start: Vector2 = center + dir * (radius + 68.0)
	var end: Vector2 = center - dir * (radius * 0.4)
	SkillEffectManager.create_line_effect({
		"start": start,
		"end": end,
		"width": 20.0,
		"damage": 0,
		"damage_interval": 0.2,
		"duration": 0.2,
		"color": Color(0.76, 0.94, 1.0, 0.9)
	})
	_apply_line_burst_damage(start, end, 12.0, shatter_sweep_damage)

func _launch_frost_lance(start: Vector2, finish: Vector2) -> void:
	var seg: Vector2 = finish - start
	var length: float = seg.length()
	if length <= 1.0:
		return
	var move_dir: Vector2 = seg / length
	var host: Node2D = Node2D.new()
	host.name = "GlacierFrostLanceHost"
	add_child(host)

	var step_total: int = int(max(2.0, ceil(length / max(12.0, frost_lance_step_distance))))
	var step_index: int = 0
	var timer: Timer = Timer.new()
	timer.wait_time = max(0.03, frost_lance_tick_interval)
	timer.one_shot = false
	host.add_child(timer)
	timer.timeout.connect(func() -> void:
		if not is_instance_valid(host):
			return
		if step_index > step_total:
			timer.stop()
			host.queue_free()
			_spawn_frost_recall(finish, start, move_dir)
			return
		_emit_frost_lance_tick(start, finish, step_index, step_total, move_dir)
		step_index += 1
	)
	timer.start()

func _spawn_frost_recall(from_pos: Vector2, to_pos: Vector2, move_dir: Vector2) -> void:
	var tree: SceneTree = get_tree()
	if tree == null:
		return
	tree.create_timer(max(0.05, frost_recall_delay)).timeout.connect(func() -> void:
		if not is_inside_tree():
			return
		var host: Node2D = Node2D.new()
		host.name = "GlacierFrostRecallHost"
		add_child(host)
		var pulse_total: int = int(max(1, frost_recall_count))
		var pulse_index: int = 0
		var timer: Timer = Timer.new()
		timer.wait_time = max(0.06, frost_lance_tick_interval * 1.6)
		timer.one_shot = false
		host.add_child(timer)
		timer.timeout.connect(func() -> void:
			if not is_instance_valid(host):
				return
			if pulse_index >= pulse_total:
				timer.stop()
				host.queue_free()
				return
			_emit_frost_recall_tick(from_pos, to_pos, pulse_index, pulse_total, move_dir)
			pulse_index += 1
		)
		timer.start()
	)

func _emit_frost_lance_tick(start: Vector2, finish: Vector2, index: int, total: int, move_dir: Vector2) -> void:
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
		"color": Color(0.82, 0.98, 1.0, 0.9)
	})
	_apply_radius_frost_damage(current, frost_lance_hit_radius, frost_lance_damage)
	_apply_direction_push(current, frost_lance_hit_radius * 1.18, move_dir, frost_lance_push)

func _emit_frost_recall_tick(
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
		"color": Color(0.9, 1.0, 1.0, 0.92)
	})
	_apply_line_burst_damage(start, end, 11.0, frost_recall_damage)
	_apply_pull_to_point(center, frost_lance_hit_radius * 1.55, frost_recall_pull)

func _spawn_frost_reel(polygon: PackedVector2Array) -> void:
	var center: Vector2 = _calculate_polygon_center(polygon)
	var radius: float = _polygon_radius(polygon, center)
	var sweep_total: int = int(max(1, frost_reel_count))
	var sweep_index: int = 0
	var host: Node2D = Node2D.new()
	host.name = "GlacierFrostReelHost"
	add_child(host)

	var timer: Timer = Timer.new()
	timer.wait_time = max(0.08, frost_reel_interval)
	timer.one_shot = false
	host.add_child(timer)
	timer.timeout.connect(func() -> void:
		if not is_instance_valid(host):
			return
		if sweep_index >= sweep_total:
			timer.stop()
			host.queue_free()
			return
		_emit_frost_reel(center, radius, sweep_index, sweep_total)
		sweep_index += 1
	)
	timer.start()

func _emit_frost_reel(center: Vector2, radius: float, index: int, total: int) -> void:
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
		"color": Color(0.84, 1.0, 1.0, 0.9)
	})
	_apply_line_burst_damage(start, end, 11.0, frost_reel_damage)
	_apply_pull_to_point(center, radius * 1.02, frost_recall_pull * 0.55)

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
		_apply_status(enemy, "freeze", freeze_duration * 0.65, 0.0, 1, 0.1)

func _apply_radius_frost_damage(center: Vector2, radius: float, damage: int) -> void:
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
		_apply_status(enemy, "slow", 0.9, deep_slow, 1, 0.1)

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

func _build_circle_polygon(center: Vector2, radius: float, segments: int) -> PackedVector2Array:
	var points: PackedVector2Array = PackedVector2Array()
	var segment_count: int = int(max(8, segments))
	for i: int in range(segment_count):
		var ang: float = TAU * float(i) / float(segment_count)
		points.append(center + Vector2.RIGHT.rotated(ang) * radius)
	return points

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
	return Color(0.5, 0.8, 1.0, 1.0)

func _get_closure_color() -> Color:
	return Color(0.3, 0.6, 1.0, 1.0)

func _mark_glacier_active(duration: float) -> void:
	if not is_instance_valid(skill_owner):
		return
	var expire_msec: int = Time.get_ticks_msec() + int(round(max(0.2, duration) * 1000.0))
	skill_owner.set_meta(GLACIER_ACTIVE_META, expire_msec)
