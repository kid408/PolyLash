extends RefCounted
class_name ItemWeapon
## 武器物品类

enum WeaponType {
	MELEE,
	RANGE
}

var weapon_id: String = ""
var item_name: String = ""
var type: WeaponType = WeaponType.MELEE
var level: int = 1
var stats: WeaponStats = null
var icon_path: String = ""
var upgrade_to: String = ""
var scene: PackedScene = null  # 武器场景

# 从 CSV 创建武器
static func create_from_csv(weapon_id: String) -> ItemWeapon:
	var stats = WeaponConfigLoader.get_weapon_stats(weapon_id)
	if not stats:
		return null
	
	var info = WeaponConfigLoader.get_weapon_info(weapon_id)
	if info.is_empty():
		return null
	
	var weapon = ItemWeapon.new()
	weapon.weapon_id = weapon_id
	weapon.item_name = info.get("display_name", weapon_id)
	weapon.level = info.get("level", 1)
	weapon.icon_path = info.get("icon_path", "")
	weapon.upgrade_to = info.get("upgrade_to", "")
	weapon.stats = stats
	
	# 加载武器场景
	if not stats.base_scene_path.is_empty():
		print("[ItemWeapon] 尝试加载武器场景: ", stats.base_scene_path)
		if ResourceLoader.exists(stats.base_scene_path):
			weapon.scene = load(stats.base_scene_path) as PackedScene
			if not weapon.scene:
				printerr("[ItemWeapon] 错误: 无法加载武器场景: ", stats.base_scene_path)
			else:
				print("[ItemWeapon] 成功加载武器场景: ", stats.base_scene_path)
		else:
			printerr("[ItemWeapon] 错误: 武器场景路径不存在: ", stats.base_scene_path)
	else:
		printerr("[ItemWeapon] 错误: 武器场景路径为空 - weapon_id: ", weapon_id)
	
	# 根据类型字符串设置枚举
	var type_str = info.get("type", "melee").to_lower()
	if type_str == "range":
		weapon.type = WeaponType.RANGE
	else:
		weapon.type = WeaponType.MELEE
	
	return weapon
