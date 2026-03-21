extends SkillQBase
class_name SkillMedicQ

const TEMP_ARMOR_META: String = "temp_armor_stacks"
const DASH_LIGHT_SHIELD_SEC: float = 0.60

var heal_value: int = 5
var slow_value: float = 0.4
var invincible_duration: float = 2.2
var triage_speed_boost: float = 0.18
var field_lifesteal: float = 0.12
var field_heal_multiplier: float = 1.6
var triage_node_spacing: float = 165.0
var triage_node_radius: float = 96.0
var triage_node_duration: float = 3.2
var triage_pulse_interval: float = 0.24
var triage_pulse_count: int = 5
var triage_pulse_damage: int = 12
var closure_wave_count: int = 3
var closure_wave_interval: float = 0.34
var triage_dart_step_distance: float = 50.0
var triage_dart_tick_interval: float = 0.05
var triage_dart_hit_radius: float = 54.0
var triage_dart_damage: int = 14
var triage_dart_push: float = 16.0
var triage_recall_delay: float = 0.2
var triage_recall_count: int = 5
var triage_recall_damage: int = 18
var triage_recall_pull: float = 20.0
var closure_reel_count: int = 5
var closure_reel_interval: float = 0.16
var closure_reel_damage: int = 18

var _triage_nodes: Array[Vector2] = []
var _station_windows: Array[Dictionary] = []
var _dash_started_in_station: bool = false

func _init() -> void:
	base_line_duration = 3.2
	q_asset_duration_open = 3.2
	q_asset_duration_closed = 2.2

func _ready() -> void:
	super._ready()
	_connect_dash_signals()

func _exit_tree() -> void:
	_disconnect_dash_signals()
	super._exit_tree()

func _enter_planning_mode() -> void:
	_triage_nodes.clear()
	super._enter_planning_mode()

func _spawn_line_effect(start: Vector2, end: Vector2) -> void:
	SkillEffectManager.create_buff_zone({
		"start": start,
		"end": end,
		"width": 26.0,
		"duration": _get_line_duration(),
		"buff_type": "heal",
		"buff_value": float(heal_value),
		"tick_interval": 0.35,
		"color": Color(0.35, 1.0, 0.58, 0.45)
	})

	SkillEffectManager.create_buff_zone({
		"start": start,
		"end": end,
		"width": 20.0,
		"duration": _get_line_duration(),
		"buff_type": "speed_boost",
		"buff_value": triage_speed_boost,
		"tick_interval": 0.5,
		"color": Color(0.6, 1.0, 0.8, 0.25)
	})

	SkillEffectManager.create_debuff_zone({
		"start": start,
		"end": end,
		"width": 24.0,
		"duration": _get_line_duration(),
		"debuff_type": "slow",
		"debuff_value": slow_value,
		"debuff_duration": 2.4,
		"tick_interval": 0.45,
		"color": Color(0.4, 0.85, 0.6, 0.25)
	})

	_launch_triage_dart(start, end)
	_deploy_triage_node_if_needed(start)
	_deploy_triage_node_if_needed(end)

func _spawn_area_effect(polygon: PackedVector2Array) -> void:
	if polygon.size() < 3:
		return
	var field_duration: float = float(max(0.2, invincible_duration))
	var field_heal: int = int(max(1, int(round(float(heal_value) * field_heal_multiplier))))

	SkillEffectManager.create_buff_zone({
		"polygon": polygon,
		"duration": field_duration,
		"buff_type": "heal",
		"buff_value": float(field_heal),
		"tick_interval": 0.35,
		"color": Color(0.35, 1.0, 0.55, 0.42)
	})

	SkillEffectManager.create_buff_zone({
		"polygon": polygon,
		"duration": field_duration,
		"buff_type": "lifesteal",
		"buff_value": field_lifesteal,
		"tick_interval": 0.5,
		"color": Color(0.5, 0.95, 0.75, 0.25)
	})

	SkillEffectManager.create_debuff_zone({
		"polygon": polygon,
		"duration": field_duration,
		"debuff_type": "slow",
		"debuff_value": min(0.85, slow_value + 0.15),
		"debuff_duration": 1.8,
		"tick_interval": 0.4,
		"color": Color(0.25, 0.75, 0.55, 0.22)
	})

	_spawn_closure_triage_waves(polygon, field_duration)
	_spawn_closure_reel(polygon)

func _launch_triage_dart(start: Vector2, finish: Vector2) -> void:
	var seg: Vector2 = finish - start
	var length: float = seg.length()
	if length <= 1.0:
		return
	var move_dir: Vector2 = seg / length
	var host: Node2D = Node2D.new()
	host.name = "MedicTriageDartHost"
	add_child(host)

	var step_total: int = int(max(2.0, ceil(length / max(12.0, triage_dart_step_distance))))
	var step_index: int = 0
	var timer: Timer = Timer.new()
	timer.wait_time = max(0.03, triage_dart_tick_interval)
	timer.one_shot = false
	host.add_child(timer)
	timer.timeout.connect(func() -> void:
		if not is_instance_valid(host):
			return
		if step_index > step_total:
			timer.stop()
			host.queue_free()
			_spawn_triage_recall(finish, start, move_dir)
			return
		_emit_triage_dart_tick(start, finish, step_index, step_total, move_dir)
		step_index += 1
	)
	timer.start()

func _spawn_triage_recall(from_pos: Vector2, to_pos: Vector2, move_dir: Vector2) -> void:
	var tree: SceneTree = get_tree()
	if tree == null:
		return
	tree.create_timer(max(0.05, triage_recall_delay)).timeout.connect(func() -> void:
		if not is_inside_tree():
			return
		var host: Node2D = Node2D.new()
		host.name = "MedicTriageRecallHost"
		add_child(host)
		var pulse_total: int = int(max(1, triage_recall_count))
		var pulse_index: int = 0
		var timer: Timer = Timer.new()
		timer.wait_time = max(0.06, triage_dart_tick_interval * 1.6)
		timer.one_shot = false
		host.add_child(timer)
		timer.timeout.connect(func() -> void:
			if not is_instance_valid(host):
				return
			if pulse_index >= pulse_total:
				timer.stop()
				host.queue_free()
				return
			_emit_triage_recall_tick(from_pos, to_pos, pulse_index, pulse_total, move_dir)
			pulse_index += 1
		)
		timer.start()
	)

func _emit_triage_dart_tick(start: Vector2, finish: Vector2, index: int, total: int, move_dir: Vector2) -> void:
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
		"color": Color(0.7, 1.0, 0.86, 0.9)
	})
	_apply_radius_heal_pulse(current, triage_dart_hit_radius, triage_dart_damage)
	_apply_direction_push(current, triage_dart_hit_radius * 1.18, move_dir, triage_dart_push)

func _emit_triage_recall_tick(
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
		"color": Color(0.82, 1.0, 0.9, 0.92)
	})
	_apply_line_burst_damage(start, end, 12.0, triage_recall_damage)
	_apply_pull_to_point(center, triage_dart_hit_radius * 1.55, triage_recall_pull)
	_heal_owner_around(center, triage_node_radius + 36.0, int(max(1, heal_value * 0.6)))

func _spawn_closure_reel(polygon: PackedVector2Array) -> void:
	var center: Vector2 = _calculate_polygon_center(polygon)
	var radius: float = _polygon_radius(polygon, center)
	var sweep_total: int = int(max(1, closure_reel_count))
	var sweep_index: int = 0
	var host: Node2D = Node2D.new()
	host.name = "MedicClosureReelHost"
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
	var start: Vector2 = center + dir * radius * 1.28
	var end: Vector2 = center - dir * radius * 0.08
	SkillEffectManager.create_line_effect({
		"start": start,
		"end": end,
		"width": 13.0,
		"damage": 0,
		"damage_interval": 0.2,
		"duration": 0.18,
		"color": Color(0.78, 1.0, 0.9, 0.88)
	})
	_apply_line_burst_damage(start, end, 11.0, closure_reel_damage)
	_apply_pull_to_point(center, radius * 1.02, triage_recall_pull * 0.52)
	_heal_owner_around(center, triage_node_radius + 44.0, int(max(1, heal_value * 0.7)))

func _deploy_triage_node_if_needed(pos: Vector2) -> void:
	if _triage_nodes.is_empty():
		_triage_nodes.append(pos)
		_spawn_triage_node(pos)
		return
	var last_pos: Vector2 = _triage_nodes[_triage_nodes.size() - 1]
	if last_pos.distance_to(pos) < triage_node_spacing:
		return
	_triage_nodes.append(pos)
	_spawn_triage_node(pos)
	_spawn_chain_pulse(last_pos, pos)

func _spawn_triage_node(center: Vector2) -> void:
	var station_duration: float = max(0.2, min(triage_node_duration, _get_line_duration()))
	var polygon: PackedVector2Array = _build_circle_polygon(center, triage_node_radius, 14)
	SkillEffectManager.create_buff_zone({
		"polygon": polygon,
		"duration": station_duration,
		"buff_type": "heal",
		"buff_value": float(max(1, heal_value - 1)),
		"tick_interval": 0.4,
		"color": Color(0.55, 1.0, 0.74, 0.28)
	})
	SkillEffectManager.create_buff_zone({
		"polygon": polygon,
		"duration": station_duration,
		"buff_type": "speed_boost",
		"buff_value": triage_speed_boost * 0.9,
		"tick_interval": 0.4,
		"color": Color(0.72, 1.0, 0.85, 0.18)
	})
	SkillEffectManager.create_debuff_zone({
		"polygon": polygon,
		"duration": station_duration,
		"debuff_type": "slow",
		"debuff_value": slow_value * 0.7,
		"debuff_duration": 0.9,
		"tick_interval": 0.35,
		"color": Color(0.4, 0.8, 0.55, 0.14)
	})
	_register_station_window(center, triage_node_radius, station_duration)
	spawn_skill_vfx(center, Color(0.58, 1.0, 0.72, 0.7), 0.38)

func _spawn_chain_pulse(from_pos: Vector2, to_pos: Vector2) -> void:
	var host: Node2D = Node2D.new()
	host.name = "MedicChainPulse"
	add_child(host)
	var pulse_index: int = 0
	var pulse_total: int = int(max(1, triage_pulse_count))

	_emit_chain_pulse(from_pos, to_pos, pulse_index, pulse_total)
	pulse_index += 1

	var timer: Timer = Timer.new()
	timer.wait_time = max(0.06, triage_pulse_interval)
	timer.one_shot = false
	host.add_child(timer)
	timer.timeout.connect(func() -> void:
		if not is_instance_valid(host):
			return
		if pulse_index >= pulse_total:
			timer.stop()
			host.queue_free()
			return
		_emit_chain_pulse(from_pos, to_pos, pulse_index, pulse_total)
		pulse_index += 1
	)
	timer.start()

func _emit_chain_pulse(from_pos: Vector2, to_pos: Vector2, index: int, total: int) -> void:
	var t: float = 0.0
	if total > 1:
		t = float(index) / float(total - 1)
	var pulse_pos: Vector2 = from_pos.lerp(to_pos, clamp(t, 0.0, 1.0))
	_apply_point_pulse(pulse_pos)
	spawn_skill_vfx(pulse_pos, Color(0.65, 1.0, 0.8, 0.66), 0.28)

func _apply_point_pulse(pos: Vector2) -> void:
	if is_instance_valid(skill_owner) and skill_owner.has_node("HealthComponent"):
		if skill_owner.global_position.distance_to(pos) <= triage_node_radius + 26.0:
			var owner_hc: Node = skill_owner.get_node("HealthComponent")
			if owner_hc.has_method("heal"):
				var heal_amount: int = int(max(1, int(round(float(heal_value) * 1.15))))
				owner_hc.call("heal", heal_amount)

	var enemies: Array = get_tree().get_nodes_in_group("enemies")
	for enemy_obj: Variant in enemies:
		if enemy_obj == null or not is_instance_valid(enemy_obj):
			continue
		if not (enemy_obj is Node2D):
			continue
		var enemy: Node2D = enemy_obj
		if enemy.global_position.distance_to(pos) > triage_node_radius * 0.9:
			continue
		_apply_damage(enemy, triage_pulse_damage)
		_apply_status(enemy, "slow", 1.0, min(0.9, slow_value + 0.08), 1, 0.1)

func _apply_radius_heal_pulse(center: Vector2, radius: float, damage: int) -> void:
	_heal_owner_around(center, radius + 24.0, int(max(1, heal_value * 0.5)))
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
		_apply_status(enemy, "slow", 0.9, min(0.88, slow_value + 0.08), 1, 0.1)

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
		_apply_status(enemy, "slow", 0.9, min(0.88, slow_value + 0.08), 1, 0.1)

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

func _heal_owner_around(center: Vector2, radius: float, amount: int) -> void:
	if amount <= 0:
		return
	if not is_instance_valid(skill_owner):
		return
	if skill_owner.global_position.distance_to(center) > radius:
		return
	var owner_hc: Node = skill_owner.get_node_or_null("HealthComponent")
	if owner_hc == null:
		return
	if owner_hc.has_method("heal"):
		owner_hc.call("heal", amount)

func _spawn_closure_triage_waves(polygon: PackedVector2Array, field_duration: float) -> void:
	var center: Vector2 = _calculate_polygon_center(polygon)
	var max_radius: float = _polygon_radius(polygon, center)
	var wave_count: int = int(max(1, closure_wave_count))
	var wave_index: int = 0
	var host: Node2D = Node2D.new()
	host.name = "MedicClosureWaves"
	add_child(host)

	_emit_closure_wave(polygon, center, max_radius, wave_index, wave_count, field_duration)
	wave_index += 1

	var timer: Timer = Timer.new()
	timer.wait_time = max(0.08, closure_wave_interval)
	timer.one_shot = false
	host.add_child(timer)
	timer.timeout.connect(func() -> void:
		if not is_instance_valid(host):
			return
		if wave_index >= wave_count:
			timer.stop()
			host.queue_free()
			return
		_emit_closure_wave(polygon, center, max_radius, wave_index, wave_count, field_duration)
		wave_index += 1
	)
	timer.start()

func _emit_closure_wave(
	polygon: PackedVector2Array,
	center: Vector2,
	max_radius: float,
	wave_index: int,
	wave_count: int,
	field_duration: float
) -> void:
	var ratio: float = float(wave_index + 1) / float(max(1, wave_count))
	var wave_radius: float = float(max(42.0, max_radius * ratio))
	var wave_poly: PackedVector2Array = _build_circle_polygon(center, wave_radius, 18)
	var heal_tick: float = float(max(1, int(round(float(heal_value) * (1.0 + 0.4 * ratio)))))

	SkillEffectManager.create_buff_zone({
		"polygon": wave_poly,
		"duration": max(0.2, field_duration * 0.18),
		"buff_type": "heal",
		"buff_value": heal_tick,
		"tick_interval": 0.16,
		"color": Color(0.62, 1.0, 0.8, 0.24)
	})
	SkillEffectManager.create_buff_zone({
		"polygon": wave_poly,
		"duration": 0.28,
		"buff_type": "invincible",
		"buff_value": 1.0,
		"tick_interval": 0.1,
		"color": Color(0.75, 1.0, 0.86, 0.14)
	})

	var enemies: Array = get_tree().get_nodes_in_group("enemies")
	for enemy_obj: Variant in enemies:
		if enemy_obj == null or not is_instance_valid(enemy_obj):
			continue
		if not (enemy_obj is Node2D):
			continue
		var enemy: Node2D = enemy_obj
		if not Geometry2D.is_point_in_polygon(enemy.global_position, polygon):
			continue
		if enemy.global_position.distance_to(center) > wave_radius + 14.0:
			continue
		_apply_status(enemy, "slow", 1.0, min(0.88, slow_value + 0.1), 1, 0.1)
		if wave_index == wave_count - 1:
			_apply_status(enemy, "freeze", 0.45, 0.0, 1, 0.1)

	spawn_skill_vfx(center + Vector2.RIGHT.rotated(TAU * ratio) * wave_radius * 0.45, Color(0.7, 1.0, 0.82, 0.72), 0.42)

func _build_circle_polygon(center: Vector2, radius: float, segments: int) -> PackedVector2Array:
	var points: PackedVector2Array = PackedVector2Array()
	var segment_count: int = segments
	if segment_count < 8:
		segment_count = 8
	for i: int in range(segment_count):
		var ang: float = TAU * float(i) / float(segment_count)
		points.append(center + Vector2.RIGHT.rotated(ang) * radius)
	return points

func _polygon_radius(polygon: PackedVector2Array, center: Vector2) -> float:
	var radius: float = 0.0
	for point: Vector2 in polygon:
		radius = max(radius, center.distance_to(point))
	return max(20.0, radius)

func _connect_dash_signals() -> void:
	if not is_instance_valid(skill_owner):
		return
	var started_callable := Callable(self, "_on_owner_dash_started")
	var finished_callable := Callable(self, "_on_owner_dash_finished")
	if skill_owner.has_signal("dash_started") and not skill_owner.is_connected("dash_started", started_callable):
		skill_owner.connect("dash_started", started_callable)
	if skill_owner.has_signal("dash_finished") and not skill_owner.is_connected("dash_finished", finished_callable):
		skill_owner.connect("dash_finished", finished_callable)

func _disconnect_dash_signals() -> void:
	if not is_instance_valid(skill_owner):
		return
	var started_callable := Callable(self, "_on_owner_dash_started")
	var finished_callable := Callable(self, "_on_owner_dash_finished")
	if skill_owner.has_signal("dash_started") and skill_owner.is_connected("dash_started", started_callable):
		skill_owner.disconnect("dash_started", started_callable)
	if skill_owner.has_signal("dash_finished") and skill_owner.is_connected("dash_finished", finished_callable):
		skill_owner.disconnect("dash_finished", finished_callable)

func _register_station_window(center: Vector2, radius: float, duration: float) -> void:
	_cleanup_station_windows()
	_station_windows.append({
		"center": center,
		"radius": max(24.0, radius),
		"expire_msec": Time.get_ticks_msec() + int(round(max(0.2, duration) * 1000.0)),
	})

func _cleanup_station_windows() -> void:
	var now_msec: int = Time.get_ticks_msec()
	var kept: Array[Dictionary] = []
	for entry_var in _station_windows:
		if not (entry_var is Dictionary):
			continue
		var entry: Dictionary = entry_var
		if int(entry.get("expire_msec", 0)) > now_msec:
			kept.append(entry)
	_station_windows = kept

func _is_inside_active_station(point: Vector2) -> bool:
	_cleanup_station_windows()
	for entry in _station_windows:
		var center: Vector2 = entry.get("center", Vector2.ZERO)
		var radius: float = float(entry.get("radius", 0.0))
		if point.distance_to(center) <= radius:
			return true
	return false

func _get_owner_player_id() -> String:
	if not is_instance_valid(skill_owner):
		return ""
	if "player_id" in skill_owner:
		return str(skill_owner.get("player_id"))
	return ""

func _on_owner_dash_started(player_id: String, start_pos: Vector2, _direction: Vector2) -> void:
	if not is_instance_valid(skill_owner):
		return
	if player_id != _get_owner_player_id():
		return
	_dash_started_in_station = _is_inside_active_station(start_pos)

func _on_owner_dash_finished(player_id: String, _end_pos: Vector2, _direction: Vector2) -> void:
	if not is_instance_valid(skill_owner):
		return
	if player_id != _get_owner_player_id():
		return
	if not _dash_started_in_station:
		return
	_dash_started_in_station = false
	if _grant_temporary_armor(1, DASH_LIGHT_SHIELD_SEC):
		Global.spawn_floating_text(skill_owner.global_position, "LIGHT SHIELD", Color(0.72, 1.0, 0.88))
		spawn_skill_vfx(skill_owner.global_position, Color(0.7, 1.0, 0.86, 0.72), 0.32)

func _grant_temporary_armor(stacks: int, duration_sec: float) -> bool:
	if stacks <= 0 or duration_sec <= 0.0:
		return false
	if not is_instance_valid(skill_owner):
		return false
	if not ("armor" in skill_owner and "max_armor" in skill_owner):
		return false
	var before: int = int(skill_owner.get("armor"))
	var grantable: int = min(stacks, max(0, int(skill_owner.get("max_armor")) - before))
	if grantable <= 0:
		return false
	skill_owner.set("armor", before + grantable)
	var current_temp: int = int(skill_owner.get_meta(TEMP_ARMOR_META, 0))
	skill_owner.set_meta(TEMP_ARMOR_META, current_temp + grantable)
	if skill_owner.has_signal("armor_changed"):
		skill_owner.emit_signal("armor_changed", int(skill_owner.get("armor")))
	get_tree().create_timer(max(0.05, duration_sec)).timeout.connect(func() -> void:
		_expire_temporary_armor(grantable)
	)
	return true

func _expire_temporary_armor(stacks: int) -> void:
	if stacks <= 0 or not is_instance_valid(skill_owner):
		return
	if not skill_owner.has_meta(TEMP_ARMOR_META):
		return
	var current_temp: int = max(0, int(skill_owner.get_meta(TEMP_ARMOR_META, 0)))
	if current_temp <= 0:
		skill_owner.remove_meta(TEMP_ARMOR_META)
		return
	var remove_count: int = min(stacks, current_temp)
	var current_armor: int = int(skill_owner.get("armor"))
	if remove_count > 0 and current_armor > 0:
		skill_owner.set("armor", max(0, current_armor - remove_count))
		if skill_owner.has_signal("armor_changed"):
			skill_owner.emit_signal("armor_changed", int(skill_owner.get("armor")))
	var remaining_temp: int = current_temp - remove_count
	if remaining_temp > 0:
		skill_owner.set_meta(TEMP_ARMOR_META, remaining_temp)
	else:
		skill_owner.remove_meta(TEMP_ARMOR_META)

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
	return Color(0.35, 1.0, 0.58, 1.0)

func _get_closure_color() -> Color:
	return Color(0.25, 0.9, 0.45, 1.0)
