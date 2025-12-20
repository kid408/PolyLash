extends Resource
class_name ItemBase

enum ItemType{
	WEAPON,
	UPGRADE,
	PASSIVE
}

# 武器名称
@export var item_name:String
# 武器图标
@export var item_icon:Texture2D
# 武器品质
@export var item_tier:Global.UpgradeTier
# 武器类型
@export var item_type:ItemType
# 武器价值
@export var item_cost:int

func get_description() -> String:
	return ""
