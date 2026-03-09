@tool
extends EditorScript

# ============================================================================
# 角色可用武器自动分配工具（当前流程版）
# ============================================================================
#
# 功能：
# - 从 player_config.csv 动态读取当前启用角色
# - 从 weapon_config_optimized.csv 动态读取武器基类 ID
# - 生成 player_available_weapons.csv（4列：前三列分配，第4列留空）
#
# 设计：
# - weapon_type_1：默认武器，尽量全角色唯一（武器数量不足时才循环）
# - weapon_type_2/3：按偏移轮转，保证同角色内不重复
# ============================================================================

const PLAYER_CONFIG_PATH := "res://config/player/player_config.csv"
const WEAPON_CONFIG_PATH := "res://config/weapon/weapon_config_optimized.csv"
const OUTPUT_PATH := "res://config/player/player_available_weapons.csv"

func _run() -> void:
	print("========== 开始分配角色可用武器 ==========")

	var player_ids := _load_enabled_player_ids()
	var weapon_types := _load_weapon_types()

	if player_ids.is_empty():
		printerr("❌ 未读取到启用角色，请检查 %s" % PLAYER_CONFIG_PATH)
		return
	if weapon_types.size() < 3:
		printerr("❌ 可用武器类型不足（至少需要3个），当前: %d" % weapon_types.size())
		return

	var assignments := _build_assignments(player_ids, weapon_types)
	_write_output(assignments, player_ids)

	print("\n========== 分配完成 ==========")
	print("角色数: %d" % player_ids.size())
	print("武器类型数: %d" % weapon_types.size())
	print("输出文件: %s" % OUTPUT_PATH)

func _load_enabled_player_ids() -> Array[String]:
	var ids: Array[String] = []
	var file := FileAccess.open(PLAYER_CONFIG_PATH, FileAccess.READ)
	if file == null:
		return ids

	while not file.eof_reached():
		var row := file.get_csv_line()
		if row.size() < 4:
			continue
		var player_id := str(row[0]).strip_edges()
		if player_id.is_empty() or player_id == "player_id" or player_id == "-1":
			continue
		var enabled_val := str(row[3]).strip_edges()
		if enabled_val == "0":
			continue
		ids.append(player_id)

	file.close()
	return ids

func _load_weapon_types() -> Array[String]:
	var out: Array[String] = []
	var seen: Dictionary = {}

	var file := FileAccess.open(WEAPON_CONFIG_PATH, FileAccess.READ)
	if file == null:
		return out

	while not file.eof_reached():
		var row := file.get_csv_line()
		if row.size() < 1:
			continue
		var weapon_id := str(row[0]).strip_edges()
		if weapon_id.is_empty() or weapon_id == "weapon_base_id" or weapon_id == "-1":
			continue
		if seen.has(weapon_id):
			continue
		seen[weapon_id] = true
		out.append(weapon_id)

	file.close()
	return out

func _build_assignments(player_ids: Array[String], weapon_types: Array[String]) -> Dictionary:
	var result: Dictionary = {}
	var count := weapon_types.size()

	for i in range(player_ids.size()):
		var pid := player_ids[i]
		var w1 := weapon_types[i % count]

		var w2_idx := (i + 7) % count
		while weapon_types[w2_idx] == w1:
			w2_idx = (w2_idx + 1) % count
		var w2 := weapon_types[w2_idx]

		var w3_idx := (i + 13) % count
		while weapon_types[w3_idx] == w1 or weapon_types[w3_idx] == w2:
			w3_idx = (w3_idx + 1) % count
		var w3 := weapon_types[w3_idx]

		result[pid] = [w1, w2, w3, ""]
		print("%s -> %s, %s, %s" % [pid, w1, w2, w3])

	return result

func _write_output(assignments: Dictionary, player_ids: Array[String]) -> void:
	var file := FileAccess.open(OUTPUT_PATH, FileAccess.WRITE)
	if file == null:
		printerr("❌ 无法写入: %s" % OUTPUT_PATH)
		return

	file.store_line("player_id,weapon_type_1,weapon_type_2,weapon_type_3,weapon_type_4")
	file.store_line("-1,武器类型1,武器类型2,武器类型3,武器类型4")

	for pid in player_ids:
		var weapons: Array = assignments.get(pid, ["punch", "laser", "pistol", ""])
		file.store_csv_line(PackedStringArray([
			pid,
			str(weapons[0]),
			str(weapons[1]),
			str(weapons[2]),
			str(weapons[3])
		]))

	file.close()
	print("✅ 已更新 %s" % OUTPUT_PATH)
