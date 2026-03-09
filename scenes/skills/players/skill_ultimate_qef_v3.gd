extends SkillUltimate
class_name SkillUltimateQEFV3

const MIN_TICK_INTERVAL: float = 0.25
const DEFAULT_TARGET_CAP: int = 8

const LINE_PROFILES := {
	"butcher": {"damage_mul": 1.18, "radius_mul": 0.90, "status": "marked", "status_duration": 1.6, "status_value": 0.20, "knockback": 145.0, "max_targets": 10, "util_damage_scale": 0.20},
	"weaver": {"damage_mul": 0.90, "radius_mul": 1.05, "status": "slow", "status_duration": 2.2, "status_value": 0.34, "max_targets": 10, "util_status_scale": 0.10},
	"herder": {"damage_mul": 1.00, "radius_mul": 1.00, "status": "marked", "status_duration": 1.8, "status_value": 0.18, "knockback": 180.0, "max_targets": 12},
	"pyro": {"damage_mul": 1.12, "radius_mul": 0.95, "status": "burn", "status_duration": 3.2, "status_value": 0.30, "status_tick": 0.6, "max_targets": 9},
	"wind": {"damage_mul": 0.96, "radius_mul": 1.15, "status": "slow", "status_duration": 1.9, "status_value": 0.28, "pull": 22.0, "max_targets": 9},
	"sapper": {"damage_mul": 1.05, "radius_mul": 0.96, "status": "marked", "status_duration": 1.7, "status_value": 0.22, "max_targets": 11},
	"glacier": {"damage_mul": 0.96, "radius_mul": 1.02, "status": "slow", "status_duration": 2.4, "status_value": 0.38, "max_targets": 9},
	"tesla": {"damage_mul": 1.02, "radius_mul": 1.00, "status": "marked", "status_duration": 1.8, "status_value": 0.22, "status_stacks": 1, "max_targets": 10},
	"new_pyro": {"damage_mul": 1.10, "radius_mul": 0.98, "status": "burn", "status_duration": 3.0, "status_value": 0.33, "status_tick": 0.55, "max_targets": 9},
	"plague": {"damage_mul": 0.92, "radius_mul": 1.08, "status": "poison", "status_duration": 3.4, "status_value": 0.28, "status_tick": 0.7, "status_stacks": 2, "max_targets": 10},
	"jailer": {"damage_mul": 0.94, "radius_mul": 1.03, "status": "slow", "status_duration": 2.0, "status_value": 0.35, "knockback": 90.0, "max_targets": 11},
	"new_tempest": {"damage_mul": 1.00, "radius_mul": 1.12, "status": "slow", "status_duration": 2.0, "status_value": 0.30, "pull": 20.0, "max_targets": 10},
	"blacksmith": {"damage_mul": 1.10, "radius_mul": 0.90, "status": "burn", "status_duration": 2.6, "status_value": 0.26, "knockback": 125.0, "max_targets": 8},
	"medic": {"damage_mul": 0.78, "radius_mul": 1.12, "status": "slow", "status_duration": 1.8, "status_value": 0.22, "heal_ratio": 0.12, "max_targets": 10},
	"ammo": {"damage_mul": 1.08, "radius_mul": 0.98, "status": "marked", "status_duration": 1.8, "status_value": 0.24, "energy_gain": 0.7, "max_targets": 10},
	"paladin": {"damage_mul": 0.96, "radius_mul": 1.06, "status": "marked", "status_duration": 2.0, "status_value": 0.20, "heal_ratio": 0.10, "max_targets": 10},
	"vampire": {"damage_mul": 1.00, "radius_mul": 0.95, "status": "curse", "status_duration": 3.2, "status_value": 0.25, "status_stacks": 2, "heal_ratio": 0.16, "max_targets": 9},
	"banner": {"damage_mul": 0.92, "radius_mul": 1.18, "status": "marked", "status_duration": 2.1, "status_value": 0.22, "knockback": 130.0, "max_targets": 12},
	"train": {"damage_mul": 1.16, "radius_mul": 1.00, "status": "slow", "status_duration": 1.6, "status_value": 0.24, "knockback": 220.0, "max_targets": 12},
	"swarm": {"damage_mul": 0.90, "radius_mul": 1.12, "status": "poison", "status_duration": 3.5, "status_value": 0.27, "status_stacks": 2, "max_targets": 10},
	"new_totem": {"damage_mul": 0.96, "radius_mul": 1.02, "status": "marked", "status_duration": 1.9, "status_value": 0.22, "status_tick": 0.8, "max_targets": 10},
	"turret_eng": {"damage_mul": 1.15, "radius_mul": 0.94, "status": "marked", "status_duration": 1.7, "status_value": 0.20, "max_targets": 9},
	"goo": {"damage_mul": 0.88, "radius_mul": 1.12, "status": "poison", "status_duration": 3.2, "status_value": 0.22, "status_stacks": 2, "status_tick": 0.7, "max_targets": 10},
	"necro": {"damage_mul": 0.92, "radius_mul": 1.06, "status": "curse", "status_duration": 3.0, "status_value": 0.28, "status_stacks": 2, "max_targets": 10},
	"illusionist": {"damage_mul": 1.00, "radius_mul": 1.08, "status": "marked", "status_duration": 1.7, "status_value": 0.18, "random_damage_spread": 0.25, "max_targets": 10},
	"voodoo": {"damage_mul": 0.94, "radius_mul": 1.04, "status": "curse", "status_duration": 3.3, "status_value": 0.30, "status_stacks": 2, "mark_bonus_scale": 0.20, "max_targets": 10},
	"merchant": {"damage_mul": 0.72, "radius_mul": 1.00, "status": "marked", "status_duration": 1.8, "status_value": 0.16, "coin_drop": 1, "energy_gain": 0.4, "max_targets": 9},
	"midas": {"damage_mul": 0.96, "radius_mul": 1.00, "status": "slow", "status_duration": 2.2, "status_value": 0.34, "coin_drop": 1, "max_targets": 9},
	"vacuum": {"damage_mul": 1.02, "radius_mul": 1.16, "status": "slow", "status_duration": 1.7, "status_value": 0.25, "pull": 35.0, "max_targets": 12},
	"executioner": {"damage_mul": 1.05, "radius_mul": 0.92, "status": "marked", "status_duration": 2.0, "status_value": 0.24, "execute_threshold": 0.20, "execute_scale": 5.0, "max_targets": 8},
	"gambler": {"damage_mul": 0.94, "radius_mul": 1.02, "status": "marked", "status_duration": 1.6, "status_value": 0.18, "random_damage_spread": 0.40, "coin_drop": 1, "max_targets": 10},
	"hunter": {"damage_mul": 1.06, "radius_mul": 1.12, "status": "marked", "status_duration": 2.2, "status_value": 0.26, "mark_bonus_scale": 0.28, "max_targets": 12},
}

const CLOSURE_PROFILES := {
	"butcher": {"damage_mul": 1.55, "radius_mul": 1.08, "status": "curse", "status_duration": 3.2, "status_value": 0.36, "status_stacks": 2, "execute_threshold": 0.30, "execute_scale": 8.5, "max_targets": 14, "player_text": "血锯屠场"},
	"weaver": {"damage_mul": 1.28, "radius_mul": 1.22, "status": "slow", "status_duration": 3.4, "status_value": 0.45, "pull": 25.0, "max_targets": 14, "player_text": "蛛茧封锁"},
	"herder": {"damage_mul": 1.34, "radius_mul": 1.25, "status": "marked", "status_duration": 2.6, "status_value": 0.26, "knockback": 230.0, "max_targets": 16, "player_text": "围猎冲圈"},
	"pyro": {"damage_mul": 1.62, "radius_mul": 1.16, "status": "burn", "status_duration": 4.0, "status_value": 0.42, "status_tick": 0.45, "max_targets": 14, "player_text": "炼狱爆燃"},
	"wind": {"damage_mul": 1.32, "radius_mul": 1.32, "status": "slow", "status_duration": 2.8, "status_value": 0.36, "pull": 38.0, "max_targets": 14, "player_text": "飓眼收束"},
	"sapper": {"damage_mul": 1.66, "radius_mul": 1.15, "status": "marked", "status_duration": 2.5, "status_value": 0.30, "knockback": 180.0, "max_targets": 15, "player_text": "超限连爆"},
	"glacier": {"damage_mul": 1.36, "radius_mul": 1.24, "status": "freeze", "status_duration": 1.2, "status_value": 0.0, "max_targets": 14, "player_text": "极夜碎裂"},
	"tesla": {"damage_mul": 1.48, "radius_mul": 1.20, "status": "stun", "status_duration": 0.8, "status_value": 0.0, "max_targets": 14, "player_text": "雷暴并网"},
	"new_pyro": {"damage_mul": 1.64, "radius_mul": 1.18, "status": "burn", "status_duration": 4.0, "status_value": 0.44, "status_tick": 0.4, "max_targets": 14, "player_text": "符炎轰击"},
	"plague": {"damage_mul": 1.28, "radius_mul": 1.28, "status": "poison", "status_duration": 4.2, "status_value": 0.38, "status_stacks": 3, "status_tick": 0.6, "max_targets": 15, "player_text": "瘴界扩散"},
	"jailer": {"damage_mul": 1.30, "radius_mul": 1.24, "status": "stun", "status_duration": 1.1, "status_value": 0.0, "max_targets": 14, "player_text": "终审落锁"},
	"new_tempest": {"damage_mul": 1.46, "radius_mul": 1.32, "status": "slow", "status_duration": 2.6, "status_value": 0.34, "pull": 40.0, "max_targets": 16, "player_text": "多核台风"},
	"blacksmith": {"damage_mul": 1.48, "radius_mul": 1.12, "status": "burn", "status_duration": 3.2, "status_value": 0.34, "knockback": 180.0, "max_targets": 12, "player_text": "神工重锻"},
	"medic": {"damage_mul": 1.12, "radius_mul": 1.30, "status": "slow", "status_duration": 2.4, "status_value": 0.28, "heal_ratio": 0.30, "energy_gain": 1.0, "max_targets": 14, "player_text": "总医院接管"},
	"ammo": {"damage_mul": 1.46, "radius_mul": 1.18, "status": "marked", "status_duration": 2.4, "status_value": 0.30, "energy_gain": 1.4, "max_targets": 14, "player_text": "火力链路"},
	"paladin": {"damage_mul": 1.30, "radius_mul": 1.24, "status": "stun", "status_duration": 0.9, "status_value": 0.0, "heal_ratio": 0.24, "max_targets": 14, "player_text": "圣谕降临"},
	"vampire": {"damage_mul": 1.44, "radius_mul": 1.16, "status": "curse", "status_duration": 3.8, "status_value": 0.34, "status_stacks": 3, "heal_ratio": 0.34, "max_targets": 13, "player_text": "猩红盛宴"},
	"banner": {"damage_mul": 1.24, "radius_mul": 1.36, "status": "marked", "status_duration": 2.8, "status_value": 0.30, "knockback": 190.0, "max_targets": 16, "player_text": "总攻军令"},
	"train": {"damage_mul": 1.68, "radius_mul": 1.30, "status": "slow", "status_duration": 2.0, "status_value": 0.30, "knockback": 260.0, "max_targets": 16, "player_text": "钢轨碾压"},
	"swarm": {"damage_mul": 1.24, "radius_mul": 1.30, "status": "poison", "status_duration": 4.2, "status_value": 0.34, "status_stacks": 3, "max_targets": 15, "player_text": "母巢解放"},
	"new_totem": {"damage_mul": 1.30, "radius_mul": 1.22, "status": "marked", "status_duration": 2.6, "status_value": 0.28, "status_tick": 0.8, "energy_gain": 1.0, "max_targets": 14, "player_text": "祖灵共鸣"},
	"turret_eng": {"damage_mul": 1.58, "radius_mul": 1.18, "status": "marked", "status_duration": 2.2, "status_value": 0.28, "max_targets": 13, "player_text": "战术超频"},
	"goo": {"damage_mul": 1.18, "radius_mul": 1.32, "status": "poison", "status_duration": 4.0, "status_value": 0.30, "status_stacks": 3, "status_tick": 0.65, "max_targets": 15, "player_text": "裂变黏潮"},
	"necro": {"damage_mul": 1.26, "radius_mul": 1.26, "status": "curse", "status_duration": 4.2, "status_value": 0.36, "status_stacks": 3, "energy_gain": 1.1, "max_targets": 15, "player_text": "冥域行军"},
	"illusionist": {"damage_mul": 1.34, "radius_mul": 1.24, "status": "marked", "status_duration": 2.4, "status_value": 0.26, "random_damage_spread": 0.35, "max_targets": 14, "player_text": "镜域分身"},
	"voodoo": {"damage_mul": 1.26, "radius_mul": 1.22, "status": "curse", "status_duration": 4.0, "status_value": 0.40, "status_stacks": 3, "mark_bonus_scale": 0.30, "max_targets": 14, "player_text": "大巫降神"},
	"merchant": {"damage_mul": 1.05, "radius_mul": 1.22, "status": "marked", "status_duration": 2.4, "status_value": 0.22, "coin_drop": 3, "energy_gain": 1.5, "max_targets": 12, "player_text": "黑市清算"},
	"midas": {"damage_mul": 1.30, "radius_mul": 1.18, "status": "slow", "status_duration": 3.2, "status_value": 0.46, "coin_drop": 2, "max_targets": 13, "player_text": "黄金法典"},
	"vacuum": {"damage_mul": 1.52, "radius_mul": 1.34, "status": "slow", "status_duration": 2.4, "status_value": 0.34, "pull": 55.0, "max_targets": 16, "player_text": "奇点坍缩"},
	"executioner": {"damage_mul": 1.46, "radius_mul": 1.08, "status": "marked", "status_duration": 2.8, "status_value": 0.32, "execute_threshold": 0.40, "execute_scale": 9.0, "max_targets": 12, "player_text": "断罪时刻"},
	"gambler": {"damage_mul": 1.24, "radius_mul": 1.18, "status": "marked", "status_duration": 2.0, "status_value": 0.22, "random_damage_spread": 0.70, "coin_drop": 2, "max_targets": 14, "player_text": "命运梭哈"},
	"hunter": {"damage_mul": 1.50, "radius_mul": 1.32, "status": "marked", "status_duration": 3.2, "status_value": 0.36, "mark_bonus_scale": 0.44, "max_targets": 16, "player_text": "终猎季"},
}

const TICK_PROFILES := {
	"butcher": {"damage_mul": 0.95, "radius_mul": 1.02, "status": "marked", "status_duration": 1.2, "status_value": 0.14, "heal_ratio": 0.08, "max_targets": 7},
	"weaver": {"damage_mul": 0.72, "radius_mul": 1.14, "status": "slow", "status_duration": 1.5, "status_value": 0.20, "max_targets": 8},
	"herder": {"damage_mul": 0.82, "radius_mul": 1.18, "status": "marked", "status_duration": 1.3, "status_value": 0.16, "knockback": 80.0, "max_targets": 9},
	"pyro": {"damage_mul": 1.05, "radius_mul": 1.02, "status": "burn", "status_duration": 1.8, "status_value": 0.16, "status_tick": 0.5, "max_targets": 7},
	"wind": {"damage_mul": 0.78, "radius_mul": 1.18, "status": "slow", "status_duration": 1.4, "status_value": 0.20, "pull": 12.0, "max_targets": 8},
	"sapper": {"damage_mul": 0.92, "radius_mul": 1.02, "status": "marked", "status_duration": 1.2, "status_value": 0.14, "max_targets": 8},
	"glacier": {"damage_mul": 0.80, "radius_mul": 1.16, "status": "slow", "status_duration": 1.6, "status_value": 0.24, "max_targets": 8},
	"tesla": {"damage_mul": 0.90, "radius_mul": 1.08, "status": "marked", "status_duration": 1.3, "status_value": 0.16, "max_targets": 8},
	"new_pyro": {"damage_mul": 1.04, "radius_mul": 1.04, "status": "burn", "status_duration": 1.8, "status_value": 0.18, "status_tick": 0.45, "max_targets": 8},
	"plague": {"damage_mul": 0.78, "radius_mul": 1.20, "status": "poison", "status_duration": 2.0, "status_value": 0.16, "status_stacks": 2, "max_targets": 9},
	"jailer": {"damage_mul": 0.76, "radius_mul": 1.14, "status": "slow", "status_duration": 1.5, "status_value": 0.22, "max_targets": 8},
	"new_tempest": {"damage_mul": 0.92, "radius_mul": 1.20, "status": "slow", "status_duration": 1.5, "status_value": 0.21, "pull": 16.0, "max_targets": 9},
	"blacksmith": {"damage_mul": 0.95, "radius_mul": 1.00, "status": "burn", "status_duration": 1.6, "status_value": 0.14, "max_targets": 7},
	"medic": {"damage_mul": 0.62, "radius_mul": 1.20, "status": "slow", "status_duration": 1.2, "status_value": 0.16, "heal_ratio": 0.16, "energy_gain": 0.6, "max_targets": 8},
	"ammo": {"damage_mul": 0.90, "radius_mul": 1.06, "status": "marked", "status_duration": 1.3, "status_value": 0.18, "energy_gain": 0.8, "max_targets": 8},
	"paladin": {"damage_mul": 0.78, "radius_mul": 1.16, "status": "marked", "status_duration": 1.5, "status_value": 0.17, "heal_ratio": 0.12, "max_targets": 8},
	"vampire": {"damage_mul": 0.92, "radius_mul": 1.04, "status": "curse", "status_duration": 1.8, "status_value": 0.16, "heal_ratio": 0.18, "max_targets": 8},
	"banner": {"damage_mul": 0.72, "radius_mul": 1.24, "status": "marked", "status_duration": 1.6, "status_value": 0.16, "max_targets": 9},
	"train": {"damage_mul": 1.00, "radius_mul": 1.22, "status": "slow", "status_duration": 1.2, "status_value": 0.18, "knockback": 120.0, "max_targets": 10},
	"swarm": {"damage_mul": 0.74, "radius_mul": 1.20, "status": "poison", "status_duration": 1.9, "status_value": 0.16, "status_stacks": 2, "max_targets": 9},
	"new_totem": {"damage_mul": 0.80, "radius_mul": 1.10, "status": "marked", "status_duration": 1.4, "status_value": 0.17, "energy_gain": 0.7, "max_targets": 8},
	"turret_eng": {"damage_mul": 0.98, "radius_mul": 1.04, "status": "marked", "status_duration": 1.3, "status_value": 0.18, "max_targets": 8},
	"goo": {"damage_mul": 0.70, "radius_mul": 1.22, "status": "poison", "status_duration": 1.8, "status_value": 0.15, "status_stacks": 2, "max_targets": 9},
	"necro": {"damage_mul": 0.78, "radius_mul": 1.16, "status": "curse", "status_duration": 1.9, "status_value": 0.18, "status_stacks": 2, "energy_gain": 0.7, "max_targets": 9},
	"illusionist": {"damage_mul": 0.84, "radius_mul": 1.14, "status": "marked", "status_duration": 1.3, "status_value": 0.15, "random_damage_spread": 0.35, "max_targets": 8},
	"voodoo": {"damage_mul": 0.78, "radius_mul": 1.12, "status": "curse", "status_duration": 2.0, "status_value": 0.20, "status_stacks": 2, "max_targets": 8},
	"merchant": {"damage_mul": 0.56, "radius_mul": 1.08, "status": "marked", "status_duration": 1.2, "status_value": 0.12, "coin_drop": 1, "energy_gain": 0.8, "max_targets": 7},
	"midas": {"damage_mul": 0.78, "radius_mul": 1.10, "status": "slow", "status_duration": 1.8, "status_value": 0.24, "coin_drop": 1, "max_targets": 8},
	"vacuum": {"damage_mul": 0.92, "radius_mul": 1.24, "status": "slow", "status_duration": 1.4, "status_value": 0.18, "pull": 18.0, "max_targets": 10},
	"executioner": {"damage_mul": 0.90, "radius_mul": 1.02, "status": "marked", "status_duration": 1.4, "status_value": 0.20, "execute_threshold": 0.26, "execute_scale": 6.0, "max_targets": 8},
	"gambler": {"damage_mul": 0.70, "radius_mul": 1.08, "status": "marked", "status_duration": 1.2, "status_value": 0.14, "random_damage_spread": 0.85, "coin_drop": 1, "max_targets": 8},
	"hunter": {"damage_mul": 0.92, "radius_mul": 1.24, "status": "marked", "status_duration": 1.8, "status_value": 0.24, "mark_bonus_scale": 0.30, "max_targets": 10},
}

var _mode_id_runtime: String = ""
var _tick_accum: float = 0.0
var _line_event_count: int = 0
var _closure_event_count: int = 0
var _mode_trigger_count: int = 0
var _sapper_mines: Array = []
var _pyro_patches: Array = []
var _turret_pylons: Array = []
var _goo_pools: Array = []

func _on_ultimate_activated() -> void:
	_mode_id_runtime = _resolve_mode_id()
	_tick_accum = 0.0
	_line_event_count = 0
	_closure_event_count = 0
	_mode_trigger_count = 0
	_clear_signature_nodes()
	_sync_mode_runtime_profile()

func _on_ultimate_deactivated() -> void:
	_mode_id_runtime = ""
	_tick_accum = 0.0
	_clear_signature_nodes()

func _on_ultimate_update(delta: float) -> void:
	var tick_interval = max(MIN_TICK_INTERVAL, f_internal_cd)
	_tick_accum += delta
	while _tick_accum >= tick_interval:
		_tick_accum -= tick_interval
		_emit_tick_mode_effect()

func on_q_path_executed(is_closed: bool, segment_count: int, polygon_count: int) -> void:
	if not is_active:
		return

	if is_closed:
		_closure_event_count += 1
		_mode_trigger_count += 1
		_emit_closure_mode_effect(max(1.0, float(polygon_count)))
	else:
		_line_event_count += 1
		_mode_trigger_count += 1
		_emit_line_mode_effect(max(1.0, float(segment_count)))

	_sync_mode_runtime_profile()

func _resolve_mode_id() -> String:
	var mode = f_mode_id.strip_edges()
	if mode != "":
		return mode

	if is_instance_valid(player_ref) and "player_id" in player_ref:
		return str(player_ref.player_id)

	if ult_id.ends_with("_ult"):
		if ult_id.length() > 4:
			return ult_id.substr(0, ult_id.length() - 4)
	return ult_id

func _emit_line_mode_effect(intensity: float) -> void:
	var profile = LINE_PROFILES.get(_mode_id_runtime, {})
	if profile.is_empty():
		return
	var packet = _build_packet(profile, "line", intensity, _get_payload_scale(f_bond_o_payload))
	_apply_packet(packet)

func _emit_closure_mode_effect(intensity: float) -> void:
	var profile = CLOSURE_PROFILES.get(_mode_id_runtime, {})
	if profile.is_empty():
		return
	var packet = _build_packet(profile, "closure", intensity, _get_payload_scale(f_bond_m_payload))
	_apply_packet(packet)

func _emit_tick_mode_effect() -> void:
	var profile = TICK_PROFILES.get(_mode_id_runtime, {})
	if profile.is_empty():
		return
	var packet = _build_packet(profile, "tick", 1.0, _get_payload_scale(f_bond_t_payload))
	_apply_packet(packet)
	_sync_mode_runtime_profile()

func _build_packet(profile: Dictionary, phase: String, intensity: float, bond_scale: float) -> Dictionary:
	var packet = profile.duplicate(true)

	var base_radius = max(140.0, f_special_value_2)
	var utility = max(0.0, f_special_value_3)

	var phase_base_scale = 0.5
	match phase:
		"line":
			phase_base_scale = max(0.16, f_special_value_1 * 0.75)
		"closure":
			phase_base_scale = max(0.24, f_special_value_1 * 1.30)
		_:
			phase_base_scale = max(0.10, f_special_value_1 * 0.45)

	var radius = base_radius * float(packet.get("radius_mul", 1.0))
	radius += float(packet.get("radius_bonus", 0.0))
	radius += max(0.0, intensity - 1.0) * float(packet.get("radius_per_intensity", 8.0))
	radius += utility * float(packet.get("util_radius_scale", 20.0))

	var damage_scale = phase_base_scale * float(packet.get("damage_mul", 1.0))
	damage_scale *= bond_scale
	damage_scale *= 1.0 + max(0.0, intensity - 1.0) * float(packet.get("intensity_scale", 0.04))
	damage_scale *= 1.0 + utility * float(packet.get("util_damage_scale", 0.0))

	packet["radius"] = radius
	packet["damage_scale"] = damage_scale
	packet["pull"] = float(packet.get("pull", 0.0)) * bond_scale
	packet["knockback"] = float(packet.get("knockback", 0.0)) * bond_scale
	packet["energy_gain"] = float(packet.get("energy_gain", 0.0)) * bond_scale
	packet["heal_ratio"] = float(packet.get("heal_ratio", 0.0)) * (1.0 + (bond_scale - 1.0) * 0.5)
	packet["coin_drop"] = int(round(float(packet.get("coin_drop", 0.0)) * bond_scale))
	packet["status_value"] = float(packet.get("status_value", 0.0)) + utility * float(packet.get("util_status_scale", 0.0))
	packet["max_targets"] = max(1, int(packet.get("max_targets", DEFAULT_TARGET_CAP)))
	packet["phase"] = phase

	return packet

func _apply_packet(packet: Dictionary) -> void:
	if not is_instance_valid(player_ref):
		return

	var center: Vector2 = _resolve_packet_center(packet)
	var radius: float = max(40.0, float(packet.get("radius", 120.0)))
	var enemies: Array = _get_enemies_in_radius(center, radius)
	var max_targets: int = max(1, int(packet.get("max_targets", DEFAULT_TARGET_CAP)))

	var base_damage: float = _get_player_base_damage()
	var hit_count: int = 0

	for enemy in enemies:
		if hit_count >= max_targets:
			break
		if not is_instance_valid(enemy):
			continue

		var damage_scale: float = float(packet.get("damage_scale", 0.0))
		var random_spread: float = max(0.0, float(packet.get("random_damage_spread", 0.0)))
		if random_spread > 0.0:
			damage_scale *= randf_range(max(0.2, 1.0 - random_spread), 1.0 + random_spread)

		var mark_bonus: float = float(packet.get("mark_bonus_scale", 0.0))
		if mark_bonus > 0.0 and enemy.has_method("has_status") and enemy.has_status("marked"):
			damage_scale *= (1.0 + mark_bonus)

		var execute_threshold: float = float(packet.get("execute_threshold", -1.0))
		var execute_scale: float = max(1.0, float(packet.get("execute_scale", 6.0)))

		if execute_threshold > 0.0 and _is_enemy_below_threshold(enemy, execute_threshold):
			_damage_enemy(enemy, base_damage * execute_scale, "EXECUTE", Color(1.0, 0.2, 0.2))
		elif damage_scale > 0.0:
			_damage_enemy(enemy, base_damage * damage_scale)

		var pull: float = float(packet.get("pull", 0.0))
		if pull > 0.0:
			_pull_enemy(enemy, center, pull)

		var knockback: float = float(packet.get("knockback", 0.0))
		if knockback > 0.0:
			_knock_enemy(enemy, center, knockback)

		var status_name: String = str(packet.get("status", "")).strip_edges()
		if status_name != "":
			var status_duration: float = float(packet.get("status_duration", 0.0))
			if status_duration > 0.0:
				var status_value: float = float(packet.get("status_value", 0.0))
				if status_name in ["burn", "curse", "poison"]:
					status_value = max(1.0, base_damage * status_value)
				_apply_enemy_status(
					enemy,
					status_name,
					status_duration,
					status_value,
					max(1, int(packet.get("status_stacks", 1))),
					max(0.05, float(packet.get("status_tick", 1.0)))
				)

		hit_count += 1

	if hit_count <= 0:
		return

	var heal_ratio: float = float(packet.get("heal_ratio", 0.0))
	if heal_ratio > 0.0:
		_heal_player(base_damage * heal_ratio * float(hit_count))

	var energy_gain: float = float(packet.get("energy_gain", 0.0))
	if energy_gain > 0.0:
		_gain_energy(energy_gain * max(1.0, float(hit_count) * 0.5))

	var coin_drop: int = int(packet.get("coin_drop", 0))
	if coin_drop > 0:
		_drop_coins(coin_drop)

	var player_text: String = str(packet.get("player_text", "")).strip_edges()
	if player_text != "":
		Global.spawn_floating_text(center, player_text, visual_color)

	_apply_mode_signature(str(packet.get("phase", "tick")), packet, center, hit_count)

func _resolve_packet_center(packet: Dictionary) -> Vector2:
	if not is_instance_valid(player_ref):
		return Vector2.ZERO
	var center: Vector2 = player_ref.global_position
	if _mode_id_runtime == "wind":
		var radius: float = max(80.0, float(packet.get("radius", 140.0)))
		var aim_dir: Vector2 = _get_player_aim_direction()
		center += aim_dir * min(radius * 0.55, 170.0)
	return center

func _apply_mode_signature(phase: String, packet: Dictionary, center: Vector2, hit_count: int) -> void:
	if not is_active:
		return
	match _mode_id_runtime:
		"butcher":
			_signature_butcher(phase, packet, center)
		"weaver":
			_signature_weaver(phase, packet, center)
		"herder":
			_signature_herder(phase, packet, center)
		"pyro":
			_signature_pyro(phase, packet, center)
		"wind":
			_signature_wind(phase, packet, center)
		"sapper":
			_signature_sapper(phase, packet, center, hit_count)
		"glacier":
			_signature_glacier(phase, packet, center)
		"tesla":
			_signature_tesla(phase, packet, center)
		"necro":
			_signature_necro(phase, packet, center)
		"swarm":
			_signature_swarm(phase, packet, center)
		"turret_eng":
			_signature_turret_eng(phase, packet, center)
		"hunter":
			_signature_hunter(phase, packet, center)
		"blacksmith":
			_signature_blacksmith(phase, packet, center)
		"medic":
			_signature_medic(phase, packet, center)
		"ammo":
			_signature_ammo(phase, packet, center)
		"paladin":
			_signature_paladin(phase, packet, center)
		"banner":
			_signature_banner(phase, packet, center)
		"midas":
			_signature_midas(phase, packet, center)
		"new_pyro":
			_signature_new_pyro(phase, packet, center)
		"plague":
			_signature_plague(phase, packet, center)
		"jailer":
			_signature_jailer(phase, packet, center)
		"new_tempest":
			_signature_new_tempest(phase, packet, center)
		"vampire":
			_signature_vampire(phase, packet, center)
		"train":
			_signature_train(phase, packet, center)
		"new_totem":
			_signature_new_totem(phase, packet, center)
		"goo":
			_signature_goo(phase, packet, center)
		"illusionist":
			_signature_illusionist(phase, packet, center)
		"voodoo":
			_signature_voodoo(phase, packet, center)
		"merchant":
			_signature_merchant(phase, packet, center)
		"vacuum":
			_signature_vacuum(phase, packet, center)
		"executioner":
			_signature_executioner(phase, packet, center)
		"gambler":
			_signature_gambler(phase, packet, center)
		_:
			pass

func _signature_butcher(phase: String, packet: Dictionary, center: Vector2) -> void:
	var radius: float = max(80.0, float(packet.get("radius", 120.0)) * 0.84)
	var targets: Array = _sort_enemies_by_distance(_get_enemies_in_radius(center, radius), center)
	if targets.is_empty():
		return
	var limit: int = 1
	var damage_scale: float = 0.45
	match phase:
		"line":
			limit = 2
			damage_scale = 0.62
		"closure":
			limit = 3
			damage_scale = 0.92
		_:
			limit = 1
			damage_scale = 0.45
	var base_damage: float = _get_player_base_damage()
	for i in range(min(limit, targets.size())):
		var enemy: Node = targets[i]
		_pull_enemy(enemy, center, 14.0 + 8.0 * float(i))
		_damage_enemy(enemy, base_damage * damage_scale, "RIP", Color(1.0, 0.35, 0.35))
		_apply_enemy_status(enemy, "curse", 1.2 + (0.4 if phase == "closure" else 0.0), max(1.0, base_damage * 0.12), 1, 0.6)
	_heal_player(base_damage * (0.04 + 0.01 * float(limit)))

func _signature_weaver(phase: String, packet: Dictionary, center: Vector2) -> void:
	var radius: float = max(90.0, float(packet.get("radius", 120.0)) * 1.06)
	var targets: Array = _sort_enemies_by_distance(_get_enemies_in_radius(center, radius), center)
	if targets.is_empty():
		return
	var limit: int = 2 if phase == "tick" else 4
	for i in range(min(limit, targets.size())):
		var enemy: Node = targets[i]
		_pull_enemy(enemy, center, 10.0 + (10.0 if phase == "closure" else 4.0))
		_apply_enemy_status(enemy, "slow", 1.2 + 0.25 * float(i), 0.32, 1, 0.1)
		if phase == "closure":
			_apply_enemy_status(enemy, "stun", 0.55, 0.0, 1, 0.1)

func _signature_herder(phase: String, packet: Dictionary, center: Vector2) -> void:
	var radius: float = max(100.0, float(packet.get("radius", 120.0)) * 0.98)
	var inner_radius: float = radius * 0.35
	var targets: Array = _get_enemies_in_radius(center, radius)
	if targets.is_empty():
		return
	var base_damage: float = _get_player_base_damage()
	var hit: int = 0
	for enemy in targets:
		if hit >= 10:
			break
		if not is_instance_valid(enemy) or not (enemy is Node2D):
			continue
		var enemy_node: Node2D = enemy
		var dist: float = enemy_node.global_position.distance_to(center)
		if dist < inner_radius:
			continue
		_knock_enemy(enemy, center, 120.0 + (70.0 if phase == "closure" else 0.0))
		_damage_enemy(enemy, base_damage * (0.35 + (0.28 if phase == "closure" else 0.0)))
		_apply_enemy_status(enemy, "marked", 1.4, 0.16, 1, 0.4)
		hit += 1
	if phase == "closure" and hit > 0:
		_add_player_armor(1)

func _signature_pyro(phase: String, packet: Dictionary, center: Vector2) -> void:
	var radius: float = max(70.0, float(packet.get("radius", 120.0)) * (0.56 if phase != "closure" else 0.64))
	var duration: float = 1.2 if phase == "tick" else 1.8
	var damage_scale: float = 0.25 if phase == "tick" else 0.34
	_spawn_pyro_patch(center, radius, duration, damage_scale)
	if phase == "closure":
		for i in range(2):
			var angle: float = randf_range(0.0, TAU)
			var offset: Vector2 = Vector2(cos(angle), sin(angle)) * radius * 0.8
			_spawn_pyro_patch(center + offset, radius * 0.7, duration * 0.8, damage_scale * 0.9)

func _signature_wind(phase: String, packet: Dictionary, center: Vector2) -> void:
	var radius: float = max(85.0, float(packet.get("radius", 120.0)) * 0.82)
	var targets: Array = _sort_enemies_by_distance(_get_enemies_in_radius(center, radius), center)
	if targets.is_empty():
		return
	var base_damage: float = _get_player_base_damage()
	var limit: int = 3 if phase != "closure" else 5
	for i in range(min(limit, targets.size())):
		var enemy: Node = targets[i]
		_pull_enemy(enemy, center, 14.0 + (10.0 if phase == "closure" else 6.0))
		_apply_enemy_status(enemy, "slow", 1.0 + 0.2 * float(i), 0.30, 1, 0.1)
		if phase == "closure":
			_damage_enemy(enemy, base_damage * 0.42)

func _signature_sapper(phase: String, packet: Dictionary, center: Vector2, _hit_count: int) -> void:
	if phase == "closure":
		_detonate_all_sapper_mines(true)
		return
	var orbit_radius: float = max(60.0, float(packet.get("radius", 120.0)) * 0.34)
	var angle: float = randf_range(0.0, TAU)
	var spawn_pos: Vector2 = center + Vector2(cos(angle), sin(angle)) * orbit_radius
	_spawn_sapper_mine(spawn_pos, 0.9, max(48.0, orbit_radius * 0.7), 0.52)

func _signature_glacier(phase: String, packet: Dictionary, center: Vector2) -> void:
	var radius: float = max(90.0, float(packet.get("radius", 120.0)) * 0.96)
	var inner_radius: float = radius * (0.52 if phase == "closure" else 0.42)
	var enemies: Array = _get_enemies_in_radius(center, radius)
	if enemies.is_empty():
		return
	var base_damage: float = _get_player_base_damage()
	for enemy in enemies:
		if not is_instance_valid(enemy) or not (enemy is Node2D):
			continue
		var enemy_node: Node2D = enemy
		var dist: float = enemy_node.global_position.distance_to(center)
		if dist <= inner_radius:
			_damage_enemy(enemy, base_damage * (0.45 if phase == "closure" else 0.30))
			_apply_enemy_status(enemy, "freeze", 0.65 if phase == "closure" else 0.35, 0.0, 1, 0.1)
		else:
			_knock_enemy(enemy, center, 105.0 + (45.0 if phase == "closure" else 0.0))
			_apply_enemy_status(enemy, "slow", 1.1, 0.34, 1, 0.1)

func _signature_tesla(phase: String, packet: Dictionary, center: Vector2) -> void:
	var radius: float = max(100.0, float(packet.get("radius", 120.0)) * 1.08)
	var jump_count: int = 2
	var link_range: float = radius * 0.72
	var base_scale: float = 0.42
	match phase:
		"line":
			jump_count = 3
			base_scale = 0.48
		"closure":
			jump_count = 5
			link_range = radius * 0.88
			base_scale = 0.62
		_:
			jump_count = 2
			base_scale = 0.42
	var chain: Array = _build_chain_targets(center, radius, jump_count, link_range)
	if chain.is_empty():
		return
	var base_damage: float = _get_player_base_damage()
	for i in range(chain.size()):
		var enemy: Node = chain[i]
		var step_scale: float = max(0.55, 1.0 - 0.1 * float(i))
		_damage_enemy(enemy, base_damage * base_scale * step_scale, "ARC", Color(0.45, 0.95, 1.3))
		_apply_enemy_status(enemy, "stun", 0.38 + 0.08 * float(i == 0), 0.0, 1, 0.1)
		_apply_enemy_status(enemy, "marked", 1.2, 0.18, 1, 0.3)

func _signature_necro(phase: String, packet: Dictionary, center: Vector2) -> void:
	var radius: float = max(95.0, float(packet.get("radius", 120.0)) * 1.02)
	var targets: Array = _sort_enemies_by_distance(_get_enemies_in_radius(center, radius), center)
	if targets.is_empty():
		return
	var max_targets: int = 2 if phase == "tick" else (4 if phase == "line" else 6)
	var refs: Array = []
	for i in range(min(max_targets, targets.size())):
		var enemy: Node = targets[i]
		_apply_enemy_status(enemy, "curse", 1.5 + (0.4 if phase == "closure" else 0.0), max(1.0, _get_player_base_damage() * 0.14), 1, 0.6)
		refs.append(weakref(enemy))
	var reap_delay: float = 0.46 if phase != "closure" else 0.33
	var reap_scale: float = 0.38 if phase != "closure" else 0.62
	get_tree().create_timer(reap_delay).timeout.connect(_on_necro_reap_timeout.bind(refs, reap_scale, center))

func _signature_swarm(phase: String, packet: Dictionary, center: Vector2) -> void:
	var radius: float = max(90.0, float(packet.get("radius", 120.0)) * 1.12)
	var target: Node2D = _pick_nearest_enemy(center, radius * 1.2, [])
	if SkillEffectManager != null and SkillEffectManager.has_method("command_summons"):
		SkillEffectManager.command_summons("skill_swarm_q", "focus_fire", target)
	var boost: float = 0.07
	var boost_duration: float = 1.6
	if phase == "line":
		boost = 0.1
		boost_duration = 1.9
	elif phase == "closure":
		boost = 0.14
		boost_duration = 2.4
	_apply_temp_attack_boost(boost_duration, boost)
	if phase == "closure":
		var burst_center: Vector2 = target.global_position if target != null else center
		var burst_damage: float = _get_player_base_damage() * 0.46
		for enemy in _get_enemies_in_radius(burst_center, radius * 0.45):
			_damage_enemy(enemy, burst_damage)
			_apply_enemy_status(enemy, "poison", 1.6, max(1.0, burst_damage * 0.4), 1, 0.6)

func _signature_turret_eng(phase: String, packet: Dictionary, center: Vector2) -> void:
	var count: int = 1
	var radius: float = max(90.0, float(packet.get("radius", 120.0)) * 0.64)
	var duration: float = 1.6
	var damage_scale: float = 0.34
	if phase == "line":
		count = 1
		duration = 1.9
		damage_scale = 0.4
	elif phase == "closure":
		count = 2
		duration = 2.5
		damage_scale = 0.56
	var aim_dir: Vector2 = _get_player_aim_direction()
	var spread: float = 0.4
	for i in range(count):
		var ratio: float = 0.5 if count <= 1 else float(i) / float(count - 1)
		var angle: float = lerp(-spread, spread, ratio)
		var dir: Vector2 = aim_dir.rotated(angle)
		var pos: Vector2 = center + dir * (66.0 + float(i) * 22.0)
		_spawn_turret_pylon(pos, radius, duration, damage_scale)

func _signature_hunter(phase: String, packet: Dictionary, center: Vector2) -> void:
	var radius: float = max(110.0, float(packet.get("radius", 120.0)) * 1.1)
	var target: Node2D = _pick_hunter_target(center, radius)
	if target == null:
		return
	var mark_time: float = 1.6 if phase != "closure" else 2.3
	var mark_value: float = 0.22 if phase != "closure" else 0.34
	_apply_enemy_status(target, "marked", mark_time, mark_value, 1, 0.4)
	_apply_enemy_status(target, "slow", 1.0, 0.28, 1, 0.1)
	var delay: float = 0.2 if phase != "closure" else 0.12
	var shot_scale: float = 0.56 if phase != "closure" else 1.05
	get_tree().create_timer(delay).timeout.connect(_on_hunter_shot_timeout.bind(weakref(target), shot_scale))

func _signature_blacksmith(phase: String, packet: Dictionary, center: Vector2) -> void:
	var radius: float = max(90.0, float(packet.get("radius", 120.0)) * 0.92)
	var aim_dir: Vector2 = _get_player_aim_direction()
	var sweep_angle: float = 0.65 if phase == "line" else (0.95 if phase == "closure" else 0.48)
	var damage_scale: float = 0.52 if phase == "line" else (0.88 if phase == "closure" else 0.38)
	var base_damage: float = _get_player_base_damage()
	var enemies: Array = _get_enemies_in_radius(center, radius)
	var hit_count: int = 0
	for enemy in enemies:
		if hit_count >= 10:
			break
		if not is_instance_valid(enemy) or not (enemy is Node2D):
			continue
		var enemy_node: Node2D = enemy
		var dir: Vector2 = (enemy_node.global_position - center).normalized()
		var angle_delta: float = absf(aim_dir.angle_to(dir))
		if angle_delta > sweep_angle:
			continue
		_damage_enemy(enemy, base_damage * damage_scale, "FORGE", Color(1.0, 0.68, 0.28))
		_apply_enemy_status(enemy, "burn", 1.2 + (0.6 if phase == "closure" else 0.0), max(1.0, base_damage * 0.22), 1, 0.5)
		if phase != "tick":
			_knock_enemy(enemy, center, 95.0 + (40.0 if phase == "closure" else 0.0))
		hit_count += 1
	if phase == "closure" and hit_count > 0:
		_apply_temp_attack_boost(1.8, 0.12)

func _signature_medic(phase: String, packet: Dictionary, center: Vector2) -> void:
	var radius: float = max(120.0, float(packet.get("radius", 120.0)) * 1.06)
	var heal_ratio: float = 0.10 if phase == "line" else (0.16 if phase == "closure" else 0.08)
	_heal_player(_get_player_base_damage() * heal_ratio * 4.0)
	if phase != "tick":
		_apply_temp_meta_delta("lifesteal_bonus", 0.08 if phase == "line" else 0.14, 1.8 if phase == "line" else 2.4)
	var enemies: Array = _get_enemies_in_radius(center, radius)
	var hit_count: int = 0
	for enemy in enemies:
		if hit_count >= 10:
			break
		_apply_enemy_status(enemy, "slow", 1.1 + (0.3 if phase == "closure" else 0.0), 0.24, 1, 0.1)
		if phase == "closure":
			_apply_enemy_status(enemy, "marked", 1.4, 0.16, 1, 0.3)
		hit_count += 1

func _signature_ammo(phase: String, packet: Dictionary, center: Vector2) -> void:
	var radius: float = max(110.0, float(packet.get("radius", 120.0)) * 1.0)
	var energy_gain: float = 5.0 if phase == "tick" else (8.0 if phase == "line" else 12.0)
	_gain_energy(energy_gain)
	if phase != "tick":
		var cd_delta: float = 0.08 if phase == "line" else 0.13
		var cd_duration: float = 1.6 if phase == "line" else 2.2
		_apply_temp_meta_delta("buff_cooldown_reduction", cd_delta, cd_duration)
	var damage_scale: float = 0.42 if phase == "line" else (0.66 if phase == "closure" else 0.34)
	var base_damage: float = _get_player_base_damage()
	for enemy in _get_enemies_in_radius(center, radius):
		_damage_enemy(enemy, base_damage * damage_scale)
		_apply_enemy_status(enemy, "marked", 1.1, 0.18, 1, 0.3)

func _signature_paladin(phase: String, packet: Dictionary, center: Vector2) -> void:
	var radius: float = max(115.0, float(packet.get("radius", 120.0)) * 1.05)
	var enemies: Array = _get_enemies_in_radius(center, radius)
	var base_damage: float = _get_player_base_damage()
	var hit_count: int = 0
	for enemy in enemies:
		if hit_count >= 12:
			break
		if phase == "closure":
			_apply_enemy_status(enemy, "stun", 0.45, 0.0, 1, 0.1)
		else:
			_apply_enemy_status(enemy, "slow", 0.9, 0.3, 1, 0.1)
		_apply_enemy_status(enemy, "marked", 1.4, 0.16, 1, 0.3)
		if phase != "tick":
			_damage_enemy(enemy, base_damage * (0.34 if phase == "line" else 0.52))
		hit_count += 1
	if hit_count > 0:
		_add_player_armor(1 if phase != "closure" else 2)
		if phase == "closure":
			_heal_player(base_damage * 0.7)

func _signature_banner(phase: String, packet: Dictionary, center: Vector2) -> void:
	var radius: float = max(120.0, float(packet.get("radius", 120.0)) * 1.08)
	var aim_dir: Vector2 = _get_player_aim_direction()
	var base_damage: float = _get_player_base_damage()
	var wave_power: float = 130.0 if phase == "line" else (190.0 if phase == "closure" else 90.0)
	var damage_scale: float = 0.36 if phase == "line" else (0.58 if phase == "closure" else 0.24)
	for enemy in _get_enemies_in_radius(center, radius):
		if is_instance_valid(enemy) and enemy is Node2D:
			var enemy_node: Node2D = enemy
			var dot_forward: float = (enemy_node.global_position - center).normalized().dot(aim_dir)
			if dot_forward < -0.25:
				continue
		_damage_enemy(enemy, base_damage * damage_scale)
		_knock_enemy(enemy, center - aim_dir * 20.0, wave_power)
		_apply_enemy_status(enemy, "marked", 1.2, 0.14, 1, 0.3)
	var speed_delta: float = 0.08 if phase == "line" else (0.12 if phase == "closure" else 0.05)
	var speed_duration: float = 1.5 if phase == "line" else (2.3 if phase == "closure" else 1.0)
	_apply_temp_meta_delta("buff_speed_boost", speed_delta, speed_duration)

func _signature_midas(phase: String, packet: Dictionary, center: Vector2) -> void:
	var radius: float = max(95.0, float(packet.get("radius", 120.0)) * 0.95)
	var target: Node2D = _pick_nearest_enemy(center, radius, [])
	if target == null:
		return
	var base_damage: float = _get_player_base_damage()
	var damage_scale: float = 0.48 if phase == "line" else (0.82 if phase == "closure" else 0.36)
	var amount: float = base_damage * damage_scale
	var coin_count: int = 1 if phase != "closure" else 2
	if _is_enemy_below_threshold(target, 0.2):
		amount = base_damage * (2.6 if phase == "closure" else 1.8)
		coin_count += 1
		_damage_enemy(target, amount, "GOLD EXEC", Color(1.0, 0.82, 0.3))
	else:
		_damage_enemy(target, amount, "GILD", Color(0.95, 0.72, 0.24))
	_apply_enemy_status(target, "slow", 1.0 + (0.4 if phase == "closure" else 0.0), 0.28, 1, 0.1)
	_drop_coins_at((target as Node2D).global_position, coin_count)

func _signature_new_pyro(phase: String, packet: Dictionary, center: Vector2) -> void:
	var radius: float = max(90.0, float(packet.get("radius", 120.0)) * 0.78)
	var aim_dir: Vector2 = _get_player_aim_direction()
	var rune_count: int = 1
	var patch_scale: float = 0.24
	var delay_base: float = 0.20
	match phase:
		"line":
			rune_count = 2
			patch_scale = 0.30
			delay_base = 0.16
		"closure":
			rune_count = 3
			patch_scale = 0.38
			delay_base = 0.11
		_:
			rune_count = 1
			patch_scale = 0.24
			delay_base = 0.20
	for i in range(rune_count):
		var spread: float = randf_range(-0.42, 0.42)
		var dir: Vector2 = aim_dir.rotated(spread)
		var pos: Vector2 = center + dir * (56.0 + float(i) * 52.0)
		_spawn_pyro_patch(pos, radius * 0.44, 1.2 + 0.25 * float(rune_count), patch_scale)
		var delay: float = delay_base + float(i) * 0.09
		get_tree().create_timer(delay).timeout.connect(_on_new_pyro_rune_timeout.bind(pos, radius * 0.58, patch_scale + 0.12))

func _signature_plague(phase: String, packet: Dictionary, center: Vector2) -> void:
	var radius: float = max(110.0, float(packet.get("radius", 120.0)) * 1.08)
	var targets: Array = _sort_enemies_by_distance(_get_enemies_in_radius(center, radius), center)
	if targets.is_empty():
		return
	var limit: int = 3 if phase == "tick" else (5 if phase == "line" else 7)
	var refs: Array = []
	for i in range(min(limit, targets.size())):
		var enemy: Node = targets[i]
		_apply_enemy_status(enemy, "poison", 1.8 + (0.6 if phase == "closure" else 0.2), max(1.0, _get_player_base_damage() * 0.18), 1, 0.6)
		_apply_enemy_status(enemy, "slow", 0.9 + 0.2 * float(i), 0.28, 1, 0.1)
		if phase != "tick":
			_apply_enemy_status(enemy, "curse", 1.2, max(1.0, _get_player_base_damage() * 0.12), 1, 0.7)
		refs.append(weakref(enemy))
	if refs.is_empty():
		return
	var delay: float = 0.42 if phase != "closure" else 0.28
	var bloom_radius: float = radius * (0.28 if phase != "closure" else 0.34)
	var bloom_scale: float = 0.34 if phase != "closure" else 0.56
	get_tree().create_timer(delay).timeout.connect(_on_plague_bloom_timeout.bind(refs, bloom_radius, bloom_scale))

func _signature_jailer(phase: String, packet: Dictionary, center: Vector2) -> void:
	var radius: float = max(100.0, float(packet.get("radius", 120.0)) * 1.02)
	var targets: Array = _sort_enemies_by_distance(_get_enemies_in_radius(center, radius), center)
	if targets.is_empty():
		return
	var base_damage: float = _get_player_base_damage()
	var limit: int = 4 if phase == "tick" else (7 if phase == "line" else 10)
	var verdict_refs: Array = []
	for i in range(min(limit, targets.size())):
		var enemy: Node = targets[i]
		_pull_enemy(enemy, center, 10.0 + (8.0 if phase == "closure" else 3.0))
		if phase == "closure":
			_apply_enemy_status(enemy, "stun", 0.52, 0.0, 1, 0.1)
			if _is_enemy_below_threshold(enemy, 0.24):
				_damage_enemy(enemy, base_damage * 2.0, "VERDICT", Color(1.0, 0.5, 0.45))
			else:
				_damage_enemy(enemy, base_damage * 0.60)
		else:
			_apply_enemy_status(enemy, "slow", 1.0 + 0.15 * float(i), 0.34, 1, 0.1)
			_damage_enemy(enemy, base_damage * (0.30 if phase == "line" else 0.20))
			if phase == "line" and i < 3:
				verdict_refs.append(weakref(enemy))
	if phase == "line" and not verdict_refs.is_empty():
		get_tree().create_timer(0.24).timeout.connect(_on_jailer_verdict_timeout.bind(verdict_refs, 0.48))

func _signature_new_tempest(phase: String, packet: Dictionary, center: Vector2) -> void:
	var radius: float = max(110.0, float(packet.get("radius", 120.0)) * 1.12)
	var core_count: int = 1 if phase == "tick" else (2 if phase == "line" else 3)
	var pull_force: float = 12.0 if phase == "tick" else (18.0 if phase == "line" else 24.0)
	var damage_scale: float = 0.28 if phase == "tick" else (0.40 if phase == "line" else 0.56)
	var base_damage: float = _get_player_base_damage()
	for i in range(core_count):
		var angle: float = TAU * float(i) / float(core_count) + (0.18 if phase == "closure" else 0.0)
		var core_pos: Vector2 = center + Vector2.RIGHT.rotated(angle) * radius * (0.34 + 0.06 * float(i % 2))
		for enemy in _get_enemies_in_radius(core_pos, radius * 0.54):
			_pull_enemy(enemy, core_pos, pull_force)
			_damage_enemy(enemy, base_damage * damage_scale)
			_apply_enemy_status(enemy, "slow", 1.1 + (0.3 if phase == "closure" else 0.0), 0.30, 1, 0.1)
	if phase != "tick":
		_apply_temp_meta_delta("buff_speed_boost", 0.08 if phase == "line" else 0.13, 1.6 if phase == "line" else 2.3)

func _signature_vampire(phase: String, packet: Dictionary, center: Vector2) -> void:
	var radius: float = max(95.0, float(packet.get("radius", 120.0)) * 0.96)
	var targets: Array = _sort_enemies_by_distance(_get_enemies_in_radius(center, radius), center)
	if targets.is_empty():
		return
	var base_damage: float = _get_player_base_damage()
	var limit: int = 2 if phase == "tick" else (4 if phase == "line" else 6)
	var self_cost: float = 1.2 if phase == "tick" else (2.0 if phase == "line" else 3.2)
	var heal_scale: float = 0.10 if phase == "tick" else (0.14 if phase == "line" else 0.22)
	_consume_player_health(self_cost)
	var drained: int = 0
	for i in range(min(limit, targets.size())):
		var enemy: Node = targets[i]
		_apply_enemy_status(enemy, "curse", 1.6 + (0.5 if phase == "closure" else 0.2), max(1.0, base_damage * 0.18), 1, 0.6)
		_damage_enemy(enemy, base_damage * (0.34 if phase == "tick" else (0.48 if phase == "line" else 0.72)))
		if phase == "closure" and _is_enemy_below_threshold(enemy, 0.28):
			_damage_enemy(enemy, base_damage * 1.9, "FEAST", Color(1.0, 0.2, 0.2))
		drained += 1
	if drained > 0:
		_heal_player(base_damage * heal_scale * float(drained))

func _signature_train(phase: String, packet: Dictionary, center: Vector2) -> void:
	var radius: float = max(120.0, float(packet.get("radius", 120.0)) * 1.18)
	var lane_len: float = radius * (0.95 if phase == "tick" else 1.14)
	var half_width: float = radius * (0.24 if phase == "tick" else 0.30)
	var aim_dir: Vector2 = _get_player_aim_direction()
	var base_damage: float = _get_player_base_damage()
	var first_scale: float = 0.34 if phase == "tick" else (0.52 if phase == "line" else 0.82)
	var knock_power: float = 120.0 if phase == "tick" else (190.0 if phase == "line" else 280.0)
	for enemy in _get_enemies_in_radius(center, lane_len):
		if not is_instance_valid(enemy) or not (enemy is Node2D):
			continue
		var enemy_node: Node2D = enemy
		var rel: Vector2 = enemy_node.global_position - center
		var forward: float = rel.dot(aim_dir)
		if forward < -20.0 or forward > lane_len:
			continue
		var side: float = absf(rel.dot(aim_dir.orthogonal()))
		if side > half_width:
			continue
		_damage_enemy(enemy, base_damage * first_scale, "RAIL", Color(1.0, 0.82, 0.35))
		_knock_enemy(enemy, center - aim_dir * 45.0, knock_power)
		_apply_enemy_status(enemy, "slow", 0.9 + (0.4 if phase == "closure" else 0.1), 0.30, 1, 0.1)
	if phase != "tick":
		var delay: float = 0.22 if phase == "line" else 0.15
		var second_scale: float = 0.40 if phase == "line" else 0.72
		get_tree().create_timer(delay).timeout.connect(_on_train_aftershock_timeout.bind(center, aim_dir, lane_len, half_width * 1.16, second_scale))

func _signature_new_totem(phase: String, packet: Dictionary, center: Vector2) -> void:
	var radius: float = max(100.0, float(packet.get("radius", 120.0)) * 1.02)
	var pulse_count: int = 1 if phase == "tick" else (2 if phase == "line" else 3)
	var pulse_scale: float = 0.26 if phase == "tick" else (0.40 if phase == "line" else 0.58)
	var aim_dir: Vector2 = _get_player_aim_direction()
	for i in range(pulse_count):
		var ratio: float = 0.5 if pulse_count <= 1 else float(i) / float(pulse_count - 1)
		var angle: float = lerp(-0.85, 0.85, ratio)
		var dir: Vector2 = aim_dir.rotated(angle)
		var pos: Vector2 = center + dir * (54.0 + 24.0 * float(i))
		var delay: float = 0.11 * float(i)
		get_tree().create_timer(delay).timeout.connect(_on_new_totem_pulse_timeout.bind(pos, radius * 0.52, pulse_scale + 0.08 * float(i), phase == "closure"))
	if phase != "tick":
		_gain_energy(2.0 if phase == "line" else 3.5)

func _signature_goo(phase: String, packet: Dictionary, center: Vector2) -> void:
	var radius: float = max(96.0, float(packet.get("radius", 120.0)) * 1.06)
	var pool_count: int = 1 if phase == "tick" else (2 if phase == "line" else 3)
	var duration: float = 1.6 if phase == "tick" else (2.3 if phase == "line" else 3.0)
	var scale: float = 0.22 if phase == "tick" else (0.32 if phase == "line" else 0.46)
	var split_count: int = 0 if phase != "closure" else 1
	for i in range(pool_count):
		var angle: float = randf_range(0.0, TAU)
		var offset_len: float = radius * (0.18 + 0.26 * randf())
		var pos: Vector2 = center + Vector2(cos(angle), sin(angle)) * offset_len
		_spawn_goo_pool(pos, radius * (0.30 + 0.06 * float(i)), duration, scale, split_count)

func _signature_illusionist(phase: String, packet: Dictionary, center: Vector2) -> void:
	var radius: float = max(105.0, float(packet.get("radius", 120.0)) * 1.04)
	var targets: Array = _sort_enemies_by_distance(_get_enemies_in_radius(center, radius), center)
	if targets.is_empty():
		return
	var limit: int = 2 if phase == "tick" else (4 if phase == "line" else 6)
	var base_damage: float = _get_player_base_damage()
	var shot_scale: float = 0.32 if phase == "tick" else (0.50 if phase == "line" else 0.72)
	for i in range(min(limit, targets.size())):
		var enemy: Node = targets[i]
		if not is_instance_valid(enemy) or not (enemy is Node2D):
			continue
		var enemy_node: Node2D = enemy
		_apply_enemy_status(enemy, "marked", 1.1 + (0.4 if phase == "closure" else 0.1), 0.20, 1, 0.3)
		_damage_enemy(enemy, base_damage * 0.24)
		var mirror_dir: Vector2 = (center - enemy_node.global_position).normalized()
		var mirror_pos: Vector2 = center + mirror_dir * min(radius * 0.45, 92.0)
		var delay: float = 0.16 + 0.04 * float(i)
		get_tree().create_timer(delay).timeout.connect(_on_illusionist_mirror_timeout.bind(weakref(enemy), mirror_pos, shot_scale))

func _signature_voodoo(phase: String, packet: Dictionary, center: Vector2) -> void:
	var radius: float = max(105.0, float(packet.get("radius", 120.0)) * 1.00)
	var targets: Array = _sort_enemies_by_distance(_get_enemies_in_radius(center, radius), center)
	if targets.is_empty():
		return
	var refs: Array = []
	var limit: int = 2 if phase == "tick" else (4 if phase == "line" else 5)
	for i in range(min(limit, targets.size())):
		var enemy: Node = targets[i]
		_apply_enemy_status(enemy, "curse", 1.8 + (0.4 if phase == "closure" else 0.0), max(1.0, _get_player_base_damage() * 0.16), 1, 0.7)
		_apply_enemy_status(enemy, "marked", 1.0, 0.16, 1, 0.3)
		refs.append(weakref(enemy))
	if refs.is_empty():
		return
	var delay: float = 0.38 if phase != "closure" else 0.24
	var link_scale: float = 0.30 if phase != "closure" else 0.52
	get_tree().create_timer(delay).timeout.connect(_on_voodoo_link_timeout.bind(refs, center, link_scale))

func _signature_merchant(phase: String, packet: Dictionary, center: Vector2) -> void:
	var radius: float = max(100.0, float(packet.get("radius", 120.0)) * 0.98)
	var targets: Array = _sort_enemies_by_distance(_get_enemies_in_radius(center, radius), center)
	if targets.is_empty():
		return
	var base_damage: float = _get_player_base_damage()
	var limit: int = 3 if phase == "tick" else (6 if phase == "line" else 8)
	var coin_total: int = 0
	for i in range(min(limit, targets.size())):
		var enemy: Node = targets[i]
		_apply_enemy_status(enemy, "marked", 1.2 + (0.3 if phase == "closure" else 0.0), 0.18, 1, 0.3)
		_damage_enemy(enemy, base_damage * (0.22 if phase == "tick" else (0.34 if phase == "line" else 0.50)))
		if _is_enemy_below_threshold(enemy, 0.30 if phase == "closure" else 0.22):
			if enemy is Node2D:
				var enemy_node: Node2D = enemy
				_drop_coins_at(enemy_node.global_position, 1)
			coin_total += 1
	if phase != "tick":
		_apply_temp_meta_delta("buff_speed_boost", 0.06 if phase == "line" else 0.12, 1.6 if phase == "line" else 2.4)
		_gain_energy(1.6 if phase == "line" else 2.6)
	if phase == "closure" and coin_total >= 3:
		_drop_coins(1)

func _signature_vacuum(phase: String, packet: Dictionary, center: Vector2) -> void:
	var radius: float = max(130.0, float(packet.get("radius", 120.0)) * 1.20)
	var pull_force: float = 12.0 if phase == "tick" else (18.0 if phase == "line" else 28.0)
	var base_damage: float = _get_player_base_damage()
	for enemy in _get_enemies_in_radius(center, radius):
		_pull_enemy(enemy, center, pull_force)
		_apply_enemy_status(enemy, "slow", 0.9 + (0.4 if phase == "closure" else 0.1), 0.30, 1, 0.1)
		if phase == "closure":
			_damage_enemy(enemy, base_damage * 0.46)
	if phase != "tick":
		var delay: float = 0.22 if phase == "line" else 0.16
		var implode_scale: float = 0.44 if phase == "line" else 0.72
		get_tree().create_timer(delay).timeout.connect(_on_vacuum_implode_timeout.bind(center, radius * 0.56, implode_scale))

func _signature_executioner(phase: String, packet: Dictionary, center: Vector2) -> void:
	var radius: float = max(95.0, float(packet.get("radius", 120.0)) * 0.90)
	var targets: Array = _sort_enemies_by_distance(_get_enemies_in_radius(center, radius), center)
	if targets.is_empty():
		return
	var base_damage: float = _get_player_base_damage()
	var threshold: float = 0.26 if phase == "tick" else (0.32 if phase == "line" else 0.40)
	var limit: int = 3 if phase == "tick" else (5 if phase == "line" else 7)
	var execute_count: int = 0
	for i in range(min(limit, targets.size())):
		var enemy: Node = targets[i]
		if _is_enemy_below_threshold(enemy, threshold):
			_damage_enemy(enemy, base_damage * (1.6 if phase == "tick" else (2.2 if phase == "line" else 3.2)), "EXEC", Color(1.0, 0.2, 0.2))
			execute_count += 1
		else:
			_damage_enemy(enemy, base_damage * (0.30 if phase == "tick" else (0.46 if phase == "line" else 0.64)))
			_apply_enemy_status(enemy, "marked", 1.3 + (0.6 if phase == "closure" else 0.0), 0.22, 1, 0.3)
			if phase == "closure":
				_apply_enemy_status(enemy, "slow", 0.9, 0.34, 1, 0.1)
	if execute_count > 0:
		_gain_energy(1.0 + float(execute_count) * 0.6)
	if phase == "closure":
		var guillotine_scale: float = 0.74 + 0.08 * float(min(3, execute_count))
		get_tree().create_timer(0.18).timeout.connect(_on_executioner_guillotine_timeout.bind(center, radius * 0.58, guillotine_scale))

func _signature_gambler(phase: String, packet: Dictionary, center: Vector2) -> void:
	if not is_instance_valid(player_ref):
		return
	var radius: float = max(100.0, float(packet.get("radius", 120.0)) * 1.00)
	var base_damage: float = _get_player_base_damage()
	var streak: int = 0
	if player_ref.has_meta("gambler_jackpot_streak"):
		streak = int(player_ref.get_meta("gambler_jackpot_streak"))
	var roll: float = randf() - min(0.28, float(streak) * 0.08)
	var jackpot: bool = roll < 0.22
	if jackpot:
		player_ref.set_meta("gambler_jackpot_streak", 0)
		for enemy in _get_enemies_in_radius(center, radius * 0.75):
			_damage_enemy(enemy, base_damage * (0.74 if phase != "closure" else 1.05), "JACKPOT", Color(1.0, 0.82, 0.3))
			_apply_enemy_status(enemy, "marked", 1.6, 0.24, 1, 0.3)
		_drop_coins(2 if phase != "closure" else 4)
		_apply_temp_attack_boost(2.0 if phase != "closure" else 2.8, 0.10 if phase != "closure" else 0.16)
		return
	player_ref.set_meta("gambler_jackpot_streak", streak + 1)
	var safe_outcome: bool = roll < 0.72
	if safe_outcome:
		for enemy in _get_enemies_in_radius(center, radius):
			_damage_enemy(enemy, base_damage * (0.26 if phase == "tick" else (0.40 if phase == "line" else 0.54)))
			_apply_enemy_status(enemy, "marked", 1.1, 0.18, 1, 0.3)
		_gain_energy(2.0 if phase != "closure" else 3.0)
	else:
		for enemy in _get_enemies_in_radius(center, radius * 1.12):
			_apply_enemy_status(enemy, "slow", 1.2 + (0.4 if phase == "closure" else 0.0), 0.30, 1, 0.1)
			_damage_enemy(enemy, base_damage * (0.18 if phase == "tick" else 0.30))
		_consume_player_health(1.2 if phase != "closure" else 2.2)
		_gain_energy(3.2 if phase != "closure" else 4.5)
		_drop_coins(1)

func _on_new_pyro_rune_timeout(center: Vector2, radius: float, damage_scale: float) -> void:
	var damage: float = _get_player_base_damage() * damage_scale
	for enemy in _get_enemies_in_radius(center, radius):
		_damage_enemy(enemy, damage, "RUNE", Color(1.0, 0.45, 0.2))
		_apply_enemy_status(enemy, "burn", 1.5, max(1.0, damage * 0.42), 1, 0.5)
		_knock_enemy(enemy, center, 90.0)

func _on_plague_bloom_timeout(target_refs: Array, bloom_radius: float, bloom_scale: float) -> void:
	var damage: float = _get_player_base_damage() * bloom_scale
	for ref_obj in target_refs:
		var target = ref_obj.get_ref() if ref_obj != null else null
		if target == null or not is_instance_valid(target):
			continue
		if not (target is Node2D):
			continue
		var target_node: Node2D = target
		for enemy in _get_enemies_in_radius(target_node.global_position, bloom_radius):
			_damage_enemy(enemy, damage)
			_apply_enemy_status(enemy, "poison", 1.4, max(1.0, damage * 0.36), 1, 0.6)
			_apply_enemy_status(enemy, "slow", 0.8, 0.22, 1, 0.1)

func _on_jailer_verdict_timeout(target_refs: Array, damage_scale: float) -> void:
	var damage: float = _get_player_base_damage() * damage_scale
	for ref_obj in target_refs:
		var target = ref_obj.get_ref() if ref_obj != null else null
		if target == null or not is_instance_valid(target):
			continue
		_damage_enemy(target, damage, "LOCK", Color(0.95, 0.7, 0.5))
		_apply_enemy_status(target, "stun", 0.34, 0.0, 1, 0.1)

func _on_train_aftershock_timeout(center: Vector2, aim_dir: Vector2, lane_len: float, half_width: float, damage_scale: float) -> void:
	var damage: float = _get_player_base_damage() * damage_scale
	for enemy in _get_enemies_in_radius(center, lane_len):
		if not is_instance_valid(enemy) or not (enemy is Node2D):
			continue
		var enemy_node: Node2D = enemy
		var rel: Vector2 = enemy_node.global_position - center
		var forward: float = rel.dot(aim_dir)
		if forward < -20.0 or forward > lane_len:
			continue
		var side: float = absf(rel.dot(aim_dir.orthogonal()))
		if side > half_width:
			continue
		_damage_enemy(enemy, damage, "AFTERSHOCK", Color(1.0, 0.88, 0.45))
		_knock_enemy(enemy, center, 170.0)

func _on_new_totem_pulse_timeout(center: Vector2, radius: float, damage_scale: float, apply_stun: bool) -> void:
	var damage: float = _get_player_base_damage() * damage_scale
	for enemy in _get_enemies_in_radius(center, radius):
		_damage_enemy(enemy, damage, "PULSE", Color(0.62, 0.95, 1.0))
		_apply_enemy_status(enemy, "marked", 1.2, 0.20, 1, 0.3)
		_apply_enemy_status(enemy, "slow", 0.9, 0.22, 1, 0.1)
		if apply_stun:
			_apply_enemy_status(enemy, "stun", 0.24, 0.0, 1, 0.1)

func _on_illusionist_mirror_timeout(target_ref: WeakRef, mirror_pos: Vector2, damage_scale: float) -> void:
	var target = target_ref.get_ref() if target_ref != null else null
	if target == null or not is_instance_valid(target):
		return
	var damage: float = _get_player_base_damage() * damage_scale
	_damage_enemy(target, damage, "MIRROR", Color(0.85, 0.65, 1.0))
	_apply_enemy_status(target, "marked", 1.3, 0.22, 1, 0.3)
	for enemy in _get_enemies_in_radius(mirror_pos, 70.0):
		if enemy == target:
			continue
		_damage_enemy(enemy, damage * 0.42)
		_apply_enemy_status(enemy, "slow", 0.8, 0.24, 1, 0.1)

func _on_voodoo_link_timeout(target_refs: Array, center: Vector2, damage_scale: float) -> void:
	var damage: float = _get_player_base_damage() * damage_scale
	var valid_targets: Array = []
	for ref_obj in target_refs:
		var target = ref_obj.get_ref() if ref_obj != null else null
		if target == null or not is_instance_valid(target):
			continue
		valid_targets.append(target)
	if valid_targets.is_empty():
		return
	for target in valid_targets:
		_damage_enemy(target, damage, "HEX", Color(0.78, 0.42, 1.0))
		_apply_enemy_status(target, "curse", 1.6, max(1.0, damage * 0.45), 1, 0.7)
		_pull_enemy(target, center, 8.0)

func _on_vacuum_implode_timeout(center: Vector2, radius: float, damage_scale: float) -> void:
	var damage: float = _get_player_base_damage() * damage_scale
	for enemy in _get_enemies_in_radius(center, radius):
		_damage_enemy(enemy, damage, "IMPLODE", Color(0.7, 0.95, 1.0))
		_knock_enemy(enemy, center, 210.0)

func _on_executioner_guillotine_timeout(center: Vector2, radius: float, damage_scale: float) -> void:
	var damage: float = _get_player_base_damage() * damage_scale
	var targets: Array = _sort_enemies_by_distance(_get_enemies_in_radius(center, radius), center)
	for i in range(min(5, targets.size())):
		var enemy: Node = targets[i]
		_damage_enemy(enemy, damage, "GUILLOTINE", Color(1.0, 0.26, 0.26))
		_apply_enemy_status(enemy, "slow", 0.9, 0.30, 1, 0.1)

func _on_necro_reap_timeout(target_refs: Array, damage_scale: float, center: Vector2) -> void:
	var base_damage: float = _get_player_base_damage()
	for ref_obj in target_refs:
		var target = ref_obj.get_ref() if ref_obj != null else null
		if target == null or not is_instance_valid(target):
			continue
		_damage_enemy(target, base_damage * damage_scale, "REAP", Color(0.75, 0.3, 0.95))
		_pull_enemy(target, center, 10.0)
		_apply_enemy_status(target, "slow", 0.9, 0.26, 1, 0.1)

func _on_hunter_shot_timeout(target_ref: WeakRef, damage_scale: float) -> void:
	var target = target_ref.get_ref() if target_ref != null else null
	if target == null or not is_instance_valid(target):
		return
	var base_damage: float = _get_player_base_damage()
	if _is_enemy_below_threshold(target, 0.2):
		_damage_enemy(target, base_damage * max(1.6, damage_scale * 2.0), "EXECUTE", Color(1.0, 0.25, 0.25))
	else:
		_damage_enemy(target, base_damage * damage_scale, "HUNT", Color(0.75, 1.0, 0.55))

func _build_chain_targets(origin: Vector2, radius: float, max_count: int, link_range: float) -> Array:
	var result: Array = []
	var first: Node2D = _pick_nearest_enemy(origin, radius, [])
	if first == null:
		return result
	result.append(first)
	var used: Array = [first]
	var current_pos: Vector2 = first.global_position
	for i in range(max(0, max_count - 1)):
		var next_enemy: Node2D = _pick_nearest_enemy(current_pos, link_range, used)
		if next_enemy == null:
			break
		result.append(next_enemy)
		used.append(next_enemy)
		current_pos = next_enemy.global_position
	return result

func _pick_nearest_enemy(origin: Vector2, radius: float, used: Array) -> Node2D:
	var nearest: Node2D = null
	var nearest_dist: float = radius
	var enemies: Array = _get_enemies_in_radius(origin, radius)
	for enemy in enemies:
		if used.has(enemy):
			continue
		if not is_instance_valid(enemy) or not (enemy is Node2D):
			continue
		var enemy_node: Node2D = enemy
		var dist: float = origin.distance_to(enemy_node.global_position)
		if dist <= nearest_dist:
			nearest = enemy_node
			nearest_dist = dist
	return nearest

func _pick_hunter_target(center: Vector2, radius: float) -> Node2D:
	var enemies: Array = _sort_enemies_by_distance(_get_enemies_in_radius(center, radius), center)
	if enemies.is_empty():
		return null
	for enemy in enemies:
		if enemy.has_method("has_status") and enemy.has_status("marked"):
			return enemy
	return enemies[0]

func _apply_temp_attack_boost(duration: float, bonus: float) -> void:
	if bonus <= 0.0 or duration <= 0.0:
		return
	if not is_instance_valid(player_ref):
		return
	var current: float = 0.0
	if player_ref.has_meta("attack_boost"):
		current = float(player_ref.get_meta("attack_boost"))
	player_ref.set_meta("attack_boost", current + bonus)
	get_tree().create_timer(duration).timeout.connect(_on_temp_attack_boost_timeout.bind(bonus))

func _on_temp_attack_boost_timeout(bonus: float) -> void:
	if bonus <= 0.0:
		return
	if not is_instance_valid(player_ref):
		return
	if not player_ref.has_meta("attack_boost"):
		return
	var current: float = float(player_ref.get_meta("attack_boost"))
	var next: float = current - bonus
	if absf(next) <= 0.001:
		player_ref.remove_meta("attack_boost")
	else:
		player_ref.set_meta("attack_boost", next)

func _spawn_turret_pylon(pos: Vector2, radius: float, duration: float, damage_scale: float) -> void:
	if _turret_pylons.size() >= 4:
		var oldest: Node = _turret_pylons[0]
		if is_instance_valid(oldest):
			oldest.queue_free()
		_erase_node_from_array(_turret_pylons, oldest)

	var pylon: Node2D = Node2D.new()
	pylon.global_position = pos
	pylon.z_index = 58
	pylon.set_meta("radius", radius)
	pylon.set_meta("damage_scale", damage_scale)

	var visual: Polygon2D = Polygon2D.new()
	visual.polygon = PackedVector2Array([
		Vector2(0.0, -12.0),
		Vector2(11.0, 10.0),
		Vector2(-11.0, 10.0),
	])
	visual.color = Color(0.55, 0.72, 0.4, 0.9)
	visual.z_index = 58
	pylon.add_child(visual)

	var scene: Node = get_tree().current_scene if get_tree() else self
	scene.add_child(pylon)
	_turret_pylons.append(pylon)

	var tick_timer: Timer = Timer.new()
	tick_timer.wait_time = 0.35
	tick_timer.one_shot = false
	tick_timer.autostart = true
	pylon.add_child(tick_timer)
	tick_timer.timeout.connect(_on_turret_pylon_tick.bind(pylon))

	var life_timer: Timer = Timer.new()
	life_timer.wait_time = max(0.4, duration)
	life_timer.one_shot = true
	life_timer.autostart = true
	pylon.add_child(life_timer)
	life_timer.timeout.connect(_on_turret_pylon_timeout.bind(pylon))

func _on_turret_pylon_tick(pylon: Node2D) -> void:
	if not is_instance_valid(pylon):
		return
	var radius: float = float(pylon.get_meta("radius", 80.0))
	var damage_scale: float = float(pylon.get_meta("damage_scale", 0.35))
	var damage: float = _get_player_base_damage() * damage_scale
	var enemies: Array = _get_enemies_in_radius(pylon.global_position, radius)
	var hit: int = 0
	for enemy in enemies:
		if hit >= 4:
			break
		_damage_enemy(enemy, damage)
		_apply_enemy_status(enemy, "marked", 1.1, 0.18, 1, 0.4)
		hit += 1

func _on_turret_pylon_timeout(pylon: Node2D) -> void:
	if is_instance_valid(pylon):
		pylon.queue_free()
	_erase_node_from_array(_turret_pylons, pylon)

func _spawn_pyro_patch(center: Vector2, radius: float, duration: float, damage_scale: float) -> void:
	if not is_inside_tree():
		return
	var patch: Node2D = Node2D.new()
	patch.global_position = center
	patch.set_meta("radius", radius)
	patch.set_meta("damage_scale", damage_scale)
	patch.z_index = 56

	var visual: Polygon2D = Polygon2D.new()
	visual.polygon = _build_circle_polygon(radius, 18)
	visual.color = Color(1.0, 0.38, 0.12, 0.35)
	visual.z_index = 56
	patch.add_child(visual)

	var scene: Node = get_tree().current_scene if get_tree() else self
	scene.add_child(patch)
	_pyro_patches.append(patch)

	var tick_timer: Timer = Timer.new()
	tick_timer.wait_time = 0.35
	tick_timer.autostart = true
	tick_timer.one_shot = false
	patch.add_child(tick_timer)
	tick_timer.timeout.connect(_on_pyro_patch_tick.bind(patch))

	var life_timer: Timer = Timer.new()
	life_timer.wait_time = max(0.45, duration)
	life_timer.autostart = true
	life_timer.one_shot = true
	patch.add_child(life_timer)
	life_timer.timeout.connect(_on_pyro_patch_timeout.bind(patch))

func _on_pyro_patch_tick(patch: Node2D) -> void:
	if not is_instance_valid(patch):
		return
	var radius: float = float(patch.get_meta("radius", 60.0))
	var scale: float = float(patch.get_meta("damage_scale", 0.25))
	var damage: float = _get_player_base_damage() * scale
	var enemies: Array = _get_enemies_in_radius(patch.global_position, radius)
	for enemy in enemies:
		_damage_enemy(enemy, damage)
		_apply_enemy_status(enemy, "burn", 1.5, max(1.0, damage * 0.45), 1, 0.5)

func _on_pyro_patch_timeout(patch: Node2D) -> void:
	if is_instance_valid(patch):
		patch.queue_free()
	_erase_node_from_array(_pyro_patches, patch)

func _spawn_goo_pool(pos: Vector2, radius: float, duration: float, damage_scale: float, split_count: int) -> void:
	if not is_inside_tree():
		return
	if _goo_pools.size() >= 8:
		var oldest: Node = _goo_pools[0]
		if is_instance_valid(oldest):
			oldest.queue_free()
		_erase_node_from_array(_goo_pools, oldest)

	var pool: Node2D = Node2D.new()
	pool.global_position = pos
	pool.z_index = 55
	pool.set_meta("radius", radius)
	pool.set_meta("damage_scale", damage_scale)
	pool.set_meta("split_count", split_count)

	var visual: Polygon2D = Polygon2D.new()
	visual.polygon = _build_circle_polygon(radius, 16)
	visual.color = Color(0.4, 0.85, 0.45, 0.35)
	visual.z_index = 55
	pool.add_child(visual)

	var scene: Node = get_tree().current_scene if get_tree() else self
	scene.add_child(pool)
	_goo_pools.append(pool)

	var tick_timer: Timer = Timer.new()
	tick_timer.wait_time = 0.35
	tick_timer.one_shot = false
	tick_timer.autostart = true
	pool.add_child(tick_timer)
	tick_timer.timeout.connect(_on_goo_pool_tick.bind(pool))

	var life_timer: Timer = Timer.new()
	life_timer.wait_time = max(0.45, duration)
	life_timer.one_shot = true
	life_timer.autostart = true
	pool.add_child(life_timer)
	life_timer.timeout.connect(_on_goo_pool_timeout.bind(pool))

func _on_goo_pool_tick(pool: Node2D) -> void:
	if not is_instance_valid(pool):
		return
	var radius: float = float(pool.get_meta("radius", 50.0))
	var scale: float = float(pool.get_meta("damage_scale", 0.25))
	var damage: float = _get_player_base_damage() * scale
	for enemy in _get_enemies_in_radius(pool.global_position, radius):
		_damage_enemy(enemy, damage)
		_apply_enemy_status(enemy, "poison", 1.4, max(1.0, damage * 0.38), 1, 0.6)
		_apply_enemy_status(enemy, "slow", 0.9, 0.26, 1, 0.1)

func _on_goo_pool_timeout(pool: Node2D) -> void:
	if not is_instance_valid(pool):
		_erase_node_from_array(_goo_pools, pool)
		return
	var split_count: int = int(pool.get_meta("split_count", 0))
	var radius: float = float(pool.get_meta("radius", 50.0))
	var scale: float = float(pool.get_meta("damage_scale", 0.25))
	var center: Vector2 = pool.global_position
	pool.queue_free()
	_erase_node_from_array(_goo_pools, pool)
	if split_count <= 0:
		return
	for i in range(2):
		var angle: float = randf_range(0.0, TAU)
		var offset: Vector2 = Vector2(cos(angle), sin(angle)) * radius * 0.65
		_spawn_goo_pool(center + offset, max(26.0, radius * 0.62), 1.2, max(0.12, scale * 0.75), split_count - 1)

func _spawn_sapper_mine(pos: Vector2, delay: float, radius: float, damage_scale: float) -> void:
	if not is_inside_tree():
		return
	if _sapper_mines.size() >= 6:
		var oldest: Node = _sapper_mines[0]
		_detonate_sapper_mine(oldest, false)

	var mine: Node2D = Node2D.new()
	mine.global_position = pos
	mine.set_meta("radius", radius)
	mine.set_meta("damage_scale", damage_scale)
	mine.z_index = 57

	var marker: Polygon2D = Polygon2D.new()
	marker.polygon = PackedVector2Array([
		Vector2(0, -10), Vector2(9, 6), Vector2(-9, 6),
	])
	marker.color = Color(1.0, 0.78, 0.22, 0.95)
	marker.z_index = 57
	mine.add_child(marker)

	var scene: Node = get_tree().current_scene if get_tree() else self
	scene.add_child(mine)
	_sapper_mines.append(mine)

	var timer: Timer = Timer.new()
	timer.wait_time = max(0.25, delay)
	timer.one_shot = true
	timer.autostart = true
	mine.add_child(timer)
	timer.timeout.connect(_on_sapper_mine_timeout.bind(mine))

func _on_sapper_mine_timeout(mine: Node) -> void:
	_detonate_sapper_mine(mine, false)

func _detonate_all_sapper_mines(from_closure: bool) -> void:
	var snapshot: Array = _sapper_mines.duplicate()
	for mine in snapshot:
		_detonate_sapper_mine(mine, from_closure)

func _detonate_sapper_mine(mine: Node, from_closure: bool) -> void:
	if not is_instance_valid(mine):
		_erase_node_from_array(_sapper_mines, mine)
		return
	var center: Vector2 = (mine as Node2D).global_position
	var radius: float = float(mine.get_meta("radius", 52.0))
	var scale: float = float(mine.get_meta("damage_scale", 0.52))
	if from_closure:
		scale *= 1.35
	var damage: float = _get_player_base_damage() * scale
	var enemies: Array = _get_enemies_in_radius(center, radius)
	for enemy in enemies:
		_damage_enemy(enemy, damage)
		_apply_enemy_status(enemy, "marked", 1.2, 0.18, 1, 0.4)
		_apply_enemy_status(enemy, "slow", 0.8, 0.28, 1, 0.1)
	spawn_skill_vfx(center, Color(1.2, 0.8, 0.25, 0.85), 0.4)
	mine.queue_free()
	_erase_node_from_array(_sapper_mines, mine)

func _add_player_armor(value: int) -> void:
	if value <= 0:
		return
	if not is_instance_valid(player_ref):
		return
	if not ("armor" in player_ref and "max_armor" in player_ref):
		return
	var before: int = int(player_ref.armor)
	var after: int = min(int(player_ref.max_armor), before + value)
	if after <= before:
		return
	player_ref.armor = after
	if player_ref.has_signal("armor_changed"):
		player_ref.armor_changed.emit(after)

func _sort_enemies_by_distance(enemies: Array, center: Vector2) -> Array:
	var sorted: Array = []
	for enemy in enemies:
		if not is_instance_valid(enemy) or not (enemy is Node2D):
			continue
		var enemy_node: Node2D = enemy
		var dist: float = enemy_node.global_position.distance_to(center)
		var inserted: bool = false
		for i in range(sorted.size()):
			var current: Node2D = sorted[i]
			var current_dist: float = current.global_position.distance_to(center)
			if dist < current_dist:
				sorted.insert(i, enemy_node)
				inserted = true
				break
		if not inserted:
			sorted.append(enemy_node)
	return sorted

func _get_player_aim_direction() -> Vector2:
	if not is_instance_valid(player_ref) or not (player_ref is Node2D):
		return Vector2.RIGHT
	var player_node: Node2D = player_ref
	var dir: Vector2 = player_node.get_global_mouse_position() - player_node.global_position
	if dir.length_squared() <= 0.01:
		return Vector2.RIGHT
	return dir.normalized()

func _build_circle_polygon(radius: float, segments: int) -> PackedVector2Array:
	var points: PackedVector2Array = PackedVector2Array()
	var seg_count: int = max(6, segments)
	for i in range(seg_count):
		var angle: float = TAU * float(i) / float(seg_count)
		points.append(Vector2(cos(angle), sin(angle)) * radius)
	return points

func _erase_node_from_array(arr: Array, node: Node) -> void:
	var idx: int = arr.find(node)
	if idx >= 0:
		arr.remove_at(idx)

func _clear_signature_nodes() -> void:
	for mine in _sapper_mines:
		if is_instance_valid(mine):
			mine.queue_free()
	_sapper_mines.clear()
	for patch in _pyro_patches:
		if is_instance_valid(patch):
			patch.queue_free()
	_pyro_patches.clear()
	for pylon in _turret_pylons:
		if is_instance_valid(pylon):
			pylon.queue_free()
	_turret_pylons.clear()
	for pool in _goo_pools:
		if is_instance_valid(pool):
			pool.queue_free()
	_goo_pools.clear()

func _get_enemies_in_radius(center: Vector2, radius: float) -> Array:
	var enemies: Array = []
	var tree := get_tree()
	if tree == null:
		return enemies

	for node in tree.get_nodes_in_group("enemies"):
		if not is_instance_valid(node):
			continue
		if not (node is Node2D):
			continue
		var enemy := node as Node2D
		if center.distance_to(enemy.global_position) <= radius:
			enemies.append(enemy)
	return enemies

func _get_player_base_damage() -> float:
	var base_damage = 12.0
	if is_instance_valid(player_ref) and ("damage" in player_ref):
		base_damage = max(base_damage, float(player_ref.damage))
	return base_damage

func _damage_enemy(enemy: Node, amount: float, text: String = "", text_color: Color = Color(1.0, 0.85, 0.2)) -> void:
	if not is_instance_valid(enemy):
		return
	if enemy.has_node("HealthComponent"):
		var hc = enemy.get_node("HealthComponent")
		if hc and hc.has_method("take_damage"):
			hc.take_damage(max(1.0, amount))
	if text != "":
		Global.spawn_floating_text(enemy.global_position, text, text_color)

func _apply_enemy_status(enemy: Node, status: String, duration: float, value: float, stacks: int, tick_interval: float) -> void:
	if not is_instance_valid(enemy):
		return
	if enemy.has_method("apply_status"):
		enemy.apply_status(status, max(0.1, duration), value, max(1, stacks), max(0.05, tick_interval))

func _is_enemy_below_threshold(enemy: Node, threshold: float) -> bool:
	if not is_instance_valid(enemy):
		return false
	if not enemy.has_node("HealthComponent"):
		return false

	var hc = enemy.get_node("HealthComponent")
	if hc == null:
		return false
	var max_health = float(hc.get("max_health"))
	if max_health <= 0.0:
		return false
	var current_health = float(hc.get("current_health"))
	return current_health <= max_health * max(0.0, threshold)

func _pull_enemy(enemy: Node, center: Vector2, distance: float) -> void:
	if not (enemy is Node2D):
		return
	var enemy_node := enemy as Node2D
	var diff = center - enemy_node.global_position
	if diff.length_squared() <= 1.0:
		return
	enemy_node.global_position += diff.normalized() * distance

func _knock_enemy(enemy: Node, center: Vector2, power: float) -> void:
	if enemy.has_method("apply_knockback") and enemy is Node2D:
		var enemy_node1 := enemy as Node2D
		var dir = center.direction_to(enemy_node1.global_position)
		enemy.apply_knockback(dir, power)
		return

	if enemy is Node2D:
		var enemy_node := enemy as Node2D
		var dir2 = center.direction_to(enemy_node.global_position)
		enemy_node.global_position += dir2 * power * 0.02

func _gain_energy(amount: float) -> void:
	if amount <= 0.0:
		return
	if is_instance_valid(player_ref) and player_ref.has_method("gain_energy"):
		player_ref.gain_energy(amount)

func _heal_player(amount: float) -> void:
	if amount <= 0.0:
		return
	if not is_instance_valid(player_ref):
		return
	if not player_ref.has_node("HealthComponent"):
		return

	var hc = player_ref.get_node("HealthComponent")
	if hc and hc.has_method("heal"):
		hc.heal(amount)

func _consume_player_health(amount: float) -> void:
	if amount <= 0.0:
		return
	if not is_instance_valid(player_ref):
		return
	if not player_ref.has_node("HealthComponent"):
		return
	var hc = player_ref.get_node("HealthComponent")
	if hc and hc.has_method("take_damage"):
		hc.take_damage(amount)

func _drop_coins(count: int) -> void:
	if count <= 0:
		return
	if not is_instance_valid(player_ref):
		return
	if not Global.has_method("spawn_coin"):
		return

	for i in range(count):
		var offset = Vector2(randf_range(-70.0, 70.0), randf_range(-70.0, 70.0))
		Global.spawn_coin(player_ref.global_position + offset, 1)

func _drop_coins_at(center: Vector2, count: int) -> void:
	if count <= 0:
		return
	if not Global.has_method("spawn_coin"):
		return
	for i in range(count):
		var offset: Vector2 = Vector2(randf_range(-45.0, 45.0), randf_range(-45.0, 45.0))
		Global.spawn_coin(center + offset, 1)

func _apply_temp_meta_delta(meta_key: String, delta: float, duration: float) -> void:
	if meta_key.strip_edges() == "":
		return
	if absf(delta) <= 0.0001 or duration <= 0.0:
		return
	if not is_instance_valid(player_ref):
		return
	var current: float = 0.0
	if player_ref.has_meta(meta_key):
		current = float(player_ref.get_meta(meta_key))
	player_ref.set_meta(meta_key, current + delta)
	get_tree().create_timer(duration).timeout.connect(_on_temp_meta_delta_timeout.bind(meta_key, delta))

func _on_temp_meta_delta_timeout(meta_key: String, delta: float) -> void:
	if meta_key.strip_edges() == "":
		return
	if absf(delta) <= 0.0001:
		return
	if not is_instance_valid(player_ref):
		return
	if not player_ref.has_meta(meta_key):
		return
	var current: float = float(player_ref.get_meta(meta_key))
	var next: float = current - delta
	if absf(next) <= 0.0001:
		player_ref.remove_meta(meta_key)
	else:
		player_ref.set_meta(meta_key, next)

func _get_payload_scale(payload: String) -> float:
	if payload.strip_edges() == "":
		return 1.0
	if BondManager == null or not BondManager.has_method("get_active_bond_level"):
		return 1.0

	var payload_map = _parse_payload(payload)
	var tag = str(payload_map.get("tag", "")).strip_edges()
	if tag == "":
		return 1.0

	var level = int(BondManager.get_active_bond_level(tag))
	var lv2 = _safe_to_float(payload_map.get("lv2", "0.0"))
	var lv3 = _safe_to_float(payload_map.get("lv3", "0.0"))

	var bonus = 0.0
	if level >= 3:
		bonus = lv3
	elif level >= 2:
		bonus = lv2
	return max(1.0, 1.0 + bonus)

func _parse_payload(payload: String) -> Dictionary:
	var parsed: Dictionary = {}
	var text = payload.strip_edges()
	if text == "":
		return parsed

	var items = text.split("|", false)
	for item in items:
		var pair = item.split(":", false, 1)
		if pair.size() < 2:
			continue
		parsed[pair[0].strip_edges()] = pair[1].strip_edges()
	return parsed

func _safe_to_float(value: Variant) -> float:
	var text = str(value).strip_edges()
	if text.is_valid_float():
		return float(text)
	if text.is_valid_int():
		return float(int(text))
	return 0.0

func _sync_mode_runtime_profile() -> void:
	update_runtime_profile({
		"mode_id": _mode_id_runtime,
		"line_events": _line_event_count,
		"closure_events": _closure_event_count,
		"mode_trigger_count": _mode_trigger_count,
		"bond_o_scale": _get_payload_scale(f_bond_o_payload),
		"bond_m_scale": _get_payload_scale(f_bond_m_payload),
		"bond_t_scale": _get_payload_scale(f_bond_t_payload),
	})
