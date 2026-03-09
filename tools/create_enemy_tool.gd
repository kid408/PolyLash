@tool
extends EditorScript

## 敌人创建工具
## 使用方法: 修改下面的配置，然后 File -> Run

# ==============================================================================
# 默认配置（内部使用）
# ==============================================================================
const DEFAULT_CONFIG = {
	# 基础属性
	"enemy_id": "",
	"display_name": "",
	"health": 100,
	"speed": 160,
	"damage": 15,
	"attack_range": 50,
	"attack_cooldown": 1.0,
	"xp_value": 10,
	"gold_value": 5,
	"knockback_resistance": 0.5,
	"energy_drop": 2,
	"flock_push": 20.0,
	"stop_distance": 60.0,
	
	# 视觉配置
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
	"flash_color_b": 1.0,
	
	# 能力配置
	"charge_prep_time": 0.8,
	"charge_duration": 0.6,
	"charge_speed_mult": 3.5,
	"charge_cooldown": 3,
	"break_radius": 40,
	"can_charge": 0,
	"shoot_cooldown": 3,
	"projectile_count": 3,
	"projectile_arc_angle": 45,
	"projectile_speed": 1800,
	"pool_radius": 60,
	"pool_damage": 5,
	"pool_damage_interval": 0.5,
	"pool_lifetime": 8,

	# 导演系统（enemy_config_v2）
	"director_role": "runner",        # runner | elite | tank | ranged | swarm ...
	"director_cost": 1.0,             # 导演预算消耗
	"behavior_params": "{}"           # JSON 字符串
}

const ENEMY_CONFIG_V2_PATH := "res://config/enemy/enemy_config_v2.csv"

# ==============================================================================
# 主函数 - 在这里修改配置并运行
# ==============================================================================
func _run() -> void:
	print("\n================================================================================")
	print("敌人创建工具")
	print("================================================================================\n")
	
	# ============================================================================
	# 在这里修改配置
	# ============================================================================
	var config = {
		"enemy_id": "steel_enemy",           # 敌人ID（必填，英文）
		"display_name": "钢头怪",          # 显示名称（必填，中文）
		"health": 350,                      # 生命值
		"speed": 180,                       # 移动速度
		"damage": 15,                       # 攻击力
		"director_role": "runner",          # 导演职业（写入 enemy_config_v2.csv）
		"director_cost": 1.0,               # 导演预算消耗（写入 enemy_config_v2.csv）
		"attack_range": 50,                 # 攻击范围
		"attack_cooldown": 1.0,             # 攻击冷却
		"xp_value": 15,                     # 经验值
		"gold_value": 8,                    # 金币
		"sprite_path": "res://assets/sprites/Enemies/Enemy_7.png",  # 精灵路径
		"abilities": []                     # 能力列表: ["poison_pool", "shooting", "charge"]
	}
	# ============================================================================
	
	print("配置信息:")
	print("  ID: %s" % config.enemy_id)
	print("  名称: %s" % config.display_name)
	print("  生命: %d" % config.health)
	print("  速度: %d" % config.speed)
	print("  伤害: %d" % config.damage)
	if config.abilities.size() > 0:
		print("  能力: %s" % str(config.abilities))
	print("")
	
	# 创建敌人
	print("开始创建敌人...")
	var success = create_enemy(config)
	
	if success:
		print("\n================================================================================")
		print("✅ 创建成功!")
		print("================================================================================")
		print("\n下一步:")
		print("1. 打开测试场景")
		print("2. 添加 scenes/unit/enemy/enemy_generic.tscn")
		print("3. 设置 Enemy Id 为 '%s'" % config.enemy_id)
		print("4. 按 F5 运行测试")
	else:
		print("\n================================================================================")
		print("❌ 创建失败!")
		print("================================================================================")
		print("\n请检查:")
		print("1. enemy_id 是否已存在")
		print("2. 配置是否正确")
		print("3. 查看上面的错误信息")

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

	# 5. 写入导演配置 enemy_config_v2.csv（可选，默认开启）
	if config.get("add_to_director_v2", true):
		if not _add_to_enemy_config_v2(config):
			return false

	# 6. 创建资源文件（可选）
	if config.get("create_resource", false):
		_create_resource_file(config)
	
	print("\n[CreateEnemyTool] ✅ 敌人创建成功: %s" % enemy_id)
	print("================================================================================")
	_print_usage_guide(enemy_id)
	
	return true

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
	var full_config = DEFAULT_CONFIG.duplicate()
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
	var full_config = DEFAULT_CONFIG.duplicate()
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

func _add_to_enemy_config_v2(config: Dictionary) -> bool:
	"""写入 enemy_config_v2.csv（导演预算出怪链路）"""
	if not FileAccess.file_exists(ENEMY_CONFIG_V2_PATH):
		print("[CreateEnemyTool] 警告: 未找到 %s，跳过导演配置写入" % ENEMY_CONFIG_V2_PATH)
		return true

	var enemy_id: String = str(config.get("enemy_id", "")).strip_edges()
	if enemy_id.is_empty():
		printerr("[CreateEnemyTool] 错误: enemy_id 为空，无法写入 enemy_config_v2.csv")
		return false

	if _id_exists_in_csv(ENEMY_CONFIG_V2_PATH, enemy_id):
		print("[CreateEnemyTool] ⚠️ enemy_config_v2 已存在，跳过: %s" % enemy_id)
		return true

	var full_config = DEFAULT_CONFIG.duplicate()
	full_config.merge(config, true)

	var row = PackedStringArray([
		enemy_id,
		str(full_config.get("director_role", "runner")).to_lower(),
		str(full_config.get("director_cost", 1.0)),
		str(full_config.get("health", 100)),
		str(full_config.get("speed", 160)),
		str(full_config.get("damage", 15)),
		str(full_config.get("behavior_params", "{}"))
	])

	return _append_csv_row(ENEMY_CONFIG_V2_PATH, row)

func _id_exists_in_csv(file_path: String, target_id: String) -> bool:
	if not FileAccess.file_exists(file_path):
		return false
	var file := FileAccess.open(file_path, FileAccess.READ)
	if file == null:
		return false
	while not file.eof_reached():
		var row := file.get_csv_line()
		if row.is_empty():
			continue
		if str(row[0]).strip_edges() == target_id:
			file.close()
			return true
	file.close()
	return false

func _append_to_csv(file_path: String, line: String) -> bool:
	"""追加一行到CSV文件"""
	var original := ""
	var read_file := FileAccess.open(file_path, FileAccess.READ)
	if read_file:
		original = read_file.get_as_text()
		read_file.close()

	var file = FileAccess.open(file_path, FileAccess.READ_WRITE)
	if not file:
		printerr("[CreateEnemyTool] 错误: 无法打开文件 %s" % file_path)
		return false
	
	# 移动到文件末尾
	file.seek_end()
	if original.length() > 0 and not original.ends_with("\n"):
		file.store_string("\n")
	file.store_line(line)
	file.close()
	
	print("[CreateEnemyTool] 已添加到 %s" % file_path)
	return true

func _append_csv_row(file_path: String, row: PackedStringArray) -> bool:
	var original := ""
	var read_file := FileAccess.open(file_path, FileAccess.READ)
	if read_file:
		original = read_file.get_as_text()
		read_file.close()

	var file := FileAccess.open(file_path, FileAccess.READ_WRITE)
	if file == null:
		printerr("[CreateEnemyTool] 错误: 无法打开文件 %s" % file_path)
		return false
	file.seek_end()
	if original.length() > 0 and not original.ends_with("\n"):
		file.store_string("\n")
	file.store_csv_line(row)
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
	print("   - 修改 config/enemy/enemy_config_v2.csv（导演预算出怪）")
	print("\n4. 添加能力:")
	print("   - 编辑 config/enemy/enemy_abilities.csv")
	print("   - 可用能力: poison_pool, shooting, charge")
	print("\n5. 如需在导演系统波次中出现：")
	print("   - 在 config/wave/wave_units_config_v2.csv 配置该 enemy_id")
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
