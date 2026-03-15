extends RefCounted
class_name SkillContextBridge

const META_Q_CONTEXT := "skill_ctx_q_last"
const META_E_CONTEXT := "skill_ctx_e_last"
const META_F_CONTEXT := "skill_ctx_f_last"

const LEGACY_Q_CENTER := "q_ctx_last_center"
const LEGACY_Q_RADIUS := "q_ctx_last_radius"
const LEGACY_Q_TIME_MSEC := "q_ctx_last_time_msec"
const LEGACY_Q_CLOSED := "q_ctx_last_closed"
const LEGACY_Q_SEGMENTS := "q_ctx_last_segments"
const LEGACY_Q_POLYGONS := "q_ctx_last_polygons"
const LEGACY_Q_PROTO_CENTER := "q_proto_last_center"
const LEGACY_Q_PROTO_RADIUS := "q_proto_last_radius"
const LEGACY_Q_PROTO_TIME_MSEC := "q_proto_last_time_msec"

static func build_packet(
	owner: Node,
	skill_slot: String,
	skill_id: String,
	source_kind: String,
	center: Vector2,
	radius: float,
	payload: Dictionary = {},
	metrics: Dictionary = {},
	tags: Array[String] = []
) -> SkillContextPacket:
	var packet := SkillContextPacket.new()
	packet.role_id = _resolve_role_id(owner, skill_id)
	packet.skill_slot = skill_slot.strip_edges().to_lower()
	packet.skill_id = skill_id.strip_edges()
	packet.source_kind = source_kind.strip_edges().to_lower()
	packet.center = center
	packet.radius = max(0.0, radius)
	packet.timestamp_msec = Time.get_ticks_msec()
	packet.payload = payload.duplicate(true)
	packet.metrics = metrics.duplicate(true)

	for tag_var in tags:
		var tag := str(tag_var).strip_edges().to_lower()
		if tag.is_empty() or packet.tags.has(tag):
			continue
		packet.tags.append(tag)

	if not packet.skill_slot.is_empty() and not packet.tags.has(packet.skill_slot):
		packet.tags.append(packet.skill_slot)

	return packet

static func publish_q_context(
	owner: Node,
	packet_input: Variant,
	asset_kind: String = "",
	asset_duration_sec: float = 0.0,
	asset_payload: Dictionary = {},
	asset_node: Node = null
) -> Dictionary:
	var packet := _ensure_packet(packet_input)
	if packet == null:
		return {}

	var asset_entry: Dictionary = {}
	if not asset_kind.strip_edges().is_empty():
		asset_entry = SkillAssetRegistry.register_asset(
			owner,
			asset_kind,
			packet.center,
			packet.radius,
			asset_payload,
			asset_duration_sec,
			asset_node
		)
		var asset_id := str(asset_entry.get("asset_id", ""))
		if not asset_id.is_empty():
			packet.attach_asset(asset_id)

	_publish_packet(owner, META_Q_CONTEXT, packet)
	_publish_legacy_q_meta(owner, packet)
	return asset_entry

static func publish_e_context(
	owner: Node,
	packet_input: Variant,
	asset_kind: String = "",
	asset_duration_sec: float = 0.0,
	asset_payload: Dictionary = {},
	asset_node: Node = null
) -> Dictionary:
	return _publish_generic_context(owner, META_E_CONTEXT, packet_input, asset_kind, asset_duration_sec, asset_payload, asset_node)

static func publish_f_context(
	owner: Node,
	packet_input: Variant,
	asset_kind: String = "",
	asset_duration_sec: float = 0.0,
	asset_payload: Dictionary = {},
	asset_node: Node = null
) -> Dictionary:
	return _publish_generic_context(owner, META_F_CONTEXT, packet_input, asset_kind, asset_duration_sec, asset_payload, asset_node)

static func get_q_context(owner: Node, max_age_msec: int = 0) -> Dictionary:
	var packet := _read_packet(owner, META_Q_CONTEXT)
	if packet == null:
		packet = _read_legacy_q_packet(owner)
	if packet == null:
		return {}
	if max_age_msec > 0 and not packet.is_recent(max_age_msec):
		return {}
	return packet.to_dict()

static func get_e_context(owner: Node, max_age_msec: int = 0) -> Dictionary:
	return _read_context_dict(owner, META_E_CONTEXT, max_age_msec)

static func get_f_context(owner: Node, max_age_msec: int = 0) -> Dictionary:
	return _read_context_dict(owner, META_F_CONTEXT, max_age_msec)

static func get_q_assets(owner: Node, kind_filter: String = "", max_age_msec: int = 0) -> Array[Dictionary]:
	return _get_linked_assets(owner, META_Q_CONTEXT, kind_filter, max_age_msec)

static func get_recent_q_asset(owner: Node, kind_filter: String = "", max_age_msec: int = 0) -> Dictionary:
	var assets := get_q_assets(owner, kind_filter, max_age_msec)
	if assets.is_empty():
		return {}
	return assets[0]

static func get_e_assets(owner: Node, kind_filter: String = "", max_age_msec: int = 0) -> Array[Dictionary]:
	return _get_linked_assets(owner, META_E_CONTEXT, kind_filter, max_age_msec)

static func get_recent_e_asset(owner: Node, kind_filter: String = "", max_age_msec: int = 0) -> Dictionary:
	var assets := get_e_assets(owner, kind_filter, max_age_msec)
	if assets.is_empty():
		return {}
	return assets[0]

static func get_f_assets(owner: Node, kind_filter: String = "", max_age_msec: int = 0) -> Array[Dictionary]:
	return _get_linked_assets(owner, META_F_CONTEXT, kind_filter, max_age_msec)

static func get_recent_f_asset(owner: Node, kind_filter: String = "", max_age_msec: int = 0) -> Dictionary:
	var assets := get_f_assets(owner, kind_filter, max_age_msec)
	if assets.is_empty():
		return {}
	return assets[0]

static func snapshot_owner(owner: Node) -> Dictionary:
	return {
		"q_context": get_q_context(owner),
		"e_context": get_e_context(owner),
		"f_context": get_f_context(owner),
		"assets": SkillAssetRegistry.snapshot_for_owner(owner),
	}

static func _publish_generic_context(
	owner: Node,
	meta_key: String,
	packet_input: Variant,
	asset_kind: String,
	asset_duration_sec: float,
	asset_payload: Dictionary,
	asset_node: Node
) -> Dictionary:
	var packet := _ensure_packet(packet_input)
	if packet == null:
		return {}

	var asset_entry: Dictionary = {}
	if not asset_kind.strip_edges().is_empty():
		asset_entry = SkillAssetRegistry.register_asset(
			owner,
			asset_kind,
			packet.center,
			packet.radius,
			asset_payload,
			asset_duration_sec,
			asset_node
		)
		var asset_id := str(asset_entry.get("asset_id", ""))
		if not asset_id.is_empty():
			packet.attach_asset(asset_id)

	_publish_packet(owner, meta_key, packet)
	return asset_entry

static func _get_linked_assets(owner: Node, meta_key: String, kind_filter: String = "", max_age_msec: int = 0) -> Array[Dictionary]:
	var packet := _read_packet(owner, meta_key)
	if packet != null and not packet.asset_ids.is_empty():
		var assets: Array[Dictionary] = []
		for asset_id in packet.asset_ids:
			var entry := SkillAssetRegistry.get_asset_by_id(owner, asset_id)
			if entry.is_empty():
				continue
			if not kind_filter.strip_edges().is_empty() and str(entry.get("kind", "")) != kind_filter:
				continue
			if max_age_msec > 0:
				var created_msec := int(entry.get("created_msec", 0))
				if created_msec <= 0 or Time.get_ticks_msec() - created_msec > max_age_msec:
					continue
			assets.append(entry)
		if not assets.is_empty():
			return assets

	return SkillAssetRegistry.list_assets(owner, kind_filter, "", max_age_msec)

static func _read_context_dict(owner: Node, meta_key: String, max_age_msec: int = 0) -> Dictionary:
	var packet := _read_packet(owner, meta_key)
	if packet == null:
		return {}
	if max_age_msec > 0 and not packet.is_recent(max_age_msec):
		return {}
	return packet.to_dict()

static func _publish_packet(owner: Node, meta_key: String, packet: SkillContextPacket) -> void:
	if owner == null or not is_instance_valid(owner):
		return
	owner.set_meta(meta_key, packet.to_dict())

static func _read_packet(owner: Node, meta_key: String) -> SkillContextPacket:
	if owner == null or not is_instance_valid(owner):
		return null
	if not owner.has_meta(meta_key):
		return null
	var packet_var: Variant = owner.get_meta(meta_key, {})
	if packet_var is Dictionary:
		return SkillContextPacket.from_dict(packet_var as Dictionary)
	return null

static func _read_legacy_q_packet(owner: Node) -> SkillContextPacket:
	if owner == null or not is_instance_valid(owner):
		return null
	if not owner.has_meta(LEGACY_Q_CENTER):
		return null

	var center_var: Variant = owner.get_meta(LEGACY_Q_CENTER, Vector2.ZERO)
	if not (center_var is Vector2):
		return null

	var packet := SkillContextPacket.new()
	packet.role_id = _resolve_role_id(owner, "")
	packet.skill_slot = "q"
	packet.skill_id = ""
	packet.source_kind = "q_legacy"
	packet.center = center_var
	packet.radius = float(owner.get_meta(LEGACY_Q_RADIUS, 0.0))
	packet.timestamp_msec = int(owner.get_meta(LEGACY_Q_TIME_MSEC, 0))
	packet.is_closed = bool(owner.get_meta(LEGACY_Q_CLOSED, false))
	packet.segment_count = int(owner.get_meta(LEGACY_Q_SEGMENTS, 0))
	packet.polygon_count = int(owner.get_meta(LEGACY_Q_POLYGONS, 0))
	packet.tags = ["q", "legacy"]
	return packet

static func _publish_legacy_q_meta(owner: Node, packet: SkillContextPacket) -> void:
	if owner == null or not is_instance_valid(owner):
		return
	owner.set_meta(LEGACY_Q_CENTER, packet.center)
	owner.set_meta(LEGACY_Q_RADIUS, packet.radius)
	owner.set_meta(LEGACY_Q_TIME_MSEC, packet.timestamp_msec)
	owner.set_meta(LEGACY_Q_CLOSED, packet.is_closed)
	owner.set_meta(LEGACY_Q_SEGMENTS, packet.segment_count)
	owner.set_meta(LEGACY_Q_POLYGONS, packet.polygon_count)
	owner.set_meta(LEGACY_Q_PROTO_CENTER, packet.center)
	owner.set_meta(LEGACY_Q_PROTO_RADIUS, packet.radius)
	owner.set_meta(LEGACY_Q_PROTO_TIME_MSEC, packet.timestamp_msec)

static func _ensure_packet(packet_input: Variant) -> SkillContextPacket:
	if packet_input is SkillContextPacket:
		return packet_input as SkillContextPacket
	if packet_input is Dictionary:
		return SkillContextPacket.from_dict(packet_input as Dictionary)
	return null

static func _resolve_role_id(owner: Node, skill_id: String) -> String:
	if owner != null and is_instance_valid(owner) and "player_id" in owner:
		return str(owner.get("player_id")).strip_edges()
	var clean_skill_id := skill_id.strip_edges()
	if clean_skill_id.begins_with("skill_"):
		clean_skill_id = clean_skill_id.trim_prefix("skill_")
	if clean_skill_id.ends_with("_q") or clean_skill_id.ends_with("_e") or clean_skill_id.ends_with("_f"):
		clean_skill_id = clean_skill_id.substr(0, clean_skill_id.length() - 2)
	return clean_skill_id
