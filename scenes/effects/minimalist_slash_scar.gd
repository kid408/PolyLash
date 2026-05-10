extends Node2D
class_name MinimalistSlashScar

@export var lifetime: float = 4.0

@onready var main_line: Line2D = $MainLine
@onready var glow_line: Line2D = $GlowLine
@onready var life_timer: Timer = $LifeTimer

var _path_points: PackedVector2Array = PackedVector2Array()
var _cached_length: float = 0.0
var _effect_half_width: float = 80.0

func _ready() -> void:
	add_to_group("player_skill_effects")
	add_to_group("minimalist_slash_scar")
	add_to_group("player_summoned_entity")
	set_meta("logic_tags", PackedStringArray(["高热", "金属"]))
	_refresh_visuals()
	_restart_lifetime_timer()

func setup(points: PackedVector2Array, duration: float = 4.0, effect_half_width: float = 80.0) -> void:
	_path_points = points.duplicate()
	lifetime = duration
	_effect_half_width = effect_half_width
	_cached_length = _compute_path_length(_path_points)
	_refresh_visuals()
	_restart_lifetime_timer()

func get_path_points() -> PackedVector2Array:
	return _path_points.duplicate()

func get_total_length() -> float:
	return _cached_length

func get_effect_half_width() -> float:
	return _effect_half_width

func get_end_point() -> Vector2:
	if _path_points.is_empty():
		return global_position
	return _path_points[_path_points.size() - 1]

func get_nearest_point(target: Vector2) -> Vector2:
	if _path_points.size() < 2:
		return get_end_point()
	var best_point: Vector2 = _path_points[0]
	var best_distance: float = INF
	for i in range(_path_points.size() - 1):
		var a: Vector2 = _path_points[i]
		var b: Vector2 = _path_points[i + 1]
		var closest: Vector2 = Geometry2D.get_closest_point_to_segment(target, a, b)
		var distance_sq: float = target.distance_squared_to(closest)
		if distance_sq < best_distance:
			best_distance = distance_sq
			best_point = closest
	return best_point

func sample_points_along_path(step: float) -> PackedVector2Array:
	var samples: PackedVector2Array = PackedVector2Array()
	if _path_points.is_empty():
		return samples
	if _path_points.size() == 1 or step <= 0.0:
		return _path_points.duplicate()

	samples.append(_path_points[0])
	var carry: float = step
	for i in range(_path_points.size() - 1):
		var start: Vector2 = _path_points[i]
		var finish: Vector2 = _path_points[i + 1]
		var segment: Vector2 = finish - start
		var segment_length: float = segment.length()
		if segment_length <= 0.001:
			continue
		var direction: Vector2 = segment / segment_length
		var traveled: float = carry
		while traveled < segment_length:
			samples.append(start + direction * traveled)
			traveled += step
		carry = traveled - segment_length
		if carry <= 0.001:
			carry = step

	var end_point: Vector2 = _path_points[_path_points.size() - 1]
	if samples.is_empty() or samples[samples.size() - 1].distance_to(end_point) > 1.0:
		samples.append(end_point)
	return samples

func _restart_lifetime_timer() -> void:
	if not is_inside_tree() or not is_instance_valid(life_timer):
		return
	life_timer.stop()
	life_timer.wait_time = lifetime
	life_timer.start()

func _refresh_visuals() -> void:
	if is_instance_valid(main_line):
		main_line.z_index = 34
		main_line.points = _path_points
	if is_instance_valid(glow_line):
		glow_line.z_index = 33
		glow_line.points = _path_points

func _compute_path_length(points: PackedVector2Array) -> float:
	var total: float = 0.0
	for i in range(points.size() - 1):
		total += points[i].distance_to(points[i + 1])
	return total

func _on_life_timer_timeout() -> void:
	var tween: Tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(main_line, "modulate:a", 0.0, 0.35)
	tween.tween_property(glow_line, "modulate:a", 0.0, 0.35)
	tween.finished.connect(queue_free)
