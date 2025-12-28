extends Area2D
class_name ChestSimple

# ============================================================================
# 宝箱系统 - 使用AnimatedSprite2D播放用户创建的动画
# ============================================================================

signal chest_opened(chest: ChestSimple)

@export var chest_tier: int = 1  # 宝箱等级 (1-4)
@export var is_opened: bool = false

var player_nearby: bool = false
var chest_config: Dictionary = {}

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var interaction_label: Label = $InteractionLabel

# 宝箱动画名称映射
var chest_animations = {
	1: "wood_chests",      # 木质宝箱
	2: "bronze_chests",    # 青铜宝箱
	3: "gold_chests",      # 黄金宝箱
	4: "diamond_chests"    # 钻石宝箱
}

var chest_open_animations = {
	1: "wood_chests_open",
	2: "bronze_chests_open",
	3: "gold_chests_open",
	4: "diamond_chests_open"
}

func _ready() -> void:
	# 加载宝箱配置
	chest_config = ConfigManager.get_chest_config(chest_tier)
	
	# 设置动画
	_setup_animation()
	
	# 设置碰撞层 - 宝箱在第3层(4)，检测玩家第1层(1)
	collision_layer = 4
	collision_mask = 1
	
	# 确保监听启用
	monitoring = true
	monitorable = true
	
	# 连接信号
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	area_entered.connect(_on_area_entered)
	area_exited.connect(_on_area_exited)
	
	# 设置提示标签颜色和文本
	_setup_interaction_label()
	
	# 隐藏交互提示
	interaction_label.visible = false
	
	print("[Chest] 宝箱初始化完成 - 等级: %d, 位置: %v, Layer: %d, Mask: %d, Monitoring: %s, Monitorable: %s" % 
		  [chest_tier, global_position, collision_layer, collision_mask, monitoring, monitorable])

func _setup_interaction_label() -> void:
	if not interaction_label:
		return
	
	# 根据宝箱等级设置不同的颜色和文本
	match chest_tier:
		1:  # 木质宝箱 - 白色
			interaction_label.text = "木质宝箱"
			interaction_label.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9))  # 浅灰白色
		2:  # 青铜宝箱 - 绿色
			interaction_label.text = "青铜宝箱"
			interaction_label.add_theme_color_override("font_color", Color(0.3, 0.9, 0.3))  # 亮绿色
		3:  # 黄金宝箱 - 蓝色
			interaction_label.text = "黄金宝箱"
			interaction_label.add_theme_color_override("font_color", Color(0.3, 0.6, 1.0))  # 亮蓝色
		4:  # 钻石宝箱 - 紫色
			interaction_label.text = "钻石宝箱"
			interaction_label.add_theme_color_override("font_color", Color(0.8, 0.3, 1.0))  # 紫色
		_:  # 默认
			interaction_label.text = "宝箱"
			interaction_label.add_theme_color_override("font_color", Color.WHITE)

func _setup_animation() -> void:
	if not animated_sprite:
		printerr("[Chest] AnimatedSprite2D 节点未找到")
		return
	
	# 获取对应等级的动画名称
	var anim_name = chest_animations.get(chest_tier, "wood_chests")
	
	# 检查动画是否存在
	if animated_sprite.sprite_frames and animated_sprite.sprite_frames.has_animation(anim_name):
		animated_sprite.play(anim_name)
	else:
		printerr("[Chest] 未找到动画: %s" % anim_name)
	
	# 根据等级设置缩放和颜色调制（发光效果）
	match chest_tier:
		1: 
			animated_sprite.scale = Vector2(2.0, 2.0)
			animated_sprite.modulate = Color(1.0, 1.0, 1.0)  # 白色（无调制）
		2: 
			animated_sprite.scale = Vector2(2.2, 2.2)
			animated_sprite.modulate = Color(1.0, 1.2, 1.0)  # 微绿色发光
		3: 
			animated_sprite.scale = Vector2(2.5, 2.5)
			animated_sprite.modulate = Color(1.0, 1.1, 1.3)  # 微蓝色发光
		4: 
			animated_sprite.scale = Vector2(2.8, 2.8)
			animated_sprite.modulate = Color(1.2, 1.0, 1.3)  # 微紫色发光
	
	# print("[Chest] 宝箱设置完成 - 等级: %d" % chest_tier)

func _process(delta: float) -> void:
	# 调试：每秒检测一次附近的物体
	if not is_opened and Engine.get_frames_drawn() % 60 == 0:
		var bodies = get_overlapping_bodies()
		var areas = get_overlapping_areas()
		if bodies.size() > 0 or areas.size() > 0:
			print("[Chest %d @ %v] 检测到 %d 个Body, %d 个Area" % [chest_tier, global_position, bodies.size(), areas.size()])
			for body in bodies:
				if is_instance_valid(body):
					print("  - Body: %s (type: %s, groups: %s, layer: %d)" % 
						  [body.name, body.get_class(), body.get_groups(), body.collision_layer if "collision_layer" in body else -1])
			for area in areas:
				if is_instance_valid(area):
					print("  - Area: %s (type: %s, groups: %s, layer: %d)" % 
						  [area.name, area.get_class(), area.get_groups(), area.collision_layer if "collision_layer" in area else -1])


func _on_area_entered(area: Area2D) -> void:
	print("[Chest] Area entered: %s, is_in_group(player): %s, is_opened: %s" % [area.name, area.is_in_group("player"), is_opened])
	if area.is_in_group("player") and not is_opened:
		player_nearby = true
		interaction_label.visible = true
		# 触碰自动打开
		open_chest()

func _on_body_entered(body: Node2D) -> void:
	print("[Chest] Body entered: %s, type: %s, is_in_group(player): %s, is_opened: %s" % 
		  [body.name, body.get_class(), body.is_in_group("player"), is_opened])
	if body.is_in_group("player") and not is_opened:
		player_nearby = true
		interaction_label.visible = true
		# 触碰自动打开
		open_chest()

func _on_body_exited(body: Node2D) -> void:
	print("[Chest] Body exited: %s" % body.name)
	if body.is_in_group("player"):
		player_nearby = false
		interaction_label.visible = false

func _on_area_exited(area: Area2D) -> void:
	print("[Chest] Area exited: %s" % area.name)
	if area.is_in_group("player"):
		player_nearby = false
		interaction_label.visible = false

func open_chest() -> void:
	if is_opened:
		return
	
	print("[Chest] Opening chest - tier: %d" % chest_tier)
	
	is_opened = true
	player_nearby = false
	interaction_label.visible = false
	
	# 播放打开动画
	if animated_sprite and animated_sprite.sprite_frames:
		var open_anim = chest_open_animations.get(chest_tier, "wood_chests_open")
		if animated_sprite.sprite_frames.has_animation(open_anim):
			animated_sprite.play(open_anim)
		else:
			printerr("[Chest] 未找到打开动画: %s" % open_anim)
	
	# 暂停游戏
	Global.game_paused = true
	print("[Chest] Game paused, emitting chest_opened signal")
	
	# 发送信号
	chest_opened.emit(self)
	
	print("[Chest] 宝箱已打开 - 等级: %d" % chest_tier)

# 选择完属性后隐藏宝箱
func hide_chest() -> void:
	# 淡出动画
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.5)
	tween.tween_callback(queue_free)

func get_tier() -> int:
	return chest_tier

func get_position_2d() -> Vector2:
	return global_position
