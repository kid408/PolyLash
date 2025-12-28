extends Area2D
class_name Chest

# ============================================================================
# 宝箱系统 - 可交互的升级宝箱
# ============================================================================

signal chest_opened(chest: Chest)

@export var chest_tier: int = 1  # 宝箱等级 (1-4)
@export var is_opened: bool = false

var player_nearby: bool = false
var chest_config: Dictionary = {}

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var interaction_label: Label = $InteractionLabel

func _ready() -> void:
	# 加载宝箱配置
	chest_config = ConfigManager.get_chest_config(chest_tier)
	
	# 设置动画
	_setup_animation()
	
	# 连接信号
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	
	# 隐藏交互提示
	interaction_label.visible = false
	
	# 设置碰撞层
	collision_layer = 0
	collision_mask = 1  # 只检测玩家层

func _setup_animation() -> void:
	if not animated_sprite:
		return
	
	# 根据宝箱等级选择动画名称
	var idle_anim = ""
	
	match chest_tier:
		1:
			idle_anim = "wood_chests"
		2:
			idle_anim = "bronze_chests"
		3:
			idle_anim = "gold_chests"
		4:
			idle_anim = "diamond_chests"
		_:
			idle_anim = "wood_chests"
	
	# 尝试播放idle动画
	if animated_sprite.sprite_frames:
		if animated_sprite.sprite_frames.has_animation(idle_anim):
			animated_sprite.play(idle_anim)
			print("[Chest] 播放动画: ", idle_anim)
		else:
			printerr("[Chest] 未找到动画: ", idle_anim)
			printerr("[Chest] 可用动画列表: ", animated_sprite.sprite_frames.get_animation_names())
	else:
		printerr("[Chest] AnimatedSprite2D 没有 sprite_frames")

func _process(_delta: float) -> void:
	# 不再需要按键，触碰自动打开
	pass

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player") and not is_opened:
		player_nearby = true
		interaction_label.visible = true
		# 触碰自动打开
		open_chest()

func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		player_nearby = false
		interaction_label.visible = false

func open_chest() -> void:
	if is_opened:
		return
	
	is_opened = true
	player_nearby = false
	interaction_label.visible = false
	
	# 播放打开动画
	var open_anim = ""
	match chest_tier:
		1: open_anim = "wood_chests_open"
		2: open_anim = "bronze_chests_open"
		3: open_anim = "gold_chests_open"
		4: open_anim = "diamond_chests_open"
		_: open_anim = "wood_chests_open"
	
	if animated_sprite.sprite_frames:
		if animated_sprite.sprite_frames.has_animation(open_anim):
			animated_sprite.play(open_anim)
			print("[Chest] 播放打开动画: ", open_anim)
		else:
			printerr("[Chest] 未找到打开动画: ", open_anim)
	
	# 暂停游戏
	Global.game_paused = true
	
	# 发送信号
	chest_opened.emit(self)
	
	print("[Chest] 宝箱已打开 - 等级: %d" % chest_tier)

func get_tier() -> int:
	return chest_tier

func get_position_2d() -> Vector2:
	return global_position
