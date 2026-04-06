extends Control
class_name BondHUD

const DEBUG_VERBOSE := false

# ============================================================================
# 缇佺粖 HUD - 宸︿笅瑙掑浘鏍囨樉绀猴紙绾浘鏍囷紝鏃犳枃瀛楋級
# ============================================================================

# 缇佺粖绫诲瀷棰滆壊缂栫爜
const BOND_COLORS = {
	"origin": Color(0.13, 0.55, 0.13),      # 韬笘缇佺粖 - 妫灄缁?
	"mastery": Color(0.86, 0.08, 0.24),     # 鑱岃兘缇佺粖 - 娣辩孩
	"tactic": Color(0.39, 0.58, 0.93)       # 鎴樻湳缇佺粖 - 鐭㈣溅鑿婅摑
}

# 鑺傜偣寮曠敤
@onready var active_container: HBoxContainer = %ActiveBondsContainer
@onready var inactive_container: HBoxContainer = %InactiveBondsContainer

# 鍥炬爣鍦烘櫙
var bond_icon_scene: PackedScene = preload("res://scenes/ui/bond_hud/bond_icon.tscn")

# 褰撳墠鏄剧ず鐨勭緛缁婃暟鎹?
var current_display_data: Dictionary = {}

# ============================================================================
# 鍒濆鍖?
# ============================================================================

func _ready() -> void:
	if DEBUG_VERBOSE: print("[BondHUD] ===== _ready() 寮€濮?=====")
	if DEBUG_VERBOSE: print("[BondHUD] 鑺傜偣璺緞: %s" % get_path())
	if DEBUG_VERBOSE: print("[BondHUD] 鍙鎬? %s" % visible)
	if DEBUG_VERBOSE: print("[BondHUD] 浣嶇疆: %s, 澶у皬: %s" % [position, size])
	
	# 杩炴帴 BondManager 鐨勪俊鍙?
	if BondManager:
		BondManager.bonds_recalculated.connect(_on_bonds_recalculated)
		BondManager.bond_level_changed.connect(_on_bond_level_changed)
		if DEBUG_VERBOSE: print("[BondHUD] 鉁?宸茶繛鎺?BondManager 淇″彿")
		if DEBUG_VERBOSE: print("[BondHUD] BondManager.active_bonds: %s" % str(BondManager.active_bonds.keys()))
		if DEBUG_VERBOSE: print("[BondHUD] BondManager.current_bond_counts: %s" % str(BondManager.current_bond_counts))
	else:
		printerr("[BondHUD] 错误: BondManager 未加载")
		return
	
	# 绛夊緟涓€甯х‘淇濇墍鏈夎妭鐐瑰噯澶囧畬姣?
	await get_tree().process_frame
	
	# 鍒濆鏄剧ず
	if DEBUG_VERBOSE: print("[BondHUD] 璋冪敤 _update_display()...")
	_update_display()
	if DEBUG_VERBOSE: print("[BondHUD] ===== _ready() 瀹屾垚 =====")

# ============================================================================
# 淇″彿澶勭悊
# ============================================================================

func _on_bonds_recalculated(active_bonds: Dictionary) -> void:
	"""BondManager 重新计算羁绊时调用"""
	_update_display()

func _on_bond_level_changed(bond_id: String, old_level: int, new_level: int) -> void:
	"""缇佺粖绛夌骇鍙樺寲鏃剁殑瑙嗚鍙嶉"""
	if new_level > old_level:
		# 鍗囩骇锛氬脊璺冲姩鐢?+ 椋樺瓧 + 闊虫晥
		_play_upgrade_feedback(bond_id, new_level)
	elif new_level < old_level:
		# 闄嶇骇锛氱缉灏忓姩鐢?+ 闄嶇骇鎻愮ず
		_play_downgrade_feedback(bond_id, new_level)

# ============================================================================
# 绛夌骇鍙樺寲瑙嗚鍙嶉
# ============================================================================

func _play_upgrade_feedback(bond_id: String, new_level: int) -> void:
	"""鍗囩骇鍙嶉锛氬浘鏍囧脊璺?+ 灞忓箷涓ぎ椋樺瓧 + 闊虫晥"""
	# 1. 鍥炬爣鏀惧ぇ寮硅烦鍔ㄧ敾
	var icon_node = _find_bond_icon(bond_id)
	if icon_node:
		var tween = create_tween()
		tween.tween_property(icon_node, "scale", Vector2(1.4, 1.4), 0.15).set_ease(Tween.EASE_OUT)
		tween.tween_property(icon_node, "scale", Vector2(0.9, 0.9), 0.1).set_ease(Tween.EASE_IN)
		tween.tween_property(icon_node, "scale", Vector2(1.0, 1.0), 0.1).set_ease(Tween.EASE_OUT)
		icon_node.pivot_offset = icon_node.size / 2.0
	
	# 2. 灞忓箷涓ぎ椋樺瓧
	var display_name = BondManager.get_bond_display_name(bond_id)
	var text = "%s Lv.%d" % [display_name, new_level]
	_show_floating_text(text, Color(1.0, 0.85, 0.2))  # 閲戣壊
	
	# 3. 鎾斁闊虫晥
	if SoundManager:
		SoundManager.play("bond_trigger_generic")

	# 4. Lv3 璐ㄥ彉棰濆鍙嶉锛堜笓灞為煶鐢伙級
	if new_level >= 3:
		_show_floating_text("%s 鍏遍福瑙夐啋!" % display_name, Color(1.2, 1.7, 2.0))
		Global.on_camera_shake.emit(11.0, 0.20)

func _play_downgrade_feedback(bond_id: String, new_level: int) -> void:
	"""闄嶇骇鍙嶉锛氬浘鏍囩缉灏?+ 闄嶇骇鎻愮ず"""
	# 1. 鍥炬爣缂╁皬鍔ㄧ敾
	var icon_node = _find_bond_icon(bond_id)
	if icon_node:
		var tween = create_tween()
		tween.tween_property(icon_node, "scale", Vector2(0.6, 0.6), 0.2).set_ease(Tween.EASE_IN)
		tween.tween_property(icon_node, "scale", Vector2(1.0, 1.0), 0.15).set_ease(Tween.EASE_OUT)
		icon_node.pivot_offset = icon_node.size / 2.0
	
	# 2. 闄嶇骇鎻愮ず椋樺瓧
	var display_name = BondManager.get_bond_display_name(bond_id)
	var text = "%s 闄嶇骇" % display_name if new_level == 0 else "%s Lv.%d" % [display_name, new_level]
	_show_floating_text(text, Color(0.8, 0.3, 0.3))  # 绾㈣壊

func _find_bond_icon(bond_id: String) -> BondIcon:
	"""在容器中查找指定 bond_id 的图标节点"""
	for container in [active_container, inactive_container]:
		for child in container.get_children():
			if child is BondIcon and child.bond_id == bond_id:
				return child
	return null

func _show_floating_text(text: String, color: Color) -> void:
	"""在屏幕中央显示飘字提示"""
	if _is_validation_test_mode_active():
		return
	call_deferred("_spawn_floating_text", text, color)

func _spawn_floating_text(text: String, color: Color) -> void:
	"""延后一帧创建飘字，避免场景切换期间的 add_child 冲突"""
	if _is_validation_test_mode_active():
		return
	if not is_inside_tree():
		return
	var tree := get_tree()
	if tree == null:
		return
	var label = Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 28)
	label.add_theme_color_override("font_color", color)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	
	# 娣诲姞鍒板満鏅爲椤跺眰
	var canvas_layer = tree.root
	canvas_layer.add_child(label)
	
	# 灞呬腑瀹氫綅
	var viewport_size = get_viewport_rect().size
	label.position = Vector2(viewport_size.x / 2.0, viewport_size.y * 0.35)
	label.pivot_offset = label.size / 2.0
	
	# 椋樺瓧鍔ㄧ敾锛氭斁澶у嚭鐜?鈫?涓婇 鈫?娣″嚭
	label.modulate.a = 0.0
	label.scale = Vector2(0.5, 0.5)
	
	var tween = create_tween()
	# 鍑虹幇
	tween.tween_property(label, "modulate:a", 1.0, 0.2)
	tween.parallel().tween_property(label, "scale", Vector2(1.0, 1.0), 0.2).set_ease(Tween.EASE_OUT)
	# 鍋滅暀
	tween.tween_interval(0.8)
	# 涓婇娣″嚭
	tween.tween_property(label, "position:y", label.position.y - 60, 0.5).set_ease(Tween.EASE_IN)
	tween.parallel().tween_property(label, "modulate:a", 0.0, 0.5)
	# 娓呯悊
	tween.tween_callback(label.queue_free)

func _is_validation_test_mode_active() -> bool:
	return (
		(Global != null and Global.has_meta("qef_test_mode_active") and bool(Global.get_meta("qef_test_mode_active")))
		or (Global != null and Global.has_meta("skill_synergy_test_mode_active") and bool(Global.get_meta("skill_synergy_test_mode_active")))
	)

# ============================================================================
# 鏄剧ず鏇存柊
# ============================================================================

func _update_display() -> void:
	"""鏇存柊缇佺粖鏄剧ず"""
	if DEBUG_VERBOSE: print("[BondHUD] ===== _update_display() 寮€濮?=====")
	
	if not BondManager:
		printerr("[BondHUD] 错误: BondManager 不存在")
		return
	
	var active_bonds = BondManager.active_bonds
	var bond_counts = BondManager.current_bond_counts
	
	if DEBUG_VERBOSE: print("[BondHUD] active_bonds 鏁伴噺: %d" % active_bonds.size())
	if DEBUG_VERBOSE: print("[BondHUD] bond_counts 鏁伴噺: %d" % bond_counts.size())
	
	# 濡傛灉娌℃湁浠讳綍缇佺粖鏁版嵁锛屽彂鍑鸿鍛?
	if bond_counts.is_empty():
		if DEBUG_VERBOSE: print("[BondHUD] 鈿狅笍 璀﹀憡: bond_counts 涓虹┖锛屽彲鑳借繕娌℃湁闃熶紞鏁版嵁")
		if DEBUG_VERBOSE: print("[BondHUD] 提示: 请确保在选择界面选择了角色")
		return
	
	# 鐢熸垚鏄剧ず鏁版嵁鐨勫搱甯岋紝鐢ㄤ簬妫€娴嬪彉鍖?
	var display_hash = _generate_display_hash(active_bonds, bond_counts)
	if current_display_data.get("hash", "") == display_hash:
		if DEBUG_VERBOSE: print("[BondHUD] 鏁版嵁鏈彉鍖栵紝璺宠繃鏇存柊")
		return  # 鏁版嵁鏈彉鍖栵紝璺宠繃鏇存柊
	
	current_display_data["hash"] = display_hash
	
	# 娓呯┖鏃у浘鏍?
	_clear_containers()
	
	# 鍒嗙被缇佺粖
	var active_bond_ids: Array = []
	var inactive_bond_ids: Array = []
	
	for bond_id in bond_counts.keys():
		if active_bonds.has(bond_id):
			active_bond_ids.append(bond_id)
		else:
			inactive_bond_ids.append(bond_id)
	
	if DEBUG_VERBOSE: print("[BondHUD] 宸叉縺娲荤緛缁? %s" % str(active_bond_ids))
	if DEBUG_VERBOSE: print("[BondHUD] 鏈縺娲荤緛缁? %s" % str(inactive_bond_ids))
	
	# 鏄剧ず宸叉縺娲荤殑缇佺粖锛堜笂鎺掞級
	for bond_id in active_bond_ids:
		if DEBUG_VERBOSE: print("[BondHUD] 鍒涘缓婵€娲诲浘鏍? %s" % bond_id)
		_create_bond_icon(bond_id, true, active_container)
	
	# 鏄剧ず鏈縺娲讳絾鏈夎繘搴︾殑缇佺粖锛堜笅鎺掞級
	for bond_id in inactive_bond_ids:
		if DEBUG_VERBOSE: print("[BondHUD] 鍒涘缓鏈縺娲诲浘鏍? %s" % bond_id)
		_create_bond_icon(bond_id, false, inactive_container)
	
	if DEBUG_VERBOSE: print("[BondHUD] 鉁?鏇存柊鏄剧ず瀹屾垚: 婵€娲?%d, 鏈縺娲?%d" % [active_bond_ids.size(), inactive_bond_ids.size()])
	if DEBUG_VERBOSE: print("[BondHUD] ===== _update_display() 瀹屾垚 =====")

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
# 鍥炬爣鍒涘缓
# ============================================================================

func _create_bond_icon(bond_id: String, is_active: bool, container: HBoxContainer) -> void:
	"""鍒涘缓缇佺粖鍥炬爣"""
	if DEBUG_VERBOSE: print("[BondHUD] _create_bond_icon: bond_id=%s, is_active=%s" % [bond_id, is_active])
	
	if not BondManager.bond_configs.has(bond_id):
		printerr("[BondHUD] 鉂?閿欒: 鎵句笉鍒扮緛缁婇厤缃? %s" % bond_id)
		return
	
	var bond_config = BondManager.bond_configs[bond_id]
	var bond_type = bond_config.get("bond_type", "origin")
	var display_name = bond_config.get("display_name", bond_id)
	var icon_path_index = bond_config.get("icon_path_index", 1)
	
	# 瀹炰緥鍖栧浘鏍?
	var icon_instance = bond_icon_scene.instantiate() as BondIcon
	if not icon_instance:
		printerr("[BondHUD] 鉂?閿欒: 鏃犳硶瀹炰緥鍖?bond_icon_scene")
		return
	
	container.add_child(icon_instance)
	if DEBUG_VERBOSE: print("[BondHUD] 鉁?鍥炬爣宸叉坊鍔犲埌瀹瑰櫒: %s" % container.name)
	
	# 鑾峰彇缇佺粖鏁版嵁
	var level = 0
	var effect_description = ""
	
	if is_active and BondManager.active_bonds.has(bond_id):
		var bond_data = BondManager.active_bonds[bond_id]
		level = bond_data.get("level", 0)
		effect_description = _get_effect_description(bond_data.get("effects", []))
	
	var current_count = BondManager.current_bond_counts.get(bond_id, 0)
	var required_count = _get_required_count(bond_id, level + 1)
	
	# 鏋勫缓鍥炬爣璺緞
	var icon_path = _get_icon_path(bond_type, icon_path_index)
	if DEBUG_VERBOSE: print("[BondHUD] 鍥炬爣璺緞: %s" % icon_path)
	
	# 璁剧疆鍥炬爣
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
	
	# 璁剧疆杈规棰滆壊
	var border_color = BOND_COLORS.get(bond_type, Color.WHITE)
	icon_instance.set_border_color(border_color)
	
	# 璁剧疆閫忔槑搴?
	if is_active:
		icon_instance.modulate.a = 1.0
	else:
		icon_instance.modulate.a = 0.6
	
	if DEBUG_VERBOSE: print("[BondHUD] 鉁?鍥炬爣璁剧疆瀹屾垚: %s (Lv.%d)" % [display_name, level])

# ============================================================================
# 杈呭姪鍑芥暟
# ============================================================================

func _get_effect_description(effects: Array) -> String:
	"""鑾峰彇鏁堟灉鎻忚堪"""
	if effects.is_empty():
		return ""
	
	var descriptions: Array = []
	for effect in effects:
		# 浼樺厛浣跨敤 CSV 涓殑 description 瀛楁锛堝弸濂界殑涓枃鎻忚堪锛?
		var description = effect.get("description", "")
		if description != "":
			descriptions.append(description)
			continue
		
		# 濡傛灉娌℃湁 description锛屽垯鏍规嵁 effect_type 鐢熸垚鎻忚堪
		var effect_type = effect.get("effect_type", "")
		var effect_param = effect.get("effect_param", "")
		var effect_value = effect.get("effect_value", 0.0)
		
		var desc = ""
		match effect_type:
			"stat_mod":
				# 灞炴€т慨鏀癸紙閫氱敤锛?
				desc = "%s +%.0f" % [_translate_stat_param(effect_param), effect_value]
			"stat_add":
				desc = "%s +%.0f" % [_translate_stat_param(effect_param), effect_value]
			"stat_multiply":
				desc = "%s +%.0f%%" % [_translate_stat_param(effect_param), effect_value * 100]
			"mechanic":
				# 鏈哄埗鏁堟灉锛堜娇鐢ㄥ弬鏁板悕锛?
				desc = "%s" % _translate_mechanic(effect_param)
			"skill_cooldown":
				desc = "鍐峰嵈 %.0f%%" % (effect_value * 100)
			"damage_boost":
				desc = "浼ゅ +%.0f%%" % (effect_value * 100)
			_:
				desc = "%s: %.2f" % [effect_type, effect_value]
		
		descriptions.append(desc)
	
	return "\n".join(descriptions)

func _translate_stat_param(param: String) -> String:
	"""将属性参数名翻译为中文"""
	match param:
		"crit_chance": return "暴击率"
		"crit_damage": return "鏆村嚮浼ゅ"
		"energy_regen": return "鑳介噺鍥炲"
		"cooldown_reduction": return "鍐峰嵈缂╁噺"
		"max_health": return "鐢熷懡涓婇檺"
		"speed": return "绉诲姩閫熷害"
		"armor": return "鎶ょ敳"
		"dodge_chance": return "闪避率"
		"health_regen": return "鐢熷懡鍥炲"
		"projectile_speed": return "寮归亾閫熷害"
		"gold_gain": return "閲戝竵鑾峰彇"
		"exp_gain": return "缁忛獙鑾峰彇"
		_: return param

func _translate_mechanic(mechanic: String) -> String:
	"""灏嗘満鍒跺悕绉扮炕璇戜负涓枃"""
	match mechanic:
		"revive": return "澶嶆椿鏈哄埗"
		"backstab_damage": return "鑳屽埡浼ゅ"
		"thorns_damage": return "鍙嶄激"
		"tech_turret": return "绉戞妧鐐彴"
		"draw_damage_mult": return "鐢诲浘浼ゅ鎻愬崌"
		"draw_explode": return "鍥惧舰鐖嗙偢"
		"speed_to_dmg_ratio": return "速度转伤害"
		"bench_cd_reduce": return "后台冷却加速"
		"mirror_draw": return "闀滃儚浣滅敾"
		"ink_inherit": return "鍥惧舰缁ф壙"
		"switch_reset": return "鍒囨崲閲嶇疆"
		"soul_attach": return "鐏甸瓊闄勭潃"
		"dual_order": return "鍙岄噸鎸囦护"
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
# 鍏叡鎺ュ彛
# ============================================================================

func force_update() -> void:
	"""寮哄埗鏇存柊鏄剧ず"""
	current_display_data.clear()
	_update_display()
