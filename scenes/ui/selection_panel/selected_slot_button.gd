extends Button
class_name SelectedSlotButton

# ============================================================================
# 已选槽位按钮 - 支持接收拖拽
# ============================================================================

signal player_dropped(slot_index: int, player_id: String, weapon_type: String)

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
		player_dropped.emit(slot_index, player_id, weapon_type)
