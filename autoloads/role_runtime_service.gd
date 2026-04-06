extends Node

signal v2_configs_ready

var _resolved_bundles: Dictionary = {}

func _ready() -> void:
	_reload_from_repository()
	if ConfigRepositoryV2.has_signal("configs_reloaded"):
		var callable_ref: Callable = Callable(self, "_on_repository_reloaded")
		if not ConfigRepositoryV2.configs_reloaded.is_connected(callable_ref):
			ConfigRepositoryV2.configs_reloaded.connect(callable_ref)

func _on_repository_reloaded() -> void:
	_reload_from_repository()

func reload_v2_configs() -> void:
	ConfigRepositoryV2.reload_all()

func has_v2_role(player_id: String) -> bool:
	return _resolved_bundles.has(player_id)

func get_v2_player_config(player_id: String) -> Dictionary:
	return ConfigRepositoryV2.get_player_config(player_id)

func get_v2_runtime_binding(player_id: String) -> Dictionary:
	return ConfigRepositoryV2.get_runtime_binding(player_id)

func get_v2_role_bundle(player_id: String) -> Dictionary:
	return _resolved_bundles.get(player_id, {}).duplicate(true)

func get_all_v2_role_ids() -> Array[String]:
	var ids: Array[String] = []
	for key_variant: Variant in _resolved_bundles.keys():
		ids.append(str(key_variant))
	return ids

func _reload_from_repository() -> void:
	_resolved_bundles.clear()
	var player_ids: Array[String] = ConfigRepositoryV2.get_all_player_ids()
	for player_id: String in player_ids:
		var bundle: Dictionary = _build_role_bundle(player_id)
		if bundle.is_empty():
			continue
		_resolved_bundles[player_id] = bundle
	v2_configs_ready.emit()

func _build_role_bundle(player_id: String) -> Dictionary:
	var player_config: Dictionary = ConfigRepositoryV2.get_player_config(player_id)
	if player_config.is_empty():
		return {}

	var runtime_binding: Dictionary = ConfigRepositoryV2.get_runtime_binding(player_id)
	if runtime_binding.is_empty():
		return {}

	var space_skill_id: String = str(runtime_binding.get("space_skill_id", "")).strip_edges()
	var e_skill_id: String = str(runtime_binding.get("e_skill_id", "")).strip_edges()
	var f_skill_id: String = str(runtime_binding.get("f_skill_id", "")).strip_edges()
	var assist_id: String = str(runtime_binding.get("assist_id", "")).strip_edges()

	var bundle: Dictionary = {
		"player_config": player_config,
		"runtime_binding": runtime_binding,
		"space_skill": ConfigRepositoryV2.get_space_skill_config(space_skill_id),
		"e_skill": ConfigRepositoryV2.get_e_skill_config(e_skill_id),
		"f_skill": ConfigRepositoryV2.get_f_skill_config(f_skill_id),
		"assist": ConfigRepositoryV2.get_assist_config(assist_id)
	}
	return bundle
