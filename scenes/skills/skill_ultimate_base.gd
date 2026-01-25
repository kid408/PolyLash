extends Node
class_name SkillUltimate

# ============================================================================
# 大招技能基类 - F键变身系统
# ============================================================================
# 
# 【设计理念】
# F 键大招是所有角色的通用功能，包含两个核心效果：
# 1. 基础效果：武器获得爆炸效果（AOE伤害）- 所有角色共享
# 2. 角色特色：每个角色可以添加额外的独特效果
# 
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

# 爆炸效果参数（所有角色共享）
# 可以在子类中覆盖这些值以实现不同角色的特色爆炸效果
var explosion_radius: float = 250.0        # 爆炸半径（像素）- 推荐: 200-300
var explosion_damage_scale: float = 1.0   # 爆炸伤害倍率 - 推荐: 0.8-1.2

# 运行时状态
var is_active: bool = false
var remaining_time: float = 0.0
var player_ref: Node = null

# 视觉效果缓存
var original_scale: Vector2 = Vector2.ONE
var original_modulate: Color = Color.WHITE

# 武器爆炸效果缓存
var original_weapon_stats: Dictionary = {}

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
	
	# 从配置读取能量消耗
	if config.has("energy_cost"):
		energy_cost = config.get("energy_cost", 80.0)
	
	# 从配置读取爆炸参数
	if config.has("explosion_radius"):
		explosion_radius = config.get("explosion_radius", 250.0)
	if config.has("explosion_damage_scale"):
		explosion_damage_scale = config.get("explosion_damage_scale", 1.0)
	
	# 解析颜色
	var color_hex = config.get("visual_color_hex", "#FFFFFF")
	visual_color = _parse_color(color_hex)
	
	player_ref = player
	
	# 保存原始视觉状态
	if player_ref:
		original_scale = player_ref.scale
		original_modulate = player_ref.modulate
	
	print("[SkillUltimate] 初始化大招: %s (持续%.1fs, 能量消耗:%.0f%%, 爆炸半径:%.0f, 爆炸倍率:%.1f, 标签:%s)" % [ult_name, duration, energy_cost, explosion_radius, explosion_damage_scale, bonus_bond_tag])

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
	
	# 【核心功能】为所有武器添加爆炸效果
	_apply_explosion_to_weapons()
	
	# 启动计时器
	duration_timer.start(duration)
	
	# 调用子类钩子（角色特色效果）
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
	
	# 移除临时羁绊标签（安全检查）
	if bonus_bond_tag != "" and BondManager:
		# 检查标签是否在临时标签列表中
		var temp_tags = BondManager.get_temp_tags()
		if temp_tags.has(bonus_bond_tag):
			BondManager.remove_temp_tag(bonus_bond_tag)
		else:
			print("[SkillUltimate] 警告: 临时标签 %s 不存在，跳过移除" % bonus_bond_tag)
	
	# 恢复视觉效果
	_restore_visuals()
	
	# 【核心功能】移除所有武器的爆炸效果
	_remove_explosion_from_weapons()
	
	# 停止计时器
	if duration_timer:
		duration_timer.stop()
	
	# 调用子类钩子（角色特色效果）
	_on_ultimate_deactivated()
	
	# 发出信号
	ultimate_deactivated.emit()

# ============================================================================
# 爆炸效果管理（所有角色共享）
# ============================================================================

func _apply_explosion_to_weapons() -> void:
	"""为所有武器添加爆炸效果"""
	print("[SkillUltimate] ========== 开始为武器添加爆炸效果 ==========")
	
	if not player_ref:
		print("[SkillUltimate] ❌ 错误: player_ref 为空")
		return
	
	print("[SkillUltimate] 玩家: %s (类型: %s)" % [player_ref.name, player_ref.get_class()])
	print("[SkillUltimate] 目标爆炸半径: %.1f" % explosion_radius)
	print("[SkillUltimate] 目标爆炸倍率: %.1f" % explosion_damage_scale)
	
	var weapons = _get_player_weapons()
	
	print("[SkillUltimate] 找到 %d 个武器" % weapons.size())
	
	if weapons.size() == 0:
		print("[SkillUltimate] ⚠️ 警告: 玩家没有武器")
		print("[SkillUltimate] 玩家子节点列表:")
		for child in player_ref.get_children():
			var script_path = str(child.get_script()) if child.get_script() else "无脚本"
			print("  - %s (类型: %s, 脚本: %s)" % [child.name, child.get_class(), script_path])
		return
	
	var success_count = 0
	
	for i in range(weapons.size()):
		var weapon = weapons[i]
		print("[SkillUltimate] --- 处理武器 %d/%d ---" % [i + 1, weapons.size()])
		
		if not weapon or not is_instance_valid(weapon):
			print("[SkillUltimate] ❌ 武器无效或已被删除")
			continue
		
		print("[SkillUltimate] 武器名称: %s" % weapon.name)
		print("[SkillUltimate] 武器类型: %s" % weapon.get_class())
		
		if not weapon.data:
			print("[SkillUltimate] ❌ 武器 %s 没有 data 属性" % weapon.name)
			continue
		
		print("[SkillUltimate] 武器 data.item_name: %s" % weapon.data.item_name)
		
		if not weapon.data.stats:
			print("[SkillUltimate] ❌ 武器 %s 没有 stats 属性" % weapon.name)
			continue
		
		var stats = weapon.data.stats as WeaponStats
		
		print("[SkillUltimate] 武器 %s 当前爆炸半径: %.1f" % [weapon.data.item_name, stats.explosion_radius])
		print("[SkillUltimate] 武器 %s 当前爆炸倍率: %.1f" % [weapon.data.item_name, stats.explosion_damage_scale])
		
		# 保存原始属性
		original_weapon_stats[weapon] = {
			"explosion_radius": stats.explosion_radius,
			"explosion_damage_scale": stats.explosion_damage_scale
		}
		
		# 设置爆炸属性
		stats.explosion_radius = explosion_radius
		stats.explosion_damage_scale = explosion_damage_scale
		
		print("[SkillUltimate] ✅ 武器 %s 设置爆炸效果成功" % weapon.data.item_name)
		print("[SkillUltimate]    新爆炸半径: %.1f" % stats.explosion_radius)
		print("[SkillUltimate]    新爆炸倍率: %.1f" % stats.explosion_damage_scale)
		
		success_count += 1
	
	print("[SkillUltimate] ========== 爆炸效果添加完成 ==========")
	print("[SkillUltimate] 成功: %d/%d 个武器" % [success_count, weapons.size()])
	print("[SkillUltimate] 缓存的武器数量: %d" % original_weapon_stats.size())

func _remove_explosion_from_weapons() -> void:
	"""移除所有武器的爆炸效果"""
	for weapon in original_weapon_stats.keys():
		if not weapon or not is_instance_valid(weapon):
			continue
		
		if not weapon.data or not weapon.data.stats:
			continue
		
		var stats = weapon.data.stats as WeaponStats
		var original = original_weapon_stats[weapon]
		
		# 恢复原始值
		stats.explosion_radius = original["explosion_radius"]
		stats.explosion_damage_scale = original["explosion_damage_scale"]
		
		print("[SkillUltimate] 武器 %s 恢复正常" % weapon.data.item_name)
	
	# 清空缓存
	original_weapon_stats.clear()

func _get_player_weapons() -> Array:
	"""获取玩家的所有武器"""
	var weapons: Array = []
	
	if not player_ref:
		print("[SkillUltimate] ❌ player_ref 为空，无法查找武器")
		return weapons
	
	print("[SkillUltimate] ========== 查找武器 ==========")
	
	# 方法1: 通过 current_weapons 数组
	if "current_weapons" in player_ref:
		print("[SkillUltimate] 玩家有 current_weapons 属性")
		var current_weapons = player_ref.current_weapons
		print("[SkillUltimate] current_weapons 类型: %s" % str(typeof(current_weapons)))
		print("[SkillUltimate] current_weapons 大小: %d" % current_weapons.size())
		
		if current_weapons.size() > 0:
			weapons = current_weapons.duplicate()
			print("[SkillUltimate] ✅ 通过 current_weapons 找到 %d 个武器" % weapons.size())
			for i in range(weapons.size()):
				var w = weapons[i]
				if w:
					print("[SkillUltimate]   武器 %d: %s" % [i + 1, w.name])
		else:
			print("[SkillUltimate] ⚠️ current_weapons 为空")
	else:
		print("[SkillUltimate] ⚠️ 玩家没有 current_weapons 属性")
	
	# 方法2: 递归搜索（如果方法1失败）
	if weapons.size() == 0:
		print("[SkillUltimate] current_weapons 为空，尝试递归搜索...")
		weapons = _find_weapons_recursive(player_ref)
		print("[SkillUltimate] 递归搜索找到 %d 个武器" % weapons.size())
	
	print("[SkillUltimate] ========== 查找完成 ==========")
	return weapons

func _find_weapons_recursive(node: Node, depth: int = 0) -> Array:
	"""递归查找所有武器节点"""
	var weapons: Array = []
	var indent = "  ".repeat(depth)
	
	for child in node.get_children():
		var node_class = child.get_class()
		var script_path = str(child.get_script()) if child.get_script() else "无脚本"
		
		print("%s[SkillUltimate] 检查节点: %s (类型: %s)" % [indent, child.name, node_class])
		
		# 检查是否是 Weapon 类
		if node_class == "Weapon":
			print("%s[SkillUltimate] ✅ 找到武器: %s" % [indent, child.name])
			weapons.append(child)
		elif "weapon" in child.name.to_lower() or "Weapon" in script_path:
			print("%s[SkillUltimate] ✅ 找到疑似武器: %s (脚本: %s)" % [indent, child.name, script_path])
			weapons.append(child)
		else:
			# 递归搜索子节点
			var child_weapons = _find_weapons_recursive(child, depth + 1)
			if child_weapons.size() > 0:
				print("%s[SkillUltimate] 在 %s 的子节点中找到 %d 个武器" % [indent, child.name, child_weapons.size()])
				weapons.append_array(child_weapons)
	
	return weapons

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
	"""大招激活时调用（子类重写以添加角色特色效果）"""
	pass

func _on_ultimate_deactivated() -> void:
	"""大招停用时调用（子类重写以移除角色特色效果）"""
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
		hex = hex.substr(1, hex.length() - 1)
	
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
