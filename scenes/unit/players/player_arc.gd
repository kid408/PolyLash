extends PlayerBase
class_name PlayerArc

const DEFAULT_ATTACK: float = 40.0
const DEFAULT_HEALTH: float = 180.0
const DEFAULT_SPEED: float = 300.0
const DEFAULT_MAX_ENERGY: float = 100.0
const DEFAULT_ENERGY_REGEN: float = 10.0
const DEFAULT_PICKUP_RANGE: float = 150.0

enum TravelMode {
	NONE,
	OPEN,
	CLOSED,
}

@export_group("Arc Draw")
@export var draw_sample_spacing: float = 12.0
@export var draw_close_threshold: float = 48.0
@export var draw_min_release_length: float = 8.0
@export var draw_start_max_distance: float = 250.0
@export var draw_deposit_cost: float = 5.0
@export var draw_deposit_refund_length: float = 50.0
@export var draw_length_cost_unit: float = 25.0
@export var travel_cut_half_width: float = 34.0

@export_group("Dash")
@export var dash_cost: float = 5.0
@export var dash_distance: float = 400.0
@export var dash_speed: float = 2000.0
@export var dash_invuln_duration: float = 0.35

@export_group("Traversal")
@export var traversal_speed: float = 2500.0
@export var traversal_damage_ratio: float = 3.0
@export var traversal_overdrive_damage_ratio: float = 6.0
@export var orbit_loops_per_second: float = 2.0
@export var orbit_damage_ratio: float = 0.8
@export var orbit_overdrive_damage_ratio: float = 1.6
@export var orbit_energy_drain_per_second: float = 15.0
@export var open_hit_spacing: float = 48.0
@export var orbit_hit_spacing: float = 18.0
@export var landing_lock_duration: float = 0.10
@export var traversal_damage_taken_multiplier: float = 0.20
@export var traversal_interrupt_stun_duration: float = 0.5
@export var traversal_interrupt_probe_radius: float = 46.0

@export_group("E Skill")
@export var drift_energy_cost: float = 25.0
@export var drift_cooldown: float = 6.0
@export var drift_slide_distance: float = 100.0
@export var drift_slide_duration: float = 0.12
@export var drift_blast_radius: float = 140.0
@export var drift_blast_damage_ratio: float = 2.5
@export var drift_blast_knockback: float = 180.0

@export_group("F Skill")
@export var overdrive_energy_percent: float = 40.0
@export var overdrive_duration: float = 6.0

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
var _deposit_paid: bool = false

var _travel_mode: int = TravelMode.NONE
var _travel_points: PackedVector2Array = PackedVector2Array()
var _travel_cumulative_lengths: Array[float] = []
var _travel_total_length: float = 0.0
var _travel_progress: float = 0.0
var _travel_total_progress: float = 0.0
var _travel_tangent: Vector2 = Vector2.RIGHT
var _travel_hit_progress_by_enemy: Dictionary = {}

var _post_travel_lock_timer: float = 0.0
var _drift_slide_timer: float = 0.0
var _drift_slide_start: Vector2 = Vector2.ZERO
var _drift_slide_end: Vector2 = Vector2.ZERO
var _travel_crash_stun_timer: float = 0.0

var _e_cooldown_remaining: float = 0.0
var _overdrive_timer: float = 0.0
var _v2_bundle: Dictionary = {}

func _ready() -> void:
	if player_id.strip_edges().is_empty():
		player_id = "arc"
	super._ready()

	damage = DEFAULT_ATTACK
	energy = max_energy
	skill_e_cost = drift_energy_cost
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
		draw_line.default_color = Color(0.84, 0.98, 1.0, 0.96)
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

	drift_energy_cost = float(e_config.get("energy_cost", drift_energy_cost))
	drift_cooldown = float(e_config.get("cooldown", drift_cooldown))
	drift_blast_radius = float(e_config.get("effect_radius", drift_blast_radius))
	drift_slide_duration = max(0.05, float(e_config.get("effect_duration", drift_slide_duration)))
	skill_e_cost = drift_energy_cost

	var f_cost_mode: String = str(f_config.get("energy_cost_mode", "percent_current")).strip_edges()
	if f_cost_mode in ["percent", "percent_current"]:
		overdrive_energy_percent = float(f_config.get("energy_cost", overdrive_energy_percent))
	overdrive_duration = max(0.1, float(f_config.get("duration", overdrive_duration)))

	damage = DEFAULT_ATTACK
	close_threshold = draw_close_threshold

func _load_weapons_from_config() -> void:
	super._load_weapons_from_config()

func _load_ultimate_skill() -> void:
	ultimate_skill = null

func _auto_create_skill_manager() -> void:
	pass

func _handle_input(delta: float) -> void:
	move_dir = Input.get_vector("move_left", "move_right", "move_up", "move_down")

	if _travel_active():
		_update_travel(delta)
	elif _is_dashing:
		_update_dash(delta)
	elif _drift_slide_timer > 0.0:
		_update_drift_slide(delta)
	elif _travel_crash_stun_timer > 0.0:
		pass
	elif _post_travel_lock_timer <= 0.0 and can_move():
		position += move_dir * get_effective_move_speed() * delta

	if Input.is_action_just_pressed("tactical_reject"):
		_try_activate_tactical_reject()

	if _travel_crash_stun_timer > 0.0:
		return

	if Input.is_action_just_pressed("skill_e"):
		_activate_drift_eject()

	if Input.is_action_just_pressed("skill_f"):
		_activate_matrix_overdrive()

	if _travel_mode == TravelMode.CLOSED and Input.is_action_just_pressed("click_right"):
		_end_travel(true)
		Global.spawn_floating_text(global_position, "EJECT", Color(0.74, 0.96, 1.0))
		return

	if _travel_active() or _drift_slide_timer > 0.0 or _post_travel_lock_timer > 0.0:
		return

	if Input.is_action_just_pressed("click_left") and not _is_drawing:
		_try_start_dash()

	if Input.is_action_just_pressed("click_right") and not _is_drawing:
		_begin_drawing()

	if Input.is_action_pressed("click_right") and _is_drawing:
		_update_drawing_path()
	elif _is_drawing and Input.is_action_just_released("click_right"):
		_release_drawing_path()

func _process_subclass(delta: float) -> void:
	if _e_cooldown_remaining > 0.0:
		_e_cooldown_remaining = max(0.0, _e_cooldown_remaining - delta)
	if _post_travel_lock_timer > 0.0:
		_post_travel_lock_timer = max(0.0, _post_travel_lock_timer - delta)
	if _travel_crash_stun_timer > 0.0:
		_travel_crash_stun_timer = max(0.0, _travel_crash_stun_timer - delta)
	if _overdrive_timer > 0.0:
		_overdrive_timer = max(0.0, _overdrive_timer - delta)
	_refresh_invincible_meta()

func _begin_drawing() -> void:
	var start_point: Vector2 = get_global_mouse_position()
	if global_position.distance_to(start_point) > draw_start_max_distance:
		SoundManager.play("ui_error")
		Global.spawn_floating_text(start_point, "超出距离", Color(1.0, 0.52, 0.28))
		return

	if not _is_overdrive_active() and not consume_energy(draw_deposit_cost):
		return

	_is_drawing = true
	_draw_points = PackedVector2Array()
	_draw_step_remainder = 0.0
	_deposit_paid = not _is_overdrive_active()
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
	var remaining_distance: float = distance_to_target
	var cursor: Vector2 = last_point
	var next_step: float = max(0.001, draw_sample_spacing - _draw_step_remainder)

	while remaining_distance >= next_step:
		var new_point: Vector2 = cursor + direction * next_step
		_maybe_emit_prism_stun(cursor, new_point)
		_draw_points.append(new_point)
		cursor = new_point
		remaining_distance -= next_step
		next_step = draw_sample_spacing

	_draw_step_remainder = draw_sample_spacing - remaining_distance
	_refresh_draw_visual()

func _release_drawing_path() -> void:
	if not _is_drawing:
		return

	var final_point: Vector2 = get_global_mouse_position()
	var last_point: Vector2 = _draw_points[_draw_points.size() - 1]
	if last_point.distance_to(final_point) > 1.0:
		_maybe_emit_prism_stun(last_point, final_point)
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

	var forced_closure: Dictionary = BondManager.apply_forced_closure(self, captured_points) if BondManager != null and BondManager.has_method("apply_forced_closure") else {}
	if bool(forced_closure.get("forced_closed", false)):
		captured_points = forced_closure.get("points", captured_points)
	var is_closed: bool = _determine_closed_shape(captured_points)
	var draw_cost: float = 0.0
	if not _is_overdrive_active() and total_length >= draw_deposit_refund_length:
		if _deposit_paid:
			energy = min(max_energy, energy + draw_deposit_cost)
			update_ui_signals()
		draw_cost = total_length / draw_length_cost_unit
		if draw_cost > 0.0 and not consume_energy(draw_cost):
			return

	var release_points: PackedVector2Array = captured_points.duplicate()
	if is_closed:
		var closed_polygon: PackedVector2Array = _build_closed_polygon(captured_points)
		if closed_polygon.size() < 3:
			is_closed = false
		else:
			release_points = closed_polygon.duplicate()
			release_points.append(closed_polygon[0])

	var payload_cost: float = draw_cost
	if payload_cost <= 0.0 and _deposit_paid:
		payload_cost = draw_deposit_cost
	notify_space_draw_release({
		"source": "space",
		"skill_id": "draw_arc",
		"is_closed": is_closed,
		"points": _packed_to_points(release_points),
		"centroid": _resolve_centroid(release_points, is_closed),
		"approx_area": _estimate_polygon_area(release_points, is_closed),
		"draw_cost": payload_cost,
		"resolved_damage": damage * (_get_open_damage_ratio() if not is_closed else _get_closed_damage_ratio()),
	})
	_spawn_release_trace(release_points, is_closed)
	_begin_travel(release_points, is_closed)

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
	dash_started.emit(player_id, global_position, _dash_direction)
	notify_front_dash_used({
		"start": global_position,
		"end": global_position + _dash_direction * dash_distance,
		"direction": _dash_direction,
		"distance": dash_distance,
	})
	_refresh_invincible_meta()

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

func _begin_travel(points: PackedVector2Array, is_closed: bool) -> void:
	_travel_mode = TravelMode.CLOSED if is_closed else TravelMode.OPEN
	_travel_points = points.duplicate()
	_travel_cumulative_lengths = _build_cumulative_lengths(_travel_points)
	_travel_total_length = 0.0
	if not _travel_cumulative_lengths.is_empty():
		_travel_total_length = _travel_cumulative_lengths[_travel_cumulative_lengths.size() - 1]
	if _travel_total_length <= 0.001:
		_end_travel(false)
		return

	_travel_progress = 0.0
	_travel_total_progress = 0.0
	_travel_hit_progress_by_enemy.clear()
	var sample: Dictionary = _sample_travel_path(0.0)
	global_position = sample.get("position", points[0])
	_travel_tangent = sample.get("tangent", Vector2.RIGHT)
	_post_travel_lock_timer = 0.0
	_refresh_invincible_meta()

func _update_travel(delta: float) -> void:
	if not _travel_active():
		return
	var previous_position: Vector2 = global_position
	var step_distance: float = traversal_speed * delta
	if _travel_mode == TravelMode.CLOSED:
		step_distance = _travel_total_length * orbit_loops_per_second * delta
		if not _is_overdrive_active() and not _consume_orbit_drain(delta):
			_end_travel(true)
			return

	_travel_total_progress += step_distance
	if _travel_mode == TravelMode.OPEN:
		_travel_progress = min(_travel_total_length, _travel_progress + step_distance)
	else:
		_travel_progress = fposmod(_travel_progress + step_distance, _travel_total_length)

	var sample: Dictionary = _sample_travel_path(_travel_progress)
	var new_position: Vector2 = sample.get("position", previous_position)
	_travel_tangent = sample.get("tangent", _travel_tangent)
	global_position = new_position
	var interrupt_info: Dictionary = _check_travel_interrupt(previous_position, new_position)
	if bool(interrupt_info.get("hit", false)):
		_interrupt_travel(interrupt_info.get("position", new_position))
		return
	_apply_travel_damage(previous_position, new_position)

	if _travel_mode == TravelMode.OPEN and _travel_progress >= _travel_total_length - 0.001:
		_end_travel(true)

func _end_travel(apply_lock: bool) -> void:
	_travel_mode = TravelMode.NONE
	_travel_points = PackedVector2Array()
	_travel_cumulative_lengths.clear()
	_travel_total_length = 0.0
	_travel_progress = 0.0
	_travel_total_progress = 0.0
	_travel_hit_progress_by_enemy.clear()
	if apply_lock:
		_post_travel_lock_timer = landing_lock_duration
	_refresh_invincible_meta()

func _travel_active() -> bool:
	return _travel_mode != TravelMode.NONE

func _consume_orbit_drain(delta: float) -> bool:
	var drain_amount: float = orbit_energy_drain_per_second * delta
	if energy >= drain_amount:
		energy -= drain_amount
		update_ui_signals()
		return true
	energy = 0.0
	update_ui_signals()
	return false

func _apply_travel_damage(from_pos: Vector2, to_pos: Vector2) -> void:
	if from_pos.distance_to(to_pos) <= 0.001:
		return
	var damage_ratio: float = _get_open_damage_ratio()
	var min_spacing: float = open_hit_spacing
	if _travel_mode == TravelMode.CLOSED:
		damage_ratio = _get_closed_damage_ratio()
		min_spacing = orbit_hit_spacing
	var damage_amount: float = damage * damage_ratio

	for enemy_node: Node in get_tree().get_nodes_in_group("enemies"):
		if not (enemy_node is Enemy):
			continue
		var enemy: Enemy = enemy_node as Enemy
		if not is_instance_valid(enemy) or enemy.is_dead:
			continue
		var closest: Vector2 = Geometry2D.get_closest_point_to_segment(enemy.global_position, from_pos, to_pos)
		if enemy.global_position.distance_to(closest) > travel_cut_half_width:
			continue
		var enemy_key: int = enemy.get_instance_id()
		var last_progress: float = float(_travel_hit_progress_by_enemy.get(enemy_key, -999999.0))
		if _travel_total_progress - last_progress < min_spacing:
			continue
		_travel_hit_progress_by_enemy[enemy_key] = _travel_total_progress
		enemy.apply_modifier_damage(damage_amount, self, {
			"kind": "arc_travel",
			"damage_type": "DMG_DIRECT",
			"skill_slot": "q",
			"space_skill_mode": "open",
		})
		if enemy.has_method("set_flash_material"):
			enemy.set_flash_material()
		Global.spawn_floating_text(enemy.global_position, "ARC", Color(0.78, 0.96, 1.0))

func _activate_drift_eject() -> void:
	if not _travel_active():
		Global.spawn_floating_text(global_position, "MISS", Color(1.0, 0.42, 0.42))
		return
	if _e_cooldown_remaining > 0.0:
		Global.spawn_floating_text(global_position, "CD", Color(0.9, 0.8, 0.4))
		return
	if not consume_energy(drift_energy_cost):
		return
	_e_cooldown_remaining = drift_cooldown
	notify_front_skill_cast("e", {"skill_id": "e_arc"})

	var blast_origin: Vector2 = global_position
	var tangent: Vector2 = _travel_tangent
	_end_travel(false)
	_execute_drift_blast(blast_origin)
	_start_drift_slide(blast_origin, tangent)
	Global.spawn_floating_text(blast_origin, "DRIFT", Color(0.76, 0.98, 1.0))

func _execute_drift_blast(center: Vector2) -> void:
	var root: Node2D = Node2D.new()
	root.top_level = true
	root.z_index = 33
	get_tree().current_scene.add_child(root)

	var ring: Line2D = Line2D.new()
	ring.closed = true
	ring.width = 10.0
	ring.default_color = Color(0.64, 0.94, 1.0, 0.84)
	ring.antialiased = true
	var points: PackedVector2Array = PackedVector2Array()
	for i: int in range(25):
		var angle: float = (float(i) / 24.0) * TAU
		points.append(center + Vector2.RIGHT.rotated(angle) * drift_blast_radius)
	ring.points = points
	root.add_child(ring)
	var tween: Tween = root.create_tween()
	tween.set_parallel(true)
	tween.tween_property(ring, "scale", Vector2(1.18, 1.18), 0.14)
	tween.tween_property(ring, "modulate:a", 0.0, 0.14)
	tween.finished.connect(root.queue_free)

	var hit_enemies: Array = []
	for enemy_node: Node in get_tree().get_nodes_in_group("enemies"):
		if not (enemy_node is Enemy):
			continue
		var enemy: Enemy = enemy_node as Enemy
		if not is_instance_valid(enemy) or enemy.is_dead:
			continue
		var distance_to_center: float = enemy.global_position.distance_to(center)
		if distance_to_center > drift_blast_radius:
			continue
		enemy.apply_modifier_damage(damage * drift_blast_damage_ratio, self, {
			"kind": "arc_drift_blast",
			"damage_type": "DMG_AOE",
			"skill_slot": "e",
		})
		var push_dir: Vector2 = enemy.global_position - center
		if push_dir.length_squared() <= 0.0001:
			push_dir = Vector2.RIGHT.rotated(randf() * TAU)
		enemy.global_position += push_dir.normalized() * drift_blast_knockback
		if enemy.has_method("set_flash_material"):
			enemy.set_flash_material()
		hit_enemies.append(enemy)

	if not hit_enemies.is_empty():
		notify_front_skill_damage("e", hit_enemies, {
			"skill_id": "e_arc",
			"source": "arc_drift_blast",
		})

func _start_drift_slide(start_pos: Vector2, tangent: Vector2) -> void:
	var slide_direction: Vector2 = tangent.normalized()
	if slide_direction.length_squared() <= 0.0001:
		slide_direction = Vector2.RIGHT
	_drift_slide_start = start_pos
	_drift_slide_end = start_pos + slide_direction * drift_slide_distance
	_drift_slide_timer = drift_slide_duration

func _update_drift_slide(delta: float) -> void:
	if _drift_slide_timer <= 0.0:
		return
	_drift_slide_timer = max(0.0, _drift_slide_timer - delta)
	var elapsed_ratio: float = 1.0 - (_drift_slide_timer / max(0.001, drift_slide_duration))
	global_position = _drift_slide_start.lerp(_drift_slide_end, elapsed_ratio)
	if _drift_slide_timer <= 0.0:
		_post_travel_lock_timer = landing_lock_duration

func _activate_matrix_overdrive() -> void:
	var energy_cost: float = energy * (overdrive_energy_percent / 100.0)
	if energy_cost <= 0.0:
		Global.spawn_floating_text(global_position, "NO ENERGY", Color(1.0, 0.42, 0.42))
		return
	if not consume_energy(energy_cost):
		return
	_overdrive_timer = overdrive_duration
	notify_front_skill_cast("f", {"skill_id": "f_arc"})
	Global.spawn_floating_text(global_position, "OVERDRIVE", Color(0.62, 0.94, 1.0))

func _is_overdrive_active() -> bool:
	return _overdrive_timer > 0.0

func _get_open_damage_ratio() -> float:
	return traversal_overdrive_damage_ratio if _is_overdrive_active() else traversal_damage_ratio

func _get_closed_damage_ratio() -> float:
	return orbit_overdrive_damage_ratio if _is_overdrive_active() else orbit_damage_ratio

func _refresh_invincible_meta() -> void:
	var should_be_invincible: bool = _dash_invulnerable
	if should_be_invincible:
		set_meta("buff_invincible", true)
	elif has_meta("buff_invincible"):
		remove_meta("buff_invincible")

func _check_travel_interrupt(from_pos: Vector2, to_pos: Vector2) -> Dictionary:
	if from_pos.distance_to(to_pos) <= 0.001:
		return {"hit": false}
	var world_2d: World2D = get_world_2d()
	if world_2d != null:
		var query := PhysicsRayQueryParameters2D.create(from_pos, to_pos)
		query.collide_with_bodies = true
		query.collide_with_areas = false
		var result: Dictionary = world_2d.direct_space_state.intersect_ray(query)
		if not result.is_empty():
			var collider: Variant = result.get("collider", null)
			if collider is StaticBody2D:
				return {
					"hit": true,
					"position": Vector2(result.get("position", to_pos)),
				}
	for enemy_node: Node in get_tree().get_nodes_in_group("enemies"):
		if not (enemy_node is Enemy):
			continue
		var enemy: Enemy = enemy_node as Enemy
		if not is_instance_valid(enemy) or enemy.is_dead:
			continue
		if not enemy.is_tactical_reject_elite_immune() and not enemy.is_boss_enemy():
			continue
		var closest: Vector2 = Geometry2D.get_closest_point_to_segment(enemy.global_position, from_pos, to_pos)
		if enemy.global_position.distance_to(closest) > traversal_interrupt_probe_radius:
			continue
		return {
			"hit": true,
			"position": closest,
		}
	return {"hit": false}

func _interrupt_travel(crash_position: Vector2) -> void:
	global_position = crash_position
	_end_travel(false)
	_drift_slide_timer = 0.0
	_travel_crash_stun_timer = traversal_interrupt_stun_duration
	Global.spawn_floating_text(global_position, "CRASH", Color(1.0, 0.48, 0.32))
	set_flash_material()

func get_incoming_damage_multiplier() -> float:
	var base_multiplier: float = super.get_incoming_damage_multiplier()
	if _travel_active() or _drift_slide_timer > 0.0:
		return base_multiplier * traversal_damage_taken_multiplier
	return base_multiplier

func apply_knockback_self(force: Vector2) -> void:
	if _travel_active() or _drift_slide_timer > 0.0:
		return
	super.apply_knockback_self(force)

func _fail_short_circuit(text: String) -> void:
	_is_drawing = false
	_draw_points = PackedVector2Array()
	_draw_step_remainder = 0.0
	_clear_draw_visual()
	SoundManager.play("ui_error")
	Global.spawn_floating_text(global_position, text, Color(1.0, 0.38, 0.3))

func _maybe_emit_prism_stun(start_point: Vector2, end_point: Vector2) -> void:
	if BondManager == null or not BondManager.has_method("on_draw_self_intersection"):
		return
	if _draw_points.size() < 3:
		return
	for i: int in range(_draw_points.size() - 2):
		var a_start: Vector2 = _draw_points[i]
		var a_end: Vector2 = _draw_points[i + 1]
		var intersection_variant: Variant = Geometry2D.segment_intersects_segment(a_start, a_end, start_point, end_point)
		if intersection_variant == null or not (intersection_variant is Vector2):
			continue
		BondManager.on_draw_self_intersection(self, intersection_variant)
		return

func _determine_closed_shape(points: PackedVector2Array) -> bool:
	return _build_closed_polygon(points).size() >= 3

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

func _compute_path_length(points: PackedVector2Array) -> float:
	var total: float = 0.0
	for i: int in range(points.size() - 1):
		total += points[i].distance_to(points[i + 1])
	return total

func _build_cumulative_lengths(points: PackedVector2Array) -> Array[float]:
	var cumulative: Array[float] = []
	var total: float = 0.0
	cumulative.append(0.0)
	for i: int in range(points.size() - 1):
		total += points[i].distance_to(points[i + 1])
		cumulative.append(total)
	return cumulative

func _sample_travel_path(distance_along: float) -> Dictionary:
	var result: Dictionary = {
		"position": global_position,
		"tangent": _travel_tangent,
	}
	if _travel_points.size() < 2 or _travel_cumulative_lengths.is_empty():
		return result
	var clamped_distance: float = clamp(distance_along, 0.0, _travel_total_length)
	for i: int in range(_travel_points.size() - 1):
		var seg_start_distance: float = _travel_cumulative_lengths[i]
		var seg_end_distance: float = _travel_cumulative_lengths[i + 1]
		if clamped_distance > seg_end_distance and i < _travel_points.size() - 2:
			continue
		var a: Vector2 = _travel_points[i]
		var b: Vector2 = _travel_points[i + 1]
		var segment_length: float = max(0.001, seg_end_distance - seg_start_distance)
		var weight: float = clamp((clamped_distance - seg_start_distance) / segment_length, 0.0, 1.0)
		result["position"] = a.lerp(b, weight)
		var tangent: Vector2 = (b - a).normalized()
		result["tangent"] = tangent if tangent.length_squared() > 0.0 else _travel_tangent
		return result
	return result

func _resolve_centroid(points: PackedVector2Array, is_closed: bool) -> Vector2:
	if points.is_empty():
		return global_position
	if not is_closed:
		return _average_point(points)
	var polygon: PackedVector2Array = points.duplicate()
	if polygon.size() >= 2 and polygon[0].distance_to(polygon[polygon.size() - 1]) <= 1.0:
		polygon.remove_at(polygon.size() - 1)
	if polygon.size() < 3:
		return _average_point(points)
	var double_area: float = 0.0
	var centroid_accum: Vector2 = Vector2.ZERO
	for i: int in range(polygon.size()):
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
	var polygon: PackedVector2Array = points.duplicate()
	if polygon.size() >= 2 and polygon[0].distance_to(polygon[polygon.size() - 1]) <= 1.0:
		polygon.remove_at(polygon.size() - 1)
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

func _spawn_release_trace(points: PackedVector2Array, is_closed: bool) -> void:
	var root: Node2D = Node2D.new()
	root.top_level = true
	root.z_index = 30
	get_tree().current_scene.add_child(root)

	var outer_line: Line2D = Line2D.new()
	outer_line.points = points
	outer_line.closed = is_closed
	outer_line.width = 18.0
	outer_line.default_color = Color(0.42, 0.86, 1.0, 0.34)
	outer_line.begin_cap_mode = Line2D.LINE_CAP_ROUND
	outer_line.end_cap_mode = Line2D.LINE_CAP_ROUND
	outer_line.joint_mode = Line2D.LINE_JOINT_ROUND
	outer_line.antialiased = true
	root.add_child(outer_line)

	var inner_line: Line2D = Line2D.new()
	inner_line.points = points
	inner_line.closed = is_closed
	inner_line.width = 8.0
	inner_line.default_color = Color(0.94, 0.99, 1.0, 0.96)
	inner_line.begin_cap_mode = Line2D.LINE_CAP_ROUND
	inner_line.end_cap_mode = Line2D.LINE_CAP_ROUND
	inner_line.joint_mode = Line2D.LINE_JOINT_ROUND
	inner_line.antialiased = true
	root.add_child(inner_line)

	var tween: Tween = root.create_tween()
	tween.set_parallel(true)
	tween.tween_property(outer_line, "modulate:a", 0.0, 0.12)
	tween.tween_property(inner_line, "modulate:a", 0.0, 0.10)
	tween.finished.connect(root.queue_free)

func _refresh_draw_visual() -> void:
	if is_instance_valid(draw_line):
		draw_line.points = _draw_points
		draw_line.modulate = Color(0.72, 0.98, 1.0, 1.0) if _is_overdrive_active() else Color(1.0, 1.0, 1.0, 1.0)

func _clear_draw_visual() -> void:
	if is_instance_valid(draw_line):
		draw_line.points = PackedVector2Array()
