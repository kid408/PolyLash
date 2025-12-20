extends Resource
class_name UnitStats

# 单位类型枚举
enum UnitType{
	PLAYER,
	ENEMY
}
# 名字
@export var name:String
# 类型
@export var type:UnitType
# 图标
@export var icon:Texture2D
# 生命
@export var health:=1
# 每波之后增加的生命
@export var health_increase_per_wave := 1.0
# 伤害
@export var damage:=1
# 每波之后增加的伤害
@export var damage_increase_per_wave := 1.0
# 速度
@export var speed := 300
# 幸运值
@export var luck:=1.0
# 闪避
@export var block_chance:=1.0
# 金币掉落
@export var gold_drop := 1
