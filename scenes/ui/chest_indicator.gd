extends CanvasLayer
class_name ChestIndicator

const RoleSpecRegistry = preload("res://scripts/qef/roles/role_spec_registry.gd")

var indicator_nodes: Array[Control] = []
var chest_manager: ChestManager = null
var show_qef_packs: bool = true

var tier_colors: Dictionary = {
	1: Color.WHITE,
	2: Color.CYAN,
	3: Color.YELLOW,
	4: Color(1.0, 0.0, 1.0),
}

var rarity_colors: Dictionary = {
	"common": Color(0.95, 0.95, 0.95),
	"uncommon": Color(0.6, 1.0, 0.72),
	"rare": Color(0.55, 0.9, 1.0),
	"epic": Color(1.0, 0.72, 0.38),
	"legendary": Color(1.0, 0.86, 0.38),
	"mythic": Color(1.0, 0.52, 0.52),
}

var indicator_show_range: float = 3000.0

@onready var indicator_container: Control = $IndicatorContainer

func _ready() -> void:
	indicator_show_range = ConfigManager.get_map_setting("indicator_show_range", 3000.0)
	for _i in range(3):
		var indicator: Control = _create_indicator()
		indicator_container.add_child(indicator)
		indicator_nodes.append(indicator)
		indicator.visible = false

func _process(delta: float) -> void:
	var _unused_delta: float = delta
	if not is_instance_valid(Global.player):
		_hide_all_indicators()
		return

	var camera: Camera2D = get_viewport().get_camera_2d()
	if camera == null:
		_hide_all_indicators()
		return

	var player_pos: Vector2 = Global.player.global_position
	var targets: Array[Dictionary] = []
	targets.append_array(_collect_chest_targets(player_pos, camera))
	if show_qef_packs:
		targets.append_array(_collect_qef_pack_targets(player_pos, camera))

	targets.sort_custom(func(a, b) -> bool:
		var priority_a: int = int(a.get("priority", 99))
		var priority_b: int = int(b.get("priority", 99))
		if priority_a == priority_b:
			return float(a.get("distance", 0.0)) < float(b.get("distance", 0.0))
		return priority_a < priority_b
	)

	for i: int in range(indicator_nodes.size()):
		var indicator: Control = indicator_nodes[i]
		if i < targets.size():
			_update_indicator(indicator, targets[i], player_pos)
			indicator.visible = true
		else:
			indicator.visible = false

func set_chest_manager(manager: ChestManager) -> void:
	chest_manager = manager

func set_qef_pack_tracking(enabled: bool) -> void:
	show_qef_packs = enabled
	if not enabled:
		_hide_all_indicators()

func _collect_chest_targets(player_pos: Vector2, camera: Camera2D) -> Array[Dictionary]:
	var targets: Array[Dictionary] = []
	if chest_manager == null:
		return targets

	var all_chests = chest_manager.get_nearby_chests(player_pos, 10)
	for chest_data_var in all_chests:
		if not (chest_data_var is Dictionary):
			continue
		var chest_data: Dictionary = chest_data_var
		var chest_pos: Vector2 = chest_data.get("position", Vector2.ZERO)
		var distance: float = float(chest_data.get("distance", 0.0))
		if distance > indicator_show_range or _is_on_screen(chest_pos, camera):
			continue
		targets.append({
			"kind": "chest",
			"position": chest_pos,
			"distance": distance,
			"display_color": _resolve_chest_color(int(chest_data.get("tier", 1))),
			"label_text": "%dm" % int(distance),
			"priority": 10,
		})
		if targets.size() >= indicator_nodes.size():
			break
	return targets

func _collect_qef_pack_targets(player_pos: Vector2, camera: Camera2D) -> Array[Dictionary]:
	var targets: Array[Dictionary] = []
	var tree: SceneTree = get_tree()
	if tree == null:
		return targets

	var active_player_id: String = ""
	if is_instance_valid(Global.player) and "player_id" in Global.player:
		active_player_id = str(Global.player.get("player_id")).strip_edges()
	for pack_var in tree.get_nodes_in_group("qef_loot_packs"):
		if pack_var == null or not is_instance_valid(pack_var):
			continue
		if not (pack_var is Node2D):
			continue
		var pack: Node2D = pack_var
		if pack.is_queued_for_deletion():
			continue
		var pack_payload_var: Variant = pack.get("pack_payload") if "pack_payload" in pack else {}
		var reward_hint_var: Variant = pack.get("reward_hint") if "reward_hint" in pack else {}
		var pack_payload: Dictionary = pack_payload_var if pack_payload_var is Dictionary else {}
		var reward_hint: Dictionary = reward_hint_var if reward_hint_var is Dictionary else {}
		if pack_payload.is_empty():
			continue

		var world_pos: Vector2 = pack.global_position
		var distance: float = player_pos.distance_to(world_pos)
		if distance > indicator_show_range or _is_on_screen(world_pos, camera):
			continue

		var owner_player_id: String = str(pack_payload.get("owner_player_id", "")).strip_edges()
		var role_id: String = str(pack_payload.get("role_id", owner_player_id)).strip_edges()
		var display_color: Color = _resolve_pack_color(pack_payload, reward_hint)
		targets.append({
			"kind": "qef_pack",
			"position": world_pos,
			"distance": distance,
			"display_color": display_color,
			"label_text": "%s %dm" % [_resolve_pack_short_name(role_id), int(distance)],
			"priority": 0 if owner_player_id == active_player_id else 1,
		})
	return targets

func _resolve_chest_color(tier: int) -> Color:
	if tier == 4:
		var hue: float = fmod(Time.get_ticks_msec() / 1000.0, 1.0)
		return Color.from_hsv(hue, 0.8, 1.0)
	return tier_colors.get(tier, Color.WHITE)

func _resolve_pack_color(pack_payload: Dictionary, reward_hint: Dictionary) -> Color:
	var vfx_color_var: Variant = reward_hint.get("vfx_color", null)
	if vfx_color_var is Color:
		return vfx_color_var as Color
	var rarity: String = str(pack_payload.get("rarity", reward_hint.get("rarity", "common"))).strip_edges().to_lower()
	return rarity_colors.get(rarity, Color(1.0, 0.82, 0.42))

func _resolve_pack_short_name(role_id: String) -> String:
	var spec: Dictionary = RoleSpecRegistry.get_role_spec(role_id)
	var display_name: String = str(spec.get("display_name", "")).strip_edges()
	if not display_name.is_empty():
		return display_name.left(2)
	if role_id.is_empty():
		return "封包"
	return role_id.left(3).to_upper()

func _hide_all_indicators() -> void:
	for indicator: Control in indicator_nodes:
		indicator.visible = false

func _is_on_screen(world_pos: Vector2, camera: Camera2D) -> bool:
	var screen_size: Vector2 = get_viewport().get_visible_rect().size
	var camera_pos: Vector2 = camera.global_position
	var zoom: Vector2 = camera.zoom
	var half_screen: Vector2 = screen_size / 2.0 / zoom

	var screen_left: float = camera_pos.x - half_screen.x + 50.0
	var screen_right: float = camera_pos.x + half_screen.x - 50.0
	var screen_top: float = camera_pos.y - half_screen.y + 50.0
	var screen_bottom: float = camera_pos.y + half_screen.y - 50.0

	return world_pos.x >= screen_left and world_pos.x <= screen_right and world_pos.y >= screen_top and world_pos.y <= screen_bottom

func _create_indicator() -> Control:
	var container := Control.new()
	container.custom_minimum_size = Vector2(96, 80)

	var arrow := Polygon2D.new()
	arrow.polygon = PackedVector2Array([
		Vector2(0, -20),
		Vector2(15, 10),
		Vector2(0, 5),
		Vector2(-15, 10),
	])
	arrow.color = Color.WHITE
	arrow.position = Vector2(48, 36)
	container.add_child(arrow)

	var label := Label.new()
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.position = Vector2(0, 48)
	label.size = Vector2(96, 20)
	container.add_child(label)

	return container

func _update_indicator(indicator: Control, target_data: Dictionary, player_pos: Vector2) -> void:
	var target_pos: Vector2 = target_data.get("position", Vector2.ZERO)
	var display_color: Color = target_data.get("display_color", Color.WHITE)
	var label_text: String = str(target_data.get("label_text", ""))

	var direction: Vector2 = (target_pos - player_pos).normalized()
	if direction.length_squared() <= 0.001:
		direction = Vector2.UP

	var screen_size: Vector2 = get_viewport().get_visible_rect().size
	var screen_center: Vector2 = screen_size / 2.0
	var edge_pos: Vector2 = screen_center + direction * (screen_size.length() / 2.0 - 110.0)
	edge_pos.x = clamp(edge_pos.x, 50.0, screen_size.x - 50.0)
	edge_pos.y = clamp(edge_pos.y, 50.0, screen_size.y - 50.0)
	indicator.position = edge_pos

	var arrow: Polygon2D = indicator.get_child(0) as Polygon2D
	if arrow != null:
		arrow.rotation = direction.angle() + PI / 2.0
		arrow.color = display_color

	var label: Label = indicator.get_child(1) as Label
	if label != null:
		label.text = label_text
		label.modulate = display_color
