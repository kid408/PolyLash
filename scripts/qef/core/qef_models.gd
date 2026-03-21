extends RefCounted
class_name QEFModels

const TARGET_SLOT_E := "e"
const TARGET_SLOT_Q_CLOSE := "q_close"
const TARGET_SLOT_LINKED := "linked"
const TARGET_SLOT_NONE := "none"

const REWARD_KIND_CORE := "core"
const REWARD_KIND_UTILITY := "utility"
const REWARD_KIND_JACKPOT := "jackpot"

static func build_default_slot(target_slot: String = "") -> Dictionary:
	return {
		"active": false,
		"reward_id": "",
		"display_name": "",
		"rarity": "",
		"reward_kind": "",
		"target_slot": target_slot.strip_edges().to_lower(),
		"link_group_id": "",
		"behavior_tags": [],
		"payload": {},
		"source_pack_id": "",
		"source_type": "",
		"loaded_window_seq": 0,
		"granted_at_msec": 0,
	}

static func build_default_runtime(player_id: String = "", role_id: String = "", mode_name: String = "") -> Dictionary:
	return {
		"owner_player_id": player_id,
		"role_id": role_id,
		"active": false,
		"time_left": 0.0,
		"duration": 0.0,
		"window_seq": 0,
		"mode_name": mode_name,
		"f_role_id": role_id,
		"ult_id": "",
		"q_line_amp": 1.0,
		"q_closure_amp": 1.0,
		"internal_cd": 0.0,
		"special_1": 0.0,
		"special_2": 0.0,
		"special_3": 0.0,
		"line_events": 0,
		"closure_events": 0,
		"tick_events": 0,
		"active_pickup_count": 0,
		"unopened_pack_ids": [],
		"unopened_count": 0,
		"opened_pack_count": 0,
		"slot_e": build_default_slot(TARGET_SLOT_E),
		"slot_q": build_default_slot(TARGET_SLOT_Q_CLOSE),
		"utility_buff": {},
		"utility_buff_list": [],
		"jackpot_linked": false,
		"pending_free_cost_target": "",
		"pending_free_cost_expire_msec": 0,
		"runtime_profile": {},
		"last_q_report": {},
		"last_e_report": {},
		"last_reward": {},
	}

static func normalize_slot(slot_input: Variant, target_slot: String = "") -> Dictionary:
	var slot: Dictionary = build_default_slot(target_slot)
	if slot_input is Dictionary:
		slot.merge((slot_input as Dictionary).duplicate(true), true)
	if str(slot.get("target_slot", "")).strip_edges().is_empty():
		slot["target_slot"] = target_slot.strip_edges().to_lower()
	return slot

static func normalize_runtime(runtime_input: Variant, player_id: String = "") -> Dictionary:
	var runtime: Dictionary = build_default_runtime(player_id)
	if runtime_input is Dictionary:
		runtime.merge((runtime_input as Dictionary).duplicate(true), true)
	var owner_player_id: String = str(runtime.get("owner_player_id", player_id)).strip_edges()
	if owner_player_id.is_empty():
		owner_player_id = player_id
	runtime["owner_player_id"] = owner_player_id
	runtime["role_id"] = str(runtime.get("role_id", runtime.get("f_role_id", ""))).strip_edges().to_lower()
	runtime["f_role_id"] = str(runtime.get("f_role_id", runtime.get("role_id", ""))).strip_edges().to_lower()
	runtime["slot_e"] = normalize_slot(runtime.get("slot_e", {}), TARGET_SLOT_E)
	runtime["slot_q"] = normalize_slot(runtime.get("slot_q", {}), TARGET_SLOT_Q_CLOSE)
	if not (runtime.get("unopened_pack_ids", []) is Array):
		runtime["unopened_pack_ids"] = []
	if not (runtime.get("utility_buff_list", []) is Array):
		runtime["utility_buff_list"] = []
	if not (runtime.get("runtime_profile", {}) is Dictionary):
		runtime["runtime_profile"] = {}
	if not (runtime.get("last_q_report", {}) is Dictionary):
		runtime["last_q_report"] = {}
	if not (runtime.get("last_e_report", {}) is Dictionary):
		runtime["last_e_report"] = {}
	if not (runtime.get("last_reward", {}) is Dictionary):
		runtime["last_reward"] = {}
	runtime["pending_free_cost_expire_msec"] = int(runtime.get("pending_free_cost_expire_msec", 0))
	var unopened_pack_ids: Array = runtime.get("unopened_pack_ids", [])
	runtime["unopened_count"] = unopened_pack_ids.size()
	runtime["jackpot_linked"] = bool(runtime.get("jackpot_linked", false))
	return runtime

static func build_q_report(packet_input: Variant, asset_entry: Dictionary = {}) -> Dictionary:
	var packet: Dictionary = packet_input.duplicate(true) if packet_input is Dictionary else {}
	return {
		"report_type": "q",
		"timestamp_msec": Time.get_ticks_msec(),
		"role_id": str(packet.get("role_id", "")).strip_edges().to_lower(),
		"skill_id": str(packet.get("skill_id", "")).strip_edges(),
		"source_kind": str(packet.get("source_kind", "q")).strip_edges().to_lower(),
		"is_closed": bool(packet.get("is_closed", false)),
		"segment_count": int(packet.get("segment_count", 0)),
		"polygon_count": int(packet.get("polygon_count", 0)),
		"center": packet.get("center", Vector2.ZERO),
		"radius": float(packet.get("radius", 0.0)),
		"payload": packet.get("payload", {}) if packet.get("payload", {}) is Dictionary else {},
		"metrics": packet.get("metrics", {}) if packet.get("metrics", {}) is Dictionary else {},
		"linked_asset": asset_entry.duplicate(true),
		"carrier_points": _extract_carrier_points(packet, asset_entry),
		"consumed_slot": {},
	}

static func build_e_report(packet_input: Variant, asset_entry: Dictionary = {}) -> Dictionary:
	var packet: Dictionary = packet_input.duplicate(true) if packet_input is Dictionary else {}
	return {
		"report_type": "e",
		"timestamp_msec": Time.get_ticks_msec(),
		"role_id": str(packet.get("role_id", "")).strip_edges().to_lower(),
		"skill_id": str(packet.get("skill_id", "")).strip_edges(),
		"source_kind": str(packet.get("source_kind", "e")).strip_edges().to_lower(),
		"center": packet.get("center", Vector2.ZERO),
		"radius": float(packet.get("radius", 0.0)),
		"payload": packet.get("payload", {}) if packet.get("payload", {}) is Dictionary else {},
		"linked_asset": asset_entry.duplicate(true),
		"carrier_points": _extract_carrier_points(packet, asset_entry),
		"consumed_slot": {},
	}

static func build_pack_payload(
	pack_id: String,
	owner_player_id: String,
	role_id: String,
	window_seq: int,
	spawn_source: String,
	world_pos: Vector2,
	reward_hint: Dictionary = {}
) -> Dictionary:
	return {
		"pack_id": pack_id,
		"owner_player_id": owner_player_id,
		"role_id": role_id,
		"window_seq": window_seq,
		"spawn_source": spawn_source,
		"reward_hint": reward_hint.duplicate(true),
		"rarity": str(reward_hint.get("rarity", "")).strip_edges().to_lower(),
		"world_pos": world_pos,
		"source_world_pos": reward_hint.get("source_world_pos", world_pos),
		"spawned_msec": Time.get_ticks_msec(),
	}

static func _extract_carrier_points(packet: Dictionary, asset_entry: Dictionary) -> Array:
	var result: Array = []
	var payload_var: Variant = packet.get("payload", {})
	if payload_var is Dictionary:
		var payload: Dictionary = payload_var
		var carriers_var: Variant = payload.get("carrier_points", [])
		if carriers_var is Array:
			for point_var in carriers_var:
				if point_var is Vector2:
					result.append(point_var)
	var center_var: Variant = packet.get("center", Vector2.ZERO)
	if result.is_empty() and center_var is Vector2:
		result.append(center_var)
	var asset_center_var: Variant = asset_entry.get("center", null)
	if asset_center_var is Vector2 and not result.has(asset_center_var):
		result.append(asset_center_var)
	return result
