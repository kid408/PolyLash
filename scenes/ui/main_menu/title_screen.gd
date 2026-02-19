extends Control
## 标题界面 - 显示游戏 Logo、闪烁提示文本和背景几何线条动画
## 按任意键触发过渡动画并发出 any_key_pressed 信号

signal any_key_pressed

@onready var logo: TextureRect = $Logo
@onready var prompt_label: Label = $PromptLabel
@onready var bg_lines: Node2D = $BackgroundLines

# 闪烁控制
var _blink_tween: Tween = null
var _input_enabled: bool = true

# 背景线条数据
var _lines: Array[Dictionary] = []
const LINE_COUNT := 8
const LINE_COLOR := Color(0.298, 0.686, 0.314, 0.2)  # #4CAF50 at 20% opacity
const LINE_SPEED_MIN := 10.0
const LINE_SPEED_MAX := 20.0

func _ready() -> void:
	_start_blink_animation()
	_init_background_lines()

func _process(delta: float) -> void:
	_update_background_lines(delta)
	bg_lines.queue_redraw()

func _input(event: InputEvent) -> void:
	if not _input_enabled:
		return
	if event is InputEventKey or event is InputEventMouseButton:
		if event.pressed:
			_input_enabled = false
			_stop_blink()
			any_key_pressed.emit()

# --- 闪烁动画 ---

func _start_blink_animation() -> void:
	# 1秒周期闪烁：0.5秒淡出 + 0.5秒淡入
	_blink_tween = create_tween().set_loops()
	_blink_tween.tween_property(prompt_label, "modulate:a", 0.0, 0.5)
	_blink_tween.tween_property(prompt_label, "modulate:a", 1.0, 0.5)

func _stop_blink() -> void:
	if _blink_tween:
		_blink_tween.kill()
		_blink_tween = null
	prompt_label.modulate.a = 0.0

# --- 背景几何线条 ---

func _init_background_lines() -> void:
	var viewport_size := get_viewport_rect().size
	for i in LINE_COUNT:
		var line_data := {
			"points": _generate_line_points(viewport_size),
			"speed": randf_range(LINE_SPEED_MIN, LINE_SPEED_MAX),
			"offset": 0.0,
			"direction": Vector2(randf_range(-1.0, 1.0), randf_range(-0.5, 0.5)).normalized()
		}
		_lines.append(line_data)

func _generate_line_points(viewport_size: Vector2) -> PackedVector2Array:
	# 生成3-6个点的折线段
	var points := PackedVector2Array()
	var num_points := randi_range(3, 6)
	var start_x := randf_range(0, viewport_size.x)
	var start_y := randf_range(0, viewport_size.y)
	points.append(Vector2(start_x, start_y))
	for j in range(1, num_points):
		var prev := points[j - 1]
		var next_x := prev.x + randf_range(-300, 300)
		var next_y := prev.y + randf_range(-200, 200)
		points.append(Vector2(next_x, next_y))
	return points

func _update_background_lines(delta: float) -> void:
	var viewport_size := get_viewport_rect().size
	for line_data in _lines:
		line_data["offset"] += line_data["speed"] * delta
		# 当线条完全移出屏幕时重新生成
		if line_data["offset"] > viewport_size.x:
			line_data["points"] = _generate_line_points(viewport_size)
			line_data["offset"] = 0.0
			line_data["direction"] = Vector2(randf_range(-1.0, 1.0), randf_range(-0.5, 0.5)).normalized()

# BackgroundLines 节点的绘制回调（通过脚本连接）
func _draw_lines() -> void:
	for line_data in _lines:
		var offset_vec: Vector2 = line_data["direction"] * line_data["offset"]
		var points: PackedVector2Array = line_data["points"]
		var shifted_points := PackedVector2Array()
		for p in points:
			shifted_points.append(p + offset_vec)
		if shifted_points.size() >= 2:
			bg_lines.draw_polyline(shifted_points, LINE_COLOR, 1.5, true)

# --- 过渡动画 ---

func play_transition_out() -> void:
	# Logo 上移至屏幕顶部并缩小至40%，0.5秒
	_stop_blink()
	_input_enabled = false

	var tween := create_tween().set_parallel(true)

	# Logo 上移到顶部居中位置（y约60px）并缩小
	tween.tween_property(logo, "position:y", 30.0, 0.5).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(logo, "scale", Vector2(0.4, 0.4), 0.5).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_CUBIC)

	# 提示文本淡出
	tween.tween_property(prompt_label, "modulate:a", 0.0, 0.2)

	# 背景线条淡出
	tween.tween_property(bg_lines, "modulate:a", 0.0, 0.3)

	await tween.finished
