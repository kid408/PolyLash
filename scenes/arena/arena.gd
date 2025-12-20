extends Node2D
class_name Arena

@export var player:Player
@export var normal_color:Color
@export var blockedl_color:Color
@export var critical_color:Color
@export var hp_color:Color

@onready var wave_index_lable: Label = %waveIndexLable
@onready var wave_time_lable: Label = %waveTimeLable
@onready var spawner: Spawner = $Spawner

func _ready() -> void:
	# 将角色添加到全局变量中
	Global.player = player
	# 闪避飘字信号 Unit类 _on_hurtbox_component_on_damaged 调用
	Global.on_create_block_text.connect(_on_create_block_text)
	# 伤害飘字信号
	Global.on_create_damage_text.connect(_on_create_damage_text)



func _process(delta: float) -> void:
	if Global.game_paused: return
	if not spawner.spawn_timer.is_stopped():
		wave_index_lable.text = spawner.get_wave_text()
		wave_time_lable.text = spawner.get_wave_timer_text()

# 创建具体飘字数据
func create_floating_text(unit: Node2D) -> FloatingText:
	var instance := Global.FLOATING_TEXT_SCENE.instantiate() as FloatingText
	# 添加到场景中
	get_tree().root.add_child(instance)
	# 随机位置 TAU 360 度旋转
	var random_pos := randf_range(0,TAU) * 35
	# 生成位置
	var spawn_pos := unit.global_position + Vector2.RIGHT.rotated(random_pos)
	
	instance.global_position = spawn_pos
	
	return instance
	
# 创建闪避飘字
func _on_create_block_text(unit:Node2D) -> void:
	var text := create_floating_text(unit)
	text.setup("闪!",blockedl_color)
	

# 创建伤害飘字
func _on_create_damage_text(uinit:Node2D,hitbox:HitboxComponent) -> void:
	var text := create_floating_text(uinit)
	var color := critical_color if hitbox.critical else normal_color
	text.setup(str(hitbox.damage),color)
