extends RefCounted
class_name SkillAssetRegistry

const REGISTRY_META_KEY := "skill_asset_registry_v1"

static func register_asset(
	owner: Node,
	kind: String,
	center: Vector2,
	radius: float,
	payload: Dictionary = {},
	duration_sec: float = 0.0,
	asset_node: Node = null
) -> Dictionary:
	var root := _resolve_root(owner)
	if root == null:
		return {}

	var registry := _get_registry(root)
	_prune_registry(registry)

	var clean_kind := kind.strip_edges()
	if clean_kind.is_empty():
		clean_kind = "generic"

	var owner_role_id := _resolve_role_id(owner)
	var created_msec := Time.get_ticks_msec()
	var asset_id := "%s:%s:%d" % [
		owner_role_id if not owner_role_id.is_empty() else "skill",
		clean_kind,
		created_msec
	]
	while registry.has(asset_id):
		asset_id += "_"

	var expire_msec := 0
	if duration_sec > 0.0:
		expire_msec = created_msec + int(round(duration_sec * 1000.0))

	var entry: Dictionary = {
		"asset_id": asset_id,
		"kind": clean_kind,
		"center": center,
		"radius": max(0.0, radius),
		"created_msec": created_msec,
		"expire_msec": expire_msec,
		"owner_instance_id": owner.get_instance_id() if is_instance_valid(owner) else 0,
		"owner_role_id": owner_role_id,
		"payload": payload.duplicate(true),
		"node_ref": weakref(asset_node) if asset_node != null and is_instance_valid(asset_node) else null,
	}

	if asset_node != null and is_instance_valid(asset_node):
		if not asset_node.is_in_group("player_summoned_entity"):
			asset_node.add_to_group("player_summoned_entity")
		if payload.has("logic_tags"):
			asset_node.set_meta("logic_tags", payload.get("logic_tags"))
		if payload.has("physics_tags"):
			asset_node.set_meta("physics_tags", payload.get("physics_tags"))

	registry[asset_id] = entry
	root.set_meta(REGISTRY_META_KEY, registry)
	return _sanitize_entry(entry)

static func get_asset_by_id(owner: Node, asset_id: String) -> Dictionary:
	var root := _resolve_root(owner)
	if root == null:
		return {}
	var registry := _get_registry(root)
	_prune_registry(registry)
	var entry_var: Variant = registry.get(asset_id, {})
	if not (entry_var is Dictionary):
		return {}
	return _sanitize_entry(entry_var as Dictionary)

static func list_assets(
	owner: Node = null,
	kind_filter: String = "",
	role_filter: String = "",
	max_age_msec: int = 0
) -> Array[Dictionary]:
	var root := _resolve_root(owner)
	var owner_instance_id := owner.get_instance_id() if owner != null and is_instance_valid(owner) else 0
	return _list_assets_from_root(root, kind_filter, role_filter, max_age_msec, owner_instance_id)

static func list_scene_assets(
	owner: Node,
	kind_filter: String = "",
	role_filter: String = "",
	max_age_msec: int = 0
) -> Array[Dictionary]:
	var root := _resolve_root(owner)
	return _list_assets_from_root(root, kind_filter, role_filter, max_age_msec, 0)

static func _list_assets_from_root(
	root: Node,
	kind_filter: String,
	role_filter: String,
	max_age_msec: int,
	owner_instance_id: int
) -> Array[Dictionary]:
	if root == null:
		return []

	var registry := _get_registry(root)
	_prune_registry(registry)
	var clean_kind := kind_filter.strip_edges()
	var clean_role := role_filter.strip_edges()
	var sorted_keys := registry.keys()
	sorted_keys.sort_custom(func(a, b):
		var entry_a := registry.get(a, {}) as Dictionary
		var entry_b := registry.get(b, {}) as Dictionary
		var created_a := int(entry_a.get("created_msec", 0))
		var created_b := int(entry_b.get("created_msec", 0))
		if created_a == created_b:
			return str(a) > str(b)
		return created_a > created_b
	)

	var result: Array[Dictionary] = []
	for asset_key in sorted_keys:
		var entry_var: Variant = registry.get(asset_key, {})
		if not (entry_var is Dictionary):
			continue
		var entry: Dictionary = entry_var
		if owner_instance_id > 0 and int(entry.get("owner_instance_id", 0)) != owner_instance_id:
			continue
		if not clean_role.is_empty() and str(entry.get("owner_role_id", "")) != clean_role:
			continue
		if not clean_kind.is_empty() and str(entry.get("kind", "")) != clean_kind:
			continue
		if max_age_msec > 0:
			var created_msec := int(entry.get("created_msec", 0))
			if created_msec <= 0 or Time.get_ticks_msec() - created_msec > max_age_msec:
				continue
		result.append(_sanitize_entry(entry))
	return result

static func find_recent_asset(
	owner: Node = null,
	kind_filter: String = "",
	role_filter: String = "",
	max_age_msec: int = 0
) -> Dictionary:
	var assets := list_assets(owner, kind_filter, role_filter, max_age_msec)
	if assets.is_empty():
		return {}
	return assets[0]

static func snapshot_for_owner(owner: Node) -> Array[Dictionary]:
	return list_assets(owner)

static func _resolve_root(owner: Node) -> Node:
	if owner != null and is_instance_valid(owner):
		var tree := owner.get_tree()
		if tree != null and tree.current_scene != null:
			return tree.current_scene
		return owner
	return null

static func _get_registry(root: Node) -> Dictionary:
	if root == null:
		return {}
	if not root.has_meta(REGISTRY_META_KEY):
		root.set_meta(REGISTRY_META_KEY, {})
	var registry_var: Variant = root.get_meta(REGISTRY_META_KEY, {})
	if registry_var is Dictionary:
		return registry_var as Dictionary
	root.set_meta(REGISTRY_META_KEY, {})
	return root.get_meta(REGISTRY_META_KEY, {}) as Dictionary

static func _prune_registry(registry: Dictionary) -> void:
	var remove_ids: Array[String] = []
	var now_msec := Time.get_ticks_msec()
	for asset_id_var in registry.keys():
		var asset_id := str(asset_id_var)
		var entry_var: Variant = registry.get(asset_id, {})
		if not (entry_var is Dictionary):
			remove_ids.append(asset_id)
			continue

		var entry: Dictionary = entry_var
		var expire_msec := int(entry.get("expire_msec", 0))
		if expire_msec > 0 and now_msec > expire_msec:
			remove_ids.append(asset_id)
			continue

		var node_ref_var: Variant = entry.get("node_ref", null)
		if node_ref_var is WeakRef:
			var node_obj: Variant = (node_ref_var as WeakRef).get_ref()
			if node_obj == null or not is_instance_valid(node_obj):
				remove_ids.append(asset_id)

	for asset_id in remove_ids:
		registry.erase(asset_id)

static func _sanitize_entry(entry: Dictionary) -> Dictionary:
	var copy := entry.duplicate(true)
	copy.erase("node_ref")
	return copy

static func _resolve_role_id(owner: Node) -> String:
	if owner != null and is_instance_valid(owner) and "player_id" in owner:
		return str(owner.get("player_id")).strip_edges()
	return ""
