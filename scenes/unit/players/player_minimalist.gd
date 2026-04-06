extends PlayerBase
class_name PlayerMinimalist

const SCAR_SCENE: PackedScene = preload("res://scenes/effects/minimalist_slash_scar.tscn")

const DEFAULT_ATTACK: float = 40.0
const DEFAULT_HEALTH: float = 110.0
const DEFAULT_SPEED: float = 520.0
const DEFAULT_MAX_ENERGY: float = 160.0
const DEFAULT_ENERGY_REGEN: float = 0.8
const DEFAULT_PICKUP_RANGE: float = 112.0

@export_group("Minimalist Draw")
@export var draw_sample_spacing: float = 10.0
@export var draw_base_energy_cost: float = 0.0
@export var draw_energy_cost_per_step: float = 0.4
@export var draw_max_total_length: float = 99999.0
@export var draw_min_release_length: float = 24.0
@export var slash_base_half_width: float = 20.0
@export var slash_bonus_half_width: float = 150.0
@export var slash_width_length_cap: float = 2500.0
@export var slash_base_damage_ratio: float = 0.80
@export var slash_damage_bonus_ratio: float = 2.5
@export var self_break_slow_duration: float = 1.0
@export var self_break_slow_multiplier: float = 0.60
@export var scar_lifetime: float = 4.0

@export_group("Dash")
@export var dash_cost: float = 5.0
@export var dash_distance: float = 400.0
@export var dash_speed: float = 2000.0
@export var dash_invuln_duration: float = 0.35

@export_group("Hitstop")
@export var hitstop_threshold_length: float = 800.0
@export var hitstop_base_duration: float = 0.2
@export var hitstop_bonus_duration: float = 1.0
@export var hitstop_bonus_length: float = 1700.0

@export_group("E Skill")
@export var resonance_energy_cost: float = 40.0
@export var resonance_cooldown: float = 8.0
@export var resonance_half_width: float = 80.0
@export var resonance_stun_duration: float = 0.18
@export var resonance_knockback_distance: float = 180.0

@export_group("F Skill")
@export var dimension_energy_percent: float = 40.0
@export var dimension_sample_step: float = 60.0
@export var dimension_explosion_radius: float = 100.0
@export var dimension_true_damage_ratio: float = 2.50
@export var dimension_sequence_duration: float = 0.4

@onready var dash_timer: Timer = $DashTimer
@onready var draw_line: Line2D = $Line2D

var _draw_band_outer: Line2D = null
var _draw_band_inner: Line2D = null

var _is_test_dashing: bool = false
var _dash_direction: Vector2 = Vector2.ZERO
var _dash_remaining_distance: float = 0.0
var _dash_total_distance: float = 0.0
var _dash_invulnerable: bool = false

var _is_drawing: bool = false
var _draw_points: PackedVector2Array = PackedVector2Array()
var _draw_step_remainder: float = 0.0

var _slow_penalty_timer: float = 0.0
var _e_cooldown_remaining: float = 0.0
var _f_sequence_timer: float = 0.0
var _f_pending_teleport: Vector2 = Vector2.ZERO

var _global_hitstop_timer: float = 0.0
var _paused_nodes: Array[Dictionary] = []

var _current_scar: MinimalistSlashScar = null
var _v2_bundle: Dictionary = {}

func _ready() -> void:
	if player_id.strip_edges().is_empty():
		player_id = "minimalist"
	super._ready()

	damage = DEFAULT_ATTACK
	energy = max_energy
	skill_e_cost = resonance_energy_cost
	close_threshold = 99999.0

	if health_component:
		health_component.setup_with_health(health)
	update_ui_signals()

	if is_instance_valid(dash_timer):
		dash_timer.one_shot = true
		dash_timer.wait_time = dash_invuln_duration

	if is_instance_valid(draw_line):
		draw_line.top_level = true
		draw_line.width = 8.0
		draw_line.default_color = Color(1.0, 0.97, 0.84, 0.98)
		draw_line.joint_mode = Line2D.LINE_JOINT_ROUND
		draw_line.begin_cap_mode = Line2D.LINE_CAP_ROUND
		draw_line.end_cap_mode = Line2D.LINE_CAP_ROUND
		draw_line.antialiased = true
		draw_line.z_index = 36

	_ensure_live_band_preview()
	_clear_draw_visual()

func _exit_tree() -> void:
	_resume_global_hitstop()
	super._exit_tree()

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
	draw_max_total_length = float(space_config.get("max_total_length", draw_max_total_length))
	draw_min_release_length = float(space_config.get("min_release_length", draw_min_release_length))
	slash_base_half_width = float(space_config.get("preview_width_base", slash_base_half_width))
	slash_bonus_half_width = max(0.0, float(space_config.get("preview_width_max", 170.0)) - slash_base_half_width)
	scar_lifetime = float(space_config.get("release_asset_lifetime", scar_lifetime))

	var energy_mode: String = str(space_config.get("energy_mode", "per_unit")).strip_edges()
	var energy_cost_per_unit: float = float(space_config.get("energy_cost_per_unit", 0.4))
	var energy_cost_unit_px: float = max(1.0, float(space_config.get("energy_cost_unit_px", draw_sample_spacing)))
	if energy_mode == "per_unit":
		draw_energy_cost_per_step = energy_cost_per_unit * (draw_sample_spacing / energy_cost_unit_px)
	else:
		draw_energy_cost_per_step = energy_cost_per_unit

	resonance_energy_cost = float(e_config.get("energy_cost", resonance_energy_cost))
	resonance_cooldown = float(e_config.get("cooldown", resonance_cooldown))
	resonance_half_width = float(e_config.get("effect_radius", resonance_half_width))
	resonance_stun_duration = float(e_config.get("effect_duration", resonance_stun_duration))
	skill_e_cost = resonance_energy_cost

	var f_cost_mode: String = str(f_config.get("energy_cost_mode", "percent_current")).strip_edges()
	if f_cost_mode == "percent_current":
		dimension_energy_percent = float(f_config.get("energy_cost", dimension_energy_percent))
	dimension_sequence_duration = float(f_config.get("duration", dimension_sequence_duration))

	damage = DEFAULT_ATTACK

func _load_weapons_from_config() -> void:
	super._load_weapons_from_config()

func _load_ultimate_skill() -> void:
	ultimate_skill = null

func _auto_create_skill_manager() -> void:
	pass

func _handle_input(delta: float) -> void:
	move_dir = Input.get_vector("move_left", "move_right", "move_up", "move_down")

	if _is_test_dashing:
		_update_test_dash(delta)
	elif can_move():
		var current_speed: float = get_effective_move_speed()
		if _slow_penalty_timer > 0.0:
			current_speed *= self_break_slow_multiplier
		position += move_dir * current_speed * delta

	if Input.is_action_just_pressed("tactical_reject"):
		_try_activate_tactical_reject()

	if Input.is_action_just_pressed("click_left") and not _f_sequence_active():
		_try_start_dash()

	if Input.is_action_just_pressed("skill_e"):
		_activate_resonance()

	if Input.is_action_just_pressed("skill_f"):
		_activate_dimension_slash()

	if Input.is_action_pressed("click_right"):
		if not _is_drawing:
			_begin_drawing()
		_update_drawing_path()
	elif _is_drawing:
		_release_drawing_path()

func _process_subclass(delta: float) -> void:
	if _slow_penalty_timer > 0.0:
		_slow_penalty_timer = max(0.0, _slow_penalty_timer - delta)

	if _e_cooldown_remaining > 0.0:
		_e_cooldown_remaining = max(0.0, _e_cooldown_remaining - delta)

	if _global_hitstop_timer > 0.0:
		_global_hitstop_timer = max(0.0, _global_hitstop_timer - delta)
		if _global_hitstop_timer <= 0.0:
			_resume_global_hitstop()

	if _f_sequence_timer > 0.0:
		_f_sequence_timer = max(0.0, _f_sequence_timer - delta)
		if _f_sequence_timer <= 0.0:
			_finish_dimension_slash()

	_refresh_invincible_meta()

func _begin_drawing() -> void:
	if draw_base_energy_cost > 0.0 and not consume_energy(draw_base_energy_cost):
		return
	_is_drawing = true
	_draw_points = PackedVector2Array()
	_draw_step_remainder = 0.0
	_draw_points.append(global_position)
	_refresh_draw_visual()

func _update_drawing_path() -> void:
	if not _is_drawing:
		return
	var target_point: Vector2 = global_position
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
	if previous.distance_to(point) <= 0.001:
		return true
	if _would_exceed_max_length(previous, point):
		_handle_self_intersection_failure()
		return false
	if not _can_ignore_self_intersection() and _would_self_intersect(previous, point):
		_handle_self_intersection_failure()
		return false
	if not consume_energy(draw_energy_cost_per_step):
		return false

	_draw_points.append(point)
	_refresh_draw_visual()
	return true

func _release_drawing_path() -> void:
	if not _is_drawing:
		return

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

	var half_width: float = _compute_slash_half_width(total_length)
	var damage_amount: float = damage * slash_base_damage_ratio * (1.0 + _compute_slash_width_coefficient(total_length) * slash_damage_bonus_ratio)
	_apply_polyline_damage(captured_points, half_width, damage_amount, false, "SLASH")
	notify_space_draw_release({
		"source": "space",
		"skill_id": "space_minimalist",
		"is_closed": false,
		"points": _packed_to_points(captured_points),
		"centroid": _calculate_path_center(captured_points),
		"approx_area": 0.0,
		"draw_cost": _estimate_draw_cost(captured_points),
	})
	_spawn_path_band_flash(captured_points, half_width, Color(1.0, 0.94, 0.76, 0.50), Color(1.0, 0.72, 0.18, 0.40), 0.12, 0.24)
	_spawn_or_replace_scar(captured_points, half_width)
	_trigger_hitstop_if_needed(total_length)

func _handle_self_intersection_failure() -> void:
	_is_drawing = false
	_draw_points = PackedVector2Array()
	_draw_step_remainder = 0.0
	_clear_draw_visual()
	_slow_penalty_timer = self_break_slow_duration
	SoundManager.play("ui_error")
	Global.spawn_floating_text(global_position, "BREAK", Color(1.0, 0.35, 0.3))
	set_flash_material()

func _would_self_intersect(start_point: Vector2, end_point: Vector2) -> bool:
	if _draw_points.size() < 3:
		return false
	for i in range(_draw_points.size() - 2):
		var a: Vector2 = _draw_points[i]
		var b: Vector2 = _draw_points[i + 1]
		var hit: Variant = Geometry2D.segment_intersects_segment(a, b, start_point, end_point)
		if hit != null:
			return true
	return false

func _would_exceed_max_length(start_point: Vector2, end_point: Vector2) -> bool:
	if draw_max_total_length <= 0.0:
		return false
	var projected_length: float = _compute_path_length(_draw_points) + start_point.distance_to(end_point)
	return projected_length > draw_max_total_length

func _can_ignore_self_intersection() -> bool:
	return _dash_invulnerable

func _try_start_dash() -> void:
	if _is_test_dashing:
		return
	if not consume_energy(dash_cost):
		return

	var dash_target: Vector2 = get_global_mouse_position()
	var dash_dir: Vector2 = global_position.direction_to(dash_target)
	if dash_dir.length_squared() <= 0.0001:
		dash_dir = move_dir.normalized()
	if dash_dir.length_squared() <= 0.0001:
		dash_dir = Vector2.RIGHT if is_facing_right() else Vector2.LEFT

	_is_test_dashing = true
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

func _update_test_dash(delta: float) -> void:
	if not _is_test_dashing:
		return
	var step: float = min(_dash_remaining_distance, dash_speed * delta)
	global_position += _dash_direction * step
	_dash_remaining_distance = max(0.0, _dash_remaining_distance - step)
	var normalized_time: float = 1.0 - (_dash_remaining_distance / max(1.0, _dash_total_distance))
	dash_active.emit(player_id, global_position, _dash_direction, normalized_time)
	if _dash_remaining_distance <= 0.0:
		_finish_test_dash()

func _finish_test_dash() -> void:
	if not _is_test_dashing:
		return
	_is_test_dashing = false
	dash_finished.emit(player_id, global_position, _dash_direction)

func _on_dash_timer_timeout() -> void:
	_dash_invulnerable = false
	_refresh_invincible_meta()

func _activate_resonance() -> void:
	if _e_cooldown_remaining > 0.0:
		Global.spawn_floating_text(global_position, "CD", Color(0.9, 0.8, 0.4))
		return
	if not consume_energy(resonance_energy_cost):
		return
	_e_cooldown_remaining = resonance_cooldown

	var scar: MinimalistSlashScar = _get_active_scar()
	if scar == null:
		Global.spawn_floating_text(global_position, "MISS", Color(1.0, 0.4, 0.4))
		SoundManager.play("ui_error")
		return

	var path_points: PackedVector2Array = scar.get_path_points()
	_apply_resonance_effect(scar, path_points)
	_spawn_path_band_flash(path_points, resonance_half_width, Color(1.0, 0.82, 0.52, 0.42), Color(1.0, 0.46, 0.14, 0.30), 0.08, 0.20)
	Global.spawn_floating_text(global_position, "RESONANCE", Color(1.0, 0.82, 0.45))

func _activate_dimension_slash() -> void:
	if _f_sequence_active():
		return
	var energy_cost: float = max_energy * (dimension_energy_percent / 100.0)
	if not consume_energy(energy_cost):
		return

	var scar: MinimalistSlashScar = _get_active_scar()
	if scar == null:
		energy = min(max_energy, energy + energy_cost)
		update_ui_signals()
		Global.spawn_floating_text(global_position, "MISS", Color(1.0, 0.4, 0.4))
		SoundManager.play("ui_error")
		return

	var hit_enemies: Array = []
	var sample_points: PackedVector2Array = scar.sample_points_along_path(dimension_sample_step)
	if sample_points.is_empty():
		sample_points = scar.get_path_points()
	for sample: Vector2 in sample_points:
		_spawn_dimension_explosion(sample)
		hit_enemies.append_array(_apply_dimension_explosion(sample))

	_f_sequence_timer = dimension_sequence_duration
	_f_pending_teleport = scar.get_end_point()
	if is_instance_valid(_current_scar):
		_current_scar.queue_free()
		_current_scar = null
	_refresh_invincible_meta()
	Global.spawn_floating_text(global_position, "DIMENSION", Color(0.88, 0.92, 1.0))
	if not hit_enemies.is_empty():
		notify_front_skill_damage("f", hit_enemies, {
			"skill_id": "f_minimalist",
			"source": "dimension_slash",
		})

func _finish_dimension_slash() -> void:
	global_position = _f_pending_teleport
	_f_pending_teleport = Vector2.ZERO
	_refresh_invincible_meta()

func _f_sequence_active() -> bool:
	return _f_sequence_timer > 0.0

func _refresh_invincible_meta() -> void:
	var should_be_invincible: bool = _dash_invulnerable or _f_sequence_active()
	if should_be_invincible:
		set_meta("buff_invincible", true)
	elif has_meta("buff_invincible"):
		remove_meta("buff_invincible")

func _spawn_or_replace_scar(points: PackedVector2Array, half_width: float) -> void:
	if is_instance_valid(_current_scar):
		_current_scar.queue_free()
		_current_scar = null
	if SCAR_SCENE == null:
		return
	var scar: MinimalistSlashScar = SCAR_SCENE.instantiate() as MinimalistSlashScar
	if scar == null:
		return
	get_tree().current_scene.add_child(scar)
	scar.setup(points, scar_lifetime, half_width)
	_current_scar = scar

func _get_active_scar() -> MinimalistSlashScar:
	if is_instance_valid(_current_scar) and not _current_scar.is_queued_for_deletion():
		return _current_scar
	_current_scar = null
	for node: Node in get_tree().get_nodes_in_group("minimalist_slash_scar"):
		if node is MinimalistSlashScar and is_instance_valid(node) and not node.is_queued_for_deletion():
			_current_scar = node as MinimalistSlashScar
			return _current_scar
	return null

func _apply_resonance_effect(scar: MinimalistSlashScar, path_points: PackedVector2Array) -> void:
	for enemy_node: Node in get_tree().get_nodes_in_group("enemies"):
		if not (enemy_node is Enemy):
			continue
		var enemy: Enemy = enemy_node as Enemy
		if not is_instance_valid(enemy) or enemy.is_dead:
			continue

		var nearest: Vector2 = scar.get_nearest_point(enemy.global_position)
		if enemy.global_position.distance_to(nearest) > resonance_half_width:
			continue

		if enemy.has_method("apply_move_speed_modifier"):
			enemy.apply_move_speed_modifier(
				"minimalist_resonance_stun",
				0.0,
				resonance_stun_duration,
				CombatModifierComponent.STACK_REFRESH,
				self,
				{"kind": "minimalist_resonance"}
			)

		var tangent: Vector2 = _get_nearest_segment_tangent(path_points, nearest)
		var normal: Vector2 = Vector2(-tangent.y, tangent.x)
		var side_sign: float = sign(normal.dot(enemy.global_position - nearest))
		if is_zero_approx(side_sign):
			side_sign = 1.0
		enemy.global_position += normal * side_sign * resonance_knockback_distance
		if enemy.has_method("set_flash_material"):
			enemy.set_flash_material()

func _get_nearest_segment_tangent(points: PackedVector2Array, target: Vector2) -> Vector2:
	var best_distance_sq: float = INF
	var best_tangent: Vector2 = Vector2.RIGHT
	for i in range(points.size() - 1):
		var a: Vector2 = points[i]
		var b: Vector2 = points[i + 1]
		var closest: Vector2 = Geometry2D.get_closest_point_to_segment(target, a, b)
		var distance_sq: float = target.distance_squared_to(closest)
		if distance_sq >= best_distance_sq:
			continue
		best_distance_sq = distance_sq
		var tangent: Vector2 = (b - a).normalized()
		if tangent.length_squared() > 0.0:
			best_tangent = tangent
	return best_tangent

func _apply_dimension_explosion(center: Vector2) -> Array:
	var hit_enemies: Array = []
	for enemy_node: Node in get_tree().get_nodes_in_group("enemies"):
		if not (enemy_node is Enemy):
			continue
		var enemy: Enemy = enemy_node as Enemy
		if not is_instance_valid(enemy) or enemy.is_dead:
			continue
		if enemy.global_position.distance_to(center) > dimension_explosion_radius:
			continue
		if _apply_damage_to_enemy(enemy, damage * dimension_true_damage_ratio, true, "VOID"):
			hit_enemies.append(enemy)
	return hit_enemies

func _apply_polyline_damage(points: PackedVector2Array, half_width: float, damage_amount: float, true_damage: bool, label: String) -> int:
	var hit_count: int = 0
	for enemy_node: Node in get_tree().get_nodes_in_group("enemies"):
		if not (enemy_node is Enemy):
			continue
		var enemy: Enemy = enemy_node as Enemy
		if not is_instance_valid(enemy) or enemy.is_dead:
			continue
		if not _is_point_inside_polyline_width(enemy.global_position, points, half_width):
			continue
		if _apply_damage_to_enemy(enemy, damage_amount, true_damage, label):
			hit_count += 1
	return hit_count

func _is_point_inside_polyline_width(point: Vector2, points: PackedVector2Array, half_width: float) -> bool:
	if points.size() < 2:
		return false
	var half_width_sq: float = half_width * half_width
	for i in range(points.size() - 1):
		var start: Vector2 = points[i]
		var finish: Vector2 = points[i + 1]
		var closest: Vector2 = Geometry2D.get_closest_point_to_segment(point, start, finish)
		if point.distance_squared_to(closest) <= half_width_sq:
			return true
	return false

func _apply_damage_to_enemy(enemy: Enemy, damage_amount: float, true_damage: bool, label: String) -> bool:
	if not is_instance_valid(enemy) or enemy.is_dead or enemy.health_component == null:
		return false
	if enemy.has_method("set_flash_material"):
		enemy.set_flash_material()
	if true_damage:
		_apply_true_damage(enemy, damage_amount)
	else:
		enemy.health_component.take_damage(damage_amount)
	Global.spawn_floating_text(enemy.global_position, label, Color(1.0, 0.95, 0.7))
	return true

func _apply_true_damage(enemy: Enemy, damage_amount: float) -> void:
	var hc: HealthComponent = enemy.health_component
	if hc == null or hc.current_health <= 0.0:
		return
	hc.current_health = max(0.0, hc.current_health - damage_amount)
	hc.on_unit_hit.emit()
	if hc.current_health == 0.0:
		hc.on_unit_died.emit()
		hc.die()

func _trigger_hitstop_if_needed(total_length: float) -> void:
	if total_length < hitstop_threshold_length:
		return
	var hitstop_duration: float = hitstop_base_duration + min((total_length - hitstop_threshold_length) / hitstop_bonus_length, 1.0) * hitstop_bonus_duration
	_apply_global_hitstop(hitstop_duration)

func _apply_global_hitstop(duration: float) -> void:
	_resume_global_hitstop()
	_global_hitstop_timer = duration
	_paused_nodes.clear()
	for group_name: String in ["enemies", "projectiles", "elite_projectiles"]:
		for node: Node in get_tree().get_nodes_in_group(group_name):
			if not is_instance_valid(node) or node == self:
				continue
			_paused_nodes.append(_capture_pause_state(node))

func _capture_pause_state(node: Node) -> Dictionary:
	var state: Dictionary = {
		"node_ref": weakref(node),
		"process_mode": node.process_mode,
		"anims": [],
	}
	node.process_mode = Node.PROCESS_MODE_DISABLED
	for anim_node: Node in node.find_children("*", "AnimationPlayer", true, false):
		if not (anim_node is AnimationPlayer):
			continue
		var anim: AnimationPlayer = anim_node as AnimationPlayer
		var was_playing: bool = anim.is_playing()
		(state["anims"] as Array).append({
			"anim_ref": weakref(anim),
			"was_playing": was_playing,
		})
		if was_playing:
			anim.pause()
	return state

func _resume_global_hitstop() -> void:
	if _paused_nodes.is_empty():
		_global_hitstop_timer = 0.0
		return
	for state_variant: Variant in _paused_nodes:
		if not (state_variant is Dictionary):
			continue
		var state: Dictionary = state_variant
		var node_ref_variant: Variant = state.get("node_ref", null)
		if node_ref_variant == null or not (node_ref_variant is WeakRef):
			continue
		var node: Node = (node_ref_variant as WeakRef).get_ref() as Node
		if node == null or not is_instance_valid(node):
			continue
		node.process_mode = int(state.get("process_mode", Node.PROCESS_MODE_INHERIT))
		var anims: Array = state.get("anims", [])
		for anim_state_variant: Variant in anims:
			if not (anim_state_variant is Dictionary):
				continue
			var anim_state: Dictionary = anim_state_variant
			var anim_ref_variant: Variant = anim_state.get("anim_ref", null)
			if anim_ref_variant == null or not (anim_ref_variant is WeakRef):
				continue
			var anim: AnimationPlayer = (anim_ref_variant as WeakRef).get_ref() as AnimationPlayer
			if anim != null and is_instance_valid(anim) and bool(anim_state.get("was_playing", false)):
				anim.play()
	_paused_nodes.clear()
	_global_hitstop_timer = 0.0

func _spawn_path_band_flash(points: PackedVector2Array, half_width: float, inner_color: Color, outer_color: Color, expand_time: float, fade_time: float) -> void:
	if points.size() < 2:
		return
	var root: Node2D = Node2D.new()
	root.add_to_group("player_skill_effects")
	var outer_line: Line2D = Line2D.new()
	outer_line.top_level = true
	outer_line.points = points
	outer_line.width = 10.0
	outer_line.default_color = outer_color
	outer_line.joint_mode = Line2D.LINE_JOINT_ROUND
	outer_line.begin_cap_mode = Line2D.LINE_CAP_ROUND
	outer_line.end_cap_mode = Line2D.LINE_CAP_ROUND
	outer_line.antialiased = true
	outer_line.z_index = 31
	root.add_child(outer_line)

	var inner_line: Line2D = Line2D.new()
	inner_line.top_level = true
	inner_line.points = points
	inner_line.width = 4.0
	inner_line.default_color = inner_color
	inner_line.joint_mode = Line2D.LINE_JOINT_ROUND
	inner_line.begin_cap_mode = Line2D.LINE_CAP_ROUND
	inner_line.end_cap_mode = Line2D.LINE_CAP_ROUND
	inner_line.antialiased = true
	inner_line.z_index = 32
	root.add_child(inner_line)

	get_tree().current_scene.add_child(root)
	var final_width: float = max(4.0, half_width * 2.0)
	var tween: Tween = root.create_tween()
	tween.set_parallel(true)
	tween.tween_property(outer_line, "width", final_width + 18.0, expand_time)
	tween.tween_property(inner_line, "width", final_width, expand_time)
	tween.tween_property(outer_line, "modulate:a", 0.0, fade_time).set_delay(expand_time)
	tween.tween_property(inner_line, "modulate:a", 0.0, fade_time).set_delay(expand_time)
	tween.finished.connect(root.queue_free)

func _spawn_dimension_explosion(center: Vector2) -> void:
	var ring: Line2D = Line2D.new()
	ring.top_level = true
	ring.closed = true
	ring.width = 8.0
	ring.default_color = Color(0.86, 0.92, 1.0, 0.92)
	ring.antialiased = true
	var points: PackedVector2Array = PackedVector2Array()
	for i in range(25):
		var angle: float = (float(i) / 24.0) * TAU
		points.append(center + Vector2.RIGHT.rotated(angle) * dimension_explosion_radius)
	ring.points = points
	get_tree().current_scene.add_child(ring)
	var tween: Tween = ring.create_tween()
	tween.set_parallel(true)
	tween.tween_property(ring, "scale", Vector2(1.18, 1.18), 0.16)
	tween.tween_property(ring, "modulate:a", 0.0, 0.16)
	tween.finished.connect(ring.queue_free)

func _compute_path_length(points: PackedVector2Array) -> float:
	var total: float = 0.0
	for i in range(points.size() - 1):
		total += points[i].distance_to(points[i + 1])
	return total

func _packed_to_points(points: PackedVector2Array) -> Array[Vector2]:
	var result: Array[Vector2] = []
	for point: Vector2 in points:
		result.append(point)
	return result

func _calculate_path_center(points: PackedVector2Array) -> Vector2:
	if points.is_empty():
		return global_position
	var center: Vector2 = Vector2.ZERO
	for point: Vector2 in points:
		center += point
	return center / float(points.size())

func _estimate_draw_cost(points: PackedVector2Array) -> float:
	var cost: float = draw_base_energy_cost
	for i in range(points.size() - 1):
		var segment_length: float = points[i].distance_to(points[i + 1])
		cost += (segment_length / max(0.001, draw_sample_spacing)) * draw_energy_cost_per_step
	return cost

func _compute_slash_width_coefficient(total_length: float) -> float:
	return min(total_length / max(1.0, slash_width_length_cap), 1.0)

func _compute_slash_half_width(total_length: float) -> float:
	return slash_base_half_width + _compute_slash_width_coefficient(total_length) * slash_bonus_half_width

func _ensure_live_band_preview() -> void:
	if is_instance_valid(_draw_band_outer) and is_instance_valid(_draw_band_inner):
		return
	_draw_band_outer = Line2D.new()
	_draw_band_outer.top_level = true
	_draw_band_outer.default_color = Color(1.0, 0.42, 0.08, 0.42)
	_draw_band_outer.joint_mode = Line2D.LINE_JOINT_ROUND
	_draw_band_outer.begin_cap_mode = Line2D.LINE_CAP_ROUND
	_draw_band_outer.end_cap_mode = Line2D.LINE_CAP_ROUND
	_draw_band_outer.antialiased = true
	_draw_band_outer.z_index = 33
	add_child(_draw_band_outer)

	_draw_band_inner = Line2D.new()
	_draw_band_inner.top_level = true
	_draw_band_inner.default_color = Color(1.0, 0.9, 0.62, 0.46)
	_draw_band_inner.joint_mode = Line2D.LINE_JOINT_ROUND
	_draw_band_inner.begin_cap_mode = Line2D.LINE_CAP_ROUND
	_draw_band_inner.end_cap_mode = Line2D.LINE_CAP_ROUND
	_draw_band_inner.antialiased = true
	_draw_band_inner.z_index = 34
	add_child(_draw_band_inner)

func _refresh_draw_visual() -> void:
	_ensure_live_band_preview()
	var preview_points: PackedVector2Array = _draw_points
	if is_instance_valid(draw_line):
		draw_line.points = preview_points
	if preview_points.size() < 2:
		if is_instance_valid(_draw_band_outer):
			_draw_band_outer.points = PackedVector2Array()
		if is_instance_valid(_draw_band_inner):
			_draw_band_inner.points = PackedVector2Array()
		return

	var total_length: float = _compute_path_length(preview_points)
	var width_coeff: float = _compute_slash_width_coefficient(total_length)
	var half_width: float = _compute_slash_half_width(total_length)
	var band_width: float = max(half_width * 2.0, slash_base_half_width * 2.0)

	if is_instance_valid(draw_line):
		draw_line.width = lerp(10.0, 24.0, width_coeff)
		draw_line.modulate = Color(1.0, 1.0, 1.0, lerp(0.92, 1.0, width_coeff))
	if is_instance_valid(_draw_band_outer):
		_draw_band_outer.points = preview_points
		_draw_band_outer.width = band_width + 32.0
		_draw_band_outer.modulate = Color(1.0, 1.0, 1.0, lerp(0.38, 0.62, width_coeff))
	if is_instance_valid(_draw_band_inner):
		_draw_band_inner.points = preview_points
		_draw_band_inner.width = band_width + 10.0
		_draw_band_inner.modulate = Color(1.0, 1.0, 1.0, lerp(0.42, 0.66, width_coeff))

func _clear_draw_visual() -> void:
	if is_instance_valid(draw_line):
		draw_line.points = PackedVector2Array()
	if is_instance_valid(_draw_band_outer):
		_draw_band_outer.points = PackedVector2Array()
	if is_instance_valid(_draw_band_inner):
		_draw_band_inner.points = PackedVector2Array()
