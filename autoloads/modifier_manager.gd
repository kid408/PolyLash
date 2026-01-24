extends Node

## ==============================================================================
## 修改器管理器 - 标签驱动的泛用性数值系统
## ==============================================================================
## 
## 功能说明:
## - 存储基于标签的修改器（支持加法和百分比）
## - 子集匹配：只要技能标签包含道具目标标签即生效
## - 加法叠加：Final = Base * (1.0 + Sum(PercentModifiers))
## 
## 使用方法:
##   modifier_manager.add_modifier(["fire"], "percent_add", 0.20)
##   var final_damage = modifier_manager.get_modified_value(20.0, ["damage", "fire", "aoe"])
##   # 结果: 20 * (1.0 + 0.20) = 24
## 
## ==============================================================================

# ==============================================================================
# 修改器存储结构
# ==============================================================================

## 修改器列表 [{target_tags: Array, type: String, value: float}]
var modifiers: Array = []

# ==============================================================================
# 公共 API
# ==============================================================================

## 添加修改器
## @param target_tags: 目标标签数组（如 ["fire"]）
## @param modifier_type: 修改器类型（"flat_add" 或 "percent_add"）
## @param value: 修改值（如 0.20 表示 +20%）
func add_modifier(target_tags: Array, modifier_type: String, value: float) -> void:
	if target_tags.is_empty():
		push_warning("[ModifierManager] 警告: target_tags 为空，跳过添加")
		return
	
	var modifier = {
		"target_tags": target_tags,
		"type": modifier_type,
		"value": value
	}
	
	modifiers.append(modifier)
	
	if OS.is_debug_build():
		print("[ModifierManager] 添加修改器: tags=%s, type=%s, value=%s" % [target_tags, modifier_type, value])

## 获取修改后的数值
## @param base_value: 基础数值
## @param skill_tags: 技能携带的标签数组（如 ["damage", "fire", "aoe"]）
## @return: 修改后的最终数值
func get_modified_value(base_value: float, skill_tags: Array) -> float:
	if skill_tags.is_empty():
		return base_value
	
	var flat_sum: float = 0.0
	var percent_sum: float = 0.0
	
	# 遍历所有修改器
	for modifier in modifiers:
		var target_tags: Array = modifier["target_tags"]
		var modifier_type: String = modifier["type"]
		var value: float = modifier["value"]
		
		# 子集匹配：检查技能标签是否包含所有目标标签
		if _is_subset_match(target_tags, skill_tags):
			match modifier_type:
				"flat_add":
					flat_sum += value
				"percent_add":
					percent_sum += value
	
	# 计算最终值：(Base + FlatSum) * (1.0 + PercentSum)
	var final_value = (base_value + flat_sum) * (1.0 + percent_sum)
	
	if OS.is_debug_build() and (flat_sum != 0.0 or percent_sum != 0.0):
		print("[ModifierManager] 数值计算: base=%.2f, flat=+%.2f, percent=+%.2f%%, final=%.2f" % [
			base_value, flat_sum, percent_sum * 100, final_value
		])
	
	return final_value

## 清空所有修改器
func clear_modifiers() -> void:
	modifiers.clear()
	if OS.is_debug_build():
		print("[ModifierManager] 已清空所有修改器")

## 获取当前修改器数量
func get_modifier_count() -> int:
	return modifiers.size()

# ==============================================================================
# 内部辅助函数
# ==============================================================================

## 子集匹配：检查 target_tags 是否是 skill_tags 的子集
## @param target_tags: 道具指定的目标标签（如 ["fire"]）
## @param skill_tags: 技能拥有的标签（如 ["damage", "fire", "aoe"]）
## @return: 如果所有 target_tags 都在 skill_tags 中，返回 true
func _is_subset_match(target_tags: Array, skill_tags: Array) -> bool:
	for target_tag in target_tags:
		if not skill_tags.has(target_tag):
			return false
	return true

# ==============================================================================
# 调试工具
# ==============================================================================

## 打印所有修改器（调试用）
func print_all_modifiers() -> void:
	print("[ModifierManager] ========== 当前修改器列表 ==========")
	if modifiers.is_empty():
		print("[ModifierManager] （无修改器）")
		return
	
	for i in range(modifiers.size()):
		var mod = modifiers[i]
		print("[ModifierManager] [%d] tags=%s, type=%s, value=%s" % [
			i, mod["target_tags"], mod["type"], mod["value"]
		])
	print("[ModifierManager] ==========================================")
