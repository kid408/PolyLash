extends Node
class_name SkillUltimate

# ============================================================================
# 大招技能基类 - F键变身系统
# ============================================================================

signal ultimate_activated
signal ultimate_deactivated
signal ultimate_duration_changed(remaining: float, total: float)

# 配置数据
var ult_id: String = ""
var ult_name: String = "Ultimate"
var duration: float = 10.0
var bonus_bond_tag: String = ""
var visual_color: Color = Color.WHITE
var scale_multiplier: float = 1.2
var description: String = ""

# 能量需求
var energy_cost: float = 80.0  # 需要80%以上能量才能激活

# 运行时状态
var is_active: bool = false
var remaining_time: float = 0.0
var player_ref: Node = null

# 视觉效果缓存
var original_scale: Vector2 = Vector2.ONE
var original_modulate: Color = Color.WHITE

# 计时器
var duration_timer: Timer = null

# ============================================================================
# 初始化
# ============================================================================

func _ready() -> void:
	# 创建持续时间计时器
	duration_timer = Timer.new()
	duration_timer.one_shot = true
	duration_timer.timeout.connect(_on_duration_timeout)
	add_child(duration_timer)

func initialize(config: Dictionary, player: Node) -> void:
	"""初始化大招配置
	
	Args:
		config: 大招配置字典
		player: 玩家节点引用
	"""
	ult_id = config.get("ult_id", "")
	ult_name = config.get("name", "Ultimate")
	duration = config.get("duration", 10.0)
	bonus_bond_tag = config.get("bonus_bond_tag", "")
	scale_multiplier = config.get("scale_multiplier", 1.2)
	description = config.get("description", "")
	
	# 从配置读取能量消耗（如果CSV中有配置）
	if config.has("energy_cost"):
		energy_cost = config.get("energy_cost", 80.0)
	
	# 解析颜色
	var color_hex = config.get("visual_color_hex", "#FFFFFF")
	visual_color = _parse_color(color_hex)
	
	player_ref = player
	
	# 保存原始视觉状态
	if player_ref:
		original_scale = player_ref.scale
		original_modulate = player_ref.modulate
	
	print("[SkillUltimate] 初始化大招: %s (持续%.1fs, 能量消耗:%.0f%%, 标签:%s)" % [ult_name, duration, energy_cost, bonus_bond_tag])

# ============================================================================
# 激活/停用
# ============================================================================

func try_activate() -> bool:
	"""尝试激活大招
	
	Returns:
		是否成功激活
	"""
	print("[SkillUltimate] try_activate 被调用")
	
	if is_active:
		print("[SkillUltimate] 大招已激活，无法重复激活")
		# 显示飘字提示
		if player_ref:
			Global.spawn_floating_text(player_ref.global_position, "大招激活中", Color.YELLOW)
		return false
	
	if not player_ref:
		printerr("[SkillUltimate] 玩家引用丢失")
		return false
	
	# 检查能量
	if not _check_energy():
		print("[SkillUltimate] 能量不足，无法激活大招")
		# 显示能量不足飘字
		var current_energy = 0.0
		if player_ref.has_method("get_energy_percent"):
			current_energy = player_ref.get_energy_percent()
		Global.spawn_floating_text(
			player_ref.global_position, 
			"能量不足 (%.0f%%/%.0f%%)" % [current_energy, energy_cost], 
			Color.ORANGE_RED
		)
		return false
	
	# 消耗能量
	_consume_energy()
	
	# 激活大招
	_activate()
	
	return true

func _activate() -> void:
	"""内部激活逻辑"""
	is_active = true
	remaining_time = duration
	
	print("[SkillUltimate] 激活大招: %s" % ult_name)
	
	# 添加临时羁绊标签
	if bonus_bond_tag != "":
		BondManager.add_temp_tag(bonus_bond_tag)
	
	# 应用视觉效果
	_apply_visuals()
	
	# 启动计时器
	duration_timer.start(duration)
	
	# 调用子类钩子
	_on_ultimate_activated()
	
	# 发出信号
	ultimate_activated.emit()

func deactivate() -> void:
	"""停用大招"""
	if not is_active:
		return
	
	is_active = false
	remaining_time = 0.0
	
	print("[SkillUltimate] 停用大招: %s" % ult_name)
	
	# 移除临时羁绊标签
	if bonus_bond_tag != "":
		BondManager.remove_temp_tag(bonus_bond_tag)
	
	# 恢复视觉效果
	_restore_visuals()
	
	# 停止计时器
	if duration_timer:
		duration_timer.stop()
	
	# 调用子类钩子
	_on_ultimate_deactivated()
	
	# 发出信号
	ultimate_deactivated.emit()

# ============================================================================
# 能量检查
# ============================================================================

func _check_energy() -> bool:
	"""检查能量是否足够
	
	Returns:
		是否足够
	"""
	if not player_ref or not player_ref.has_method("get_energy_percent"):
		print("[SkillUltimate] 玩家没有 get_energy_percent 方法，默认允许")
		return true  # 如果没有能量系统，默认允许
	
	var energy_percent = player_ref.get_energy_percent()
	print("[SkillUltimate] 当前能量: %.1f%%, 需要: %.1f%%" % [energy_percent, energy_cost])
	return energy_percent >= energy_cost

func _consume_energy() -> void:
	"""消耗能量"""
	if player_ref and player_ref.has_method("consume_energy_percent"):
		# 使用百分比消耗能量
		player_ref.consume_energy_percent(energy_cost)
		print("[SkillUltimate] 消耗能量: %.1f%%" % energy_cost)

# ============================================================================
# 视觉效果
# ============================================================================

func _apply_visuals() -> void:
	"""应用变身视觉效果"""
	if not player_ref:
		return
	
	# 保存原始状态
	original_scale = player_ref.scale
	original_modulate = player_ref.modulate
	
	# 创建缩放动画
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(player_ref, "scale", original_scale * scale_multiplier, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(player_ref, "modulate", visual_color, 0.3).set_trans(Tween.TRANS_SINE)
	
	print("[SkillUltimate] 应用视觉效果: 缩放%.1fx, 颜色%s" % [scale_multiplier, visual_color])

func _restore_visuals() -> void:
	"""恢复原始视觉效果"""
	if not player_ref:
		return
	
	# 创建恢复动画
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(player_ref, "scale", original_scale, 0.3).set_trans(Tween.TRANS_SINE)
	tween.tween_property(player_ref, "modulate", original_modulate, 0.3).set_trans(Tween.TRANS_SINE)
	
	print("[SkillUltimate] 恢复视觉效果")

# ============================================================================
# 更新
# ============================================================================

func _process(delta: float) -> void:
	if not is_active:
		return
	
	remaining_time -= delta
	
	# 发出持续时间变化信号
	ultimate_duration_changed.emit(remaining_time, duration)
	
	# 调用子类更新钩子
	_on_ultimate_update(delta)

# ============================================================================
# 计时器回调
# ============================================================================

func _on_duration_timeout() -> void:
	"""持续时间结束"""
	print("[SkillUltimate] 大招持续时间结束")
	deactivate()

# ============================================================================
# 子类钩子（可重写）
# ============================================================================

func _on_ultimate_activated() -> void:
	"""大招激活时调用（子类重写）"""
	pass

func _on_ultimate_deactivated() -> void:
	"""大招停用时调用（子类重写）"""
	pass

func _on_ultimate_update(delta: float) -> void:
	"""大招激活期间每帧调用（子类重写）"""
	pass

# ============================================================================
# 工具函数
# ============================================================================

func _parse_color(hex: String) -> Color:
	"""解析十六进制颜色
	
	Args:
		hex: 十六进制颜色字符串（如 "#FF3333"）
	
	Returns:
		Color对象
	"""
	if hex.begins_with("#"):
		hex = hex.substr(1)
	
	if hex.length() == 6:
		var r = ("0x" + hex.substr(0, 2)).hex_to_int() / 255.0
		var g = ("0x" + hex.substr(2, 2)).hex_to_int() / 255.0
		var b = ("0x" + hex.substr(4, 2)).hex_to_int() / 255.0
		return Color(r, g, b)
	
	return Color.WHITE

func get_cooldown_progress() -> float:
	"""获取冷却进度（0-1）
	
	Returns:
		进度值
	"""
	if is_active:
		return 0.0  # 激活期间无法再次使用
	
	# 这里可以添加冷却时间逻辑
	return 1.0  # 默认总是可用

func get_status_text() -> String:
	"""获取状态文本
	
	Returns:
		状态描述
	"""
	if is_active:
		return "%s 激活中 (%.1fs)" % [ult_name, remaining_time]
	else:
		return "%s 就绪" % ult_name
