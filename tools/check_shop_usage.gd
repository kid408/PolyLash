@tool
extends EditorScript

# ============================================================================
# 商店系统使用情况检查工具
# ============================================================================
#
# 使用方法：
# 1. 在Godot编辑器中打开此脚本
# 2. 点击 File -> Run
# 3. 查看输出面板的检查结果
#
# ============================================================================

func _run() -> void:
	print("\n" + "=".repeat(60))
	print("商店系统使用情况检查")
	print("=".repeat(60) + "\n")
	
	_check_old_system()
	_check_new_system()
	_check_conflicts()
	_print_recommendations()
	
	print("\n" + "=".repeat(60))
	print("检查完成")
	print("=".repeat(60) + "\n")

func _check_old_system() -> void:
	"""检查旧系统"""
	print("【旧系统检查】")
	
	# 检查配置文件
	var old_config = "res://config/item/shop_item_config.csv"
	if FileAccess.file_exists(old_config):
		print("  ✅ 配置文件存在: %s" % old_config)
		_print_file_info(old_config)
	else:
		print("  ❌ 配置文件不存在: %s" % old_config)
	
	# 检查管理器
	var old_manager = "res://autoloads/shop_manager.gd"
	if FileAccess.file_exists(old_manager):
		print("  ✅ 管理器存在: %s" % old_manager)
	else:
		print("  ❌ 管理器不存在: %s" % old_manager)
	
	# 检查自动加载
	var autoloads = ProjectSettings.get_setting("autoload")
	if autoloads and "ShopManager" in str(autoloads):
		print("  ✅ 已注册为自动加载: ShopManager")
	else:
		print("  ❌ 未注册为自动加载: ShopManager")
	
	# 搜索使用情况
	print("  📊 使用情况:")
	_search_usage("ShopManager")
	
	print("")

func _check_new_system() -> void:
	"""检查新系统"""
	print("【新系统检查】")
	
	# 检查配置文件
	var new_configs = [
		"res://config/wave/shop_attribute_config.csv",
		"res://config/wave/shop_wave_config.csv"
	]
	
	for config in new_configs:
		if FileAccess.file_exists(config):
			print("  ✅ 配置文件存在: %s" % config)
			_print_file_info(config)
		else:
			print("  ❌ 配置文件不存在: %s" % config)
	
	# 检查管理器
	var new_manager = "res://autoloads/shop_attribute_manager.gd"
	if FileAccess.file_exists(new_manager):
		print("  ✅ 管理器存在: %s" % new_manager)
	else:
		print("  ❌ 管理器不存在: %s" % new_manager)
	
	# 检查自动加载
	var autoloads = ProjectSettings.get_setting("autoload")
	if autoloads and "ShopAttributeManager" in str(autoloads):
		print("  ✅ 已注册为自动加载: ShopAttributeManager")
	else:
		print("  ⚠️  未注册为自动加载: ShopAttributeManager")
	
	# 搜索使用情况
	print("  📊 使用情况:")
	_search_usage("ShopAttributeManager")
	
	print("")

func _check_conflicts() -> void:
	"""检查冲突"""
	print("【冲突检查】")
	
	var old_exists = FileAccess.file_exists("res://autoloads/shop_manager.gd")
	var new_exists = FileAccess.file_exists("res://autoloads/shop_attribute_manager.gd")
	
	if old_exists and new_exists:
		print("  ⚠️  两个系统同时存在")
		print("     建议：选择一个系统使用，或明确分工")
	elif old_exists:
		print("  ℹ️  只有旧系统存在")
	elif new_exists:
		print("  ℹ️  只有新系统存在")
	else:
		print("  ❌ 两个系统都不存在")
	
	print("")

func _print_recommendations() -> void:
	"""打印建议"""
	print("【迁移建议】")
	
	var old_exists = FileAccess.file_exists("res://autoloads/shop_manager.gd")
	var new_exists = FileAccess.file_exists("res://autoloads/shop_attribute_manager.gd")
	var new_registered = false
	
	var autoloads = ProjectSettings.get_setting("autoload")
	if autoloads:
		new_registered = "ShopAttributeManager" in str(autoloads)
	
	if old_exists and new_exists and not new_registered:
		print("  📝 步骤1: 在 project.godot 中添加 ShopAttributeManager 到自动加载")
		print("  📝 步骤2: 修改 shop_panel.gd 使用新系统")
		print("  📝 步骤3: 测试新系统功能")
		print("  📝 步骤4: 确认无误后移除旧系统")
	elif old_exists and new_exists and new_registered:
		print("  ✅ 新系统已注册，可以开始迁移UI代码")
		print("  📝 参考: MIGRATION_GUIDE.md")
	elif old_exists and not new_exists:
		print("  ℹ️  当前使用旧系统")
		print("  💡 如需使用新系统，请先创建新配置文件")
	elif new_exists and not old_exists:
		print("  ✅ 已完全迁移到新系统")
	
	print("")

func _print_file_info(path: String) -> void:
	"""打印文件信息"""
	var file = FileAccess.open(path, FileAccess.READ)
	if file:
		var line_count = 0
		while not file.eof_reached():
			file.get_line()
			line_count += 1
		file.close()
		print("     行数: %d" % line_count)

func _search_usage(keyword: String) -> void:
	"""搜索关键词使用情况"""
	var found_files = []
	_search_in_directory("res://", keyword, found_files)
	
	if found_files.is_empty():
		print("     未找到使用 '%s' 的文件" % keyword)
	else:
		print("     找到 %d 个文件使用 '%s':" % [found_files.size(), keyword])
		for file_path in found_files:
			print("       - %s" % file_path)

func _search_in_directory(dir_path: String, keyword: String, found_files: Array) -> void:
	"""递归搜索目录"""
	var dir = DirAccess.open(dir_path)
	if not dir:
		return
	
	dir.list_dir_begin()
	var file_name = dir.get_next()
	
	while file_name != "":
		var full_path = dir_path.path_join(file_name)
		
		if dir.current_is_dir():
			if not file_name.begins_with("."):
				_search_in_directory(full_path, keyword, found_files)
		elif file_name.ends_with(".gd"):
			if _file_contains_keyword(full_path, keyword):
				found_files.append(full_path)
		
		file_name = dir.get_next()
	
	dir.list_dir_end()

func _file_contains_keyword(file_path: String, keyword: String) -> bool:
	"""检查文件是否包含关键词"""
	var file = FileAccess.open(file_path, FileAccess.READ)
	if not file:
		return false
	
	var content = file.get_as_text()
	file.close()
	
	return keyword in content
