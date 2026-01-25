extends Node2D
class_name Projectile

@export var hitbox: HitboxComponent
@export var life_time: float = 5.0 # 子弹最大存活时间(秒)

var velocity: Vector2
var weapon_stats: WeaponStats = null  # 武器属性引用（用于爆炸效果）
var owner_unit: Node2D = null  # 发射者引用（用于爆炸伤害）

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

func set_projectile(velocity: Vector2, damage: float, critical: bool, knockback: float, unit: Node2D, stats: WeaponStats = null) -> void:
	self.velocity = velocity
	self.owner_unit = unit
	self.weapon_stats = stats
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
	# 检查是否需要生成爆炸效果（延迟调用以避免物理查询冲突）
	call_deferred("_spawn_explosion_if_needed")
	
	# 打中人也销毁
	queue_free()


# ==============================================================================
# 爆炸效果系统
# ==============================================================================

func _spawn_explosion_if_needed() -> void:
	"""检查并生成爆炸效果（如果武器有爆炸属性）"""
	if not weapon_stats:
		return
	
	if weapon_stats.explosion_radius <= 0:
		return
	
	print("[Projectile] ✓ 生成爆炸: 伤害=%.1f, 半径=%.1f" % [weapon_stats.damage, weapon_stats.explosion_radius])
	
	# 加载爆炸场景
	var explosion_scene = load("res://scenes/vfx/explosion_area.tscn")
	if not explosion_scene:
		printerr("[Projectile] 错误: 无法加载爆炸场景")
		return
	
	# 实例化爆炸
	var explosion = explosion_scene.instantiate()
	
	# 【关键】先设置位置和参数，再添加到场景
	explosion.global_position = global_position
	
	# 【安全检查】确保 owner_unit 仍然有效
	var valid_owner = null
	if owner_unit and is_instance_valid(owner_unit):
		valid_owner = owner_unit
	else:
		print("[Projectile] ⚠️ owner_unit 已被释放，使用 null")
	
	# 计算爆炸伤害（基于武器伤害 + 玩家伤害）
	var base_damage = weapon_stats.damage
	
	# 添加玩家伤害加成
	if valid_owner and "damage" in valid_owner:
		base_damage += valid_owner.damage
	elif Global.player and is_instance_valid(Global.player) and "damage" in Global.player:
		base_damage += Global.player.damage
	
	var explosion_damage = base_damage * weapon_stats.explosion_damage_scale
	
	print("[Projectile] 爆炸伤害: %.1f (基础:%.1f × 倍率:%.1f)" % [explosion_damage, base_damage, weapon_stats.explosion_damage_scale])
	
	# 设置爆炸参数
	if explosion.has_method("setup"):
		explosion.setup(
			explosion_damage,
			weapon_stats.explosion_radius,
			valid_owner  # 使用验证后的 owner
		)
	
	# 【关键】最后才添加到场景树
	get_tree().root.add_child(explosion)
