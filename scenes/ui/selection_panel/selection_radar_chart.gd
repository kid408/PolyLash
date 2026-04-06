extends Control
class_name SelectionRadarChart

const AXIS_LABELS: PackedStringArray = [
	"生命",
	"速度",
	"能量上限",
	"回蓝",
	"爆发",
	"控制",
]

var _values: PackedFloat32Array = PackedFloat32Array([0.55, 0.55, 0.55, 0.55, 0.55, 0.55])
var _grid_color: Color = Color("30363D")
var _accent_color: Color = Color("00F0FF")
var _fill_color: Color = Color(0.0, 0.94, 1.0, 0.35)
var _text_color: Color = Color("E6EDF3")

func set_palette(grid_color: Color, accent_color: Color, fill_color: Color, text_color: Color) -> void:
	_grid_color = grid_color
	_accent_color = accent_color
	_fill_color = fill_color
	_text_color = text_color
	queue_redraw()

func set_values(values: Array) -> void:
	if values.size() != AXIS_LABELS.size():
		return
	_values.clear()
	for value in values:
		_values.append(clampf(float(value), 0.0, 1.0))
	queue_redraw()

func _draw() -> void:
	var center: Vector2 = size * 0.5
	var radius: float = min(size.x, size.y) * 0.34
	var font: Font = get_theme_default_font()
	var font_size: int = 14

	for ring in range(1, 5):
		var ring_ratio := float(ring) / 4.0
		var ring_points := _build_polygon(center, radius * ring_ratio)
		ring_points.append(ring_points[0])
		draw_polyline(ring_points, _grid_color, 1.2, true)

	var data_points := PackedVector2Array()
	for i in range(AXIS_LABELS.size()):
		var direction := _axis_direction(i)
		var endpoint: Vector2 = center + direction * radius
		draw_line(center, endpoint, _grid_color, 1.0, true)
		data_points.append(center + direction * radius * _values[i])

		if font != null:
			var label := AXIS_LABELS[i]
			var label_size := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
			var label_position: Vector2 = center + direction * (radius + 28.0)
			label_position -= label_size * 0.5
			draw_string(font, label_position + Vector2(0.0, label_size.y), label, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, _text_color)

	data_points.append(data_points[0])
	draw_colored_polygon(data_points.slice(0, data_points.size() - 1), _fill_color)
	draw_polyline(data_points, _accent_color, 2.4, true)

	for i in range(data_points.size() - 1):
		draw_circle(data_points[i], 3.0, _accent_color)

func _build_polygon(center: Vector2, radius: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in range(AXIS_LABELS.size()):
		points.append(center + _axis_direction(i) * radius)
	return points

func _axis_direction(index: int) -> Vector2:
	var angle := -PI / 2.0 + TAU * float(index) / float(AXIS_LABELS.size())
	return Vector2.RIGHT.rotated(angle)
