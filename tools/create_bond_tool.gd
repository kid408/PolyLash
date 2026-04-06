@tool
extends EditorScript

## ==============================================================================
## 羁绊创建工具
## ==============================================================================
##
## 使用方法：
## 1. 修改 _run() 中的 config 字典
## 2. 在 Godot 编辑器中：File -> Run
## 3. 工具会自动将羁绊追加到当前生效羁绊表
##    - 写入: bond_config.csv
##
## 羁绊类型说明：
##   - origin  : 身世羁绊（如 魔导/重装/游侠/后勤）
##   - mastery : 职能羁绊（如 爆破师/筑墙者/咒术师/几何学家）
##   - tactic  : 战术羁绊（如 支援型/突击型/指挥型）
##
## 效果类型说明：
##   - stat_mod  : 属性修改（百分比或固定值，通过 BondManager.apply_stat_modifiers 生效）
##   - mechanic  : 机制效果（通过 BondManager.has_mechanic / get_mechanic_value 查询）
##
## ==============================================================================

# ==============================================================================
# 主函数
# ==============================================================================

func _run() -> void:
	print("\n================================================================================")
	print("羁绊创建工具")
	print("================================================================================\n")
	print("当前写入目标: %s\n" % _get_bond_csv_path())

	# ============================================================================
	# 在这里修改配置，然后 File -> Run
	# ============================================================================

	var config = {
		# ---------- 基础信息 ----------
		"bond_id": "example",                # 羁绊ID（英文，与 player_config 中的标签对应）
		"bond_type": "origin",               # 类型: "origin" | "mastery" | "tactic"
		"display_name": "示例羁绊",           # 显示名称（中文）
		"icon_path_index": 1,                # 图标索引（对应 assets/sprites/Icons/ 下的编号）

		# ---------- 等级配置（数组，每个元素是一个等级） ----------
		"levels": [
			{
				"level": 1,
				"required_count": 2,           # 激活所需标签数量
				"effect_type": "stat_mod",     # 效果类型: "stat_mod" | "mechanic"
				"effect_param": "max_health_pct",  # 效果参数名
				"effect_value": 0.25,          # 效果数值
				"description": "全队生命上限+25%",
			},
			{
				"level": 2,
				"required_count": 3,
				"effect_type": "mechanic",
				"effect_param": "super_armor",
				"effect_value": 1,
				"description": "画闭合图形时霸体",
			},
			{
				"level": 3,
				"required_count": 5,
				"effect_type": "stat_mod",
				"effect_param": "max_health_pct",
				"effect_value": 0.6,
				"description": "全队生命上限+60%",
			},
		],

		# ---------- 可选：同时创建对应的徽章 ----------
		"create_emblem": true,               # 是否同时在 emblem_config.csv 创建徽章
		"emblem_price": 120,                 # 徽章商店价格
		"emblem_icon": "res://assets/emblems/example.png",
	}

	# ============================================================================

	var success = create_bond(config)

	if success:
		print("\n================================================================================")
		print("✅ 羁绊创建成功: %s (%s)" % [config.display_name, config.bond_id])
		print("================================================================================")
		_print_next_steps(config)
	else:
		print("\n❌ 创建失败，请检查上方错误信息")

# ==============================================================================
# 创建羁绊
# ==============================================================================

func create_bond(config: Dictionary) -> bool:
	var bond_id = config.get("bond_id", "")
	if bond_id.is_empty():
		printerr("[CreateBondTool] 错误: bond_id 不能为空")
		return false

	var levels = config.get("levels", [])
	if levels.is_empty():
		printerr("[CreateBondTool] 错误: 至少需要定义一个等级")
		return false

	# 检查是否已存在
	if _bond_exists(bond_id):
		printerr("[CreateBondTool] 错误: bond_id 已存在: %s" % bond_id)
		return false

	# 验证配置
	if not _validate_config(config):
		return false

	# 写入 bond_config.csv
	if not _write_bond_config(config):
		return false

	# 可选：创建对应徽章
	if config.get("create_emblem", false):
		_create_matching_emblem(config)

	# 可选：创建对应圣物
	if config.get("create_relic", false):
		_create_matching_relic(config)

	return true

# ==============================================================================
# 写入 bond_config.csv
# ==============================================================================

func _write_bond_config(config: Dictionary) -> bool:
	var csv_path = _get_bond_csv_path()
	var bond_id = config.bond_id
	var bond_type = config.get("bond_type", "origin")
	var icon_idx = config.get("icon_path_index", 1)
	var display_name = config.get("display_name", bond_id)
	var levels = config.get("levels", [])

	for level_data in levels:
		# bond_id,type,level,required_count,effect_type,effect_param,effect_value,icon_path_index,display_name,description
		var row = PackedStringArray([
			bond_id,
			bond_type,
			str(level_data.get("level", 1)),
			str(level_data.get("required_count", 2)),
			str(level_data.get("effect_type", "stat_mod")),
			str(level_data.get("effect_param", "")),
			str(level_data.get("effect_value", 0)),
			str(icon_idx),
			display_name,
			str(level_data.get("description", "")),
		])

		if not _append_csv_row(csv_path, row):
			return false

	print("[CreateBondTool] ✅ 已写入 %d 个等级到 %s" % [levels.size(), csv_path.get_file()])
	return true

# ==============================================================================
# 创建对应徽章（emblem_config.csv）
# ==============================================================================

func _create_matching_emblem(config: Dictionary) -> void:
	var emblem_id = "emblem_%s" % config.bond_id
	var csv_path = "res://config/item/emblem_config.csv"

	if _id_exists_in_csv(csv_path, emblem_id):
		print("[CreateBondTool] ⚠️ 徽章已存在，跳过: %s" % emblem_id)
		return

	var display_name = "%s徽章" % config.get("display_name", config.bond_id)
	var icon_path = config.get("emblem_icon", "res://assets/emblems/%s.png" % config.bond_id)
	var price = config.get("emblem_price", 120)

	# emblem_id,display_name,artifact_type,bond_tag,rarity,shop_price,is_unique,icon_path,description
	var row = PackedStringArray([
		emblem_id,
		display_name,
		"emblem",
		config.bond_id,
		"common",
		str(price),
		"0",
		icon_path,
		"全队%s标签+1" % config.get("display_name", config.bond_id),
	])

	if _append_csv_row(csv_path, row):
		print("[CreateBondTool] ✅ 已创建徽章: %s" % emblem_id)

# ==============================================================================
# 创建对应圣物（item_config.csv）
# ==============================================================================

func _create_matching_relic(config: Dictionary) -> void:
	var relic_id = "relic_%s" % config.bond_id
	var csv_path = "res://config/item/item_config.csv"

	if _id_exists_in_csv(csv_path, relic_id):
		print("[CreateBondTool] ⚠️ 圣物已存在，跳过: %s" % relic_id)
		return

	var display_name = "%s圣物" % config.get("display_name", config.bond_id)
	var relic_cfg = config.get("relic_config", {})
	var base_stat = relic_cfg.get("base_stat", "hp")
	var base_value = relic_cfg.get("base_value", 300)
	var mod_type = relic_cfg.get("mod_type", "max_health_pct")
	var mod_value = relic_cfg.get("mod_value", "0.15")
	var price = relic_cfg.get("shop_price", 200)
	var icon_path = relic_cfg.get("icon_path", "res://assets/sprites/Icons/origins/origin1.png")

	# id,name,tier,type,slot_type,base_stat,base_value,mod_type,mod_value,bond_grant,shop_price,icon_path,description
	var row = PackedStringArray([
		relic_id,
		display_name,
		"3",
		"equipment",
		"weapon",
		base_stat,
		str(base_value),
		mod_type,
		mod_value,
		config.bond_id,
		str(price),
		icon_path,
		"%s神器" % config.get("display_name", config.bond_id),
	])

	if _append_csv_row(csv_path, row):
		print("[CreateBondTool] ✅ 已创建圣物: %s" % relic_id)

# ==============================================================================
# 批量创建
# ==============================================================================

func create_bonds_batch(configs: Array) -> int:
	var ok_count = 0
	for cfg in configs:
		if create_bond(cfg):
			ok_count += 1
	print("\n[CreateBondTool] 批量创建完成: %d/%d 成功" % [ok_count, configs.size()])
	return ok_count

# ==============================================================================
# 为已有羁绊添加新等级
# ==============================================================================

func add_level_to_bond(bond_id: String, level_data: Dictionary) -> bool:
	"""为已存在的羁绊追加一个新等级"""
	if not _bond_exists(bond_id):
		printerr("[CreateBondTool] 错误: 羁绊不存在: %s" % bond_id)
		return false

	# 从现有配置中读取 bond_type、icon_path_index、display_name
	var existing = _read_bond_info(bond_id)
	if existing.is_empty():
		printerr("[CreateBondTool] 错误: 无法读取羁绊信息: %s" % bond_id)
		return false

	var csv_path = _get_bond_csv_path()
	var row = PackedStringArray([
		bond_id,
		existing.get("type", "origin"),
		str(level_data.get("level", 1)),
		str(level_data.get("required_count", 2)),
		str(level_data.get("effect_type", "stat_mod")),
		str(level_data.get("effect_param", "")),
		str(level_data.get("effect_value", 0)),
		str(existing.get("icon_path_index", 1)),
		existing.get("display_name", bond_id),
		str(level_data.get("description", "")),
	])

	if _append_csv_row(csv_path, row):
		print("[CreateBondTool] ✅ 已为 %s 添加 Lv.%d" % [bond_id, level_data.get("level", 1)])
		return true
	return false

# ==============================================================================
# 预设模板
# ==============================================================================

func get_preset_templates() -> Dictionary:
	return {
		"origin_stat": {
			"bond_type": "origin",
			"icon_path_index": 1,
			"levels": [
				{"level": 1, "required_count": 2, "effect_type": "stat_mod",
				 "effect_param": "max_health_pct", "effect_value": 0.25,
				 "description": "全队生命上限+25%"},
				{"level": 2, "required_count": 3, "effect_type": "stat_mod",
				 "effect_param": "max_health_pct", "effect_value": 0.5,
				 "description": "全队生命上限+50%"},
				{"level": 3, "required_count": 5, "effect_type": "stat_mod",
				 "effect_param": "max_health_pct", "effect_value": 0.8,
				 "description": "全队生命上限+80%"},
			],
			"create_emblem": true,
		},
		"mastery_mechanic": {
			"bond_type": "mastery",
			"icon_path_index": 1,
			"levels": [
				{"level": 1, "required_count": 2, "effect_type": "mechanic",
				 "effect_param": "custom_mechanic", "effect_value": 0.2,
				 "description": "自定义机制效果+20%"},
				{"level": 2, "required_count": 3, "effect_type": "mechanic",
				 "effect_param": "custom_mechanic_2", "effect_value": 1,
				 "description": "解锁高级机制"},
				{"level": 3, "required_count": 5, "effect_type": "mechanic",
				 "effect_param": "custom_mechanic_3", "effect_value": 1,
				 "description": "终极机制"},
			],
			"create_emblem": true,
		},
		"tactic_2level": {
			"bond_type": "tactic",
			"icon_path_index": 1,
			"levels": [
				{"level": 1, "required_count": 2, "effect_type": "mechanic",
				 "effect_param": "tactic_effect_1", "effect_value": 0.3,
				 "description": "战术效果Lv.1"},
				{"level": 2, "required_count": 4, "effect_type": "mechanic",
				 "effect_param": "tactic_effect_2", "effect_value": 1,
				 "description": "战术效果Lv.2"},
			],
			"create_emblem": true,
		},
	}

func create_from_preset(bond_id: String, display_name: String, preset_name: String) -> bool:
	var presets = get_preset_templates()
	if not presets.has(preset_name):
		printerr("[CreateBondTool] 未知预设: %s" % preset_name)
		return false
	var cfg = presets[preset_name].duplicate(true)
	cfg["bond_id"] = bond_id
	cfg["display_name"] = display_name
	return create_bond(cfg)

# ==============================================================================
# 验证
# ==============================================================================

func _validate_config(config: Dictionary) -> bool:
	var bond_type = config.get("bond_type", "")
	if bond_type not in ["origin", "mastery", "tactic"]:
		printerr("[CreateBondTool] 错误: bond_type 必须是 origin/mastery/tactic，当前: %s" % bond_type)
		return false

	var levels = config.get("levels", [])
	for i in range(levels.size()):
		var ld = levels[i]
		if not ld.has("level") or not ld.has("required_count"):
			printerr("[CreateBondTool] 错误: levels[%d] 缺少 level 或 required_count" % i)
			return false
		if ld.get("effect_type", "") not in ["stat_mod", "mechanic"]:
			printerr("[CreateBondTool] 错误: levels[%d].effect_type 必须是 stat_mod 或 mechanic" % i)
			return false

	return true

func _bond_exists(bond_id: String) -> bool:
	return _id_exists_in_csv(_get_bond_csv_path(), bond_id)

func _read_bond_info(bond_id: String) -> Dictionary:
	"""读取已有羁绊的基本信息（type, icon_path_index, display_name）"""
	var csv_path = _get_bond_csv_path()
	if not FileAccess.file_exists(csv_path):
		return {}
	var file = FileAccess.open(csv_path, FileAccess.READ)
	if not file:
		return {}
	while not file.eof_reached():
		var line = file.get_csv_line()
		if line.size() >= 10 and line[0].strip_edges() == bond_id:
			file.close()
			return {
				"type": line[1].strip_edges(),
				"icon_path_index": line[7].strip_edges(),
				"display_name": line[8].strip_edges(),
			}
	file.close()
	return {}

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
		var row = file.get_csv_line()
		if row.is_empty():
			continue
		var row_id = str(row[0]).strip_edges()
		if row_id == target_id:
			file.close()
			return true
	file.close()
	return false

func _get_bond_csv_path() -> String:
	return "res://config/player/bond_config.csv"

func _append_csv_row(file_path: String, row: PackedStringArray) -> bool:
	if not FileAccess.file_exists(file_path):
		printerr("[CreateBondTool] 文件不存在: %s" % file_path)
		return false

	var file = FileAccess.open(file_path, FileAccess.READ)
	if not file:
		printerr("[CreateBondTool] 无法读取文件: %s" % file_path)
		return false
	var content = file.get_as_text()
	file.close()

	file = FileAccess.open(file_path, FileAccess.READ_WRITE)
	if not file:
		printerr("[CreateBondTool] 无法写入文件: %s" % file_path)
		return false
	file.seek_end()
	if content.length() > 0 and not content.ends_with("\n"):
		file.store_string("\n")
	file.store_csv_line(row)
	file.close()
	return true

# ==============================================================================
# 使用指南
# ==============================================================================

func _print_next_steps(config: Dictionary) -> void:
	print("\n📖 下一步:")
	print("────────────────────────────────────────")
	print("1. 重启游戏使 BondManager 重新加载 %s" % _get_bond_csv_path().get_file())
	print("2. 在 player_config.csv 中为角色分配标签:")
	print("   - origin_tag / mastery_tag / tactic_tag 列填入 '%s'" % config.bond_id)
	print("3. 选择足够数量的角色即可激活羁绊")
	if config.get("create_emblem", false):
		print("4. 对应徽章 emblem_%s 已创建，可在商店购买" % config.bond_id)
	print("")
	print("效果类型说明:")
	print("  stat_mod  → 自动通过 BondManager.apply_stat_modifiers() 生效")
	print("  mechanic  → 需在技能代码中查询:")
	print("              if BondManager.has_mechanic(\"xxx\"): ...")
	print("              var val = BondManager.get_mechanic_value(\"xxx\")")
	print("────────────────────────────────────────")
