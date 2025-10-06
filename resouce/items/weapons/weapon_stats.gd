extends Resource
class_name WeaponStats

# 伤害
@export var damage := 1.0
# 精度
@export_range(0.0,1.0) var accuracy := 0.9
# 冷却时间
@export_range(0.0,3.0) var cooldown := 1.0
# 暴击率
@export_range(0.0,1.0) var crit_chance := 0.05
# 暴击伤害
@export var crit_damage := 1.5
# 最大返回
@export var max_range := 150.0
# 击退
@export var knockback:= 0.0
# 生命窃取
@export_range(0.0,1.0) var life_steal := 0.0
# 后坐力
@export var recoil:=25.0
# 后坐力持续时间,武器收回动作
@export_range(0.1,3.0) var recoil_duration := 0.1
# 攻击持续时间
@export_range(0.1,3.0) var attack_duration := 0.2
# 武器攻击后返回持续时间
@export_range(0.1,3.0) var back_duration := 0.15
# 子弹场景
@export var projectile_scene:PackedScene
# 子弹速度
@export var projectile_speed := 1600.0
