extends Node2D
class_name BackgroundManager

# ============================================================================
# 背景管理器 - 无限地图背景平铺
# ============================================================================

# 地图纹理
var map_texture: Texture2D = preload("res://assets/sprites/Map.png")

# 瓦片大小
var tile_size: float = 2000.0

# 已生成的瓦片
var active_tiles: Dictionary = {}

# 扩展阈值
var extend_threshold: float = 1000.0

@onready var camera: Camera2D = get_tree().get_first_node_in_group("camera")

func _ready() -> void:
	# 加载配置
	tile_size = ConfigManager.get_map_setting("map_tile_size", 2000.0)
	extend_threshold = ConfigManager.get_map_setting("background_extend_threshold", 1000.0)
	
	# 检查纹理
	if map_texture:
		var texture_size = map_texture.get_size()
		print("[BackgroundManager] 地图纹理大小: %v" % texture_size)
	else:
		printerr("[BackgroundManager] 错误: 无法加载地图纹理!")
	
	# 生成初始瓦片
	_generate_initial_tiles()
	
	print("[BackgroundManager] 初始化完成 - 瓦片大小: %d, 已生成: %d 个瓦片" % [tile_size, active_tiles.size()])

func _process(_delta: float) -> void:
	if not camera:
		return
	
	# 根据摄像机位置动态生成瓦片
	_update_tiles()

func _generate_initial_tiles() -> void:
	# 生成5x5的初始瓦片网格（更大的初始覆盖）
	for x in range(-2, 3):
		for y in range(-2, 3):
			_create_tile(x, y)

func _update_tiles() -> void:
	var camera_pos = camera.global_position
	
	# 计算摄像机所在的瓦片坐标
	var tile_x = int(floor(camera_pos.x / tile_size))
	var tile_y = int(floor(camera_pos.y / tile_size))
	
	# 检查周围更大范围的瓦片（5x5）
	for x in range(tile_x - 2, tile_x + 3):
		for y in range(tile_y - 2, tile_y + 3):
			var tile_key = Vector2i(x, y)
			if not active_tiles.has(tile_key):
				_create_tile(x, y)

func _create_tile(tile_x: int, tile_y: int) -> void:
	var tile_key = Vector2i(tile_x, tile_y)
	
	if active_tiles.has(tile_key):
		return
	
	# 创建Sprite2D
	var sprite = Sprite2D.new()
	sprite.texture = map_texture
	sprite.centered = true  # 居中对齐，避免缝隙
	
	# 瓦片位置：使用瓦片中心点
	var center_offset = tile_size / 2.0
	sprite.position = Vector2(
		tile_x * tile_size + center_offset,
		tile_y * tile_size + center_offset
	)
	
	# 获取纹理实际大小并计算缩放
	var texture_size = map_texture.get_size()
	sprite.scale = Vector2(tile_size / texture_size.x, tile_size / texture_size.y)
	sprite.z_index = -10  # 确保在最底层
	
	# 裁剪掉纹理边缘的黑边（增加裁剪量到20像素）
	# 使用 region 功能裁剪纹理
	sprite.region_enabled = true
	sprite.region_rect = Rect2(0, 0, texture_size.x , texture_size.y )
	
	add_child(sprite)
	active_tiles[tile_key] = sprite
	
	# print("[BackgroundManager] 创建瓦片 (%d, %d) at position (%f, %f)" % [tile_x, tile_y, sprite.position.x, sprite.position.y])

func get_tile_count() -> int:
	return active_tiles.size()
