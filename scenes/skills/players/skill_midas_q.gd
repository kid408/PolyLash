extends SkillDrawingBase
class_name SkillMidasQ

var petrify_slow: float = 0.95
var petrify_duration: float = 3.0
var transmute_damage_amp: float = 0.5
var transmute_duration: float = 5.0
var gilded_line_damage: int = 10
var transmute_coin_count: int = 4
var transmute_bonus_damage: int = 22
var stake_spacing: float = 165.0
var stake_trigger_radius: float = 58.0
var stake_blast_radius: float = 118.0
var stake_arm_delay: float = 0.22
var stake_check_interval: float = 0.12
var treasury_pulse_count: int = 6
var treasury_pulse_interval: float = 0.26
var treasury_pulse_damage: int = 20
var execute_threshold: float = 0.28
var spear_step_distance: float = 50.0
var spear_tick_interval: float = 0.05
var spear_hit_radius: float = 55.0
var spear_hit_damage: int = 17
var spear_push: float = 20.0
var spear_recall_delay: float = 0.2
var spear_recall_count: int = 5
var spear_recall_damage: int = 19
var spear_recall_pull: float = 24.0
var treasury_reflux_count: int = 6
var treasury_reflux_interval: float = 0.17
var treasury_reflux_damage: int = 21

const MIDAS_META_CENTER: String = "midas_transmute_center"
const MIDAS_META_RADIUS: String = "midas_transmute_radius"
const MIDAS_META_EXPIRE_MSEC: String = "midas_transmute_expire_msec"

var _has_last_stake_anchor: bool = false
var _last_stake_anchor: Vector2 = Vector2.ZERO

func _enter_planning_mode() -> void:
	_has_last_stake_anchor = false
	_last_stake_anchor = Vector2.ZERO
	super._enter_planning_mode()

func _spawn_line_effect(start: Vector2, end: Vector2) -> void:
	SkillEffectManager.create_debuff_zone({
		"start": start,
		"end": end,
		"width": 24.0,
		"duration": _get_line_duration(),
		"debuff_type": "slow",
		"debuff_value": petrify_slow,
		"debuff_duration": petrify_duration,
		"tick_interval": 0.75,
		"damage": gilded_line_damage,
		"damage_interval": 0.75,
		"color": Color(0.9, 0.7, 0.1, 0.5)
	})

	SkillEffectManager.create_debuff_zone({
		"start": start,
		"end": end,
		"width": 20.0,
		"duration": _get_line_duration(),
		"debuff_type": "damage_amp",
		"debuff_value": transmute_damage_amp * 0.5,
		"debuff_duration": 2.0,
		"tick_interval": 0.75,
		"color": Color(0.95, 0.78, 0.2, 0.3)
	})

	_deploy_stakes_along_segment(start, end)
	_launch_gilded_spear(start, end)

func _spawn_area_effect(polygon: PackedVector2Array) -> void:
	if polygon.size() < 3:
		return
	SkillEffectManager.create_debuff_zone({
		"polygon": polygon,
		"duration": transmute_duration,
		"debuff_type": "damage_amp",
		"debuff_value": transmute_damage_amp,
		"debuff_duration": transmute_duration,
		"tick_interval": 0.6,
		"color": Color(0.92, 0.74, 0.14, 0.42)
	})

	SkillEffectManager.create_debuff_zone({
		"polygon": polygon,
		"duration": transmute_duration,
		"debuff_type": "slow",
		"debuff_value": float(min(0.98, petrify_slow + 0.03)),
		"debuff_duration": petrify_duration,
		"tick_interval": 1.1,
		"color": Color(0.85, 0.65, 0.05, 0.25)
	})

	SkillEffectManager.create_area_effect({
		"polygon": polygon,
		"damage": transmute_bonus_damage,
		"damage_interval": 0.8,
		"duration": transmute_duration,
		"color": Color(0.8, 0.6, 0.0, 0.18)
	})

	_spawn_transmute_coin_burst(polygon, transmute_coin_count)
	_spawn_treasury_pulses(polygon)
	var center: Vector2 = _calculate_polygon_center(polygon)
	var radius: float = _calculate_transmute_radius(polygon, center)
	_spawn_treasury_reflux(center, radius)
	_cache_transmute_window(polygon, transmute_duration)

func _launch_gilded_spear(start: Vector2, finish: Vector2) -> void:
	var seg: Vector2 = finish - start
	var length: float = seg.length()
	if length <= 1.0:
		return
	var move_dir: Vector2 = seg / length
	var host: Node2D = Node2D.new()
	host.name = "MidasSpearHost"
	add_child(host)

	var step_total: int = int(max(2.0, ceil(length / max(12.0, spear_step_distance))))
	var step_index: int = 0
	var timer: Timer = Timer.new()
	timer.wait_time = max(0.03, spear_tick_interval)
	timer.one_shot = false
	host.add_child(timer)
	timer.timeout.connect(func() -> void:
		if not is_instance_valid(host):
			return
		if step_index > step_total:
			timer.stop()
			host.queue_free()
			_spawn_spear_recall(finish, start, move_dir)
			return
		_emit_spear_tick(start, finish, step_index, step_total, move_dir)
		step_index += 1
	)
	timer.start()

func _spawn_spear_recall(from_pos: Vector2, to_pos: Vector2, move_dir: Vector2) -> void:
	var tree: SceneTree = get_tree()
	if tree == null:
		return
	tree.create_timer(max(0.05, spear_recall_delay)).timeout.connect(func() -> void:
		if not is_inside_tree():
			return
		var host: Node2D = Node2D.new()
		host.name = "MidasSpearRecallHost"
		add_child(host)
		var pulse_total: int = int(max(1, spear_recall_count))
		var pulse_index: int = 0
		var timer: Timer = Timer.new()
		timer.wait_time = max(0.06, treasury_pulse_interval * 0.75)
		timer.one_shot = false
		host.add_child(timer)
		timer.timeout.connect(func() -> void:
			if not is_instance_valid(host):
				return
			if pulse_index >= pulse_total:
				timer.stop()
				host.queue_free()
				return
			_emit_spear_recall_tick(from_pos, to_pos, pulse_index, pulse_total, move_dir)
			pulse_index += 1
		)
		timer.start()
	)

func _emit_spear_tick(start: Vector2, finish: Vector2, index: int, total: int, move_dir: Vector2) -> void:
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
		"color": Color(1.0, 0.88, 0.5, 0.92)
	})
	_apply_radius_damage(current, spear_hit_radius, spear_hit_damage)
	_apply_forward_push(current, spear_hit_radius * 1.2, move_dir, spear_push)

func _emit_spear_recall_tick(
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
	var start: Vector2 = center - tangent * 66.0
	var end: Vector2 = center + tangent * 66.0
	SkillEffectManager.create_line_effect({
		"start": start,
		"end": end,
		"width": 12.0,
		"damage": 0,
		"damage_interval": 0.2,
		"duration": 0.16,
		"color": Color(1.0, 0.94, 0.62, 0.92)
	})
	_apply_line_burst_damage(start, end, 12.0, spear_recall_damage)
	_apply_pull_to_point(center, spear_hit_radius * 1.5, spear_recall_pull)

func _deploy_stakes_along_segment(start: Vector2, end: Vector2) -> void:
	var seg: Vector2 = end - start
	var length: float = seg.length()
	if length <= 1.0:
		return
	var dir: Vector2 = seg / length

	if not _has_last_stake_anchor:
		_has_last_stake_anchor = true
		_last_stake_anchor = start
		_spawn_gilded_stake(start)

	var cursor: float = 0.0
	var step_len: float = float(max(24.0, stake_spacing * 0.35))
	while cursor <= length:
		var point: Vector2 = start + dir * cursor
		if _last_stake_anchor.distance_to(point) >= stake_spacing:
			_spawn_gilded_stake(point)
			_last_stake_anchor = point
		cursor += step_len

	if _last_stake_anchor.distance_to(end) >= stake_spacing:
		_spawn_gilded_stake(end)
		_last_stake_anchor = end

func _spawn_gilded_stake(pos: Vector2) -> void:
	var stake: Node2D = Node2D.new()
	stake.name = "MidasGildedStake"
	stake.global_position = pos
	add_child(stake)
	stake.add_to_group("player_skill_effects")

	var ring: Line2D = Line2D.new()
	ring.width = 2.0
	ring.closed = true
	ring.default_color = Color(0.95, 0.8, 0.28, 0.9)
	var ring_segments: int = 14
	for i: int in range(ring_segments):
		var ang: float = TAU * float(i) / float(ring_segments)
		ring.add_point(Vector2.RIGHT.rotated(ang) * stake_trigger_radius)
	stake.add_child(ring)

	var armed: bool = false
	var triggered: bool = false
	var elapsed: float = 0.0
	var timer: Timer = Timer.new()
	timer.wait_time = max(0.05, stake_check_interval)
	timer.one_shot = false
	stake.add_child(timer)
	timer.timeout.connect(func() -> void:
		if not is_instance_valid(stake):
			return
		elapsed += timer.wait_time
		if not armed and elapsed >= stake_arm_delay:
			armed = true
			ring.default_color = Color(1.0, 0.88, 0.35, 0.96)
		if elapsed >= petrify_duration:
			timer.stop()
			stake.queue_free()
			return
		if not armed or triggered:
			return
		var target: Node2D = _find_enemy_in_radius(stake.global_position, stake_trigger_radius)
		if target == null:
			return
		triggered = true
		_trigger_stake_blast(stake.global_position)
		timer.stop()
		var tree: SceneTree = get_tree()
		if tree != null:
			var cleanup_timer: SceneTreeTimer = tree.create_timer(0.12)
			cleanup_timer.timeout.connect(func() -> void:
				if is_instance_valid(stake):
					stake.queue_free()
			)
	)
	timer.start()

func _trigger_stake_blast(center: Vector2) -> void:
	var blast_poly: PackedVector2Array = _build_circle_polygon(center, stake_blast_radius, 18)
	SkillEffectManager.create_area_effect({
		"polygon": blast_poly,
		"damage": max(1, transmute_bonus_damage - 2),
		"damage_interval": 0.1,
		"duration": 0.26,
		"color": Color(1.0, 0.78, 0.3, 0.42)
	})
	var enemies: Array = get_tree().get_nodes_in_group("enemies")
	for enemy_obj: Variant in enemies:
		if enemy_obj == null or not is_instance_valid(enemy_obj):
			continue
		if not (enemy_obj is Node2D):
			continue
		var enemy: Node2D = enemy_obj
		if enemy.global_position.distance_to(center) > stake_blast_radius:
			continue
		_apply_damage(enemy, max(1, transmute_bonus_damage))
		_apply_status(enemy, "slow", petrify_duration * 0.6, float(min(0.98, petrify_slow + 0.02)), 1, 0.1)
		_apply_status(enemy, "marked", 1.2, transmute_damage_amp * 0.45, 1, 0.3)
	spawn_skill_vfx(center, Color(1.0, 0.82, 0.35, 0.82), 0.44)

func _spawn_treasury_pulses(polygon: PackedVector2Array) -> void:
	var center: Vector2 = _calculate_polygon_center(polygon)
	var radius: float = _calculate_transmute_radius(polygon, center)
	var pulse_total: int = int(max(1, treasury_pulse_count))
	var pulse_index: int = 0
	var host: Node2D = Node2D.new()
	host.name = "MidasTreasuryPulses"
	add_child(host)

	_emit_treasury_pulse(polygon, center, radius, pulse_index, pulse_total)
	pulse_index += 1

	var timer: Timer = Timer.new()
	timer.wait_time = max(0.08, treasury_pulse_interval)
	timer.one_shot = false
	host.add_child(timer)
	timer.timeout.connect(func() -> void:
		if not is_instance_valid(host):
			return
		if pulse_index >= pulse_total:
			timer.stop()
			host.queue_free()
			return
		_emit_treasury_pulse(polygon, center, radius, pulse_index, pulse_total)
		pulse_index += 1
	)
	timer.start()

func _spawn_treasury_reflux(center: Vector2, radius: float) -> void:
	var sweep_total: int = int(max(1, treasury_reflux_count))
	var sweep_index: int = 0
	var host: Node2D = Node2D.new()
	host.name = "MidasTreasuryRefluxHost"
	add_child(host)

	var timer: Timer = Timer.new()
	timer.wait_time = max(0.08, treasury_reflux_interval)
	timer.one_shot = false
	host.add_child(timer)
	timer.timeout.connect(func() -> void:
		if not is_instance_valid(host):
			return
		if sweep_index >= sweep_total:
			timer.stop()
			host.queue_free()
			return
		_emit_treasury_reflux(center, radius, sweep_index, sweep_total)
		sweep_index += 1
	)
	timer.start()

func _emit_treasury_reflux(center: Vector2, radius: float, index: int, total: int) -> void:
	var angle: float = TAU * float(index) / float(max(1, total))
	var dir: Vector2 = Vector2.RIGHT.rotated(angle)
	var start: Vector2 = center + dir * radius * 1.35
	var end: Vector2 = center - dir * radius * 0.08
	SkillEffectManager.create_line_effect({
		"start": start,
		"end": end,
		"width": 13.0,
		"damage": 0,
		"damage_interval": 0.2,
		"duration": 0.18,
		"color": Color(1.0, 0.98, 0.7, 0.92)
	})
	_apply_line_burst_damage(start, end, 12.0, treasury_reflux_damage)
	_apply_pull_to_point(center, radius * 0.95, spear_recall_pull * 0.75)

func _emit_treasury_pulse(polygon: PackedVector2Array, center: Vector2, radius: float, index: int, total: int) -> void:
	var target: Node2D = _find_best_target_in_polygon(polygon, center)
	if target == null:
		return
	var angle: float = TAU * float(index) / float(max(1, total))
	var origin: Vector2 = center + Vector2.RIGHT.rotated(angle) * (radius + 80.0)
	SkillEffectManager.create_line_effect({
		"start": origin,
		"end": target.global_position,
		"width": 10.0,
		"damage": 0,
		"damage_interval": 0.2,
		"duration": 0.2,
		"color": Color(1.0, 0.86, 0.4, 0.92)
	})
	var hp_ratio: float = _get_enemy_hp_ratio(target)
	var damage: int = treasury_pulse_damage + int(round(float(index) * 0.7))
	if hp_ratio <= execute_threshold:
		damage = max(damage, int(round(float(treasury_pulse_damage) * 2.0)))
		Global.spawn_coin(target.global_position, 2)
		Global.spawn_floating_text(target.global_position, "GILD!", Color(1.0, 0.85, 0.35))
	else:
		Global.spawn_coin(target.global_position, 1)
	_apply_damage(target, max(1, damage))
	_apply_status(target, "marked", 1.2, transmute_damage_amp, 1, 0.3)

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
		_apply_status(enemy, "marked", 1.1, transmute_damage_amp * 0.55, 1, 0.3)

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
		_apply_status(enemy, "slow", 0.8, petrify_slow * 0.7, 1, 0.1)
		_apply_status(enemy, "marked", 1.0, transmute_damage_amp * 0.4, 1, 0.3)

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
		var score: float = (1.0 - hp_ratio) * 1.8 + (1.0 / max(1.0, dist * 0.01))
		if score > best_score:
			best_score = score
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

func _spawn_transmute_coin_burst(polygon: PackedVector2Array, base_count: int) -> void:
	if base_count <= 0 or polygon.size() < 3:
		return

	var center: Vector2 = _calculate_polygon_center(polygon)
	var area: float = _calculate_polygon_area(polygon)
	var scaled_count: int = base_count + int(clamp(area / 18000.0, 0.0, 4.0))

	for i: int in range(scaled_count):
		var angle: float = TAU * float(i) / float(max(scaled_count, 1))
		var radius: float = 36.0 + float(i % 3) * 18.0
		var pos: Vector2 = center + Vector2.RIGHT.rotated(angle) * radius
		Global.spawn_coin(pos, 1)

	Global.spawn_floating_text(center, "GOLD RUSH!", Color(1.0, 0.85, 0.22))

func _cache_transmute_window(polygon: PackedVector2Array, duration: float) -> void:
	if not is_instance_valid(skill_owner):
		return
	var center: Vector2 = _calculate_polygon_center(polygon)
	var radius: float = _calculate_transmute_radius(polygon, center)
	var expire_msec: int = Time.get_ticks_msec() + int(round(max(0.2, duration) * 1000.0))
	skill_owner.set_meta(MIDAS_META_CENTER, center)
	skill_owner.set_meta(MIDAS_META_RADIUS, radius)
	skill_owner.set_meta(MIDAS_META_EXPIRE_MSEC, expire_msec)

func _calculate_transmute_radius(polygon: PackedVector2Array, center: Vector2) -> float:
	var radius: float = 0.0
	for point: Vector2 in polygon:
		radius = float(max(radius, center.distance_to(point)))
	return float(max(8.0, radius))

func _build_circle_polygon(center: Vector2, radius: float, segments: int) -> PackedVector2Array:
	var points: PackedVector2Array = PackedVector2Array()
	var segment_count: int = segments
	if segment_count < 8:
		segment_count = 8
	for i: int in range(segment_count):
		var ang: float = TAU * float(i) / float(segment_count)
		points.append(center + Vector2.RIGHT.rotated(ang) * radius)
	return points

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
	return Color(0.9, 0.7, 0.1, 1.0)

func _get_closure_color() -> Color:
	return Color(0.8, 0.6, 0.0, 1.0)
