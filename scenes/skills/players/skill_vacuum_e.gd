extends SkillBase
class_name SkillVacuumE

## ==============================================================================
## 吸尘器E技能 - 吸取掉落物
## ==============================================================================
## 
## 功能说明:
## - 按E键立即吸取范围内所有掉落物（金币等）到玩家位置
## 
## ==============================================================================

# ==============================================================================
# 技能参数（从CSV加载）
# ==============================================================================

## 吸取范围
var vacuum_radius: float = 300.0

# ==============================================================================
# 技能执行
# ==============================================================================

## 执行技能
func execute() -> void:
	if not consume_energy():
		if skill_owner:
			Global.spawn_floating_text(skill_owner.global_position, "No Energy!", Color.RED)
		return

	var collected_count: int = 0
	var owner_pos: Vector2 = skill_owner.global_position

	# 查找场景中所有 GoldCoin 实例
	var tree = get_tree()
	if tree and tree.current_scene:
		var coins = _find_coins_recursive(tree.current_scene)
		for coin in coins:
			if is_instance_valid(coin) and not coin.is_collected:
				var dist = owner_pos.distance_to(coin.global_position)
				if dist <= vacuum_radius:
					# 强制吸附到玩家位置
					coin.is_magnetized = true
					coin.global_position = owner_pos
					collected_count += 1

	if collected_count > 0:
		Global.on_camera_shake.emit(4.0, 0.1)
		Global.spawn_floating_text(owner_pos, "VACUUM x%d!" % collected_count, Color(0.4, 0.2, 0.6))
	else:
		Global.spawn_floating_text(owner_pos, "Nothing!", Color.GRAY)

	start_cooldown()

## 递归查找场景中所有 GoldCoin 节点
func _find_coins_recursive(node: Node) -> Array:
	var result: Array = []
	if node is GoldCoin:
		result.append(node)
	for child in node.get_children():
		result.append_array(_find_coins_recursive(child))
	return result
