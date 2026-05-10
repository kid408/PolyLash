extends Node

const DEBUG_VERBOSE := false
const COMBAT_EVENT_TYPES := preload("res://scenes/components/combat_event_types.gd")
const PRISM_STUN_SCENE := preload("res://scenes/effects/prism_stun.tscn")

# 羁绊系统核心入口：
# 1) 汇总角色/装备/护符/临时标签四类来源；
# 2) 计算各羁绊激活等级与效果列表；
# 3) 对外发射重算信号，驱动 HUD 与属性重算。
signal bonds_recalculated(active_bonds: Dictionary)
signal stat_modifiers_changed()
signal bond_level_changed(bond_id: String, old_level: int, new_level: int)


# 配表缓存：bond_id -> BondConfig
var bond_configs: Dictionary = {}

# 当前已激活羁绊：bond_id -> { level, effects, ... }
var active_bonds: Dictionary = {}

# 当前标签总数：bond_id -> count
var current_bond_counts: Dictionary = {}

# 标签来源拆分：用于 UI 展示和 3级激活判定
var tag_sources: Dictionary = {}

# 临时标签（战斗中临时加成）
var temp_bonus_tags: Dictionary = {}
var _damage_hook_cooldowns: Dictionary = {}
var _front_player_ref: WeakRef = null
var _front_player_id: String = ""
var _cyber_last_stand_used: bool = false
var _active_laser_walls: Array[Dictionary] = []
var _active_static_barriers: Array[Dictionary] = []

# 狂暴模式：开启后，任意羁绊可直接按最高级结算
var is_overdrive_mode: bool = false

# 兜底队伍缓存，防止实时队伍尚未就绪时无法重算
var _last_team_player_ids: Array = []


func _ready() -> void:
	_load_bond_configs()
	_connect_runtime_sources()
	if DEBUG_VERBOSE: print("[BondManager] init done, loaded %d bond configs" % bond_configs.size())



func _connect_runtime_sources() -> void:
	if EmblemManager == null or Global == null:
		call_deferred("_connect_runtime_sources")
		return

	if not EmblemManager.emblem_added.is_connected(_on_emblem_inventory_changed):
		EmblemManager.emblem_added.connect(_on_emblem_inventory_changed)
	if not EmblemManager.emblem_removed.is_connected(_on_emblem_inventory_changed):
		EmblemManager.emblem_removed.connect(_on_emblem_inventory_changed)
	if not Global.on_player_switch_requested.is_connected(_on_player_switch_requested):
		Global.on_player_switch_requested.connect(_on_player_switch_requested)
	_refresh_front_player_connections()

func _process(delta: float) -> void:
	_refresh_front_player_connections()
	if _damage_hook_cooldowns.is_empty():
		_process_runtime_mechanics(delta)
		return
	var expired_keys: Array[String] = []
	for key_variant: Variant in _damage_hook_cooldowns.keys():
		var key: String = str(key_variant)
		var remaining: float = max(0.0, float(_damage_hook_cooldowns.get(key, 0.0)) - delta)
		if remaining <= 0.0:
			expired_keys.append(key)
		else:
			_damage_hook_cooldowns[key] = remaining
	for key: String in expired_keys:
		_damage_hook_cooldowns.erase(key)
	_process_runtime_mechanics(delta)

func _on_emblem_inventory_changed(_emblem_data: Dictionary) -> void:
	_recalculate_with_current_team()
func _load_bond_configs() -> void:
	bond_configs = ConfigRepository.load_bond_configs()
	var line_count: int = 0
	for bond_id in bond_configs.keys():
		line_count += bond_configs[bond_id].levels.size()
	if DEBUG_VERBOSE: print("[BondManager] loaded %d bond config rows from ConfigRepository" % line_count)


func recalculate_active_bonds(team_player_ids: Array, equipped_relics: Array = []) -> void:
	# 兼容保留参数：equipped_relics 当前版本未直接使用，来源统一由 EquipmentManager 读取。
	var old_bonds = active_bonds.duplicate(true)
	_last_team_player_ids = team_player_ids.duplicate()
	

	current_bond_counts.clear()
	tag_sources.clear()
	active_bonds.clear()
	

	# 1) 角色本体标签
	_count_character_tags(team_player_ids)
	

	# 2) 装备赋予标签
	_count_equipment_tags(team_player_ids)
	

	# 3) 护符标签
	_count_emblem_tags()
	

	# 4) 临时标签
	_add_temp_tags()
	
	for bond_id in bond_configs.keys():
		var count = current_bond_counts.get(bond_id, 0)
		if count == 0:
			continue
		
		var activated_level = _get_activated_level(bond_id, count)
		if activated_level > 0:
			_activate_bond(bond_id, activated_level)
	

	_detect_level_changes(old_bonds)
	
	if DEBUG_VERBOSE: print("[BondManager] recalc bonds: tags=%d active=%d" % [current_bond_counts.size(), active_bonds.size()])
	if DEBUG_VERBOSE: print("[BondManager] tag counts: %s" % str(current_bond_counts))
	if DEBUG_VERBOSE: print("[BondManager] tag sources: %s" % str(tag_sources))
	if DEBUG_VERBOSE: print("[BondManager] active bond ids: %s" % str(active_bonds.keys()))
	

	bonds_recalculated.emit(active_bonds)
	stat_modifiers_changed.emit()


func _count_character_tags(team_player_ids: Array) -> void:
	for player_id in team_player_ids:
		var config = ConfigManager.get_player_config(player_id)
		if config.is_empty():
			continue

		var tags = [
			config.get("origin_tag", ""),
			config.get("mastery_tag", ""),
			config.get("tactic_tag", "")
		]

		for tag in tags:
			if tag == "":
				continue
			current_bond_counts[tag] = current_bond_counts.get(tag, 0) + 1
			_add_tag_source(tag, "character", 1)


func _count_equipment_tags(team_player_ids: Array) -> void:
	for pid in team_player_ids:
		var item_data = EquipmentManager.get_equipped_item_data(str(pid))
		if item_data.is_empty():
			continue

		var bond_grant := str(item_data.get("bond_grant", "")).strip_edges()
		if bond_grant.is_empty():
			continue

		for tag in bond_grant.split("|"):
			var cleaned_tag := tag.strip_edges()
			if cleaned_tag.is_empty():
				continue
			current_bond_counts[cleaned_tag] = current_bond_counts.get(cleaned_tag, 0) + 1
			_add_tag_source(cleaned_tag, "equipment", 1)


func _count_emblem_tags() -> void:
	var emblem_tags = EmblemManager.get_emblem_tags()
	for tag in emblem_tags:
		current_bond_counts[tag] = current_bond_counts.get(tag, 0) + emblem_tags[tag]
		_add_tag_source(tag, "emblem", emblem_tags[tag])


func _add_temp_tags() -> void:
	for tag in temp_bonus_tags.keys():
		current_bond_counts[tag] = current_bond_counts.get(tag, 0) + temp_bonus_tags[tag]


func _add_tag_source(bond_tag: String, source: String, count: int) -> void:
	if not tag_sources.has(bond_tag):
		tag_sources[bond_tag] = {
			"character": 0,
			"equipment": 0,
			"emblem": 0
		}
	tag_sources[bond_tag][source] += count


func _get_activated_level(bond_id: String, current_count: int) -> int:
	if not bond_configs.has(bond_id):
		return 0

	var levels = bond_configs[bond_id].levels
	var activated_level := 0

	if is_overdrive_mode and current_count >= 1 and levels.size() > 0:
		return levels[levels.size() - 1].level

	for level_data in levels:
		if current_count >= level_data.required_count:
			activated_level = level_data.level
		else:
			break

	if activated_level >= 3 and not _can_activate_level3_from_runtime_source(bond_id):
		# 3级必须至少有一种“运行时来源”（装备/护符/临时标签），纯角色数量不可直达3级。
		activated_level = min(activated_level, 2)

	return activated_level


func _can_activate_level3_from_runtime_source(bond_id: String) -> bool:
	# 只要运行时来源任意一项>0，即允许突破到3级。
	var sources = get_tag_sources(bond_id)
	var equip_count := int(sources.get("equipment", 0))
	var emblem_count := int(sources.get("emblem", 0))
	var temp_count := int(temp_bonus_tags.get(bond_id, 0))
	return (equip_count + emblem_count + temp_count) > 0

func _activate_bond(bond_id: String, level: int) -> void:
	if not bond_configs.has(bond_id):
		return
	
	var levels = bond_configs[bond_id].levels
	var effects = []
	
	for level_data in levels:
		if level_data.level <= level:
			effects.append({
				"level": level_data.level,
				"effect_type": level_data.effect_type,
				"effect_param": level_data.effect_param,
				"effect_value": level_data.effect_value,
				"description": level_data.description
			})
	
	active_bonds[bond_id] = {
		"level": level,
		"effects": effects,
		"bond_type": bond_configs[bond_id].bond_type,
		"display_name": bond_configs[bond_id].display_name
	}

func _detect_level_changes(old_bonds: Dictionary) -> void:
	for bond_id in active_bonds.keys():
		var new_level = active_bonds[bond_id].level
		var old_level = old_bonds.get(bond_id, {}).get("level", 0)
		if new_level != old_level:
			bond_level_changed.emit(bond_id, old_level, new_level)
	
	for bond_id in old_bonds.keys():
		if not active_bonds.has(bond_id):
			bond_level_changed.emit(bond_id, old_bonds[bond_id].level, 0)


func get_active_bond_level(bond_id: String) -> int:
	if active_bonds.has(bond_id):
		return active_bonds[bond_id].level
	return 0

func get_bond_max_level(bond_id: String) -> int:
	if not bond_configs.has(bond_id):
		return 0
	
	var levels = bond_configs[bond_id].levels
	if levels.size() == 0:
		return 0
	
	return levels[levels.size() - 1].level

func get_bond_required_count(bond_id: String, level: int) -> int:
	if not bond_configs.has(bond_id):
		return 0
	
	for level_data in bond_configs[bond_id].levels:
		if level_data.level == level:
			return level_data.required_count
	
	return 0

func get_bond_current_count(bond_id: String) -> int:
	return current_bond_counts.get(bond_id, 0)

func is_bond_active(bond_id: String) -> bool:
	return active_bonds.has(bond_id)

func get_all_active_bonds() -> Dictionary:
	return active_bonds.duplicate(true)

func get_bond_config(bond_id: String) -> Dictionary:
	return bond_configs.get(bond_id, {})

func get_bond_display_name(bond_id: String) -> String:
	if not bond_configs.has(bond_id):
		return bond_id
	
	return bond_configs[bond_id].get("display_name", bond_id)

func get_activated_level(bond_id: String, count: int) -> int:
	return _get_activated_level(bond_id, count)

func get_tag_sources(bond_tag: String) -> Dictionary:
	if tag_sources.has(bond_tag):
		return tag_sources[bond_tag].duplicate()
	return {"character": 0, "equipment": 0, "emblem": 0}





static func format_bond_status(count: int, activated_level: int, max_level: int, next_required: int) -> String:
	if activated_level == 0:
		return "0/%d" % next_required
	elif activated_level >= max_level:
		if count > next_required:
			return "Lv.%d (%d/%d)" % [activated_level, count, next_required]
		return "Lv.MAX"
	else:
		return "Lv.%d (%d/%d)" % [activated_level, count, next_required]

func get_bond_status_text(bond_id: String, count: int) -> String:
	var activated_level = get_activated_level(bond_id, count)
	var max_level = get_bond_max_level(bond_id)
	
	var next_required: int = 0
	if activated_level == 0:

		next_required = get_bond_required_count(bond_id, 1)
	elif activated_level >= max_level:

		next_required = get_bond_required_count(bond_id, max_level)
	else:

		next_required = get_bond_required_count(bond_id, activated_level + 1)
	
	if next_required == 0:
		next_required = 1
	
	return BondManager.format_bond_status(count, activated_level, max_level, next_required)

func get_bond_tooltip_text(bond_id: String, current_count: int) -> String:
	if not bond_configs.has(bond_id):
		return "Unknown Bond"

	var config = bond_configs[bond_id]
	var display_name = config.get("display_name", bond_id)
	var levels = config.get("levels", [])

	if levels.is_empty():
		return display_name

	var activated_level: int = get_activated_level(bond_id, current_count)
	var max_level: int = get_bond_max_level(bond_id)
	var next_required: int = get_bond_required_count(bond_id, min(max_level, activated_level + 1))
	if activated_level <= 0:
		next_required = get_bond_required_count(bond_id, 1)
	var remain_to_next: int = max(0, next_required - current_count)
	var mechanic_summary: String = _get_current_mechanic_summary(bond_id)

	var tooltip = "[%s] count=%d level=Lv.%d/%d\n" % [display_name, current_count, activated_level, max_level]
	if activated_level >= max_level and max_level > 0:
		tooltip += "Next: MAX\n"
	else:
		tooltip += "Next: +%d tags\n" % remain_to_next
	tooltip += "Mechanic: %s\n" % mechanic_summary

	for level_data in levels:
		var required = level_data.required_count
		var description = level_data.description
		var is_active = current_count >= required
		var status = "[x]" if is_active else "[ ]"
		tooltip += "%s (%d) %s\n" % [status, required, description]

	return tooltip.strip_edges()

func _get_current_mechanic_summary(bond_id: String) -> String:
	if not active_bonds.has(bond_id):
		return "inactive"
	var effects = active_bonds[bond_id].get("effects", [])
	var parts: Array[String] = []
	for effect in effects:
		if str(effect.get("effect_type", "")) != "mechanic":
			continue
		var desc := str(effect.get("description", "")).strip_edges()
		if desc.is_empty():
			desc = str(effect.get("effect_param", ""))
		parts.append(desc)
	return ", ".join(parts) if not parts.is_empty() else "stat bonus"

func record_damage_event(source: Variant, target: Variant, applied_damage: float, payload: Dictionary = {}) -> void:
	if applied_damage <= 0.0:
		return
	if bool(payload.get("is_shared_damage", false)):
		return

	var damage_type: int = COMBAT_EVENT_TYPES.normalize_damage_type(
		payload.get("damage_type", COMBAT_EVENT_TYPES.DamageType.DIRECT)
	)
	var source_player: PlayerBase = _resolve_damage_source_player(source)
	var target_enemy: Enemy = target as Enemy if target is Enemy else null
	if source_player != null and is_instance_valid(source_player):
		if damage_type != COMBAT_EVENT_TYPES.DamageType.DOT:
			_try_trigger_generic_lifesteal(source_player, applied_damage)
		if target_enemy != null and is_instance_valid(target_enemy):
			_try_trigger_anomaly_reactor(source_player, target_enemy)
	if damage_type == COMBAT_EVENT_TYPES.DamageType.AOE and target_enemy != null and is_instance_valid(target_enemy):
		_try_apply_military_vulnerable(target_enemy, source_player)
		_try_trigger_global_damage_share(target_enemy, applied_damage, payload)
	match damage_type:
		COMBAT_EVENT_TYPES.DamageType.AOE:
			_try_trigger_aoe_shard_burst(source, target, applied_damage, payload)
		COMBAT_EVENT_TYPES.DamageType.DOT:
			_try_trigger_dot_lifesteal(source, applied_damage)

func process_enemy_knockback(enemy: Variant, payload: Dictionary) -> Dictionary:
	var result: Dictionary = payload.duplicate(true)
	if not has_mechanic("knockback_power_scale"):
		return result
	var bonus_scale: float = max(0.0, float(get_mechanic_value("knockback_power_scale")))
	result["power"] = float(result.get("power", 0.0)) * (1.0 + bonus_scale)
	result["bond_modified"] = true
	result["bond_modifier"] = "knockback_power_scale"
	return result

func _try_trigger_aoe_shard_burst(source: Variant, target: Variant, applied_damage: float, _payload: Dictionary) -> void:
	if not has_mechanic("aoe_shard_burst"):
		return
	if not (target is Enemy):
		return
	var target_enemy: Enemy = target as Enemy
	if target_enemy == null or not is_instance_valid(target_enemy) or target_enemy.is_dead:
		return

	var cooldown_key: String = "aoe_shard_burst:%d" % target_enemy.get_instance_id()
	if float(_damage_hook_cooldowns.get(cooldown_key, 0.0)) > 0.0:
		return
	_damage_hook_cooldowns[cooldown_key] = 0.05

	var damage_ratio: float = max(0.05, float(get_mechanic_value("aoe_shard_burst")))
	var shard_damage: float = max(1.0, applied_damage * damage_ratio)
	var candidate_enemies: Array[Enemy] = []
	for enemy_node: Node in get_tree().get_nodes_in_group("enemies"):
		if not (enemy_node is Enemy):
			continue
		var enemy: Enemy = enemy_node as Enemy
		if enemy == target_enemy or not is_instance_valid(enemy) or enemy.is_dead:
			continue
		if enemy.global_position.distance_to(target_enemy.global_position) > 120.0:
			continue
		candidate_enemies.append(enemy)
	candidate_enemies.sort_custom(func(a: Enemy, b: Enemy) -> bool:
		return target_enemy.global_position.distance_squared_to(a.global_position) < target_enemy.global_position.distance_squared_to(b.global_position)
	)
	var shard_hits: int = min(3, candidate_enemies.size())
	for i: int in range(shard_hits):
		var shard_target: Enemy = candidate_enemies[i]
		shard_target.apply_modifier_damage(shard_damage, source, {
			"kind": "bond_aoe_shard_burst",
			"damage_type": COMBAT_EVENT_TYPES.DamageType.AOE,
		})
		if shard_target.has_method("set_flash_material"):
			shard_target.set_flash_material()
	if shard_hits > 0:
		Global.spawn_floating_text(target_enemy.global_position + Vector2(0, -16), "SHARD", Color(1.0, 0.82, 0.52))

func _try_trigger_dot_lifesteal(source: Variant, applied_damage: float) -> void:
	if not has_mechanic("dot_lifesteal"):
		return
	var source_player: PlayerBase = _resolve_damage_source_player(source)
	if source_player == null or not is_instance_valid(source_player):
		return
	if source_player.health_component == null or source_player.health_component.current_health <= 0.0:
		return
	var lifesteal_ratio: float = max(0.0, float(get_mechanic_value("dot_lifesteal")))
	if lifesteal_ratio <= 0.0:
		return
	var heal_amount: float = max(1.0, applied_damage * lifesteal_ratio)
	source_player.health_component.heal(heal_amount)
	Global.spawn_floating_text(source_player.global_position + Vector2(0, -18), "+%d" % int(round(heal_amount)), Color(0.72, 1.0, 0.72))

func _resolve_damage_source_player(source: Variant) -> PlayerBase:
	var source_object: Object = _as_valid_object(source)
	if source_object == null:
		return null
	if source_object is PlayerBase:
		return source_object as PlayerBase
	if source_object is Node:
		var source_node: Node = source_object as Node
		if source_node.has_meta("owner_player"):
			var owner_player: PlayerBase = _as_valid_player_base(source_node.get_meta("owner_player"))
			if owner_player != null:
				return owner_player
		if source_node.has_method("get_owner_player"):
			var owner_result: Variant = source_node.call("get_owner_player")
			var owner_player_result: PlayerBase = _as_valid_player_base(owner_result)
			if owner_player_result != null:
				return owner_player_result
	return null

func _as_valid_object(value: Variant) -> Object:
	if value == null:
		return null
	if typeof(value) != TYPE_OBJECT:
		return null
	var object_value: Object = value as Object
	if object_value == null or not is_instance_valid(object_value):
		return null
	return object_value

func _as_valid_player_base(value: Variant) -> PlayerBase:
	var object_value: Object = _as_valid_object(value)
	if object_value == null or not (object_value is PlayerBase):
		return null
	return object_value as PlayerBase

func preprocess_damage(target_owner: Variant, incoming_damage: float, payload: Dictionary = {}) -> Dictionary:
	var processed_payload: Dictionary = payload.duplicate(true)
	var damage_value: float = incoming_damage
	var damage_type: int = COMBAT_EVENT_TYPES.normalize_damage_type(
		processed_payload.get("damage_type", COMBAT_EVENT_TYPES.DamageType.DIRECT)
	)
	processed_payload["damage_type"] = damage_type

	var source_player: PlayerBase = _resolve_damage_source_player(processed_payload.get("source", null))
	if source_player != null and is_instance_valid(source_player):
		if damage_type == COMBAT_EVENT_TYPES.DamageType.DIRECT and has_mechanic("blood_shield_true_damage") and source_player.get_blood_shield() > 0.0:
			damage_value *= max(1.0, float(get_mechanic_value("blood_shield_true_damage")))
			processed_payload["damage_type"] = COMBAT_EVENT_TYPES.DamageType.TRUE_DAMAGE
			processed_payload["true_damage"] = true
		if processed_payload["damage_type"] == COMBAT_EVENT_TYPES.DamageType.AOE and target_owner is Enemy:
			var target_enemy: Enemy = target_owner as Enemy
			if target_enemy != null and (target_enemy.get_abnormal_state_count() > 0 or target_enemy.has_mechanic_mark("soul_link") or target_enemy.has_mechanic_mark("mark")):
				damage_value *= 1.0 + max(0.0, float(get_mechanic_value("aoe_mark_amp")))

	return {
		"damage": damage_value,
		"payload": processed_payload,
	}

func try_prevent_player_lethal(owner_node: Variant, _payload: Dictionary = {}) -> Dictionary:
	if _cyber_last_stand_used:
		return {"prevent_death": false}
	if not has_mechanic("cyber_last_stand"):
		return {"prevent_death": false}
	if not is_instance_valid(owner_node) or not (owner_node is PlayerBase):
		return {"prevent_death": false}
	var player_node: PlayerBase = owner_node as PlayerBase
	if player_node == null or not is_instance_valid(player_node):
		return {"prevent_death": false}
	_cyber_last_stand_used = true
	player_node.energy = player_node.max_energy
	player_node.add_blood_shield(player_node.health_component.max_health * 0.5, player_node.health_component.max_health * 0.5)
	player_node.update_ui_signals()
	player_node.set_meta("buff_invincible", true)
	var active_player_ref: WeakRef = weakref(player_node)
	get_tree().create_timer(3.0).timeout.connect(func() -> void:
		var restored_player: Variant = active_player_ref.get_ref()
		if is_instance_valid(restored_player) and restored_player is PlayerBase:
			if (restored_player as PlayerBase).has_meta("buff_invincible"):
				(restored_player as PlayerBase).remove_meta("buff_invincible")
	)
	Global.on_camera_shake.emit(10.0, 0.18)
	Global.frame_freeze(0.08, 0.12)
	Global.spawn_floating_text(player_node.global_position, "QUANTUM BACKUP", Color(0.52, 0.96, 1.0))
	return {
		"prevent_death": true,
		"restored_health": player_node.health_component.max_health,
	}

func on_health_component_healed(owner_node: Variant, _applied_amount: float, overflow_amount: float) -> void:
	if overflow_amount <= 0.0:
		return
	if not has_mechanic("blood_shield_overflow"):
		return
	if not (owner_node is PlayerBase):
		return
	var player_node: PlayerBase = owner_node as PlayerBase
	var shield_cap: float = player_node.health_component.max_health * max(0.0, float(get_mechanic_value("blood_shield_overflow")))
	player_node.add_blood_shield(overflow_amount, shield_cap)
	Global.spawn_floating_text(player_node.global_position + Vector2(0, -18), "BLOOD SHIELD", Color(1.0, 0.36, 0.46))

func consume_player_energy(player_node: PlayerBase, amount: float) -> bool:
	var remaining_cost: float = max(0.0, amount)
	if has_mechanic("shield_energy_buffer") and player_node.get_blood_shield() > 0.0:
		var spent_shield: float = player_node.spend_blood_shield(remaining_cost)
		remaining_cost = max(0.0, remaining_cost - spent_shield)
		if spent_shield > 0.0:
			Global.spawn_floating_text(player_node.global_position + Vector2(0, -20), "SHIELD -%.0f" % spent_shield, Color(1.0, 0.48, 0.56))
	if remaining_cost <= 0.0:
		return true
	if player_node.energy >= remaining_cost:
		player_node.energy -= remaining_cost
		return true
	return false

func on_player_took_damage(player_node: PlayerBase, _final_damage: float, _payload: Dictionary = {}) -> void:
	if has_mechanic("reactive_armor_on_hit"):
		player_node.add_temporary_armor_stack(5.0)

func on_space_draw_release(owner: Node, release_data: Dictionary) -> void:
	if owner == null or not is_instance_valid(owner):
		return
	if has_mechanic("post_release_speed_boost") and owner is PlayerBase:
		var player_node: PlayerBase = owner as PlayerBase
		player_node.apply_move_speed_modifier(
			"bond_vanguard_release_speed",
			1.0 + max(0.0, float(get_mechanic_value("post_release_speed_boost"))),
			2.0
		)
		player_node.set_meta("bond_super_armor_until", _now_seconds() + max(0.1, float(get_mechanic_value("post_release_super_armor"))))
		Global.spawn_floating_text(player_node.global_position + Vector2(0, -18), "RUSH", Color(0.86, 0.95, 1.0))
	if has_mechanic("closure_static_barrier") and bool(release_data.get("is_closed", false)):
		_try_spawn_static_barrier(release_data)
	if has_mechanic("mirrored_draw") and owner is PlayerBase:
		var base_damage: float = float(release_data.get("resolved_damage", (owner as PlayerBase).damage))
		Global.trigger_mirror_draw_from_player((owner as PlayerBase).player_id, (owner as PlayerBase).global_position, base_damage)

func apply_forced_closure(_owner: Node, points: PackedVector2Array) -> Dictionary:
	var result: Dictionary = {
		"points": points.duplicate(),
		"forced_closed": false,
	}
	if not has_mechanic("forced_closure"):
		return result
	if points.size() < 3:
		return result
	var total_length: float = _compute_polyline_length(points)
	if total_length < 150.0:
		return result
	var last_index: int = points.size() - 1
	var middle_index: int = int(floor(float(last_index) * 0.5))
	var first_point: Vector2 = points[0]
	var middle_point: Vector2 = points[middle_index]
	var last_point: Vector2 = points[last_index]
	var to_first: Vector2 = first_point - middle_point
	var to_last: Vector2 = last_point - middle_point
	if to_first.length_squared() <= 0.001 or to_last.length_squared() <= 0.001:
		return result
	var enclosed_angle: float = abs(to_first.angle_to(to_last))
	if enclosed_angle > (PI * 0.5 + 0.001):
		return result
	var resolved_points: PackedVector2Array = points.duplicate()
	if resolved_points[0].distance_to(resolved_points[resolved_points.size() - 1]) > 0.001:
		resolved_points.append(resolved_points[0])
	result["points"] = resolved_points
	result["forced_closed"] = true
	result["length"] = total_length
	return result

func on_draw_self_intersection(owner: Node, intersection_point: Vector2) -> void:
	if owner == null or not is_instance_valid(owner):
		return
	if not has_mechanic("prism_stun"):
		return
	var prism_key: String = "prism_spawn:%d:%d" % [int(round(intersection_point.x / 12.0)), int(round(intersection_point.y / 12.0))]
	if float(_damage_hook_cooldowns.get(prism_key, 0.0)) > 0.0:
		return
	_damage_hook_cooldowns[prism_key] = 0.12
	if PRISM_STUN_SCENE == null or get_tree() == null or get_tree().current_scene == null:
		return
	var prism_variant: Variant = PRISM_STUN_SCENE.instantiate()
	if not (prism_variant is Node2D):
		return
	var prism_node: Node2D = prism_variant as Node2D
	prism_node.global_position = intersection_point
	if prism_node.has_method("setup"):
		prism_node.call("setup", owner, 2.0 * _get_summoned_lifespan_scale(), 1.0)
	get_tree().current_scene.add_child(prism_node)

func on_front_skill_cast(owner: Node, skill_slot: String, _payload: Dictionary = {}) -> void:
	if owner == null or not is_instance_valid(owner):
		return
	if not has_mechanic("bench_energy_gain"):
		return
	if skill_slot != "e" and skill_slot != "f":
		return
	if not (owner is PlayerBase):
		return
	var bench_energy: float = max(0.0, float(get_mechanic_value("bench_energy_gain")))
	for player_id: String in Global.selected_player_ids:
		if player_id == (owner as PlayerBase).player_id:
			continue
		_gain_energy_to_player_id(player_id, bench_energy)

func on_dash_started(_owner: Node, _dash_data: Dictionary) -> void:
	pass

func on_enemy_killed(enemy: Enemy, payload: Dictionary = {}) -> void:
	if enemy == null or not is_instance_valid(enemy):
		return
	if has_mechanic("mark_spread_on_death") and (enemy.has_mechanic_mark("soul_link") or enemy.has_mechanic_mark("mark")):
		_spread_link_on_enemy_death(enemy)
	if has_mechanic("cyber_elite_skill_reset") and _is_elite_or_boss(enemy) and _payload_counts_as_skill_kill(payload):
		var active_player := _get_front_player()
		if active_player != null:
			active_player.reset_dash_cooldown()
			active_player.reset_skill_e_cooldown()
			Global.spawn_floating_text(active_player.global_position + Vector2(0, -24), "RESET", Color(0.56, 0.96, 1.0))

func on_enemy_knockback_wall_impact(enemy: Enemy, payload: Dictionary, hit: Dictionary = {}) -> void:
	if enemy == null or not is_instance_valid(enemy):
		return
	var impact_position: Vector2 = hit.get("position", enemy.global_position)
	var source_player: PlayerBase = _resolve_damage_source_player(payload.get("source", null))
	var source_attack: float = max(1.0, float(payload.get("source_attack", source_player.damage if source_player != null else 1.0)))
	if has_mechanic("knockback_wall_blast"):
		var blast_damage: float = source_attack * max(0.0, float(get_mechanic_value("knockback_wall_blast")))
		_deal_aoe_damage(impact_position, 96.0, blast_damage, source_player, "bond_knockback_wall_blast")
		Global.spawn_floating_text(impact_position, "WALL BLAST", Color(1.0, 0.76, 0.36))
	if has_mechanic("knockback_fission"):
		_try_trigger_knockback_fission(enemy, payload, impact_position)

func is_player_immune_to_knockback(player_node: PlayerBase) -> bool:
	if player_node == null or not is_instance_valid(player_node):
		return false
	if has_mechanic("immune_knockback"):
		return true
	var super_armor_until: float = float(player_node.get_meta("bond_super_armor_until", 0.0)) if player_node.has_meta("bond_super_armor_until") else 0.0
	return super_armor_until > _now_seconds()

func _on_player_switch_requested(target_player_id: String) -> void:
	var previous_player_id: String = _front_player_id
	call_deferred("_handle_player_switch_runtime", previous_player_id, target_player_id)

func _handle_player_switch_runtime(previous_player_id: String, target_player_id: String) -> void:
	_refresh_front_player_connections()
	if has_mechanic("switch_echo") and not previous_player_id.is_empty():
		var active_player := _get_front_player()
		if active_player != null and active_player.player_id == target_player_id:
			_try_trigger_switch_echo(previous_player_id, active_player)

func _refresh_front_player_connections() -> void:
	var active_player := _get_front_player()
	var current_id: String = active_player.player_id if active_player != null else ""
	if active_player == _get_cached_front_player() and current_id == _front_player_id:
		return
	var cached_player := _get_cached_front_player()
	if cached_player != null and cached_player.dash_finished.is_connected(_on_front_dash_finished):
		cached_player.dash_finished.disconnect(_on_front_dash_finished)
	_front_player_ref = weakref(active_player) if active_player != null else null
	_front_player_id = current_id
	if active_player != null and not active_player.dash_finished.is_connected(_on_front_dash_finished):
		active_player.dash_finished.connect(_on_front_dash_finished)
	_apply_entry_effects(active_player)

func _get_cached_front_player() -> PlayerBase:
	if _front_player_ref == null:
		return null
	var cached_variant: Variant = _front_player_ref.get_ref()
	if is_instance_valid(cached_variant) and cached_variant is PlayerBase:
		return cached_variant as PlayerBase
	return null

func _get_front_player() -> PlayerBase:
	if Global == null:
		return null
	var global_player: Variant = Global.player
	if is_instance_valid(global_player) and global_player is PlayerBase:
		return global_player as PlayerBase
	return null

func _apply_entry_effects(player_node: PlayerBase) -> void:
	if player_node == null or not is_instance_valid(player_node):
		return
	if has_mechanic("cyber_entry_energy"):
		var state: Dictionary = _get_or_create_player_state(player_node.player_id)
		if not bool(state.get("cyber_entry_granted", false)):
			_gain_energy_to_player_id(player_node.player_id, max(0.0, float(get_mechanic_value("cyber_entry_energy"))))
			state["cyber_entry_granted"] = true
			Global.player_states[player_node.player_id] = state

func _process_runtime_mechanics(delta: float) -> void:
	_process_active_laser_walls(delta)
	_process_static_barriers()
	_process_armor_pulse(delta)

func _process_static_barriers() -> void:
	if _active_static_barriers.is_empty():
		return
	var now: float = _now_seconds()
	var kept: Array[Dictionary] = []
	for barrier_entry: Dictionary in _active_static_barriers:
		var node_variant: Variant = barrier_entry.get("node", null)
		if not (node_variant is Node) or not is_instance_valid(node_variant):
			continue
		var expires_at: float = float(barrier_entry.get("expires_at", 0.0))
		if expires_at > 0.0 and expires_at <= now:
			(node_variant as Node).queue_free()
			continue
		kept.append(barrier_entry)
	_active_static_barriers = kept

func _process_active_laser_walls(delta: float) -> void:
	if _active_laser_walls.is_empty():
		return
	var now: float = _now_seconds()
	var kept: Array[Dictionary] = []
	for wall_entry: Dictionary in _active_laser_walls:
		var expires_at: float = float(wall_entry.get("expires_at", 0.0))
		var line_variant: Variant = wall_entry.get("line", null)
		var line_node: Line2D = line_variant as Line2D if line_variant is Line2D else null
		if expires_at <= now:
			if line_node != null and is_instance_valid(line_node):
				line_node.queue_free()
			continue
		var next_tick_at: float = float(wall_entry.get("next_tick_at", 0.0)) - delta
		wall_entry["next_tick_at"] = next_tick_at
		if next_tick_at <= 0.0:
			wall_entry["next_tick_at"] = 0.2
			_tick_laser_wall(wall_entry)
		kept.append(wall_entry)
	_active_laser_walls = kept

func _process_armor_pulse(_delta: float) -> void:
	if not has_mechanic("armor_pulse"):
		return
	var active_player := _get_front_player()
	if active_player == null:
		return
	var cooldown_key: String = "armor_pulse:%s" % active_player.player_id
	if float(_damage_hook_cooldowns.get(cooldown_key, 0.0)) > 0.0:
		return
	if active_player.get_temporary_armor_bonus() < 20.0:
		return
	_damage_hook_cooldowns[cooldown_key] = 1.0
	var pulse_damage: float = max(1.0, (float(active_player.armor) + active_player.get_temporary_armor_bonus()) * max(0.0, float(get_mechanic_value("armor_pulse"))))
	_deal_aoe_damage(active_player.global_position, 140.0, pulse_damage, active_player, "bond_armor_pulse")
	Global.spawn_floating_text(active_player.global_position + Vector2(0, -22), "ARMOR PULSE", Color(0.76, 0.92, 1.0))

func _tick_laser_wall(wall_entry: Dictionary) -> void:
	var start_point: Vector2 = wall_entry.get("start", Vector2.ZERO)
	var end_point: Vector2 = wall_entry.get("end", Vector2.ZERO)
	var damage_value: float = float(wall_entry.get("damage", 0.0))
	var source_player: PlayerBase = wall_entry.get("source", null) as PlayerBase if wall_entry.get("source", null) is PlayerBase else null
	for enemy_node: Node in get_tree().get_nodes_in_group("enemies"):
		if not (enemy_node is Enemy):
			continue
		var enemy: Enemy = enemy_node as Enemy
		if enemy == null or not is_instance_valid(enemy) or enemy.is_dead:
			continue
		var closest_point: Vector2 = Geometry2D.get_closest_point_to_segment(enemy.global_position, start_point, end_point)
		if enemy.global_position.distance_to(closest_point) > 22.0:
			continue
		enemy.apply_modifier_damage(damage_value, source_player, {
			"kind": "bond_dash_laser_wall",
			"damage_type": COMBAT_EVENT_TYPES.DamageType.DIRECT,
		})

func _try_trigger_generic_lifesteal(source_player: PlayerBase, applied_damage: float) -> void:
	if not has_mechanic("lifesteal"):
		return
	if source_player.health_component == null or source_player.health_component.current_health <= 0.0:
		return
	var heal_amount: float = max(1.0, applied_damage * max(0.0, float(get_mechanic_value("lifesteal"))))
	source_player.health_component.heal(heal_amount)

func _try_apply_military_vulnerable(target_enemy: Enemy, source_player: PlayerBase) -> void:
	if not has_mechanic("aoe_apply_vulnerable"):
		return
	target_enemy.apply_vulnerable_modifier(
		"bond_military_vulnerable",
		1.20,
		max(0.1, float(get_mechanic_value("aoe_apply_vulnerable"))),
		"refresh",
		source_player
	)

func _try_trigger_anomaly_reactor(_source_player: PlayerBase, target_enemy: Enemy) -> void:
	if not has_mechanic("anomaly_reactor"):
		return
	if target_enemy.get_abnormal_state_count() <= 0:
		return
	var cooldown_key: String = "anomaly_reactor"
	if float(_damage_hook_cooldowns.get(cooldown_key, 0.0)) > 0.0:
		return
	_damage_hook_cooldowns[cooldown_key] = 0.2
	for player_id: String in Global.selected_player_ids:
		_gain_energy_to_player_id(player_id, max(0.0, float(get_mechanic_value("anomaly_reactor"))))

func _try_trigger_global_damage_share(primary_target: Enemy, applied_damage: float, payload: Dictionary) -> void:
	if not has_mechanic("global_damage_share"):
		return
	var shared_damage: float = applied_damage * max(0.0, float(get_mechanic_value("global_damage_share")))
	if shared_damage <= 0.0:
		return
	for enemy_node: Node in get_tree().get_nodes_in_group("enemies"):
		if not (enemy_node is Enemy):
			continue
		var enemy: Enemy = enemy_node as Enemy
		if enemy == primary_target or enemy == null or not is_instance_valid(enemy) or enemy.is_dead:
			continue
		enemy.apply_modifier_damage(shared_damage, payload.get("source", null), {
			"kind": "bond_global_damage_share",
			"damage_type": payload.get("damage_type", COMBAT_EVENT_TYPES.DamageType.DIRECT),
			"is_shared_damage": true,
		})

func _spread_link_on_enemy_death(origin_enemy: Enemy) -> void:
	var candidates: Array[Enemy] = []
	for enemy_node: Node in get_tree().get_nodes_in_group("enemies"):
		if not (enemy_node is Enemy):
			continue
		var enemy: Enemy = enemy_node as Enemy
		if enemy == origin_enemy or enemy == null or not is_instance_valid(enemy) or enemy.is_dead:
			continue
		if origin_enemy.global_position.distance_to(enemy.global_position) > 300.0:
			continue
		candidates.append(enemy)
	candidates.sort_custom(func(a: Enemy, b: Enemy) -> bool:
		return origin_enemy.global_position.distance_squared_to(a.global_position) < origin_enemy.global_position.distance_squared_to(b.global_position)
	)
	var source_player := _get_front_player()
	for i: int in range(min(2, candidates.size())):
		candidates[i].apply_tag_marker("bond_link_spread", "soul_link", 4.0, "refresh", source_player)

func _payload_counts_as_skill_kill(payload: Dictionary) -> bool:
	var kind_text: String = str(payload.get("kind", payload.get("skill_id", ""))).to_lower()
	for token: String in ["skill", "space", "draw", "ult", "e_", "f_", "parasite", "collapse", "minimalist", "phalanx", "arc", "silk", "joule", "overtone"]:
		if kind_text.contains(token):
			return true
	return payload.has("skill_id")

func _is_elite_or_boss(enemy: Enemy) -> bool:
	return enemy is EnemyElites or enemy.enemy_id == "boss_enemy" or enemy.has_meta("is_boss")

func _gain_energy_to_player_id(player_id: String, amount: float) -> void:
	if player_id.is_empty() or amount <= 0.0:
		return
	var active_player := _get_front_player()
	if active_player != null and active_player.player_id == player_id:
		active_player.gain_energy(amount)
		return
	var state: Dictionary = _get_or_create_player_state(player_id)
	var max_energy: float = float(state.get("max_energy", ConfigManager.get_player_config(player_id).get("max_energy", 100.0)))
	state["energy"] = clamp(float(state.get("energy", max_energy)) + amount, 0.0, max_energy)
	Global.player_states[player_id] = state

func _get_or_create_player_state(player_id: String) -> Dictionary:
	if Global.player_states.has(player_id):
		return (Global.player_states[player_id] as Dictionary).duplicate(true)
	var config: Dictionary = ConfigManager.get_player_config(player_id)
	return {
		"health": float(config.get("health", 100.0)),
		"max_health": float(config.get("health", 100.0)),
		"energy": float(config.get("initial_energy", config.get("max_energy", 100.0))),
		"max_energy": float(config.get("max_energy", 100.0)),
		"armor": int(config.get("max_armor", 0)),
	}

func _on_front_dash_finished(_player_id: String, end_pos: Vector2, direction: Vector2) -> void:
	var active_player := _get_front_player()
	if active_player == null:
		return
	if has_mechanic("dash_wave"):
		_emit_dash_wave(active_player, end_pos, direction)
	if has_mechanic("dash_echo_blast"):
		_spawn_dash_echo_blast(active_player, end_pos)
	if has_mechanic("dash_laser_wall"):
		_spawn_dash_laser_wall(active_player, end_pos, direction)

func _emit_dash_wave(player_node: PlayerBase, end_pos: Vector2, direction: Vector2) -> void:
	var wave_direction: Vector2 = direction.normalized()
	if wave_direction.length_squared() <= 0.0001:
		wave_direction = Vector2.RIGHT
	var start_pos: Vector2 = end_pos
	var target_pos: Vector2 = end_pos + wave_direction * 250.0
	var line := Line2D.new()
	line.top_level = true
	line.width = 16.0
	line.default_color = Color(0.82, 0.95, 1.0, 0.94)
	line.points = PackedVector2Array([start_pos, target_pos])
	get_tree().current_scene.add_child(line)
	var tween := line.create_tween()
	tween.set_parallel(true)
	tween.tween_property(line, "width", 2.0, 0.18)
	tween.tween_property(line, "default_color:a", 0.0, 0.18)
	tween.finished.connect(line.queue_free)
	var damage_value: float = max(1.0, player_node.damage * max(0.0, float(get_mechanic_value("dash_wave"))))
	for enemy_node: Node in get_tree().get_nodes_in_group("enemies"):
		if not (enemy_node is Enemy):
			continue
		var enemy: Enemy = enemy_node as Enemy
		if enemy == null or not is_instance_valid(enemy) or enemy.is_dead:
			continue
		var closest_point: Vector2 = Geometry2D.get_closest_point_to_segment(enemy.global_position, start_pos, target_pos)
		if enemy.global_position.distance_to(closest_point) > 34.0:
			continue
		enemy.apply_modifier_damage(damage_value, player_node, {
			"kind": "bond_dash_wave",
			"damage_type": COMBAT_EVENT_TYPES.DamageType.DIRECT,
		})

func _spawn_dash_echo_blast(player_node: PlayerBase, blast_pos: Vector2) -> void:
	var damage_value: float = max(1.0, player_node.damage * max(0.0, float(get_mechanic_value("dash_echo_blast"))))
	get_tree().create_timer(1.0).timeout.connect(func() -> void:
		_deal_aoe_damage(blast_pos, 96.0, damage_value, player_node, "bond_dash_echo_blast")
		Global.spawn_floating_text(blast_pos, "ECHO", Color(1.0, 0.66, 0.36))
	)

func _spawn_dash_laser_wall(player_node: PlayerBase, end_pos: Vector2, direction: Vector2) -> void:
	var dash_distance: float = 120.0
	if "dash_distance" in player_node:
		dash_distance = float(player_node.get("dash_distance"))
	var dash_payload: Dictionary = {
		"start": player_node.global_position - direction.normalized() * max(1.0, dash_distance),
		"end": end_pos,
		"damage": max(1.0, player_node.damage * 0.6),
		"source": player_node,
		"expires_at": _now_seconds() + 6.0,
		"next_tick_at": 0.0,
	}
	var line := Line2D.new()
	line.top_level = true
	line.width = 8.0
	line.default_color = Color(1.0, 0.24, 0.18, 0.92)
	line.points = PackedVector2Array([dash_payload["start"], dash_payload["end"]])
	get_tree().current_scene.add_child(line)
	dash_payload["line"] = line
	_active_laser_walls.append(dash_payload)

func _try_spawn_static_barrier(release_data: Dictionary) -> void:
	var points_variant: Variant = release_data.get("points", [])
	if not (points_variant is Array):
		return
	var points_array: Array = points_variant
	if points_array.size() < 3:
		return
	var polygon_points: PackedVector2Array = PackedVector2Array()
	for point_variant: Variant in points_array:
		if point_variant is Vector2:
			polygon_points.append(point_variant)
	polygon_points = _normalize_polygon_outline(polygon_points)
	if polygon_points.size() < 3:
		return
	var barrier_duration: float = max(0.5, float(release_data.get("bond_barrier_duration", release_data.get("duration", release_data.get("release_asset_lifetime", 4.0))))) * _get_summoned_lifespan_scale()
	var root := Node2D.new()
	root.top_level = true
	root.add_to_group("player_summoned_entity")
	var body := StaticBody2D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	var collision := CollisionPolygon2D.new()
	collision.build_mode = CollisionPolygon2D.BUILD_SEGMENTS
	collision.polygon = polygon_points
	body.add_child(collision)
	root.add_child(body)
	var outline := Line2D.new()
	outline.top_level = true
	outline.closed = true
	outline.width = 10.0
	outline.default_color = Color(0.54, 0.88, 1.0, 0.80)
	outline.points = polygon_points
	root.add_child(outline)
	get_tree().current_scene.add_child(root)
	_active_static_barriers.append({
		"node": root,
		"expires_at": _now_seconds() + barrier_duration,
	})

func _deal_aoe_damage(center: Vector2, radius: float, damage_value: float, source: Variant, kind: String) -> void:
	for enemy_node: Node in get_tree().get_nodes_in_group("enemies"):
		if not (enemy_node is Enemy):
			continue
		var enemy: Enemy = enemy_node as Enemy
		if enemy == null or not is_instance_valid(enemy) or enemy.is_dead:
			continue
		if enemy.global_position.distance_to(center) > radius:
			continue
		enemy.apply_modifier_damage(damage_value, source, {
			"kind": kind,
			"damage_type": COMBAT_EVENT_TYPES.DamageType.AOE,
		})

func _normalize_polygon_outline(points: PackedVector2Array) -> PackedVector2Array:
	var normalized: PackedVector2Array = points.duplicate()
	if normalized.size() >= 2 and normalized[0].distance_to(normalized[normalized.size() - 1]) <= 0.001:
		normalized.remove_at(normalized.size() - 1)
	return normalized

func _compute_polyline_length(points: PackedVector2Array) -> float:
	var total_length: float = 0.0
	for index: int in range(points.size() - 1):
		total_length += points[index].distance_to(points[index + 1])
	return total_length

func _get_summoned_lifespan_scale() -> float:
	if not has_mechanic("summoned_lifespan_scale"):
		return 1.0
	return max(0.1, float(get_mechanic_value("summoned_lifespan_scale")))

func _try_trigger_knockback_fission(enemy: Enemy, payload: Dictionary, impact_position: Vector2) -> void:
	var cooldown_key: String = "knockback_fission"
	if float(_damage_hook_cooldowns.get(cooldown_key, 0.0)) > 0.0:
		return
	_damage_hook_cooldowns[cooldown_key] = 0.05
	var generation: int = int(payload.get("knockback_generation", 0))
	if generation >= 2:
		return
	var source_player: PlayerBase = _resolve_damage_source_player(payload.get("source", null))
	var source_attack: float = max(1.0, float(payload.get("source_attack", source_player.damage if source_player != null else 1.0)))
	for angle_offset: float in [-0.5, 0.0, 0.5]:
		var direction: Vector2 = Vector2.RIGHT.rotated(randf() * TAU + angle_offset)
		enemy.apply_phalanx_ballistic(direction, 900.0, 180.0, 0.25, source_attack, 1.0, source_player, 12.0, false)
	enemy.set_phalanx_motion_locked(false)
	Global.spawn_floating_text(impact_position + Vector2(0, -22), "FISSION", Color(1.0, 0.6, 0.3))

func _try_trigger_switch_echo(previous_player_id: String, target_player: PlayerBase) -> void:
	var snapshot: Dictionary = Global.get_recent_draw_path(previous_player_id)
	if snapshot.is_empty():
		return
	var points_variant: Variant = snapshot.get("points", [])
	if not (points_variant is Array):
		return
	var raw_points: Array = points_variant
	if raw_points.size() < 2:
		return
	var translated_points: Array[Vector2] = []
	var first_point: Vector2 = raw_points[0]
	for point_variant: Variant in raw_points:
		if point_variant is Vector2:
			translated_points.append((point_variant as Vector2) - first_point + target_player.global_position)
	if translated_points.size() < 2:
		return
	var closed_shape: bool = bool(snapshot.get("closed", false))
	if closed_shape and translated_points.size() >= 3:
		var polygon: PackedVector2Array = PackedVector2Array(translated_points)
		for enemy_node: Node in get_tree().get_nodes_in_group("enemies"):
			if not (enemy_node is Enemy):
				continue
			var enemy: Enemy = enemy_node as Enemy
			if enemy == null or not is_instance_valid(enemy) or enemy.is_dead:
				continue
			if Geometry2D.is_point_in_polygon(enemy.global_position, polygon):
				enemy.apply_modifier_damage(max(1.0, target_player.damage), target_player, {
					"kind": "bond_switch_echo",
					"damage_type": COMBAT_EVENT_TYPES.DamageType.AOE,
				})
	else:
		for i: int in range(1, translated_points.size()):
			var start_pos: Vector2 = translated_points[i - 1]
			var end_pos: Vector2 = translated_points[i]
			for enemy_node: Node in get_tree().get_nodes_in_group("enemies"):
				if not (enemy_node is Enemy):
					continue
				var enemy: Enemy = enemy_node as Enemy
				if enemy == null or not is_instance_valid(enemy) or enemy.is_dead:
					continue
				var closest_point: Vector2 = Geometry2D.get_closest_point_to_segment(enemy.global_position, start_pos, end_pos)
				if enemy.global_position.distance_to(closest_point) > 30.0:
					continue
				enemy.apply_modifier_damage(max(1.0, target_player.damage), target_player, {
					"kind": "bond_switch_echo",
					"damage_type": COMBAT_EVENT_TYPES.DamageType.DIRECT,
				})
	Global.spawn_floating_text(target_player.global_position + Vector2(0, -24), "ECHO", Color(0.86, 0.96, 1.0))

func _now_seconds() -> float:
	return float(Time.get_ticks_msec()) / 1000.0


func apply_stat_modifiers(player_stats: Dictionary) -> Dictionary:
	# 先叠加 stat_mod，再处理 mechanic（如 stat_share）等二次计算效果。
	var modified_stats = player_stats.duplicate(true)
	
	for bond_id in active_bonds.keys():
		var bond_data = active_bonds[bond_id]
		
		for effect in bond_data.effects:
			if effect.effect_type == "stat_mod":
				_apply_stat_modifier(modified_stats, effect.effect_param, effect.effect_value)
	
	if has_mechanic("stat_share"):
		_apply_stat_share(modified_stats)
	
	return modified_stats

func _apply_stat_share(stats: Dictionary) -> void:
	# 将替补角色的基础属性按比例共享给当前出战角色。
	var share_ratio = get_mechanic_value("stat_share")
	if share_ratio <= 0:
		return
	
	var bench_characters = _get_bench_characters()
	if bench_characters.is_empty():
		return
	
	if DEBUG_VERBOSE: print("[BondManager] [P4-3] stat_share triggered, share_ratio: %.0f%%" % (share_ratio * 100))
	
	var total_bonus_damage = 0.0
	var total_bonus_health = 0.0
	var total_bonus_speed = 0.0
	
	for char_id in bench_characters:
		var char_config = ConfigManager.get_player_config(char_id)
		if char_config.is_empty():
			continue
		
		var base_damage = float(char_config.get("damage", 0))
		var base_health = float(char_config.get("health", 0))
		var base_speed = float(char_config.get("base_speed", 0))
		

		total_bonus_damage += base_damage * share_ratio
		total_bonus_health += base_health * share_ratio
		total_bonus_speed += base_speed * share_ratio
		
		if DEBUG_VERBOSE: print("[BondManager] [P4-3] bench %s shared: damage %.0f, health %.0f, speed %.0f" % [
			char_id,
			base_damage * share_ratio,
			base_health * share_ratio,
			base_speed * share_ratio
		])
	
	if total_bonus_damage > 0:
		stats["damage"] = stats.get("damage", 0) + total_bonus_damage
		if DEBUG_VERBOSE: print("[BondManager] [P4-3] total shared damage bonus: +%.0f" % total_bonus_damage)
	
	if total_bonus_health > 0:
		stats["max_health"] = stats.get("max_health", 100) + total_bonus_health
		if DEBUG_VERBOSE: print("[BondManager] [P4-3] total shared health bonus: +%.0f" % total_bonus_health)
	
	if total_bonus_speed > 0:
		stats["speed"] = stats.get("speed", 100) + total_bonus_speed
		if DEBUG_VERBOSE: print("[BondManager] [P4-3] total shared speed bonus: +%.0f" % total_bonus_speed)

func _get_bench_characters() -> Array[String]:
	var bench: Array[String] = []
	
	var current_player_id = Global.get_current_player_id()
	
	for player_id in Global.selected_player_ids:
		if player_id != current_player_id:
			var state = Global.get_player_state(player_id)
			var health = state.get("health", 0)
			if health > 0:
				bench.append(player_id)
	
	return bench

func _apply_stat_modifier(stats: Dictionary, param: String, value: float) -> void:
	var is_percentage = param.ends_with("_pct")
	var base_param = param.trim_suffix("_pct") if is_percentage else param
	
	if is_percentage:
		match base_param:
			"energy_regen":
				var base_value = stats.get("energy_regen", 0)
				stats["energy_regen"] = base_value * (1.0 + value)
			"max_health":
				var base_value = stats.get("max_health", 100)
				stats["max_health"] = base_value * (1.0 + value)
			"movement_speed", "speed":
				var base_value = stats.get("speed", 100)
				stats["speed"] = base_value * (1.0 + value)
			"pickup_range":
				var base_value = stats.get("pickup_range", 100)
				stats["pickup_range"] = base_value * (1.0 + value)
			_:
				if stats.has(base_param):
					stats[base_param] = stats[base_param] * (1.0 + value)
				else:
					pass
		return
	
	match param:
		"crit_chance":
			stats["crit_chance"] = stats.get("crit_chance", 0) + value
		"crit_damage":
			stats["crit_damage"] = stats.get("crit_damage", 1.0) + value
		"energy_regen":
			stats["energy_regen"] = stats.get("energy_regen", 0) + value
		"max_energy":
			stats["max_energy"] = stats.get("max_energy", 0) + value
		"cooldown_reduction":
			stats["cooldown_reduction"] = stats.get("cooldown_reduction", 0) + value
		"max_health":
			stats["max_health"] = stats.get("max_health", 100) + value
		"max_armor":
			stats["max_armor"] = stats.get("max_armor", 0) + value
		"speed":
			stats["speed"] = stats.get("speed", 100) + value
		"armor":
			stats["armor"] = stats.get("armor", 0) + value
		"stat_share", "stat_share_ratio":
			stats["stat_share_ratio"] = stats.get("stat_share_ratio", 0) + value
		"gold_gain":
			stats["gold_gain"] = stats.get("gold_gain", 1.0) + value
		"exp_gain":
			stats["exp_gain"] = stats.get("exp_gain", 1.0) + value
		"dodge_chance":
			stats["dodge_chance"] = stats.get("dodge_chance", 0) + value
		"health_regen":
			stats["health_regen"] = stats.get("health_regen", 0) + value
		"projectile_speed":
			stats["projectile_speed"] = stats.get("projectile_speed", 1.0) + value
		"heal_power":
			stats["heal_power"] = stats.get("heal_power", 1.0) + value
		"damage_taken_reduction":
			stats["damage_taken_reduction"] = stats.get("damage_taken_reduction", 0) + value
		"pickup_range":
			stats["pickup_range"] = stats.get("pickup_range", 100) + value
		_:
			if stats.has(param):
				stats[param] = stats[param] + value
			else:
				stats[param] = value

func get_active_mechanics() -> Array:
	var mechanics = []
	
	for bond_id in active_bonds.keys():
		var bond_data = active_bonds[bond_id]
		
		for effect in bond_data.effects:
			if effect.effect_type == "mechanic":
				mechanics.append({
					"bond_id": bond_id,
					"effect_param": effect.effect_param,
					"effect_value": effect.effect_value,
					"description": effect.description,
					"level": effect.level
				})
	
	return mechanics

func has_mechanic(mechanic_name: String) -> bool:
	for bond_id in active_bonds.keys():
		var bond_data = active_bonds[bond_id]
		
		for effect in bond_data.effects:
			if effect.effect_type == "mechanic" and effect.effect_param == mechanic_name:
				return true
	
	return false

func get_mechanic_value(mechanic_name: String) -> float:
	# 同名机制取“最高等级”的值，避免多羁绊叠加导致数值失控。
	var found := false
	var selected_level := -1
	var selected_value := 0.0

	for bond_id in active_bonds.keys():
		var bond_data = active_bonds[bond_id]
		for effect in bond_data.effects:
			if effect.effect_type != "mechanic" or effect.effect_param != mechanic_name:
				continue
			var level = int(effect.get("level", 0))
			if not found or level >= selected_level:
				found = true
				selected_level = level
				selected_value = float(effect.get("effect_value", 0.0))

	return selected_value if found else 0.0


func add_temp_tag(tag: String) -> void:
	if tag.is_empty():
		return

	temp_bonus_tags[tag] = temp_bonus_tags.get(tag, 0) + 1
	if DEBUG_VERBOSE: print("[BondManager] add temp tag: %s (%d)" % [tag, temp_bonus_tags[tag]])
	_recalculate_with_current_team()

func remove_temp_tag(tag: String) -> void:
	if tag.is_empty() or not temp_bonus_tags.has(tag):
		return

	temp_bonus_tags[tag] -= 1
	if temp_bonus_tags[tag] <= 0:
		temp_bonus_tags.erase(tag)

	if DEBUG_VERBOSE: print("[BondManager] remove temp tag: %s (%d)" % [tag, temp_bonus_tags.get(tag, 0)])
	_recalculate_with_current_team()

func get_temp_tags() -> Dictionary:
	return temp_bonus_tags.duplicate()

func clear_temp_tags() -> void:
	temp_bonus_tags.clear()
	_recalculate_with_current_team()

func _recalculate_with_current_team() -> void:
	var team_ids: Array = []
	if not Global.selected_player_ids.is_empty():
		team_ids = Global.selected_player_ids.duplicate()
	elif not _last_team_player_ids.is_empty():
		team_ids = _last_team_player_ids.duplicate()

	if team_ids.is_empty():
		stat_modifiers_changed.emit()
		return

	recalculate_active_bonds(team_ids)

func set_overdrive_mode(enabled: bool) -> void:
	if is_overdrive_mode == enabled:
		return

	is_overdrive_mode = enabled
	if DEBUG_VERBOSE: print("[BondManager] overdrive mode: %s" % ("on" if enabled else "off"))
	_recalculate_with_current_team()

func is_in_overdrive_mode() -> bool:
	return is_overdrive_mode

func get_bond_summary() -> Array:
	var summary: Array = []
	for bond_id in active_bonds.keys():
		var bond_data = active_bonds[bond_id]
		summary.append({
			"bond_id": bond_id,
			"level": bond_data.level,
			"count": current_bond_counts.get(bond_id, 0)
		})
	return summary

func restore_from_save(bond_counts_data: Dictionary) -> void:
	if DEBUG_VERBOSE: print("[BondManager] restore from save: %s" % str(bond_counts_data))
	current_bond_counts = bond_counts_data.duplicate(true)

	active_bonds.clear()
	for bond_id in current_bond_counts.keys():
		var count = current_bond_counts[bond_id]
		var activated_level = _get_activated_level(bond_id, count)
		if activated_level > 0:
			_activate_bond(bond_id, activated_level)

	if DEBUG_VERBOSE: print("[BondManager] restore complete: active=%d" % active_bonds.size())
	bonds_recalculated.emit(active_bonds)
	stat_modifiers_changed.emit()

func print_active_bonds() -> void:
	if DEBUG_VERBOSE: print("\n========== Active Bonds ==========")
	for bond_id in active_bonds.keys():
		var bond_data = active_bonds[bond_id]
		if DEBUG_VERBOSE: print("[%s] Lv.%d - %s" % [bond_data.display_name, bond_data.level, bond_id])
		for effect in bond_data.effects:
			if DEBUG_VERBOSE: print("  - Lv.%d %s: %s = %.2f (%s)" % [
				effect.level,
				effect.effect_type,
				effect.effect_param,
				effect.effect_value,
				effect.description
			])
	if DEBUG_VERBOSE: print("================================\n")
