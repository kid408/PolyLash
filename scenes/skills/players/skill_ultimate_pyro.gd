extends SkillUltimate
class_name SkillUltimatePyro

# ============================================================================
# 火焰法师大招 - Inferno Avatar (炼狱化身)
# ============================================================================
# 效果：
# - 获得 Destruction 羁绊标签
# - Q技能无冷却
# - 视觉：蓝色火焰光环，放大1.2倍
# ============================================================================

# Q技能引用
var q_skill: Node = null

# 原始冷却时间
var original_cooldown: float = 0.0

# ============================================================================
# 钩子实现
# ============================================================================

func _on_ultimate_activated() -> void:
	"""大招激活时"""
	print("[SkillUltimatePyro] Inferno Avatar 激活！")
	
	# 找到Q技能并移除冷却
	if player_ref:
		q_skill = _find_q_skill()
		if q_skill:
			# 保存原始冷却时间
			if "cooldown" in q_skill:
				original_cooldown = q_skill.cooldown
				q_skill.cooldown = 0.0
				print("[SkillUltimatePyro] Q技能冷却移除: %.1fs -> 0s" % original_cooldown)
			
			# 如果有当前冷却计时器，也清零
			if "current_cooldown" in q_skill:
				q_skill.current_cooldown = 0.0
	
	# 添加火焰光环效果
	_spawn_inferno_aura()

func _on_ultimate_deactivated() -> void:
	"""大招停用时"""
	print("[SkillUltimatePyro] Inferno Avatar 结束")
	
	# 恢复Q技能冷却
	if q_skill and "cooldown" in q_skill:
		q_skill.cooldown = original_cooldown
		print("[SkillUltimatePyro] Q技能冷却恢复: %.1fs" % original_cooldown)
	
	# 移除火焰光环
	_remove_inferno_aura()

func _on_ultimate_update(delta: float) -> void:
	"""大招激活期间每帧更新"""
	# 确保Q技能冷却始终为0
	if q_skill and "current_cooldown" in q_skill:
		q_skill.current_cooldown = 0.0

# ============================================================================
# 技能查找
# ============================================================================

func _find_q_skill() -> Node:
	"""查找Q技能节点
	
	Returns:
		Q技能节点，未找到返回null
	"""
	if not player_ref:
		return null
	
	# 尝试多种查找方式
	# 方式1: 直接查找名为 "SkillQ" 的子节点
	var skill_q = player_ref.get_node_or_null("SkillQ")
	if skill_q:
		return skill_q
	
	# 方式2: 查找 Skills 容器下的 Q 技能
	var skills_container = player_ref.get_node_or_null("Skills")
	if skills_container:
		skill_q = skills_container.get_node_or_null("SkillQ")
		if skill_q:
			return skill_q
	
	# 方式3: 遍历所有子节点查找
	for child in player_ref.get_children():
		if child.name.contains("SkillQ") or (child.has_method("get_skill_key") and child.get_skill_key() == "q"):
			return child
	
	printerr("[SkillUltimatePyro] 未找到Q技能节点")
	return null

# ============================================================================
# 视觉效果
# ============================================================================

func _spawn_inferno_aura() -> void:
	"""生成炼狱光环效果"""
	# TODO: 添加蓝色火焰粒子效果
	# 可以创建一个 CPUParticles2D 或 GPUParticles2D
	pass

func _remove_inferno_aura() -> void:
	"""移除炼狱光环效果"""
	# TODO: 移除粒子效果
	pass
