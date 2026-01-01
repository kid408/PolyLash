extends Node2D
class_name Unit

@export var stats:UnitStats

@onready var visuals: Node2D = $Visuals
@onready var sprite: Sprite2D = $Visuals/Sprite
@onready var anim_player: AnimationPlayer = $AnimationPlayer
@onready var health_component: HealthComponent = $HealthComponent
@onready var flash_timer: Timer = $FlashTimer

# 伤害累积系统
var accumulated_damage: int = 0
var damage_pop_timer: Timer = null
var damage_hit_count: int = 0  # 记录连击次数



func _ready() -> void:	
	 # --- 新增安全检查 ---
	if stats == null:
		printerr("[Unit Error] 致命错误！节点 '%s' 没有分配 Stats 资源！请在 Inspector 中赋值。" % name)
		return # 直接返回，不执行 setup，防止红字报错
	# ------------------

	# 设置生命条数据
	health_component.setup(stats)
	
	# 初始化伤害累积计时器
	damage_pop_timer = Timer.new()
	damage_pop_timer.wait_time = 0.5  # 增加累积时间：0.3 → 0.5秒
	damage_pop_timer.one_shot = true
	add_child(damage_pop_timer)
	damage_pop_timer.timeout.connect(_on_damage_pop_timeout)

func set_flash_material() -> void:
	sprite.material = Global.FLASH_MATERIAL
	flash_timer.start()

func _on_hurtbox_component_on_damaged(hitbox: HitboxComponent) -> void:
	if health_component.current_health <=0:
		return
	
	var blocked := Global.get_chance_sucess(stats.block_chance / 100)
	if blocked:
		# 发送闪避的信号
		Global.on_create_block_text.emit(self)
		return
		
	set_flash_material()
	
	# 受到伤害，调用健康组件的受到伤害
	health_component.take_damage(hitbox.damage)
	
	# 累积伤害而不是立即显示
	accumulated_damage += hitbox.damage
	damage_hit_count += 1  # 增加连击计数
	
	# 如果计时器未运行，启动它
	if damage_pop_timer and damage_pop_timer.is_stopped():
		damage_pop_timer.start()
	else:
		# 如果已经在累积，重置计时器（延长显示时间）
		damage_pop_timer.start()
	
	#print("%s :%d" %[name,health_component.current_health])

# 伤害累积计时器超时，显示累积的伤害
func _on_damage_pop_timeout() -> void:
	if accumulated_damage > 0:
		# 根据伤害大小和连击数调整颜色、大小和特效
		var damage_color = Color.WHITE
		var damage_text = str(accumulated_damage)
		var scale_mult = 1.5  # 基础缩放
		
		# 根据伤害分级
		if accumulated_damage >= 200:
			damage_color = Color(3.0, 0.3, 0.0) # 超高伤害：超亮橙红色
			damage_text = "!!!" + damage_text + "!!!"
			scale_mult = 3.0
			# 超高伤害额外反馈
			Global.on_camera_shake.emit(3.0, 0.1)
			Global.frame_freeze(0.02, 0.3)
		elif accumulated_damage >= 100:
			damage_color = Color(2.5, 0.5, 0.0) # 高伤害：亮橙色
			damage_text = "!!" + damage_text + "!!"
			scale_mult = 2.5
		elif accumulated_damage >= 50:
			damage_color = Color(2.0, 1.0, 0.0) # 中伤害：亮黄色
			damage_text = "!" + damage_text + "!"
			scale_mult = 2.0
		
		# 连击加成：每5次连击增加0.2倍缩放
		if damage_hit_count >= 5:
			scale_mult += (damage_hit_count / 5) * 0.2
			damage_text = "x%d " % damage_hit_count + damage_text
		
		# 生成飘字（FloatingText会使用scale_mult）
		Global.spawn_floating_text(global_position, damage_text, damage_color)
		
		# 重置累积
		accumulated_damage = 0
		damage_hit_count = 0


func _on_flash_timer_timeout() -> void:
	sprite.material = null
	
