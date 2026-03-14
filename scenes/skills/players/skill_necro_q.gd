extends SkillDrawingBase
class_name SkillNecroQ

var wall_health: int = 3
var wall_width: float = 16.0
var wall_contact_damage: int = 12

var grave_spacing: float = 170.0
var grave_duration: float = 5.2
var grave_interval: float = 0.32
var grave_sense_radius: float = 220.0
var grave_tick_damage: int = 10
var grave_curse_value: float = 8.0
var grave_pull_strength: float = 22.0

var crypt_duration: float = 6.0
var crypt_pulse_count: int = 6
var crypt_pulse_interval: float = 0.26
var crypt_pulse_damage: int = 22
var execute_threshold: float = 0.28

var skeleton_count: int = 2
var summon_duration: float = 6.0
var summon_damage_ratio: float = 0.45
var soul_nail_step_distance: float = 46.0
var soul_nail_tick_interval: float = 0.05
var soul_nail_hit_radius: float = 52.0
var soul_nail_line_damage: int = 16
var soul_nail_push: float = 20.0
var soul_recall_delay: float = 0.2
var soul_recall_count: int = 5
var soul_recall_damage: int = 20
var soul_recall_pull: float = 28.0
var closure_reflux_count: int = 6
var closure_reflux_interval: float = 0.16
var closure_reflux_damage: int = 24

const GRAVE_META_CENTER: String = "necro_grave_center"
const GRAVE_META_RADIUS: String = "necro_grave_radius"
const GRAVE_META_EXPIRE_MSEC: String = "necro_grave_expire_msec"

var _grave_points: Array[Vector2] = []

func _enter_planning_mode() -> void:
	_grave_points.clear()
	super._enter_planning_mode()

func _spawn_line_effect(start: Vector2, end: Vector2) -> void:
	SkillEffectManager.create_wall_effect({
		"start": start,
		"end": end,
		"width": wall_width,
		"duration": _get_line_duration(),
		"health": wall_health,
		"block_enemies": true,
		"block_bullets": false,
		"contact_damage": wall_contact_damage,
		"contact_interval": 0.55,
		"color": Color(0.45, 0.12, 0.52, 0.75)
	})

	_launch_soul_nail(start, end)
	_spawn_graves_along_segment(start, end)

func _spawn_area_effect(polygon: PackedVector2Array) -> void:
	if polygon.size() < 3:
		return

	SkillEffectManager.create_debuff_zone({
		"polygon": polygon,
		"duration": crypt_duration,
		"debuff_type": "curse",
		"debuff_value": grave_curse_value,
		"debuff_duration": 2.2,
		"tick_interval": 0.8,
		"color": Color(0.35, 0.08, 0.46, 0.3)
	})

	SkillEffectManager.create_area_effect({
		"polygon": polygon,
		"damage": int(max(1, crypt_pulse_damage - 4)),
		"damage_interval": 0.9,
		"duration": crypt_duration,
		"color": Color(0.3, 0.02, 0.4, 0.26)
	})

	var center: Vector2 = _calculate_polygon_center(polygon)
	_spawn_crypt_pulses(polygon, center)
	_spawn_ritual_reflux(polygon, center)
	_spawn_skeleton_swarm(center, skeleton_count)
	_cache_grave_window(polygon, crypt_duration)

func _launch_soul_nail(start: Vector2, finish: Vector2) -> void:
	var seg: Vector2 = finish - start
	var length: float = seg.length()
	if length <= 1.0:
		return
	var move_dir: Vector2 = seg / length
	var host: Node2D = Node2D.new()
	host.name = "NecroSoulNailHost"
	add_child(host)

	var step_total: int = int(max(2.0, ceil(length / max(12.0, soul_nail_step_distance))))
	var step_index: int = 0
	var timer: Timer = Timer.new()
	timer.wait_time = max(0.03, soul_nail_tick_interval)
	timer.one_shot = false
	host.add_child(timer)
	timer.timeout.connect(func() -> void:
		if not is_instance_valid(host):
			return
		if step_index > step_total:
			timer.stop()
			host.queue_free()
			_spawn_soul_nail_recall(finish, start, move_dir)
			return
		_emit_soul_nail_tick(start, finish, step_index, step_total, move_dir)
		step_index += 1
	)
	timer.start()

func _spawn_soul_nail_recall(from_pos: Vector2, to_pos: Vector2, move_dir: Vector2) -> void:
	var tree: SceneTree = get_tree()
	if tree == null:
		return
	tree.create_timer(max(0.05, soul_recall_delay)).timeout.connect(func() -> void:
		if not is_inside_tree():
			return
		var host: Node2D = Node2D.new()
		host.name = "NecroSoulNailRecallHost"
		add_child(host)
		var pulse_total: int = int(max(1, soul_recall_count))
		var pulse_index: int = 0
		var timer: Timer = Timer.new()
		timer.wait_time = max(0.06, soul_nail_tick_interval * 1.8)
		timer.one_shot = false
		host.add_child(timer)
		timer.timeout.connect(func() -> void:
			if not is_instance_valid(host):
				return
			if pulse_index >= pulse_total:
				timer.stop()
				host.queue_free()
				return
			_emit_soul_recall_tick(from_pos, to_pos, pulse_index, pulse_total, move_dir)
			pulse_index += 1
		)
		timer.start()
	)

func _emit_soul_nail_tick(start: Vector2, finish: Vector2, index: int, total: int, move_dir: Vector2) -> void:
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
		"color": Color(0.76, 0.34, 0.88, 0.94)
	})
	_apply_radius_damage_and_curse(current, soul_nail_hit_radius, soul_nail_line_damage)
	_apply_forward_push(current, soul_nail_hit_radius * 1.15, move_dir, soul_nail_push)

func _emit_soul_recall_tick(
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
		"duration": 0.18,
		"color": Color(0.9, 0.52, 1.0, 0.9)
	})
	_apply_line_burst_damage(start, end, 12.0, soul_recall_damage)
	_apply_pull_to_point(center, soul_nail_hit_radius * 1.6, soul_recall_pull)
	_spawn_skeleton_swarm(center, 1)

func _spawn_ritual_reflux(polygon: PackedVector2Array, center: Vector2) -> void:
	var radius: float = _polygon_radius(polygon, center)
	var sweep_total: int = int(max(1, closure_reflux_count))
	var sweep_index: int = 0
	var host: Node2D = Node2D.new()
	host.name = "NecroRitualRefluxHost"
	add_child(host)

	var timer: Timer = Timer.new()
	timer.wait_time = max(0.08, closure_reflux_interval)
	timer.one_shot = false
	host.add_child(timer)
	timer.timeout.connect(func() -> void:
		if not is_instance_valid(host):
			return
		if sweep_index >= sweep_total:
			timer.stop()
			host.queue_free()
			return
		_emit_ritual_reflux(center, radius, sweep_index, sweep_total)
		sweep_index += 1
	)
	timer.start()

func _emit_ritual_reflux(center: Vector2, radius: float, index: int, total: int) -> void:
	var angle: float = TAU * float(index) / float(max(1, total))
	var dir: Vector2 = Vector2.RIGHT.rotated(angle)
	var start: Vector2 = center + dir * radius * 1.4
	var end: Vector2 = center - dir * radius * 0.08
	SkillEffectManager.create_line_effect({
		"start": start,
		"end": end,
		"width": 14.0,
		"damage": 0,
		"damage_interval": 0.2,
		"duration": 0.2,
		"color": Color(0.82, 0.36, 0.95, 0.9)
	})
	_apply_line_burst_damage(start, end, 13.0, closure_reflux_damage)
	_apply_pull_to_point(center, radius * 0.95, soul_recall_pull * 0.7)
	_apply_radius_damage_and_curse(center, radius * 0.28, int(max(1, closure_reflux_damage * 0.3)))

func _spawn_graves_along_segment(start: Vector2, end: Vector2) -> void:
	var seg: Vector2 = end - start
	var length: float = seg.length()
	if length <= 1.0:
		_deploy_grave_if_needed(start)
		return
	var dir: Vector2 = seg / length
	var spacing: float = float(max(64.0, grave_spacing))
	var cursor: float = 0.0
	while cursor <= length:
		_deploy_grave_if_needed(start + dir * cursor)
		cursor += spacing
	if fmod(length, spacing) > 24.0:
		_deploy_grave_if_needed(end)

func _deploy_grave_if_needed(pos: Vector2) -> void:
	if _grave_points.is_empty():
		_grave_points.append(pos)
		_spawn_grave_post(pos)
		return
	var last_pos: Vector2 = _grave_points[_grave_points.size() - 1]
	if last_pos.distance_to(pos) < grave_spacing:
		return
	_grave_points.append(pos)
	_spawn_grave_post(pos)

func _spawn_grave_post(pos: Vector2) -> void:
	var post: Node2D = Node2D.new()
	post.name = "NecroGravePost"
	post.global_position = pos
	add_child(post)
	post.add_to_group("player_skill_effects")

	var elapsed: float = 0.0
	var timer: Timer = Timer.new()
	timer.wait_time = float(max(0.08, grave_interval))
	timer.one_shot = false
	post.add_child(timer)
	timer.timeout.connect(func() -> void:
		if not is_instance_valid(post):
			return
		elapsed += timer.wait_time
		if elapsed >= grave_duration:
			timer.stop()
			post.queue_free()
			return
		_process_grave_post(post.global_position)
	)
	timer.start()

	spawn_skill_vfx(pos, Color(0.55, 0.2, 0.65, 0.76), 0.32)

func _process_grave_post(center: Vector2) -> void:
	var target: Node2D = _find_nearest_enemy(center, grave_sense_radius)
	if target == null:
		return
	_apply_damage(target, grave_tick_damage)
	_apply_status(target, "curse", 2.0, grave_curse_value, 1, 0.8)
	var pull_dir: Vector2 = (center - target.global_position).normalized()
	target.global_position += pull_dir * grave_pull_strength

	var hp_ratio: float = _get_enemy_hp_ratio(target)
	if hp_ratio <= execute_threshold:
		_apply_damage(target, int(max(1, crypt_pulse_damage)))
		spawn_skill_vfx(target.global_position, Color(0.6, 0.2, 0.7, 0.82), 0.28)
		_spawn_skeleton_swarm(target.global_position, 1)

func _spawn_crypt_pulses(polygon: PackedVector2Array, center: Vector2) -> void:
	var radius: float = _polygon_radius(polygon, center)
	var pulse_total: int = int(max(1, crypt_pulse_count))
	var pulse_index: int = 0
	var host: Node2D = Node2D.new()
	host.name = "NecroCryptPulses"
	add_child(host)

	_emit_crypt_pulse(polygon, center, radius, pulse_index)
	pulse_index += 1

	var timer: Timer = Timer.new()
	timer.wait_time = float(max(0.08, crypt_pulse_interval))
	timer.one_shot = false
	host.add_child(timer)
	timer.timeout.connect(func() -> void:
		if not is_instance_valid(host):
			return
		if pulse_index >= pulse_total:
			timer.stop()
			host.queue_free()
			return
		_emit_crypt_pulse(polygon, center, radius, pulse_index)
		pulse_index += 1
	)
	timer.start()

func _emit_crypt_pulse(polygon: PackedVector2Array, center: Vector2, radius: float, index: int) -> void:
	var angle: float = TAU * float(index) / float(max(1, crypt_pulse_count))
	var dir: Vector2 = Vector2.RIGHT.rotated(angle)
	var start: Vector2 = center + dir * (radius + 76.0)
	var end: Vector2 = center - dir * (radius * 0.42)
	SkillEffectManager.create_line_effect({
		"start": start,
		"end": end,
		"width": 22.0,
		"damage": 0,
		"damage_interval": 0.2,
		"duration": 0.2,
		"color": Color(0.56, 0.24, 0.7, 0.9)
	})
	_apply_line_burst_damage(start, end, 12.0, crypt_pulse_damage)

	var target: Node2D = _find_best_target_in_polygon(polygon, center)
	if target == null:
		return
	_apply_status(target, "fear", 0.6, 1.0, 1, 0.2)
	_apply_status(target, "curse", 1.8, grave_curse_value, 1, 0.8)

func _spawn_skeleton_swarm(center: Vector2, count: int) -> void:
	if count <= 0:
		return
	var summon_damage: int = int(max(8, round(float(crypt_pulse_damage) * summon_damage_ratio)))
	var summon_count: int = int(max(1, count))
	for i: int in range(summon_count):
		var angle: float = TAU * float(i) / float(summon_count)
		var pos: Vector2 = center + Vector2.RIGHT.rotated(angle) * 44.0
		SkillEffectManager.create_summon({
			"position": pos,
			"summon_type": "beetle",
			"duration": float(max(crypt_duration, summon_duration)),
			"damage": summon_damage,
			"attack_interval": 1.05,
			"attack_range": 180.0,
			"max_count": 8,
			"owner_skill_id": "skill_necro_q",
			"color": Color(0.5, 0.2, 0.6, 0.85)
		})

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
		_apply_status(enemy, "curse", 1.8, grave_curse_value, 1, 0.8)

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
		var score: float = (1.0 - hp_ratio) * 1.9 + (1.0 / float(max(1.0, dist * 0.01)))
		if score > best_score:
			best_score = score
			best_enemy = enemy
	return best_enemy

func _apply_radius_damage_and_curse(center: Vector2, radius: float, damage: int) -> void:
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
		_apply_status(enemy, "curse", 1.8, grave_curse_value, 1, 0.8)

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

func _cache_grave_window(polygon: PackedVector2Array, duration: float) -> void:
	if not is_instance_valid(skill_owner):
		return
	var center: Vector2 = _calculate_polygon_center(polygon)
	var radius: float = _polygon_radius(polygon, center)
	var expire_msec: int = Time.get_ticks_msec() + int(round(float(max(0.2, duration)) * 1000.0))
	skill_owner.set_meta(GRAVE_META_CENTER, center)
	skill_owner.set_meta(GRAVE_META_RADIUS, radius)
	skill_owner.set_meta(GRAVE_META_EXPIRE_MSEC, expire_msec)

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
	return Color(0.45, 0.12, 0.52, 1.0)

func _get_closure_color() -> Color:
	return Color(0.3, 0.02, 0.4, 1.0)
