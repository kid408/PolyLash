extends SkillQBase
class_name SkillBrokerQ

var bounty_damage_amp: float = 0.2
var bounty_duration: float = 3.0
var discount_speed_boost: float = 0.15
var market_duration: float = 6.0
var market_coin_count: int = 3
var market_discount_amp: float = 0.16
var beacon_spacing: float = 170.0
var beacon_radius: float = 86.0
var beacon_duration: float = 4.8
var beacon_attack_interval: float = 0.32
var beacon_attack_damage: int = 11
var beacon_attack_range: float = 300.0
var contract_slash_damage: int = 14
var contract_slash_width: float = 28.0
var auction_pulse_count: int = 6
var auction_pulse_interval: float = 0.24
var auction_pulse_damage: int = 18
var perimeter_tax_count: int = 7
var perimeter_tax_interval: float = 0.22
var perimeter_tax_damage: int = 16
var perimeter_tax_width: float = 22.0
var perimeter_tax_coin_chance: float = 0.45
var caravan_step_distance: float = 52.0
var caravan_tick_interval: float = 0.05
var caravan_hit_radius: float = 56.0
var caravan_hit_damage: int = 15
var caravan_push: float = 18.0
var caravan_recall_delay: float = 0.2
var caravan_recall_count: int = 5
var caravan_recall_damage: int = 17
var caravan_recall_pull: float = 22.0
var market_reflux_count: int = 6
var market_reflux_interval: float = 0.17
var market_reflux_damage: int = 18

const MARKET_META_CENTER: String = "broker_market_center"
const MARKET_META_RADIUS: String = "broker_market_radius"
const MARKET_META_EXPIRE_MSEC: String = "broker_market_expire_msec"

var _beacon_points: Array[Vector2] = []

func _enter_planning_mode() -> void:
	_beacon_points.clear()
	super._enter_planning_mode()

func _spawn_line_effect(start: Vector2, end: Vector2) -> void:
	SkillEffectManager.create_debuff_zone({
		"start": start,
		"end": end,
		"width": 24.0,
		"duration": _get_line_duration(),
		"debuff_type": "damage_amp",
		"debuff_value": bounty_damage_amp,
		"debuff_duration": bounty_duration,
		"tick_interval": 0.6,
		"color": Color(1.0, 0.8, 0.2, 0.5)
	})

	_spawn_contract_slash(start, end)
	_launch_trade_caravan(start, end)
	_deploy_beacon_if_needed(start)
	_deploy_beacon_if_needed(end)

func _spawn_area_effect(polygon: PackedVector2Array) -> void:
	if polygon.size() < 3:
		return
	SkillEffectManager.create_buff_zone({
		"polygon": polygon,
		"duration": market_duration,
		"buff_type": "speed_boost",
		"buff_value": discount_speed_boost,
		"tick_interval": 0.5,
		"color": Color(1.0, 0.7, 0.1, 0.4)
	})
	SkillEffectManager.create_debuff_zone({
		"polygon": polygon,
		"duration": market_duration,
		"debuff_type": "damage_amp",
		"debuff_value": market_discount_amp,
		"debuff_duration": 1.1,
		"tick_interval": 0.45,
		"color": Color(1.0, 0.72, 0.18, 0.16)
	})
	_spawn_market_coin_burst(polygon, market_coin_count)
	_spawn_auction_pulses(polygon)
	_spawn_perimeter_tax_sweeps(polygon)
	var center: Vector2 = _calculate_polygon_center(polygon)
	var radius: float = _calculate_market_radius(polygon, center)
	_spawn_market_reflux(center, radius)
	_cache_market_window(polygon, market_duration)

func _spawn_contract_slash(start: Vector2, end: Vector2) -> void:
	SkillEffectManager.create_line_effect({
		"start": start,
		"end": end,
		"width": contract_slash_width,
		"damage": 0,
		"damage_interval": 0.2,
		"duration": 0.2,
		"color": Color(1.0, 0.85, 0.32, 0.78)
	})
	_apply_line_burst_damage(start, end, contract_slash_width * 0.52, contract_slash_damage)

func _launch_trade_caravan(start: Vector2, finish: Vector2) -> void:
	var seg: Vector2 = finish - start
	var length: float = seg.length()
	if length <= 1.0:
		return
	var move_dir: Vector2 = seg / length
	var host: Node2D = Node2D.new()
	host.name = "MerchantCaravanHost"
	add_child(host)

	var step_total: int = int(max(2.0, ceil(length / max(12.0, caravan_step_distance))))
	var step_index: int = 0
	var timer: Timer = Timer.new()
	timer.wait_time = max(0.03, caravan_tick_interval)
	timer.one_shot = false
	host.add_child(timer)
	timer.timeout.connect(func() -> void:
		if not is_instance_valid(host):
			return
		if step_index > step_total:
			timer.stop()
			host.queue_free()
			_spawn_caravan_recall(finish, start, move_dir)
			return
		_emit_caravan_tick(start, finish, step_index, step_total, move_dir)
		step_index += 1
	)
	timer.start()

func _spawn_caravan_recall(from_pos: Vector2, to_pos: Vector2, move_dir: Vector2) -> void:
	var tree: SceneTree = get_tree()
	if tree == null:
		return
	tree.create_timer(max(0.05, caravan_recall_delay)).timeout.connect(func() -> void:
		if not is_inside_tree():
			return
		var host: Node2D = Node2D.new()
		host.name = "MerchantCaravanRecallHost"
		add_child(host)
		var pulse_total: int = int(max(1, caravan_recall_count))
		var pulse_index: int = 0
		var timer: Timer = Timer.new()
		timer.wait_time = max(0.06, perimeter_tax_interval * 0.8)
		timer.one_shot = false
		host.add_child(timer)
		timer.timeout.connect(func() -> void:
			if not is_instance_valid(host):
				return
			if pulse_index >= pulse_total:
				timer.stop()
				host.queue_free()
				return
			_emit_caravan_recall_tick(from_pos, to_pos, pulse_index, pulse_total, move_dir)
			pulse_index += 1
		)
		timer.start()
	)

func _emit_caravan_tick(start: Vector2, finish: Vector2, index: int, total: int, move_dir: Vector2) -> void:
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
		"color": Color(1.0, 0.9, 0.46, 0.92)
	})
	_apply_radius_damage(current, caravan_hit_radius, caravan_hit_damage)
	_apply_forward_push(current, caravan_hit_radius * 1.2, move_dir, caravan_push)

func _emit_caravan_recall_tick(
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
	var start: Vector2 = center - tangent * 62.0
	var end: Vector2 = center + tangent * 62.0
	SkillEffectManager.create_line_effect({
		"start": start,
		"end": end,
		"width": 12.0,
		"damage": 0,
		"damage_interval": 0.2,
		"duration": 0.16,
		"color": Color(1.0, 0.95, 0.62, 0.92)
	})
	_apply_line_burst_damage(start, end, 12.0, caravan_recall_damage)
	_apply_pull_to_point(center, caravan_hit_radius * 1.5, caravan_recall_pull)

func _deploy_beacon_if_needed(pos: Vector2) -> void:
	if _beacon_points.is_empty():
		_beacon_points.append(pos)
		_spawn_trade_beacon(pos)
		return
	var last_pos: Vector2 = _beacon_points[_beacon_points.size() - 1]
	if last_pos.distance_to(pos) < beacon_spacing:
		return
	_beacon_points.append(pos)
	_spawn_trade_beacon(pos)

func _spawn_trade_beacon(center: Vector2) -> void:
	var polygon: PackedVector2Array = _build_circle_polygon(center, beacon_radius, 14)
	SkillEffectManager.create_buff_zone({
		"polygon": polygon,
		"duration": beacon_duration,
		"buff_type": "speed_boost",
		"buff_value": discount_speed_boost * 0.75,
		"tick_interval": 0.45,
		"color": Color(1.0, 0.78, 0.22, 0.22)
	})
	SkillEffectManager.create_buff_zone({
		"polygon": polygon,
		"duration": beacon_duration,
		"buff_type": "cooldown_reduction",
		"buff_value": 0.14,
		"tick_interval": 0.45,
		"color": Color(1.0, 0.66, 0.2, 0.15)
	})
	SkillEffectManager.create_debuff_zone({
		"polygon": polygon,
		"duration": beacon_duration,
		"debuff_type": "damage_amp",
		"debuff_value": bounty_damage_amp,
		"debuff_duration": 1.0,
		"tick_interval": 0.35,
		"color": Color(1.0, 0.75, 0.25, 0.14)
	})

	var beacon: Node2D = Node2D.new()
	beacon.name = "MerchantTradeBeacon"
	beacon.global_position = center
	add_child(beacon)
	beacon.add_to_group("player_skill_effects")

	var elapsed: float = 0.0
	var coin_timer: float = 0.0
	var timer: Timer = Timer.new()
	timer.wait_time = max(0.08, beacon_attack_interval)
	timer.one_shot = false
	beacon.add_child(timer)
	timer.timeout.connect(func() -> void:
		if not is_instance_valid(beacon):
			return
		elapsed += timer.wait_time
		coin_timer += timer.wait_time
		if elapsed >= beacon_duration:
			timer.stop()
			beacon.queue_free()
			return
		var target: Node2D = _find_nearest_enemy(beacon.global_position, beacon_attack_range)
		if target == null:
			return
		SkillEffectManager.create_line_effect({
			"start": beacon.global_position,
			"end": target.global_position,
			"width": 8.0,
			"damage": 0,
			"damage_interval": 0.2,
			"duration": 0.16,
			"color": Color(1.0, 0.86, 0.38, 0.88)
		})
		_apply_damage(target, beacon_attack_damage)
		_apply_status(target, "marked", 1.2, bounty_damage_amp, 1, 0.3)
		if coin_timer >= 1.0:
			Global.spawn_coin(target.global_position, 1)
			coin_timer = 0.0
	)
	timer.start()

	spawn_skill_vfx(center, Color(1.0, 0.8, 0.28, 0.7), 0.32)

func _spawn_auction_pulses(polygon: PackedVector2Array) -> void:
	var center: Vector2 = _calculate_polygon_center(polygon)
	var radius: float = _calculate_market_radius(polygon, center)
	var pulse_total: int = int(max(1, auction_pulse_count))
	var pulse_index: int = 0
	var host: Node2D = Node2D.new()
	host.name = "MerchantAuctionPulses"
	add_child(host)

	_emit_auction_pulse(polygon, center, radius, pulse_index, pulse_total)
	pulse_index += 1

	var timer: Timer = Timer.new()
	timer.wait_time = max(0.08, auction_pulse_interval)
	timer.one_shot = false
	host.add_child(timer)
	timer.timeout.connect(func() -> void:
		if not is_instance_valid(host):
			return
		if pulse_index >= pulse_total:
			timer.stop()
			host.queue_free()
			return
		_emit_auction_pulse(polygon, center, radius, pulse_index, pulse_total)
		pulse_index += 1
	)
	timer.start()

func _emit_auction_pulse(polygon: PackedVector2Array, center: Vector2, radius: float, index: int, total: int) -> void:
	var target: Node2D = _find_best_target_in_polygon(polygon, center)
	if target == null:
		return
	var angle: float = TAU * float(index) / float(max(1, total))
	var origin: Vector2 = center + Vector2.RIGHT.rotated(angle) * (radius + 86.0)
	SkillEffectManager.create_line_effect({
		"start": origin,
		"end": target.global_position,
		"width": 10.0,
		"damage": 0,
		"damage_interval": 0.2,
		"duration": 0.18,
		"color": Color(1.0, 0.82, 0.28, 0.92)
	})
	var damage: int = auction_pulse_damage + int(round(float(index) * 0.8))
	_apply_damage(target, max(1, damage))
	_apply_status(target, "marked", 1.4, market_discount_amp, 1, 0.3)
	_apply_status(target, "fear", 0.5, 1.0, 1, 0.2)
	Global.spawn_coin(target.global_position, 1)

func _spawn_perimeter_tax_sweeps(polygon: PackedVector2Array) -> void:
	if polygon.size() < 3:
		return
	var sweep_total: int = int(max(1, perimeter_tax_count))
	var sweep_index: int = 0
	var host: Node2D = Node2D.new()
	host.name = "MerchantPerimeterTaxHost"
	add_child(host)

	_emit_perimeter_tax_sweep(polygon, sweep_index)
	sweep_index += 1

	var timer: Timer = Timer.new()
	timer.wait_time = float(max(0.08, perimeter_tax_interval))
	timer.one_shot = false
	host.add_child(timer)
	timer.timeout.connect(func() -> void:
		if not is_instance_valid(host):
			return
		if sweep_index >= sweep_total:
			timer.stop()
			host.queue_free()
			return
		_emit_perimeter_tax_sweep(polygon, sweep_index)
		sweep_index += 1
	)
	timer.start()

func _spawn_market_reflux(center: Vector2, radius: float) -> void:
	var sweep_total: int = int(max(1, market_reflux_count))
	var sweep_index: int = 0
	var host: Node2D = Node2D.new()
	host.name = "MerchantMarketRefluxHost"
	add_child(host)

	var timer: Timer = Timer.new()
	timer.wait_time = max(0.08, market_reflux_interval)
	timer.one_shot = false
	host.add_child(timer)
	timer.timeout.connect(func() -> void:
		if not is_instance_valid(host):
			return
		if sweep_index >= sweep_total:
			timer.stop()
			host.queue_free()
			return
		_emit_market_reflux(center, radius, sweep_index, sweep_total)
		sweep_index += 1
	)
	timer.start()

func _emit_market_reflux(center: Vector2, radius: float, index: int, total: int) -> void:
	var angle: float = TAU * float(index) / float(max(1, total))
	var dir: Vector2 = Vector2.RIGHT.rotated(angle)
	var start: Vector2 = center + dir * radius * 1.34
	var end: Vector2 = center - dir * radius * 0.08
	SkillEffectManager.create_line_effect({
		"start": start,
		"end": end,
		"width": perimeter_tax_width * 0.8,
		"damage": 0,
		"damage_interval": 0.2,
		"duration": 0.18,
		"color": Color(1.0, 0.98, 0.65, 0.92)
	})
	_apply_line_burst_damage(start, end, perimeter_tax_width * 0.45, market_reflux_damage)
	_apply_pull_to_point(center, radius * 0.95, caravan_recall_pull * 0.75)

func _emit_perimeter_tax_sweep(polygon: PackedVector2Array, index: int) -> void:
	var point_count: int = polygon.size()
	if point_count < 2:
		return
	var edge_index: int = index % point_count
	var start: Vector2 = polygon[edge_index]
	var end: Vector2 = polygon[(edge_index + 1) % point_count]
	SkillEffectManager.create_line_effect({
		"start": start,
		"end": end,
		"width": perimeter_tax_width,
		"damage": 0,
		"damage_interval": 0.2,
		"duration": 0.16,
		"color": Color(1.0, 0.92, 0.42, 0.88)
	})
	_apply_line_burst_damage(start, end, perimeter_tax_width * 0.5, perimeter_tax_damage)
	_apply_perimeter_tax_reward(start, end, perimeter_tax_width * 0.5)

func _apply_perimeter_tax_reward(start: Vector2, end: Vector2, hit_radius: float) -> void:
	var enemies: Array = get_tree().get_nodes_in_group("enemies")
	var coins_spawned: int = 0
	for enemy_obj: Variant in enemies:
		if enemy_obj == null or not is_instance_valid(enemy_obj):
			continue
		if not (enemy_obj is Node2D):
			continue
		var enemy: Node2D = enemy_obj
		var closest: Vector2 = Geometry2D.get_closest_point_to_segment(enemy.global_position, start, end)
		if enemy.global_position.distance_to(closest) > hit_radius:
			continue
		_apply_status(enemy, "marked", 1.0, market_discount_amp * 0.72, 1, 0.3)
		if coins_spawned >= 2:
			continue
		if randf() < perimeter_tax_coin_chance:
			Global.spawn_coin(enemy.global_position, 1)
			coins_spawned += 1

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
		_apply_status(enemy, "marked", 1.0, bounty_damage_amp, 1, 0.3)

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
		_apply_status(enemy, "marked", 1.0, bounty_damage_amp * 0.8, 1, 0.3)

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
		var score: float = (1.0 - hp_ratio) * 1.6 + (1.0 / max(1.0, dist * 0.01))
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

func _spawn_market_coin_burst(polygon: PackedVector2Array, coin_count: int) -> void:
	if coin_count <= 0 or polygon.size() < 3:
		return
	var center: Vector2 = _calculate_polygon_center(polygon)
	for i: int in range(coin_count):
		var angle: float = TAU * float(i) / float(max(coin_count, 1))
		var pos: Vector2 = center + Vector2.RIGHT.rotated(angle) * 40.0
		Global.spawn_coin(pos, 1)
	Global.spawn_floating_text(center, "MARKET!", Color(1.0, 0.8, 0.2))

func _cache_market_window(polygon: PackedVector2Array, duration: float) -> void:
	if not is_instance_valid(skill_owner):
		return
	var center: Vector2 = _calculate_polygon_center(polygon)
	var radius: float = _calculate_market_radius(polygon, center)
	var expire_msec: int = Time.get_ticks_msec() + int(round(max(0.2, duration) * 1000.0))
	skill_owner.set_meta(MARKET_META_CENTER, center)
	skill_owner.set_meta(MARKET_META_RADIUS, radius)
	skill_owner.set_meta(MARKET_META_EXPIRE_MSEC, expire_msec)

func _calculate_market_radius(polygon: PackedVector2Array, center: Vector2) -> float:
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
	return Color(1.0, 0.8, 0.2, 1.0)

func _get_closure_color() -> Color:
	return Color(1.0, 0.7, 0.1, 1.0)

