@tool
extends EditorScript

## =======================================s=======================================
## 角色创建工具
## ==============================================================================
## 
## 使用方法：
## 1. 修改下面的配置参数
## 2. 在Godot编辑器中：File -> Run -> 选择此脚本
## 3. 工具会自动创建角色脚本和CSV配置模板
## 
## ==============================================================================

# ==============================================================================
# 配置参数 - 修改这里来创建新角色
# ==============================================================================

const CHARACTER_ID = "dryad"           # 角色ID（小写，用下划线）
const CHARACTER_NAME = "德鲁伊"          # 角色名称（中文）
const SPRITE_PATH = "res://assets/sprites/Players/Player_26.png"
# CHARACTER_CLASS_NAME 会自动从 CHARACTER_ID 转换为大驼峰格式

# 基础属性
const MAX_HP = 100.0
const MAX_ENERGY = 100.0
const SPEED = 300.0
const ENERGY_REGEN = 10.0

# 技能绑定（留空表示不绑定）
const SKILL_Q = "skill_wind_path"        # Q技能ID
const SKILL_E = "skill_storm_eye"        # E技能ID
const SKILL_LMB = "skill_dash"           # 左键技能ID
const SKILL_RMB = ""                     # 右键技能ID（通常留空）

# 视觉配置

const SPRITE_SCALE = 1.0
const COLOR_MODULATE = "#ffffff"

# ==============================================================================
# 工具执行
# ==============================================================================

func _run() -> void:
	print("================================================================================")
	print("角色创建工具")
	print("================================================================================")
	print("")
	print("角色ID: %s" % CHARACTER_ID)
	print("角色名称: %s" % CHARACTER_NAME)
	print("类名: %s" % _to_pascal_case(CHARACTER_ID))
	print("")
	
	# 1. 创建角色脚本
	_create_character_script()
	
	# 2. 自动添加到CSV文件
	_add_to_csv_files()
	
	print("================================================================================")
	print("✅ 角色创建完成！")
	print("================================================================================")
	print("")
	print("下一步：")
	print("1. 在游戏中测试角色：PlayerFactory.create_player(\"%s\")" % CHARACTER_ID)
	print("2. 根据需要调整CSV配置文件中的参数")
	print("")

# ==============================================================================
# 工具函数
# ==============================================================================

func _to_pascal_case(snake_case: String) -> String:
	"""将蛇形命名转换为大驼峰命名
	例如: lovely_girl -> LovelyGirl
	"""
	var parts = snake_case.split("_")
	var result = ""
	for part in parts:
		if part.length() > 0:
			result += part[0].to_upper() + part.substr(1)
	return result

# ==============================================================================
# 创建角色脚本
# ==============================================================================

func _create_character_script() -> void:
	var script_path = "res://scenes/unit/players/player_%s.gd" % CHARACTER_ID
	var class_name_str = _to_pascal_case(CHARACTER_ID)
	
	# 检查文件是否已存在
	if FileAccess.file_exists(script_path):
		print("⚠️ 警告: 角色脚本已存在: %s" % script_path)
		print("   如需重新创建，请先删除现有文件")
		return
	
	var template = """extends PlayerBase
class_name Player%s

## ==============================================================================
## %s - 使用技能系统
## ==============================================================================

# ==============================================================================
# 配置参数（供技能类读取）
# ==============================================================================

@export_group("%s Settings")
# 在这里添加角色特定的参数
# 例如：
# @export var special_damage: int = 50
# @export var special_duration: float = 3.0

# ==============================================================================
# 技能管理器
# ==============================================================================
var skill_manager: SkillManager

# ==============================================================================
# 生命周期
# ==============================================================================

func _ready() -> void:
	super._ready()
	
	# 初始化技能管理器
	skill_manager = SkillManager.new(self)
	skill_manager.debug_mode = false
	add_child(skill_manager)
	skill_manager.load_skills_from_config("%s")

# ==============================================================================
# 输入处理
# ==============================================================================
func _handle_input(delta: float) -> void:
	# 1. 移动逻辑
	move_dir = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if can_move():
		var current_speed = speed
		position += move_dir * current_speed * delta
	
	# 2. 技能按键分发
	if not skill_manager:
		return
	
	# F键 - 大招
	if Input.is_action_just_pressed("skill_f"):
		if ultimate_skill:
			ultimate_skill.try_activate()
		else:
			Global.spawn_floating_text(global_position, "大招未实现", Color.GRAY)
		return
	
	# E技能（瞬发）
	if Input.is_action_just_pressed("skill_e"):
		skill_manager.execute_skill("e")
		return
	
	# Q技能（蓄力）
	if Input.is_action_pressed("skill_q"):
		skill_manager.charge_skill("q", delta)
		return
	elif Input.is_action_just_released("skill_q"):
		skill_manager.release_skill("q")
		return
	
	# 左键技能
	if Input.is_action_just_pressed("click_left"):
		skill_manager.execute_skill("lmb")

# ==============================================================================
# 自定义逻辑（可选）
# ==============================================================================

# 在这里添加角色特定的方法
# 例如：
# func on_special_event() -> void:
#     print("[Player%s] 触发特殊事件")
"""
	
	var content = template % [
		class_name_str,
		CHARACTER_NAME,
		CHARACTER_NAME,
		CHARACTER_ID,
		class_name_str
	]
	
	# 写入文件
	var file = FileAccess.open(script_path, FileAccess.WRITE)
	if not file:
		printerr("❌ 错误: 无法创建文件: %s" % script_path)
		return
	
	file.store_string(content)
	file.close()
	
	print("✅ 角色脚本创建成功: %s" % script_path)

# ==============================================================================
# 自动添加到CSV文件
# ==============================================================================

func _add_to_csv_files() -> void:
	print("")
	print("--------------------------------------------------------------------------------")
	print("正在添加到CSV配置文件...")
	print("--------------------------------------------------------------------------------")
	print("")
	
	# 1. player_config.csv
	# 列: player_id,display_name,display_order,enabled,ties,health,health_regen,skill_q_cost,skill_e_cost,close_threshold,energy_regen,max_energy,initial_energy,max_armor,base_speed,description,external_force_decay,knockback_scale,origin_tag,mastery_tag,tactic_tag
	var config_line = "%s,%s,99,1,通用,%.1f,0,50,30,60,%.1f,%.1f,%.1f,3,%.1f,新角色,50,0.3,,," % [
		CHARACTER_ID,
		CHARACTER_NAME,
		MAX_HP,
		ENERGY_REGEN,
		MAX_ENERGY,
		MAX_ENERGY,  # initial_energy = max_energy
		SPEED
	]
	_append_to_csv("res://config/player/player_config.csv", config_line, "player_config.csv")
	
	# 2. player_visual.csv
	# 列: player_id,sprite_path,scene_path,scale_x,scale_y,color_r,color_g,color_b,color_a,z_index
	var visual_line = "%s,%s,res://scenes/unit/players/player_generic.tscn,%.1f,%.1f,1,1,1,1,1" % [
		CHARACTER_ID,
		SPRITE_PATH,
		SPRITE_SCALE,
		SPRITE_SCALE
	]
	_append_to_csv("res://config/player/player_visual.csv", visual_line, "player_visual.csv")
	
	# 3. player_skill_bindings.csv
	# 列: player_id,slot_q,slot_e,slot_lmb,slot_rmb
	var skill_q_val = SKILL_Q if SKILL_Q != "" else ""
	var skill_e_val = SKILL_E if SKILL_E != "" else ""
	var skill_lmb_val = SKILL_LMB if SKILL_LMB != "" else ""
	var skill_rmb_val = SKILL_RMB if SKILL_RMB != "" else ""
	var bindings_line = "%s,%s,%s,%s,%s" % [
		CHARACTER_ID,
		skill_q_val,
		skill_e_val,
		skill_lmb_val,
		skill_rmb_val
	]
	_append_to_csv("res://config/player/player_skill_bindings.csv", bindings_line, "player_skill_bindings.csv")
	
	# 4. player_weapons.csv
	# 列: player_id,weapon_slot_1,weapon_slot_2,weapon_slot_3,weapon_slot_4,weapon_slot_5,weapon_slot_6
	var weapons_line = "%s,punch_1,punch_2,,,," % CHARACTER_ID
	_append_to_csv("res://config/player/player_weapons.csv", weapons_line, "player_weapons.csv")
	
	# 5. player_available_weapons.csv
	# 列: player_id,weapon_type_1,weapon_type_2,weapon_type_3,weapon_type_4
	var available_line = "%s,punch,laser,," % CHARACTER_ID
	_append_to_csv("res://config/player/player_available_weapons.csv", available_line, "player_available_weapons.csv")
	
	# 6. ult_config.csv
	# 列: ult_id,name,duration,energy_cost,bonus_bond_tag,visual_color_hex,scale_multiplier,explosion_radius,explosion_damage_scale,description
	var ult_id = "%s_ult" % CHARACTER_ID
	var ult_line = "%s,%s大招,10.0,40.0,martial,#FF3333,1.2,200.0,1.0,%s的终极技能" % [
		ult_id,
		CHARACTER_NAME,
		CHARACTER_NAME
	]
	_append_to_csv("res://config/player/ult_config.csv", ult_line, "ult_config.csv")
	
	print("")
	print("✅ 所有CSV配置已自动添加")
	print("")

func _append_to_csv(file_path: String, line: String, display_name: String) -> bool:
	"""追加一行到CSV文件"""
	# 检查文件是否存在
	if not FileAccess.file_exists(file_path):
		printerr("❌ 错误: CSV文件不存在: %s" % file_path)
		return false
	
	# 检查是否已存在该角色ID
	if _character_exists_in_csv(file_path, CHARACTER_ID):
		print("⚠️ 跳过 %s: 角色ID已存在" % display_name)
		return false
	
	# 读取文件内容检查最后一个字符
	var file = FileAccess.open(file_path, FileAccess.READ)
	if not file:
		printerr("❌ 错误: 无法打开文件: %s" % file_path)
		return false
	
	var content = file.get_as_text()
	file.close()
	
	# 重新打开文件用于追加
	file = FileAccess.open(file_path, FileAccess.READ_WRITE)
	if not file:
		printerr("❌ 错误: 无法打开文件: %s" % file_path)
		return false
	
	# 移动到文件末尾
	file.seek_end()
	
	# 如果文件不是以换行符结尾，先添加一个换行符
	if content.length() > 0 and not content.ends_with("\n"):
		file.store_string("\n")
	
	# 追加新行
	file.store_line(line)
	file.close()
	
	print("✅ 已添加到 %s" % display_name)
	return true

func _character_exists_in_csv(file_path: String, character_id: String) -> bool:
	"""检查角色ID是否已在CSV文件中"""
	var file = FileAccess.open(file_path, FileAccess.READ)
	if not file:
		return false
	
	while not file.eof_reached():
		var line = file.get_line().strip_edges()
		if line.begins_with(character_id + ","):
			file.close()
			return true
	
	file.close()
	return false

# ==============================================================================
# 打印CSV配置模板（备用）
# ==============================================================================

func _print_csv_templates() -> void:
	print("")
	print("--------------------------------------------------------------------------------")
	print("CSV配置模板")
	print("--------------------------------------------------------------------------------")
	print("")
	
	# player_config.csv
	print("【1. player_config.csv】")
	print("在文件末尾添加以下行：")
	print("")
	print("%s,%s,99,1,通用,%.1f,0,50,30,60,%.1f,%.1f,%.1f,3,%.1f,新角色,50,0.3,,,," % [
		CHARACTER_ID,
		CHARACTER_NAME,
		MAX_HP,
		ENERGY_REGEN,
		MAX_ENERGY,
		MAX_ENERGY,
		SPEED
	])
	print("")
	
	# player_visual.csv
	print("【2. player_visual.csv】")
	print("在文件末尾添加以下行：")
	print("")
	print("%s,%s,res://scenes/unit/players/player_generic.tscn,%.1f,%.1f,1,1,1,1,1" % [
		CHARACTER_ID,
		SPRITE_PATH,
		SPRITE_SCALE,
		SPRITE_SCALE
	])
	print("")
	
	# player_skill_bindings.csv
	print("【3. player_skill_bindings.csv】")
	print("在文件末尾添加以下行：")
	print("")
	var skill_q_val = SKILL_Q if SKILL_Q != "" else ""
	var skill_e_val = SKILL_E if SKILL_E != "" else ""
	var skill_lmb_val = SKILL_LMB if SKILL_LMB != "" else ""
	var skill_rmb_val = SKILL_RMB if SKILL_RMB != "" else ""
	print("%s,%s,%s,%s,%s" % [
		CHARACTER_ID,
		skill_q_val,
		skill_e_val,
		skill_lmb_val,
		skill_rmb_val
	])
	print("")
	
	# player_weapons.csv
	print("【4. player_weapons.csv】")
	print("在文件末尾添加以下行：")
	print("")
	print("%s,punch_1,punch_2,,,," % CHARACTER_ID)
	print("")
	
	# player_available_weapons.csv
	print("【5. player_available_weapons.csv】")
	print("在文件末尾添加以下行：")
	print("")
	print("%s,punch,laser,," % CHARACTER_ID)
	print("")
	
	print("--------------------------------------------------------------------------------")
