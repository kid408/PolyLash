extends Control
class_name EnergyBar

@export var back_color: Color = Color(0.2, 0.2, 0.3)
@export var fill_color: Color = Color(0.3, 0.8, 1.0)  # 蓝色能量

@onready var progress_bar: ProgressBar = $ProgressBar
@onready var energy_amount: Label = $EnergyAmount


func _ready() -> void:
	var back_style := progress_bar.get_theme_stylebox("background").duplicate()
	back_style.bg_color = back_color
	
	var fill_style := progress_bar.get_theme_stylebox("fill").duplicate()
	fill_style.bg_color = fill_color
	
	progress_bar.add_theme_stylebox_override("background", back_style)
	progress_bar.add_theme_stylebox_override("fill", fill_style)

func update_bar(value: float, energy: float) -> void:
	progress_bar.value = value
	energy_amount.text = str(int(energy))

# 连接到 PlayerBase 的 energy_changed 信号
func _on_player_energy_changed(current: float, max_val: float) -> void:
	var value = current / max_val
	update_bar(value, current)
