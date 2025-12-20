extends ItemBase
class_name ItemWeapon

enum WeaponType{
	MELEE,
	RANGE
}

# 武器类型
@export var type:WeaponType
# 场景
@export var scene:PackedScene
# 武器参数
@export var stats: WeaponStats
# 升级到下一级
@export var upgrade_to:ItemWeapon
