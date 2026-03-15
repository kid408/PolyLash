@tool
extends EditorScript

# ============================================================================
# 商店/奖励流程检查工具（当前流程版）
# ============================================================================
#
# 目标：
# - 校验当前“波次奖励 -> 商店 -> 下一波”流程依赖是否齐全
# - 检查关键配置与 autoload 注册
# - 输出代码引用位置，方便定位旧逻辑和冲突点
#
# 使用方法：
# 1. 在 Godot 编辑器中打开本脚本
# 2. File -> Run
# 3. 查看输出面板
# ============================================================================

const REQUIRED_FILES: Dictionary = {
	"商店管理器": "res://autoloads/shop_manager.gd",
	"属性商店管理器": "res://autoloads/shop_attribute_manager.gd",
	"波次奖励系统": "res://scenes/arena/wave_reward_system.gd",
	"波次奖励面板": "res://scenes/ui/wave_reward/wave_reward_panel.gd",
	"商店流程服务": "res://scenes/arena/services/shop_flow_service.gd",
	"奖励流程服务": "res://scenes/arena/services/reward_flow_service.gd",
	"战斗流程控制器": "res://scenes/arena/battle_flow_controller.gd",
	"竞技场核心": "res://scenes/arena/arena_core.gd"
}

const REQUIRED_CONFIGS: Dictionary = {
	"物品商店配置": "res://config/item/shop_item_config.csv",
	"属性商店配置": "res://config/wave/shop_attribute_config.csv",
	"属性商店波次配置": "res://config/wave/shop_wave_config.csv"
}

const KEYWORDS: Array[String] = [
	"ShopManager",
	"ShopAttributeManager",
	"WaveRewardSystem",
	"WaveRewardPanel",
	"ShopFlowService",
	"RewardFlowService",
	"BattleFlowController"
]

func _run() -> void:
	print("\n" + "=".repeat(72))
	print("商店/奖励流程检查（当前流程版）")
	print("=".repeat(72) + "\n")

	var ok: bool = true
	ok = _check_required_files() and ok
	ok = _check_required_configs() and ok
	ok = _check_autoloads() and ok
	_print_keyword_usage()

	print("\n" + "=".repeat(72))
	if ok:
		print("✅ 检查通过：关键依赖与配置均已就绪")
	else:
		print("⚠️ 检查未通过：请按上方缺失项修复")
	print("=".repeat(72) + "\n")

func _check_required_files() -> bool:
	print("【1/4】关键脚本检查")
	var all_ok: bool = true
	for display_name_variant: Variant in REQUIRED_FILES.keys():
		var display_name: String = str(display_name_variant)
		var path: String = str(REQUIRED_FILES.get(display_name, ""))
		if FileAccess.file_exists(path):
			print("  ✅ %s: %s" % [display_name, path])
		else:
			print("  ❌ %s 缺失: %s" % [display_name, path])
			all_ok = false
	return all_ok

func _check_required_configs() -> bool:
	print("\n【2/4】关键配置检查")
	var all_ok: bool = true
	for display_name_variant: Variant in REQUIRED_CONFIGS.keys():
		var display_name: String = str(display_name_variant)
		var path: String = str(REQUIRED_CONFIGS.get(display_name, ""))
		if FileAccess.file_exists(path):
			print("  ✅ %s: %s" % [display_name, path])
			_print_csv_row_count(path)
		else:
			print("  ❌ %s 缺失: %s" % [display_name, path])
			all_ok = false
	return all_ok

func _check_autoloads() -> bool:
	print("\n【3/4】Autoload 检查")
	var all_ok: bool = true
	var autoload_setting: Variant = ProjectSettings.get_setting("autoload", {})
	var autoloads: Dictionary = {}
	if autoload_setting is Dictionary:
		autoloads = autoload_setting
	var autoload_text: String = str(autoloads)

	var required_autoloads: Dictionary = {
		"ShopManager": "res://autoloads/shop_manager.gd",
		"ShopAttributeManager": "res://autoloads/shop_attribute_manager.gd"
	}

	for name_variant: Variant in required_autoloads.keys():
		var name: String = str(name_variant)
		var path: String = str(required_autoloads.get(name, ""))
		var has_name: bool = name in autoload_text
		var has_path: bool = path in autoload_text
		if has_name and has_path:
			print("  ✅ %s 已注册" % name)
		else:
			print("  ❌ %s 未正确注册（期望路径: %s）" % [name, path])
			all_ok = false

	return all_ok

func _print_keyword_usage() -> void:
	print("\n【4/4】关键字引用扫描（.gd）")
	for keyword in KEYWORDS:
		var found_files: Array[String] = []
		_search_gd_usage("res://", keyword, found_files)
		if found_files.is_empty():
			print("  ⚠️ 未找到 '%s' 的 .gd 引用" % keyword)
		else:
			print("  ✅ '%s' 命中 %d 个文件" % [keyword, found_files.size()])
			for i in range(min(5, found_files.size())):
				print("     - %s" % found_files[i])
			if found_files.size() > 5:
				print("     ... 其余 %d 个文件省略" % (found_files.size() - 5))

func _print_csv_row_count(path: String) -> void:
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return
	var rows: int = 0
	while not file.eof_reached():
		file.get_line()
		rows += 1
	file.close()
	print("     行数: %d" % rows)

func _search_gd_usage(dir_path: String, keyword: String, found_files: Array[String]) -> void:
	var dir: DirAccess = DirAccess.open(dir_path)
	if dir == null:
		return

	dir.list_dir_begin()
	var file_name: String = dir.get_next()
	while file_name != "":
		var full_path: String = dir_path.path_join(file_name)
		if dir.current_is_dir():
			if not file_name.begins_with("."):
				_search_gd_usage(full_path, keyword, found_files)
		elif file_name.ends_with(".gd"):
			if _gd_contains_keyword(full_path, keyword):
				found_files.append(full_path)
		file_name = dir.get_next()
	dir.list_dir_end()

func _gd_contains_keyword(file_path: String, keyword: String) -> bool:
	var file: FileAccess = FileAccess.open(file_path, FileAccess.READ)
	if file == null:
		return false
	var content: String = file.get_as_text()
	file.close()
	return keyword in content
