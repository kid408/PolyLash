extends RefCounted
class_name RunStateService

# ============================================================================
# RunStateService - 局内状态唯一入口（run_gold/run_xp）
# ============================================================================

static var _gold_gain_multiplier: float = 1.0
static var _xp_gain_multiplier: float = 1.0

static func get_run_gold() -> int:
	return DataManager.get_run_gold()

static func set_run_gold(amount: int) -> void:
	DataManager.set_run_gold(amount)

static func add_run_gold(amount: int, count_as_session_gain: bool = false) -> int:
	if amount == 0:
		return 0

	var final_amount := amount
	if amount > 0:
		final_amount = int(round(float(amount) * _gold_gain_multiplier))

	DataManager.add_run_gold(final_amount)
	if count_as_session_gain and final_amount > 0:
		Global.session_gold = max(0, int(Global.session_gold) + final_amount)

	return final_amount

static func spend_run_gold(amount: int) -> bool:
	return DataManager.spend_run_gold(amount)

static func reset_run_gold() -> void:
	DataManager.reset_run_gold()

static func get_run_xp() -> int:
	return int(Global.session_xp)

static func set_run_xp(value: int) -> void:
	Global.session_xp = max(0, value)
	Global.on_session_xp_changed.emit(Global.session_xp)

static func add_run_xp(amount: int) -> int:
	if amount == 0:
		return 0

	var final_amount := amount
	if amount > 0:
		final_amount = int(round(float(amount) * _xp_gain_multiplier))

	Global.session_xp = max(0, int(Global.session_xp) + final_amount)
	Global.on_session_xp_changed.emit(Global.session_xp)
	return final_amount

static func add_session_gold(amount: int) -> void:
	if amount == 0:
		return
	Global.session_gold = max(0, int(Global.session_gold) + amount)

static func set_session_gold(value: int) -> void:
	Global.session_gold = max(0, value)

static func get_session_gold() -> int:
	return int(Global.session_gold)

static func reset_session_state() -> void:
	Global.session_xp = 0
	Global.session_kills = 0
	Global.session_gold = 0
	_gold_gain_multiplier = 1.0
	_xp_gain_multiplier = 1.0
	Global.on_session_xp_changed.emit(Global.session_xp)

static func set_gold_gain_multiplier(multiplier: float) -> void:
	_gold_gain_multiplier = max(0.0, multiplier)

static func set_xp_gain_multiplier(multiplier: float) -> void:
	_xp_gain_multiplier = max(0.0, multiplier)

static func get_gold_gain_multiplier() -> float:
	return _gold_gain_multiplier

static func get_xp_gain_multiplier() -> float:
	return _xp_gain_multiplier
