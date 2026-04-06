extends Control

signal slot_selected(slot_index: int)
signal back_pressed

const SAVE_SLOT_CARD := preload("res://scenes/ui/main_menu/save_slot_card.tscn")
const COLOR_TEXT := Color("#E6EDF3")
const COLOR_BG := Color("#0D1117")

var mode := "new_game"
var _ui_font: Font

@onready var root_vbox: VBoxContainer = $VBoxContainer
@onready var title_label: Label = $VBoxContainer/Header
@onready var save_grid: GridContainer = $VBoxContainer/ScrollContainer/SaveGrid

func _ready() -> void:
	_ui_font = _create_font()
	apply_theme()

func setup(panel_mode: String) -> void:
	mode = panel_mode
	title_label.text = "新建存档" if mode == "new_game" else "加载存档"
	_refresh_slots()

func apply_theme() -> void:
	var bg := get_parent()
	title_label.add_theme_font_override("font", _ui_font)
	title_label.add_theme_font_size_override("font_size", 36)
	title_label.add_theme_color_override("font_color", COLOR_TEXT)
	if bg is Control:
		(bg as Control).add_theme_color_override("font_color", COLOR_TEXT)

func _refresh_slots() -> void:
	for child in save_grid.get_children():
		child.queue_free()

	for i in range(SaveManager.MAX_SLOTS):
		var card := SAVE_SLOT_CARD.instantiate()
		save_grid.add_child(card)
		var data := SaveManager.get_slot_data(i)
		card.setup(i, data, mode)
		card.clicked.connect(_on_slot_clicked)

func _on_slot_clicked(slot_index: int) -> void:
	match mode:
		"new_game":
			if SaveManager.is_slot_empty(slot_index):
				slot_selected.emit(slot_index)
			else:
				var dialog := _get_confirm_dialog()
				if dialog:
					dialog.show_dialog("该槽位已有存档，是否覆盖？", func():
						SaveManager.delete_save(slot_index)
						slot_selected.emit(slot_index)
					)
		"load":
			if not SaveManager.is_slot_empty(slot_index):
				slot_selected.emit(slot_index)

func _get_confirm_dialog() -> ConfirmDialog:
	var root := get_parent()
	if root and root.has_node("ConfirmDialog"):
		return root.get_node("ConfirmDialog") as ConfirmDialog
	return null

func _create_font() -> Font:
	var font := SystemFont.new()
	font.font_names = PackedStringArray([
		"Noto Sans SC",
		"Source Han Sans SC",
		"Microsoft YaHei UI",
		"Microsoft YaHei",
		"Segoe UI",
		"Arial",
	])
	font.font_weight = 600
	return font
