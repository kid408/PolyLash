@tool
extends EditorScript

## 敌人创建系统测试脚本
## 用于验证系统是否正常工作

func _run() -> void:
	print("================================================================================")
	print("敌人创建系统测试")
	print("================================================================================")
	
	# 测试1: 创建简单敌人
	print("\n[测试1] 创建简单敌人...")
	var simple_config = {
		"enemy_id": "test_simple",
		"display_name": "测试简单敌人",
		"health": 100,
		"speed": 150,
		"damage": 10,
		"sprite_path": "res://assets/sprites/Enemies/Enemy_1.png"
	}
	
	var tool = load("res://tools/create_enemy_tool.gd").new()
	var result1 = tool.create_enemy(simple_config)
	print("[测试1] 结果: %s" % ("✅ 成功" if result1 else "❌ 失败"))
	
	# 测试2: 创建带能力的敌人
	print("\n[测试2] 创建带能力的敌人...")
	var ability_config = {
		"enemy_id": "test_with_ability",
		"display_name": "测试能力敌人",
		"health": 150,
		"speed": 180,
		"damage": 15,
		"sprite_path": "res://assets/sprites/Enemies/Enemy_2.png",
		"abilities": ["charge"]
	}
	
	var result2 = tool.create_enemy(ability_config)
	print("[测试2] 结果: %s" % ("✅ 成功" if result2 else "❌ 失败"))
	
	# 测试3: 从预设创建
	print("\n[测试3] 从预设创建敌人...")
	var result3 = tool.create_from_preset("test_preset_tank", "tank")
	print("[测试3] 结果: %s" % ("✅ 成功" if result3 else "❌ 失败"))
	
	# 总结
	print("\n================================================================================")
	print("测试完成")
	print("================================================================================")
	print("\n提示:")
	print("1. 检查 config/enemy/ 目录下的CSV文件")
	print("2. 在场景中测试创建的敌人")
	print("3. 如有问题，查看控制台错误信息")
	print("\n创建的测试敌人:")
	print("  - test_simple")
	print("  - test_with_ability")
	print("  - test_preset_tank")
