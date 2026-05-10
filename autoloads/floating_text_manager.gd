extends Node
class_name FloatingTextManager

const INITIAL_POOL_SIZE: int = 50
const MAX_STATUS_TEXTS: int = 15
const STATUS_CLUSTER_WINDOW: float = 0.10
const STATUS_CLUSTER_RADIUS: float = 150.0
const LOW_DAMAGE_SHOW_CHANCE: float = 0.30

var _floating_text_scene: PackedScene = null
var _pool: Array[FloatingText] = []
var _active_metadata: Dictionary = {}
var _pending_status_clusters: Array[Dictionary] = []
var _active_status_text_count: int = 0

func configure(scene: PackedScene) -> void:
	_floating_text_scene = scene
	if _floating_text_scene == null:
		return
	if _pool.is_empty():
		_expand_pool(INITIAL_POOL_SIZE)
	set_process(true)

func request_floating_text(pos: Vector2, value: String, color: Color) -> void:
	if _floating_text_scene == null:
		return
	var normalized_value: String = value.strip_edges()
	if normalized_value.is_empty():
		return
	if _is_numeric_damage_text(normalized_value):
		_request_damage_text(pos, normalized_value, color)
		return
	_request_status_text(pos, normalized_value, color)

func _process(_delta: float) -> void:
	if _pending_status_clusters.is_empty():
		return
	var now: float = _now_seconds()
	for i in range(_pending_status_clusters.size() - 1, -1, -1):
		var cluster: Dictionary = _pending_status_clusters[i]
		if now < float(cluster.get("expires_at", 0.0)):
			continue
		_pending_status_clusters.remove_at(i)
		_flush_status_cluster(cluster)

func _request_damage_text(pos: Vector2, value: String, color: Color) -> void:
	var damage_amount: int = _extract_last_number(value)
	if damage_amount > 0 and _should_cull_low_damage(damage_amount, color):
		return
	var baseline: float = _get_damage_baseline()
	var scale_mult: float = _compute_damage_scale(value, color, damage_amount, baseline)
	var options := {
		"is_status_text": false,
		"scale_mult": scale_mult,
		"spread_x": 54.0,
		"rise_distance": 56.0,
		"intro_duration": 0.12,
		"hold_duration": 0.30,
		"fade_duration": 0.40,
	}
	_emit_floating_text(pos, value, color, options)

func _request_status_text(pos: Vector2, value: String, color: Color) -> void:
	var now: float = _now_seconds()
	var cluster_index: int = _find_status_cluster_index(value, pos, now)
	if cluster_index >= 0:
		var existing: Dictionary = _pending_status_clusters[cluster_index]
		var positions: Array = existing.get("positions", [])
		positions.append(pos)
		existing["positions"] = positions
		existing["color"] = color
		_pending_status_clusters[cluster_index] = existing
		return
	if _active_status_text_count + _pending_status_clusters.size() >= MAX_STATUS_TEXTS:
		return
	_pending_status_clusters.append({
		"value": value,
		"positions": [pos],
		"color": color,
		"expires_at": now + STATUS_CLUSTER_WINDOW,
	})

func _flush_status_cluster(cluster: Dictionary) -> void:
	var positions: Array = cluster.get("positions", [])
	if positions.is_empty():
		return
	if _active_status_text_count >= MAX_STATUS_TEXTS:
		return
	var center: Vector2 = _average_positions(positions)
	var merged_count: int = positions.size()
	var color: Color = cluster.get("color", Color.WHITE)
	var options := {
		"is_status_text": true,
		"scale_mult": clamp(1.10 + 0.18 * float(max(0, merged_count - 1)), 1.10, 2.20),
		"spread_x": 42.0,
		"rise_distance": 44.0,
		"intro_duration": 0.14,
		"hold_duration": 0.28,
		"fade_duration": 0.45,
	}
	_emit_floating_text(center, str(cluster.get("value", "")), color, options)
	if merged_count > 1:
		_spawn_status_burst(center, color, merged_count)
		if Global != null:
			Global.on_camera_shake.emit(min(5.0, 1.6 + 0.22 * float(merged_count)), 0.05)

func _emit_floating_text(pos: Vector2, value: String, color: Color, options: Dictionary) -> void:
	var text_node: FloatingText = _acquire_text()
	if text_node == null:
		return
	var metadata := {
		"is_status_text": bool(options.get("is_status_text", false)),
	}
	_active_metadata[text_node] = metadata
	if metadata["is_status_text"]:
		_active_status_text_count += 1
	text_node.global_position = pos
	text_node.show()
	text_node.setup(value, color, options, Callable(self, "_release_text").bind(text_node))

func _acquire_text() -> FloatingText:
	if _pool.is_empty():
		_expand_pool(max(10, INITIAL_POOL_SIZE / 2))
	if _pool.is_empty():
		return null
	var text_node: FloatingText = _pool.pop_back()
	if text_node.get_parent() != self:
		add_child(text_node)
	return text_node

func _release_text(text_node: FloatingText) -> void:
	if text_node == null:
		return
	var metadata: Dictionary = _active_metadata.get(text_node, {})
	if bool(metadata.get("is_status_text", false)):
		_active_status_text_count = max(0, _active_status_text_count - 1)
	_active_metadata.erase(text_node)
	text_node.reset_for_pool()
	if text_node.get_parent() != self:
		add_child(text_node)
	_pool.append(text_node)

func _expand_pool(count: int) -> void:
	if _floating_text_scene == null or count <= 0:
		return
	for _i in range(count):
		var text_node := _floating_text_scene.instantiate() as FloatingText
		if text_node == null:
			continue
		add_child(text_node)
		text_node.reset_for_pool()
		_pool.append(text_node)

func _find_status_cluster_index(value: String, pos: Vector2, now: float) -> int:
	for i in range(_pending_status_clusters.size()):
		var cluster: Dictionary = _pending_status_clusters[i]
		if str(cluster.get("value", "")) != value:
			continue
		if now > float(cluster.get("expires_at", 0.0)):
			continue
		var cluster_center: Vector2 = _average_positions(cluster.get("positions", []))
		if cluster_center.distance_to(pos) <= STATUS_CLUSTER_RADIUS:
			return i
	return -1

func _average_positions(positions: Array) -> Vector2:
	if positions.is_empty():
		return Vector2.ZERO
	var total := Vector2.ZERO
	var count: int = 0
	for entry in positions:
		if entry is Vector2:
			total += entry
			count += 1
	if count <= 0:
		return Vector2.ZERO
	return total / float(count)

func _is_numeric_damage_text(value: String) -> bool:
	if value.is_empty():
		return false
	var has_digit: bool = false
	for i in range(value.length()):
		var ch: String = value.substr(i, 1)
		var code: int = ch.unicode_at(0)
		var is_digit: bool = code >= 48 and code <= 57
		if is_digit:
			has_digit = true
			continue
		if ch == "x" or ch == "X" or ch == "+" or ch == "-" or ch == "!" or ch == "." or ch == "," or ch == " ":
			continue
		return false
	return has_digit

func _extract_last_number(value: String) -> int:
	var current_number: String = ""
	var last_number: String = ""
	for i in range(value.length()):
		var ch: String = value.substr(i, 1)
		var code: int = ch.unicode_at(0)
		if code >= 48 and code <= 57:
			current_number += ch
			continue
		if not current_number.is_empty():
			last_number = current_number
			current_number = ""
	if not current_number.is_empty():
		last_number = current_number
	return int(last_number) if not last_number.is_empty() else 0

func _should_cull_low_damage(damage_amount: int, color: Color) -> bool:
	if not _is_white_or_gray(color):
		return false
	var threshold: float = max(3.0, _get_damage_baseline() * 0.10)
	if float(damage_amount) >= threshold:
		return false
	return randf() > LOW_DAMAGE_SHOW_CHANCE

func _compute_damage_scale(value: String, color: Color, damage_amount: int, baseline: float) -> float:
	var scale_mult: float = 1.0
	if damage_amount > 0:
		var ratio: float = float(damage_amount) / max(1.0, baseline)
		scale_mult += clamp(ratio * 0.18, 0.0, 0.90)
	if value.find("!!!") >= 0:
		scale_mult += 0.55
	elif value.find("!!") >= 0:
		scale_mult += 0.35
	elif value.find("!") >= 0:
		scale_mult += 0.18
	if not _is_white_or_gray(color):
		scale_mult += 0.12
	return clamp(scale_mult, 1.0, 2.40)

func _is_white_or_gray(color: Color) -> bool:
	var max_channel: float = max(color.r, max(color.g, color.b))
	var min_channel: float = min(color.r, min(color.g, color.b))
	if max_channel <= 0.0:
		return false
	var saturation: float = (max_channel - min_channel) / max_channel
	return max_channel >= 0.75 and saturation <= 0.25

func _get_damage_baseline() -> float:
	if Global != null and is_instance_valid(Global.player) and "damage" in Global.player:
		return max(1.0, float(Global.player.damage))
	return 20.0

func _spawn_status_burst(center: Vector2, color: Color, merged_count: int) -> void:
	var root := Node2D.new()
	root.global_position = center
	root.z_index = 9
	add_child(root)

	var ring := Line2D.new()
	ring.width = 3.0
	ring.default_color = Color(color.r, color.g, color.b, 0.95)
	ring.closed = true
	ring.points = _build_circle_points(26.0 + min(14.0, 2.5 * float(merged_count)))
	root.add_child(ring)

	var fill := Polygon2D.new()
	fill.color = Color(color.r, color.g, color.b, 0.14)
	fill.polygon = _build_circle_points(18.0 + min(10.0, 2.0 * float(merged_count)))
	root.add_child(fill)

	root.scale = Vector2(0.7, 0.7)
	var tween := create_tween()
	tween.parallel().tween_property(root, "scale", Vector2.ONE * (1.25 + min(0.40, 0.05 * float(merged_count))), 0.18)
	tween.parallel().tween_property(root, "modulate:a", 0.0, 0.28)
	tween.finished.connect(root.queue_free)

func _build_circle_points(radius: float, segments: int = 20) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in range(segments):
		var ratio: float = float(i) / float(segments)
		var angle: float = TAU * ratio
		points.append(Vector2.RIGHT.rotated(angle) * radius)
	return points

func _now_seconds() -> float:
	return float(Time.get_ticks_msec()) / 1000.0
