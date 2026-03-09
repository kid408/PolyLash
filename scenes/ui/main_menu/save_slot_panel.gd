extends Control
## 存档槽位面板
## 支持 "new_game"（新游戏选择槽位）和 "load"（加载存档）两种模式
## 动态创建3个 SaveSlotCard，处理点击/删除逻辑，通过信号与 MainMenuRoot 通信

signal slot_selected(slot_index: int)
signal back_pressed

var mode: String = "new_game"  # "new_game" 或 "load"

const SAVE_SLOT_CARD = preload("res://scenes/ui/main_menu/save_slot_card.tscn")

@onready var title_label: Label = $MarginContainer/VBoxContainer/TopBar/TitleLabel
@onready var back_button: Button = $MarginContainer/VBoxContainer/TopBar/BackButton
@onready var card_container: HBoxContainer = $MarginContainer/VBoxContainer/CardContainer

func _ready() -> void:
	back_button.pressed.connect(_on_back_pressed)

## 设置面板模式并刷新槽位卡片
func setup(panel_mode: String) -> void:
	mode = panel_mode
	match mode:
		"new_game":
			title_label.text = "选择存档槽位"
		"load":
			title_label.text = "加载存档"
	_refresh_slots()

## 刷新3个存档槽位卡片
func _refresh_slots() -> void:
	# 清除旧卡片
	for child in card_container.get_children():
		child.queue_free()

	# 创建3个新卡片
	for i in range(SaveManager.MAX_SLOTS):
		var card = SAVE_SLOT_CARD.instantiate()
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card_container.add_child(card)
		var data := SaveManager.get_slot_data(i)
		card.setup(i, data, mode)
		card.clicked.connect(_on_slot_clicked)
		card.delete_requested.connect(_on_delete_requested)

## 槽位点击处理
func _on_slot_clicked(slot_index: int) -> void:
	match mode:
		"new_game":
			if SaveManager.is_slot_empty(slot_index):
				# 空槽位 - 直接选择，由 MainMenuRoot 处理后续导航
				slot_selected.emit(slot_index)
			else:
				# 非空槽位 - 弹出覆盖确认
				var dialog := _get_confirm_dialog()
				if dialog:
					dialog.show_dialog("该槽位已有存档，是否覆盖？", func():
						# 删除旧存档后选择该槽位
						SaveManager.delete_save(slot_index)
						slot_selected.emit(slot_index)
					)
		"load":
			if not SaveManager.is_slot_empty(slot_index):
				# 非空槽位 - 加载存档
				slot_selected.emit(slot_index)

## 删除请求处理
func _on_delete_requested(slot_index: int) -> void:
	var dialog := _get_confirm_dialog()
	if dialog:
		dialog.show_dialog("确认删除该存档？此操作不可撤销。", func():
			SaveManager.delete_save(slot_index)
			_refresh_slots()
		)

## 返回按钮
func _on_back_pressed() -> void:
	back_pressed.emit()

## 获取 ConfirmDialog（从 MainMenuRoot 获取）
func _get_confirm_dialog() -> ConfirmDialog:
	var root = get_parent()
	if root and root.has_node("ConfirmDialog"):
		return root.get_node("ConfirmDialog") as ConfirmDialog
	return null
