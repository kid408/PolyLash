extends Control
class_name WildcardPanel

signal wildcard_assigned

var emblem_data: Dictionary = {}

@onready var options_container: VBoxContainer = %OptionsContainer

var buttons: Array[Button] = []

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false

func show_wildcard_selection(p_emblem_data: Dictionary) -> void:
	emblem_data = p_emblem_data
	_populate_options()
	visible = true
	print("[WildcardPanel] 显示万能鬼牌选择界面")

func _populate_options() -> void:
	_clear_options()

	var counts: Dictionary = BondManager.current_bond_counts
	var options: Array[Dictionary] = []
	for tag in EmblemManager.VALID_BOND_TAGS:
		var display_name: String = str(BondManager.get_bond_display_name(tag))
		var count: int = int(counts.get(tag, 0))
		var max_level: int = int(BondManager.get_bond_max_level(tag))
		var current_level: int = int(BondManager.get_activated_level(tag, count))
		var next_required: int = _get_next_level_required(tag, current_level, max_level)

		options.append({
			"tag": tag,
			"display_name": display_name,
			"count": count,
			"current_level": current_level,
			"max_level": max_level,
			"next_required": next_required,
			"has_tags": count > 0,
		})

	options.sort_custom(func(a, b):
		if a.has_tags != b.has_tags:
			return a.has_tags
		return a.count > b.count
	)

	for opt in options:
		var btn: Button = Button.new()
		btn.custom_minimum_size = Vector2(380, 40)
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT

		var text: String = "  %s  - %d" % [opt.display_name, opt.count]
		if opt.next_required > 0:
			text += "/%d" % opt.next_required
		if opt.current_level > 0:
			text += "  (Lv.%d)" % opt.current_level
		btn.text = text

		if opt.has_tags:
			btn.add_theme_color_override("font_color", Color(1.0, 0.9, 0.4))
		else:
			btn.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))

		btn.pressed.connect(_on_bond_selected.bind(opt.tag))
		options_container.add_child(btn)
		buttons.append(btn)

func _get_next_level_required(bond_id: String, current_level: int, max_level: int) -> int:
	if current_level >= max_level:
		return 0
	var next_level: int = current_level + 1
	return int(BondManager.get_bond_required_count(bond_id, next_level))

func _clear_options() -> void:
	for btn in buttons:
		if is_instance_valid(btn):
			btn.queue_free()
	buttons.clear()

func _on_bond_selected(bond_tag: String) -> void:
	print("[WildcardPanel] 玩家选择羁绊: %s" % bond_tag)

	var emblem_index: int = _find_emblem_index()
	if emblem_index < 0:
		printerr("[WildcardPanel] 找不到万能鬼牌索引")
		wildcard_assigned.emit()
		return

	EmblemManager.assign_wildcard(emblem_index, bond_tag)
	SoundManager.play("ui_confirm")
	wildcard_assigned.emit()

func _find_emblem_index() -> int:
	var emblem_id: String = str(emblem_data.get("emblem_id", ""))
	for i in range(EmblemManager.held_emblems.size()):
		var e: Dictionary = EmblemManager.held_emblems[i]
		if e.get("is_wildcard", false) and e.get("bond_tag", "") == "wildcard":
			if emblem_id != "" and e.get("emblem_id", "") == emblem_id:
				return i
			return i
	return -1
