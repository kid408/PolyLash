extends PanelContainer
class_name BondIcon

# ============================================================================
# 羁绊图标 - 单个羁绊的显示组件（纯图标版本）
# ============================================================================

# 节点引用
@onready var texture_rect: TextureRect = %IconTexture
@onready var level_label: Label = %LevelLabel
@onready var border: Panel = %BorderPanel

# 羁绊数据
var bond_id: String = ""
var bond_name: String = ""
var bond_type: String = ""
var bond_level: int = 0
var current_count: int = 0
var required_count: int = 0
var effect_description: String = ""
var is_active: bool = false

# ============================================================================
# 设置
# ============================================================================

func setup(
	p_bond_id: String,
	p_bond_name: String,
	p_bond_type: String,
	p_level: int,
	p_current_count: int,
	p_required_count: int,
	p_icon_path: String,
	p_effect_description: String,
	p_is_active: bool
) -> void:
	"""设置羁绊图标数据"""
	bond_id = p_bond_id
	bond_name = p_bond_name
	bond_type = p_bond_type
	bond_level = p_level
	current_count = p_current_count
	required_count = p_required_count
	effect_description = p_effect_description
	is_active = p_is_active
	
	# 加载图标
	if FileAccess.file_exists(p_icon_path):
		var texture = load(p_icon_path) as Texture2D
		if texture and texture_rect:
			texture_rect.texture = texture
	else:
		printerr("[BondIcon] 图标文件不存在: %s" % p_icon_path)
	
	# 设置等级标签（只在激活时显示）
	if level_label:
		if is_active and bond_level > 0:
			level_label.text = "Lv.%d" % bond_level
			level_label.visible = true
		else:
			level_label.visible = false
	
	# 设置 Tooltip（鼠标悬停时显示）
	_setup_tooltip()

func set_border_color(color: Color) -> void:
	"""设置边框颜色"""
	if border:
		# 使用 StyleBox 设置边框颜色
		var style = border.get_theme_stylebox("panel")
		if style is StyleBoxFlat:
			var style_copy = style.duplicate() as StyleBoxFlat
			style_copy.border_color = color
			border.add_theme_stylebox_override("panel", style_copy)

# ============================================================================
# Tooltip
# ============================================================================

func _setup_tooltip() -> void:
	"""设置 Tooltip（简化版本）"""
	var tooltip_text = "%s" % bond_name
	
	if is_active:
		tooltip_text += " - Lv.%d" % bond_level
		if effect_description != "":
			tooltip_text += "\n%s" % effect_description
	else:
		if required_count > 0:
			tooltip_text += " (%d/%d)" % [current_count, required_count]
	
	# 在 Godot 4.x 中，直接设置 tooltip_text 属性
	set_tooltip_text(tooltip_text)
	mouse_filter = Control.MOUSE_FILTER_PASS
