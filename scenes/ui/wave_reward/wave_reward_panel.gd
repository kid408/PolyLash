extends Control
class_name WaveRewardPanel

# ============================================================================
# 波次奖励面板 - 三选一奖励界面
# ============================================================================
#
# 在特定波次结束后弹出，显示三个奖励卡片供玩家选择。
# 选择后应用奖励并关闭面板。
# process_mode = ALWAYS 以便在暂停时仍可交互。
# ============================================================================

# 玩家选择奖励后发出（携带奖励数据）
signal reward_chosen(reward_data: Dictionary)

# WaveRewardSystem 引用（由外部设置）
var wave_reward_system: Node = null

# 内部节点引用
var _bg: ColorRect
var _title_label: Label
var _cards_container: HBoxContainer
var _cards: Array[RewardCard] = []

# ============================================================================
# 初始化
# ============================================================================

func _ready() -> void:
	# 暂停时仍可交互
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
	_bg.color = Color(0, 0, 0, 0.6)
	_bg.mouse_filter = Control.MOUSE_FILTER_STOP  # 拦截点击
	add_child(_bg)

	# 居中容器
	var center = CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 20)
	center.add_child(vbox)

	# 标题
	_title_label = Label.new()
	_title_label.text = "选择奖励"
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_label.add_theme_font_size_override("font_size", 28)
	vbox.add_child(_title_label)

	# 卡片容器
	_cards_container = HBoxContainer.new()
	_cards_container.add_theme_constant_override("separation", 16)
	_cards_container.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(_cards_container)

# ============================================================================
# 显示/隐藏
# ============================================================================

func show_rewards(options: Array[Dictionary]) -> void:
	"""显示奖励选项
	
	Args:
		options: 三选一奖励数据数组
	"""
	# 清除旧卡片
	_clear_cards()

	# 创建新卡片
	for i in range(options.size()):
		var card = RewardCard.new()
		_cards_container.add_child(card)
		card.setup(i, options[i])
		card.card_pressed.connect(_on_card_pressed)
		_cards.append(card)

	visible = true
	# 暂停游戏
	get_tree().paused = true
	SoundManager.play("ui_panel_open")
	print("[WaveRewardPanel] 显示 %d 个奖励选项" % options.size())

func _hide_panel() -> void:
	"""隐藏面板并恢复游戏"""
	visible = false
	_clear_cards()
	SoundManager.play("ui_panel_close")
	# 恢复游戏
	get_tree().paused = false
	print("[WaveRewardPanel] 面板关闭，游戏恢复")

func _clear_cards() -> void:
	"""清除所有卡片"""
	for card in _cards:
		if is_instance_valid(card):
			card.queue_free()
	_cards.clear()

# ============================================================================
# 信号处理
# ============================================================================

func _on_card_pressed(index: int) -> void:
	"""玩家选择了一个奖励"""
	print("[WaveRewardPanel] 玩家选择了奖励 #%d" % index)

	# 通过 WaveRewardSystem 应用奖励
	if wave_reward_system and wave_reward_system.has_method("select_reward"):
		wave_reward_system.select_reward(index)

	# 发出信号
	var reward = {}
	if index >= 0 and index < _cards.size():
		reward = _cards[index].reward_data
	reward_chosen.emit(reward)

	# 关闭面板
	_hide_panel()
