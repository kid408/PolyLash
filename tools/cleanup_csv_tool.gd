@tool
extends EditorScript

## ==============================================================================
## CSV清理工具
## ==============================================================================
## 
## 用途：清理错误的CSV数据
## 使用方法：File -> Run -> 选择此脚本
## 
## ==============================================================================

# 要清理的角色ID
const CHARACTER_ID_TO_REMOVE = "lovely"

func _run() -> void:
	print("================================================================================")
	print("CSV清理工具")
	print("================================================================================")
	print("")
	print("将要删除角色: %s" % CHARACTER_ID_TO_REMOVE)
	print("")
	
	var files_to_clean = [
		"res://config/player/player_config.csv",
		"res://config/player/player_visual.csv",
		"res://config/player/player_skill_bindings.csv",
		"res://config/player/player_weapons.csv",
		"res://config/player/player_available_weapons.csv",
		"res://config/player/ult_config.csv"
	]
	
	var cleaned_count = 0
	
	for file_path in files_to_clean:
		if _remove_character_from_csv(file_path, CHARACTER_ID_TO_REMOVE):
			cleaned_count += 1
	
	print("")
	print("================================================================================")
	print("✅ 清理完成！")
	print("================================================================================")
	print("")
	print("清理了 %d 个文件" % cleaned_count)
	print("")
	print("下一步：")
	print("1. 重新运行 create_character_tool.gd")
	print("2. 使用正确的格式创建角色")
	print("")

func _remove_character_from_csv(file_path: String, character_id: String) -> bool:
	"""从CSV文件中删除指定角色的行"""
	
	if not FileAccess.file_exists(file_path):
		printerr("❌ 文件不存在: %s" % file_path)
		return false
	
	# 读取所有行（CSV解析，兼容引号）
	var file = FileAccess.open(file_path, FileAccess.READ)
	if not file:
		printerr("❌ 无法打开文件: %s" % file_path)
		return false
	
	var rows: Array[PackedStringArray] = []
	var found = false
	
	# 对于 ult_config.csv，需要匹配 {character_id}_ult
	var is_ult_config = file_path.ends_with("ult_config.csv")
	var search_id = character_id + "_ult" if is_ult_config else character_id
	
	while not file.eof_reached():
		var row = file.get_csv_line()
		if row.is_empty():
			continue
		var row_id = str(row[0]).strip_edges()
		if row_id != search_id:
			rows.append(row)
		else:
			found = true
			var display_id = character_id + "_ult" if is_ult_config else character_id
			print("  从 %s 中删除: %s" % [file_path.get_file(), display_id])
	
	file.close()
	
	if not found:
		var display_id = character_id + "_ult" if is_ult_config else character_id
		print("  %s 中没有找到 %s" % [file_path.get_file(), display_id])
		return false
	
	# 写回文件
	file = FileAccess.open(file_path, FileAccess.WRITE)
	if not file:
		printerr("❌ 无法写入文件: %s" % file_path)
		return false
	
	for row in rows:
		file.store_csv_line(row)
	
	file.close()
	
	print("  ✅ 已清理: %s" % file_path.get_file())
	return true
