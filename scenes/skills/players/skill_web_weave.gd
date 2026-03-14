extends SkillBase
class_name SkillWebWeave

enum SkillState { IDLE, PLANNING, WEAVE, RECALL }

var energy_per_10px: float = 1.0
var energy_threshold_distance: float = 1800.0
var energy_scale_multiplier: float = 0.0006
const POINT_INTERVAL: float = 10.0

var recall_fly_speed: float = 3.2
var recall_damage: int = 46
var recall_execute_mult: float = 2.8
var auto_recall_delay: float = 7.0
var close_threshold: float = 60.0
var shuttle_step_distance: float = 50.0
var shuttle_tick_interval: float = 0.05
var shuttle_hit_radius: float = 52.0
var shuttle_hit_damage: int = 15
var shuttle_push: float = 14.0
var shuttle_recall_delay: float = 0.2
var shuttle_recall_count: int = 5
var shuttle_recall_damage: int = 18
var shuttle_recall_pull: float = 24.0
var collapse_count: int = 6
var collapse_interval: float = 0.16
var collapse_damage: int = 20

var web_color_open: Color = Color(0.6, 0.8, 1.0, 0.8)
var web_color_closed: Color = Color(1.0, 0.5, 0.2, 0.9)
var web_color_fill: Color = Color(1.0, 0.2, 0.2, 0.3)

var skill_state: SkillState = SkillState.IDLE
var is_planning: bool = false
var is_drawing: bool = false
var is_dashing: bool = false

var last_point: Vector2 = Vector2.ZERO
var total_distance_drawn: float = 0.0
var has_closure: bool = false
var current_web_timer: float = 0.0

var path_points: Array[Vector2] = []
var path_segments: Array[Dictionary] = []
var active_web_lines: Array[Line2D] = []
var active_trap_polygons: Array[Polygon2D] = []
var trapped_enemies: Array[WeakRef] = []

var recall_progress: Dictionary = {}
var recall_line_start: Dictionary = {}
var recall_line_end: Dictionary = {}
var hit_history: Dictionary = {}
var _recall_bonus_mult: float = 1.0
var _forced_pull_strength: float = 0.0

var line_2d: Line2D = null
var web_container: Node2D = null

func _ready() -> void:
	super._ready()
	_ensure_web_nodes()

func _process(delta: float) -> void:
	super._process(delta)
	_ensure_web_nodes()
	_update_planning_visuals()
	_process_recall(delta)

	if skill_state == SkillState.WEAVE:
		current_web_timer += delta
		var manual_trigger: bool = Input.is_action_just_pressed("skill_q")
		var auto_trigger: bool = current_web_timer >= auto_recall_delay
		if manual_trigger or auto_trigger:
			_start_recall(1.0, 0.0)

func charge(_delta: float) -> void:
	if skill_state == SkillState.RECALL:
		return

	if skill_state == SkillState.IDLE and not is_planning:
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
		_deploy_web()

func trigger_forced_recall(damage_bonus_mult: float = 1.25, pull_strength: float = 480.0) -> bool:
	if skill_state != SkillState.WEAVE:
		return false
	_start_recall(max(1.0, damage_bonus_mult), max(0.0, pull_strength))
	return true

func has_active_web() -> bool:
	return skill_state == SkillState.WEAVE or skill_state == SkillState.RECALL

func _enter_planning_mode() -> void:
	if skill_state == SkillState.WEAVE:
		_cleanup_webs()

	_ensure_web_nodes()
	is_planning = true
	is_charging = true
	is_drawing = false
	has_closure = false
	total_distance_drawn = 0.0
	skill_state = SkillState.PLANNING
	Engine.time_scale = 0.1

	path_points.clear()
	path_segments.clear()
	if is_instance_valid(line_2d):
		line_2d.clear_points()

	if is_instance_valid(skill_owner):
		last_point = skill_owner.get_global_mouse_position()
		path_points.append(last_point)

func _ensure_web_nodes() -> void:
	if not is_instance_valid(skill_owner):
		return

	if web_container != null and not is_instance_valid(web_container):
		web_container = null
	if line_2d != null and not is_instance_valid(line_2d):
		line_2d = null

	if not is_instance_valid(web_container):
		web_container = Node2D.new()
		web_container.name = "WebContainer"
		web_container.top_level = true
		web_container.global_position = Vector2.ZERO
		skill_owner.add_child(web_container)

	if not is_instance_valid(line_2d):
		line_2d = Line2D.new()
		line_2d.name = "WebPlanningLine"
		line_2d.top_level = true
		line_2d.width = 4.0
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
	if has_closure:
		return
	if path_segments.size() < 3:
		return
	var threshold: float = _get_effective_close_threshold()

	var latest_seg: Dictionary = path_segments[path_segments.size() - 1]
	for i: int in range(path_segments.size() - 2):
		var old_seg: Dictionary = path_segments[i]
		if _segments_intersect(latest_seg, old_seg):
			has_closure = true
			return

	if path_points.size() >= 12:
		var current_point: Vector2 = path_points[path_points.size() - 1]
		if current_point.distance_to(path_points[0]) < threshold:
			has_closure = true

func _segments_intersect(seg1: Dictionary, seg2: Dictionary) -> bool:
	var p1: Vector2 = seg1.get("start", Vector2.ZERO)
	var p2: Vector2 = seg1.get("end", Vector2.ZERO)
	var p3: Vector2 = seg2.get("start", Vector2.ZERO)
	var p4: Vector2 = seg2.get("end", Vector2.ZERO)
	var intersection: Variant = Geometry2D.segment_intersects_segment(p1, p2, p3, p4)
	return intersection != null

func _clear_all_points() -> void:
	var refunded: float = _calculate_total_consumed_energy()
	if is_instance_valid(skill_owner) and refunded > 0.0:
		skill_owner.energy += refunded
		if skill_owner.has_method("update_ui_signals"):
			skill_owner.update_ui_signals()

	path_points.clear()
	path_segments.clear()
	total_distance_drawn = 0.0
	has_closure = false

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

func _update_planning_visuals() -> void:
	if not is_instance_valid(line_2d):
		return
	if not is_planning:
		if skill_state == SkillState.IDLE:
			line_2d.clear_points()
		return

	line_2d.global_position = Vector2.ZERO
	line_2d.clear_points()
	for point: Vector2 in path_points:
		line_2d.add_point(point)
	if is_drawing and is_instance_valid(skill_owner):
		line_2d.add_point(skill_owner.get_global_mouse_position())

	line_2d.default_color = web_color_closed if has_closure else web_color_open
	line_2d.width = 6.0 if has_closure else 4.0

func _deploy_web() -> void:
	is_planning = false
	is_drawing = false
	is_charging = false
	Engine.time_scale = 1.0
	skill_state = SkillState.WEAVE
	current_web_timer = 0.0

	if path_points.size() < 2:
		skill_state = SkillState.IDLE
		_cleanup_webs()
		return

	_perform_final_closure_check()
	for i: int in range(path_points.size() - 1):
		_create_web_line(path_points[i], path_points[i + 1])

	var loops: Array[PackedVector2Array] = PolygonUtils.find_all_closing_polygons(path_points, _get_effective_close_threshold())
	for polygon: PackedVector2Array in loops:
		_create_trap_polygon(polygon)
	if path_points.size() >= 2:
		_launch_silk_shuttle(path_points[0], path_points[path_points.size() - 1])
	if has_closure and not loops.is_empty():
		_spawn_web_collapse(loops[0])

	path_points.clear()
	path_segments.clear()
	if is_instance_valid(line_2d):
		line_2d.clear_points()
	start_cooldown()

func _launch_silk_shuttle(start: Vector2, finish: Vector2) -> void:
	var seg: Vector2 = finish - start
	var length: float = seg.length()
	if length <= 1.0:
		return
	var move_dir: Vector2 = seg / length
	var host: Node2D = Node2D.new()
	host.name = "WeaverShuttleHost"
	add_child(host)

	var step_total: int = int(max(2.0, ceil(length / max(12.0, shuttle_step_distance))))
	var step_index: int = 0
	var timer: Timer = Timer.new()
	timer.wait_time = max(0.03, shuttle_tick_interval)
	timer.one_shot = false
	host.add_child(timer)
	timer.timeout.connect(func() -> void:
		if not is_instance_valid(host):
			return
		if step_index > step_total:
			timer.stop()
			host.queue_free()
			_spawn_shuttle_recall(finish, start, move_dir)
			return
		_emit_shuttle_tick(start, finish, step_index, step_total, move_dir)
		step_index += 1
	)
	timer.start()

func _spawn_shuttle_recall(from_pos: Vector2, to_pos: Vector2, move_dir: Vector2) -> void:
	var tree: SceneTree = get_tree()
	if tree == null:
		return
	tree.create_timer(max(0.05, shuttle_recall_delay)).timeout.connect(func() -> void:
		if not is_inside_tree():
			return
		var host: Node2D = Node2D.new()
		host.name = "WeaverShuttleRecallHost"
		add_child(host)
		var pulse_total: int = int(max(1, shuttle_recall_count))
		var pulse_index: int = 0
		var timer: Timer = Timer.new()
		timer.wait_time = max(0.06, collapse_interval * 0.75)
		timer.one_shot = false
		host.add_child(timer)
		timer.timeout.connect(func() -> void:
			if not is_instance_valid(host):
				return
			if pulse_index >= pulse_total:
				timer.stop()
				host.queue_free()
				return
			_emit_shuttle_recall_tick(from_pos, to_pos, pulse_index, pulse_total, move_dir)
			pulse_index += 1
		)
		timer.start()
	)

func _emit_shuttle_tick(start: Vector2, finish: Vector2, index: int, total: int, move_dir: Vector2) -> void:
	var t: float = float(index) / float(max(1, total))
	var prev_t: float = float(max(0, index - 1)) / float(max(1, total))
	var current: Vector2 = start.lerp(finish, t)
	var previous: Vector2 = start.lerp(finish, prev_t)
	SkillEffectManager.create_line_effect({
		"start": previous,
		"end": current,
		"width": 11.0,
		"damage": 0,
		"damage_interval": 0.2,
		"duration": 0.12,
		"color": Color(0.78, 0.92, 1.08, 0.92)
	})
	_apply_shuttle_hit(current, shuttle_hit_radius, shuttle_hit_damage, move_dir, shuttle_push)

func _emit_shuttle_recall_tick(
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
	var start: Vector2 = center - tangent * 68.0
	var end: Vector2 = center + tangent * 68.0
	SkillEffectManager.create_line_effect({
		"start": start,
		"end": end,
		"width": 11.0,
		"damage": 0,
		"damage_interval": 0.2,
		"duration": 0.16,
		"color": Color(0.9, 1.0, 1.16, 0.92)
	})
	_apply_line_slice_damage(start, end, 12.0, shuttle_recall_damage)
	_apply_pull_to_point(center, shuttle_hit_radius * 1.45, shuttle_recall_pull)

func _spawn_web_collapse(polygon: PackedVector2Array) -> void:
	if polygon.size() < 3:
		return
	var center: Vector2 = Vector2.ZERO
	for point: Vector2 in polygon:
		center += point
	center /= float(polygon.size())
	var radius: float = 0.0
	for point: Vector2 in polygon:
		radius = max(radius, center.distance_to(point))
	var sweep_total: int = int(max(1, collapse_count))
	var sweep_index: int = 0
	var host: Node2D = Node2D.new()
	host.name = "WeaverCollapseHost"
	add_child(host)

	var timer: Timer = Timer.new()
	timer.wait_time = max(0.08, collapse_interval)
	timer.one_shot = false
	host.add_child(timer)
	timer.timeout.connect(func() -> void:
		if not is_instance_valid(host):
			return
		if sweep_index >= sweep_total:
			timer.stop()
			host.queue_free()
			return
		_emit_web_collapse_tick(center, radius, sweep_index, sweep_total)
		sweep_index += 1
	)
	timer.start()

func _emit_web_collapse_tick(center: Vector2, radius: float, index: int, total: int) -> void:
	var angle: float = TAU * float(index) / float(max(1, total))
	var dir: Vector2 = Vector2.RIGHT.rotated(angle)
	var start: Vector2 = center + dir * radius * 1.3
	var end: Vector2 = center - dir * radius * 0.08
	SkillEffectManager.create_line_effect({
		"start": start,
		"end": end,
		"width": 12.0,
		"damage": 0,
		"damage_interval": 0.2,
		"duration": 0.18,
		"color": Color(1.0, 0.72, 0.46, 0.9)
	})
	_apply_line_slice_damage(start, end, 12.0, collapse_damage)
	_apply_pull_to_point(center, radius * 0.9, shuttle_recall_pull * 0.75)

func _perform_final_closure_check() -> void:
	has_closure = false
	if path_segments.size() < 3:
		return
	var threshold: float = _get_effective_close_threshold()

	for i: int in range(path_segments.size()):
		for j: int in range(i + 2, path_segments.size()):
			if _segments_intersect(path_segments[i], path_segments[j]):
				has_closure = true
				return

	if path_points.size() < 3:
		return

	var end_point: Vector2 = path_points[path_points.size() - 1]
	if end_point.distance_to(path_points[0]) < threshold:
		has_closure = true
		return

func _get_effective_close_threshold() -> float:
	if not is_instance_valid(skill_owner):
		return close_threshold
	if "close_threshold" in skill_owner:
		var owner_threshold: float = float(skill_owner.get("close_threshold"))
		if owner_threshold > 0.0:
			return owner_threshold
	return close_threshold

func _create_web_line(from_pos: Vector2, to_pos: Vector2) -> void:
	if not is_instance_valid(web_container):
		return
	var line: Line2D = Line2D.new()
	line.width = 4.0
	line.default_color = web_color_open
	line.add_point(from_pos)
	line.add_point(to_pos)
	web_container.add_child(line)
	active_web_lines.append(line)

func _create_trap_polygon(polygon: PackedVector2Array) -> void:
	if not is_instance_valid(web_container):
		return
	var poly_node: Polygon2D = Polygon2D.new()
	poly_node.polygon = polygon
	poly_node.color = web_color_fill
	web_container.add_child(poly_node)
	active_trap_polygons.append(poly_node)
	_apply_trap_logic(polygon)

func _apply_trap_logic(polygon: PackedVector2Array) -> void:
	var polygons: Array[PackedVector2Array] = [polygon]
	PolygonUtils.show_closure_masks(polygons, Color(0.9, 0.3, 0.8, 0.62), get_tree(), 0.55)

	var enemies: Array = get_tree().get_nodes_in_group("enemies")
	var count: int = 0
	for enemy_obj: Variant in enemies:
		if enemy_obj == null or not is_instance_valid(enemy_obj):
			continue
		if not (enemy_obj is Node2D):
			continue
		var enemy: Node2D = enemy_obj
		if not Geometry2D.is_point_in_polygon(enemy.global_position, polygon):
			continue
		if _is_enemy_trapped(enemy):
			continue

		trapped_enemies.append(weakref(enemy))
		Global.spawn_floating_text(enemy.global_position, "TRAPPED!", Color(1.0, 0.32, 0.32))
		if "can_move" in enemy:
			enemy.set("can_move", false)
		enemy.modulate = Color(1.0, 0.55, 0.55)
		count += 1

	if count > 0:
		Global.on_camera_shake.emit(2.0 + float(count) * 0.5, 0.12)

func _is_enemy_trapped(enemy: Node2D) -> bool:
	for enemy_ref: WeakRef in trapped_enemies:
		if enemy_ref.get_ref() == enemy:
			return true
	return false

func _start_recall(bonus_mult: float, pull_strength: float) -> void:
	if skill_state != SkillState.WEAVE:
		return
	skill_state = SkillState.RECALL
	is_dashing = true
	hit_history.clear()
	_recall_bonus_mult = max(1.0, bonus_mult)
	_forced_pull_strength = max(0.0, pull_strength)

	recall_progress.clear()
	recall_line_start.clear()
	recall_line_end.clear()
	for line: Line2D in active_web_lines:
		if not is_instance_valid(line):
			continue
		var id: int = line.get_instance_id()
		recall_progress[id] = 0.0
		recall_line_start[id] = line.get_point_position(0)
		recall_line_end[id] = line.get_point_position(1)

	for poly: Polygon2D in active_trap_polygons:
		if is_instance_valid(poly):
			var tween: Tween = create_tween()
			tween.tween_property(poly, "modulate:a", 0.0, 0.25)
			tween.tween_callback(poly.queue_free)
	active_trap_polygons.clear()

func _process_recall(delta: float) -> void:
	if skill_state != SkillState.RECALL:
		return
	if not is_instance_valid(skill_owner):
		_cleanup_webs()
		return

	var target: Vector2 = skill_owner.global_position
	var has_active_line: bool = false

	for line: Line2D in active_web_lines:
		if not is_instance_valid(line):
			continue
		has_active_line = true
		var id: int = line.get_instance_id()
		var progress: float = float(recall_progress.get(id, 0.0))
		progress += delta * recall_fly_speed
		recall_progress[id] = progress

		var t: float = clamp(progress, 0.0, 1.0)
		var start0: Vector2 = recall_line_start.get(id, target)
		var end0: Vector2 = recall_line_end.get(id, target)
		var current_start: Vector2 = start0.lerp(target, t)
		var current_end: Vector2 = end0.lerp(target, t)
		line.set_point_position(0, current_start)
		line.set_point_position(1, current_end)

		if t < 0.95:
			_check_line_collision(current_start, current_end)

		if t >= 1.0:
			line.queue_free()
		elif t > 0.9:
			line.modulate.a = 1.0 - (t - 0.9) * 10.0

	if not has_active_line:
		_cleanup_webs()

func _check_line_collision(p1: Vector2, p2: Vector2) -> void:
	var enemies: Array = get_tree().get_nodes_in_group("enemies")
	for enemy_obj: Variant in enemies:
		if enemy_obj == null or not is_instance_valid(enemy_obj):
			continue
		if not (enemy_obj is Node2D):
			continue
		var enemy: Node2D = enemy_obj
		var enemy_id: int = enemy.get_instance_id()
		if hit_history.has(enemy_id):
			continue
		var close_p: Vector2 = Geometry2D.get_closest_point_to_segment(enemy.global_position, p1, p2)
		if enemy.global_position.distance_to(close_p) > 40.0:
			continue
		_apply_recall_damage(enemy)
		hit_history[enemy_id] = true

func _apply_line_slice_damage(start: Vector2, end: Vector2, hit_radius: float, damage: int) -> void:
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
		if enemy.has_node("HealthComponent"):
			enemy.get_node("HealthComponent").take_damage(max(1, damage))
		if enemy.has_method("apply_status"):
			enemy.call("apply_status", "marked", 1.0, 0.12, 1, 0.2)

func _apply_shuttle_hit(center: Vector2, radius: float, damage: int, move_dir: Vector2, push_amount: float) -> void:
	var safe_dir: Vector2 = move_dir.normalized()
	if safe_dir.length_squared() <= 0.001:
		safe_dir = Vector2.RIGHT
	var enemies: Array = get_tree().get_nodes_in_group("enemies")
	for enemy_obj: Variant in enemies:
		if enemy_obj == null or not is_instance_valid(enemy_obj):
			continue
		if not (enemy_obj is Node2D):
			continue
		var enemy: Node2D = enemy_obj
		if enemy.global_position.distance_to(center) > radius:
			continue
		if enemy.has_node("HealthComponent"):
			enemy.get_node("HealthComponent").take_damage(max(1, damage))
		if enemy.has_method("apply_status"):
			enemy.call("apply_status", "slow", 0.8, 0.42, 1, 0.1)
		enemy.global_position += safe_dir * push_amount

func _apply_pull_to_point(center: Vector2, radius: float, pull_amount: float) -> void:
	var enemies: Array = get_tree().get_nodes_in_group("enemies")
	for enemy_obj: Variant in enemies:
		if enemy_obj == null or not is_instance_valid(enemy_obj):
			continue
		if not (enemy_obj is Node2D):
			continue
		var enemy: Node2D = enemy_obj
		var offset: Vector2 = center - enemy.global_position
		var dist: float = offset.length()
		if dist > radius or dist <= 0.001:
			continue
		enemy.global_position += offset / dist * pull_amount

func _apply_recall_damage(enemy: Node2D) -> void:
	var damage: float = float(recall_damage)
	if _is_enemy_trapped(enemy):
		damage *= max(1.0, recall_execute_mult)
		Global.spawn_floating_text(enemy.global_position, "EXECUTE!", Color(1.25, 0.28, 0.28))
	else:
		Global.spawn_floating_text(enemy.global_position, "CUT!", Color(1.0, 1.0, 1.0))

	damage *= _recall_bonus_mult
	if enemy.has_node("HealthComponent"):
		enemy.get_node("HealthComponent").take_damage(max(1, int(round(damage))))

	if _forced_pull_strength > 0.0 and is_instance_valid(skill_owner):
		var dir: Vector2 = (skill_owner.global_position - enemy.global_position).normalized()
		enemy.global_position += dir * (_forced_pull_strength * 0.05)

func _cleanup_webs() -> void:
	if is_instance_valid(web_container):
		for child: Node in web_container.get_children():
			child.queue_free()

	path_points.clear()
	path_segments.clear()
	active_web_lines.clear()
	active_trap_polygons.clear()
	recall_progress.clear()
	recall_line_start.clear()
	recall_line_end.clear()
	hit_history.clear()
	current_web_timer = 0.0
	_recall_bonus_mult = 1.0
	_forced_pull_strength = 0.0

	for enemy_ref: WeakRef in trapped_enemies:
		var enemy_obj: Variant = enemy_ref.get_ref()
		if enemy_obj == null or not is_instance_valid(enemy_obj):
			continue
		if not (enemy_obj is Node2D):
			continue
		var enemy: Node2D = enemy_obj
		enemy.modulate = Color.WHITE
		if "can_move" in enemy:
			enemy.set("can_move", true)
	trapped_enemies.clear()

	if is_planning:
		Engine.time_scale = 1.0
	is_planning = false
	is_drawing = false
	is_dashing = false
	is_charging = false
	has_closure = false
	skill_state = SkillState.IDLE

func can_move() -> bool:
	return not is_planning

func cleanup() -> void:
	_cleanup_webs()
	if is_instance_valid(line_2d):
		line_2d.queue_free()
	line_2d = null
	if is_instance_valid(web_container):
		web_container.queue_free()
	web_container = null
