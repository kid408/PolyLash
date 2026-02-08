extends RefCounted
class_name WeaponStats
## 武器统计数据类

# 基础数值属性
var damage: float = 1.0
var accuracy: float = 1.0
var cooldown: float = 1.0
var crit_chance: float = 0.05
var crit_damage: float = 1.5
var max_range: float = 150.0
var knockback: float = 0.0
var life_steal: float = 0.0
var recoil: float = 15.0
var recoil_duration: float = 0.1
var attack_duration: float = 0.2
var back_duration: float = 0.15
var projectile_speed: float = 1600.0

# 爆炸效果属性
var explosion_radius: float = 0.0
var explosion_damage_scale: float = 1.0

# 路径字段
var base_scene_path: String = ""
var sprite_texture: String = ""
var sprite_texture_levels: String = ""
var animation_frames_path: String = ""
var vfx_attack_scene: String = ""
var vfx_hit_scene: String = ""
var audio_attack: String = ""
var projectile_scene: PackedScene = null

# 偏移/缩放字段（格式 "x|y"）
var muzzle_offset: String = "0|0"
var hitbox_offset: String = "0|0"
var hitbox_scale: String = "1.0|1.0"

# 形状/模式/效果字段
var shape_type: String = ""
var bullet_mode: String = ""
var effect_type: String = ""

# 数值参数
var sector_angle: float = 0.0
var bullet_count: int = 1
var spread_angle: float = 0.0
var pierce_count: int = 0

# 通用扩展参数
var param1: String = ""
var param2: String = ""
var param3: String = ""

# 辅助方法：解析偏移字符串为 Vector2
func get_muzzle_offset() -> Vector2:
	return _parse_vector2(muzzle_offset)

func get_hitbox_offset() -> Vector2:
	return _parse_vector2(hitbox_offset)

func get_hitbox_scale() -> Vector2:
	return _parse_vector2(hitbox_scale)

func _parse_vector2(value: String) -> Vector2:
	if value.is_empty():
		return Vector2.ZERO
	var parts = value.split("|")
	if parts.size() != 2:
		return Vector2.ZERO
	return Vector2(float(parts[0]), float(parts[1]))
