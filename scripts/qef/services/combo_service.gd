extends RefCounted
class_name ComboService

const QEFModels = preload("res://scripts/qef/core/qef_models.gd")
const QEFRuntimeService = preload("res://scripts/qef/core/qef_runtime_service.gd")
const RoleSpecRegistry = preload("res://scripts/qef/roles/role_spec_registry.gd")

const WINDOW_SEC: float = 8.0
const COOLDOWN_SEC: float = 18.0
const FREE_CAST_SEC: float = 4.0
const META_KEY := "qef_combo_state"
const MARK_RISK := "risk"
const MARK_PRECISION := "precision"
const MARK_CONVERT := "convert"

static func register_mark(owner: Node, mark_id: String, source: String = "") -> Dictionary:
	if owner == null or not is_instance_valid(owner):
		return {}

	var state: Dictionary = _get_state(owner)
	var normalized: String = _normalize_mark(mark_id)
	if normalized.is_empty():
		return state

	_prune_state(state)
	var marks: Dictionary = state.get("marks", {}) if state.get("marks", {}) is Dictionary else {}
	marks[normalized] = {
		"source": source,
		"timestamp_msec": Time.get_ticks_msec(),
	}
	state["marks"] = marks

	var now_msec: int = Time.get_ticks_msec()
	var certified: bool = _has_all_marks(state) and now_msec >= int(state.get("cooldown_until_msec", 0))
	if certified:
		state["cooldown_until_msec"] = now_msec + int(round(COOLDOWN_SEC * 1000.0))

		var player_id: String = ""
		if "player_id" in owner:
			player_id = str(owner.get("player_id")).strip_edges().to_lower()
		var runtime: Dictionary = QEFRuntimeService.get_runtime(player_id)
		var preferred_slot: String = QEFModels.TARGET_SLOT_E
		var slot_e: Dictionary = runtime.get("slot_e", {}) if runtime.get("slot_e", {}) is Dictionary else {}
		if bool(slot_e.get("active", false)):
			preferred_slot = QEFModels.TARGET_SLOT_Q_CLOSE

		var reward: Dictionary = RoleSpecRegistry.roll_combo_reward(player_id, preferred_slot)
		if not reward.is_empty():
			QEFRuntimeService.apply_reward_direct(owner, reward, "combo")
		QEFRuntimeService.set_pending_free_cost_target(owner, preferred_slot, FREE_CAST_SEC)
		_emit_combo_feedback(owner, preferred_slot)

		(marks as Dictionary).clear()
		state["last_certified_at_msec"] = now_msec
		state["last_target_slot"] = preferred_slot

	_save_state(owner, state)
	state["certified"] = certified
	return state

static func register_mark_from_q_report(owner: Node, report: Dictionary) -> Dictionary:
	if bool(report.get("is_closed", false)):
		return register_mark(owner, MARK_PRECISION, str(report.get("source_kind", "q_closed")))
	return register_mark(owner, MARK_RISK, str(report.get("source_kind", "q_open")))

static func register_mark_from_e_report(owner: Node, report: Dictionary) -> Dictionary:
	var linked_asset: Dictionary = report.get("linked_asset", {}) if report.get("linked_asset", {}) is Dictionary else {}
	var source: String = str(report.get("source_kind", "e_action"))
	if not linked_asset.is_empty():
		source = "%s:%s" % [source, str(linked_asset.get("kind", "asset"))]
	return register_mark(owner, MARK_CONVERT, source)

static func reset(owner: Node) -> void:
	if owner == null or not is_instance_valid(owner):
		return
	owner.remove_meta(META_KEY)

static func _get_state(owner: Node) -> Dictionary:
	if owner.has_meta(META_KEY):
		var raw_state: Variant = owner.get_meta(META_KEY, {})
		if raw_state is Dictionary:
			var state: Dictionary = {
				"marks": {},
				"cooldown_until_msec": 0,
				"last_certified_at_msec": 0,
				"last_target_slot": "",
			}
			state.merge((raw_state as Dictionary).duplicate(true), true)
			if not (state.get("marks", {}) is Dictionary):
				state["marks"] = {}
			return state
	return {
		"marks": {},
		"cooldown_until_msec": 0,
		"last_certified_at_msec": 0,
		"last_target_slot": "",
	}

static func _save_state(owner: Node, state: Dictionary) -> void:
	owner.set_meta(META_KEY, state.duplicate(true))

static func _prune_state(state: Dictionary) -> void:
	var marks: Dictionary = state.get("marks", {}) if state.get("marks", {}) is Dictionary else {}
	var now_msec: int = Time.get_ticks_msec()
	var expired: Array[String] = []
	for key_var in marks.keys():
		var key: String = str(key_var)
		var entry: Dictionary = marks.get(key, {}) if marks.get(key, {}) is Dictionary else {}
		if now_msec - int(entry.get("timestamp_msec", 0)) > int(round(WINDOW_SEC * 1000.0)):
			expired.append(key)
	for key: String in expired:
		marks.erase(key)
	state["marks"] = marks

static func _has_all_marks(state: Dictionary) -> bool:
	var marks: Dictionary = state.get("marks", {}) if state.get("marks", {}) is Dictionary else {}
	return marks.has(MARK_RISK) and marks.has(MARK_PRECISION) and marks.has(MARK_CONVERT)

static func _normalize_mark(mark_id: String) -> String:
	var normalized: String = mark_id.strip_edges().to_lower()
	match normalized:
		"risk", "险印":
			return MARK_RISK
		"precision", "准印":
			return MARK_PRECISION
		"convert", "turn", "转印":
			return MARK_CONVERT
	return ""

static func _emit_combo_feedback(owner: Node, preferred_slot: String) -> void:
	var player_node := owner as Node2D
	if player_node != null and Global != null and Global.has_method("spawn_floating_text"):
		Global.spawn_floating_text(player_node.global_position, "Combo认证", Color(0.72, 1.0, 0.88))

	var hud: Node = _resolve_global_hud(owner)
	if hud == null or not hud.has_method("show_combo_subtitle"):
		return

	var slot_text: String = "E 槽"
	if preferred_slot == QEFModels.TARGET_SLOT_Q_CLOSE:
		slot_text = "Q 闭合槽"
	hud.call(
		"show_combo_subtitle",
		"Combo成立: %s 已装载, %ds 内首拍免耗" % [slot_text, int(FREE_CAST_SEC)],
		Color(0.76, 1.0, 0.9),
		1.8
	)

static func _resolve_global_hud(owner: Node) -> Node:
	var tree: SceneTree = null
	if owner != null and is_instance_valid(owner):
		tree = owner.get_tree()
	if tree == null:
		tree = Engine.get_main_loop() as SceneTree
	if tree == null:
		return null

	var arena: Node = tree.get_first_node_in_group("arena")
	if arena == null or not is_instance_valid(arena):
		return null
	return arena.get("global_hud") if "global_hud" in arena else null
