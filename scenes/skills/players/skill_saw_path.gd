extends SkillBase
class_name SkillSawPath

var energy_per_10px: float = 1.0
var energy_threshold_distance: float = 1800.0
var energy_scale_multiplier: float = 0.001

const POINT_INTERVAL: float = 10.0

var saw_fly_speed: float = 1100.0
var saw_damage_tick: int = 3
var saw_damage_open: int = 1
var saw_contact_interval: float = 0.32
var saw_area_interval: float = 0.32
var chain_radius: float = 250.0
var saw_max_distance: float = 900.0
var saw_launch_distance_cap: float = 220.0
var saw_rotation_speed: float = 25.0
var saw_push_force: float = 1000.0
var closure_duration: float = 6.7
var dismember_damage: int = 72
var close_threshold: float = 60.0

var planning_color_normal: Color = Color(1.0, 1.0, 1.0, 0.5)
var planning_color_closed: Color = Color(1.0, 0.0, 0.0, 1.0)

var is_planning: bool = false
var is_drawing: bool = false
var is_dashing: bool = false
var is_path_closed: bool = false

var last_point: Vector2 = Vector2.ZERO
var total_distance_drawn: float = 0.0

var path_points: Array[Vector2] = []
var path_segments: Array[Dictionary] = []

var active_saw: Node2D = null
var line_2d: Line2D = null

func _ready() -> void:
	super._ready()
	_ensure_line_2d()

func _process(delta: float) -> void:
	super._process(delta)
	if is_dashing and (not is_instance_valid(active_saw)):
		is_dashing = false
	_update_planning_visuals()

func charge(_delta: float) -> void:
	if is_instance_valid(active_saw) and not is_planning:
		if active_saw.has_method("manual_dismiss"):
			active_saw.call("manual_dismiss")
		active_saw = null
		is_dashing = false
		return

	if not is_planning:
		_enter_planning_mode()

	if not is_planning or not is_instance_valid(skill_owner):
		return

	if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		if not is_drawing:
			is_drawing = true
		_extend_path_by_mouse()
	else:
		is_drawing = false

	if Input.is_action_just_pressed("click_right"):
		_clear_all_points()

func release() -> void:
	if is_planning:
		_launch_saw_construct()

func cancel_planning_state(refund_energy: bool = false) -> void:
	if not is_planning:
		return
	if refund_energy:
		var refunded: float = _calculate_total_consumed_energy()
		if refunded > 0.0 and is_instance_valid(skill_owner):
			skill_owner.energy += refunded
			if skill_owner.has_method("update_ui_signals"):
				skill_owner.update_ui_signals()

	is_planning = false
	is_drawing = false
	is_charging = false
	is_path_closed = false
	Engine.time_scale = 1.0
	path_points.clear()
	path_segments.clear()
	total_distance_drawn = 0.0
	if is_instance_valid(line_2d):
		line_2d.clear_points()

func _enter_planning_mode() -> void:
	_ensure_line_2d()
	is_planning = true
	is_drawing = false
	is_charging = true
	is_dashing = false
	is_path_closed = false
	total_distance_drawn = 0.0
	Engine.time_scale = 0.1

	path_points.clear()
	path_segments.clear()
	if is_instance_valid(line_2d):
		line_2d.clear_points()

	if is_instance_valid(skill_owner):
		last_point = skill_owner.get_global_mouse_position()
		path_points.append(last_point)

func _ensure_line_2d() -> void:
	if line_2d != null and not is_instance_valid(line_2d):
		line_2d = null
	if is_instance_valid(line_2d):
		return
	if not is_instance_valid(skill_owner):
		return

	line_2d = Line2D.new()
	line_2d.name = "SawPathLine"
	line_2d.top_level = true
	line_2d.width = 6.0
	line_2d.z_index = 100
	line_2d.global_position = Vector2.ZERO
	skill_owner.add_child(line_2d)

func _extend_path_by_mouse() -> void:
	if not is_instance_valid(skill_owner):
		return

	var mouse_pos: Vector2 = skill_owner.get_global_mouse_position()
	var distance_to_mouse: float = last_point.distance_to(mouse_pos)
	if distance_to_mouse < 1.0:
		return

	var points_to_add: int = max(1, int(distance_to_mouse / POINT_INTERVAL))
	var direction: Vector2 = (mouse_pos - last_point).normalized()

	for _i: int in range(points_to_add):
		var current_energy_cost: float = _calculate_current_energy_cost()
		if skill_owner.energy < current_energy_cost:
			is_drawing = false
			Global.spawn_floating_text(skill_owner.global_position, "No Energy!", Color.RED)
			return

		skill_owner.consume_energy(current_energy_cost)
		total_distance_drawn += POINT_INTERVAL

		var new_point: Vector2 = last_point + direction * POINT_INTERVAL
		path_points.append(new_point)
		path_segments.append({"start": last_point, "end": new_point})
		last_point = new_point

		_check_intersection_and_closure()

func _check_intersection_and_closure() -> void:
	if is_path_closed:
		return
	if path_segments.size() < 3:
		return

	var threshold: float = _get_effective_close_threshold()

	var latest_seg: Dictionary = path_segments[path_segments.size() - 1]
	for i: int in range(path_segments.size() - 2):
		var old_seg: Dictionary = path_segments[i]
		if _segments_intersect(latest_seg, old_seg):
			is_path_closed = true
			return

	if path_points.size() >= 12:
		var current_point: Vector2 = path_points[path_points.size() - 1]
		if current_point.distance_to(path_points[0]) < threshold:
			is_path_closed = true

func _segments_intersect(seg1: Dictionary, seg2: Dictionary) -> bool:
	var p1: Vector2 = seg1.get("start", Vector2.ZERO)
	var p2: Vector2 = seg1.get("end", Vector2.ZERO)
	var p3: Vector2 = seg2.get("start", Vector2.ZERO)
	var p4: Vector2 = seg2.get("end", Vector2.ZERO)
	var intersection: Variant = Geometry2D.segment_intersects_segment(p1, p2, p3, p4)
	return intersection != null

func _clear_all_points() -> void:
	var total_consumed_energy: float = _calculate_total_consumed_energy()
	if is_instance_valid(skill_owner) and total_consumed_energy > 0.0:
		skill_owner.energy += total_consumed_energy
		if skill_owner.has_method("update_ui_signals"):
			skill_owner.update_ui_signals()

	path_points.clear()
	path_segments.clear()
	is_path_closed = false
	total_distance_drawn = 0.0

	if is_instance_valid(skill_owner):
		last_point = skill_owner.get_global_mouse_position()
		path_points.append(last_point)

func _calculate_current_energy_cost() -> float:
	if total_distance_drawn <= energy_threshold_distance:
		return energy_per_10px
	var excess_distance: float = total_distance_drawn - energy_threshold_distance
	var multiplier: float = 1.0 + excess_distance * energy_scale_multiplier
	return energy_per_10px * multiplier

func _calculate_total_consumed_energy() -> float:
	var total: float = 0.0
	var distance: float = 0.0
	while distance < total_distance_drawn:
		if distance <= energy_threshold_distance:
			total += energy_per_10px
		else:
			var excess: float = distance - energy_threshold_distance
			var multiplier: float = 1.0 + excess * energy_scale_multiplier
			total += energy_per_10px * multiplier
		distance += POINT_INTERVAL
	return total

func _launch_saw_construct() -> void:
	is_planning = false
	is_drawing = false
	is_charging = false
	Engine.time_scale = 1.0

	if is_instance_valid(line_2d):
		line_2d.clear_points()

	if path_points.size() < 2:
		path_points.clear()
		path_segments.clear()
		is_path_closed = false
		return

	_perform_final_closure_check()

	if is_instance_valid(active_saw):
		active_saw.queue_free()
		active_saw = null

	if not is_instance_valid(skill_owner):
		return

	var player_pos: Vector2 = skill_owner.global_position
	var path_center: Vector2 = Vector2.ZERO
	for point: Vector2 in path_points:
		path_center += point
	path_center /= float(path_points.size())

	var launch_dir: Vector2 = (path_center - player_pos).normalized()
	if launch_dir.length_squared() <= 0.0001:
		launch_dir = (path_points[path_points.size() - 1] - path_points[0]).normalized()
	if launch_dir.length_squared() <= 0.0001:
		launch_dir = Vector2.RIGHT

	var launch_distance: float = min(saw_max_distance, saw_launch_distance_cap)
	# 将行为参数下发到投射物，便于通过 CSV 直接调手感。
	skill_owner.set("saw_contact_interval", saw_contact_interval)
	skill_owner.set("saw_area_interval", saw_area_interval)
	skill_owner.set("closure_duration", closure_duration)
	skill_owner.set("dismember_damage", dismember_damage)
	var saw: SawProjectile = SawProjectile.new()
	saw.name = "Saw_%s" % str(Time.get_ticks_msec())
	skill_owner.get_parent().add_child(saw)
	saw.global_position = player_pos
	saw.setup(path_points.duplicate(), is_path_closed, launch_dir, skill_owner, launch_distance, chain_radius)

	active_saw = saw
	is_dashing = true
	Global.on_camera_shake.emit(5.0, 0.16)

	path_points.clear()
	path_segments.clear()
	total_distance_drawn = 0.0
	is_path_closed = false

	start_cooldown()

func _perform_final_closure_check() -> void:
	is_path_closed = false
	if path_segments.size() < 3:
		return

	var threshold: float = _get_effective_close_threshold()

	for i: int in range(path_segments.size()):
		for j: int in range(i + 2, path_segments.size()):
			var seg1: Dictionary = path_segments[i]
			var seg2: Dictionary = path_segments[j]
			if _segments_intersect(seg1, seg2):
				is_path_closed = true
				return

	if path_points.size() < 3:
		return

	var end_point: Vector2 = path_points[path_points.size() - 1]
	if end_point.distance_to(path_points[0]) < threshold:
		is_path_closed = true
		return

func _get_effective_close_threshold() -> float:
	if not is_instance_valid(skill_owner):
		return close_threshold
	if "close_threshold" in skill_owner:
		var owner_threshold: float = float(skill_owner.get("close_threshold"))
		if owner_threshold > 0.0:
			return owner_threshold
	return close_threshold

func _update_planning_visuals() -> void:
	_ensure_line_2d()
	if not is_instance_valid(line_2d):
		return

	if not is_planning:
		line_2d.clear_points()
		return

	line_2d.global_position = Vector2.ZERO
	line_2d.clear_points()
	if path_points.is_empty():
		return

	for point: Vector2 in path_points:
		line_2d.add_point(point)

	if is_drawing and is_instance_valid(skill_owner):
		line_2d.add_point(skill_owner.get_global_mouse_position())

	if is_path_closed:
		line_2d.default_color = planning_color_closed
		line_2d.width = 8.0
	else:
		line_2d.default_color = planning_color_normal
		line_2d.width = 6.0

func can_move() -> bool:
	return not is_planning

func cleanup() -> void:
	if is_planning:
		Engine.time_scale = 1.0
	is_planning = false
	is_drawing = false
	is_charging = false
	is_dashing = false

	if is_instance_valid(line_2d):
		line_2d.queue_free()
	line_2d = null

	if is_instance_valid(active_saw):
		active_saw.queue_free()
	active_saw = null

	path_points.clear()
	path_segments.clear()
	total_distance_drawn = 0.0
	is_path_closed = false
