extends SkillDrawingBase
class_name SkillIllusionistQ

var wall_width: float = 16.0
var wall_duration: float = 5.5
var mirror_mark_amp: float = 0.2
var mirror_fear_duration: float = 0.75

var gate_spacing: float = 170.0
var gate_duration: float = 4.8
var gate_interval: float = 0.32
var gate_range: float = 260.0
var gate_shot_damage: int = 11
var gate_side_offset: float = 54.0

var phantom_damage: int = 18
var phantom_duration: float = 8.0
var phantom_count: int = 3

var replay_sweep_damage: int = 18
var replay_sweep_width: float = 22.0
var replay_interval: float = 0.2
var shard_step_distance: float = 50.0
var shard_tick_interval: float = 0.05
var shard_hit_radius: float = 54.0
var shard_hit_damage: int = 17
var shard_push: float = 16.0
var shard_recall_delay: float = 0.2
var shard_recall_count: int = 5
var shard_recall_damage: int = 19
var shard_recall_pull: float = 22.0
var fold_reflux_count: int = 6
var fold_reflux_interval: float = 0.16
var fold_reflux_damage: int = 20

const MIRROR_META_CENTER: String = "illusion_mirror_center"
const MIRROR_META_RADIUS: String = "illusion_mirror_radius"
const MIRROR_META_EXPIRE_MSEC: String = "illusion_mirror_expire_msec"

var _mirror_points: Array[Vector2] = []

func _enter_planning_mode() -> void:
	_mirror_points.clear()
	super._enter_planning_mode()

func _spawn_line_effect(start: Vector2, end: Vector2) -> void:
	SkillEffectManager.create_wall_effect({
		"start": start,
		"end": end,
		"width": wall_width,
		"duration": float(max(wall_duration, _get_line_duration())),
		"block_enemies": true,
		"block_bullets": true,
		"reflect_bullets": true,
		"color": Color(0.72, 0.72, 0.92, 0.74)
	})

	SkillEffectManager.create_debuff_zone({
		"start": start,
		"end": end,
		"width": 18.0,
		"duration": _get_line_duration(),
		"debuff_type": "damage_amp",
		"debuff_value": mirror_mark_amp,
		"debuff_duration": 2.2,
		"tick_interval": 0.55,
		"color": Color(0.65, 0.65, 0.9, 0.28)
	})

	var dir: Vector2 = (end - start).normalized()
	if dir.length_squared() <= 0.0001:
		dir = Vector2.RIGHT
	_deploy_gate_if_needed(start, dir)
	_deploy_gate_if_needed(end, dir)
	_launch_mirror_shard(start, end)

func _spawn_area_effect(polygon: PackedVector2Array) -> void:
	if polygon.size() < 3:
		return

	var center: Vector2 = _calculate_polygon_center(polygon)
	SkillEffectManager.create_debuff_zone({
		"polygon": polygon,
		"duration": phantom_duration,
		"debuff_type": "fear",
		"debuff_value": 1.0,
		"debuff_duration": mirror_fear_duration,
		"tick_interval": 1.0,
		"color": Color(0.58, 0.58, 0.85, 0.2)
	})

	_spawn_phantom_ring(center)
	_spawn_replay_sweeps(polygon, center)
	var radius: float = _polygon_radius(polygon, center)
	_spawn_fold_reflux(center, radius)
	_cache_mirror_window(polygon, phantom_duration)

func _launch_mirror_shard(start: Vector2, finish: Vector2) -> void:
	var seg: Vector2 = finish - start
	var length: float = seg.length()
	if length <= 1.0:
		return
	var move_dir: Vector2 = seg / length
	var host: Node2D = Node2D.new()
	host.name = "IllusionMirrorShardHost"
	add_child(host)

	var step_total: int = int(max(2.0, ceil(length / max(12.0, shard_step_distance))))
	var step_index: int = 0
	var timer: Timer = Timer.new()
	timer.wait_time = max(0.03, shard_tick_interval)
	timer.one_shot = false
	host.add_child(timer)
	timer.timeout.connect(func() -> void:
		if not is_instance_valid(host):
			return
		if step_index > step_total:
			timer.stop()
			host.queue_free()
			_spawn_shard_recall(finish, start, move_dir)
			return
		_emit_shard_tick(start, finish, step_index, step_total, move_dir)
		step_index += 1
	)
	timer.start()

func _spawn_shard_recall(from_pos: Vector2, to_pos: Vector2, move_dir: Vector2) -> void:
	var tree: SceneTree = get_tree()
	if tree == null:
		return
	tree.create_timer(max(0.05, shard_recall_delay)).timeout.connect(func() -> void:
		if not is_inside_tree():
			return
		var host: Node2D = Node2D.new()
		host.name = "IllusionShardRecallHost"
		add_child(host)
		var pulse_total: int = int(max(1, shard_recall_count))
		var pulse_index: int = 0
		var timer: Timer = Timer.new()
		timer.wait_time = max(0.06, replay_interval * 0.8)
		timer.one_shot = false
		host.add_child(timer)
		timer.timeout.connect(func() -> void:
			if not is_instance_valid(host):
				return
			if pulse_index >= pulse_total:
				timer.stop()
				host.queue_free()
				return
			_emit_shard_recall_tick(from_pos, to_pos, pulse_index, pulse_total, move_dir)
			pulse_index += 1
		)
		timer.start()
	)

func _emit_shard_tick(start: Vector2, finish: Vector2, index: int, total: int, move_dir: Vector2) -> void:
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
		"color": Color(0.88, 0.88, 1.08, 0.92)
	})
	_apply_radius_shard_damage(current, shard_hit_radius, shard_hit_damage, move_dir, shard_push)

func _emit_shard_recall_tick(
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
	var start: Vector2 = center - tangent * 68.0
	var end: Vector2 = center + tangent * 68.0
	SkillEffectManager.create_line_effect({
		"start": start,
		"end": end,
		"width": 12.0,
		"damage": 0,
		"damage_interval": 0.2,
		"duration": 0.16,
		"color": Color(0.96, 0.96, 1.15, 0.92)
	})
	_apply_line_burst_damage(start, end, 12.0, shard_recall_damage)
	_apply_pull_to_point(center, shard_hit_radius * 1.4, shard_recall_pull)

func _deploy_gate_if_needed(pos: Vector2, dir: Vector2) -> void:
	if _mirror_points.is_empty():
		_mirror_points.append(pos)
		_spawn_mirror_gate(pos, dir)
		return
	var last_pos: Vector2 = _mirror_points[_mirror_points.size() - 1]
	if last_pos.distance_to(pos) < gate_spacing:
		return
	_mirror_points.append(pos)
	_spawn_mirror_gate(pos, dir)

func _spawn_mirror_gate(pos: Vector2, dir: Vector2) -> void:
	var gate: Node2D = Node2D.new()
	gate.name = "IllusionMirrorGate"
	gate.global_position = pos
	add_child(gate)
	gate.add_to_group("player_skill_effects")

	var elapsed: float = 0.0
	var timer: Timer = Timer.new()
	timer.wait_time = float(max(0.08, gate_interval))
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
		_emit_mirror_shot(gate.global_position, dir)
	)
	timer.start()

	spawn_skill_vfx(pos, Color(0.72, 0.72, 0.95, 0.72), 0.3)

func _emit_mirror_shot(center: Vector2, dir: Vector2) -> void:
	var target: Node2D = _find_nearest_enemy(center, gate_range)
	if target == null:
		return
	var side: Vector2 = Vector2(-dir.y, dir.x)
	if side.length_squared() <= 0.0001:
		side = Vector2.UP
	var origin_a: Vector2 = center + side * gate_side_offset
	var origin_b: Vector2 = center - side * gate_side_offset

	SkillEffectManager.create_line_effect({
		"start": origin_a,
		"end": target.global_position,
		"width": 8.0,
		"damage": 0,
		"damage_interval": 0.2,
		"duration": 0.16,
		"color": Color(0.76, 0.76, 0.98, 0.88)
	})
	SkillEffectManager.create_line_effect({
		"start": origin_b,
		"end": target.global_position,
		"width": 8.0,
		"damage": 0,
		"damage_interval": 0.2,
		"duration": 0.16,
		"color": Color(0.62, 0.62, 0.94, 0.82)
	})

	_apply_damage(target, gate_shot_damage)
	_apply_status(target, "marked", 1.2, mirror_mark_amp, 1, 0.3)

func _spawn_phantom_ring(center: Vector2) -> void:
	if phantom_count <= 0:
		return
	var count: int = int(max(1, phantom_count))
	for i: int in range(count):
		var angle: float = TAU * float(i) / float(count)
		var pos: Vector2 = center + Vector2.RIGHT.rotated(angle) * 52.0
		SkillEffectManager.create_summon({
			"position": pos,
			"summon_type": "phantom",
			"duration": phantom_duration,
			"damage": phantom_damage,
			"attack_interval": 0.85,
			"attack_range": 180.0,
			"max_count": count,
			"owner_skill_id": "skill_illusionist_q",
			"color": Color(0.7, 0.7, 0.9, 0.66)
		})

func _spawn_replay_sweeps(polygon: PackedVector2Array, center: Vector2) -> void:
	var edge_count: int = polygon.size()
	if edge_count < 2:
		return
	var sweep_total: int = edge_count
	var sweep_index: int = 0
	var host: Node2D = Node2D.new()
	host.name = "IllusionReplaySweeps"
	add_child(host)

	_emit_replay_sweep(polygon, center, sweep_index)
	sweep_index += 1

	var timer: Timer = Timer.new()
	timer.wait_time = float(max(0.08, replay_interval))
	timer.one_shot = false
	host.add_child(timer)
	timer.timeout.connect(func() -> void:
		if not is_instance_valid(host):
			return
		if sweep_index >= sweep_total:
			timer.stop()
			host.queue_free()
			return
		_emit_replay_sweep(polygon, center, sweep_index)
		sweep_index += 1
	)
	timer.start()

func _spawn_fold_reflux(center: Vector2, radius: float) -> void:
	var sweep_total: int = int(max(1, fold_reflux_count))
	var sweep_index: int = 0
	var host: Node2D = Node2D.new()
	host.name = "IllusionFoldRefluxHost"
	add_child(host)

	var timer: Timer = Timer.new()
	timer.wait_time = max(0.08, fold_reflux_interval)
	timer.one_shot = false
	host.add_child(timer)
	timer.timeout.connect(func() -> void:
		if not is_instance_valid(host):
			return
		if sweep_index >= sweep_total:
			timer.stop()
			host.queue_free()
			return
		_emit_fold_reflux(center, radius, sweep_index, sweep_total)
		sweep_index += 1
	)
	timer.start()

func _emit_fold_reflux(center: Vector2, radius: float, index: int, total: int) -> void:
	var angle: float = TAU * float(index) / float(max(1, total))
	var dir: Vector2 = Vector2.RIGHT.rotated(angle)
	var start: Vector2 = center + dir * radius * 1.32
	var end: Vector2 = center - dir * radius * 0.1
	SkillEffectManager.create_line_effect({
		"start": start,
		"end": end,
		"width": replay_sweep_width * 0.7,
		"damage": 0,
		"damage_interval": 0.2,
		"duration": 0.18,
		"color": Color(1.0, 1.0, 1.2, 0.9)
	})
	_apply_line_burst_damage(start, end, replay_sweep_width * 0.38, fold_reflux_damage)
	_apply_pull_to_point(center, radius * 0.9, shard_recall_pull * 0.75)

func _emit_replay_sweep(polygon: PackedVector2Array, center: Vector2, index: int) -> void:
	var point_count: int = polygon.size()
	if point_count < 2:
		return
	var start: Vector2 = polygon[index % point_count]
	var end: Vector2 = polygon[(index + 1) % point_count]
	var mirror_start: Vector2 = center * 2.0 - start
	var mirror_end: Vector2 = center * 2.0 - end

	SkillEffectManager.create_line_effect({
		"start": start,
		"end": end,
		"width": replay_sweep_width,
		"damage": 0,
		"damage_interval": 0.2,
		"duration": 0.16,
		"color": Color(0.82, 0.82, 1.0, 0.84)
	})
	SkillEffectManager.create_line_effect({
		"start": mirror_start,
		"end": mirror_end,
		"width": replay_sweep_width,
		"damage": 0,
		"damage_interval": 0.2,
		"duration": 0.16,
		"color": Color(0.62, 0.62, 0.95, 0.78)
	})

	_apply_line_burst_damage(start, end, replay_sweep_width * 0.5, replay_sweep_damage)
	_apply_line_burst_damage(mirror_start, mirror_end, replay_sweep_width * 0.45, int(max(1, replay_sweep_damage - 2)))

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
		_apply_status(enemy, "fear", mirror_fear_duration * 0.5, 1.0, 1, 0.2)

func _apply_radius_shard_damage(center: Vector2, radius: float, damage: int, move_dir: Vector2, push_amount: float) -> void:
	var safe_dir: Vector2 = move_dir.normalized()
	if safe_dir.length_squared() <= 0.001:
		safe_dir = Vector2.RIGHT
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
		_apply_status(enemy, "marked", 1.0, mirror_mark_amp * 0.8, 1, 0.3)
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

func _cache_mirror_window(polygon: PackedVector2Array, duration: float) -> void:
	if not is_instance_valid(skill_owner):
		return
	var center: Vector2 = _calculate_polygon_center(polygon)
	var radius: float = _polygon_radius(polygon, center)
	var expire_msec: int = Time.get_ticks_msec() + int(round(float(max(0.2, duration)) * 1000.0))
	skill_owner.set_meta(MIRROR_META_CENTER, center)
	skill_owner.set_meta(MIRROR_META_RADIUS, radius)
	skill_owner.set_meta(MIRROR_META_EXPIRE_MSEC, expire_msec)

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
	return Color(0.7, 0.7, 0.9, 1.0)

func _get_closure_color() -> Color:
	return Color(0.6, 0.6, 0.85, 1.0)
