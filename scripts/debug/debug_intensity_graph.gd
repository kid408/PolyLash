extends Control
class_name DebugIntensityGraph

const GRID_COLOR: Color = Color(0.19, 0.24, 0.31, 0.75)
const FILL_COLOR: Color = Color(0.0, 0.94, 1.0, 0.18)
const PEAK_COLOR: Color = Color(1.0, 0.32, 0.36, 0.55)
const IDLE_COLOR: Color = Color(0.42, 1.0, 0.58, 0.40)
const LOW_COLOR: Color = Color(0.42, 1.0, 0.58, 0.95)
const MID_COLOR: Color = Color(1.0, 0.82, 0.28, 0.95)
const HIGH_COLOR: Color = Color(1.0, 0.35, 0.35, 0.98)
const POINT_GLOW_COLOR: Color = Color(1.0, 1.0, 1.0, 0.22)
const WAVE_MARKER_COLOR: Color = Color(0.92, 0.96, 1.0, 0.26)

var _samples: Array[Dictionary] = []

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func set_scores(scores: Array[float]) -> void:
	_samples.clear()
	for score: float in scores:
		_samples.append({
			"score": score,
			"wave": -1,
		})
	queue_redraw()

func set_samples(samples: Array[Dictionary]) -> void:
	_samples = samples.duplicate(true)
	queue_redraw()

func _draw() -> void:
	var rect: Rect2 = Rect2(Vector2.ZERO, size)
	if rect.size.x <= 4.0 or rect.size.y <= 4.0:
		return

	draw_rect(rect, Color(0.03, 0.05, 0.07, 0.55), true)
	_draw_grid(rect)
	_draw_threshold(rect, 75.0, PEAK_COLOR)
	_draw_threshold(rect, 15.0, IDLE_COLOR)
	if _samples.size() < 2:
		return
	_draw_curve(rect)

func _draw_grid(rect: Rect2) -> void:
	for i in range(1, 4):
		var y: float = rect.position.y + rect.size.y * float(i) / 4.0
		draw_line(Vector2(rect.position.x, y), Vector2(rect.end.x, y), GRID_COLOR, 1.0)
	for i in range(1, 6):
		var x: float = rect.position.x + rect.size.x * float(i) / 6.0
		draw_line(Vector2(x, rect.position.y), Vector2(x, rect.end.y), GRID_COLOR, 1.0)

func _draw_threshold(rect: Rect2, score: float, color: Color) -> void:
	var y: float = rect.end.y - clamp(score / 100.0, 0.0, 1.0) * rect.size.y
	draw_line(Vector2(rect.position.x, y), Vector2(rect.end.x, y), color, 1.0)

func _draw_curve(rect: Rect2) -> void:
	var points: PackedVector2Array = PackedVector2Array()
	var scores: Array[float] = _extract_scores()
	var count: int = scores.size()
	for i in range(count):
		var t: float = float(i) / float(max(1, count - 1))
		var x: float = rect.position.x + rect.size.x * t
		var y: float = rect.end.y - clamp(scores[i] / 100.0, 0.0, 1.0) * rect.size.y
		points.append(Vector2(x, y))

	_draw_wave_markers(rect, points)

	var fill_points: PackedVector2Array = PackedVector2Array()
	fill_points.append(Vector2(rect.position.x, rect.end.y))
	for point: Vector2 in points:
		fill_points.append(point)
	fill_points.append(Vector2(rect.end.x, rect.end.y))
	draw_colored_polygon(fill_points, FILL_COLOR)
	for i in range(points.size() - 1):
		var segment_color: Color = _get_score_color(max(scores[i], scores[i + 1]))
		draw_line(points[i], points[i + 1], segment_color, 2.5, true)
	var latest_point: Vector2 = points[points.size() - 1]
	var latest_color: Color = _get_score_color(scores[scores.size() - 1])
	draw_circle(latest_point, 5.5, POINT_GLOW_COLOR)
	draw_circle(latest_point, 3.0, latest_color)
	_draw_peak_markers(points, scores)

func _extract_scores() -> Array[float]:
	var scores: Array[float] = []
	for sample: Dictionary in _samples:
		scores.append(float(sample.get("score", 0.0)))
	return scores

func _draw_wave_markers(rect: Rect2, points: PackedVector2Array) -> void:
	for i in range(1, _samples.size()):
		var prev_wave: int = int(_samples[i - 1].get("wave", -1))
		var next_wave: int = int(_samples[i].get("wave", -1))
		if prev_wave < 0 or next_wave < 0 or prev_wave == next_wave:
			continue
		var x: float = points[i].x
		draw_line(Vector2(x, rect.position.y), Vector2(x, rect.end.y), WAVE_MARKER_COLOR, 1.0)

func _draw_peak_markers(points: PackedVector2Array, scores: Array[float]) -> void:
	for i in range(1, scores.size() - 1):
		var score: float = scores[i]
		if score < 75.0:
			continue
		if score < scores[i - 1] or score < scores[i + 1]:
			continue
		draw_circle(points[i], 3.8, POINT_GLOW_COLOR)
		draw_circle(points[i], 2.2, HIGH_COLOR)

func _get_score_color(score: float) -> Color:
	if score >= 70.0:
		return HIGH_COLOR
	if score >= 30.0:
		return MID_COLOR
	return LOW_COLOR
