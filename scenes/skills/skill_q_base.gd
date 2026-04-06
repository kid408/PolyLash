extends SkillDrawingBase
class_name SkillQBase

var q_asset_kind_open: String = ""
var q_asset_kind_closed: String = ""
var q_asset_duration_open: float = 0.0
var q_asset_duration_closed: float = 0.0

func _cache_q_execution_context(
	is_closed_path: bool,
	segment_count: int,
	polygon_count: int,
	center: Vector2,
	radius: float
) -> void:
	super._cache_q_execution_context(is_closed_path, segment_count, polygon_count, center, radius)

	if not is_instance_valid(skill_owner):
		return

	var payload := _build_q_context_payload(is_closed_path, segment_count, polygon_count, center, radius)
	var metrics := {
		"segment_count": max(0, segment_count),
		"polygon_count": max(0, polygon_count),
	}
	var packet := SkillContextBridge.build_packet(
		skill_owner,
		"q",
		skill_id,
		"q_closed" if is_closed_path else "q_open",
		center,
		radius,
		payload,
		metrics,
		_build_q_tags(is_closed_path)
	)
	packet.is_closed = is_closed_path
	packet.segment_count = max(0, segment_count)
	packet.polygon_count = max(0, polygon_count)

	var asset_entry := SkillContextBridge.publish_q_context(
		skill_owner,
		packet,
		_get_q_asset_kind(is_closed_path),
		_get_q_asset_duration(is_closed_path),
		_build_q_asset_payload(is_closed_path, segment_count, polygon_count, center, radius)
	)
	_on_q_context_published(packet.to_dict(), asset_entry)

func get_recent_q_context(max_age_msec: int = 0) -> Dictionary:
	return SkillContextBridge.get_q_context(skill_owner, max_age_msec)

func get_recent_q_assets(kind_filter: String = "", max_age_msec: int = 0) -> Array[Dictionary]:
	return SkillContextBridge.get_q_assets(skill_owner, kind_filter, max_age_msec)

func _get_q_asset_kind(is_closed_path: bool) -> String:
	if is_closed_path and not q_asset_kind_closed.is_empty():
		return q_asset_kind_closed
	if not is_closed_path and not q_asset_kind_open.is_empty():
		return q_asset_kind_open

	var role_id := _resolve_role_id()
	if role_id.is_empty():
		role_id = skill_id.trim_prefix("skill_").trim_suffix("_q")
	if role_id.is_empty():
		role_id = "skill"
	return "%s_%s" % [role_id, "closure" if is_closed_path else "line"]

func _get_q_asset_duration(is_closed_path: bool) -> float:
	if is_closed_path and q_asset_duration_closed > 0.0:
		return q_asset_duration_closed
	if not is_closed_path and q_asset_duration_open > 0.0:
		return q_asset_duration_open
	return max(1.0, base_line_duration)

func _build_q_context_payload(
	is_closed_path: bool,
	segment_count: int,
	polygon_count: int,
	center: Vector2,
	radius: float
) -> Dictionary:
	return {
		"role_id": _resolve_role_id(),
		"is_closed": is_closed_path,
		"segment_count": max(0, segment_count),
		"polygon_count": max(0, polygon_count),
		"center": center,
		"radius": radius,
	}

func _build_q_asset_payload(
	is_closed_path: bool,
	segment_count: int,
	polygon_count: int,
	center: Vector2,
	radius: float
) -> Dictionary:
	var payload := _build_q_context_payload(is_closed_path, segment_count, polygon_count, center, radius)
	payload.merge(_get_pending_q_asset_payload(is_closed_path), true)
	return payload

func _build_q_tags(is_closed_path: bool) -> Array[String]:
	var tags: Array[String] = ["q", _resolve_role_id()]
	if is_closed_path:
		tags.append("closed")
	else:
		tags.append("open")
	return tags

func _on_q_context_published(_packet: Dictionary, _asset_entry: Dictionary) -> void:
	pass

func _resolve_role_id() -> String:
	if is_instance_valid(skill_owner) and "player_id" in skill_owner:
		return str(skill_owner.get("player_id")).strip_edges()
	if skill_id.begins_with("skill_"):
		var base_id := skill_id.trim_prefix("skill_")
		if base_id.ends_with("_q"):
			base_id = base_id.substr(0, base_id.length() - 2)
		return base_id
	return ""
