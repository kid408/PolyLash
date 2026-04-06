extends Node

const PLAYER_GENERIC_SCENE: String = "res://scenes/unit/players/player_generic.tscn"

func _ready() -> void:
	print("[PlayerFactory] ready")

func create_player(player_id: String) -> PlayerBase:
	if player_id.strip_edges().is_empty():
		printerr("[PlayerFactory] create_player failed: empty player_id")
		return null

	var scene_path: String = ""
	var script_path: String = ""

	var visual_config: Dictionary = ConfigManager.get_player_visual(player_id)
	if not visual_config.is_empty():
		scene_path = str(visual_config.get("scene_path", "")).strip_edges()

	if scene_path.is_empty():
		var runtime_binding: Dictionary = RoleRuntimeService.get_v2_runtime_binding(player_id)
		scene_path = str(runtime_binding.get("player_scene_path", PLAYER_GENERIC_SCENE)).strip_edges()
		script_path = str(runtime_binding.get("player_script_path", "")).strip_edges()

	if scene_path.is_empty():
		scene_path = PLAYER_GENERIC_SCENE

	var scene: PackedScene = load(scene_path) as PackedScene
	if scene == null:
		printerr("[PlayerFactory] failed to load player scene: %s" % scene_path)
		return null

	var root: Node = scene.instantiate()
	if root == null:
		printerr("[PlayerFactory] failed to instantiate player scene: %s" % scene_path)
		return null

	if not script_path.is_empty():
		var script_resource: Script = load(script_path) as Script
		if script_resource == null:
			printerr("[PlayerFactory] failed to load player script: %s" % script_path)
			root.queue_free()
			return null
		root.set_script(script_resource)

	var player: PlayerBase = root as PlayerBase
	if player == null:
		printerr("[PlayerFactory] instantiated root is not PlayerBase: %s" % player_id)
		root.queue_free()
		return null

	player.player_id = player_id
	return player

func get_available_players() -> Array[String]:
	var formal_ids: Array[String] = []
	for config_variant: Dictionary in ConfigManager.get_enabled_players():
		formal_ids.append(str(config_variant.get("player_id", "")))
	if not formal_ids.is_empty():
		return formal_ids

	var ids: Array[String] = []
	for player_id: String in RoleRuntimeService.get_all_v2_role_ids():
		var bundle: Dictionary = RoleRuntimeService.get_v2_role_bundle(player_id)
		var config: Dictionary = bundle.get("player_config", {})
		if int(config.get("enabled", 0)) == 1:
			ids.append(player_id)

	if not ids.is_empty():
		return ids

	var legacy_ids: Array[String] = []
	var legacy_config: Dictionary = ConfigManager.get_all_player_configs()
	for key_variant: Variant in legacy_config.keys():
		var legacy_id: String = str(key_variant)
		var config: Dictionary = legacy_config.get(legacy_id, {})
		if bool(config.get("enabled", false)):
			legacy_ids.append(legacy_id)
	return legacy_ids

func has_player(player_id: String) -> bool:
	if not ConfigManager.get_player_config(player_id).is_empty():
		return true
	if RoleRuntimeService.has_v2_role(player_id):
		return true
	return false
