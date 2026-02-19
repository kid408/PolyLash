extends PanelContainer
# ============================================================================
# 图鉴详情面板 - 显示角色/圣物/怪物的详细信息
# ============================================================================

# Tier 颜色
const TIER_COLORS := {
	1: Color.WHITE,
	2: Color("#4488FF"),
	3: Color("#AA44FF"),
}

# 节点引用
@onready var close_button: Button = $MarginContainer/VBoxContainer/TopBar/CloseButton
@onready var portrait: TextureRect = $MarginContainer/VBoxContainer/Portrait
@onready var name_label: Label = $MarginContainer/VBoxContainer/NameLabel
@onready var tags_label: Label = $MarginContainer/VBoxContainer/TagsLabel
@onready var separator: HSeparator = $MarginContainer/VBoxContainer/Separator
@onready var stats_label: Label = $MarginContainer/VBoxContainer/StatsLabel
@onready var desc_label: Label = $MarginContainer/VBoxContainer/DescLabel

func _ready() -> void:
	close_button.pressed.connect(hide_panel)
	visible = false

# ============================================================================
# 角色详情
# ============================================================================

func show_character_detail(id: String) -> void:
	var config: Dictionary = ConfigManager.player_configs.get(id, {})
	var visual: Dictionary = ConfigManager.player_visual_configs.get(id, {})
	if config.is_empty():
		return

	# 头像
	var sprite_path: String = visual.get("sprite_path", "")
	if sprite_path != "" and ResourceLoader.exists(sprite_path):
		portrait.texture = load(sprite_path)
	else:
		portrait.texture = null
	portrait.modulate = Color.WHITE
	portrait.visible = true

	# 名称
	name_label.text = config.get("display_name", id)
	name_label.add_theme_color_override("font_color", Color.WHITE)

	# 羁绊标签
	var ties_str: String = config.get("ties", "")
	if ties_str != "":
		tags_label.text = ties_str.replace("|", "  •  ")
		tags_label.visible = true
	else:
		tags_label.visible = false

	# 基础属性
	var hp: String = str(config.get("health", "?"))
	var armor: String = str(config.get("max_armor", "?"))
	var spd: String = str(config.get("base_speed", "?"))
	var energy: String = str(config.get("max_energy", "?"))
	stats_label.text = "生命值: %s    护甲: %s\n速度: %s    能量: %s" % [hp, armor, spd, energy]
	stats_label.visible = true

	# 技能描述
	var desc: String = config.get("description", "")
	if desc != "":
		desc_label.text = desc
		desc_label.visible = true
	else:
		desc_label.visible = false

	separator.visible = true
	_show()

# ============================================================================
# 圣物详情
# ============================================================================

func show_relic_detail(id: String) -> void:
	var config: Dictionary = ConfigManager.item_configs_new.get(id, {})
	if config.is_empty():
		return

	# 图标
	var icon_path: String = config.get("icon_path", "")
	if icon_path != "" and ResourceLoader.exists(icon_path):
		portrait.texture = load(icon_path)
	else:
		portrait.texture = null
	portrait.modulate = Color.WHITE
	portrait.visible = true

	# 名称 + Tier 颜色
	var tier: int = int(config.get("tier", 1))
	var tier_color: Color = TIER_COLORS.get(tier, Color.WHITE)
	name_label.text = "%s  (Tier %d)" % [config.get("name", id), tier]
	name_label.add_theme_color_override("font_color", tier_color)

	# 标签隐藏
	tags_label.visible = false

	# 修正属性
	var modifiers: Array = config.get("modifiers", [])
	var base_stat: String = config.get("base_stat", "")
	var base_value: String = str(config.get("base_value", ""))
	var stats_text := ""
	if base_stat != "" and base_value != "" and base_value != "0":
		stats_text = "基础属性: %s +%s" % [base_stat, base_value]
	if modifiers.size() > 0:
		for mod in modifiers:
			var mod_name: String = mod.get("type", "")
			var mod_val = mod.get("value", 0)
			if stats_text != "":
				stats_text += "\n"
			stats_text += "修正: %s %s" % [mod_name, str(mod_val)]
	if stats_text != "":
		stats_label.text = stats_text
		stats_label.visible = true
	else:
		stats_label.visible = false

	# 效果描述
	var desc: String = config.get("description", "")
	if desc != "":
		desc_label.text = desc
		desc_label.visible = true
	else:
		desc_label.visible = false

	separator.visible = true
	_show()

# ============================================================================
# 怪物详情
# ============================================================================

func show_monster_detail(id: String) -> void:
	var config: Dictionary = ConfigManager.enemy_configs.get(id, {})
	var visual: Dictionary = ConfigManager.enemy_visual_configs.get(id, {})
	if config.is_empty():
		return

	# 头像
	var sprite_path: String = visual.get("sprite_path", "")
	if sprite_path != "" and ResourceLoader.exists(sprite_path):
		portrait.texture = load(sprite_path)
	else:
		portrait.texture = null
	portrait.modulate = Color.WHITE
	portrait.visible = true

	# 名称
	name_label.text = config.get("display_name", id)
	name_label.add_theme_color_override("font_color", Color.WHITE)

	# 标签隐藏
	tags_label.visible = false

	# 基础属性
	var hp: String = str(config.get("health", "?"))
	var atk: String = str(config.get("damage", "?"))
	var spd: String = str(config.get("speed", "?"))
	stats_label.text = "生命值: %s    攻击力: %s\n移动速度: %s" % [hp, atk, spd]
	stats_label.visible = true

	# 描述（敌人配置中无 description 字段，留空）
	desc_label.visible = false

	separator.visible = true
	_show()

# ============================================================================
# 显示/隐藏
# ============================================================================

func hide_panel() -> void:
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.15)
	tween.tween_callback(func(): visible = false)

func _show() -> void:
	modulate.a = 0.0
	visible = true
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 1.0, 0.15)
