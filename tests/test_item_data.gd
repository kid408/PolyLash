extends Node

## ==============================================================================
## 道具数据测试脚本
## ==============================================================================
## 
## 使用方法：
## 1. 将此脚本添加到测试场景
## 2. 运行场景
## 3. 查看控制台输出
## 
## ==============================================================================

func _ready() -> void:
	print("\n========== 道具数据测试开始 ==========\n")
	
	test_warehouse_initialization()
	test_item_configs()
	test_item_effect_configs()
	
	print("\n========== 道具数据测试完成 ==========\n")

# ==============================================================================
# 测试 1: 仓库初始化
# ==============================================================================

func test_warehouse_initialization() -> void:
	print("【测试 1】仓库初始化")
	
	if not WarehouseManager:
		printerr("❌ WarehouseManager 未加载")
		return
	
	var items = WarehouseManager.get_all_items()
	print("✅ 仓库道具数量: %d" % items.size())
	
	if items.size() == 15:
		print("✅ 默认道具数量正确（15个）")
	else:
		printerr("❌ 默认道具数量错误，预期 15，实际 %d" % items.size())
	
	# 打印前 5 个道具
	print("\n前 5 个道具：")
	for i in range(min(5, items.size())):
		var item_type = items.get(i, 0)
		var config = WarehouseManager.get_item_config(item_type)
		print("  槽位 %d: 道具 %d - %s" % [i, item_type, config.get("description", "未知")])

# ==============================================================================
# 测试 2: item_config.csv 配置
# ==============================================================================

func test_item_configs() -> void:
	print("\n【测试 2】item_config.csv 配置")
	
	var test_items = [
		{"id": 1, "name": "生命药水", "icon": "origin1.png"},
		{"id": 4, "name": "火焰之心", "icon": "mastery1.png"},
		{"id": 10, "name": "武道圣物", "icon": "tactic1.png"}
	]
	
	for item in test_items:
		var config = WarehouseManager.get_item_config(item["id"])
		if config.is_empty():
			printerr("❌ 道具 %d 配置不存在" % item["id"])
			continue
		
		var desc = config.get("description", "")
		var icon = config.get("resourcePath", "")
		
		if item["name"] in desc:
			print("✅ 道具 %d: %s" % [item["id"], desc])
		else:
			printerr("❌ 道具 %d 名称不匹配" % item["id"])
		
		if item["icon"] in icon:
			print("  ✅ 图标路径正确: %s" % icon)
		else:
			printerr("  ❌ 图标路径错误: %s" % icon)

# ==============================================================================
# 测试 3: item_effect_config.csv 配置
# ==============================================================================

func test_item_effect_configs() -> void:
	print("\n【测试 3】item_effect_config.csv 配置")
	
	var test_cases = [
		{"item_id": "attr_hp_potion", "tier": 1, "effect": "flat_add"},
		{"item_id": "magic_fire_heart", "tier": 2, "effect": "percent_add"},
		{"item_id": "relic_martial", "tier": 3, "effect": "bond_tag"}
	]
	
	for test in test_cases:
		var config = _load_item_effect_config(test["item_id"])
		if config.is_empty():
			printerr("❌ 道具效果配置不存在: %s" % test["item_id"])
			continue
		
		var tier = int(config.get("item_tier", 0))
		var effect_type = config.get("effect_type", "")
		
		if tier == test["tier"]:
			print("✅ %s: Tier %d" % [test["item_id"], tier])
		else:
			printerr("❌ %s: Tier 错误，预期 %d，实际 %d" % [test["item_id"], test["tier"], tier])
		
		if effect_type == test["effect"]:
			print("  ✅ 效果类型: %s" % effect_type)
		else:
			printerr("  ❌ 效果类型错误，预期 %s，实际 %s" % [test["effect"], effect_type])

# ==============================================================================
# 辅助函数
# ==============================================================================

func _load_item_effect_config(item_id: String) -> Dictionary:
	var file = FileAccess.open("res://config/item/item_effect_config.csv", FileAccess.READ)
	if not file:
		return {}
	
	file.get_line()  # 跳过表头
	
	while not file.eof_reached():
		var line = file.get_csv_line()
		if line.size() < 10:
			continue
		
		if line[0] == item_id:
			return {
				"item_id": line[0],
				"item_name": line[1],
				"item_type": line[2],
				"item_tier": line[3],
				"effect_type": line[4],
				"effect_target": line[5],
				"target_tags": line[6],
				"effect_value": line[7],
				"icon_path": line[8],
				"description": line[9]
			}
	
	return {}
