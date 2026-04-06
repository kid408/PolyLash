extends PlayerBase
class_name PlayerOvertone

const OVERTONE_STRING_SCRIPT: Script = preload("res://scenes/effects/overtone_string.gd")
const OVERTONE_DRUM_SCRIPT: Script = preload("res://scenes/effects/overtone_drum.gd")

const DEFAULT_ATTACK: float = 40.0
const DEFAULT_HEALTH: float = 180.0
const DEFAULT_SPEED: float = 290.0
const DEFAULT_MAX_ENERGY: float = 100.0
const DEFAULT_ENERGY_REGEN: float = 10.0
const DEFAULT_PICKUP_RANGE: float = 150.0

@export_group("Overtone Draw")
@export var draw_sample_spacing: float = 10.0
@export var draw_min_release_length: float = 24.0
@export var draw_close_threshold: float = 56.0
@export var draw_base_energy_cost: float = 0.0
@export var draw_energy_cost_per_step: float = 0.33333334
@export var draw_energy_cost_unit_px: float = 30.0
@export var string_lifetime: float = 10.0
@export var string_pluck_damage_ratio: float = 1.2
@export var string_max_plucks: int = 3
@export var drum_lifetime: float = 3.0
@export var drum_roll_damage_ratio: float = 3.0

@export_group("Dash")
@export var dash_cost: float = 5.0
@export var dash_distance: float = 400.0
@export var dash_speed: float = 2000.0
@export var dash_invuln_duration: float = 0.35

@export_group("E Skill")
@export var tuning_energy_cost: float = 30.0
@export var tuning_cooldown: float = 8.0

@export_group("F Skill")
@export var death_metal_energy_percent: float = 40.0
@export var death_metal_duration: float = 8.0

@onready var dash_timer: Timer = $DashTimer
@onready var draw_line: Line2D = $Line2D

var _is_dashing: bool = false
var _dash_direction: Vector2 = Vector2.ZERO
var _dash_remaining_distance: float = 0.0
var _dash_total_distance: float = 0.0
var _dash_invulnerable: bool = false

var _is_drawing: bool = false
var _draw_points: PackedVector2Array = PackedVector2Array()
var _draw_step_remainder: float = 0.0
var _draw_energy_spent: float = 0.0

var _e_cooldown_remaining: float = 0.0
var _death_metal_timer: float = 0.0
var _v2_bundle: Dictionary = {}

func _ready() -> void:
	if player_id.strip_edges().is_empty():
		player_id = "overtone"
	super._ready()

	damage = DEFAULT_ATTACK
	energy = max_energy
	skill_e_cost = tuning_energy_cost
	close_threshold = draw_close_threshold

	if health_component:
		health_component.setup_with_health(health)
	update_ui_signals()

	if is_instance_valid(dash_timer):
		dash_timer.one_shot = true
		dash_timer.wait_time = dash_invuln_duration

	if is_instance_valid(draw_line):
		draw_line.top_level = true
		draw_line.width = 8.0
		draw_line.default_color = Color(1.0, 0.94, 0.72, 0.96)
		draw_line.joint_mode = Line2D.LINE_JOINT_ROUND
		draw_line.begin_cap_mode = Line2D.LINE_CAP_ROUND
		draw_line.end_cap_mode = Line2D.LINE_CAP_ROUND
		draw_line.antialiased = true
		draw_line.z_index = 36
		_clear_draw_visual()

func _load_config_from_csv() -> void:
	super._load_config_from_csv()
	_v2_bundle = RoleRuntimeService.get_v2_role_bundle(player_id)
	var player_config: Dictionary = _v2_bundle.get("player_config", {})
	var space_config: Dictionary = _v2_bundle.get("space_skill", {})
	var e_config: Dictionary = _v2_bundle.get("e_skill", {})
	var f_config: Dictionary = _v2_bundle.get("f_skill", {})

	health = float(player_config.get("health", DEFAULT_HEALTH))
	max_energy = float(player_config.get("max_energy", DEFAULT_MAX_ENERGY))
	energy = float(player_config.get("initial_energy", max_energy))
	energy_regen = float(player_config.get("energy_regen", DEFAULT_ENERGY_REGEN))
	max_armor = int(player_config.get("max_armor", max_armor))
	base_speed = float(player_config.get("base_speed", DEFAULT_SPEED))
	speed = base_speed
	pickup_range = float(player_config.get("pickup_range", DEFAULT_PICKUP_RANGE))
	external_force_decay = float(player_config.get("external_force_decay", external_force_decay))
	knockback_scale = float(player_config.get("knockback_scale", knockback_scale))

	draw_sample_spacing = float(space_config.get("point_sample_step", draw_sample_spacing))
	draw_min_release_length = float(space_config.get("min_release_length", draw_min_release_length))
	draw_base_energy_cost = float(space_config.get("base_energy_cost", draw_base_energy_cost))
	draw_energy_cost_unit_px = max(1.0, float(space_config.get("energy_cost_unit_px", draw_energy_cost_unit_px)))
	var energy_cost_per_unit: float = float(space_config.get("energy_cost_per_unit", 1.0))
	draw_energy_cost_per_step = energy_cost_per_unit * (draw_sample_spacing / draw_energy_cost_unit_px)

	tuning_energy_cost = float(e_config.get("energy_cost", tuning_energy_cost))
	tuning_cooldown = float(e_config.get("cooldown", tuning_cooldown))
	skill_e_cost = tuning_energy_cost

	var f_cost_mode: String = str(f_config.get("energy_cost_mode", "percent_current")).strip_edges()
	if f_cost_mode in ["percent", "percent_current"]:
		death_metal_energy_percent = float(f_config.get("energy_cost", death_metal_energy_percent))
	death_metal_duration = max(0.1, float(f_config.get("duration", death_metal_duration)))

	damage = DEFAULT_ATTACK

func _load_weapons_from_config() -> void:
	super._load_weapons_from_config()

func _load_ultimate_skill() -> void:
	ultimate_skill = null

func _auto_create_skill_manager() -> void:
	pass

func _handle_input(delta: float) -> void:
	move_dir = Input.get_vector("move_left", "move_right", "move_up", "move_down")

	if _is_dashing:
		_update_dash(delta)
	elif can_move():
		position += move_dir * get_effective_move_speed() * delta

	if Input.is_action_just_pressed("tactical_reject"):
		_try_activate_tactical_reject()

	if Input.is_action_just_pressed("click_left"):
		_try_start_dash()

	if Input.is_action_just_pressed("skill_e"):
		_activate_tuning()

	if Input.is_action_just_pressed("skill_f"):
		_activate_death_metal()

	if Input.is_action_pressed("click_right"):
		if not _is_drawing:
			_begin_drawing()
		_update_drawing_path()
	elif _is_drawing and Input.is_action_just_released("click_right"):
		_release_drawing_path()

func _process_subclass(delta: float) -> void:
	if _e_cooldown_remaining > 0.0:
		_e_cooldown_remaining = max(0.0, _e_cooldown_remaining - delta)

	if _death_metal_timer > 0.0:
		_death_metal_timer = max(0.0, _death_metal_timer - delta)
		if _death_metal_timer <= 0.0:
			_set_all_strings_frenzy(false)

	_refresh_invincible_meta()

func _begin_drawing() -> void:
	if draw_base_energy_cost > 0.0 and not _is_death_metal_active() and not consume_energy(draw_base_energy_cost):
		return
	_is_drawing = true
	_draw_points = PackedVector2Array()
	_draw_step_remainder = 0.0
	_draw_energy_spent = draw_base_energy_cost if not _is_death_metal_active() else 0.0
	_draw_points.append(get_global_mouse_position())
	_refresh_draw_visual()

func _update_drawing_path() -> void:
	if not _is_drawing:
		return
	var target_point: Vector2 = get_global_mouse_position()
	if _draw_points.is_empty():
		_draw_points.append(target_point)
		_refresh_draw_visual()
		return

	var last_point: Vector2 = _draw_points[_draw_points.size() - 1]
	var delta_vec: Vector2 = target_point - last_point
	var distance_to_target: float = delta_vec.length()
	if distance_to_target <= 0.001:
		return

	var direction: Vector2 = delta_vec / distance_to_target
	var remaining_distance: float = distance_to_target
	var cursor: Vector2 = last_point
	var next_step: float = max(0.001, draw_sample_spacing - _draw_step_remainder)

	while remaining_distance >= next_step:
		var new_point: Vector2 = cursor + direction * next_step
		if not _append_draw_point(new_point):
			return
		cursor = new_point
		remaining_distance -= next_step
		next_step = draw_sample_spacing

	_draw_step_remainder = draw_sample_spacing - remaining_distance

func _append_draw_point(point: Vector2) -> bool:
	if _draw_points.is_empty():
		_draw_points.append(point)
		_refresh_draw_visual()
		return true
	var previous: Vector2 = _draw_points[_draw_points.size() - 1]
	var segment_length: float = previous.distance_to(point)
	if segment_length <= 0.001:
		return true
	if not _is_death_metal_active() and not consume_energy(draw_energy_cost_per_step):
		_cancel_drawing()
		return false
	if not _is_death_metal_active():
		_draw_energy_spent += draw_energy_cost_per_step
	_draw_points.append(point)
	_refresh_draw_visual()
	return true

func _release_drawing_path() -> void:
	if not _is_drawing:
		return
	var final_point: Vector2 = get_global_mouse_position()
	if _draw_points.is_empty() or _draw_points[_draw_points.size() - 1].distance_to(final_point) > 1.0:
		_draw_points.append(final_point)

	var captured_points: PackedVector2Array = _draw_points.duplicate()
	_is_drawing = false
	_draw_points = PackedVector2Array()
	_draw_step_remainder = 0.0
	_clear_draw_visual()

	if captured_points.size() < 2:
		return

	var total_length: float = _compute_path_length(captured_points)
	if total_length < draw_min_release_length:
		return

	var closed_polygon: PackedVector2Array = _build_closed_polygon(captured_points)
	var is_closed: bool = closed_polygon.size() >= 3
	var release_points: PackedVector2Array = closed_polygon if is_closed else captured_points
	var centroid: Vector2 = _resolve_centroid(release_points, is_closed)
	var approx_area: float = _estimate_polygon_area(release_points, is_closed)

	Global.cache_recent_draw_path(player_id, _packed_to_points(release_points), is_closed)
	notify_space_draw_release({
		"source": "space",
		"skill_id": "draw_overtone",
		"is_closed": is_closed,
		"points": _packed_to_points(release_points),
		"centroid": centroid,
		"approx_area": approx_area,
		"draw_cost": _draw_energy_spent,
	})
	_draw_energy_spent = 0.0

	if is_closed:
		_spawn_resonance_drum(release_points, centroid)
	else:
		_spawn_tension_string(release_points)

func _cancel_drawing() -> void:
	_is_drawing = false
	_draw_points = PackedVector2Array()
	_draw_step_remainder = 0.0
	_clear_draw_visual()

func _spawn_tension_string(points: PackedVector2Array) -> void:
	var string_asset: OvertoneString = OVERTONE_STRING_SCRIPT.new() as OvertoneString
	if string_asset == null:
		return
	string_asset.sonic_boom_damage_ratio = string_pluck_damage_ratio
	string_asset.max_plucks = max(1, string_max_plucks)
	string_asset.setup(self, points, damage, string_lifetime, _is_death_metal_active())
	get_tree().current_scene.add_child(string_asset)
	Global.spawn_floating_text(_average_point(points), "STRING", Color(1.0, 0.86, 0.34))

func _spawn_resonance_drum(polygon: PackedVector2Array, centroid_value: Vector2) -> void:
	var drum_asset: OvertoneDrum = OVERTONE_DRUM_SCRIPT.new() as OvertoneDrum
	if drum_asset == null:
		return
	drum_asset.damage_ratio = drum_roll_damage_ratio
	drum_asset.setup(self, polygon, centroid_value, drum_lifetime)
	get_tree().current_scene.add_child(drum_asset)
	Global.spawn_floating_text(centroid_value, "DRUM", Color(1.0, 0.92, 0.56))

func _activate_tuning() -> void:
	if _e_cooldown_remaining > 0.0:
		Global.spawn_floating_text(global_position, "CD", Color(0.9, 0.8, 0.4))
		return
	if not consume_energy(tuning_energy_cost):
		return
	_e_cooldown_remaining = tuning_cooldown
 
	var strings_to_retune: Array[OvertoneString] = []
	var group_center_accum: Vector2 = Vector2.ZERO
	for node: Node in get_tree().get_nodes_in_group("overtone_strings"):
		if not (node is OvertoneString):
			continue
		var overtone_string: OvertoneString = node as OvertoneString
		if overtone_string == null or not is_instance_valid(overtone_string):
			continue
		if overtone_string.owner_player != self:
			continue
		strings_to_retune.append(overtone_string)
		group_center_accum += overtone_string.get_string_center()

	if strings_to_retune.is_empty():
		Global.spawn_floating_text(global_position, "MISS", Color(1.0, 0.42, 0.42))
		SoundManager.play("ui_error")
		return

	var group_center: Vector2 = group_center_accum / float(strings_to_retune.size())
	var shared_offset: Vector2 = global_position - group_center
	for overtone_string: OvertoneString in strings_to_retune:
		overtone_string.translate_by_offset(shared_offset, global_position)

	Global.spawn_floating_text(global_position, "TUNE x%d" % strings_to_retune.size(), Color(1.0, 0.86, 0.38))

func _activate_death_metal() -> void:
	var energy_cost: float = energy * (death_metal_energy_percent / 100.0)
	if energy_cost <= 0.0:
		Global.spawn_floating_text(global_position, "NO ENERGY", Color(1.0, 0.42, 0.42))
		return
	if not consume_energy(energy_cost):
		return
	_death_metal_timer = death_metal_duration
	_set_all_strings_frenzy(true)
	Global.spawn_floating_text(global_position, "DEATH METAL", Color(1.0, 0.82, 0.36))

func _set_all_strings_frenzy(active: bool) -> void:
	for node: Node in get_tree().get_nodes_in_group("overtone_strings"):
		if node is OvertoneString and is_instance_valid(node):
			(node as OvertoneString).set_frenzy_active(active)

func _is_death_metal_active() -> bool:
	return _death_metal_timer > 0.0

func _try_start_dash() -> void:
	if _is_dashing:
		return
	if not consume_energy(dash_cost):
		return

	var dash_target: Vector2 = get_global_mouse_position()
	var dash_dir: Vector2 = global_position.direction_to(dash_target)
	if dash_dir.length_squared() <= 0.0001:
		dash_dir = move_dir.normalized()
	if dash_dir.length_squared() <= 0.0001:
		dash_dir = Vector2.RIGHT if is_facing_right() else Vector2.LEFT

	_is_dashing = true
	_dash_direction = dash_dir.normalized()
	_dash_remaining_distance = dash_distance
	_dash_total_distance = dash_distance
	_dash_invulnerable = true
	if is_instance_valid(dash_timer):
		dash_timer.stop()
		dash_timer.wait_time = dash_invuln_duration
		dash_timer.start()
	_refresh_invincible_meta()
	dash_started.emit(player_id, global_position, _dash_direction)
	notify_front_dash_used({
		"start": global_position,
		"end": global_position + _dash_direction * dash_distance,
		"direction": _dash_direction,
		"distance": dash_distance,
	})

func _update_dash(delta: float) -> void:
	if not _is_dashing:
		return
	var step: float = min(_dash_remaining_distance, dash_speed * delta)
	global_position += _dash_direction * step
	_dash_remaining_distance = max(0.0, _dash_remaining_distance - step)
	var normalized_time: float = 1.0 - (_dash_remaining_distance / max(1.0, _dash_total_distance))
	dash_active.emit(player_id, global_position, _dash_direction, normalized_time)
	if _dash_remaining_distance <= 0.0:
		_finish_dash()

func _finish_dash() -> void:
	if not _is_dashing:
		return
	_is_dashing = false
	dash_finished.emit(player_id, global_position, _dash_direction)

func _on_dash_timer_timeout() -> void:
	_dash_invulnerable = false
	_refresh_invincible_meta()

func _refresh_invincible_meta() -> void:
	if _dash_invulnerable:
		set_meta("buff_invincible", true)
	elif has_meta("buff_invincible"):
		remove_meta("buff_invincible")

func reset_dash_cooldown() -> void:
	pass

func _refresh_draw_visual() -> void:
	if is_instance_valid(draw_line):
		draw_line.points = _draw_points

func _clear_draw_visual() -> void:
	if is_instance_valid(draw_line):
		draw_line.points = PackedVector2Array()

func _compute_path_length(points: PackedVector2Array) -> float:
	var total: float = 0.0
	for i: int in range(points.size() - 1):
		total += points[i].distance_to(points[i + 1])
	return total

func _build_closed_polygon(points: PackedVector2Array) -> PackedVector2Array:
	var polygon: PackedVector2Array = PackedVector2Array()
	if points.size() < 3:
		return polygon
	if points[0].distance_to(points[points.size() - 1]) <= draw_close_threshold:
		for point: Vector2 in points:
			polygon.append(point)
		if polygon.size() >= 2:
			polygon.remove_at(polygon.size() - 1)
		return polygon

	var self_intersection: Dictionary = _find_self_intersection_loop(points)
	if bool(self_intersection.get("found", false)):
		var loop_polygon_variant: Variant = self_intersection.get("polygon", PackedVector2Array())
		if loop_polygon_variant is PackedVector2Array:
			return loop_polygon_variant
	return polygon

func _find_self_intersection_loop(points: PackedVector2Array) -> Dictionary:
	var result: Dictionary = {"found": false, "polygon": PackedVector2Array()}
	if points.size() < 4:
		return result
	for i: int in range(points.size() - 1):
		var a_start: Vector2 = points[i]
		var a_end: Vector2 = points[i + 1]
		for j: int in range(i + 2, points.size() - 1):
			if j == i + 1:
				continue
			var b_start: Vector2 = points[j]
			var b_end: Vector2 = points[j + 1]
			var intersection_variant: Variant = Geometry2D.segment_intersects_segment(a_start, a_end, b_start, b_end)
			if intersection_variant == null or not (intersection_variant is Vector2):
				continue
			var intersection: Vector2 = intersection_variant
			var loop_polygon: PackedVector2Array = PackedVector2Array()
			loop_polygon.append(intersection)
			for point_index: int in range(i + 1, j + 1):
				loop_polygon.append(points[point_index])
			loop_polygon.append(intersection)
			if loop_polygon.size() >= 4:
				loop_polygon.remove_at(loop_polygon.size() - 1)
			if loop_polygon.size() >= 3 and _estimate_simple_polygon_area(loop_polygon) > 1.0:
				result["found"] = true
				result["polygon"] = loop_polygon
				return result
	return result

func _estimate_simple_polygon_area(polygon: PackedVector2Array) -> float:
	if polygon.size() < 3:
		return 0.0
	var double_area: float = 0.0
	for i: int in range(polygon.size()):
		var a: Vector2 = polygon[i]
		var b: Vector2 = polygon[(i + 1) % polygon.size()]
		double_area += a.x * b.y - b.x * a.y
	return abs(double_area) * 0.5

func _resolve_centroid(points: PackedVector2Array, is_closed: bool) -> Vector2:
	if points.is_empty():
		return global_position
	if not is_closed:
		return _average_point(points)
	var double_area: float = 0.0
	var centroid_accum: Vector2 = Vector2.ZERO
	for i: int in range(points.size()):
		var a: Vector2 = points[i]
		var b: Vector2 = points[(i + 1) % points.size()]
		var cross: float = a.x * b.y - b.x * a.y
		double_area += cross
		centroid_accum += (a + b) * cross
	if abs(double_area) <= 0.001:
		return _average_point(points)
	return centroid_accum / (3.0 * double_area)

func _estimate_polygon_area(points: PackedVector2Array, is_closed: bool) -> float:
	if not is_closed or points.size() < 3:
		return 0.0
	var double_area: float = 0.0
	for i: int in range(points.size()):
		var a: Vector2 = points[i]
		var b: Vector2 = points[(i + 1) % points.size()]
		double_area += a.x * b.y - b.x * a.y
	return abs(double_area) * 0.5

func _average_point(points: PackedVector2Array) -> Vector2:
	if points.is_empty():
		return global_position
	var total: Vector2 = Vector2.ZERO
	for point: Vector2 in points:
		total += point
	return total / float(points.size())

func _packed_to_points(points: PackedVector2Array) -> Array[Vector2]:
	var result: Array[Vector2] = []
	for point: Vector2 in points:
		result.append(point)
	return result
