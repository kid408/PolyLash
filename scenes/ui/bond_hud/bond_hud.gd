extends Control
class_name BondHUD

# ============================================================================
# 羁绊 HUD - 左下角图标显示（纯图标，无文字）
# ============================================================================

# 羁绊类型颜色编码
const BOND_COLORS = {
	"origin": Color(0.13, 0.55, 0.13),      # 身世羁绊 - 森林绿
	"mastery": Color(0.86, 0.08, 0.24),     # 职能羁绊 - 深红
	"tactic": Color(0.39, 0.58, 0.93)       # 战术羁绊 - 矢车菊蓝
}

# 节点引用
@onready var active_container: HBoxContainer = %ActiveBondsContainer
@onready var inactive_container: HBoxContainer = %InactiveBondsContainer

# 图标场景
var bond_icon_scene: PackedScene = preload("res://scenes/ui/bond_hud/bond_icon.tscn")

# 当前显示的羁绊数据
var current_display_data: Dictionary = {}

# ============================================================================
# 初始化
# ============================================================================

func _ready() -> void:
	print("[BondHUD] ===== _ready() 开始 =====")
	print("[BondHUD] 节点路径: %s" % get_path())
	print("[BondHUD] 可见性: %s" % visible)
	print("[BondHUD] 位置: %s, 大小: %s" % [position, size])
	
	# 连接 BondManager 的信号
	if BondManager:
		BondManager.bonds_recalculated.connect(_on_bonds_recalculated)
		BondManager.bond_level_changed.connect(_on_bond_level_changed)
		print("[BondHUD] ✅ 已连接 BondManager 信号")
		print("[BondHUD] BondManager.active_bonds: %s" % str(BondManager.active_bonds.keys()))
		print("[BondHUD] BondManager.current_bond_counts: %s" % str(BondManager.current_bond_counts))
	else:
		printerr("[BondHUD] ❌ 错误: BondManager 未加载")
		return
	
	# 等待一帧确保所有节点准备完毕
	await get_tree().process_frame
	
	# 初始显示
	print("[BondHUD] 调用 _update_display()...")
	_update_display()
	print("[BondHUD] ===== _ready() 完成 =====")

# ============================================================================
# 信号处理
# ============================================================================

func _on_bonds_recalculated(active_bonds: Dictionary) -> void:
	"""BondManager 重新计算羁绊时调用"""
	_update_display()

func _on_bond_level_changed(bond_id: String, old_level: int, new_level: int) -> void:
	"""羁绊等级变化时的视觉反馈"""
	if new_level > old_level:
		# 升级：弹跳动画 + 飘字 + 音效
		_play_upgrade_feedback(bond_id, new_level)
	elif new_level < old_level:
		# 降级：缩小动画 + 降级提示
		_play_downgrade_feedback(bond_id, new_level)

# ============================================================================
# 等级变化视觉反馈
# ============================================================================

func _play_upgrade_feedback(bond_id: String, new_level: int) -> void:
	"""升级反馈：图标弹跳 + 屏幕中央飘字 + 音效"""
	# 1. 图标放大弹跳动画
	var icon_node = _find_bond_icon(bond_id)
	if icon_node:
		var tween = create_tween()
		tween.tween_property(icon_node, "scale", Vector2(1.4, 1.4), 0.15).set_ease(Tween.EASE_OUT)
		tween.tween_property(icon_node, "scale", Vector2(0.9, 0.9), 0.1).set_ease(Tween.EASE_IN)
		tween.tween_property(icon_node, "scale", Vector2(1.0, 1.0), 0.1).set_ease(Tween.EASE_OUT)
		icon_node.pivot_offset = icon_node.size / 2.0
	
	# 2. 屏幕中央飘字
	var display_name = BondManager.get_bond_display_name(bond_id)
	var text = "%s Lv.%d" % [display_name, new_level]
	_show_floating_text(text, Color(1.0, 0.85, 0.2))  # 金色
	
	# 3. 播放音效
	if SoundManager:
		SoundManager.play("bond_trigger_generic")

	# 4. Lv3 质变额外反馈（专属音画）
	if new_level >= 3:
		_show_floating_text("%s 共鸣觉醒!" % display_name, Color(1.2, 1.7, 2.0))
		Global.on_camera_shake.emit(11.0, 0.20)

func _play_downgrade_feedback(bond_id: String, new_level: int) -> void:
	"""降级反馈：图标缩小 + 降级提示"""
	# 1. 图标缩小动画
	var icon_node = _find_bond_icon(bond_id)
	if icon_node:
		var tween = create_tween()
		tween.tween_property(icon_node, "scale", Vector2(0.6, 0.6), 0.2).set_ease(Tween.EASE_IN)
		tween.tween_property(icon_node, "scale", Vector2(1.0, 1.0), 0.15).set_ease(Tween.EASE_OUT)
		icon_node.pivot_offset = icon_node.size / 2.0
	
	# 2. 降级提示飘字
	var display_name = BondManager.get_bond_display_name(bond_id)
	var text = "%s 降级" % display_name if new_level == 0 else "%s Lv.%d" % [display_name, new_level]
	_show_floating_text(text, Color(0.8, 0.3, 0.3))  # 红色

func _find_bond_icon(bond_id: String) -> BondIcon:
	"""在容器中查找指定 bond_id 的图标节点"""
	for container in [active_container, inactive_container]:
		for child in container.get_children():
			if child is BondIcon and child.bond_id == bond_id:
				return child
	return null

func _show_floating_text(text: String, color: Color) -> void:
	"""在屏幕中央显示飘字提示"""
	var label = Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 28)
	label.add_theme_color_override("font_color", color)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	
	# 添加到场景树顶层
	var canvas_layer = get_tree().root
	canvas_layer.add_child(label)
	
	# 居中定位
	var viewport_size = get_viewport_rect().size
	label.position = Vector2(viewport_size.x / 2.0, viewport_size.y * 0.35)
	label.pivot_offset = label.size / 2.0
	
	# 飘字动画：放大出现 → 上飘 → 淡出
	label.modulate.a = 0.0
	label.scale = Vector2(0.5, 0.5)
	
	var tween = create_tween()
	# 出现
	tween.tween_property(label, "modulate:a", 1.0, 0.2)
	tween.parallel().tween_property(label, "scale", Vector2(1.0, 1.0), 0.2).set_ease(Tween.EASE_OUT)
	# 停留
	tween.tween_interval(0.8)
	# 上飘淡出
	tween.tween_property(label, "position:y", label.position.y - 60, 0.5).set_ease(Tween.EASE_IN)
	tween.parallel().tween_property(label, "modulate:a", 0.0, 0.5)
	# 清理
	tween.tween_callback(label.queue_free)

# ============================================================================
# 显示更新
# ============================================================================

func _update_display() -> void:
	"""更新羁绊显示"""
	print("[BondHUD] ===== _update_display() 开始 =====")
	
	if not BondManager:
		printerr("[BondHUD] ❌ BondManager 不存在")
		return
	
	var active_bonds = BondManager.active_bonds
	var bond_counts = BondManager.current_bond_counts
	
	print("[BondHUD] active_bonds 数量: %d" % active_bonds.size())
	print("[BondHUD] bond_counts 数量: %d" % bond_counts.size())
	
	# 如果没有任何羁绊数据，发出警告
	if bond_counts.is_empty():
		print("[BondHUD] ⚠️ 警告: bond_counts 为空，可能还没有队伍数据")
		print("[BondHUD] 提示: 请确保在选择界面选择了角色")
		return
	
	# 生成显示数据的哈希，用于检测变化
	var display_hash = _generate_display_hash(active_bonds, bond_counts)
	if current_display_data.get("hash", "") == display_hash:
		print("[BondHUD] 数据未变化，跳过更新")
		return  # 数据未变化，跳过更新
	
	current_display_data["hash"] = display_hash
	
	# 清空旧图标
	_clear_containers()
	
	# 分类羁绊
	var active_bond_ids: Array = []
	var inactive_bond_ids: Array = []
	
	for bond_id in bond_counts.keys():
		if active_bonds.has(bond_id):
			active_bond_ids.append(bond_id)
		else:
			inactive_bond_ids.append(bond_id)
	
	print("[BondHUD] 已激活羁绊: %s" % str(active_bond_ids))
	print("[BondHUD] 未激活羁绊: %s" % str(inactive_bond_ids))
	
	# 显示已激活的羁绊（上排）
	for bond_id in active_bond_ids:
		print("[BondHUD] 创建激活图标: %s" % bond_id)
		_create_bond_icon(bond_id, true, active_container)
	
	# 显示未激活但有进度的羁绊（下排）
	for bond_id in inactive_bond_ids:
		print("[BondHUD] 创建未激活图标: %s" % bond_id)
		_create_bond_icon(bond_id, false, inactive_container)
	
	print("[BondHUD] ✅ 更新显示完成: 激活=%d, 未激活=%d" % [active_bond_ids.size(), inactive_bond_ids.size()])
	print("[BondHUD] ===== _update_display() 完成 =====")

func _generate_display_hash(active_bonds: Dictionary, bond_counts: Dictionary) -> String:
	"""生成显示数据的哈希值"""
	var hash_parts: Array = []
	
	for bond_id in active_bonds.keys():
		var level = active_bonds[bond_id].get("level", 0)
		hash_parts.append("%s:%d" % [bond_id, level])
	
	for bond_id in bond_counts.keys():
		if not active_bonds.has(bond_id):
			hash_parts.append("%s:%d" % [bond_id, bond_counts[bond_id]])
	
	hash_parts.sort()
	return ",".join(hash_parts)

func _clear_containers() -> void:
	"""清空所有容器"""
	for child in active_container.get_children():
		child.queue_free()
	for child in inactive_container.get_children():
		child.queue_free()

# ============================================================================
# 图标创建
# ============================================================================

func _create_bond_icon(bond_id: String, is_active: bool, container: HBoxContainer) -> void:
	"""创建羁绊图标"""
	print("[BondHUD] _create_bond_icon: bond_id=%s, is_active=%s" % [bond_id, is_active])
	
	if not BondManager.bond_configs.has(bond_id):
		printerr("[BondHUD] ❌ 错误: 找不到羁绊配置: %s" % bond_id)
		return
	
	var bond_config = BondManager.bond_configs[bond_id]
	var bond_type = bond_config.get("bond_type", "origin")
	var display_name = bond_config.get("display_name", bond_id)
	var icon_path_index = bond_config.get("icon_path_index", 1)
	
	# 实例化图标
	var icon_instance = bond_icon_scene.instantiate() as BondIcon
	if not icon_instance:
		printerr("[BondHUD] ❌ 错误: 无法实例化 bond_icon_scene")
		return
	
	container.add_child(icon_instance)
	print("[BondHUD] ✅ 图标已添加到容器: %s" % container.name)
	
	# 获取羁绊数据
	var level = 0
	var effect_description = ""
	
	if is_active and BondManager.active_bonds.has(bond_id):
		var bond_data = BondManager.active_bonds[bond_id]
		level = bond_data.get("level", 0)
		effect_description = _get_effect_description(bond_data.get("effects", []))
	
	var current_count = BondManager.current_bond_counts.get(bond_id, 0)
	var required_count = _get_required_count(bond_id, level + 1)
	
	# 构建图标路径
	var icon_path = _get_icon_path(bond_type, icon_path_index)
	print("[BondHUD] 图标路径: %s" % icon_path)
	
	# 设置图标
	icon_instance.setup(
		bond_id,
		display_name,
		bond_type,
		level,
		current_count,
		required_count,
		icon_path,
		effect_description,
		is_active
	)
	
	# 设置边框颜色
	var border_color = BOND_COLORS.get(bond_type, Color.WHITE)
	icon_instance.set_border_color(border_color)
	
	# 设置透明度
	if is_active:
		icon_instance.modulate.a = 1.0
	else:
		icon_instance.modulate.a = 0.6
	
	print("[BondHUD] ✅ 图标设置完成: %s (Lv.%d)" % [display_name, level])

# ============================================================================
# 辅助函数
# ============================================================================

func _get_effect_description(effects: Array) -> String:
	"""获取效果描述"""
	if effects.is_empty():
		return ""
	
	var descriptions: Array = []
	for effect in effects:
		# 优先使用 CSV 中的 description 字段（友好的中文描述）
		var description = effect.get("description", "")
		if description != "":
			descriptions.append(description)
			continue
		
		# 如果没有 description，则根据 effect_type 生成描述
		var effect_type = effect.get("effect_type", "")
		var effect_param = effect.get("effect_param", "")
		var effect_value = effect.get("effect_value", 0.0)
		
		var desc = ""
		match effect_type:
			"stat_mod":
				# 属性修改（通用）
				desc = "%s +%.0f" % [_translate_stat_param(effect_param), effect_value]
			"stat_add":
				desc = "%s +%.0f" % [_translate_stat_param(effect_param), effect_value]
			"stat_multiply":
				desc = "%s +%.0f%%" % [_translate_stat_param(effect_param), effect_value * 100]
			"mechanic":
				# 机制效果（使用参数名）
				desc = "%s" % _translate_mechanic(effect_param)
			"skill_cooldown":
				desc = "冷却 %.0f%%" % (effect_value * 100)
			"damage_boost":
				desc = "伤害 +%.0f%%" % (effect_value * 100)
			_:
				desc = "%s: %.2f" % [effect_type, effect_value]
		
		descriptions.append(desc)
	
	return "\n".join(descriptions)

func _translate_stat_param(param: String) -> String:
	"""将属性参数名翻译为中文"""
	match param:
		"crit_chance": return "暴击率"
		"crit_damage": return "暴击伤害"
		"energy_regen": return "能量回复"
		"cooldown_reduction": return "冷却缩减"
		"max_health": return "生命上限"
		"speed": return "移动速度"
		"armor": return "护甲"
		"dodge_chance": return "闪避率"
		"health_regen": return "生命回复"
		"projectile_speed": return "弹道速度"
		"gold_gain": return "金币获取"
		"exp_gain": return "经验获取"
		_: return param

func _translate_mechanic(mechanic: String) -> String:
	"""将机制名称翻译为中文"""
	match mechanic:
		"revive": return "复活机制"
		"backstab_damage": return "背刺伤害"
		"thorns_damage": return "反伤"
		"tech_turret": return "科技炮台"
		"draw_damage_mult": return "画图伤害提升"
		"draw_explode": return "图形爆炸"
		"speed_to_dmg_ratio": return "速度转伤害"
		"bench_cd_reduce": return "后台冷却加速"
		"mirror_draw": return "镜像作画"
		"ink_inherit": return "图形继承"
		"switch_reset": return "切换重置"
		"soul_attach": return "灵魂附着"
		"dual_order": return "双重指令"
		_: return mechanic

func _get_required_count(bond_id: String, level: int) -> int:
	"""获取指定等级所需的标签数量"""
	if not BondManager.bond_configs.has(bond_id):
		return 0
	
	var bond_config = BondManager.bond_configs[bond_id]
	var levels = bond_config.get("levels", [])
	
	for level_data in levels:
		if level_data.get("level", 0) == level:
			return level_data.get("required_count", 0)
	
	return 0

func _get_icon_path(bond_type: String, icon_index: int) -> String:
	"""根据羁绊类型和索引构建图标路径"""
	var folder = ""
	var prefix = ""
	
	match bond_type:
		"origin":
			folder = "origins"
			prefix = "origin"
		"mastery":
			folder = "masterys"
			prefix = "mastery"
		"tactic":
			folder = "tactics"
			prefix = "tactic"
		_:
			folder = "origins"
			prefix = "origin"
	
	return "res://assets/sprites/Icons/%s/%s%d.png" % [folder, prefix, icon_index]

# ============================================================================
# 公共接口
# ============================================================================

func force_update() -> void:
	"""强制更新显示"""
	current_display_data.clear()
	_update_display()
