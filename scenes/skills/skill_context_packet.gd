extends RefCounted
class_name SkillContextPacket

const SCHEMA_VERSION := 1

var schema_version: int = SCHEMA_VERSION
var role_id: String = ""
var skill_slot: String = ""
var skill_id: String = ""
var source_kind: String = ""
var center: Vector2 = Vector2.ZERO
var radius: float = 0.0
var timestamp_msec: int = 0
var is_closed: bool = false
var segment_count: int = 0
var polygon_count: int = 0
var tags: Array[String] = []
var metrics: Dictionary = {}
var payload: Dictionary = {}
var asset_ids: Array[String] = []

static func from_dict(data: Dictionary) -> SkillContextPacket:
	var packet := SkillContextPacket.new()
	packet.schema_version = int(data.get("schema_version", SCHEMA_VERSION))
	packet.role_id = str(data.get("role_id", ""))
	packet.skill_slot = str(data.get("skill_slot", ""))
	packet.skill_id = str(data.get("skill_id", ""))
	packet.source_kind = str(data.get("source_kind", ""))
	packet.center = data.get("center", Vector2.ZERO) if data.get("center", Vector2.ZERO) is Vector2 else Vector2.ZERO
	packet.radius = float(data.get("radius", 0.0))
	packet.timestamp_msec = int(data.get("timestamp_msec", 0))
	packet.is_closed = bool(data.get("is_closed", false))
	packet.segment_count = int(data.get("segment_count", 0))
	packet.polygon_count = int(data.get("polygon_count", 0))

	var raw_tags: Variant = data.get("tags", [])
	if raw_tags is Array:
		for tag_var in raw_tags:
			var tag := str(tag_var).strip_edges().to_lower()
			if tag.is_empty() or packet.tags.has(tag):
				continue
			packet.tags.append(tag)

	var raw_metrics: Variant = data.get("metrics", {})
	if raw_metrics is Dictionary:
		packet.metrics = (raw_metrics as Dictionary).duplicate(true)

	var raw_payload: Variant = data.get("payload", {})
	if raw_payload is Dictionary:
		packet.payload = (raw_payload as Dictionary).duplicate(true)

	var raw_asset_ids: Variant = data.get("asset_ids", [])
	if raw_asset_ids is Array:
		for asset_id_var in raw_asset_ids:
			var asset_id := str(asset_id_var).strip_edges()
			if asset_id.is_empty() or packet.asset_ids.has(asset_id):
				continue
			packet.asset_ids.append(asset_id)

	return packet

func to_dict() -> Dictionary:
	return {
		"schema_version": schema_version,
		"role_id": role_id,
		"skill_slot": skill_slot,
		"skill_id": skill_id,
		"source_kind": source_kind,
		"center": center,
		"radius": radius,
		"timestamp_msec": timestamp_msec,
		"is_closed": is_closed,
		"segment_count": segment_count,
		"polygon_count": polygon_count,
		"tags": tags.duplicate(),
		"metrics": metrics.duplicate(true),
		"payload": payload.duplicate(true),
		"asset_ids": asset_ids.duplicate(),
	}

func duplicate_packet() -> SkillContextPacket:
	return SkillContextPacket.from_dict(to_dict())

func attach_asset(asset_id: String) -> void:
	var clean_id := asset_id.strip_edges()
	if clean_id.is_empty() or asset_ids.has(clean_id):
		return
	asset_ids.append(clean_id)

func is_recent(max_age_msec: int) -> bool:
	if max_age_msec <= 0:
		return true
	if timestamp_msec <= 0:
		return false
	return Time.get_ticks_msec() - timestamp_msec <= max_age_msec

func has_tag(tag: String) -> bool:
	var normalized := tag.strip_edges().to_lower()
	if normalized.is_empty():
		return false
	return tags.has(normalized)
