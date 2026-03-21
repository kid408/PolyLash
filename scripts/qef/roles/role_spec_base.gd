extends RefCounted
class_name RoleSpecBase

const QEFModels = preload("res://scripts/qef/core/qef_models.gd")

var spec: Dictionary = {}

func get_spec() -> Dictionary:
	return spec.duplicate(true)

func get_role_id() -> String:
	return str(spec.get("role_id", "")).strip_edges().to_lower()

func get_reward_by_id(reward_id: String) -> Dictionary:
	if reward_id.strip_edges().is_empty():
		return {}
	for reward in get_all_rewards():
		if str(reward.get("reward_id", "")).strip_edges() == reward_id.strip_edges():
			return reward.duplicate(true)
	return {}

func get_all_rewards() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var f_spec: Dictionary = spec.get("f", {}) if spec.get("f", {}) is Dictionary else {}
	for key in ["core_pool", "utility_pool", "jackpot_pool"]:
		var pool_var: Variant = f_spec.get(key, [])
		if not (pool_var is Array):
			continue
		for reward_var in pool_var:
			if reward_var is Dictionary:
				result.append((reward_var as Dictionary).duplicate(true))
	return result

func roll_pack_reward(runtime: Dictionary, _pack_payload: Dictionary = {}) -> Dictionary:
	var f_spec: Dictionary = spec.get("f", {}) if spec.get("f", {}) is Dictionary else {}
	var first_reward_id: String = str(f_spec.get("first_pack_reward_id", "")).strip_edges()
	var opened_count: int = int(runtime.get("opened_pack_count", 0))
	if opened_count <= 0 and not first_reward_id.is_empty():
		var first_reward: Dictionary = get_reward_by_id(first_reward_id)
		if not first_reward.is_empty():
			return first_reward

	var jackpot_pool: Array = f_spec.get("jackpot_pool", []) if f_spec.get("jackpot_pool", []) is Array else []
	var utility_pool: Array = f_spec.get("utility_pool", []) if f_spec.get("utility_pool", []) is Array else []
	var core_pool: Array = f_spec.get("core_pool", []) if f_spec.get("core_pool", []) is Array else []
	var jackpot_chance: float = clamp(float(f_spec.get("jackpot_chance", 0.08)), 0.0, 1.0)
	if not jackpot_pool.is_empty() and randf() <= jackpot_chance:
		return _pick_random_reward(jackpot_pool)
	var mixed: Array = []
	mixed.append_array(core_pool)
	mixed.append_array(utility_pool)
	if mixed.is_empty():
		return _build_fallback_utility()
	return _pick_random_reward(mixed)

func roll_combo_reward(preferred_slot: String = QEFModels.TARGET_SLOT_E) -> Dictionary:
	var f_spec: Dictionary = spec.get("f", {}) if spec.get("f", {}) is Dictionary else {}
	var core_pool: Array = f_spec.get("core_pool", []) if f_spec.get("core_pool", []) is Array else []
	for reward_var in core_pool:
		if not (reward_var is Dictionary):
			continue
		var reward: Dictionary = reward_var
		if str(reward.get("target_slot", "")).strip_edges().to_lower() == preferred_slot:
			return reward.duplicate(true)
	if preferred_slot != QEFModels.TARGET_SLOT_Q_CLOSE:
		return roll_combo_reward(QEFModels.TARGET_SLOT_Q_CLOSE)
	return _build_fallback_utility()

func build_base_spec(
	role_id: String,
	display_name: String,
	mode_name: String,
	timing: Dictionary,
	energy: Dictionary
) -> Dictionary:
	return {
		"role_id": role_id.strip_edges().to_lower(),
		"display_name": display_name,
		"mode_name": mode_name,
		"timing": timing.duplicate(true),
		"energy": energy.duplicate(true),
		"q_open": {},
		"q_close": {},
		"e": {},
		"dash_link": {},
		"f": {
			"pack_sources": [],
			"pickup_hint": {},
			"first_pack_reward_id": "",
			"jackpot_chance": 0.08,
			"core_pool": [],
			"utility_pool": [],
			"jackpot_pool": [],
		},
	}

func build_core_reward(
	reward_id: String,
	display_name: String,
	target_slot: String,
	payload: Dictionary,
	rarity: String = "rare",
	behavior_tags: Array = []
) -> Dictionary:
	return {
		"reward_id": reward_id,
		"display_name": display_name,
		"rarity": rarity,
		"reward_kind": QEFModels.REWARD_KIND_CORE,
		"target_slot": target_slot,
		"behavior_tags": behavior_tags.duplicate(true),
		"payload": payload.duplicate(true),
	}

func build_utility_reward(
	reward_id: String,
	display_name: String,
	payload: Dictionary,
	rarity: String = "common",
	behavior_tags: Array = []
) -> Dictionary:
	return {
		"reward_id": reward_id,
		"display_name": display_name,
		"rarity": rarity,
		"reward_kind": QEFModels.REWARD_KIND_UTILITY,
		"target_slot": QEFModels.TARGET_SLOT_NONE,
		"behavior_tags": behavior_tags.duplicate(true),
		"payload": payload.duplicate(true),
	}

func build_linked_reward(
	reward_id: String,
	display_name: String,
	payload_e: Dictionary,
	payload_q: Dictionary,
	rarity: String = "legendary",
	behavior_tags: Array = []
) -> Dictionary:
	return {
		"reward_id": reward_id,
		"display_name": display_name,
		"rarity": rarity,
		"reward_kind": QEFModels.REWARD_KIND_JACKPOT,
		"target_slot": QEFModels.TARGET_SLOT_LINKED,
		"behavior_tags": behavior_tags.duplicate(true),
		"payload_e": payload_e.duplicate(true),
		"payload_q": payload_q.duplicate(true),
	}

func _pick_random_reward(pool: Array) -> Dictionary:
	if pool.is_empty():
		return _build_fallback_utility()
	var picked_var: Variant = pool[randi() % pool.size()]
	if picked_var is Dictionary:
		return (picked_var as Dictionary).duplicate(true)
	return _build_fallback_utility()

func _build_fallback_utility() -> Dictionary:
	return build_utility_reward(
		"%s_fallback_utility" % get_role_id(),
		"保底补给",
		{
			"energy_gain": 18.0,
		}
	)
