extends Node

# ============================================================================
# ProgressionManager - 局内成长闭环（XP -> 等级 -> 升级事件）
# ============================================================================

signal progression_changed(level: int, xp_in_level: int, xp_to_next: int, total_xp: int)
signal level_up(level: int, reward_tier: int, total_xp: int)

const DEFAULT_BASE_XP: int = 60
const DEFAULT_LINEAR_XP: int = 24
const DEFAULT_QUAD_XP: float = 3.0
const MAX_LEVEL: int = 60

var _current_level: int = 1
var _xp_in_level: int = 0
var _xp_to_next: int = DEFAULT_BASE_XP
var _total_xp: int = 0
var _suppress_external_sync: bool = false

func _ready() -> void:
	if Global and Global.has_signal("on_session_xp_changed"):
		if not Global.on_session_xp_changed.is_connected(_on_total_xp_changed):
			Global.on_session_xp_changed.connect(_on_total_xp_changed)
	_recalculate_from_total_xp(RunStateService.get_run_xp(), false)

func add_xp(amount: int) -> Dictionary:
	if amount == 0:
		return {
			"applied_xp": 0,
			"level_ups": 0,
			"new_level": _current_level,
			"total_xp": _total_xp
		}

	var old_level := _current_level
	_suppress_external_sync = true
	var applied := RunStateService.add_run_xp(amount)
	_suppress_external_sync = false

	_recalculate_from_total_xp(RunStateService.get_run_xp(), true)

	return {
		"applied_xp": applied,
		"level_ups": max(0, _current_level - old_level),
		"new_level": _current_level,
		"total_xp": _total_xp
	}

func reset_run_progress(sync_total_xp: bool = false) -> void:
	if sync_total_xp:
		RunStateService.set_run_xp(0)
	_recalculate_from_total_xp(RunStateService.get_run_xp(), false)

func recalculate_from_total_xp(total_xp: int, emit_events: bool = false) -> void:
	_recalculate_from_total_xp(total_xp, emit_events)

func get_current_level() -> int:
	return _current_level

func get_total_xp() -> int:
	return _total_xp

func get_xp_in_level() -> int:
	return _xp_in_level

func get_xp_to_next_level() -> int:
	return _xp_to_next

func get_level_progress_ratio() -> float:
	if _xp_to_next <= 0:
		return 1.0
	return clamp(float(_xp_in_level) / float(_xp_to_next), 0.0, 1.0)

func get_reward_tier_for_level(level: int) -> int:
	if level >= 10:
		return 4
	if level >= 7:
		return 3
	if level >= 4:
		return 2
	return 1

func get_xp_required_for_level(level: int) -> int:
	var lv: int = max(1, level) - 1
	var base_xp := int(ConfigManager.get_game_setting("xp_level_base", DEFAULT_BASE_XP))
	var linear_xp := int(ConfigManager.get_game_setting("xp_level_linear", DEFAULT_LINEAR_XP))
	var quad_xp := float(ConfigManager.get_game_setting("xp_level_quad", DEFAULT_QUAD_XP))
	var required := int(round(base_xp + linear_xp * lv + quad_xp * lv * lv))
	return max(20, required)

func _on_total_xp_changed(current: int) -> void:
	if _suppress_external_sync:
		return
	_recalculate_from_total_xp(current, false)

func _recalculate_from_total_xp(total_xp: int, emit_events: bool) -> void:
	var safe_total: int = max(0, total_xp)
	var old_level: int = _current_level

	var remaining: int = safe_total
	var new_level: int = 1
	var need: int = get_xp_required_for_level(new_level)

	while new_level < MAX_LEVEL and remaining >= need:
		remaining -= need
		new_level += 1
		need = get_xp_required_for_level(new_level)

	_total_xp = safe_total
	_current_level = new_level
	_xp_in_level = remaining
	_xp_to_next = 0 if _current_level >= MAX_LEVEL else need

	if emit_events and _current_level > old_level:
		for level in range(old_level + 1, _current_level + 1):
			var reward_tier: int = get_reward_tier_for_level(level)
			level_up.emit(level, reward_tier, _total_xp)
			_emit_level_up_feedback(level)

	progression_changed.emit(_current_level, _xp_in_level, _xp_to_next, _total_xp)

func _emit_level_up_feedback(level: int) -> void:
	SoundManager.play("player_level_up")
	if Global:
		if is_instance_valid(Global.player):
			Global.spawn_floating_text(
				Global.player.global_position + Vector2(0, -46),
				"LEVEL UP! Lv.%d" % level,
				Color(1.25, 1.0, 0.25)
			)
		Global.on_camera_shake.emit(6.0, 0.12)
