extends SkillQBase
class_name ColossusQBase

const Utils = preload("res://scripts/qef/core/colossus_skill_utils.gd")

var colossus_role_id: String = ""
var _release_dir: Vector2 = Vector2.RIGHT
var _open_state: Dictionary = {}
var _closed_state: Dictionary = {}
var _open_host: Node2D = null
var _closed_host: Node2D = null
var _projection_preview_host: Node2D = null


func _enter_planning_mode() -> void:
	_clear_projection_preview()
	_clear_active_hosts()
	super._enter_planning_mode()


func _before_execute_path(is_closed_path: bool) -> void:
	_clear_projection_preview()
	_release_dir = _resolve_projection_direction(is_closed_path)
	if is_closed_path:
		_clear_closed_state()
	else:
		_clear_open_state()


func _resolve_projection_direction(is_closed_path: bool) -> Vector2:
	var fallback_dir: Vector2 = _resolve_projection_fallback_dir()
	if not _uses_projected_launch(is_closed_path):
		return fallback_dir
	return _resolve_closed_projection_dir(fallback_dir) if is_closed_path else _resolve_open_projection_dir(fallback_dir)


func _uses_projected_launch(is_closed_path: bool) -> bool:
	return _uses_projected_closed_launch() if is_closed_path else _uses_projected_open_launch()


func _resolve_projection_fallback_dir() -> Vector2:
	if is_instance_valid(skill_owner):
		var mouse_dir: Vector2 = skill_owner.get_global_mouse_position() - skill_owner.global_position
		if mouse_dir.length_squared() > 0.0001:
			return mouse_dir.normalized()
	return Vector2.RIGHT


func _resolve_open_projection_anchor(points: Array[Vector2]) -> Vector2:
	if points.size() >= 2 and is_instance_valid(skill_owner):
		var projected: Dictionary = Utils.project_point_to_polyline(skill_owner.global_position, points)
		return projected.get("point", _calculate_points_center(points))
	if points.size() == 1:
		return points[0]
	return skill_owner.global_position if is_instance_valid(skill_owner) else Vector2.ZERO


func _resolve_open_projection_dir(fallback_dir: Vector2) -> Vector2:
	var source_points: Array[Vector2] = _read_points(path_points)
	if source_points.size() < 2 or not is_instance_valid(skill_owner):
		return fallback_dir
	var projected: Dictionary = Utils.project_point_to_polyline(skill_owner.global_position, source_points)
	var anchor: Vector2 = projected.get("point", source_points[0])
	var radial_dir: Vector2 = anchor - skill_owner.global_position
	if radial_dir.length_squared() > 0.0001:
		return radial_dir.normalized()
	var idx: int = clamp(int(projected.get("index", 0)), 0, source_points.size() - 2)
	var seg_dir: Vector2 = (source_points[idx + 1] - source_points[idx]).normalized()
	if seg_dir.length_squared() > 0.0001:
		var normal: Vector2 = Vector2(-seg_dir.y, seg_dir.x)
		if normal.dot(fallback_dir) < 0.0:
			normal = -normal
		if normal.length_squared() > 0.0001:
			return normal.normalized()
	return fallback_dir


func _resolve_closed_projection_anchor(polygons: Array[PackedVector2Array]) -> Vector2:
	var primary: PackedVector2Array = _select_largest_polygon(polygons)
	if primary.size() >= 3 and is_instance_valid(skill_owner):
		var edge_info: Dictionary = Utils.distance_to_polygon_edge(skill_owner.global_position, primary)
		return edge_info.get("point", _calculate_polygon_center(primary))
	if primary.size() >= 3:
		return _calculate_polygon_center(primary)
	return skill_owner.global_position if is_instance_valid(skill_owner) else Vector2.ZERO


func _resolve_closed_projection_dir(fallback_dir: Vector2) -> Vector2:
	var source_polygon: PackedVector2Array = _find_primary_source_polygon()
	if source_polygon.size() < 3 or not is_instance_valid(skill_owner):
		return fallback_dir
	var edge_info: Dictionary = Utils.distance_to_polygon_edge(skill_owner.global_position, source_polygon)
	var anchor: Vector2 = edge_info.get("point", _calculate_polygon_center(source_polygon))
	var radial_dir: Vector2 = anchor - skill_owner.global_position
	if radial_dir.length_squared() > 0.0001:
		return radial_dir.normalized()
	var outward_dir: Vector2 = anchor - _calculate_polygon_center(source_polygon)
	if outward_dir.length_squared() > 0.0001:
		return outward_dir.normalized()
	return fallback_dir


func _transform_open_segment_for_execution(start: Vector2, end_pos: Vector2) -> Dictionary:
	var offset: Vector2 = _release_dir * _get_open_projection_distance()
	return {
		"start": start + offset,
		"end": end_pos + offset,
	}


func _transform_polygon_for_execution(polygon: PackedVector2Array) -> PackedVector2Array:
	var offset: Vector2 = _release_dir * _get_close_projection_distance()
	return Utils.translate_polygon(polygon, offset)


func _spawn_line_effect(start: Vector2, end_pos: Vector2) -> void:
	_spawn_line_visual_segment(start, end_pos, _get_role_line_width(), _get_open_color(), _get_role_open_duration())
	if _role_uses_wall_visual():
		SkillEffectManager.create_wall_effect({
			"start": start,
			"end": end_pos,
			"width": _get_role_line_width(),
			"duration": _get_role_open_duration(),
			"block_enemies": true,
			"block_bullets": false,
			"contact_damage": 0,
			"color": _get_open_color().darkened(0.1),
		})


func _spawn_area_effect(polygon: PackedVector2Array) -> void:
	if polygon.size() < 3:
		return
	SkillEffectManager.create_area_effect({
		"polygon": polygon,
		"damage": 0,
		"damage_interval": 0.2,
		"duration": _get_role_close_duration(),
		"color": _get_closed_color().darkened(0.05),
	})


func _execute_open_path() -> void:
	if not _uses_projected_open_launch():
		super._execute_open_path()
		return
	if path_points.size() < 2:
		print("[%s] path too short, skip open-path execution" % skill_id)
		return

	SoundManager.play("skill_q_open_execute")

	const MERGE_DISTANCE: float = 100.0

	var merged_segments: Array[Dictionary] = []
	var seg_start: Vector2 = path_points[0]
	var accumulated: float = 0.0

	for i in range(1, path_points.size()):
		var dist: float = path_points[i - 1].distance_to(path_points[i])
		accumulated += dist
		if accumulated >= MERGE_DISTANCE or i == path_points.size() - 1:
			merged_segments.append({"start": seg_start, "end": path_points[i]})
			seg_start = path_points[i]
			accumulated = 0.0

	print("[%s] 投射开放线分段: 点数=%d, 段数=%d" % [skill_id, path_points.size(), merged_segments.size()])

	var transformed_points: Array[Vector2] = []
	for point: Vector2 in path_points:
		var transformed_point: Dictionary = _transform_open_segment_for_execution(point, point)
		transformed_points.append(transformed_point.get("start", point))

	var context_center: Vector2 = _calculate_points_center(transformed_points)
	var context_radius: float = _calculate_points_radius(transformed_points, context_center)
	var line_duration: float = _get_line_duration()
	var preview_points: Array[Vector2] = _read_points(path_points)
	var travel_sec: float = _get_open_projection_travel_sec()

	_publish_projected_open_preview_context(merged_segments.size(), context_center, context_radius)
	_spawn_projected_open_preview(preview_points, transformed_points, travel_sec)
	_queue_projected_open_finalize(
		merged_segments.duplicate(true),
		preview_points.duplicate(),
		line_duration,
		context_center,
		context_radius,
		travel_sec
	)


func _execute_closed_path() -> void:
	if not _uses_projected_closed_launch():
		super._execute_closed_path()
		return

	if skill_owner and "player_id" in skill_owner:
		SoundManager.play_character_q_closure(skill_owner.player_id)
	else:
		SoundManager.play("skill_q_closure_generic")

	var tolerance: float = _get_closure_tolerance()
	var source_polygons: Array[PackedVector2Array] = []
	for poly_obj: Variant in PolygonUtils.find_all_closing_polygons(path_points, tolerance):
		if not (poly_obj is PackedVector2Array):
			continue
		source_polygons.append(poly_obj)
	if source_polygons.is_empty():
		super._execute_closed_path()
		return

	var transformed_polygons: Array[PackedVector2Array] = []
	for polygon: PackedVector2Array in source_polygons:
		transformed_polygons.append(_transform_polygon_for_execution(polygon))

	var primary_polygon: PackedVector2Array = _select_largest_polygon(transformed_polygons)
	var context_center: Vector2 = _calculate_polygon_center(primary_polygon)
	var context_radius: float = _calculate_polygon_radius(primary_polygon, context_center)
	var travel_sec: float = _get_close_projection_travel_sec()

	_spawn_projected_closed_preview(source_polygons, transformed_polygons, travel_sec)
	_queue_projected_closed_finalize(
		transformed_polygons.duplicate(true),
		context_center,
		context_radius,
		travel_sec
	)


func _queue_projected_open_finalize(
	merged_segments: Array,
	source_points: Array,
	line_duration: float,
	context_center: Vector2,
	context_radius: float,
	travel_sec: float
) -> void:
	var tree: SceneTree = get_tree()
	if tree == null or travel_sec <= 0.01:
		_finalize_projected_open_path(merged_segments, source_points, line_duration, context_center, context_radius)
		return
	var self_ref: WeakRef = weakref(self)
	tree.create_timer(travel_sec).timeout.connect(func() -> void:
		var self_var: Variant = self_ref.get_ref()
		if self_var == null or not is_instance_valid(self_var):
			return
		(self_var as ColossusQBase)._finalize_projected_open_path(
			merged_segments,
			source_points,
			line_duration,
			context_center,
			context_radius
		)
	)


func _finalize_projected_open_path(
	merged_segments: Array,
	source_points: Array,
	line_duration: float,
	context_center: Vector2,
	context_radius: float
) -> void:
	var cached_path_points: Array[Vector2] = _read_points(path_points)
	path_points = _read_points(source_points)

	for seg_var: Variant in merged_segments:
		if not (seg_var is Dictionary):
			continue
		var seg: Dictionary = seg_var
		var transformed_seg: Dictionary = _transform_open_segment_for_execution(
			seg.get("start", Vector2.ZERO),
			seg.get("end", Vector2.ZERO)
		)
		var seg_start_exec: Vector2 = transformed_seg.get("start", seg.get("start", Vector2.ZERO))
		var seg_end_exec: Vector2 = transformed_seg.get("end", seg.get("end", Vector2.ZERO))
		_spawn_thorns_wall_trigger(seg_start_exec, seg_end_exec, line_duration)

	print("[%s] projected open-path effects spawned" % skill_id)
	_cache_q_execution_context(false, merged_segments.size(), 0, context_center, context_radius)
	path_points = cached_path_points
	_notify_ultimate_path_executed(false, merged_segments.size(), 0)


func _spawn_projected_open_preview(
	source_points: Array[Vector2],
	target_points: Array[Vector2],
	travel_sec: float
) -> void:
	_clear_projection_preview()
	if source_points.size() < 2 or target_points.size() < 2:
		return
	var tree: SceneTree = get_tree()
	if tree == null or tree.current_scene == null:
		return

	var source_anchor: Vector2 = _resolve_open_projection_anchor(source_points)
	var target_anchor: Vector2 = source_anchor + _release_dir * _get_open_projection_distance()
	var host: Node2D = Node2D.new()
	host.name = "%sProjectedOpenPreview" % colossus_role_id.capitalize()
	host.z_index = 95
	host.global_position = source_anchor
	host.scale = Vector2(0.84, 0.84)
	host.add_to_group("player_skill_effects")

	var line: Line2D = Line2D.new()
	line.z_index = 95
	var target_width: float = max(16.0, min(_get_role_line_width() * 0.32, 30.0))
	line.width = target_width * 0.72
	line.default_color = _get_open_color().lightened(0.18)
	line.begin_cap_mode = Line2D.LINE_CAP_ROUND
	line.end_cap_mode = Line2D.LINE_CAP_ROUND
	line.joint_mode = Line2D.LINE_JOINT_ROUND
	line.antialiased = true
	line.modulate = Color(1.0, 1.0, 1.0, 0.78)
	for point: Vector2 in source_points:
		line.add_point(point - source_anchor)
	host.add_child(line)

	tree.current_scene.add_child(host)
	_projection_preview_host = host

	var safe_travel_sec: float = max(0.08, travel_sec)
	var tween: Tween = host.create_tween()
	tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(host, "global_position", target_anchor, safe_travel_sec)
	tween.parallel().tween_property(host, "scale", Vector2.ONE, safe_travel_sec)
	tween.parallel().tween_property(line, "width", target_width, safe_travel_sec)
	tween.parallel().tween_property(line, "modulate:a", 0.98, safe_travel_sec)
	tween.tween_callback(func() -> void:
		if _projection_preview_host == host:
			_projection_preview_host = null
		if is_instance_valid(host):
			host.queue_free()
	)


func _queue_projected_closed_finalize(
	polygons: Array,
	context_center: Vector2,
	context_radius: float,
	travel_sec: float
) -> void:
	var tree: SceneTree = get_tree()
	if tree == null or travel_sec <= 0.01:
		_finalize_projected_closed_path(polygons, context_center, context_radius)
		return
	var self_ref: WeakRef = weakref(self)
	tree.create_timer(travel_sec).timeout.connect(func() -> void:
		var self_var: Variant = self_ref.get_ref()
		if self_var == null or not is_instance_valid(self_var):
			return
		(self_var as ColossusQBase)._finalize_projected_closed_path(
			polygons,
			context_center,
			context_radius
		)
	)


func _finalize_projected_closed_path(
	polygons: Array,
	context_center: Vector2,
	context_radius: float
) -> void:
	if not polygons.is_empty():
		var mask_color: Color = _get_closure_color()
		mask_color.a = 0.7
		PolygonUtils.show_closure_masks(polygons, mask_color, get_tree(), 0.6)

	for polygon_var: Variant in polygons:
		if not (polygon_var is PackedVector2Array):
			continue
		var polygon: PackedVector2Array = polygon_var
		_push_runtime_effect_damage_multiplier(true)
		_spawn_area_effect(polygon)
		_pop_runtime_effect_damage_multiplier()
		_apply_polygon_effect(polygon)

		var main_damage: int = _estimate_closed_shape_damage(polygon)
		_trigger_secondary_explode(polygon, main_damage)
		_trigger_chain_reaction(polygon, main_damage)

	print("[%s] projected closed-path effects spawned" % skill_id)
	_cache_q_execution_context(true, path_points.size(), polygons.size(), context_center, context_radius)
	_notify_ultimate_path_executed(true, path_points.size(), polygons.size())


func _spawn_projected_closed_preview(
	source_polygons: Array[PackedVector2Array],
	target_polygons: Array[PackedVector2Array],
	travel_sec: float
) -> void:
	_clear_projection_preview()
	if source_polygons.is_empty() or target_polygons.is_empty():
		return
	var tree: SceneTree = get_tree()
	if tree == null or tree.current_scene == null:
		return

	var source_primary: PackedVector2Array = _select_largest_polygon(source_polygons)
	var target_primary: PackedVector2Array = _select_largest_polygon(target_polygons)
	if source_primary.size() < 3 or target_primary.size() < 3:
		return

	var source_anchor: Vector2 = _resolve_closed_projection_anchor(source_polygons)
	var target_anchor: Vector2 = source_anchor + _release_dir * _get_close_projection_distance()
	var host: Node2D = Node2D.new()
	host.name = "%sProjectedClosedPreview" % colossus_role_id.capitalize()
	host.z_index = 95
	host.global_position = source_anchor
	host.scale = Vector2(0.82, 0.82)
	host.add_to_group("player_skill_effects")

	var outline_width: float = max(10.0, min(_get_role_line_width() * 0.26, 24.0))
	for polygon: PackedVector2Array in source_polygons:
		var fill: Polygon2D = Polygon2D.new()
		fill.polygon = _polygon_to_local_points(polygon, source_anchor)
		var fill_color: Color = _get_closed_color().lightened(0.04)
		fill_color.a = 0.16
		fill.color = fill_color
		host.add_child(fill)

		var outline: Line2D = Line2D.new()
		outline.closed = true
		outline.width = outline_width * 0.72
		outline.default_color = _get_closed_color().lightened(0.12)
		outline.begin_cap_mode = Line2D.LINE_CAP_ROUND
		outline.end_cap_mode = Line2D.LINE_CAP_ROUND
		outline.joint_mode = Line2D.LINE_JOINT_ROUND
		outline.antialiased = true
		outline.modulate = Color(1.0, 1.0, 1.0, 0.78)
		for point: Vector2 in polygon:
			outline.add_point(point - source_anchor)
		host.add_child(outline)

	tree.current_scene.add_child(host)
	_projection_preview_host = host

	var safe_travel_sec: float = max(0.08, travel_sec)
	var tween: Tween = host.create_tween()
	tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(host, "global_position", target_anchor, safe_travel_sec)
	tween.parallel().tween_property(host, "scale", Vector2.ONE, safe_travel_sec)
	for child_var: Variant in host.get_children():
		if child_var is Line2D:
			var outline_node: Line2D = child_var
			tween.parallel().tween_property(outline_node, "width", outline_width, safe_travel_sec)
			tween.parallel().tween_property(outline_node, "modulate:a", 0.96, safe_travel_sec)
	tween.tween_callback(func() -> void:
		if _projection_preview_host == host:
			_projection_preview_host = null
		if is_instance_valid(host):
			host.queue_free()
	)


func _publish_projected_open_preview_context(
	segment_count: int,
	center: Vector2,
	radius: float
) -> void:
	if not is_instance_valid(skill_owner):
		return
	var safe_radius: float = float(max(60.0, radius))
	var now_msec: int = Time.get_ticks_msec()
	skill_owner.set_meta(Q_CTX_META_CENTER, center)
	skill_owner.set_meta(Q_CTX_META_RADIUS, safe_radius)
	skill_owner.set_meta(Q_CTX_META_TIME_MSEC, now_msec)
	skill_owner.set_meta(Q_CTX_META_CLOSED, false)
	skill_owner.set_meta(Q_CTX_META_SEGMENTS, max(0, segment_count))
	skill_owner.set_meta(Q_CTX_META_POLYGONS, 0)
	skill_owner.set_meta(Q_CTX_LEGACY_CENTER, center)
	skill_owner.set_meta(Q_CTX_LEGACY_RADIUS, safe_radius)
	skill_owner.set_meta(Q_CTX_LEGACY_TIME_MSEC, now_msec)

	var metrics: Dictionary = {
		"segment_count": max(0, segment_count),
		"polygon_count": 0,
	}
	var packet := SkillContextBridge.build_packet(
		skill_owner,
		"q",
		skill_id,
		"q_open",
		center,
		safe_radius,
		_build_q_context_payload(false, segment_count, 0, center, safe_radius),
		metrics,
		_build_q_tags(false)
	)
	packet.is_closed = false
	packet.segment_count = max(0, segment_count)
	packet.polygon_count = 0
	SkillContextBridge.publish_q_context(skill_owner, packet)


func _get_q_asset_kind(is_closed_path: bool) -> String:
	return "%s_%s" % [colossus_role_id, "closure" if is_closed_path else "line"]


func _get_q_asset_duration(is_closed_path: bool) -> float:
	return _get_role_close_duration() if is_closed_path else _get_role_open_duration()


func _build_q_asset_payload(
	is_closed_path: bool,
	segment_count: int,
	polygon_count: int,
	center: Vector2,
	radius: float
) -> Dictionary:
	var payload: Dictionary = {
		"role_id": colossus_role_id,
		"is_closed": is_closed_path,
		"segment_count": segment_count,
		"polygon_count": polygon_count,
		"center": center,
		"radius": radius,
		"duration_sec": _get_q_asset_duration(is_closed_path),
		"aim_dir": _release_dir,
	}
	if is_closed_path:
		var polygon: PackedVector2Array = _find_primary_transformed_polygon()
		var poly_center: Vector2 = _calculate_polygon_center(polygon)
		var poly_radius: float = _calculate_polygon_radius(polygon, poly_center)
		payload["polygon"] = polygon
		payload["center"] = poly_center
		payload["radius"] = poly_radius
		_fill_closed_payload(payload, polygon, poly_center, poly_radius)
	else:
		var points: Array[Vector2] = []
		for point: Vector2 in path_points:
			points.append(point + _release_dir * _get_open_projection_distance())
		payload["points"] = points
		payload["start_point"] = points.front() if not points.is_empty() else center
		payload["end_point"] = points.back() if not points.is_empty() else center
		_fill_open_payload(payload, points)
	return payload


func _on_q_context_published(_packet: Dictionary, asset_entry: Dictionary) -> void:
	var payload_var: Variant = asset_entry.get("payload", {})
	var payload: Dictionary = payload_var if payload_var is Dictionary else {}
	if payload.is_empty():
		return
	var is_closed: bool = bool(payload.get("is_closed", false))
	payload["expire_msec"] = int(asset_entry.get("expire_msec", 0))
	if is_closed:
		_activate_closed_state(payload)
	else:
		_activate_open_state(payload)


func get_open_state() -> Dictionary:
	if _open_state.is_empty():
		return {}
	if int(_open_state.get("expire_msec", 0)) > 0 and Time.get_ticks_msec() > int(_open_state.get("expire_msec", 0)):
		_clear_open_state()
		return {}
	return _open_state.duplicate(true)


func get_closed_state() -> Dictionary:
	if _closed_state.is_empty():
		return {}
	if int(_closed_state.get("expire_msec", 0)) > 0 and Time.get_ticks_msec() > int(_closed_state.get("expire_msec", 0)):
		_clear_closed_state()
		return {}
	return _closed_state.duplicate(true)


func mutate_open_state(updates: Dictionary) -> void:
	for key_var: Variant in updates.keys():
		_open_state[key_var] = updates[key_var]


func mutate_closed_state(updates: Dictionary) -> void:
	for key_var: Variant in updates.keys():
		_closed_state[key_var] = updates[key_var]


func _activate_open_state(payload: Dictionary) -> void:
	_clear_open_state()
	_open_state = payload.duplicate(true)
	_spawn_open_signature(_open_state)
	_open_host = _spawn_ticking_host(
		"%sOpenHost" % colossus_role_id.capitalize(),
		_get_role_open_duration(),
		_get_open_tick_interval(),
		false
	)


func _activate_closed_state(payload: Dictionary) -> void:
	_clear_closed_state()
	_closed_state = payload.duplicate(true)
	_spawn_closed_signature(_closed_state)
	_closed_host = _spawn_ticking_host(
		"%sClosedHost" % colossus_role_id.capitalize(),
		_get_role_close_duration(),
		_get_closed_tick_interval(),
		true
	)


func _spawn_ticking_host(name: String, duration: float, interval: float, is_closed: bool) -> Node2D:
	var host: Node2D = Node2D.new()
	host.name = name
	add_child(host)
	var elapsed: float = 0.0
	var timer: Timer = Timer.new()
	timer.wait_time = max(0.05, interval)
	timer.one_shot = false
	host.add_child(timer)
	timer.timeout.connect(func() -> void:
		if not is_instance_valid(host):
			return
		elapsed += timer.wait_time
		if elapsed > duration:
			timer.stop()
			host.queue_free()
			return
		if is_closed:
			_tick_closed_state(elapsed)
		else:
			_tick_open_state(elapsed)
	)
	timer.start()
	return host


func _spawn_open_signature(state: Dictionary) -> void:
	var points: Array[Vector2] = _read_points(state.get("points", []))
	if points.size() >= 2:
		_spawn_polyline_visual(points, _get_role_line_width(), _get_open_color(), _get_role_open_duration(), _role_uses_wall_visual())
	match colossus_role_id:
		"butcher":
			spawn_skill_vfx(state.get("end_point", skill_owner.global_position), Color(1.0, 0.2, 0.18, 0.9), 0.72)
		"glacier":
			for point: Vector2 in state.get("crack_points", []):
				spawn_skill_vfx(point, Color(0.7, 0.95, 1.2, 0.72), 0.42)
		"jailer":
			for gate_point: Vector2 in state.get("gate_points", []):
				spawn_skill_vfx(gate_point, Color(1.0, 0.88, 0.42, 0.66), 0.34)
		"blacksmith":
			for slot_point: Vector2 in state.get("slot_points", []):
				spawn_skill_vfx(slot_point, Color(1.0, 0.6, 0.25, 0.64), 0.34)
		"paladin":
			for frontier_point: Vector2 in state.get("frontier_points", []):
				spawn_skill_vfx(frontier_point, Color(1.0, 0.92, 0.48, 0.68), 0.34)
		"breachmarshal":
			spawn_skill_vfx(state.get("end_point", skill_owner.global_position), Color(0.92, 0.88, 0.78, 0.82), 0.65)
		"hexwarden":
			for nail_point: Vector2 in state.get("nail_points", []):
				spawn_skill_vfx(nail_point, Color(0.92, 0.44, 1.0, 0.72), 0.32)
		"executioner":
			spawn_skill_vfx(state.get("start_point", skill_owner.global_position), Color(1.0, 0.28, 0.28, 0.7), 0.38)
			spawn_skill_vfx(state.get("end_point", skill_owner.global_position), Color(1.0, 0.28, 0.28, 0.84), 0.48)


func _spawn_closed_signature(state: Dictionary) -> void:
	var polygon: PackedVector2Array = _read_polygon(state.get("polygon", PackedVector2Array()))
	if polygon.size() >= 3:
		SkillEffectManager.create_debuff_zone({
			"polygon": polygon,
			"duration": _get_role_close_duration(),
			"debuff_type": "slow",
			"debuff_value": 0.12,
			"debuff_duration": 0.3,
			"tick_interval": 0.35,
			"color": _get_closed_color().darkened(0.06),
		})
	match colossus_role_id:
		"butcher":
			spawn_skill_vfx(state.get("mouth_center", state.get("center", skill_owner.global_position)), Color(1.0, 0.22, 0.18, 0.88), 0.76)
		"glacier":
			spawn_skill_vfx(state.get("return_corner", state.get("center", skill_owner.global_position)), Color(0.78, 1.0, 1.18, 0.76), 0.62)
		"jailer":
			spawn_skill_vfx(state.get("amnesty_point", state.get("center", skill_owner.global_position)), Color(0.78, 1.0, 1.0, 0.62), 0.46)
			spawn_skill_vfx(state.get("dead_door_point", state.get("center", skill_owner.global_position)), Color(1.0, 0.52, 0.3, 0.78), 0.56)
		"blacksmith":
			spawn_skill_vfx(state.get("center", skill_owner.global_position), Color(1.0, 0.56, 0.22, 0.84), 0.7)
		"paladin":
			spawn_skill_vfx(state.get("entry_point", state.get("center", skill_owner.global_position)), Color(1.0, 0.92, 0.56, 0.68), 0.46)
			spawn_skill_vfx(state.get("verdict_point", state.get("center", skill_owner.global_position)), Color(1.0, 0.82, 0.32, 0.86), 0.64)
		"breachmarshal":
			spawn_skill_vfx(state.get("mouth_point", state.get("center", skill_owner.global_position)), Color(0.96, 0.9, 0.8, 0.84), 0.68)
		"hexwarden":
			spawn_skill_vfx(state.get("center", skill_owner.global_position), Color(0.92, 0.42, 1.0, 0.78), 0.66)
		"executioner":
			spawn_skill_vfx(state.get("center", skill_owner.global_position), Color(1.0, 0.24, 0.24, 0.84), 0.72)
			_spawn_line_visual_segment(
				state.get("guillotine_start", state.get("center", skill_owner.global_position)),
				state.get("guillotine_end", state.get("center", skill_owner.global_position)),
				16.0,
				Color(1.0, 0.28, 0.28, 0.92),
				_get_role_close_duration()
			)


func _tick_open_state(elapsed: float) -> void:
	match colossus_role_id:
		"butcher":
			_tick_butcher_open(_open_state)
		"glacier":
			_tick_glacier_open(_open_state)
		"jailer":
			_tick_jailer_open(_open_state)
		"blacksmith":
			_tick_blacksmith_open(_open_state)
		"paladin":
			_tick_paladin_open(_open_state)
		"breachmarshal":
			_tick_breachmarshal_open(_open_state)
		"hexwarden":
			_tick_hexwarden_open(_open_state)
		"executioner":
			_tick_executioner_open(_open_state, elapsed)


func _tick_closed_state(elapsed: float) -> void:
	match colossus_role_id:
		"butcher":
			_tick_butcher_closed(_closed_state, elapsed)
		"glacier":
			_tick_glacier_closed(_closed_state)
		"jailer":
			_tick_jailer_closed(_closed_state)
		"blacksmith":
			_tick_blacksmith_closed(_closed_state)
		"paladin":
			_tick_paladin_closed(_closed_state)
		"breachmarshal":
			_tick_breachmarshal_closed(_closed_state, elapsed)
		"hexwarden":
			_tick_hexwarden_closed(_closed_state, elapsed)
		"executioner":
			_tick_executioner_closed(_closed_state, elapsed)


func _tick_butcher_open(state: Dictionary) -> void:
	var points: Array[Vector2] = _read_points(state.get("points", []))
	if points.size() < 2:
		return
	var anchor: Vector2 = state.get("end_point", points.back())
	for enemy: Node2D in Utils.get_enemies(get_tree()):
		var projected: Dictionary = Utils.project_point_to_polyline(enemy.global_position, points)
		if float(projected.get("distance", INF)) > 44.0:
			continue
		Utils.apply_damage(enemy, 14)
		Utils.apply_status(enemy, "slow", 0.4, 0.30, 1, 0.1)
		var advance: Dictionary = Utils.advance_along_polyline(points, int(projected.get("index", 0)), float(projected.get("t", 0.0)), 90.0, true)
		var target_pos: Vector2 = advance.get("point", anchor)
		target_pos = target_pos.lerp(anchor, 0.35)
		Utils.move_enemy_towards(enemy, target_pos, 60.0)


func _tick_glacier_open(state: Dictionary) -> void:
	var points: Array[Vector2] = _read_points(state.get("points", []))
	if points.size() < 2:
		return
	var safe_side: float = float(state.get("safe_side", 1.0))
	for enemy: Node2D in Utils.get_enemies(get_tree()):
		var projected: Dictionary = Utils.project_point_to_polyline(enemy.global_position, points)
		if float(projected.get("distance", INF)) > 48.0:
			continue
		var idx: int = int(projected.get("index", 0))
		var seg_dir: Vector2 = (points[min(idx + 1, points.size() - 1)] - points[idx]).normalized()
		var seg_normal: Vector2 = Vector2(-seg_dir.y, seg_dir.x)
		var side: float = sign(seg_normal.dot(enemy.global_position - projected.get("point", enemy.global_position)))
		if side == safe_side:
			continue
		Utils.apply_status(enemy, "slow", 0.8, 0.38, 1, 0.1)
		if Utils.enemy_has_status(enemy, "marked"):
			Utils.apply_status(enemy, "freeze", 0.55, 0.0, 1, 0.1)
		else:
			Utils.apply_status(enemy, "marked", 0.6, 0.18, 1, 0.3)
		Utils.apply_knockback_or_move(enemy, -seg_normal * safe_side, 420.0, 0.08)


func _tick_jailer_open(state: Dictionary) -> void:
	var gate_points: Array[Vector2] = _read_points(state.get("gate_points", []))
	var gate_dir: Vector2 = state.get("gate_dir", _release_dir)
	if gate_points.is_empty():
		return
	for enemy: Node2D in Utils.get_enemies(get_tree()):
		for gate_point: Vector2 in gate_points:
			if enemy.global_position.distance_to(gate_point) > 58.0:
				continue
			var side: float = sign(Vector2(-gate_dir.y, gate_dir.x).dot(enemy.global_position - gate_point))
			if side < 0.0:
				Utils.apply_knockback_or_move(enemy, -gate_dir, 540.0, 0.08)
				Utils.apply_status(enemy, "marked", 1.0, 0.18, 1, 0.3)
				Utils.apply_status(enemy, "slow", 0.45, 0.42, 1, 0.1)
			else:
				Utils.apply_status(enemy, "slow", 0.3, 0.12, 1, 0.1)
			break


func _tick_blacksmith_open(state: Dictionary) -> void:
	var points: Array[Vector2] = _read_points(state.get("points", []))
	var slot_points: Array[Vector2] = _read_points(state.get("slot_points", []))
	if points.size() < 2:
		return
	for enemy: Node2D in Utils.get_enemies(get_tree()):
		var projected: Dictionary = Utils.project_point_to_polyline(enemy.global_position, points)
		if float(projected.get("distance", INF)) > 44.0:
			continue
		Utils.apply_damage(enemy, 12)
		Utils.apply_status(enemy, "burn", 0.7, 6.0, 1, 0.3)
		var nearest_slot: Vector2 = _find_nearest_point(enemy.global_position, slot_points)
		if nearest_slot != Vector2.ZERO:
			Utils.move_enemy_towards(enemy, nearest_slot, 18.0)


func _tick_paladin_open(state: Dictionary) -> void:
	var points: Array[Vector2] = _read_points(state.get("points", []))
	if points.size() < 2:
		return
	var safe_side: float = float(state.get("safe_side", 1.0))
	for enemy: Node2D in Utils.get_enemies(get_tree()):
		var projected: Dictionary = Utils.project_point_to_polyline(enemy.global_position, points)
		if float(projected.get("distance", INF)) > 48.0:
			continue
		var idx: int = int(projected.get("index", 0))
		var seg_dir: Vector2 = (points[min(idx + 1, points.size() - 1)] - points[idx]).normalized()
		var normal: Vector2 = Vector2(-seg_dir.y, seg_dir.x)
		Utils.apply_status(enemy, "marked", 0.8, 0.14, 1, 0.3)
		Utils.apply_knockback_or_move(enemy, normal * -safe_side, 460.0, 0.08)


func _tick_breachmarshal_open(state: Dictionary) -> void:
	var points: Array[Vector2] = _read_points(state.get("points", []))
	if points.size() < 2:
		return
	for enemy: Node2D in Utils.get_enemies(get_tree()):
		var projected: Dictionary = Utils.project_point_to_polyline(enemy.global_position, points)
		if float(projected.get("distance", INF)) > 48.0:
			continue
		Utils.apply_status(enemy, "marked", 0.9, 0.16, 1, 0.3)
		Utils.apply_status(enemy, "slow", 0.7, 0.28, 1, 0.1)
		var advance: Dictionary = Utils.advance_along_polyline(points, int(projected.get("index", 0)), float(projected.get("t", 0.0)), 70.0, true)
		Utils.move_enemy_towards(enemy, advance.get("point", points.back()), 54.0)


func _tick_hexwarden_open(state: Dictionary) -> void:
	var points: Array[Vector2] = _read_points(state.get("points", []))
	if points.size() < 2:
		return
	var cursed_side: float = float(state.get("cursed_side", -1.0))
	var nail_points: Array[Vector2] = _read_points(state.get("nail_points", []))
	for enemy: Node2D in Utils.get_enemies(get_tree()):
		var projected: Dictionary = Utils.project_point_to_polyline(enemy.global_position, points)
		if float(projected.get("distance", INF)) > 42.0:
			continue
		var idx: int = int(projected.get("index", 0))
		var seg_dir: Vector2 = (points[min(idx + 1, points.size() - 1)] - points[idx]).normalized()
		var normal: Vector2 = Vector2(-seg_dir.y, seg_dir.x)
		var side: float = sign(normal.dot(enemy.global_position - projected.get("point", enemy.global_position)))
		if side != cursed_side:
			continue
		Utils.apply_status(enemy, "curse", 1.4, 8.0, 1, 0.7)
		Utils.apply_status(enemy, "slow", 0.8, 0.26, 1, 0.1)
		var nail_point: Vector2 = _find_nearest_point(enemy.global_position, nail_points)
		if nail_point != Vector2.ZERO:
			Utils.move_enemy_towards(enemy, nail_point, 22.0)


func _tick_executioner_open(state: Dictionary, elapsed: float) -> void:
	var points: Array[Vector2] = _read_points(state.get("points", []))
	if points.size() < 2:
		return
	var threshold: float = min(0.40, 0.28 + floor(elapsed / 0.20) * 0.04)
	for enemy: Node2D in Utils.get_enemies(get_tree()):
		var projected: Dictionary = Utils.project_point_to_polyline(enemy.global_position, points)
		if float(projected.get("distance", INF)) > 41.0:
			continue
		Utils.apply_status(enemy, "marked", 0.9, 0.20, 1, 0.3)
		if Utils.is_enemy_below_threshold(enemy, threshold):
			Global.spawn_floating_text(enemy.global_position, "线下", Color(1.0, 0.22, 0.22))


func _tick_butcher_closed(state: Dictionary, elapsed: float) -> void:
	var polygon: PackedVector2Array = _read_polygon(state.get("polygon", PackedVector2Array()))
	var center: Vector2 = state.get("center", skill_owner.global_position)
	var mouth_center: Vector2 = state.get("mouth_center", center)
	if polygon.size() < 3:
		return
	for enemy: Node2D in Utils.get_enemies(get_tree()):
		var edge_info: Dictionary = Utils.distance_to_polygon_edge(enemy.global_position, polygon)
		var inside: bool = Geometry2D.is_point_in_polygon(enemy.global_position, polygon)
		if not inside and float(edge_info.get("distance", INF)) > 80.0:
			continue
		if elapsed < 0.16:
			Utils.move_enemy_towards(enemy, center, 28.0)
			continue
		Utils.move_enemy_towards(enemy, mouth_center, 42.0)
		if enemy.global_position.distance_to(mouth_center) <= 62.0:
			Utils.apply_damage(enemy, 20)
			Utils.apply_status(enemy, "marked", 0.6, 0.24, 1, 0.3)


func _tick_glacier_closed(state: Dictionary) -> void:
	var polygon: PackedVector2Array = _read_polygon(state.get("polygon", PackedVector2Array()))
	var return_corner: Vector2 = state.get("return_corner", state.get("center", skill_owner.global_position))
	if polygon.size() < 3:
		return
	for enemy: Node2D in Utils.get_enemies(get_tree()):
		if not Geometry2D.is_point_in_polygon(enemy.global_position, polygon):
			continue
		var edge_info: Dictionary = Utils.distance_to_polygon_edge(enemy.global_position, polygon)
		Utils.move_enemy_towards(enemy, edge_info.get("point", enemy.global_position), 30.0)
		if enemy.global_position.distance_to(return_corner) <= 72.0:
			Utils.apply_damage(enemy, 18)
			Utils.apply_status(enemy, "freeze", 0.5, 0.0, 1, 0.1)


func _tick_jailer_closed(state: Dictionary) -> void:
	var polygon: PackedVector2Array = _read_polygon(state.get("polygon", PackedVector2Array()))
	var center: Vector2 = state.get("center", skill_owner.global_position)
	var dead_door: Vector2 = state.get("dead_door_point", center)
	var amnesty: Vector2 = state.get("amnesty_point", center)
	if polygon.size() < 3:
		return
	for enemy: Node2D in Utils.get_enemies(get_tree()):
		if not Geometry2D.is_point_in_polygon(enemy.global_position, polygon):
			continue
		if enemy.global_position.distance_to(dead_door) <= 84.0:
			Utils.apply_knockback_or_move(enemy, (center - dead_door).normalized(), 620.0, 0.08)
			Utils.apply_status(enemy, "slow", 0.7, 0.32, 1, 0.1)
			Utils.apply_status(enemy, "marked", 1.0, 0.18, 1, 0.3)
		elif enemy.global_position.distance_to(amnesty) > 72.0:
			Utils.move_enemy_towards(enemy, dead_door, 28.0)


func _tick_blacksmith_closed(state: Dictionary) -> void:
	var center: Vector2 = state.get("center", skill_owner.global_position)
	var radius: float = float(state.get("radius", 120.0))
	var ring_poly: PackedVector2Array = _read_polygon(state.get("polygon", PackedVector2Array()))
	var asset_nodes: Array[Node2D] = Utils.get_reforge_assets(get_tree(), center, radius)
	for asset_node: Node2D in asset_nodes:
		if not asset_node.has_meta("blacksmith_reforged"):
			asset_node.set_meta("blacksmith_reforged", true)
			spawn_skill_vfx(asset_node.global_position, Color(1.0, 0.62, 0.25, 0.72), 0.36)
	for enemy: Node2D in Utils.get_enemies(get_tree()):
		if ring_poly.size() >= 3 and not Geometry2D.is_point_in_polygon(enemy.global_position, ring_poly):
			continue
		var nearest_asset: Vector2 = _find_nearest_asset_point(enemy.global_position, asset_nodes, center)
		Utils.apply_status(enemy, "burn", 0.7, 8.0, 1, 0.35)
		Utils.move_enemy_towards(enemy, nearest_asset, 20.0)


func _tick_paladin_closed(state: Dictionary) -> void:
	var polygon: PackedVector2Array = _read_polygon(state.get("polygon", PackedVector2Array()))
	var verdict_point: Vector2 = state.get("verdict_point", state.get("center", skill_owner.global_position))
	if polygon.size() < 3:
		return
	for enemy: Node2D in Utils.get_enemies(get_tree()):
		if not Geometry2D.is_point_in_polygon(enemy.global_position, polygon):
			continue
		Utils.move_enemy_towards(enemy, verdict_point, 30.0)
		Utils.apply_status(enemy, "marked", 0.9, 0.18, 1, 0.3)


func _tick_breachmarshal_closed(state: Dictionary, elapsed: float) -> void:
	var polygon: PackedVector2Array = _read_polygon(state.get("polygon", PackedVector2Array()))
	var center: Vector2 = state.get("center", skill_owner.global_position)
	var edge_point: Vector2 = state.get("reverb_point", center)
	if polygon.size() < 3:
		return
	var pull_phase: bool = fmod(elapsed, 0.32) < 0.16
	for enemy: Node2D in Utils.get_enemies(get_tree()):
		if not Geometry2D.is_point_in_polygon(enemy.global_position, polygon):
			continue
		if pull_phase:
			Utils.move_enemy_towards(enemy, center, 30.0)
		else:
			Utils.move_enemy_towards(enemy, edge_point, 44.0)
		Utils.apply_status(enemy, "marked", 0.8, 0.16, 1, 0.3)


func _tick_hexwarden_closed(state: Dictionary, elapsed: float) -> void:
	var polygon: PackedVector2Array = _read_polygon(state.get("polygon", PackedVector2Array()))
	var center: Vector2 = state.get("center", skill_owner.global_position)
	if polygon.size() < 3:
		return
	var inside: Array[Node2D] = []
	for enemy: Node2D in Utils.get_enemies(get_tree()):
		if Geometry2D.is_point_in_polygon(enemy.global_position, polygon):
			inside.append(enemy)
	if inside.is_empty():
		return
	var shrink_phase: bool = elapsed > _get_role_close_duration() * 0.55
	for enemy: Node2D in inside:
		Utils.apply_status(enemy, "curse", 1.0, 8.0, 1, 0.7)
		Utils.apply_status(enemy, "slow", 0.8, 0.24, 1, 0.1)
		if shrink_phase:
			Utils.move_enemy_towards(enemy, center, 16.0)
	if inside.size() >= 2:
		for enemy: Node2D in inside:
			Utils.apply_damage(enemy, 8)


func _tick_executioner_closed(state: Dictionary, elapsed: float) -> void:
	var polygon: PackedVector2Array = _read_polygon(state.get("polygon", PackedVector2Array()))
	var guillotine_start: Vector2 = state.get("guillotine_start", state.get("center", skill_owner.global_position))
	var guillotine_end: Vector2 = state.get("guillotine_end", state.get("center", skill_owner.global_position))
	var threshold: float = min(0.40, 0.28 + floor(elapsed / 0.20) * 0.04)
	if polygon.size() < 3:
		return
	for enemy: Node2D in Utils.get_enemies(get_tree()):
		if not Geometry2D.is_point_in_polygon(enemy.global_position, polygon):
			continue
		var projected: Dictionary = Utils.project_point_to_segment(enemy.global_position, guillotine_start, guillotine_end)
		Utils.move_enemy_towards(enemy, projected.get("point", enemy.global_position), 26.0)
		Utils.apply_status(enemy, "marked", 0.9, 0.22, 1, 0.3)
		if Utils.is_enemy_below_threshold(enemy, threshold):
			Global.spawn_floating_text(enemy.global_position, "名单", Color(1.0, 0.2, 0.2))


func _fill_open_payload(payload: Dictionary, points: Array[Vector2]) -> void:
	match colossus_role_id:
		"butcher":
			payload["anchor_point"] = points.back() if not points.is_empty() else skill_owner.global_position
		"glacier":
			payload["safe_side"] = _compute_player_side(points)
			payload["crack_points"] = [points.front(), points.back()]
		"jailer":
			payload["gate_points"] = Utils.get_polyline_sample_points(points, 180.0)
			payload["gate_dir"] = _release_dir
		"blacksmith":
			payload["slot_points"] = Utils.get_polyline_sample_points(points, 260.0)
		"paladin":
			payload["safe_side"] = _compute_player_side(points)
			payload["frontier_points"] = Utils.get_polyline_sample_points(points, 220.0)
		"breachmarshal":
			payload["mouth_point"] = points.back() if not points.is_empty() else skill_owner.global_position
		"hexwarden":
			payload["cursed_side"] = -_compute_player_side(points)
			payload["nail_points"] = Utils.get_polyline_sample_points(points, 220.0)
		"executioner":
			payload["threshold_base"] = 0.28


func _fill_closed_payload(payload: Dictionary, polygon: PackedVector2Array, center: Vector2, radius: float) -> void:
	var tangent: Vector2 = Vector2(-_release_dir.y, _release_dir.x)
	if tangent.length_squared() <= 0.0001:
		tangent = Vector2.UP
	match colossus_role_id:
		"butcher":
			payload["mouth_center"] = center + _release_dir * min(radius * 0.55, 110.0)
			payload["mouth_length"] = 110.0
			payload["mouth_angle_deg"] = 70.0
		"glacier":
			payload["return_corner"] = Utils.choose_vertex_by_direction(polygon, center, _release_dir)
		"jailer":
			payload["amnesty_point"] = Utils.choose_edge_midpoint_by_direction(polygon, center, _release_dir).get("point", center)
			payload["dead_door_point"] = Utils.choose_edge_midpoint_by_direction(polygon, center, -_release_dir).get("point", center)
		"blacksmith":
			payload["ring_direction"] = _release_dir
		"paladin":
			payload["entry_point"] = Utils.choose_edge_midpoint_by_direction(polygon, center, _release_dir).get("point", center)
			payload["verdict_point"] = Utils.choose_edge_midpoint_by_direction(polygon, center, -_release_dir).get("point", center)
		"breachmarshal":
			payload["mouth_point"] = Utils.choose_edge_midpoint_by_direction(polygon, center, _release_dir).get("point", center)
			payload["reverb_point"] = Utils.choose_edge_midpoint_by_direction(polygon, center, -_release_dir).get("point", center)
		"hexwarden":
			payload["hall_dir"] = _release_dir
		"executioner":
			payload["guillotine_start"] = center - tangent * radius * 0.7
			payload["guillotine_end"] = center + tangent * radius * 0.7
			payload["threshold_base"] = 0.28


func _get_role_open_duration() -> float:
	var spec: Dictionary = get_role_spec()
	var timing: Variant = spec.get("timing", {})
	if timing is Dictionary:
		return max(1.0, float((timing as Dictionary).get("q_open_sec", 2.6)))
	return 2.6


func _get_role_close_duration() -> float:
	var spec: Dictionary = get_role_spec()
	var timing: Variant = spec.get("timing", {})
	if timing is Dictionary:
		return max(1.0, float((timing as Dictionary).get("q_close_sec", 1.8)))
	return 1.8


func _get_open_projection_distance() -> float:
	match colossus_role_id:
		"butcher":
			return 240.0
		"glacier":
			return 210.0
		"jailer":
			return 220.0
		"breachmarshal":
			return 240.0
		_:
			return 0.0


func _get_close_projection_distance() -> float:
	match colossus_role_id:
		"butcher":
			return 220.0
		"glacier":
			return 190.0
		"jailer":
			return 200.0
		_:
			return 0.0


func _get_role_line_width() -> float:
	match colossus_role_id:
		"butcher":
			return 84.0
		"glacier":
			return 96.0
		"jailer":
			return 78.0
		"blacksmith":
			return 88.0
		"paladin":
			return 92.0
		"breachmarshal":
			return 96.0
		"hexwarden":
			return 84.0
		"executioner":
			return 82.0
		_:
			return 82.0


func _get_open_tick_interval() -> float:
	match colossus_role_id:
		"butcher":
			return 0.20
		"blacksmith":
			return 0.24
		"executioner":
			return 0.20
		_:
			return 0.18


func _get_closed_tick_interval() -> float:
	match colossus_role_id:
		"butcher":
			return 0.10
		"glacier":
			return 0.12
		"executioner":
			return 0.12
		_:
			return 0.16


func _get_open_color() -> Color:
	match colossus_role_id:
		"butcher":
			return Color(0.9, 0.16, 0.14, 0.86)
		"glacier":
			return Color(0.62, 0.88, 1.0, 0.82)
		"jailer":
			return Color(0.98, 0.86, 0.38, 0.82)
		"blacksmith":
			return Color(1.0, 0.58, 0.22, 0.84)
		"paladin":
			return Color(1.0, 0.9, 0.48, 0.84)
		"breachmarshal":
			return Color(0.92, 0.88, 0.76, 0.84)
		"hexwarden":
			return Color(0.9, 0.42, 1.0, 0.84)
		"executioner":
			return Color(1.0, 0.26, 0.26, 0.84)
		_:
			return Color.WHITE


func _get_closed_color() -> Color:
	return _get_open_color().darkened(0.12)


func _role_uses_wall_visual() -> bool:
	return colossus_role_id in ["glacier", "jailer", "paladin"]


func _find_primary_transformed_polygon() -> PackedVector2Array:
	var polygons: Array = PolygonUtils.find_all_closing_polygons(path_points, _get_closure_tolerance())
	if polygons.is_empty():
		return PackedVector2Array()
	var best_poly: PackedVector2Array = _transform_polygon_for_execution(polygons[0])
	var best_area: float = _calculate_polygon_area(best_poly)
	for poly_obj: Variant in polygons:
		if not (poly_obj is PackedVector2Array):
			continue
		var poly: PackedVector2Array = _transform_polygon_for_execution(poly_obj)
		var area: float = _calculate_polygon_area(poly)
		if area > best_area:
			best_area = area
			best_poly = poly
	return best_poly


func _find_primary_source_polygon() -> PackedVector2Array:
	var polygons: Array = PolygonUtils.find_all_closing_polygons(path_points, _get_closure_tolerance())
	return _select_largest_polygon(polygons)


func _select_largest_polygon(polygons: Array) -> PackedVector2Array:
	var best_polygon: PackedVector2Array = PackedVector2Array()
	var best_area: float = -1.0
	for polygon_var: Variant in polygons:
		if not (polygon_var is PackedVector2Array):
			continue
		var polygon: PackedVector2Array = polygon_var
		if polygon.size() < 3:
			continue
		var area: float = absf(_calculate_polygon_area(polygon))
		if area <= best_area:
			continue
		best_area = area
		best_polygon = polygon
	return best_polygon


func _polygon_to_local_points(polygon: PackedVector2Array, origin: Vector2) -> PackedVector2Array:
	var local_points: PackedVector2Array = PackedVector2Array()
	for point: Vector2 in polygon:
		local_points.append(point - origin)
	return local_points


func _spawn_polyline_visual(points: Array[Vector2], width: float, color: Color, duration: float, wall_mode: bool) -> void:
	if points.size() < 2:
		return
	for i: int in range(max(0, points.size() - 1)):
		if wall_mode:
			SkillEffectManager.create_wall_effect({
				"start": points[i],
				"end": points[i + 1],
				"width": width,
				"duration": duration,
				"block_enemies": true,
				"block_bullets": false,
				"contact_damage": 0,
				"color": color,
			})
	if not wall_mode:
		_spawn_continuous_polyline_visual(points, width, color, duration)


func _spawn_line_visual_segment(start: Vector2, end_pos: Vector2, width: float, color: Color, duration: float) -> void:
	SkillEffectManager.create_line_effect({
		"start": start,
		"end": end_pos,
		"width": width,
		"damage": 0,
		"damage_interval": 0.2,
		"duration": duration,
		"color": color,
	})


func _spawn_continuous_polyline_visual(points: Array[Vector2], width: float, color: Color, duration: float) -> void:
	if points.size() < 2:
		return
	var tree: SceneTree = get_tree()
	if tree == null or tree.current_scene == null:
		return

	var host: Node2D = Node2D.new()
	host.name = "%sOpenPolylineVisual" % colossus_role_id.capitalize()
	host.z_index = 96
	host.global_position = points[0]
	host.add_to_group("player_skill_effects")

	var line: Line2D = Line2D.new()
	line.width = max(2.0, width)
	line.default_color = color
	line.begin_cap_mode = Line2D.LINE_CAP_ROUND
	line.end_cap_mode = Line2D.LINE_CAP_ROUND
	line.joint_mode = Line2D.LINE_JOINT_ROUND
	line.antialiased = true
	line.z_index = 96
	line.modulate = Color(1.0, 1.0, 1.0, 0.0)
	for point: Vector2 in points:
		line.add_point(point - points[0])
	host.add_child(line)

	tree.current_scene.add_child(host)

	var safe_duration: float = max(0.12, duration)
	var fade_in_sec: float = min(0.12, safe_duration * 0.22)
	var fade_out_sec: float = min(0.18, safe_duration * 0.28)
	var hold_sec: float = max(0.0, safe_duration - fade_in_sec - fade_out_sec)
	var tween: Tween = host.create_tween()
	tween.tween_property(line, "modulate:a", 1.0, fade_in_sec)
	if hold_sec > 0.0:
		tween.tween_interval(hold_sec)
	tween.tween_property(line, "modulate:a", 0.0, fade_out_sec)
	tween.tween_callback(func() -> void:
		if is_instance_valid(host):
			host.queue_free()
	)


func _compute_player_side(points: Array[Vector2]) -> float:
	if points.size() < 2 or not is_instance_valid(skill_owner):
		return 1.0
	var seg_dir: Vector2 = (points[1] - points[0]).normalized()
	if seg_dir.length_squared() <= 0.0001:
		return 1.0
	var normal: Vector2 = Vector2(-seg_dir.y, seg_dir.x)
	return 1.0 if normal.dot(skill_owner.global_position - points[0]) >= 0.0 else -1.0


func _find_nearest_point(origin: Vector2, points: Array[Vector2]) -> Vector2:
	if points.is_empty():
		return Vector2.ZERO
	var best_point: Vector2 = points[0]
	var best_dist: float = origin.distance_to(best_point)
	for point: Vector2 in points:
		var dist: float = origin.distance_to(point)
		if dist >= best_dist:
			continue
		best_dist = dist
		best_point = point
	return best_point


func _find_nearest_asset_point(origin: Vector2, asset_nodes: Array[Node2D], fallback: Vector2) -> Vector2:
	if asset_nodes.is_empty():
		return fallback
	var best_point: Vector2 = asset_nodes[0].global_position
	var best_dist: float = origin.distance_to(best_point)
	for asset_node: Node2D in asset_nodes:
		var dist: float = origin.distance_to(asset_node.global_position)
		if dist >= best_dist:
			continue
		best_dist = dist
		best_point = asset_node.global_position
	return best_point


func _read_points(raw_points: Variant) -> Array[Vector2]:
	var points: Array[Vector2] = []
	if raw_points is PackedVector2Array:
		for point: Vector2 in raw_points:
			points.append(point)
		return points
	if raw_points is Array:
		for point_var: Variant in raw_points:
			if point_var is Vector2:
				points.append(point_var)
	return points


func _read_polygon(raw_polygon: Variant) -> PackedVector2Array:
	if raw_polygon is PackedVector2Array:
		return raw_polygon
	var polygon: PackedVector2Array = PackedVector2Array()
	if raw_polygon is Array:
		for point_var: Variant in raw_polygon:
			if point_var is Vector2:
				polygon.append(point_var)
	return polygon


func _clear_open_state() -> void:
	if is_instance_valid(_open_host):
		_open_host.queue_free()
	_open_host = null
	_open_state.clear()


func _clear_closed_state() -> void:
	if is_instance_valid(_closed_host):
		_closed_host.queue_free()
	_closed_host = null
	_closed_state.clear()


func _clear_active_hosts() -> void:
	_clear_open_state()
	_clear_closed_state()


func cleanup() -> void:
	_clear_projection_preview()
	super.cleanup()


func _clear_projection_preview() -> void:
	if is_instance_valid(_projection_preview_host):
		_projection_preview_host.queue_free()
	_projection_preview_host = null


func _uses_projected_open_launch() -> bool:
	return colossus_role_id in ["butcher", "glacier", "jailer", "breachmarshal"]


func _uses_projected_closed_launch() -> bool:
	return colossus_role_id in ["butcher", "glacier", "jailer"]


func _get_open_projection_travel_sec() -> float:
	match colossus_role_id:
		"butcher":
			return 0.24
		"glacier":
			return 0.24
		"jailer":
			return 0.24
		"breachmarshal":
			return 0.24
		_:
			return 0.0


func _get_close_projection_travel_sec() -> float:
	match colossus_role_id:
		"butcher":
			return 0.24
		"glacier":
			return 0.24
		"jailer":
			return 0.24
		_:
			return 0.0
