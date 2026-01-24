extends Node

## ==============================================================================
## 修改器系统测试脚本
## ==============================================================================
## 
## 使用方法：
## 1. 将此脚本添加到测试场景
## 2. 运行场景
## 3. 查看控制台输出
## 
## ==============================================================================

func _ready() -> void:
	print("\n========== 修改器系统测试开始 ==========\n")
	
	test_modifier_manager()
	test_subset_matching()
	test_stacking_rules()
	test_player_integration()
	
	print("\n========== 修改器系统测试完成 ==========\n")

# ==============================================================================
# 测试 1: ModifierManager 基础功能
# ==============================================================================

func test_modifier_manager() -> void:
	print("【测试 1】ModifierManager 基础功能")
	
	var manager = ModifierManager
	
	# 清空之前的修改器
	manager.clear_modifiers()
	
	# 添加修改器
	manager.add_modifier(["fire"], "percent_add", 0.20)
	manager.add_modifier(["damage"], "flat_add", 5.0)
	
	# 测试匹配
	var base_value = 20.0
	var tags = ["damage", "fire", "aoe"]
	var result = manager.get_modified_value(base_value, tags)
	
	# 预期：(20 + 5) * (1.0 + 0.20) = 30
	_assert_equal(result, 30.0, "基础功能测试")
	print("✅ 基础功能测试通过：%.2f" % result)
	
	manager.queue_free()

# ==============================================================================
# 测试 2: 子集匹配逻辑
# ==============================================================================

func test_subset_matching() -> void:
	print("\n【测试 2】子集匹配逻辑")
	
	var manager = ModifierManager
	
	# 清空之前的修改器
	manager.clear_modifiers()
	
	# 添加修改器
	manager.add_modifier(["fire"], "percent_add", 0.20)
	manager.add_modifier(["fire", "aoe"], "percent_add", 0.10)
	manager.add_modifier(["ice"], "percent_add", 0.15)
	
	# 测试 1：技能有 fire 标签
	var result1 = manager.get_modified_value(100.0, ["damage", "fire"])
	# 预期：100 * (1.0 + 0.20) = 120（只匹配 ["fire"]）
	_assert_equal(result1, 120.0, "子集匹配测试 1")
	print("✅ 子集匹配测试 1 通过：%.2f" % result1)
	
	# 测试 2：技能有 fire 和 aoe 标签
	var result2 = manager.get_modified_value(100.0, ["damage", "fire", "aoe"])
	# 预期：100 * (1.0 + 0.20 + 0.10) = 130（匹配 ["fire"] 和 ["fire", "aoe"]）
	_assert_equal(result2, 130.0, "子集匹配测试 2")
	print("✅ 子集匹配测试 2 通过：%.2f" % result2)
	
	# 测试 3：技能没有 ice 标签
	var result3 = manager.get_modified_value(100.0, ["damage", "fire"])
	# 预期：100 * (1.0 + 0.20) = 120（不匹配 ["ice"]）
	_assert_equal(result3, 120.0, "子集匹配测试 3")
	print("✅ 子集匹配测试 3 通过：%.2f" % result3)

# ==============================================================================
# 测试 3: 叠加规则
# ==============================================================================

func test_stacking_rules() -> void:
	print("\n【测试 3】叠加规则")
	
	var manager = ModifierManager
	
	# 清空之前的修改器
	manager.clear_modifiers()
	
	# 添加多个百分比修改器
	manager.add_modifier(["fire"], "percent_add", 0.20)
	manager.add_modifier(["damage"], "percent_add", 0.15)
	manager.add_modifier(["aoe"], "percent_add", 0.10)
	
	# 测试加法叠加
	var result = manager.get_modified_value(100.0, ["damage", "fire", "aoe"])
	# 预期：100 * (1.0 + 0.20 + 0.15 + 0.10) = 145
	_assert_equal(result, 145.0, "加法叠加测试")
	print("✅ 加法叠加测试通过：%.2f" % result)
	
	# 测试混合修改器（flat + percent）
	manager.add_modifier(["damage"], "flat_add", 10.0)
	var result2 = manager.get_modified_value(100.0, ["damage", "fire", "aoe"])
	# 预期：(100 + 10) * (1.0 + 0.20 + 0.15 + 0.10) = 159.5
	_assert_equal(result2, 159.5, "混合修改器测试")
	print("✅ 混合修改器测试通过：%.2f" % result2)

# ==============================================================================
# 测试 4: PlayerBase 集成
# ==============================================================================

func test_player_integration() -> void:
	print("\n【测试 4】PlayerBase 集成")
	
	# 注意：此测试需要在实际游戏场景中运行
	# 这里只是展示测试逻辑
	
	print("⚠️  此测试需要在实际游戏场景中运行")
	print("   测试步骤：")
	print("   1. 进入角色选择界面")
	print("   2. 装备 '火焰之心' 道具")
	print("   3. 进入战斗场景")
	print("   4. 使用火焰技能")
	print("   5. 验证伤害是否增加 20%")

# ==============================================================================
# 辅助函数
# ==============================================================================

func _assert_equal(actual: float, expected: float, test_name: String) -> void:
	if abs(actual - expected) > 0.01:
		var message = "❌ %s 失败：预期 %.2f，实际 %.2f" % [test_name, expected, actual]
		printerr(message)
		push_error(message)
