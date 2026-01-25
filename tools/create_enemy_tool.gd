@tool
extends EditorScript

## 敌人创建工具
## 使用方法: 在Godot编辑器中 File -> Run 选择此脚本
## 或者在代码中调用 create_enemy() 函数

# ==============================================================================
# 配置模板
# ==============================================================================
const ENEMY_CONFIG_TEMPLATE = {
	"enemy_id": "",
	"display_name": "新敌人",
	"health": 100,
	"speed": 150,
	"damage": 10,
	"attack_range": 50,
	"attack_cooldown": 1.0,
	"xp_value": 10,
	"gold_value": 5,
	"knockback_resistance": 0.5,
	"energy_drop": 2,
	"color_r": 1.0,
	"color_g": 1.0,
	"color_b": 1.0,
	"flock_push": 20.0,
	"stop_distance": 60.0
}

const VISUAL_CONFIG_TEMPLATE = {
	"enemy_id": "",
	"sprite_path": "res://assets/sprites/Enemies/Enemy_1.png",
	"scale_x": 1.0,
	"scale_y": 1.0,
	"color_r": 1.0,
	"color_g": 1.0,
	"color_b": 1.0,
	"color_a": 1.0,
	"z_index": 0,
	"offset_x": 0.0,
	"offset_y": 0.0,
	"collision_radius": 20.0,
	"hitbox_width": 40.0,
	"hitbox_height": 40.0,
	"animation_speed": 1.0,
	"flash_color_r": 1.0,
	"flash_color_g": 1.0,
	"flash_color_b": 1.0
}

# ==============================================================================
# 主函数
# ==============================================================================
func _run() -> void:
	print("================================================================================")
	print("敌人创建工具")
	print("================================================================================")
	
	# 示例：创建一个新敌人
	var config = {
		"enemy_id": "example_enemy",
		"display_name": "示例敌人",
		"health": 150,
		"speed": 180,
		"damage": 15,
		"sprite_path": "res://assets/sprites/Enemies/Enemy_1.png",
		"abilities": ["poison_pool"]  # 可选：添加能力
	}
	
	print("\n示例：创建敌人配置")
	print("配置: %s" % str(config))
	print("\n请修改上面的配置，然后调用 create_enemy(config)")
	print("\n或者使用交互式创建:")
	print("  var tool = load('res://tools/create_enemy_tool.gd').new()")
	print("  tool.create_enemy_interactive()")

# ==============================================================================
# 创建敌人（完整流程）
# ==============================================================================
func create_enemy(config: Dictionary) -> bool:
	"""
	创建一个新敌人
	
	参数:
		config: 敌人配置字典，必须包含 enemy_id
	
	返回:
		bool: 是否创建成功
	"""
	if not config.has("enemy_id") or config.enemy_id.is_empty():
		printerr("[CreateEnemyTool] 错误: 必须提供 enemy_id")
		return false
	
	var enemy_id = config.enemy_id
	print("\n[CreateEnemyTool] 开始创建敌人: %s" % enemy_id)
	
	# 1. 验证配置
	if not _validate_config(config):
		return false
	
	# 2. 添加到 enemy_config.csv
	if not _add_to_enemy_config(config):
		return false
	
	# 3. 添加到 enemy_visual.csv
	if not _add_to_visual_config(config):
		return false
	
	# 4. 添加能力配置（如果有）
	if config.has("abilities") and config.abilities.size() > 0:
		if not _add_abilities(enemy_id, config.abilities):
			return false
	
	# 5. 创建资源文件（可选）
	if config.get("create_resource", false):
		_create_resource_file(config)
	
	print("\n[CreateEnemyTool] ✅ 敌人创建成功: %s" % enemy_id)
	print("================================================================================")
	_print_usage_guide(enemy_id)
	
	return true

# ==============================================================================
# 交互式创建
# ==============================================================================
func create_enemy_interactive() -> void:
	"""交互式创建敌人（在编辑器中使用）"""
	print("\n================================================================================")
	print("交互式敌人创建向导")
	print("================================================================================")
	
	# 注意：Godot的EditorScript不支持真正的交互式输入
	# 这里提供一个配置示例，用户需要修改代码后运行
	
	var config = {
		"enemy_id": "new_enemy",  # 修改这里
		"display_name": "新敌人",  # 修改这里
		"health": 100,
		"speed": 150,
		"damage": 10,
		"sprite_path": "res://assets/sprites/Enemies/Enemy_1.png",
		"abilities": []  # 可选: ["poison_pool", "shooting", "charge"]
	}
	
	print("\n请在代码中修改上面的 config 字典，然后重新运行此脚本")
	print("\n当前配置:")
	for key in config.keys():
		print("  %s: %s" % [key, config[key]])
	
	# 如果配置看起来已经修改过了（不是默认值），则创建
	if config.enemy_id != "new_enemy":
		print("\n检测到自定义配置，开始创建...")
		create_enemy(config)
	else:
		print("\n提示: 修改 enemy_id 后重新运行以创建敌人")

# ==============================================================================
# 配置验证
# ==============================================================================
func _validate_config(config: Dictionary) -> bool:
	"""验证配置完整性"""
	var required_fields = ["enemy_id", "display_name"]
	
	for field in required_fields:
		if not config.has(field):
			printerr("[CreateEnemyTool] 错误: 缺少必需字段 '%s'" % field)
			return false
	
	# 检查 enemy_id 是否已存在
	if _enemy_exists(config.enemy_id):
		printerr("[CreateEnemyTool] 错误: 敌人ID已存在 '%s'" % config.enemy_id)
		return false
	
	# 检查精灵文件是否存在
	if config.has("sprite_path"):
		if not FileAccess.file_exists(config.sprite_path):
			print("[CreateEnemyTool] 警告: 精灵文件不存在 '%s'" % config.sprite_path)
	
	return true

func _enemy_exists(enemy_id: String) -> bool:
	"""检查敌人ID是否已存在"""
	var file_path = "res://config/enemy/enemy_config.csv"
	if not FileAccess.file_exists(file_path):
		return false
	
	var file = FileAccess.open(file_path, FileAccess.READ)
	if not file:
		return false
	
	while not file.eof_reached():
		var line = file.get_line()
		if line.begins_with(enemy_id + ","):
			file.close()
			return true
	
	file.close()
	return false

# ==============================================================================
# 添加配置到CSV
# ==============================================================================
func _add_to_enemy_config(config: Dictionary) -> bool:
	"""添加到 enemy_config.csv"""
	var file_path = "res://config/enemy/enemy_config.csv"
	
	# 合并默认值
	var full_config = ENEMY_CONFIG_TEMPLATE.duplicate()
	full_config.merge(config, true)
	
	# 构建CSV行
	var values = [
		full_config.enemy_id,
		full_config.display_name,
		full_config.health,
		full_config.speed,
		full_config.damage,
		full_config.attack_range,
		full_config.attack_cooldown,
		full_config.xp_value,
		full_config.gold_value,
		full_config.knockback_resistance,
		full_config.energy_drop,
		full_config.color_r,
		full_config.color_g,
		full_config.color_b,
		full_config.flock_push,
		full_config.stop_distance,
		full_config.get("charge_prep_time", 0.8),
		full_config.get("charge_duration", 0.6),
		full_config.get("charge_speed_mult", 3.5),
		full_config.get("charge_cooldown", 3),
		full_config.get("break_radius", 40),
		full_config.get("can_charge", 0),
		full_config.get("shoot_cooldown", 3),
		full_config.get("projectile_count", 3),
		full_config.get("projectile_arc_angle", 45),
		full_config.get("projectile_speed", 1800),
		full_config.get("pool_radius", 60),
		full_config.get("pool_damage", 5),
		full_config.get("pool_damage_interval", 0.5),
		full_config.get("pool_lifetime", 8)
	]
	
	var line = ",".join(PackedStringArray(values))
	
	return _append_to_csv(file_path, line)

func _add_to_visual_config(config: Dictionary) -> bool:
	"""添加到 enemy_visual.csv"""
	var file_path = "res://config/enemy/enemy_visual.csv"
	
	# 合并默认值
	var full_config = VISUAL_CONFIG_TEMPLATE.duplicate()
	full_config.merge(config, true)
	full_config.enemy_id = config.enemy_id
	
	# 构建CSV行
	var values = [
		full_config.enemy_id,
		full_config.sprite_path,
		full_config.scale_x,
		full_config.scale_y,
		full_config.color_r,
		full_config.color_g,
		full_config.color_b,
		full_config.color_a,
		full_config.z_index,
		full_config.offset_x,
		full_config.offset_y,
		full_config.collision_radius,
		full_config.hitbox_width,
		full_config.hitbox_height,
		full_config.animation_speed,
		full_config.flash_color_r,
		full_config.flash_color_g,
		full_config.flash_color_b
	]
	
	var line = ",".join(PackedStringArray(values))
	
	return _append_to_csv(file_path, line)

func _add_abilities(enemy_id: String, abilities: Array) -> bool:
	"""添加能力配置"""
	var file_path = "res://config/enemy/enemy_abilities.csv"
	
	for ability_id in abilities:
		var line = "%s,%s,3.0,0,999999,0,1,,,,,," % [enemy_id, ability_id]
		if not _append_to_csv(file_path, line):
			return false
	
	print("[CreateEnemyTool] 添加了 %d 个能力" % abilities.size())
	return true

func _append_to_csv(file_path: String, line: String) -> bool:
	"""追加一行到CSV文件"""
	var file = FileAccess.open(file_path, FileAccess.READ_WRITE)
	if not file:
		printerr("[CreateEnemyTool] 错误: 无法打开文件 %s" % file_path)
		return false
	
	# 移动到文件末尾
	file.seek_end()
	file.store_line(line)
	file.close()
	
	print("[CreateEnemyTool] 已添加到 %s" % file_path)
	return true

# ==============================================================================
# 资源文件创建
# ==============================================================================
func _create_resource_file(config: Dictionary) -> void:
	"""创建 .tres 资源文件（可选）"""
	var resource_path = "res://resouce/unit/enemies/stats_enemy_%s.tres" % config.enemy_id
	
	# 这里可以创建一个Resource文件
	# 由于EditorScript的限制，这部分需要手动实现
	print("[CreateEnemyTool] 提示: 如需创建资源文件，请手动创建: %s" % resource_path)

# ==============================================================================
# 使用指南
# ==============================================================================
func _print_usage_guide(enemy_id: String) -> void:
	"""打印使用指南"""
	print("\n📖 使用指南:")
	print("────────────────────────────────────────────────────────────────────────────────")
	print("1. 在波次配置中使用:")
	print("   enemy_id: %s" % enemy_id)
	print("\n2. 测试敌人:")
	print("   - 打开测试场景")
	print("   - 添加 enemy_generic.tscn 实例")
	print("   - 设置 enemy_id 为 '%s'" % enemy_id)
	print("\n3. 调整属性:")
	print("   - 修改 config/enemy/enemy_config.csv")
	print("   - 修改 config/enemy/enemy_visual.csv")
	print("\n4. 添加能力:")
	print("   - 编辑 config/enemy/enemy_abilities.csv")
	print("   - 可用能力: poison_pool, shooting, charge")
	print("────────────────────────────────────────────────────────────────────────────────")

# ==============================================================================
# 批量创建
# ==============================================================================
func create_enemy_batch(configs: Array) -> int:
	"""批量创建敌人"""
	var success_count = 0
	
	for config in configs:
		if create_enemy(config):
			success_count += 1
	
	print("\n[CreateEnemyTool] 批量创建完成: %d/%d 成功" % [success_count, configs.size()])
	return success_count

# ==============================================================================
# 预设模板
# ==============================================================================
func get_preset_templates() -> Dictionary:
	"""获取预设模板"""
	return {
		"fast_melee": {
			"display_name": "快速近战",
			"health": 80,
			"speed": 250,
			"damage": 8,
			"attack_range": 40,
			"sprite_path": "res://assets/sprites/Enemies/Enemy_2.png"
		},
		"tank": {
			"display_name": "坦克",
			"health": 300,
			"speed": 100,
			"damage": 20,
			"attack_range": 60,
			"knockback_resistance": 0.9,
			"sprite_path": "res://assets/sprites/Enemies/Enemy_3.png"
		},
		"ranged": {
			"display_name": "远程",
			"health": 60,
			"speed": 120,
			"damage": 12,
			"attack_range": 300,
			"abilities": ["shooting"],
			"sprite_path": "res://assets/sprites/Enemies/Enemy_4.png"
		},
		"charger": {
			"display_name": "冲锋",
			"health": 100,
			"speed": 180,
			"damage": 15,
			"abilities": ["charge"],
			"sprite_path": "res://assets/sprites/Enemies/Enemy_5.png"
		}
	}

func create_from_preset(enemy_id: String, preset_name: String) -> bool:
	"""从预设创建敌人"""
	var presets = get_preset_templates()
	if not presets.has(preset_name):
		printerr("[CreateEnemyTool] 错误: 未知的预设 '%s'" % preset_name)
		return false
	
	var config = presets[preset_name].duplicate()
	config.enemy_id = enemy_id
	
	return create_enemy(config)
