extends SkillQBase
class_name SkillTrapperQ

var slow_value: float = 0.5
var slow_duration: float = 3.0
var freeze_duration: float = 2.0
var trap_duration: float = 8.0
var trap_damage: int = 14
var mark_damage_amp: float = 0.28
var burst_damage: int = 24
var trap_spacing: float = 150.0
var trap_trigger_radius: float = 60.0
var trap_blast_radius: float = 120.0
var trap_arm_delay: float = 0.18
var trap_check_interval: float = 0.12
var sniper_shots: int = 6
var sniper_interval: float = 0.22
var sniper_damage: int = 30
var sniper_mark_duration: float = 1.8
var hook_step_distance: float = 48.0
var hook_tick_interval: float = 0.05
var hook_hit_radius: float = 54.0
var hook_line_damage: int = 18
var hook_push: float = 20.0
var hook_recall_delay: float = 0.2
var hook_recall_count: int = 5
var hook_recall_damage: int = 20
var hook_recall_pull: float = 26.0
var closure_reel_count: int = 5
var closure_reel_interval: float = 0.16
var closure_reel_damage: int = 22

const TRAP_META_CENTER: String = "trapper_trap_center"
const TRAP_META_RADIUS: String = "trapper_trap_radius"
const TRAP_META_EXPIRE_MSEC: String = "trapper_trap_expire_msec"

var _has_last_trap_anchor: bool = false
var _last_trap_anchor: Vector2 = Vector2.ZERO

func _enter_planning_mode() -> void:
	_has_last_trap_anchor = false
	_last_trap_anchor = Vector2.ZERO
	super._enter_planning_mode()

func _spawn_line_effect(start: Vector2, end: Vector2) -> void:
	SkillEffectManager.create_debuff_zone({
		"start": start,
		"end": end,
		"width": 24.0,
		"duration": _get_line_duration(),
		"debuff_type": "slow",
		"debuff_value": slow_value,
		"debuff_duration": slow_duration,
		"tick_interval": 0.5,
		"damage": trap_damage,
		"damage_interval": 0.5,
		"color": Color(0.2, 0.5, 0.2, 0.5)
	})

	SkillEffectManager.create_debuff_zone({
		"start": start,
		"end": end,
		"width": 18.0,
		"duration": _get_line_duration(),
		"debuff_type": "freeze",
		"debuff_value": 0.0,
		"debuff_duration": freeze_duration * 0.45,
		"tick_interval": 1.5,
		"color": Color(0.25, 0.6, 0.35, 0.25)
	})

	_deploy_traps_along_segment(start, end)
	_launch_trapper_hook(start, end)

func _spawn_area_effect(polygon: PackedVector2Array) -> void:
	if polygon.size() < 3:
		return
	SkillEffectManager.create_debuff_zone({
		"polygon": polygon,
		"duration": trap_duration,
		"debuff_type": "damage_amp",
		"debuff_value": mark_damage_amp,
		"debuff_duration": trap_duration,
		"tick_interval": 0.45,
		"color": Color(0.25, 0.55, 0.25, 0.4)
	})

	SkillEffectManager.create_debuff_zone({
		"polygon": polygon,
		"duration": trap_duration,
		"debuff_type": "freeze",
		"debuff_value": 0.0,
		"debuff_duration": freeze_duration,
		"tick_interval": 1.25,
		"color": Color(0.2, 0.45, 0.22, 0.3)
	})

	SkillEffectManager.create_area_effect({
		"polygon": polygon,
		"damage": burst_damage,
		"damage_interval": 0.75,
		"duration": trap_duration,
		"color": Color(0.2, 0.45, 0.2, 0.18)
	})

	_cache_trap_window(polygon, trap_duration)
	_spawn_sniper_salvo(polygon)
	var center: Vector2 = _calculate_polygon_center(polygon)
	var radius: float = _polygon_radius(polygon, center)
	_spawn_closure_reel_sweeps(center, radius)

func _launch_trapper_hook(start: Vector2, finish: Vector2) -> void:
	var seg: Vector2 = finish - start
	var length: float = seg.length()
	if length <= 1.0:
		return
	var move_dir: Vector2 = seg / length
	var host: Node2D = Node2D.new()
	host.name = "HunterHookHost"
	add_child(host)

	var step_total: int = int(max(2.0, ceil(length / max(12.0, hook_step_distance))))
	var step_index: int = 0
	var timer: Timer = Timer.new()
	timer.wait_time = max(0.03, hook_tick_interval)
	timer.one_shot = false
	host.add_child(timer)
	timer.timeout.connect(func() -> void:
		if not is_instance_valid(host):
			return
		if step_index > step_total:
			timer.stop()
			host.queue_free()
			_spawn_hook_recall(finish, start, move_dir)
			return
		_emit_hook_tick(start, finish, step_index, step_total, move_dir)
		step_index += 1
	)
	timer.start()

func _spawn_hook_recall(from_pos: Vector2, to_pos: Vector2, move_dir: Vector2) -> void:
	var tree: SceneTree = get_tree()
	if tree == null:
		return
	tree.create_timer(max(0.05, hook_recall_delay)).timeout.connect(func() -> void:
		if not is_inside_tree():
			return
		var host: Node2D = Node2D.new()
		host.name = "HunterHookRecallHost"
		add_child(host)
		var pulse_total: int = int(max(1, hook_recall_count))
		var pulse_index: int = 0
		var timer: Timer = Timer.new()
		timer.wait_time = max(0.06, sniper_interval * 0.75)
		timer.one_shot = false
		host.add_child(timer)
		timer.timeout.connect(func() -> void:
			if not is_instance_valid(host):
				return
			if pulse_index >= pulse_total:
				timer.stop()
				host.queue_free()
				return
			_emit_hook_recall_tick(from_pos, to_pos, pulse_index, pulse_total, move_dir)
			pulse_index += 1
		)
		timer.start()
	)

func _emit_hook_tick(start: Vector2, finish: Vector2, index: int, total: int, move_dir: Vector2) -> void:
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
		"color": Color(0.62, 0.9, 0.62, 0.92)
	})
	_apply_radius_damage_and_mark(current, hook_hit_radius, hook_line_damage)
	_apply_forward_push(current, hook_hit_radius * 1.2, move_dir, hook_push)

func _emit_hook_recall_tick(
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
		"color": Color(0.74, 1.0, 0.74, 0.92)
	})
	_apply_line_burst_damage(start, end, 12.0, hook_recall_damage)
	_apply_pull_to_point(center, hook_hit_radius * 1.5, hook_recall_pull)

func _spawn_closure_reel_sweeps(center: Vector2, radius: float) -> void:
	var sweep_total: int = int(max(1, closure_reel_count))
	var sweep_index: int = 0
	var host: Node2D = Node2D.new()
	host.name = "HunterClosureReelHost"
	add_child(host)

	var timer: Timer = Timer.new()
	timer.wait_time = max(0.08, closure_reel_interval)
	timer.one_shot = false
	host.add_child(timer)
	timer.timeout.connect(func() -> void:
		if not is_instance_valid(host):
			return
		if sweep_index >= sweep_total:
			timer.stop()
			host.queue_free()
			return
		_emit_closure_reel(center, radius, sweep_index, sweep_total)
		sweep_index += 1
	)
	timer.start()

func _emit_closure_reel(center: Vector2, radius: float, index: int, total: int) -> void:
	var angle: float = TAU * float(index) / float(max(1, total))
	var dir: Vector2 = Vector2.RIGHT.rotated(angle)
	var start: Vector2 = center + dir * radius * 1.35
	var end: Vector2 = center - dir * radius * 0.05
	SkillEffectManager.create_line_effect({
		"start": start,
		"end": end,
		"width": 13.0,
		"damage": 0,
		"damage_interval": 0.2,
		"duration": 0.18,
		"color": Color(0.82, 1.08, 0.82, 0.9)
	})
	_apply_line_burst_damage(start, end, 12.0, closure_reel_damage)
	_apply_pull_to_point(center, radius * 0.95, hook_recall_pull * 0.7)

func _deploy_traps_along_segment(start: Vector2, end: Vector2) -> void:
	var seg: Vector2 = end - start
	var length: float = seg.length()
	if length <= 1.0:
		return
	var dir: Vector2 = seg / length

	if not _has_last_trap_anchor:
		_has_last_trap_anchor = true
		_last_trap_anchor = start
		_spawn_path_trap(start)

	var cursor: float = 0.0
	var step_len: float = float(max(24.0, trap_spacing * 0.35))
	while cursor <= length:
		var point: Vector2 = start + dir * cursor
		if _last_trap_anchor.distance_to(point) >= trap_spacing:
			_spawn_path_trap(point)
			_last_trap_anchor = point
		cursor += step_len

	if _last_trap_anchor.distance_to(end) >= trap_spacing:
		_spawn_path_trap(end)
		_last_trap_anchor = end

func _spawn_path_trap(pos: Vector2) -> void:
	var trap: Node2D = Node2D.new()
	trap.name = "HunterPathTrap"
	trap.global_position = pos
	add_child(trap)
	trap.add_to_group("player_skill_effects")

	var ring: Line2D = Line2D.new()
	ring.width = 3.0
	ring.closed = true
	ring.default_color = Color(0.3, 0.7, 0.3, 0.9)
	var ring_segments: int = 16
	for i: int in range(ring_segments):
		var ang: float = TAU * float(i) / float(ring_segments)
		ring.add_point(Vector2.RIGHT.rotated(ang) * trap_trigger_radius)
	trap.add_child(ring)

	var armed: bool = false
	var triggered: bool = false
	var elapsed: float = 0.0
	var timer: Timer = Timer.new()
	timer.wait_time = max(0.05, trap_check_interval)
	timer.one_shot = false
	trap.add_child(timer)
	timer.timeout.connect(func() -> void:
		if not is_instance_valid(trap):
			return
		elapsed += timer.wait_time
		if not armed and elapsed >= trap_arm_delay:
			armed = true
			ring.default_color = Color(0.55, 0.95, 0.55, 0.95)
		if elapsed >= trap_duration:
			timer.stop()
			trap.queue_free()
			return
		if not armed or triggered:
			return
		var target: Node2D = _find_enemy_in_radius(trap.global_position, trap_trigger_radius)
		if target == null:
			return
		triggered = true
		_trigger_trap_blast(trap.global_position)
		timer.stop()
		var tree: SceneTree = get_tree()
		if tree != null:
			var cleanup_timer: SceneTreeTimer = tree.create_timer(0.12)
			cleanup_timer.timeout.connect(func() -> void:
				if is_instance_valid(trap):
					trap.queue_free()
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

func _trigger_trap_blast(center: Vector2) -> void:
	var blast_poly: PackedVector2Array = _build_circle_polygon(center, trap_blast_radius, 18)
	SkillEffectManager.create_area_effect({
		"polygon": blast_poly,
		"damage": max(1, trap_damage + 8),
		"damage_interval": 0.1,
		"duration": 0.28,
		"color": Color(0.36, 0.8, 0.32, 0.48)
	})

	var enemies: Array = get_tree().get_nodes_in_group("enemies")
	for enemy_obj: Variant in enemies:
		if enemy_obj == null or not is_instance_valid(enemy_obj):
			continue
		if not (enemy_obj is Node2D):
			continue
		var enemy: Node2D = enemy_obj
		if enemy.global_position.distance_to(center) > trap_blast_radius:
			continue
		_apply_damage(enemy, max(1, trap_damage + 10))
		_apply_status(enemy, "freeze", freeze_duration * 0.7, 0.0, 1, 0.1)
		_apply_status(enemy, "marked", sniper_mark_duration, mark_damage_amp, 1, 0.3)

	spawn_skill_vfx(center, Color(0.45, 0.9, 0.42, 0.78), 0.48)
	Global.spawn_floating_text(center, "TRAP!", Color(0.4, 0.95, 0.4))

func _spawn_sniper_salvo(polygon: PackedVector2Array) -> void:
	var center: Vector2 = _calculate_polygon_center(polygon)
	var radius: float = _polygon_radius(polygon, center)
	var max_shot_count: int = int(max(1, sniper_shots))
	var shot_index: int = 0
	var host: Node2D = Node2D.new()
	host.name = "HunterSniperSalvo"
	add_child(host)

	var fired_first: bool = _fire_sniper_shot(polygon, center, radius, shot_index, max_shot_count)
	if fired_first:
		shot_index += 1

	var timer: Timer = Timer.new()
	timer.wait_time = max(0.08, sniper_interval)
	timer.one_shot = false
	host.add_child(timer)
	timer.timeout.connect(func() -> void:
		if not is_instance_valid(host):
			return
		if shot_index >= max_shot_count:
			timer.stop()
			host.queue_free()
			return
		var fired: bool = _fire_sniper_shot(polygon, center, radius, shot_index, max_shot_count)
		shot_index += 1
		if not fired and shot_index >= 2:
			timer.stop()
			host.queue_free()
	)
	timer.start()

func _fire_sniper_shot(polygon: PackedVector2Array, center: Vector2, radius: float, shot_index: int, shot_total: int) -> bool:
	var target: Node2D = _find_best_target_in_polygon(polygon, center)
	if target == null:
		return false

	var angle: float = TAU * float(shot_index) / float(max(1, shot_total))
	var origin: Vector2 = center + Vector2.RIGHT.rotated(angle) * (radius + 92.0)
	SkillEffectManager.create_line_effect({
		"start": origin,
		"end": target.global_position,
		"width": 8.0,
		"damage": 0,
		"damage_interval": 0.2,
		"duration": 0.2,
		"color": Color(0.65, 0.9, 0.65, 0.92)
	})

	var hp_ratio: float = _get_enemy_hp_ratio(target)
	var damage: int = sniper_damage
	if hp_ratio <= 0.35:
		damage = max(damage, int(round(float(sniper_damage) * 1.6)))
	_apply_damage(target, damage)
	_apply_status(target, "marked", sniper_mark_duration, mark_damage_amp + 0.08, 1, 0.3)
	if hp_ratio <= 0.5:
		_apply_status(target, "freeze", freeze_duration * 0.35, 0.0, 1, 0.1)
	spawn_skill_vfx(target.global_position, Color(0.75, 1.0, 0.7, 0.72), 0.34)
	return true

func _find_best_target_in_polygon(polygon: PackedVector2Array, center: Vector2) -> Node2D:
	var enemies: Array = get_tree().get_nodes_in_group("enemies")
	var best_enemy: Node2D = null
	var best_ratio: float = 99.0
	var best_dist: float = INF
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
		if hp_ratio < best_ratio or (is_equal_approx(hp_ratio, best_ratio) and dist < best_dist):
			best_ratio = hp_ratio
			best_dist = dist
			best_enemy = enemy
	return best_enemy

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

func _cache_trap_window(polygon: PackedVector2Array, duration: float) -> void:
	if not is_instance_valid(skill_owner):
		return
	var center: Vector2 = _calculate_polygon_center(polygon)
	var radius: float = _polygon_radius(polygon, center)
	var expire_msec: int = Time.get_ticks_msec() + int(round(max(0.2, duration) * 1000.0))
	skill_owner.set_meta(TRAP_META_CENTER, center)
	skill_owner.set_meta(TRAP_META_RADIUS, radius)
	skill_owner.set_meta(TRAP_META_EXPIRE_MSEC, expire_msec)

func _polygon_radius(polygon: PackedVector2Array, center: Vector2) -> float:
	var radius: float = 0.0
	for point: Vector2 in polygon:
		radius = max(radius, center.distance_to(point))
	return max(20.0, radius)

func _build_circle_polygon(center: Vector2, radius: float, segments: int) -> PackedVector2Array:
	var points: PackedVector2Array = PackedVector2Array()
	var segment_count: int = segments
	if segment_count < 8:
		segment_count = 8
	for i: int in range(segment_count):
		var ang: float = TAU * float(i) / float(segment_count)
		points.append(center + Vector2.RIGHT.rotated(ang) * radius)
	return points

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
		_apply_damage(enemy, max(1, damage))
		_apply_status(enemy, "marked", sniper_mark_duration, mark_damage_amp, 1, 0.3)

func _apply_radius_damage_and_mark(center: Vector2, radius: float, damage: int) -> void:
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
		_apply_status(enemy, "marked", sniper_mark_duration, mark_damage_amp, 1, 0.3)
		_apply_status(enemy, "slow", 0.8, slow_value * 0.7, 1, 0.1)

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

func _apply_forward_push(center: Vector2, radius: float, dir: Vector2, push_amount: float) -> void:
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
	return Color(0.2, 0.5, 0.2, 1.0)

func _get_closure_color() -> Color:
	return Color(0.15, 0.4, 0.15, 1.0)

