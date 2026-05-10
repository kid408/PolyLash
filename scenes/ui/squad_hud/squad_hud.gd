extends Control
class_name SquadHUD

signal slot_clicked(index: int)

@onready var slots_container: HBoxContainer = $VBoxContainer/SlotsContainer
@onready var f_window_panel: FWindowPanel = $VBoxContainer/FWindowPanel
@onready var energy_bar: ProgressBar = $VBoxContainer/EnergyBar
@onready var energy_label: Label = $VBoxContainer/EnergyBar/EnergyLabel

var character_slots: Array[CharacterSlot] = []

const CHARACTER_SLOT_SCENE = preload("res://scenes/ui/squad_hud/character_slot.tscn")

func _ready() -> void:
	Global.on_active_character_changed.connect(_on_active_character_changed)
	Global.on_switch_rejected.connect(_on_switch_rejected)
	Global.on_squad_state_changed.connect(_on_squad_state_changed)
	Global.on_f_runtime_changed.connect(_on_f_runtime_changed)

func _process(_delta: float) -> void:
	_update_active_energy()
	_update_all_character_states()

func init_squad(player_ids: Array[String]) -> void:
	for slot: CharacterSlot in character_slots:
		if is_instance_valid(slot):
			slot.queue_free()
	character_slots.clear()

	for i in range(min(player_ids.size(), 3)):
		var slot := CHARACTER_SLOT_SCENE.instantiate() as CharacterSlot
		slots_container.add_child(slot)
		slot.setup(player_ids[i], i + 1)
		slot.clicked.connect(_on_slot_clicked.bind(i))
		character_slots.append(slot)

	if not character_slots.is_empty():
		var active_index: int = clamp(Global.current_player_index, 0, character_slots.size() - 1)
		set_active_character(active_index)

	print("[SquadHUD] initialized %d character slots" % character_slots.size())

func update_character_state(index: int, health: float, max_health: float, energy: float, max_energy: float, is_dead: bool) -> void:
	if index < 0 or index >= character_slots.size():
		return

	var slot: CharacterSlot = character_slots[index]
	if not is_instance_valid(slot):
		return

	slot.update_health(health, max_health)
	slot.update_energy(energy, max_energy)
	slot.set_dead(is_dead)

func update_character_f_runtime(index: int, f_runtime: Dictionary) -> void:
	if index < 0 or index >= character_slots.size():
		return

	var slot: CharacterSlot = character_slots[index]
	if is_instance_valid(slot):
		slot.update_f_runtime(f_runtime)

func set_active_character(index: int) -> void:
	for i in range(character_slots.size()):
		var slot: CharacterSlot = character_slots[i]
		if is_instance_valid(slot):
			slot.set_active(i == index)

func update_energy(current: float, max_energy: float) -> void:
	if energy_bar:
		energy_bar.max_value = max_energy
		energy_bar.value = current

	if energy_label:
		energy_label.text = "%d / %d" % [int(current), int(max_energy)]

func play_invalid_feedback(index: int) -> void:
	if index < 0 or index >= character_slots.size():
		return

	var slot: CharacterSlot = character_slots[index]
	if is_instance_valid(slot):
		slot.play_shake_animation()

func _update_active_energy() -> void:
	if is_instance_valid(Global.player):
		update_energy(Global.player.energy, Global.player.max_energy)

func _update_all_character_states() -> void:
	_ensure_squad_slots()

	if is_instance_valid(Global.player):
		var current_id: String = Global.player.player_id
		if Global.player_states.has(current_id):
			Global.player_states[current_id].health = Global.player.health_component.current_health
			Global.player_states[current_id].max_health = Global.player.health_component.max_health
			Global.player_states[current_id].energy = Global.player.energy
			Global.player_states[current_id].max_energy = Global.player.max_energy

	for i in range(character_slots.size()):
		_sync_slot_identity(i)
		var state: Dictionary = Global.get_player_state_by_index(i)
		if state.is_empty():
			continue

		var health: float = float(state.get("health", 0))
		var max_health: float = float(state.get("max_health", 100))
		var energy: float = float(state.get("energy", 0))
		var max_energy: float = float(state.get("max_energy", 999))
		var is_dead: bool = health <= 0

		update_character_state(i, health, max_health, energy, max_energy, is_dead)
		update_character_f_runtime(i, state.get("f_runtime", {}) if state.get("f_runtime", {}) is Dictionary else {})

	_update_active_f_window()

func _update_active_f_window() -> void:
	if not is_instance_valid(f_window_panel):
		return

	var active_id: String = Global.get_current_player_id()
	if active_id.is_empty():
		f_window_panel.visible = false
		return

	f_window_panel.update_runtime(active_id, Global.get_player_f_runtime(active_id))

func _on_active_character_changed(index: int) -> void:
	_ensure_squad_slots()
	set_active_character(index)
	_update_active_f_window()

func _on_switch_rejected(index: int, reason: String) -> void:
	if reason == "dead":
		play_invalid_feedback(index)

func _on_squad_state_changed(index: int, state: Dictionary) -> void:
	_ensure_squad_slots()
	_sync_slot_identity(index)

	var health: float = float(state.get("health", 0))
	var max_health: float = float(state.get("max_health", 100))
	var energy: float = float(state.get("energy", 0))
	var max_energy: float = float(state.get("max_energy", 999))
	var is_dead: bool = health <= 0

	update_character_state(index, health, max_health, energy, max_energy, is_dead)
	update_character_f_runtime(index, state.get("f_runtime", {}) if state.get("f_runtime", {}) is Dictionary else {})
	_update_active_f_window()

func _on_f_runtime_changed(player_id: String, f_runtime: Dictionary) -> void:
	var index: int = Global.selected_player_ids.find(player_id)
	if index >= 0:
		update_character_f_runtime(index, f_runtime)
	if player_id == Global.get_current_player_id():
		_update_active_f_window()

func _on_slot_clicked(index: int) -> void:
	slot_clicked.emit(index)
	Global.switch_to_player_by_index(index)

func _ensure_squad_slots() -> void:
	var expected_count: int = min(Global.selected_player_ids.size(), 3)
	if character_slots.size() == expected_count:
		return
	init_squad(Global.selected_player_ids)

func _sync_slot_identity(index: int) -> void:
	if index < 0 or index >= character_slots.size():
		return

	var expected_player_id: String = Global.get_player_id_by_index(index)
	if expected_player_id.is_empty():
		return

	var slot: CharacterSlot = character_slots[index]
	if not is_instance_valid(slot):
		return

	slot.refresh_player_identity(expected_player_id)
