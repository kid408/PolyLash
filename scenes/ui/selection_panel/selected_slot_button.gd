extends Button
class_name SelectedSlotButton

# ============================================================================
# 已选槽位按钮 - 支持接收拖拽
# ============================================================================

signal player_dropped(slot_index: int, player_id: String, weapon_type: String)
signal remove_requested(slot_index: int)

var slot_index: int = 0

func setup(p_slot_index: int) -> void:
	slot_index = p_slot_index

func _can_drop_data(_at_position: Vector2, data) -> bool:
	if data is Dictionary and data.get("type") == "player":
		return true
	return false

func _drop_data(_at_position: Vector2, data) -> void:
	if data is Dictionary and data.get("type") == "player":
		var player_id = data.get("player_id", "")
		var weapon_type = data.get("weapon_type", "")
		
		# 检查该角色是否已被选择过（在其他槽位中）
		var selection_panel = get_tree().root.get_child(0).find_child("SelectionPanel", true, false)
		if selection_panel and selection_panel.has_method("is_player_selected"):
			if selection_panel.is_player_selected(player_id):
				print("[SelectionPanel] 角色 %s 已被选择，不能放入槽位" % player_id)
				return
		
		player_dropped.emit(slot_index, player_id, weapon_type)

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
		remove_requested.emit(slot_index)
		accept_event()
