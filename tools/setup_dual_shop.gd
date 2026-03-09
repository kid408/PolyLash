@tool
extends EditorScript

# ============================================================================
# 商店/奖励流程快速校准工具（兼容旧文件名 setup_dual_shop.gd）
# ============================================================================
#
# 说明：
# - 该脚本不再做“旧双商店流程”迁移。
# - 当前项目以 BattleFlowController + RewardFlowService + ShopFlowService 为主流程。
# - 本工具负责检查依赖并生成最新集成示例。
# ============================================================================

const REQUIRED_FILES := {
	"流程编排控制器": "res://scenes/arena/battle_flow_controller.gd",
	"奖励流程服务": "res://scenes/arena/services/reward_flow_service.gd",
	"商店流程服务": "res://scenes/arena/services/shop_flow_service.gd",
	"波次奖励系统": "res://scenes/arena/wave_reward_system.gd",
	"波次奖励面板": "res://scenes/ui/wave_reward/wave_reward_panel.gd",
	"商店面板": "res://scenes/ui/shop_panel/shop_panel.gd",
	"商店管理器": "res://autoloads/shop_manager.gd",
	"属性商店管理器": "res://autoloads/shop_attribute_manager.gd"
}

const REQUIRED_CONFIGS := {
	"物品商店配置": "res://config/item/shop_item_config.csv",
	"属性商店配置": "res://config/wave/shop_attribute_config.csv",
	"属性商店波次配置": "res://config/wave/shop_wave_config.csv"
}

func _run() -> void:
	print("\n" + "=".repeat(72))
	print("商店/奖励流程快速校准")
	print("=".repeat(72) + "\n")

	var ok := true
	ok = _check_files() and ok
	ok = _check_configs() and ok
	ok = _check_autoload() and ok

	print("\n【4/4】生成最新流程示例")
	_generate_battle_flow_example()

	print("\n" + "=".repeat(72))
	if ok:
		print("✅ 校准完成：流程依赖齐全，示例已生成")
	else:
		print("⚠️ 校准完成：示例已生成，但存在缺失项，请先修复")
	print("=".repeat(72) + "\n")

func _check_files() -> bool:
	print("【1/4】关键脚本检查")
	var all_ok := true
	for display_name in REQUIRED_FILES.keys():
		var path := REQUIRED_FILES[display_name]
		if FileAccess.file_exists(path):
			print("  ✅ %s: %s" % [display_name, path])
		else:
			print("  ❌ %s 缺失: %s" % [display_name, path])
			all_ok = false
	return all_ok

func _check_configs() -> bool:
	print("\n【2/4】关键配置检查")
	var all_ok := true
	for display_name in REQUIRED_CONFIGS.keys():
		var path := REQUIRED_CONFIGS[display_name]
		if FileAccess.file_exists(path):
			print("  ✅ %s: %s" % [display_name, path])
		else:
			print("  ❌ %s 缺失: %s" % [display_name, path])
			all_ok = false
	return all_ok

func _check_autoload() -> bool:
	print("\n【3/4】Autoload 检查")
	var all_ok := true
	var autoloads := ProjectSettings.get_setting("autoload", {})
	var autoload_text := str(autoloads)

	var required_autoloads := {
		"ShopManager": "res://autoloads/shop_manager.gd",
		"ShopAttributeManager": "res://autoloads/shop_attribute_manager.gd"
	}

	for name in required_autoloads.keys():
		var path := required_autoloads[name]
		var has_name := name in autoload_text
		var has_path := path in autoload_text
		if has_name and has_path:
			print("  ✅ %s 已注册" % name)
		else:
			print("  ❌ %s 未正确注册（期望: %s）" % [name, path])
			all_ok = false

	return all_ok

func _generate_battle_flow_example() -> void:
	var example := """# ============================================================================
# BattleFlowController 集成示例（当前流程）
# 适用：ArenaCore 或同类关卡控制脚本
# ============================================================================

var _battle_flow: BattleFlowController = BattleFlowController.new()

func _setup_flow() -> void:
	_battle_flow.setup(spawner, shop_panel, wave_reward_system, wave_reward_panel)

func _on_wave_completed(wave_number: int) -> void:
	# 返回 true 代表进入奖励/商店流程；false 可按需求直接开下一波
	var handled := _battle_flow.on_wave_completed(wave_number)
	if not handled:
		_start_next_wave()

func _on_wave_reward_chosen(reward_data: Dictionary) -> void:
	var keep_shop := _battle_flow.on_wave_reward_chosen(reward_data)
	if not keep_shop:
		_start_next_wave()

func _on_shop_next_wave_requested(slot_index: int, wave_number: int) -> void:
	var started := _battle_flow.on_shop_next_wave_requested(slot_index, wave_number)
	if not started:
		push_warning("shop next wave request failed")
"""

	_save_example("res://tools/_battle_flow_integration_example.gd", example)
	print("  ✅ 已生成: tools/_battle_flow_integration_example.gd")

func _save_example(path: String, content: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		printerr("  ❌ 写入失败: %s" % path)
		return
	file.store_string(content)
	file.close()
