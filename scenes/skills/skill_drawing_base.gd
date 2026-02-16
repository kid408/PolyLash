extends SkillBase
class_name SkillDrawingBase

## ==============================================================================
## 画线技能基类 - 所有画线技能的中间基类
## ==============================================================================
## 
## 功能说明:
## - 统一管理画线技能的能量消耗逻辑（动态递增）
## - 统一管理规划模式、划线检测、闭合检测
## - 子类只需实现具体的视觉效果和执行逻辑
## 
## 使用方法:
##   1. 继承SkillDrawingBase（而不是SkillBase）
##   2. 实现 _spawn_line_effect() 和 _spawn_area_effect()
##   3. 可选：重写 _get_line_color() 自定义线条颜色
## 
## ==============================================================================

# ==============================================================================
# 画线技能通用参数（从CSV加载）
# ==============================================================================

## 每10像素消耗的能量（基础值）
var energy_per_10px: float = 1.0

## 能量递增阈值距离（像素）
var energy_threshold_distance: float = 1800.0

## 能量递增系数
var energy_scale_multiplier: float = 0.0005

## 闭合判定阈值
var close_threshold: float = 60.0

## 每隔多少像素记录一个路径点
const POINT_INTERVAL: float = 10.0

## 线条持续时间（基础值，可被羁绊加成）
var base_line_duration: float = 5.0

# ==============================================================================
# 画线技能运行时状态
# ==============================================================================

## 是否处于规划模式
var is_planning: bool = false

## 是否正在划线
var is_drawing: bool = false

## 上一个记录的点
var last_point: Vector2 = Vector2.ZERO

## P1-4: 上一次生成金币的位置（用于金币轨迹）
var last_gold_spawn_pos: Vector2 = Vector2.ZERO

## P1-4: 金币生成距离阈值（像素）
const GOLD_SPAWN_DISTANCE: float = 100.0

## 累计距离（用于判断是否达到10像素）
var accumulated_distance: float = 0.0

## 路径点列表（用于绘制和执行）
var path_points: Array[Vector2] = []

## 路径线段列表（用于交叉检测）
var path_segments: Array[Dictionary] = []

## 是否有封闭空间
var has_closure: bool = false

## 已画的总距离（用于能量递增计算）
var total_distance_drawn: float = 0.0

## 是否已显示能量不足提示（防止重复弹出）
var has_shown_no_energy_hint: bool = false

## 用于绘制规划路径的Line2D
var line_2d: Line2D

# ==============================================================================
# 虚函数接口（子类必须实现）
# ==============================================================================

## 生成线段效果（未闭合状态）
## @param start: 线段起点
## @param end: 线段终点
func _spawn_line_effect(start: Vector2, end: Vector2) -> void:
	push_warning("[SkillDrawingBase] _spawn_line_effect() 未实现: %s" % skill_id)

## P2-2: 为线段添加反伤墙效果（筑墙者 Lv.2）
## @param line_area: 线段的Area2D节点
func _add_thorns_wall_effect(line_area: Area2D) -> void:
	"""为线段添加反伤效果"""
	if not BondManager.has_mechanic("thorns_wall"):
		return
	
	if not is_instance_valid(skill_owner):
		return
	
	# 获取玩家攻击力
	var player_damage = skill_owner.damage if "damage" in skill_owner else 10.0
	var thorns_damage = player_damage * 0.3  # 反伤30%攻击力
	
	print("[%s] [P2-2] 反伤墙激活: 伤害=%.0f (玩家攻击力的30%%)" % [skill_id, thorns_damage])
	
	# 连接碰撞信号
	if not line_area.body_entered.is_connected(_on_thorns_wall_hit):
		line_area.body_entered.connect(_on_thorns_wall_hit.bind(thorns_damage))
	if not line_area.area_entered.is_connected(_on_thorns_wall_area_hit):
		line_area.area_entered.connect(_on_thorns_wall_area_hit.bind(thorns_damage))
	SoundManager.play("bond_thorns_wall")

## P2-2: 反伤墙碰撞处理（Body）
func _on_thorns_wall_hit(body: Node2D, thorns_damage: float) -> void:
	if body.is_in_group("enemies"):
		_apply_thorns_damage(body, thorns_damage)

## P2-2: 反伤墙碰撞处理（Area）
func _on_thorns_wall_area_hit(area: Area2D, thorns_damage: float) -> void:
	if area.owner and area.owner.is_in_group("enemies"):
		_apply_thorns_damage(area.owner, thorns_damage)

## P2-2: 应用反伤伤害
func _apply_thorns_damage(enemy: Node2D, thorns_damage: float) -> void:
	if not is_instance_valid(enemy):
		return
	
	if enemy.has_node("HealthComponent"):
		enemy.get_node("HealthComponent").take_damage(int(thorns_damage))
		Global.spawn_floating_text(enemy.global_position, "THORNS!", Color(0.8, 0.4, 0.0))
		print("[%s] [P2-2] 反伤墙触发: 对 %s 造成 %.0f 伤害" % [skill_id, enemy.name, thorns_damage])

## 生成区域效果（闭合状态）
## @param polygon: 闭合多边形的点集
func _spawn_area_effect(polygon: PackedVector2Array) -> void:
	push_warning("[SkillDrawingBase] _spawn_area_effect() 未实现: %s" % skill_id)

## P4-2: 检查并应用图形继承加成（突击型 Lv.2）
## @param base_damage: 基础伤害
## @return: 应用加成后的伤害
func _apply_ink_inherit_bonus(base_damage: float) -> float:
	"""检查是否有图形继承羁绊，应用额外伤害
	
	Args:
		base_damage: 基础伤害
	
	Returns:
		应用加成后的伤害
	"""
	if not BondManager.has_mechanic("ink_inherit"):
		return base_damage
	
	# 获取加成倍率
	var bonus_multiplier = BondManager.get_mechanic_value("ink_inherit")
	if bonus_multiplier <= 0:
		return base_damage
	
	# 检查当前技能所有者是否是切换后的新角色
	# 简化实现：只要有图形继承羁绊，就应用加成
	var final_damage = base_damage * (1.0 + bonus_multiplier)
	
	print("[%s] [P4-2] 图形继承加成: %.0f -> %.0f (+%.0f%%)" % [
		skill_id,
		base_damage,
		final_damage,
		bonus_multiplier * 100
	])
	
	# 视觉反馈
	if is_instance_valid(skill_owner):
		Global.spawn_floating_text(skill_owner.global_position, "INK INHERIT!", Color(0.5, 1.5, 2.0))
	
	return final_damage

## P2-4: 为闭合区域添加诅咒叠加效果（咒术师 Lv.2）
## @param area: 区域效果的 Area2D 节点
## @param polygon: 闭合多边形的点集
func _add_curse_stacking_effect(area: Area2D, polygon: PackedVector2Array) -> void:
	"""为闭合区域添加诅咒叠加效果"""
	if not BondManager.has_mechanic("curse_stack"):
		return
	
	if not is_instance_valid(area):
		return
	
	print("[%s] [P2-4] 诅咒叠加激活" % skill_id)
	
	# 创建诅咒计时器（每秒触发一次）
	var curse_timer = Timer.new()
	curse_timer.name = "CurseStackTimer"
	curse_timer.wait_time = 1.0
	curse_timer.one_shot = false
	area.add_child(curse_timer)
	
	# 诅咒伤害值（每层每秒造成的伤害）
	var curse_damage_per_stack = 2.0  # 可以从配置读取
	
	curse_timer.timeout.connect(func():
		if not is_instance_valid(area) or area.is_queued_for_deletion():
			curse_timer.stop()
			return
		
		# 检测所有在区域内的敌人
		var enemies = area.get_overlapping_bodies() + area.get_overlapping_areas()
		
		for target in enemies:
			var enemy = null
			
			if target.is_in_group("enemies"):
				enemy = target
			elif target.owner and target.owner.is_in_group("enemies"):
				enemy = target.owner
			
			if is_instance_valid(enemy) and enemy.has_method("apply_status"):
				# 应用诅咒状态（持续5秒，每秒叠加1层）
				# P2-3: apply_status 内部会自动检查 debuff_duration 并延长持续时间
				enemy.apply_status("curse", 5.0, curse_damage_per_stack, 1, 1.0)
				print("[%s] [P2-4] 对 %s 叠加诅咒" % [skill_id, enemy.name])
	)
	
	curse_timer.start()
	print("[%s] [P2-4] 诅咒计时器已启动" % skill_id)

## 获取规划线条颜色（子类可重写以自定义颜色）
## @return: 线条颜色
func _get_line_color() -> Color:
	# 默认白色，子类可重写
	return Color.WHITE

## 获取闭合提示颜色（子类可重写）
## @return: 闭合时的线条颜色
func _get_closure_color() -> Color:
	# 默认红色
	return Color(2.0, 0.1, 0.1, 1.0)

# ==============================================================================
# P0 核心画图机制 - 羁绊系统集成
# ==============================================================================

## P0-1: 计算闭合图形伤害（应用爆破师羁绊加成）
## @param base_damage: 基础伤害值
## @return: 应用加成后的伤害值
func _calculate_closed_shape_damage(base_damage: float) -> float:
	var final_damage = base_damage
	
	# 检查爆破师羁绊 - 闭合图形伤害加成
	if BondManager.has_mechanic("closed_shape_dmg"):
		var bonus = BondManager.get_mechanic_value("closed_shape_dmg")
		final_damage *= (1.0 + bonus)
		print("[%s] [P0-1] 闭合图形伤害加成: %.0f -> %.0f (+%.0f%%)" % [
			skill_id, 
			base_damage, 
			final_damage, 
			bonus * 100
		])
	
	return final_damage

## P0-2: 获取线条持续时间（应用筑墙者羁绊加成）
## @return: 应用加成后的持续时间（秒）
func _get_line_duration() -> float:
	var duration = base_line_duration
	
	# 检查筑墙者羁绊 - 线条持续时间延长
	if BondManager.has_mechanic("line_duration"):
		var bonus = BondManager.get_mechanic_value("line_duration")
		duration += bonus
		print("[%s] [P0-2] 线条持续时间延长: %.1f秒 -> %.1f秒 (+%.1f秒)" % [
			skill_id,
			base_line_duration,
			duration,
			bonus
		])
	
	return duration

## P0-3: 获取闭合容错距离（应用几何学家羁绊加成）
## @return: 应用加成后的容错距离（像素）
func _get_closure_tolerance() -> float:
	var tolerance = close_threshold
	
	# 检查几何学家羁绊 - 图形闭合容错率提升
	if BondManager.has_mechanic("shape_tolerance"):
		var level = BondManager.get_mechanic_value("shape_tolerance")
		# 每级增加15像素容错
		var bonus = level * 15.0
		tolerance += bonus
		print("[%s] [P0-3] 闭合容错提升: %.0f像素 -> %.0f像素 (+%.0f像素)" % [
			skill_id,
			close_threshold,
			tolerance,
			bonus
		])
	
	return tolerance

## P1-3: 应用速度转伤害加成（风行者羁绊）
## @param base_damage: 基础伤害值
## @return: 应用速度加成后的伤害值
func _apply_speed_damage_bonus(base_damage: float) -> float:
	if not skill_owner or not skill_owner.has_method("get_speed_damage_bonus"):
		return base_damage
	
	var speed_bonus = skill_owner.get_speed_damage_bonus()
	if speed_bonus <= 0:
		return base_damage
	
	var final_damage = base_damage * (1.0 + speed_bonus)
	
	print("[%s] [P1-3] 速度转伤害应用: %.0f -> %.0f (+%.1f%%)" % [
		skill_id,
		base_damage,
		final_damage,
		speed_bonus * 100
	])
	
	return final_damage

## P1-4: 检查并生成金币轨迹（炼金术士羁绊）
## @param current_pos: 当前位置
func _check_and_spawn_gold_trail(current_pos: Vector2) -> void:
	# 检查炼金术士羁绊 - 金币轨迹
	if not BondManager.has_mechanic("gold_trail"):
		return
	
	# 检查距离阈值（防止生成过多金币）
	var distance_from_last = current_pos.distance_to(last_gold_spawn_pos)
	if distance_from_last < GOLD_SPAWN_DISTANCE:
		return
	
	# 生成金币
	var gold_amount = int(BondManager.get_mechanic_value("gold_trail"))
	if gold_amount <= 0:
		gold_amount = 1  # 默认1金币
	
	# 生成金币实体
	Global.spawn_coin(current_pos, gold_amount)
	SoundManager.play("bond_gold_trail")
	print("[%s] [P1-4] 金币轨迹触发: 生成%d金币 at (%.0f, %.0f)" % [
		skill_id,
		gold_amount,
		current_pos.x,
		current_pos.y
	])
	# 视觉反馈
	Global.spawn_floating_text(current_pos, "GOLD!", Color.GOLD)
	
	# 更新上次生成位置
	last_gold_spawn_pos = current_pos

# ==============================================================================
# P3 高级机制 - 终极天赋
# ==============================================================================

## P3-1: 连锁反应（爆破师 Lv.3）
## @param polygon: 闭合多边形
## @param main_damage: 主爆炸伤害
func _trigger_chain_reaction(polygon: PackedVector2Array, main_damage: int) -> void:
	"""对区域外的所有敌人造成连锁爆炸伤害"""
	if not BondManager.has_mechanic("chain_reaction"):
		return
	
	# 获取所有敌人
	var all_enemies = get_tree().get_nodes_in_group("enemies")
	if all_enemies.is_empty():
		return
	
	# 筛选区域外的敌人
	var outside_enemies = []
	for enemy in all_enemies:
		if not is_instance_valid(enemy):
			continue
		
		# 检查敌人是否在多边形内
		if not Geometry2D.is_point_in_polygon(enemy.global_position, polygon):
			outside_enemies.append(enemy)
	
	# 性能保护：限制最大数量
	const MAX_CHAIN_TARGETS = 50
	if outside_enemies.size() > MAX_CHAIN_TARGETS:
		outside_enemies.shuffle()
		outside_enemies = outside_enemies.slice(0, MAX_CHAIN_TARGETS)
	
	if outside_enemies.is_empty():
		return
	
	# 计算连锁伤害（主爆炸的30%）
	var chain_damage = int(main_damage * 0.3)
	
	print("[%s] [P3-1] 连锁反应触发，波及 %d 个敌人，伤害=%d" % [
		skill_id,
		outside_enemies.size(),
		chain_damage
	])
	SoundManager.play("bond_chain_reaction")
	
	# 对每个敌人造成伤害并播放特效
	for enemy in outside_enemies:
		if not is_instance_valid(enemy):
			continue
		
		# 造成伤害
		if enemy.has_node("HealthComponent"):
			enemy.get_node("HealthComponent").take_damage(chain_damage)
		
		# 视觉反馈：小爆炸特效
		Global.spawn_floating_text(enemy.global_position, "CHAIN!", Color(2.0, 0.8, 0.0))
		
		# 生成小爆炸特效（使用默认爆炸）
		_spawn_mini_explosion(enemy.global_position)

## P3-1: 生成小爆炸特效
func _spawn_mini_explosion(pos: Vector2) -> void:
	"""在指定位置生成小爆炸特效"""
	const DEFAULT_EXPLOSION = preload("uid://dvfjoyutjx5jf")
	
	if not DEFAULT_EXPLOSION:
		return
	
	var vfx = DEFAULT_EXPLOSION.instantiate()
	vfx.global_position = pos
	vfx.scale = Vector2(0.5, 0.5)  # 缩小到50%
	vfx.z_index = 100
	
	get_tree().current_scene.call_deferred("add_child", vfx)
	
	# 自动清理 - 使用 weakref 避免 lambda capture freed 错误
	var vfx_ref = weakref(vfx)
	var cleanup_timer = get_tree().create_timer(1.0)
	cleanup_timer.timeout.connect(func():
		var v = vfx_ref.get_ref()
		if v and is_instance_valid(v):
			v.queue_free()
	)

## P3-2: 永久牢笼（筑墙者 Lv.3）
## @param area: 区域效果节点
## @param polygon: 闭合多边形
func _apply_permanent_cage(area: Area2D, polygon: PackedVector2Array) -> void:
	"""将闭合区域转换为永久牢笼（阻挡敌人移动）"""
	if not BondManager.has_mechanic("permanent_cage"):
		return
	
	if not is_instance_valid(area):
		return
	
	print("[%s] [P3-2] 永久牢笼激活" % skill_id)
	SoundManager.play("bond_permanent_cage")
	
	# 视觉反馈
	var center = _calculate_polygon_center(polygon)
	Global.spawn_floating_text(center, "CAGE!", Color(0.5, 0.5, 1.0))
	
	# 创建物理墙体（StaticBody2D）
	var cage = StaticBody2D.new()
	cage.name = "PermanentCage"
	cage.collision_layer = 4  # 独立碰撞层
	cage.collision_mask = 1 | 2  # 检测 Layer1(Player/Enemy默认) + Layer2(Enemy标记)
	
	# 添加碰撞形状
	var col = CollisionPolygon2D.new()
	col.polygon = polygon
	col.build_mode = CollisionPolygon2D.BUILD_SEGMENTS  # 只有边界，不是实心
	cage.add_child(col)
	
	# 视觉效果：半透明墙体
	var vis = Line2D.new()
	for p in polygon:
		vis.add_point(p)
	vis.add_point(polygon[0])  # 闭合线条
	vis.width = 8.0
	vis.default_color = Color(0.5, 0.5, 1.0, 0.6)
	vis.z_index = 5
	cage.add_child(vis)
	
	# 添加到场景
	get_tree().current_scene.add_child(cage)
	
	# 牢笼管理：限制数量或时间
	_manage_cage_lifecycle(cage)
	
	print("[%s] [P3-2] 牢笼已生成，位置: (%.0f, %.0f)" % [
		skill_id,
		polygon[0].x,
		polygon[0].y
	])

## P3-2: 管理牢笼生命周期
func _manage_cage_lifecycle(cage: StaticBody2D) -> void:
	"""管理牢笼的生命周期（时间限制或数量限制）"""
	const MAX_CAGES = 5
	const CAGE_LIFETIME = 15.0  # 15秒后自动消失
	
	# 获取或创建牢笼列表
	if not get_tree().current_scene.has_meta("active_cages"):
		get_tree().current_scene.set_meta("active_cages", [])
	
	var active_cages: Array = get_tree().current_scene.get_meta("active_cages")
	
	# 清理无效牢笼
	var valid_cages = []
	for c in active_cages:
		if is_instance_valid(c):
			valid_cages.append(c)
	active_cages = valid_cages
	
	# 如果超过数量限制，移除最早的牢笼
	if active_cages.size() >= MAX_CAGES:
		var oldest_cage = active_cages[0]
		if is_instance_valid(oldest_cage):
			_remove_cage(oldest_cage)
		active_cages.remove_at(0)
	
	# 添加新牢笼
	active_cages.append(cage)
	get_tree().current_scene.set_meta("active_cages", active_cages)
	
	# 设置生命周期定时器
	var lifetime_timer = Timer.new()
	lifetime_timer.wait_time = CAGE_LIFETIME
	lifetime_timer.one_shot = true
	cage.add_child(lifetime_timer)
	
	var cage_ref = weakref(cage)
	lifetime_timer.timeout.connect(func():
		var c = cage_ref.get_ref()
		if c and is_instance_valid(c):
			# 淡出动画
			var vis = c.get_node_or_null("Line2D")
			if is_instance_valid(vis):
				var tween = c.create_tween()
				tween.tween_property(vis, "modulate:a", 0.0, 0.5)
				tween.tween_callback(func():
					if is_instance_valid(c):
						c.queue_free()
				)
			else:
				c.queue_free()
	)
	
	lifetime_timer.start()

## P3-2: 移除牢笼
func _remove_cage(cage: StaticBody2D) -> void:
	"""移除牢笼（带淡出动画）"""
	if not is_instance_valid(cage):
		return
	
	# 淡出动画
	var vis = cage.get_node_or_null("Line2D")
	if is_instance_valid(vis):
		var tween = cage.create_tween()
		tween.tween_property(vis, "modulate:a", 0.0, 0.5)
		tween.tween_callback(func():
			if is_instance_valid(cage):
				cage.queue_free()
		)
	else:
		cage.queue_free()

## P3-3: 小图形暴击（几何学家 Lv.2）
## @param polygon: 闭合多边形
## @param base_damage: 基础伤害
## @return: 应用暴击后的伤害
func _apply_small_shape_crit(polygon: PackedVector2Array, base_damage: float) -> float:
	"""检查图形面积，小图形触发暴击"""
	if not BondManager.has_mechanic("small_shape_crit"):
		return base_damage
	
	# 计算多边形面积（鞋带公式 Shoelace Formula）
	var area = _calculate_polygon_area(polygon)
	
	# 面积阈值（像素平方）
	const AREA_THRESHOLD = 15000.0
	
	# 检查是否触发暴击
	if area < AREA_THRESHOLD:
		var crit_damage = base_damage * 2.0
		SoundManager.play("bond_small_shape_crit")
		
		print("[%s] [P3-3] 图形面积: %.2f (阈值: %.2f) -> 暴击触发! 伤害: %.0f -> %.0f" % [
			skill_id,
			area,
			AREA_THRESHOLD,
			base_damage,
			crit_damage
		])
		
		# 视觉反馈
		var center = _calculate_polygon_center(polygon)
		Global.spawn_floating_text(center, "CRITICAL!", Color(2.0, 2.0, 0.0))
		Global.on_camera_shake.emit(10.0, 0.2)
		
		return crit_damage
	else:
		print("[%s] [P3-3] 图形面积: %.2f (阈值: %.2f) -> 未触发暴击" % [
			skill_id,
			area,
			AREA_THRESHOLD
		])
		return base_damage

## P3-3: 计算多边形面积（鞋带公式）
func _calculate_polygon_area(polygon: PackedVector2Array) -> float:
	"""使用鞋带公式计算多边形面积"""
	if polygon.size() < 3:
		return 0.0
	
	var area = 0.0
	var n = polygon.size()
	
	for i in range(n):
		var j = (i + 1) % n
		area += polygon[i].x * polygon[j].y
		area -= polygon[j].x * polygon[i].y
	
	return abs(area) / 2.0

## P3-3: 计算多边形中心点
func _calculate_polygon_center(polygon: PackedVector2Array) -> Vector2:
	"""计算多边形的几何中心"""
	if polygon.is_empty():
		return Vector2.ZERO
	
	var center = Vector2.ZERO
	for p in polygon:
		center += p
	return center / polygon.size()

# ==============================================================================
# 生命周期
# ==============================================================================

func _ready() -> void:
	super._ready()
	
	print("[SkillDrawingBase] _ready() 技能: %s, skill_owner: %s" % [skill_id, skill_owner])
	
	if skill_owner:
		# 创建Line2D用于绘制规划路径
		line_2d = Line2D.new()
		line_2d.name = "DrawingPlanningLine"
		line_2d.width = 4.0
		
		# 确保Line2D添加到玩家节点
		var player_node = skill_owner
		if skill_owner is Area2D:
			player_node = skill_owner.get_parent()
		if player_node:
			player_node.add_child(line_2d)
		else:
			skill_owner.add_child(line_2d)
		
		line_2d.top_level = true
		line_2d.clear_points()
		line_2d.default_color = _get_line_color()
		print("[SkillDrawingBase] ✅ Line2D 创建成功: %s" % skill_id)
	else:
		print("[SkillDrawingBase] ⚠️ skill_owner 为空，无法创建 Line2D: %s" % skill_id)

func _process(delta: float) -> void:
	super._process(delta)
	
	# 强制维持子弹时间
	if is_planning and Engine.time_scale > 0.2:
		Engine.time_scale = 0.1
	
	# 每帧更新视觉效果
	_update_visuals()

# ==============================================================================
# 技能执行（统一接口）
# ==============================================================================

## 蓄力技能（持续按住Q）
func charge(delta: float) -> void:
	if not is_planning:
		_enter_planning_mode()
	
	if is_planning:
		# 检测鼠标左键按下 - 开始或继续划线
		if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
			if not is_drawing:
				_start_drawing()
			
			_continue_drawing()
		else:
			# 鼠标左键松开
			if is_drawing:
				is_drawing = false
		
		# 右键：清除所有路径
		if Input.is_action_just_pressed("click_right"):
			_clear_all_points()

## 释放技能（松开Q）
func release() -> void:
	if is_planning:
		_exit_planning_mode_and_execute()

# ==============================================================================
# 规划模式管理
# ==============================================================================

## 进入规划模式
func _enter_planning_mode() -> void:
	is_planning = true
	is_charging = true
	is_drawing = false
	accumulated_distance = 0.0
	has_closure = false
	total_distance_drawn = 0.0
	has_shown_no_energy_hint = false
	
	# 清空路径数据
	path_points.clear()
	path_segments.clear()
	
	# 设置起点为鼠标位置
	var start_pos = skill_owner.get_global_mouse_position()
	path_points.append(start_pos)
	last_point = start_pos
	
	print("[%s] ===== 进入规划模式 ===== 起点: %s, line_2d有效: %s" % [skill_id, start_pos, is_instance_valid(line_2d)])
	
	SoundManager.play("skill_q_planning")
	Engine.time_scale = 0.1

## 退出规划模式并执行技能
func _exit_planning_mode_and_execute() -> void:
	is_planning = false
	is_charging = false
	is_drawing = false
	Engine.time_scale = 1.0
	
	print("[%s] ===== 退出规划模式 ===== 路径点数: %d, 闭合: %s" % [skill_id, path_points.size(), has_closure])
	
	if path_points.size() > 1:
		# 最终闭合检测
		_perform_final_closure_check()
		
		print("[%s] 最终闭合检测结果: %s" % [skill_id, has_closure])
		
		# 根据闭合状态生成效果
		if has_closure:
			_execute_closed_path()
		else:
			_execute_open_path()
		
		start_cooldown()
		_clear_all_points()
	else:
		print("[%s] 路径点不足，跳过执行" % skill_id)
		_clear_all_points()

## 执行闭合路径
func _execute_closed_path() -> void:
	# 播放角色专属 Q 闭合音效
	if skill_owner and "player_id" in skill_owner:
		SoundManager.play_character_q_closure(skill_owner.player_id)
	else:
		SoundManager.play("skill_q_closure_generic")
	
	# P0-3: 使用羁绊加成后的容错距离
	var tolerance = _get_closure_tolerance()
	var polygons = PolygonUtils.find_all_closing_polygons(path_points, tolerance)
	
	if polygons.size() > 0:
		print("[%s] 检测到 %d 个闭合区域" % [skill_id, polygons.size()])
		
		# 显示闭合遮罩（统一动画）
		var mask_color = _get_closure_color()
		mask_color.a = 0.7
		PolygonUtils.show_closure_masks(polygons, mask_color, get_tree(), 0.6)
		
		# 为每个闭合区域生成效果
		for polygon in polygons:
			# 子类实现具体效果
			_spawn_area_effect(polygon)

## 执行开放路径
func _execute_open_path() -> void:
	if path_points.size() < 2:
		print("[%s] 路径点不足，跳过开放路径" % skill_id)
		return
	
	SoundManager.play("skill_q_open_execute")
	
	# 将密集的小路径点合并为较长的线段（每段约 80-120px）
	# 这样墙体更宽、更容易阻挡敌人，同时减少节点数量
	const MERGE_DISTANCE: float = 100.0  # 每段目标长度
	
	var merged_segments: Array[Dictionary] = []
	var seg_start: Vector2 = path_points[0]
	var accumulated: float = 0.0
	
	for i in range(1, path_points.size()):
		var dist = path_points[i - 1].distance_to(path_points[i])
		accumulated += dist
		
		if accumulated >= MERGE_DISTANCE or i == path_points.size() - 1:
			merged_segments.append({"start": seg_start, "end": path_points[i]})
			seg_start = path_points[i]
			accumulated = 0.0
	
	print("[%s] 生成开放路径效果，原始点数: %d, 合并线段数: %d" % [skill_id, path_points.size(), merged_segments.size()])
	
	for seg in merged_segments:
		_spawn_line_effect(seg["start"], seg["end"])
	
	print("[%s] 开放路径效果生成完毕" % skill_id)

# ==============================================================================
# 划线逻辑
# ==============================================================================

## 开始划线
func _start_drawing() -> void:
	is_drawing = true
	SoundManager.play("skill_q_draw_start")
	var mouse_pos = skill_owner.get_global_mouse_position()
	
	# 清空之前的路径，重新从鼠标位置开始
	path_points.clear()
	path_segments.clear()
	has_closure = false
	accumulated_distance = 0.0
	total_distance_drawn = 0.0
	
	path_points.append(mouse_pos)
	last_point = mouse_pos
	has_shown_no_energy_hint = false
	
	# P1-4: 重置金币生成位置
	last_gold_spawn_pos = mouse_pos

## 继续划线
func _continue_drawing() -> void:
	var mouse_pos = skill_owner.get_global_mouse_position()
	var distance = last_point.distance_to(mouse_pos)
	
	# 如果鼠标移动距离太小，跳过本帧
	if distance < 1.0:
		return
	
	# 计算需要添加多少个点
	var points_to_add = int(distance / POINT_INTERVAL)
	
	# 沿着鼠标轨迹添加点
	for i in range(points_to_add):
		# 计算当前能量消耗（动态递增）
		var current_energy_cost = _calculate_current_energy_cost()
		
		# 检查能量是否足够
		if skill_owner.energy >= current_energy_cost:
			# 消耗能量
			skill_owner.consume_energy(current_energy_cost)
			
			# 更新总距离
			total_distance_drawn += POINT_INTERVAL
			
			# 沿着方向前进
			var direction = (mouse_pos - last_point).normalized()
			var new_point = last_point + direction * POINT_INTERVAL
			
			# 添加路径点
			path_points.append(new_point)
			
			# 创建线段
			var segment = {
				"start": last_point,
				"end": new_point
			}
			path_segments.append(segment)
			
			# 检测线段交叉
			_check_intersection_and_closure()
			
			# P1-4: 金币轨迹机制
			_check_and_spawn_gold_trail(new_point)
			
			# 更新状态
			last_point = new_point
		else:
			# 能量不足
			is_drawing = false
			SoundManager.play("skill_q_energy_depleted")
			if not has_shown_no_energy_hint:
				has_shown_no_energy_hint = true
				Global.spawn_floating_text(skill_owner.global_position, "No Energy!", Color.RED)
			break

# ==============================================================================
# 能量消耗计算（核心逻辑）
# ==============================================================================

## 计算当前能量消耗（动态递增）
func _calculate_current_energy_cost() -> float:
	if total_distance_drawn <= energy_threshold_distance:
		# 基础阶段
		return energy_per_10px
	else:
		# 递增阶段
		var excess_distance = total_distance_drawn - energy_threshold_distance
		var multiplier = 1.0 + excess_distance * energy_scale_multiplier
		return energy_per_10px * multiplier

## 计算已消耗的总能量（用于返还）
func _calculate_total_consumed_energy() -> float:
	var total = 0.0
	var distance = 0.0
	
	# 从起点开始，每10像素计算一次
	while distance < total_distance_drawn:
		if distance <= energy_threshold_distance:
			total += energy_per_10px
		else:
			var excess = distance - energy_threshold_distance
			var multiplier = 1.0 + excess * energy_scale_multiplier
			total += energy_per_10px * multiplier
		
		distance += POINT_INTERVAL
	
	return total

# ==============================================================================
# 闭合检测
# ==============================================================================

## 执行最终的闭合检测（松开Q键时调用）
func _perform_final_closure_check() -> void:
	has_closure = false
	
	if path_segments.size() < 3:
		return
	
	# P0-3: 使用羁绊加成后的容错距离
	var tolerance = _get_closure_tolerance()
	
	# 检查任意两条不相邻的线段是否相交
	for i in range(path_segments.size()):
		for j in range(i + 2, path_segments.size()):
			var seg1 = path_segments[i]
			var seg2 = path_segments[j]
			
			if _segments_intersect(seg1, seg2):
				has_closure = true
				return
	
	# 检查距离闭合
	if path_points.size() >= 3:
		var last_point_pos = path_points[path_points.size() - 1]
		
		# 检查是否接近起点（使用羁绊加成后的容错距离）
		if last_point_pos.distance_to(path_points[0]) < tolerance:
			has_closure = true
			return
		
		# 检查是否接近路径中的其他点（使用羁绊加成后的容错距离）
		var check_until = max(0, path_points.size() - 20)
		for i in range(check_until):
			if last_point_pos.distance_to(path_points[i]) < tolerance:
				has_closure = true
				return

## 检测线段交叉和封闭空间（实时检测，用于视觉反馈）
func _check_intersection_and_closure() -> void:
	if has_closure:
		return
	
	if path_segments.size() < 3:
		return
	
	# P0-3: 使用羁绊加成后的容错距离
	var tolerance = _get_closure_tolerance()
	
	# 检查最新线段是否与之前的线段相交
	var latest_seg = path_segments[path_segments.size() - 1]
	
	for i in range(path_segments.size() - 2):
		var old_seg = path_segments[i]
		
		if _segments_intersect(latest_seg, old_seg):
			has_closure = true
			SoundManager.play("skill_q_closure_detected")
			return
	
	# 检查距离闭合（使用羁绊加成后的容错距离）
	if path_points.size() >= 20:
		var current_point = path_points[path_points.size() - 1]
		if current_point.distance_to(path_points[0]) < tolerance:
			has_closure = true
			SoundManager.play("skill_q_closure_detected")
			return

## 检测两条线段是否相交
func _segments_intersect(seg1: Dictionary, seg2: Dictionary) -> bool:
	var p1 = seg1["start"]
	var p2 = seg1["end"]
	var p3 = seg2["start"]
	var p4 = seg2["end"]
	
	var intersection = Geometry2D.segment_intersects_segment(p1, p2, p3, p4)
	return intersection != null

# ==============================================================================
# 路径管理
# ==============================================================================

## 清除所有路径点
func _clear_all_points() -> void:
	# 计算已消耗的总能量
	var total_consumed_energy = _calculate_total_consumed_energy()
	
	# 返还能量
	if skill_owner and total_consumed_energy > 0:
		skill_owner.energy += total_consumed_energy
		skill_owner.update_ui_signals()
	
	# 清空数据
	path_points.clear()
	path_segments.clear()
	has_closure = false
	accumulated_distance = 0.0
	total_distance_drawn = 0.0
	
	# 重置起点为鼠标位置
	if skill_owner:
		var start_pos = skill_owner.get_global_mouse_position()
		path_points.append(start_pos)
		last_point = start_pos

# ==============================================================================
# 视觉效果
# ==============================================================================

## 更新规划路径的视觉效果（每帧调用）
func _update_visuals() -> void:
	if not is_instance_valid(line_2d):
		return
	
	line_2d.clear_points()
	
	if path_points.is_empty() and not is_planning:
		return
	
	if not skill_owner:
		return
	
	# 绘制已确认的路径点
	for p in path_points:
		line_2d.add_point(p)
	
	# 如果正在划线，添加到鼠标的预览线
	if is_planning and is_drawing:
		var mouse_pos = skill_owner.get_global_mouse_position()
		line_2d.add_point(mouse_pos)
	
	# 颜色判断
	var final_color = _get_line_color()
	
	if has_closure:
		# 闭合提示
		final_color = _get_closure_color()
	elif is_planning and skill_owner and skill_owner.energy < _calculate_current_energy_cost():
		# 能量不足
		final_color = Color(0.5, 0.5, 0.5, 0.5)
	elif is_planning and total_distance_drawn > energy_threshold_distance:
		# 超过阈值，颜色渐变提示
		var excess_ratio = (total_distance_drawn - energy_threshold_distance) / energy_threshold_distance
		excess_ratio = clamp(excess_ratio, 0.0, 1.0)
		var base_color = _get_line_color()
		var warning_color = Color.ORANGE
		final_color = base_color.lerp(warning_color, excess_ratio * 0.5)
	
	line_2d.default_color = final_color

# ==============================================================================
# 清理
# ==============================================================================

## 清理资源
func cleanup() -> void:
	print("[%s] cleanup() 被调用" % skill_id)
	
	# 清理规划线
	if is_instance_valid(line_2d):
		line_2d.queue_free()
	
	# 重置状态
	is_planning = false
	is_drawing = false
	has_shown_no_energy_hint = false
	path_points.clear()
	path_segments.clear()
	accumulated_distance = 0.0
	total_distance_drawn = 0.0
	has_closure = false
	Engine.time_scale = 1.0
	
	print("[%s] cleanup() 结束" % skill_id)
