@tool
extends EditorScript

# ============================================================================
# 瑙掕壊鍒涘缓宸ュ叿锛堝綋鍓嶆祦绋嬬増锛?
# ============================================================================
#
# 鍔熻兘锛?
# 1. 鐢熸垚鏈€灏忚鑹茶剼鏈細player_<id>.gd锛堢户鎵?PlayerBase锛?
# 2. 杩藉姞鏈€鏂拌〃缁撴瀯閰嶇疆锛?
#    - player_config.csv
#    - player_visual.csv
#    - player_skill_bindings.csv
#    - player_weapons.csv
#    - player_available_weapons.csv
#    - ult_config.csv锛?0鍒楋級
#
# 璇存槑锛?
# - 褰撳墠椤圭洰鐢?PlayerBase 鑷姩鍒涘缓 SkillManager 涓庡鐞嗚緭鍏ワ紝
#   瑙掕壊鑴氭湰榛樿鍙繚鐣欐渶灏忓瓙绫伙紝閬垮厤閲嶅閫昏緫銆?
# ============================================================================

# ----------------------------------------------------------------------------
# 瑙掕壊鍩虹閰嶇疆锛堟寜闇€淇敼锛?
# ----------------------------------------------------------------------------
const CHARACTER_ID := "dryad"
const CHARACTER_NAME := "寰烽瞾浼?
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

# 缇佺粖鏍囩锛圛D锛?
const ORIGIN_TAG := "nomad"
const MASTERY_TAG := "geometrist"
const TACTIC_TAG := "commander"

# 灞曠ず鐢ㄤ笁绫绘枃妗堬紙player_config.ties锛?
const TIES_DISPLAY := "锋芒|几何师|指挥型"

# 鎶€鑳界粦瀹?
const SKILL_Q := "skill_windblade_path"
const SKILL_E := "skill_storm_eye"
const SKILL_LMB := "skill_dash"
const SKILL_RMB := ""

# 鍒濆姝﹀櫒
const WEAPON_SLOT_1 := "punch_1"
const WEAPON_SLOT_2 := "punch_2"
const AVAILABLE_WEAPON_1 := "punch"
const AVAILABLE_WEAPON_2 := "laser"
const AVAILABLE_WEAPON_3 := ""
const AVAILABLE_WEAPON_4 := ""

# Q闂悎涓撳睘闊虫晥锛堝彲鐣欑┖锛?
const Q_CLOSURE_SFX := ""
const Q_CLOSURE_VOLUME_DB := 0.0
const Q_CLOSURE_SFX_ENABLED := 0

# 澶ф嫑榛樿閰嶇疆锛坲lt_config.csv锛?
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
	print("瑙掕壊鍒涘缓宸ュ叿锛堝綋鍓嶆祦绋嬬増锛?)
	print("=".repeat(72))
	print("瑙掕壊ID: %s" % CHARACTER_ID)
	print("瑙掕壊鍚? %s" % CHARACTER_NAME)
	print("鑴氭湰绫诲悕: Player%s" % _to_pascal_case(CHARACTER_ID))

	if CHARACTER_ID.strip_edges().is_empty():
		printerr("鉂?CHARACTER_ID 涓嶈兘涓虹┖")
		return

	_create_character_script()
	_append_all_csv_rows()

	print("\n鉁?鍒涘缓瀹屾垚")
	print("涓嬩竴姝ワ細")
	print("1. 鍦ㄩ€夋嫨鐣岄潰纭璇ヨ鑹插凡鍑虹幇")
	print("2. 鍦?player_skill_bindings.csv 妫€鏌ユ妧鑳絀D鏄惁鍙姞杞?)
	print("3. 鍦?ult_config.csv 鎸夎鑹插畾浣嶈皟鏁?F 鍙傛暟")
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
		print("鈿狅笍 宸插瓨鍦ㄨ鑹茶剼鏈紝璺宠繃鍒涘缓: %s" % script_path)
		return

	var content := """extends PlayerBase
class_name Player%s

## ==============================================================================
## %s
## 璇存槑锛?
## - 榛樿浣跨敤 PlayerBase 鐨勮嚜鍔ㄨ緭鍏ヤ笌鎶€鑳界鐞嗘祦绋?
## - 鑻ラ渶瑙掕壊涓撳睘琛屼负锛岃閲嶅啓 _process_subclass / 鍏朵粬閽╁瓙
## ==============================================================================

func _process_subclass(_delta: float) -> void:
	pass
""" % [class_name_str, CHARACTER_NAME]

	var file := FileAccess.open(script_path, FileAccess.WRITE)
	if file == null:
		printerr("鉂?鏃犳硶鍐欏叆瑙掕壊鑴氭湰: %s" % script_path)
		return
	file.store_string(content)
	file.close()
	print("鉁?宸插垱寤鸿鑹茶剼鏈? %s" % script_path)

func _append_all_csv_rows() -> void:
	print("\n--- 鍐欏叆 CSV 閰嶇疆 ---")

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
		"鏂拌鑹?,
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
		"%s澶ф嫑" % CHARACTER_NAME,
		str(ULT_DURATION),
		str(ULT_ENERGY_COST),
		TACTIC_TAG,
		ULT_VISUAL_COLOR,
		str(ULT_SCALE_MULTIPLIER),
		str(ULT_EXPLOSION_RADIUS),
		str(ULT_EXPLOSION_DAMAGE_SCALE),
		"%s鐨勭粓鏋佹妧鑳? % CHARACTER_NAME,
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
		printerr("鉂?鏂囦欢涓嶅瓨鍦? %s" % file_path)
		return

	if _csv_contains_id(file_path, id_value):
		print("鈿狅笍 璺宠繃 %s: ID 宸插瓨鍦?(%s)" % [display_name, id_value])
		return

	var original_text := ""
	var read_file := FileAccess.open(file_path, FileAccess.READ)
	if read_file != null:
		original_text = read_file.get_as_text()
		read_file.close()

	var file := FileAccess.open(file_path, FileAccess.READ_WRITE)
	if file == null:
		printerr("鉂?鏃犳硶鍐欏叆鏂囦欢: %s" % file_path)
		return

	file.seek_end()
	if original_text.length() > 0 and not original_text.ends_with("\n"):
		file.store_string("\n")
	file.store_csv_line(row)
	file.close()
	print("鉁?宸插啓鍏?%s" % display_name)

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
