extends Node

# 玩家配置数据加载器
# 从CSV文件加载所有玩家的通用配置数据

var player_configs: Dictionary = {}

func _ready() -> void:
	load_player_configs()

func load_player_configs() -> void:
	var file_path = "res://config/player_config.csv"
	var file = FileAccess.open(file_path, FileAccess.READ)
	
	if file == null:
		printerr("[PlayerConfigLoader] 无法打开配置文件: ", file_path)
		return
	
	# 读取表头
	var header_line = file.get_csv_line()
	if header_line.is_empty():
		printerr("[PlayerConfigLoader] CSV文件为空")
		return
	
	# 读取数据行
	while not file.eof_reached():
		var line = file.get_csv_line()
		if line.size() < 2 or line[0].is_empty():
			continue
		
		# 跳过注释行（第一列为 -1）
		if line[0].strip_edges() == "-1":
			print("[PlayerConfigLoader] 跳过注释行")
			continue
		
		var config = _parse_config_line(header_line, line)
		if config.has("player_id"):
			player_configs[config["player_id"]] = config
	
	file.close()
	print("[PlayerConfigLoader] 加载了 %d 个玩家配置" % player_configs.size())

func _parse_config_line(headers: PackedStringArray, values: PackedStringArray) -> Dictionary:
	var config = {}
	
	for i in range(min(headers.size(), values.size())):
		var key = headers[i].strip_edges()
		var value = values[i].strip_edges()
		
		# 类型转换
		if value.is_valid_float():
			config[key] = float(value)
		elif value.is_valid_int():
			config[key] = int(value)
		else:
			config[key] = value
	
	return config

func get_config(player_id: String) -> Dictionary:
	if player_configs.has(player_id):
		return player_configs[player_id]
	else:
		printerr("[PlayerConfigLoader] 未找到玩家配置: ", player_id)
		return {}

func get_value(player_id: String, key: String, default_value = null):
	var config = get_config(player_id)
	return config.get(key, default_value)
