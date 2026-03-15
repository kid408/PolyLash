extends SkillQBase
class_name SkillTurretwrightQ

var turret_damage: int = 24
var turret_count: int = 3
var turret_duration: float = 12.0
var repair_boost: float = 0.65
var repair_duration: float = 6.5
var overclock_turret_damage: int = 34
var overclock_count: int = 1
var hardpoint_spacing: float = 175.0
var hardpoint_duration: float = 5.0
var hardpoint_attack_interval: float = 0.36
var hardpoint_attack_damage: int = 16
var hardpoint_attack_range: float = 300.0
var fortress_barrage_count: int = 7
var fortress_barrage_interval: float = 0.24
var fortress_barrage_damage: int = 22
var fortress_barrage_width: float = 26.0
var fort_lance_step_distance: float = 52.0
var fort_lance_tick_interval: float = 0.05
var fort_lance_hit_radius: float = 54.0
var fort_lance_damage: int = 16
var fort_lance_push: float = 14.0
var fort_recall_delay: float = 0.2
var fort_recall_count: int = 5
var fort_recall_damage: int = 20
var fort_recall_pull: float = 18.0
var fort_reel_count: int = 5
var fort_reel_interval: float = 0.16
var fort_reel_damage: int = 20

const FORT_META_CENTER: String = "turret_fort_center"
const FORT_META_RADIUS: String = "turret_fort_radius"
const FORT_META_EXPIRE_MSEC: String = "turret_fort_expire_msec"

var _line_hardpoint_anchors: Array[Vector2] = []

func _enter_planning_mode() -> void:
	_line_hardpoint_anchors.clear()
	super._enter_planning_mode()

func _spawn_line_effect(start: Vector2, end: Vector2) -> void:
	for i: int in range(turret_count):
		var t: float = 0.0
		if turret_count > 1:
			t = float(i) / float(turret_count - 1)
		var pos: Vector2 = start.lerp(end, t)
		SkillEffectManager.create_summon({
			"position": pos,
			"summon_type": "turret",
			"duration": turret_duration,
			"damage": turret_damage,
			"attack_interval": 0.95,
			"attack_range": 260.0,
			"max_count": 8,
			"owner_skill_id": "skill_turretwright_q",
			"color": Color(0.4, 0.5, 0.3)
		})

	_deploy_hardpoint_if_needed(start)
	_deploy_hardpoint_if_needed(end)
	_launch_fort_lance(start, end)
	_spawn_hardpoint_barrage(start, end)

func _spawn_area_effect(polygon: PackedVector2Array) -> void:
	if polygon.size() < 3:
		return
	var center: Vector2 = _calculate_polygon_center(polygon)

	for i: int in range(overclock_count):
		var angle: float = TAU * float(i) / float(max(overclock_count, 1))
		var pos: Vector2 = center + Vector2.RIGHT.rotated(angle) * 24.0
		SkillEffectManager.create_summon({
			"position": pos,
			"summon_type": "turret",
			"duration": repair_duration,
			"damage": overclock_turret_damage,
			"attack_interval": 0.7,
			"attack_range": 280.0,
			"max_count": 8,
			"owner_skill_id": "skill_turretwright_q",
			"color": Color(0.5, 0.62, 0.35)
		})

	SkillEffectManager.create_buff_zone({
		"polygon": polygon,
		"duration": repair_duration,
		"buff_type": "attack_boost",
		"buff_value": repair_boost,
		"tick_interval": 0.5,
		"color": Color(0.3, 0.4, 0.2, 0.4)
	})

	SkillEffectManager.create_buff_zone({
		"polygon": polygon,
		"duration": repair_duration,
		"buff_type": "cooldown_reduction",
		"buff_value": 0.22,
		"tick_interval": 0.5,
		"color": Color(0.35, 0.45, 0.25, 0.22)
	})

	_spawn_fortress_barrage(polygon)
	_spawn_fort_reel(polygon)
	_cache_fort_window(polygon, repair_duration)

func _launch_fort_lance(start: Vector2, finish: Vector2) -> void:
	var seg: Vector2 = finish - start
	var length: float = seg.length()
	if length <= 1.0:
		return
	var move_dir: Vector2 = seg / length
	var host: Node2D = Node2D.new()
	host.name = "TurretFortLanceHost"
	add_child(host)

	var step_total: int = int(max(2.0, ceil(length / max(12.0, fort_lance_step_distance))))
	var step_index: int = 0
	var timer: Timer = Timer.new()
	timer.wait_time = max(0.03, fort_lance_tick_interval)
	timer.one_shot = false
	host.add_child(timer)
	timer.timeout.connect(func() -> void:
		if not is_instance_valid(host):
			return
		if step_index > step_total:
			timer.stop()
			host.queue_free()
			_spawn_fort_recall(finish, start, move_dir)
			return
		_emit_fort_lance_tick(start, finish, step_index, step_total, move_dir)
		step_index += 1
	)
	timer.start()

func _spawn_fort_recall(from_pos: Vector2, to_pos: Vector2, move_dir: Vector2) -> void:
	var tree: SceneTree = get_tree()
	if tree == null:
		return
	tree.create_timer(max(0.05, fort_recall_delay)).timeout.connect(func() -> void:
		if not is_inside_tree():
			return
		var host: Node2D = Node2D.new()
		host.name = "TurretFortRecallHost"
		add_child(host)
		var pulse_total: int = int(max(1, fort_recall_count))
		var pulse_index: int = 0
		var timer: Timer = Timer.new()
		timer.wait_time = max(0.06, fort_lance_tick_interval * 1.6)
		timer.one_shot = false
		host.add_child(timer)
		timer.timeout.connect(func() -> void:
			if not is_instance_valid(host):
				return
			if pulse_index >= pulse_total:
				timer.stop()
				host.queue_free()
				return
			_emit_fort_recall_tick(from_pos, to_pos, pulse_index, pulse_total, move_dir)
			pulse_index += 1
		)
		timer.start()
	)

func _emit_fort_lance_tick(start: Vector2, finish: Vector2, index: int, total: int, move_dir: Vector2) -> void:
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
		"color": Color(0.84, 0.96, 0.62, 0.88)
	})
	_apply_radius_fort_damage(current, fort_lance_hit_radius, fort_lance_damage)
	_apply_direction_push(current, fort_lance_hit_radius * 1.18, move_dir, fort_lance_push)

func _emit_fort_recall_tick(
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
		"color": Color(0.92, 1.0, 0.74, 0.9)
	})
	_apply_line_burst_damage(start, end, 11.0, fort_recall_damage)
	_apply_pull_to_point(center, fort_lance_hit_radius * 1.55, fort_recall_pull)

func _spawn_fort_reel(polygon: PackedVector2Array) -> void:
	var center: Vector2 = _calculate_polygon_center(polygon)
	var radius: float = _polygon_radius(polygon, center)
	var sweep_total: int = int(max(1, fort_reel_count))
	var sweep_index: int = 0
	var host: Node2D = Node2D.new()
	host.name = "TurretFortReelHost"
	add_child(host)

	var timer: Timer = Timer.new()
	timer.wait_time = max(0.08, fort_reel_interval)
	timer.one_shot = false
	host.add_child(timer)
	timer.timeout.connect(func() -> void:
		if not is_instance_valid(host):
			return
		if sweep_index >= sweep_total:
			timer.stop()
			host.queue_free()
			return
		_emit_fort_reel(center, radius, sweep_index, sweep_total)
		sweep_index += 1
	)
	timer.start()

func _emit_fort_reel(center: Vector2, radius: float, index: int, total: int) -> void:
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
		"color": Color(0.88, 1.0, 0.7, 0.88)
	})
	_apply_line_burst_damage(start, end, 11.0, fort_reel_damage)
	_apply_pull_to_point(center, radius * 1.02, fort_recall_pull * 0.55)

func _deploy_hardpoint_if_needed(pos: Vector2) -> void:
	if _line_hardpoint_anchors.is_empty():
		_line_hardpoint_anchors.append(pos)
		_spawn_hardpoint_node(pos)
		return
	var last_anchor: Vector2 = _line_hardpoint_anchors[_line_hardpoint_anchors.size() - 1]
	if last_anchor.distance_to(pos) < hardpoint_spacing:
		return
	_line_hardpoint_anchors.append(pos)
	_spawn_hardpoint_node(pos)

func _spawn_hardpoint_node(pos: Vector2) -> void:
	var node: Node2D = Node2D.new()
	node.name = "TurretHardpoint"
	node.global_position = pos
	add_child(node)
	node.add_to_group("player_skill_effects")

	var life_timer: Timer = Timer.new()
	life_timer.wait_time = max(0.4, hardpoint_duration)
	life_timer.one_shot = true
	node.add_child(life_timer)
	life_timer.timeout.connect(func() -> void:
		if is_instance_valid(node):
			node.queue_free()
	)
	life_timer.start()

	var attack_timer: Timer = Timer.new()
	attack_timer.wait_time = max(0.08, hardpoint_attack_interval)
	attack_timer.one_shot = false
	node.add_child(attack_timer)
	attack_timer.timeout.connect(func() -> void:
		if not is_instance_valid(node):
			return
		var target: Node2D = _find_nearest_enemy(node.global_position, hardpoint_attack_range)
		if target == null:
			return
		_fire_hardpoint_shot(node.global_position, target.global_position)
	)
	attack_timer.start()

	spawn_skill_vfx(pos, Color(0.6, 0.75, 0.45, 0.72), 0.3)

func _spawn_hardpoint_barrage(start: Vector2, end: Vector2) -> void:
	SkillEffectManager.create_line_effect({
		"start": start,
		"end": end,
		"width": 10.0,
		"damage": 0,
		"damage_interval": 0.2,
		"duration": 0.24,
		"color": Color(0.65, 0.8, 0.48, 0.78)
	})
	_apply_line_burst_damage(start, end, 20.0, hardpoint_attack_damage)

func _spawn_fortress_barrage(polygon: PackedVector2Array) -> void:
	var center: Vector2 = _calculate_polygon_center(polygon)
	var radius: float = _polygon_radius(polygon, center)
	var host: Node2D = Node2D.new()
	host.name = "TurretFortressBarrage"
	add_child(host)
	var barrage_total: int = int(max(1, fortress_barrage_count))
	var barrage_index: int = 0

	_fire_fortress_barrage(center, radius, barrage_index, barrage_total)
	barrage_index += 1

	var timer: Timer = Timer.new()
	timer.wait_time = max(0.08, fortress_barrage_interval)
	timer.one_shot = false
	host.add_child(timer)
	timer.timeout.connect(func() -> void:
		if not is_instance_valid(host):
			return
		if barrage_index >= barrage_total:
			timer.stop()
			host.queue_free()
			return
		_fire_fortress_barrage(center, radius, barrage_index, barrage_total)
		barrage_index += 1
	)
	timer.start()

func _fire_fortress_barrage(center: Vector2, radius: float, barrage_index: int, barrage_total: int) -> void:
	var angle: float = TAU * float(barrage_index) / float(max(1, barrage_total))
	var start: Vector2 = center + Vector2.RIGHT.rotated(angle) * (radius + 82.0)
	var end: Vector2 = center + Vector2.RIGHT.rotated(angle + PI) * (radius * 0.3)
	SkillEffectManager.create_line_effect({
		"start": start,
		"end": end,
		"width": fortress_barrage_width,
		"damage": 0,
		"damage_interval": 0.2,
		"duration": 0.22,
		"color": Color(0.72, 0.86, 0.54, 0.9)
	})
	_apply_line_burst_damage(start, end, fortress_barrage_width * 0.52, fortress_barrage_damage)

func _fire_hardpoint_shot(from_pos: Vector2, to_pos: Vector2) -> void:
	SkillEffectManager.create_line_effect({
		"start": from_pos,
		"end": to_pos,
		"width": 8.0,
		"damage": 0,
		"damage_interval": 0.2,
		"duration": 0.16,
		"color": Color(0.74, 0.9, 0.56, 0.88)
	})
	_apply_line_burst_damage(from_pos, to_pos, 22.0, hardpoint_attack_damage)

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
		_apply_status(enemy, "slow", 0.8, 0.26, 1, 0.1)

func _apply_radius_fort_damage(center: Vector2, radius: float, damage: int) -> void:
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
		_apply_status(enemy, "slow", 0.8, 0.26, 1, 0.1)

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

func _cache_fort_window(polygon: PackedVector2Array, duration: float) -> void:
	if not is_instance_valid(skill_owner):
		return
	var center: Vector2 = _calculate_polygon_center(polygon)
	var radius: float = _polygon_radius(polygon, center)
	var expire_msec: int = Time.get_ticks_msec() + int(round(max(0.2, duration) * 1000.0))
	skill_owner.set_meta(FORT_META_CENTER, center)
	skill_owner.set_meta(FORT_META_RADIUS, radius)
	skill_owner.set_meta(FORT_META_EXPIRE_MSEC, expire_msec)

func _polygon_radius(polygon: PackedVector2Array, center: Vector2) -> float:
	var radius: float = 0.0
	for point: Vector2 in polygon:
		radius = max(radius, center.distance_to(point))
	return max(18.0, radius)

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
	return Color(0.4, 0.5, 0.3, 1.0)

func _get_closure_color() -> Color:
	return Color(0.3, 0.4, 0.2, 1.0)

