extends SkillBase
class_name SkillDrawingBase

## ==============================================================================

## ==============================================================================
## 
## 鍔熻兘璇存槑:


## - 瀛愮被鍙渶瀹炵幇鍏蜂綋鐨勮瑙夋晥鏋滃拰鎵ц閫昏緫
## 
## 浣跨敤鏂规硶:



## 
## ==============================================================================

# ==============================================================================

# ==============================================================================

# 字段定义
var energy_per_10px: float = 1.0

# 字段定义
var energy_threshold_distance: float = 1800.0

## 鑳介噺閫掑绯绘暟
var energy_scale_multiplier: float = 0.0005

# 字段定义
var close_threshold: float = 60.0

# 字段定义
const POINT_INTERVAL: float = 10.0

# 字段定义
var base_line_duration: float = 5.0

# Q->E/F 联动上下文（统一键）
const Q_CTX_META_CENTER: String = "q_ctx_last_center"
const Q_CTX_META_RADIUS: String = "q_ctx_last_radius"
const Q_CTX_META_TIME_MSEC: String = "q_ctx_last_time_msec"
const Q_CTX_META_CLOSED: String = "q_ctx_last_closed"
const Q_CTX_META_SEGMENTS: String = "q_ctx_last_segments"
const Q_CTX_META_POLYGONS: String = "q_ctx_last_polygons"

# 兼容旧 E 原型键（避免已有逻辑失效）
const Q_CTX_LEGACY_CENTER: String = "q_proto_last_center"
const Q_CTX_LEGACY_RADIUS: String = "q_proto_last_radius"
const Q_CTX_LEGACY_TIME_MSEC: String = "q_proto_last_time_msec"

# ==============================================================================
# 閻㈣崵鍤庨幎鈧懗鍊熺箥鐞涘本妞傞悩鑸碘偓?
# ==============================================================================

# 字段定义
var is_planning: bool = false

## 鏄惁姝ｅ湪鍒掔嚎
var is_drawing: bool = false

# 字段定义
var last_point: Vector2 = Vector2.ZERO

# 字段定义
var last_gold_spawn_pos: Vector2 = Vector2.ZERO

# 字段定义
const GOLD_SPAWN_DISTANCE: float = 100.0

# 字段定义
var accumulated_distance: float = 0.0

# 字段定义
var path_points: Array[Vector2] = []

## 璺緞绾挎鍒楄〃锛堢敤浜庝氦鍙夋娴嬶級
var path_segments: Array[Dictionary] = []
var _pending_open_asset_payload: Dictionary = {}

## death_brush 鑺傛祦璁℃椂鍣紙閬垮厤姣忓抚楂橀鎵弿锛?
var _death_brush_tick_cooldown: float = 0.0

# 字段定义
var has_closure: bool = false

# 字段定义
var total_distance_drawn: float = 0.0

# 字段定义
var has_shown_no_energy_hint: bool = false

# 字段定义
var line_2d: Line2D

# ==============================================================================

# ==============================================================================


## @param start: 绾挎璧风偣
# 函数：_spawn_line_effect
func _spawn_line_effect(start: Vector2, end: Vector2) -> void:
	push_warning("[SkillDrawingBase] _spawn_line_effect() 閺堫亜鐤勯悳? %s" % skill_id)


## @param line_area: 绾挎鐨凙rea2D鑺傜偣
func _add_thorns_wall_effect(line_area: Area2D) -> void:
	"""Add thorns-wall effect hook for line segments."""
	if not BondManager.has_mechanic("thorns_wall"):
		return
	
	if not is_instance_valid(skill_owner):
		return
	
	# 字段定义
	var player_damage = skill_owner.damage if "damage" in skill_owner else 10.0
	var thorns_damage = player_damage * 0.3
	
	print("[%s] [P2-2] 閸欏秳婵€婢ф瑦绺哄ú? 娴笺倕顔?%.0f (閻溾晛顔嶉弨璇插毊閸旀稓娈?0%%)" % [skill_id, thorns_damage])
	
	# 条件判断
	if not line_area.body_entered.is_connected(_on_thorns_wall_hit):
		line_area.body_entered.connect(_on_thorns_wall_hit.bind(thorns_damage))
	if not line_area.area_entered.is_connected(_on_thorns_wall_area_hit):
		line_area.area_entered.connect(_on_thorns_wall_area_hit.bind(thorns_damage))
	SoundManager.play("bond_thorns_wall")

# 函数：_on_thorns_wall_hit
func _on_thorns_wall_hit(body: Node2D, thorns_damage: float) -> void:
	if body.is_in_group("enemies"):
		_apply_thorns_damage(body, thorns_damage)

# 函数：_on_thorns_wall_area_hit
func _on_thorns_wall_area_hit(area: Area2D, thorns_damage: float) -> void:
	if area.owner and area.owner.is_in_group("enemies"):
		_apply_thorns_damage(area.owner, thorns_damage)

## P2-2: 搴旂敤鍙嶄激浼ゅ
func _apply_thorns_damage(enemy: Node2D, thorns_damage: float) -> void:
	if not is_instance_valid(enemy):
		return
	
	if enemy.has_node("HealthComponent"):
		enemy.get_node("HealthComponent").take_damage(int(thorns_damage), {
			"source": skill_owner,
			"kind": "bond_thorns_wall",
			"damage_type": "DMG_DIRECT",
		})
		Global.spawn_floating_text(enemy.global_position, "THORNS!", Color(0.8, 0.4, 0.0))
		print("[%s] [P2-2] 反伤命中: %s, damage=%.0f" % [skill_id, enemy.name, thorns_damage])

## 鐢熸垚鍖哄煙鏁堟灉锛堥棴鍚堢姸鎬侊級
# 函数：_spawn_area_effect
func _spawn_area_effect(polygon: PackedVector2Array) -> void:
	push_warning("[SkillDrawingBase] _spawn_area_effect() not implemented for %s" % skill_id)


## @return: 搴旂敤鍔犳垚鍚庣殑浼ゅ
func _apply_ink_inherit_bonus(base_damage: float, show_feedback: bool = true) -> float:
	# 应用图形继承羁绊带来的额外伤害，返回最终伤害。
	if not BondManager.has_mechanic("ink_inherit"):
		return base_damage
	
	# 字段定义
	var bonus_multiplier = BondManager.get_mechanic_value("ink_inherit")
	if bonus_multiplier <= 0:
		return base_damage
	
	# 字段定义
	# 字段定义
	var final_damage = base_damage * (1.0 + bonus_multiplier)
	
	if show_feedback:
		print("[%s] [P4-2] 閸ユ儳鑸扮紒褎澹欓崝鐘冲灇: %.0f -> %.0f (+%.0f%%)" % [
			skill_id,
			base_damage,
			final_damage,
			bonus_multiplier * 100
		])
		# 瑙嗚鍙嶉
		if is_instance_valid(skill_owner):
			Global.spawn_floating_text(skill_owner.global_position, "INK INHERIT!", Color(0.5, 1.5, 2.0))
	
	return final_damage

# 函数：_add_curse_stacking_effect
# 函数：_add_curse_stacking_effect
# 函数：_add_curse_stacking_effect
func _add_curse_stacking_effect(area: Area2D, polygon: PackedVector2Array) -> void:
	"""Add curse stacking effect for closed areas."""
	if not BondManager.has_mechanic("curse_stack"):
		return
	
	if not is_instance_valid(area):
		return
	
	print("[%s] [P2-4] curse stacking activated" % skill_id)
	
	# 鍒涘缓璇呭拻璁℃椂鍣紙姣忕瑙﹀彂涓拷娆★級
	var curse_timer = Timer.new()
	curse_timer.name = "CurseStackTimer"
	curse_timer.wait_time = 1.0
	curse_timer.one_shot = false
	area.add_child(curse_timer)
	
	# 璇呭拻浼ゅ鍊硷紙姣忓眰姣忕閫犳垚鐨勪激瀹筹級
	var curse_damage_per_stack = 2.0
	
	curse_timer.timeout.connect(func():
		if not is_instance_valid(area) or area.is_queued_for_deletion():
			curse_timer.stop()
			return
		
		# 妫拷娴嬫墍鏈夊湪鍖哄煙鍐呯殑鏁屼汉
		var enemies = area.get_overlapping_bodies() + area.get_overlapping_areas()
		
		for target in enemies:
			var enemy = null
			
			if target.is_in_group("enemies"):
				enemy = target
			elif target.owner and target.owner.is_in_group("enemies"):
				enemy = target.owner
			
			if is_instance_valid(enemy) and enemy.has_method("apply_status"):


				enemy.apply_status("curse", 5.0, curse_damage_per_stack, 1, 1.0)
				print("[%s] [P2-4] 鐎?%s 閸欑姴濮炵拠鍛嫽" % [skill_id, enemy.name])
	)
	
	curse_timer.start()
	print("[%s] [P2-4] 鐠囧懎鎷荤拋鈩冩閸ｃ劌鍑￠崥顖氬З" % skill_id)


## @return: 绾挎潯棰滆壊
func _get_line_color() -> Color:
	# 榛樿鐧借壊锛屽瓙绫诲彲閲嶅啓
	return Color.WHITE

# 函数：_get_closure_color
# 函数：_get_closure_color
func _get_closure_color() -> Color:
	# 姒涙顓荤痪銏ｅ
	return Color(2.0, 0.1, 0.1, 1.0)

# ==============================================================================

# ==============================================================================

func _calculate_closed_shape_damage(base_damage: float, show_log: bool = true) -> float:
	var final_damage = base_damage
	
	# 条件判断
	if BondManager.has_mechanic("closed_shape_dmg"):
		var bonus = BondManager.get_mechanic_value("closed_shape_dmg")
		final_damage *= (1.0 + bonus)
		if show_log:
			print("[%s] [P0-1] 闭合伤害加成: %.0f -> %.0f (+%.0f%%)" % [
				skill_id, 
				base_damage, 
				final_damage, 
				bonus * 100
			])
	
	return final_damage

func _get_runtime_effect_damage_multiplier(is_closed_path: bool) -> float:
	var multiplier: float = 1.0
	multiplier *= _get_ultimate_runtime_damage_amp(is_closed_path)
	if is_closed_path:
		multiplier = _calculate_closed_shape_damage(multiplier, false)
	multiplier = _apply_ink_inherit_bonus(multiplier, false)
	return max(0.0, multiplier)

func _get_ultimate_runtime_damage_amp(is_closed_path: bool) -> float:
	if not is_instance_valid(skill_owner):
		return 1.0
	if not skill_owner.has_meta("f_runtime_profile"):
		return 1.0

	var profile_data: Variant = skill_owner.get_meta("f_runtime_profile")
	if not (profile_data is Dictionary):
		return 1.0

	var profile: Dictionary = profile_data
	if not bool(profile.get("active", false)):
		return 1.0

	var key := "q_closure_amp" if is_closed_path else "q_line_amp"
	var amp := float(profile.get(key, 1.0))
	return max(0.1, amp)

func _push_runtime_effect_damage_multiplier(is_closed_path: bool) -> void:
	var multiplier: float = _get_runtime_effect_damage_multiplier(is_closed_path)
	if SkillEffectManager and SkillEffectManager.has_method("push_damage_multiplier"):
		SkillEffectManager.push_damage_multiplier(multiplier)

func _pop_runtime_effect_damage_multiplier() -> void:
	if SkillEffectManager and SkillEffectManager.has_method("pop_damage_multiplier"):
		SkillEffectManager.pop_damage_multiplier()

# 函数：_get_line_duration
# 函数：_get_line_duration
func _get_line_duration() -> float:
	var duration = base_line_duration
	
	# 条件判断
	if BondManager.has_mechanic("line_duration"):
		var bonus = BondManager.get_mechanic_value("line_duration")
		duration += bonus
		print("[%s] [P0-2] 线段持续加成: %.1fs -> %.1fs (+%.1fs)" % [
			skill_id,
			base_line_duration,
			duration,
			bonus
		])
	
	return duration


## @return: 搴旂敤鍔犳垚鍚庣殑瀹归敊璺濈锛堝儚绱狅級
func _get_closure_tolerance() -> float:
	var tolerance = close_threshold
	
	# 条件判断
	if BondManager.has_mechanic("shape_tolerance"):
		var level = BondManager.get_mechanic_value("shape_tolerance")
		# 姣忕骇澧炲姞15鍍忕礌瀹归敊
		var bonus = level * 15.0
		tolerance += bonus
		print("[%s] [P0-3] 闭合容差加成: %.0fpx -> %.0fpx (+%.0fpx)" % [
			skill_id,
			close_threshold,
			tolerance,
			bonus
		])
	
	return tolerance


## @param base_damage: 閸╄櫣顢呮导銈咁唺閸?
# 函数：_apply_speed_damage_bonus
func _apply_speed_damage_bonus(base_damage: float) -> float:
	if not skill_owner or not skill_owner.has_method("get_speed_damage_bonus"):
		return base_damage
	
	var speed_bonus = skill_owner.get_speed_damage_bonus()
	if speed_bonus <= 0:
		return base_damage
	
	var final_damage = base_damage * (1.0 + speed_bonus)
	
	print("[%s] [P1-3] 闁喎瀹虫潪顑挎縺鐎瑰啿绨查悽? %.0f -> %.0f (+%.1f%%)" % [
		skill_id,
		base_damage,
		final_damage,
		speed_bonus * 100
	])
	
	return final_damage


## @param current_pos: 褰撳墠浣嶇疆
func _check_and_spawn_gold_trail(current_pos: Vector2) -> void:
	# 条件判断
	if not BondManager.has_mechanic("gold_trail"):
		return
	
	# 字段定义
	var distance_from_last = current_pos.distance_to(last_gold_spawn_pos)
	if distance_from_last < GOLD_SPAWN_DISTANCE:
		return
	
	# 鐢熸垚閲戝竵
	var gold_amount = int(BondManager.get_mechanic_value("gold_trail"))
	if gold_amount <= 0:
		gold_amount = 1  # 榛樿1閲戝竵
	
	# 鐢熸垚閲戝竵瀹炰綋
	Global.spawn_coin(current_pos, gold_amount)
	SoundManager.play("bond_gold_trail")
	print("[%s] [P1-4] 闁叉垵绔垫潪銊ㄦ姉鐟欙箑褰? 閻㈢喐鍨?d闁叉垵绔?at (%.0f, %.0f)" % [
		skill_id,
		gold_amount,
		current_pos.x,
		current_pos.y
	])
	# 瑙嗚鍙嶉
	Global.spawn_floating_text(current_pos, "GOLD!", Color.GOLD)
	

	last_gold_spawn_pos = current_pos

# ==============================================================================

# ==============================================================================

# 函数：_trigger_chain_reaction
# 函数：_trigger_chain_reaction
# 函数：_trigger_chain_reaction
func _trigger_chain_reaction(polygon: PackedVector2Array, main_damage: int) -> void:
	"""对区域外敌人触发链式伤害。"""
	if not BondManager.has_mechanic("chain_reaction"):
		return
	
	# 字段定义
	var all_enemies = get_tree().get_nodes_in_group("enemies")
	if all_enemies.is_empty():
		return
	
	# 字段定义
	var outside_enemies = []
	for enemy in all_enemies:
		if not is_instance_valid(enemy):
			continue
		
		# 条件判断
		if not Geometry2D.is_point_in_polygon(enemy.global_position, polygon):
			outside_enemies.append(enemy)
	
	# 字段定义
	const MAX_CHAIN_TARGETS = 50
	if outside_enemies.size() > MAX_CHAIN_TARGETS:
		outside_enemies.shuffle()
		outside_enemies = outside_enemies.slice(0, MAX_CHAIN_TARGETS)
	
	if outside_enemies.is_empty():
		return
	
	# 字段定义
	var chain_damage = int(main_damage * 0.3)
	
	print("[%s] [P3-1] 链式反应触发: 目标=%d, 伤害=%d" % [
		skill_id,
		outside_enemies.size(),
		chain_damage
	])
	SoundManager.play("bond_chain_reaction")
	
	# 鐎佃鐦℃稉顏呮櫕娴滄椽鈧姵鍨氭导銈咁唺楠炶埖鎸遍弨鍓у閺?
	for enemy in outside_enemies:
		if not is_instance_valid(enemy):
			continue
		
		# 閫犳垚浼ゅ
		if enemy.has_node("HealthComponent"):
			enemy.get_node("HealthComponent").take_damage(chain_damage, {
				"source": skill_owner,
				"kind": "bond_chain_reaction",
				"damage_type": "DMG_AOE",
			})
		
		# 瑙嗚鍙嶉锛氬皬鐖嗙偢鐗规晥
		Global.spawn_floating_text(enemy.global_position, "CHAIN!", Color(2.0, 0.8, 0.0))
		

		_spawn_mini_explosion(enemy.global_position)

# 函数：_spawn_mini_explosion
func _spawn_mini_explosion(pos: Vector2) -> void:
	"""在指定位置生成小爆炸特效。"""
	const DEFAULT_EXPLOSION = preload("uid://dvfjoyutjx5jf")
	
	if not DEFAULT_EXPLOSION:
		return
	
	var vfx = DEFAULT_EXPLOSION.instantiate()
	vfx.global_position = pos
	vfx.scale = Vector2(0.5, 0.5)
	vfx.z_index = 100
	
	get_tree().current_scene.call_deferred("add_child", vfx)
	
	# 鑷姩娓呯悊 - 浣跨敤 weakref 閬垮厤 lambda capture freed 閿欒
	var vfx_ref = weakref(vfx)
	var cleanup_timer = get_tree().create_timer(1.0)
	cleanup_timer.timeout.connect(func():
		var v = vfx_ref.get_ref()
		if v and is_instance_valid(v):
			v.queue_free()
	)

## P3-2: 濮橀晲绠欓悧銏㈩儣閿涘牏鐡氭晶娆掆偓?Lv.3閿?
## @param area: 鍖哄煙鏁堟灉鑺傜偣
# 函数：_apply_permanent_cage
func _apply_permanent_cage(area: Area2D, polygon: PackedVector2Array) -> void:
	"""灏嗛棴鍚堝尯鍩熻浆鎹负姘镐箙鐗㈢锛堥樆鎸℃晫浜虹Щ鍔級"""
	if not BondManager.has_mechanic("permanent_cage"):
		return
	
	if not is_instance_valid(area):
		return
	
	print("[%s] [P3-2] permanent cage activated" % skill_id)
	SoundManager.play("bond_permanent_cage")
	
	# 瑙嗚鍙嶉
	var center = _calculate_polygon_center(polygon)
	Global.spawn_floating_text(center, "CAGE!", Color(0.5, 0.5, 1.0))
	
	# 字段定义
	var cage = StaticBody2D.new()
	cage.name = "PermanentCage"
	cage.collision_layer = 4  # 閻欘剛鐝涚喊鐗堟寬鐏?
	cage.collision_mask = 1 | 2
	
	# 娣诲姞纰版挒褰㈢姸
	var col = CollisionPolygon2D.new()
	col.polygon = polygon
	col.build_mode = CollisionPolygon2D.BUILD_SEGMENTS
	cage.add_child(col)
	
	# 瑙嗚鏁堟灉锛氬崐閫忔槑澧欎綋
	var vis = Line2D.new()
	for p in polygon:
		vis.add_point(p)
	vis.add_point(polygon[0])
	vis.width = 8.0
	vis.default_color = Color(0.5, 0.5, 1.0, 0.6)
	vis.z_index = 5
	cage.add_child(vis)
	

	get_tree().current_scene.add_child(cage)
	
	# 鐗㈢绠＄悊锛氶檺鍒舵暟閲忔垨鏃堕棿
	_manage_cage_lifecycle(cage)
	
	print("[%s] [P3-2] 閻椼垻顑楀鑼晸閹存劧绱濇担宥囩枂: (%.0f, %.0f)" % [
		skill_id,
		polygon[0].x,
		polygon[0].y
	])

## P3-2: 绠＄悊鐗㈢鐢熷懡鍛ㄦ湡
func _manage_cage_lifecycle(cage: StaticBody2D) -> void:
	"""管理牢笼生命周期（时间或数量上限）。"""
	const MAX_CAGES = 5
	const CAGE_LIFETIME = 15.0
	
	# 条件判断
	if not get_tree().current_scene.has_meta("active_cages"):
		get_tree().current_scene.set_meta("active_cages", [])
	
	var active_cages: Array = get_tree().current_scene.get_meta("active_cages")
	
	# 娓呯悊鏃犳晥鐗㈢
	var valid_cages = []
	for c in active_cages:
		if is_instance_valid(c):
			valid_cages.append(c)
	active_cages = valid_cages
	
	# 濡傛灉瓒呰繃鏁伴噺闄愬埗锛岀Щ闄ゆ渶鏃╃殑鐗㈢
	if active_cages.size() >= MAX_CAGES:
		var oldest_cage = active_cages[0]
		if is_instance_valid(oldest_cage):
			_remove_cage(oldest_cage)
		active_cages.remove_at(0)
	

	active_cages.append(cage)
	get_tree().current_scene.set_meta("active_cages", active_cages)
	
	# 字段定义
	var lifetime_timer = Timer.new()
	lifetime_timer.wait_time = CAGE_LIFETIME
	lifetime_timer.one_shot = true
	cage.add_child(lifetime_timer)
	
	var cage_ref = weakref(cage)
	lifetime_timer.timeout.connect(func():
		var c = cage_ref.get_ref()
		if c and is_instance_valid(c):
			# 娣″嚭鍔ㄧ敾
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

## P3-2: 绉婚櫎鐗㈢
func _remove_cage(cage: StaticBody2D) -> void:
	"""Remove cage with a fade-out transition."""
	if not is_instance_valid(cage):
		return
	
	# 娣″嚭鍔ㄧ敾
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



## @param base_damage: 鍩虹浼ゅ
## @return: 搴旂敤鏆村嚮鍚庣殑浼ゅ
func _apply_small_shape_crit(polygon: PackedVector2Array, base_damage: float) -> float:
	"""Check polygon area and trigger small-shape critical."""
	if not BondManager.has_mechanic("small_shape_crit"):
		return base_damage
	
	# 字段定义
	var area = _calculate_polygon_area(polygon)
	
	# 字段定义
	const AREA_THRESHOLD = 15000.0
	
	# 条件判断
	if area < AREA_THRESHOLD:
		var crit_damage = base_damage * 2.0
		SoundManager.play("bond_small_shape_crit")
		
		print("[%s] [P3-3] 小图形暴击: area=%.2f (threshold=%.2f), damage %.0f -> %.0f" % [
			skill_id,
			area,
			AREA_THRESHOLD,
			base_damage,
			crit_damage
		])
		
		# 瑙嗚鍙嶉
		var center = _calculate_polygon_center(polygon)
		Global.spawn_floating_text(center, "CRITICAL!", Color(2.0, 2.0, 0.0))
		Global.on_camera_shake.emit(10.0, 0.2)
		
		return crit_damage
	else:
		print("[%s] [P3-3] area=%.2f (threshold=%.2f) -> no critical" % [
			skill_id,
			area,
			AREA_THRESHOLD
		])
		return base_damage

# 函数：_calculate_polygon_area
func _calculate_polygon_area(polygon: PackedVector2Array) -> float:
	"""Compute polygon area with shoelace formula."""
	if polygon.size() < 3:
		return 0.0
	
	var area = 0.0
	var n = polygon.size()
	
	for i in range(n):
		var j = (i + 1) % n
		area += polygon[i].x * polygon[j].y
		area -= polygon[j].x * polygon[i].y
	
	return abs(area) / 2.0

# 函数：_calculate_polygon_center
func _calculate_polygon_center(polygon: PackedVector2Array) -> Vector2:
	"""计算多边形几何中心。"""
	if polygon.is_empty():
		return Vector2.ZERO
	
	var center = Vector2.ZERO
	for p in polygon:
		center += p
	return center / polygon.size()

func _calculate_polygon_radius(polygon: PackedVector2Array, center: Vector2) -> float:
	if polygon.is_empty():
		return 120.0
	var radius: float = 0.0
	for point: Vector2 in polygon:
		radius = float(max(radius, center.distance_to(point)))
	return float(max(60.0, radius))

# ==============================================================================
# 鐢熷懡鍛ㄦ湡
# ==============================================================================

func _ready() -> void:
	super._ready()
	
	print("[SkillDrawingBase] _ready(): %s, skill_owner=%s" % [skill_id, skill_owner])
	
	if skill_owner:

		line_2d = Line2D.new()
		line_2d.name = "DrawingPlanningLine"
		line_2d.width = 4.0
		
		# 字段定义
		var player_node = skill_owner
		if skill_owner is Area2D:
			player_node = skill_owner.get_parent()
		if player_node:
			player_node.add_child(line_2d)
		else:
			skill_owner.add_child(line_2d)
		
		line_2d.top_level = true
		line_2d.global_position = Vector2.ZERO
		line_2d.clear_points()
		line_2d.default_color = _get_line_color()
		print("[SkillDrawingBase] Line2D 创建成功: %s" % skill_id)
	else:
		print("[SkillDrawingBase] warning: skill_owner 为空，无法创建 Line2D: %s" % skill_id)

func _process(delta: float) -> void:
	super._process(delta)
	if _death_brush_tick_cooldown > 0.0:
		_death_brush_tick_cooldown = max(0.0, _death_brush_tick_cooldown - delta)

	_update_visuals()

# ==============================================================================

# ==============================================================================

# 函数：charge
func charge(delta: float) -> void:
	if not is_planning:
		_enter_planning_mode()
	
	if is_planning:
		var left_pressed: bool = Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
		if (
			not left_pressed
			and Global != null
			and Global.has_meta("qef_test_mode_active")
			and bool(Global.get_meta("qef_test_mode_active"))
		):
			left_pressed = Input.is_action_pressed("click_left")
		# 条件判断
		if left_pressed:
			if not is_drawing:
				_start_drawing()
			
			_continue_drawing()
		else:
			# 榧犳爣宸﹂敭鏉惧紑
			if is_drawing:
				is_drawing = false
		
		if Input.is_action_just_pressed("click_right"):
			_clear_all_points(false)

# 函数：release
func release() -> void:
	if is_planning:
		_exit_planning_mode_and_execute()

# ==============================================================================
# 瑙勫垝妯″紡绠＄悊
# ==============================================================================

# 函数：_enter_planning_mode
func _enter_planning_mode() -> void:
	is_planning = true
	is_charging = true
	is_drawing = false
	accumulated_distance = 0.0
	has_closure = false
	total_distance_drawn = 0.0
	has_shown_no_energy_hint = false
	
	# 娓呯┖璺緞鏁版嵁
	path_points.clear()
	path_segments.clear()
	
	# 字段定义
	var start_pos = skill_owner.get_global_mouse_position()
	path_points.append(start_pos)
	last_point = start_pos
	
	print("[%s] ===== 鏉╂稑鍙嗙憴鍕灊濡€崇础 ===== 鐠ч鍋? %s, line_2d閺堝鏅? %s" % [skill_id, start_pos, is_instance_valid(line_2d)])
	
	SoundManager.play("skill_q_planning")

# 函数：_exit_planning_mode_and_execute
func _exit_planning_mode_and_execute() -> void:
	is_planning = false
	is_charging = false
	is_drawing = false
	
	print("[%s] ===== 退出规划模式 ===== 点数: %d, 闭合: %s" % [skill_id, path_points.size(), has_closure])
	
	if path_points.size() > 1:
		_perform_final_closure_check()
		
		print("[%s] 最终闭合判定: %s" % [skill_id, has_closure])
		
		# 条件判断
		if has_closure:
			_execute_closed_path()
		else:
			_execute_open_path()
		
		_cache_draw_snapshot()
		
		start_cooldown()
		_clear_all_points(false)
	else:
		print("[%s] 鐠侯垰绶為悙閫涚瑝鐡掔绱濈捄瀹犵箖閹笛嗩攽" % skill_id)
		_clear_all_points(false)

func cancel_planning_state(refund_energy: bool = false) -> void:
	is_planning = false
	is_charging = false
	is_drawing = false
	if is_instance_valid(line_2d):
		line_2d.clear_points()
	_clear_all_points(refund_energy)

# 函数：_execute_closed_path
func _execute_closed_path() -> void:
	# 条件判断
	if skill_owner and "player_id" in skill_owner:
		SoundManager.play_character_q_closure(skill_owner.player_id)
	else:
		SoundManager.play("skill_q_closure_generic")
	
	# P0-3: 浣跨敤缇佺粖鍔犳垚鍚庣殑瀹归敊璺濈
	var tolerance = _get_closure_tolerance()
	var polygons = PolygonUtils.find_all_closing_polygons(path_points, tolerance)
	
	var context_center: Vector2 = _calculate_points_center(path_points)
	var context_radius: float = _calculate_points_radius(path_points, context_center)
	var max_area: float = 0.0

	if polygons.size() > 0:
		print("[%s] detected %d closed polygons" % [skill_id, polygons.size()])

		var primary_polygon: PackedVector2Array = polygons[0]
		max_area = _calculate_polygon_area(primary_polygon)
		for poly_obj: Variant in polygons:
			if not (poly_obj is PackedVector2Array):
				continue
			var poly: PackedVector2Array = poly_obj
			var area: float = _calculate_polygon_area(poly)
			if area > max_area:
				max_area = area
				primary_polygon = poly
		context_center = _calculate_polygon_center(primary_polygon)
		context_radius = _calculate_polygon_radius(primary_polygon, context_center)

		# 字段定义
		var mask_color = _get_closure_color()
		mask_color.a = 0.7
		PolygonUtils.show_closure_masks(polygons, mask_color, get_tree(), 0.6)

		for polygon in polygons:
			# 瀛愮被瀹炵幇鍏蜂綋鏁堟灉
			_push_runtime_effect_damage_multiplier(true)
			_spawn_area_effect(polygon)
			_pop_runtime_effect_damage_multiplier()
			_apply_polygon_effect(polygon)

			var main_damage: int = _estimate_closed_shape_damage(polygon)
			_trigger_secondary_explode(polygon, main_damage)
			_trigger_chain_reaction(polygon, main_damage)

	_cache_q_execution_context(true, path_points.size(), polygons.size(), context_center, context_radius)
	_notify_ultimate_path_executed(true, path_points.size(), polygons.size())
	if is_instance_valid(skill_owner) and skill_owner.has_method("notify_space_draw_release"):
		skill_owner.notify_space_draw_release({
			"source": "space",
			"skill_id": skill_id,
			"is_closed": true,
			"points": path_points.duplicate(),
			"centroid": context_center,
			"approx_area": max_area,
			"draw_cost": _calculate_total_consumed_energy(),
			"polygon_count": polygons.size(),
		})

## 閹笛嗩攽瀵偓閺€鎹愮熅瀵?
func _execute_open_path() -> void:
	if path_points.size() < 2:
		print("[%s] path too short, skip open-path execution" % skill_id)
		return
	
	SoundManager.play("skill_q_open_execute")
	
	# 字段定义
	# 字段定义
	const MERGE_DISTANCE: float = 100.0  # 姣忔鐩爣闀垮害
	
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
	
	print("[%s] 閻㈢喐鍨氬鈧弨鎹愮熅瀵板嫭鏅ラ弸婊愮礉閸樼喎顫愰悙瑙勬殶: %d, 閸氬牆鑻熺痪鎸庮唽閺? %d" % [skill_id, path_points.size(), merged_segments.size()])
	_pending_open_asset_payload = _build_open_path_asset_payload(merged_segments)
	var line_duration: float = _get_line_duration()
	var context_center: Vector2 = _calculate_points_center(path_points)
	var context_radius: float = _calculate_points_radius(path_points, context_center)
	
	for seg in merged_segments:
		_push_runtime_effect_damage_multiplier(false)
		_spawn_line_effect(seg["start"], seg["end"])
		_pop_runtime_effect_damage_multiplier()
		_spawn_thorns_wall_trigger(seg["start"], seg["end"], line_duration)
	
	print("[%s] open-path effects spawned" % skill_id)
	_cache_q_execution_context(false, merged_segments.size(), 0, context_center, context_radius)
	_notify_ultimate_path_executed(false, merged_segments.size(), 0)
	if is_instance_valid(skill_owner) and skill_owner.has_method("notify_space_draw_release"):
		skill_owner.notify_space_draw_release({
			"source": "space",
			"skill_id": skill_id,
			"is_closed": false,
			"points": path_points.duplicate(),
			"centroid": context_center,
			"approx_area": 0.0,
			"draw_cost": _calculate_total_consumed_energy(),
			"segment_count": merged_segments.size(),
		})

func _notify_ultimate_path_executed(is_closed: bool, segment_count: int, polygon_count: int) -> void:
	if not is_instance_valid(skill_owner):
		return
	if not skill_owner.has_method("notify_q_path_executed"):
		return
	skill_owner.notify_q_path_executed(is_closed, segment_count, polygon_count)

func _spawn_thorns_wall_trigger(start: Vector2, end_pos: Vector2, duration: float) -> void:
	if not BondManager.has_mechanic("thorns_wall"):
		return
	var tree: SceneTree = get_tree()
	if not tree or not tree.current_scene:
		return

	var seg: Vector2 = end_pos - start
	var length: float = seg.length()
	if length <= 1.0:
		return

	var line_area := Area2D.new()
	line_area.collision_layer = 0
	line_area.collision_mask = 1 | 2
	line_area.monitorable = false
	line_area.monitoring = true
	line_area.global_position = start

	var col := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(length, 24.0)
	col.shape = shape
	col.position = Vector2(length / 2.0, 0.0)
	col.rotation = seg.angle()
	line_area.add_child(col)

	tree.current_scene.add_child(line_area)
	_add_thorns_wall_effect(line_area)

	var area_ref: WeakRef = weakref(line_area)
	tree.create_timer(max(0.1, duration)).timeout.connect(func() -> void:
		var area_obj: Object = area_ref.get_ref()
		if area_obj and is_instance_valid(area_obj):
			var area_node: Node = area_obj as Node
			if area_node:
				area_node.queue_free()
	)

func _estimate_closed_shape_damage(polygon: PackedVector2Array) -> int:
	var base_damage: float = 20.0
	if is_instance_valid(skill_owner) and ("damage" in skill_owner):
		base_damage = float(skill_owner.damage)
	var final_damage: float = _calculate_closed_shape_damage(base_damage, false)
	final_damage = _apply_ink_inherit_bonus(final_damage, false)
	final_damage = _apply_small_shape_crit(polygon, final_damage)
	return max(1, int(round(final_damage)))

func _build_open_path_asset_payload(merged_segments: Array[Dictionary]) -> Dictionary:
	var payload: Dictionary = {
		"is_closed": false,
		"segments": [],
		"aabb": Rect2(),
	}
	if merged_segments.is_empty():
		return payload
	
	var first_start: Vector2 = (merged_segments[0] as Dictionary).get("start", Vector2.ZERO)
	var asset_rect := Rect2(first_start, Vector2.ZERO)
	var serialized_segments: Array[Dictionary] = []
	for seg_var: Variant in merged_segments:
		if not (seg_var is Dictionary):
			continue
		var seg: Dictionary = seg_var
		var start: Vector2 = seg.get("start", Vector2.ZERO)
		var end_pos: Vector2 = seg.get("end", Vector2.ZERO)
		var seg_rect: Rect2 = _build_segment_aabb(start, end_pos)
		asset_rect = asset_rect.merge(seg_rect)
		serialized_segments.append({
			"start": start,
			"end": end_pos,
			"aabb": seg_rect,
		})
	
	payload["aabb"] = asset_rect
	payload["segments"] = serialized_segments
	if path_points.size() >= 2:
		payload["path_start"] = path_points[0]
		payload["path_end"] = path_points[path_points.size() - 1]
	return payload

func _build_segment_aabb(start: Vector2, end_pos: Vector2, padding: float = 0.0) -> Rect2:
	var min_x: float = min(start.x, end_pos.x)
	var min_y: float = min(start.y, end_pos.y)
	var max_x: float = max(start.x, end_pos.x)
	var max_y: float = max(start.y, end_pos.y)
	var rect := Rect2(Vector2(min_x, min_y), Vector2(max_x - min_x, max_y - min_y))
	return rect.grow(max(0.0, padding))

func _get_pending_q_asset_payload(is_closed_path: bool) -> Dictionary:
	if is_closed_path:
		return {}
	return _pending_open_asset_payload.duplicate(true)

func _trigger_secondary_explode(polygon: PackedVector2Array, main_damage: int) -> void:
	if not BondManager.has_mechanic("secondary_explode"):
		return
	if polygon.size() < 3:
		return

	var ratio: float = max(0.1, float(BondManager.get_mechanic_value("secondary_explode")))
	var splash_damage: int = max(1, int(round(float(main_damage) * 0.35 * ratio)))
	var hit_count: int = 0
	var enemies: Array = get_tree().get_nodes_in_group("enemies")

	for enemy in enemies:
		if not is_instance_valid(enemy) or not enemy.has_node("HealthComponent"):
			continue
		if not Geometry2D.is_point_in_polygon(enemy.global_position, polygon):
			continue
		var hc: Variant = enemy.get_node("HealthComponent")
		hc.take_damage(splash_damage, {
			"source": skill_owner,
			"kind": "bond_secondary_explode",
			"damage_type": "DMG_AOE",
		})
		Global.spawn_floating_text(enemy.global_position, "SECOND!", Color(2.0, 1.1, 0.2))
		hit_count += 1

	if hit_count > 0:
		SoundManager.play("bond_trigger_generic")

# ==============================================================================
# 鍒掔嚎閫昏緫
# ==============================================================================

## 瀵偓婵鍨濈痪?
func _start_drawing() -> void:
	is_drawing = true
	SoundManager.play("skill_q_draw_start")
	var mouse_pos = skill_owner.get_global_mouse_position()
	
	path_points.clear()
	path_segments.clear()
	_pending_open_asset_payload.clear()
	has_closure = false
	accumulated_distance = 0.0
	total_distance_drawn = 0.0
	
	path_points.append(mouse_pos)
	last_point = mouse_pos
	has_shown_no_energy_hint = false
	
	# P1-4: 閲嶇疆閲戝竵鐢熸垚浣嶇疆
	last_gold_spawn_pos = mouse_pos

# 函数：_continue_drawing
func _continue_drawing() -> void:
	var mouse_pos = skill_owner.get_global_mouse_position()
	var distance = last_point.distance_to(mouse_pos)
	
	# 条件判断
	if distance < 1.0:
		return
	
	# 字段定义
	var points_to_add = int(distance / POINT_INTERVAL)
	
	# 循环处理
	for i in range(points_to_add):
		# 字段定义
		var current_energy_cost = _calculate_current_energy_cost()
		
		# 条件判断
		if skill_owner.energy >= current_energy_cost:

			skill_owner.consume_energy(current_energy_cost)
			

			total_distance_drawn += POINT_INTERVAL
			
			# 娌跨潃鏂瑰悜鍓嶈繘
			var direction = (mouse_pos - last_point).normalized()
			var new_point = last_point + direction * POINT_INTERVAL
			

			path_points.append(new_point)
			
			# 鍒涘缓绾挎
			var segment = {
				"start": last_point,
				"end": new_point
			}
			path_segments.append(segment)
			

			_check_intersection_and_closure()
			
			# P1-4: 閲戝竵杞ㄨ抗鏈哄埗
			_check_and_spawn_gold_trail(new_point)
			
			_apply_death_brush_segment(last_point, new_point)
			
			last_point = new_point
		else:
			# 鑳介噺涓嶈冻
			is_drawing = false
			SoundManager.play("skill_q_energy_depleted")
			if not has_shown_no_energy_hint:
				has_shown_no_energy_hint = true
				Global.spawn_floating_text(skill_owner.global_position, "No Energy!", Color.RED)
			break

func _cache_draw_snapshot() -> void:
	if not is_instance_valid(skill_owner):
		return
	if not ("player_id" in skill_owner):
		return
	Global.cache_recent_draw_path(skill_owner.player_id, path_points, has_closure)

func _cache_q_execution_context(
	is_closed_path: bool,
	segment_count: int,
	polygon_count: int,
	center: Vector2,
	radius: float
) -> void:
	if not is_instance_valid(skill_owner):
		return
	var now_msec: int = Time.get_ticks_msec()
	var safe_radius: float = float(max(60.0, radius))

	# 新统一键
	skill_owner.set_meta(Q_CTX_META_CENTER, center)
	skill_owner.set_meta(Q_CTX_META_RADIUS, safe_radius)
	skill_owner.set_meta(Q_CTX_META_TIME_MSEC, now_msec)
	skill_owner.set_meta(Q_CTX_META_CLOSED, is_closed_path)
	skill_owner.set_meta(Q_CTX_META_SEGMENTS, max(0, segment_count))
	skill_owner.set_meta(Q_CTX_META_POLYGONS, max(0, polygon_count))

	# 旧键兼容（E 原型仍在使用）
	skill_owner.set_meta(Q_CTX_LEGACY_CENTER, center)
	skill_owner.set_meta(Q_CTX_LEGACY_RADIUS, safe_radius)
	skill_owner.set_meta(Q_CTX_LEGACY_TIME_MSEC, now_msec)

func _calculate_points_center(points: Array[Vector2]) -> Vector2:
	if points.is_empty():
		return skill_owner.global_position if is_instance_valid(skill_owner) else Vector2.ZERO
	var center: Vector2 = Vector2.ZERO
	for point: Vector2 in points:
		center += point
	return center / float(points.size())

func _calculate_points_radius(points: Array[Vector2], center: Vector2) -> float:
	if points.is_empty():
		return 120.0
	var radius: float = 0.0
	for point: Vector2 in points:
		radius = float(max(radius, center.distance_to(point)))
	return float(max(60.0, radius))

func _apply_death_brush_segment(seg_start: Vector2, seg_end: Vector2) -> void:
	if not BondManager.has_mechanic("death_brush"):
		return
	if _death_brush_tick_cooldown > 0.0:
		return

	var damage_ratio: float = max(0.0, float(BondManager.get_mechanic_value("death_brush")))
	if damage_ratio <= 0.0:
		return

	_death_brush_tick_cooldown = 0.35
	var enemies = get_tree().get_nodes_in_group("enemies")
	var hit_count := 0

	for enemy in enemies:
		if not is_instance_valid(enemy) or not enemy.has_node("HealthComponent"):
			continue

		var enemy_pos: Vector2 = enemy.global_position
		var closest := Geometry2D.get_closest_point_to_segment(enemy_pos, seg_start, seg_end)
		if enemy_pos.distance_to(closest) > 28.0:
			continue

		var health_comp = enemy.get_node("HealthComponent")
		var max_hp := float(health_comp.max_health)
		var damage := int(round(max_hp * damage_ratio))

		# Boss/楂樿鍗曚綅涓婇檺锛岄伩鍏嶅紓甯哥鏉拷
		if max_hp >= 1200.0:
			damage = min(damage, 120)
		else:
			damage = min(damage, 90)

		if damage <= 0:
			continue

		health_comp.take_damage(damage, {
			"source": skill_owner,
			"kind": "bond_death_brush",
			"damage_type": "DMG_AOE",
		})
		Global.spawn_floating_text(enemy_pos, "DEATH BRUSH!", Color(1.6, 0.4, 1.2))
		hit_count += 1

	if hit_count > 0:
		SoundManager.play("bond_trigger_generic")

func _apply_polygon_effect(polygon: PackedVector2Array) -> void:
	if not BondManager.has_mechanic("polygon_effect"):
		return
	if polygon.size() < 3:
		return

	var sides := polygon.size()
	var enemies = get_tree().get_nodes_in_group("enemies")
	var applied := 0

	for enemy in enemies:
		if not is_instance_valid(enemy) or not enemy.has_method("apply_status"):
			continue
		if not Geometry2D.is_point_in_polygon(enemy.global_position, polygon):
			continue

		if sides <= 4:
			enemy.apply_status("poison", 4.0, 3.0, 2, 1.0)
		elif sides == 5:
			enemy.apply_status("stun", 1.2, 0.0, 1, 1.0)
		else:
			enemy.apply_status("freeze", 0.9, 0.0, 1, 1.0)
		applied += 1

	if applied > 0:
		var center := _calculate_polygon_center(polygon)
		Global.spawn_floating_text(center, "POLYGON x%d" % sides, Color(0.9, 1.3, 2.0))
		SoundManager.play("bond_trigger_generic")

# ==============================================================================

# ==============================================================================

# 函数：_calculate_current_energy_cost
func _calculate_current_energy_cost() -> float:
	if total_distance_drawn <= energy_threshold_distance:
		# 鍩虹闃舵
		return energy_per_10px
	else:
		# 閫掑闃舵
		var excess_distance = total_distance_drawn - energy_threshold_distance
		var multiplier = 1.0 + excess_distance * energy_scale_multiplier
		return energy_per_10px * multiplier

# 函数：_calculate_total_consumed_energy
func _calculate_total_consumed_energy() -> float:
	var total = 0.0
	var distance = 0.0
	
	# 循环处理
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

# ==============================================================================

# 函数：_perform_final_closure_check
func _perform_final_closure_check() -> void:
	has_closure = false
	
	if path_segments.size() < 3:
		return
	
	# P0-3: 浣跨敤缇佺粖鍔犳垚鍚庣殑瀹归敊璺濈
	var tolerance = _get_closure_tolerance()
	
	# 循环处理
	for i in range(path_segments.size()):
		for j in range(i + 2, path_segments.size()):
			var seg1 = path_segments[i]
			var seg2 = path_segments[j]
			
			if _segments_intersect(seg1, seg2):
				has_closure = true
				return
	
	# 条件判断
	if path_points.size() >= 3:
		var last_point_pos: Vector2 = path_points[path_points.size() - 1]
		
		# 条件判断
		if last_point_pos.distance_to(path_points[0]) < tolerance:
			has_closure = true
			return

# 函数：_check_intersection_and_closure
func _check_intersection_and_closure() -> void:
	if has_closure:
		return
	
	if path_segments.size() < 3:
		return
	
	# P0-3: 浣跨敤缇佺粖鍔犳垚鍚庣殑瀹归敊璺濈
	var tolerance = _get_closure_tolerance()
	
	# 字段定义
	var latest_seg = path_segments[path_segments.size() - 1]
	
	for i in range(path_segments.size() - 2):
		var old_seg = path_segments[i]
		
		if _segments_intersect(latest_seg, old_seg):
			has_closure = true
			SoundManager.play("skill_q_closure_detected")
			return
	
	# 条件判断
	if path_points.size() >= 12:
		var current_point: Vector2 = path_points[path_points.size() - 1]
		if current_point.distance_to(path_points[0]) < tolerance:
			has_closure = true
			SoundManager.play("skill_q_closure_detected")
			return

# 函数：_segments_intersect
func _segments_intersect(seg1: Dictionary, seg2: Dictionary) -> bool:
	var p1 = seg1["start"]
	var p2 = seg1["end"]
	var p3 = seg2["start"]
	var p4 = seg2["end"]
	
	var intersection = Geometry2D.segment_intersects_segment(p1, p2, p3, p4)
	return intersection != null

# ==============================================================================
# 璺緞绠＄悊
# ==============================================================================

## 娓呴櫎鎵拷鏈夎矾寰勭偣
func _clear_all_points(refund_energy: bool = false) -> void:
	# 条件判断
	if refund_energy:
		var total_consumed_energy = _calculate_total_consumed_energy()
		if skill_owner and total_consumed_energy > 0:
			skill_owner.energy += total_consumed_energy
			skill_owner.update_ui_signals()
	
	# 娓呯┖鏁版嵁
	path_points.clear()
	path_segments.clear()
	_pending_open_asset_payload.clear()
	has_closure = false
	accumulated_distance = 0.0
	total_distance_drawn = 0.0
	
	# 条件判断
	if skill_owner:
		var start_pos = skill_owner.get_global_mouse_position()
		path_points.append(start_pos)
		last_point = start_pos

# ==============================================================================
# 瑙嗚鏁堟灉
# ==============================================================================

# 函数：_update_visuals
func _update_visuals() -> void:
	if not is_instance_valid(line_2d):
		return
	
	line_2d.global_position = Vector2.ZERO
	line_2d.clear_points()
	
	if path_points.is_empty() and not is_planning:
		return
	
	if not skill_owner:
		return
	
	# 循环处理
	for p in path_points:
		line_2d.add_point(p)
	
	# 濡傛灉姝ｅ湪鍒掔嚎锛屾坊鍔犲埌榧犳爣鐨勯瑙堢嚎
	if is_planning and is_drawing:
		var mouse_pos = skill_owner.get_global_mouse_position()
		line_2d.add_point(mouse_pos)
	
	# 棰滆壊鍒ゆ柇
	var final_color = _get_line_color()
	
	if has_closure:

		final_color = _get_closure_color()
	elif is_planning and skill_owner and skill_owner.energy < _calculate_current_energy_cost():
		# 鑳介噺涓嶈冻
		final_color = Color(0.5, 0.5, 0.5, 0.5)
	elif is_planning and total_distance_drawn > energy_threshold_distance:
		# 字段定义
		var excess_ratio = (total_distance_drawn - energy_threshold_distance) / energy_threshold_distance
		excess_ratio = clamp(excess_ratio, 0.0, 1.0)
		var base_color = _get_line_color()
		var warning_color = Color.ORANGE
		final_color = base_color.lerp(warning_color, excess_ratio * 0.5)
	
	line_2d.default_color = final_color

# ==============================================================================
# 娓呯悊
# ==============================================================================

## 娓呯悊璧勬簮
func cleanup() -> void:
	print("[%s] cleanup() called" % skill_id)
	
	# 条件判断
	if is_instance_valid(line_2d):
		line_2d.queue_free()
	
	# 闁插秶鐤嗛悩鑸碘偓?
	is_planning = false
	is_drawing = false
	has_shown_no_energy_hint = false
	path_points.clear()
	path_segments.clear()
	_pending_open_asset_payload.clear()
	accumulated_distance = 0.0
	total_distance_drawn = 0.0
	has_closure = false
	
	print("[%s] cleanup() finished" % skill_id)
