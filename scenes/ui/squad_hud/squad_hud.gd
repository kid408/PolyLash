extends Control
class_name SquadHUD

signal slot_clicked(index: int)

# UI 节点引用
@onready var slots_container: HBoxContainer = $VBoxContainer/SlotsContainer
@onready var energy_bar: ProgressBar = $VBoxContainer/EnergyBar
@onready var energy_label: Label = $VBoxContainer/EnergyBar/EnergyLabel

# 角色卡槽数组
var character_slots: Array[CharacterSlot] = []

# 预加载卡槽场景
const CHARACTER_SLOT_SCENE = preload("res://scenes/ui/squad_hud/character_slot.tscn")

func _ready() -> void:
	# 连接 Global 信号
	Global.on_active_character_changed.connect(_on_active_character_changed)
	Global.on_switch_rejected.connect(_on_switch_rejected)
	Global.on_squad_state_changed.connect(_on_squad_state_changed)

func _process(_delta: float) -> void:
	# 实时更新当前角色的能量条
	_update_active_energy()
	# 实时更新所有角色状态
	_update_all_character_states()

# 初始化小队显示
func init_squad(player_ids: Array[String]) -> void:
	# 清除现有卡槽
	for slot in character_slots:
		if is_instance_valid(slot):
			slot.queue_free()
	character_slots.clear()
	
	# 创建新卡槽
	for i in range(player_ids.size()):
		if i >= 3:  # 最多 3 个卡槽
			break
		
		var slot = CHARACTER_SLOT_SCENE.instantiate() as CharacterSlot
		slots_container.add_child(slot)
		slot.setup(player_ids[i], i + 1)  # 按键 1, 2, 3
		
		# 连接点击信号
		slot.clicked.connect(_on_slot_clicked.bind(i))
		
		character_slots.append(slot)
	
	# 设置第一个为激活状态
	if character_slots.size() > 0:
		set_active_character(0)
	
	print("[SquadHUD] 初始化 %d 个角色卡槽" % character_slots.size())

# 更新角色状态（血量和能量）
func update_character_state(index: int, health: float, max_health: float, energy: float, max_energy: float, is_dead: bool) -> void:
	if index < 0 or index >= character_slots.size():
		return
	
	var slot = character_slots[index]
	if not is_instance_valid(slot):
		return
	
	slot.update_health(health, max_health)
	slot.update_energy(energy, max_energy)
	slot.set_dead(is_dead)

# 设置当前激活角色
func set_active_character(index: int) -> void:
	for i in range(character_slots.size()):
		var slot = character_slots[i]
		if is_instance_valid(slot):
			slot.set_active(i == index)

# 更新能量条
func update_energy(current: float, max_energy: float) -> void:
	if energy_bar:
		energy_bar.max_value = max_energy
		energy_bar.value = current
	
	if energy_label:
		energy_label.text = "%d / %d" % [int(current), int(max_energy)]

# 播放无效操作反馈
func play_invalid_feedback(index: int) -> void:
	if index < 0 or index >= character_slots.size():
		return
	
	var slot = character_slots[index]
	if is_instance_valid(slot):
		slot.play_shake_animation()

# 实时更新当前角色能量
func _update_active_energy() -> void:
	if is_instance_valid(Global.player):
		update_energy(Global.player.energy, Global.player.max_energy)

# 实时更新所有角色状态
func _update_all_character_states() -> void:
	# 首先更新当前激活角色的状态到 player_states（实时同步）
	if is_instance_valid(Global.player):
		var current_id = Global.player.player_id
		if Global.player_states.has(current_id):
			Global.player_states[current_id].health = Global.player.health_component.current_health
			Global.player_states[current_id].max_health = Global.player.health_component.max_health
			Global.player_states[current_id].energy = Global.player.energy
			Global.player_states[current_id].max_energy = Global.player.max_energy
	
	# 然后更新所有卡槽的显示
	for i in range(character_slots.size()):
		var state = Global.get_player_state_by_index(i)
		if state.is_empty():
			continue
		
		var health = float(state.get("health", 0))
		var max_health = float(state.get("max_health", 100))
		var energy = float(state.get("energy", 0))
		var max_energy = float(state.get("max_energy", 999))
		var is_dead = health <= 0
		
		update_character_state(i, health, max_health, energy, max_energy, is_dead)

# 信号处理
func _on_active_character_changed(index: int) -> void:
	set_active_character(index)

func _on_switch_rejected(index: int, reason: String) -> void:
	if reason == "dead":
		play_invalid_feedback(index)

func _on_squad_state_changed(index: int, state: Dictionary) -> void:
	var health = float(state.get("health", 0))
	var max_health = float(state.get("max_health", 100))
	var energy = float(state.get("energy", 0))
	var max_energy = float(state.get("max_energy", 999))
	var is_dead = health <= 0
	update_character_state(index, health, max_health, energy, max_energy, is_dead)

func _on_slot_clicked(index: int) -> void:
	emit_signal("slot_clicked", index)
	# 尝试切换到点击的角色
	Global.switch_to_player_by_index(index)
