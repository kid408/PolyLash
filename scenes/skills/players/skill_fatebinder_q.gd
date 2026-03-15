extends SkillQBase
class_name SkillFatebinderQ

var line_mark_amp: float = 0.22
var line_chip_spacing: float = 165.0
var chip_duration: float = 4.8
var chip_interval: float = 0.38
var chip_trigger_radius: float = 220.0
var chip_hit_damage: int = 12
var jackpot_damage: int = 30
var jackpot_chain_radius: float = 220.0
var jackpot_chain_max_targets: int = 3

var roulette_duration: float = 5.2
var roulette_pulse_count: int = 7
var roulette_pulse_interval: float = 0.24
var roulette_pulse_damage: int = 20
var roulette_execute_threshold: float = 0.3
var jackpot_streak_limit: int = 3
var sector_flip_count: int = 6
var sector_flip_interval: float = 0.22
var sector_flip_damage: int = 18
var sector_flip_inner_ratio: float = 1.02
var sector_flip_outer_ratio: float = 1.36
var sector_flip_angle_deg: float = 34.0
var dart_step_distance: float = 52.0
var dart_tick_interval: float = 0.05
var dart_hit_radius: float = 54.0
var dart_line_damage: int = 16
var dart_push: float = 18.0
var dart_recall_delay: float = 0.2
var dart_recall_count: int = 5
var dart_recall_damage: int = 20
var dart_recall_pull: float = 24.0
var jackpot_reel_count: int = 5
var jackpot_reel_interval: float = 0.16
var jackpot_reel_damage: int = 22

var _line_no_jackpot_streak: int = 0

const GAMBLE_META_CENTER: String = "fatebinder_zone_center"
const GAMBLE_META_RADIUS: String = "fatebinder_zone_radius"
const GAMBLE_META_EXPIRE_MSEC: String = "fatebinder_zone_expire_msec"
const GAMBLE_META_OUTCOME: String = "fatebinder_zone_outcome"

func _spawn_line_effect(start: Vector2, end: Vector2) -> void:
	SkillEffectManager.create_debuff_zone({
		"start": start,
		"end": end,
		"width": 22.0,
		"duration": _get_line_duration(),
		"debuff_type": "damage_amp",
		"debuff_value": line_mark_amp,
		"debuff_duration": 1.8,
		"tick_interval": 0.55,
		"damage": chip_hit_damage,
		"damage_interval": 0.55,
		"color": Color(0.95, 0.75, 0.16, 0.48)
	})

	_launch_lucky_dart(start, end)
	_spawn_card_slash(start, end)
	_spawn_chips_along_segment(start, end)

func _spawn_area_effect(polygon: PackedVector2Array) -> void:
	if polygon.size() < 3:
		return

	SkillEffectManager.create_debuff_zone({
		"polygon": polygon,
		"duration": roulette_duration,
		"debuff_type": "damage_amp",
		"debuff_value": line_mark_amp,
		"debuff_duration": 1.6,
		"tick_interval": 0.6,
		"color": Color(0.9, 0.66, 0.12, 0.2)
	})

	var outcome: String = "jackpot"
	_spawn_roulette_pulses(polygon)
	_spawn_sector_flip_rig(polygon)
	_spawn_jackpot_reel(polygon)
	_cache_gamble_window(polygon, roulette_duration, outcome)

func _launch_lucky_dart(start: Vector2, finish: Vector2) -> void:
	var seg: Vector2 = finish - start
	var length: float = seg.length()
	if length <= 1.0:
		return
	var move_dir: Vector2 = seg / length
	var host: Node2D = Node2D.new()
	host.name = "GamblerLuckyDartHost"
	add_child(host)

	var step_total: int = int(max(2.0, ceil(length / max(12.0, dart_step_distance))))
	var step_index: int = 0
	var timer: Timer = Timer.new()
	timer.wait_time = max(0.03, dart_tick_interval)
	timer.one_shot = false
	host.add_child(timer)
	timer.timeout.connect(func() -> void:
		if not is_instance_valid(host):
			return
		if step_index > step_total:
			timer.stop()
			host.queue_free()
			_spawn_lucky_dart_recall(finish, start, move_dir)
			return
		_emit_lucky_dart_tick(start, finish, step_index, step_total, move_dir)
		step_index += 1
	)
	timer.start()

func _spawn_lucky_dart_recall(from_pos: Vector2, to_pos: Vector2, move_dir: Vector2) -> void:
	var tree: SceneTree = get_tree()
	if tree == null:
		return
	tree.create_timer(max(0.05, dart_recall_delay)).timeout.connect(func() -> void:
		if not is_inside_tree():
			return
		var host: Node2D = Node2D.new()
		host.name = "GamblerLuckyDartRecallHost"
		add_child(host)
		var pulse_total: int = int(max(1, dart_recall_count))
		var pulse_index: int = 0
		var timer: Timer = Timer.new()
		timer.wait_time = max(0.06, dart_tick_interval * 1.6)
		timer.one_shot = false
		host.add_child(timer)
		timer.timeout.connect(func() -> void:
			if not is_instance_valid(host):
				return
			if pulse_index >= pulse_total:
				timer.stop()
				host.queue_free()
				return
			_emit_lucky_dart_recall_tick(from_pos, to_pos, pulse_index, pulse_total, move_dir)
			pulse_index += 1
		)
		timer.start()
	)

func _emit_lucky_dart_tick(start: Vector2, finish: Vector2, index: int, total: int, move_dir: Vector2) -> void:
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
		"color": Color(1.0, 0.9, 0.4, 0.92)
	})
	_apply_radius_mark_damage(current, dart_hit_radius, dart_line_damage)
	_apply_direction_push(current, dart_hit_radius * 1.2, move_dir, dart_push)

func _emit_lucky_dart_recall_tick(
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
		"color": Color(1.0, 0.95, 0.55, 0.92)
	})
	_apply_line_burst_damage(start, end, 12.0, dart_recall_damage)
	_apply_pull_to_point(center, dart_hit_radius * 1.55, dart_recall_pull)

func _spawn_jackpot_reel(polygon: PackedVector2Array) -> void:
	var center: Vector2 = _calculate_polygon_center(polygon)
	var radius: float = _polygon_radius(polygon, center)
	var sweep_total: int = int(max(1, jackpot_reel_count))
	var sweep_index: int = 0
	var host: Node2D = Node2D.new()
	host.name = "GamblerJackpotReelHost"
	add_child(host)

	var timer: Timer = Timer.new()
	timer.wait_time = max(0.08, jackpot_reel_interval)
	timer.one_shot = false
	host.add_child(timer)
	timer.timeout.connect(func() -> void:
		if not is_instance_valid(host):
			return
		if sweep_index >= sweep_total:
			timer.stop()
			host.queue_free()
			return
		_emit_jackpot_reel(center, radius, sweep_index, sweep_total)
		sweep_index += 1
	)
	timer.start()

func _emit_jackpot_reel(center: Vector2, radius: float, index: int, total: int) -> void:
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
		"color": Color(1.0, 0.9, 0.42, 0.9)
	})
	_apply_line_burst_damage(start, end, 12.0, jackpot_reel_damage)
	_apply_pull_to_point(center, radius * 1.02, dart_recall_pull * 0.58)

func _spawn_card_slash(start: Vector2, end: Vector2) -> void:
	SkillEffectManager.create_line_effect({
		"start": start,
		"end": end,
		"width": 10.0,
		"damage": 0,
		"damage_interval": 0.2,
		"duration": 0.18,
		"color": Color(1.0, 0.82, 0.26, 0.9)
	})
	_apply_line_burst_damage(start, end, 18.0, chip_hit_damage)

func _spawn_chips_along_segment(start: Vector2, end: Vector2) -> void:
	var seg: Vector2 = end - start
	var length: float = seg.length()
	if length <= 1.0:
		_spawn_chip(start)
		return
	var dir: Vector2 = seg / length
	var spacing: float = float(max(56.0, line_chip_spacing))
	var cursor: float = 0.0
	while cursor <= length:
		_spawn_chip(start + dir * cursor)
		cursor += spacing
	if fmod(length, spacing) > 20.0:
		_spawn_chip(end)

func _spawn_chip(pos: Vector2) -> void:
	var chip: Node2D = Node2D.new()
	chip.name = "GamblerChipNode"
	chip.global_position = pos
	add_child(chip)
	chip.add_to_group("player_skill_effects")

	var elapsed: float = 0.0
	var timer: Timer = Timer.new()
	timer.wait_time = float(max(0.08, chip_interval))
	timer.one_shot = false
	chip.add_child(timer)
	timer.timeout.connect(func() -> void:
		if not is_instance_valid(chip):
			return
		elapsed += timer.wait_time
		if elapsed >= chip_duration:
			timer.stop()
			chip.queue_free()
			return
		_emit_chip_pulse(chip.global_position)
	)
	timer.start()

	spawn_skill_vfx(pos, Color(1.0, 0.82, 0.28, 0.72), 0.26)

func _emit_chip_pulse(center: Vector2) -> void:
	var target: Node2D = _find_nearest_enemy(center, chip_trigger_radius)
	if target == null:
		return

	var outcome: String = _roll_line_outcome()
	match outcome:
		"buff":
			_apply_damage(target, chip_hit_damage + 2)
			_apply_status(target, "marked", 1.2, line_mark_amp, 1, 0.3)
			Global.spawn_coin(target.global_position, 1)
			Global.spawn_floating_text(target.global_position, "WIN", Color(1.0, 0.86, 0.32))
		"debuff":
			_apply_damage(target, chip_hit_damage)
			_apply_status(target, "slow", 1.0, 0.52, 1, 0.1)
			_apply_status(target, "fear", 0.5, 1.0, 1, 0.2)
			Global.spawn_floating_text(target.global_position, "LOSS", Color(0.9, 0.62, 0.14))
		_:
			_apply_damage(target, jackpot_damage)
			_apply_status(target, "marked", 1.5, line_mark_amp + 0.1, 1, 0.3)
			_chain_jackpot(target.global_position, target)
			Global.spawn_coin(target.global_position, 2)
			Global.spawn_floating_text(target.global_position, "JACKPOT!", Color(1.0, 0.92, 0.32))

func _chain_jackpot(center: Vector2, primary_target: Node2D) -> void:
	var hit_count: int = 0
	var enemies: Array = get_tree().get_nodes_in_group("enemies")
	for enemy_obj: Variant in enemies:
		if enemy_obj == null or not is_instance_valid(enemy_obj):
			continue
		if not (enemy_obj is Node2D):
			continue
		var enemy: Node2D = enemy_obj
		if enemy == primary_target:
			continue
		if enemy.global_position.distance_to(center) > jackpot_chain_radius:
			continue
		SkillEffectManager.create_line_effect({
			"start": center,
			"end": enemy.global_position,
			"width": 8.0,
			"damage": 0,
			"damage_interval": 0.2,
			"duration": 0.16,
			"color": Color(1.0, 0.9, 0.36, 0.9)
		})
		_apply_damage(enemy, int(max(1, jackpot_damage - 8)))
		_apply_status(enemy, "marked", 1.0, line_mark_amp, 1, 0.3)
		hit_count += 1
		if hit_count >= jackpot_chain_max_targets:
			break

func _spawn_roulette_pulses(polygon: PackedVector2Array) -> void:
	var center: Vector2 = _calculate_polygon_center(polygon)
	var radius: float = _polygon_radius(polygon, center)
	var pulse_total: int = int(max(1, roulette_pulse_count))
	var pulse_index: int = 0
	var host: Node2D = Node2D.new()
	host.name = "GamblerRouletteHost"
	add_child(host)

	_emit_roulette_pulse(polygon, center, radius, pulse_index)
	pulse_index += 1

	var timer: Timer = Timer.new()
	timer.wait_time = float(max(0.08, roulette_pulse_interval))
	timer.one_shot = false
	host.add_child(timer)
	timer.timeout.connect(func() -> void:
		if not is_instance_valid(host):
			return
		if pulse_index >= pulse_total:
			timer.stop()
			host.queue_free()
			return
		_emit_roulette_pulse(polygon, center, radius, pulse_index)
		pulse_index += 1
	)
	timer.start()

func _emit_roulette_pulse(polygon: PackedVector2Array, center: Vector2, radius: float, index: int) -> void:
	var target: Node2D = _find_best_target_in_polygon(polygon, center)
	if target == null:
		return
	var angle: float = TAU * float(index) / float(max(1, roulette_pulse_count))
	var origin: Vector2 = center + Vector2.RIGHT.rotated(angle) * (radius + 78.0)
	SkillEffectManager.create_line_effect({
		"start": origin,
		"end": target.global_position,
		"width": 10.0,
		"damage": 0,
		"damage_interval": 0.2,
		"duration": 0.2,
		"color": Color(1.0, 0.84, 0.32, 0.9)
	})

	var damage: int = roulette_pulse_damage + int(round(float(index) * 0.6))
	var hp_ratio: float = _get_enemy_hp_ratio(target)
	if hp_ratio <= roulette_execute_threshold or ((index + 1) % 3 == 0):
		damage = max(damage, int(round(float(roulette_pulse_damage) * 1.8)))
		_apply_status(target, "fear", 0.6, 1.0, 1, 0.2)
		Global.spawn_floating_text(target.global_position, "ALL-IN", Color(1.0, 0.9, 0.3))
	_apply_damage(target, max(1, damage))
	_apply_status(target, "marked", 1.3, line_mark_amp + 0.06, 1, 0.3)

func _spawn_sector_flip_rig(polygon: PackedVector2Array) -> void:
	var center: Vector2 = _calculate_polygon_center(polygon)
	var radius: float = _polygon_radius(polygon, center)
	var flip_total: int = int(max(1, sector_flip_count))
	var flip_index: int = 0
	var host: Node2D = Node2D.new()
	host.name = "GamblerSectorFlipHost"
	add_child(host)

	_emit_sector_flip(center, radius, flip_index, flip_total)
	flip_index += 1

	var timer: Timer = Timer.new()
	timer.wait_time = float(max(0.08, sector_flip_interval))
	timer.one_shot = false
	host.add_child(timer)
	timer.timeout.connect(func() -> void:
		if not is_instance_valid(host):
			return
		if flip_index >= flip_total:
			timer.stop()
			host.queue_free()
			return
		_emit_sector_flip(center, radius, flip_index, flip_total)
		flip_index += 1
	)
	timer.start()

func _emit_sector_flip(center: Vector2, radius: float, index: int, total: int) -> void:
	var angle: float = TAU * float(index) / float(max(1, total))
	var dir: Vector2 = Vector2.RIGHT.rotated(angle)
	var start: Vector2 = center + dir * radius * max(1.01, sector_flip_inner_ratio)
	var end: Vector2 = center + dir * radius * max(1.14, sector_flip_outer_ratio)
	SkillEffectManager.create_line_effect({
		"start": start,
		"end": end,
		"width": 14.0,
		"damage": 0,
		"damage_interval": 0.2,
		"duration": 0.16,
		"color": Color(1.0, 0.9, 0.34, 0.9)
	})
	var reward_sector: bool = randf() < 0.45
	var half_angle_cos: float = cos(deg_to_rad(max(8.0, sector_flip_angle_deg) * 0.5))
	_apply_sector_flip(
		center,
		radius * max(1.01, sector_flip_inner_ratio),
		radius * max(1.14, sector_flip_outer_ratio),
		dir,
		half_angle_cos,
		reward_sector
	)

func _apply_sector_flip(
	center: Vector2,
	inner_radius: float,
	outer_radius: float,
	facing: Vector2,
	half_angle_cos: float,
	reward_sector: bool
) -> void:
	var enemies: Array = get_tree().get_nodes_in_group("enemies")
	var safe_facing: Vector2 = facing.normalized()
	var spawned_coins: int = 0
	for enemy_obj: Variant in enemies:
		if enemy_obj == null or not is_instance_valid(enemy_obj):
			continue
		if not (enemy_obj is Node2D):
			continue
		var enemy: Node2D = enemy_obj
		var offset: Vector2 = enemy.global_position - center
		var dist: float = offset.length()
		if dist < inner_radius or dist > outer_radius:
			continue
		if dist <= 0.001:
			continue
		var dir_norm: Vector2 = offset / dist
		if dir_norm.dot(safe_facing) < half_angle_cos:
			continue
		if reward_sector:
			_apply_status(enemy, "marked", 1.1, line_mark_amp + 0.08, 1, 0.3)
			_apply_status(enemy, "slow", 0.8, 0.28, 1, 0.1)
			if spawned_coins < 2 and randf() < 0.55:
				Global.spawn_coin(enemy.global_position, 1)
				spawned_coins += 1
		else:
			_apply_damage(enemy, max(1, sector_flip_damage))
			_apply_status(enemy, "fear", 0.6, 1.0, 1, 0.2)
			_apply_status(enemy, "slow", 1.0, 0.44, 1, 0.1)
			enemy.global_position += dir_norm * 24.0

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
		_apply_status(enemy, "marked", 1.0, line_mark_amp, 1, 0.3)

func _apply_radius_mark_damage(center: Vector2, radius: float, damage: int) -> void:
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
		_apply_status(enemy, "marked", 1.1, line_mark_amp + 0.02, 1, 0.3)

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
		var score: float = (1.0 - hp_ratio) * 1.8 + (1.0 / float(max(1.0, dist * 0.01)))
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

func _roll_line_outcome() -> String:
	if _line_no_jackpot_streak >= jackpot_streak_limit:
		_line_no_jackpot_streak = 0
		return "jackpot"

	var roll: float = randf()
	if roll < 0.2:
		_line_no_jackpot_streak = 0
		return "jackpot"
	if roll < 0.62:
		_line_no_jackpot_streak += 1
		return "buff"
	_line_no_jackpot_streak += 1
	return "debuff"

func _cache_gamble_window(polygon: PackedVector2Array, duration: float, outcome: String) -> void:
	if not is_instance_valid(skill_owner):
		return
	var center: Vector2 = _calculate_polygon_center(polygon)
	var radius: float = _polygon_radius(polygon, center)
	var expire_msec: int = Time.get_ticks_msec() + int(round(float(max(0.2, duration)) * 1000.0))
	skill_owner.set_meta(GAMBLE_META_CENTER, center)
	skill_owner.set_meta(GAMBLE_META_RADIUS, radius)
	skill_owner.set_meta(GAMBLE_META_EXPIRE_MSEC, expire_msec)
	skill_owner.set_meta(GAMBLE_META_OUTCOME, outcome)

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
	return Color(0.95, 0.78, 0.2, 1.0)

func _get_closure_color() -> Color:
	return Color(0.95, 0.68, 0.1, 1.0)

