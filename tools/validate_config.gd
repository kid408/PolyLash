extends Node

# CSV配置验证工具
# 使用方法: 在Godot编辑器中运行此脚本，检查配置文件是否有效

func _ready() -> void:
	print("=" * 60)
	print("开始验证玩家配置...")
	print("=" * 60)
	
	validate_csv_file()
	validate_player_configs()
	
	print("=" * 60)
	print("验证完成！")
	print("=" * 60)
	
	# 验证完成后退出
	get_tree().quit()

func validate_csv_file() -> void:
	print("\n[1] 检查CSV文件...")
	
	var file_path = "res://resouce/player_config.csv"
	var file = FileAccess.open(file_path, FileAccess.READ)
	
	if file == null:
		printerr("  ❌ 错误: 无法打开文件 %s" % file_path)
		return
	
	print("  ✅ CSV文件存在")
	
	# 检查表头
	var header = file.get_csv_line()
	var required_fields = [
		"player_id", "display_name", "dash_distance", "dash_speed",
		"dash_damage", "dash_knockback", "dash_cost", "skill_q_cost",
		"skill_e_cost", "close_threshold", "energy_regen", "max_energy",
		"max_armor", "base_speed"
	]
	
	var missing_fields = []
	for field in required_fields:
		if not field in header:
			missing_fields.append(field)
	
	if missing_fields.size() > 0:
		printerr("  ❌ 缺少必需字段: %s" % str(missing_fields))
	else:
		print("  ✅ 所有必需字段都存在")
	
	# 检查数据行
	var line_count = 0
	var player_ids = []
	
	while not file.eof_reached():
		var line = file.get_csv_line()
		if line.size() < 2 or line[0].is_empty():
			continue
		
		line_count += 1
		var player_id = line[0].strip_edges()
		
		if player_id in player_ids:
			printerr("  ❌ 重复的 player_id: %s" % player_id)
		else:
			player_ids.append(player_id)
		
		# 验证数值字段
		if line.size() >= header.size():
			for i in range(2, min(line.size(), header.size())):
				var value = line[i].strip_edges()
				if not value.is_valid_float() and not value.is_valid_int():
					printerr("  ⚠️  警告: %s 的 %s 不是有效数字: '%s'" % [
						player_id, header[i], value
					])
	
	print("  ✅ 找到 %d 个角色配置" % line_count)
	print("  角色列表: %s" % str(player_ids))
	
	file.close()

func validate_player_configs() -> void:
	print("\n[2] 检查配置加载...")
	
	# 检查 PlayerConfigLoader 是否存在
	if not has_node("/root/PlayerConfigLoader"):
		printerr("  ❌ 错误: PlayerConfigLoader 未注册到 autoload")
		printerr("     请在 project.godot 中添加:")
		printerr("     PlayerConfigLoader=\"*res://autoloads/player_config_loader.gd\"")
		return
	
	print("  ✅ PlayerConfigLoader 已注册")
	
	var loader = get_node("/root/PlayerConfigLoader")
	var configs = loader.player_configs
	
	if configs.is_empty():
		printerr("  ❌ 错误: 没有加载任何配置")
		return
	
	print("  ✅ 成功加载 %d 个配置" % configs.size())
	
	# 验证每个配置的完整性
	print("\n[3] 验证配置数据...")
	
	for player_id in configs.keys():
		var config = configs[player_id]
		print("\n  检查角色: %s" % player_id)
		
		var warnings = []
		
		# 检查必需字段
		if not config.has("dash_distance"):
			warnings.append("缺少 dash_distance")
		elif config["dash_distance"] <= 0:
			warnings.append("dash_distance 必须大于0")
		
		if not config.has("dash_speed"):
			warnings.append("缺少 dash_speed")
		elif config["dash_speed"] <= 0:
			warnings.append("dash_speed 必须大于0")
		
		if not config.has("max_energy"):
			warnings.append("缺少 max_energy")
		elif config["max_energy"] <= 0:
			warnings.append("max_energy 必须大于0")
		
		if not config.has("base_speed"):
			warnings.append("缺少 base_speed")
		elif config["base_speed"] <= 0:
			warnings.append("base_speed 必须大于0")
		
		# 检查合理性
		if config.get("dash_cost", 0) > config.get("max_energy", 999):
			warnings.append("dash_cost 大于 max_energy，无法使用冲刺")
		
		if config.get("skill_q_cost", 0) > config.get("max_energy", 999):
			warnings.append("skill_q_cost 大于 max_energy，无法使用Q技能")
		
		if config.get("skill_e_cost", 0) > config.get("max_energy", 999):
			warnings.append("skill_e_cost 大于 max_energy，无法使用E技能")
		
		if config.get("energy_regen", 0) <= 0:
			warnings.append("energy_regen 应该大于0，否则能量无法恢复")
		
		if warnings.size() > 0:
			for warning in warnings:
				printerr("    ⚠️  %s" % warning)
		else:
			print("    ✅ 配置正常")
		
		# 打印关键数值
		print("    冲刺: 距离=%d 速度=%d 伤害=%d 消耗=%d" % [
			config.get("dash_distance", 0),
			config.get("dash_speed", 0),
			config.get("dash_damage", 0),
			config.get("dash_cost", 0)
		])
		print("    技能: Q消耗=%d E消耗=%d" % [
			config.get("skill_q_cost", 0),
			config.get("skill_e_cost", 0)
		])
		print("    属性: 能量=%d/%d 护甲=%d 速度=%d" % [
			config.get("energy_regen", 0),
			config.get("max_energy", 0),
			config.get("max_armor", 0),
			config.get("base_speed", 0)
		])

func print_usage_example() -> void:
	print("\n" + "=" * 60)
	print("使用示例:")
	print("=" * 60)
	print("""
# 在角色脚本中使用配置:

extends PlayerBase
class_name MyHero

func _ready() -> void:
	player_id = "my_hero"  # 对应CSV中的player_id
	super._ready()
	
	# 配置会自动加载，可以直接使用:
	print("冲刺距离: ", dash_distance)
	print("Q技能消耗: ", skill_q_cost)

func release_skill_q() -> void:
	if not consume_energy(skill_q_cost):
		return
	# 技能实现...
""")
