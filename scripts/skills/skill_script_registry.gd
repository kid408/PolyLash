extends RefCounted
class_name SkillScriptRegistry

const ACTIVE_SKILL_EXACT_DIRS := [
	"res://scripts/skills/entries",
	"res://scenes/skills/players",
]
const ROLE_SKILL_DIR := "res://scripts/skills/roles"
const ULTIMATE_BASE_PATH := "res://scenes/skills/skill_ultimate_base.gd"
const LEGACY_ULTIMATE_DIR := "res://scenes/skills/players/f_roles"

static func resolve_active_skill_script(skill_id: String, slot_name: String = "") -> Script:
	var path: String = resolve_active_skill_script_path(skill_id, slot_name)
	if path.is_empty():
		return null
	return load(path) as Script

static func resolve_active_skill_script_path(skill_id: String, slot_name: String = "") -> String:
	var normalized_id: String = skill_id.strip_edges().to_lower()
	if normalized_id.is_empty():
		return ""
	return _first_existing_path(_build_active_skill_candidates(normalized_id, slot_name))

static func resolve_ultimate_script(player_id: String, ult_config: Dictionary = {}) -> Script:
	var path: String = resolve_ultimate_script_path(player_id, ult_config)
	if path.is_empty():
		return null
	return load(path) as Script

static func resolve_ultimate_script_path(player_id: String, ult_config: Dictionary = {}) -> String:
	var normalized_player_id: String = _normalize_role_id(player_id)
	var candidates: Array[String] = _build_ultimate_candidates(normalized_player_id, ult_config)
	return _first_existing_path(candidates)

static func _build_active_skill_candidates(skill_id: String, slot_name: String) -> Array[String]:
	var candidates: Array[String] = []
	var parsed: Dictionary = _parse_active_skill_id(skill_id, slot_name)
	var role_id: String = str(parsed.get("role_id", "")).strip_edges().to_lower()
	var slot_id: String = str(parsed.get("slot", "")).strip_edges().to_lower()

	if not role_id.is_empty():
		_push_unique(candidates, "%s/%s/%s_%s_skill.gd" % [ROLE_SKILL_DIR, role_id, role_id, slot_id])
		_push_unique(candidates, "%s/%s/%s.gd" % [ROLE_SKILL_DIR, role_id, skill_id])

	for dir_path: String in ACTIVE_SKILL_EXACT_DIRS:
		_push_unique(candidates, "%s/%s.gd" % [dir_path, skill_id])

	return candidates

static func _build_ultimate_candidates(player_id: String, ult_config: Dictionary) -> Array[String]:
	var candidates: Array[String] = []
	var role_ids: Array[String] = []
	_push_unique(role_ids, _normalize_role_id(str(ult_config.get("f_role_id", ""))))
	_push_unique(role_ids, player_id)

	var ult_id: String = str(ult_config.get("ult_id", "")).strip_edges().to_lower()
	if ult_id.ends_with("_ult"):
		_push_unique(role_ids, ult_id.trim_suffix("_ult"))

	for role_id: String in role_ids:
		if role_id.is_empty():
			continue
		_push_unique(candidates, "%s/%s/%s_f_skill.gd" % [ROLE_SKILL_DIR, role_id, role_id])
		_push_unique(candidates, "%s/skill_%s_f.gd" % [LEGACY_ULTIMATE_DIR, role_id])

	_push_unique(candidates, ULTIMATE_BASE_PATH)
	return candidates

static func _parse_active_skill_id(skill_id: String, slot_name: String) -> Dictionary:
	var normalized_id: String = skill_id.strip_edges().to_lower()
	var normalized_slot: String = slot_name.strip_edges().to_lower()
	if normalized_id.is_empty():
		return {}

	if normalized_id.begins_with("skill_"):
		var legacy_body: String = normalized_id.trim_prefix("skill_")
		var legacy_split: Dictionary = _split_role_and_slot(legacy_body)
		if not legacy_split.is_empty():
			return legacy_split

	if normalized_id.ends_with("_skill"):
		var modern_body: String = normalized_id.trim_suffix("_skill")
		var modern_split: Dictionary = _split_role_and_slot(modern_body)
		if not modern_split.is_empty():
			return modern_split

	if not normalized_slot.is_empty():
		var suffix: String = "_%s" % normalized_slot
		if normalized_id.ends_with(suffix):
			var role_id: String = normalized_id.substr(0, normalized_id.length() - suffix.length())
			if not role_id.is_empty():
				return {
					"role_id": role_id,
					"slot": normalized_slot,
				}

	return {}

static func _split_role_and_slot(value: String) -> Dictionary:
	var normalized: String = value.strip_edges().to_lower()
	for slot_id: String in ["q", "e", "lmb", "rmb", "f"]:
		var suffix: String = "_%s" % slot_id
		if not normalized.ends_with(suffix):
			continue
		var role_id: String = normalized.substr(0, normalized.length() - suffix.length())
		if role_id.is_empty():
			return {}
		return {
			"role_id": role_id,
			"slot": slot_id,
		}
	return {}

static func _first_existing_path(candidates: Array[String]) -> String:
	for path: String in candidates:
		if path.is_empty():
			continue
		if FileAccess.file_exists(path):
			return path
	return ""

static func _normalize_role_id(value: String) -> String:
	return value.strip_edges().to_lower()

static func _push_unique(items: Array[String], value: String) -> void:
	var normalized: String = value.strip_edges()
	if normalized.is_empty():
		return
	if items.has(normalized):
		return
	items.append(normalized)
