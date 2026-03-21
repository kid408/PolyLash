extends RefCounted
class_name ColossusSkillUtils


static func get_enemies(tree: SceneTree) -> Array[Node2D]:
	var enemies: Array[Node2D] = []
	if tree == null:
		return enemies
	for enemy_obj: Variant in tree.get_nodes_in_group("enemies"):
		if enemy_obj == null or not is_instance_valid(enemy_obj):
			continue
		if enemy_obj is Node2D:
			enemies.append(enemy_obj as Node2D)
	return enemies


static func find_nearest_enemy(
	tree: SceneTree,
	center: Vector2,
	max_distance: float,
	aim_dir: Vector2 = Vector2.ZERO,
	cone_deg: float = -1.0
) -> Node2D:
	var best: Node2D = null
	var best_dist: float = max_distance
	var use_cone: bool = cone_deg > 0.0 and aim_dir.length_squared() > 0.0001
	var safe_dir: Vector2 = aim_dir.normalized()
	for enemy: Node2D in get_enemies(tree):
		var dist: float = center.distance_to(enemy.global_position)
		if dist > best_dist:
			continue
		if use_cone and not is_point_in_cone(enemy.global_position, center, safe_dir, cone_deg, max_distance):
			continue
		best = enemy
		best_dist = dist
	return best


static func is_point_in_cone(
	point: Vector2,
	origin: Vector2,
	aim_dir: Vector2,
	cone_deg: float,
	radius: float
) -> bool:
	var offset: Vector2 = point - origin
	if offset.length_squared() <= 0.0001:
		return true
	if offset.length() > radius:
		return false
	var safe_dir: Vector2 = aim_dir.normalized()
	if safe_dir.length_squared() <= 0.0001:
		return true
	return rad_to_deg(abs(safe_dir.angle_to(offset.normalized()))) <= cone_deg * 0.5


static func build_circle_polygon(center: Vector2, radius: float, segments: int = 18) -> PackedVector2Array:
	var points: PackedVector2Array = PackedVector2Array()
	var safe_segments: int = max(6, segments)
	var safe_radius: float = max(2.0, radius)
	for i: int in range(safe_segments):
		var angle: float = TAU * float(i) / float(safe_segments)
		points.append(center + Vector2.RIGHT.rotated(angle) * safe_radius)
	return points


static func translate_polygon(polygon: PackedVector2Array, offset: Vector2) -> PackedVector2Array:
	var shifted: PackedVector2Array = PackedVector2Array()
	for point: Vector2 in polygon:
		shifted.append(point + offset)
	return shifted


static func translate_points(points: Array[Vector2], offset: Vector2) -> Array[Vector2]:
	var shifted: Array[Vector2] = []
	for point: Vector2 in points:
		shifted.append(point + offset)
	return shifted


static func project_point_to_segment(point: Vector2, start: Vector2, finish: Vector2) -> Dictionary:
	var seg: Vector2 = finish - start
	var len_sq: float = seg.length_squared()
	if len_sq <= 0.0001:
		return {
			"point": start,
			"t": 0.0,
			"distance": point.distance_to(start),
		}
	var t: float = clamp((point - start).dot(seg) / len_sq, 0.0, 1.0)
	var closest: Vector2 = start + seg * t
	return {
		"point": closest,
		"t": t,
		"distance": point.distance_to(closest),
	}


static func project_point_to_polyline(point: Vector2, points: Array[Vector2]) -> Dictionary:
	if points.size() <= 1:
		var base_point: Vector2 = point
		if points.size() == 1:
			base_point = points[0]
		return {
			"point": base_point,
			"index": 0,
			"t": 0.0,
			"distance": point.distance_to(base_point),
		}
	var best: Dictionary = {
		"point": points[0],
		"index": 0,
		"t": 0.0,
		"distance": INF,
	}
	for i: int in range(points.size() - 1):
		var projected: Dictionary = project_point_to_segment(point, points[i], points[i + 1])
		if float(projected.get("distance", INF)) >= float(best.get("distance", INF)):
			continue
		best["point"] = projected.get("point", points[i])
		best["index"] = i
		best["t"] = float(projected.get("t", 0.0))
		best["distance"] = float(projected.get("distance", INF))
	return best


static func advance_along_polyline(
	points: Array[Vector2],
	segment_index: int,
	segment_t: float,
	distance: float,
	forward: bool = true
) -> Dictionary:
	if points.size() <= 1:
		var only_point: Vector2 = Vector2.ZERO
		if not points.is_empty():
			only_point = points[0]
		return {"point": only_point, "index": 0, "t": 0.0}

	var remaining: float = max(0.0, distance)
	var safe_index: int = clamp(segment_index, 0, points.size() - 2)
	var safe_t: float = clamp(segment_t, 0.0, 1.0)
	var step: int = 1 if forward else -1
	var current_index: int = safe_index
	var current_t: float = safe_t

	while true:
		var start_idx: int = current_index
		var end_idx: int = current_index + step
		if end_idx < 0 or end_idx >= points.size():
			break
		var start_point: Vector2 = points[start_idx]
		var end_point: Vector2 = points[end_idx]
		var seg: Vector2 = end_point - start_point
		var seg_len: float = seg.length()
		if seg_len <= 0.0001:
			current_index += step
			current_t = 0.0 if forward else 1.0
			continue

		var progress_len: float = (seg_len * (1.0 - current_t)) if forward else (seg_len * current_t)
		if remaining <= progress_len:
			var ratio_delta: float = remaining / seg_len
			var final_t: float = current_t + ratio_delta if forward else current_t - ratio_delta
			var point: Vector2 = start_point.lerp(end_point, clamp(final_t, 0.0, 1.0))
			return {
				"point": point,
				"index": current_index,
				"t": clamp(final_t, 0.0, 1.0),
			}

		remaining -= progress_len
		current_index += step
		current_t = 0.0 if forward else 1.0

	return {
		"point": points.back() if forward else points.front(),
		"index": clamp(points.size() - 2 if forward else 0, 0, max(0, points.size() - 2)),
		"t": 1.0 if forward else 0.0,
	}


static func distance_to_polyline(point: Vector2, points: Array[Vector2]) -> float:
	return float(project_point_to_polyline(point, points).get("distance", INF))


static func get_polyline_length(points: Array[Vector2]) -> float:
	var total: float = 0.0
	for i: int in range(max(0, points.size() - 1)):
		total += points[i].distance_to(points[i + 1])
	return total


static func get_polyline_sample_points(points: Array[Vector2], spacing: float) -> Array[Vector2]:
	var samples: Array[Vector2] = []
	if points.is_empty():
		return samples
	samples.append(points[0])
	if points.size() == 1:
		return samples
	var cursor: float = max(16.0, spacing)
	var total: float = get_polyline_length(points)
	while cursor < total:
		var step: Dictionary = advance_from_distance(points, cursor)
		samples.append(step.get("point", points[0]))
		cursor += max(16.0, spacing)
	samples.append(points.back())
	return samples


static func advance_from_distance(points: Array[Vector2], distance: float) -> Dictionary:
	if points.size() <= 1:
		var only_point: Vector2 = Vector2.ZERO
		if not points.is_empty():
			only_point = points[0]
		return {"point": only_point, "index": 0, "t": 0.0}
	var remaining: float = max(0.0, distance)
	for i: int in range(points.size() - 1):
		var seg_len: float = points[i].distance_to(points[i + 1])
		if seg_len <= 0.0001:
			continue
		if remaining <= seg_len:
			var t: float = remaining / seg_len
			return {
				"point": points[i].lerp(points[i + 1], t),
				"index": i,
				"t": t,
			}
		remaining -= seg_len
	return {"point": points.back(), "index": points.size() - 2, "t": 1.0}


static func choose_vertex_by_direction(polygon: PackedVector2Array, center: Vector2, dir: Vector2) -> Vector2:
	if polygon.is_empty():
		return center
	var safe_dir: Vector2 = dir.normalized()
	if safe_dir.length_squared() <= 0.0001:
		return polygon[0]
	var best_point: Vector2 = polygon[0]
	var best_score: float = -INF
	for point: Vector2 in polygon:
		var score: float = safe_dir.dot((point - center).normalized())
		if score > best_score:
			best_score = score
			best_point = point
	return best_point


static func choose_edge_midpoint_by_direction(polygon: PackedVector2Array, center: Vector2, dir: Vector2) -> Dictionary:
	if polygon.size() < 2:
		return {"point": center, "index": 0}
	var safe_dir: Vector2 = dir.normalized()
	if safe_dir.length_squared() <= 0.0001:
		safe_dir = Vector2.RIGHT
	var best_mid: Vector2 = (polygon[0] + polygon[1]) * 0.5
	var best_index: int = 0
	var best_score: float = -INF
	for i: int in range(polygon.size()):
		var next_i: int = (i + 1) % polygon.size()
		var mid: Vector2 = (polygon[i] + polygon[next_i]) * 0.5
		var score: float = safe_dir.dot((mid - center).normalized())
		if score > best_score:
			best_score = score
			best_mid = mid
			best_index = i
	return {"point": best_mid, "index": best_index}


static func distance_to_polygon_edge(point: Vector2, polygon: PackedVector2Array) -> Dictionary:
	if polygon.size() < 2:
		return {"distance": INF, "point": point, "index": 0}
	var best_distance: float = INF
	var best_point: Vector2 = point
	var best_index: int = 0
	for i: int in range(polygon.size()):
		var next_i: int = (i + 1) % polygon.size()
		var projected: Dictionary = project_point_to_segment(point, polygon[i], polygon[next_i])
		var dist: float = float(projected.get("distance", INF))
		if dist >= best_distance:
			continue
		best_distance = dist
		best_point = projected.get("point", point)
		best_index = i
	return {
		"distance": best_distance,
		"point": best_point,
		"index": best_index,
	}


static func apply_damage(enemy: Node2D, amount: int) -> void:
	if enemy == null or not is_instance_valid(enemy):
		return
	if not enemy.has_node("HealthComponent"):
		return
	var hc: Node = enemy.get_node("HealthComponent")
	if hc != null and hc.has_method("take_damage"):
		hc.call("take_damage", max(1, amount))


static func apply_status(
	enemy: Node2D,
	status_name: String,
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
			status_name,
			max(0.1, duration),
			value,
			max(1, stacks),
			max(0.05, tick_interval)
		)


static func enemy_has_status(enemy: Node2D, status_name: String) -> bool:
	if enemy == null or not is_instance_valid(enemy):
		return false
	if enemy.has_method("has_status"):
		return bool(enemy.call("has_status", status_name))
	return false


static func apply_knockback_or_move(enemy: Node2D, direction: Vector2, power: float, fallback_scale: float = 0.1) -> void:
	if enemy == null or not is_instance_valid(enemy):
		return
	var safe_dir: Vector2 = direction.normalized()
	if safe_dir.length_squared() <= 0.0001:
		return
	if enemy.has_method("apply_knockback"):
		enemy.call("apply_knockback", safe_dir, power)
	else:
		enemy.global_position += safe_dir * max(24.0, power * fallback_scale)


static func move_enemy_towards(enemy: Node2D, target: Vector2, distance: float) -> void:
	if enemy == null or not is_instance_valid(enemy):
		return
	var offset: Vector2 = target - enemy.global_position
	if offset.length_squared() <= 0.0001:
		return
	var max_step: float = min(offset.length(), max(0.0, distance))
	enemy.global_position += offset.normalized() * max_step


static func move_enemy_to_offset(enemy: Node2D, target: Vector2, lerp_ratio: float = 0.45) -> void:
	if enemy == null or not is_instance_valid(enemy):
		return
	enemy.global_position = enemy.global_position.lerp(target, clamp(lerp_ratio, 0.0, 1.0))


static func enemy_hp_ratio(enemy: Node2D) -> float:
	if enemy == null or not is_instance_valid(enemy):
		return 1.0
	if not enemy.has_node("HealthComponent"):
		return 1.0
	var hc: Node = enemy.get_node("HealthComponent")
	if hc == null:
		return 1.0
	var max_hp: float = max(1.0, float(hc.get("max_health")))
	return float(hc.get("current_health")) / max_hp


static func is_enemy_below_threshold(enemy: Node2D, threshold: float) -> bool:
	return enemy_hp_ratio(enemy) <= max(0.0, threshold)


static func get_reforge_assets(tree: SceneTree, center: Vector2, radius: float) -> Array[Node2D]:
	var result: Array[Node2D] = []
	if tree == null:
		return result
	var groups: Array[String] = ["projectiles", "player_skill_effects", "summons", "pickups"]
	var seen: Dictionary = {}
	for group_name: String in groups:
		for node_var: Variant in tree.get_nodes_in_group(group_name):
			if node_var == null or not is_instance_valid(node_var):
				continue
			if not (node_var is Node2D):
				continue
			var node2d: Node2D = node_var
			if seen.has(node2d):
				continue
			if center.distance_to(node2d.global_position) > radius:
				continue
			seen[node2d] = true
			result.append(node2d)
	return result
