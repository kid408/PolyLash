extends Node

# 所有角色场景路径列表
var character_paths = [
	"res://scenes/unit/players/player_herder.tscn",   # 0 - 牧羊人
	"res://scenes/unit/players/player_weaver.tscn",   # 1 - 织网者
	"res://scenes/unit/players/player_pyro.tscn",     # 2 - 纵火者
	"res://scenes/unit/players/player_wind.tscn",     # 3 - 御风者
	"res://scenes/unit/players/player_sapper.tscn",   # 4 - 工兵
	"res://scenes/unit/players/player_butcher.tscn",  # 5 - 屠夫
	"res://scenes/unit/players/player_tempest.tscn",  # 6 - 风暴使者
]

var current_character_index: int = 0

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		# Tab 键切换角色
		if event.keycode == KEY_TAB:
			_switch_to_next_character()
		# 数字键 1-6 切换武器
		elif event.keycode >= KEY_1 and event.keycode <= KEY_6:
			_switch_weapon(event.keycode - KEY_1)
	 # 检测是否按下了键盘上的 Escape 键
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		get_tree().quit()


func _switch_to_next_character() -> void:
	# 循环切换到下一个角色
	current_character_index = (current_character_index + 1) % character_paths.size()
	var path = character_paths[current_character_index]
	_switch_character(path)

func _switch_weapon(slot_index: int) -> void:
	var player = Global.player
	if not is_instance_valid(player):
		return
	
	# 检查玩家是否有 current_weapons 数组
	if not "current_weapons" in player:
		return
	
	var weapons = player.current_weapons
	if slot_index < weapons.size():
		# 切换到指定武器
		# 这里需要武器系统支持切换逻辑
		print(">>> [DEBUG] 切换到武器槽位: ", slot_index + 1)
		Global.spawn_floating_text(player.global_position, "Weapon %d" % (slot_index + 1), Color.CYAN)

func _switch_character(path: String) -> void:
	if not ResourceLoader.exists(path):
		printerr("DebugError: 找不到场景文件 -> ", path)
		return
		
	var old_player = Global.player
	if not is_instance_valid(old_player):
		printerr("DebugError: 当前没有存活的玩家，无法切换位置。")
		return

	# 1. 加载新场景
	var new_scene = load(path).instantiate()
	
	# 2. 继承旧玩家的位置
	new_scene.global_position = old_player.global_position
	
	# 3. 清理旧玩家的技能效果
	if old_player.has_method("_cleanup_skill_effects"):
		old_player._cleanup_skill_effects()
	
	# 4. 清理场景中所有残留的技能效果区域
	_cleanup_all_skill_areas()
	
	# 5. 添加到场景树 (加到旧玩家的父节点下)
	old_player.get_parent().add_child(new_scene)
	
	# 6. 销毁旧玩家
	old_player.queue_free()
	
	# 7. Global.player 会在 PlayerBase._ready() 里自动更新，这里不用管
	print(">>> [DEBUG] 切换角色为: ", new_scene.name)
	
	# 视觉提示
	Global.spawn_floating_text(new_scene.global_position, "MORPH!", Color.GOLD)

# 清理场景中所有技能效果区域（火线、风墙、火海、陷阱等）
func _cleanup_all_skill_areas() -> void:
	var scene_root = get_tree().current_scene
	if not scene_root:
		return
	
	# 查找所有 Area2D 节点（技能效果通常是 Area2D）
	var areas_to_remove: Array[Node] = []
	
	for child in scene_root.get_children():
		# 检查是否是技能效果节点（Area2D 且不是敌人或玩家）
		if child is Area2D:
			# 排除玩家和敌人的碰撞区域
			if not child.is_in_group("player") and not child.is_in_group("enemies"):
				# 检查是否有 Line2D 或 Polygon2D 子节点（技能效果的特征）
				for subchild in child.get_children():
					if subchild is Line2D or subchild is Polygon2D or subchild is CollisionShape2D or subchild is CollisionPolygon2D:
						areas_to_remove.append(child)
						break
	
	# 移除所有技能效果
	for area in areas_to_remove:
		if is_instance_valid(area):
			area.queue_free()
	
	if areas_to_remove.size() > 0:
		print(">>> [DEBUG] 清理了 %d 个残留技能效果" % areas_to_remove.size())
