extends CanvasLayer
class_name UpgradeSelectionUI

# ============================================================================
# 升级选择UI - 显示3个随机属性供玩家选择
# ============================================================================

signal upgrade_selected(attribute_id: String)

var available_upgrades: Array[Dictionary] = []
var chest_tier: int = 1

@onready var panel: Panel = $Panel
@onready var title_label: Label = $Panel/TitleLabel
@onready var option1_button: Button = $Panel/VBoxContainer/Option1
@onready var option2_button: Button = $Panel/VBoxContainer/Option2
@onready var option3_button: Button = $Panel/VBoxContainer/Option3

func _ready() -> void:
	# 初始隐藏
	visible = false
	
	# 连接按钮信号
	option1_button.pressed.connect(_on_option_selected.bind(0))
	option2_button.pressed.connect(_on_option_selected.bind(1))
	option3_button.pressed.connect(_on_option_selected.bind(2))

func _process(_delta: float) -> void:
	if not visible:
		return
	
	# 键盘快捷键
	if Input.is_action_just_pressed("ui_accept") or Input.is_key_pressed(KEY_1):
		_on_option_selected(0)
	elif Input.is_key_pressed(KEY_2):
		_on_option_selected(1)
	elif Input.is_key_pressed(KEY_3):
		_on_option_selected(2)

func show_upgrades(tier: int) -> void:
	print("[UpgradeSelectionUI] show_upgrades called with tier: %d" % tier)
	chest_tier = tier
	
	# 生成随机属性
	available_upgrades = UpgradeManager.generate_random_attributes(3, tier)
	
	print("[UpgradeSelectionUI] Generated %d upgrades" % available_upgrades.size())
	
	if available_upgrades.size() == 0:
		printerr("[UpgradeSelectionUI] 没有可用的升级属性")
		hide_ui()
		return
	
	# 更新UI
	title_label.text = "选择升级 (等级 %d 宝箱)" % tier
	
	_update_button(option1_button, 0)
	_update_button(option2_button, 1)
	_update_button(option3_button, 2)
	
	# 显示UI
	visible = true
	Global.game_paused = true
	
	print("[UpgradeSelectionUI] UI shown, game paused")

func _update_button(button: Button, index: int) -> void:
	if index >= available_upgrades.size():
		button.visible = false
		return
	
	button.visible = true
	var upgrade = available_upgrades[index]
	
	var display_name = upgrade.get("display_name", "未知")
	var description = upgrade.get("description", "")
	var upgrade_value = upgrade.get("upgrade_value", 0)
	var value_type = upgrade.get("value_type", "flat")
	var current_level = upgrade.get("current_level", 0)
	
	# 格式化数值显示
	var value_str = ""
	if value_type == "percent":
		value_str = "+%d%%" % upgrade_value
	else:
		value_str = "+%d" % upgrade_value
	
	button.text = "%s %s\n%s\n(等级: %d)" % [display_name, value_str, description, current_level]

func _on_option_selected(index: int) -> void:
	if index >= available_upgrades.size():
		return
	
	var selected = available_upgrades[index]
	var attribute_id = selected.get("attribute_id", "")
	
	if attribute_id == "":
		return
	
	print("[UpgradeSelectionUI] 选择了属性: %s" % attribute_id)
	
	# 应用升级
	var result = UpgradeManager.apply_upgrade(attribute_id, chest_tier)
	print("[UpgradeSelectionUI] 升级结果: %s" % str(result))
	
	# 发送信号
	upgrade_selected.emit(attribute_id)
	
	# 隐藏UI
	hide_ui()
	
	print("[UpgradeSelectionUI] UI已隐藏，游戏继续")

func hide_ui() -> void:
	visible = false
	Global.game_paused = false
	available_upgrades.clear()
