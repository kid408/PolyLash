extends SkillQBase
class_name SkillBlacksmithQ

var rail_contact_damage: int = 18
var rail_contact_interval: float = 0.35
var rail_width: float = 20.0
var forge_attack_boost: float = 0.45
var forge_lifesteal: float = 0.18
var buff_duration: float = 5.5
var forge_heat_gain: float = 1.0
var forge_quench_slow: float = 0.24
var forge_node_spacing: float = 170.0
var forge_node_radius: float = 88.0
var forge_node_duration: float = 4.4
var forge_pulse_count: int = 4
var forge_pulse_interval: float = 0.24
var forge_pulse_damage: int = 14
var anvil_rain_count: int = 7
var anvil_rain_interval: float = 0.2
var anvil_rain_damage: int = 26
var anvil_rain_radius: float = 72.0
var hammer_step_distance: float = 52.0
var hammer_tick_interval: float = 0.05
var hammer_hit_radius: float = 56.0
var hammer_line_damage: int = 18
var hammer_push: float = 22.0
var hammer_recall_delay: float = 0.2
var hammer_recall_count: int = 5
var hammer_recall_damage: int = 22
var hammer_recall_pull: float = 24.0
var quench_reel_count: int = 5
var quench_reel_interval: float = 0.16
var quench_reel_damage: int = 24

const FORGE_HEAT_META: String = "blacksmith_forge_heat"
const FORGE_WINDOW_META: String = "blacksmith_forge_window_msec"

var _line_nodes: Array[Vector2] = []

func _enter_planning_mode() -> void:
	_line_nodes.clear()
	super._enter_planning_mode()

func _spawn_line_effect(start: Vector2, end: Vector2) -> void:
	var duration: float = _get_line_duration()
	SkillEffectManager.create_wall_effect({
		"start": start,
		"end": end,
		"width": rail_width,
		"duration": duration,
		"block_enemies": true,
		"block_bullets": false,
		"contact_damage": rail_contact_damage,
		"contact_interval": rail_contact_interval,
		"color": Color(0.95, 0.48, 0.08, 0.75)
	})

	SkillEffectManager.create_debuff_zone({
		"start": start,
		"end": end,
		"width": rail_width + 4.0,
		"duration": duration,
		"debuff_type": "slow",
		"debuff_value": forge_quench_slow,
		"debuff_duration": 1.0,
		"tick_interval": 0.4,
		"color": Color(0.96, 0.56, 0.18, 0.2)
	})

	_launch_forge_hammer(start, end)
	_spawn_forge_pulse_track(start, end)
	_deploy_forge_node_if_needed(start)
	_deploy_forge_node_if_needed(end)
	_add_forge_heat(forge_heat_gain * 0.6, duration)

func _spawn_area_effect(polygon: PackedVector2Array) -> void:
	if polygon.size() < 3:
		return
	SkillEffectManager.create_buff_zone({
		"polygon": polygon,
		"duration": buff_duration,
		"buff_type": "attack_boost",
		"buff_value": forge_attack_boost,
		"tick_interval": 0.5,
		"color": Color(1.0, 0.45, 0.08, 0.45)
	})

	SkillEffectManager.create_buff_zone({
		"polygon": polygon,
		"duration": buff_duration,
		"buff_type": "lifesteal",
		"buff_value": forge_lifesteal,
		"tick_interval": 0.5,
		"color": Color(1.0, 0.65, 0.18, 0.25)
	})

	SkillEffectManager.create_debuff_zone({
		"polygon": polygon,
		"duration": buff_duration,
		"debuff_type": "damage_amp",
		"debuff_value": 0.16,
		"debuff_duration": 1.2,
		"tick_interval": 0.5,
		"color": Color(0.95, 0.55, 0.2, 0.15)
	})

	_apply_anvil_burst(polygon)
	_spawn_anvil_rain(polygon)
	_spawn_quench_reel(polygon)
	_add_forge_heat(forge_heat_gain, buff_duration)

func _launch_forge_hammer(start: Vector2, finish: Vector2) -> void:
	var seg: Vector2 = finish - start
	var length: float = seg.length()
	if length <= 1.0:
		return
	var move_dir: Vector2 = seg / length
	var host: Node2D = Node2D.new()
	host.name = "BlacksmithForgeHammerHost"
	add_child(host)

	var step_total: int = int(max(2.0, ceil(length / max(12.0, hammer_step_distance))))
	var step_index: int = 0
	var timer: Timer = Timer.new()
	timer.wait_time = max(0.03, hammer_tick_interval)
	timer.one_shot = false
	host.add_child(timer)
	timer.timeout.connect(func() -> void:
		if not is_instance_valid(host):
			return
		if step_index > step_total:
			timer.stop()
			host.queue_free()
			_spawn_hammer_recall(finish, start, move_dir)
			return
		_emit_hammer_tick(start, finish, step_index, step_total, move_dir)
		step_index += 1
	)
	timer.start()

func _spawn_hammer_recall(from_pos: Vector2, to_pos: Vector2, move_dir: Vector2) -> void:
	var tree: SceneTree = get_tree()
	if tree == null:
		return
	tree.create_timer(max(0.05, hammer_recall_delay)).timeout.connect(func() -> void:
		if not is_inside_tree():
			return
		var host: Node2D = Node2D.new()
		host.name = "BlacksmithHammerRecallHost"
		add_child(host)
		var pulse_total: int = int(max(1, hammer_recall_count))
		var pulse_index: int = 0
		var timer: Timer = Timer.new()
		timer.wait_time = max(0.06, hammer_tick_interval * 1.6)
		timer.one_shot = false
		host.add_child(timer)
		timer.timeout.connect(func() -> void:
			if not is_instance_valid(host):
				return
			if pulse_index >= pulse_total:
				timer.stop()
				host.queue_free()
				return
			_emit_hammer_recall_tick(from_pos, to_pos, pulse_index, pulse_total, move_dir)
			pulse_index += 1
		)
		timer.start()
	)

func _emit_hammer_tick(start: Vector2, finish: Vector2, index: int, total: int, move_dir: Vector2) -> void:
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
		"color": Color(1.0, 0.72, 0.32, 0.9)
	})
	_apply_radius_heat_damage(current, hammer_hit_radius, hammer_line_damage)
	_apply_direction_push(current, hammer_hit_radius * 1.2, move_dir, hammer_push)

func _emit_hammer_recall_tick(
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
	var start: Vector2 = center - tangent * 76.0
	var end: Vector2 = center + tangent * 76.0
	SkillEffectManager.create_line_effect({
		"start": start,
		"end": end,
		"width": 13.0,
		"damage": 0,
		"damage_interval": 0.2,
		"duration": 0.16,
		"color": Color(1.0, 0.82, 0.46, 0.92)
	})
	_apply_line_burst_damage(start, end, 12.0, hammer_recall_damage)
	_apply_pull_to_point(center, hammer_hit_radius * 1.55, hammer_recall_pull)

func _spawn_quench_reel(polygon: PackedVector2Array) -> void:
	var center: Vector2 = _polygon_center(polygon)
	var radius: float = _polygon_radius(polygon, center)
	var sweep_total: int = int(max(1, quench_reel_count))
	var sweep_index: int = 0
	var host: Node2D = Node2D.new()
	host.name = "BlacksmithQuenchReelHost"
	add_child(host)

	var timer: Timer = Timer.new()
	timer.wait_time = max(0.08, quench_reel_interval)
	timer.one_shot = false
	host.add_child(timer)
	timer.timeout.connect(func() -> void:
		if not is_instance_valid(host):
			return
		if sweep_index >= sweep_total:
			timer.stop()
			host.queue_free()
			return
		_emit_quench_reel(center, radius, sweep_index, sweep_total)
		sweep_index += 1
	)
	timer.start()

func _emit_quench_reel(center: Vector2, radius: float, index: int, total: int) -> void:
	var angle: float = TAU * float(index) / float(max(1, total))
	var dir: Vector2 = Vector2.RIGHT.rotated(angle)
	var start: Vector2 = center + dir * radius * 1.3
	var end: Vector2 = center - dir * radius * 0.05
	SkillEffectManager.create_line_effect({
		"start": start,
		"end": end,
		"width": 14.0,
		"damage": 0,
		"damage_interval": 0.2,
		"duration": 0.2,
		"color": Color(1.0, 0.78, 0.4, 0.9)
	})
	_apply_line_burst_damage(start, end, 12.0, quench_reel_damage)
	_apply_pull_to_point(center, radius * 1.02, hammer_recall_pull * 0.55)

func _spawn_forge_pulse_track(start: Vector2, end: Vector2) -> void:
	var host: Node2D = Node2D.new()
	host.name = "BlacksmithPulseTrack"
	add_child(host)
	var pulse_index: int = 0
	var pulse_total: int = int(max(1, forge_pulse_count))

	_emit_forge_track_pulse(start, end, pulse_index, pulse_total)
	pulse_index += 1

	var timer: Timer = Timer.new()
	timer.wait_time = max(0.08, forge_pulse_interval)
	timer.one_shot = false
	host.add_child(timer)
	timer.timeout.connect(func() -> void:
		if not is_instance_valid(host):
			return
		if pulse_index >= pulse_total:
			timer.stop()
			host.queue_free()
			return
		_emit_forge_track_pulse(start, end, pulse_index, pulse_total)
		pulse_index += 1
	)
	timer.start()

func _emit_forge_track_pulse(start: Vector2, end: Vector2, index: int, total: int) -> void:
	var t: float = 0.0
	if total > 1:
		t = float(index) / float(total - 1)
	var pulse_pos: Vector2 = start.lerp(end, float(clamp(t, 0.0, 1.0)))
	var pulse_poly: PackedVector2Array = _build_circle_polygon(pulse_pos, forge_node_radius * 0.5, 12)
	SkillEffectManager.create_area_effect({
		"polygon": pulse_poly,
		"damage": forge_pulse_damage,
		"damage_interval": 0.1,
		"duration": 0.2,
		"color": Color(1.0, 0.65, 0.26, 0.36)
	})
	SkillEffectManager.create_debuff_zone({
		"polygon": pulse_poly,
		"duration": 0.28,
		"debuff_type": "slow",
		"debuff_value": forge_quench_slow + 0.08,
		"debuff_duration": 0.8,
		"tick_interval": 0.2,
		"color": Color(1.0, 0.56, 0.2, 0.18)
	})
	spawn_skill_vfx(pulse_pos, Color(1.0, 0.65, 0.3, 0.75), 0.3)

func _deploy_forge_node_if_needed(pos: Vector2) -> void:
	if _line_nodes.is_empty():
		_line_nodes.append(pos)
		_spawn_forge_node(pos)
		return
	var last_pos: Vector2 = _line_nodes[_line_nodes.size() - 1]
	if last_pos.distance_to(pos) < forge_node_spacing:
		return
	_line_nodes.append(pos)
	_spawn_forge_node(pos)

func _spawn_forge_node(center: Vector2) -> void:
	var polygon: PackedVector2Array = _build_circle_polygon(center, forge_node_radius, 14)
	SkillEffectManager.create_buff_zone({
		"polygon": polygon,
		"duration": forge_node_duration,
		"buff_type": "attack_boost",
		"buff_value": forge_attack_boost * 0.7,
		"tick_interval": 0.45,
		"color": Color(1.0, 0.58, 0.2, 0.24)
	})
	SkillEffectManager.create_buff_zone({
		"polygon": polygon,
		"duration": forge_node_duration,
		"buff_type": "lifesteal",
		"buff_value": forge_lifesteal * 0.75,
		"tick_interval": 0.45,
		"color": Color(1.0, 0.7, 0.28, 0.14)
	})
	SkillEffectManager.create_debuff_zone({
		"polygon": polygon,
		"duration": forge_node_duration,
		"debuff_type": "slow",
		"debuff_value": forge_quench_slow + 0.08,
		"debuff_duration": 0.9,
		"tick_interval": 0.35,
		"color": Color(1.0, 0.55, 0.2, 0.16)
	})
	spawn_skill_vfx(center, Color(1.0, 0.62, 0.28, 0.72), 0.38)

func _apply_anvil_burst(polygon: PackedVector2Array) -> void:
	var center: Vector2 = _polygon_center(polygon)
	var radius: float = _polygon_radius(polygon, center)
	var damage: int = int(max(1, int(round(float(rail_contact_damage) * 2.2))))
	var hit_count: int = 0
	for enemy_obj: Variant in get_tree().get_nodes_in_group("enemies"):
		if enemy_obj == null or not is_instance_valid(enemy_obj):
			continue
		if not (enemy_obj is Node2D):
			continue
		var enemy: Node2D = enemy_obj
		if enemy.global_position.distance_to(center) > radius:
			continue
		_apply_damage(enemy, damage)
		_apply_status(enemy, "slow", 0.9, 0.28, 1, 0.1)
		hit_count += 1
	if hit_count > 0:
		Global.spawn_floating_text(center, "ANVIL x%d" % hit_count, Color(1.0, 0.6, 0.25))
		spawn_skill_vfx(center, Color(1.0, 0.55, 0.2, 0.82), 0.62)

func _spawn_anvil_rain(polygon: PackedVector2Array) -> void:
	var bounds: Rect2 = _polygon_bounds(polygon)
	if bounds.size.x <= 1.0 or bounds.size.y <= 1.0:
		return

	var host: Node2D = Node2D.new()
	host.name = "BlacksmithAnvilRain"
	add_child(host)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.randomize()
	var strike_total: int = int(max(1, anvil_rain_count))
	var strike_index: int = 0

	_emit_anvil_rain_hit(polygon, bounds, rng)
	strike_index += 1

	var timer: Timer = Timer.new()
	timer.wait_time = max(0.08, anvil_rain_interval)
	timer.one_shot = false
	host.add_child(timer)
	timer.timeout.connect(func() -> void:
		if not is_instance_valid(host):
			return
		if strike_index >= strike_total:
			timer.stop()
			host.queue_free()
			return
		_emit_anvil_rain_hit(polygon, bounds, rng)
		strike_index += 1
	)
	timer.start()

func _emit_anvil_rain_hit(polygon: PackedVector2Array, bounds: Rect2, rng: RandomNumberGenerator) -> void:
	var hit_pos: Vector2 = _random_point_in_polygon(polygon, bounds, rng)
	var blast_poly: PackedVector2Array = _build_circle_polygon(hit_pos, anvil_rain_radius, 14)
	SkillEffectManager.create_area_effect({
		"polygon": blast_poly,
		"damage": anvil_rain_damage,
		"damage_interval": 0.1,
		"duration": 0.24,
		"color": Color(1.0, 0.6, 0.24, 0.46)
	})
	SkillEffectManager.create_debuff_zone({
		"polygon": blast_poly,
		"duration": 0.3,
		"debuff_type": "slow",
		"debuff_value": forge_quench_slow + 0.12,
		"debuff_duration": 0.8,
		"tick_interval": 0.2,
		"color": Color(1.0, 0.54, 0.2, 0.22)
	})
	spawn_skill_vfx(hit_pos, Color(1.0, 0.65, 0.3, 0.82), 0.46)

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
		_apply_status(enemy, "slow", 0.9, forge_quench_slow + 0.06, 1, 0.1)

func _apply_radius_heat_damage(center: Vector2, radius: float, damage: int) -> void:
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
		_apply_status(enemy, "slow", 0.9, forge_quench_slow + 0.08, 1, 0.1)

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

func _polygon_bounds(polygon: PackedVector2Array) -> Rect2:
	if polygon.is_empty():
		return Rect2(Vector2.ZERO, Vector2.ZERO)
	var min_x: float = polygon[0].x
	var min_y: float = polygon[0].y
	var max_x: float = polygon[0].x
	var max_y: float = polygon[0].y
	for p: Vector2 in polygon:
		min_x = min(min_x, p.x)
		min_y = min(min_y, p.y)
		max_x = max(max_x, p.x)
		max_y = max(max_y, p.y)
	return Rect2(Vector2(min_x, min_y), Vector2(max_x - min_x, max_y - min_y))

func _random_point_in_polygon(polygon: PackedVector2Array, bounds: Rect2, rng: RandomNumberGenerator) -> Vector2:
	for _i: int in range(24):
		var x: float = rng.randf_range(bounds.position.x, bounds.position.x + bounds.size.x)
		var y: float = rng.randf_range(bounds.position.y, bounds.position.y + bounds.size.y)
		var candidate: Vector2 = Vector2(x, y)
		if Geometry2D.is_point_in_polygon(candidate, polygon):
			return candidate
	return _polygon_center(polygon)

func _add_forge_heat(amount: float, window_duration: float) -> void:
	if not is_instance_valid(skill_owner):
		return
	var old_heat: float = float(skill_owner.get_meta(FORGE_HEAT_META, 0.0))
	var next_heat: float = float(clamp(old_heat + amount, 0.0, 6.0))
	skill_owner.set_meta(FORGE_HEAT_META, next_heat)
	var expire_msec: int = Time.get_ticks_msec() + int(round(max(0.2, window_duration) * 1000.0))
	skill_owner.set_meta(FORGE_WINDOW_META, expire_msec)

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
	return max(8.0, radius)

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
	return Color(0.9, 0.5, 0.1, 1.0)

func _get_closure_color() -> Color:
	return Color(1.0, 0.4, 0.0, 1.0)

