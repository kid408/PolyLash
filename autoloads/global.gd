extends Node

# 闪避文字
signal on_create_block_text(unit:Node2D)
# 伤害数文字
signal on_create_damage_text(unit:Node2D,hitbox:HitboxComponent)

# --- 新增信号 ---
signal on_camera_shake(intensity: float, duration: float)

const FLASH_MATERIAL = preload("uid://coi4nu8ohpgeo")
const FLOATING_TEXT_SCENE = preload("uid://cp86d6q6156la")

# 等级类型
enum UpgradeTier{
	COMMON,
	RARE,
	EPIC,
	LEGENDARY
}

var player:Player
var game_paused:= false

# 是否暴击
func get_chance_sucess(chance:float) -> bool:
	# 从0~1之间随机
	var random := randf_range(0,1.0)
	if random < chance:
		return true
	return false


# --- 新增：顿帧系统 (Hitstop) ---
# duration: 停顿持续的真实时间 (秒)
# time_scale: 停顿时的速度 (0.05 通常效果最好，接近静止但不是死机)
func frame_freeze(duration: float, time_scale: float = 0.05) -> void:
	if Engine.time_scale < 1.0: return # 防止连续触发导致卡死
	
	Engine.time_scale = time_scale
	
	# 创建一个忽略 TimeScale 的计时器，确保按真实时间恢复
	await get_tree().create_timer(duration * time_scale, true, false, true).timeout
	
	Engine.time_scale = 1.0
	

func spawn_floating_text(pos: Vector2, value: String, color: Color) -> void:
	if FLOATING_TEXT_SCENE:
		var text_instance = FLOATING_TEXT_SCENE.instantiate()
		# 添加到当前场景中
		get_tree().current_scene.add_child(text_instance)
		text_instance.global_position = pos
		text_instance.setup(value, color)
		
