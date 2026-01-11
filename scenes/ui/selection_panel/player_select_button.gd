extends Button
class_name PlayerSelectButton

# ============================================================================
# 角色选择按钮 - 支持拖拽功能
# ============================================================================

var player_id: String = ""
var weapon_type: String = ""

func setup(p_player_id: String, p_weapon_type: String = "") -> void:
	player_id = p_player_id
	weapon_type = p_weapon_type

func _get_drag_data(_at_position: Vector2):
	if player_id == "":
		return null
	
	# 创建拖拽预览
	var preview = TextureRect.new()
	preview.custom_minimum_size = Vector2(64, 64)
	preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	
	if icon:
		preview.texture = icon
	
	set_drag_preview(preview)
	
	return {
		"type": "player",
		"player_id": player_id,
		"weapon_type": weapon_type
	}
