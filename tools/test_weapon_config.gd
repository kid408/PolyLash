extends Node

# 测试武器配置加载
# 将此脚本添加到场景中运行测试

func _ready() -> void:
	print("=== 测试武器配置 ===")
	
	# 等待 ConfigManager 加载完成
	await get_tree().process_frame
	
	# 测试获取玩家武器配置
	var player_id = "butcher"
	var weapon_cfg = ConfigManager.get_player_weapons(player_id)
	
	print("玩家 ", player_id, " 的武器配置:")
	for i in range(1, 7):
		var slot_key = "weapon_slot_%d" % i
		var weapon_id = weapon_cfg.get(slot_key, "")
		print("  槽位 ", i, ": ", weapon_id)
		
		if weapon_id != "":
			var weapon_data = ConfigManager.get_weapon_config(weapon_id)
			print("    - 场景: ", weapon_data.get("scene_path", "未找到"))
			print("    - 伤害: ", weapon_data.get("damage", 0))
	
	print("=== 测试完成 ===")
