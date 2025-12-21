extends Node2D
class_name Unit

@export var stats:UnitStats

@onready var visuals: Node2D = $Visuals
@onready var sprite: Sprite2D = $Visuals/Sprite
@onready var anim_player: AnimationPlayer = $AnimationPlayer
@onready var health_component: HealthComponent = $HealthComponent
@onready var flash_timer: Timer = $FlashTimer



func _ready() -> void:	
	 # --- 新增安全检查 ---
	if stats == null:
		printerr("[Unit Error] 致命错误！节点 '%s' 没有分配 Stats 资源！请在 Inspector 中赋值。" % name)
		return # 直接返回，不执行 setup，防止红字报错
	# ------------------

	# 设置生命条数据
	health_component.setup(stats)

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
	# 发送伤害飘字信号
	Global.on_create_damage_text.emit(self,hitbox)
	#print("%s :%d" %[name,health_component.current_health])


func _on_flash_timer_timeout() -> void:
	sprite.material = null
	
