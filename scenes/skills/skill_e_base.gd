extends SkillBase
class_name SkillEBase

var q_context_max_age_msec: int = 8000
var _e_context_published_this_cast: bool = false
var _staged_e_context_valid: bool = false
var _staged_e_center: Vector2 = Vector2.ZERO
var _staged_e_radius: float = 0.0
var _staged_e_source_kind: String = "e_action"
var _staged_e_payload: Dictionary = {}
var _staged_e_asset_kind: String = ""
var _staged_e_asset_duration_sec: float = 0.0

func consume_energy() -> bool:
	_e_context_published_this_cast = false
	_clear_staged_e_context()
	return super.consume_energy()

func start_cooldown() -> void:
	_publish_pending_e_context_if_needed()
	super.start_cooldown()

func get_recent_q_context(max_age_msec: int = -1) -> Dictionary:
	var effective_age: int = q_context_max_age_msec if max_age_msec < 0 else max_age_msec
	return SkillContextBridge.get_q_context(skill_owner, effective_age)

func get_recent_q_asset(kind_filter: String = "", max_age_msec: int = -1) -> Dictionary:
	var effective_age: int = q_context_max_age_msec if max_age_msec < 0 else max_age_msec
	return SkillContextBridge.get_recent_q_asset(skill_owner, kind_filter, effective_age)

func get_recent_q_assets(kind_filter: String = "", max_age_msec: int = -1) -> Array[Dictionary]:
	var effective_age: int = q_context_max_age_msec if max_age_msec < 0 else max_age_msec
	return SkillContextBridge.get_q_assets(skill_owner, kind_filter, effective_age)

func get_recent_draw_snapshot(max_age_sec: float = 8.0) -> Dictionary:
	if Global == null or not is_instance_valid(skill_owner):
		return {}
	if not ("player_id" in skill_owner):
		return {}
	var player_id: String = str(skill_owner.get("player_id")).strip_edges()
	if player_id.is_empty():
		return {}
	var snapshot: Dictionary = Global.get_recent_draw_path(player_id)
	if snapshot.is_empty():
		return {}
	var timestamp: float = float(snapshot.get("timestamp", 0.0))
	if max_age_sec > 0.0 and timestamp > 0.0 and Time.get_ticks_msec() / 1000.0 - timestamp > max_age_sec:
		return {}
	return snapshot

func get_recent_draw_points(max_age_sec: float = 8.0) -> Array[Vector2]:
	var snapshot: Dictionary = get_recent_draw_snapshot(max_age_sec)
	if snapshot.is_empty():
		return []
	var points_var: Variant = snapshot.get("points", [])
	if not (points_var is Array):
		return []
	var points: Array[Vector2] = []
	for point_var in points_var:
		if point_var is Vector2:
			points.append(point_var)
	return points

func is_recent_draw_closed(max_age_sec: float = 8.0) -> bool:
	var snapshot: Dictionary = get_recent_draw_snapshot(max_age_sec)
	if snapshot.is_empty():
		return false
	return bool(snapshot.get("closed", false))

func get_q_asset_points(asset: Dictionary) -> Array[Vector2]:
	if asset.is_empty():
		return []
	var payload_var: Variant = asset.get("payload", {})
	if not (payload_var is Dictionary):
		return []
	var payload: Dictionary = payload_var
	var points_var: Variant = payload.get("points", [])
	if not (points_var is Array):
		return []
	var points: Array[Vector2] = []
	for point_var in points_var:
		if point_var is Vector2:
			points.append(point_var)
	return points

func get_recent_q_path_points(kind_filter: String = "", max_age_msec: int = -1) -> Array[Vector2]:
	var asset: Dictionary = get_recent_q_asset(kind_filter, max_age_msec)
	var asset_points: Array[Vector2] = get_q_asset_points(asset)
	if asset_points.size() >= 2:
		return asset_points
	return get_recent_draw_points(float((q_context_max_age_msec if max_age_msec < 0 else max_age_msec)) / 1000.0)

func spawn_transient_polyline(
	points: Array[Vector2],
	color: Color,
	width: float = 12.0,
	duration: float = 0.35,
	closed: bool = false
) -> Node2D:
	if points.size() < 2:
		return null
	var tree: SceneTree = get_tree()
	if tree == null or tree.current_scene == null:
		return null
	var host: Node2D = Node2D.new()
	host.name = "ESkillTransientPolyline"
	host.z_index = 95
	var line: Line2D = Line2D.new()
	line.width = max(2.0, width)
	line.default_color = color
	line.z_index = 95
	for point in points:
		line.add_point(point)
	if closed:
		line.add_point(points[0])
	host.add_child(line)
	tree.current_scene.add_child(host)
	var host_ref: WeakRef = weakref(host)
	tree.create_timer(max(0.08, duration)).timeout.connect(func() -> void:
		var host_obj: Variant = host_ref.get_ref() if host_ref != null else null
		if host_obj != null and is_instance_valid(host_obj):
			(host_obj as Node).queue_free()
	)
	return host

func spawn_transient_ring(
	center: Vector2,
	radius: float,
	color: Color,
	width: float = 8.0,
	duration: float = 0.35
) -> Node2D:
	var points: Array[Vector2] = []
	var segments: int = 24
	var safe_radius: float = max(12.0, radius)
	for i in range(segments):
		var angle: float = TAU * float(i) / float(segments)
		points.append(center + Vector2.RIGHT.rotated(angle) * safe_radius)
	return spawn_transient_polyline(points, color, width, duration, true)

func publish_e_context(
	center: Vector2,
	radius: float,
	source_kind: String = "e_action",
	payload: Dictionary = {},
	asset_kind: String = "",
	asset_duration_sec: float = 0.0
) -> Dictionary:
	var packet: SkillContextPacket = SkillContextBridge.build_packet(
		skill_owner,
		"e",
		skill_id,
		source_kind,
		center,
		radius,
		payload,
		{},
		["e"]
	)
	_e_context_published_this_cast = true
	_staged_e_context_valid = false
	return SkillContextBridge.publish_e_context(
		skill_owner,
		packet,
		asset_kind,
		asset_duration_sec,
		payload
	)

func stage_e_context(
	center: Vector2,
	radius: float,
	source_kind: String = "e_action",
	payload: Dictionary = {},
	asset_kind: String = "",
	asset_duration_sec: float = 0.0
) -> void:
	_staged_e_context_valid = true
	_staged_e_center = center
	_staged_e_radius = max(48.0, radius)
	_staged_e_source_kind = source_kind
	_staged_e_payload = payload.duplicate(true)
	_staged_e_asset_kind = asset_kind
	_staged_e_asset_duration_sec = asset_duration_sec

func get_q_skill() -> Node:
	if not is_instance_valid(skill_owner):
		return null
	var skill_manager: Node = skill_owner.get_node_or_null("SkillManager")
	if skill_manager == null or not is_instance_valid(skill_manager):
		return null
	if not skill_manager.has_method("get_skill"):
		return null
	var q_skill_var: Variant = skill_manager.call("get_skill", "q")
	if q_skill_var is Node:
		return q_skill_var as Node
	return null

func find_nearest_enemy(max_distance: float) -> Node2D:
	if not is_inside_tree():
		return null
	var best: Node2D = null
	var best_dist: float = max_distance
	for enemy_obj in get_tree().get_nodes_in_group("enemies"):
		if enemy_obj == null or not is_instance_valid(enemy_obj):
			continue
		if not (enemy_obj is Node2D):
			continue
		var enemy: Node2D = enemy_obj as Node2D
		var dist: float = skill_owner.global_position.distance_to(enemy.global_position)
		if dist > best_dist:
			continue
		best = enemy
		best_dist = dist
	return best

func apply_damage(enemy: Node2D, amount: int) -> void:
	if enemy == null or not is_instance_valid(enemy):
		return
	if not enemy.has_node("HealthComponent"):
		return
	var health_component: Node = enemy.get_node("HealthComponent")
	if health_component != null and health_component.has_method("take_damage"):
		health_component.call("take_damage", max(1, amount))

func apply_status(
	enemy: Node2D,
	status_type: String,
	duration: float,
	value: float,
	stacks: int = 1,
	tick_interval: float = 0.6
) -> void:
	if enemy == null or not is_instance_valid(enemy):
		return
	if enemy.has_method("apply_status"):
		enemy.call(
			"apply_status",
			status_type,
			max(0.1, duration),
			value,
			max(1, stacks),
			max(0.05, tick_interval)
		)

func enemy_has_status(enemy: Node2D, status_type: String) -> bool:
	if enemy == null or not is_instance_valid(enemy):
		return false
	if enemy.has_method("has_status"):
		return bool(enemy.call("has_status", status_type))
	return false

func distance_point_to_segment(point: Vector2, start: Vector2, finish: Vector2) -> float:
	var segment: Vector2 = finish - start
	var len_sq: float = segment.length_squared()
	if len_sq <= 0.0001:
		return point.distance_to(start)
	var t: float = clamp((point - start).dot(segment) / len_sq, 0.0, 1.0)
	var closest: Vector2 = start + segment * t
	return point.distance_to(closest)

func get_aim_direction() -> Vector2:
	if not is_instance_valid(skill_owner):
		return Vector2.RIGHT
	var dir: Vector2 = skill_owner.get_global_mouse_position() - skill_owner.global_position
	if dir.length_squared() <= 0.01:
		return Vector2.RIGHT
	return dir.normalized()

func get_enemy_hp_ratio(enemy: Node2D) -> float:
	if enemy == null or not is_instance_valid(enemy):
		return 1.0
	if not enemy.has_node("HealthComponent"):
		return 1.0
	var health_component: Node = enemy.get_node("HealthComponent")
	if health_component == null:
		return 1.0
	if not ("max_health" in health_component and "current_health" in health_component):
		return 1.0
	var max_hp: float = max(1.0, float(health_component.get("max_health")))
	return float(health_component.get("current_health")) / max_hp

func _publish_pending_e_context_if_needed() -> void:
	if _e_context_published_this_cast or not is_instance_valid(skill_owner):
		return

	var role_id: String = _resolve_role_id()
	var center: Vector2 = skill_owner.global_position
	var radius: float = 160.0
	var source_kind: String = "%s_action" % role_id
	var payload: Dictionary = {
		"role_id": role_id,
		"auto_generated": true,
	}
	var asset_kind: String = "%s_e_window" % role_id
	var asset_duration_sec: float = 2.0

	if _staged_e_context_valid:
		center = _staged_e_center
		radius = max(48.0, _staged_e_radius)
		source_kind = _staged_e_source_kind
		payload = _staged_e_payload.duplicate(true)
		payload["role_id"] = role_id
		asset_kind = _staged_e_asset_kind
		asset_duration_sec = _staged_e_asset_duration_sec
	else:
		var q_context: Dictionary = get_recent_q_context()
		if not q_context.is_empty():
			var q_center_var: Variant = q_context.get("center", center)
			if q_center_var is Vector2:
				center = q_center_var
			var q_radius: float = max(60.0, float(q_context.get("radius", radius)))
			var q_closed: bool = bool(q_context.get("is_closed", false))
			radius = max(radius, q_radius * (0.72 if q_closed else 0.55))
			payload["used_q_context"] = true
			payload["q_closed"] = q_closed
			payload["segment_count"] = int(q_context.get("segment_count", 0))
			payload["polygon_count"] = int(q_context.get("polygon_count", 0))
		var q_asset: Dictionary = get_recent_q_asset("", 4000)
		if not q_asset.is_empty():
			radius = max(radius, max(60.0, float(q_asset.get("radius", radius))) * 0.8)
			var q_asset_kind: String = str(q_asset.get("kind", "")).strip_edges()
			if not q_asset_kind.is_empty():
				payload["q_asset_kind"] = q_asset_kind

	publish_e_context(
		center,
		radius,
		source_kind,
		payload,
		asset_kind,
		asset_duration_sec
	)
	_clear_staged_e_context()

func _clear_staged_e_context() -> void:
	_staged_e_context_valid = false
	_staged_e_center = Vector2.ZERO
	_staged_e_radius = 0.0
	_staged_e_source_kind = "e_action"
	_staged_e_payload = {}
	_staged_e_asset_kind = ""
	_staged_e_asset_duration_sec = 0.0

func _resolve_role_id() -> String:
	if is_instance_valid(skill_owner) and "player_id" in skill_owner:
		return str(skill_owner.get("player_id")).strip_edges().to_lower()
	var base_id: String = skill_id.trim_prefix("skill_")
	if base_id.ends_with("_e"):
		base_id = base_id.substr(0, base_id.length() - 2)
	if base_id.is_empty():
		return "skill"
	return base_id.to_lower()
