extends Button
## 主菜单按钮预制体 - 支持 Default / Hover / Pressed 三种视觉状态
## 悬停：Scale 1.05 + 文字变色 #4CAF50 + 播放 ui_hover
## 按下：Y+2px 下沉 + 播放 ui_click

# 按钮动作标识符，由外部设置
@export var action_id: String = ""

# 信号：按下时发出动作标识
signal button_action(action: String)

# 颜色常量
const COLOR_DEFAULT := Color("#FFFFFF")
const COLOR_HOVER := Color("#4CAF50")

# 动画时长
const HOVER_DURATION := 0.15
const PRESS_DURATION := 0.1

# 内部状态
var _hover_tween: Tween = null
var _press_tween: Tween = null

func _ready() -> void:
	# 设置按钮为纯文本样式（无背景）
	flat = true

	# 连接信号
	mouse_entered.connect(_on_hover_enter)
	mouse_exited.connect(_on_hover_exit)
	pressed.connect(_on_pressed)
	button_down.connect(_on_button_down)
	button_up.connect(_on_button_up)

	# 初始状态
	pivot_offset = size / 2.0
	add_theme_color_override("font_color", COLOR_DEFAULT)
	add_theme_color_override("font_hover_color", COLOR_HOVER)
	add_theme_color_override("font_pressed_color", COLOR_HOVER)
	add_theme_color_override("font_focus_color", COLOR_DEFAULT)

# --- 悬停状态 ---

func _on_hover_enter() -> void:
	_kill_hover_tween()
	_hover_tween = create_tween().set_parallel(true)
	# 缩放到 1.05
	_hover_tween.tween_property(self, "scale", Vector2(1.05, 1.05), HOVER_DURATION) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	# 文字变色
	_hover_tween.tween_property(self, "theme_override_colors/font_color", COLOR_HOVER, HOVER_DURATION)
	# 播放悬停音效
	SoundManager.play("ui_hover")

func _on_hover_exit() -> void:
	_kill_hover_tween()
	_hover_tween = create_tween().set_parallel(true)
	# 恢复缩放
	_hover_tween.tween_property(self, "scale", Vector2.ONE, HOVER_DURATION) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	# 恢复文字颜色
	_hover_tween.tween_property(self, "theme_override_colors/font_color", COLOR_DEFAULT, HOVER_DURATION)

# --- 按下状态 ---

func _on_button_down() -> void:
	_kill_press_tween()
	_press_tween = create_tween()
	# 缩放略微缩小表示按下
	_press_tween.tween_property(self, "scale", Vector2(0.98, 0.98), PRESS_DURATION) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)

func _on_button_up() -> void:
	_kill_press_tween()
	_press_tween = create_tween()
	# 恢复到当前悬停缩放（如果正在悬停则为 1.05，否则为 1.0）
	var target_scale := Vector2(1.05, 1.05) if is_hovered() else Vector2.ONE
	_press_tween.tween_property(self, "scale", target_scale, PRESS_DURATION) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)

func _on_pressed() -> void:
	# 播放点击音效
	SoundManager.play("ui_click")
	# 发出动作信号
	button_action.emit(action_id)

# --- 工具方法 ---

func _kill_hover_tween() -> void:
	if _hover_tween:
		_hover_tween.kill()
		_hover_tween = null

func _kill_press_tween() -> void:
	if _press_tween:
		_press_tween.kill()
		_press_tween = null

## 外部调用：设置按钮文本和动作标识
func setup(label_text: String, action: String) -> void:
	text = label_text
	action_id = action
