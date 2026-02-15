extends Node
## 武器配置加载器 - 从优化后的 CSV 动态创建 WeaponStats
## 新系统：每武器1行 + 等级倍率系统，大幅减少维护成本

const WEAPON_CONFIG_PATH = "res://config/weapon/weapon_config_optimized.csv"

# 缓存字典：{weapon_id: WeaponStats}（weapon_id = base_id + "_" + level）
var _weapon_cache: Dictionary = {}
# 原始 CSV 数据：{weapon_base_id: Dictionary}
var _raw_data: Dictionary = {}
# 表头映射：{字段名: 列索引}
var _header_map: Dictionary = {}

func _ready() -> void:
	load_weapon_config()

## 加载并解析 weapon_config_optimized.csv
func load_weapon_config() -> void:
	if not FileAccess.file_exists(WEAPON_CONFIG_PATH):
		printerr("[WeaponConfigLoader] 错误: 配置文件不存在 - ", WEAPON_CONFIG_PATH)
		return
	
	var file = FileAccess.open(WEAPON_CONFIG_PATH, FileAccess.READ)
	if not file:
		printerr("[WeaponConfigLoader] 错误: 无法打开配置文件 - ", WEAPON_CONFIG_PATH)
		return
	
	var line_number = 0
	var headers: Array = []
	
	while not file.eof_reached():
		var line = file.get_csv_line()
		line_number += 1
		
		# 跳过空行
		if line.size() == 0 or (line.size() == 1 and line[0].is_empty()):
			continue
		
		# 第一行：表头（英文字段名）
		if line_number == 1:
			headers = line
			for i in range(headers.size()):
				_header_map[headers[i]] = i
			print("[WeaponConfigLoader] 加载表头: ", headers.size(), " 个字段")
			continue
		
		# 第二行：中文注释（跳过）
		if line_number == 2:
			continue
		
		# 数据行：解析并缓存
		if line.size() < headers.size():
			push_warning("[WeaponConfigLoader] 第 ", line_number, " 行数据不完整，跳过")
			continue
		
		var weapon_base_id = line[_header_map["weapon_base_id"]]
		if weapon_base_id.is_empty() or weapon_base_id == "-1":
			continue
		
		# 构建原始数据字典
		var row_data = {}
		for i in range(headers.size()):
			row_data[headers[i]] = line[i] if i < line.size() else ""
		
		_raw_data[weapon_base_id] = row_data
	
	file.close()
	print("[WeaponConfigLoader] 加载完成: ", _raw_data.size(), " 个武器基础配置")

## 获取武器 Stats（带缓存）- 新版本支持等级参数
func get_weapon_stats(weapon_id: String) -> WeaponStats:
	# weapon_id 格式：base_id + "_" + level（如 "punch_1", "laser_3"）
	# 或者直接传入 base_id，默认等级为 1
	
	# 检查缓存
	if _weapon_cache.has(weapon_id):
		return _weapon_cache[weapon_id]
	
	# 解析 weapon_id
	var parts = weapon_id.split("_")
	var base_id = ""
	var level = 1
	
	if parts.size() >= 2 and parts[-1].is_valid_int():
		# 格式：base_id_level（如 "punch_1"）
		level = int(parts[-1])
		parts.remove_at(parts.size() - 1)
		base_id = "_".join(parts)
	else:
		# 格式：base_id（如 "punch"），默认等级 1
		base_id = weapon_id
		level = 1
	
	# 检查原始数据
	if not _raw_data.has(base_id):
		printerr("[WeaponConfigLoader] 错误: 未找到武器基础 ID - ", base_id)
		return null
	
	var row = _raw_data[base_id]
	
	# 调试：打印 row 的所有键
	if base_id == "punch":
		print("[WeaponConfigLoader] DEBUG punch row keys:")
		for key in row.keys():
			print("  - ", key, ": ", row[key])
	
	var max_level = _parse_int(row, "max_level", 4)
	
	# 验证等级范围
	if level < 1 or level > max_level:
		printerr("[WeaponConfigLoader] 错误: 等级 ", level, " 超出范围 [1, ", max_level, "] - ", weapon_id)
		return null
	
	# 动态创建 WeaponStats
	var stats = WeaponStats.new()
	
	# ============================================================================
	# 基础数值属性（应用等级倍率）
	# ============================================================================
	var base_damage = _parse_float(row, "base_damage", 1.0)
	var damage_scale = _parse_float(row, "damage_scale", 0.5)  # 每级增加 50%
	stats.damage = base_damage + (base_damage * damage_scale * (level - 1))
	
	stats.accuracy = _parse_float(row, "base_accuracy", 1.0)
	
	var base_cooldown = _parse_float(row, "base_cooldown", 1.0)
	var cooldown_scale = _parse_float(row, "cooldown_scale", -0.1)  # 每级减少 0.1 秒
	stats.cooldown = max(0.1, base_cooldown + (cooldown_scale * (level - 1)))
	
	var base_crit_chance = _parse_float(row, "base_crit_chance", 0.05)
	stats.crit_chance = base_crit_chance + (0.01 * (level - 1))  # 每级 +1%
	
	stats.crit_damage = _parse_float(row, "base_crit_damage", 1.5)
	
	var base_max_range = _parse_float(row, "base_max_range", 150.0)
	var range_scale = _parse_float(row, "range_scale", 10.0)  # 每级增加 10
	stats.max_range = base_max_range + (range_scale * (level - 1))
	
	# 调试日志
	if base_id == "punch":
		print("[WeaponConfigLoader] DEBUG punch:")
		print("  - base_max_range: ", base_max_range)
		print("  - range_scale: ", range_scale)
		print("  - level: ", level)
		print("  - max_range: ", stats.max_range)
		print("  - row['base_max_range']: ", row.get("base_max_range", "KEY_NOT_FOUND"))
	
	var base_knockback = _parse_float(row, "base_knockback", 0.0)
	var knockback_scale = _parse_float(row, "knockback_scale", 0.1)  # 每级增加 0.1
	stats.knockback = base_knockback + (knockback_scale * (level - 1))
	
	stats.life_steal = _parse_float(row, "base_life_steal", 0.0)
	stats.recoil = _parse_float(row, "base_recoil", 15.0)
	stats.recoil_duration = _parse_float(row, "base_recoil_duration", 0.1)
	stats.attack_duration = _parse_float(row, "base_attack_duration", 0.2)
	stats.back_duration = _parse_float(row, "base_back_duration", 0.15)
	stats.projectile_speed = _parse_float(row, "base_projectile_speed", 1600.0)
	
	# ============================================================================
	# 路径字段（支持模板）
	# ============================================================================
	stats.base_scene_path = _get_string(row, "base_scene_path")
	
	# 贴图模板（如 "punch_%d.png"）
	var sprite_template = _get_string(row, "sprite_texture_template")
	if sprite_template.contains("%d"):
		stats.sprite_texture = sprite_template.replace("%d", str(level))
	else:
		stats.sprite_texture = sprite_template
	
	# 图标模板
	var icon_template = _get_string(row, "icon_path_template")
	if icon_template.contains("%d"):
		# 暂时不使用，保持原样
		pass
	
	stats.sprite_texture_levels = _get_string(row, "sprite_texture_levels")
	stats.animation_frames_path = _get_string(row, "animation_frames_path")
	stats.vfx_attack_scene = _get_string(row, "vfx_attack_scene")
	stats.vfx_hit_scene = _get_string(row, "vfx_hit_scene")
	stats.audio_attack = _get_string(row, "audio_attack")
	
	# 子弹场景（特殊处理：需要加载为 PackedScene）
	var projectile_path = _get_string(row, "projectile_scene")
	if base_id == "shotgun":
		print("[WeaponConfigLoader] DEBUG shotgun projectile:")
		print("  - projectile_path: ", projectile_path)
		print("  - is_empty: ", projectile_path.is_empty())
		print("  - ResourceLoader.exists: ", ResourceLoader.exists(projectile_path))
	if not projectile_path.is_empty() and ResourceLoader.exists(projectile_path):
		stats.projectile_scene = load(projectile_path)
		if base_id == "shotgun":
			print("  - projectile_scene loaded: ", stats.projectile_scene)
	elif base_id == "shotgun":
		print("  - projectile_scene NOT loaded (path empty or doesn't exist)")
	
	# ============================================================================
	# 偏移/缩放字段（格式 "x|y"）
	# ============================================================================
	stats.muzzle_offset = _get_string(row, "muzzle_offset", "0|0")
	stats.hitbox_offset = _get_string(row, "hitbox_offset", "0|0")
	stats.hitbox_scale = _get_string(row, "hitbox_scale", "1.0|1.0")
	
	# ============================================================================
	# 形状/模式/效果字段
	# ============================================================================
	stats.shape_type = _get_string(row, "shape_type")
	stats.bullet_mode = _get_string(row, "bullet_mode")
	stats.effect_type = _get_string(row, "effect_type")
	
	# ============================================================================
	# 数值参数（应用等级倍率）
	# ============================================================================
	stats.sector_angle = _parse_float(row, "base_sector_angle", 0.0)
	
	var base_bullet_count = _parse_int(row, "base_bullet_count", 1)
	var bullet_count_scale = _parse_int(row, "bullet_count_scale", 0)  # 每级增加数量
	stats.bullet_count = base_bullet_count + (bullet_count_scale * (level - 1))
	
	stats.spread_angle = _parse_float(row, "base_spread_angle", 0.0)
	
	var base_pierce_count = _parse_int(row, "base_pierce_count", 0)
	var pierce_scale = _parse_float(row, "pierce_scale", 0.0)  # 每级增加穿透
	stats.pierce_count = base_pierce_count + int(pierce_scale * (level - 1))
	
	# ============================================================================
	# 通用扩展参数
	# ============================================================================
	stats.param1 = _get_string(row, "param1")
	stats.param2 = _get_string(row, "param2")
	stats.param3 = _get_string(row, "param3")
	
	# 缓存并返回
	_weapon_cache[weapon_id] = stats
	print("[WeaponConfigLoader] 创建武器 Stats: ", weapon_id, " (", base_id, " Lv.", level, ")")
	return stats

## 获取武器基础信息（不创建完整 Stats）
func get_weapon_info(weapon_id: String) -> Dictionary:
	# 解析 weapon_id
	var parts = weapon_id.split("_")
	var base_id = ""
	var level = 1
	
	if parts.size() >= 2 and parts[-1].is_valid_int():
		level = int(parts[-1])
		parts.remove_at(parts.size() - 1)
		base_id = "_".join(parts)
	else:
		base_id = weapon_id
		level = 1
	
	if not _raw_data.has(base_id):
		return {}
	
	var row = _raw_data[base_id]
	var max_level = _parse_int(row, "max_level", 4)
	
	# 生成显示名（应用模板）
	var display_name_template = _get_string(row, "display_name_template")
	var display_name = display_name_template.replace("%d", str(level)) if display_name_template.contains("%d") else display_name_template
	
	# 生成图标路径（应用模板）
	var icon_template = _get_string(row, "icon_path_template")
	var icon_path = icon_template.replace("%d", str(level)) if icon_template.contains("%d") else icon_template
	
	# 生成升级目标
	var upgrade_to = ""
	if level < max_level:
		upgrade_to = base_id + "_" + str(level + 1)
	
	# 计算物品花费（基础花费 * 等级）
	var base_cost = _parse_int(row, "item_cost_base", 1)
	var item_cost = base_cost * level
	
	return {
		"weapon_id": weapon_id,
		"base_id": base_id,
		"display_name": display_name,
		"type": _get_string(row, "type"),
		"level": level,
		"max_level": max_level,
		"icon_path": icon_path,
		"upgrade_to": upgrade_to,
		"item_cost": item_cost
	}

## 获取所有武器 ID 列表
func get_all_weapon_ids() -> Array:
	return _raw_data.keys()

## 清除缓存（用于热重载）
func clear_cache() -> void:
	_weapon_cache.clear()
	print("[WeaponConfigLoader] 缓存已清除")

# ============================================================================
# 私有辅助函数
# ============================================================================

func _get_string(row: Dictionary, key: String, default: String = "") -> String:
	if not row.has(key):
		return default
	var value = row[key]
	return value if value != null else default

func _parse_float(row: Dictionary, key: String, default: float = 0.0) -> float:
	var value = _get_string(row, key)
	if value.is_empty():
		return default
	return float(value)

func _parse_int(row: Dictionary, key: String, default: int = 0) -> int:
	var value = _get_string(row, key)
	if value.is_empty():
		return default
	return int(value)
