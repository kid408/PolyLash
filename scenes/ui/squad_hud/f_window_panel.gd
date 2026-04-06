extends PanelContainer
class_name FWindowPanel

@onready var mode_label: Label = $MarginContainer/VBoxContainer/HeaderRow/ModeLabel
@onready var timer_label: Label = $MarginContainer/VBoxContainer/HeaderRow/TimerLabel
@onready var timer_bar: ProgressBar = $MarginContainer/VBoxContainer/TimerBar
@onready var pickup_label: Label = $MarginContainer/VBoxContainer/InfoRow/PickupLabel
@onready var e_slot_label: Label = $MarginContainer/VBoxContainer/SlotRow/ESlot
@onready var q_slot_label: Label = $MarginContainer/VBoxContainer/SlotRow/QSlot
@onready var utility_label: Label = $MarginContainer/VBoxContainer/InfoRow/UtilityLabel

func update_runtime(player_id: String, runtime: Dictionary) -> void:
	var active: bool = bool(runtime.get("active", false))
	var has_payload: bool = (
		active
		or int(runtime.get("active_pickup_count", 0)) > 0
		or int(runtime.get("unopened_count", 0)) > 0
		or _slot_is_active(runtime.get("slot_e", {}))
		or _slot_is_active(runtime.get("slot_q", {}))
	)
	visible = has_payload
	if not has_payload:
		return

	var mode_name: String = str(runtime.get("mode_name", player_id)).strip_edges()
	var time_left: float = max(0.0, float(runtime.get("time_left", 0.0)))
	var duration: float = max(0.01, float(runtime.get("duration", 10.0)))
	var pickup_count: int = max(0, int(runtime.get("active_pickup_count", 0)))
	var unopened_count: int = max(0, int(runtime.get("unopened_count", 0)))

	mode_label.text = "%s F" % mode_name
	timer_label.text = "%.1fs" % time_left
	timer_bar.max_value = duration
	timer_bar.value = time_left
	pickup_label.text = "追击物 %d / 包 %d" % [pickup_count, unopened_count]
	e_slot_label.text = _build_slot_text("E", runtime.get("slot_e", {}))
	q_slot_label.text = _build_slot_text("Q闭合", runtime.get("slot_q", {}))
	utility_label.text = _build_utility_text(runtime)

func _slot_is_active(slot_var: Variant) -> bool:
	if not (slot_var is Dictionary):
		return false
	return bool((slot_var as Dictionary).get("active", false))

func _build_slot_text(slot_name: String, slot_var: Variant) -> String:
	if not (slot_var is Dictionary):
		return "%s: 空" % slot_name
	var slot: Dictionary = slot_var
	if not bool(slot.get("active", false)):
		return "%s: 空" % slot_name
	var display_name: String = str(slot.get("display_name", "")).strip_edges()
	if display_name.is_empty():
		display_name = str(slot.get("reward_id", "已装载")).strip_edges()
	return "%s: %s" % [slot_name, display_name]

func _build_utility_text(runtime: Dictionary) -> String:
	var utility: Dictionary = runtime.get("utility_buff", {}) if runtime.get("utility_buff", {}) is Dictionary else {}
	if not utility.is_empty():
		var display_name: String = str(utility.get("display_name", "")).strip_edges()
		if display_name.is_empty():
			display_name = str(utility.get("reward_id", "Buff")).strip_edges()
		return "Buff: %s" % display_name
	var pickup_count: int = max(0, int(runtime.get("active_pickup_count", 0)))
	if pickup_count > 0:
		return "场上有可拾取高光资源"
	return "无短时增益"
