extends Node
class_name SkillUltimate

const DEBUG_VERBOSE := false
const QEFRuntimeService = preload("res://scripts/qef/core/qef_runtime_service.gd")

signal ultimate_activated
signal ultimate_deactivated
signal ultimate_duration_changed(remaining: float, total: float)

# Config
var ult_id: String = ""
var ult_name: String = "Ultimate"
var duration: float = 10.0
var bonus_bond_tag: String = ""
var visual_color: Color = Color.WHITE
var scale_multiplier: float = 1.2
var description: String = ""

# Cost / shared F parameters
var energy_cost: float = 80.0
var f_role_id: String = ""
var f_internal_cd: float = 1.0
var f_q_line_amp: float = 1.0
var f_q_closure_amp: float = 1.0
var f_special_value_1: float = 0.0
var f_special_value_2: float = 0.0
var f_special_value_3: float = 0.0
var f_bond_o_payload: String = ""
var f_bond_m_payload: String = ""
var f_bond_t_payload: String = ""

# Shared explosion modifier on weapons
var explosion_radius: float = 250.0
var explosion_damage_scale: float = 1.0

# Runtime
var is_active: bool = false
var remaining_time: float = 0.0
var player_ref: Node = null

var original_scale: Vector2 = Vector2.ONE
var original_modulate: Color = Color.WHITE
var original_weapon_stats: Dictionary = {}
var f_runtime_profile: Dictionary = {}

var duration_timer: Timer = null

func _ready() -> void:
	duration_timer = Timer.new()
	duration_timer.one_shot = true
	duration_timer.timeout.connect(_on_duration_timeout)
	add_child(duration_timer)

func _exit_tree() -> void:
	var preserve_on_exit: bool = is_instance_valid(player_ref) and player_ref.has_meta("preserve_f_runtime_on_exit") and bool(player_ref.get_meta("preserve_f_runtime_on_exit"))
	if preserve_on_exit:
		return
	if is_active:
		deactivate()
	else:
		_clear_runtime_profile()

func initialize(config: Dictionary, player: Node) -> void:
	ult_id = str(config.get("ult_id", ""))
	ult_name = str(config.get("name", "Ultimate"))
	duration = float(config.get("duration", 10.0))
	bonus_bond_tag = str(config.get("bonus_bond_tag", ""))
	scale_multiplier = float(config.get("scale_multiplier", 1.2))
	description = str(config.get("description", ""))

	energy_cost = float(config.get("energy_cost", 80.0))
	explosion_radius = float(config.get("explosion_radius", 250.0))
	explosion_damage_scale = float(config.get("explosion_damage_scale", 1.0))

	f_role_id = str(config.get("f_role_id", ""))
	f_internal_cd = float(config.get("f_internal_cd", 1.0))
	f_q_line_amp = float(config.get("f_q_line_amp", 1.0))
	f_q_closure_amp = float(config.get("f_q_closure_amp", 1.0))
	f_special_value_1 = float(config.get("f_special_value_1", 0.0))
	f_special_value_2 = float(config.get("f_special_value_2", 0.0))
	f_special_value_3 = float(config.get("f_special_value_3", 0.0))
	f_bond_o_payload = str(config.get("f_bond_o_payload", ""))
	f_bond_m_payload = str(config.get("f_bond_m_payload", ""))
	f_bond_t_payload = str(config.get("f_bond_t_payload", ""))

	var color_hex: String = str(config.get("visual_color_hex", "#FFFFFF"))
	visual_color = _parse_color(color_hex)

	player_ref = player
	if is_instance_valid(player_ref):
		var node2d: Node2D = player_ref as Node2D
		if node2d != null:
			original_scale = node2d.scale
		var canvas_item: CanvasItem = player_ref as CanvasItem
		if canvas_item != null:
			original_modulate = canvas_item.modulate

	if DEBUG_VERBOSE:
		print("[SkillUltimate] init: %s, duration=%.2f, cost=%.1f, exp_radius=%.1f, exp_scale=%.2f" % [
			ult_name, duration, energy_cost, explosion_radius, explosion_damage_scale
		])

func try_activate() -> bool:
	if is_active:
		if is_instance_valid(player_ref):
			var global_node: Node = _get_global_singleton()
			if global_node != null and global_node.has_method("spawn_floating_text"):
				global_node.call("spawn_floating_text", _get_player_global_position(), "Ultimate Active", Color.YELLOW)
		return false

	if not is_instance_valid(player_ref):
		printerr("[SkillUltimate] player_ref invalid")
		return false

	if not _check_energy():
		var current_energy: float = 0.0
		if player_ref.has_method("get_energy_percent"):
			current_energy = float(player_ref.get_energy_percent())
		var global_node: Node = _get_global_singleton()
		if global_node != null and global_node.has_method("spawn_floating_text"):
			global_node.call(
				"spawn_floating_text",
				_get_player_global_position(),
				"Not enough energy (%.0f%%/%.0f%%)" % [current_energy, energy_cost],
				Color.ORANGE_RED
			)
		return false

	_consume_energy()
	_activate()
	return true

func _activate() -> void:
	is_active = true
	remaining_time = max(0.01, duration)

	var sound_manager: Node = _get_autoload_node("SoundManager")
	if sound_manager != null and sound_manager.has_method("play"):
		sound_manager.call("play", "skill_ult_activate")

	var bond_manager: Node = _get_autoload_node("BondManager")
	if bonus_bond_tag != "" and bond_manager != null and bond_manager.has_method("add_temp_tag"):
		bond_manager.call("add_temp_tag", bonus_bond_tag)

	_apply_visuals()
	_apply_explosion_to_weapons()

	f_runtime_profile = _build_runtime_profile()
	f_runtime_profile["window_seq"] = int(f_runtime_profile.get("window_seq", 0)) + 1
	var started_runtime: Dictionary = QEFRuntimeService.begin_window(player_ref, _resolve_runtime_role_id(), ult_name, duration, f_runtime_profile)
	if not started_runtime.is_empty():
		f_runtime_profile = started_runtime.duplicate(true)
	_publish_runtime_profile()

	if duration_timer != null:
		duration_timer.start(max(0.01, duration))

	_on_ultimate_activated()
	_publish_runtime_profile()
	ultimate_activated.emit()

func deactivate() -> void:
	if not is_active:
		return

	is_active = false
	remaining_time = 0.0

	var sound_manager: Node = _get_autoload_node("SoundManager")
	if sound_manager != null and sound_manager.has_method("play"):
		sound_manager.call("play", "skill_ult_deactivate")

	var bond_manager: Node = _get_autoload_node("BondManager")
	if bonus_bond_tag != "" and bond_manager != null and bond_manager.has_method("get_temp_tags"):
		var temp_tags: Dictionary = bond_manager.call("get_temp_tags")
		if temp_tags.has(bonus_bond_tag):
			if bond_manager.has_method("remove_temp_tag"):
				bond_manager.call("remove_temp_tag", bonus_bond_tag)

	_restore_visuals()
	_remove_explosion_from_weapons()

	if duration_timer != null:
		duration_timer.stop()

	_on_ultimate_deactivated()
	_clear_runtime_profile()
	ultimate_deactivated.emit()

func _apply_explosion_to_weapons() -> void:
	if not is_instance_valid(player_ref):
		return

	var weapons: Array = _get_player_weapons()
	if weapons.is_empty():
		return

	for weapon_variant in weapons:
		var weapon_node: Node = weapon_variant as Node
		if weapon_node == null or not is_instance_valid(weapon_node):
			continue

		var data_obj: Variant = weapon_node.get("data")
		if not (data_obj is Object):
			continue

		var stats_obj: Variant = (data_obj as Object).get("stats")
		var stats: WeaponStats = stats_obj as WeaponStats
		if stats == null:
			continue

		original_weapon_stats[weapon_node] = {
			"explosion_radius": float(stats.explosion_radius),
			"explosion_damage_scale": float(stats.explosion_damage_scale)
		}

		stats.explosion_radius = explosion_radius
		stats.explosion_damage_scale = explosion_damage_scale

func _remove_explosion_from_weapons() -> void:
	for key in original_weapon_stats.keys():
		var weapon_node: Node = key as Node
		if weapon_node == null or not is_instance_valid(weapon_node):
			continue

		var data_obj: Variant = weapon_node.get("data")
		if not (data_obj is Object):
			continue

		var stats_obj: Variant = (data_obj as Object).get("stats")
		var stats: WeaponStats = stats_obj as WeaponStats
		if stats == null:
			continue

		var original_variant: Variant = original_weapon_stats[key]
		if not (original_variant is Dictionary):
			continue
		var original: Dictionary = original_variant

		stats.explosion_radius = float(original.get("explosion_radius", stats.explosion_radius))
		stats.explosion_damage_scale = float(original.get("explosion_damage_scale", stats.explosion_damage_scale))

	original_weapon_stats.clear()

func _get_player_weapons() -> Array:
	var weapons: Array = []
	if not is_instance_valid(player_ref):
		return weapons

	var current_weapons_variant: Variant = null
	if "current_weapons" in player_ref:
		current_weapons_variant = player_ref.get("current_weapons")
	if current_weapons_variant != null:
		if current_weapons_variant is Array:
			var current_weapons: Array = current_weapons_variant
			for w in current_weapons:
				var wn: Node = w as Node
				if wn != null and is_instance_valid(wn):
					weapons.append(wn)
			if not weapons.is_empty():
				return weapons

	return _find_weapons_recursive(player_ref)

func _find_weapons_recursive(node: Node, depth: int = 0) -> Array:
	var weapons: Array = []
	if node == null:
		return weapons
	if depth > 8:
		return weapons

	for child in node.get_children():
		var child_node: Node = child as Node
		if child_node == null:
			continue

		var node_class: String = child_node.get_class()
		var script_obj: Script = child_node.get_script() as Script
		var script_path: String = script_obj.resource_path if script_obj != null else ""
		var lower_name: String = child_node.name.to_lower()
		var lower_path: String = script_path.to_lower()

		if node_class == "Weapon" or lower_name.find("weapon") != -1 or lower_path.find("/weapons/") != -1:
			weapons.append(child_node)
			continue

		var nested: Array = _find_weapons_recursive(child_node, depth + 1)
		if not nested.is_empty():
			weapons.append_array(nested)

	return weapons

func _check_energy() -> bool:
	if not is_instance_valid(player_ref) or not player_ref.has_method("get_energy_percent"):
		return true
	var energy_percent: float = float(player_ref.get_energy_percent())
	return energy_percent >= energy_cost

func _consume_energy() -> void:
	if is_instance_valid(player_ref) and player_ref.has_method("consume_energy_percent"):
		player_ref.consume_energy_percent(energy_cost)

func _apply_visuals() -> void:
	if not is_instance_valid(player_ref):
		return

	var node2d: Node2D = player_ref as Node2D
	var canvas_item: CanvasItem = player_ref as CanvasItem
	if node2d != null:
		original_scale = node2d.scale
	if canvas_item != null:
		original_modulate = canvas_item.modulate

	var tween: Tween = create_tween()
	tween.set_parallel(true)
	if node2d != null:
		tween.tween_property(node2d, "scale", original_scale * scale_multiplier, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if canvas_item != null:
		tween.tween_property(canvas_item, "modulate", visual_color, 0.25).set_trans(Tween.TRANS_SINE)

func _restore_visuals() -> void:
	if not is_instance_valid(player_ref):
		return

	var node2d: Node2D = player_ref as Node2D
	var canvas_item: CanvasItem = player_ref as CanvasItem
	var tween: Tween = create_tween()
	tween.set_parallel(true)
	if node2d != null:
		tween.tween_property(node2d, "scale", original_scale, 0.25).set_trans(Tween.TRANS_SINE)
	if canvas_item != null:
		tween.tween_property(canvas_item, "modulate", original_modulate, 0.25).set_trans(Tween.TRANS_SINE)

func _process(delta: float) -> void:
	if not is_active:
		return

	remaining_time = max(0.0, remaining_time - delta)
	f_runtime_profile["time_left"] = remaining_time
	ultimate_duration_changed.emit(remaining_time, duration)
	_publish_runtime_profile()
	_on_ultimate_update(delta)

func _on_duration_timeout() -> void:
	deactivate()

func _get_player_global_position() -> Vector2:
	var node2d: Node2D = player_ref as Node2D
	if node2d != null:
		return node2d.global_position
	return Vector2.ZERO

func _on_ultimate_activated() -> void:
	pass

func _on_ultimate_deactivated() -> void:
	pass

func _on_ultimate_update(_delta: float) -> void:
	pass

func on_q_path_executed(_is_closed: bool, _segment_count: int, _polygon_count: int) -> void:
	pass

func _parse_color(hex: String) -> Color:
	var cleaned: String = hex.strip_edges()
	if cleaned.is_empty():
		return Color.WHITE
	if not cleaned.begins_with("#"):
		cleaned = "#" + cleaned
	return Color.from_string(cleaned, Color.WHITE)

func spawn_skill_vfx(pos: Vector2, color: Color = Color.WHITE, vfx_scale: float = 0.6) -> void:
	var explosion_scene: PackedScene = load("res://scenes/vfx/explosion_area.tscn") as PackedScene
	if explosion_scene == null:
		return

	var tree: SceneTree = get_tree()
	if tree == null or tree.current_scene == null:
		return

	var vfx_node: Node = explosion_scene.instantiate()
	var vfx_2d: Node2D = vfx_node as Node2D
	if vfx_2d == null:
		return

	vfx_2d.global_position = pos
	vfx_2d.scale = Vector2(vfx_scale, vfx_scale)
	vfx_2d.modulate = color
	vfx_2d.z_index = 100
	tree.current_scene.call_deferred("add_child", vfx_2d)

	var timer: SceneTreeTimer = tree.create_timer(1.0)
	timer.timeout.connect(Callable(self, "_on_skill_vfx_timeout").bind(weakref(vfx_2d)), CONNECT_ONE_SHOT)

func _on_skill_vfx_timeout(vfx_ref: WeakRef) -> void:
	var vfx_obj: Variant = vfx_ref.get_ref()
	var vfx_node: Node = vfx_obj as Node
	if vfx_node != null and is_instance_valid(vfx_node):
		vfx_node.queue_free()

func _build_runtime_profile() -> Dictionary:
	return {
		"active": is_active,
		"owner_player_id": str(player_ref.get("player_id")) if is_instance_valid(player_ref) and "player_id" in player_ref else "",
		"ult_id": ult_id,
		"mode_name": ult_name,
		"f_role_id": f_role_id,
		"q_line_amp": f_q_line_amp,
		"q_closure_amp": f_q_closure_amp,
		"internal_cd": f_internal_cd,
		"special_1": f_special_value_1,
		"special_2": f_special_value_2,
		"special_3": f_special_value_3,
		"bond_o_payload": f_bond_o_payload,
		"bond_m_payload": f_bond_m_payload,
		"bond_t_payload": f_bond_t_payload,
		"duration": duration,
		"time_left": remaining_time,
		"window_seq": 0,
	}

func _resolve_runtime_role_id() -> String:
	if not f_role_id.strip_edges().is_empty():
		return f_role_id.strip_edges().to_lower()
	if is_instance_valid(player_ref) and "player_id" in player_ref:
		return str(player_ref.get("player_id")).strip_edges().to_lower()
	return ""

func update_runtime_profile(changes: Dictionary) -> void:
	if changes.is_empty():
		return
	for key in changes.keys():
		f_runtime_profile[key] = changes[key]
	_publish_runtime_profile()

func _publish_runtime_profile() -> void:
	if not is_instance_valid(player_ref):
		return
	if f_runtime_profile.is_empty():
		return
	f_runtime_profile["active"] = is_active
	f_runtime_profile["time_left"] = remaining_time
	f_runtime_profile["duration"] = duration
	f_runtime_profile["mode_name"] = ult_name
	f_runtime_profile["owner_player_id"] = str(player_ref.get("player_id")) if "player_id" in player_ref else ""
	var merged_runtime: Dictionary = QEFRuntimeService.sync_skill_profile(player_ref, f_runtime_profile)
	f_runtime_profile = merged_runtime.duplicate(true)
	player_ref.set_meta("f_runtime_profile", merged_runtime.duplicate(true))

func _clear_runtime_profile() -> void:
	var player_id: String = str(player_ref.get("player_id")) if is_instance_valid(player_ref) and "player_id" in player_ref else ""
	f_runtime_profile.clear()
	if is_instance_valid(player_ref) and player_ref.has_meta("f_runtime_profile"):
		player_ref.remove_meta("f_runtime_profile")
	if not player_id.is_empty():
		QEFRuntimeService.end_window(player_id)

func get_runtime_profile() -> Dictionary:
	return f_runtime_profile.duplicate(true)

func resume_from_runtime(saved_runtime: Dictionary) -> void:
	if saved_runtime.is_empty():
		return
	var time_left: float = max(0.0, float(saved_runtime.get("time_left", 0.0)))
	if time_left <= 0.0:
		return
	is_active = true
	remaining_time = time_left
	f_runtime_profile = _build_runtime_profile()
	f_runtime_profile.merge(saved_runtime.duplicate(true), true)
	f_runtime_profile["active"] = true
	f_runtime_profile["time_left"] = time_left
	_apply_visuals()
	if duration_timer != null:
		duration_timer.start(max(0.01, time_left))
	_publish_runtime_profile()

func get_energy_cost() -> float:
	return energy_cost

func get_cooldown_progress() -> float:
	return 0.0 if is_active else 1.0

func get_status_text() -> String:
	if is_active:
		return "%s active (%.1fs)" % [ult_name, remaining_time]
	return "%s ready" % ult_name

func _get_global_singleton() -> Node:
	return _get_autoload_node("Global")

func _get_autoload_node(node_name: String) -> Node:
	var tree: SceneTree = get_tree()
	if tree == null:
		return null
	return tree.root.get_node_or_null(node_name)
