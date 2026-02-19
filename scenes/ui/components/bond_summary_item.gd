extends HBoxContainer
class_name BondSummaryItem

# ============================================================================
# 羁绊统计条目 - 显示单个羁绊的激活状态
# ============================================================================

# 节点引用
@onready var icon: TextureRect = $Icon
@onready var name_label: Label = $NameLabel
@onready var count_label: Label = $CountLabel

# 数据
var bond_id: String = ""
var bond_type: String = ""
var current_count: int = 0
var max_count: int = 2

# 颜色配置
const COLOR_ACTIVE = Color(0.3, 0.9, 0.4)      # 绿色 - 已激活
const COLOR_PARTIAL = Color(0.9, 0.75, 0.2)    # 金色 - 部分激活
const COLOR_INACTIVE = Color(0.5, 0.5, 0.5)    # 灰色 - 未激活

# ============================================================================
# 初始化
# ============================================================================

func _ready() -> void:
	pass

# ============================================================================
# 公共接口
# ============================================================================

func update_info(p_bond_id: String, p_bond_type: String, p_current_count: int, p_max_count: int) -> void:
	"""更新羁绊信息
	
	Args:
		p_bond_id: 羁绊ID（如 "martial"）
		p_bond_type: 羁绊类型（"origin", "mastery", "tactic"）
		p_current_count: 当前数量
		p_max_count: 最大阈值
	"""
	bond_id = p_bond_id
	bond_type = p_bond_type
	current_count = p_current_count
	max_count = p_max_count
	
	# 更新图标
	_update_icon()
	
	# 更新名称（使用显示名称而非ID）
	_update_name()
	
	# 更新计数
	_update_count()
	
	# 更新颜色
	_update_colors()
	
	# 更新悬浮提示
	_update_tooltip()

# ============================================================================
# 内部更新函数
# ============================================================================

func _update_icon() -> void:
	"""更新羁绊图标"""
	if not icon:
		return
	
	var texture = BondUILoader.get_bond_icon(bond_id, bond_type)
	if texture:
		icon.texture = texture
		icon.modulate = Color.WHITE
	else:
		icon.texture = null
		icon.modulate = Color(0.3, 0.3, 0.3, 0.5)

func _update_name() -> void:
	"""更新羁绊名称（使用显示名称）"""
	if not name_label:
		return
	
	# 从 BondManager 获取显示名称
	var display_name = BondManager.get_bond_display_name(bond_id)
	name_label.text = display_name

func _update_count() -> void:
	"""更新计数显示（使用统一格式化逻辑）"""
	if not count_label:
		return
	
	count_label.text = BondManager.get_bond_status_text(bond_id, current_count)

func _update_colors() -> void:
	"""更新颜色状态"""
	var color: Color
	
	if current_count >= max_count:
		# 已激活 - 绿色
		color = COLOR_ACTIVE
	elif current_count > 0:
		# 部分激活 - 金色
		color = COLOR_PARTIAL
	else:
		# 未激活 - 灰色
		color = COLOR_INACTIVE
	
	# 应用颜色到标签
	if name_label:
		name_label.add_theme_color_override("font_color", color)
	if count_label:
		count_label.add_theme_color_override("font_color", color)
	
	# 图标也应用颜色调制
	if icon and icon.texture:
		if current_count >= max_count:
			icon.modulate = Color.WHITE
		elif current_count > 0:
			icon.modulate = Color(1.0, 1.0, 0.8)
		else:
			icon.modulate = Color(0.6, 0.6, 0.6)

func _update_tooltip() -> void:
	"""更新悬浮提示"""
	# 从 BondManager 获取格式化的提示文本
	var tooltip = BondManager.get_bond_tooltip_text(bond_id, current_count)
	
	# 设置到根节点
	tooltip_text = tooltip
	
	# 确保鼠标过滤器允许悬浮事件
	mouse_filter = Control.MOUSE_FILTER_STOP
