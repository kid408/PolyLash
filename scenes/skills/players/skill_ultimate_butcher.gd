extends SkillUltimate
class_name SkillUltimateButcher

# ============================================================================
# 屠夫大招 - Blood Rage (血之狂怒)
# ============================================================================
# 效果：
# - 获得 Martial 羁绊标签
# - 大幅提升吸血效果（通过 UpgradeManager）
# - 视觉：红色光环，放大1.2倍
# ============================================================================

# 吸血加成值（百分比）
var lifesteal_bonus: float = 30.0  # 额外增加 30% 吸血

# ============================================================================
# 钩子实现
# ============================================================================

func _on_ultimate_activated() -> void:
	"""大招激活时"""
	print("[SkillUltimateButcher] Blood Rage 激活！")
	
	# 通过 UpgradeManager 添加吸血加成
	if UpgradeManager:
		UpgradeManager.add_attribute_bonus("lifesteal", lifesteal_bonus)
		var total_lifesteal = UpgradeManager.get_attribute_bonus("lifesteal")
		print("[SkillUltimateButcher] 吸血提升: +%.1f%% (总计: %.1f%%)" % [lifesteal_bonus, total_lifesteal])
	
	# 可以添加粒子效果、音效等
	_spawn_blood_aura()

func _on_ultimate_deactivated() -> void:
	"""大招停用时"""
	print("[SkillUltimateButcher] Blood Rage 结束")
	
	# 移除吸血加成
	if UpgradeManager:
		UpgradeManager.add_attribute_bonus("lifesteal", -lifesteal_bonus)
		var total_lifesteal = UpgradeManager.get_attribute_bonus("lifesteal")
		print("[SkillUltimateButcher] 吸血恢复: %.1f%%" % total_lifesteal)
	
	# 移除粒子效果
	_remove_blood_aura()

func _on_ultimate_update(delta: float) -> void:
	"""大招激活期间每帧更新"""
	# 可以添加持续的视觉效果更新
	pass

# ============================================================================
# 视觉效果
# ============================================================================

func _spawn_blood_aura() -> void:
	"""生成血之光环效果"""
	# TODO: 添加粒子效果
	# 可以创建一个 CPUParticles2D 或 GPUParticles2D
	pass

func _remove_blood_aura() -> void:
	"""移除血之光环效果"""
	# TODO: 移除粒子效果
	pass
