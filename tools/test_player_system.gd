extends Node2D

# 玩家系统测试脚本
# 用于快速测试重构后的玩家系统是否正常工作

@onready var info_label: Label = $InfoLabel

var test_results: Array[Dictionary] = []

func _ready() -> void:
	# 创建UI
	if not has_node("InfoLabel"):
		var label = Label.new()
		label.name = "InfoLabel"
		label.position = Vector2(20, 20)
		label.add_theme_font_size_override("font_size", 16)
		add_child(label)
		info_label = label
	
	print("\n" + "=" * 60)
	print("玩家系统测试")
	print("=" * 60)
	
	await get_tree().create_timer(0.5).timeout
	
	run_tests()

func run_tests() -> void:
	test_config_loader()
	test_player_base()
	
	print_test_results()

func test_config_loader() -> void:
	print("\n[测试1] PlayerConfigLoader")
	
	if not has_node("/root/PlayerConfigLoader"):
		add_test_result("ConfigLoader存在", false, "未找到autoload")
		return
	
	add_test_result("ConfigLoader存在", true)
	
	var loader = get_node("/root/PlayerConfigLoader")
	var configs = loader.player_configs
	
	if configs.is_empty():
		add_test_result("配置加载", false, "配置为空")
		return
	
	add_test_result("配置加载", true, "加载了%d个配置" % configs.size())
	
	# 测试获取配置
	var test_config = loader.get_config("butcher")
	if test_config.is_empty():
		add_test_result("获取配置", false, "无法获取butcher配置")
	else:
		add_test_result("获取配置", true, "成功获取butcher配置")
	
	# 测试获取单个值
	var dash_dist = loader.get_value("butcher", "dash_distance", 0)
	if dash_dist > 0:
		add_test_result("读取数值", true, "dash_distance=%d" % dash_dist)
	else:
		add_test_result("读取数值", false, "无法读取dash_distance")

func test_player_base() -> void:
	print("\n[测试2] PlayerBase基类")
	
	# 检查基类文件是否存在
	var base_script = load("res://scenes/unit/players/player_base.gd")
	if base_script == null:
		add_test_result("基类文件", false, "无法加载player_base.gd")
		return
	
	add_test_result("基类文件", true)
	
	# 测试示例角色
	var refactored_script = load("res://scenes/unit/players/player_butcher_refactored.gd")
	if refactored_script != null:
		add_test_result("示例角色", true, "player_butcher_refactored.gd存在")
	else:
		add_test_result("示例角色", false, "未找到示例角色")

func add_test_result(test_name: String, passed: bool, details: String = "") -> void:
	test_results.append({
		"name": test_name,
		"passed": passed,
		"details": details
	})
	
	var status = "✅" if passed else "❌"
	var msg = "  %s %s" % [status, test_name]
	if not details.is_empty():
		msg += " - %s" % details
	print(msg)

func print_test_results() -> void:
	print("\n" + "=" * 60)
	print("测试结果汇总")
	print("=" * 60)
	
	var passed_count = 0
	var failed_count = 0
	
	for result in test_results:
		if result["passed"]:
			passed_count += 1
		else:
			failed_count += 1
	
	var total = test_results.size()
	var pass_rate = (float(passed_count) / total * 100) if total > 0 else 0
	
	print("总计: %d 个测试" % total)
	print("通过: %d 个 (%.1f%%)" % [passed_count, pass_rate])
	print("失败: %d 个" % failed_count)
	
	if failed_count == 0:
		print("\n🎉 所有测试通过！系统运行正常。")
	else:
		print("\n⚠️  有 %d 个测试失败，请检查配置。" % failed_count)
	
	# 更新UI
	update_info_label()
	
	print("=" * 60)

func update_info_label() -> void:
	if info_label == null:
		return
	
	var text = "玩家系统测试结果\n\n"
	
	for result in test_results:
		var status = "✅" if result["passed"] else "❌"
		text += "%s %s\n" % [status, result["name"]]
		if not result["details"].is_empty():
			text += "   %s\n" % result["details"]
	
	var passed = test_results.filter(func(r): return r["passed"]).size()
	var total = test_results.size()
	
	text += "\n通过率: %d/%d (%.1f%%)" % [
		passed, total, 
		(float(passed) / total * 100) if total > 0 else 0
	]
	
	info_label.text = text

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_R:
			print("\n重新运行测试...")
			test_results.clear()
			run_tests()
		elif event.keycode == KEY_Q:
			print("\n退出测试")
			get_tree().quit()

func _process(_delta: float) -> void:
	# 显示帮助信息
	if test_results.size() > 0 and info_label:
		if not info_label.text.contains("按键说明"):
			info_label.text += "\n\n按键说明:\nR - 重新测试\nQ - 退出"
