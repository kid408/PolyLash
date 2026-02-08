@tool
extends EditorScript

## 角色武器分配工具
## 
## 功能：为每个角色分配武器
## 规则：
## 1. 每个角色至少3个武器
## 2. 默认武器（第1个）必须唯一，不能和其他角色重复
## 3. 其他武器（第2、3个）可以重复

func _run() -> void:
	print("========== 开始分配角色武器 ==========")
	
	# 所有可用武器列表（30个）
	var all_weapons = [
		"punch", "laser", "pistol", "spear", "axe", "sword", "shotgun", "wand",
		"chainsaw", "revolver", "smg", "mace", "scimitar", "heal_bolt",
		"thrust_charged", "swing_cleave", "swing_heavy", "circular_vortex",
		"circular_dual", "hammer_smash", "whip_lash", "spear_spin",
		"dagger_flurry", "scythe_reap", "chain_whip", "single_arc",
		"single_sniper", "spread_fan", "spread_burst", "pierce_ricochet",
		"pierce_laser", "magic_chain", "magic_meteor", "magic_heal_aoe",
		"bow_arrow"
	]
	
	# 角色列表（26个）
	var characters = [
		{"id": "butcher", "name": "屠夫", "type": "重装", "role": "突击"},
		{"id": "technology_hurricane", "name": "科技飓风", "type": "重装", "role": "突击"},
		{"id": "tankman", "name": "坦克手", "type": "重装", "role": "支援"},
		{"id": "heavy_support", "name": "重型援兵", "type": "重装", "role": "支援"},
		{"id": "warrior", "name": "武士", "type": "重装", "role": "突击"},
		{"id": "pyro", "name": "火焰", "type": "魔导", "role": "突击"},
		{"id": "weaver", "name": "织网", "type": "魔导", "role": "支援"},
		{"id": "electric_shock", "name": "电击", "type": "魔导", "role": "突击"},
		{"id": "wizard", "name": "巫师", "type": "魔导", "role": "指挥"},
		{"id": "fortune_teller", "name": "占卜师", "type": "魔导", "role": "支援"},
		{"id": "tarot_reader", "name": "塔罗师", "type": "魔导", "role": "指挥"},
		{"id": "necromancer", "name": "死灵法师", "type": "魔导", "role": "指挥"},
		{"id": "magician", "name": "魔法师", "type": "魔导", "role": "支援"},
		{"id": "witch_doctor", "name": "巫医", "type": "魔导", "role": "指挥"},
		{"id": "wind", "name": "疾风", "type": "游侠", "role": "指挥"},
		{"id": "lovely", "name": "小可爱", "type": "游侠", "role": "支援"},
		{"id": "camouflage", "name": "迷彩", "type": "游侠", "role": "突击"},
		{"id": "the_flash", "name": "闪电侠", "type": "游侠", "role": "突击"},
		{"id": "light_support", "name": "轻型援兵", "type": "游侠", "role": "支援"},
		{"id": "dryad", "name": "德鲁伊", "type": "游侠", "role": "指挥"},
		{"id": "sapper", "name": "工兵", "type": "后勤", "role": "支援"},
		{"id": "herder", "name": "牧者", "type": "后勤", "role": "指挥"},
		{"id": "information_Support", "name": "信息支援", "type": "后勤", "role": "指挥"},
		{"id": "technical_support", "name": "科技援兵", "type": "后勤", "role": "支援"},
		{"id": "doctor", "name": "医生", "type": "后勤", "role": "支援"},
		{"id": "nurse", "name": "护士", "type": "后勤", "role": "支援"},
	]
	
	# 武器分类（根据类型和角色特点）
	var melee_weapons = ["punch", "spear", "axe", "sword", "chainsaw", "mace", "scimitar", 
		"thrust_charged", "swing_cleave", "swing_heavy", "circular_vortex", "circular_dual",
		"hammer_smash", "whip_lash", "spear_spin", "dagger_flurry", "scythe_reap", "chain_whip"]
	
	var range_weapons = ["laser", "pistol", "shotgun", "revolver", "smg", "single_arc",
		"single_sniper", "spread_fan", "spread_burst", "pierce_ricochet", "pierce_laser", "bow_arrow"]
	
	var magic_weapons = ["wand", "magic_chain", "magic_meteor"]
	
	var support_weapons = ["heal_bolt", "magic_heal_aoe"]
	
	# 为每个角色分配武器
	var weapon_assignments = {}
	var used_default_weapons = []  # 已使用的默认武器
	
	for i in range(characters.size()):
		var char = characters[i]
		var char_id = char["id"]
		var char_type = char["type"]
		var char_role = char["role"]
		
		var assigned_weapons = []
		
		# 1. 分配默认武器（必须唯一）
		var default_weapon = _assign_default_weapon(char_type, char_role, i, all_weapons, used_default_weapons)
		assigned_weapons.append(default_weapon)
		used_default_weapons.append(default_weapon)
		
		# 2. 分配第2个武器（可以重复）
		var second_weapon = _assign_secondary_weapon(char_type, char_role, all_weapons, assigned_weapons)
		assigned_weapons.append(second_weapon)
		
		# 3. 分配第3个武器（可以重复）
		var third_weapon = _assign_tertiary_weapon(char_type, char_role, all_weapons, assigned_weapons)
		assigned_weapons.append(third_weapon)
		
		weapon_assignments[char_id] = assigned_weapons
		
		print("%s (%s - %s): %s" % [char["name"], char_type, char_role, ", ".join(assigned_weapons)])
	
	print("\n========== 分配完成 ==========")
	print("总角色数: %d" % characters.size())
	print("总武器数: %d" % all_weapons.size())
	print("已使用的唯一默认武器: %d" % used_default_weapons.size())
	
	# 生成配置文件
	_generate_config_file(weapon_assignments, characters)

## 分配默认武器（必须唯一）
func _assign_default_weapon(char_type: String, char_role: String, index: int, all_weapons: Array, used: Array) -> String:
	# 根据角色类型和索引分配唯一的默认武器
	var available = []
	for weapon in all_weapons:
		if weapon not in used:
			available.append(weapon)
	
	if available.is_empty():
		push_error("没有可用的默认武器了！")
		return "punch"
	
	# 根据角色类型优先选择合适的武器
	match char_type:
		"重装":
			# 优先选择近战重型武器
			for w in ["hammer_smash", "mace", "axe", "swing_heavy", "sword", "spear"]:
				if w in available:
					return w
		"魔导":
			# 优先选择魔法武器
			for w in ["wand", "magic_chain", "magic_meteor", "laser", "heal_bolt"]:
				if w in available:
					return w
		"游侠":
			# 优先选择远程或快速武器
			for w in ["pistol", "revolver", "smg", "dagger_flurry", "scimitar", "bow_arrow"]:
				if w in available:
					return w
		"后勤":
			# 优先选择支援或远程武器
			for w in ["heal_bolt", "magic_heal_aoe", "pistol", "shotgun", "wand"]:
				if w in available:
					return w
	
	# 如果没有匹配的，返回第一个可用的
	return available[0]

## 分配第2个武器（可以重复）
func _assign_secondary_weapon(char_type: String, char_role: String, all_weapons: Array, assigned: Array) -> String:
	var available = []
	for weapon in all_weapons:
		if weapon not in assigned:
			available.append(weapon)
	
	# 根据角色类型选择互补的武器
	match char_type:
		"重装":
			# 添加一个远程武器作为补充
			for w in ["shotgun", "pistol", "revolver", "laser"]:
				if w in available:
					return w
		"魔导":
			# 添加另一个魔法武器
			for w in ["laser", "magic_chain", "wand", "magic_meteor"]:
				if w in available:
					return w
		"游侠":
			# 添加另一个远程武器
			for w in ["smg", "bow_arrow", "single_arc", "pistol"]:
				if w in available:
					return w
		"后勤":
			# 添加支援武器
			for w in ["magic_heal_aoe", "heal_bolt", "pistol", "wand"]:
				if w in available:
					return w
	
	return available[0] if not available.is_empty() else "punch"

## 分配第3个武器（可以重复）
func _assign_tertiary_weapon(char_type: String, char_role: String, all_weapons: Array, assigned: Array) -> String:
	var available = []
	for weapon in all_weapons:
		if weapon not in assigned:
			available.append(weapon)
	
	# 根据角色角色选择第三个武器
	match char_role:
		"突击":
			# 高伤害武器
			for w in ["single_sniper", "swing_heavy", "hammer_smash", "axe", "shotgun"]:
				if w in available:
					return w
		"支援":
			# 支援或控制武器
			for w in ["heal_bolt", "magic_heal_aoe", "wand", "pistol"]:
				if w in available:
					return w
		"指挥":
			# 范围或控制武器
			for w in ["spread_fan", "magic_chain", "circular_vortex", "scythe_reap"]:
				if w in available:
					return w
	
	return available[0] if not available.is_empty() else "laser"

## 生成配置文件
func _generate_config_file(assignments: Dictionary, characters: Array) -> void:
	# 生成 player_available_weapons.csv 格式
	var output = "player_id,weapon_type_1,weapon_type_2,weapon_type_3,weapon_type_4\n"
	output += "-1,武器类型1,武器类型2,武器类型3,武器类型4\n"
	
	for char in characters:
		var char_id = char["id"]
		var weapons = assignments[char_id]
		# 格式: player_id,weapon_type_1,weapon_type_2,weapon_type_3,weapon_type_4
		output += "%s,%s,%s,%s,\n" % [char_id, weapons[0], weapons[1], weapons[2]]
	
	# 保存到文件
	var file_path = "res://config/player/player_available_weapons.csv"
	var file = FileAccess.open(file_path, FileAccess.WRITE)
	if file:
		file.store_string(output)
		file.close()
		print("\n✅ 配置文件已更新: %s" % file_path)
		print("   格式: player_id,weapon_type_1,weapon_type_2,weapon_type_3")
	else:
		push_error("❌ 无法创建配置文件: %s" % file_path)
