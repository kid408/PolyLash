extends PanelContainer
class_name RewardCard

signal card_pressed(index: int)

var card_index: int = -1
var reward_data: Dictionary = {}

@onready var type_label: Label = %TypeLabel
@onready var name_label: Label = %NameLabel
@onready var desc_label: Label = %DescLabel
@onready var select_button: Button = %SelectButton

func _ready() -> void:
	if not select_button.pressed.is_connected(_on_select_pressed):
		select_button.pressed.connect(_on_select_pressed)

func setup(index: int, data: Dictionary) -> void:
	card_index = index
	reward_data = data

	if not is_node_ready():
		await ready

	name_label.text = str(data.get("display_name", "未知奖励"))
	desc_label.text = str(data.get("description", ""))

	var reward_type := str(data.get("type", ""))
	match reward_type:
		"artifact":
			type_label.text = "[护符]"
			type_label.add_theme_color_override("font_color", Color(0.4, 0.8, 1.0))
		"equipment":
			type_label.text = "[装备]"
			type_label.add_theme_color_override("font_color", Color(1.0, 0.8, 0.3))
		"gold":
			type_label.text = "[金币]"
			type_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.4))
		_:
			type_label.text = "[奖励]"
			type_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))

func _on_select_pressed() -> void:
	SoundManager.play("ui_click")
	card_pressed.emit(card_index)
