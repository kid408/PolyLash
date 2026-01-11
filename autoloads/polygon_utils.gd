extends Node
class_name PolygonUtils

## ==============================================================================
## 多边形工具类 - 公共的划线闭合检测和遮罩显示逻辑
## ==============================================================================
## 
## 功能说明:
## - 检测路径中的所有闭合多边形（支持8字形等多区域）
## - 同步显示多个遮罩（同时淡入、同时淡出）
## - 多边形验证和简化
## 
## 使用方法:
##   var polygons = PolygonUtils.find_all_closing_polygons(path_points, close_threshold)
##   PolygonUtils.show_closure_masks(polygons, mask_color, scene_tree)
## 
## ==============================================================================

# ==============================================================================
# 多边形检测
# ==============================================================================

## 查找路径中所有闭合多边形（支持8字形等多区域）
static func find_all_closing_polygons(points: Array[Vector2], close_threshold: float = 60.0) -> Array[PackedVector2Array]:
	var result: Array[PackedVector2Array] = []
	
	if points.size() < 3:
		return result
	
	var last_point = points[points.size() - 1]
	
	# 1. 收集所有交叉点
	var all_intersections: Array[Dictionary] = []
	for j in range(points.size() - 1, 2, -1):
		for i in range(j - 2):
			var seg1_start = points[i]
			var seg1_end = points[i + 1]
			var seg2_start = points[j - 1]
			var seg2_end = points[j]
			
			var intersection = Geometry2D.segment_intersects_segment(
				seg1_start, seg1_end, seg2_start, seg2_end
			)
			
			if intersection:
				all_intersections.append({
					"i": i,
					"j": j,
					"point": intersection
				})
	
	# 2. 检查距离闭合（用户画的完整形状）
	var distance_to_start = last_point.distance_to(points[0])
	if distance_to_start < close_threshold and all_intersections.size() == 0:
		var poly = PackedVector2Array()
		for p in points:
			poly.append(p)
		if _validate_polygon(poly):
			result.append(poly)
		return result
	
	# 3. 如果有交叉点，提取闭合区域
	if all_intersections.size() > 0:
		result = _extract_regions_from_intersections(points, all_intersections)
	
	return result

## 从交叉点提取闭合区域（完整版，支持8字形）
static func _extract_regions_from_intersections(points: Array[Vector2], intersections: Array[Dictionary]) -> Array[PackedVector2Array]:
	var result: Array[PackedVector2Array] = []
	
	if intersections.size() < 1:
		return result
	
	# 按i索引排序交叉点
	var sorted_intersections = intersections.duplicate()
	sorted_intersections.sort_custom(func(a, b): return a["i"] < b["i"])
	
	print("[PolygonUtils] 交叉点数量: %d" % intersections.size())
	print("[PolygonUtils] 排序后: %s" % str(sorted_intersections.map(func(x): return "[%d,%d]" % [x["i"], x["j"]])))
	
	if intersections.size() == 1:
		# 单交叉点：简单闭合
		var intersection = intersections[0]
		var idx_i = intersection["i"]
		var idx_j = intersection["j"]
		var intersection_point = intersection["point"]
		
		var poly = PackedVector2Array()
		poly.append(intersection_point)
		for k in range(idx_i + 1, idx_j):
			if k < points.size():
				poly.append(points[k])
		
		if _validate_polygon(poly):
			result.append(poly)
			print("[PolygonUtils] 单交叉点区域: 点数=%d" % poly.size())
	
	elif intersections.size() == 2:
		# 8字形检测
		var int1 = sorted_intersections[0]
		var int2 = sorted_intersections[1]
		
		var i1 = int1["i"]
		var j1 = int1["j"]
		var point1 = int1["point"]
		
		var i2 = int2["i"]
		var j2 = int2["j"]
		var point2 = int2["point"]
		
		print("[PolygonUtils] 8字形检测: i1=%d, j1=%d, i2=%d, j2=%d" % [i1, j1, i2, j2])
		
		# 检查是否是8字形结构: i1 < i2 < j2 < j1
		if i1 < i2 and i2 < j2 and j2 < j1:
			print("[PolygonUtils] ✅ 确认为8字形结构")
			
			# 区域1（上圈）: point1 -> path[i1+1...i2-1] -> point2 -> path[j2+1...j1-1] -> point1
			var poly1 = PackedVector2Array()
			poly1.append(point1)
			for k in range(i1 + 1, i2):
				if k < points.size():
					poly1.append(points[k])
			poly1.append(point2)
			for k in range(j2 + 1, j1):
				if k < points.size():
					poly1.append(points[k])
			
			if _validate_polygon(poly1):
				result.append(poly1)
				print("[PolygonUtils] ✓ 区域1: 点数=%d, 面积=%.1f" % [poly1.size(), _calculate_polygon_area(poly1)])
			
			# 区域2（下圈）: point2 -> path[i2+1...j2-1] -> point2
			var poly2 = PackedVector2Array()
			poly2.append(point2)
			for k in range(i2 + 1, j2):
				if k < points.size():
					poly2.append(points[k])
			
			if _validate_polygon(poly2):
				result.append(poly2)
				print("[PolygonUtils] ✓ 区域2: 点数=%d, 面积=%.1f" % [poly2.size(), _calculate_polygon_area(poly2)])
		else:
			# 非标准8字形，为每个交叉点单独创建区域
			print("[PolygonUtils] ⚠️ 非标准8字形，单独处理每个交叉点")
			for intersection in intersections:
				var idx_i = intersection["i"]
				var idx_j = intersection["j"]
				var intersection_point = intersection["point"]
				
				var poly = PackedVector2Array()
				poly.append(intersection_point)
				for k in range(idx_i + 1, idx_j):
					if k < points.size():
						poly.append(points[k])
				
				if _validate_polygon(poly):
					# 检查是否与已有区域重叠
					var dominated = false
					for existing in result:
						var existing_area = abs(_calculate_polygon_area(existing))
						var new_area = abs(_calculate_polygon_area(poly))
						if new_area > existing_area * 0.9 and new_area < existing_area * 1.1:
							dominated = true
							break
					if not dominated:
						result.append(poly)
	else:
		# 多于2个交叉点
		print("[PolygonUtils] 多交叉点(%d个)" % intersections.size())
		for i in range(sorted_intersections.size()):
			var current = sorted_intersections[i]
			var idx_i = current["i"]
			var idx_j = current["j"]
			var point_current = current["point"]
			
			var poly = PackedVector2Array()
			poly.append(point_current)
			
			# 查找下一个交叉点
			var next_intersection: Dictionary = {}
			if i + 1 < sorted_intersections.size():
				var candidate = sorted_intersections[i + 1]
				if candidate["i"] > idx_i and candidate["j"] < idx_j:
					next_intersection = candidate
			
			if not next_intersection.is_empty():
				var next_i = next_intersection["i"]
				var next_j = next_intersection["j"]
				var point_next = next_intersection["point"]
				
				for k in range(idx_i + 1, next_i):
					if k < points.size():
						poly.append(points[k])
				poly.append(point_next)
				for k in range(next_j + 1, idx_j):
					if k < points.size():
						poly.append(points[k])
			else:
				for k in range(idx_i + 1, idx_j):
					if k < points.size():
						poly.append(points[k])
			
			if _validate_polygon(poly):
				result.append(poly)
	
	print("[PolygonUtils] 提取完成，共 %d 个区域" % result.size())
	return result

# ==============================================================================
# 多边形验证和处理
# ==============================================================================

## 验证多边形是否有效
static func _validate_polygon(points: PackedVector2Array) -> bool:
	if points.size() < 3:
		return false
	
	var area = abs(_calculate_polygon_area(points))
	return area > 100.0

## 计算多边形面积
static func _calculate_polygon_area(poly: PackedVector2Array) -> float:
	if poly.size() < 3:
		return 0.0
	
	var area = 0.0
	var n = poly.size()
	
	for i in range(n):
		var j = (i + 1) % n
		area += (poly[i].x * poly[j].y) - (poly[j].x * poly[i].y)
	
	return abs(area) / 2.0

## 确保多边形点为逆时针方向
static func ensure_ccw_winding(points: PackedVector2Array) -> PackedVector2Array:
	if points.size() < 3:
		return points
	
	# 移除首尾重复点
	var working_points = PackedVector2Array()
	for p in points:
		working_points.append(p)
	
	if working_points.size() > 1:
		var first = working_points[0]
		var last = working_points[working_points.size() - 1]
		if first.distance_to(last) < 5.0:
			var temp = PackedVector2Array()
			for i in range(working_points.size() - 1):
				temp.append(working_points[i])
			working_points = temp
	
	if working_points.size() < 3:
		return points
	
	# 计算有符号面积
	var signed_area = 0.0
	var n = working_points.size()
	for i in range(n):
		var j = (i + 1) % n
		signed_area += (working_points[j].x - working_points[i].x) * (working_points[j].y + working_points[i].y)
	
	# 如果面积为正，说明是顺时针，需要反转
	if signed_area > 0:
		var reversed_points = PackedVector2Array()
		for i in range(working_points.size() - 1, -1, -1):
			reversed_points.append(working_points[i])
		return reversed_points
	
	return working_points

## 简化多边形
static func simplify_polygon(points: PackedVector2Array, min_distance: float = 3.0) -> PackedVector2Array:
	if points.size() < 4:
		return points
	
	var simplified = PackedVector2Array()
	simplified.append(points[0])
	
	for i in range(1, points.size()):
		var last_point = simplified[simplified.size() - 1]
		if points[i].distance_to(last_point) >= min_distance:
			simplified.append(points[i])
	
	# 确保最后一个点不与第一个点重复
	if simplified.size() > 1:
		var first = simplified[0]
		var last = simplified[simplified.size() - 1]
		if first.distance_to(last) < min_distance:
			var temp = PackedVector2Array()
			for i in range(simplified.size() - 1):
				temp.append(simplified[i])
			simplified = temp
	
	return simplified


# ==============================================================================
# 遮罩显示
# ==============================================================================

## 显示多个闭合遮罩（同步动画）
static func show_closure_masks(
	polygons: Array[PackedVector2Array],
	base_color: Color,
	scene_tree: SceneTree,
	display_duration: float = 0.6
) -> void:
	if polygons.is_empty() or scene_tree == null:
		return
	
	var mask_nodes: Array[Dictionary] = []
	
	# 创建所有遮罩节点
	for i in range(polygons.size()):
		var points = polygons[i]
		var processed_points = ensure_ccw_winding(points)
		processed_points = simplify_polygon(processed_points)
		
		if processed_points.size() < 3:
			continue
		
		var poly_node = Polygon2D.new()
		poly_node.polygon = processed_points
		
		# 为不同遮罩分配不同颜色
		var mask_color = base_color
		if i > 0:
			match i:
				1: mask_color = Color(0.0, 0.8, 1.0, base_color.a)  # 蓝色
				2: mask_color = Color(1.0, 0.8, 0.0, base_color.a)  # 黄色
				3: mask_color = Color(0.8, 0.0, 1.0, base_color.a)  # 紫色
				_: mask_color = Color(0.0, 1.0, 0.4, base_color.a)  # 绿色
		
		poly_node.color = Color(mask_color.r, mask_color.g, mask_color.b, 0.0)
		poly_node.z_index = 1000 + i * 50
		poly_node.top_level = true
		poly_node.name = "ClosureMask_%d" % i
		
		scene_tree.current_scene.add_child(poly_node)
		
		mask_nodes.append({
			"node": poly_node,
			"design_color": mask_color
		})
	
	if mask_nodes.is_empty():
		return
	
	# 同步动画
	_animate_masks_sync(mask_nodes, scene_tree, display_duration)

## 同步动画多个遮罩
static func _animate_masks_sync(mask_nodes: Array[Dictionary], scene_tree: SceneTree, display_duration: float) -> void:
	var tween = scene_tree.create_tween()
	tween.set_parallel(true)
	
	# 淡入
	for mask_data in mask_nodes:
		var mask_node = mask_data["node"]
		if is_instance_valid(mask_node):
			tween.tween_property(mask_node, "color:a", 0.8, 0.15).from(0.0)
	
	tween.set_parallel(false)
	
	# 闪光
	tween.tween_callback(func():
		for mask_data in mask_nodes:
			var mask_node = mask_data["node"]
			if is_instance_valid(mask_node):
				mask_node.color = Color(2, 2, 2, 1)
	)
	
	tween.tween_interval(0.08)
	
	# 恢复颜色
	tween.set_parallel(true)
	for mask_data in mask_nodes:
		var mask_node = mask_data["node"]
		var design_color = mask_data["design_color"]
		if is_instance_valid(mask_node):
			var original_color = design_color
			original_color.a = 0.8
			tween.tween_property(mask_node, "color", original_color, 0.05)
	
	tween.set_parallel(false)
	
	# 保持显示
	tween.tween_interval(display_duration)
	
	# 淡出
	tween.set_parallel(true)
	for mask_data in mask_nodes:
		var mask_node = mask_data["node"]
		if is_instance_valid(mask_node):
			tween.tween_property(mask_node, "color:a", 0.0, 0.2)
	
	tween.set_parallel(false)
	
	# 清理
	tween.tween_callback(func():
		for mask_data in mask_nodes:
			var mask_node = mask_data["node"]
			if is_instance_valid(mask_node):
				mask_node.queue_free()
	)

## 显示单个闭合遮罩（简化版本）
static func show_single_closure_mask(
	points: PackedVector2Array,
	base_color: Color,
	scene_tree: SceneTree,
	display_duration: float = 0.6
) -> void:
	var polygons: Array[PackedVector2Array] = [points]
	show_closure_masks(polygons, base_color, scene_tree, display_duration)
