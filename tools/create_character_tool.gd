@tool
extends EditorScript

## ==============================================================================
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

const CHARACTER_ID = "tempest"           # 角色ID（小写，用下划线）
const CHARACTER_NAME = "暴风使"          # 角色名称（中文）
const CHARACTER_CLASS_NAME = "Tempest"   # 类名（大驼峰）

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
const SPRITE_PATH = "res://assets/sprites/Player_1.png"
const SPRITE_SCALE = 1.0
const COLOR_MODULATE = "#ffffff"

# ==============================================================================
# 工具执行
# ==============================================================================

func _run() -> void:
	print("================================================================================")
	print("角色创建工具")
	print("================================================================================")
	
	# 1. 创建角色脚本
	_create_character_script()
	
	# 2. 打印CSV配置模板
	_print_csv_templates()
	
	print("================================================================================")
	print("✅ 角色创建完成！")
	print("================================================================================")
	print("")
	print("下一步：")
	print("1. 将上面的CSV配置复制到对应的CSV文件中")
	print("2. 在游戏中测试角色：PlayerFactory.create_player(\"%s\")" % CHARACTER_ID)
	print("")

# ==============================================================================
# 创建角色脚本
# ==============================================================================

func _create_character_script() -> void:
	var script_path = "res://scenes/unit/players/player_%s.gd" % CHARACTER_ID
	
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
		CHARACTER_CLASS_NAME,
		CHARACTER_NAME,
		CHARACTER_NAME,
		CHARACTER_ID,
		CHARACTER_CLASS_NAME
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
# 打印CSV配置模板
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
	print("%s,%s,%.1f,%.1f,%.1f,%.1f,true" % [
		CHARACTER_ID,
		CHARACTER_NAME,
		MAX_HP,
		MAX_ENERGY,
		SPEED,
		ENERGY_REGEN
	])
	print("")
	
	# player_visual.csv
	print("【2. player_visual.csv】")
	print("在文件末尾添加以下行：")
	print("")
	print("%s,%s,%.1f,%s" % [
		CHARACTER_ID,
		SPRITE_PATH,
		SPRITE_SCALE,
		COLOR_MODULATE
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
	print("在文件末尾添加以下行（示例）：")
	print("")
	print("%s,weapon_pistol,1" % CHARACTER_ID)
	print("%s,weapon_shotgun,5" % CHARACTER_ID)
	print("")
	
	# player_available_weapons.csv
	print("【5. player_available_weapons.csv】")
	print("在文件末尾添加以下行（根据需要修改true/false）：")
	print("")
	print("%s,true,true,false,false,false,false,false,false,false" % CHARACTER_ID)
	print("")
	
	# skill_params.csv
	if SKILL_Q != "" or SKILL_E != "" or SKILL_LMB != "":
		print("【6. skill_params.csv】")
		print("为每个技能添加参数配置（如果技能需要角色特定参数）：")
		print("")
		if SKILL_Q != "":
			print("# %s 的 Q 技能参数" % CHARACTER_NAME)
			print("%s,%s,50,5,..." % [SKILL_Q, CHARACTER_ID])
		if SKILL_E != "":
			print("# %s 的 E 技能参数" % CHARACTER_NAME)
			print("%s,%s,30,3,..." % [SKILL_E, CHARACTER_ID])
		if SKILL_LMB != "":
			print("# %s 的左键技能参数" % CHARACTER_NAME)
			print("%s,%s,10,1,..." % [SKILL_LMB, CHARACTER_ID])
		print("")
	
	print("--------------------------------------------------------------------------------")
