extends Node

# ============================================================================
# Bond UI Loader
# 负责读取羁绊配置，并为 HUD/选择界面提供图标与文本数据。
# 缺失配置时会自动降级为占位配置，避免界面层反复刷错。
# ============================================================================

var bond_configs: Dictionary = {}
var _warned_missing_bonds: Dictionary = {}
var _warned_type_mismatches: Dictionary = {}

const ICON_PATH_TEMPLATES := {
	"origin": "res://assets/sprites/Icons/origins/origin%d.png",
	"mastery": "res://assets/sprites/Icons/masterys/mastery%d.png",
	"tactic": "res://assets/sprites/Icons/tactics/tactic%d.png",
}

const FALLBACK_DISPLAY_NAMES := {
	"inkborn": "墨裔",
	"colossus": "巨像",
	"nomad": "流浪",
	"alchemist": "炼金",
	"blaster": "爆破",
	"architect": "构筑",
	"hexer": "咒术",
	"geometrist": "几何",
	"assist": "辅助",
	"commander": "指挥",
}

func _ready() -> void:
	_load_bond_configs()
	print("[BondUILoader] 初始化完成，加载了 %d 个羁绊配置" % bond_configs.size())

func _load_bond_configs() -> void:
	bond_configs.clear()
	_warned_missing_bonds.clear()
	_warned_type_mismatches.clear()

	var loaded: Dictionary = ConfigRepository.load_bond_configs()
	for bond_id_variant in loaded.keys():
		var bond_id: String = str(bond_id_variant).strip_edges()
		if bond_id.is_empty():
			continue
		var cfg: Dictionary = loaded[bond_id_variant]
		var levels: Variant = cfg.get("levels", [])
		var description: String = ""
		if levels is Array and not levels.is_empty():
			description = str(levels[0].get("description", ""))
		bond_configs[bond_id] = {
			"bond_type": str(cfg.get("bond_type", "")).strip_edges(),
			"icon_path_index": int(cfg.get("icon_path_index", 1)),
			"display_name": str(cfg.get("display_name", bond_id)),
			"description": description,
		}

func _get_or_create_bond_config(bond_tag: String, requested_bond_type: String = "") -> Dictionary:
	var normalized_tag: String = bond_tag.strip_edges()
	if normalized_tag.is_empty():
		return {}

	if bond_configs.has(normalized_tag):
		var config: Dictionary = bond_configs[normalized_tag]
		var config_type: String = str(config.get("bond_type", "")).strip_edges()
		if not requested_bond_type.is_empty() and not config_type.is_empty() and config_type != requested_bond_type:
			var warn_key: String = "%s|%s|%s" % [normalized_tag, config_type, requested_bond_type]
			if not _warned_type_mismatches.has(warn_key):
				push_warning("[BondUILoader] 羁绊类型不匹配，自动回退: %s (%s -> %s)" % [
					normalized_tag,
					config_type,
					requested_bond_type
				])
				_warned_type_mismatches[warn_key] = true
			var patched: Dictionary = config.duplicate(true)
			patched["bond_type"] = requested_bond_type
			return patched
		return config

	if not _warned_missing_bonds.has(normalized_tag):
		push_warning("[BondUILoader] 缺少羁绊配置，使用占位回退: %s" % normalized_tag)
		_warned_missing_bonds[normalized_tag] = true

	var fallback: Dictionary = _build_fallback_bond_config(normalized_tag, requested_bond_type)
	bond_configs[normalized_tag] = fallback
	return fallback

func _build_fallback_bond_config(bond_tag: String, requested_bond_type: String = "") -> Dictionary:
	var resolved_type: String = requested_bond_type if not requested_bond_type.is_empty() else "origin"
	return {
		"bond_type": resolved_type,
		"icon_path_index": 1,
		"display_name": str(FALLBACK_DISPLAY_NAMES.get(bond_tag, _prettify_bond_tag(bond_tag))),
		"description": "占位羁绊配置，当前未提供额外效果",
	}

func _prettify_bond_tag(bond_tag: String) -> String:
	return bond_tag.replace("_", " ").capitalize()

func get_bond_icon(bond_tag: String, bond_type: String) -> Texture2D:
	var config: Dictionary = _get_or_create_bond_config(bond_tag, bond_type)
	if config.is_empty():
		return null

	var resolved_type: String = str(config.get("bond_type", bond_type)).strip_edges()
	var icon_path_template: String = str(ICON_PATH_TEMPLATES.get(resolved_type, ""))
	if icon_path_template.is_empty():
		push_warning("[BondUILoader] 未知羁绊类型，使用 origin 图标回退: %s" % resolved_type)
		resolved_type = "origin"
		icon_path_template = str(ICON_PATH_TEMPLATES.get(resolved_type, ""))
		if icon_path_template.is_empty():
			return null

	var icon_index: int = max(1, int(config.get("icon_path_index", 1)))
	var icon_path: String = icon_path_template % icon_index
	if FileAccess.file_exists(icon_path):
		var texture: Texture2D = load(icon_path) as Texture2D
		if texture != null:
			return texture
		push_warning("[BondUILoader] 无法加载羁绊图标: %s" % icon_path)

	var fallback_path: String = icon_path_template % 1
	if FileAccess.file_exists(fallback_path):
		var fallback_texture: Texture2D = load(fallback_path) as Texture2D
		if fallback_texture != null:
			return fallback_texture
	return null

func get_bond_display_name(bond_tag: String) -> String:
	var config: Dictionary = _get_or_create_bond_config(bond_tag)
	if config.is_empty():
		return bond_tag
	return str(config.get("display_name", bond_tag))

func get_bond_description(bond_tag: String) -> String:
	var config: Dictionary = _get_or_create_bond_config(bond_tag)
	if config.is_empty():
		return ""
	return str(config.get("description", ""))

func get_bond_config(bond_tag: String) -> Dictionary:
	return _get_or_create_bond_config(bond_tag)

func create_bond_icon_container(
	origin_tag: String,
	mastery_tag: String,
	tactic_tag: String,
	icon_size: int = 24,
	team_player_ids: Array = []
) -> HBoxContainer:
	var container: HBoxContainer = HBoxContainer.new()
	container.name = "BondIconsContainer"
	container.add_theme_constant_override("separation", 4)

	var bond_counts: Dictionary = {}
	if not team_player_ids.is_empty():
		var bond_stats: Dictionary = calculate_team_bonds(team_player_ids)
		for bond_id_variant in bond_stats.get("bonds", {}).keys():
			var entry: Dictionary = bond_stats["bonds"][bond_id_variant]
			bond_counts[str(bond_id_variant)] = int(entry.get("count", 0))

	var bonds: Array[Dictionary] = [
		{"tag": origin_tag, "type": "origin"},
		{"tag": mastery_tag, "type": "mastery"},
		{"tag": tactic_tag, "type": "tactic"},
	]

	for bond: Dictionary in bonds:
		var bond_tag: String = str(bond.get("tag", "")).strip_edges()
		var bond_type: String = str(bond.get("type", "")).strip_edges()
		var icon_rect: TextureRect = TextureRect.new()
		icon_rect.custom_minimum_size = Vector2(icon_size, icon_size)
		icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED

		var texture: Texture2D = get_bond_icon(bond_tag, bond_type)
		if texture != null:
			icon_rect.texture = texture
			var current_count: int = int(bond_counts.get(bond_tag, 0))
			if current_count > 0:
				icon_rect.tooltip_text = BondManager.get_bond_tooltip_text(bond_tag, current_count)
			else:
				icon_rect.tooltip_text = BondManager.get_bond_display_name(bond_tag)
		else:
			icon_rect.modulate = Color(0.3, 0.3, 0.3, 0.5)
		container.add_child(icon_rect)

	return container

func update_bond_icons(
	container: HBoxContainer,
	origin_tag: String,
	mastery_tag: String,
	tactic_tag: String,
	team_player_ids: Array = []
) -> void:
	if container == null:
		push_warning("[BondUILoader] 无效的羁绊图标容器")
		return

	for child: Node in container.get_children():
		child.queue_free()

	var rebuilt: HBoxContainer = create_bond_icon_container(
		origin_tag,
		mastery_tag,
		tactic_tag,
		24,
		team_player_ids
	)
	for child: Node in rebuilt.get_children():
		rebuilt.remove_child(child)
		container.add_child(child)
	rebuilt.queue_free()

func calculate_team_bonds(selected_player_ids: Array) -> Dictionary:
	var result: Dictionary = {"bonds": {}}

	for player_id_variant in selected_player_ids:
		var player_id: String = str(player_id_variant).strip_edges()
		if player_id.is_empty():
			continue
		var config: Dictionary = ConfigManager.get_player_config(player_id)
		if config.is_empty():
			continue

		var tags: Array[Dictionary] = [
			{"tag": str(config.get("origin_tag", "")).strip_edges(), "type": "origin"},
			{"tag": str(config.get("mastery_tag", "")).strip_edges(), "type": "mastery"},
			{"tag": str(config.get("tactic_tag", "")).strip_edges(), "type": "tactic"},
		]

		for tag_info: Dictionary in tags:
			var tag: String = str(tag_info.get("tag", "")).strip_edges()
			var bond_type: String = str(tag_info.get("type", "")).strip_edges()
			if tag.is_empty():
				continue
			if not result["bonds"].has(tag):
				result["bonds"][tag] = {
					"count": 0,
					"type": bond_type,
				}
			result["bonds"][tag]["count"] = int(result["bonds"][tag].get("count", 0)) + 1

		var item_data: Dictionary = EquipmentManager.get_equipped_item_data(player_id)
		if item_data.is_empty():
			continue
		var bond_grant: String = str(item_data.get("bond_grant", "")).strip_edges()
		if bond_grant.is_empty():
			continue
		for raw_tag: String in bond_grant.split("|"):
			var tag: String = raw_tag.strip_edges()
			if tag.is_empty():
				continue
			var tag_config: Dictionary = _get_or_create_bond_config(tag)
			var tag_type: String = str(tag_config.get("bond_type", "tactic")).strip_edges()
			if not result["bonds"].has(tag):
				result["bonds"][tag] = {
					"count": 0,
					"type": tag_type,
				}
			result["bonds"][tag]["count"] = int(result["bonds"][tag].get("count", 0)) + 1

	return result

func get_sorted_bonds(bond_stats: Dictionary) -> Array:
	var bonds_array: Array = []
	var bonds: Dictionary = bond_stats.get("bonds", {})
	for bond_id_variant in bonds.keys():
		var bond_id: String = str(bond_id_variant)
		var bond_data: Dictionary = bonds[bond_id_variant]
		var bond_type: String = str(bond_data.get("type", ""))
		var count: int = int(bond_data.get("count", 0))
		var max_level: int = BondManager.get_bond_max_level(bond_id)
		var max_count: int = 0
		if max_level > 0:
			max_count = BondManager.get_bond_required_count(bond_id, max_level)
		bonds_array.append({
			"bond_id": bond_id,
			"count": count,
			"type": bond_type,
			"max": max_count,
			"max_level": max_level,
		})

	bonds_array.sort_custom(func(a: Dictionary, b: Dictionary): return int(a.get("count", 0)) > int(b.get("count", 0)))
	return bonds_array
