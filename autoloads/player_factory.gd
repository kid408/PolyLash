extends Node

## ==============================================================================
## 玩家工厂类 - 负责创建玩家角色实例
## ==============================================================================
## 
## 使用方式：
##   var player = PlayerFactory.create_player("butcher")
##   get_tree().root.add_child(player)
## 
## ==============================================================================

# 通用玩家场景模板
const PLAYER_GENERIC_SCENE = "res://scenes/unit/players/player_generic.tscn"

# 角色脚本路径模板
const PLAYER_SCRIPT_TEMPLATE = "res://scenes/unit/players/player_%s.gd"
const LEGACY_PLAYER_ID_ALIASES: Dictionary = {
	"new_pyro": "runeblazer",
	"new_totem": "spiritcaller",
	"new_tempest": "stormseer",
	"tempest": "stormseer",
	"train": "breachmarshal",
	"goo": "mirebinder",
	"herder": "lurewarden",
	"hunter": "trapper",
	"ammo": "quartermaster",
	"turret_eng": "turretwright",
	"vacuum": "singularist",
	"tesla": "arcstriker",
	"voodoo": "hexwarden",
	"gambler": "fatebinder",
	"merchant": "broker",
	"midas": "gildhand",
	"vampire": "bloodsworn"
}

# 脚本映射（用于处理别名或特殊情况）
var script_mapping = LEGACY_PLAYER_ID_ALIASES.duplicate()

func _ready() -> void:
	print("[PlayerFactory] 已初始化")

## 创建指定 ID 的玩家角色
## 
## 参数：
##   player_id: 角色 ID（如 "butcher", "lurewarden" 等）
## 
## 返回：
##   创建的玩家实例（PlayerBase 或其子类）
func create_player(player_id: String) -> PlayerBase:
	if player_id.is_empty():
		printerr("[PlayerFactory] 错误: player_id 为空")
		return null
	var normalized_player_id := _normalize_player_id(player_id)
	
	# 1. 加载通用场景
	var scene = load(PLAYER_GENERIC_SCENE) as PackedScene
	if not scene:
		printerr("[PlayerFactory] 错误: 无法加载通用场景 %s" % PLAYER_GENERIC_SCENE)
		return null
	
	# 2. 实例化场景
	var player = scene.instantiate() as PlayerBase
	if not player:
		printerr("[PlayerFactory] 错误: 场景实例化失败，player_id=%s" % player_id)
		return null
	
	# 3. 设置 player_id（必须在加载脚本之前）
	player.player_id = normalized_player_id
	if normalized_player_id != player_id:
		print("[PlayerFactory] 旧角色ID已映射: %s -> %s" % [player_id, normalized_player_id])
	print("[PlayerFactory] 设置 player_id: %s" % normalized_player_id)
	
	# 4. 加载角色特定脚本（必须在 add_child 之前）
	_load_character_script(player, normalized_player_id)
	
	print("[PlayerFactory] 成功创建角色: %s" % normalized_player_id)
	return player

func _normalize_player_id(player_id: String) -> String:
	if player_id.is_empty():
		return player_id
	return str(LEGACY_PLAYER_ID_ALIASES.get(player_id, player_id))

## 加载角色特定脚本
func _load_character_script(player: PlayerBase, player_id: String) -> void:
	# 检查是否有脚本映射
	var actual_script_id = script_mapping.get(player_id, player_id)
	
	var script_path = PLAYER_SCRIPT_TEMPLATE % actual_script_id
	var script = load(script_path) as Script
	
	if not script:
		print("[PlayerFactory] 警告: 未找到角色脚本 %s，使用默认 PlayerBase" % script_path)
		return
	
	# 设置脚本（在 _ready 之前）
	player.set_script(script)
	print("[PlayerFactory] 已加载脚本: %s (player_id=%s)" % [script_path, player_id])

## 获取所有可用的角色 ID
func get_available_players() -> Array[String]:
	var players: Array[String] = []
	var config = ConfigManager.get_all_player_configs()
	
	for player_id in config.keys():
		if config[player_id].get("enabled", false):
			players.append(player_id)
	
	return players

## 检查角色是否存在
func has_player(player_id: String) -> bool:
	var config = ConfigManager.get_player_config(_normalize_player_id(player_id))
	return not config.is_empty()
