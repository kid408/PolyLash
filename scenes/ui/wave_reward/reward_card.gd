extends PanelContainer
class_name RewardCard

signal card_pressed(index: int)

var card_index: int = -1
var reward_data: Dictionary = {}

@onready var type_label: Label = %TypeLabel
@onready var name_label: Label = %NameLabel
@onready var icon_rect: TextureRect = %IconRect
@onready var desc_label: Label = %DescLabel
@onready var select_button: Button = %SelectButton

var _is_affordable: bool = true

func _ready() -> void:
	if not select_button.pressed.is_connected(_on_select_pressed):
		select_button.pressed.connect(_on_select_pressed)

func setup(index: int, data: Dictionary) -> void:
	card_index = index
	reward_data = data

	if not is_node_ready():
		await ready

	name_label.text = str(data.get("display_name", "Unknown Reward"))
	desc_label.text = str(data.get("description", ""))
	_is_affordable = bool(data.get("affordable", true))

	var icon_path: String = str(data.get("icon_path", ""))
	if is_instance_valid(icon_rect):
		icon_rect.texture = null
		icon_rect.visible = false
		if not icon_path.is_empty() and FileAccess.file_exists(icon_path):
			var texture := load(icon_path) as Texture2D
			if texture != null:
				icon_rect.texture = texture
				icon_rect.visible = true

	var reward_type: String = str(data.get("type", ""))
	var locked_source: bool = bool(data.get("locked_source", false))
	match reward_type:
		"recruit":
			type_label.text = "[Recruit*]" if locked_source else "[Recruit]"
			type_label.add_theme_color_override("font_color", Color(0.5, 1.0, 0.7))
		"recruit_replace":
			type_label.text = "[Swap*]" if locked_source else "[Swap]"
			type_label.add_theme_color_override("font_color", Color(0.5, 0.95, 0.85))
		"recruit_lock":
			type_label.text = "[Lock]"
			type_label.add_theme_color_override("font_color", Color(0.7, 0.85, 1.0))
		"solo_bonus":
			type_label.text = "[Solo]"
			type_label.add_theme_color_override("font_color", Color(0.85, 0.95, 0.55))
		"artifact":
			type_label.text = "[Artifact]"
			type_label.add_theme_color_override("font_color", Color(0.4, 0.8, 1.0))
		"equipment":
			type_label.text = "[Gear]"
			type_label.add_theme_color_override("font_color", Color(1.0, 0.8, 0.3))
		"attribute_boost":
			type_label.text = "[Attr]"
			type_label.add_theme_color_override("font_color", Color(0.7, 0.95, 1.0))
		"gold":
			type_label.text = "[Gold]"
			type_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.4))
		_:
			type_label.text = "[Reward]"
			type_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))

	if is_instance_valid(select_button):
		select_button.text = "金币不足" if not _is_affordable else "选择"
	if not _is_affordable:
		modulate = Color(0.72, 0.72, 0.72, 1.0)
	else:
		modulate = Color(1.0, 1.0, 1.0, 1.0)

func _on_select_pressed() -> void:
	SoundManager.play("ui_click")
	card_pressed.emit(card_index)

func set_selectable(enabled: bool) -> void:
	if is_instance_valid(select_button):
		select_button.disabled = (not enabled) or (not _is_affordable)
