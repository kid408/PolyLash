extends PlayerBase
class_name PlayerPhalanx

const PHALANX_BARRIER_SCRIPT: Script = preload("res://scenes/effects/phalanx_barrier.gd")
const PHALANX_PINBALL_ARENA_SCRIPT: Script = preload("res://scenes/effects/phalanx_pinball_arena.gd")

const DEFAULT_ATTACK: float = 40.0
const DEFAULT_HEALTH: float = 260.0
const DEFAULT_SPEED: float = 270.0
const DEFAULT_MAX_ENERGY: float = 100.0
const DEFAULT_ENERGY_REGEN: float = 8.0
const DEFAULT_PICKUP_RANGE: float = 150.0

@export_group("Phalanx Draw")
@export var draw_sample_spacing: float = 10.0
@export var draw_min_release_length: float = 24.0
@export var draw_close_threshold: float = 60.0
@export var draw_base_energy_cost: float = 0.0
@export var draw_energy_cost_per_step: float = 0.25
@export var draw_energy_cost_unit_px: float = 40.0
@export var barrier_lifetime: float = 6.0
@export var barrier_half_width: float = 18.0
@export var pinball_arena_lifetime: float = 4.0
@export var pinball_reference_radius: float = 120.0
@export var pinball_min_damage_ratio: float = 0.75
@export var pinball_max_damage_ratio: float = 1.35
@export var pinball_max_bonus_bounces: int = 3

@export_group("Barrier Bounce")
@export var barrier_bounce_speed: float = 1200.0
@export var barrier_bounce_distance: float = 150.0
@export var barrier_bounce_duration: float = 0.25
@export var barrier_micro_stun_duration: float = 0.15
@export var barrier_durability_divisor: float = 40.0
@export var barrier_collision_damage_ratio: float = 1.0
@export var sweep_launch_speed: float = 2000.0
@export var sweep_launch_distance: float = 400.0
@export var sweep_bounce_distance: float = 800.0
@export var sweep_ballistic_collision_damage_ratio: float = 3.5

@export_group("Dash")
@export var dash_cost: float = 5.0
@export var dash_distance: float = 400.0
@export var dash_speed: float = 2000.0
@export var dash_invuln_duration: float = 0.35

@export_group("E Skill")
@export var sweep_energy_cost: float = 30.0
@export var sweep_cooldown: float = 8.0

@export_group("F Skill")
@export var rigid_body_energy_percent: float = 40.0
@export var rigid_body_duration: float = 6.0
@export var rigid_body_enemy_cooldown: float = 0.5
@export var rigid_body_boss_damage_ratio: float = 3.0
@export var rigid_body_body_radius: float = 48.0

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
var _rigid_body_timer: float = 0.0
var _f_enemy_cooldowns: Dictionary = {}
var _f_boss_hits: Dictionary = {}
var _bundle: Dictionary = {}

func _ready() -> void:
	if player_id.strip_edges().is_empty():
		player_id = "phalanx"
	super._ready()

	damage = DEFAULT_ATTACK
	energy = max_energy
	skill_e_cost = sweep_energy_cost
	close_threshold = draw_close_threshold

	if health_component:
		health_component.setup_with_health(health)
	update_ui_signals()

	if is_instance_valid(dash_timer):
		dash_timer.one_shot = true
		dash_timer.wait_time = dash_invuln_duration

	if is_instance_valid(draw_line):
		draw_line.top_level = true
		draw_line.width = barrier_half_width * 2.0
		draw_line.default_color = Color(0.72, 0.90, 1.0, 0.92)
		draw_line.joint_mode = Line2D.LINE_JOINT_ROUND
		draw_line.begin_cap_mode = Line2D.LINE_CAP_ROUND
		draw_line.end_cap_mode = Line2D.LINE_CAP_ROUND
		draw_line.antialiased = true
		draw_line.z_index = 36
		_clear_draw_visual()

func _load_config_from_csv() -> void:
	super._load_config_from_csv()
	_bundle = RoleRuntimeService.get_v2_role_bundle(player_id)
	var player_config: Dictionary = _bundle.get("player_config", {})
	var space_config: Dictionary = _bundle.get("space_skill", {})
	var e_config: Dictionary = _bundle.get("e_skill", {})
	var f_config: Dictionary = _bundle.get("f_skill", {})

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
	pinball_reference_radius = max(1.0, float(space_config.get("pinball_reference_radius", pinball_reference_radius)))
	pinball_min_damage_ratio = max(0.1, float(space_config.get("pinball_min_damage_ratio", pinball_min_damage_ratio)))
	pinball_max_damage_ratio = max(pinball_min_damage_ratio, float(space_config.get("pinball_max_damage_ratio", pinball_max_damage_ratio)))
	pinball_max_bonus_bounces = max(0, int(space_config.get("pinball_max_bonus_bounces", pinball_max_bonus_bounces)))

	sweep_energy_cost = float(e_config.get("energy_cost", sweep_energy_cost))
	sweep_cooldown = float(e_config.get("cooldown", sweep_cooldown))
	skill_e_cost = sweep_energy_cost

	var f_cost_mode: String = str(f_config.get("energy_cost_mode", "percent_current")).strip_edges()
	if f_cost_mode in ["percent", "percent_current"]:
		rigid_body_energy_percent = float(f_config.get("energy_cost", rigid_body_energy_percent))
	rigid_body_duration = max(0.1, float(f_config.get("duration", rigid_body_duration)))

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
		_activate_sweep()

	if Input.is_action_just_pressed("skill_f"):
		_activate_absolute_rigid_body()

	if Input.is_action_pressed("click_right"):
		if not _is_drawing:
			_begin_drawing()
		_update_drawing_path()
	elif _is_drawing and Input.is_action_just_released("click_right"):
		_release_drawing_path()

func _process_subclass(delta: float) -> void:
	if _e_cooldown_remaining > 0.0:
		_e_cooldown_remaining = max(0.0, _e_cooldown_remaining - delta)
	if _rigid_body_timer > 0.0:
		_rigid_body_timer = max(0.0, _rigid_body_timer - delta)
		_process_absolute_rigid_body(delta)
		if _rigid_body_timer <= 0.0:
			_set_all_barriers_overdrive(false)
			_f_enemy_cooldowns.clear()
			_f_boss_hits.clear()
	_decay_f_enemy_cooldowns(delta)
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
	_maybe_emit_prism_stun(previous, point)
	if not consume_energy(draw_energy_cost_per_step):
		_cancel_drawing()
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
		if not _draw_points.is_empty():
			_maybe_emit_prism_stun(_draw_points[_draw_points.size() - 1], final_point)
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
	var closed_polygon: PackedVector2Array = _build_closed_polygon(captured_points)
	var is_closed: bool = closed_polygon.size() >= 3
	var release_points: PackedVector2Array = closed_polygon if is_closed else captured_points
	var centroid_value: Vector2 = _resolve_centroid(release_points, is_closed)
	var approx_area: float = _estimate_polygon_area(release_points, is_closed)

	notify_space_draw_release({
		"source": "space",
		"skill_id": "draw_phalanx",
		"is_closed": is_closed,
		"points": _packed_to_points(release_points),
		"centroid": centroid_value,
		"approx_area": approx_area,
		"draw_cost": _draw_energy_spent,
	})
	_draw_energy_spent = 0.0

	if is_closed:
		_spawn_pinball_arena(release_points, centroid_value, approx_area)
	else:
		_spawn_barrier(release_points, total_length)

func _cancel_drawing() -> void:
	_is_drawing = false
	_draw_points = PackedVector2Array()
	_draw_step_remainder = 0.0
	_clear_draw_visual()

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

func _spawn_barrier(points: PackedVector2Array, total_length: float) -> void:
	var barrier: PhalanxBarrier = PHALANX_BARRIER_SCRIPT.new() as PhalanxBarrier
	if barrier == null:
		return
	barrier.half_width = barrier_half_width
	barrier.bounce_speed = barrier_bounce_speed
	barrier.bounce_distance = barrier_bounce_distance
	barrier.sweep_speed = sweep_launch_speed
	barrier.sweep_travel_distance = sweep_launch_distance
	barrier.sweep_bounce_distance = sweep_bounce_distance
	barrier.bounce_duration = barrier_bounce_duration
	barrier.micro_stun_duration = barrier_micro_stun_duration
	barrier.ballistic_collision_damage_ratio = barrier_collision_damage_ratio
	barrier.sweep_ballistic_collision_damage_ratio = sweep_ballistic_collision_damage_ratio
	barrier.setup(self, points, damage, barrier_lifetime, _compute_barrier_durability(total_length))
	barrier.set_infinite_durability(_is_rigid_body_active())
	get_tree().current_scene.add_child(barrier)
	Global.spawn_floating_text(_average_point(points), "BARRIER", Color(0.72, 0.90, 1.0))

func _spawn_pinball_arena(polygon: PackedVector2Array, centroid_value: Vector2, approx_area: float) -> void:
	var arena_asset: PhalanxPinballArena = PHALANX_PINBALL_ARENA_SCRIPT.new() as PhalanxPinballArena
	if arena_asset == null:
		return
	var total_length: float = _compute_path_length(polygon)
	var equivalent_radius: float = _compute_closure_equivalent_radius(approx_area)
	var bounce_budget: int = _compute_pinball_bounce_budget(total_length, equivalent_radius)
	var damage_ratio: float = _compute_pinball_damage_ratio(equivalent_radius)
	arena_asset.setup(
		self,
		polygon,
		centroid_value,
		damage,
		pinball_arena_lifetime,
		bounce_budget,
		damage_ratio
	)
	get_tree().current_scene.add_child(arena_asset)
	Global.spawn_floating_text(centroid_value, "PINBALL", Color(0.78, 0.94, 1.0))

func _activate_sweep() -> void:
	if _e_cooldown_remaining > 0.0:
		Global.spawn_floating_text(global_position, "CD", Color(0.9, 0.8, 0.4))
		return
	if not consume_energy(sweep_energy_cost):
		return
	_e_cooldown_remaining = sweep_cooldown
	notify_front_skill_cast("e", {"skill_id": "e_phalanx"})

	var swept_count: int = 0
	for node: Node in get_tree().get_nodes_in_group("phalanx_barriers"):
		if not (node is PhalanxBarrier):
			continue
		var barrier: PhalanxBarrier = node as PhalanxBarrier
		if barrier == null or not is_instance_valid(barrier):
			continue
		if barrier.owner_player != self:
			continue
		barrier.start_kinetic_launch(global_position)
		swept_count += 1

	if swept_count <= 0:
		Global.spawn_floating_text(global_position, "MISS", Color(1.0, 0.42, 0.42))
		SoundManager.play("ui_error")
		return
	Global.spawn_floating_text(global_position, "SWEEP x%d" % swept_count, Color(0.72, 0.94, 1.0))

func _activate_absolute_rigid_body() -> void:
	var energy_cost: float = energy * (rigid_body_energy_percent / 100.0)
	if energy_cost <= 0.0:
		Global.spawn_floating_text(global_position, "NO ENERGY", Color(1.0, 0.42, 0.42))
		return
	if not consume_energy(energy_cost):
		return
	_rigid_body_timer = rigid_body_duration
	notify_front_skill_cast("f", {"skill_id": "f_phalanx"})
	_f_enemy_cooldowns.clear()
	_f_boss_hits.clear()
	_set_all_barriers_overdrive(true)
	Global.spawn_floating_text(global_position, "RIGID BODY", Color(0.78, 0.94, 1.0))

func _process_absolute_rigid_body(_delta: float) -> void:
	for enemy_node: Node in get_tree().get_nodes_in_group("enemies"):
		if not (enemy_node is Enemy):
			continue
		var enemy: Enemy = enemy_node as Enemy
		if enemy == null or not is_instance_valid(enemy) or enemy.is_dead:
			continue
		var distance_value: float = global_position.distance_to(enemy.global_position)
		if distance_value > rigid_body_body_radius:
			continue
		if enemy.has_method("is_boss_enemy") and bool(enemy.call("is_boss_enemy")):
			var boss_id: int = enemy.get_instance_id()
			if _f_boss_hits.has(boss_id):
				continue
			_f_boss_hits[boss_id] = true
			var boss_damage: float = damage * rigid_body_boss_damage_ratio
			enemy.apply_modifier_damage(boss_damage, self, {
				"kind": "phalanx_rigid_body_boss",
				"damage_type": "DMG_DIRECT",
				"skill_slot": "f",
			})
			if enemy.has_method("set_flash_material"):
				enemy.set_flash_material()
			notify_front_skill_damage("f", [enemy], {"skill_id": "f_phalanx"})
			continue
		var enemy_id: int = enemy.get_instance_id()
		if float(_f_enemy_cooldowns.get(enemy_id, 0.0)) > 0.0:
			continue
		var bounce_dir: Vector2 = enemy.global_position - global_position
		if bounce_dir.length_squared() <= 0.0001:
			bounce_dir = Vector2.RIGHT.rotated(randf() * TAU)
		enemy.apply_status("stun", barrier_micro_stun_duration, 0.0, 1, 1.0)
		enemy.apply_phalanx_ballistic(
			bounce_dir,
			barrier_bounce_speed,
			barrier_bounce_distance,
			barrier_bounce_duration,
			damage,
			3.5,
			self,
			10.0
		)
		_f_enemy_cooldowns[enemy_id] = rigid_body_enemy_cooldown

func _set_all_barriers_overdrive(active: bool) -> void:
	for node: Node in get_tree().get_nodes_in_group("phalanx_barriers"):
		if node is PhalanxBarrier and is_instance_valid(node):
			var barrier: PhalanxBarrier = node as PhalanxBarrier
			if barrier.owner_player == self:
				barrier.set_infinite_durability(active)

func _decay_f_enemy_cooldowns(delta: float) -> void:
	if _f_enemy_cooldowns.is_empty():
		return
	var expired_ids: Array[int] = []
	for enemy_id_variant: Variant in _f_enemy_cooldowns.keys():
		var enemy_id: int = int(enemy_id_variant)
		var remaining: float = max(0.0, float(_f_enemy_cooldowns.get(enemy_id, 0.0)) - delta)
		if remaining <= 0.0:
			expired_ids.append(enemy_id)
		else:
			_f_enemy_cooldowns[enemy_id] = remaining
	for enemy_id: int in expired_ids:
		_f_enemy_cooldowns.erase(enemy_id)

func _is_rigid_body_active() -> bool:
	return _rigid_body_timer > 0.0

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

func _compute_barrier_durability(total_length: float) -> int:
	return max(2, int(floor(total_length / max(1.0, barrier_durability_divisor))))

func _compute_closure_equivalent_radius(area: float) -> float:
	if area <= 0.0:
		return 0.0
	return sqrt(area / PI)

func _compute_pinball_damage_ratio(equivalent_radius: float) -> float:
	var normalized_radius: float = clamp(
		equivalent_radius / max(1.0, pinball_reference_radius * 2.0),
		0.0,
		1.0
	)
	return lerp(pinball_min_damage_ratio, pinball_max_damage_ratio, normalized_radius)

func _compute_pinball_bounce_budget(total_length: float, equivalent_radius: float) -> int:
	var length_budget: int = int(round(clamp(
		total_length / max(1.0, barrier_durability_divisor * 3.0),
		0.0,
		4.0
	)))
	var radius_bonus: int = int(floor(clamp(
		equivalent_radius / max(1.0, pinball_reference_radius) - 0.65,
		0.0,
		float(pinball_max_bonus_bounces)
	)))
	return int(clamp(2 + length_budget + radius_bonus, 2, 6 + pinball_max_bonus_bounces))

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
