extends PlayerBase
class_name PlayerCollapse

const TRAP_SCRIPT: Script = preload("res://scenes/effects/collapse_singularity_trap.gd")

const DEFAULT_ATTACK: float = 40.0
const DEFAULT_HEALTH: float = 220.0
const DEFAULT_SPEED: float = 360.0
const DEFAULT_MAX_ENERGY: float = 220.0
const DEFAULT_ENERGY_REGEN: float = 18.0
const DEFAULT_PICKUP_RANGE: float = 170.0

@export_group("Collapse Draw")
@export var draw_sample_spacing: float = 10.0
@export var draw_energy_cost: float = 10.0
@export var draw_length_limit: float = 360.0
@export var closure_threshold: float = 56.0
@export var singularity_trap_lifetime: float = 3.5
@export var singularity_trap_radius: float = 140.0
@export var singularity_trap_pull_strength: float = 620.0
@export var singularity_tick_interval: float = 1.0

@export_group("Dash")
@export var dash_cost: float = 5.0
@export var dash_distance: float = 400.0
@export var dash_speed: float = 2000.0
@export var dash_invuln_duration: float = 0.35

@export_group("Collapse E")
@export var gravity_well_energy_cost: float = 30.0
@export var gravity_well_cooldown: float = 6.0
@export var gravity_well_radius: float = 250.0
@export var gravity_well_slow_duration: float = 1.0
@export var gravity_well_slow_ratio: float = 0.80
@export var gravity_well_pull_ratio: float = 0.72

@export_group("Collapse F")
@export var event_horizon_energy_percent: float = 40.0

@onready var dash_timer: Timer = $DashTimer
@onready var draw_line: Line2D = $Line2D

var _is_dashing: bool = false
var _dash_direction: Vector2 = Vector2.ZERO
var _dash_remaining_distance: float = 0.0
var _dash_total_distance: float = 0.0
var _dash_invulnerable: bool = false

var _is_drawing: bool = false
var _draw_points: PackedVector2Array = PackedVector2Array()
var _draw_total_length: float = 0.0
var _draw_energy_spent: float = 0.0
var _has_self_intersection: bool = false
var _self_intersection_point: Vector2 = Vector2.ZERO

var _gravity_well_cooldown_remaining: float = 0.0
var _active_traps: Array[CollapseSingularityTrap] = []
var _v2_bundle: Dictionary = {}

func _ready() -> void:
	if player_id.strip_edges().is_empty():
		player_id = "collapse"
	super._ready()

	health = DEFAULT_HEALTH
	damage = DEFAULT_ATTACK
	energy = max_energy
	skill_q_cost = 0.0
	skill_e_cost = gravity_well_energy_cost
	close_threshold = closure_threshold

	if health_component:
		health_component.setup_with_health(health)
	update_ui_signals()

	if is_instance_valid(dash_timer):
		dash_timer.one_shot = true
		dash_timer.wait_time = dash_invuln_duration

	if is_instance_valid(draw_line):
		draw_line.top_level = true
		draw_line.width = 8.0
		draw_line.default_color = Color(0.84, 0.9, 1.0, 0.94)
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
	closure_threshold = float(player_config.get("close_threshold", closure_threshold))
	close_threshold = closure_threshold

	draw_sample_spacing = float(space_config.get("point_sample_step", draw_sample_spacing))
	draw_energy_cost = float(space_config.get("base_energy_cost", draw_energy_cost))
	draw_length_limit = float(space_config.get("max_total_length", draw_length_limit))
	singularity_trap_lifetime = max(0.5, float(space_config.get("release_asset_lifetime", singularity_trap_lifetime)))

	gravity_well_energy_cost = float(e_config.get("energy_cost", gravity_well_energy_cost))
	gravity_well_cooldown = float(e_config.get("cooldown", gravity_well_cooldown))
	gravity_well_radius = float(e_config.get("effect_radius", gravity_well_radius))
	gravity_well_slow_duration = float(e_config.get("effect_duration", gravity_well_slow_duration))
	skill_e_cost = gravity_well_energy_cost

	var f_cost_mode: String = str(f_config.get("energy_cost_mode", "percent_current")).strip_edges()
	if f_cost_mode in ["percent", "percent_current"]:
		event_horizon_energy_percent = float(f_config.get("energy_cost", event_horizon_energy_percent))

	damage = DEFAULT_ATTACK

func _load_weapons_from_config() -> void:
	super._load_weapons_from_config()

func _load_ultimate_skill() -> void:
	ultimate_skill = null

func _auto_create_skill_manager() -> void:
	pass

func _handle_input(delta: float) -> void:
	move_dir = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var draw_held: bool = Input.is_action_pressed("click_right")

	if _is_dashing:
		_update_dash(delta)
	elif can_move():
		var current_speed: float = speed
		if has_meta("buff_speed_boost"):
			current_speed *= (1.0 + float(get_meta("buff_speed_boost")))
		position += move_dir * current_speed * delta

	if Input.is_action_just_pressed("tactical_reject"):
		_try_activate_tactical_reject()

	if Input.is_action_just_pressed("click_left"):
		_try_start_dash()

	if Input.is_action_just_pressed("skill_e"):
		_activate_gravity_well()

	if Input.is_action_just_pressed("skill_f"):
		_activate_event_horizon()

	if draw_held:
		if not _is_drawing:
			_begin_drawing()
		_update_drawing_path()
	elif _is_drawing and Input.is_action_just_released("click_right"):
		_release_drawing_path()

func _process_subclass(delta: float) -> void:
	if _gravity_well_cooldown_remaining > 0.0:
		_gravity_well_cooldown_remaining = max(0.0, _gravity_well_cooldown_remaining - delta)
	_cleanup_traps()
	_refresh_invincible_meta()

func _begin_drawing() -> void:
	if _is_drawing:
		return
	if not consume_energy(draw_energy_cost):
		return
	_is_drawing = true
	_draw_points = PackedVector2Array()
	_draw_total_length = 0.0
	_draw_energy_spent = draw_energy_cost
	_has_self_intersection = false
	_self_intersection_point = Vector2.ZERO
	var start_point: Vector2 = get_global_mouse_position()
	_draw_points.append(start_point)
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
	var cursor: Vector2 = last_point
	var remaining_distance: float = distance_to_target
	while remaining_distance >= draw_sample_spacing:
		var new_point: Vector2 = cursor + direction * draw_sample_spacing
		if not _append_draw_point(new_point):
			return
		cursor = new_point
		remaining_distance -= draw_sample_spacing

func _append_draw_point(point: Vector2) -> bool:
	if _draw_points.is_empty():
		_draw_points.append(point)
		_refresh_draw_visual()
		return true

	var previous: Vector2 = _draw_points[_draw_points.size() - 1]
	var segment_length: float = previous.distance_to(point)
	if segment_length <= 0.001:
		return true

	_draw_total_length += segment_length
	if _draw_total_length > draw_length_limit:
		_fail_short_circuit()
		return false

	var hit: Variant = _find_self_intersection(previous, point)
	if hit != null:
		_has_self_intersection = true
		_self_intersection_point = hit
		if BondManager != null and BondManager.has_method("on_draw_self_intersection") and hit is Vector2:
			BondManager.on_draw_self_intersection(self, hit)

	_draw_points.append(point)
	_refresh_draw_visual()
	return true

func _release_drawing_path() -> void:
	if not _is_drawing:
		return
	var final_point: Vector2 = get_global_mouse_position()
	if _draw_points.is_empty() or _draw_points[_draw_points.size() - 1].distance_to(final_point) > 1.0:
		_append_draw_point(final_point)
	var captured_points: PackedVector2Array = _draw_points.duplicate()
	var total_length: float = _draw_total_length
	var draw_cost_spent: float = _draw_energy_spent
	var forced_closure: Dictionary = BondManager.apply_forced_closure(self, captured_points) if BondManager != null and BondManager.has_method("apply_forced_closure") else {}
	if bool(forced_closure.get("forced_closed", false)):
		captured_points = forced_closure.get("points", captured_points)
	var is_closed: bool = _determine_closed_shape(captured_points)
	var centroid: Vector2 = _resolve_centroid(captured_points, is_closed)
	var approx_area: float = _estimate_polygon_area(captured_points, is_closed)

	_is_drawing = false
	_draw_points = PackedVector2Array()
	_draw_total_length = 0.0
	_draw_energy_spent = 0.0
	_has_self_intersection = false
	_self_intersection_point = Vector2.ZERO
	_clear_draw_visual()

	if captured_points.size() < 2 or total_length <= 0.0:
		return

	Global.cache_recent_draw_path(player_id, _packed_to_points(captured_points), is_closed)
	_notify_draw_release(captured_points, is_closed, centroid, approx_area, draw_cost_spent)

	if not is_closed:
		Global.spawn_floating_text(global_position, "WASTE", Color(1.0, 0.44, 0.4))
		return

	_spawn_singularity_trap(centroid)
	Global.spawn_floating_text(centroid, "SINGULARITY", Color(0.82, 0.92, 1.0))

func _determine_closed_shape(points: PackedVector2Array) -> bool:
	if points.size() < 3:
		return false
	if _has_self_intersection:
		return true
	return points[0].distance_to(points[points.size() - 1]) <= closure_threshold

func _resolve_centroid(points: PackedVector2Array, is_closed: bool) -> Vector2:
	if points.is_empty():
		return global_position
	if _has_self_intersection:
		return _self_intersection_point if _self_intersection_point != Vector2.ZERO else _average_point(points)
	if is_closed:
		var polygon_points: PackedVector2Array = points.duplicate()
		if polygon_points[0].distance_to(polygon_points[polygon_points.size() - 1]) > 0.001:
			polygon_points.append(polygon_points[0])
		var signed_area: float = 0.0
		var centroid_x: float = 0.0
		var centroid_y: float = 0.0
		for i in range(polygon_points.size() - 1):
			var a: Vector2 = polygon_points[i]
			var b: Vector2 = polygon_points[i + 1]
			var cross: float = a.x * b.y - b.x * a.y
			signed_area += cross
			centroid_x += (a.x + b.x) * cross
			centroid_y += (a.y + b.y) * cross
		if abs(signed_area) > 0.001:
			signed_area *= 0.5
			return Vector2(centroid_x / (6.0 * signed_area), centroid_y / (6.0 * signed_area))
	return _average_point(points)

func _estimate_polygon_area(points: PackedVector2Array, is_closed: bool) -> float:
	if not is_closed or points.size() < 3:
		return 0.0
	var polygon_points: PackedVector2Array = points.duplicate()
	if polygon_points[0].distance_to(polygon_points[polygon_points.size() - 1]) > 0.001:
		polygon_points.append(polygon_points[0])
	var double_area: float = 0.0
	for i in range(polygon_points.size() - 1):
		var a: Vector2 = polygon_points[i]
		var b: Vector2 = polygon_points[i + 1]
		double_area += a.x * b.y - b.x * a.y
	return abs(double_area) * 0.5

func _average_point(points: PackedVector2Array) -> Vector2:
	var sum: Vector2 = Vector2.ZERO
	for point: Vector2 in points:
		sum += point
	return sum / float(max(1, points.size()))

func _find_self_intersection(start_point: Vector2, end_point: Vector2) -> Variant:
	if _draw_points.size() < 3:
		return null
	for i in range(_draw_points.size() - 2):
		var a: Vector2 = _draw_points[i]
		var b: Vector2 = _draw_points[i + 1]
		var hit: Variant = Geometry2D.segment_intersects_segment(a, b, start_point, end_point)
		if hit != null:
			return hit
	return null

func _fail_short_circuit() -> void:
	_is_drawing = false
	_draw_points = PackedVector2Array()
	_draw_total_length = 0.0
	_draw_energy_spent = 0.0
	_has_self_intersection = false
	_self_intersection_point = Vector2.ZERO
	_clear_draw_visual()
	SoundManager.play("ui_error")
	Global.spawn_floating_text(global_position, "SHORT", Color(1.0, 0.4, 0.3))
	set_flash_material()

func _notify_draw_release(points: PackedVector2Array, is_closed: bool, centroid: Vector2, approx_area: float, draw_cost_spent: float) -> void:
	notify_space_draw_release({
		"source": "space",
		"skill_id": "collapse_space",
		"is_closed": is_closed,
		"points": _packed_to_points(points),
		"centroid": centroid,
		"approx_area": approx_area,
		"draw_cost": draw_cost_spent,
	})

func _packed_to_points(points: PackedVector2Array) -> Array[Vector2]:
	var result: Array[Vector2] = []
	for point in points:
		result.append(point)
	return result

func _spawn_singularity_trap(center: Vector2) -> void:
	var trap: CollapseSingularityTrap = TRAP_SCRIPT.new() as CollapseSingularityTrap
	if trap == null:
		return
	trap.global_position = center
	trap.visual_radius = 18.0
	trap.attract_radius = singularity_trap_radius
	trap.lifetime = singularity_trap_lifetime
	trap.pull_strength = singularity_trap_pull_strength
	trap.idle_tick_interval = singularity_tick_interval
	trap.setup(self, damage)
	if not trap.removed.is_connected(_on_trap_removed):
		trap.removed.connect(_on_trap_removed)
	get_tree().current_scene.add_child(trap)
	_active_traps.append(trap)

func _activate_gravity_well() -> void:
	if _gravity_well_cooldown_remaining > 0.0:
		Global.spawn_floating_text(global_position, "CD", Color(0.92, 0.82, 0.42))
		return
	if not consume_energy(gravity_well_energy_cost):
		return
	_gravity_well_cooldown_remaining = gravity_well_cooldown
	notify_front_skill_cast("e", {"skill_id": "e_collapse"})
	var center: Vector2 = get_global_mouse_position()
	_spawn_gravity_well_vfx(center)
	for enemy_node in get_tree().get_nodes_in_group("enemies"):
		if not (enemy_node is Enemy):
			continue
		var enemy: Enemy = enemy_node as Enemy
		if not is_instance_valid(enemy) or enemy.is_dead:
			continue
		var distance_to_center: float = enemy.global_position.distance_to(center)
		if distance_to_center > gravity_well_radius:
			continue
		enemy.global_position = enemy.global_position.lerp(center, gravity_well_pull_ratio)
		enemy.apply_status("slow", gravity_well_slow_duration, gravity_well_slow_ratio, 1, 1.0)
	Global.spawn_floating_text(center, "WELL", Color(0.78, 0.9, 1.0))

func _spawn_gravity_well_vfx(center: Vector2) -> void:
	var ring: Line2D = Line2D.new()
	ring.top_level = true
	ring.closed = true
	ring.width = 10.0
	ring.default_color = Color(0.76, 0.88, 1.0, 0.6)
	ring.antialiased = true
	var points: PackedVector2Array = PackedVector2Array()
	for i in range(25):
		var angle: float = (float(i) / 24.0) * TAU
		points.append(center + Vector2.RIGHT.rotated(angle) * gravity_well_radius)
	ring.points = points
	get_tree().current_scene.add_child(ring)
	var tween: Tween = ring.create_tween()
	tween.set_parallel(true)
	tween.tween_property(ring, "scale", Vector2(0.18, 0.18), 0.18)
	tween.tween_property(ring, "modulate:a", 0.0, 0.18)
	tween.finished.connect(ring.queue_free)

func _activate_event_horizon() -> void:
	_cleanup_traps()
	var energy_cost: float = max_energy * (event_horizon_energy_percent / 100.0)
	if not consume_energy(energy_cost):
		return
	if _active_traps.is_empty():
		energy = min(max_energy, energy + energy_cost)
		update_ui_signals()
		Global.spawn_floating_text(global_position, "MISS", Color(1.0, 0.44, 0.42))
		SoundManager.play("ui_error")
		return
	notify_front_skill_cast("f", {"skill_id": "f_collapse"})
	for trap in _active_traps:
		if is_instance_valid(trap):
			trap.activate_event_horizon()
	Global.spawn_floating_text(global_position, "EVENT HORIZON", Color(0.86, 0.94, 1.0))

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
	_dash_direction = get_modified_dash_direction(dash_dir.normalized())
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
	Global.spawn_floating_text(global_position, "DASH", Color(0.78, 0.98, 1.0))

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

func _refresh_draw_visual() -> void:
	if is_instance_valid(draw_line):
		draw_line.points = _draw_points

func _clear_draw_visual() -> void:
	if is_instance_valid(draw_line):
		draw_line.points = PackedVector2Array()

func _cleanup_traps() -> void:
	var valid_traps: Array[CollapseSingularityTrap] = []
	for trap in _active_traps:
		if is_instance_valid(trap) and not trap.is_queued_for_deletion():
			valid_traps.append(trap)
	_active_traps = valid_traps

func _on_trap_removed(_trap: CollapseSingularityTrap) -> void:
	_cleanup_traps()
