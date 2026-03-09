extends Node

signal reward_selected(reward_data: Dictionary)

const REWARD_WAVES: Array[int] = [5, 10, 15]

const GOLD_MIN: int = 200
const GOLD_MAX: int = 300

const BASE_DROP_CHANCE: float = 0.18
const ELITE_DROP_CHANCE: float = 0.55
const BASE_DROP_POINTS: int = 1
const ELITE_DROP_POINTS: int = 2
const MAX_DROP_POINTS_PER_WAVE: int = 6

const FIRST_RECRUIT_COST: int = 260
const SECOND_RECRUIT_COST: int = 420
const SOLO_SUPPLY_GOLD_BASE: int = 140
const SOLO_SUPPLY_GOLD_WAVE_SCALE: int = 15
const REWARD_OPTION_COUNT: int = 3

const TYPE_RECRUIT: String = "recruit"
const TYPE_ATTRIBUTE: String = "attribute"
const TYPE_BOND: String = "bond"
const TYPE_OTHER: String = "other"

var _current_options: Array[Dictionary] = []

var _pending_drop_points: int = 0
var _pending_drop_count: int = 0
var _pending_best_tier: int = 1
var _pending_wave_number: int = 1

var _locked_recruit_ids: Array[String] = []
var _using_locked_candidates: bool = false

func check_wave_reward(wave_number: int) -> bool:
	_pending_wave_number = wave_number
	if Global.should_offer_recruit_for_wave(wave_number):
		return true
	if _pending_drop_points > 0:
		return true
	return wave_number in REWARD_WAVES

func record_enemy_drop(enemy_id: String, is_elite: bool = false, wave_number: int = 1) -> void:
	_pending_wave_number = wave_number

	var drop_chance: float = ELITE_DROP_CHANCE if is_elite else BASE_DROP_CHANCE
	if randf() > drop_chance:
		return

	var points: int = ELITE_DROP_POINTS if is_elite else BASE_DROP_POINTS
	_pending_drop_points = min(_pending_drop_points + points, MAX_DROP_POINTS_PER_WAVE)
	_pending_drop_count += 1

	var enemy_cfg: Dictionary = ConfigManager.get_enemy_config(enemy_id)
	var enemy_tier: int = int(enemy_cfg.get("tier", 1))
	if is_elite:
		enemy_tier = max(enemy_tier, 3)
	_pending_best_tier = clamp(max(_pending_best_tier, enemy_tier), 1, 4)

func generate_reward_options() -> Array[Dictionary]:
	_current_options.clear()

	var reward_tier: int = _calc_reward_tier()
	var used_type_map: Dictionary = {}

	# 招募波次统一只占用一个奖励格子：
	# - 未满员：直接招募
	# - 满员：先给“招募并替换”卡，点击后再弹替换目标选择面板
	if Global.should_offer_recruit_for_wave(_pending_wave_number):
		var recruit_option: Dictionary = _generate_single_recruit_option()
		if not recruit_option.is_empty():
			_current_options.append(recruit_option)
		if not _current_options.is_empty():
			used_type_map[TYPE_RECRUIT] = true

	while _current_options.size() < REWARD_OPTION_COUNT:
		var option: Dictionary = _generate_weighted_option(reward_tier, used_type_map)
		if option.is_empty():
			option = _generate_gold_option(reward_tier)
		var type_key: String = _get_option_type_key(option)
		if not type_key.is_empty():
			used_type_map[type_key] = true
		_current_options.append(option)

	return _current_options

func _generate_weighted_option(reward_tier: int, used_type_map: Dictionary) -> Dictionary:
	var entries: Array[Dictionary] = []
	_append_weight_entry(entries, TYPE_RECRUIT, _get_type_weight(TYPE_RECRUIT), used_type_map, _can_offer_recruit())
	_append_weight_entry(entries, TYPE_ATTRIBUTE, _get_type_weight(TYPE_ATTRIBUTE), used_type_map, true)
	_append_weight_entry(entries, TYPE_BOND, _get_type_weight(TYPE_BOND), used_type_map, true)
	_append_weight_entry(entries, TYPE_OTHER, _get_type_weight(TYPE_OTHER), used_type_map, true)

	# 若都被“去重类型”过滤掉，允许重复类型，避免凑不齐三选一。
	if entries.is_empty():
		_append_weight_entry(entries, TYPE_RECRUIT, _get_type_weight(TYPE_RECRUIT), {}, _can_offer_recruit())
		_append_weight_entry(entries, TYPE_ATTRIBUTE, _get_type_weight(TYPE_ATTRIBUTE), {}, true)
		_append_weight_entry(entries, TYPE_BOND, _get_type_weight(TYPE_BOND), {}, true)
		_append_weight_entry(entries, TYPE_OTHER, _get_type_weight(TYPE_OTHER), {}, true)

	for _i in range(8):
		if entries.is_empty():
			break
		var picked_type: String = _pick_weighted_key(entries)
		var option: Dictionary = {}
		match picked_type:
			TYPE_RECRUIT:
				option = _generate_single_recruit_option()
			TYPE_ATTRIBUTE:
				option = _generate_attribute_option(reward_tier)
			TYPE_BOND:
				option = _generate_artifact_option(reward_tier)
			TYPE_OTHER:
				option = _generate_other_option(reward_tier)
			_:
				option = {}
		if not option.is_empty():
			return option
		_remove_weight_entry(entries, picked_type)

	return {}

func _append_weight_entry(
	entries: Array[Dictionary],
	type_key: String,
	weight: float,
	used_type_map: Dictionary,
	enabled: bool
) -> void:
	if not enabled or weight <= 0.0:
		return
	if used_type_map.has(type_key):
		return
	entries.append({
		"key": type_key,
		"weight": weight
	})

func _remove_weight_entry(entries: Array[Dictionary], type_key: String) -> void:
	for i in range(entries.size() - 1, -1, -1):
		var key: String = str(entries[i].get("key", ""))
		if key == type_key:
			entries.remove_at(i)

func _pick_weighted_key(entries: Array[Dictionary]) -> String:
	var total_weight: float = 0.0
	for entry in entries:
		total_weight += float(entry.get("weight", 0.0))
	if total_weight <= 0.0:
		return ""

	var roll: float = randf() * total_weight
	var acc: float = 0.0
	for entry in entries:
		acc += float(entry.get("weight", 0.0))
		if roll <= acc:
			return str(entry.get("key", ""))
	return str(entries.back().get("key", ""))

func _get_type_weight(type_key: String) -> float:
	match type_key:
		TYPE_RECRUIT:
			return float(ConfigManager.get_game_setting("reward_weight_recruit", 55))
		TYPE_ATTRIBUTE:
			return float(ConfigManager.get_game_setting("reward_weight_attribute", 20))
		TYPE_BOND:
			return float(ConfigManager.get_game_setting("reward_weight_bond", 15))
		TYPE_OTHER:
			return float(ConfigManager.get_game_setting("reward_weight_other", 10))
		_:
			return 0.0

func _get_option_type_key(option: Dictionary) -> String:
	var reward_type: String = str(option.get("type", ""))
	match reward_type:
		"recruit", "recruit_replace":
			return TYPE_RECRUIT
		"attribute_boost":
			return TYPE_ATTRIBUTE
		"artifact":
			return TYPE_BOND
		"equipment", "gold":
			return TYPE_OTHER
		_:
			return reward_type

func _can_offer_recruit() -> bool:
	var candidates: Array[Dictionary] = _resolve_recruit_candidates(1)
	return not candidates.is_empty()

func _generate_single_recruit_option() -> Dictionary:
	var candidates: Array[Dictionary] = _resolve_recruit_candidates(8)
	if candidates.is_empty():
		return {}
	var candidate: Dictionary = _pick_recruit_candidate(candidates)
	return _build_recruit_option_from_candidate(candidate, "")

func _build_recruit_option_from_candidate(candidate: Dictionary, out_player_id: String) -> Dictionary:
	if candidate.is_empty():
		return {}

	var player_id: String = str(candidate.get("player_id", ""))
	if player_id.is_empty():
		return {}

	var display_name: String = str(candidate.get("display_name", player_id))
	var base_desc: String = str(candidate.get("description", "Join squad and unlock switch slot"))
	var lock_prefix: String = "[Locked] " if _using_locked_candidates else ""

	var is_full_squad: bool = Global.selected_player_ids.size() >= Global.MAX_ACTIVE_SQUAD_SIZE
	if is_full_squad:
		var recruit_cost: int = _get_recruit_cost(true)
		var replace_targets: Array[String] = _get_replace_targets()
		if replace_targets.is_empty():
			return {}

		var selected_out_player_id: String = out_player_id
		var affordable: bool = RunStateService.get_run_gold() >= recruit_cost
		var icon_path: String = _resolve_icon_path(
			str(candidate.get("icon_path", "")),
			"reward_icon_recruit",
			"res://assets/sprites/Icons/origins/origin1.png"
		)
		var replace_candidate_entries: Array[Dictionary] = _build_replace_candidate_entries(replace_targets)
		var description: String = ""
		if selected_out_player_id.is_empty():
			description = "%s (Cost %d gold, choose replace target x%d)%s" % [
				base_desc,
				recruit_cost,
				replace_candidate_entries.size(),
				"" if affordable else " [Gold not enough]"
			]
		else:
			var out_name: String = _get_player_display_name(selected_out_player_id)
			description = "%s (Cost %d gold, replace %s)%s" % [
				base_desc,
				recruit_cost,
				out_name,
				"" if affordable else " [Gold not enough]"
			]

		return {
			"type": "recruit_replace",
			"player_id": player_id,
			"replace_out_player_id": selected_out_player_id if not selected_out_player_id.is_empty() else "",
			"replace_candidates": replace_candidate_entries,
			"cost": recruit_cost,
			"affordable": affordable,
			"requires_replace_choose": selected_out_player_id.is_empty(),
			"locked_source": _using_locked_candidates,
			"display_name": "%sRecruit %s" % [lock_prefix, display_name],
			"description": description,
			"icon_path": icon_path
		}

	var recruit_cost: int = _get_recruit_cost(false)
	var affordable: bool = RunStateService.get_run_gold() >= recruit_cost
	var icon_path: String = _resolve_icon_path(
		str(candidate.get("icon_path", "")),
		"reward_icon_recruit",
		"res://assets/sprites/Icons/origins/origin1.png"
	)
	return {
		"type": "recruit",
		"player_id": player_id,
		"cost": recruit_cost,
		"affordable": affordable,
		"locked_source": _using_locked_candidates,
		"display_name": "%sRecruit %s" % [lock_prefix, display_name],
		"description": "%s (Cost %d gold)%s" % [base_desc, recruit_cost, "" if affordable else " [Gold not enough]"],
		"icon_path": icon_path
	}
func _build_replace_candidate_entries(targets: Array[String]) -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	for pid in targets:
		var player_id: String = str(pid)
		if player_id.is_empty():
			continue
		entries.append({
			"player_id": player_id,
			"display_name": _get_player_display_name(player_id)
		})
	return entries

func _pick_recruit_candidate(candidates: Array[Dictionary]) -> Dictionary:
	if candidates.is_empty():
		return {}

	var weighted: Array[Dictionary] = []
	for candidate in candidates:
		if not (candidate is Dictionary):
			continue
		var data: Dictionary = candidate
		var player_id: String = str(data.get("player_id", ""))
		if player_id.is_empty():
			continue
		var cfg: Dictionary = ConfigManager.get_player_config(player_id)
		var weight: float = float(cfg.get("recruit_weight", 100))
		if weight <= 0.0:
			continue
		weighted.append({
			"key": player_id,
			"weight": weight
		})

	if weighted.is_empty():
		return candidates[0]

	var picked_id: String = _pick_weighted_key(weighted)
	for candidate in candidates:
		if not (candidate is Dictionary):
			continue
		var data: Dictionary = candidate
		if str(data.get("player_id", "")) == picked_id:
			return data

	return candidates[0]

func _generate_attribute_option(reward_tier: int) -> Dictionary:
	var attr_entries: Array[Dictionary] = [
		{"key": "max_health", "weight": float(ConfigManager.get_game_setting("reward_attr_weight_max_health", 35))},
		{"key": "max_energy", "weight": float(ConfigManager.get_game_setting("reward_attr_weight_max_energy", 25))},
		{"key": "energy_regen", "weight": float(ConfigManager.get_game_setting("reward_attr_weight_energy_regen", 20))},
		{"key": "base_speed", "weight": float(ConfigManager.get_game_setting("reward_attr_weight_base_speed", 20))}
	]

	var attr_key: String = _pick_weighted_key(attr_entries)
	match attr_key:
		"max_health":
			var hp_bonus: float = 18.0 + 6.0 * float(reward_tier)
			return {
				"type": "attribute_boost",
				"attr_key": "max_health",
				"value": hp_bonus,
				"display_name": "体魄强化 +%d" % int(round(hp_bonus)),
				"description": "当前角色最大生命与当前生命提升",
				"icon_path": _resolve_icon_path("", "reward_icon_attr_max_health", "res://assets/sprites/Icons/origins/origin1.png")
			}
		"max_energy":
			var energy_bonus: float = 24.0 + 8.0 * float(reward_tier)
			return {
				"type": "attribute_boost",
				"attr_key": "max_energy",
				"value": energy_bonus,
				"display_name": "能量扩容 +%d" % int(round(energy_bonus)),
				"description": "当前角色最大能量与当前能量提升",
				"icon_path": _resolve_icon_path("", "reward_icon_attr_max_energy", "res://assets/sprites/Icons/origins/origin2.png")
			}
		"energy_regen":
			var regen_bonus: float = 0.06 + 0.02 * float(reward_tier)
			return {
				"type": "attribute_boost",
				"attr_key": "energy_regen",
				"value": regen_bonus,
				"display_name": "能量回复 +%.2f/s" % regen_bonus,
				"description": "当前角色能量回复速度提升",
				"icon_path": _resolve_icon_path("", "reward_icon_attr_energy_regen", "res://assets/sprites/Icons/masterys/mastery1.png")
			}
		"base_speed":
			var speed_bonus: float = 8.0 + 2.0 * float(reward_tier)
			return {
				"type": "attribute_boost",
				"attr_key": "base_speed",
				"value": speed_bonus,
				"display_name": "战术机动 +%d" % int(round(speed_bonus)),
				"description": "当前角色移动速度提升",
				"icon_path": _resolve_icon_path("", "reward_icon_attr_base_speed", "res://assets/sprites/Icons/origins/origin2.png")
			}
		_:
			return _generate_gold_option(reward_tier)

func _generate_other_option(reward_tier: int) -> Dictionary:
	var entries: Array[Dictionary] = [
		{"key": "equipment", "weight": float(ConfigManager.get_game_setting("reward_weight_other_equipment", 70))},
		{"key": "gold", "weight": float(ConfigManager.get_game_setting("reward_weight_other_gold", 30))}
	]
	var picked: String = _pick_weighted_key(entries)
	if picked == "equipment":
		return _generate_equipment_option(reward_tier)
	return _generate_gold_option(reward_tier)

func _generate_recruit_options() -> Array[Dictionary]:
	var option: Dictionary = _generate_single_recruit_option()
	if option.is_empty():
		return []
	return [option]

func _resolve_recruit_candidates(max_count: int) -> Array[Dictionary]:
	_using_locked_candidates = false
	var candidates: Array[Dictionary] = []

	if not _locked_recruit_ids.is_empty():
		for player_id in _locked_recruit_ids:
			if Global.reserve_player_ids.has(player_id):
				candidates.append(_build_recruit_candidate(player_id))
				if candidates.size() >= max_count:
					break
		if not candidates.is_empty():
			_using_locked_candidates = true
			return candidates
		_locked_recruit_ids.clear()

	return Global.get_recruit_candidates(max_count)

func _build_recruit_candidate(player_id: String) -> Dictionary:
	var config: Dictionary = ConfigManager.get_player_config(player_id)
	var visual: Dictionary = ConfigManager.get_player_visual(player_id)
	var display_name: String = str(config.get("display_name", player_id))
	var ties: String = str(config.get("ties", ""))
	var desc: String = "Join squad and unlock switch slot"
	if not ties.is_empty():
		desc = "%s (%s)" % [desc, ties]
	var raw_icon_path: String = str(visual.get("sprite_path", ""))
	return {
		"player_id": player_id,
		"display_name": display_name,
		"description": desc,
		"icon_path": _resolve_icon_path(raw_icon_path, "reward_icon_recruit", "res://assets/sprites/Icons/origins/origin1.png")
	}

func _get_replace_targets() -> Array[String]:
	var targets: Array[String] = []
	var leader_player_id: String = ""
	if Global.has_method("get_leader_player_id"):
		leader_player_id = str(Global.get_leader_player_id())

	for player_id in Global.selected_player_ids:
		var normalized_id: String = str(player_id)
		if normalized_id.is_empty():
			continue
		if normalized_id == leader_player_id:
			continue
		targets.append(normalized_id)

	return targets

func set_option_context(option_index: int, context: Dictionary) -> bool:
	if option_index < 0 or option_index >= _current_options.size():
		return false
	if context.is_empty():
		return true

	var option: Dictionary = _current_options[option_index]
	if option.is_empty():
		return false

	for key_raw in context.keys():
		var key: String = str(key_raw)
		option[key] = context[key_raw]

	_current_options[option_index] = option
	return true
func _get_player_display_name(player_id: String) -> String:
	if player_id.is_empty():
		return "Unknown"
	var cfg: Dictionary = ConfigManager.get_player_config(player_id)
	return str(cfg.get("display_name", player_id))

func _resolve_icon_path(source_path: String, config_key: String, fallback_path: String) -> String:
	var candidates: Array[String] = []
	if not source_path.is_empty():
		candidates.append(source_path)
	var cfg_path: String = str(ConfigManager.get_game_setting(config_key, ""))
	if not cfg_path.is_empty():
		candidates.append(cfg_path)
	candidates.append(fallback_path)

	for path in candidates:
		if path.is_empty():
			continue
		if FileAccess.file_exists(path):
			return path
	return ""

func _make_lock_option(candidates: Array[Dictionary]) -> Dictionary:
	var candidate_ids: Array[String] = []
	for candidate in candidates:
		var player_id: String = str(candidate.get("player_id", ""))
		if not player_id.is_empty():
			candidate_ids.append(player_id)

	return {
		"type": "recruit_lock",
		"candidate_ids": candidate_ids,
		"display_name": "Lock Recruit Candidates",
		"description": "Keep these candidates for the next recruit wave",
		"icon_path": ""
	}

func _make_solo_bonus_option() -> Dictionary:
	var solo_supply_gold: int = SOLO_SUPPLY_GOLD_BASE + max(0, _pending_wave_number - 1) * SOLO_SUPPLY_GOLD_WAVE_SCALE
	return {
		"type": "solo_bonus",
		"amount": solo_supply_gold,
		"display_name": "Solo Supply",
		"description": "Skip recruit, get %d gold and leader stat boost" % solo_supply_gold,
		"icon_path": ""
	}

func _get_recruit_cost(is_replace: bool = false) -> int:
	if is_replace:
		return int(ConfigManager.get_game_setting("recruit_cost_replace_member", SECOND_RECRUIT_COST))
	return int(ConfigManager.get_game_setting("recruit_cost_add_member", FIRST_RECRUIT_COST))

func _calc_reward_tier() -> int:
	var tier_from_points: int = 1
	if _pending_drop_points >= 2:
		tier_from_points = 2
	if _pending_drop_points >= 4:
		tier_from_points = 3
	if _pending_drop_points >= 6:
		tier_from_points = 4
	return clamp(max(_pending_best_tier, tier_from_points), 1, 4)

func _generate_artifact_option(reward_tier: int) -> Dictionary:
	var all_configs: Dictionary = ConfigManager.get_all_emblem_configs()
	var candidates: Array[String] = []
	var allow_relic: bool = reward_tier >= 3

	for emblem_id in all_configs:
		var config: Dictionary = all_configs[emblem_id]
		if emblem_id == "emblem_wildcard":
			continue
		var artifact_type: String = str(config.get("artifact_type", ""))
		if artifact_type == "relic":
			if EmblemManager.has_unique_relic(emblem_id):
				continue
			if not allow_relic:
				continue
		candidates.append(emblem_id)

	if candidates.is_empty():
		return _generate_gold_option(reward_tier)

	var emblem_entries: Array[Dictionary] = []
	for emblem_id in candidates:
		var cfg: Dictionary = all_configs[emblem_id]
		emblem_entries.append({
			"key": emblem_id,
			"weight": float(cfg.get("reward_weight", 100))
		})
	var chosen_id: String = _pick_weighted_key(emblem_entries)
	if chosen_id.is_empty():
		chosen_id = candidates[0]
	var chosen_cfg: Dictionary = all_configs[chosen_id]
	return {
		"type": "artifact",
		"emblem_id": chosen_id,
		"display_name": str(chosen_cfg.get("display_name", chosen_id)),
		"description": "Drop count %d, reward tier T%d" % [_pending_drop_count, reward_tier],
		"icon_path": _resolve_icon_path(
			str(chosen_cfg.get("icon_path", "")),
			"reward_icon_bond",
			"res://assets/sprites/Icons/masterys/mastery5.png"
		)
	}

func _generate_equipment_option(reward_tier: int) -> Dictionary:
	var picked: Dictionary = _pick_equipment_by_tier(reward_tier)
	if picked.is_empty():
		return _generate_gold_option(reward_tier)

	return {
		"type": "equipment",
		"item_id": picked.get("item_id", ""),
		"display_name": str(picked.get("name", picked.get("item_id", "Equipment"))),
		"description": "Drop conversion: equipment tier T%d" % int(picked.get("tier", reward_tier)),
		"icon_path": _resolve_icon_path(
			str(picked.get("icon_path", "")),
			"reward_icon_equipment",
			"res://assets/sprites/Icons/origins/origin3.png"
		)
	}

func _pick_equipment_by_tier(target_tier: int) -> Dictionary:
	var clamped_tier: int = int(clamp(target_tier, 1, 4))
	for tier in range(clamped_tier, 0, -1):
		var candidates: Array[String] = []
		var candidate_entries: Array[Dictionary] = []
		for item_id in ConfigManager.item_configs_new:
			var cfg: Dictionary = ConfigManager.item_configs_new[item_id]
			if int(cfg.get("tier", 0)) == tier:
				candidates.append(item_id)
				candidate_entries.append({
					"key": item_id,
					"weight": float(cfg.get("reward_weight", 100))
				})

		if not candidates.is_empty():
			var chosen_id: String = _pick_weighted_key(candidate_entries)
			if chosen_id.is_empty():
				chosen_id = candidates[0]
			var chosen_cfg: Dictionary = ConfigManager.item_configs_new[chosen_id]
			var result: Dictionary = chosen_cfg.duplicate(true)
			result["item_id"] = chosen_id
			return result

	return {}

func _generate_gold_option(reward_tier: int) -> Dictionary:
	var bonus_from_drop: int = _pending_drop_points * 35
	var bonus_from_tier: int = (reward_tier - 1) * 30
	var min_amount: int = GOLD_MIN + bonus_from_drop + bonus_from_tier
	var max_amount: int = GOLD_MAX + bonus_from_drop + bonus_from_tier
	var amount: int = randi_range(min_amount, max_amount)

	return {
		"type": "gold",
		"amount": amount,
		"display_name": "%d Gold" % amount,
		"description": "Drop count %d, points %d" % [_pending_drop_count, _pending_drop_points],
		"icon_path": _resolve_icon_path("", "reward_icon_gold", "res://assets/sprites/Icons/masterys/mastery6.png")
	}

func select_reward(option_index: int) -> bool:
	if option_index < 0 or option_index >= _current_options.size():
		printerr("[WaveRewardSystem] Invalid option index: %d" % option_index)
		return false

	var reward: Dictionary = _current_options[option_index]
	var reward_type: String = str(reward.get("type", ""))

	match reward_type:
		"recruit":
			if not _apply_recruit_reward(reward):
				return false
			_cleanup_locked_recruit_ids()
		"recruit_replace":
			if not _apply_recruit_replace_reward(reward):
				return false
			_cleanup_locked_recruit_ids()
		"attribute_boost":
			if not _apply_attribute_boost(reward):
				return false
		"recruit_lock":
			if not _apply_recruit_lock(reward):
				return false
		"solo_bonus":
			_locked_recruit_ids.clear()
			_apply_solo_supply_bonus(reward)
		"artifact":
			var emblem_id: String = str(reward.get("emblem_id", ""))
			if not emblem_id.is_empty():
				EmblemManager.add_emblem(emblem_id)
		"equipment":
			var item_id: String = str(reward.get("item_id", ""))
			if not item_id.is_empty():
				var item_type: int = WarehouseManager.get_type_from_item_id(item_id)
				if item_type > 0:
					WarehouseManager.add_item(item_type)
				else:
					printerr("[WaveRewardSystem] Unknown equipment type: %s" % item_id)
		"gold":
			var amount: int = int(reward.get("amount", 0))
			if amount > 0:
				RunStateService.add_run_gold(amount)
		_:
			printerr("[WaveRewardSystem] Unknown reward type: %s" % reward_type)
			return false

	reward_selected.emit(reward)
	_current_options.clear()
	_consume_wave_drops()
	return true

func _apply_recruit_reward(reward: Dictionary) -> bool:
	var player_id: String = str(reward.get("player_id", ""))
	if player_id.is_empty():
		return false

	if reward.has("affordable") and not bool(reward.get("affordable", true)):
		push_warning("[WaveRewardSystem] 金币不足，无法招募 %s" % player_id)
		return false

	var cost: int = int(reward.get("cost", 0))
	if cost > 0 and not RunStateService.spend_run_gold(cost):
		push_warning("[WaveRewardSystem] 金币不足，无法招募 %s (需要 %d)" % [player_id, cost])
		return false

	var success: bool = Global.recruit_player(player_id)
	if not success and cost > 0:
		RunStateService.add_run_gold(cost)
	return success

func _apply_recruit_replace_reward(reward: Dictionary) -> bool:
	var player_id: String = str(reward.get("player_id", ""))
	var out_player_id: String = str(reward.get("replace_out_player_id", ""))
	if player_id.is_empty():
		return false
	if out_player_id.is_empty():
		push_warning("[WaveRewardSystem] recruit replace requires selected out player")
		return false

	if reward.has("affordable") and not bool(reward.get("affordable", true)):
		push_warning("[WaveRewardSystem] 金币不足，无法替换招募 %s" % player_id)
		return false

	var cost: int = int(reward.get("cost", 0))
	if cost > 0 and not RunStateService.spend_run_gold(cost):
		push_warning("[WaveRewardSystem] 金币不足，无法替换招募 %s (需要 %d)" % [player_id, cost])
		return false

	var success: bool = Global.replace_player(out_player_id, player_id)
	if not success and cost > 0:
		RunStateService.add_run_gold(cost)
	return success
func _apply_attribute_boost(reward: Dictionary) -> bool:
	var attr_key: String = str(reward.get("attr_key", ""))
	var value: float = float(reward.get("value", 0.0))
	if attr_key.is_empty() or value == 0.0:
		return false

	var target_player_id: String = Global.get_current_player_id()
	if target_player_id.is_empty() and not Global.selected_player_ids.is_empty():
		target_player_id = str(Global.selected_player_ids[0])
	if target_player_id.is_empty():
		return false

	var state: Dictionary = Global.get_player_state(target_player_id)
	if state.is_empty():
		return false

	match attr_key:
		"max_health":
			var new_max_health: float = float(state.get("max_health", 100.0)) + value
			var new_health: float = min(float(state.get("health", new_max_health)) + value, new_max_health)
			state["max_health"] = new_max_health
			state["health"] = new_health
		"max_energy":
			var new_max_energy: float = float(state.get("max_energy", 100.0)) + value
			var new_energy: float = min(float(state.get("energy", new_max_energy)) + value, new_max_energy)
			state["max_energy"] = new_max_energy
			state["energy"] = new_energy
		"energy_regen":
			state["energy_regen"] = float(state.get("energy_regen", 0.5)) + value
		"base_speed":
			var new_base_speed: float = float(state.get("base_speed", state.get("speed", 200.0))) + value
			state["base_speed"] = new_base_speed
			state["speed"] = new_base_speed
		_:
			return false

	Global.player_states[target_player_id] = state

	if is_instance_valid(Global.player) and str(Global.player.player_id) == target_player_id:
		if attr_key == "max_health" and is_instance_valid(Global.player.health_component):
			Global.player.health_component.max_health = float(state.get("max_health", Global.player.health_component.max_health))
			Global.player.health_component.current_health = float(state.get("health", Global.player.health_component.current_health))
		elif attr_key == "max_energy":
			Global.player.max_energy = float(state.get("max_energy", Global.player.max_energy))
			Global.player.energy = float(state.get("energy", Global.player.energy))
		elif attr_key == "energy_regen" and "energy_regen" in Global.player:
			Global.player.energy_regen = float(state.get("energy_regen", Global.player.energy_regen))
		elif attr_key == "base_speed":
			if "base_speed" in Global.player:
				Global.player.base_speed = float(state.get("base_speed", Global.player.base_speed))
			if "speed" in Global.player:
				Global.player.speed = float(state.get("speed", Global.player.speed))
		if Global.player.has_method("update_ui_signals"):
			Global.player.update_ui_signals()

	var index: int = Global.selected_player_ids.find(target_player_id)
	if index >= 0:
		Global.notify_squad_state_changed(index)
	return true

func _apply_recruit_lock(reward: Dictionary) -> bool:
	var candidate_ids_raw: Variant = reward.get("candidate_ids", [])
	if not (candidate_ids_raw is Array):
		return false

	_locked_recruit_ids.clear()
	for value in candidate_ids_raw:
		var player_id: String = str(value)
		if not player_id.is_empty() and Global.reserve_player_ids.has(player_id):
			_locked_recruit_ids.append(player_id)

	if _locked_recruit_ids.is_empty():
		printerr("[WaveRewardSystem] Lock recruit failed: no valid candidates")
		return false

	print("[WaveRewardSystem] Locked recruit candidates: %s" % str(_locked_recruit_ids))
	return true

func _cleanup_locked_recruit_ids() -> void:
	if _locked_recruit_ids.is_empty():
		return

	var filtered: Array[String] = []
	for player_id in _locked_recruit_ids:
		if Global.reserve_player_ids.has(player_id):
			filtered.append(player_id)
	_locked_recruit_ids = filtered

func _apply_solo_supply_bonus(reward: Dictionary) -> void:
	var amount: int = int(reward.get("amount", 0))
	if amount > 0:
		RunStateService.add_run_gold(amount)

	var leader_id: String = Global.get_current_player_id()
	if leader_id.is_empty():
		return

	var state: Dictionary = Global.get_player_state(leader_id)
	if state.is_empty():
		return

	var hp_bonus: float = 24.0
	var speed_bonus: float = 8.0
	var max_health: float = float(state.get("max_health", 100.0)) + hp_bonus
	var health: float = min(float(state.get("health", 100.0)) + hp_bonus, max_health)
	var base_speed: float = float(state.get("base_speed", state.get("speed", 200.0))) + speed_bonus

	state["max_health"] = max_health
	state["health"] = health
	state["base_speed"] = base_speed
	state["speed"] = base_speed
	Global.player_states[leader_id] = state

	if is_instance_valid(Global.player) and str(Global.player.player_id) == leader_id:
		if is_instance_valid(Global.player.health_component):
			Global.player.health_component.max_health = max_health
			Global.player.health_component.current_health = health
		if "base_speed" in Global.player:
			Global.player.base_speed = base_speed
		if "speed" in Global.player:
			Global.player.speed = base_speed

	var leader_index: int = Global.selected_player_ids.find(leader_id)
	if leader_index >= 0:
		Global.notify_squad_state_changed(leader_index)

func _consume_wave_drops() -> void:
	_pending_drop_points = 0
	_pending_drop_count = 0
	_pending_best_tier = 1

func get_pending_drop_summary() -> Dictionary:
	return {
		"wave_number": _pending_wave_number,
		"drop_points": _pending_drop_points,
		"drop_count": _pending_drop_count,
		"best_tier": _pending_best_tier
	}
