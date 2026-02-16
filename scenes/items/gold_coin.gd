extends Area2D
class_name GoldCoin

## ==============================================================================
## 金币实体 - Gold Coin Entity
## ==============================================================================
## 
## 功能说明:
## - 生成时向上弹跳
## - 检测玩家距离，自动吸附
## - 碰撞玩家后给予金币并销毁
## - 双重保险：碰撞检测 + 距离强制拾取
## 
## ==============================================================================

# 金币数量
@export var gold_amount: int = 1

# 拾取范围（从玩家读取）
var pickup_range: float = 150.0

# 吸附速度
var magnet_speed: float = 800.0

# 强制拾取距离（像素）
const FORCE_PICKUP_DISTANCE: float = 15.0

# 是否正在被吸附
var is_magnetized: bool = false

# 是否已被拾取（防止重复触发）
var is_collected: bool = false

# 节点引用
@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var collision: CollisionShape2D = $CollisionShape2D

func _ready() -> void:
	# 设置碰撞层级
	collision_layer = 0  # 不在任何层
	collision_mask = 1   # 只检测玩家层（Layer 1）
	
	# 连接信号
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)
	
	# 播放动画
	if sprite:
		sprite.play("default")
	
	# 弹跳效果
	_play_pop_animation()
	
	print("[GoldCoin] 金币初始化完成，collision_mask=%d" % collision_mask)

func _process(delta: float) -> void:
	if Global.game_paused:
		return
	
	# 如果已被拾取，停止处理
	if is_collected:
		return
	
	# 检查玩家是否存在
	if not is_instance_valid(Global.player):
		return
	
	# 获取玩家的拾取范围（使用 in 关键字检查属性）
	if "pickup_range" in Global.player:
		pickup_range = Global.player.pickup_range
	
	# 计算与玩家的距离
	var distance = global_position.distance_to(Global.player.global_position)
	
	# 【新增】距离过近强制拾取（双重保险）
	if distance < FORCE_PICKUP_DISTANCE:
		print("[GoldCoin] 距离过近 (%.1f < %.1f)，强制拾取" % [distance, FORCE_PICKUP_DISTANCE])
		_collect_coin(Global.player)
		return
	
	# 如果在拾取范围内，开始吸附
	if distance < pickup_range:
		is_magnetized = true
	
	# 吸附移动
	if is_magnetized:
		var direction = global_position.direction_to(Global.player.global_position)
		global_position += direction * magnet_speed * delta

func _play_pop_animation() -> void:
	"""播放弹跳动画"""
	# 初始缩放为0
	scale = Vector2.ZERO
	
	# 创建弹跳动画
	var tween = create_tween()
	tween.set_parallel(true)
	
	# 缩放动画（弹性效果）
	tween.tween_property(self, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	
	# 向上弹跳
	var start_pos = global_position
	var jump_height = 30.0
	tween.tween_property(self, "global_position:y", start_pos.y - jump_height, 0.15).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.chain().tween_property(self, "global_position:y", start_pos.y, 0.15).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

func _on_body_entered(body: Node2D) -> void:
	"""碰撞到玩家（CharacterBody2D）"""
	print("[GoldCoin] body_entered 触发: %s" % body.name)
	
	# 【修改】更宽容的判定逻辑
	if body.is_in_group("player") or body.has_method("add_gold"):
		print("[GoldCoin] 检测到玩家，触发拾取")
		_collect_coin(body)
	else:
		print("[GoldCoin] 不是玩家，忽略")

func _on_area_entered(area: Area2D) -> void:
	"""碰撞到玩家的Area2D"""
	print("[GoldCoin] area_entered 触发: %s" % area.name)
	
	# 【修改】更宽容的判定逻辑
	if area.is_in_group("player") or area.has_method("add_gold"):
		print("[GoldCoin] Area 是玩家，触发拾取")
		_collect_coin(area)
	elif area.owner and (area.owner.is_in_group("player") or area.owner.has_method("add_gold")):
		print("[GoldCoin] Area.owner 是玩家: %s，触发拾取" % area.owner.name)
		_collect_coin(area.owner)
	else:
		print("[GoldCoin] 不是玩家相关的 Area，忽略")

func _collect_coin(player: Node2D) -> void:
	"""拾取金币（统一入口，防止重复触发）"""
	# 防止重复触发
	if is_collected:
		print("[GoldCoin] 已被拾取，忽略重复触发")
		return
	
	print("[GoldCoin] _collect_coin 被调用，玩家: %s" % (player.name if is_instance_valid(player) else "无效"))
	
	if not is_instance_valid(player):
		print("[GoldCoin] 玩家无效，取消拾取")
		return
	
	# 标记为已拾取
	is_collected = true
	
	# 播放金币拾取音效
	SoundManager.play("gold_pickup")
	
	# 给予金币
	if player.has_method("add_gold"):
		player.add_gold(gold_amount)
		print("[GoldCoin] ✅ 拾取金币成功: %d" % gold_amount)
	else:
		print("[GoldCoin] ⚠️ 玩家没有 add_gold 方法")
	
	# 销毁金币
	print("[GoldCoin] 调用 queue_free()")
	queue_free()

## 设置金币数量
func set_amount(amount: int) -> void:
	gold_amount = amount
