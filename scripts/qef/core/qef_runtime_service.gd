extends RefCounted
class_name QEFRuntimeService

const QEFModels = preload("res://scripts/qef/core/qef_models.gd")
const QEFSlotLogic = preload("res://scripts/qef/core/qef_slot_logic.gd")
const RoleSpecRegistry = preload("res://scripts/qef/roles/role_spec_registry.gd")

static func begin_window(owner: Node, role_id: String, mode_name: String, duration: float, runtime_profile: Dictionary = {}) -> Dictionary:
	var player_id: String = _resolve_player_id(owner)
	if player_id.is_empty():
		return {}
	var current: Dictionary = get_runtime(player_id)
	var runtime: Dictionary = QEFModels.build_default_runtime(player_id, role_id, mode_name)
	var profile_window_seq: int = int(runtime_profile.get("window_seq", 0))
	var next_window_seq: int = max(int(current.get("window_seq", 0)) + 1, profile_window_seq)
	runtime["window_seq"] = next_window_seq
	runtime["active"] = true
	runtime["time_left"] = max(0.0, duration)
	runtime["duration"] = max(0.0, duration)
	runtime["mode_name"] = mode_name
	runtime["role_id"] = role_id.strip_edges().to_lower()
	runtime["f_role_id"] = runtime["role_id"]
	runtime["runtime_profile"] = runtime_profile.duplicate(true)
	runtime.merge(runtime_profile.duplicate(true), true)
	_push_runtime(player_id, runtime, owner)
	return runtime

static func sync_skill_profile(owner: Node, runtime_profile: Dictionary) -> Dictionary:
	var player_id: String = _resolve_player_id(owner)
	if player_id.is_empty():
		return {}
	var runtime: Dictionary = get_runtime(player_id)
	if runtime.is_empty():
		runtime = QEFModels.build_default_runtime(player_id)
	runtime["owner_player_id"] = player_id
	runtime["runtime_profile"] = runtime_profile.duplicate(true)
	runtime.merge(runtime_profile.duplicate(true), true)
	if str(runtime.get("role_id", "")).strip_edges().is_empty():
		runtime["role_id"] = str(runtime.get("f_role_id", "")).strip_edges().to_lower()
	_push_runtime(player_id, runtime, owner)
	return runtime

static func end_window(owner_or_id: Variant) -> void:
	var player_id: String = _resolve_player_id(owner_or_id)
	if player_id.is_empty():
		return
	var service := load("res://scripts/qef/services/loot_pack_service.gd")
	if service != null:
		service.clear_player_packs(player_id)
	var runtime: Dictionary = QEFModels.build_default_runtime(player_id)
	_push_runtime(player_id, runtime, _resolve_owner_node(owner_or_id))

static func get_runtime(owner_or_id: Variant) -> Dictionary:
	var player_id: String = _resolve_player_id(owner_or_id)
	if player_id.is_empty() or Global == null or not Global.has_method("get_player_f_runtime"):
		return QEFModels.build_default_runtime(player_id)
	return QEFModels.normalize_runtime(Global.get_player_f_runtime(player_id), player_id)

static func register_pack_spawn(owner_or_id: Variant, pack_payload: Dictionary) -> Dictionary:
	var player_id: String = _resolve_player_id(owner_or_id)
	if player_id.is_empty():
		return {}
	var runtime: Dictionary = get_runtime(player_id)
	var pack_id: String = str(pack_payload.get("pack_id", "")).strip_edges()
	if not pack_id.is_empty():
		var unopened: Array = runtime.get("unopened_pack_ids", []) if runtime.get("unopened_pack_ids", []) is Array else []
		if not unopened.has(pack_id):
			unopened.append(pack_id)
		runtime["unopened_pack_ids"] = unopened
		runtime["unopened_count"] = unopened.size()
	runtime["active_pickup_count"] = max(int(runtime.get("active_pickup_count", 0)), int(runtime.get("unopened_count", 0)))
	_push_runtime(player_id, runtime, _resolve_owner_node(owner_or_id))
	return runtime

static func register_pack_removed(owner_or_id: Variant, pack_id: String) -> Dictionary:
	var player_id: String = _resolve_player_id(owner_or_id)
	if player_id.is_empty():
		return {}
	var runtime: Dictionary = get_runtime(player_id)
	var unopened: Array = runtime.get("unopened_pack_ids", []) if runtime.get("unopened_pack_ids", []) is Array else []
	unopened.erase(pack_id)
	runtime["unopened_pack_ids"] = unopened
	runtime["unopened_count"] = unopened.size()
	runtime["active_pickup_count"] = min(int(runtime.get("active_pickup_count", 0)), runtime["unopened_count"])
	_push_runtime(player_id, runtime, _resolve_owner_node(owner_or_id))
	return runtime

static func clear_unopened_packs(owner_or_id: Variant) -> Dictionary:
	var player_id: String = _resolve_player_id(owner_or_id)
	if player_id.is_empty():
		return {}
	var runtime: Dictionary = get_runtime(player_id)
	runtime["unopened_pack_ids"] = []
	runtime["unopened_count"] = 0
	runtime["active_pickup_count"] = 0
	_push_runtime(player_id, runtime, _resolve_owner_node(owner_or_id))
	return runtime

static func set_active_pickup_count(owner_or_id: Variant, count: int) -> Dictionary:
	var player_id: String = _resolve_player_id(owner_or_id)
	if player_id.is_empty():
		return {}
	var runtime: Dictionary = get_runtime(player_id)
	runtime["active_pickup_count"] = max(0, count)
	_push_runtime(player_id, runtime, _resolve_owner_node(owner_or_id))
	return runtime

static func reveal_pack(owner_or_id: Variant, pack_payload: Dictionary, collector: Node = null) -> Dictionary:
	var player_id: String = _resolve_player_id(owner_or_id)
	if player_id.is_empty():
		return {}
	var runtime: Dictionary = get_runtime(player_id)
	var pack_id: String = str(pack_payload.get("pack_id", "")).strip_edges()
	var unopened: Array = runtime.get("unopened_pack_ids", []) if runtime.get("unopened_pack_ids", []) is Array else []
	unopened.erase(pack_id)
	runtime["unopened_pack_ids"] = unopened
	runtime["unopened_count"] = unopened.size()
	runtime["active_pickup_count"] = max(0, int(runtime.get("active_pickup_count", 0)) - 1)
	var role_id: String = str(pack_payload.get("role_id", runtime.get("role_id", ""))).strip_edges().to_lower()
	var collector_id: String = _resolve_player_id(collector)
	var reward: Dictionary = RoleSpecRegistry.roll_pack_reward(role_id, runtime, pack_payload)
	if reward.is_empty():
		reward = {
			"reward_id": "%s_fallback" % role_id,
			"display_name": "保底补给",
			"rarity": "common",
			"reward_kind": QEFModels.REWARD_KIND_UTILITY,
			"target_slot": QEFModels.TARGET_SLOT_NONE,
			"payload": {"energy_gain": 18.0},
		}
	runtime["opened_pack_count"] = int(runtime.get("opened_pack_count", 0)) + 1
	runtime["last_reward"] = reward.duplicate(true)
	if collector_id == player_id:
		runtime = QEFSlotLogic.apply_reward_to_runtime(runtime, reward, pack_id, int(pack_payload.get("window_seq", runtime.get("window_seq", 0))))
		_apply_immediate_reward_feedback(collector, reward)
	else:
		_apply_off_role_pity(collector)
	_push_runtime(player_id, runtime, _resolve_owner_node(collector))
	return reward

static func apply_reward_direct(owner_or_id: Variant, reward_input: Dictionary, source_pack_id: String = "direct") -> Dictionary:
	var player_id: String = _resolve_player_id(owner_or_id)
	if player_id.is_empty():
		return {}
	var runtime: Dictionary = get_runtime(player_id)
	var reward: Dictionary = QEFSlotLogic.normalize_reward(reward_input)
	runtime = QEFSlotLogic.apply_reward_to_runtime(runtime, reward, source_pack_id, int(runtime.get("window_seq", 0)))
	runtime["last_reward"] = reward.duplicate(true)
	_push_runtime(player_id, runtime, _resolve_owner_node(owner_or_id))
	_apply_immediate_reward_feedback(_resolve_owner_node(owner_or_id), reward)
	return reward

static func on_q_path_executed(owner: Node, is_closed: bool, segment_count: int, polygon_count: int) -> Dictionary:
	if owner == null or not is_instance_valid(owner):
		return {}
	var player_id: String = _resolve_player_id(owner)
	if player_id.is_empty():
		return {}
	var q_context: Dictionary = SkillContextBridge.get_q_context(owner, 5000)
	q_context["is_closed"] = is_closed
	q_context["segment_count"] = segment_count
	q_context["polygon_count"] = polygon_count
	var report: Dictionary = QEFModels.build_q_report(q_context)
	var runtime: Dictionary = get_runtime(player_id)
	if is_closed:
		var slot_result: Dictionary = QEFSlotLogic.consume_slot(runtime, QEFModels.TARGET_SLOT_Q_CLOSE)
		runtime = slot_result.get("runtime", runtime)
		report["consumed_slot"] = slot_result.get("consumed", {})
	runtime["last_q_report"] = report.duplicate(true)
	runtime["line_events"] = int(runtime.get("line_events", 0)) + (0 if is_closed else 1)
	runtime["closure_events"] = int(runtime.get("closure_events", 0)) + (1 if is_closed else 0)
	_push_runtime(player_id, runtime, owner)
	var combo_service := load("res://scripts/qef/services/combo_service.gd")
	if combo_service != null:
		combo_service.register_mark_from_q_report(owner, report)
	return report

static func on_e_result_executed(owner: Node, report_input: Dictionary) -> Dictionary:
	if owner == null or not is_instance_valid(owner):
		return {}
	var player_id: String = _resolve_player_id(owner)
	if player_id.is_empty():
		return {}
	var report: Dictionary = QEFModels.build_e_report(report_input)
	var runtime: Dictionary = get_runtime(player_id)
	var slot_result: Dictionary = QEFSlotLogic.consume_slot(runtime, QEFModels.TARGET_SLOT_E)
	runtime = slot_result.get("runtime", runtime)
	report["consumed_slot"] = slot_result.get("consumed", {})
	runtime["last_e_report"] = report.duplicate(true)
	_push_runtime(player_id, runtime, owner)
	var combo_service := load("res://scripts/qef/services/combo_service.gd")
	if combo_service != null:
		combo_service.register_mark_from_e_report(owner, report)
	return report

static func get_slot(owner_or_id: Variant, slot_name: String) -> Dictionary:
	return QEFSlotLogic.get_slot(get_runtime(owner_or_id), slot_name)

static func get_e_bonus(owner_or_id: Variant) -> Dictionary:
	var slot: Dictionary = get_slot(owner_or_id, QEFModels.TARGET_SLOT_E)
	if not bool(slot.get("active", false)):
		return {}
	return slot.get("payload", {}) if slot.get("payload", {}) is Dictionary else {}

static func get_q_bonus(owner_or_id: Variant, is_closed: bool) -> Dictionary:
	if not is_closed:
		return {}
	var slot: Dictionary = get_slot(owner_or_id, QEFModels.TARGET_SLOT_Q_CLOSE)
	if not bool(slot.get("active", false)):
		return {}
	return slot.get("payload", {}) if slot.get("payload", {}) is Dictionary else {}

static func try_consume_free_cost_target(owner_or_id: Variant, target_slot: String) -> bool:
	var player_id: String = _resolve_player_id(owner_or_id)
	if player_id.is_empty():
		return false
	var runtime: Dictionary = get_runtime(player_id)
	var expire_msec: int = int(runtime.get("pending_free_cost_expire_msec", 0))
	if expire_msec > 0 and Time.get_ticks_msec() > expire_msec:
		runtime["pending_free_cost_target"] = ""
		runtime["pending_free_cost_expire_msec"] = 0
		_push_runtime(player_id, runtime, _resolve_owner_node(owner_or_id))
		return false
	if str(runtime.get("pending_free_cost_target", "")).strip_edges().to_lower() != target_slot.strip_edges().to_lower():
		return false
	runtime["pending_free_cost_target"] = ""
	runtime["pending_free_cost_expire_msec"] = 0
	_push_runtime(player_id, runtime, _resolve_owner_node(owner_or_id))
	return true

static func set_pending_free_cost_target(owner_or_id: Variant, target_slot: String, duration_sec: float = 0.0) -> Dictionary:
	var player_id: String = _resolve_player_id(owner_or_id)
	if player_id.is_empty():
		return {}
	var runtime: Dictionary = get_runtime(player_id)
	runtime["pending_free_cost_target"] = target_slot.strip_edges().to_lower()
	runtime["pending_free_cost_expire_msec"] = 0
	if duration_sec > 0.0:
		runtime["pending_free_cost_expire_msec"] = Time.get_ticks_msec() + int(round(duration_sec * 1000.0))
	_push_runtime(player_id, runtime, _resolve_owner_node(owner_or_id))
	return runtime

static func _apply_immediate_reward_feedback(owner: Node, reward: Dictionary) -> void:
	var player_node := owner as Node2D
	if player_node == null or not is_instance_valid(player_node):
		return
	var payload: Dictionary = reward.get("payload", {}) if reward.get("payload", {}) is Dictionary else {}
	if float(payload.get("energy_gain", 0.0)) > 0.0 and player_node.has_method("gain_energy"):
		player_node.call("gain_energy", float(payload.get("energy_gain", 0.0)))
	if int(payload.get("armor_gain", 0)) > 0 and "armor" in player_node and "max_armor" in player_node:
		player_node.set("armor", min(int(player_node.get("max_armor")), int(player_node.get("armor")) + int(payload.get("armor_gain", 0))))
	if Global != null and Global.has_method("spawn_floating_text"):
		Global.spawn_floating_text(
			player_node.global_position,
			str(reward.get("display_name", reward.get("reward_id", "Pack"))),
			Color(1.0, 0.92, 0.6)
		)

static func _apply_off_role_pity(owner: Node) -> void:
	var player_node := owner as Node2D
	if player_node == null or not is_instance_valid(player_node):
		return
	if player_node.has_method("gain_energy"):
		player_node.call("gain_energy", 10.0)
	if Global != null and Global.has_method("spawn_floating_text"):
		Global.spawn_floating_text(player_node.global_position, "保底回能", Color(0.78, 0.95, 1.0))

static func _push_runtime(player_id: String, runtime_input: Variant, owner: Node = null) -> Dictionary:
	var runtime: Dictionary = QEFModels.normalize_runtime(runtime_input, player_id)
	runtime["owner_player_id"] = player_id
	if Global != null and Global.has_method("set_player_f_runtime"):
		Global.set_player_f_runtime(player_id, runtime)
	if owner != null and is_instance_valid(owner):
		owner.set_meta("f_runtime_profile", runtime.duplicate(true))
	return runtime

static func _resolve_player_id(owner_or_id: Variant) -> String:
	if owner_or_id is String:
		return str(owner_or_id).strip_edges()
	if owner_or_id is Node and is_instance_valid(owner_or_id) and "player_id" in owner_or_id:
		return str(owner_or_id.get("player_id")).strip_edges()
	return ""

static func _resolve_owner_node(owner_or_id: Variant) -> Node:
	if owner_or_id is Node and is_instance_valid(owner_or_id):
		return owner_or_id as Node
	if Global != null and Global.player != null and is_instance_valid(Global.player):
		var player_node: Node = Global.player
		if str(player_node.get("player_id")) == _resolve_player_id(owner_or_id):
			return player_node
	return null
