extends Node

signal shop_items_generated(items: Array)
signal shop_item_updated(index: int, item: Dictionary)
signal item_purchased(item_id: String, index: int)
signal shop_rerolled()
signal purchase_failed(reason: String)

const REROLL_BASE_COST: int = 20
const REROLL_COST_INCREMENT: int = 10
const DEFAULT_SHOP_SLOT_COUNT: int = 4
const EMBLEM_SPAWN_CHANCE: float = 0.25
const RECRUIT_CHANCE_UNDERFILLED: float = 0.70
const RECRUIT_CHANCE_FULL_SQUAD: float = 0.10
const FIRST_RECRUIT_COST: int = 260
const SECOND_RECRUIT_COST: int = 420
const FULL_SQUAD_REPLACE_COST: int = 520

var shop_item_configs: Dictionary = {}
var current_shop_items: Array = []
var purchased_indices: Array[int] = []
var current_shop_wave_number: int = -1
var current_shop_reroll_count: int = 0

func _ready() -> void:
	_load_shop_configs()
	print("[ShopManager] initialized with %d legacy shop items" % shop_item_configs.size())

func _load_shop_configs() -> void:
	shop_item_configs = ConfigRepository.load_shop_item_configs()
	var line_count: int = 0
	for item_id_variant in shop_item_configs.keys():
		var item_id: String = str(item_id_variant)
		var cfg: Dictionary = shop_item_configs[item_id]
		line_count += cfg.get("effects", []).size()
	print("[ShopManager] loaded %d legacy shop effects" % line_count)

func generate_shop_items(count: int = DEFAULT_SHOP_SLOT_COUNT, next_wave_number: int = -1) -> void:
	current_shop_items.clear()
	purchased_indices.clear()
	if next_wave_number >= 0:
		current_shop_wave_number = next_wave_number
		current_shop_reroll_count = 0

	var used_ids: Array[String] = []
	var used_recruit_player_ids: Array[String] = []
	var guaranteed_recruit_slots: int = _get_guaranteed_recruit_slots(next_wave_number, count)

	for index in range(max(count, 0)):
		var item: Dictionary = {}
		var force_recruit: bool = index < guaranteed_recruit_slots

		if force_recruit or _should_spawn_recruit_card(used_recruit_player_ids):
			item = _generate_recruit_item(used_ids, used_recruit_player_ids)

		if item.is_empty():
			if randf() < EMBLEM_SPAWN_CHANCE:
				item = _generate_emblem_item(used_ids)
			else:
				item = _generate_equipment_item(used_ids)

		if item.is_empty() and not force_recruit and _can_generate_recruit_card(used_recruit_player_ids):
			item = _generate_recruit_item(used_ids, used_recruit_player_ids)

		if item.is_empty():
			item = _generate_consumable_item(used_ids)

		if item.is_empty():
			continue

		var item_id: String = str(item.get("item_id", ""))
		if item_id.is_empty():
			continue

		var recruit_player_id: String = str(item.get("player_id", ""))
		if not recruit_player_id.is_empty() and not used_recruit_player_ids.has(recruit_player_id):
			used_recruit_player_ids.append(recruit_player_id)

		used_ids.append(item_id)
		current_shop_items.append(item)

	print("[ShopManager] generated shop items: %s" % str(_get_item_ids()))
	shop_items_generated.emit(current_shop_items)

func _get_item_ids() -> Array:
	var ids: Array = []
	for item_variant in current_shop_items:
		var item: Dictionary = item_variant
		ids.append(str(item.get("item_id", "unknown")))
	return ids

func _generate_emblem_item(used_ids: Array[String]) -> Dictionary:
	var all_configs: Dictionary = ConfigManager.get_all_emblem_configs()
	if all_configs.is_empty():
		return _generate_equipment_item(used_ids)

	var candidates: Array[Dictionary] = []
	for emblem_id_variant in all_configs.keys():
		var emblem_id: String = str(emblem_id_variant)
		if emblem_id == "emblem_wildcard":
			continue
		if emblem_id in used_ids:
			continue

		var config: Dictionary = all_configs[emblem_id]
		var is_unique: bool = str(config.get("is_unique", "0")) == "1"
		if is_unique and EmblemManager.has_unique_relic(emblem_id):
			continue

		candidates.append(config)

	if candidates.is_empty():
		return _generate_equipment_item(used_ids)

	var weights: Dictionary = _get_smart_emblem_weights()
	var weighted_candidates: Array[Dictionary] = []
	var total_weight: float = 0.0

	for config in candidates:
		var bond_tag: String = str(config.get("bond_tag", ""))
		var weight: float = float(weights.get(bond_tag, 1.0))
		if str(config.get("artifact_type", "")) == "relic":
			weight = 1.0
		weighted_candidates.append({"config": config, "weight": weight})
		total_weight += weight

	if total_weight <= 0.0:
		return _generate_equipment_item(used_ids)

	var roll: float = randf() * total_weight
	var cumulative: float = 0.0
	var selected_config: Dictionary = weighted_candidates[0].get("config", {})

	for entry_variant in weighted_candidates:
		var entry: Dictionary = entry_variant
		cumulative += float(entry.get("weight", 0.0))
		if roll <= cumulative:
			selected_config = entry.get("config", {})
			break

	var selected_id: String = str(selected_config.get("emblem_id", ""))
	return {
		"item_id": selected_id,
		"item_name": str(selected_config.get("display_name", "")),
		"item_type": "emblem",
		"item_tier": 0,
		"icon_path": str(selected_config.get("icon_path", "")),
		"price": int(selected_config.get("shop_price", 120)),
		"shop_weight": 10,
		"effects": [],
		"description": str(selected_config.get("description", "")),
		"artifact_type": str(selected_config.get("artifact_type", "emblem")),
		"bond_tag": str(selected_config.get("bond_tag", "")),
		"rarity": str(selected_config.get("rarity", "common"))
	}

func _generate_equipment_item(used_ids: Array[String]) -> Dictionary:
	var blocked_ids: Dictionary = _collect_blocked_equipment_ids(used_ids)
	var weighted_pool: Array[Dictionary] = []
	var total_weight: int = 0

	for item_id_variant in ConfigManager.item_configs_new.keys():
		var item_id: String = str(item_id_variant)
		var cfg_variant: Variant = ConfigManager.item_configs_new[item_id]
		if not (cfg_variant is Dictionary):
			continue
		var cfg: Dictionary = cfg_variant

		if str(cfg.get("type", "")) != "equipment":
			continue
		if blocked_ids.has(item_id):
			continue

		var tier: int = int(cfg.get("tier", 1))
		if tier <= 0:
			continue

		var weight: int = _resolve_equipment_weight(tier)
		if weight <= 0:
			continue

		var display_name: String = str(cfg.get("name", item_id))
		var description: String = str(cfg.get("description", ""))
		var effects: Array = []
		if not description.is_empty():
			effects.append({
				"description": description,
				"is_trade_off": false
			})

		var item: Dictionary = {
			"item_id": item_id,
			"item_name": display_name,
			"item_type": "equipment",
			"item_tier": tier,
			"icon_path": str(cfg.get("icon_path", "")),
			"price": _resolve_equipment_price(cfg, tier),
			"shop_weight": weight,
			"effects": effects,
			"description": description
		}

		weighted_pool.append({"item": item, "weight": weight})
		total_weight += weight

	if weighted_pool.is_empty() or total_weight <= 0:
		return {}

	var roll: int = randi() % total_weight
	var cumulative: int = 0
	for entry_variant in weighted_pool:
		var entry: Dictionary = entry_variant
		cumulative += int(entry.get("weight", 0))
		if roll < cumulative:
			return entry.get("item", {})

	return weighted_pool[weighted_pool.size() - 1].get("item", {})

func _collect_blocked_equipment_ids(used_ids: Array[String]) -> Dictionary:
	var blocked: Dictionary = {}

	for item_id in used_ids:
		blocked[item_id] = true

	var warehouse_items: Dictionary = WarehouseManager.get_all_items()
	for slot_variant in warehouse_items.keys():
		var slot: int = int(slot_variant)
		var item_type: int = int(warehouse_items.get(slot, 0))
		if item_type <= 0:
			continue
		var item_id: String = WarehouseManager.get_item_id_from_type(item_type)
		if not item_id.is_empty():
			blocked[item_id] = true

	for player_id_variant in EquipmentManager.equipped_items.keys():
		var player_id: String = str(player_id_variant)
		var raw_type: Variant = EquipmentManager.equipped_items.get(player_id, 0)
		var item_type: int = int(raw_type)
		if item_type <= 0:
			continue
		var item_id: String = WarehouseManager.get_item_id_from_type(item_type)
		if not item_id.is_empty():
			blocked[item_id] = true

	return blocked

func _resolve_equipment_price(cfg: Dictionary, tier: int) -> int:
	var configured_price: int = int(cfg.get("shop_price", 0))
	if configured_price > 0:
		return configured_price
	match tier:
		1:
			return 40
		2:
			return 70
		3:
			return 110
		_:
			return 120

func _resolve_equipment_weight(tier: int) -> int:
	match tier:
		1:
			return 14
		2:
			return 10
		3:
			return 6
		_:
			return 4

func _generate_consumable_item(used_ids: Array[String]) -> Dictionary:
	if shop_item_configs.is_empty():
		return {}

	var weighted_pool: Array[String] = []
	for item_id_variant in shop_item_configs.keys():
		var item_id: String = str(item_id_variant)
		if item_id in used_ids:
			continue
		var cfg: Dictionary = shop_item_configs[item_id]
		if str(cfg.get("item_type", "")) != "consumable":
			continue
		var weight: int = int(cfg.get("shop_weight", 0))
		for _i in range(max(weight, 0)):
			weighted_pool.append(item_id)

	if weighted_pool.is_empty():
		return {}

	var picked_index: int = randi() % weighted_pool.size()
	var picked_id: String = weighted_pool[picked_index]
	return shop_item_configs[picked_id].duplicate(true)

func _get_guaranteed_recruit_slots(next_wave_number: int, count: int) -> int:
	if next_wave_number != 2:
		return 0
	if Global.selected_player_ids.size() >= Global.MAX_ACTIVE_SQUAD_SIZE:
		return 0
	return min(2, count)

func _should_spawn_recruit_card(used_recruit_player_ids: Array[String]) -> bool:
	if not _can_generate_recruit_card(used_recruit_player_ids):
		return false

	var squad_size: int = Global.selected_player_ids.size()
	var recruit_chance: float = RECRUIT_CHANCE_UNDERFILLED
	if squad_size >= Global.MAX_ACTIVE_SQUAD_SIZE:
		recruit_chance = RECRUIT_CHANCE_FULL_SQUAD
	return randf() < recruit_chance

func _can_generate_recruit_card(used_recruit_player_ids: Array[String]) -> bool:
	return not _get_recruit_candidates_for_shop(used_recruit_player_ids).is_empty()

func _generate_recruit_item(used_ids: Array[String], used_recruit_player_ids: Array[String]) -> Dictionary:
	var candidates: Array[Dictionary] = _get_recruit_candidates_for_shop(used_recruit_player_ids)
	if candidates.is_empty():
		return {}

	var candidate: Dictionary = _pick_recruit_candidate(candidates)
	if candidate.is_empty():
		return {}

	var player_id: String = str(candidate.get("player_id", ""))
	if player_id.is_empty():
		return {}

	var item_id: String = "recruit_card_%s" % player_id
	if item_id in used_ids:
		return {}

	var squad_size: int = Global.selected_player_ids.size()
	var is_replace: bool = squad_size >= Global.MAX_ACTIVE_SQUAD_SIZE
	var replace_out_player_id: String = ""
	var replace_candidates: Array[Dictionary] = []
	if is_replace:
		replace_candidates = _build_replace_candidates()
		replace_out_player_id = _select_default_replace_target(replace_candidates)
		if replace_out_player_id.is_empty():
			return {}

	var display_name: String = str(candidate.get("display_name", player_id))
	var item_name: String = display_name
	var item_type: String = "recruit"
	var recruit_weight: float = float(candidate.get("recruit_weight", 0.0))
	var recruit_weight_share: float = float(candidate.get("recruit_weight_share", 0.0))
	var recruit_spawn_chance: float = _get_current_recruit_spawn_chance()

	if is_replace:
		item_type = "recruit_replace"

	var item: Dictionary = {
		"item_id": item_id,
		"item_name": item_name,
		"item_type": item_type,
		"player_id": player_id,
		"display_name": display_name,
		"replace_out_player_id": replace_out_player_id,
		"replace_candidates": replace_candidates,
		"icon_path": str(candidate.get("icon_path", "")),
		"price": _get_recruit_price(is_replace),
		"shop_weight": 1,
		"recruit_weight": recruit_weight,
		"recruit_weight_share": recruit_weight_share,
		"recruit_spawn_chance": recruit_spawn_chance,
		"origin_tag": str(candidate.get("origin_tag", "")),
		"mastery_tag": str(candidate.get("mastery_tag", "")),
		"tactic_tag": str(candidate.get("tactic_tag", "")),
	}
	item["effects"] = [
		{
			"description": _build_recruit_effect_desc(item),
			"is_trade_off": false
		}
	]
	item["description"] = str(item["effects"][0].get("description", ""))
	return item

func _build_recruit_effect_desc(item: Dictionary) -> String:
	var display_name: String = str(item.get("display_name", item.get("player_id", "")))
	var origin_name: String = _get_bond_display_name(str(item.get("origin_tag", "")))
	var mastery_name: String = _get_bond_display_name(str(item.get("mastery_tag", "")))
	var tactic_name: String = _get_bond_display_name(str(item.get("tactic_tag", "")))
	var weight_text: String = "当前招募权重 %.0f" % float(item.get("recruit_weight", 0.0))
	var share_text: String = "候选占比 %.1f%%" % float(item.get("recruit_weight_share", 0.0))
	var base_text: String = "%s [%s / %s / %s]\n%s | %s" % [
		display_name,
		origin_name,
		mastery_name,
		tactic_name,
		weight_text,
		share_text
	]
	if str(item.get("item_type", "")) == "recruit_replace":
		var out_name: String = _get_player_display_name(str(item.get("replace_out_player_id", "")))
		base_text += "\n替换目标：%s" % out_name
	else:
		base_text += "\n加入当前战术编队"
	return base_text

func _get_current_recruit_spawn_chance() -> float:
	if Global.selected_player_ids.size() >= Global.MAX_ACTIVE_SQUAD_SIZE:
		return RECRUIT_CHANCE_FULL_SQUAD
	return RECRUIT_CHANCE_UNDERFILLED

func _build_replace_candidates() -> Array[Dictionary]:
	var candidates: Array[Dictionary] = []
	var leader_player_id: String = ""
	if Global.has_method("get_leader_player_id"):
		leader_player_id = str(Global.get_leader_player_id())

	for player_id_variant in Global.selected_player_ids:
		var player_id: String = str(player_id_variant)
		if player_id.is_empty() or player_id == leader_player_id:
			continue
		var cfg: Dictionary = ConfigManager.get_player_config(player_id)
		var visual: Dictionary = ConfigManager.get_player_visual(player_id)
		var icon_path: String = str(visual.get("sprite_path", ""))
		if icon_path.is_empty():
			icon_path = str(cfg.get("portrait_sprite_path", ""))
		candidates.append({
			"player_id": player_id,
			"display_name": str(cfg.get("display_name", player_id)),
			"icon_path": icon_path,
		})
	return candidates

func update_recruit_replace_target(index: int, replace_out_player_id: String) -> bool:
	if index < 0 or index >= current_shop_items.size():
		return false

	var item: Dictionary = current_shop_items[index]
	if str(item.get("item_type", "")) != "recruit_replace":
		return false

	var normalized_target: String = replace_out_player_id.strip_edges()
	if normalized_target.is_empty():
		return false

	var valid_target: bool = false
	for candidate_variant in item.get("replace_candidates", []):
		if not (candidate_variant is Dictionary):
			continue
		var candidate: Dictionary = candidate_variant
		if str(candidate.get("player_id", "")) == normalized_target:
			valid_target = true
			break

	if not valid_target:
		return false

	item["replace_out_player_id"] = normalized_target
	item["effects"] = [
		{
			"description": _build_recruit_effect_desc(item),
			"is_trade_off": false
		}
	]
	item["description"] = str(item["effects"][0].get("description", ""))
	current_shop_items[index] = item
	shop_item_updated.emit(index, item)
	return true

func _get_recruit_candidates_for_shop(used_recruit_player_ids: Array[String]) -> Array[Dictionary]:
	var candidates: Array[Dictionary] = []
	var excluded_ids: Dictionary = {}

	for player_id in Global.selected_player_ids:
		excluded_ids[str(player_id)] = true
	for player_id in used_recruit_player_ids:
		excluded_ids[str(player_id)] = true

	var pool_ids: Array[String] = []
	for player_id in Global.reserve_player_ids:
		var normalized: String = str(player_id)
		if normalized.is_empty():
			continue
		if not pool_ids.has(normalized):
			pool_ids.append(normalized)

	if pool_ids.is_empty() and ConfigManager.has_method("get_enabled_players"):
		push_warning("[ShopManager] reserve recruit pool is empty; using enabled player fallback")
		var enabled_players_raw: Variant = ConfigManager.get_enabled_players()
		if enabled_players_raw is Array:
			for entry in enabled_players_raw:
				if not (entry is Dictionary):
					continue
				var cfg: Dictionary = entry
				var player_id: String = str(cfg.get("player_id", ""))
				if player_id.is_empty():
					continue
				if pool_ids.has(player_id):
					continue
				pool_ids.append(player_id)

	for player_id in pool_ids:
		if excluded_ids.has(player_id):
			continue

		var config: Dictionary = ConfigManager.get_player_config(player_id)
		if config.is_empty():
			continue
		if int(config.get("enabled", 0)) != 1:
			continue

		var visual: Dictionary = ConfigManager.get_player_visual(player_id)
		var display_name: String = str(config.get("display_name", player_id))
		var description: String = "Join current squad"
		var ties: String = str(config.get("ties", ""))
		if not ties.is_empty():
			description = "%s (%s)" % [description, ties]

		var icon_path: String = str(visual.get("sprite_path", ""))
		if icon_path.is_empty():
			icon_path = str(config.get("portrait_sprite_path", ""))

		candidates.append({
			"player_id": player_id,
			"display_name": display_name,
			"description": description,
			"icon_path": icon_path,
			"origin_tag": str(config.get("origin_tag", "")),
			"mastery_tag": str(config.get("mastery_tag", "")),
			"tactic_tag": str(config.get("tactic_tag", "")),
		})

	return candidates

func _pick_recruit_candidate(candidates: Array[Dictionary]) -> Dictionary:
	if candidates.is_empty():
		return {}

	var weighted: Array[Dictionary] = []
	var total_weight: float = 0.0
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
			"candidate": data.duplicate(true),
			"key": player_id,
			"weight": weight
		})
		total_weight += weight

	if weighted.is_empty():
		return candidates[0]

	if total_weight <= 0.0:
		return candidates[0]

	var roll: float = randf() * total_weight
	var cumulative: float = 0.0
	var picked_id: String = ""
	for entry in weighted:
		cumulative += float(entry.get("weight", 0.0))
		if roll <= cumulative:
			picked_id = str(entry.get("key", ""))
			break

	if picked_id.is_empty():
		picked_id = str(weighted.back().get("key", ""))

	for entry_variant in weighted:
		var entry: Dictionary = entry_variant
		var candidate: Dictionary = entry.get("candidate", {})
		if str(entry.get("key", "")) == picked_id:
			candidate["recruit_weight"] = float(entry.get("weight", 0.0))
			candidate["recruit_weight_share"] = (float(entry.get("weight", 0.0)) / total_weight) * 100.0
			return candidate

	return candidates[0]

func _select_default_replace_target(replace_candidates: Array[Dictionary] = []) -> String:
	var leader_player_id: String = ""
	if Global.has_method("get_leader_player_id"):
		leader_player_id = str(Global.get_leader_player_id())

	if not replace_candidates.is_empty():
		for i in range(replace_candidates.size() - 1, -1, -1):
			var candidate: Dictionary = replace_candidates[i]
			var player_id: String = str(candidate.get("player_id", ""))
			if player_id.is_empty() or player_id == leader_player_id:
				continue
			return player_id

	for player_id in Global.selected_player_ids:
		var normalized: String = str(player_id)
		if normalized != leader_player_id:
			return normalized
	return ""

func _get_bond_display_name(tag_id: String) -> String:
	var normalized_tag: String = tag_id.strip_edges()
	if normalized_tag.is_empty():
		return "未定义"

	var overrides := {
		"cyber": "赛博",
		"esper": "异能",
		"mech": "机械",
		"military": "军工",
		"vanguard": "锋芒",
		"anomaly": "术理",
		"sentinel": "御阵",
		"harmony": "协律",
		"shuttle": "爆发",
		"link": "连携",
		"knockback": "击退",
	}
	if overrides.has(normalized_tag):
		return str(overrides[normalized_tag])
	if BondUILoader != null and BondUILoader.has_method("get_bond_display_name"):
		var display_name: String = str(BondUILoader.get_bond_display_name(normalized_tag))
		if not display_name.is_empty() and not display_name.contains("?"):
			return display_name
	return normalized_tag.capitalize()

func _get_recruit_price(is_replace: bool) -> int:
	if is_replace:
		return FULL_SQUAD_REPLACE_COST

	match Global.selected_player_ids.size():
		0, 1:
			return FIRST_RECRUIT_COST
		2:
			return SECOND_RECRUIT_COST
		_:
			return FULL_SQUAD_REPLACE_COST

func _get_player_display_name(player_id: String) -> String:
	if player_id.is_empty():
		return ""
	var cfg: Dictionary = ConfigManager.get_player_config(player_id)
	return str(cfg.get("display_name", player_id))

func _ensure_recruit_player_available(player_id: String) -> bool:
	var normalized_player_id: String = player_id.strip_edges()
	if normalized_player_id.is_empty():
		return false
	if Global.selected_player_ids.has(normalized_player_id):
		printerr("[ShopManager] recruit target is already active: %s" % normalized_player_id)
		return false
	if Global.reserve_player_ids.has(normalized_player_id):
		return true

	var config: Dictionary = ConfigManager.get_player_config(normalized_player_id)
	if config.is_empty():
		printerr("[ShopManager] recruit target missing config: %s" % normalized_player_id)
		return false
	if int(config.get("enabled", 0)) != 1:
		printerr("[ShopManager] recruit target is disabled: %s" % normalized_player_id)
		return false

	Global.reserve_player_ids.append(normalized_player_id)
	return true

func _apply_recruit_purchase(item: Dictionary) -> bool:
	var player_id: String = str(item.get("player_id", "")).strip_edges()
	if not _ensure_recruit_player_available(player_id):
		return false

	var ok: bool = Global.recruit_player(player_id)
	if not ok:
		printerr("[ShopManager] recruit failed: player=%s active=%s reserve=%s" % [
			player_id,
			str(Global.selected_player_ids),
			str(Global.reserve_player_ids)
		])
	return ok

func _apply_recruit_replace_purchase(item: Dictionary) -> bool:
	var player_id: String = str(item.get("player_id", "")).strip_edges()
	if not _ensure_recruit_player_available(player_id):
		return false

	var replace_out_player_id: String = str(item.get("replace_out_player_id", "")).strip_edges()
	if replace_out_player_id.is_empty():
		var replace_candidates_variant: Variant = item.get("replace_candidates", [])
		var replace_candidates: Array[Dictionary] = []
		if replace_candidates_variant is Array:
			for candidate_variant in replace_candidates_variant:
				if candidate_variant is Dictionary:
					replace_candidates.append(candidate_variant)
		replace_out_player_id = _select_default_replace_target(replace_candidates)
	if replace_out_player_id.is_empty():
		printerr("[ShopManager] recruit_replace failed: missing replace_out_player_id for %s" % player_id)
		return false
	if not Global.selected_player_ids.has(replace_out_player_id):
		printerr("[ShopManager] recruit_replace failed: target %s is not active, active=%s" % [
			replace_out_player_id,
			str(Global.selected_player_ids)
		])
		return false

	var ok: bool = Global.replace_player(replace_out_player_id, player_id)
	if not ok:
		printerr("[ShopManager] recruit_replace failed: out=%s in=%s active=%s reserve=%s" % [
			replace_out_player_id,
			player_id,
			str(Global.selected_player_ids),
			str(Global.reserve_player_ids)
		])
	return ok

func _get_smart_emblem_weights() -> Dictionary:
	var weights: Dictionary = {}
	var base_weight: float = 1.0
	var boosted_weight: float = 3.0

	var bond_counts: Dictionary = BondManager.current_bond_counts
	var bond_configs: Dictionary = BondManager.bond_configs

	for bond_id_variant in bond_configs.keys():
		var bond_id: String = str(bond_id_variant)
		var count: int = int(bond_counts.get(bond_id, 0))
		var max_level: int = int(BondManager.get_bond_max_level(bond_id))
		var current_level: int = int(BondManager.get_activated_level(bond_id, count))
		if count > 0 and current_level < max_level:
			weights[bond_id] = boosted_weight
		else:
			weights[bond_id] = base_weight

	return weights

func purchase_item(index: int) -> bool:
	if index < 0 or index >= current_shop_items.size():
		purchase_failed.emit("invalid shop index")
		return false

	if index in purchased_indices:
		purchase_failed.emit("item already purchased")
		return false

	var item: Dictionary = current_shop_items[index]
	var item_id: String = str(item.get("item_id", ""))
	var price: int = int(item.get("price", 0))
	var current_gold: int = RunStateService.get_run_gold()
	if current_gold < price:
		purchase_failed.emit("not enough gold")
		return false

	var purchase_result: Dictionary = ShopDomainService.try_purchase(price, func() -> bool:
		return _apply_purchase_payload(item)
	)
	if not bool(purchase_result.get("success", false)):
		var reason: String = str(purchase_result.get("reason", "purchase failed"))
		print("[ShopManager] purchase failed: %s" % reason)
		purchase_failed.emit(reason)
		return false

	purchased_indices.append(index)
	print("[ShopManager] purchase success: item_id=%s, price=%d" % [item_id, price])
	item_purchased.emit(item_id, index)
	return true

func _apply_purchase_payload(item: Dictionary) -> bool:
	var item_id: String = str(item.get("item_id", ""))
	var item_type: String = str(item.get("item_type", ""))

	match item_type:
		"emblem":
			return EmblemManager.add_emblem(item_id)
		"equipment":
			return WarehouseManager.add_item_by_id(item_id)
		"recruit":
			return _apply_recruit_purchase(item)
		"recruit_replace":
			return _apply_recruit_replace_purchase(item)
		"consumable":
			return _apply_item_effects(item)
		_:
			printerr("[ShopManager] unknown item type: %s" % item_type)
			return false

func _apply_item_effects(item: Dictionary) -> bool:
	var effects: Array = item.get("effects", [])
	var item_id: String = str(item.get("item_id", "unknown"))

	var player_node: Node = Global.player
	if player_node == null or not (player_node is PlayerBase):
		printerr("[ShopManager] cannot apply consumable effects without active player: %s" % item_id)
		return false

	var player: PlayerBase = player_node
	var all_ok: bool = true
	for effect_variant in effects:
		if not (effect_variant is Dictionary):
			all_ok = false
			continue
		var effect: Dictionary = effect_variant
		var ok: bool = PurchaseEffectPipeline.apply_effect(player, effect, {
			"source": "shop_manager",
			"item_id": item_id
		})
		if not ok:
			all_ok = false
			printerr("[ShopManager] effect apply failed: item_id=%s effect=%s" % [item_id, str(effect)])

	return all_ok

func _apply_stat_effect(player: PlayerBase, stat_tags: Array, value: float, effect_type: String = "") -> void:
	if stat_tags.is_empty():
		return
	if not PurchaseEffectPipeline.apply_from_tags(player, stat_tags, value, effect_type, {
		"source": "shop_manager"
	}):
		printerr("[ShopManager] unknown stat effect: type=%s tags=%s" % [effect_type, str(stat_tags)])

func reroll_shop() -> bool:
	var reroll_cost: int = get_reroll_cost()
	var current_gold: int = RunStateService.get_run_gold()
	if current_gold < reroll_cost:
		purchase_failed.emit("not enough gold")
		return false

	var result: Dictionary = ShopDomainService.try_reroll(reroll_cost, func() -> bool:
		generate_shop_items(current_shop_items.size(), -1)
		return true
	)
	if not bool(result.get("success", false)):
		var reason: String = str(result.get("reason", "reroll failed"))
		purchase_failed.emit(reason)
		return false

	current_shop_reroll_count += 1
	shop_rerolled.emit()
	return true

func get_current_shop_items() -> Array:
	return current_shop_items

func is_item_purchased(index: int) -> bool:
	return index in purchased_indices

func get_reroll_cost() -> int:
	var base_cost: int = max(0, int(ConfigManager.get_game_setting("shop_reroll_base_cost", REROLL_BASE_COST)))
	var cost_increment: int = max(0, int(ConfigManager.get_game_setting("shop_reroll_cost_increment", REROLL_COST_INCREMENT)))
	return base_cost + (current_shop_reroll_count * cost_increment)

func print_shop_items() -> void:
	print("\n========== Current Shop Items ==========")
	for i in range(current_shop_items.size()):
		var item: Dictionary = current_shop_items[i]
		var item_id: String = str(item.get("item_id", "unknown"))
		var item_name: String = str(item.get("item_name", "unknown"))
		var item_type: String = str(item.get("item_type", ""))
		var price: int = int(item.get("price", 0))
		var purchased: String = " [purchased]" if is_item_purchased(i) else ""
		print("[%d] %s (%s/%s) - %d gold%s" % [i, item_name, item_id, item_type, price, purchased])
	print("==================================\n")
