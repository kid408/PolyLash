@tool
extends EditorScript

## ==============================================================================
## 道具创建工具
## ==============================================================================
##
## 使用方法：
## 1. 修改 _run() 中的 config 字典
## 2. 在 Godot 编辑器中：File -> Run
## 3. 工具会自动将道具追加到对应的 CSV 配置文件
##
## 支持创建的道具类型：
##   - Tier 1 属性道具（直接加数值）
##   - Tier 2 魔法道具（百分比修正）
##   - Tier 3 圣物道具（提供羁绊标签 + 属性）
##   - 消耗品（立即使用，不占槽位）
##   - 徽章（全局羁绊标签，通过 EmblemManager 管理）
##   - 遗物（全局唯一效果，通过 EmblemManager 管理）
##
## ==============================================================================

# ==============================================================================
# 主函数
# ==============================================================================

func _run() -> void:
	print("\n================================================================================")
	print("道具创建工具")
	print("================================================================================\n")

	# ============================================================================
	# 在这里修改配置，然后 File -> Run
	# ============================================================================

	var config = {
		# ---------- 必填字段 ----------
		"item_id": "relic_example",          # 道具唯一ID（英文，下划线分隔）
		"item_name": "示例圣物",              # 显示名称（中文）
		"item_category": "item",             # 道具大类: "item" | "emblem"
		#                                      item  → 写入 item_config.csv
		#                                      emblem → 写入 emblem_config.csv

		# ---------- item 类道具字段 ----------
		"tier": 3,                           # 层级: 0=消耗品, 1=属性, 2=魔法, 3=圣物
		"type": "equipment",                 # 类型: "equipment" | "consumable"
		"slot_type": "weapon",               # 槽位类型（目前统一 "weapon"）
		"base_stat": "hp",                   # 基础属性: hp / speed / attack / energy
		"base_value": 400,                   # 基础属性数值
		"mod_type": "max_health_pct",        # 修正类型（可用分号分隔多个）
		"mod_value": "0.20",                 # 修正数值（可用分号分隔多个）
		"bond_grant": "colossus",            # 提供的羁绊标签（仅 Tier 3 圣物）
		"shop_price": 200,                   # 商店价格
		"icon_path": "res://assets/sprites/Icons/origins/origin2.png",
		"description": "示例圣物 生命+400 最大生命+20%",

		# ---------- emblem 类道具字段 ----------
		# "artifact_type": "emblem",         # 护符类型: "emblem" | "relic"
		# "bond_tag": "inkborn",             # 羁绊标签（emblem 类必填）
		# "rarity": "common",               # 稀有度: common / rare / legendary
		# "is_unique": 0,                    # 是否唯一: 0=可叠加, 1=唯一
	}

	# ============================================================================

	var category = config.get("item_category", "item")
	var success = false

	match category:
		"item":
			success = create_item(config)
		"emblem":
			success = create_emblem(config)
		_:
			printerr("未知的 item_category: %s（应为 item 或 emblem）" % category)

	if success:
		print("\n================================================================================")
		print("✅ 道具创建成功: %s (%s)" % [config.item_name, config.item_id])
		print("================================================================================")
		_print_next_steps(config)
	else:
		print("\n❌ 创建失败，请检查上方错误信息")

# ==============================================================================
# 创建 item_config.csv 道具
# ==============================================================================

func create_item(config: Dictionary) -> bool:
	var item_id = config.get("item_id", "")
	if item_id.is_empty():
		printerr("[CreateItemTool] 错误: item_id 不能为空")
		return false

	if _id_exists_in_csv("res://config/item/item_config.csv", item_id):
		printerr("[CreateItemTool] 错误: item_id 已存在: %s" % item_id)
		return false

	# 构建 CSV 行（列顺序与 item_config.csv 表头一致）
	# id,name,tier,type,slot_type,base_stat,base_value,mod_type,mod_value,bond_grant,shop_price,icon_path,description
	var line = ",".join(PackedStringArray([
		str(config.get("item_id", "")),
		str(config.get("item_name", "")),
		str(config.get("tier", 1)),
		str(config.get("type", "equipment")),
		str(config.get("slot_type", "weapon")),
		str(config.get("base_stat", "")),
		str(config.get("base_value", 0)),
		str(config.get("mod_type", "")),
		str(config.get("mod_value", "")),
		str(config.get("bond_grant", "")),
		str(config.get("shop_price", 0)),
		str(config.get("icon_path", "")),
		str(config.get("description", "")),
	]))

	if not _append_line("res://config/item/item_config.csv", line):
		return false

	print("[CreateItemTool] ✅ 已写入 item_config.csv")

	# 如果同时需要写入 item_effect_config.csv（Tier 2/3 道具）
	if config.get("tier", 1) >= 2 and config.get("write_effect", false):
		_write_item_effect(config)

	return true

# ==============================================================================
# 创建 emblem_config.csv 护符/遗物
# ==============================================================================

func create_emblem(config: Dictionary) -> bool:
	var emblem_id = config.get("item_id", "")
	if emblem_id.is_empty():
		printerr("[CreateItemTool] 错误: item_id 不能为空")
		return false

	if _id_exists_in_csv("res://config/item/emblem_config.csv", emblem_id):
		printerr("[CreateItemTool] 错误: emblem_id 已存在: %s" % emblem_id)
		return false

	# emblem_id,display_name,artifact_type,bond_tag,rarity,shop_price,is_unique,icon_path,description
	var line = ",".join(PackedStringArray([
		str(config.get("item_id", "")),
		str(config.get("item_name", "")),
		str(config.get("artifact_type", "emblem")),
		str(config.get("bond_tag", "")),
		str(config.get("rarity", "common")),
		str(config.get("shop_price", 120)),
		str(config.get("is_unique", 0)),
		str(config.get("icon_path", "")),
		str(config.get("description", "")),
	]))

	if not _append_line("res://config/item/emblem_config.csv", line):
		return false

	print("[CreateItemTool] ✅ 已写入 emblem_config.csv")
	return true

# ==============================================================================
# 写入 item_effect_config.csv（可选）
# ==============================================================================

func _write_item_effect(config: Dictionary) -> void:
	var effect_type = "percent_add" if config.get("tier", 1) >= 2 else "flat_add"
	var effect_target = "modifier" if config.get("tier", 1) == 2 else "bond"
	var target_tags = config.get("bond_grant", config.get("mod_type", ""))

	# item_id,item_name,item_type,item_tier,effect_type,effect_target,target_tags,effect_value,icon_path,description
	var line = ",".join(PackedStringArray([
		str(config.get("item_id", "")),
		str(config.get("item_name", "")),
		str(config.get("tier", 2)),
		str(config.get("tier", 2)),
		effect_type,
		effect_target,
		target_tags,
		str(config.get("mod_value", "0")),
		str(config.get("icon_path", "")),
		str(config.get("description", "")),
	]))

	if _append_line("res://config/item/item_effect_config.csv", line):
		print("[CreateItemTool] ✅ 已写入 item_effect_config.csv")

# ==============================================================================
# 批量创建
# ==============================================================================

func create_items_batch(configs: Array) -> int:
	var ok_count = 0
	for cfg in configs:
		var cat = cfg.get("item_category", "item")
		var success = false
		match cat:
			"item": success = create_item(cfg)
			"emblem": success = create_emblem(cfg)
		if success:
			ok_count += 1
	print("\n[CreateItemTool] 批量创建完成: %d/%d 成功" % [ok_count, configs.size()])
	return ok_count

# ==============================================================================
# 预设模板
# ==============================================================================

func get_preset_templates() -> Dictionary:
	return {
		"tier1_hp": {
			"item_category": "item",
			"tier": 1, "type": "equipment", "slot_type": "weapon",
			"base_stat": "hp", "base_value": 50,
			"mod_type": "", "mod_value": "", "bond_grant": "",
			"shop_price": 80,
			"icon_path": "res://assets/sprites/Icons/origins/origin1.png",
		},
		"tier1_speed": {
			"item_category": "item",
			"tier": 1, "type": "equipment", "slot_type": "weapon",
			"base_stat": "speed", "base_value": 50,
			"mod_type": "", "mod_value": "", "bond_grant": "",
			"shop_price": 80,
			"icon_path": "res://assets/sprites/Icons/origins/origin2.png",
		},
		"tier1_attack": {
			"item_category": "item",
			"tier": 1, "type": "equipment", "slot_type": "weapon",
			"base_stat": "attack", "base_value": 10,
			"mod_type": "", "mod_value": "", "bond_grant": "",
			"shop_price": 80,
			"icon_path": "res://assets/sprites/Icons/origins/origin3.png",
		},
		"tier2_magic": {
			"item_category": "item",
			"tier": 2, "type": "equipment", "slot_type": "weapon",
			"base_stat": "attack", "base_value": 15,
			"mod_type": "fire_percent", "mod_value": "0.20", "bond_grant": "",
			"shop_price": 150,
			"icon_path": "res://assets/sprites/Icons/masterys/mastery1.png",
		},
		"tier3_relic": {
			"item_category": "item",
			"tier": 3, "type": "equipment", "slot_type": "weapon",
			"base_stat": "hp", "base_value": 500,
			"mod_type": "max_health_pct", "mod_value": "0.15", "bond_grant": "colossus",
			"shop_price": 200,
			"icon_path": "res://assets/sprites/Icons/origins/origin2.png",
		},
		"consumable_heal": {
			"item_category": "item",
			"tier": 0, "type": "consumable", "slot_type": "",
			"base_stat": "hp", "base_value": 100,
			"mod_type": "", "mod_value": "", "bond_grant": "",
			"shop_price": 50,
			"icon_path": "res://assets/sprites/Icons/origins/origin1.png",
		},
		"emblem_bond": {
			"item_category": "emblem",
			"artifact_type": "emblem",
			"bond_tag": "inkborn", "rarity": "common",
			"is_unique": 0, "shop_price": 120,
			"icon_path": "res://assets/emblems/inkborn.png",
		},
		"emblem_relic": {
			"item_category": "emblem",
			"artifact_type": "relic",
			"bond_tag": "", "rarity": "rare",
			"is_unique": 1, "shop_price": 150,
			"icon_path": "res://assets/emblems/gold_ink.png",
		},
	}

func create_from_preset(item_id: String, item_name: String, preset_name: String) -> bool:
	var presets = get_preset_templates()
	if not presets.has(preset_name):
		printerr("[CreateItemTool] 未知预设: %s" % preset_name)
		return false
	var cfg = presets[preset_name].duplicate()
	cfg["item_id"] = item_id
	cfg["item_name"] = item_name
	var cat = cfg.get("item_category", "item")
	match cat:
		"item": return create_item(cfg)
		"emblem": return create_emblem(cfg)
	return false

# ==============================================================================
# 工具函数
# ==============================================================================

func _id_exists_in_csv(file_path: String, target_id: String) -> bool:
	if not FileAccess.file_exists(file_path):
		return false
	var file = FileAccess.open(file_path, FileAccess.READ)
	if not file:
		return false
	while not file.eof_reached():
		var line = file.get_line().strip_edges()
		if line.begins_with(target_id + ","):
			file.close()
			return true
	file.close()
	return false

func _append_line(file_path: String, line: String) -> bool:
	if not FileAccess.file_exists(file_path):
		printerr("[CreateItemTool] 文件不存在: %s" % file_path)
		return false

	var file = FileAccess.open(file_path, FileAccess.READ)
	if not file:
		printerr("[CreateItemTool] 无法读取文件: %s" % file_path)
		return false
	var content = file.get_as_text()
	file.close()

	file = FileAccess.open(file_path, FileAccess.READ_WRITE)
	if not file:
		printerr("[CreateItemTool] 无法写入文件: %s" % file_path)
		return false
	file.seek_end()
	if content.length() > 0 and not content.ends_with("\n"):
		file.store_string("\n")
	file.store_line(line)
	file.close()
	return true

func _print_next_steps(config: Dictionary) -> void:
	var cat = config.get("item_category", "item")
	print("\n📖 下一步:")
	print("────────────────────────────────────────")
	if cat == "item":
		print("1. 重启游戏使 ConfigManager 重新加载 CSV")
		print("2. 道具会自动出现在仓库/商店系统中")
		if config.get("tier", 0) == 3:
			print("3. 圣物装备后会提供羁绊标签: %s" % config.get("bond_grant", ""))
		print("4. 调整属性请编辑 config/item/item_config.csv")
	else:
		print("1. 重启游戏使 ConfigManager 重新加载 CSV")
		print("2. 护符会出现在波次奖励/商店中")
		print("3. 调整属性请编辑 config/item/emblem_config.csv")
	print("────────────────────────────────────────")
