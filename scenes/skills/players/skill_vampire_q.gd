extends SkillDrawingBase
class_name SkillVampireQ

var hp_cost_percent: float = 0.08
var blood_damage: int = 34
var blood_mark_amp: float = 0.25

var tether_spacing: float = 165.0
var tether_duration: float = 4.8
var tether_interval: float = 0.32
var tether_radius: float = 220.0
var tether_tick_damage: int = 12
var tether_heal: int = 2

var blood_pool_duration: float = 5.4
var lifesteal_value: float = 1.0
var blood_heal_value: int = 4
var sacrifice_pulse_count: int = 6
var sacrifice_interval: float = 0.24
var sacrifice_damage: int = 24
var execute_threshold: float = 0.3
var blood_spear_step_distance: float = 50.0
var blood_spear_tick_interval: float = 0.05
var blood_spear_hit_radius: float = 54.0
var blood_spear_damage: int = 18
var blood_spear_push: float = 18.0
var blood_recall_delay: float = 0.2
var blood_recall_count: int = 5
var blood_recall_damage: int = 22
var blood_recall_pull: float = 26.0
var blood_reel_count: int = 5
var blood_reel_interval: float = 0.16
var blood_reel_damage: int = 24

const BLOOD_META_CENTER: String = "vampire_blood_pool_center"
const BLOOD_META_RADIUS: String = "vampire_blood_pool_radius"
const BLOOD_META_EXPIRE_MSEC: String = "vampire_blood_pool_expire_msec"

var _tether_points: Array[Vector2] = []

func _enter_planning_mode() -> void:
	_tether_points.clear()
	super._enter_planning_mode()

func _spawn_line_effect(start: Vector2, end: Vector2) -> void:
	_pay_blood_cost()

	SkillEffectManager.create_line_effect({
		"start": start,
		"end": end,
		"width": 26.0,
		"damage": blood_damage,
		"damage_interval": 0.45,
		"duration": _get_line_duration(),
		"color": Color(0.7, 0.1, 0.1, 0.72)
	})

	SkillEffectManager.create_debuff_zone({
		"start": start,
		"end": end,
		"width": 20.0,
		"duration": _get_line_duration(),
		"debuff_type": "damage_amp",
		"debuff_value": blood_mark_amp,
		"debuff_duration": 2.0,
		"tick_interval": 0.5,
		"color": Color(0.62, 0.08, 0.08, 0.24)
	})

	_launch_blood_spear(start, end)
	_spawn_tethers_along_segment(start, end)

func _spawn_area_effect(polygon: PackedVector2Array) -> void:
	if polygon.size() < 3:
		return

	SkillEffectManager.create_buff_zone({
		"polygon": polygon,
		"duration": blood_pool_duration,
		"buff_type": "lifesteal",
		"buff_value": lifesteal_value,
		"tick_interval": 0.45,
		"color": Color(0.5, 0.0, 0.0, 0.5)
	})

	SkillEffectManager.create_buff_zone({
		"polygon": polygon,
		"duration": blood_pool_duration,
		"buff_type": "heal",
		"buff_value": float(blood_heal_value),
		"tick_interval": 0.55,
		"color": Color(0.62, 0.08, 0.08, 0.28)
	})

	SkillEffectManager.create_debuff_zone({
		"polygon": polygon,
		"duration": blood_pool_duration,
		"debuff_type": "damage_amp",
		"debuff_value": blood_mark_amp,
		"debuff_duration": 1.6,
		"tick_interval": 0.5,
		"color": Color(0.56, 0.08, 0.08, 0.18)
	})

	_spawn_sacrifice_pulses(polygon)
	_spawn_blood_reel(polygon)
	_cache_blood_window(polygon, blood_pool_duration)

func _launch_blood_spear(start: Vector2, finish: Vector2) -> void:
	var seg: Vector2 = finish - start
	var length: float = seg.length()
	if length <= 1.0:
		return
	var move_dir: Vector2 = seg / length
	var host: Node2D = Node2D.new()
	host.name = "VampireBloodSpearHost"
	add_child(host)

	var step_total: int = int(max(2.0, ceil(length / max(12.0, blood_spear_step_distance))))
	var step_index: int = 0
	var timer: Timer = Timer.new()
	timer.wait_time = max(0.03, blood_spear_tick_interval)
	timer.one_shot = false
	host.add_child(timer)
	timer.timeout.connect(func() -> void:
		if not is_instance_valid(host):
			return
		if step_index > step_total:
			timer.stop()
			host.queue_free()
			_spawn_blood_spear_recall(finish, start, move_dir)
			return
		_emit_blood_spear_tick(start, finish, step_index, step_total, move_dir)
		step_index += 1
	)
	timer.start()

func _spawn_blood_spear_recall(from_pos: Vector2, to_pos: Vector2, move_dir: Vector2) -> void:
	var tree: SceneTree = get_tree()
	if tree == null:
		return
	tree.create_timer(max(0.05, blood_recall_delay)).timeout.connect(func() -> void:
		if not is_inside_tree():
			return
		var host: Node2D = Node2D.new()
		host.name = "VampireBloodSpearRecallHost"
		add_child(host)
		var pulse_total: int = int(max(1, blood_recall_count))
		var pulse_index: int = 0
		var timer: Timer = Timer.new()
		timer.wait_time = max(0.06, blood_spear_tick_interval * 1.6)
		timer.one_shot = false
		host.add_child(timer)
		timer.timeout.connect(func() -> void:
			if not is_instance_valid(host):
				return
			if pulse_index >= pulse_total:
				timer.stop()
				host.queue_free()
				return
			_emit_blood_recall_tick(from_pos, to_pos, pulse_index, pulse_total, move_dir)
			pulse_index += 1
		)
		timer.start()
	)

func _emit_blood_spear_tick(start: Vector2, finish: Vector2, index: int, total: int, move_dir: Vector2) -> void:
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
		"color": Color(0.92, 0.28, 0.28, 0.92)
	})
	_apply_radius_blood_mark(current, blood_spear_hit_radius, blood_spear_damage)
	_apply_direction_push(current, blood_spear_hit_radius * 1.2, move_dir, blood_spear_push)
	_heal_owner(1)

func _emit_blood_recall_tick(
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
		"color": Color(1.0, 0.42, 0.42, 0.92)
	})
	_apply_line_burst_damage(start, end, 12.0, blood_recall_damage)
	_apply_pull_to_point(center, blood_spear_hit_radius * 1.6, blood_recall_pull)
	_heal_owner(2)

func _spawn_blood_reel(polygon: PackedVector2Array) -> void:
	var center: Vector2 = _polygon_center(polygon)
	var radius: float = _polygon_radius(polygon, center)
	var sweep_total: int = int(max(1, blood_reel_count))
	var sweep_index: int = 0
	var host: Node2D = Node2D.new()
	host.name = "VampireBloodReelHost"
	add_child(host)

	var timer: Timer = Timer.new()
	timer.wait_time = max(0.08, blood_reel_interval)
	timer.one_shot = false
	host.add_child(timer)
	timer.timeout.connect(func() -> void:
		if not is_instance_valid(host):
			return
		if sweep_index >= sweep_total:
			timer.stop()
			host.queue_free()
			return
		_emit_blood_reel(center, radius, sweep_index, sweep_total)
		sweep_index += 1
	)
	timer.start()

func _emit_blood_reel(center: Vector2, radius: float, index: int, total: int) -> void:
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
		"color": Color(0.96, 0.34, 0.34, 0.9)
	})
	_apply_line_burst_damage(start, end, 12.0, blood_reel_damage)
	_apply_pull_to_point(center, radius * 1.02, blood_recall_pull * 0.55)
	_heal_owner(1)

func _spawn_tethers_along_segment(start: Vector2, end: Vector2) -> void:
	var seg: Vector2 = end - start
	var length: float = seg.length()
	if length <= 1.0:
		_deploy_tether_if_needed(start)
		return
	var dir: Vector2 = seg / length
	var spacing: float = float(max(60.0, tether_spacing))
	var cursor: float = 0.0
	while cursor <= length:
		_deploy_tether_if_needed(start + dir * cursor)
		cursor += spacing
	if fmod(length, spacing) > 20.0:
		_deploy_tether_if_needed(end)

func _deploy_tether_if_needed(pos: Vector2) -> void:
	if _tether_points.is_empty():
		_tether_points.append(pos)
		_spawn_blood_tether(pos)
		return
	var last_pos: Vector2 = _tether_points[_tether_points.size() - 1]
	if last_pos.distance_to(pos) < tether_spacing:
		return
	_tether_points.append(pos)
	_spawn_blood_tether(pos)

func _spawn_blood_tether(pos: Vector2) -> void:
	var tether: Node2D = Node2D.new()
	tether.name = "VampireBloodTether"
	tether.global_position = pos
	add_child(tether)
	tether.add_to_group("player_skill_effects")

	var elapsed: float = 0.0
	var timer: Timer = Timer.new()
	timer.wait_time = float(max(0.08, tether_interval))
	timer.one_shot = false
	tether.add_child(timer)
	timer.timeout.connect(func() -> void:
		if not is_instance_valid(tether):
			return
		elapsed += timer.wait_time
		if elapsed >= tether_duration:
			timer.stop()
			tether.queue_free()
			return
		_emit_tether_tick(tether.global_position)
	)
	timer.start()

	spawn_skill_vfx(pos, Color(0.76, 0.16, 0.16, 0.74), 0.28)

func _emit_tether_tick(center: Vector2) -> void:
	var target: Node2D = _find_nearest_enemy(center, tether_radius)
	if target == null:
		return
	SkillEffectManager.create_line_effect({
		"start": center,
		"end": target.global_position,
		"width": 8.0,
		"damage": 0,
		"damage_interval": 0.2,
		"duration": 0.16,
		"color": Color(0.84, 0.22, 0.22, 0.9)
	})
	_apply_damage(target, tether_tick_damage)
	_apply_status(target, "marked", 1.1, blood_mark_amp, 1, 0.3)
	_heal_owner(tether_heal)

func _spawn_sacrifice_pulses(polygon: PackedVector2Array) -> void:
	var center: Vector2 = _polygon_center(polygon)
	var radius: float = _polygon_radius(polygon, center)
	var pulse_total: int = int(max(1, sacrifice_pulse_count))
	var pulse_index: int = 0
	var host: Node2D = Node2D.new()
	host.name = "VampireSacrificeHost"
	add_child(host)

	_emit_sacrifice_pulse(polygon, center, radius, pulse_index)
	pulse_index += 1

	var timer: Timer = Timer.new()
	timer.wait_time = float(max(0.08, sacrifice_interval))
	timer.one_shot = false
	host.add_child(timer)
	timer.timeout.connect(func() -> void:
		if not is_instance_valid(host):
			return
		if pulse_index >= pulse_total:
			timer.stop()
			host.queue_free()
			return
		_emit_sacrifice_pulse(polygon, center, radius, pulse_index)
		pulse_index += 1
	)
	timer.start()

func _emit_sacrifice_pulse(polygon: PackedVector2Array, center: Vector2, radius: float, index: int) -> void:
	var target: Node2D = _find_best_target_in_polygon(polygon, center)
	if target == null:
		return
	var angle: float = TAU * float(index) / float(max(1, sacrifice_pulse_count))
	var origin: Vector2 = center + Vector2.RIGHT.rotated(angle) * (radius + 68.0)
	SkillEffectManager.create_line_effect({
		"start": origin,
		"end": target.global_position,
		"width": 10.0,
		"damage": 0,
		"damage_interval": 0.2,
		"duration": 0.2,
		"color": Color(0.9, 0.24, 0.24, 0.92)
	})

	var damage: int = sacrifice_damage
	var hp_ratio: float = _get_enemy_hp_ratio(target)
	if hp_ratio <= execute_threshold:
		damage = max(damage, int(round(float(sacrifice_damage) * 1.9)))
		_heal_owner(6)
		Global.spawn_floating_text(target.global_position, "SACRIFICE", Color(0.95, 0.3, 0.3))
	else:
		_heal_owner(2)
	_apply_damage(target, damage)
	_apply_status(target, "marked", 1.3, blood_mark_amp + 0.08, 1, 0.3)

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
		_apply_status(enemy, "marked", 1.1, blood_mark_amp, 1, 0.3)

func _apply_radius_blood_mark(center: Vector2, radius: float, damage: int) -> void:
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
		_apply_status(enemy, "marked", 1.0, blood_mark_amp * 0.7, 1, 0.3)

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

func _pay_blood_cost() -> void:
	if not is_instance_valid(skill_owner):
		return
	var hc: Node = skill_owner.get_node_or_null("HealthComponent")
	if hc == null:
		return
	var max_health: int = int(hc.get("max_health"))
	var current_health: int = int(hc.get("current_health"))
	var cost: int = int(round(float(max_health) * hp_cost_percent))
	if current_health <= 1:
		return
	var actual_cost: int = int(min(cost, current_health - 1))
	if actual_cost <= 0:
		return
	if hc.has_method("take_damage"):
		hc.call("take_damage", actual_cost)
	Global.spawn_floating_text(skill_owner.global_position, "-%d HP" % actual_cost, Color(0.7, 0.1, 0.1))

func _heal_owner(amount: int) -> void:
	if amount <= 0:
		return
	if not is_instance_valid(skill_owner):
		return
	var hc: Node = skill_owner.get_node_or_null("HealthComponent")
	if hc == null:
		return
	if hc.has_method("heal"):
		hc.call("heal", amount)
		return
	var max_health: int = int(hc.get("max_health"))
	var current_health: int = int(hc.get("current_health"))
	var new_health: int = int(min(max_health, current_health + amount))
	hc.set("current_health", new_health)

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

func _cache_blood_window(polygon: PackedVector2Array, duration: float) -> void:
	if not is_instance_valid(skill_owner):
		return
	var center: Vector2 = _polygon_center(polygon)
	var radius: float = _polygon_radius(polygon, center)
	var expire_msec: int = Time.get_ticks_msec() + int(round(float(max(0.2, duration)) * 1000.0))
	skill_owner.set_meta(BLOOD_META_CENTER, center)
	skill_owner.set_meta(BLOOD_META_RADIUS, radius)
	skill_owner.set_meta(BLOOD_META_EXPIRE_MSEC, expire_msec)

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
	return Color(0.7, 0.1, 0.1, 1.0)

func _get_closure_color() -> Color:
	return Color(0.5, 0.0, 0.0, 1.0)
