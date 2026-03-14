extends Node

const DEBUG_VERBOSE := false

## ==============================================================================
## 技能效果生命周期管理器 - 统一管理所有技能的场景效果
## ==============================================================================
## 
## 功能说明:
## - 统一管理技能效果的生命周期（火海、风墙、锯条、地雷等）
## - 提供独立的伤害、物理效果、视觉效果管理
## - 不依赖技能实例，即使角色切换也能继续工作
## 
## 使用方法:
##   var effect_id = SkillEffectManager.create_area_effect({
##       "polygon": points,
##       "damage": 40,
##       "damage_interval": 0.3,
##       "duration": 5.0,
##       "color": Color.RED,
##       "pull_to_center": true,
##       "pull_force": 400.0
##   })
## 
## ==============================================================================

## 效果节点字典 {effect_id: effect_data}
var active_effects: Dictionary = {}

## 效果ID计数器
var next_effect_id: int = 0

## 临时伤害倍率栈（由技能基类压栈/出栈）
var _damage_multiplier_stack: Array[float] = []

func push_damage_multiplier(multiplier: float) -> void:
	var safe_multiplier: float = max(0.0, multiplier)
	_damage_multiplier_stack.append(safe_multiplier)

func pop_damage_multiplier() -> void:
	if _damage_multiplier_stack.is_empty():
		return
	_damage_multiplier_stack.pop_back()

func _get_damage_multiplier() -> float:
	if _damage_multiplier_stack.is_empty():
		return 1.0
	var multiplier: float = 1.0
	for item in _damage_multiplier_stack:
		multiplier *= max(0.0, item)
	return multiplier

func _apply_runtime_damage_multiplier(config: Dictionary) -> Dictionary:
	var multiplier: float = _get_damage_multiplier()
	if is_equal_approx(multiplier, 1.0):
		return config

	var adjusted: Dictionary = config.duplicate(true)
	for key in ["damage", "contact_damage"]:
		if not adjusted.has(key):
			continue
		adjusted[key] = int(round(float(adjusted.get(key, 0)) * multiplier))
	return adjusted

func _normalize_polygon_config(config: Dictionary, effect_name: String) -> Dictionary:
	if not config.has("polygon"):
		return config

	var raw_points: PackedVector2Array = config["polygon"]
	var polygon: PackedVector2Array = PolygonUtils.sanitize_polygon(raw_points)
	if polygon.is_empty():
		push_warning(
			"[SkillEffectManager] %s 跳过无效多边形: raw_points=%d" % [
				effect_name,
				raw_points.size()
			]
		)
		return {}

	var adjusted: Dictionary = config.duplicate(true)
	adjusted["polygon"] = polygon

	if DEBUG_VERBOSE and polygon.size() != raw_points.size():
		print(
			"[SkillEffectManager] %s polygon sanitized: %d -> %d" % [
				effect_name,
				raw_points.size(),
				polygon.size()
			]
		)

	return adjusted

# ==============================================================================
# 创建效果
# ==============================================================================

## 创建区域效果（多边形）
## @param config: 配置字典
##   - polygon: PackedVector2Array (必需)
##   - damage: int (可选，默认0)
##   - damage_interval: float (可选，默认0.5)
##   - duration: float (可选，默认5.0)
##   - color: Color (可选，默认白色)
##   - pull_to_center: bool (可选，默认false)
##   - pull_force: float (可选，默认0)
##   - pull_interval: float (可选，默认0.05)
##   - z_index: int (可选，默认10)
##   - fade_in_duration: float (可选，默认0.2)
##   - fade_out_duration: float (可选，默认0.3)
## @return: effect_id (用于后续操作)
func create_area_effect(config: Dictionary) -> int:
	config = _apply_runtime_damage_multiplier(config)
	var effect_id = next_effect_id
	next_effect_id += 1
	
	# 验证必需参数
	if not config.has("polygon"):
		push_error("[SkillEffectManager] 缺少必需参数: polygon")
		return -1

	config = _normalize_polygon_config(config, "create_area_effect")
	if config.is_empty():
		return -1
	
	var points: PackedVector2Array = config["polygon"]
	if points.size() < 3:
		push_error("[SkillEffectManager] 多边形点数不足: %d" % points.size())
		return -1
	
	if DEBUG_VERBOSE:
		print("[SkillEffectManager] create_area_effect 被调用: 点数=%d, damage=%d, duration=%.1f" % [
		points.size(), config.get("damage", 0), config.get("duration", 5.0)
	])
	
	# 创建 Area2D
	var area = Area2D.new()
	area.collision_layer = 0
	area.collision_mask = 1 | 2  # 检测 Layer1(Player/Enemy默认) + Layer2(Enemy标记)
	area.monitorable = false
	area.monitoring = true
	area.name = "SkillEffect_%d" % effect_id
	
	# 碰撞形状
	var col = CollisionPolygon2D.new()
	col.polygon = points
	area.add_child(col)
	
	# 视觉效果
	var vis_poly = Polygon2D.new()
	vis_poly.polygon = points
	vis_poly.color = Color(1.0, 1.0, 1.0, 0.0)
	vis_poly.z_index = config.get("z_index", 10)
	area.add_child(vis_poly)
	
	# 添加到 SkillEffectManager 自身（autoload 节点，角色切换不影响）
	add_child(area)
	
	# 保存效果数据
	var effect_data = {
		"area": area,
		"vis_poly": vis_poly,
		"config": config,
		"elapsed": 0.0,
		"phase": "fade_in"
	}
	active_effects[effect_id] = effect_data
	
	# 淡入动画
	var fade_in_duration = config.get("fade_in_duration", 0.2)
	var target_color = config.get("color", Color.WHITE)
	var tween = area.create_tween()
	tween.tween_property(vis_poly, "color", target_color, fade_in_duration).from(Color(target_color.r, target_color.g, target_color.b, 0.0))
	
	# 计算中心点（用于吸附效果）
	if config.get("pull_to_center", false):
		var center = Vector2.ZERO
		for p in points:
			center += p
		center /= points.size()
		effect_data["center"] = center
	
	# 启动效果管理
	_start_effect_lifecycle(effect_id)
	
	return effect_id

## 创建线段效果（火线、风墙等）
## @param config: 配置字典
##   - start: Vector2 (必需)
##   - end: Vector2 (必需)
##   - width: float (可选，默认24)
##   - damage: int (可选，默认0)
##   - damage_interval: float (可选，默认0.5)
##   - duration: float (可选，默认5.0)
##   - color: Color (可选，默认白色)
##   - pull_to_line: bool (可选，默认false)
##   - pull_force: float (可选，默认0)
## @return: effect_id
func create_line_effect(config: Dictionary) -> int:
	config = _apply_runtime_damage_multiplier(config)
	var effect_id = next_effect_id
	next_effect_id += 1
	
	# 验证必需参数
	if not config.has("start") or not config.has("end"):
		push_error("[SkillEffectManager] 缺少必需参数: start 或 end")
		return -1
	
	if DEBUG_VERBOSE:
		print("[SkillEffectManager] create_line_effect 被调用: damage=%d, duration=%.1f" % [
		config.get("damage", 0), config.get("duration", 5.0)
	])
	
	var start: Vector2 = config["start"]
	var end: Vector2 = config["end"]
	var width: float = config.get("width", 24.0)
	
	# 创建 Area2D
	var area = Area2D.new()
	area.position = start
	area.collision_layer = 0
	area.collision_mask = 1 | 2  # 检测 Layer1(Player/Enemy默认) + Layer2(Enemy标记)
	area.monitorable = false
	area.monitoring = true
	area.name = "SkillEffect_%d" % effect_id
	
	var vec = end - start
	var length = vec.length()
	var angle = vec.angle()
	
	# 碰撞形状
	var col = CollisionShape2D.new()
	var shape = RectangleShape2D.new()
	shape.size = Vector2(length, width)
	col.shape = shape
	col.position = Vector2(length / 2.0, 0)
	col.rotation = angle
	area.add_child(col)
	
	# 视觉效果
	var vis_line = Line2D.new()
	vis_line.add_point(Vector2.ZERO)
	vis_line.add_point(end - start)
	vis_line.width = width
	vis_line.default_color = config.get("color", Color.WHITE)
	vis_line.begin_cap_mode = Line2D.LINE_CAP_ROUND
	vis_line.end_cap_mode = Line2D.LINE_CAP_ROUND
	area.add_child(vis_line)
	
	# 添加到 SkillEffectManager 自身（autoload 节点，角色切换不影响）
	add_child(area)
	
	# 保存效果数据
	var effect_data = {
		"area": area,
		"vis_line": vis_line,
		"config": config,
		"elapsed": 0.0,
		"phase": "active",
		"start": start,
		"end": end
	}
	active_effects[effect_id] = effect_data
	
	# 启动效果管理
	_start_effect_lifecycle(effect_id)
	
	return effect_id

# ==============================================================================
# 墙体效果
# ==============================================================================

## 创建墙体效果（StaticBody2D）
## @param config: 配置字典
##   - start: Vector2 (必需) - 墙体起点
##   - end: Vector2 (必需) - 墙体终点
##   - width: float (可选, 默认 16) - 墙体宽度
##   - duration: float (可选, 默认 5.0) - 持续时间
##   - health: int (可选, 默认 -1) - 墙体生命值，-1 为不可破坏
##   - block_enemies: bool (可选, 默认 true) - 是否阻挡敌人
##   - block_bullets: bool (可选, 默认 false) - 是否阻挡子弹
##   - reflect_bullets: bool (可选, 默认 false) - 是否反射子弹
##   - contact_damage: int (可选, 默认 0) - 接触伤害
##   - contact_interval: float (可选, 默认 0.5) - 接触伤害间隔
##   - color: Color (可选) - 墙体颜色
## @return: effect_id (用于后续操作), -1 表示失败
func create_wall_effect(config: Dictionary) -> int:
	config = _apply_runtime_damage_multiplier(config)
	# 验证必需参数
	if not config.has("start") or not config.has("end"):
		push_error("[SkillEffectManager] create_wall_effect 缺少必需参数: start 或 end")
		return -1

	if DEBUG_VERBOSE:
		print("[SkillEffectManager] create_wall_effect 被调用: start=%s, end=%s, block=%s, damage=%d" % [
		config.get("start"), config.get("end"),
		config.get("block_enemies", true), config.get("contact_damage", 0)
	])

	var effect_id = next_effect_id
	next_effect_id += 1

	var start: Vector2 = config["start"]
	var end_pos: Vector2 = config["end"]
	var width: float = config.get("width", 16.0)
	var duration: float = config.get("duration", 5.0)
	var health: int = config.get("health", -1)
	var block_enemies: bool = config.get("block_enemies", true)
	var block_bullets: bool = config.get("block_bullets", false)
	var reflect_bullets: bool = config.get("reflect_bullets", false)
	var contact_damage: int = config.get("contact_damage", 0)
	var contact_interval: float = config.get("contact_interval", 0.5)
	var color: Color = config.get("color", Color(0.7, 0.85, 1.0, 0.7))

	var vec = end_pos - start
	var length = vec.length()
	var angle = vec.angle()

	# --- StaticBody2D 物理墙体 ---
	var static_body = StaticBody2D.new()
	static_body.name = "WallEffect_%d" % effect_id

	# 碰撞层设置
	var col_layer = 0
	if block_enemies:
		col_layer |= 4  # Layer 3: 障碍物层，敌人会碰撞
	if block_bullets or reflect_bullets:
		col_layer |= 4  # 同层，子弹也会碰撞
	static_body.collision_layer = col_layer
	static_body.collision_mask = 0  # StaticBody 不需要主动检测

	# 碰撞形状：沿线段的矩形
	var col_shape = CollisionShape2D.new()
	var rect_shape = RectangleShape2D.new()
	rect_shape.size = Vector2(length, width)
	col_shape.shape = rect_shape
	# 将碰撞形状放在线段中点，旋转到线段方向
	col_shape.position = vec / 2.0
	col_shape.rotation = angle
	static_body.add_child(col_shape)

	# 设置墙体位置为起点
	static_body.global_position = start

	# --- Line2D 视觉占位 ---
	var vis_line = Line2D.new()
	vis_line.add_point(Vector2.ZERO)
	vis_line.add_point(vec)
	vis_line.width = width
	vis_line.default_color = color
	vis_line.begin_cap_mode = Line2D.LINE_CAP_ROUND
	vis_line.end_cap_mode = Line2D.LINE_CAP_ROUND
	vis_line.z_index = 5
	static_body.add_child(vis_line)

	# --- 接触伤害 Area2D ---
	var damage_area: Area2D = null
	if contact_damage > 0:
		damage_area = Area2D.new()
		damage_area.name = "WallDamageArea"
		damage_area.collision_layer = 0
		damage_area.collision_mask = 1 | 2  # 检测 Layer1(Player/Enemy默认) + Layer2(Enemy标记)
		damage_area.monitorable = false
		damage_area.monitoring = true

		var dmg_col = CollisionShape2D.new()
		var dmg_shape = RectangleShape2D.new()
		dmg_shape.size = Vector2(length, width + 16.0)  # 比墙体宽，确保接触检测可靠
		dmg_col.shape = dmg_shape
		dmg_col.position = vec / 2.0
		dmg_col.rotation = angle
		damage_area.add_child(dmg_col)
		static_body.add_child(damage_area)

	# --- 阻挡敌人 Area2D（因为敌人是 Area2D，不受 StaticBody2D 物理阻挡）---
	var block_area: Area2D = null
	if block_enemies:
		block_area = Area2D.new()
		block_area.name = "WallBlockArea"
		block_area.collision_layer = 0
		block_area.collision_mask = 1 | 2  # 检测 Layer1(Player/Enemy默认) + Layer2(Enemy标记)
		block_area.monitorable = false
		block_area.monitoring = true

		var blk_col = CollisionShape2D.new()
		var blk_shape = RectangleShape2D.new()
		blk_shape.size = Vector2(length, width + 32.0)  # 比墙体宽很多，确保提前检测到敌人
		blk_col.shape = blk_shape
		blk_col.position = vec / 2.0
		blk_col.rotation = angle
		block_area.add_child(blk_col)
		static_body.add_child(block_area)

	# --- 阻挡子弹 Area2D（敌人子弹是 Area2D/HitboxComponent，不受 StaticBody2D 阻挡）---
	var bullet_block_area: Area2D = null
	if block_bullets or reflect_bullets:
		bullet_block_area = Area2D.new()
		bullet_block_area.name = "WallBulletBlockArea"
		bullet_block_area.collision_layer = 0
		bullet_block_area.collision_mask = 4  # Layer 3: HitboxEnemy（敌人子弹的 hitbox）
		bullet_block_area.monitorable = false
		bullet_block_area.monitoring = true

		var blt_col = CollisionShape2D.new()
		var blt_shape = RectangleShape2D.new()
		blt_shape.size = Vector2(length, width + 24.0)  # 比墙体稍宽确保拦截
		blt_col.shape = blt_shape
		blt_col.position = vec / 2.0
		blt_col.rotation = angle
		bullet_block_area.add_child(blt_col)
		static_body.add_child(bullet_block_area)

		# 预计算墙体法线（用于反射）
		var wall_dir = vec.normalized()
		var wall_normal_for_reflect = Vector2(-wall_dir.y, wall_dir.x)  # 垂直于墙体方向

		# 连接信号：检测到敌人子弹时阻挡或反射
		var do_reflect = reflect_bullets
		bullet_block_area.area_entered.connect(func(area: Area2D):
			# --- 解析子弹节点 ---
			var projectile_node: Node = null
			if area is HitboxComponent:
				var p = area.get_parent()
				if p and is_instance_valid(p) and p is Projectile:
					projectile_node = p
			if projectile_node == null:
				var p = area.get_parent()
				if p and is_instance_valid(p) and p.is_in_group("projectiles"):
					projectile_node = p

			if projectile_node == null:
				return

			# --- 反射逻辑 ---
			if do_reflect and is_instance_valid(projectile_node):
				if projectile_node is Projectile:
					# 标准 Projectile：反转 velocity 沿墙体法线反射
					var vel: Vector2 = projectile_node.velocity
					var reflected = vel - 2.0 * vel.dot(wall_normal_for_reflect) * wall_normal_for_reflect
					projectile_node.velocity = reflected
					projectile_node.rotation = reflected.angle()
					# 修改 hitbox 碰撞层：从敌人子弹变为玩家子弹，使其能伤害敌人
					if projectile_node.hitbox:
						projectile_node.hitbox.collision_layer = 16  # Layer 5: HitboxPlayer
						projectile_node.hitbox.collision_mask = 8    # Layer 4: HurtboxEnemy
						projectile_node.hitbox.source = Global.player if is_instance_valid(Global.player) else null
					return

			# --- 纯阻挡：销毁子弹 ---
			if is_instance_valid(projectile_node):
				projectile_node.queue_free()
		)

	# 添加到 SkillEffectManager 自身（autoload 节点，角色切换不影响）
	add_child(static_body)

	# --- 保存效果数据 ---
	var effect_data = {
		"type": "wall",
		"static_body": static_body,
		"vis_line": vis_line,
		"config": config,
		"elapsed": 0.0,
		"health": health,
	}
	if damage_area:
		effect_data["damage_area"] = damage_area
		effect_data["contact_timer"] = 0.0
	if block_area:
		effect_data["block_area"] = block_area
		# 预计算墙体法线方向（用于推回敌人）
		var wall_normal = vec.rotated(PI / 2.0).normalized()
		effect_data["wall_normal"] = wall_normal
		effect_data["wall_start"] = start
		effect_data["wall_end"] = end_pos
		effect_data["wall_width"] = width
	active_effects[effect_id] = effect_data

	# 启动墙体生命周期
	_start_wall_lifecycle(effect_id)

	return effect_id

## 墙体受到伤害（外部调用，用于可破坏墙体）
func wall_take_damage(effect_id: int, damage: int) -> void:
	if not active_effects.has(effect_id):
		return
	var effect_data = active_effects[effect_id]
	if effect_data.get("type") != "wall":
		return
	if effect_data["health"] < 0:
		return  # 不可破坏

	effect_data["health"] -= damage
	if effect_data["health"] <= 0:
		_destroy_wall(effect_id)

## 启动墙体生命周期管理
func _start_wall_lifecycle(effect_id: int) -> void:
	if not active_effects.has(effect_id):
		return

	var effect_data = active_effects[effect_id]
	var static_body = effect_data["static_body"]

	var timer = Timer.new()
	timer.wait_time = 0.016  # ~60fps
	static_body.add_child(timer)

	timer.timeout.connect(func():
		_update_wall_effect(effect_id, timer.wait_time)
	)
	timer.start()

## 更新墙体效果
func _update_wall_effect(effect_id: int, delta: float) -> void:
	if not active_effects.has(effect_id):
		return

	var effect_data = active_effects[effect_id]
	var static_body = effect_data["static_body"]

	if not is_instance_valid(static_body):
		active_effects.erase(effect_id)
		return

	effect_data["elapsed"] += delta
	var duration = effect_data["config"].get("duration", 5.0)

	# 接触伤害 tick
	if effect_data.has("damage_area"):
		var damage_area: Area2D = effect_data["damage_area"]
		var contact_damage_val: int = effect_data["config"].get("contact_damage", 0)
		var contact_interval: float = effect_data["config"].get("contact_interval", 0.5)

		if is_instance_valid(damage_area) and contact_damage_val > 0:
			effect_data["contact_timer"] += delta
			if effect_data["contact_timer"] >= contact_interval:
				_apply_wall_contact_damage(damage_area, contact_damage_val)
				effect_data["contact_timer"] = 0.0

	# 阻挡敌人（Area2D 推回机制，因为敌人是 Area2D 不受 StaticBody2D 物理阻挡）
	if effect_data["config"].get("block_enemies", false) and effect_data.has("block_area"):
		var block_area: Area2D = effect_data["block_area"]
		if is_instance_valid(block_area):
			_push_enemies_from_wall(block_area, effect_data)

	# 持续时间到期 → 淡出并移除
	if effect_data["elapsed"] >= duration:
		_end_wall_effect(effect_id)

## 应用墙体接触伤害
func _apply_wall_contact_damage(damage_area: Area2D, damage: int) -> void:
	if not is_instance_valid(damage_area):
		return

	var targets = damage_area.get_overlapping_bodies() + damage_area.get_overlapping_areas()
	for t in targets:
		var enemy = null
		if t.is_in_group("enemies"):
			enemy = t
		elif t.owner and t.owner.is_in_group("enemies"):
			enemy = t.owner

		if enemy and is_instance_valid(enemy) and enemy.has_node("HealthComponent"):
			enemy.health_component.take_damage(damage)
			if DEBUG_VERBOSE:
				print("[SkillEffectManager] 墙体接触伤害: %d -> %s" % [damage, enemy.name])

## 将敌人推离墙体（Area2D 推回机制）
## 因为敌人是 Area2D 使用 position += 移动，StaticBody2D 无法物理阻挡
## 所以通过每帧检测重叠并推回来模拟阻挡效果
func _push_enemies_from_wall(block_area: Area2D, effect_data: Dictionary) -> void:
	if not is_instance_valid(block_area):
		return

	var wall_start: Vector2 = effect_data["wall_start"]
	var wall_end: Vector2 = effect_data["wall_end"]
	var wall_width: float = effect_data["wall_width"]

	var targets = block_area.get_overlapping_bodies() + block_area.get_overlapping_areas()
	for t in targets:
		var enemy = null
		if t.is_in_group("enemies"):
			enemy = t
		elif t.owner and t.owner.is_in_group("enemies"):
			enemy = t.owner

		if enemy and is_instance_valid(enemy):
			# 计算敌人到墙体线段的最近点
			var closest = Geometry2D.get_closest_point_to_segment(enemy.global_position, wall_start, wall_end)
			var to_enemy = enemy.global_position - closest
			var dist = to_enemy.length()

			# 如果敌人在墙体宽度内，推到墙体边缘外
			var push_dist = (wall_width / 2.0 + 16.0)  # 墙体半宽 + 缓冲（加大缓冲确保推出）
			if dist < push_dist:
				var push_dir: Vector2
				if dist > 0.1:
					push_dir = to_enemy.normalized()
				else:
					# 敌人几乎在墙体线上，使用墙体法线推开
					push_dir = effect_data["wall_normal"]
				enemy.global_position = closest + push_dir * push_dist
				# 仅首次推回时打印日志（避免刷屏）
				if not effect_data.has("_push_logged"):
					effect_data["_push_logged"] = true
					if DEBUG_VERBOSE:
						print("[SkillEffectManager] 墙体推回敌人: %s, dist=%.1f" % [enemy.name, dist])

## 墙体淡出并移除
func _end_wall_effect(effect_id: int) -> void:
	if not active_effects.has(effect_id):
		return

	var effect_data = active_effects[effect_id]
	var static_body = effect_data["static_body"]

	if not is_instance_valid(static_body):
		active_effects.erase(effect_id)
		return

	var fade_out_duration = effect_data["config"].get("fade_out_duration", 0.3)
	var vis_line = effect_data["vis_line"]

	if is_instance_valid(vis_line):
		var tween = static_body.create_tween()
		tween.tween_property(vis_line, "modulate:a", 0.0, fade_out_duration)
		tween.tween_callback(func():
			if is_instance_valid(static_body):
				static_body.queue_free()
			active_effects.erase(effect_id)
		)
	else:
		static_body.queue_free()
		active_effects.erase(effect_id)

## 立即销毁墙体（生命值归零时调用）
func _destroy_wall(effect_id: int) -> void:
	if not active_effects.has(effect_id):
		return

	var effect_data = active_effects[effect_id]
	var static_body = effect_data["static_body"]

	if is_instance_valid(static_body):
		# 快速闪烁后销毁
		var tween = static_body.create_tween()
		tween.tween_property(static_body, "modulate:a", 0.0, 0.15)
		tween.tween_callback(func():
			if is_instance_valid(static_body):
				static_body.queue_free()
			active_effects.erase(effect_id)
		)
	else:
		active_effects.erase(effect_id)

# ==============================================================================
# Buff 区域效果
# ==============================================================================

## 创建 Buff 区域效果（Area2D）
## @param config: 配置字典
##   - polygon: PackedVector2Array (多边形形状，与 start/end 二选一)
##   - start: Vector2 (线段型起点，与 polygon 二选一)
##   - end: Vector2 (线段型终点)
##   - width: float (线段型宽度，默认 24)
##   - duration: float (持续时间，默认 5.0)
##   - buff_type: String (必需) - Buff 类型:
##       "attack_boost", "speed_boost", "heal", "lifesteal",
##       "invincible", "cooldown_reduction", "ignore_collision"
##   - buff_value: float (Buff 数值，默认 0.0)
##   - tick_interval: float (效果触发间隔，默认 1.0)
##   - color: Color (区域颜色)
##   - target_group: String (目标组，默认 "player")
##   - fade_out_duration: float (淡出时间，默认 0.3)
## @return: effect_id, -1 表示失败
func create_buff_zone(config: Dictionary) -> int:
	# 验证必需参数
	var has_polygon = config.has("polygon")
	var has_line = config.has("start") and config.has("end")
	if not has_polygon and not has_line:
		push_error("[SkillEffectManager] create_buff_zone 缺少必需参数: polygon 或 start/end")
		return -1

	if has_polygon:
		config = _normalize_polygon_config(config, "create_buff_zone")
		if config.is_empty():
			return -1

	var effect_id = next_effect_id
	next_effect_id += 1

	var duration: float = config.get("duration", 5.0)
	var buff_type: String = config.get("buff_type", "")
	var buff_value: float = config.get("buff_value", 0.0)
	var tick_interval: float = config.get("tick_interval", 1.0)
	var color: Color = config.get("color", Color(0.3, 1.0, 0.3, 0.4))
	var target_group: String = config.get("target_group", "player")

	# --- Area2D 检测区域 ---
	var area = Area2D.new()
	area.name = "BuffZone_%d" % effect_id
	area.collision_layer = 0
	area.monitorable = false
	area.monitoring = true

	var effect_data = {
		"type": "buff_zone",
		"area": area,
		"config": config,
		"elapsed": 0.0,
		"buff_timer": max(tick_interval - 0.1, 0.0),
	}

	if has_polygon:
		# --- 多边形形状 ---
		var points: PackedVector2Array = config["polygon"]
		if points.size() < 3:
			push_error("[SkillEffectManager] create_buff_zone 多边形点数不足: %d" % points.size())
			return -1

		# 碰撞形状
		var col = CollisionPolygon2D.new()
		col.polygon = points
		area.add_child(col)

		# 视觉效果 - Polygon2D
		var vis_poly = Polygon2D.new()
		vis_poly.polygon = points
		vis_poly.color = color
		vis_poly.z_index = 5
		area.add_child(vis_poly)
		effect_data["vis_poly"] = vis_poly

		# 设置碰撞掩码检测 players 组
		area.collision_mask = 1  # Layer 1: players
	else:
		# --- 线段形状 ---
		var start: Vector2 = config["start"]
		var end_pos: Vector2 = config["end"]
		var width: float = config.get("width", 48.0)  # 默认48px宽，确保玩家容易触发

		area.position = start
		var vec = end_pos - start
		var length = vec.length()
		var angle = vec.angle()

		# 碰撞形状 - 比视觉宽度更大，确保检测可靠
		var col = CollisionShape2D.new()
		var shape = RectangleShape2D.new()
		shape.size = Vector2(length, width + 32.0)  # 碰撞比视觉宽32px
		col.shape = shape
		col.position = Vector2(length / 2.0, 0)
		col.rotation = angle
		area.add_child(col)

		# 视觉效果 - Line2D
		var vis_line = Line2D.new()
		vis_line.add_point(Vector2.ZERO)
		vis_line.add_point(vec)
		vis_line.width = width
		vis_line.default_color = color
		vis_line.begin_cap_mode = Line2D.LINE_CAP_ROUND
		vis_line.end_cap_mode = Line2D.LINE_CAP_ROUND
		vis_line.z_index = 5
		area.add_child(vis_line)
		effect_data["vis_line"] = vis_line

		# 设置碰撞掩码检测 players 组
		area.collision_mask = 1  # Layer 1: players

	# 添加到场景树（而非 SkillEffectManager 自身），确保 Area2D 物理检测正常工作
	var scene_root = get_tree().current_scene
	if scene_root:
		scene_root.add_child(area)
	else:
		add_child(area)

	active_effects[effect_id] = effect_data

	# 启动 Buff 区域生命周期
	_start_buff_zone_lifecycle(effect_id)

	return effect_id

## 启动 Buff 区域生命周期管理
func _start_buff_zone_lifecycle(effect_id: int) -> void:
	if not active_effects.has(effect_id):
		return

	var effect_data = active_effects[effect_id]
	var area = effect_data["area"]

	var timer = Timer.new()
	timer.wait_time = 0.016  # ~60fps
	area.add_child(timer)

	timer.timeout.connect(func():
		_update_buff_zone(effect_id, timer.wait_time)
	)
	timer.start()

## 更新 Buff 区域效果
func _update_buff_zone(effect_id: int, delta: float) -> void:
	if not active_effects.has(effect_id):
		return

	var effect_data = active_effects[effect_id]
	var area = effect_data["area"]

	if not is_instance_valid(area):
		active_effects.erase(effect_id)
		return

	effect_data["elapsed"] += delta
	var config = effect_data["config"]
	var duration: float = config.get("duration", 5.0)
	var tick_interval: float = config.get("tick_interval", 1.0)

	# Buff tick
	effect_data["buff_timer"] += delta
	if effect_data["buff_timer"] >= tick_interval:
		_apply_buff_to_targets(area, config)
		effect_data["buff_timer"] = 0.0

	# 持续时间到期 → 淡出并移除
	if effect_data["elapsed"] >= duration:
		_end_buff_zone(effect_id)

## 对区域内目标应用 Buff 效果
func _apply_buff_to_targets(area: Area2D, config: Dictionary) -> void:
	if not is_instance_valid(area):
		return

	var target_group: String = config.get("target_group", "player")
	var buff_type: String = config.get("buff_type", "")
	var buff_value: float = config.get("buff_value", 0.0)

	var overlapping_areas = area.get_overlapping_areas()
	var overlapping_bodies = area.get_overlapping_bodies()
	var targets = overlapping_bodies + overlapping_areas
	
	# 收集命中的玩家
	var hit_players: Array = []
	for t in targets:
		var player = null
		if t.is_in_group(target_group):
			player = t
		elif t.owner and t.owner.is_in_group(target_group):
			player = t.owner

		if player and is_instance_valid(player) and player not in hit_players:
			hit_players.append(player)

	# 备用方案：如果 Area2D 重叠检测未命中，使用距离检测
	# 这解决了 SkillEffectManager(Node) 作为父节点时 Area2D 物理检测可能不可靠的问题
	if hit_players.is_empty() and target_group == "player":
		var player = Global.player if is_instance_valid(Global.player) else null
		if player:
			# 计算玩家到 buff 区域的距离
			var in_range = false
			if config.has("polygon"):
				# 多边形：检查玩家是否在多边形内
				in_range = Geometry2D.is_point_in_polygon(player.global_position, config["polygon"])
			elif config.has("start") and config.has("end"):
				# 线段：检查玩家到线段的距离
				var closest = Geometry2D.get_closest_point_to_segment(
					player.global_position, config["start"], config["end"]
				)
				var dist = player.global_position.distance_to(closest)
				var width = config.get("width", 48.0)
				in_range = dist <= (width / 2.0 + 20.0)  # 线段半宽 + 玩家碰撞半径
			
			if in_range:
				hit_players.append(player)

	# 应用 Buff
	for player in hit_players:
		_apply_single_buff(player, buff_type, buff_value, config)

## 对单个目标应用 Buff
func _apply_single_buff(player: Node, buff_type: String, buff_value: float, config: Dictionary) -> void:
	match buff_type:
		"attack_boost":
			# 增加攻击力百分比
			if not player.has_meta("buff_attack_boost"):
				player.set_meta("buff_attack_boost", buff_value)
			else:
				# 刷新值（取较大值）
				var current = player.get_meta("buff_attack_boost")
				player.set_meta("buff_attack_boost", max(current, buff_value))

		"speed_boost":
			# 增加移动速度百分比
			if not player.has_meta("buff_speed_boost"):
				player.set_meta("buff_speed_boost", buff_value)
				if DEBUG_VERBOSE:
					print("[SkillEffectManager] Buff区域命中: speed_boost -> %s (+%.0f%%)" % [player.name, buff_value * 100])
			else:
				var current = player.get_meta("buff_speed_boost")
				player.set_meta("buff_speed_boost", max(current, buff_value))

		"heal":
			# 恢复生命值
			if player.has_node("HealthComponent"):
				player.health_component.heal(int(buff_value))
			elif "hp" in player:
				player.hp = min(player.hp + int(buff_value), player.max_hp)

		"lifesteal":
			# 设置生命偷取百分比
			player.set_meta("buff_lifesteal", buff_value)

		"invincible":
			# 无敌状态
			player.set_meta("buff_invincible", true)

		"cooldown_reduction":
			# 减少冷却百分比
			player.set_meta("buff_cooldown_reduction", buff_value)

		"ignore_collision":
			# 忽略单位碰撞
			player.set_meta("buff_ignore_collision", true)

## 清除单个目标上的 Buff meta
func _clear_buff_meta(player: Node, buff_type: String) -> void:
	if not is_instance_valid(player):
		return

	match buff_type:
		"attack_boost":
			if player.has_meta("buff_attack_boost"):
				player.remove_meta("buff_attack_boost")
		"speed_boost":
			if player.has_meta("buff_speed_boost"):
				player.remove_meta("buff_speed_boost")
		"lifesteal":
			if player.has_meta("buff_lifesteal"):
				player.remove_meta("buff_lifesteal")
		"invincible":
			if player.has_meta("buff_invincible"):
				player.remove_meta("buff_invincible")
		"cooldown_reduction":
			if player.has_meta("buff_cooldown_reduction"):
				player.remove_meta("buff_cooldown_reduction")
		"ignore_collision":
			if player.has_meta("buff_ignore_collision"):
				player.remove_meta("buff_ignore_collision")
		# "heal" 不需要清除 meta，因为它是即时效果

## 清除区域内所有目标的 Buff
func _clear_buff_zone_buffs(area: Area2D, config: Dictionary) -> void:
	var target_group: String = config.get("target_group", "player")
	var buff_type: String = config.get("buff_type", "")

	# 尝试通过 Area2D 重叠检测清除
	if is_instance_valid(area):
		var targets = area.get_overlapping_bodies() + area.get_overlapping_areas()
		for t in targets:
			var player = null
			if t.is_in_group(target_group):
				player = t
			elif t.owner and t.owner.is_in_group(target_group):
				player = t.owner

			if player and is_instance_valid(player):
				_clear_buff_meta(player, buff_type)

	# 备用：直接清除 Global.player 的 buff meta（确保不会残留）
	if target_group == "player":
		var player = Global.player if is_instance_valid(Global.player) else null
		if player:
			_clear_buff_meta(player, buff_type)

## Buff 区域淡出并移除
func _end_buff_zone(effect_id: int) -> void:
	if not active_effects.has(effect_id):
		return

	var effect_data = active_effects[effect_id]
	var area = effect_data["area"]
	var config = effect_data["config"]

	if not is_instance_valid(area):
		active_effects.erase(effect_id)
		return

	# 清除区域内所有目标的 Buff meta
	_clear_buff_zone_buffs(area, config)

	var fade_out_duration = config.get("fade_out_duration", 0.3)

	# 淡出视觉效果
	if effect_data.has("vis_poly"):
		var vis_poly = effect_data["vis_poly"]
		if is_instance_valid(vis_poly):
			var tween = area.create_tween()
			tween.tween_property(vis_poly, "modulate:a", 0.0, fade_out_duration)
			tween.tween_callback(func():
				if is_instance_valid(area):
					area.queue_free()
				active_effects.erase(effect_id)
			)
			return

	if effect_data.has("vis_line"):
		var vis_line = effect_data["vis_line"]
		if is_instance_valid(vis_line):
			var tween = area.create_tween()
			tween.tween_property(vis_line, "modulate:a", 0.0, fade_out_duration)
			tween.tween_callback(func():
				if is_instance_valid(area):
					area.queue_free()
				active_effects.erase(effect_id)
			)
			return

	# 没有视觉元素，直接删除
	area.queue_free()
	active_effects.erase(effect_id)

# ==============================================================================
# Debuff 区域效果
# ==============================================================================

## 创建 Debuff 区域效果（Area2D）
## @param config: 配置字典
##   - polygon: PackedVector2Array (多边形形状，与 start/end 二选一)
##   - start: Vector2 (线段型起点，与 polygon 二选一)
##   - end: Vector2 (线段型终点)
##   - width: float (线段型宽度，默认 24)
##   - duration: float (持续时间，默认 5.0)
##   - debuff_type: String (必需) - Debuff 类型:
##       "slow", "damage_amp", "poison", "freeze", "fear", "curse"
##   - debuff_value: float (Debuff 数值，默认 0.0)
##   - debuff_duration: float (单次 Debuff 持续时间，默认 3.0)
##   - tick_interval: float (效果触发间隔，默认 1.0)
##   - damage: int (可选) - 区域伤害
##   - damage_interval: float (可选) - 伤害间隔
##   - color: Color (区域颜色)
##   - fade_out_duration: float (淡出时间，默认 0.3)
## @return: effect_id, -1 表示失败
func create_debuff_zone(config: Dictionary) -> int:
	config = _apply_runtime_damage_multiplier(config)
	# 验证必需参数
	var has_polygon = config.has("polygon")
	var has_line = config.has("start") and config.has("end")
	if not has_polygon and not has_line:
		push_error("[SkillEffectManager] create_debuff_zone 缺少必需参数: polygon 或 start/end")
		return -1

	if DEBUG_VERBOSE:
		print("[SkillEffectManager] create_debuff_zone 被调用: type=%s, debuff=%s, damage=%d" % [
		"polygon" if has_polygon else "line",
		config.get("debuff_type", "none"),
		config.get("damage", 0)
	])

	if has_polygon:
		config = _normalize_polygon_config(config, "create_debuff_zone")
		if config.is_empty():
			return -1

	var effect_id = next_effect_id
	next_effect_id += 1

	var duration: float = config.get("duration", 5.0)
	var tick_interval: float = config.get("tick_interval", 1.0)
	var color: Color = config.get("color", Color(0.8, 0.2, 0.2, 0.4))

	# --- Area2D 检测区域 ---
	var area = Area2D.new()
	area.name = "DebuffZone_%d" % effect_id
	area.collision_layer = 0
	area.collision_mask = 1 | 2  # 检测 Layer1(Player/Enemy默认) + Layer2(Enemy标记)
	area.monitorable = false
	area.monitoring = true

	var effect_data = {
		"type": "debuff_zone",
		"area": area,
		"config": config,
		"elapsed": 0.0,
		"debuff_timer": max(tick_interval - 0.1, 0.0),  # 首次 debuff 在 ~0.1秒后触发（给物理引擎时间注册重叠）
	}

	if has_polygon:
		# --- 多边形形状 ---
		var points: PackedVector2Array = config["polygon"]
		if points.size() < 3:
			push_error("[SkillEffectManager] create_debuff_zone 多边形点数不足: %d" % points.size())
			return -1

		# 碰撞形状
		var col = CollisionPolygon2D.new()
		col.polygon = points
		area.add_child(col)

		# 视觉效果 - Polygon2D
		var vis_poly = Polygon2D.new()
		vis_poly.polygon = points
		vis_poly.color = color
		vis_poly.z_index = 5
		area.add_child(vis_poly)
		effect_data["vis_poly"] = vis_poly
	else:
		# --- 线段形状 ---
		var start: Vector2 = config["start"]
		var end_pos: Vector2 = config["end"]
		var width: float = config.get("width", 24.0)

		area.position = start
		var vec = end_pos - start
		var length = vec.length()
		var angle = vec.angle()

		# 碰撞形状
		var col = CollisionShape2D.new()
		var shape = RectangleShape2D.new()
		shape.size = Vector2(length, width)
		col.shape = shape
		col.position = Vector2(length / 2.0, 0)
		col.rotation = angle
		area.add_child(col)

		# 视觉效果 - Line2D
		var vis_line = Line2D.new()
		vis_line.add_point(Vector2.ZERO)
		vis_line.add_point(vec)
		vis_line.width = width
		vis_line.default_color = color
		vis_line.begin_cap_mode = Line2D.LINE_CAP_ROUND
		vis_line.end_cap_mode = Line2D.LINE_CAP_ROUND
		vis_line.z_index = 5
		area.add_child(vis_line)
		effect_data["vis_line"] = vis_line

	# 初始化可选的区域伤害计时器
	if config.get("damage", 0) > 0:
		effect_data["damage_timer"] = 0.0

	# 添加到 SkillEffectManager 自身（autoload 节点，角色切换不影响）
	add_child(area)

	active_effects[effect_id] = effect_data

	# 启动 Debuff 区域生命周期
	_start_debuff_zone_lifecycle(effect_id)

	return effect_id

## 启动 Debuff 区域生命周期管理
func _start_debuff_zone_lifecycle(effect_id: int) -> void:
	if not active_effects.has(effect_id):
		return

	var effect_data = active_effects[effect_id]
	var area = effect_data["area"]

	var timer = Timer.new()
	timer.wait_time = 0.016  # ~60fps
	area.add_child(timer)

	timer.timeout.connect(func():
		_update_debuff_zone(effect_id, timer.wait_time)
	)
	timer.start()

## 更新 Debuff 区域效果
func _update_debuff_zone(effect_id: int, delta: float) -> void:
	if not active_effects.has(effect_id):
		return

	var effect_data = active_effects[effect_id]
	var area = effect_data["area"]

	if not is_instance_valid(area):
		active_effects.erase(effect_id)
		return

	effect_data["elapsed"] += delta
	var config = effect_data["config"]
	var duration: float = config.get("duration", 5.0)
	var tick_interval: float = config.get("tick_interval", 1.0)

	# Debuff tick
	effect_data["debuff_timer"] += delta
	if effect_data["debuff_timer"] >= tick_interval:
		_apply_debuff_to_targets(area, config)
		effect_data["debuff_timer"] = 0.0

	# 可选的区域伤害 tick（独立于 debuff tick）
	if effect_data.has("damage_timer"):
		var damage_interval: float = config.get("damage_interval", 0.5)
		effect_data["damage_timer"] += delta
		if effect_data["damage_timer"] >= damage_interval:
			_apply_damage(area, config.get("damage", 0))
			effect_data["damage_timer"] = 0.0

	# 持续时间到期 → 淡出并移除
	if effect_data["elapsed"] >= duration:
		_end_debuff_zone(effect_id)

## 对区域内敌人应用 Debuff 效果
func _apply_debuff_to_targets(area: Area2D, config: Dictionary) -> void:
	if not is_instance_valid(area):
		return

	var debuff_type: String = config.get("debuff_type", "")
	var debuff_value: float = config.get("debuff_value", 0.0)
	var debuff_duration: float = config.get("debuff_duration", 3.0)

	var targets = area.get_overlapping_bodies() + area.get_overlapping_areas()
	for t in targets:
		var enemy = null
		if t.is_in_group("enemies"):
			enemy = t
		elif t.owner and t.owner.is_in_group("enemies"):
			enemy = t.owner

		if enemy and is_instance_valid(enemy) and enemy.has_method("apply_status"):
			if DEBUG_VERBOSE:
				print("[SkillEffectManager] Debuff区域命中: %s -> %s (type=%s)" % [debuff_type, enemy.name, enemy.get_class()])
			_apply_single_debuff(enemy, debuff_type, debuff_value, debuff_duration)

## 对单个敌人应用 Debuff
func _apply_single_debuff(enemy: Node, debuff_type: String, debuff_value: float, debuff_duration: float) -> void:
	match debuff_type:
		"slow":
			# 减速 - debuff_value 为减速比例（如 0.5 = 50% 减速）
			enemy.apply_status("slow", debuff_duration, debuff_value)
		"damage_amp":
			# 伤害放大 - 使用 "marked" 状态
			enemy.apply_status("marked", debuff_duration, debuff_value)
		"poison":
			# 中毒 - DOT 伤害
			enemy.apply_status("poison", debuff_duration, debuff_value, 1, 1.0)
		"freeze":
			# 冰冻 - 完全停止移动和攻击
			enemy.apply_status("freeze", debuff_duration, debuff_value)
		"fear":
			# 恐惧 - 逃跑行为，需要 tick 更新移动方向
			enemy.apply_status("fear", debuff_duration, debuff_value, 1, 0.1)
		"curse":
			# 诅咒 - DOT 伤害，类似 poison
			enemy.apply_status("curse", debuff_duration, debuff_value, 1, 1.0)

## Debuff 区域淡出并移除
func _end_debuff_zone(effect_id: int) -> void:
	if not active_effects.has(effect_id):
		return

	var effect_data = active_effects[effect_id]
	var area = effect_data["area"]
	var config = effect_data["config"]

	if not is_instance_valid(area):
		active_effects.erase(effect_id)
		return

	var fade_out_duration = config.get("fade_out_duration", 0.3)

	# 淡出视觉效果
	if effect_data.has("vis_poly"):
		var vis_poly = effect_data["vis_poly"]
		if is_instance_valid(vis_poly):
			var tween = area.create_tween()
			tween.tween_property(vis_poly, "modulate:a", 0.0, fade_out_duration)
			tween.tween_callback(func():
				if is_instance_valid(area):
					area.queue_free()
				active_effects.erase(effect_id)
			)
			return

	if effect_data.has("vis_line"):
		var vis_line = effect_data["vis_line"]
		if is_instance_valid(vis_line):
			var tween = area.create_tween()
			tween.tween_property(vis_line, "modulate:a", 0.0, fade_out_duration)
			tween.tween_callback(func():
				if is_instance_valid(area):
					area.queue_free()
				active_effects.erase(effect_id)
			)
			return

	# 没有视觉元素，直接删除
	area.queue_free()
	active_effects.erase(effect_id)

# ==============================================================================
# 召唤物管理
# ==============================================================================

## 创建召唤物
## @param config: 配置字典
##   - position: Vector2 (必需) - 生成位置
##   - summon_type: String (必需) - 召唤物类型 ("turret", "beetle", "slime", "phantom")
##   - duration: float (必需) - 存活时间
##   - health: int (可选, 默认 -1) - 生命值，-1 为无限
##   - damage: int (可选, 默认 10) - 攻击伤害
##   - attack_interval: float (可选, 默认 1.0) - 攻击间隔
##   - attack_range: float (可选, 默认 200.0) - 攻击范围
##   - max_count: int (可选, 默认 5) - 同技能最大数量
##   - owner_skill_id: String (必需) - 所属技能 ID
##   - color: Color (可选) - 占位颜色
## @return: effect_id, -1 表示失败
func create_summon(config: Dictionary) -> int:
	# 验证必需参数
	if not config.has("position"):
		push_error("[SkillEffectManager] create_summon 缺少必需参数: position")
		return -1
	if not config.has("owner_skill_id"):
		push_error("[SkillEffectManager] create_summon 缺少必需参数: owner_skill_id")
		return -1

	var owner_skill_id: String = config["owner_skill_id"]
	var max_count: int = config.get("max_count", 5)

	# --- max_count 限制：移除最早的召唤物 ---
	_enforce_summon_max_count(owner_skill_id, max_count)

	var effect_id = next_effect_id
	next_effect_id += 1

	var pos: Vector2 = config["position"]
	var summon_type: String = config.get("summon_type", "turret")
	var duration: float = config.get("duration", 10.0)
	var damage: int = config.get("damage", 10)
	var attack_interval: float = config.get("attack_interval", 1.0)
	var attack_range: float = config.get("attack_range", 200.0)
	var color: Color = config.get("color", Color(0.4, 0.8, 1.0, 0.8))

	# 根据类型决定视觉半径
	var visual_radius: float = 16.0
	if summon_type in ["beetle", "slime"]:
		visual_radius = 10.0

	# --- 创建召唤物根节点 ---
	var summon_root = Node2D.new()
	summon_root.name = "Summon_%s_%d" % [summon_type, effect_id]
	summon_root.global_position = pos

	# --- Area2D 用于敌人检测 ---
	var detect_area = Area2D.new()
	detect_area.name = "DetectArea"
	detect_area.collision_layer = 0
	detect_area.collision_mask = 1 | 2  # 检测 Layer1(Player/Enemy默认) + Layer2(Enemy标记)
	detect_area.monitorable = false
	detect_area.monitoring = true

	# 检测范围碰撞形状（圆形，attack_range）
	var detect_col = CollisionShape2D.new()
	var detect_shape = CircleShape2D.new()
	detect_shape.radius = attack_range
	detect_col.shape = detect_shape
	detect_area.add_child(detect_col)
	summon_root.add_child(detect_area)

	# --- Polygon2D 彩色圆形占位视觉 ---
	var vis_poly = Polygon2D.new()
	var circle_points = PackedVector2Array()
	var num_segments = 14
	for i in range(num_segments):
		var angle = (float(i) / num_segments) * TAU
		circle_points.append(Vector2(cos(angle), sin(angle)) * visual_radius)
	vis_poly.polygon = circle_points
	vis_poly.color = color
	vis_poly.z_index = 10
	summon_root.add_child(vis_poly)

	# 添加到 SkillEffectManager 自身（角色切换不影响）
	add_child(summon_root)

	# --- 保存效果数据 ---
	var effect_data = {
		"type": "summon",
		"node": summon_root,
		"detect_area": detect_area,
		"vis_poly": vis_poly,
		"config": config,
		"elapsed": 0.0,
		"attack_timer": 0.0,
		"owner_skill_id": owner_skill_id,
		"focus_target": null,  # 用于 focus_fire 指令
	}
	active_effects[effect_id] = effect_data

	# 启动召唤物生命周期
	_start_summon_lifecycle(effect_id)

	return effect_id

## 向指定技能的所有召唤物发送指令
## @param owner_skill_id: String - 所属技能 ID
## @param command: String - 指令: "focus_fire", "self_destruct", "return"
## @param target: Node2D (可选) - 目标节点（用于 focus_fire）
func command_summons(owner_skill_id: String, command: String, target: Node2D = null) -> void:
	var summon_ids = _get_summon_ids_by_skill(owner_skill_id)
	if summon_ids.is_empty():
		return

	match command:
		"focus_fire":
			for eid in summon_ids:
				if active_effects.has(eid):
					active_effects[eid]["focus_target"] = target
		"self_destruct":
			for eid in summon_ids:
				_self_destruct_summon(eid)
		"return":
			# 预留：召唤物返回玩家身边
			pass

## 获取指定技能的所有召唤物 effect_id 列表（按创建顺序）
func _get_summon_ids_by_skill(owner_skill_id: String) -> Array:
	var ids: Array = []
	for eid in active_effects.keys():
		var data = active_effects[eid]
		if data.get("type") == "summon" and data.get("owner_skill_id") == owner_skill_id:
			ids.append(eid)
	ids.sort()  # effect_id 递增，排序即为创建顺序
	return ids

## 强制执行 max_count 限制
func _enforce_summon_max_count(owner_skill_id: String, max_count: int) -> void:
	var existing_ids = _get_summon_ids_by_skill(owner_skill_id)
	# 如果已达上限，移除最早的召唤物（可能需要移除多个）
	while existing_ids.size() >= max_count and not existing_ids.is_empty():
		var oldest_id = existing_ids[0]
		_remove_summon(oldest_id)
		existing_ids.remove_at(0)

## 启动召唤物生命周期管理
func _start_summon_lifecycle(effect_id: int) -> void:
	if not active_effects.has(effect_id):
		return

	var effect_data = active_effects[effect_id]
	var summon_node = effect_data["node"]

	var timer = Timer.new()
	timer.wait_time = 0.016  # ~60fps
	summon_node.add_child(timer)

	timer.timeout.connect(func():
		_update_summon(effect_id, timer.wait_time)
	)
	timer.start()

## 更新召唤物逻辑
func _update_summon(effect_id: int, delta: float) -> void:
	if not active_effects.has(effect_id):
		return

	var effect_data = active_effects[effect_id]
	var summon_node = effect_data["node"]

	if not is_instance_valid(summon_node):
		active_effects.erase(effect_id)
		return

	effect_data["elapsed"] += delta
	var config = effect_data["config"]
	var duration: float = config.get("duration", 10.0)

	# 持续时间到期 → 移除
	if effect_data["elapsed"] >= duration:
		_end_summon(effect_id)
		return

	# --- 攻击逻辑 ---
	var attack_interval: float = config.get("attack_interval", 1.0)
	effect_data["attack_timer"] += delta
	if effect_data["attack_timer"] >= attack_interval:
		_summon_attack(effect_id)
		effect_data["attack_timer"] = 0.0

## 召唤物攻击逻辑
func _summon_attack(effect_id: int) -> void:
	if not active_effects.has(effect_id):
		return

	var effect_data = active_effects[effect_id]
	var summon_node = effect_data["node"]
	var detect_area: Area2D = effect_data["detect_area"]
	var config = effect_data["config"]
	var damage: int = config.get("damage", 10)
	var summon_type: String = config.get("summon_type", "turret")

	if not is_instance_valid(summon_node) or not is_instance_valid(detect_area):
		return

	# 幻影类型：嘲讽范围内所有敌人（每次攻击 tick 刷新仇恨）
	if summon_type == "phantom":
		_phantom_taunt_enemies(effect_data, detect_area, summon_node)

	# 查找目标：优先 focus_target，否则最近敌人
	var target_enemy = _find_summon_target(effect_data, detect_area, summon_node)
	if target_enemy == null:
		return

	# 造成伤害
	if target_enemy.has_node("HealthComponent"):
		target_enemy.health_component.take_damage(damage)

	# 攻击视觉反馈：短暂闪白
	var vis_poly = effect_data["vis_poly"]
	if is_instance_valid(vis_poly):
		var original_color = vis_poly.color
		vis_poly.color = Color.WHITE
		var tween = summon_node.create_tween()
		tween.tween_property(vis_poly, "color", original_color, 0.15)

## 查找召唤物攻击目标
func _find_summon_target(effect_data: Dictionary, detect_area: Area2D, summon_node: Node2D) -> Node:
	# 优先使用 focus_fire 指定的目标
	var focus_target = effect_data.get("focus_target")
	if focus_target != null and is_instance_valid(focus_target):
		# focus_fire 模式：攻击距离 target 最近的敌人
		var nearest_enemy = null
		var nearest_dist = INF
		var targets = detect_area.get_overlapping_bodies() + detect_area.get_overlapping_areas()
		for t in targets:
			var enemy = _resolve_enemy(t)
			if enemy:
				var dist = focus_target.global_position.distance_to(enemy.global_position)
				if dist < nearest_dist:
					nearest_dist = dist
					nearest_enemy = enemy
		return nearest_enemy

	# 默认：攻击范围内最近敌人
	var nearest_enemy = null
	var nearest_dist = INF
	var targets = detect_area.get_overlapping_bodies() + detect_area.get_overlapping_areas()
	for t in targets:
		var enemy = _resolve_enemy(t)
		if enemy:
			var dist = summon_node.global_position.distance_to(enemy.global_position)
			if dist < nearest_dist:
				nearest_dist = dist
				nearest_enemy = enemy
	return nearest_enemy

## 幻影嘲讽：让范围内敌人攻击幻影分身而非玩家
func _phantom_taunt_enemies(effect_data: Dictionary, detect_area: Area2D, summon_node: Node2D) -> void:
	if not is_instance_valid(detect_area) or not is_instance_valid(summon_node):
		return
	var targets = detect_area.get_overlapping_bodies() + detect_area.get_overlapping_areas()
	for t in targets:
		var enemy = _resolve_enemy(t)
		if enemy and enemy.has_method("set_taunt_target"):
			# 只嘲讽那些还没被嘲讽到这个幻影的敌人，或者 override_target 已失效的
			if not is_instance_valid(enemy.override_target) or enemy.override_target != summon_node:
				enemy.set_taunt_target(summon_node)

## 从碰撞目标解析出敌人节点
func _resolve_enemy(target: Node) -> Node:
	if target.is_in_group("enemies") and is_instance_valid(target):
		return target
	if target.owner and target.owner.is_in_group("enemies") and is_instance_valid(target.owner):
		return target.owner
	return null

## 召唤物自爆
func _self_destruct_summon(effect_id: int) -> void:
	if not active_effects.has(effect_id):
		return

	var effect_data = active_effects[effect_id]
	var summon_node = effect_data["node"]
	var detect_area: Area2D = effect_data["detect_area"]
	var config = effect_data["config"]
	var damage: int = config.get("damage", 10) * 2  # 自爆伤害 = 2x 普通伤害

	if not is_instance_valid(summon_node) or not is_instance_valid(detect_area):
		_remove_summon(effect_id)
		return

	# 对范围内所有敌人造成爆炸伤害
	var targets = detect_area.get_overlapping_bodies() + detect_area.get_overlapping_areas()
	for t in targets:
		var enemy = _resolve_enemy(t)
		if enemy and enemy.has_node("HealthComponent"):
			enemy.health_component.take_damage(damage)

	# 爆炸视觉反馈：快速放大 + 淡出
	var vis_poly = effect_data["vis_poly"]
	if is_instance_valid(vis_poly):
		vis_poly.color = Color(1.0, 0.5, 0.0, 1.0)  # 橙色爆炸
		var tween = summon_node.create_tween()
		tween.tween_property(summon_node, "scale", Vector2(2.5, 2.5), 0.15)
		tween.parallel().tween_property(vis_poly, "modulate:a", 0.0, 0.15)
		tween.tween_callback(func():
			_remove_summon(effect_id)
		)
	else:
		_remove_summon(effect_id)

## 召唤物到期淡出移除
func _end_summon(effect_id: int) -> void:
	if not active_effects.has(effect_id):
		return

	var effect_data = active_effects[effect_id]
	var summon_node = effect_data["node"]

	if not is_instance_valid(summon_node):
		active_effects.erase(effect_id)
		return

	var vis_poly = effect_data["vis_poly"]
	if is_instance_valid(vis_poly):
		var tween = summon_node.create_tween()
		tween.tween_property(vis_poly, "modulate:a", 0.0, 0.3)
		tween.tween_callback(func():
			_remove_summon(effect_id)
		)
	else:
		_remove_summon(effect_id)

## 立即移除召唤物
func _remove_summon(effect_id: int) -> void:
	if not active_effects.has(effect_id):
		return

	var effect_data = active_effects[effect_id]
	var summon_node = effect_data["node"]
	var summon_type: String = effect_data["config"].get("summon_type", "turret")

	# 幻影消失时清除所有被嘲讽到它的敌人的 override_target
	if summon_type == "phantom" and is_instance_valid(summon_node):
		var enemies = get_tree().get_nodes_in_group("enemies")
		for enemy in enemies:
			if is_instance_valid(enemy) and "override_target" in enemy:
				if enemy.override_target == summon_node:
					enemy.override_target = null

	if is_instance_valid(summon_node):
		summon_node.queue_free()
	active_effects.erase(effect_id)

# ==============================================================================
# 生命周期管理
# ==============================================================================

## 启动效果生命周期管理
func _start_effect_lifecycle(effect_id: int) -> void:
	if not active_effects.has(effect_id):
		return
	
	var effect_data = active_effects[effect_id]
	var area = effect_data["area"]
	var config = effect_data["config"]
	
	# 创建管理 Timer
	var timer = Timer.new()
	timer.wait_time = 0.016  # ~60fps
	area.add_child(timer)
	
	timer.timeout.connect(func():
		_update_effect(effect_id, timer.wait_time)
	)
	
	timer.start()

## 更新效果
func _update_effect(effect_id: int, delta: float) -> void:
	if not active_effects.has(effect_id):
		return
	
	var effect_data = active_effects[effect_id]
	var area = effect_data["area"]
	var config = effect_data["config"]
	
	if not is_instance_valid(area):
		active_effects.erase(effect_id)
		return
	
	effect_data["elapsed"] += delta
	var duration = config.get("duration", 5.0)
	
	# 伤害 tick
	if config.get("damage", 0) > 0:
		if not effect_data.has("damage_timer"):
			effect_data["damage_timer"] = 0.0
		
		effect_data["damage_timer"] += delta
		var damage_interval = config.get("damage_interval", 0.5)
		
		if effect_data["damage_timer"] >= damage_interval:
			_apply_damage(area, config.get("damage", 0))
			effect_data["damage_timer"] = 0.0
	
	# 物理效果 tick
	if config.get("pull_to_center", false):
		if not effect_data.has("pull_timer"):
			effect_data["pull_timer"] = 0.0
		
		effect_data["pull_timer"] += delta
		var pull_interval = config.get("pull_interval", 0.05)
		
		if effect_data["pull_timer"] >= pull_interval:
			_apply_pull_to_center(area, effect_data["center"], config.get("pull_force", 0), pull_interval)
			effect_data["pull_timer"] = 0.0
	
	elif config.get("pull_to_line", false):
		if not effect_data.has("pull_timer"):
			effect_data["pull_timer"] = 0.0
		
		effect_data["pull_timer"] += delta
		var pull_interval = config.get("pull_interval", 0.05)
		
		if effect_data["pull_timer"] >= pull_interval:
			_apply_pull_to_line(area, effect_data["start"], effect_data["end"], config.get("pull_force", 0), pull_interval)
			effect_data["pull_timer"] = 0.0
	
	# 生命周期结束
	if effect_data["elapsed"] >= duration:
		_end_effect(effect_id)

## 应用伤害
func _apply_damage(area: Area2D, damage: int) -> void:
	if not is_instance_valid(area):
		return
	
	var targets = area.get_overlapping_bodies() + area.get_overlapping_areas()
	for t in targets:
		var enemy = null
		if t.is_in_group("enemies"):
			enemy = t
		elif t.owner and t.owner.is_in_group("enemies"):
			enemy = t.owner
		
		if enemy and enemy.has_node("HealthComponent"):
			enemy.health_component.take_damage(damage)

## 应用吸附到中心
func _apply_pull_to_center(area: Area2D, center: Vector2, force: float, dt: float) -> void:
	if not is_instance_valid(area):
		return
	
	var targets = area.get_overlapping_bodies() + area.get_overlapping_areas()
	for t in targets:
		var enemy = null
		if t.is_in_group("enemies"):
			enemy = t
		elif t.owner and t.owner.is_in_group("enemies"):
			enemy = t.owner
		
		if is_instance_valid(enemy):
			var dir = (center - enemy.global_position).normalized()
			enemy.global_position += dir * force * dt

## 应用吸附到线段
func _apply_pull_to_line(area: Area2D, start: Vector2, end: Vector2, force: float, dt: float) -> void:
	if not is_instance_valid(area):
		return
	
	var targets = area.get_overlapping_bodies() + area.get_overlapping_areas()
	for t in targets:
		var enemy = null
		if t.is_in_group("enemies"):
			enemy = t
		elif t.owner and t.owner.is_in_group("enemies"):
			enemy = t.owner
		
		if is_instance_valid(enemy):
			var closest_point = Geometry2D.get_closest_point_to_segment(enemy.global_position, start, end)
			var dist = enemy.global_position.distance_to(closest_point)
			
			if dist > 5.0:
				var dir = (closest_point - enemy.global_position).normalized()
				enemy.global_position += dir * force * dt

## 结束效果
func _end_effect(effect_id: int) -> void:
	if not active_effects.has(effect_id):
		return
	
	var effect_data = active_effects[effect_id]
	var area = effect_data["area"]
	var config = effect_data["config"]
	
	if not is_instance_valid(area):
		active_effects.erase(effect_id)
		return
	
	# 淡出动画
	var fade_out_duration = config.get("fade_out_duration", 0.3)
	
	if effect_data.has("vis_poly"):
		var vis_poly = effect_data["vis_poly"]
		if is_instance_valid(vis_poly):
			var tween = area.create_tween()
			tween.tween_property(vis_poly, "modulate:a", 0.0, fade_out_duration)
			tween.tween_callback(func():
				if is_instance_valid(area):
					area.queue_free()
				active_effects.erase(effect_id)
			)
			return
	
	if effect_data.has("vis_line"):
		var vis_line = effect_data["vis_line"]
		if is_instance_valid(vis_line):
			var tween = area.create_tween()
			tween.tween_property(vis_line, "modulate:a", 0.0, fade_out_duration)
			tween.tween_callback(func():
				if is_instance_valid(area):
					area.queue_free()
				active_effects.erase(effect_id)
			)
			return
	
	# 没有视觉元素，直接删除
	area.queue_free()
	active_effects.erase(effect_id)

# ==============================================================================
# 手动控制
# ==============================================================================

## 手动移除效果
func remove_effect(effect_id: int) -> void:
	if active_effects.has(effect_id):
		var effect_data = active_effects[effect_id]
		# Buff 区域需要先清除目标上的 meta
		if effect_data.get("type") == "buff_zone" and effect_data.has("area"):
			_clear_buff_zone_buffs(effect_data["area"], effect_data["config"])
		# 召唤物使用专用移除方法
		if effect_data.get("type") == "summon":
			_remove_summon(effect_id)
			return
		var node_key = "area"
		if effect_data.get("type") == "wall":
			node_key = "static_body"
		elif effect_data.get("type") == "debuff_zone":
			node_key = "area"
		if effect_data.has(node_key) and is_instance_valid(effect_data[node_key]):
			effect_data[node_key].queue_free()
		active_effects.erase(effect_id)

## 清理所有效果
func clear_all_effects() -> void:
	for effect_id in active_effects.keys():
		remove_effect(effect_id)
