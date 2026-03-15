extends SkillQBase
class_name SkillMirebinderQ

var slow_value: float = 0.88
var slow_duration: float = 4.0
var pool_damage: int = 24
var pool_duration: float = 5.5
var slime_count: int = 3
var mirebinder_poison_value: float = 9.0

var pod_spacing: float = 165.0
var pod_duration: float = 4.8
var pod_interval: float = 0.32
var pod_trigger_radius: float = 110.0
var pod_blast_radius: float = 88.0
var pod_blast_damage: int = 14

var split_pulse_count: int = 6
var split_pulse_interval: float = 0.24
var mirebinder_lance_step_distance: float = 52.0
var mirebinder_lance_tick_interval: float = 0.05
var mirebinder_lance_hit_radius: float = 52.0
var mirebinder_lance_damage: int = 14
var mirebinder_lance_push: float = 14.0
var mirebinder_recall_delay: float = 0.2
var mirebinder_recall_count: int = 5
var mirebinder_recall_damage: int = 18
var mirebinder_recall_pull: float = 20.0
var mirebinder_reel_count: int = 5
var mirebinder_reel_interval: float = 0.16
var mirebinder_reel_damage: int = 18

const GOO_META_CENTER: String = "mirebinder_pool_center"
const GOO_META_RADIUS: String = "mirebinder_pool_radius"
const GOO_META_EXPIRE_MSEC: String = "mirebinder_pool_expire_msec"

var _pod_points: Array[Vector2] = []

func _enter_planning_mode() -> void:
	_pod_points.clear()
	super._enter_planning_mode()

func _spawn_line_effect(start: Vector2, end: Vector2) -> void:
	SkillEffectManager.create_debuff_zone({
		"start": start,
		"end": end,
		"width": 26.0,
		"duration": _get_line_duration(),
		"debuff_type": "slow",
		"debuff_value": slow_value,
		"debuff_duration": slow_duration,
		"tick_interval": 0.45,
		"color": Color(0.3, 0.9, 0.2, 0.5)
	})

	SkillEffectManager.create_debuff_zone({
		"start": start,
		"end": end,
		"width": 20.0,
		"duration": _get_line_duration(),
		"debuff_type": "poison",
		"debuff_value": mirebinder_poison_value,
		"debuff_duration": 2.5,
		"tick_interval": 0.7,
		"color": Color(0.25, 0.72, 0.12, 0.3)
	})

	_launch_mirebinder_lance(start, end)
	_spawn_pods_along_segment(start, end)

func _spawn_area_effect(polygon: PackedVector2Array) -> void:
	if polygon.size() < 3:
		return
	SkillEffectManager.create_area_effect({
		"polygon": polygon,
		"damage": pool_damage,
		"damage_interval": 0.6,
		"duration": pool_duration,
		"color": Color(0.2, 0.8, 0.1, 0.45)
	})

	SkillEffectManager.create_debuff_zone({
		"polygon": polygon,
		"duration": pool_duration,
		"debuff_type": "slow",
		"debuff_value": float(min(0.95, slow_value + 0.05)),
		"debuff_duration": 2.0,
		"tick_interval": 0.4,
		"color": Color(0.2, 0.7, 0.1, 0.25)
	})

	var center: Vector2 = _calculate_polygon_center(polygon)
	_spawn_slime_ring(center, slime_count, 52.0)
	_spawn_split_pulses(polygon, center)
	_spawn_mirebinder_reel(polygon)
	_cache_mirebinder_window(polygon, pool_duration)

func _launch_mirebinder_lance(start: Vector2, finish: Vector2) -> void:
	var seg: Vector2 = finish - start
	var length: float = seg.length()
	if length <= 1.0:
		return
	var move_dir: Vector2 = seg / length
	var host: Node2D = Node2D.new()
	host.name = "GooLanceHost"
	add_child(host)

	var step_total: int = int(max(2.0, ceil(length / max(12.0, mirebinder_lance_step_distance))))
	var step_index: int = 0
	var timer: Timer = Timer.new()
	timer.wait_time = max(0.03, mirebinder_lance_tick_interval)
	timer.one_shot = false
	host.add_child(timer)
	timer.timeout.connect(func() -> void:
		if not is_instance_valid(host):
			return
		if step_index > step_total:
			timer.stop()
			host.queue_free()
			_spawn_mirebinder_recall(finish, start, move_dir)
			return
		_emit_mirebinder_lance_tick(start, finish, step_index, step_total, move_dir)
		step_index += 1
	)
	timer.start()

func _spawn_mirebinder_recall(from_pos: Vector2, to_pos: Vector2, move_dir: Vector2) -> void:
	var tree: SceneTree = get_tree()
	if tree == null:
		return
	tree.create_timer(max(0.05, mirebinder_recall_delay)).timeout.connect(func() -> void:
		if not is_inside_tree():
			return
		var host: Node2D = Node2D.new()
		host.name = "GooRecallHost"
		add_child(host)
		var pulse_total: int = int(max(1, mirebinder_recall_count))
		var pulse_index: int = 0
		var timer: Timer = Timer.new()
		timer.wait_time = max(0.06, mirebinder_lance_tick_interval * 1.6)
		timer.one_shot = false
		host.add_child(timer)
		timer.timeout.connect(func() -> void:
			if not is_instance_valid(host):
				return
			if pulse_index >= pulse_total:
				timer.stop()
				host.queue_free()
				return
			_emit_mirebinder_recall_tick(from_pos, to_pos, pulse_index, pulse_total, move_dir)
			pulse_index += 1
		)
		timer.start()
	)

func _emit_mirebinder_lance_tick(start: Vector2, finish: Vector2, index: int, total: int, move_dir: Vector2) -> void:
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
		"color": Color(0.46, 0.98, 0.34, 0.88)
	})
	_apply_radius_mirebinder_damage(current, mirebinder_lance_hit_radius, mirebinder_lance_damage)
	_apply_direction_push(current, mirebinder_lance_hit_radius * 1.2, move_dir, mirebinder_lance_push)

func _emit_mirebinder_recall_tick(
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
		"color": Color(0.58, 1.0, 0.42, 0.9)
	})
	_apply_line_burst_damage(start, end, 11.0, mirebinder_recall_damage)
	_apply_pull_to_point(center, mirebinder_lance_hit_radius * 1.55, mirebinder_recall_pull)

func _spawn_mirebinder_reel(polygon: PackedVector2Array) -> void:
	var center: Vector2 = _calculate_polygon_center(polygon)
	var radius: float = _polygon_radius(polygon, center)
	var sweep_total: int = int(max(1, mirebinder_reel_count))
	var sweep_index: int = 0
	var host: Node2D = Node2D.new()
	host.name = "GooReelHost"
	add_child(host)

	var timer: Timer = Timer.new()
	timer.wait_time = max(0.08, mirebinder_reel_interval)
	timer.one_shot = false
	host.add_child(timer)
	timer.timeout.connect(func() -> void:
		if not is_instance_valid(host):
			return
		if sweep_index >= sweep_total:
			timer.stop()
			host.queue_free()
			return
		_emit_mirebinder_reel(center, radius, sweep_index, sweep_total)
		sweep_index += 1
	)
	timer.start()

func _emit_mirebinder_reel(center: Vector2, radius: float, index: int, total: int) -> void:
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
		"color": Color(0.52, 0.98, 0.4, 0.88)
	})
	_apply_line_burst_damage(start, end, 11.0, mirebinder_reel_damage)
	_apply_pull_to_point(center, radius * 1.02, mirebinder_recall_pull * 0.55)

func _spawn_pods_along_segment(start: Vector2, end: Vector2) -> void:
	var seg: Vector2 = end - start
	var length: float = seg.length()
	if length <= 1.0:
		_deploy_pod_if_needed(start)
		return
	var dir: Vector2 = seg / length
	var spacing: float = float(max(56.0, pod_spacing))
	var cursor: float = 0.0
	while cursor <= length:
		_deploy_pod_if_needed(start + dir * cursor)
		cursor += spacing
	if fmod(length, spacing) > 20.0:
		_deploy_pod_if_needed(end)

func _deploy_pod_if_needed(pos: Vector2) -> void:
	if _pod_points.is_empty():
		_pod_points.append(pos)
		_spawn_pod(pos)
		return
	var last_pos: Vector2 = _pod_points[_pod_points.size() - 1]
	if last_pos.distance_to(pos) < pod_spacing:
		return
	_pod_points.append(pos)
	_spawn_pod(pos)

func _spawn_pod(pos: Vector2) -> void:
	var pod: Node2D = Node2D.new()
	pod.name = "GooPod"
	pod.global_position = pos
	add_child(pod)
	pod.add_to_group("player_skill_effects")

	var elapsed: float = 0.0
	var triggered: bool = false
	var timer: Timer = Timer.new()
	timer.wait_time = float(max(0.08, pod_interval))
	timer.one_shot = false
	pod.add_child(timer)
	timer.timeout.connect(func() -> void:
		if not is_instance_valid(pod):
			return
		elapsed += timer.wait_time
		if elapsed >= pod_duration:
			timer.stop()
			pod.queue_free()
			return
		if triggered:
			return
		if not _has_enemy_in_radius(pod.global_position, pod_trigger_radius):
			return
		triggered = true
		_trigger_pod_blast(pod.global_position)
	)
	timer.start()

	spawn_skill_vfx(pos, Color(0.36, 0.92, 0.28, 0.78), 0.26)

func _trigger_pod_blast(center: Vector2) -> void:
	var blast_poly: PackedVector2Array = _build_circle_polygon(center, pod_blast_radius, 16)
	SkillEffectManager.create_area_effect({
		"polygon": blast_poly,
		"damage": pod_blast_damage,
		"damage_interval": 0.1,
		"duration": 0.25,
		"color": Color(0.35, 0.95, 0.25, 0.42)
	})
	SkillEffectManager.create_debuff_zone({
		"polygon": blast_poly,
		"duration": 1.8,
		"debuff_type": "poison",
		"debuff_value": mirebinder_poison_value,
		"debuff_duration": 1.8,
		"tick_interval": 0.7,
		"color": Color(0.28, 0.82, 0.18, 0.22)
	})
	_spawn_slime_ring(center, 1, 0.0)

func _spawn_split_pulses(polygon: PackedVector2Array, center: Vector2) -> void:
	var radius: float = _polygon_radius(polygon, center)
	var pulse_total: int = int(max(1, split_pulse_count))
	var pulse_index: int = 0
	var host: Node2D = Node2D.new()
	host.name = "GooSplitPulses"
	add_child(host)

	_emit_split_pulse(center, radius, pulse_index)
	pulse_index += 1

	var timer: Timer = Timer.new()
	timer.wait_time = float(max(0.08, split_pulse_interval))
	timer.one_shot = false
	host.add_child(timer)
	timer.timeout.connect(func() -> void:
		if not is_instance_valid(host):
			return
		if pulse_index >= pulse_total:
			timer.stop()
			host.queue_free()
			return
		_emit_split_pulse(center, radius, pulse_index)
		pulse_index += 1
	)
	timer.start()

func _emit_split_pulse(center: Vector2, radius: float, index: int) -> void:
	var angle: float = TAU * float(index) / float(max(1, split_pulse_count))
	var pulse_center: Vector2 = center + Vector2.RIGHT.rotated(angle) * (radius * 0.52)
	var pulse_poly: PackedVector2Array = _build_circle_polygon(pulse_center, 78.0, 14)
	SkillEffectManager.create_area_effect({
		"polygon": pulse_poly,
		"damage": int(max(1, pool_damage - 8)),
		"damage_interval": 0.12,
		"duration": 0.24,
		"color": Color(0.32, 0.9, 0.24, 0.36)
	})
	SkillEffectManager.create_debuff_zone({
		"polygon": pulse_poly,
		"duration": 1.4,
		"debuff_type": "slow",
		"debuff_value": slow_value,
		"debuff_duration": 1.2,
		"tick_interval": 0.35,
		"color": Color(0.24, 0.76, 0.16, 0.18)
	})

func _spawn_slime_ring(center: Vector2, count: int, radius: float) -> void:
	if count <= 0:
		return
	var total: int = int(max(1, count))
	for i: int in range(total):
		var angle: float = TAU * float(i) / float(total)
		var pos: Vector2 = center + Vector2.RIGHT.rotated(angle) * radius
		SkillEffectManager.create_summon({
			"position": pos,
			"summon_type": "slime",
			"duration": pool_duration,
			"damage": pool_damage,
			"attack_interval": 1.0,
			"attack_range": 110.0,
			"max_count": 8,
			"owner_skill_id": "skill_mirebinder_q",
			"color": Color(0.3, 0.9, 0.2, 0.85)
		})

func _has_enemy_in_radius(center: Vector2, radius: float) -> bool:
	var enemies: Array = get_tree().get_nodes_in_group("enemies")
	for enemy_obj: Variant in enemies:
		if enemy_obj == null or not is_instance_valid(enemy_obj):
			continue
		if not (enemy_obj is Node2D):
			continue
		var enemy: Node2D = enemy_obj
		if enemy.global_position.distance_to(center) <= radius:
			return true
	return false

func _build_circle_polygon(center: Vector2, radius: float, segments: int) -> PackedVector2Array:
	var points: PackedVector2Array = PackedVector2Array()
	var segment_count: int = int(max(8, segments))
	for i: int in range(segment_count):
		var ang: float = TAU * float(i) / float(segment_count)
		points.append(center + Vector2.RIGHT.rotated(ang) * radius)
	return points

func _cache_mirebinder_window(polygon: PackedVector2Array, duration: float) -> void:
	if not is_instance_valid(skill_owner):
		return
	var center: Vector2 = _calculate_polygon_center(polygon)
	var radius: float = _polygon_radius(polygon, center)
	var expire_msec: int = Time.get_ticks_msec() + int(round(float(max(0.2, duration)) * 1000.0))
	skill_owner.set_meta(GOO_META_CENTER, center)
	skill_owner.set_meta(GOO_META_RADIUS, radius)
	skill_owner.set_meta(GOO_META_EXPIRE_MSEC, expire_msec)

func _polygon_radius(polygon: PackedVector2Array, center: Vector2) -> float:
	var radius: float = 0.0
	for point: Vector2 in polygon:
		radius = float(max(radius, center.distance_to(point)))
	return float(max(18.0, radius))

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
		_apply_status(enemy, "slow", 0.9, slow_value, 1, 0.1)
		_apply_status(enemy, "poison", 1.2, mirebinder_poison_value, 1, 0.7)

func _apply_radius_mirebinder_damage(center: Vector2, radius: float, damage: int) -> void:
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
		_apply_status(enemy, "poison", 1.0, mirebinder_poison_value, 1, 0.7)

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
	return Color(0.3, 0.9, 0.2, 1.0)

func _get_closure_color() -> Color:
	return Color(0.2, 0.8, 0.1, 1.0)

