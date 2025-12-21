extends Node

# 配置你的角色场景路径 (确保路径正确！)
var character_paths = {
	KEY_1: "res://scenes/unit/players/player_herder.tscn", # 牧羊人
	KEY_2: "res://scenes/unit/players/player_weaver.tscn", # 织网者
	KEY_3: "res://scenes/unit/players/player_butcher.tscn", # 屠夫
	KEY_4: "res://scenes/unit/players/player_tempest.tscn", # 风暴使者
	KEY_5: "res://scenes/unit/players/player_sapper.tscn"  # 工兵
}

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if character_paths.has(event.keycode):
			_switch_character(character_paths[event.keycode])

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
	
	# 3. 添加到场景树 (加到旧玩家的父节点下)
	old_player.get_parent().add_child(new_scene)
	
	# 4. 销毁旧玩家
	old_player.queue_free()
	
	# 5. Global.player 会在 PlayerBase._ready() 里自动更新，这里不用管
	print(">>> [DEBUG] 切换角色为: ", new_scene.name)
	
	# 视觉提示
	Global.spawn_floating_text(new_scene.global_position, "MORPH!", Color.GOLD)
