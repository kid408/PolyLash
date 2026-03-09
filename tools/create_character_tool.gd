@tool
extends EditorScript

# ============================================================================
# 角色创建工具（当前流程版）
# ============================================================================
#
# 功能：
# 1. 生成最小角色脚本：player_<id>.gd（继承 PlayerBase）
# 2. 追加最新表结构配置：
#    - player_config.csv
#    - player_visual.csv
#    - player_skill_bindings.csv
#    - player_weapons.csv
#    - player_available_weapons.csv
#    - ult_config.csv（20列）
#
# 说明：
# - 当前项目由 PlayerBase 自动创建 SkillManager 与处理输入，
#   角色脚本默认只保留最小子类，避免重复逻辑。
# ============================================================================

# ----------------------------------------------------------------------------
# 角色基础配置（按需修改）
# ----------------------------------------------------------------------------
const CHARACTER_ID := "dryad"
const CHARACTER_NAME := "德鲁伊"
const DISPLAY_ORDER := 99
const ENABLED := 1

const SPRITE_PATH := "res://assets/sprites/Players/Player_26.png"
const SPRITE_SCALE := 1.0

const HEALTH := 100.0
const HEALTH_REGEN := 0.0
const SKILL_Q_COST := 20.0
const SKILL_E_COST := 40.0
const CLOSE_THRESHOLD := 60.0
const ENERGY_REGEN := 0.8
const MAX_ENERGY := 1000.0
const MAX_ARMOR := 3
const BASE_SPEED := 500.0

const EXTERNAL_FORCE_DECAY := 50.0
const KNOCKBACK_SCALE := 0.3

# 羁绊标签（ID）
const ORIGIN_TAG := "nomad"
const MASTERY_TAG := "geometrist"
const TACTIC_TAG := "commander"

# 展示用三类文案（player_config.ties）
const TIES_DISPLAY := "游侠|几何师|指挥型"

# 技能绑定
const SKILL_Q := "skill_wind_path"
const SKILL_E := "skill_storm_eye"
const SKILL_LMB := "skill_dash"
const SKILL_RMB := ""

# 初始武器
const WEAPON_SLOT_1 := "punch_1"
const WEAPON_SLOT_2 := "punch_2"
const AVAILABLE_WEAPON_1 := "punch"
const AVAILABLE_WEAPON_2 := "laser"
const AVAILABLE_WEAPON_3 := ""
const AVAILABLE_WEAPON_4 := ""

# Q闭合专属音效（可留空）
const Q_CLOSURE_SFX := ""
const Q_CLOSURE_VOLUME_DB := 0.0
const Q_CLOSURE_SFX_ENABLED := 0

# 大招默认配置（ult_config.csv）
const ULT_DURATION := 10.0
const ULT_ENERGY_COST := 40.0
const ULT_VISUAL_COLOR := "#66FF99"
const ULT_SCALE_MULTIPLIER := 1.2
const ULT_EXPLOSION_RADIUS := 240.0
const ULT_EXPLOSION_DAMAGE_SCALE := 1.0
const ULT_F_INTERNAL_CD := 0.95
const ULT_F_Q_LINE_AMP := 1.50
const ULT_F_Q_CLOSURE_AMP := 1.95
const ULT_F_SPECIAL_VALUE_1 := 1.15
const ULT_F_SPECIAL_VALUE_2 := 230.0
const ULT_F_SPECIAL_VALUE_3 := 0.30

func _run() -> void:
	print("\n" + "=".repeat(72))
	print("角色创建工具（当前流程版）")
	print("=".repeat(72))
	print("角色ID: %s" % CHARACTER_ID)
	print("角色名: %s" % CHARACTER_NAME)
	print("脚本类名: Player%s" % _to_pascal_case(CHARACTER_ID))

	if CHARACTER_ID.strip_edges().is_empty():
		printerr("❌ CHARACTER_ID 不能为空")
		return

	_create_character_script()
	_append_all_csv_rows()

	print("\n✅ 创建完成")
	print("下一步：")
	print("1. 在选择界面确认该角色已出现")
	print("2. 在 player_skill_bindings.csv 检查技能ID是否可加载")
	print("3. 在 ult_config.csv 按角色定位调整 F 参数")
	print("=".repeat(72) + "\n")

func _to_pascal_case(snake_case: String) -> String:
	var parts := snake_case.split("_")
	var out := ""
	for part in parts:
		if part.length() <= 0:
			continue
		out += part[0].to_upper() + part.substr(1)
	return out

func _create_character_script() -> void:
	var script_path := "res://scenes/unit/players/player_%s.gd" % CHARACTER_ID
	var class_name_str := _to_pascal_case(CHARACTER_ID)

	if FileAccess.file_exists(script_path):
		print("⚠️ 已存在角色脚本，跳过创建: %s" % script_path)
		return

	var content := """extends PlayerBase
class_name Player%s

## ==============================================================================
## %s
## 说明：
## - 默认使用 PlayerBase 的自动输入与技能管理流程
## - 若需角色专属行为，请重写 _process_subclass / 其他钩子
## ==============================================================================

func _process_subclass(_delta: float) -> void:
	pass
""" % [class_name_str, CHARACTER_NAME]

	var file := FileAccess.open(script_path, FileAccess.WRITE)
	if file == null:
		printerr("❌ 无法写入角色脚本: %s" % script_path)
		return
	file.store_string(content)
	file.close()
	print("✅ 已创建角色脚本: %s" % script_path)

func _append_all_csv_rows() -> void:
	print("\n--- 写入 CSV 配置 ---")

	var player_id := CHARACTER_ID
	var ult_id := "%s_ult" % CHARACTER_ID

	var player_config_row := PackedStringArray([
		player_id,
		CHARACTER_NAME,
		str(DISPLAY_ORDER),
		str(ENABLED),
		TIES_DISPLAY,
		str(HEALTH),
		str(HEALTH_REGEN),
		str(SKILL_Q_COST),
		str(SKILL_E_COST),
		str(CLOSE_THRESHOLD),
		str(ENERGY_REGEN),
		str(MAX_ENERGY),
		str(MAX_ENERGY),
		str(MAX_ARMOR),
		str(BASE_SPEED),
		"新角色",
		str(EXTERNAL_FORCE_DECAY),
		str(KNOCKBACK_SCALE),
		ORIGIN_TAG,
		MASTERY_TAG,
		TACTIC_TAG,
		Q_CLOSURE_SFX,
		str(Q_CLOSURE_VOLUME_DB),
		str(Q_CLOSURE_SFX_ENABLED)
	])
	_append_csv_row("res://config/player/player_config.csv", player_config_row, player_id, "player_config.csv")

	var player_visual_row := PackedStringArray([
		player_id,
		SPRITE_PATH,
		"res://scenes/unit/players/player_generic.tscn",
		str(SPRITE_SCALE),
		str(SPRITE_SCALE),
		"1",
		"1",
		"1",
		"1",
		"1"
	])
	_append_csv_row("res://config/player/player_visual.csv", player_visual_row, player_id, "player_visual.csv")

	var skill_bind_row := PackedStringArray([
		player_id,
		SKILL_Q,
		SKILL_E,
		SKILL_LMB,
		SKILL_RMB
	])
	_append_csv_row("res://config/player/player_skill_bindings.csv", skill_bind_row, player_id, "player_skill_bindings.csv")

	var player_weapons_row := PackedStringArray([
		player_id,
		WEAPON_SLOT_1,
		WEAPON_SLOT_2,
		"",
		"",
		"",
		""
	])
	_append_csv_row("res://config/player/player_weapons.csv", player_weapons_row, player_id, "player_weapons.csv")

	var available_weapons_row := PackedStringArray([
		player_id,
		AVAILABLE_WEAPON_1,
		AVAILABLE_WEAPON_2,
		AVAILABLE_WEAPON_3,
		AVAILABLE_WEAPON_4
	])
	_append_csv_row("res://config/player/player_available_weapons.csv", available_weapons_row, player_id, "player_available_weapons.csv")

	var ult_row := PackedStringArray([
		ult_id,
		"%s大招" % CHARACTER_NAME,
		str(ULT_DURATION),
		str(ULT_ENERGY_COST),
		TACTIC_TAG,
		ULT_VISUAL_COLOR,
		str(ULT_SCALE_MULTIPLIER),
		str(ULT_EXPLOSION_RADIUS),
		str(ULT_EXPLOSION_DAMAGE_SCALE),
		"%s的终极技能" % CHARACTER_NAME,
		CHARACTER_ID,
		str(ULT_F_INTERNAL_CD),
		str(ULT_F_Q_LINE_AMP),
		str(ULT_F_Q_CLOSURE_AMP),
		str(ULT_F_SPECIAL_VALUE_1),
		str(ULT_F_SPECIAL_VALUE_2),
		str(ULT_F_SPECIAL_VALUE_3),
		_build_bond_payload(ORIGIN_TAG, "line"),
		_build_bond_payload(MASTERY_TAG, "closure"),
		_build_bond_payload(TACTIC_TAG, "tempo")
	])
	_append_csv_row("res://config/player/ult_config.csv", ult_row, ult_id, "ult_config.csv")

func _build_bond_payload(tag_id: String, axis: String) -> String:
	if tag_id.strip_edges().is_empty():
		return ""
	return "tag:%s|lv2:0.12|lv3:0.24|axis:%s" % [tag_id, axis]

func _append_csv_row(file_path: String, row: PackedStringArray, id_value: String, display_name: String) -> void:
	if not FileAccess.file_exists(file_path):
		printerr("❌ 文件不存在: %s" % file_path)
		return

	if _csv_contains_id(file_path, id_value):
		print("⚠️ 跳过 %s: ID 已存在 (%s)" % [display_name, id_value])
		return

	var original_text := ""
	var read_file := FileAccess.open(file_path, FileAccess.READ)
	if read_file != null:
		original_text = read_file.get_as_text()
		read_file.close()

	var file := FileAccess.open(file_path, FileAccess.READ_WRITE)
	if file == null:
		printerr("❌ 无法写入文件: %s" % file_path)
		return

	file.seek_end()
	if original_text.length() > 0 and not original_text.ends_with("\n"):
		file.store_string("\n")
	file.store_csv_line(row)
	file.close()
	print("✅ 已写入 %s" % display_name)

func _csv_contains_id(file_path: String, target_id: String) -> bool:
	var file := FileAccess.open(file_path, FileAccess.READ)
	if file == null:
		return false

	while not file.eof_reached():
		var fields := file.get_csv_line()
		if fields.is_empty():
			continue
		var row_id := str(fields[0]).strip_edges()
		if row_id == target_id:
			file.close()
			return true
	file.close()
	return false
