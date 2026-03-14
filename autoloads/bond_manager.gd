extends Node

const DEBUG_VERBOSE := false

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

# 狂暴模式：开启后，任意羁绊可直接按最高级结算
var is_overdrive_mode: bool = false

# 兜底队伍缓存，防止实时队伍尚未就绪时无法重算
var _last_team_player_ids: Array = []


func _ready() -> void:
	_load_bond_configs()
	_connect_runtime_sources()
	if DEBUG_VERBOSE: print("[BondManager] init done, loaded %d bond configs" % bond_configs.size())



func _connect_runtime_sources() -> void:
	if EmblemManager == null:
		call_deferred("_connect_runtime_sources")
		return

	if not EmblemManager.emblem_added.is_connected(_on_emblem_inventory_changed):
		EmblemManager.emblem_added.connect(_on_emblem_inventory_changed)
	if not EmblemManager.emblem_removed.is_connected(_on_emblem_inventory_changed):
		EmblemManager.emblem_removed.connect(_on_emblem_inventory_changed)

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
		"cooldown_reduction":
			stats["cooldown_reduction"] = stats.get("cooldown_reduction", 0) + value
		"max_health":
			stats["max_health"] = stats.get("max_health", 100) + value
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
