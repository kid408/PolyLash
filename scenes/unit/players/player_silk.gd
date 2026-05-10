extends PlayerBase
class_name PlayerSilk

const SILK_LINK_UTILS := preload("res://scenes/effects/silk_link_utils.gd")

const DEFAULT_ATTACK: float = 12.0
const DEFAULT_HEALTH: float = 180.0
const DEFAULT_SPEED: float = 250.0
const DEFAULT_MAX_ENERGY: float = 120.0
const DEFAULT_ENERGY_REGEN: float = 12.0
const DEFAULT_PICKUP_RANGE: float = 165.0

@export_group("Silk Draw")
@export var draw_sample_spacing: float = 18.0
@export var draw_base_energy_cost: float = 0.0
@export var draw_energy_cost_per_step: float = 0.6
@export var draw_energy_cost_unit_px: float = 30.0
@export var draw_min_release_length: float = 24.0
@export var draw_close_threshold: float = 60.0
@export var soul_link_line_half_width: float = 34.0
@export var soul_link_duration: float = 8.0
@export var soul_link_empowered_duration: float = 10.0
@export var soul_link_transmission_ratio: float = 0.30
@export var soul_link_empowered_transmission_ratio: float = 0.80
@export var harvest_energy_restore: float = 15.0
@export var harvest_collapse_damage_ratio: float = 1.0
@export var harvest_collapse_radius: float = 120.0

@export_group("Dash")
@export var dash_cost: float = 5.0
@export var dash_distance: float = 400.0
@export var dash_speed: float = 2000.0
@export var dash_invuln_duration: float = 0.35

@export_group("E Skill")
@export var convergence_energy_cost: float = 20.0
@export var convergence_cooldown: float = 8.0
@export var convergence_slow_duration: float = 0.5
@export var convergence_slow_multiplier: float = 0.10
@export var convergence_true_damage: float = 40.0

@export_group("F Skill")
@export var web_energy_cost_mode: String = "flat"
@export var web_energy_percent: float = 0.0
@export var web_flat_energy_cost: float = 0.0
@export var web_cooldown: float = 45.0
@export var web_duration: float = 10.0

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
var _draw_total_length: float = 0.0
var _draw_energy_spent: float = 0.0

var _e_cooldown_remaining: float = 0.0
var _f_cooldown_remaining: float = 0.0
var _v2_bundle: Dictionary = {}

func _ready() -> void:
	if player_id.strip_edges().is_empty():
		player_id = "silk"
	super._ready()

	damage = DEFAULT_ATTACK
	energy = max_energy
	skill_e_cost = convergence_energy_cost
	close_threshold = draw_close_threshold

	if health_component:
		health_component.setup_with_health(health)
	update_ui_signals()

	if is_instance_valid(dash_timer):
		dash_timer.one_shot = true
		dash_timer.wait_time = dash_invuln_duration

	if is_instance_valid(draw_line):
		draw_line.top_level = true
		draw_line.width = 7.0
		draw_line.default_color = Color(0.98, 0.26, 0.34, 0.95)
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
	draw_energy_cost_unit_px = max(1.0, float(space_config.get("energy_cost_unit_px", draw_energy_cost_unit_px)))
	var energy_mode: String = str(space_config.get("energy_mode", "per_unit")).strip_edges()
	var energy_cost_per_unit: float = float(space_config.get("energy_cost_per_unit", draw_energy_cost_per_step))
	if energy_mode == "per_unit":
		draw_energy_cost_per_step = energy_cost_per_unit * (draw_sample_spacing / draw_energy_cost_unit_px)
	else:
		draw_energy_cost_per_step = energy_cost_per_unit
	soul_link_duration = max(0.1, float(space_config.get("soul_link_duration", soul_link_duration)))
	soul_link_empowered_duration = max(soul_link_duration, float(space_config.get("soul_link_empowered_duration", soul_link_empowered_duration)))
	soul_link_transmission_ratio = max(0.0, float(space_config.get("soul_link_transfer_ratio", soul_link_transmission_ratio)))
	soul_link_empowered_transmission_ratio = max(
		soul_link_transmission_ratio,
		float(space_config.get("soul_link_empowered_transfer_ratio", soul_link_empowered_transmission_ratio))
	)
	harvest_energy_restore = max(0.0, float(space_config.get("harvest_energy_restore", harvest_energy_restore)))
	harvest_collapse_damage_ratio = max(0.0, float(space_config.get("harvest_collapse_damage_ratio", harvest_collapse_damage_ratio)))
	harvest_collapse_radius = max(0.0, float(space_config.get("harvest_collapse_radius", harvest_collapse_radius)))
	SILK_LINK_UTILS.set_transmission_ratios(soul_link_transmission_ratio, soul_link_empowered_transmission_ratio)

	convergence_energy_cost = float(e_config.get("energy_cost", convergence_energy_cost))
	convergence_cooldown = float(e_config.get("cooldown", convergence_cooldown))
	convergence_slow_duration = max(0.0, float(e_config.get("effect_duration", convergence_slow_duration)))
	convergence_slow_multiplier = clamp(float(e_config.get("convergence_slow_multiplier", convergence_slow_multiplier)), 0.01, 1.0)
	convergence_true_damage = max(
		0.0,
		float(e_config.get("convergence_sever_true_damage", e_config.get("convergence_true_damage", convergence_true_damage)))
	)
	skill_e_cost = convergence_energy_cost

	web_energy_cost_mode = str(f_config.get("energy_cost_mode", web_energy_cost_mode)).strip_edges()
	if web_energy_cost_mode in ["percent", "percent_current"]:
		web_energy_percent = float(f_config.get("energy_cost", web_energy_percent))
	else:
		web_flat_energy_cost = max(0.0, float(f_config.get("energy_cost", web_flat_energy_cost)))
	web_cooldown = max(0.0, float(f_config.get("cooldown", web_cooldown)))
	web_duration = max(0.5, float(f_config.get("duration", web_duration)))

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
		_activate_convergence()

	if Input.is_action_just_pressed("skill_f"):
		_activate_web_of_destiny()

	if Input.is_action_pressed("click_right"):
		if not _is_drawing:
			_begin_drawing()
		_update_drawing_path()
	elif _is_drawing and Input.is_action_just_released("click_right"):
		_release_drawing_path()

func _process_subclass(delta: float) -> void:
	if _e_cooldown_remaining > 0.0:
		_e_cooldown_remaining = max(0.0, _e_cooldown_remaining - delta)
	if _f_cooldown_remaining > 0.0:
		_f_cooldown_remaining = max(0.0, _f_cooldown_remaining - delta)
	_refresh_invincible_meta()

func _begin_drawing() -> void:
	if draw_base_energy_cost > 0.0 and not consume_energy(draw_base_energy_cost):
		return
	_is_drawing = true
	_draw_points = PackedVector2Array()
	_draw_step_remainder = 0.0
	_draw_total_length = 0.0
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

func _release_drawing_path() -> void:
	if not _is_drawing:
		return
	var final_point: Vector2 = get_global_mouse_position()
	if _draw_points.is_empty() or _draw_points[_draw_points.size() - 1].distance_to(final_point) > 1.0:
		_append_draw_point(final_point)
	var captured_points: PackedVector2Array = _draw_points.duplicate()
	var total_length: float = _draw_total_length
	_is_drawing = false
	_draw_points = PackedVector2Array()
	_draw_step_remainder = 0.0
	_draw_total_length = 0.0
	_clear_draw_visual()

	if captured_points.size() < 2:
		_draw_energy_spent = 0.0
		return

	if total_length <= 0.0:
		total_length = _compute_path_length(captured_points)
	if total_length < draw_min_release_length:
		_draw_energy_spent = 0.0
		return

	var forced_closure: Dictionary = BondManager.apply_forced_closure(self, captured_points) if BondManager != null and BondManager.has_method("apply_forced_closure") else {}
	if bool(forced_closure.get("forced_closed", false)):
		captured_points = forced_closure.get("points", captured_points)
	var is_closed: bool = _determine_closed_shape(captured_points)
	var centroid: Vector2 = _resolve_centroid(captured_points, is_closed)
	var approx_area: float = _estimate_polygon_area(captured_points, is_closed)
	Global.cache_recent_draw_path(player_id, _packed_to_points(captured_points), is_closed)
	notify_space_draw_release({
		"source": "space",
		"skill_id": "draw_silk",
		"is_closed": is_closed,
		"points": _packed_to_points(captured_points),
		"centroid": centroid,
		"approx_area": approx_area,
		"draw_cost": _draw_energy_spent,
	})
	_draw_energy_spent = 0.0

	if is_closed and approx_area > 1.0:
		_execute_harvest(captured_points)
	else:
		_apply_soul_link_line(captured_points)

func _append_draw_point(point: Vector2) -> bool:
	if _draw_points.is_empty():
		_draw_points.append(point)
		_refresh_draw_visual()
		return true
	var previous: Vector2 = _draw_points[_draw_points.size() - 1]
	if previous.distance_to(point) <= 0.001:
		return true
	var segment_length: float = previous.distance_to(point)
	var step_cost: float = _compute_incremental_draw_energy_cost(_draw_total_length, segment_length)
	if step_cost > 0.0 and not consume_energy(step_cost):
		return false
	_maybe_emit_prism_stun(previous, point)
	_draw_total_length += segment_length
	_draw_energy_spent += step_cost
	_draw_points.append(point)
	_refresh_draw_visual()
	return true

func _compute_incremental_draw_energy_cost(_current_length: float, segment_length: float) -> float:
	if segment_length <= 0.0:
		return 0.0
	var cost_per_px: float = draw_energy_cost_per_step / max(0.001, draw_sample_spacing)
	return segment_length * cost_per_px

func _determine_closed_shape(points: PackedVector2Array) -> bool:
	return _build_closed_polygon(points).size() >= 3

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

func _apply_soul_link_line(points: PackedVector2Array) -> void:
	_spawn_soul_link_line_vfx(points)
	var linked_count: int = 0
	for enemy_node: Node in get_tree().get_nodes_in_group("enemies"):
		if not (enemy_node is Enemy):
			continue
		var enemy: Enemy = enemy_node as Enemy
		if not is_instance_valid(enemy) or enemy.is_dead:
			continue
		if not _is_point_inside_polyline_width(enemy.global_position, points, soul_link_line_half_width):
			continue
		SILK_LINK_UTILS.apply_link(enemy, self, soul_link_duration, false, soul_link_empowered_duration)
		if enemy.has_method("set_flash_material"):
			enemy.set_flash_material()
		linked_count += 1
	if linked_count > 0:
		Global.spawn_floating_text(_average_point(points), "LINK x%d" % linked_count, Color(1.0, 0.42, 0.48))
	else:
		Global.spawn_floating_text(_average_point(points), "MISS", Color(1.0, 0.42, 0.42))

func _execute_harvest(points: PackedVector2Array) -> void:
	var polygon: PackedVector2Array = _build_closed_polygon(points)
	if polygon.size() < 3:
		_apply_soul_link_line(points)
		return

	var harvested_targets: Array[Enemy] = []
	for enemy_node: Node in get_tree().get_nodes_in_group("enemies"):
		if not (enemy_node is Enemy):
			continue
		var enemy: Enemy = enemy_node as Enemy
		if not is_instance_valid(enemy) or enemy.is_dead:
			continue
		if not Geometry2D.is_point_in_polygon(enemy.global_position, polygon):
			continue
		if not SILK_LINK_UTILS.has_link(enemy):
			continue
		harvested_targets.append(enemy)

	_spawn_harvest_vfx(polygon)
	if harvested_targets.is_empty():
		Global.spawn_floating_text(_average_point(polygon), "NO LINK", Color(1.0, 0.74, 0.68))
		return

	for harvested_enemy: Enemy in harvested_targets:
		SILK_LINK_UTILS.clear_link(harvested_enemy)
		if harvested_enemy.has_method("set_flash_material"):
			harvested_enemy.set_flash_material()

	var collapse_damage: float = damage * harvest_collapse_damage_ratio
	if collapse_damage > 0.0 and harvest_collapse_radius > 0.0:
		for harvested_enemy: Enemy in harvested_targets:
			_apply_harvest_collapse(harvested_enemy.global_position, collapse_damage)

	_restore_squad_energy(float(harvested_targets.size()) * harvest_energy_restore)
	Global.spawn_floating_text(_average_point(polygon), "HARVEST x%d" % harvested_targets.size(), Color(1.0, 0.78, 0.84))

func _restore_squad_energy(amount: float) -> void:
	if amount <= 0.0:
		return
	var active_player: PlayerBase = Global.player as PlayerBase
	var active_player_id: String = Global.get_current_player_id() if Global.has_method("get_current_player_id") else player_id
	for i: int in range(Global.selected_player_ids.size()):
		var squad_player_id: String = str(Global.selected_player_ids[i])
		if squad_player_id.is_empty():
			continue
		var state: Dictionary = Global.get_player_state(squad_player_id)
		if state.is_empty():
			continue
		var max_energy_value: float = float(state.get("max_energy", amount))
		var current_energy_value: float = float(state.get("energy", 0.0))
		state["energy"] = min(max_energy_value, current_energy_value + amount)
		Global.player_states[squad_player_id] = state
		Global.notify_squad_state_changed(i)
		if squad_player_id == active_player_id and is_instance_valid(active_player):
			active_player.energy = float(state.get("energy", active_player.energy))
			active_player.update_ui_signals()
	if is_instance_valid(active_player):
		Global.spawn_floating_text(active_player.global_position + Vector2(0, -26), "+%.0f TEAM ENERGY" % amount, Color(1.0, 0.86, 0.92))

func _activate_convergence() -> void:
	if _e_cooldown_remaining > 0.0:
		Global.spawn_floating_text(global_position, "CD", Color(0.92, 0.82, 0.42))
		return
	if not consume_energy(convergence_energy_cost):
		return
	_e_cooldown_remaining = convergence_cooldown
	notify_front_skill_cast("e", {"skill_id": "e_silk"})

	var linked_enemies: Array[Enemy] = _get_linked_enemies()
	if linked_enemies.is_empty():
		Global.spawn_floating_text(global_position, "MISS", Color(1.0, 0.42, 0.42))
		SoundManager.play("ui_error")
		return

	var centroid: Vector2 = Vector2.ZERO
	var hit_enemies: Array = []
	for enemy: Enemy in linked_enemies:
		if not is_instance_valid(enemy) or enemy.is_dead:
			continue
		centroid += enemy.global_position
		enemy.apply_modifier_damage(convergence_true_damage, self, {
			"kind": "silk_resonance_ping",
			"damage_type": "DMG_TRUE",
			"true_damage": true,
			"skill_slot": "e",
			"soul_link_skip_share": true,
		})
		enemy.apply_move_speed_modifier(
			"silk_resonance_slow",
			convergence_slow_multiplier,
			convergence_slow_duration,
			CombatModifierComponent.STACK_REFRESH,
			self,
			{
				"kind": "silk_resonance_slow",
				"soul_link_skip_share": true,
			}
		)
		if enemy.has_method("set_flash_material"):
			enemy.set_flash_material()
		hit_enemies.append(enemy)

	if hit_enemies.is_empty():
		Global.spawn_floating_text(global_position, "MISS", Color(1.0, 0.42, 0.42))
		return

	centroid /= float(hit_enemies.size())
	_spawn_convergence_vfx(centroid)
	Global.spawn_floating_text(centroid, "RESONANCE x%d" % hit_enemies.size(), Color(1.0, 0.56, 0.66))
	notify_front_skill_damage("e", hit_enemies, {
		"skill_id": "e_silk",
		"source": "silk_resonance_ping",
		"resolved_damage": convergence_true_damage,
	})

func _activate_web_of_destiny() -> void:
	if _f_cooldown_remaining > 0.0:
		Global.spawn_floating_text(global_position, "CD", Color(0.92, 0.82, 0.42))
		return
	var energy_cost: float = _resolve_web_energy_cost()
	if energy_cost > 0.0 and not consume_energy(energy_cost):
		return
	_f_cooldown_remaining = web_cooldown
	notify_front_skill_cast("f", {"skill_id": "f_silk"})

	var linked_count: int = 0
	for enemy_node: Node in get_tree().get_nodes_in_group("enemies"):
		if not (enemy_node is Enemy):
			continue
		var enemy: Enemy = enemy_node as Enemy
		if not is_instance_valid(enemy) or enemy.is_dead:
			continue
		SILK_LINK_UTILS.apply_link(enemy, self, web_duration, true, web_duration)
		if enemy.has_method("set_flash_material"):
			enemy.set_flash_material()
		linked_count += 1

	_spawn_web_of_destiny_vfx()
	Global.spawn_floating_text(global_position, "WEB x%d" % linked_count, Color(1.0, 0.70, 0.82))

func _resolve_web_energy_cost() -> float:
	if web_energy_cost_mode in ["percent", "percent_current"]:
		return max(0.0, energy * (web_energy_percent / 100.0))
	if web_energy_cost_mode == "percent_max":
		return max(0.0, max_energy * (web_energy_percent / 100.0))
	return max(0.0, web_flat_energy_cost)

func _apply_harvest_collapse(center: Vector2, damage_amount: float) -> void:
	var radius_sq: float = harvest_collapse_radius * harvest_collapse_radius
	for enemy_node: Node in get_tree().get_nodes_in_group("enemies"):
		if not (enemy_node is Enemy):
			continue
		var enemy: Enemy = enemy_node as Enemy
		if not is_instance_valid(enemy) or enemy.is_dead:
			continue
		if enemy.global_position.distance_squared_to(center) > radius_sq:
			continue
		enemy.apply_modifier_damage(damage_amount, self, {
			"kind": "silk_harvest_collapse",
			"damage_type": "DMG_DIRECT",
			"skill_slot": "space",
			"soul_link_skip_share": true,
		})
		if enemy.has_method("set_flash_material"):
			enemy.set_flash_material()

func _get_linked_enemies() -> Array[Enemy]:
	var result: Array[Enemy] = []
	for enemy_node: Node in get_tree().get_nodes_in_group("enemies"):
		if not (enemy_node is Enemy):
			continue
		var enemy: Enemy = enemy_node as Enemy
		if not is_instance_valid(enemy) or enemy.is_dead:
			continue
		if not SILK_LINK_UTILS.has_link(enemy):
			continue
		result.append(enemy)
	return result

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
	var polygon: PackedVector2Array = _build_closed_polygon(points)
	if polygon.size() < 3:
		return 0.0
	var double_area: float = 0.0
	for i: int in range(polygon.size()):
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
	for i: int in range(points.size() - 1):
		var closest: Vector2 = Geometry2D.get_closest_point_to_segment(point, points[i], points[i + 1])
		if point.distance_squared_to(closest) <= half_width_sq:
			return true
	return false

func _spawn_soul_link_line_vfx(points: PackedVector2Array) -> void:
	if points.size() < 2:
		return
	var root: Node2D = Node2D.new()
	root.top_level = true
	root.z_index = 31
	get_tree().current_scene.add_child(root)

	var outer_line: Line2D = Line2D.new()
	outer_line.points = points
	outer_line.width = 18.0
	outer_line.default_color = Color(0.92, 0.18, 0.26, 0.44)
	outer_line.begin_cap_mode = Line2D.LINE_CAP_ROUND
	outer_line.end_cap_mode = Line2D.LINE_CAP_ROUND
	outer_line.joint_mode = Line2D.LINE_JOINT_ROUND
	outer_line.antialiased = true
	root.add_child(outer_line)

	var inner_line: Line2D = Line2D.new()
	inner_line.points = points
	inner_line.width = 8.0
	inner_line.default_color = Color(1.0, 0.78, 0.82, 0.92)
	inner_line.begin_cap_mode = Line2D.LINE_CAP_ROUND
	inner_line.end_cap_mode = Line2D.LINE_CAP_ROUND
	inner_line.joint_mode = Line2D.LINE_JOINT_ROUND
	inner_line.antialiased = true
	root.add_child(inner_line)

	var tween: Tween = root.create_tween()
	tween.set_parallel(true)
	tween.tween_property(outer_line, "modulate:a", 0.0, 0.22)
	tween.tween_property(inner_line, "modulate:a", 0.0, 0.18)
	tween.finished.connect(root.queue_free)

func _spawn_harvest_vfx(polygon: PackedVector2Array) -> void:
	var root: Node2D = Node2D.new()
	root.top_level = true
	root.z_index = 32
	get_tree().current_scene.add_child(root)

	var fill: Polygon2D = Polygon2D.new()
	fill.polygon = polygon
	fill.color = Color(1.0, 0.24, 0.32, 0.22)
	root.add_child(fill)

	var border: Line2D = Line2D.new()
	border.closed = true
	border.points = polygon
	border.width = 8.0
	border.default_color = Color(1.0, 0.72, 0.80, 0.90)
	border.antialiased = true
	root.add_child(border)

	var tween: Tween = root.create_tween()
	tween.set_parallel(true)
	tween.tween_property(fill, "modulate:a", 0.0, 0.22)
	tween.tween_property(border, "modulate:a", 0.0, 0.20)
	tween.finished.connect(root.queue_free)

func _spawn_convergence_vfx(center: Vector2) -> void:
	var ring: Line2D = Line2D.new()
	ring.top_level = true
	ring.closed = true
	ring.width = 10.0
	ring.default_color = Color(1.0, 0.38, 0.46, 0.74)
	ring.antialiased = true
	var points: PackedVector2Array = PackedVector2Array()
	for i: int in range(25):
		var angle: float = (float(i) / 24.0) * TAU
		points.append(center + Vector2.RIGHT.rotated(angle) * 120.0)
	ring.points = points
	get_tree().current_scene.add_child(ring)
	var tween: Tween = ring.create_tween()
	tween.set_parallel(true)
	tween.tween_property(ring, "scale", Vector2(0.2, 0.2), 0.20)
	tween.tween_property(ring, "modulate:a", 0.0, 0.20)
	tween.finished.connect(ring.queue_free)

func _spawn_web_of_destiny_vfx() -> void:
	var root: Node2D = Node2D.new()
	root.top_level = true
	root.z_index = 35
	get_tree().current_scene.add_child(root)
	for i: int in range(14):
		var ring: Line2D = Line2D.new()
		ring.closed = true
		ring.width = randf_range(3.0, 6.0)
		ring.default_color = Color(1.0, 0.36, 0.44, 0.38)
		ring.antialiased = true
		var radius: float = randf_range(80.0, 460.0)
		var points: PackedVector2Array = PackedVector2Array()
		for point_index: int in range(25):
			var angle: float = (float(point_index) / 24.0) * TAU
			points.append(global_position + Vector2.RIGHT.rotated(angle) * radius)
		ring.points = points
		root.add_child(ring)
	var tween: Tween = root.create_tween()
	tween.set_parallel(true)
	tween.tween_property(root, "modulate:a", 0.0, 0.45)
	tween.finished.connect(root.queue_free)
