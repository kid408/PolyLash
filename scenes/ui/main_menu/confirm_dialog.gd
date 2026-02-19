extends CanvasLayer
class_name ConfirmDialog
## 通用二次确认弹窗，支持自定义文本和回调

signal confirmed
signal cancelled

@onready var overlay: ColorRect = $Overlay
@onready var panel: PanelContainer = $Panel
@onready var message_label: Label = $Panel/MarginContainer/VBoxContainer/MessageLabel
@onready var confirm_button: Button = $Panel/MarginContainer/VBoxContainer/ButtonContainer/ConfirmButton
@onready var cancel_button: Button = $Panel/MarginContainer/VBoxContainer/ButtonContainer/CancelButton

var is_visible_dialog: bool = false
var _on_confirm_callback: Callable = Callable()

func _ready() -> void:
	# 暂停时仍可交互
	process_mode = PROCESS_MODE_ALWAYS
	confirm_button.pressed.connect(_on_confirm_pressed)
	cancel_button.pressed.connect(_on_cancel_pressed)
	hide()

## 显示对话框，text 为提示文本，on_confirm 为确认后的回调
func show_dialog(text: String, on_confirm: Callable = Callable()) -> void:
	message_label.text = text
	_on_confirm_callback = on_confirm
	show()
	is_visible_dialog = true
	# 默认聚焦取消按钮，防止误操作
	cancel_button.grab_focus()

func _on_confirm_pressed() -> void:
	if not is_visible_dialog:
		return
	SoundManager.play("ui_click")
	# 先保存回调引用，再关闭（_close 会重置回调）
	var callback := _on_confirm_callback
	_close()
	confirmed.emit()
	if callback.is_valid():
		callback.call()

func _on_cancel_pressed() -> void:
	if not is_visible_dialog:
		return
	SoundManager.play("ui_click")
	_close()
	cancelled.emit()

func _close() -> void:
	is_visible_dialog = false
	_on_confirm_callback = Callable()
	hide()

func _input(event: InputEvent) -> void:
	if not is_visible_dialog:
		return
	# ESC 键取消
	if event.is_action_pressed("ui_cancel"):
		_on_cancel_pressed()
		get_viewport().set_input_as_handled()
