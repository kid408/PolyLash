extends PlayerBase
class_name PlayerJoule

const JOULE_TAR_UTILS := preload("res://scenes/effects/joule_tar_utils.gd")

const DEFAULT_ATTACK: float = 40.0
const DEFAULT_HEALTH: float = 220.0
const DEFAULT_SPEED: float = 280.0
const DEFAULT_MAX_ENERGY: float = 100.0
const DEFAULT_ENERGY_REGEN: float = 8.0
const DEFAULT_PICKUP_RANGE: float = 150.0

@export_group("Joule Draw")
@export var draw_sample_spacing: float = 20.0
@export var draw_base_energy_cost: float = 0.0
@export var draw_energy_cost_per_step: float = 0.5
@export var draw_energy_cost_unit_px: float = 20.0
@export var draw_min_release_length: float = 24.0
@export var draw_close_threshold: float = 60.0
@export var tar_line_half_width: float = 34.0
@export var tar_line_visual_duration: float = 0.20

@export_group("Tar Debuff")
@export var tar_duration: float = 8.0
@export var tar_duration_max: float = 10.0
@export var tar_move_speed_multiplier: float = 0.7
@export var tar_skill_damage_taken_multiplier: float = 1.2
@export var tar_dot_ratio: float = 0.15
@export var tar_tick_interval: float = 0.5

@export_group("Closed Blast")
@export var closed_blast_delay: float = 0.5
@export var closed_blast_scratch_ratio: float = 0.5
@export var closed_blast_execute_ratio: float = 4.0
@export var closed_blast_push_distance: float = 150.0

@export_group("Dash")
@export var dash_cost: float = 5.0
@export var dash_distance: float = 400.0
@export var dash_speed: float = 2000.0
@export var dash_invuln_duration: float = 0.35

@export_group("E Skill")
@export var decoy_energy_cost: float = 30.0
@export var decoy_cooldown: float = 8.0
@export var decoy_pull_duration: float = 0.25
@export var decoy_scatter_radius: float = 20.0

@export_group("F Skill")
@export var phosphorus_energy_percent: float = 40.0
@export var phosphorus_vfx_duration: float = 0.65

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
var _pending_blasts: Array[Dictionary] = []
var _active_decoy_pulls: Array[Dictionary] = []
var _v2_bundle: Dictionary = {}

func _ready() -> void:
	if player_id.strip_edges().is_empty():
		player_id = "joule"
	super._ready()

	damage = DEFAULT_ATTACK
	energy = max_energy
	skill_e_cost = decoy_energy_cost
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
		draw_line.default_color = Color(1.0, 0.78, 0.28, 0.95)
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

	health = float(player_config.get("health", health if health > 0.0 else DEFAULT_HEALTH))
	max_energy = float(player_config.get("max_energy", max_energy if max_energy > 0.0 else DEFAULT_MAX_ENERGY))
	energy = float(player_config.get("initial_energy", max_energy))
	energy_regen = float(player_config.get("energy_regen", energy_regen if energy_regen > 0.0 else DEFAULT_ENERGY_REGEN))
	max_armor = int(player_config.get("max_armor", max_armor))
	base_speed = float(player_config.get("base_speed", base_speed if base_speed > 0.0 else DEFAULT_SPEED))
	speed = base_speed
	pickup_range = float(player_config.get("pickup_range", pickup_range if pickup_range > 0.0 else DEFAULT_PICKUP_RANGE))
	external_force_decay = float(player_config.get("external_force_decay", external_force_decay))
	knockback_scale = float(player_config.get("knockback_scale", knockback_scale))

	draw_sample_spacing = float(space_config.get("point_sample_step", draw_sample_spacing))
	draw_base_energy_cost = float(space_config.get("base_energy_cost", draw_base_energy_cost))
	draw_min_release_length = float(space_config.get("min_release_length", draw_min_release_length))
	var energy_mode: String = str(space_config.get("energy_mode", "per_unit")).strip_edges()
	var energy_cost_per_unit: float = float(space_config.get("energy_cost_per_unit", draw_energy_cost_per_step))
	draw_energy_cost_unit_px = max(1.0, float(space_config.get("energy_cost_unit_px", draw_energy_cost_unit_px)))
	if energy_mode == "per_unit":
		draw_energy_cost_per_step = energy_cost_per_unit * (draw_sample_spacing / draw_energy_cost_unit_px)
	else:
		draw_energy_cost_per_step = energy_cost_per_unit

	decoy_energy_cost = float(e_config.get("energy_cost", decoy_energy_cost))
	decoy_cooldown = float(e_config.get("cooldown", decoy_cooldown))
	decoy_scatter_radius = float(e_config.get("effect_radius", decoy_scatter_radius))
	decoy_pull_duration = float(e_config.get("effect_duration", decoy_pull_duration))
	skill_e_cost = decoy_energy_cost

	var f_cost_mode: String = str(f_config.get("energy_cost_mode", "percent_current")).strip_edges()
	if f_cost_mode in ["percent", "percent_current"]:
		phosphorus_energy_percent = float(f_config.get("energy_cost", phosphorus_energy_percent))
	phosphorus_vfx_duration = max(0.2, float(f_config.get("duration", phosphorus_vfx_duration)))

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
		_activate_magnetic_decoy()

	if Input.is_action_just_pressed("skill_f"):
		_activate_phosphorus_rain()

	if Input.is_action_pressed("click_right"):
		if not _is_drawing:
			_begin_drawing()
		_update_drawing_path()
	elif _is_drawing and Input.is_action_just_released("click_right"):
		_release_drawing_path()

func _process_subclass(delta: float) -> void:
	if _e_cooldown_remaining > 0.0:
		_e_cooldown_remaining = max(0.0, _e_cooldown_remaining - delta)
	_process_pending_blasts(delta)
	_process_decoy_pulls(delta)
	_refresh_invincible_meta()

func _begin_drawing() -> void:
	if draw_base_energy_cost > 0.0 and not consume_energy(draw_base_energy_cost):
		return
	_is_drawing = true
	_draw_points = PackedVector2Array()
	_draw_step_remainder = 0.0
	_draw_energy_spent = draw_base_energy_cost
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
	if not consume_energy(draw_energy_cost_per_step):
		return false
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

	var is_closed: bool = _determine_closed_shape(captured_points)
	var centroid: Vector2 = _resolve_centroid(captured_points, is_closed)
	var approx_area: float = _estimate_polygon_area(captured_points, is_closed)
	Global.cache_recent_draw_path(player_id, _packed_to_points(captured_points), is_closed)
	notify_space_draw_release({
		"source": "space",
		"skill_id": "draw_joule",
		"is_closed": is_closed,
		"points": _packed_to_points(captured_points),
		"centroid": centroid,
		"approx_area": approx_area,
		"draw_cost": _draw_energy_spent,
	})
	_draw_energy_spent = 0.0

	if is_closed and approx_area > 1.0:
		_queue_closed_blast(captured_points, centroid, approx_area)
	else:
		_apply_tar_line(captured_points)

func _determine_closed_shape(points: PackedVector2Array) -> bool:
	return _build_closed_polygon(points).size() >= 3

func _apply_tar_line(points: PackedVector2Array) -> void:
	_spawn_tar_line_vfx(points)
	for enemy_node: Node in get_tree().get_nodes_in_group("enemies"):
		if not (enemy_node is Enemy):
			continue
		var enemy: Enemy = enemy_node as Enemy
		if not is_instance_valid(enemy) or enemy.is_dead:
			continue
		if not _is_point_inside_polyline_width(enemy.global_position, points, tar_line_half_width):
			continue
		JOULE_TAR_UTILS.apply_tar(
			enemy,
			self,
			damage,
			false,
			tar_duration,
			tar_duration_max,
			tar_move_speed_multiplier,
			tar_skill_damage_taken_multiplier,
			tar_dot_ratio,
			tar_tick_interval
		)
		if enemy.has_method("set_flash_material"):
			enemy.set_flash_material()
	Global.spawn_floating_text(_average_point(points), "TAR", Color(1.0, 0.64, 0.20))

func _queue_closed_blast(points: PackedVector2Array, centroid: Vector2, approx_area: float) -> void:
	var polygon_points: PackedVector2Array = _build_closed_polygon(points)
	if polygon_points.size() < 3:
		_apply_tar_line(points)
		return
	var telegraph_root: Node2D = _spawn_closed_blast_telegraph(polygon_points)
	_pending_blasts.append({
		"timer": closed_blast_delay,
		"polygon": polygon_points,
		"centroid": centroid,
		"approx_area": approx_area,
		"telegraph": telegraph_root,
	})
	Global.spawn_floating_text(centroid, "ARM", Color(1.0, 0.52, 0.34))

func _process_pending_blasts(delta: float) -> void:
	if _pending_blasts.is_empty():
		return
	var remaining: Array[Dictionary] = []
	for blast in _pending_blasts:
		var next_timer: float = float(blast.get("timer", 0.0)) - delta
		if next_timer > 0.0:
			blast["timer"] = next_timer
			remaining.append(blast)
			continue
		_execute_closed_blast(blast)
	_pending_blasts = remaining

func _execute_closed_blast(blast: Dictionary) -> void:
	var polygon_variant: Variant = blast.get("polygon", PackedVector2Array())
	if not (polygon_variant is PackedVector2Array):
		return
	var polygon: PackedVector2Array = polygon_variant
	var centroid: Vector2 = blast.get("centroid", _average_point(polygon))
	var telegraph_node: Node = blast.get("telegraph", null)
	if is_instance_valid(telegraph_node):
		telegraph_node.queue_free()

	_spawn_closed_blast_vfx(polygon, centroid)
	for enemy_node: Node in get_tree().get_nodes_in_group("enemies"):
		if not (enemy_node is Enemy):
			continue
		var enemy: Enemy = enemy_node as Enemy
		if not is_instance_valid(enemy) or enemy.is_dead:
			continue
		if not Geometry2D.is_point_in_polygon(enemy.global_position, polygon):
			continue

		var has_tar: bool = JOULE_TAR_UTILS.has_tar(enemy)
		var has_tar_max: bool = JOULE_TAR_UTILS.has_tar_max(enemy)
		var damage_amount: float = damage * (closed_blast_execute_ratio if has_tar else closed_blast_scratch_ratio)
		enemy.apply_modifier_damage(
			damage_amount,
			self,
			{"kind": "joule_closed_blast", "empowered": has_tar}
		)
		if enemy.has_method("set_flash_material"):
			enemy.set_flash_material()
		if has_tar:
			var outward: Vector2 = enemy.global_position - centroid
			if outward.length_squared() <= 0.0001:
				outward = Vector2.RIGHT.rotated(randf() * TAU)
			enemy.global_position += outward.normalized() * closed_blast_push_distance
			if not has_tar_max:
				JOULE_TAR_UTILS.clear_tar(enemy)
			Global.spawn_floating_text(enemy.global_position, "EXECUTE", Color(1.0, 0.52, 0.28))
		else:
			Global.spawn_floating_text(enemy.global_position, "SCORCH", Color(1.0, 0.84, 0.54))

func _activate_magnetic_decoy() -> void:
	if _e_cooldown_remaining > 0.0:
		Global.spawn_floating_text(global_position, "CD", Color(0.9, 0.8, 0.4))
		return
	if not consume_energy(decoy_energy_cost):
		return
	_e_cooldown_remaining = decoy_cooldown

	var target_pos: Vector2 = get_global_mouse_position()
	var matched_count: int = 0
	_active_decoy_pulls.clear()
	for enemy_node: Node in get_tree().get_nodes_in_group("enemies"):
		if not (enemy_node is Enemy):
			continue
		var enemy: Enemy = enemy_node as Enemy
		if not is_instance_valid(enemy) or enemy.is_dead:
			continue
		if not JOULE_TAR_UTILS.has_tar(enemy):
			continue
		var scatter: Vector2 = Vector2.RIGHT.rotated(randf() * TAU) * randf_range(0.0, decoy_scatter_radius)
		_active_decoy_pulls.append({
			"enemy_ref": weakref(enemy),
			"start": enemy.global_position,
			"target": target_pos + scatter,
			"elapsed": 0.0,
			"duration": decoy_pull_duration,
		})
		enemy.apply_status("stun", decoy_pull_duration + 0.05, 0.0, 1, 1.0)
		matched_count += 1

	_spawn_decoy_vfx(target_pos)
	if matched_count <= 0:
		Global.spawn_floating_text(target_pos, "MISS", Color(1.0, 0.42, 0.4))
		SoundManager.play("ui_error")
	else:
		Global.spawn_floating_text(target_pos, "DECOY", Color(0.82, 0.94, 1.0))

func _process_decoy_pulls(delta: float) -> void:
	if _active_decoy_pulls.is_empty():
		return
	var remaining: Array[Dictionary] = []
	for pull in _active_decoy_pulls:
		var enemy_ref_variant: Variant = pull.get("enemy_ref", null)
		if enemy_ref_variant == null or not (enemy_ref_variant is WeakRef):
			continue
		var enemy: Enemy = (enemy_ref_variant as WeakRef).get_ref() as Enemy
		if enemy == null or not is_instance_valid(enemy) or enemy.is_dead:
			continue
		var duration: float = max(0.01, float(pull.get("duration", decoy_pull_duration)))
		var elapsed: float = min(duration, float(pull.get("elapsed", 0.0)) + delta)
		var start_pos: Vector2 = pull.get("start", enemy.global_position)
		var target_pos: Vector2 = pull.get("target", enemy.global_position)
		var weight: float = elapsed / duration
		enemy.global_position = start_pos.lerp(target_pos, weight)
		pull["elapsed"] = elapsed
		if enemy.has_method("set_flash_material"):
			enemy.set_flash_material()
		if elapsed < duration:
			remaining.append(pull)
	_active_decoy_pulls = remaining

func _activate_phosphorus_rain() -> void:
	var energy_cost: float = energy * (phosphorus_energy_percent / 100.0)
	if energy_cost <= 0.0:
		Global.spawn_floating_text(global_position, "NO ENERGY", Color(1.0, 0.42, 0.42))
		return
	if not consume_energy(energy_cost):
		return
	for enemy_node: Node in get_tree().get_nodes_in_group("enemies"):
		if not (enemy_node is Enemy):
			continue
		var enemy: Enemy = enemy_node as Enemy
		if not is_instance_valid(enemy) or enemy.is_dead:
			continue
		JOULE_TAR_UTILS.apply_tar(
			enemy,
			self,
			damage,
			true,
			tar_duration,
			tar_duration_max,
			tar_move_speed_multiplier,
			tar_skill_damage_taken_multiplier,
			tar_dot_ratio,
			tar_tick_interval
		)
		if enemy.has_method("set_flash_material"):
			enemy.set_flash_material()
	_spawn_phosphorus_rain_vfx()
	Global.spawn_floating_text(global_position, "PHOSPHORUS", Color(1.0, 0.72, 0.36))

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

func _refresh_draw_visual() -> void:
	if is_instance_valid(draw_line):
		draw_line.points = _draw_points

func _clear_draw_visual() -> void:
	if is_instance_valid(draw_line):
		draw_line.points = PackedVector2Array()

func _compute_path_length(points: PackedVector2Array) -> float:
	var total: float = 0.0
	for i in range(points.size() - 1):
		total += points[i].distance_to(points[i + 1])
	return total

func _resolve_centroid(points: PackedVector2Array, is_closed: bool) -> Vector2:
	if points.is_empty():
		return global_position
	if not is_closed:
		return _average_point(points)
	var polygon: PackedVector2Array = _build_closed_polygon(points)
	if polygon.size() < 3:
		return _average_point(points)
	var double_area: float = 0.0
	var centroid_accum: Vector2 = Vector2.ZERO
	for i in range(polygon.size()):
		var a: Vector2 = polygon[i]
		var b: Vector2 = polygon[(i + 1) % polygon.size()]
		var cross: float = a.x * b.y - b.x * a.y
		double_area += cross
		centroid_accum += (a + b) * cross
	if abs(double_area) <= 0.001:
		return _average_point(points)
	return centroid_accum / (3.0 * double_area)

func _estimate_polygon_area(points: PackedVector2Array, is_closed: bool) -> float:
	if not is_closed:
		return 0.0
	var polygon: PackedVector2Array = _build_closed_polygon(points)
	if polygon.size() < 3:
		return 0.0
	var double_area: float = 0.0
	for i in range(polygon.size()):
		var a: Vector2 = polygon[i]
		var b: Vector2 = polygon[(i + 1) % polygon.size()]
		double_area += a.x * b.y - b.x * a.y
	return abs(double_area) * 0.5

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
	var result: Dictionary = {
		"found": false,
		"polygon": PackedVector2Array(),
	}
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
			if intersection_variant == null:
				continue
			if not (intersection_variant is Vector2):
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

func _is_point_inside_polyline_width(point: Vector2, points: PackedVector2Array, half_width: float) -> bool:
	if points.size() < 2:
		return false
	var half_width_sq: float = half_width * half_width
	for i in range(points.size() - 1):
		var closest: Vector2 = Geometry2D.get_closest_point_to_segment(point, points[i], points[i + 1])
		if point.distance_squared_to(closest) <= half_width_sq:
			return true
	return false

func _spawn_tar_line_vfx(points: PackedVector2Array) -> void:
	if points.size() < 2:
		return
	var root: Node2D = Node2D.new()
	root.top_level = true
	root.z_index = 31
	get_tree().current_scene.add_child(root)

	var spray_line: Line2D = Line2D.new()
	spray_line.points = points
	spray_line.width = 18.0
	spray_line.default_color = Color(1.0, 0.62, 0.12, 0.56)
	spray_line.begin_cap_mode = Line2D.LINE_CAP_ROUND
	spray_line.end_cap_mode = Line2D.LINE_CAP_ROUND
	spray_line.joint_mode = Line2D.LINE_JOINT_ROUND
	spray_line.antialiased = true
	root.add_child(spray_line)

	var core_line: Line2D = Line2D.new()
	core_line.points = points
	core_line.width = 8.0
	core_line.default_color = Color(1.0, 0.86, 0.48, 0.90)
	core_line.begin_cap_mode = Line2D.LINE_CAP_ROUND
	core_line.end_cap_mode = Line2D.LINE_CAP_ROUND
	core_line.joint_mode = Line2D.LINE_JOINT_ROUND
	core_line.antialiased = true
	root.add_child(core_line)

	var tween: Tween = root.create_tween()
	tween.set_parallel(true)
	tween.tween_property(spray_line, "modulate:a", 0.0, tar_line_visual_duration)
	tween.tween_property(core_line, "modulate:a", 0.0, tar_line_visual_duration)
	tween.finished.connect(root.queue_free)

func _spawn_closed_blast_telegraph(polygon: PackedVector2Array) -> Node2D:
	var root: Node2D = Node2D.new()
	root.top_level = true
	root.z_index = 30
	get_tree().current_scene.add_child(root)

	var fill: Polygon2D = Polygon2D.new()
	fill.polygon = polygon
	fill.color = Color(1.0, 0.18, 0.12, 0.24)
	root.add_child(fill)

	var border: Line2D = Line2D.new()
	border.closed = true
	border.points = polygon
	border.width = 8.0
	border.default_color = Color(1.0, 0.42, 0.22, 0.72)
	border.antialiased = true
	root.add_child(border)

	var tween: Tween = root.create_tween()
	tween.set_loops()
	tween.tween_property(fill, "modulate:a", 0.08, 0.12)
	tween.tween_property(fill, "modulate:a", 0.28, 0.12)
	return root

func _spawn_closed_blast_vfx(polygon: PackedVector2Array, centroid: Vector2) -> void:
	var root: Node2D = Node2D.new()
	root.top_level = true
	root.z_index = 32
	get_tree().current_scene.add_child(root)

	var fill: Polygon2D = Polygon2D.new()
	fill.polygon = polygon
	fill.color = Color(1.0, 0.42, 0.22, 0.42)
	root.add_child(fill)

	var border: Line2D = Line2D.new()
	border.closed = true
	border.points = polygon
	border.width = 12.0
	border.default_color = Color(1.0, 0.84, 0.58, 0.86)
	border.antialiased = true
	root.add_child(border)

	var ring: Line2D = Line2D.new()
	ring.top_level = true
	ring.closed = true
	ring.width = 8.0
	ring.default_color = Color(1.0, 0.96, 0.82, 0.82)
	ring.antialiased = true
	var ring_points: PackedVector2Array = PackedVector2Array()
	for i in range(25):
		var angle: float = (float(i) / 24.0) * TAU
		ring_points.append(centroid + Vector2.RIGHT.rotated(angle) * 28.0)
	ring.points = ring_points
	get_tree().current_scene.add_child(ring)

	var tween: Tween = root.create_tween()
	tween.set_parallel(true)
	tween.tween_property(fill, "modulate:a", 0.0, 0.22)
	tween.tween_property(border, "modulate:a", 0.0, 0.22)
	tween.finished.connect(root.queue_free)

	var ring_tween: Tween = ring.create_tween()
	ring_tween.set_parallel(true)
	ring_tween.tween_property(ring, "scale", Vector2(2.4, 2.4), 0.18)
	ring_tween.tween_property(ring, "modulate:a", 0.0, 0.18)
	ring_tween.finished.connect(ring.queue_free)

func _spawn_decoy_vfx(center: Vector2) -> void:
	var ring: Line2D = Line2D.new()
	ring.top_level = true
	ring.closed = true
	ring.width = 8.0
	ring.default_color = Color(0.76, 0.90, 1.0, 0.84)
	ring.antialiased = true
	var points: PackedVector2Array = PackedVector2Array()
	for i in range(25):
		var angle: float = (float(i) / 24.0) * TAU
		points.append(center + Vector2.RIGHT.rotated(angle) * max(18.0, decoy_scatter_radius))
	ring.points = points
	get_tree().current_scene.add_child(ring)
	var tween: Tween = ring.create_tween()
	tween.set_parallel(true)
	tween.tween_property(ring, "scale", Vector2(0.25, 0.25), 0.16)
	tween.tween_property(ring, "modulate:a", 0.0, 0.16)
	tween.finished.connect(ring.queue_free)

func _spawn_phosphorus_rain_vfx() -> void:
	var root: Node2D = Node2D.new()
	root.top_level = true
	root.z_index = 35
	get_tree().current_scene.add_child(root)
	for i in range(12):
		var streak: Line2D = Line2D.new()
		streak.antialiased = true
		streak.width = randf_range(4.0, 7.0)
		streak.default_color = Color(1.0, 0.78, 0.38, 0.75)
		var start: Vector2 = global_position + Vector2(randf_range(-420.0, 420.0), randf_range(-320.0, -180.0))
		var end: Vector2 = start + Vector2(randf_range(-18.0, 18.0), randf_range(180.0, 320.0))
		streak.points = PackedVector2Array([start, end])
		root.add_child(streak)
	var tween: Tween = root.create_tween()
	tween.set_parallel(true)
	tween.tween_property(root, "modulate:a", 0.0, phosphorus_vfx_duration)
	tween.finished.connect(root.queue_free)
