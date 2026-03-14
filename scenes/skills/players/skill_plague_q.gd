extends SkillDrawingBase
class_name SkillPlagueQ

var slow_value: float = 0.55
var poison_damage: int = 10
var poison_duration: float = 5.5
var damage_amp_value: float = 0.35
var debuff_zone_duration: float = 6.5
var miasma_damage: int = 18
var curse_value: float = 8.0
var spore_spacing: float = 160.0
var spore_trigger_radius: float = 52.0
var spore_blast_radius: float = 122.0
var spore_arm_delay: float = 0.2
var spore_check_interval: float = 0.12
var outbreak_tick_count: int = 6
var outbreak_tick_interval: float = 0.3
var outbreak_chain_radius: float = 220.0
var outbreak_chain_damage: int = 12
var spore_lance_step_distance: float = 50.0
var spore_lance_tick_interval: float = 0.05
var spore_lance_hit_radius: float = 54.0
var spore_lance_damage: int = 16
var spore_lance_push: float = 16.0
var spore_recall_delay: float = 0.2
var spore_recall_count: int = 5
var spore_recall_damage: int = 20
var spore_recall_pull: float = 22.0
var outbreak_reel_count: int = 5
var outbreak_reel_interval: float = 0.16
var outbreak_reel_damage: int = 20

const MIASMA_META_CENTER: String = "plague_miasma_center"
const MIASMA_META_RADIUS: String = "plague_miasma_radius"
const MIASMA_META_EXPIRE_MSEC: String = "plague_miasma_expire_msec"

var _has_last_spore_anchor: bool = false
var _last_spore_anchor: Vector2 = Vector2.ZERO

func _enter_planning_mode() -> void:
	_has_last_spore_anchor = false
	_last_spore_anchor = Vector2.ZERO
	super._enter_planning_mode()

func _spawn_line_effect(start: Vector2, end: Vector2) -> void:
	SkillEffectManager.create_debuff_zone({
		"start": start,
		"end": end,
		"width": 24.0,
		"duration": _get_line_duration(),
		"debuff_type": "slow",
		"debuff_value": slow_value,
		"debuff_duration": poison_duration,
		"tick_interval": 0.55,
		"color": Color(0.4, 0.7, 0.1, 0.5)
	})
	SkillEffectManager.create_debuff_zone({
		"start": start,
		"end": end,
		"width": 24.0,
		"duration": _get_line_duration(),
		"debuff_type": "poison",
		"debuff_value": poison_damage,
		"debuff_duration": poison_duration,
		"tick_interval": 0.55,
		"color": Color(0.3, 0.5, 0.0, 0.3)
	})

	_launch_spore_lance(start, end)
	_deploy_spores_along_segment(start, end)

func _spawn_area_effect(polygon: PackedVector2Array) -> void:
	if polygon.size() < 3:
		return

	SkillEffectManager.create_debuff_zone({
		"polygon": polygon,
		"duration": debuff_zone_duration,
		"debuff_type": "damage_amp",
		"debuff_value": damage_amp_value,
		"debuff_duration": debuff_zone_duration,
		"tick_interval": 0.65,
		"color": Color(0.4, 0.7, 0.1, 0.4)
	})

	SkillEffectManager.create_area_effect({
		"polygon": polygon,
		"damage": miasma_damage,
		"damage_interval": 0.65,
		"duration": debuff_zone_duration,
		"color": Color(0.28, 0.5, 0.05, 0.22)
	})

	SkillEffectManager.create_debuff_zone({
		"polygon": polygon,
		"duration": debuff_zone_duration,
		"debuff_type": "curse",
		"debuff_value": curse_value,
		"debuff_duration": 2.5,
		"tick_interval": 1.0,
		"color": Color(0.26, 0.42, 0.05, 0.22)
	})

	_spawn_outbreak_chain(polygon)
	_spawn_outbreak_reel(polygon)
	_cache_miasma_window(polygon, debuff_zone_duration)

func _launch_spore_lance(start: Vector2, finish: Vector2) -> void:
	var seg: Vector2 = finish - start
	var length: float = seg.length()
	if length <= 1.0:
		return
	var move_dir: Vector2 = seg / length
	var host: Node2D = Node2D.new()
	host.name = "PlagueSporeLanceHost"
	add_child(host)

	var step_total: int = int(max(2.0, ceil(length / max(12.0, spore_lance_step_distance))))
	var step_index: int = 0
	var timer: Timer = Timer.new()
	timer.wait_time = max(0.03, spore_lance_tick_interval)
	timer.one_shot = false
	host.add_child(timer)
	timer.timeout.connect(func() -> void:
		if not is_instance_valid(host):
			return
		if step_index > step_total:
			timer.stop()
			host.queue_free()
			_spawn_spore_lance_recall(finish, start, move_dir)
			return
		_emit_spore_lance_tick(start, finish, step_index, step_total, move_dir)
		step_index += 1
	)
	timer.start()

func _spawn_spore_lance_recall(from_pos: Vector2, to_pos: Vector2, move_dir: Vector2) -> void:
	var tree: SceneTree = get_tree()
	if tree == null:
		return
	tree.create_timer(max(0.05, spore_recall_delay)).timeout.connect(func() -> void:
		if not is_inside_tree():
			return
		var host: Node2D = Node2D.new()
		host.name = "PlagueSporeLanceRecallHost"
		add_child(host)
		var pulse_total: int = int(max(1, spore_recall_count))
		var pulse_index: int = 0
		var timer: Timer = Timer.new()
		timer.wait_time = max(0.06, spore_lance_tick_interval * 1.6)
		timer.one_shot = false
		host.add_child(timer)
		timer.timeout.connect(func() -> void:
			if not is_instance_valid(host):
				return
			if pulse_index >= pulse_total:
				timer.stop()
				host.queue_free()
				return
			_emit_spore_recall_tick(from_pos, to_pos, pulse_index, pulse_total, move_dir)
			pulse_index += 1
		)
		timer.start()
	)

func _emit_spore_lance_tick(start: Vector2, finish: Vector2, index: int, total: int, move_dir: Vector2) -> void:
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
		"color": Color(0.72, 0.95, 0.4, 0.88)
	})
	_apply_radius_poison_damage(current, spore_lance_hit_radius, spore_lance_damage)
	_apply_direction_push(current, spore_lance_hit_radius * 1.18, move_dir, spore_lance_push)

func _emit_spore_recall_tick(
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
		"color": Color(0.78, 1.0, 0.5, 0.9)
	})
	_apply_line_burst_damage(start, end, 12.0, spore_recall_damage)
	_apply_pull_to_point(center, spore_lance_hit_radius * 1.55, spore_recall_pull)

func _spawn_outbreak_reel(polygon: PackedVector2Array) -> void:
	var center: Vector2 = _polygon_center(polygon)
	var radius: float = _polygon_radius(polygon, center)
	var sweep_total: int = int(max(1, outbreak_reel_count))
	var sweep_index: int = 0
	var host: Node2D = Node2D.new()
	host.name = "PlagueOutbreakReelHost"
	add_child(host)

	var timer: Timer = Timer.new()
	timer.wait_time = max(0.08, outbreak_reel_interval)
	timer.one_shot = false
	host.add_child(timer)
	timer.timeout.connect(func() -> void:
		if not is_instance_valid(host):
			return
		if sweep_index >= sweep_total:
			timer.stop()
			host.queue_free()
			return
		_emit_outbreak_reel(center, radius, sweep_index, sweep_total)
		sweep_index += 1
	)
	timer.start()

func _emit_outbreak_reel(center: Vector2, radius: float, index: int, total: int) -> void:
	var angle: float = TAU * float(index) / float(max(1, total))
	var dir: Vector2 = Vector2.RIGHT.rotated(angle)
	var start: Vector2 = center + dir * radius * 1.32
	var end: Vector2 = center - dir * radius * 0.08
	SkillEffectManager.create_line_effect({
		"start": start,
		"end": end,
		"width": 14.0,
		"damage": 0,
		"damage_interval": 0.2,
		"duration": 0.18,
		"color": Color(0.72, 0.96, 0.4, 0.88)
	})
	_apply_line_burst_damage(start, end, 12.0, outbreak_reel_damage)
	_apply_pull_to_point(center, radius * 1.02, spore_recall_pull * 0.55)

func _deploy_spores_along_segment(start: Vector2, end: Vector2) -> void:
	var seg: Vector2 = end - start
	var length: float = seg.length()
	if length <= 1.0:
		return
	var dir: Vector2 = seg / length

	if not _has_last_spore_anchor:
		_has_last_spore_anchor = true
		_last_spore_anchor = start
		_spawn_spore_pod(start)

	var cursor: float = 0.0
	var step_len: float = float(max(24.0, spore_spacing * 0.35))
	while cursor <= length:
		var point: Vector2 = start + dir * cursor
		if _last_spore_anchor.distance_to(point) >= spore_spacing:
			_spawn_spore_pod(point)
			_last_spore_anchor = point
		cursor += step_len

	if _last_spore_anchor.distance_to(end) >= spore_spacing:
		_spawn_spore_pod(end)
		_last_spore_anchor = end

func _spawn_spore_pod(pos: Vector2) -> void:
	var pod: Node2D = Node2D.new()
	pod.name = "PlagueSporePod"
	pod.global_position = pos
	add_child(pod)
	pod.add_to_group("player_skill_effects")

	var ring: Line2D = Line2D.new()
	ring.width = 2.0
	ring.closed = true
	ring.default_color = Color(0.42, 0.8, 0.25, 0.88)
	var ring_segments: int = 14
	for i: int in range(ring_segments):
		var ang: float = TAU * float(i) / float(ring_segments)
		ring.add_point(Vector2.RIGHT.rotated(ang) * spore_trigger_radius)
	pod.add_child(ring)

	var armed: bool = false
	var triggered: bool = false
	var elapsed: float = 0.0
	var timer: Timer = Timer.new()
	timer.wait_time = max(0.05, spore_check_interval)
	timer.one_shot = false
	pod.add_child(timer)
	timer.timeout.connect(func() -> void:
		if not is_instance_valid(pod):
			return
		elapsed += timer.wait_time
		if not armed and elapsed >= spore_arm_delay:
			armed = true
			ring.default_color = Color(0.62, 0.95, 0.35, 0.95)
		if elapsed >= poison_duration:
			timer.stop()
			pod.queue_free()
			return
		if not armed or triggered:
			return
		var target: Node2D = _find_enemy_in_radius(pod.global_position, spore_trigger_radius)
		if target == null:
			return
		triggered = true
		_trigger_spore_blast(pod.global_position)
		timer.stop()
		var tree: SceneTree = get_tree()
		if tree != null:
			var cleanup_timer: SceneTreeTimer = tree.create_timer(0.12)
			cleanup_timer.timeout.connect(func() -> void:
				if is_instance_valid(pod):
					pod.queue_free()
			)
	)
	timer.start()

func _find_enemy_in_radius(center: Vector2, radius: float) -> Node2D:
	var enemies: Array = get_tree().get_nodes_in_group("enemies")
	var best_enemy: Node2D = null
	var best_dist: float = radius + 0.001
	for enemy_obj: Variant in enemies:
		if enemy_obj == null or not is_instance_valid(enemy_obj):
			continue
		if not (enemy_obj is Node2D):
			continue
		var enemy: Node2D = enemy_obj
		var dist: float = enemy.global_position.distance_to(center)
		if dist > radius:
			continue
		if dist < best_dist:
			best_dist = dist
			best_enemy = enemy
	return best_enemy

func _trigger_spore_blast(center: Vector2) -> void:
	var blast_poly: PackedVector2Array = _build_circle_polygon(center, spore_blast_radius, 18)
	SkillEffectManager.create_area_effect({
		"polygon": blast_poly,
		"damage": miasma_damage,
		"damage_interval": 0.1,
		"duration": 0.28,
		"color": Color(0.45, 0.78, 0.2, 0.38)
	})

	var enemies: Array = get_tree().get_nodes_in_group("enemies")
	for enemy_obj: Variant in enemies:
		if enemy_obj == null or not is_instance_valid(enemy_obj):
			continue
		if not (enemy_obj is Node2D):
			continue
		var enemy: Node2D = enemy_obj
		if enemy.global_position.distance_to(center) > spore_blast_radius:
			continue
		_apply_damage(enemy, max(1, miasma_damage + 4))
		_apply_status(enemy, "poison", poison_duration * 0.55, float(poison_damage + 3), 1, 0.55)
		_apply_status(enemy, "slow", 1.1, min(0.85, slow_value + 0.1), 1, 0.1)

	var anchor: Node2D = _find_enemy_in_radius(center, spore_blast_radius)
	if anchor != null:
		var chained: Node2D = _find_nearest_enemy(anchor.global_position, outbreak_chain_radius, anchor)
		if chained != null:
			_apply_damage(chained, outbreak_chain_damage)
			_apply_status(chained, "poison", poison_duration * 0.45, float(poison_damage), 1, 0.6)
			spawn_skill_vfx(chained.global_position, Color(0.62, 0.9, 0.35, 0.62), 0.3)

	spawn_skill_vfx(center, Color(0.56, 0.88, 0.3, 0.8), 0.44)
	Global.spawn_floating_text(center, "SPORE!", Color(0.55, 0.96, 0.4))

func _spawn_outbreak_chain(polygon: PackedVector2Array) -> void:
	var host: Node2D = Node2D.new()
	host.name = "PlagueOutbreakChain"
	add_child(host)
	var tick_total: int = int(max(1, outbreak_tick_count))
	var tick_index: int = 0

	_emit_outbreak_tick(polygon)
	tick_index += 1

	var timer: Timer = Timer.new()
	timer.wait_time = max(0.08, outbreak_tick_interval)
	timer.one_shot = false
	host.add_child(timer)
	timer.timeout.connect(func() -> void:
		if not is_instance_valid(host):
			return
		if tick_index >= tick_total:
			timer.stop()
			host.queue_free()
			return
		_emit_outbreak_tick(polygon)
		tick_index += 1
	)
	timer.start()

func _emit_outbreak_tick(polygon: PackedVector2Array) -> void:
	var enemies: Array = get_tree().get_nodes_in_group("enemies")
	var inside_targets: Array[Node2D] = []
	for enemy_obj: Variant in enemies:
		if enemy_obj == null or not is_instance_valid(enemy_obj):
			continue
		if not (enemy_obj is Node2D):
			continue
		var enemy: Node2D = enemy_obj
		if Geometry2D.is_point_in_polygon(enemy.global_position, polygon):
			inside_targets.append(enemy)

	if inside_targets.is_empty():
		return

	var max_hits: int = int(min(3, inside_targets.size()))
	for i: int in range(max_hits):
		var target: Node2D = inside_targets[i]
		_apply_damage(target, max(1, outbreak_chain_damage + 3))
		_apply_status(target, "curse", 1.6, curse_value, 1, 0.7)
		_apply_status(target, "poison", 1.8, float(poison_damage + 2), 1, 0.6)
		var chained: Node2D = _find_nearest_enemy(target.global_position, outbreak_chain_radius, target)
		if chained != null:
			_apply_damage(chained, outbreak_chain_damage)
			_apply_status(chained, "poison", 1.4, float(poison_damage), 1, 0.65)
			spawn_skill_vfx(chained.global_position, Color(0.65, 0.95, 0.35, 0.62), 0.26)

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
		_apply_status(enemy, "poison", 1.3, float(poison_damage), 1, 0.6)
		_apply_status(enemy, "slow", 0.9, min(0.9, slow_value + 0.06), 1, 0.1)

func _apply_radius_poison_damage(center: Vector2, radius: float, damage: int) -> void:
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
		_apply_status(enemy, "poison", 1.0, float(poison_damage), 1, 0.6)

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

func _find_nearest_enemy(center: Vector2, radius: float, exclude_enemy: Node2D) -> Node2D:
	var enemies: Array = get_tree().get_nodes_in_group("enemies")
	var best_enemy: Node2D = null
	var best_dist: float = radius + 0.001
	for enemy_obj: Variant in enemies:
		if enemy_obj == null or not is_instance_valid(enemy_obj):
			continue
		if not (enemy_obj is Node2D):
			continue
		var enemy: Node2D = enemy_obj
		if enemy == exclude_enemy:
			continue
		var dist: float = enemy.global_position.distance_to(center)
		if dist > radius:
			continue
		if dist < best_dist:
			best_dist = dist
			best_enemy = enemy
	return best_enemy

func _cache_miasma_window(polygon: PackedVector2Array, duration: float) -> void:
	if not is_instance_valid(skill_owner):
		return
	var center: Vector2 = _polygon_center(polygon)
	var radius: float = _polygon_radius(polygon, center)
	var expire_msec: int = Time.get_ticks_msec() + int(round(max(0.2, duration) * 1000.0))
	skill_owner.set_meta(MIASMA_META_CENTER, center)
	skill_owner.set_meta(MIASMA_META_RADIUS, radius)
	skill_owner.set_meta(MIASMA_META_EXPIRE_MSEC, expire_msec)

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
	return max(20.0, radius)

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
	return Color(0.4, 0.7, 0.1, 1.0)

func _get_closure_color() -> Color:
	return Color(0.3, 0.5, 0.0, 1.0)
