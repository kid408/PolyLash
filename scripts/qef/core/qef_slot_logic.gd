extends RefCounted
class_name QEFSlotLogic

const QEFModels = preload("res://scripts/qef/core/qef_models.gd")

const RARITY_ORDER := {
	"common": 1,
	"uncommon": 2,
	"rare": 3,
	"epic": 4,
	"legendary": 5,
	"mythic": 6,
}

static func rarity_rank(rarity: String) -> int:
	return int(RARITY_ORDER.get(rarity.strip_edges().to_lower(), 0))

static func normalize_reward(reward_input: Variant) -> Dictionary:
	var reward: Dictionary = {
		"reward_id": "",
		"display_name": "",
		"rarity": "common",
		"reward_kind": QEFModels.REWARD_KIND_CORE,
		"target_slot": QEFModels.TARGET_SLOT_NONE,
		"link_group_id": "",
		"behavior_tags": [],
		"payload": {},
		"payload_e": {},
		"payload_q": {},
		"fallback_utility": {},
	}
	if reward_input is Dictionary:
		reward.merge((reward_input as Dictionary).duplicate(true), true)
	reward["rarity"] = str(reward.get("rarity", "common")).strip_edges().to_lower()
	reward["reward_kind"] = str(reward.get("reward_kind", QEFModels.REWARD_KIND_CORE)).strip_edges().to_lower()
	reward["target_slot"] = str(reward.get("target_slot", QEFModels.TARGET_SLOT_NONE)).strip_edges().to_lower()
	if not (reward.get("payload", {}) is Dictionary):
		reward["payload"] = {}
	if not (reward.get("payload_e", {}) is Dictionary):
		reward["payload_e"] = {}
	if not (reward.get("payload_q", {}) is Dictionary):
		reward["payload_q"] = {}
	if not (reward.get("fallback_utility", {}) is Dictionary):
		reward["fallback_utility"] = {}
	if not (reward.get("behavior_tags", []) is Array):
		reward["behavior_tags"] = []
	return reward

static func apply_reward_to_runtime(runtime_input: Variant, reward_input: Variant, source_pack_id: String = "", window_seq: int = 0) -> Dictionary:
	var runtime: Dictionary = QEFModels.normalize_runtime(runtime_input)
	var reward: Dictionary = normalize_reward(reward_input)
	var target_slot: String = str(reward.get("target_slot", QEFModels.TARGET_SLOT_NONE))
	match target_slot:
		QEFModels.TARGET_SLOT_E:
			_apply_single_slot(runtime, "slot_e", QEFModels.TARGET_SLOT_E, reward, source_pack_id, window_seq)
		QEFModels.TARGET_SLOT_Q_CLOSE:
			_apply_single_slot(runtime, "slot_q", QEFModels.TARGET_SLOT_Q_CLOSE, reward, source_pack_id, window_seq)
		QEFModels.TARGET_SLOT_LINKED:
			_apply_linked_slots(runtime, reward, source_pack_id, window_seq)
		_:
			_apply_utility(runtime, reward)
	runtime["jackpot_linked"] = _has_linked_pair(runtime)
	return runtime

static func consume_slot(runtime_input: Variant, slot_name: String) -> Dictionary:
	var runtime: Dictionary = QEFModels.normalize_runtime(runtime_input)
	var key: String = _resolve_slot_key(slot_name)
	if key.is_empty():
		return {
			"runtime": runtime,
			"consumed": {},
		}
	var target_slot: String = QEFModels.TARGET_SLOT_E if key == "slot_e" else QEFModels.TARGET_SLOT_Q_CLOSE
	var consumed: Dictionary = QEFModels.normalize_slot(runtime.get(key, {}), target_slot)
	runtime[key] = QEFModels.build_default_slot(target_slot)
	runtime["jackpot_linked"] = _has_linked_pair(runtime)
	return {
		"runtime": runtime,
		"consumed": consumed,
	}

static func get_slot(runtime_input: Variant, slot_name: String) -> Dictionary:
	var runtime: Dictionary = QEFModels.normalize_runtime(runtime_input)
	var key: String = _resolve_slot_key(slot_name)
	if key.is_empty():
		return {}
	var target_slot: String = QEFModels.TARGET_SLOT_E if key == "slot_e" else QEFModels.TARGET_SLOT_Q_CLOSE
	return QEFModels.normalize_slot(runtime.get(key, {}), target_slot)

static func _apply_single_slot(runtime: Dictionary, key: String, target_slot: String, reward: Dictionary, source_pack_id: String, window_seq: int) -> void:
	var current_slot: Dictionary = QEFModels.normalize_slot(runtime.get(key, {}), target_slot)
	var next_slot: Dictionary = _build_slot_from_reward(reward, target_slot, source_pack_id, window_seq)
	if _should_replace(current_slot, next_slot):
		runtime[key] = next_slot
		return
	var overflow: Dictionary = reward.get("fallback_utility", {}) if reward.get("fallback_utility", {}) is Dictionary else {}
	if overflow.is_empty():
		overflow = {
			"reward_id": "%s_overflow" % str(reward.get("reward_id", "overflow")),
			"display_name": "溢出补偿",
			"rarity": "common",
			"reward_kind": QEFModels.REWARD_KIND_UTILITY,
			"target_slot": QEFModels.TARGET_SLOT_NONE,
			"payload": {
				"energy_gain": 12.0,
			},
		}
	_apply_utility(runtime, normalize_reward(overflow))

static func _apply_linked_slots(runtime: Dictionary, reward: Dictionary, source_pack_id: String, window_seq: int) -> void:
	var link_group_id: String = str(reward.get("link_group_id", "")).strip_edges()
	if link_group_id.is_empty():
		link_group_id = "%s:%d" % [str(reward.get("reward_id", "linked")), Time.get_ticks_msec()]
	var reward_e: Dictionary = reward.duplicate(true)
	reward_e["target_slot"] = QEFModels.TARGET_SLOT_E
	if reward.get("payload_e", {}) is Dictionary and not (reward.get("payload_e", {}) as Dictionary).is_empty():
		reward_e["payload"] = (reward.get("payload_e", {}) as Dictionary).duplicate(true)
	else:
		reward_e["payload"] = (reward.get("payload", {}) as Dictionary).duplicate(true) if reward.get("payload", {}) is Dictionary else {}
	reward_e["link_group_id"] = link_group_id
	var reward_q: Dictionary = reward.duplicate(true)
	reward_q["target_slot"] = QEFModels.TARGET_SLOT_Q_CLOSE
	if reward.get("payload_q", {}) is Dictionary and not (reward.get("payload_q", {}) as Dictionary).is_empty():
		reward_q["payload"] = (reward.get("payload_q", {}) as Dictionary).duplicate(true)
	else:
		reward_q["payload"] = (reward.get("payload", {}) as Dictionary).duplicate(true) if reward.get("payload", {}) is Dictionary else {}
	reward_q["link_group_id"] = link_group_id
	_apply_single_slot(runtime, "slot_e", QEFModels.TARGET_SLOT_E, normalize_reward(reward_e), source_pack_id, window_seq)
	_apply_single_slot(runtime, "slot_q", QEFModels.TARGET_SLOT_Q_CLOSE, normalize_reward(reward_q), source_pack_id, window_seq)
	runtime["jackpot_linked"] = _has_linked_pair(runtime)

static func _apply_utility(runtime: Dictionary, reward: Dictionary) -> void:
	runtime["utility_buff"] = {
		"reward_id": str(reward.get("reward_id", "")),
		"display_name": str(reward.get("display_name", "")),
		"rarity": str(reward.get("rarity", "common")),
		"reward_kind": QEFModels.REWARD_KIND_UTILITY,
		"target_slot": QEFModels.TARGET_SLOT_NONE,
		"payload": (reward.get("payload", {}) as Dictionary).duplicate(true) if reward.get("payload", {}) is Dictionary else {},
		"granted_at_msec": Time.get_ticks_msec(),
	}
	var history: Array = runtime.get("utility_buff_list", []) if runtime.get("utility_buff_list", []) is Array else []
	history.append((runtime["utility_buff"] as Dictionary).duplicate(true))
	while history.size() > 4:
		history.remove_at(0)
	runtime["utility_buff_list"] = history

static func _build_slot_from_reward(reward: Dictionary, target_slot: String, source_pack_id: String, window_seq: int) -> Dictionary:
	var slot: Dictionary = QEFModels.build_default_slot(target_slot)
	slot["active"] = true
	slot["reward_id"] = str(reward.get("reward_id", ""))
	slot["display_name"] = str(reward.get("display_name", reward.get("reward_id", "")))
	slot["rarity"] = str(reward.get("rarity", "common"))
	slot["reward_kind"] = str(reward.get("reward_kind", QEFModels.REWARD_KIND_CORE))
	slot["target_slot"] = target_slot
	slot["link_group_id"] = str(reward.get("link_group_id", ""))
	slot["behavior_tags"] = (reward.get("behavior_tags", []) as Array).duplicate(true) if reward.get("behavior_tags", []) is Array else []
	slot["payload"] = (reward.get("payload", {}) as Dictionary).duplicate(true) if reward.get("payload", {}) is Dictionary else {}
	slot["source_pack_id"] = source_pack_id
	slot["source_type"] = str(reward.get("source_type", "pack"))
	slot["loaded_window_seq"] = window_seq
	slot["granted_at_msec"] = Time.get_ticks_msec()
	return slot

static func _should_replace(current_slot: Dictionary, next_slot: Dictionary) -> bool:
	if not bool(current_slot.get("active", false)):
		return true
	var current_rank: int = rarity_rank(str(current_slot.get("rarity", "")))
	var next_rank: int = rarity_rank(str(next_slot.get("rarity", "")))
	if next_rank > current_rank:
		return true
	if next_rank < current_rank:
		return false
	return int(next_slot.get("granted_at_msec", 0)) >= int(current_slot.get("granted_at_msec", 0))

static func _has_linked_pair(runtime: Dictionary) -> bool:
	var slot_e: Dictionary = QEFModels.normalize_slot(runtime.get("slot_e", {}), QEFModels.TARGET_SLOT_E)
	var slot_q: Dictionary = QEFModels.normalize_slot(runtime.get("slot_q", {}), QEFModels.TARGET_SLOT_Q_CLOSE)
	if not bool(slot_e.get("active", false)) or not bool(slot_q.get("active", false)):
		return false
	var link_group_id: String = str(slot_e.get("link_group_id", "")).strip_edges()
	if link_group_id.is_empty():
		return false
	return link_group_id == str(slot_q.get("link_group_id", "")).strip_edges()

static func _resolve_slot_key(slot_name: String) -> String:
	var normalized: String = slot_name.strip_edges().to_lower()
	if normalized == "e":
		return "slot_e"
	if normalized == "q" or normalized == "q_close":
		return "slot_q"
	return ""
