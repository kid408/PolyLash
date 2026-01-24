extends Control
class_name CharacterSlot

signal clicked()

# UI 节点引用
@onready var portrait: TextureRect = $VBoxContainer/Portrait
@onready var health_bar: ProgressBar = $VBoxContainer/HealthBar
@onready var energy_bar: ProgressBar = $VBoxContainer/EnergyBar
@onready var bond_icons_container: HBoxContainer = $VBoxContainer/BondIconsContainer
@onready var key_label: Label = $VBoxContainer/KeyLabel
@onready var dead_overlay: ColorRect = $DeadOverlay
@onready var dead_label: Label = $DeadLabel
@onready var highlight: Panel = $Highlight

# 状态
var player_id: String = ""
var is_dead: bool = false
var is_active: bool = false

# 抖动动画参数
var shake_timer: float = 0.0
var shake_intensity: float = 5.0
var original_position: Vector2

func _ready() -> void:
	original_position = position
	# 初始隐藏死亡覆盖层和高亮
	if dead_overlay:
		dead_overlay.visible = false
	if dead_label:
		dead_label.visible = false
	if highlight:
		highlight.visible = false

func _process(delta: float) -> void:
	# 处理抖动动画
	if shake_timer > 0:
		shake_timer -= delta
		position = original_position + Vector2(
			randf_range(-shake_intensity, shake_intensity),
			randf_range(-shake_intensity, shake_intensity)
		)
		if shake_timer <= 0:
			position = original_position

# 初始化卡槽
func setup(p_player_id: String, key_number: int) -> void:
	player_id = p_player_id
	
	# 设置按键标签
	if key_label:
		key_label.text = str(key_number)
	
	# 加载角色头像
	_load_portrait(p_player_id)
	
	# 加载羁绊图标
	_load_bond_icons(p_player_id)
	
	# 重置状态
	is_dead = false
	is_active = false
	_update_visual_state()

# 加载羁绊图标
func _load_bond_icons(p_player_id: String) -> void:
	if not bond_icons_container:
		return
	
	# 清除现有图标
	for child in bond_icons_container.get_children():
		child.queue_free()
	
	# 获取角色配置
	var config = ConfigManager.get_player_config(p_player_id)
	if config.is_empty():
		return
	
	# 获取羁绊标签
	var origin_tag = config.get("origin_tag", "")
	var mastery_tag = config.get("mastery_tag", "")
	var tactic_tag = config.get("tactic_tag", "")
	
	if origin_tag == "" or mastery_tag == "" or tactic_tag == "":
		print("[CharacterSlot] 角色 %s 缺少羁绊标签" % p_player_id)
		return
	
	# 创建羁绊图标（小尺寸，适合HUD）
	var bonds = [
		{"tag": origin_tag, "type": "origin"},
		{"tag": mastery_tag, "type": "mastery"},
		{"tag": tactic_tag, "type": "tactic"}
	]
	
	for bond in bonds:
		var icon_rect = TextureRect.new()
		icon_rect.custom_minimum_size = Vector2(18, 18)  # HUD中使用小图标
		icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		
		var texture = BondUILoader.get_bond_icon(bond.tag, bond.type)
		if texture:
			icon_rect.texture = texture
			icon_rect.tooltip_text = BondUILoader.get_bond_display_name(bond.tag)
		else:
			# 占位符
			icon_rect.modulate = Color(0.3, 0.3, 0.3, 0.5)
		
		bond_icons_container.add_child(icon_rect)

# 加载角色头像
func _load_portrait(p_player_id: String) -> void:
	if not portrait:
		return
	
	# 从 ConfigManager 获取角色视觉配置，使用 sprite_path
	var visual_config = ConfigManager.get_player_visual(p_player_id)
	var sprite_path = visual_config.get("sprite_path", "")
	
	print("[CharacterSlot] 加载角色图标: %s -> %s" % [p_player_id, sprite_path])
	
	if sprite_path != "" and ResourceLoader.exists(sprite_path):
		portrait.texture = load(sprite_path)
		# 设置图片自适应
		portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	else:
		# 使用默认占位图或清空
		portrait.texture = null
		print("[CharacterSlot] 未找到角色图标: %s, path: %s" % [p_player_id, sprite_path])

# 更新血量显示
func update_health(current: float, max_health: float) -> void:
	if health_bar:
		health_bar.max_value = max_health
		health_bar.value = current
	
	# 检查是否死亡
	var was_dead = is_dead
	is_dead = current <= 0
	
	if is_dead != was_dead:
		_update_visual_state()

# 更新能量显示
func update_energy(current: float, max_energy: float) -> void:
	if energy_bar:
		energy_bar.max_value = max_energy
		energy_bar.value = current

# 设置死亡状态
func set_dead(dead: bool) -> void:
	if is_dead == dead:
		return
	is_dead = dead
	_update_visual_state()

# 设置激活状态
func set_active(active: bool) -> void:
	if is_active == active:
		return
	is_active = active
	_update_visual_state()

# 更新视觉状态
func _update_visual_state() -> void:
	# 死亡覆盖层
	if dead_overlay:
		dead_overlay.visible = is_dead
	if dead_label:
		dead_label.visible = is_dead
	
	# 高亮显示
	if highlight:
		highlight.visible = is_active and not is_dead
	
	# 头像灰度效果
	if portrait:
		if is_dead:
			portrait.modulate = Color(0.4, 0.4, 0.4, 1.0)  # 灰色
		else:
			portrait.modulate = Color(1.0, 1.0, 1.0, 1.0)  # 正常

# 播放抖动动画
func play_shake_animation() -> void:
	shake_timer = 0.3  # 抖动持续 0.3 秒
	original_position = position

# 点击处理
func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			emit_signal("clicked")
