extends Panel
class_name SelectionPanel

# ============================================================================
# 角色选择面板 - 游戏开始前选择角色和武器
# ============================================================================

# ============================================================================
# 信号
# ============================================================================

signal selection_confirmed(selected_data: Array[Dictionary])

# ============================================================================
# 节点引用
# ============================================================================

@onready var player_container: Container = $MarginContainer/HBoxContainer/MainContent/MiddleSection/PlayerContainerWrapper/PlayerContainer
@onready var weapon_container: Container = $MarginContainer/HBoxContainer/MainContent/BottomSection/WeaponContainerWrapper/WeaponContainer
@onready var selected_list: VBoxContainer = $MarginContainer/HBoxContainer/LeftPanel/SelectedList
@onready var player_info: HBoxContainer = $MarginContainer/HBoxContainer/MainContent/TopSection/InfoPanel/MarginContainer/PlayerInfo
@onready var player_ico: TextureRect = $MarginContainer/HBoxContainer/MainContent/TopSection/InfoPanel/MarginContainer/PlayerInfo/PlayerIco
@onready var player_name_label: Label = $MarginContainer/HBoxContainer/MainContent/TopSection/InfoPanel/MarginContainer/PlayerInfo/RightContent/PlayerName
@onready var player_ties_label: Label = $MarginContainer/HBoxContainer/MainContent/TopSection/InfoPanel/MarginContainer/PlayerInfo/RightContent/PlayerTies
@onready var player_description: RichTextLabel = $MarginContainer/HBoxContainer/MainContent/TopSection/InfoPanel/MarginContainer/PlayerInfo/RightContent/ScrollContainer/PlayerDescription
@onready var continue_button: Button = $MarginContainer/HBoxContainer/RightPanel/Continue
@onready var upgrade_button: Button = $MarginContainer/HBoxContainer/RightPanel/UpgradeButton

# ============================================================================
# 模板按钮引用
# ============================================================================

var player_button_template: Button = null
var weapon_button_template: Button = null
var selected_slot_template: Button = null

# ============================================================================
# 数据变量
# ============================================================================

# 已选择的角色列表
var selected_players: Array[Dictionary] = []
# 格式: [{player_id: String, weapon_type: String, slot_index: int}, ...]

# 当前预览的角色ID
var preview_player_id: String = ""

# 当前预览角色选择的武器类型
var preview_weapon_type: String = ""

# 配置
var players_per_row: int = 5
var max_selected_players: int = 3

# 角色按钮映射 {player_id: Button}
var player_buttons: Dictionary = {}

# 已选槽位按钮数组
var selected_slot_buttons: Array[Button] = []

# 角色武器选择缓存 {player_id: weapon_type} - 记住每个角色选择的武器
var player_weapon_cache: Dictionary = {}

# 已选角色缓存 - 记住上次选择的角色
var selected_players_cache: Array = []

# 本地存储路径
const WEAPON_CACHE_PATH = "user://player_weapon_cache.json"
const SELECTION_CACHE_PATH = "user://player_selection_cache.json"

# ============================================================================
# 初始化
# ============================================================================

func _ready() -> void:
	# 加载配置
	players_per_row = int(ConfigManager.get_game_setting("selection_players_per_row", 5))
	max_selected_players = int(ConfigManager.get_game_setting("max_selected_players", 3))
	
	# 加载武器选择缓存
	_load_weapon_cache()
	
	# 加载已选角色缓存
	_load_selection_cache()
	
	# 保存模板按钮
	_save_templates()
	
	# 生成UI
	_generate_selected_slots()
	_generate_player_buttons()
	
	# 从缓存恢复已选角色
	_restore_selection_from_cache()
	
	# 连接Continue按钮
	continue_button.pressed.connect(_on_continue_pressed)
	continue_button.disabled = true
	
	# 连接强化按钮
	upgrade_button.pressed.connect(_on_upgrade_pressed)
	
	# 清空初始显示
	_clear_player_info()
	_clear_weapon_container()
	
	# 更新Continue按钮状态
	_update_continue_button_state()
	
	print("[SelectionPanel] 初始化完成 - 每行%d个角色，最多选择%d个" % [players_per_row, max_selected_players])

# ============================================================================
# 武器缓存持久化
# ============================================================================

func _load_weapon_cache() -> void:
	"""从本地文件加载武器选择缓存"""
	if not FileAccess.file_exists(WEAPON_CACHE_PATH):
		print("[SelectionPanel] 武器缓存文件不存在，使用默认值")
		return
	
	var file = FileAccess.open(WEAPON_CACHE_PATH, FileAccess.READ)
	if not file:
		printerr("[SelectionPanel] 无法打开武器缓存文件")
		return
	
	var json_text = file.get_as_text()
	file.close()
	
	var json = JSON.new()
	var error = json.parse(json_text)
	if error != OK:
		printerr("[SelectionPanel] 解析武器缓存JSON失败: %s" % json.get_error_message())
		return
	
	var data = json.get_data()
	if data is Dictionary:
		player_weapon_cache = data
		print("[SelectionPanel] 加载武器缓存: %s" % str(player_weapon_cache))

func _save_weapon_cache() -> void:
	"""保存武器选择缓存到本地文件"""
	var file = FileAccess.open(WEAPON_CACHE_PATH, FileAccess.WRITE)
	if not file:
		printerr("[SelectionPanel] 无法创建武器缓存文件")
		return
	
	var json_text = JSON.stringify(player_weapon_cache)
	file.store_string(json_text)
	file.close()
	print("[SelectionPanel] 保存武器缓存: %s" % str(player_weapon_cache))

func _load_selection_cache() -> void:
	"""从本地文件加载已选角色缓存"""
	if not FileAccess.file_exists(SELECTION_CACHE_PATH):
		print("[SelectionPanel] 已选角色缓存文件不存在")
		return
	
	var file = FileAccess.open(SELECTION_CACHE_PATH, FileAccess.READ)
	if not file:
		printerr("[SelectionPanel] 无法打开已选角色缓存文件")
		return
	
	var json_text = file.get_as_text()
	file.close()
	
	var json = JSON.new()
	var error = json.parse(json_text)
	if error != OK:
		printerr("[SelectionPanel] 解析已选角色缓存JSON失败: %s" % json.get_error_message())
		return
	
	var data = json.get_data()
	if data is Array:
		selected_players_cache = data
		print("[SelectionPanel] 加载已选角色缓存: %s" % str(selected_players_cache))

func _save_selection_cache() -> void:
	"""保存已选角色缓存到本地文件"""
	var cache_data: Array = []
	for data in selected_players:
		cache_data.append({
			"player_id": data.player_id,
			"weapon_type": data.weapon_type,
			"slot_index": data.slot_index
		})
	
	var file = FileAccess.open(SELECTION_CACHE_PATH, FileAccess.WRITE)
	if not file:
		printerr("[SelectionPanel] 无法创建已选角色缓存文件")
		return
	
	var json_text = JSON.stringify(cache_data)
	file.store_string(json_text)
	file.close()
	print("[SelectionPanel] 保存已选角色缓存: %s" % str(cache_data))

func _restore_selection_from_cache() -> void:
	"""从缓存恢复已选角色"""
	if selected_players_cache.is_empty():
		return
	
	for cached_data in selected_players_cache:
		var player_id = cached_data.get("player_id", "")
		var weapon_type = cached_data.get("weapon_type", "")
		
		if player_id == "":
			continue
		
		# 检查角色是否存在
		if not player_buttons.has(player_id):
			continue
		
		# 如果武器为空，使用缓存的武器
		if weapon_type == "":
			if player_weapon_cache.has(player_id):
				weapon_type = player_weapon_cache[player_id]
			else:
				var weapon_types = ConfigManager.get_player_available_weapon_types(player_id)
				if weapon_types.size() > 0:
					weapon_type = weapon_types[0]
		
		# 添加到已选列表
		_add_player_to_selected(player_id, weapon_type)
	
	print("[SelectionPanel] 从缓存恢复了 %d 个已选角色" % selected_players.size())

func _save_templates() -> void:
	# 保存角色按钮模板
	for child in player_container.get_children():
		if child is Button:
			player_button_template = child.duplicate()
			child.queue_free()
			print("[SelectionPanel] 保存角色按钮模板成功")
			break
	
	if player_button_template == null:
		print("[SelectionPanel] 警告: player_container 没有按钮子节点，无法保存模板")
	
	# 保存武器按钮模板
	for child in weapon_container.get_children():
		if child is Button:
			weapon_button_template = child.duplicate()
			weapon_button_template.modulate = Color.WHITE
			child.queue_free()
			print("[SelectionPanel] 保存武器按钮模板成功")
			break
	
	if weapon_button_template == null:
		print("[SelectionPanel] 警告: weapon_container 没有按钮子节点，创建默认模板")
		weapon_button_template = Button.new()
		weapon_button_template.custom_minimum_size = Vector2(32, 32)  # 武器最小，仅作附件展示
		weapon_button_template.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		weapon_button_template.expand_icon = true
		weapon_button_template.modulate = Color.WHITE
	
	# 保存已选槽位模板（从 SelectedList 获取）
	for child in selected_list.get_children():
		if child is Button:
			selected_slot_template = child.duplicate()
			child.queue_free()
			print("[SelectionPanel] 保存已选槽位模板成功")
			break
	
	if selected_slot_template == null:
		print("[SelectionPanel] 警告: selected_list 没有按钮子节点，无法保存模板")

# ============================================================================
# 角色列表生成
# ============================================================================

# 最小槽位数量（保证两排显示）
const MIN_CHARACTER_SLOTS = 16  # 8列 x 2行

func _generate_player_buttons() -> void:
	var enabled_players = ConfigManager.get_enabled_players()
	
	# 图标尺寸配置
	var icon_size = 120  # 角色池图标尺寸 (大图标)
	var spacing = 10  # 间距
	var grid_columns = 8  # 列数
	
	# 获取 PlayerContainerWrapper
	var wrapper = player_container.get_parent()
	
	# 清理并重新设置PlayerContainer
	player_container.queue_free()
	
	# 创建新的GridContainer - 强制设置列数
	var grid = GridContainer.new()
	grid.name = "PlayerContainer"
	grid.columns = grid_columns
	grid.add_theme_constant_override("h_separation", spacing)
	grid.add_theme_constant_override("v_separation", spacing)
	# 左对齐：不使用 FULL_RECT，改用左上角锚点
	grid.set_anchors_preset(Control.PRESET_TOP_LEFT)
	grid.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	grid.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	wrapper.add_child(grid)
	
	# 更新引用
	player_container = grid
	
	var real_count = 0
	for player_config in enabled_players:
		var player_id = player_config.get("player_id", "")
		if player_id == "":
			continue
		
		# 创建按钮（使用自定义类）
		var btn = PlayerSelectButton.new()
		btn.name = "PlayerBtn_" + player_id
		btn.custom_minimum_size = Vector2(icon_size, icon_size)
		btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		btn.expand_icon = true
		btn.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		
		# 获取该角色可用武器，优先使用缓存的武器
		var weapon_types = ConfigManager.get_player_available_weapon_types(player_id)
		var default_weapon = ""
		if player_weapon_cache.has(player_id):
			default_weapon = player_weapon_cache[player_id]
		elif weapon_types.size() > 0:
			default_weapon = weapon_types[0]
		btn.setup(player_id, default_weapon)
		
		# 设置图标（从player_visual获取sprite_path）
		var visual_config = ConfigManager.get_player_visual(player_id)
		var sprite_path = visual_config.get("sprite_path", "")
		if sprite_path != "":
			var texture = load(sprite_path)
			if texture:
				btn.icon = texture
		
		# 设置tooltip
		btn.tooltip_text = player_config.get("display_name", player_id)
		
		# 连接信号
		btn.pressed.connect(_on_player_button_pressed.bind(player_id))
		
		grid.add_child(btn)
		player_buttons[player_id] = btn
		real_count += 1
	
	# === 添加隐形占位符填充两排 ===
	var needed_placeholders = MIN_CHARACTER_SLOTS - real_count
	for i in range(needed_placeholders):
		var dummy = Control.new()
		dummy.name = "Placeholder_%d" % i
		dummy.custom_minimum_size = Vector2(icon_size, icon_size)
		dummy.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		dummy.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		dummy.mouse_filter = Control.MOUSE_FILTER_IGNORE  # 鼠标穿透
		dummy.modulate.a = 0  # 完全透明
		grid.add_child(dummy)
	
	print("[SelectionPanel] 生成了 %d 个角色按钮 + %d 个占位符，Grid列数: %d" % [real_count, needed_placeholders, grid_columns])


# ============================================================================
# 已选槽位生成
# ============================================================================

func _generate_selected_slots() -> void:
	selected_slot_buttons.clear()
	
	# 清除所有按钮子节点
	for child in selected_list.get_children():
		if child is Button:
			child.queue_free()
	
	# 始终生成5个槽位（max_selected_players个可用 + 占位符补齐到5个）
	var total_slots = 5
	var slot_size = 110  # 左侧已选列表槽位尺寸 (最大)
	
	for i in range(total_slots):
		var btn = SelectedSlotButton.new()
		btn.name = "SelectedSlot_%d" % i
		btn.custom_minimum_size = Vector2(slot_size, slot_size)
		btn.text = ""
		
		if i < max_selected_players:
			# 可用槽位
			btn.tooltip_text = "槽位 %d (空)" % (i + 1)
			btn.setup(i)
			btn.pressed.connect(_on_selected_slot_pressed.bind(i))
			btn.player_dropped.connect(_on_player_dropped)
			selected_slot_buttons.append(btn)
		else:
			# 占位符槽位（禁用状态）
			btn.tooltip_text = "槽位 %d (锁定)" % (i + 1)
			btn.disabled = true
			btn.modulate = Color(0.5, 0.5, 0.5, 0.5)
		
		selected_list.add_child(btn)
	
	print("[SelectionPanel] 生成了 %d 个已选槽位 (总共 %d 个显示)" % [max_selected_players, total_slots])

# ============================================================================
# 角色按钮事件
# ============================================================================

func _on_player_button_pressed(player_id: String) -> void:
	print("[SelectionPanel] === 开始处理角色点击: %s ===" % player_id)
	preview_player_id = player_id
	
	# 获取该角色可用武器
	var weapon_types = ConfigManager.get_player_available_weapon_types(player_id)
	
	# 优先使用缓存的武器选择，否则使用第一个
	if player_weapon_cache.has(player_id):
		preview_weapon_type = player_weapon_cache[player_id]
		print("[SelectionPanel] 从缓存获取武器: %s" % preview_weapon_type)
	elif weapon_types.size() > 0:
		preview_weapon_type = weapon_types[0]
		print("[SelectionPanel] 使用默认武器: %s" % preview_weapon_type)
		# 保存默认选择到缓存
		player_weapon_cache[player_id] = preview_weapon_type
		_save_weapon_cache()
	else:
		preview_weapon_type = ""
	
	# 更新角色按钮的武器类型（用于拖拽）
	if player_buttons.has(player_id):
		var btn = player_buttons[player_id] as PlayerSelectButton
		if btn:
			btn.weapon_type = preview_weapon_type
	
	# 更新显示
	_update_player_info(player_id)
	_update_weapon_container(player_id)
	
	print("[SelectionPanel] === 完成处理角色点击: %s, 武器: %s ===" % [player_id, preview_weapon_type])

# ============================================================================
# 角色信息显示
# ============================================================================

func _update_player_info(player_id: String) -> void:
	var config = ConfigManager.get_player_config(player_id)
	var visual_config = ConfigManager.get_player_visual(player_id)
	
	if config.is_empty():
		_clear_player_info()
		return
	
	# 设置图标
	var sprite_path = visual_config.get("sprite_path", "")
	if sprite_path != "":
		var texture = load(sprite_path)
		if texture:
			player_ico.texture = texture
	
	# 设置名称
	player_name_label.text = config.get("display_name", player_id)
	
	# 设置羁绊
	player_ties_label.text = "[%s]" % config.get("ties", "无")
	
	# 设置属性描述
	var desc_text = ""
	desc_text += "生命值: %d\n" % int(config.get("health", 0))
	desc_text += "Q技能消耗: %d\n" % int(config.get("skill_q_cost", 0))
	desc_text += "E技能消耗: %d\n" % int(config.get("skill_e_cost", 0))
	desc_text += "能量恢复: %.1f/秒\n" % config.get("energy_regen", 0)
	desc_text += "最大能量: %d\n" % int(config.get("max_energy", 0))
	desc_text += "最大护甲: %d\n" % int(config.get("max_armor", 0))
	desc_text += "移动速度: %d\n" % int(config.get("base_speed", 0))
	desc_text += "\n[color=gray]%s[/color]" % config.get("description", "")
	
	player_description.text = desc_text

func _clear_player_info() -> void:
	player_ico.texture = null
	player_name_label.text = "选择角色"
	player_ties_label.text = ""
	player_description.text = "点击下方角色查看详情"

# ============================================================================
# 武器选择
# ============================================================================

func _update_weapon_container(player_id: String) -> void:
	# 清除现有武器按钮
	_clear_weapon_container()
	
	var weapon_types = ConfigManager.get_player_available_weapon_types(player_id)
	
	# 确定当前应该高亮的武器：优先使用缓存，否则使用preview_weapon_type
	var highlight_weapon = player_weapon_cache.get(player_id, "")
	if highlight_weapon == "":
		highlight_weapon = preview_weapon_type
	
	print("[SelectionPanel] _update_weapon_container: player_id=%s, highlight_weapon=%s" % [player_id, highlight_weapon])
	
	# 武器图标尺寸 - 角色的一半，面积1/4
	var weapon_slot_size = 60
	
	for weapon_type in weapon_types:
		# 获取1级武器配置
		var weapon_config = ConfigManager.get_weapon_by_type_level(weapon_type, 1)
		if weapon_config.is_empty():
			continue
		
		# 获取武器详细配置（包含图标路径）
		var weapon_id = "%s_1" % weapon_type
		var weapon_stats = ConfigManager.get_weapon_stats(weapon_id)
		
		# 创建 Panel 作为 Slot 容器（不使用 CenterContainer，直接左对齐）
		var slot = Panel.new()
		slot.name = "WeaponSlot_" + weapon_type
		slot.custom_minimum_size = Vector2(weapon_slot_size, weapon_slot_size)
		slot.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		slot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		slot.tooltip_text = weapon_config.get("display_name", weapon_type)
		
		# 设置 Slot 背景样式
		var is_highlighted = (weapon_type == highlight_weapon)
		var style = StyleBoxFlat.new()
		if is_highlighted:
			style.bg_color = Color(0.3, 0.3, 0.3, 1)
			style.border_color = Color(1, 1, 0)  # 黄色边框
			style.set_border_width_all(2)
			print("[SelectionPanel] 高亮武器: %s" % weapon_type)
		else:
			style.bg_color = Color(0.2, 0.2, 0.2, 1)
			style.border_color = Color(0.4, 0.4, 0.4)
			style.set_border_width_all(1)
		style.set_corner_radius_all(4)
		slot.add_theme_stylebox_override("panel", style)
		
		# 创建 TextureRect 作为图标 - 完全填充 Slot
		var icon_rect = TextureRect.new()
		icon_rect.name = "IconRect"
		icon_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
		icon_rect.set_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_KEEP_SIZE, 2)
		icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		
		# 设置图标纹理
		var icon_path = weapon_stats.get("icon_path", "")
		if icon_path != "":
			var texture = load(icon_path)
			if texture:
				icon_rect.texture = texture
		
		slot.add_child(icon_rect)
		
		# 创建透明按钮覆盖层用于点击检测
		var click_btn = Button.new()
		click_btn.name = "ClickArea"
		click_btn.set_anchors_preset(Control.PRESET_FULL_RECT)
		click_btn.flat = true
		click_btn.mouse_filter = Control.MOUSE_FILTER_STOP
		click_btn.pressed.connect(_on_weapon_button_pressed.bind(weapon_type))
		slot.add_child(click_btn)
		
		# Slot 直接放入 Grid（左对齐）
		weapon_container.add_child(slot)
	
	print("[SelectionPanel] 显示 %d 种武器" % weapon_types.size())

func _clear_weapon_container() -> void:
	for child in weapon_container.get_children():
		child.free()  # 使用 free() 而不是 queue_free() 避免延迟删除导致的问题

func _on_weapon_button_pressed(weapon_type: String) -> void:
	print("[SelectionPanel] 武器按钮点击: %s (当前预览角色: %s)" % [weapon_type, preview_player_id])
	preview_weapon_type = weapon_type
	
	# 更新武器按钮高亮 - 使用 StyleBox 边框
	for child in weapon_container.get_children():
		if child is Button:
			var is_selected = child.name == "WeaponBtn_" + weapon_type
			var style = StyleBoxFlat.new()
			if is_selected:
				style.bg_color = Color(0.3, 0.3, 0.3, 1)
				style.border_color = Color(1, 1, 0)  # 黄色边框
				style.set_border_width_all(4)
			else:
				style.bg_color = Color(0.2, 0.2, 0.2, 1)
				style.border_color = Color(0.4, 0.4, 0.4)
				style.set_border_width_all(2)
			style.set_corner_radius_all(8)
			child.add_theme_stylebox_override("normal", style)
			child.add_theme_stylebox_override("hover", style)
			child.add_theme_stylebox_override("pressed", style)
			child.add_theme_stylebox_override("focus", style)
	
	# 更新角色按钮的武器类型（用于拖拽）
	if player_buttons.has(preview_player_id):
		var btn = player_buttons[preview_player_id] as PlayerSelectButton
		if btn:
			btn.weapon_type = weapon_type
	
	# 保存到缓存并持久化
	if preview_player_id != "":
		player_weapon_cache[preview_player_id] = weapon_type
		_save_weapon_cache()
	
	# 如果当前预览角色已在已选列表中，更新其武器并保存缓存
	var found_in_selected = false
	for i in range(selected_players.size()):
		if selected_players[i].player_id == preview_player_id:
			selected_players[i].weapon_type = weapon_type
			found_in_selected = true
			print("[SelectionPanel] 更新已选角色 %s 的武器为 %s" % [preview_player_id, weapon_type])
			break
	
	# 如果角色在已选列表中，保存已选角色缓存
	if found_in_selected:
		_save_selection_cache()

# ============================================================================
# 已选槽位事件
# ============================================================================

func _on_selected_slot_pressed(slot_index: int) -> void:
	# 检查该槽位是否有角色
	for i in range(selected_players.size()):
		if selected_players[i].slot_index == slot_index:
			_remove_player_from_selected(i)
			return

# ============================================================================
# 角色选择管理
# ============================================================================

func _add_player_to_selected(player_id: String, weapon_type: String) -> bool:
	# 检查是否已选满
	if selected_players.size() >= max_selected_players:
		print("[SelectionPanel] 已选满 %d 个角色" % max_selected_players)
		return false
	
	# 检查是否已选择该角色
	for data in selected_players:
		if data.player_id == player_id:
			print("[SelectionPanel] 角色 %s 已被选择" % player_id)
			return false
	
	# 找到空槽位
	var slot_index = -1
	for i in range(max_selected_players):
		var slot_occupied = false
		for data in selected_players:
			if data.slot_index == i:
				slot_occupied = true
				break
		if not slot_occupied:
			slot_index = i
			break
	
	if slot_index == -1:
		return false
	
	# 添加到已选列表
	var data = {
		"player_id": player_id,
		"weapon_type": weapon_type,
		"slot_index": slot_index
	}
	selected_players.append(data)
	
	# 更新槽位显示
	_update_selected_slot_display(slot_index, player_id)
	
	# 更新角色按钮状态（显示已选中）
	if player_buttons.has(player_id):
		player_buttons[player_id].modulate = Color(0.5, 1, 0.5)  # 绿色表示已选
	
	# 更新Continue按钮状态
	_update_continue_button_state()
	
	print("[SelectionPanel] 添加角色 %s 到槽位 %d，武器: %s" % [player_id, slot_index, weapon_type])
	return true

func _remove_player_from_selected(index: int) -> void:
	if index < 0 or index >= selected_players.size():
		return
	
	var data = selected_players[index]
	var player_id = data.player_id
	var slot_index = data.slot_index
	
	# 从列表移除
	selected_players.remove_at(index)
	
	# 清空槽位显示
	_clear_selected_slot_display(slot_index)
	
	# 恢复角色按钮状态
	if player_buttons.has(player_id):
		player_buttons[player_id].modulate = Color.WHITE
	
	# 更新Continue按钮状态
	_update_continue_button_state()
	
	# 保存已选角色缓存（删除后也要保存）
	_save_selection_cache()
	
	print("[SelectionPanel] 移除角色 %s 从槽位 %d" % [player_id, slot_index])

func _update_selected_slot_display(slot_index: int, player_id: String) -> void:
	if slot_index < 0 or slot_index >= selected_slot_buttons.size():
		return
	
	var btn = selected_slot_buttons[slot_index]
	
	# 设置图标
	var visual_config = ConfigManager.get_player_visual(player_id)
	var sprite_path = visual_config.get("sprite_path", "")
	if sprite_path != "":
		var texture = load(sprite_path)
		if texture:
			btn.icon = texture
	
	# 设置tooltip
	var config = ConfigManager.get_player_config(player_id)
	btn.tooltip_text = config.get("display_name", player_id)

func _clear_selected_slot_display(slot_index: int) -> void:
	if slot_index < 0 or slot_index >= selected_slot_buttons.size():
		return
	
	var btn = selected_slot_buttons[slot_index]
	btn.icon = null
	btn.tooltip_text = "槽位 %d (空)" % (slot_index + 1)

# ============================================================================
# 拖拽功能
# ============================================================================

func _on_player_dropped(slot_index: int, player_id: String, weapon_type: String) -> void:
	# 如果武器为空，优先使用缓存的武器，否则使用默认武器
	if weapon_type == "":
		if player_weapon_cache.has(player_id):
			weapon_type = player_weapon_cache[player_id]
		else:
			var weapon_types = ConfigManager.get_player_available_weapon_types(player_id)
			if weapon_types.size() > 0:
				weapon_type = weapon_types[0]
	
	# 尝试添加到已选列表
	_add_player_to_selected(player_id, weapon_type)

# ============================================================================
# Continue按钮
# ============================================================================

func _update_continue_button_state() -> void:
	continue_button.disabled = selected_players.size() == 0

func _on_upgrade_pressed() -> void:
	"""打开角色强化界面"""
	# 先保存当前选择
	_save_selection_cache()
	
	# 准备数据传递给Global（强化界面需要知道已选角色）
	var player_ids: Array[String] = []
	var player_weapons: Dictionary = {}
	
	var sorted_players = selected_players.duplicate()
	sorted_players.sort_custom(func(a, b): return a.slot_index < b.slot_index)
	
	for data in sorted_players:
		var pid = data.player_id
		var wtype = data.weapon_type
		if wtype == "" and player_weapon_cache.has(pid):
			wtype = player_weapon_cache[pid]
		player_ids.append(pid)
		player_weapons[pid] = wtype
	
	Global.selected_player_ids = player_ids
	Global.selected_player_weapons = player_weapons
	
	print("[SelectionPanel] 打开强化界面，已选角色: %s" % str(player_ids))
	get_tree().change_scene_to_file("res://scenes/ui/selection_panel/character_upgrade.tscn")

func _on_continue_pressed() -> void:
	if selected_players.size() == 0:
		print("[SelectionPanel] 请至少选择一个角色")
		# 显示提示信息
		_show_selection_hint("请至少选择一个角色！")
		return
	
	# 保存已选角色缓存到本地
	_save_selection_cache()
	
	# 准备数据传递给Global
	var player_ids: Array[String] = []
	var player_weapons: Dictionary = {}
	
	# 按槽位顺序排列
	var sorted_players = selected_players.duplicate()
	sorted_players.sort_custom(func(a, b): return a.slot_index < b.slot_index)
	
	for data in sorted_players:
		var pid = data.player_id
		var wtype = data.weapon_type
		
		# 如果武器类型为空，从缓存获取
		if wtype == "" and player_weapon_cache.has(pid):
			wtype = player_weapon_cache[pid]
			print("[SelectionPanel] 从缓存补充武器: %s -> %s" % [pid, wtype])
		
		player_ids.append(pid)
		player_weapons[pid] = wtype
		print("[SelectionPanel] 角色 %s 武器: %s" % [pid, wtype])
	
	# 保存到Global
	Global.selected_player_ids = player_ids
	Global.selected_player_weapons = player_weapons
	Global.current_player_index = 0
	
	print("[SelectionPanel] Global.selected_player_weapons = %s" % str(Global.selected_player_weapons))
	
	# 初始化角色状态
	Global.init_player_states()
	
	# === 检查是否需要重置属性升级 (Roguelike模式) ===
	DataManager.check_and_reset_on_new_game()
	
	print("[SelectionPanel] 确认选择，角色: %s" % str(player_ids))
	
	# 发出信号
	selection_confirmed.emit(sorted_players)
	
	# 切换到游戏场景
	get_tree().change_scene_to_file("res://scenes/arena/arena.tscn")


# ============================================================================
# 提示信息
# ============================================================================

func _show_selection_hint(message: String) -> void:
	"""显示选择提示信息（飘字效果）"""
	var hint_label = Label.new()
	hint_label.text = message
	hint_label.add_theme_font_size_override("font_size", 32)
	hint_label.add_theme_color_override("font_color", Color(1, 0.3, 0.3))  # 红色
	hint_label.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	hint_label.add_theme_constant_override("outline_size", 4)
	
	# 设置位置（屏幕中央偏上）
	hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hint_label.anchors_preset = Control.PRESET_CENTER_TOP
	hint_label.position = Vector2(get_viewport_rect().size.x / 2 - 150, 100)
	hint_label.custom_minimum_size = Vector2(300, 50)
	
	add_child(hint_label)
	
	# 创建动画：向上飘动并淡出
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(hint_label, "position:y", hint_label.position.y - 50, 1.5)
	tween.tween_property(hint_label, "modulate:a", 0.0, 1.5)
	tween.set_parallel(false)
	tween.tween_callback(hint_label.queue_free)
