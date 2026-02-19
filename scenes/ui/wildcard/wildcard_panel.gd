extends Control
class_name WildcardPanel

# ============================================================================
# 万能鬼牌选择面板 - 显示所有羁绊供玩家选择目标标签
# ============================================================================
#
# 显示所有 12 种羁绊供选择，当前队伍已有的羁绊置顶高亮。
# 每个选项显示羁绊名称、当前标签数量和下一级需求。
# 选择后调用 EmblemManager.assign_wildcard()。
# process_mode = ALWAYS 以便在暂停时仍可交互。
# ============================================================================

# 选择完毕后发出
signal wildcard_assigned

# 当前待分配的万能鬼牌数据
var _emblem_data: Dictionary = {}

# 内部节点引用
var _bg: ColorRect
var _title_label: Label
var _options_container: VBoxContainer
var _buttons: Array[Button] = []

# ============================================================================
# 初始化
# ============================================================================

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_ui()
	visible = false

func _build_ui() -> void:
	"""程序化构建面板 UI"""
	# 全屏覆盖
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	# 半透明背景
	_bg = ColorRect.new()
	_bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_bg.color = Color(0, 0, 0, 0.7)
	_bg.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_bg)

	# 居中容器
	var center = CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	center.add_child(vbox)

	# 标题
	_title_label = Label.new()
	_title_label.text = "选择目标羁绊"
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_label.add_theme_font_size_override("font_size", 26)
	vbox.add_child(_title_label)

	# 副标题
	var sub_label = Label.new()
	sub_label.text = "万能鬼牌将充当所选羁绊的标签 +1"
	sub_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub_label.add_theme_font_size_override("font_size", 16)
	sub_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.6))
	vbox.add_child(sub_label)

	# 滚动容器（防止选项过多溢出）
	var scroll = ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(400, 400)
	vbox.add_child(scroll)

	_options_container = VBoxContainer.new()
	_options_container.add_theme_constant_override("separation", 6)
	_options_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_options_container)

# ============================================================================
# 显示选择界面
# ============================================================================

func show_wildcard_selection(emblem_data: Dictionary) -> void:
	"""显示万能鬼牌选择界面
	
	Args:
		emblem_data: 万能鬼牌的护符数据
	"""
	_emblem_data = emblem_data
	_populate_options()
	visible = true
	print("[WildcardPanel] 显示万能鬼牌选择界面")

func _populate_options() -> void:
	"""填充羁绊选项列表，当前队伍已有的羁绊置顶高亮"""
	_clear_options()

	# 获取当前队伍的羁绊标签计数
	var counts: Dictionary = BondManager.current_bond_counts

	# 构建选项数据：{tag, display_name, count, next_required, has_tags}
	var options: Array[Dictionary] = []
	for tag in EmblemManager.VALID_BOND_TAGS:
		var display_name = BondManager.get_bond_display_name(tag)
		var count = counts.get(tag, 0)
		var max_level = BondManager.get_bond_max_level(tag)
		var current_level = BondManager.get_activated_level(tag, count)
		# 计算下一级需求
		var next_required = _get_next_level_required(tag, current_level, max_level)

		options.append({
			"tag": tag,
			"display_name": display_name,
			"count": count,
			"current_level": current_level,
			"max_level": max_level,
			"next_required": next_required,
			"has_tags": count > 0
		})

	# 排序：已有标签的置顶，其次按当前数量降序
	options.sort_custom(func(a, b):
		if a.has_tags != b.has_tags:
			return a.has_tags  # true 排前面
		return a.count > b.count
	)

	# 创建按钮
	for opt in options:
		var btn = Button.new()
		btn.custom_minimum_size = Vector2(380, 40)
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT

		# 构建显示文本
		var text = "  %s  —  %d" % [opt.display_name, opt.count]
		if opt.next_required > 0:
			text += "/%d" % opt.next_required
		if opt.current_level > 0:
			text += "  (Lv.%d)" % opt.current_level

		btn.text = text

		# 高亮已有标签的羁绊
		if opt.has_tags:
			btn.add_theme_color_override("font_color", Color(1.0, 0.9, 0.4))
		else:
			btn.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))

		btn.pressed.connect(_on_bond_selected.bind(opt.tag))
		_options_container.add_child(btn)
		_buttons.append(btn)

func _get_next_level_required(bond_id: String, current_level: int, max_level: int) -> int:
	"""获取下一级的需求数量"""
	if current_level >= max_level:
		return 0
	var next_level = current_level + 1
	return BondManager.get_bond_required_count(bond_id, next_level)

func _clear_options() -> void:
	"""清除所有选项按钮"""
	for btn in _buttons:
		if is_instance_valid(btn):
			btn.queue_free()
	_buttons.clear()

# ============================================================================
# 选择处理
# ============================================================================

func _on_bond_selected(bond_tag: String) -> void:
	"""玩家选择了目标羁绊"""
	print("[WildcardPanel] 玩家选择羁绊: %s" % bond_tag)

	# 找到万能鬼牌在 held_emblems 中的索引
	var emblem_index = _find_emblem_index()
	if emblem_index < 0:
		printerr("[WildcardPanel] 找不到万能鬼牌索引")
		wildcard_assigned.emit()
		return

	# 调用 EmblemManager 分配
	EmblemManager.assign_wildcard(emblem_index, bond_tag)
	SoundManager.play("ui_confirm")

	wildcard_assigned.emit()

func _find_emblem_index() -> int:
	"""查找当前万能鬼牌在 held_emblems 中的索引"""
	var emblem_id = _emblem_data.get("emblem_id", "")
	for i in range(EmblemManager.held_emblems.size()):
		var e = EmblemManager.held_emblems[i]
		if e.get("is_wildcard", false) and e.get("bond_tag", "") == "wildcard":
			# 如果有 emblem_id 匹配则优先
			if emblem_id != "" and e.get("emblem_id", "") == emblem_id:
				return i
			# 否则返回第一个未分配的万能鬼牌
			return i
	return -1
