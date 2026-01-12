extends CanvasLayer
class_name ChestIndicator

# ============================================================================
# 宝箱方向指示器 - 显示屏幕边缘的宝箱方向箭头
# ============================================================================

var indicator_nodes: Array[Control] = []
var chest_manager: ChestManager = null

# 指示器颜色映射
var tier_colors: Dictionary = {
	1: Color.WHITE,           # 木宝箱 - 白色
	2: Color.CYAN,            # 青铜宝箱 - 青色
	3: Color.YELLOW,          # 金宝箱 - 黄色
	4: Color(1.0, 0.0, 1.0)   # 钻石宝箱 - 紫色（彩虹色需要特殊处理）
}

# 从 map_config.csv 读取的指示器显示范围
var indicator_show_range: float = 3000.0

@onready var indicator_container: Control = $IndicatorContainer

func _ready() -> void:
	# 从 CSV 加载指示器显示范围
	indicator_show_range = ConfigManager.get_map_setting("indicator_show_range", 3000.0)
	print("[ChestIndicator] indicator_show_range = %d (from map_config.csv)" % int(indicator_show_range))
	
	# 创建3个指示器节点
	for i in range(3):
		var indicator = _create_indicator()
		indicator_container.add_child(indicator)
		indicator_nodes.append(indicator)
		indicator.visible = false

func _process(delta: float) -> void:
	if not is_instance_valid(Global.player) or not chest_manager:
		return
	
	var player_pos = Global.player.global_position
	var camera = get_viewport().get_camera_2d()
	
	# 获取所有宝箱（不限制数量，后面会过滤）
	var all_chests = chest_manager.get_nearby_chests(player_pos, 10)
	
	# 过滤：只显示 (距离 <= indicator_show_range) AND (不在屏幕内) 的宝箱
	var chests_to_show: Array[Dictionary] = []
	for chest_data in all_chests:
		var dist = chest_data["distance"]
		var chest_pos = chest_data["position"]
		
		# 条件1: 距离必须在显示范围内
		if dist > indicator_show_range:
			continue
		
		# 条件2: 宝箱必须不在屏幕内（off-screen）
		if _is_on_screen(chest_pos, camera):
			continue
		
		# 满足两个条件，添加到显示列表
		chests_to_show.append(chest_data)
		
		# 最多显示3个指示器
		if chests_to_show.size() >= 3:
			break
	
	# 更新指示器
	for i in range(indicator_nodes.size()):
		var indicator = indicator_nodes[i]
		
		if i < chests_to_show.size():
			var chest_data = chests_to_show[i]
			_update_indicator(indicator, chest_data, player_pos, delta)
			indicator.visible = true
		else:
			indicator.visible = false

# 检查世界坐标是否在屏幕可见范围内
func _is_on_screen(world_pos: Vector2, camera: Camera2D) -> bool:
	if not camera:
		return false
	
	# 获取屏幕尺寸
	var screen_size = get_viewport().get_visible_rect().size
	
	# 获取相机位置（世界坐标）
	var camera_pos = camera.global_position
	
	# 计算屏幕边界（世界坐标）
	# 考虑相机缩放
	var zoom = camera.zoom
	var half_screen = screen_size / 2.0 / zoom
	
	var screen_left = camera_pos.x - half_screen.x
	var screen_right = camera_pos.x + half_screen.x
	var screen_top = camera_pos.y - half_screen.y
	var screen_bottom = camera_pos.y + half_screen.y
	
	# 添加一点边距，避免箭头在边缘闪烁
	var margin = 50.0
	screen_left += margin
	screen_right -= margin
	screen_top += margin
	screen_bottom -= margin
	
	# 检查宝箱是否在屏幕范围内
	return world_pos.x >= screen_left and world_pos.x <= screen_right and \
		   world_pos.y >= screen_top and world_pos.y <= screen_bottom

func _create_indicator() -> Control:
	var container = Control.new()
	container.custom_minimum_size = Vector2(80, 80)
	
	# 箭头 (使用Polygon2D)
	var arrow = Polygon2D.new()
	arrow.polygon = PackedVector2Array([
		Vector2(0, -20),
		Vector2(15, 10),
		Vector2(0, 5),
		Vector2(-15, 10)
	])
	arrow.color = Color.WHITE
	arrow.position = Vector2(40, 40)
	container.add_child(arrow)
	
	# 距离文本
	var label = Label.new()
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.position = Vector2(0, 50)
	label.size = Vector2(80, 20)
	container.add_child(label)
	
	return container

func _update_indicator(indicator: Control, chest_data: Dictionary, player_pos: Vector2, delta: float) -> void:
	var chest_pos = chest_data["position"]
	var tier = chest_data["tier"]
	var distance = chest_data["distance"]
	
	# 获取摄像机
	var camera = get_viewport().get_camera_2d()
	if not camera:
		return
	
	# 计算方向
	var direction = (chest_pos - player_pos).normalized()
	
	# 获取屏幕尺寸
	var screen_size = get_viewport().get_visible_rect().size
	var screen_center = screen_size / 2
	
	# 计算箭头位置 (屏幕边缘)
	var edge_pos = screen_center + direction * (screen_size.length() / 2 - 100)
	
	# 限制在屏幕边缘
	edge_pos.x = clamp(edge_pos.x, 50, screen_size.x - 50)
	edge_pos.y = clamp(edge_pos.y, 50, screen_size.y - 50)
	
	indicator.position = edge_pos
	
	# 更新箭头旋转和颜色
	var arrow = indicator.get_child(0) as Polygon2D
	if arrow:
		arrow.rotation = direction.angle() + PI / 2
		
		# 钻石宝箱使用彩虹色动画
		if tier == 4:
			var hue = fmod(Time.get_ticks_msec() / 1000.0, 1.0)
			arrow.color = Color.from_hsv(hue, 0.8, 1.0)
		else:
			arrow.color = tier_colors.get(tier, Color.WHITE)
	
	# 更新距离文本
	var label = indicator.get_child(1) as Label
	if label:
		label.text = "%dm" % int(distance)
		
		# 钻石宝箱文本也使用彩虹色
		if tier == 4:
			var hue = fmod(Time.get_ticks_msec() / 1000.0, 1.0)
			label.modulate = Color.from_hsv(hue, 0.8, 1.0)
		else:
			label.modulate = tier_colors.get(tier, Color.WHITE)

func set_chest_manager(manager: ChestManager) -> void:
	chest_manager = manager
