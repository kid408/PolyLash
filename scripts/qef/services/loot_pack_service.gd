extends RefCounted
class_name LootPackService

const QEFModels = preload("res://scripts/qef/core/qef_models.gd")
const QEFRuntimeService = preload("res://scripts/qef/core/qef_runtime_service.gd")
const QEFLootPack = preload("res://scripts/qef/services/qef_loot_pack.gd")

static func spawn_pack(
	owner: Node,
	role_id: String,
	world_pos: Vector2,
	reward_hint: Dictionary = {},
	lifetime_sec: float = 6.0,
	pack_source: String = ""
) -> QEFLootPack:
	if owner == null or not is_instance_valid(owner):
		return null
	var tree: SceneTree = owner.get_tree()
	if tree == null or tree.current_scene == null:
		return null
	var player_id: String = _resolve_player_id(owner)
	if player_id.is_empty():
		return null
	var runtime: Dictionary = QEFRuntimeService.get_runtime(player_id)
	if not bool(runtime.get("active", false)):
		return null
	if int(runtime.get("unopened_count", 0)) >= 2:
		return null

	var pack_id: String = "%s:%d" % [player_id, Time.get_ticks_msec()]
	var effective_source: String = pack_source
	if effective_source.strip_edges().is_empty():
		effective_source = str(reward_hint.get("effect_id", "pack"))
	var payload: Dictionary = QEFModels.build_pack_payload(
		pack_id,
		player_id,
		role_id.strip_edges().to_lower(),
		int(runtime.get("window_seq", 0)),
		effective_source,
		world_pos,
		reward_hint
	)
	var pack := QEFLootPack.new()
	pack.setup(payload, reward_hint, lifetime_sec)
	tree.current_scene.add_child(pack)
	QEFRuntimeService.register_pack_spawn(player_id, payload)
	return pack

static func collect_pack(pack: QEFLootPack, collector: Node) -> void:
	if pack == null or not is_instance_valid(pack):
		return
	var payload: Dictionary = pack.pack_payload.duplicate(true)
	QEFRuntimeService.reveal_pack(str(payload.get("owner_player_id", "")), payload, collector)
	pack.queue_free()
	_sync_owner_pack_count(str(payload.get("owner_player_id", "")))

static func expire_pack(pack: QEFLootPack) -> void:
	if pack == null or not is_instance_valid(pack):
		return
	var payload: Dictionary = pack.pack_payload.duplicate(true)
	pack.queue_free()
	QEFRuntimeService.register_pack_removed(str(payload.get("owner_player_id", "")), str(payload.get("pack_id", "")))
	_sync_owner_pack_count(str(payload.get("owner_player_id", "")))

static func clear_player_packs(owner_player_id: String) -> void:
	if owner_player_id.strip_edges().is_empty():
		return
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree == null:
		return
	for node_var in tree.get_nodes_in_group("qef_loot_packs"):
		if node_var == null or not is_instance_valid(node_var):
			continue
		if not (node_var is QEFLootPack):
			continue
		var pack: QEFLootPack = node_var
		if pack.is_queued_for_deletion():
			continue
		if str(pack.pack_payload.get("owner_player_id", "")) != owner_player_id:
			continue
		pack.queue_free()
	QEFRuntimeService.set_active_pickup_count(owner_player_id, 0)
	QEFRuntimeService.clear_unopened_packs(owner_player_id)

static func count_active_packs(owner_player_id: String) -> int:
	if owner_player_id.strip_edges().is_empty():
		return 0
	var count: int = 0
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree == null:
		return 0
	for node_var in tree.get_nodes_in_group("qef_loot_packs"):
		if node_var == null or not is_instance_valid(node_var):
			continue
		if not (node_var is QEFLootPack):
			continue
		var pack: QEFLootPack = node_var
		if pack.is_queued_for_deletion():
			continue
		if str(pack.pack_payload.get("owner_player_id", "")) == owner_player_id:
			count += 1
	return count

static func _sync_owner_pack_count(owner_player_id: String) -> void:
	if owner_player_id.strip_edges().is_empty():
		return
	QEFRuntimeService.set_active_pickup_count(owner_player_id, count_active_packs(owner_player_id))

static func _resolve_player_id(owner: Node) -> String:
	if owner != null and is_instance_valid(owner) and "player_id" in owner:
		return str(owner.get("player_id")).strip_edges()
	return ""
