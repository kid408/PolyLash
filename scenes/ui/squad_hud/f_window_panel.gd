extends PanelContainer
class_name FWindowPanel

@onready var mode_label: Label = $MarginContainer/VBoxContainer/HeaderRow/ModeLabel
@onready var timer_label: Label = $MarginContainer/VBoxContainer/HeaderRow/TimerLabel
@onready var timer_bar: ProgressBar = $MarginContainer/VBoxContainer/TimerBar
@onready var pickup_label: Label = $MarginContainer/VBoxContainer/InfoRow/PickupLabel
@onready var e_slot_label: Label = $MarginContainer/VBoxContainer/SlotRow/ESlot
@onready var q_slot_label: Label = $MarginContainer/VBoxContainer/SlotRow/QSlot
@onready var link_band: Label = $MarginContainer/VBoxContainer/SlotRow/LinkBand
@onready var utility_label: Label = $MarginContainer/VBoxContainer/InfoRow/UtilityLabel
@onready var reveal_layer: Control = $RevealLayer

var _panel_target_visible: bool = false
var _visibility_tween: Tween = null
var _style_tweens: Dictionary = {}
var _link_tween: Tween = null
var _link_visible: bool = false
var _reveal_tween: Tween = null
var _last_opened_counts: Dictionary = {}

func _ready() -> void:
	visible = false
	modulate.a = 0.0
	scale = Vector2(0.98, 0.98)
	if utility_label != null:
		utility_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if link_band != null:
		link_band.visible = false
		link_band.modulate.a = 0.0
		link_band.scale = Vector2(0.96, 0.96)

func update_runtime(player_id: String, runtime: Dictionary) -> void:
	var active: bool = bool(runtime.get("active", false))
	var slot_e: Dictionary = runtime.get("slot_e", {}) if runtime.get("slot_e", {}) is Dictionary else {}
	var slot_q: Dictionary = runtime.get("slot_q", {}) if runtime.get("slot_q", {}) is Dictionary else {}
	var pickup_count: int = max(0, int(runtime.get("active_pickup_count", 0)))
	var unopened_count: int = max(0, int(runtime.get("unopened_count", 0)))
	var has_utility: bool = _has_utility_payload(runtime)
	var has_payload: bool = (
		active
		or pickup_count > 0
		or unopened_count > 0
		or _slot_is_active(slot_e)
		or _slot_is_active(slot_q)
		or has_utility
	)

	_set_panel_visible(has_payload)
	if not has_payload:
		_set_link_visible(false)
		return

	var mode_name: String = str(runtime.get("mode_name", player_id)).strip_edges()
	var time_left: float = max(0.0, float(runtime.get("time_left", 0.0)))
	var duration: float = max(0.01, float(runtime.get("duration", 10.0)))

	mode_label.text = "%s F" % mode_name
	timer_label.text = "%.1fs" % time_left
	timer_bar.max_value = duration
	timer_bar.value = time_left
	pickup_label.text = "未开 %d/2 · 场上 %d" % [min(2, unopened_count), pickup_count]
	e_slot_label.text = _build_slot_text("E", slot_e)
	q_slot_label.text = _build_slot_text("Q闭合", slot_q)
	utility_label.text = _build_utility_text(runtime)

	_apply_slot_visual(e_slot_label, slot_e)
	_apply_slot_visual(q_slot_label, slot_q)
	_set_link_visible(bool(runtime.get("jackpot_linked", false)) and _slot_is_active(slot_e) and _slot_is_active(slot_q))
	_maybe_play_reveal(player_id, runtime)

func _set_panel_visible(should_show: bool) -> void:
	if _panel_target_visible == should_show:
		return

	_panel_target_visible = should_show
	if _visibility_tween != null:
		_visibility_tween.kill()

	_visibility_tween = create_tween()
	if should_show:
		visible = true
		_visibility_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		_visibility_tween.tween_property(self, "modulate:a", 1.0, 0.14)
		_visibility_tween.parallel().tween_property(self, "scale", Vector2.ONE, 0.14)
		return

	_visibility_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	_visibility_tween.tween_property(self, "modulate:a", 0.0, 0.12)
	_visibility_tween.parallel().tween_property(self, "scale", Vector2(0.98, 0.98), 0.12)
	_visibility_tween.finished.connect(_on_hide_transition_finished, CONNECT_ONE_SHOT)

func _on_hide_transition_finished() -> void:
	if _panel_target_visible:
		return
	visible = false
	_clear_reveal_layer()

func _slot_is_active(slot_var: Variant) -> bool:
	if not (slot_var is Dictionary):
		return false
	return bool((slot_var as Dictionary).get("active", false))

func _build_slot_text(slot_name: String, slot_var: Variant) -> String:
	if not (slot_var is Dictionary):
		return "%s: 空" % slot_name

	var slot: Dictionary = slot_var
	if not bool(slot.get("active", false)):
		return "%s: 空" % slot_name

	var display_name: String = str(slot.get("display_name", "")).strip_edges()
	if display_name.is_empty():
		display_name = str(slot.get("reward_id", "已装载")).strip_edges()
	return "%s: %s · %s" % [slot_name, display_name, _format_rarity(str(slot.get("rarity", "")))]

func _build_utility_text(runtime: Dictionary) -> String:
	var lines: Array = []
	if bool(runtime.get("jackpot_linked", false)):
		lines.append("联结头奖待命")

	var pending_target: String = str(runtime.get("pending_free_cost_target", "")).strip_edges().to_lower()
	if pending_target == "e":
		lines.append("免费次：下一次 E")
	elif pending_target == "q_close":
		lines.append("免费次：下一次 Q闭合")

	var utilities: Array = runtime.get("utility_buff_list", []) if runtime.get("utility_buff_list", []) is Array else []
	if utilities.is_empty():
		var utility: Dictionary = runtime.get("utility_buff", {}) if runtime.get("utility_buff", {}) is Dictionary else {}
		if not utility.is_empty():
			utilities.append(utility)

	for i in range(max(0, utilities.size() - 3), utilities.size()):
		var utility_var: Variant = utilities[i]
		if not (utility_var is Dictionary):
			continue
		var utility: Dictionary = utility_var
		var display_name: String = str(utility.get("display_name", "")).strip_edges()
		if display_name.is_empty():
			display_name = str(utility.get("reward_id", "短时增益")).strip_edges()
		lines.append("Buff：%s" % display_name)

	if lines.is_empty():
		var pickup_count: int = max(0, int(runtime.get("active_pickup_count", 0)))
		if pickup_count > 0:
			return "提示：场上有待拾取封包"
		return "当前无短时增益"

	while lines.size() > 3:
		lines.remove_at(0)
	return "\n".join(lines)

func _has_utility_payload(runtime: Dictionary) -> bool:
	if str(runtime.get("pending_free_cost_target", "")).strip_edges() != "":
		return true
	if bool(runtime.get("jackpot_linked", false)):
		return true
	var utility: Dictionary = runtime.get("utility_buff", {}) if runtime.get("utility_buff", {}) is Dictionary else {}
	if not utility.is_empty():
		return true
	var utility_list: Array = runtime.get("utility_buff_list", []) if runtime.get("utility_buff_list", []) is Array else []
	return not utility_list.is_empty()

func _apply_slot_visual(label: Label, slot_var: Variant) -> void:
	if label == null:
		return

	var color: Color = Color(0.78, 0.8, 0.86, 0.9)
	var target_scale: Vector2 = Vector2.ONE
	if slot_var is Dictionary and bool((slot_var as Dictionary).get("active", false)):
		color = _rarity_color(str((slot_var as Dictionary).get("rarity", "")))
		target_scale = Vector2(1.02, 1.02)

	_tween_canvas_style(label, color, target_scale)

func _set_link_visible(should_show: bool) -> void:
	if link_band == null or _link_visible == should_show:
		return

	_link_visible = should_show
	if _link_tween != null:
		_link_tween.kill()

	_link_tween = create_tween()
	if should_show:
		link_band.visible = true
		link_band.modulate = Color(1.0, 0.9, 0.4, 0.0)
		link_band.scale = Vector2(0.96, 0.96)
		link_band.text = "联结头奖"
		_link_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		_link_tween.tween_property(link_band, "modulate:a", 1.0, 0.14)
		_link_tween.parallel().tween_property(link_band, "scale", Vector2.ONE, 0.14)
		return

	_link_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	_link_tween.tween_property(link_band, "modulate:a", 0.0, 0.12)
	_link_tween.parallel().tween_property(link_band, "scale", Vector2(0.96, 0.96), 0.12)
	_link_tween.finished.connect(_on_link_hide_finished, CONNECT_ONE_SHOT)

func _on_link_hide_finished() -> void:
	if _link_visible or link_band == null:
		return
	link_band.visible = false

func _tween_canvas_style(item: CanvasItem, target_color: Color, target_scale: Vector2, duration: float = 0.14) -> void:
	if item == null:
		return

	var key: int = item.get_instance_id()
	if _style_tweens.has(key):
		var old_tween: Tween = _style_tweens[key]
		if old_tween != null:
			old_tween.kill()

	var tween: Tween = create_tween()
	_style_tweens[key] = tween
	tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(item, "modulate", target_color, duration)
	if item is Control:
		tween.parallel().tween_property(item, "scale", target_scale, duration)

func _maybe_play_reveal(player_id: String, runtime: Dictionary) -> void:
	if player_id.strip_edges().is_empty():
		return

	var opened_count: int = max(0, int(runtime.get("opened_pack_count", 0)))
	if not _last_opened_counts.has(player_id):
		_last_opened_counts[player_id] = opened_count
		return

	var previous_count: int = int(_last_opened_counts.get(player_id, 0))
	_last_opened_counts[player_id] = opened_count
	if opened_count <= previous_count:
		return

	var reward: Dictionary = runtime.get("last_reward", {}) if runtime.get("last_reward", {}) is Dictionary else {}
	if reward.is_empty():
		return
	_show_reveal(reward)

func _show_reveal(reward: Dictionary) -> void:
	if reveal_layer == null:
		return

	for child in reveal_layer.get_children():
		child.queue_free()
	if _reveal_tween != null:
		_reveal_tween.kill()

	var reveal_bar := PanelContainer.new()
	reveal_bar.name = "RevealBar"
	var reveal_text: String = _build_reveal_text(reward)
	var bar_width: float = clamp(160.0 + float(reveal_text.length()) * 12.0, 220.0, 420.0)
	reveal_bar.custom_minimum_size = Vector2(bar_width, 30.0)
	reveal_bar.size = reveal_bar.custom_minimum_size
	reveal_bar.position = Vector2(
		max(10.0, (reveal_layer.size.x - reveal_bar.size.x) * 0.5),
		12.0
	)
	reveal_bar.modulate = Color(1.0, 1.0, 1.0, 0.0)
	reveal_bar.scale = Vector2(0.94, 0.94)

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.09, 0.1, 0.13, 0.9)
	style.border_color = _rarity_color(str(reward.get("rarity", "")))
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_right = 8
	style.corner_radius_bottom_left = 8
	reveal_bar.add_theme_stylebox_override("panel", style)

	var label := Label.new()
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.text = reveal_text
	reveal_bar.add_child(label)

	reveal_layer.add_child(reveal_bar)

	var target_control: Control = _resolve_reveal_target(str(reward.get("target_slot", "")))
	var end_pos: Vector2 = reveal_bar.position + Vector2(0.0, 8.0)
	if target_control != null:
		var target_center: Vector2 = target_control.global_position - reveal_layer.global_position + target_control.size * 0.5
		end_pos = target_center - reveal_bar.size * 0.5

	_reveal_tween = create_tween()
	_reveal_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_reveal_tween.tween_property(reveal_bar, "modulate:a", 1.0, 0.14)
	_reveal_tween.parallel().tween_property(reveal_bar, "scale", Vector2.ONE, 0.14)
	_reveal_tween.tween_interval(0.18)
	_reveal_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_reveal_tween.tween_property(reveal_bar, "position", end_pos, 0.2)
	_reveal_tween.parallel().tween_property(reveal_bar, "modulate:a", 0.0, 0.18)
	_reveal_tween.finished.connect(_clear_reveal_layer, CONNECT_ONE_SHOT)

func _clear_reveal_layer() -> void:
	if reveal_layer == null:
		return
	for child in reveal_layer.get_children():
		child.queue_free()


func _build_reveal_text(reward: Dictionary) -> String:
	var display_name: String = str(reward.get("display_name", "")).strip_edges()
	if display_name.is_empty():
		display_name = str(reward.get("reward_id", "封包结果")).strip_edges()

	var target_slot: String = str(reward.get("target_slot", "")).strip_edges().to_lower()
	var suffix: String = "立即生效"
	if target_slot == "e":
		suffix = "装入 E"
	elif target_slot == "q_close":
		suffix = "装入 Q闭合"
	elif target_slot == "linked":
		suffix = "联结双槽"
	return "%s  ->  %s" % [display_name, suffix]

func _resolve_reveal_target(target_slot: String) -> Control:
	match target_slot.strip_edges().to_lower():
		"e":
			return e_slot_label
		"q_close":
			return q_slot_label
		"linked":
			return q_slot_label
		_:
			return null

func _format_rarity(rarity: String) -> String:
	match rarity.strip_edges().to_lower():
		"common":
			return "普通"
		"uncommon":
			return "优良"
		"rare":
			return "稀有"
		"epic":
			return "史诗"
		"legendary":
			return "传奇"
		"mythic":
			return "神话"
		_:
			return "装载"

func _rarity_color(rarity: String) -> Color:
	match rarity.strip_edges().to_lower():
		"uncommon":
			return Color(0.55, 0.88, 0.56, 1.0)
		"rare":
			return Color(0.52, 0.78, 1.0, 1.0)
		"epic":
			return Color(0.92, 0.62, 1.0, 1.0)
		"legendary":
			return Color(1.0, 0.82, 0.42, 1.0)
		"mythic":
			return Color(1.0, 0.54, 0.54, 1.0)
		_:
			return Color(0.9, 0.92, 0.98, 1.0)
