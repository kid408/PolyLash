extends Node

# 商店管理器（局内）
# - 刷新徽章/装备
# - 装备购买后进入仓库
# - 消耗品保留兼容（仅作为兜底）

signal shop_items_generated(items: Array)
signal item_purchased(item_id: String, index: int)
signal shop_rerolled()
signal purchase_failed(reason: String)

const REROLL_COST: int = 20
const EMBLEM_SPAWN_CHANCE: float = 0.25

# 旧版消耗品配置（作为兜底）
var shop_item_configs: Dictionary = {}

# [{item_id, item_name, item_type, price, icon_path, effects, ...}]
var current_shop_items: Array = []
var purchased_indices: Array[int] = []

func _ready() -> void:
	_load_shop_configs()
	print("[ShopManager] 初始化完成，加载了 %d 个商店配置项" % shop_item_configs.size())

func _load_shop_configs() -> void:
	shop_item_configs = ConfigRepository.load_shop_item_configs()
	var line_count: int = 0
	for item_id_variant in shop_item_configs.keys():
		var item_id: String = str(item_id_variant)
		var cfg: Dictionary = shop_item_configs[item_id]
		line_count += cfg.get("effects", []).size()
	print("[ShopManager] 通过 ConfigRepository 加载了 %d 行商店配置数据" % line_count)

func generate_shop_items(count: int = 3) -> void:
	current_shop_items.clear()
	purchased_indices.clear()

	var used_ids: Array[String] = []
	for _i in range(count):
		var item: Dictionary = {}
		if randf() < EMBLEM_SPAWN_CHANCE:
			item = _generate_emblem_item(used_ids)
		else:
			item = _generate_equipment_item(used_ids)

		# 极端情况下兜底到旧消耗品池
		if item.is_empty():
			item = _generate_consumable_item(used_ids)

		if item.is_empty():
			continue

		var item_id: String = str(item.get("item_id", ""))
		if item_id.is_empty():
			continue

		used_ids.append(item_id)
		current_shop_items.append(item)

	print("[ShopManager] 商店物品生成完成: %s" % str(_get_item_ids()))
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
		var emblem_id: String = str(config.get("emblem_id", ""))
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
		purchase_failed.emit("无效的物品索引")
		return false

	if index in purchased_indices:
		purchase_failed.emit("物品已购买")
		return false

	var item: Dictionary = current_shop_items[index]
	var item_id: String = str(item.get("item_id", ""))
	var price: int = int(item.get("price", 0))
	var current_gold: int = RunStateService.get_run_gold()
	if current_gold < price:
		purchase_failed.emit("金币不足")
		return false

	var purchase_result: Dictionary = ShopDomainService.try_purchase(price, func() -> bool:
		return _apply_purchase_payload(item)
	)
	if not bool(purchase_result.get("success", false)):
		var reason: String = str(purchase_result.get("reason", "购买失败"))
		print("[ShopManager] 购买失败: %s" % reason)
		purchase_failed.emit(reason)
		return false

	purchased_indices.append(index)
	print("[ShopManager] 购买成功: item_id=%s, price=%d" % [item_id, price])
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
		"consumable":
			return _apply_item_effects(item)
		_:
			printerr("[ShopManager] 未知商品类型: %s" % item_type)
			return false

func _apply_item_effects(item: Dictionary) -> bool:
	var effects: Array = item.get("effects", [])
	var item_id: String = str(item.get("item_id", "unknown"))

	var player_node: Node = Global.player
	if player_node == null or not (player_node is PlayerBase):
		printerr("[ShopManager] 当前无有效玩家，无法应用消耗品效果: %s" % item_id)
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
			printerr("[ShopManager] 效果应用失败: item_id=%s, effect=%s" % [item_id, str(effect)])

	return all_ok

func _apply_stat_effect(player: PlayerBase, stat_tags: Array, value: float, effect_type: String = "") -> void:
	if stat_tags.is_empty():
		return
	if not PurchaseEffectPipeline.apply_from_tags(player, stat_tags, value, effect_type, {
		"source": "shop_manager"
	}):
		printerr("[ShopManager] 未知或无效的属性效果: type=%s, tags=%s" % [effect_type, str(stat_tags)])

func reroll_shop() -> bool:
	var current_gold: int = RunStateService.get_run_gold()
	if current_gold < REROLL_COST:
		purchase_failed.emit("金币不足")
		return false

	var result: Dictionary = ShopDomainService.try_reroll(REROLL_COST, func() -> bool:
		generate_shop_items(current_shop_items.size())
		return true
	)
	if not bool(result.get("success", false)):
		var reason: String = str(result.get("reason", "刷新失败"))
		purchase_failed.emit(reason)
		return false

	shop_rerolled.emit()
	return true

func get_current_shop_items() -> Array:
	return current_shop_items

func is_item_purchased(index: int) -> bool:
	return index in purchased_indices

func get_reroll_cost() -> int:
	return REROLL_COST

func print_shop_items() -> void:
	print("\n========== 当前商店物品 ==========")
	for i in range(current_shop_items.size()):
		var item: Dictionary = current_shop_items[i]
		var item_id: String = str(item.get("item_id", "unknown"))
		var item_name: String = str(item.get("item_name", "未知"))
		var item_type: String = str(item.get("item_type", ""))
		var price: int = int(item.get("price", 0))
		var purchased: String = " [已购买]" if is_item_purchased(i) else ""
		print("[%d] %s (%s/%s) - %d金币%s" % [i, item_name, item_id, item_type, price, purchased])
	print("==================================\n")
