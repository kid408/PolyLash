extends Unit
class_name PlayerBase

# ==============================================================================
# 1. 通用信号 & 属性
# ==============================================================================
signal energy_changed(current, max_val)
signal armor_changed(current)

@export_group("Base Stats")
# 默认值 999，你可以在编辑器修改，代码不会覆盖
@export var max_energy: float = 999.0 
@export var energy_regen: float = 0.5 
@export var max_armor: int = 3
# 基础速度兜底，如果 Stats 资源没挂载会用这个
@export var base_speed: float = 300.0

@export_group("Common Settings")
@export var dash_vfx_scene: PackedScene 

# 状态相关
var energy: float = 0.0
var armor: int = 0
var move_dir: Vector2 = Vector2.ZERO
var external_force: Vector2 = Vector2.ZERO
var external_force_decay: float = 10.0

@onready var collision: CollisionShape2D = $CollisionShape2D
@onready var dash_hitbox: HitboxComponent = $DashHitbox 

func _ready() -> void:
	super._ready() # 初始化 Stats
	
	# 【核心修复】确保加入 player 组，否则敌人可能找不到你
	if not is_in_group("player"):
		add_to_group("player")
	
	# 【核心修复】注册全局引用
	Global.player = self
	
	# 连接死亡信号
	if health_component and not health_component.on_unit_died.is_connected(_on_death):
		health_component.on_unit_died.connect(_on_death)
	
	# 初始化数值
	energy = max_energy
	armor = max_armor
	update_ui_signals()
	
	print(">>> 玩家基类加载完成: ", self.name)

func _process(delta: float) -> void:
	if Global.game_paused: return
	
	# 能量恢复
	if energy < max_energy:
		energy += energy_regen * delta
		update_ui_signals()
	
	# 物理模拟
	if external_force.length() > 10.0:
		position += external_force * delta
		external_force = external_force.lerp(Vector2.ZERO, external_force_decay * delta)
	else:
		external_force = Vector2.ZERO
	
	_handle_input(delta)
	_process_subclass(delta)
	update_rotation()

func _handle_input(delta: float) -> void:
	# 1. 移动逻辑
	move_dir = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if can_move():
		var current_speed = base_speed 
		if stats != null:
			current_speed = stats.speed
		position += move_dir * current_speed * delta
		position.x = clamp(position.x, -2000, 2000)
		position.y = clamp(position.y, -2000, 2000)

	# 2. 技能按键分发 (核心修复在这里！)
	
	# === 优先级 1: E 技能 ===
	if Input.is_action_just_pressed("skill_e"):
		use_skill_e()
		return # 阻止其他输入

	# === 优先级 2: Q 技能 (规划模式) ===
	if Input.is_action_pressed("skill_q"):
		charge_skill_q(delta)
		# 【关键】如果正在按 Q，左键点击只属于 Q 技能，
		# 哪怕你点了左键，也不要往下执行 use_dash！
		return 
	
	elif Input.is_action_just_released("skill_q"):
		release_skill_q()
		return

	# === 优先级 3: 普通左键冲刺 ===
	# 只有没按 Q 也没按 E 的时候，左键才算冲刺
	if Input.is_action_just_pressed("click_left"):
		use_dash()

# --- 虚函数 (子类重写) ---
func can_move() -> bool: return true
func _process_subclass(delta: float) -> void: pass
func use_dash() -> void: pass       
func charge_skill_q(delta:float) -> void: pass 
func release_skill_q() -> void: pass   
func use_skill_e() -> void: pass       

# --- 战斗逻辑 ---
func take_damage(raw_amount: float) -> void:
	var reduction_per_armor = 0.2
	var damage_multiplier = 1.0 - (clamp(armor, 0, max_armor) * reduction_per_armor)
	var final_damage = max(1, raw_amount * damage_multiplier)
	
	if armor > 0:
		armor -= 1
		Global.spawn_floating_text(global_position, "Armor Crack!", Color.YELLOW)
		armor_changed.emit(armor)
	else:
		Global.spawn_floating_text(global_position, "-%d" % final_damage, Color.RED)
		Global.on_camera_shake.emit(8.0, 0.2)
	
	health_component.take_damage(final_damage)
	Global.frame_freeze(0.05, 0.1)

func apply_knockback_self(force: Vector2) -> void:
	external_force = force
	Global.on_camera_shake.emit(5.0, 0.1)

func consume_energy(amount: float) -> bool:
	if energy >= amount:
		energy -= amount
		update_ui_signals()
		return true
	else:
		Global.spawn_floating_text(global_position, "No Energy!", Color.RED)
		return false

func update_ui_signals() -> void:
	energy_changed.emit(energy, max_energy)
	armor_changed.emit(armor)

func update_rotation() -> void:
	var facing_dir = get_global_mouse_position() - global_position
	if facing_dir.x != 0:
		visuals.scale.x = -0.5 if facing_dir.x > 0 else 0.5

func _on_death() -> void:
	print(">>> 玩家死亡 <<<")
	Global.play_player_death()
	visuals.visible = false
	# 简单的死亡粒子生成
	var emitter = CPUParticles2D.new()
	emitter.emitting = true
	emitter.one_shot = true
	emitter.amount = 30
	emitter.explosiveness = 1.0
	emitter.gravity = Vector2(0, 800)
	emitter.color = Color.WHITE
	emitter.global_position = global_position
	get_tree().current_scene.add_child(emitter)
	
	collision.set_deferred("disabled", true)
	set_process(false)
	set_physics_process(false)
	
	# 慢动作后重开
	Engine.time_scale = 0.2
	await get_tree().create_timer(1.0).timeout
	Engine.time_scale = 1.0
	get_tree().reload_current_scene()
