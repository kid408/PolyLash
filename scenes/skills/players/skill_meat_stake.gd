extends SkillBase
class_name SkillMeatStake

## ==============================================================================
## 灞犲かE鎶€鑳?- 鑲夋々鎶曟幏
## ==============================================================================
## 
## 鍔熻兘璇存槑:
## - 鍚戦紶鏍囦綅缃姇鎺疯倝妗?
## - 鑲夋々椋炶鏃舵媺鎵部閫旀晫浜?
## - 鐫€闄嗗悗鐢ㄩ摼鏉℃帶鍒惰寖鍥村唴鏁屼汉
## - 鎸佺画6绉掑悗娑堝け
## 
## ==============================================================================

# ==============================================================================
# 鎶€鑳藉弬鏁帮紙浠嶤SV鍔犺浇锛?
# ==============================================================================

## 閾炬潯鎺у埗鍗婂緞
var chain_radius: float = 250.0

## 鑲夋々椋炶閫熷害
var stake_throw_speed: float = 1200.0

## 鑲夋々鐫€闄嗕激瀹?
var stake_impact_damage: int = 20

## 鑲夋々鎸佺画鏃堕棿
var stake_duration: float = 6.0

## 鏈€澶ф姇鎺疯窛绂?
var max_throw_distance: float = 800.0

# ==============================================================================
# 瑙嗚閰嶇疆
# ==============================================================================

## 閾炬潯棰滆壊
var chain_color: Color = Color(0.3, 0.1, 0.1, 0.8)

# ==============================================================================
# 杩愯鏃剁姸鎬?
# ==============================================================================

## 褰撳墠婵€娲荤殑鑲夋々
var active_stake: Node2D = null

# ==============================================================================
# 鐢熷懡鍛ㄦ湡
# ==============================================================================

func _ready() -> void:
	super._ready()

# ==============================================================================
# 鎶€鑳芥墽琛?
# ==============================================================================

## 鎵ц鎶€鑳斤紙鎶曟幏鑲夋々锛?
func execute() -> void:
	# 妫€鏌ユ槸鍚﹀彲浠ユ墽琛?
	if not can_execute():
		if is_on_cooldown and skill_owner:
			Global.spawn_floating_text(skill_owner.global_position, "Cooldown!", Color.YELLOW)
		return
	
	# 娑堣€楄兘閲?
	if not consume_energy():
		if skill_owner:
			Global.spawn_floating_text(skill_owner.global_position, "No Energy!", Color.RED)
		return
	
	# 娓呴櫎鏃ц倝妗?
	if is_instance_valid(active_stake):
		active_stake.queue_free()
		active_stake = null
	
	# 璁＄畻鐩爣浣嶇疆
	if not skill_owner:
		return
	
	var target_pos = skill_owner.get_global_mouse_position()
	var dir = (target_pos - skill_owner.global_position).normalized()
	var dist = min(skill_owner.global_position.distance_to(target_pos), max_throw_distance)
	var final_pos = skill_owner.global_position + dir * dist
	
	# 鍒涘缓鑲夋々
	var stake = MeatStake.new()
	stake.setup(final_pos, skill_owner)
	
	# 璁剧疆鑲夋々鍙傛暟
	_setup_stake_params(stake)
	
	# 娣诲姞鍒板満鏅爲
	skill_owner.get_parent().add_child(stake)
	stake.global_position = skill_owner.global_position
	
	active_stake = stake
	
	# 鐩告満闇囧姩
	Global.on_camera_shake.emit(10.0, 0.2)
	
	# 寮€濮嬪喎鍗?
	start_cooldown()

## 璁剧疆鑲夋々鍙傛暟
func _setup_stake_params(stake: MeatStake) -> void:
	# 灏嗘妧鑳藉弬鏁颁紶閫掔粰鑲夋々
	# 娉ㄦ剰锛歁eatStake浼氫粠player_ref璇诲彇鍙傛暟锛屾墍浠ユ垜浠渶瑕佺‘淇漵kill_owner鏈夎繖浜涘睘鎬?
	
	# 濡傛灉skill_owner娌℃湁杩欎簺灞炴€э紝鎴戜滑闇€瑕佷复鏃舵坊鍔?
	if not "chain_radius" in skill_owner:
		skill_owner.set("chain_radius", chain_radius)
	if not "stake_throw_speed" in skill_owner:
		skill_owner.set("stake_throw_speed", stake_throw_speed)
	if not "stake_impact_damage" in skill_owner:
		skill_owner.set("stake_impact_damage", stake_impact_damage)
	if not "stake_duration" in skill_owner:
		skill_owner.set("stake_duration", stake_duration)
	if not "chain_color" in skill_owner:
		skill_owner.set("chain_color", chain_color)

# ==============================================================================
# 杈呭姪鏂规硶
# ==============================================================================

## 娓呯悊璧勬簮
func cleanup() -> void:
	if is_instance_valid(active_stake):
		active_stake.queue_free()
	active_stake = null

func get_active_stake() -> Node2D:
	return active_stake

## 妫€鏌ユ槸鍚︽湁婵€娲荤殑鑲夋々
func has_active_stake() -> bool:
	return is_instance_valid(active_stake)

## 鎵撳嵃璋冭瘯淇℃伅
func print_debug_info() -> void:
	print("[SkillMeatStake] 璋冭瘯淇℃伅:")
	print("  - has_active_stake: %s" % has_active_stake())
	print("  - chain_radius: %.0f" % chain_radius)
	print("  - stake_throw_speed: %.0f" % stake_throw_speed)
	print("  - stake_impact_damage: %d" % stake_impact_damage)
	print("  - stake_duration: %.1f" % stake_duration)
	print("  - energy_cost: %.0f" % energy_cost)
	print("  - cooldown_time: %.1f" % cooldown_time)

