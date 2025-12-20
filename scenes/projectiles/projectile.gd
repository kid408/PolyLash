extends Node2D
class_name Projectile

@export var hitbox: HitboxComponent
@export var life_time: float = 5.0 # 子弹最大存活时间(秒)

var velocity: Vector2

func _ready() -> void:
	# 【核心修复】创建一个自我销毁的计时器
	# 这种方式最稳健，不管子弹飞哪去了，时间一到强制回收
	get_tree().create_timer(life_time).timeout.connect(queue_free)
	
	# 【双重保险】如果你场景里有 VisibleOnScreenNotifier2D，尝试代码连接
	# 防止你在编辑器里忘了连信号
	if has_node("VisibleOnScreenNotifier2D"):
		var notifier = $VisibleOnScreenNotifier2D
		if not notifier.screen_exited.is_connected(_on_screen_exited):
			notifier.screen_exited.connect(_on_screen_exited)

func _process(delta: float) -> void:
	position += velocity * delta

func set_projectile(velocity: Vector2, damage: float, critical: bool, knockback: float, unit: Node2D) -> void:
	self.velocity = velocity
	rotation = velocity.angle()
	
	if hitbox:
		hitbox.setup(damage, critical, knockback, unit)

# 统一销毁逻辑
func _on_screen_exited() -> void:
	queue_free()

# 对应你之前的 VisibleOnScreenNotifier2D 信号函数
# 建议去编辑器确认一下信号是否真的连上了
func _on_visible_on_screen_notifier_2d_screen_exited() -> void:
	queue_free()

func _on_hitbox_component_on_hit_hurtbox(hurtbox: HurtboxComponent) -> void:
	# 打中人也销毁
	queue_free()
