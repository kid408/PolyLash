extends Node
class_name SkillManager

## ==============================================================================

## ==============================================================================
## 
## 鍔熻兘璇存槑:




## 
## 浣跨敤鏂规硶:
##   var skill_manager = SkillManager.new(self)
##   add_child(skill_manager)
##   skill_manager.load_skills_from_config(player_id)
##   skill_manager.execute_skill("q")
## 
## ==============================================================================

# ==============================================================================

# ==============================================================================

## 閹垛偓閼宠姤蝎娴ｅ秴鐡ч崗?
# 字段定义
# 字段定义
var skill_slots: Dictionary = {
	"q": null,
	"e": null,
	"lmb": null,
	"rmb": null
}

# 字段定义
var skill_owner: Node2D

## 璋冭瘯妯″紡
var debug_mode: bool = false

# ==============================================================================
# 闁告帗绻傞～鎰板礌?
# ==============================================================================

func _init(_owner: Node2D = null):
	if _owner:
		skill_owner = _owner

func _ready() -> void:
	if not skill_owner:
		push_error("[SkillManager] Error: skill_owner is not set")

# ==============================================================================
# 閹垛偓閼宠棄濮炴潪?
# ==============================================================================


## @param player_id: 闁绘壕鏅涢宀籇闁挎稑鐗嗛々?butcher", "weaver"闁?
# 函数：load_skills_from_config
func load_skills_from_config(player_id: String) -> bool:
	if player_id.is_empty():
		push_error("[SkillManager] Error: player_id is empty")
		return false
	
	if not skill_owner:
		push_error("[SkillManager] Error: skill_owner is not set, cannot load skills")
		return false
	
	# 字段定义
	var bindings = ConfigManager.get_player_skill_bindings(player_id)
	if bindings.is_empty():
		push_warning("[SkillManager] Warning: missing skill binding config for %s" % player_id)
		return false
	
	# 字段定义
	var success_count = 0
	var total_count = 0
	
	for slot in ["q", "e", "lmb", "rmb"]:
		var skill_id = bindings.get("slot_%s" % slot, "")
		if not skill_id.is_empty():
			total_count += 1
			if _load_skill_to_slot(slot, skill_id):
				success_count += 1
	
	return success_count > 0

## 鍔犺浇鎶拷鑳藉埌鎸囧畾妲戒綅
## @param slot: 婵″弶鍨濈紞鍛村触瀹ュ泦鐐烘晬?q", "e", "lmb", "rmb"闁?
## @param skill_id: 闁瑰灈鍋撻柤宕囩イD闁挎稑鐗嗛々?skill_dash", "skill_saw_path"闁?
# 函数：_load_skill_to_slot
func _load_skill_to_slot(slot: String, skill_id: String) -> bool:
	# 条件判断
	if skill_id.is_empty():
		if debug_mode:
			print("[SkillManager] slot %s has no skill configured" % slot.to_upper())
		return false
	
	# 构造技能脚本路径
	var skill_script_path = "res://scenes/skills/players/%s.gd" % skill_id
	
	# 字段定义
	var skill_script = load(skill_script_path)
	if not skill_script:
		push_error("[SkillManager] Error: failed to load skill script %s (file missing or bad path)" % skill_script_path)
		return false
	
	# 字段定义
	var skill: SkillBase = skill_script.new()
	if not skill:
		push_error("[SkillManager] Error: failed to create skill instance %s (script may not inherit SkillBase)" % skill_id)
		return false
	
	# 楠岃瘉鎶拷鑳藉疄渚嬫槸鍚︾户鎵胯嚜SkillBase
	if not skill is SkillBase:
		push_error("[SkillManager] Error: skill %s is not a SkillBase subtype" % skill_id)
		skill.free()
		return false
	

	skill.skill_owner = skill_owner
	skill.skill_id = skill_id
	skill.name = "%s_Skill" % slot.to_upper()
	

	_load_skill_params(skill, skill_id)
	
	# 节点管理
	add_child(skill)
	
	# 娣囨繂鐡ㄩ崚鐗埿担?
	skill_slots[slot] = skill
	
	print("[SkillManager] skill loaded %s -> %s (script=%s, class=%s, energy: %.0f, cooldown: %.1fs)" % [
		slot.to_upper(),
		skill_id,
		skill_script_path,
		skill.get_class(),
		skill.energy_cost,
		skill.cooldown_time
	])
	
	return true


## @param skill: 閹垛偓閼宠棄鐤勬笟?
## @param skill_id: 閹垛偓閼崇祤D
func _load_skill_params(skill: SkillBase, skill_id: String) -> void:
	# 字段定义
	var params = ConfigManager.get_skill_params(skill_id)
	
	if params.is_empty():
		if debug_mode:
			print("[SkillManager] Warning: missing skill params for %s, using defaults" % skill_id)
		return
	
	# 閻犱礁澧介悿鍡涙焻濮樿鲸鏆忛柛娆忓€归弳?
	if "energy_cost" in params:
		skill.energy_cost = params["energy_cost"]
	if "cooldown" in params:
		skill.cooldown_time = params["cooldown"]
	if "tags" in params:
		skill.set_skill_tags_from_value(params["tags"])
	else:
		skill.set_skill_tags_from_value(_infer_default_skill_tags(skill_id, params))
	
	for key in params.keys():
		if key in ["skill_id", "energy_cost", "cooldown", "tags"]:
			continue
		
		if key in skill:
			skill.set(key, params[key])
			if debug_mode:
				print("[SkillManager]   set param: %s = %s" % [key, params[key]])

func _infer_default_skill_tags(skill_id: String, params: Dictionary) -> String:
	var tags: Array[String] = []
	var desc_q_line := str(params.get("desc_q_line", "")).strip_edges()
	var desc_q_circle := str(params.get("desc_q_circle", "")).strip_edges()
	var desc_e := str(params.get("desc_e", "")).strip_edges()

	if not desc_q_line.is_empty() or not desc_q_circle.is_empty():
		tags.append_array(["q", "active", "drawing"])
		if skill_id.find("path") >= 0 or skill_id.find("loop") >= 0:
			tags.append("line")
		if not desc_q_circle.is_empty():
			tags.append("closed_shape")

	if not desc_e.is_empty():
		tags.append_array(["e", "active", "burst"])

	if tags.is_empty():
		if skill_id.ends_with("_q"):
			tags.append_array(["q", "active"])
		elif skill_id.ends_with("_e"):
			tags.append_array(["e", "active"])
		elif skill_id.begins_with("skill_"):
			tags.append("active")

	var normalized: Array[String] = []
	for tag in tags:
		var clean := tag.strip_edges().to_lower()
		if clean.is_empty() or normalized.has(clean):
			continue
		normalized.append(clean)

	return ",".join(normalized)

# ==============================================================================
# 閹垛偓閼宠姤澧界悰?
# ==============================================================================

## 閹笛嗩攽閹垛偓閼虫枻绱欓惉顒拷褰傞敍?
## @param slot: 婵″弶鍨濈紞鍛村触瀹ュ泦鐐烘晬?q", "e", "lmb", "rmb"闁?
func execute_skill(slot: String) -> void:
	var skill = skill_slots.get(slot)
	if not skill:
		print("[SkillManager] slot %s has no skill | loaded slots: %s" % [slot.to_upper(), str(skill_slots.keys().filter(func(k): return skill_slots[k] != null))])
		return
	
	if not is_instance_valid(skill):
		printerr("[SkillManager] Error: invalid skill instance in slot %s" % slot.to_upper())
		return
	
	# 条件判断
	if skill.is_on_cooldown:
		print("[SkillManager] skill cooling down: %s (%s), remaining: %.1fs" % [
			slot.to_upper(), skill.skill_id, skill.get_cooldown_remaining()
		])
		return
	
	var owner_energy = skill.skill_owner.energy if skill.skill_owner else -1.0
	if skill.energy_cost > 0 and owner_energy < skill.energy_cost:
		print("[SkillManager] not enough energy: %s (%s), need: %.0f, current: %.0f" % [
			slot.to_upper(), skill.skill_id, skill.energy_cost, owner_energy
		])
		return
	
	print("[SkillManager] execute skill %s (%s), energy: %.0f/%.0f, cost: %.0f" % [
		slot.to_upper(), skill.skill_id, owner_energy,
		skill.skill_owner.max_energy if skill.skill_owner else 0.0,
		skill.energy_cost
	])
	var switch_synergy_ctx: Dictionary = _begin_switch_synergy_bonus(skill, slot)
	# 条件判断
	if slot == "e":
		SoundManager.play("skill_e_instant")
	skill.execute()
	_end_switch_synergy_bonus(skill, slot, switch_synergy_ctx)


## @param slot: 婵″弶鍨濈紞鍛村触瀹ュ泦?
# 函数：charge_skill
func charge_skill(slot: String, delta: float) -> void:
	var skill = skill_slots.get(slot)
	if not skill or not is_instance_valid(skill):
		# 条件判断
		if not has_meta("_warned_no_skill_%s" % slot):
			set_meta("_warned_no_skill_%s" % slot, true)
			print("[SkillManager] charge_skill: slot %s has no skill | slot states: %s" % [
				slot.to_upper(),
				str(skill_slots.keys().map(func(k): return "%s=%s" % [k, skill_slots[k].skill_id if skill_slots[k] else "null"]))
			])
		return
	
	if not skill.is_charging:
		print("[SkillManager] start charging: %s (%s)" % [slot.to_upper(), skill.skill_id])
		skill.is_charging = true
	
	skill.charge(delta)


## @param slot: 婵″弶鍨濈紞鍛村触瀹ュ泦?
func release_skill(slot: String) -> void:
	var skill = skill_slots.get(slot)
	if not skill or not is_instance_valid(skill):
		print("[SkillManager] release_skill: slot %s has no skill" % slot.to_upper())
		return
	
	if skill.is_charging:
		print("[SkillManager] release skill %s (%s), path points: %d" % [
			slot.to_upper(), skill.skill_id,
			skill.path_points.size() if "path_points" in skill else -1
		])
		skill.is_charging = false
		var switch_synergy_ctx: Dictionary = _begin_switch_synergy_bonus(skill, slot)
		skill.release()
		_end_switch_synergy_bonus(skill, slot, switch_synergy_ctx)
	else:
		print("[SkillManager] release_skill skipped: %s (%s) is not charging" % [slot.to_upper(), skill.skill_id])

func _begin_switch_synergy_bonus(skill: SkillBase, slot: String) -> Dictionary:
	"""Apply one-shot switch synergy bonus before skill execution."""
	if not skill or not is_instance_valid(skill):
		return {}
	if Global == null or not Global.has_method("try_consume_switch_synergy"):
		return {}

	var bonus: Dictionary = Global.try_consume_switch_synergy(skill.skill_owner, slot)
	if bonus.is_empty():
		return {}

	var ctx: Dictionary = {
		"applied": true,
		"bonus": bonus,
		"had_cd_meta": false,
		"old_cd_reduction": 0.0
	}

	if skill.skill_owner:
		var owner = skill.skill_owner
		var old_cd: float = 0.0
		var had_cd: bool = owner.has_meta("buff_cooldown_reduction")
		if had_cd:
			old_cd = float(owner.get_meta("buff_cooldown_reduction"))

		var add_cd = float(bonus.get("cooldown_reduction", 0.0))
		owner.set_meta("buff_cooldown_reduction", clamp(old_cd + add_cd, 0.0, 0.85))

		ctx["had_cd_meta"] = had_cd
		ctx["old_cd_reduction"] = old_cd

	print("[SkillManager] [SwitchCombo] first-skill bonus applied: slot=%s skill=%s" % [slot.to_upper(), skill.skill_id])
	return ctx

func _end_switch_synergy_bonus(skill: SkillBase, slot: String, ctx: Dictionary) -> void:
	"""Restore temporary switch bonus and settle energy refund after execution."""
	if ctx.is_empty() or not bool(ctx.get("applied", false)):
		return
	if not skill or not is_instance_valid(skill):
		return

	if skill.skill_owner:
		var owner = skill.skill_owner
		var had_cd: bool = bool(ctx.get("had_cd_meta", false))
		var old_cd: float = float(ctx.get("old_cd_reduction", 0.0))
		if had_cd:
			owner.set_meta("buff_cooldown_reduction", old_cd)
		elif owner.has_meta("buff_cooldown_reduction"):
			owner.remove_meta("buff_cooldown_reduction")

		if skill.energy_cost > 0 and owner.has_method("gain_energy"):
			var bonus_data = ctx.get("bonus", {})
			var bonus: Dictionary = bonus_data if bonus_data is Dictionary else {}
			var refund_ratio: float = float(bonus.get("energy_refund_ratio", 0.0))
			var min_refund: float = float(bonus.get("min_refund", 0.0))
			var calculated_refund: float = skill.energy_cost * refund_ratio
			var refund: float = calculated_refund if calculated_refund > min_refund else min_refund
			if refund > 0:
				owner.gain_energy(refund)
				print("[SkillManager] [SwitchCombo] first-skill energy refund: slot=%s skill=%s refund=%.1f" % [
					slot.to_upper(), skill.skill_id, refund
				])

# ==============================================================================
# 闁瑰灈鍋撻柤瀹犲Г閻擄紕鎷?
# ==============================================================================


## @param slot: 婵″弶鍨濈紞鍛村触瀹ュ泦?
## @return: 鎶拷鑳藉疄渚嬫垨null
func get_skill(slot: String) -> SkillBase:
	return skill_slots.get(slot)


## @param slot: 婵″弶鍨濈紞鍛村触瀹ュ泦?
# 函数：has_skill
func has_skill(slot: String) -> bool:
	var skill = skill_slots.get(slot)
	return skill != null and is_instance_valid(skill)


## @return: 闁瑰灈鍋撻柤瀹犲Г閺嗙喓绱?
func get_all_skills() -> Array[SkillBase]:
	var skills: Array[SkillBase] = []
	for slot in skill_slots.keys():
		var skill = skill_slots[slot]
		if skill and is_instance_valid(skill):
			skills.append(skill)
	return skills

func force_cancel_planning_skills(refund_energy: bool = false) -> void:
	for skill in get_all_skills():
		if not is_instance_valid(skill):
			continue
		if skill.has_method("cancel_planning_state"):
			skill.call("cancel_planning_state", refund_energy)
			continue
		if "is_planning" in skill:
			skill.is_planning = false
		if "is_drawing" in skill:
			skill.is_drawing = false
		if "is_charging" in skill:
			skill.is_charging = false

func export_cooldown_state() -> Dictionary:
	var snapshot: Dictionary = {}
	for slot in skill_slots.keys():
		var skill = skill_slots[slot]
		if not skill or not is_instance_valid(skill):
			continue
		snapshot[slot] = {
			"skill_id": skill.skill_id,
			"is_on_cooldown": skill.is_on_cooldown,
			"remaining": skill.get_cooldown_remaining()
		}
	return snapshot

func import_cooldown_state(snapshot: Dictionary, elapsed_time: float = 0.0, bench_speed_multiplier: float = 1.0) -> void:
	if snapshot.is_empty():
		return

	var effective_elapsed: float = max(0.0, elapsed_time) * max(0.0, bench_speed_multiplier)
	for slot in snapshot.keys():
		var saved = snapshot.get(slot, {})
		if not (saved is Dictionary):
			continue

		var skill: SkillBase = skill_slots.get(slot)
		if not skill or not is_instance_valid(skill):
			continue

		var expected_skill_id := str(saved.get("skill_id", ""))
		if not expected_skill_id.is_empty() and expected_skill_id != skill.skill_id:
			continue

		var was_on_cd: bool = bool(saved.get("is_on_cooldown", false))
		if not was_on_cd:
			skill.reset_cooldown()
			continue

		var remaining: float = float(saved.get("remaining", 0.0)) - effective_elapsed
		skill.set_cooldown_remaining(remaining)

# ==============================================================================
# 閹垛偓閼崇晫顓搁悶?
# ==============================================================================

# 函数：cleanup
func cleanup() -> void:
	print("[SkillManager] ===== cleanup() called =====")
	print("[SkillManager] current slot states:")
	for slot in skill_slots.keys():
		var skill = skill_slots[slot]
		if skill and is_instance_valid(skill):
			print("  %s: %s (valid)" % [slot.to_upper(), skill.skill_id])
		else:
			print("  %s: (empty)" % slot.to_upper())
	
	for slot in skill_slots.keys():
		var skill = skill_slots[slot]
		if skill and is_instance_valid(skill):
			print("[SkillManager] cleaning skill %s (%s)" % [slot.to_upper(), skill.skill_id])
			if skill.has_method("cleanup"):
				skill.cleanup()
			skill.queue_free()
		skill_slots[slot] = null
	
	print("[SkillManager] ===== cleanup() done =====")



## @param player_id: 鐜╁ID
# 函数：reload_skills
func reload_skills(player_id: String) -> bool:
	cleanup()
	await get_tree().process_frame
	return load_skills_from_config(player_id)


## @return: 濡傛灉鑷冲皯鏈変竴涓妧鑳藉姞杞芥垚鍔熻繑鍥瀟rue
func is_loaded() -> bool:
	for slot in skill_slots.keys():
		if has_skill(slot):
			return true
	return false


## @return: 瀹告彃濮炴潪鐣屾畱閹垛偓閼宠姤鏆熼柌?
func get_loaded_skill_count() -> int:
	var count = 0
	for slot in skill_slots.keys():
		if has_skill(slot):
			count += 1
	return count

# ==============================================================================
# 閻犲鍟抽惁?
# ==============================================================================

# 函数：print_skills_info
func print_skills_info() -> void:
	print("[SkillManager] skill slot info:")
	for slot in ["q", "e", "lmb", "rmb"]:
		var skill = skill_slots[slot]
		if skill and is_instance_valid(skill):
			print("  %s: %s (energy: %.0f, cooldown: %.1fs, state: %s)" % [
				slot.to_upper(),
				skill.skill_id,
				skill.energy_cost,
				skill.cooldown_time,
				"Cooling" if skill.is_on_cooldown else "Ready"
			])
		else:
			print("  %s: (empty)" % slot.to_upper())
