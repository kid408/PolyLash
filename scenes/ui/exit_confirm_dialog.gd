extends CanvasLayer
class_name ExitConfirmDialog

signal confirmed
signal cancelled

@onready var yes_button = $Panel/VBoxContainer/HBoxContainer/YesButton
@onready var no_button = $Panel/VBoxContainer/HBoxContainer/NoButton

var is_visible_dialog: bool = false

func _ready() -> void:
	print("[ExitConfirmDialog] _ready() called")
	# 设置process_mode，使其在暂停时仍能处理输入
	process_mode = PROCESS_MODE_ALWAYS
	yes_button.pressed.connect(_on_yes_pressed)
	no_button.pressed.connect(_on_no_pressed)
	hide()

func show_dialog() -> void:
	print("[ExitConfirmDialog] show_dialog() called")
	show()
	is_visible_dialog = true
	SoundManager.play("ui_pause")
	# 暂停游戏
	get_tree().paused = true

func _on_yes_pressed() -> void:
	print("[ExitConfirmDialog] Yes button pressed")
	if not is_visible_dialog:
		return
	SoundManager.play("ui_click")
	# 恢复游戏
	get_tree().paused = false
	confirmed.emit()
	hide()
	is_visible_dialog = false

func _on_no_pressed() -> void:
	print("[ExitConfirmDialog] No button pressed")
	if not is_visible_dialog:
		return
	SoundManager.play("ui_resume")
	# 恢复游戏
	get_tree().paused = false
	cancelled.emit()
	hide()
	is_visible_dialog = false

func _input(event: InputEvent) -> void:
	if not is_visible_dialog:
		return
	
	# 按Enter确认
	if event.is_action_pressed("ui_accept"):
		_on_yes_pressed()
		get_viewport().set_input_as_handled()
	# 按ESC取消
	elif event.is_action_pressed("ui_cancel"):
		_on_no_pressed()
		get_viewport().set_input_as_handled()
