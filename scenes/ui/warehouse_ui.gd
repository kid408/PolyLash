extends Panel
class_name WarehouseUI

# ============================================================================
# 仓库UI - 显示和管理玩家的道具仓库
# ============================================================================

# ============================================================================
# 节点引用
# ============================================================================

@onready var grid_container: GridContainer = $MarginContainer/VBoxContainer/ScrollContainer/GridContainer
@onready var close_button: Button = $MarginContainer/VBoxContainer/TopBar/CloseButton
@onready var title_label: Label = $MarginContainer/VBoxContainer/TopBar/TitleLabel
@onready var tooltip_panel: Panel = $TooltipPanel
@onready var tooltip_label: Label = $TooltipPanel/MarginContainer/TooltipLabel

# ============================================================================
# 配置变量
# ============================================================================

var warehouse_capacity: int = 48
var warehouse_columns: int = 8
var slot_size: int = 64
var slot_spacing: int = 8

# 格子按钮数组
var slot_buttons: Array[Button] = []

# ============================================================================
# 选择模式
# ============================================================================

# 是否处于选择模式
var selection_mode: bool = false

# 选择模式信号
signal item_selected(item_type: int, slot_index: int)

# ============================================================================
# 初始化
# ============================================================================

func _ready() -> void:
	# 从配置读取仓库参数
	warehouse_capacity = int(ConfigManager.get_game_setting("WarehouseCapacity", 48))
	warehouse_columns = int(ConfigManager.get_game_setting("WarehouseColumns", 8))
	
	# 设置仓库管理器的容量
	WarehouseManager.warehouse_capacity = warehouse_capacity
	
	# 初始化UI
	_setup_ui()
	_generate_slots()
	_refresh_items()
	
	# 连接关闭按钮
	close_button.pressed.connect(_on_close_pressed)
	
	# 初始隐藏tooltip
	tooltip_panel.visible = false
	
	# 如果是选择模式，更新标题
	if selection_mode:
		title_label.text = "选择装备"
	
	print("[WarehouseUI] 初始化完成 - 容量: %d, 列数: %d, 选择模式: %s" % [warehouse_capacity, warehouse_columns, selection_mode])

# ============================================================================
# UI设置
# ============================================================================

func _setup_ui() -> void:
	"""设置UI布局和样式"""
	# 设置GridContainer
	grid_container.columns = warehouse_columns
	grid_container.add_theme_constant_override("h_separation", slot_spacing)
	grid_container.add_theme_constant_override("v_separation", slot_spacing)
	
	# 计算窗口大小
	var rows = ceili(float(warehouse_capacity) / float(warehouse_columns))
	var grid_width = warehouse_columns * slot_size + (warehouse_columns - 1) * slot_spacing
	var grid_height = rows * slot_size + (rows - 1) * slot_spacing
	
	# 设置背景Panel大小（包含边距和标题栏）
	var margin = 20
	var top_bar_height = 60
	var total_width = grid_width + margin * 2
	var total_height = grid_height + margin * 2 + top_bar_height
	
	# 居中显示
	custom_minimum_size = Vector2(total_width, total_height)
	size = custom_minimum_size
	position = (get_viewport_rect().size - size) / 2
	
	print("[WarehouseUI] 窗口大小: %dx%d, 格子区域: %dx%d" % [total_width, total_height, grid_width, grid_height])

# ============================================================================
# 格子生成
# ============================================================================

func _generate_slots() -> void:
	"""生成仓库格子"""
	slot_buttons.clear()
	
	for i in range(warehouse_capacity):
		var slot = _create_slot(i)
		grid_container.add_child(slot)
		slot_buttons.append(slot)
	
	print("[WarehouseUI] 生成了 %d 个格子" % warehouse_capacity)

func _create_slot(slot_index: int) -> Button:
	"""创建单个格子"""
	var slot = Button.new()
	slot.name = "Slot_%d" % slot_index
	slot.custom_minimum_size = Vector2(slot_size, slot_size)
	slot.expand_icon = true
	slot.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	
	# 设置背景样式
	var style_normal = StyleBoxFlat.new()
	style_normal.bg_color = Color(0.16, 0.16, 0.16, 1)  # #2a2a2a
	style_normal.set_corner_radius_all(4)
	style_normal.border_color = Color(0.3, 0.3, 0.3, 1)
	style_normal.set_border_width_all(1)
	
	var style_hover = StyleBoxFlat.new()
	style_hover.bg_color = Color(0.16, 0.16, 0.16, 1)
	style_hover.set_corner_radius_all(4)
	style_hover.border_color = Color(1, 0.84, 0, 1)  # 金色边框
	style_hover.set_border_width_all(2)
	
	slot.add_theme_stylebox_override("normal", style_normal)
	slot.add_theme_stylebox_override("hover", style_hover)
	slot.add_theme_stylebox_override("pressed", style_hover)
	
	# 连接信号
	slot.mouse_entered.connect(_on_slot_mouse_entered.bind(slot_index))
	slot.mouse_exited.connect(_on_slot_mouse_exited)
	slot.pressed.connect(_on_slot_pressed.bind(slot_index))
	
	return slot

# ============================================================================
# 道具显示
# ============================================================================

func _refresh_items() -> void:
	"""刷新所有格子的道具显示"""
	var items = WarehouseManager.get_all_items()
	
	for i in range(slot_buttons.size()):
		var slot = slot_buttons[i]
		var item_type = items.get(i, 0)
		
		if item_type > 0:
			_display_item_in_slot(slot, item_type)
		else:
			_clear_slot(slot)

func _display_item_in_slot(slot: Button, item_type: int) -> void:
	"""在格子中显示道具"""
	var config = WarehouseManager.get_item_config(item_type)
	if config.is_empty():
		return
	
	var resource_path = config.get("resourcePath", "")
	if resource_path != "":
		var texture = load(resource_path)
		if texture:
			slot.icon = texture
			# 设置图标大小（留出边距）
			slot.add_theme_constant_override("icon_max_width", slot_size - 8)

func _clear_slot(slot: Button) -> void:
	"""清空格子显示"""
	slot.icon = null

# ============================================================================
# 鼠标事件
# ============================================================================

func _on_slot_mouse_entered(slot_index: int) -> void:
	"""鼠标进入格子"""
	var item_type = WarehouseManager.get_item_at_slot(slot_index)
	if item_type > 0:
		_show_tooltip(item_type)

func _on_slot_mouse_exited() -> void:
	"""鼠标离开格子"""
	_hide_tooltip()

func _on_slot_pressed(slot_index: int) -> void:
	"""点击格子（预留接口，可用于道具使用/移除等）"""
	var item_type = WarehouseManager.get_item_at_slot(slot_index)
	if item_type > 0:
		print("[WarehouseUI] 点击槽位 %d, 道具类型: %d" % [slot_index, item_type])
		
		# 如果是选择模式，发出信号并关闭
		if selection_mode:
			item_selected.emit(item_type, slot_index)
			_on_close_pressed()
		# TODO: 这里可以添加道具使用/移除逻辑

# ============================================================================
# Tooltip显示
# ============================================================================

func _show_tooltip(item_type: int) -> void:
	"""显示道具提示"""
	var config = WarehouseManager.get_item_config(item_type)
	if config.is_empty():
		return
	
	var description = config.get("description", "未知道具")
	tooltip_label.text = description
	
	# 重置大小让Panel根据内容自适应
	tooltip_panel.reset_size()
	
	# 显示tooltip
	tooltip_panel.visible = true
	
	# 更新tooltip位置（跟随鼠标）
	_update_tooltip_position()

func _hide_tooltip() -> void:
	"""隐藏道具提示"""
	tooltip_panel.visible = false

func _update_tooltip_position() -> void:
	"""更新tooltip位置（top_level模式，使用视口坐标）"""
	var mouse_pos = get_viewport().get_mouse_position()
	var offset = Vector2(15, 15)
	
	var viewport_size = get_viewport_rect().size
	var tooltip_size = tooltip_panel.size
	
	var pos = mouse_pos + offset
	if pos.x + tooltip_size.x > viewport_size.x:
		pos.x = mouse_pos.x - tooltip_size.x - offset.x
	if pos.y + tooltip_size.y > viewport_size.y:
		pos.y = mouse_pos.y - tooltip_size.y - offset.y
	
	tooltip_panel.position = pos

func _process(_delta: float) -> void:
	"""每帧更新tooltip位置"""
	if tooltip_panel.visible:
		_update_tooltip_position()

# ============================================================================
# 关闭按钮
# ============================================================================

func _on_close_pressed() -> void:
	"""关闭仓库UI"""
	queue_free()
	print("[WarehouseUI] 关闭仓库")

# ============================================================================
# 公共接口
# ============================================================================

func add_item_to_warehouse(item_type: int) -> bool:
	"""添加道具到仓库（外部调用接口）"""
	if WarehouseManager.add_item(item_type):
		_refresh_items()
		return true
	return false
