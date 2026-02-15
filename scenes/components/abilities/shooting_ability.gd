extends AbilityBase
class_name ShootingAbility

## 射击能力 - 向玩家发射投射物
## 配置示例: shooting,射击,3.0,0,300,0,1,3,45,1800

@export_group("Shooting Settings")
@export var projectile_scene: PackedScene = null  # 投射物场景
@export var projectile_count: int = 3  # 投射物数量
@export var arc_angle: float = 45.0  # 扇形角度
@export var projectile_speed: float = 1800.0  # 投射物速度
@export var projectile_damage_mult: float = 0.5  # 伤害倍率
@export var fire_offset: Vector2 = Vector2(0, -50)  # 发射偏移

var shoot_timer: float = 0.0

# ==============================================================================
# 初始化
# ==============================================================================
func _ready() -> void:
	super._ready()
	ability_id = "shooting"
	ability_name = "射击"
	set_process(true)
	
	# 加载默认投射物
	if projectile_scene == null:
		projectile_scene = load("res://scenes/projectiles/projectile_enemy.tscn")

func _process(delta: float) -> void:
	super._process(delta)
	
	if not auto_activate or not is_instance_valid(owner_enemy):
		return
	
	shoot_timer -= delta
	if shoot_timer <= 0 and can_activate():
		try_activate()
		shoot_timer = cooldown

# ==============================================================================
# 能力实现
# ==============================================================================
func activate() -> void:
	"""激活能力 - 发射投射物"""
	if not is_instance_valid(owner_enemy) or not is_instance_valid(Global.player):
		return
	
	_shoot_projectiles()
	start_cooldown()
	is_active = false

func _shoot_projectiles() -> void:
	"""发射多个投射物"""
	# 优先攻击嘲讽目标（override_target），否则攻击玩家
	var target_node = Global.player
	if "override_target" in owner_enemy and is_instance_valid(owner_enemy.override_target):
		target_node = owner_enemy.override_target
	if not is_instance_valid(target_node):
		return
	var direction = owner_enemy.global_position.direction_to(target_node.global_position)
	var damage = int(owner_enemy.damage * projectile_damage_mult) if owner_enemy.has("damage") else 10
	
	# 计算扇形角度
	var start_angle = direction.angle() - deg_to_rad(arc_angle / 2.0)
	var angle_step = deg_to_rad(arc_angle) / max(projectile_count - 1, 1)
	
	for i in range(projectile_count):
		var angle = start_angle + (angle_step * i)
		var proj_direction = Vector2(cos(angle), sin(angle))
		_spawn_projectile(proj_direction, damage)

func _spawn_projectile(direction: Vector2, damage: int) -> void:
	"""生成单个投射物"""
	if projectile_scene == null:
		push_error("[ShootingAbility] 投射物场景未设置!")
		return
	
	var projectile = projectile_scene.instantiate()
	if not projectile:
		return
	
	# 设置位置
	var spawn_pos = owner_enemy.global_position + fire_offset
	projectile.global_position = spawn_pos
	
	# 设置属性
	if projectile.has_method("set_direction"):
		projectile.set_direction(direction)
	if projectile.has_method("set_damage"):
		projectile.set_damage(damage)
	if projectile.has_method("set_speed"):
		projectile.set_speed(projectile_speed)
	
	# 添加到场景
	owner_enemy.get_tree().current_scene.add_child(projectile)

# ==============================================================================
# 配置加载
# ==============================================================================
func setup(enemy: Node2D, config: Dictionary = {}) -> void:
	super.setup(enemy, config)
	
	if config.has("projectile_count"):
		projectile_count = int(config.projectile_count)
	if config.has("arc_angle"):
		arc_angle = float(config.arc_angle)
	if config.has("projectile_speed"):
		projectile_speed = float(config.projectile_speed)
	if config.has("projectile_damage_mult"):
		projectile_damage_mult = float(config.projectile_damage_mult)
	if config.has("fire_offset_x") and config.has("fire_offset_y"):
		fire_offset = Vector2(float(config.fire_offset_x), float(config.fire_offset_y))

func get_config_template() -> Dictionary:
	var base = super.get_config_template()
	base.merge({
		"projectile_count": projectile_count,
		"arc_angle": arc_angle,
		"projectile_speed": projectile_speed,
		"projectile_damage_mult": projectile_damage_mult,
		"fire_offset_x": fire_offset.x,
		"fire_offset_y": fire_offset.y
	})
	return base
