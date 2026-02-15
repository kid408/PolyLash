@tool
extends EditorScript

# ============================================================================
# 双商店系统快速设置工具
# ============================================================================
#
# 使用方法：
# 1. 在Godot编辑器中打开此脚本
# 2. 点击 File -> Run
# 3. 按照提示完成设置
#
# 功能：
# - 检查系统完整性
# - 自动添加自动加载配置
# - 生成示例场景代码
#
# ============================================================================

func _run() -> void:
	print("\n" + "=".repeat(60))
	print("双商店系统快速设置")
	print("=".repeat(60) + "\n")
	
	var all_ok = true
	
	# 步骤1：检查文件
	print("【步骤1】检查必需文件...")
	if not _check_files():
		all_ok = false
	
	# 步骤2：检查自动加载
	print("\n【步骤2】检查自动加载配置...")
	if not _check_autoload():
		all_ok = false
		_add_autoload()
	
	# 步骤3：生成示例代码
	print("\n【步骤3】生成集成示例...")
	_generate_examples()
	
	# 总结
	print("\n" + "=".repeat(60))
	if all_ok:
		print("✅ 双商店系统已就绪！")
		print("\n下一步：")
		print("1. 创建 attribute_shop_panel.tscn 场景")
		print("2. 参考 _integration_example.gd 集成到游戏流程")
		print("3. 查看 DUAL_SHOP_SYSTEM_GUIDE.md 了解详情")
	else:
		print("⚠️  设置未完全完成，请检查上述错误")
	print("=".repeat(60) + "\n")

func _check_files() -> bool:
	"""检查必需文件"""
	var required_files = {
		"物品商店管理器": "res://autoloads/shop_manager.gd",
		"属性商店管理器": "res://autoloads/shop_attribute_manager.gd",
		"物品配置": "res://config/item/shop_item_config.csv",
		"属性配置": "res://config/wave/shop_attribute_config.csv",
		"波次配置": "res://config/wave/shop_wave_config.csv",
		"物品商店UI": "res://scenes/ui/shop_panel/shop_panel.gd",
		"属性商店UI": "res://scenes/ui/shop_panel/attribute_shop_panel.gd"
	}
	
	var all_exist = true
	
	for name in required_files.keys():
		var path = required_files[name]
		if FileAccess.file_exists(path):
			print("  ✅ %s: %s" % [name, path])
		else:
			print("  ❌ %s 不存在: %s" % [name, path])
			all_exist = false
	
	return all_exist

func _check_autoload() -> bool:
	"""检查自动加载配置"""
	var autoloads = ProjectSettings.get_setting("autoload", {})
	
	var required_autoloads = {
		"ShopManager": "res://autoloads/shop_manager.gd",
		"ShopAttributeManager": "res://autoloads/shop_attribute_manager.gd"
	}
	
	var all_registered = true
	
	for name in required_autoloads.keys():
		var path = required_autoloads[name]
		var autoload_str = str(autoloads)
		
		if name in autoload_str:
			print("  ✅ %s 已注册" % name)
		else:
			print("  ⚠️  %s 未注册" % name)
			all_registered = false
	
	return all_registered

func _add_autoload() -> void:
	"""添加自动加载配置"""
	print("\n  尝试添加 ShopAttributeManager 到自动加载...")
	
	# 注意：EditorScript 无法直接修改 ProjectSettings
	# 需要手动添加或使用 EditorPlugin
	
	print("  ℹ️  请手动添加以下配置到 project.godot:")
	print("  ")
	print("  [autoload]")
	print("  ShopAttributeManager=\"*res://autoloads/shop_attribute_manager.gd\"")
	print("  ")
	print("  或在编辑器中：")
	print("  项目 -> 项目设置 -> 自动加载")
	print("  路径: res://autoloads/shop_attribute_manager.gd")
	print("  节点名称: ShopAttributeManager")
	print("  勾选: 启用")

func _generate_examples() -> void:
	"""生成集成示例代码"""
	
	# 示例1：同时显示两个商店
	var example1 = """# ============================================================================
# 集成示例1：同时显示两个商店
# ============================================================================

extends Node

@onready var shop_panel = $ShopPanel
@onready var attribute_shop_panel = $AttributeShopPanel

func _on_wave_completed(wave_number: int):
	\"\"\"波次完成，显示商店\"\"\"
	
	# 显示物品商店
	shop_panel.show_shop(wave_number + 1)
	
	# 显示属性商店
	attribute_shop_panel.show_shop(wave_number + 1)
	
	# 等待玩家关闭商店
	await shop_panel.next_wave_requested
	
	# 开始下一波
	_start_next_wave()

func _start_next_wave():
	\"\"\"开始下一波\"\"\"
	print("开始下一波")
	# 你的波次开始逻辑...
"""
	
	# 示例2：交替显示
	var example2 = """# ============================================================================
# 集成示例2：根据波次交替显示
# ============================================================================

extends Node

@onready var shop_panel = $ShopPanel
@onready var attribute_shop_panel = $AttributeShopPanel

func _on_wave_completed(wave_number: int):
	\"\"\"波次完成，显示商店\"\"\"
	
	if wave_number % 2 == 1:
		# 奇数波：物品商店
		print("显示物品商店")
		shop_panel.show_shop(wave_number + 1)
		await shop_panel.next_wave_requested
	else:
		# 偶数波：属性商店
		print("显示属性商店")
		attribute_shop_panel.show_shop(wave_number + 1)
		await attribute_shop_panel.shop_closed
	
	# 开始下一波
	_start_next_wave()

func _start_next_wave():
	\"\"\"开始下一波\"\"\"
	print("开始下一波")
	# 你的波次开始逻辑...
"""
	
	# 示例3：先后显示
	var example3 = """# ============================================================================
# 集成示例3：先后显示两个商店
# ============================================================================

extends Node

@onready var shop_panel = $ShopPanel
@onready var attribute_shop_panel = $AttributeShopPanel

func _on_wave_completed(wave_number: int):
	\"\"\"波次完成，显示商店\"\"\"
	
	# 先显示物品商店
	print("显示物品商店")
	shop_panel.show_shop(wave_number + 1)
	await shop_panel.next_wave_requested
	
	# 再显示属性商店
	print("显示属性商店")
	attribute_shop_panel.show_shop(wave_number + 1)
	await attribute_shop_panel.shop_closed
	
	# 开始下一波
	_start_next_wave()

func _start_next_wave():
	\"\"\"开始下一波\"\"\"
	print("开始下一波")
	# 你的波次开始逻辑...
"""
	
	# 保存示例文件
	_save_example("res://tools/_integration_example_1_simultaneous.gd", example1)
	_save_example("res://tools/_integration_example_2_alternate.gd", example2)
	_save_example("res://tools/_integration_example_3_sequential.gd", example3)
	
	print("  ✅ 已生成3个集成示例:")
	print("     - tools/_integration_example_1_simultaneous.gd (同时显示)")
	print("     - tools/_integration_example_2_alternate.gd (交替显示)")
	print("     - tools/_integration_example_3_sequential.gd (先后显示)")

func _save_example(path: String, content: String) -> void:
	"""保存示例文件"""
	var file = FileAccess.open(path, FileAccess.WRITE)
	if file:
		file.store_string(content)
		file.close()
	else:
		printerr("  ❌ 无法保存示例文件: %s" % path)
