extends Node

## ==============================================================================
## 战斗状态管理器 - 负责保存和恢复完整的战斗状态
## ==============================================================================
## 
## 功能：
## - 保存玩家状态（位置、血量、能量等）
## - 保存敌人状态（位置、血量、类型等）
## - 保存关卡进度（波次、时间等）
## - 保存场景中的物品、宝箱等
## - 恢复完整的战斗场景
##
## ==============================================================================

signal battle_state_saved
signal battle_state_loaded

## 保存完整的战斗状态
func save_battle_state() -> Dictionary:
	"""保存完整的战斗状态，包括玩家、敌人、物品等"""
	print("[BattleStateManager] 开始保存战斗状态...")
	
	var state = {
		"timestamp": int(Time.get_unix_time_from_system()),
		"player_state": _save_player_state(),
		"enemies_state": _save_enemies_state(),
		"items_state": _save_items_state(),
		"chests_state": _save_chests_state(),
		"projectiles_state": _save_projectiles_state(),
		"wave_state": _save_wave_state(),
	}
	
	print("[BattleStateManager] 战斗状态保存完成")
	battle_state_saved.emit()
	return state

## 恢复完整的战斗状态
func restore_battle_state(state: Dictionary) -> void:
	"""从保存的状态恢复战斗场景"""
	if state.is_empty():
		print("[BattleStateManager] 没有战斗状态需要恢复")
		return
	
	print("[BattleStateManager] 开始恢复战斗状态...")
	
	# 恢复玩家状态
	if state.has("player_state"):
		_restore_player_state(state["player_state"])
	
	# 恢复敌人状态
	if state.has("enemies_state"):
		_restore_enemies_state(state["enemies_state"])
	
	# 恢复物品状态
	if state.has("items_state"):
		_restore_items_state(state["items_state"])
	
	# 恢复宝箱状态
	if state.has("chests_state"):
		_restore_chests_state(state["chests_state"])
	
	# 恢复波次状态
	if state.has("wave_state"):
		_restore_wave_state(state["wave_state"])
	
	print("[BattleStateManager] 战斗状态恢复完成")
	battle_state_loaded.emit()

## ==============================================================================
## 玩家状态保存/恢复
## ==============================================================================

func _save_player_state() -> Dictionary:
	"""保存玩家状态"""
	if not is_instance_valid(Global.player):
		return {}
	
	var player = Global.player
	var state = {
		"player_id": player.player_id if "player_id" in player else "",
		"position": {
			"x": player.global_position.x,
			"y": player.global_position.y
		},
		"health": player.health_component.current_health if player.health_component else 100,
		"max_health": player.health_component.max_health if player.health_component else 100,
		"energy": player.energy if "energy" in player else 100,
		"max_energy": player.max_energy if "max_energy" in player else 100,
		"armor": player.armor if "armor" in player else 0,
		"level": player.level if "level" in player else 1,
	}
	
	print("[BattleStateManager] 玩家状态已保存: %s" % player.player_id)
	return state

func _restore_player_state(state: Dictionary) -> void:
	"""恢复玩家状态"""
	if not is_instance_valid(Global.player):
		return
	
	var player = Global.player
	
	# 恢复位置
	if state.has("position"):
		player.global_position = Vector2(state["position"]["x"], state["position"]["y"])
	
	# 恢复血量
	if player.health_component and state.has("health"):
		player.health_component.current_health = state["health"]
		player.health_component.max_health = state.get("max_health", 100)
	
	# 恢复能量
	if "energy" in player and state.has("energy"):
		player.energy = state["energy"]
	if "max_energy" in player and state.has("max_energy"):
		player.max_energy = state["max_energy"]
	
	# 恢复护甲
	if "armor" in player and state.has("armor"):
		player.armor = state["armor"]
	
	print("[BattleStateManager] 玩家状态已恢复")

## ==============================================================================
## 敌人状态保存/恢复
## ==============================================================================

func _save_enemies_state() -> Array:
	"""保存所有敌人的状态"""
	var enemies_data = []
	var enemies = get_tree().get_nodes_in_group("enemies")
	
	for enemy in enemies:
		if not is_instance_valid(enemy):
			continue
		
		var enemy_data = {
			"type": enemy.get_class() if enemy.has_method("get_class") else "Enemy",
			"scene_path": enemy.scene_file_path if enemy.scene_file_path else "",
			"position": {
				"x": enemy.global_position.x,
				"y": enemy.global_position.y
			},
			"health": enemy.health_component.current_health if enemy.health_component else 100,
			"max_health": enemy.health_component.max_health if enemy.health_component else 100,
		}
		
		enemies_data.append(enemy_data)
	
	print("[BattleStateManager] 已保存 %d 个敌人状态" % enemies_data.size())
	return enemies_data

func _restore_enemies_state(enemies_data: Array) -> void:
	"""恢复所有敌人的状态"""
	# 先清除现有敌人
	var existing_enemies = get_tree().get_nodes_in_group("enemies")
	for enemy in existing_enemies:
		if is_instance_valid(enemy):
			enemy.queue_free()
	
	# 等待一帧确保清除完成
	await get_tree().process_frame
	
	# 获取 arena 节点
	var arena = get_tree().get_first_node_in_group("arena")
	if not arena:
		printerr("[BattleStateManager] 找不到 arena 节点，无法恢复敌人")
		return
	
	# 重新生成敌人
	for enemy_data in enemies_data:
		var scene_path = enemy_data.get("scene_path", "")
		if scene_path == "" or not ResourceLoader.exists(scene_path):
			continue
		
		var enemy_scene = load(scene_path)
		if not enemy_scene:
			continue
		
		var enemy = enemy_scene.instantiate()
		arena.add_child(enemy)
		
		# 恢复位置
		if enemy_data.has("position"):
			enemy.global_position = Vector2(enemy_data["position"]["x"], enemy_data["position"]["y"])
		
		# 恢复血量
		if enemy.health_component and enemy_data.has("health"):
			enemy.health_component.current_health = enemy_data["health"]
			enemy.health_component.max_health = enemy_data.get("max_health", 100)
	
	print("[BattleStateManager] 已恢复 %d 个敌人" % enemies_data.size())

## ==============================================================================
## 物品状态保存/恢复
## ==============================================================================

func _save_items_state() -> Array:
	"""保存场景中的物品状态"""
	var items_data = []
	var items = get_tree().get_nodes_in_group("items")
	
	for item in items:
		if not is_instance_valid(item):
			continue
		
		var item_data = {
			"scene_path": item.scene_file_path if item.scene_file_path else "",
			"position": {
				"x": item.global_position.x,
				"y": item.global_position.y
			},
		}
		
		items_data.append(item_data)
	
	print("[BattleStateManager] 已保存 %d 个物品状态" % items_data.size())
	return items_data

func _restore_items_state(items_data: Array) -> void:
	"""恢复场景中的物品"""
	# 清除现有物品
	var existing_items = get_tree().get_nodes_in_group("items")
	for item in existing_items:
		if is_instance_valid(item):
			item.queue_free()
	
	await get_tree().process_frame
	
	var arena = get_tree().get_first_node_in_group("arena")
	if not arena:
		printerr("[BattleStateManager] 找不到 arena 节点，无法恢复物品")
		return
	
	# 重新生成物品
	for item_data in items_data:
		var scene_path = item_data.get("scene_path", "")
		if scene_path == "" or not ResourceLoader.exists(scene_path):
			continue
		
		var item_scene = load(scene_path)
		if not item_scene:
			continue
		
		var item = item_scene.instantiate()
		arena.add_child(item)
		
		if item_data.has("position"):
			item.global_position = Vector2(item_data["position"]["x"], item_data["position"]["y"])
	
	print("[BattleStateManager] 已恢复 %d 个物品" % items_data.size())

## ==============================================================================
## 宝箱状态保存/恢复
## ==============================================================================

func _save_chests_state() -> Array:
	"""保存宝箱状态"""
	var chests_data = []
	var chests = get_tree().get_nodes_in_group("chests")
	
	for chest in chests:
		if not is_instance_valid(chest):
			continue
		
		var chest_data = {
			"scene_path": chest.scene_file_path if chest.scene_file_path else "",
			"position": {
				"x": chest.global_position.x,
				"y": chest.global_position.y
			},
			"is_opened": chest.is_opened if "is_opened" in chest else false,
		}
		
		chests_data.append(chest_data)
	
	print("[BattleStateManager] 已保存 %d 个宝箱状态" % chests_data.size())
	return chests_data

func _restore_chests_state(chests_data: Array) -> void:
	"""恢复宝箱状态"""
	# 清除现有宝箱
	var existing_chests = get_tree().get_nodes_in_group("chests")
	for chest in existing_chests:
		if is_instance_valid(chest):
			chest.queue_free()
	
	await get_tree().process_frame
	
	var arena = get_tree().get_first_node_in_group("arena")
	if not arena:
		printerr("[BattleStateManager] 找不到 arena 节点，无法恢复宝箱")
		return
	
	# 重新生成宝箱
	for chest_data in chests_data:
		var scene_path = chest_data.get("scene_path", "")
		if scene_path == "" or not ResourceLoader.exists(scene_path):
			continue
		
		var chest_scene = load(scene_path)
		if not chest_scene:
			continue
		
		var chest = chest_scene.instantiate()
		arena.add_child(chest)
		
		if chest_data.has("position"):
			chest.global_position = Vector2(chest_data["position"]["x"], chest_data["position"]["y"])
		
		if "is_opened" in chest and chest_data.has("is_opened"):
			chest.is_opened = chest_data["is_opened"]
	
	print("[BattleStateManager] 已恢复 %d 个宝箱" % chests_data.size())

## ==============================================================================
## 投射物状态保存（可选）
## ==============================================================================

func _save_projectiles_state() -> Array:
	"""保存投射物状态（可选，通常不需要保存）"""
	# 投射物通常不需要保存，因为它们会很快消失
	# 如果需要保存，可以在这里实现
	return []

## ==============================================================================
## 波次状态保存/恢复
## ==============================================================================

func _save_wave_state() -> Dictionary:
	"""保存波次状态"""
	var arena = get_tree().get_first_node_in_group("arena")
	if not arena or not arena.spawner:
		return {}
	
	var spawner = arena.spawner
	var state = {
		"wave_index": spawner.wave_index if "wave_index" in spawner else 1,
		"is_spawning": spawner.is_spawning if "is_spawning" in spawner else false,
		"spawn_timer_remaining": spawner.spawn_timer.time_left if spawner.spawn_timer else 0.0,
		"wave_timer_remaining": spawner.wave_timer.time_left if spawner.wave_timer else 0.0,
	}
	
	print("[BattleStateManager] 波次状态已保存: 第 %d 波, 剩余时间: %.1f 秒" % [state["wave_index"], state["wave_timer_remaining"]])
	return state

func _restore_wave_state(state: Dictionary) -> void:
	"""恢复波次状态"""
	var arena = get_tree().get_first_node_in_group("arena")
	if not arena or not arena.spawner:
		printerr("[BattleStateManager] 找不到 arena 或 spawner，无法恢复波次状态")
		return
	
	var spawner = arena.spawner
	
	# 恢复波次索引
	if state.has("wave_index"):
		spawner.wave_index = state["wave_index"]
		print("[BattleStateManager] 恢复波次索引: %d" % spawner.wave_index)
	
	# 重新开始当前波次（加载波次配置并启动计时器）
	if spawner.has_method("start_wave"):
		spawner.start_wave()
		print("[BattleStateManager] 重新开始第 %d 波" % spawner.wave_index)
	
	# 恢复波次计时器的剩余时间
	if state.has("wave_timer_remaining") and spawner.wave_timer:
		var remaining_time = state["wave_timer_remaining"]
		if remaining_time > 0:
			# 停止计时器
			spawner.wave_timer.stop()
			# 设置新的等待时间为剩余时间
			spawner.wave_timer.wait_time = remaining_time
			# 重新启动计时器
			spawner.wave_timer.start()
			print("[BattleStateManager] 恢复波次计时器: %.1f 秒" % remaining_time)
	
	# 恢复生成计时器的剩余时间
	if state.has("spawn_timer_remaining") and spawner.spawn_timer:
		var remaining_time = state["spawn_timer_remaining"]
		if remaining_time > 0:
			spawner.spawn_timer.stop()
			spawner.spawn_timer.wait_time = remaining_time
			spawner.spawn_timer.start()
	
	# 恢复生成状态
	if state.has("is_spawning"):
		if state["is_spawning"]:
			if spawner.has_method("resume_spawning"):
				spawner.resume_spawning()
		else:
			if spawner.has_method("pause_spawning"):
				spawner.pause_spawning()
	
	print("[BattleStateManager] 波次状态已恢复: 第 %d 波" % spawner.wave_index)
