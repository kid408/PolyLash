extends Node
class_name SkillManager

## ==============================================================================
## 技能管理器 - 管理角色的所有技能
## ==============================================================================
## 
## 功能说明:
## - 管理四个技能槽位（Q/E/LMB/RMB）
## - 从CSV配置加载技能
## - 分发技能调用（execute/charge/release）
## - 处理技能生命周期
## 
## 使用方法:
##   var skill_manager = SkillManager.new(self)
##   add_child(skill_manager)
##   skill_manager.load_skills_from_config(player_id)
##   skill_manager.execute_skill("q")
## 
## ==============================================================================

# ==============================================================================
# 技能槽位
# ==============================================================================

## 技能槽位字典
## 键: "q", "e", "lmb", "rmb"
## 值: SkillBase实例或null
var skill_slots: Dictionary = {
	"q": null,
	"e": null,
	"lmb": null,
	"rmb": null
}

## 技能所有者（玩家或敌人）
var skill_owner: Node2D

## 调试模式
var debug_mode: bool = false

# ==============================================================================
# 初始化
# ==============================================================================

func _init(_owner: Node2D = null):
	if _owner:
		skill_owner = _owner

func _ready() -> void:
	if not skill_owner:
		push_error("[SkillManager] 错误: skill_owner未设置")

# ==============================================================================
# 技能加载
# ==============================================================================

## 从配置加载技能
## @param player_id: 玩家ID（如"butcher", "weaver"）
## @return: 如果加载成功返回true
func load_skills_from_config(player_id: String) -> bool:
	if player_id.is_empty():
		push_error("[SkillManager] 错误: player_id为空")
		return false
	
	if not skill_owner:
		push_error("[SkillManager] 错误: skill_owner未设置，无法加载技能")
		return false
	
	# 从ConfigManager获取技能绑定
	var bindings = ConfigManager.get_player_skill_bindings(player_id)
	if bindings.is_empty():
		push_warning("[SkillManager] 警告: 未找到技能绑定配置 for %s" % player_id)
		return false
	
	# 加载每个槽位的技能
	var success_count = 0
	var total_count = 0
	
	for slot in ["q", "e", "lmb", "rmb"]:
		var skill_id = bindings.get("slot_%s" % slot, "")
		if not skill_id.is_empty():
			total_count += 1
			if _load_skill_to_slot(slot, skill_id):
				success_count += 1
	
	return success_count > 0

## 加载技能到指定槽位
## @param slot: 槽位名称（"q", "e", "lmb", "rmb"）
## @param skill_id: 技能ID（如"skill_dash", "skill_saw_path"）
## @return: 如果加载成功返回true
func _load_skill_to_slot(slot: String, skill_id: String) -> bool:
	# 如果skill_id为空，跳过
	if skill_id.is_empty():
		if debug_mode:
			print("[SkillManager] 槽位 %s 未配置技能" % slot.to_upper())
		return false
	
	# 构建技能脚本路径
	var skill_script_path = "res://scenes/skills/players/%s.gd" % skill_id
	
	# 加载技能脚本
	var skill_script = load(skill_script_path)
	if not skill_script:
		push_error("[SkillManager] 错误: 无法加载技能脚本 %s (文件不存在或路径错误)" % skill_script_path)
		return false
	
	# 创建技能实例
	var skill: SkillBase = skill_script.new()
	if not skill:
		push_error("[SkillManager] 错误: 无法创建技能实例 %s (脚本可能不是SkillBase子类)" % skill_id)
		return false
	
	# 验证技能实例是否继承自SkillBase
	if not skill is SkillBase:
		push_error("[SkillManager] 错误: 技能 %s 不是SkillBase的子类" % skill_id)
		skill.free()
		return false
	
	# 设置技能基础属性
	skill.skill_owner = skill_owner
	skill.skill_id = skill_id
	skill.name = "%s_Skill" % slot.to_upper()
	
	# 从CSV加载技能参数
	_load_skill_params(skill, skill_id)
	
	# 添加到场景树
	add_child(skill)
	
	# 保存到槽位
	skill_slots[slot] = skill
	
	return true

## 从CSV加载技能参数
## @param skill: 技能实例
## @param skill_id: 技能ID
func _load_skill_params(skill: SkillBase, skill_id: String) -> void:
	# 从skill_params.csv加载技能参数
	var params = ConfigManager.get_skill_params(skill_id)
	
	if params.is_empty():
		if debug_mode:
			print("[SkillManager] 警告: 未找到技能参数配置 for %s，使用默认值" % skill_id)
		return
	
	# 设置通用参数
	if "energy_cost" in params:
		skill.energy_cost = params["energy_cost"]
	if "cooldown" in params:
		skill.cooldown_time = params["cooldown"]
	
	# 设置技能特定参数（通过反射）
	for key in params.keys():
		if key in ["skill_id", "energy_cost", "cooldown"]:
			continue  # 跳过已处理的通用参数
		
		if key in skill:
			skill.set(key, params[key])
			if debug_mode:
				print("[SkillManager]   设置参数: %s = %s" % [key, params[key]])

# ==============================================================================
# 技能执行
# ==============================================================================

## 执行技能（瞬发）
## @param slot: 槽位名称（"q", "e", "lmb", "rmb"）
func execute_skill(slot: String) -> void:
	var skill = skill_slots.get(slot)
	if not skill:
		if debug_mode:
			print("[SkillManager] 槽位 %s 没有技能" % slot.to_upper())
		return
	
	if not is_instance_valid(skill):
		printerr("[SkillManager] 错误: 槽位 %s 的技能实例无效" % slot.to_upper())
		return
	
	if skill.can_execute():
		if debug_mode:
			print("[SkillManager] 执行技能: %s (%s)" % [slot.to_upper(), skill.skill_id])
		skill.execute()
	else:
		if debug_mode:
			if skill.is_on_cooldown:
				print("[SkillManager] 技能冷却中: %s (剩余: %.1fs)" % [
					slot.to_upper(), 
					skill.get_cooldown_remaining()
				])
			else:
				print("[SkillManager] 能量不足: %s (需要: %.0f)" % [
					slot.to_upper(), 
					skill.energy_cost
				])

## 蓄力技能（持续按住）
## @param slot: 槽位名称
## @param delta: 帧时间增量
func charge_skill(slot: String, delta: float) -> void:
	var skill = skill_slots.get(slot)
	if not skill or not is_instance_valid(skill):
		return
	
	if not skill.is_charging:
		if debug_mode:
			print("[SkillManager] 开始蓄力: %s (%s)" % [slot.to_upper(), skill.skill_id])
		skill.is_charging = true
	
	skill.charge(delta)

## 释放技能（松开按键）
## @param slot: 槽位名称
func release_skill(slot: String) -> void:
	var skill = skill_slots.get(slot)
	if not skill or not is_instance_valid(skill):
		return
	
	if skill.is_charging:
		if debug_mode:
			print("[SkillManager] 释放技能: %s (%s)" % [slot.to_upper(), skill.skill_id])
		skill.is_charging = false
		skill.release()

# ==============================================================================
# 技能查询
# ==============================================================================

## 获取指定槽位的技能
## @param slot: 槽位名称
## @return: 技能实例或null
func get_skill(slot: String) -> SkillBase:
	return skill_slots.get(slot)

## 检查槽位是否有技能
## @param slot: 槽位名称
## @return: 如果有技能返回true
func has_skill(slot: String) -> bool:
	var skill = skill_slots.get(slot)
	return skill != null and is_instance_valid(skill)

## 获取所有技能
## @return: 技能数组
func get_all_skills() -> Array[SkillBase]:
	var skills: Array[SkillBase] = []
	for slot in skill_slots.keys():
		var skill = skill_slots[slot]
		if skill and is_instance_valid(skill):
			skills.append(skill)
	return skills

# ==============================================================================
# 技能管理
# ==============================================================================

## 清理所有技能
func cleanup() -> void:
	for slot in skill_slots.keys():
		var skill = skill_slots[slot]
		if skill and is_instance_valid(skill):
			skill.queue_free()
		skill_slots[slot] = null

## 重新加载技能（热加载）
## @param player_id: 玩家ID
## @return: 如果加载成功返回true
func reload_skills(player_id: String) -> bool:
	cleanup()
	await get_tree().process_frame  # 等待清理完成
	return load_skills_from_config(player_id)

## 检查所有技能是否加载成功
## @return: 如果至少有一个技能加载成功返回true
func is_loaded() -> bool:
	for slot in skill_slots.keys():
		if has_skill(slot):
			return true
	return false

## 获取已加载的技能数量
## @return: 已加载的技能数量
func get_loaded_skill_count() -> int:
	var count = 0
	for slot in skill_slots.keys():
		if has_skill(slot):
			count += 1
	return count

# ==============================================================================
# 调试
# ==============================================================================

## 打印所有技能信息
func print_skills_info() -> void:
	print("[SkillManager] 技能槽位信息:")
	for slot in ["q", "e", "lmb", "rmb"]:
		var skill = skill_slots[slot]
		if skill and is_instance_valid(skill):
			print("  %s: %s (能量: %.0f, 冷却: %.1fs, 状态: %s)" % [
				slot.to_upper(),
				skill.skill_id,
				skill.energy_cost,
				skill.cooldown_time,
				"冷却中" if skill.is_on_cooldown else "就绪"
			])
		else:
			print("  %s: (空)" % slot.to_upper())
