extends Node

const DEBUG_VERBOSE := false

## ==============================================================================
## 鎶€鑳芥晥鏋滅敓鍛藉懆鏈熺鐞嗗櫒 - 缁熶竴绠＄悊鎵€鏈夋妧鑳界殑鍦烘櫙鏁堟灉
## ==============================================================================
## 
## 鍔熻兘璇存槑:
## - 缁熶竴绠＄悊鎶€鑳芥晥鏋滅殑鐢熷懡鍛ㄦ湡锛堢伀娴枫€侀澧欍€侀敮鏉°€佸湴闆风瓑锛?
## - 鎻愪緵鐙珛鐨勪激瀹炽€佺墿鐞嗘晥鏋溿€佽瑙夋晥鏋滅鐞?
## - 涓嶄緷璧栨妧鑳藉疄渚嬶紝鍗充娇瑙掕壊鍒囨崲涔熻兘缁х画宸ヤ綔
## 
## 浣跨敤鏂规硶:
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

## 鏁堟灉鑺傜偣瀛楀吀 {effect_id: effect_data}
var active_effects: Dictionary = {}

## 鏁堟灉ID璁℃暟鍣?
var next_effect_id: int = 0

## 涓存椂浼ゅ鍊嶇巼鏍堬紙鐢辨妧鑳藉熀绫诲帇鏍?鍑烘爤锛?
var _damage_multiplier_stack: Array[float] = []

func _is_effect_ending(effect_data: Dictionary) -> bool:
	return bool(effect_data.get("ending", false))

func _mark_effect_ending(effect_data: Dictionary) -> void:
	effect_data["ending"] = true

	var area_var: Variant = effect_data.get("area", null)
	if area_var is Area2D and is_instance_valid(area_var):
		var area: Area2D = area_var
		area.monitoring = false

	var damage_area_var: Variant = effect_data.get("damage_area", null)
	if damage_area_var is Area2D and is_instance_valid(damage_area_var):
		var damage_area: Area2D = damage_area_var
		damage_area.monitoring = false

	var block_area_var: Variant = effect_data.get("block_area", null)
	if block_area_var is Area2D and is_instance_valid(block_area_var):
		var block_area: Area2D = block_area_var
		block_area.monitoring = false

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
			"[SkillEffectManager] %s 璺宠繃鏃犳晥澶氳竟褰? raw_points=%d" % [
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
# 鍒涘缓鏁堟灉
# ==============================================================================

## 鍒涘缓鍖哄煙鏁堟灉锛堝杈瑰舰锛?
## @param config: 閰嶇疆瀛楀吀
##   - polygon: PackedVector2Array (蹇呴渶)
##   - damage: int (鍙€夛紝榛樿0)
##   - damage_interval: float (鍙€夛紝榛樿0.5)
##   - duration: float (鍙€夛紝榛樿5.0)
##   - color: Color (鍙€夛紝榛樿鐧借壊)
##   - pull_to_center: bool (鍙€夛紝榛樿false)
##   - pull_force: float (鍙€夛紝榛樿0)
##   - pull_interval: float (鍙€夛紝榛樿0.05)
##   - z_index: int (鍙€夛紝榛樿10)
##   - fade_in_duration: float (鍙€夛紝榛樿0.2)
##   - fade_out_duration: float (鍙€夛紝榛樿0.3)
## @return: effect_id (鐢ㄤ簬鍚庣画鎿嶄綔)
func create_area_effect(config: Dictionary) -> int:
	config = _apply_runtime_damage_multiplier(config)
	var effect_id = next_effect_id
	next_effect_id += 1
	
	# 楠岃瘉蹇呴渶鍙傛暟
	if not config.has("polygon"):
		push_error("[SkillEffectManager] 缂哄皯蹇呴渶鍙傛暟: polygon")
		return -1

	config = _normalize_polygon_config(config, "create_area_effect")
	if config.is_empty():
		return -1
	
	var points: PackedVector2Array = config["polygon"]
	if points.size() < 3:
		push_error("[SkillEffectManager] 澶氳竟褰㈢偣鏁颁笉瓒? %d" % points.size())
		return -1
	
	if DEBUG_VERBOSE:
		print("[SkillEffectManager] create_area_effect 琚皟鐢? 鐐规暟=%d, damage=%d, duration=%.1f" % [
		points.size(), config.get("damage", 0), config.get("duration", 5.0)
	])
	
	# 鍒涘缓 Area2D
	var area = Area2D.new()
	area.collision_layer = 0
	area.collision_mask = 1 | 2  # 妫€娴?Layer1(Player/Enemy榛樿) + Layer2(Enemy鏍囪)
	area.monitorable = false
	area.monitoring = true
	area.name = "SkillEffect_%d" % effect_id
	
	# 纰版挒褰㈢姸
	var col = CollisionPolygon2D.new()
	col.polygon = points
	area.add_child(col)
	
	# 瑙嗚鏁堟灉
	var vis_poly = Polygon2D.new()
	vis_poly.polygon = points
	vis_poly.color = Color(1.0, 1.0, 1.0, 0.0)
	vis_poly.z_index = config.get("z_index", 10)
	area.add_child(vis_poly)
	
	# 娣诲姞鍒?SkillEffectManager 鑷韩锛坅utoload 鑺傜偣锛岃鑹插垏鎹笉褰卞搷锛?
	add_child(area)
	
	# 淇濆瓨鏁堟灉鏁版嵁
	var effect_data = {
		"area": area,
		"vis_poly": vis_poly,
		"config": config,
		"elapsed": 0.0,
		"phase": "fade_in"
	}
	active_effects[effect_id] = effect_data
	
	# 娣″叆鍔ㄧ敾
	var fade_in_duration = config.get("fade_in_duration", 0.2)
	var target_color = config.get("color", Color.WHITE)
	var tween = area.create_tween()
	tween.tween_property(vis_poly, "color", target_color, fade_in_duration).from(Color(target_color.r, target_color.g, target_color.b, 0.0))
	
	# 璁＄畻涓績鐐癸紙鐢ㄤ簬鍚搁檮鏁堟灉锛?
	if config.get("pull_to_center", false):
		var center = Vector2.ZERO
		for p in points:
			center += p
		center /= points.size()
		effect_data["center"] = center
	
	# 鍚姩鏁堟灉绠＄悊
	_start_effect_lifecycle(effect_id)
	
	return effect_id

## 鍒涘缓绾挎鏁堟灉锛堢伀绾裤€侀澧欑瓑锛?
## @param config: 閰嶇疆瀛楀吀
##   - start: Vector2 (蹇呴渶)
##   - end: Vector2 (蹇呴渶)
##   - width: float (鍙€夛紝榛樿24)
##   - damage: int (鍙€夛紝榛樿0)
##   - damage_interval: float (鍙€夛紝榛樿0.5)
##   - duration: float (鍙€夛紝榛樿5.0)
##   - color: Color (鍙€夛紝榛樿鐧借壊)
##   - pull_to_line: bool (鍙€夛紝榛樿false)
##   - pull_force: float (鍙€夛紝榛樿0)
## @return: effect_id
func create_line_effect(config: Dictionary) -> int:
	config = _apply_runtime_damage_multiplier(config)
	var effect_id = next_effect_id
	next_effect_id += 1
	
	# 楠岃瘉蹇呴渶鍙傛暟
	if not config.has("start") or not config.has("end"):
		push_error("[SkillEffectManager] 缂哄皯蹇呴渶鍙傛暟: start 鎴?end")
		return -1
	
	if DEBUG_VERBOSE:
		print("[SkillEffectManager] create_line_effect 琚皟鐢? damage=%d, duration=%.1f" % [
		config.get("damage", 0), config.get("duration", 5.0)
	])
	
	var start: Vector2 = config["start"]
	var end: Vector2 = config["end"]
	var width: float = config.get("width", 24.0)
	
	# 鍒涘缓 Area2D
	var area = Area2D.new()
	area.position = start
	area.collision_layer = 0
	area.collision_mask = 1 | 2  # 妫€娴?Layer1(Player/Enemy榛樿) + Layer2(Enemy鏍囪)
	area.monitorable = false
	area.monitoring = true
	area.name = "SkillEffect_%d" % effect_id
	
	var vec = end - start
	var length = vec.length()
	var angle = vec.angle()
	
	# 纰版挒褰㈢姸
	var col = CollisionShape2D.new()
	var shape = RectangleShape2D.new()
	shape.size = Vector2(length, width)
	col.shape = shape
	col.position = Vector2(length / 2.0, 0)
	col.rotation = angle
	area.add_child(col)
	
	# 瑙嗚鏁堟灉
	var vis_line = Line2D.new()
	vis_line.add_point(Vector2.ZERO)
	vis_line.add_point(end - start)
	vis_line.width = width
	vis_line.default_color = config.get("color", Color.WHITE)
	vis_line.begin_cap_mode = Line2D.LINE_CAP_ROUND
	vis_line.end_cap_mode = Line2D.LINE_CAP_ROUND
	area.add_child(vis_line)
	
	# 娣诲姞鍒?SkillEffectManager 鑷韩锛坅utoload 鑺傜偣锛岃鑹插垏鎹笉褰卞搷锛?
	add_child(area)
	
	# 淇濆瓨鏁堟灉鏁版嵁
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
	
	# 鍚姩鏁堟灉绠＄悊
	_start_effect_lifecycle(effect_id)
	
	return effect_id

# ==============================================================================
# 澧欎綋鏁堟灉
# ==============================================================================

## 鍒涘缓澧欎綋鏁堟灉锛圫taticBody2D锛?
## @param config: 閰嶇疆瀛楀吀
##   - start: Vector2 (蹇呴渶) - 澧欎綋璧风偣
##   - end: Vector2 (蹇呴渶) - 澧欎綋缁堢偣
##   - width: float (鍙€? 榛樿 16) - 澧欎綋瀹藉害
##   - duration: float (鍙€? 榛樿 5.0) - 鎸佺画鏃堕棿
##   - health: int (鍙€? 榛樿 -1) - 澧欎綋鐢熷懡鍊硷紝-1 涓轰笉鍙牬鍧?
##   - block_enemies: bool (鍙€? 榛樿 true) - 鏄惁闃绘尅鏁屼汉
##   - block_bullets: bool (鍙€? 榛樿 false) - 鏄惁闃绘尅瀛愬脊
##   - reflect_bullets: bool (鍙€? 榛樿 false) - 鏄惁鍙嶅皠瀛愬脊
##   - contact_damage: int (鍙€? 榛樿 0) - 鎺ヨЕ浼ゅ
##   - contact_interval: float (鍙€? 榛樿 0.5) - 鎺ヨЕ浼ゅ闂撮殧
##   - color: Color (鍙€? - 澧欎綋棰滆壊
## @return: effect_id (鐢ㄤ簬鍚庣画鎿嶄綔), -1 琛ㄧず澶辫触
func create_wall_effect(config: Dictionary) -> int:
	config = _apply_runtime_damage_multiplier(config)
	# 楠岃瘉蹇呴渶鍙傛暟
	if not config.has("start") or not config.has("end"):
		push_error("[SkillEffectManager] create_wall_effect 缂哄皯蹇呴渶鍙傛暟: start 鎴?end")
		return -1

	if DEBUG_VERBOSE:
		print("[SkillEffectManager] create_wall_effect 琚皟鐢? start=%s, end=%s, block=%s, damage=%d" % [
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

	# --- StaticBody2D 鐗╃悊澧欎綋 ---
	var static_body = StaticBody2D.new()
	static_body.name = "WallEffect_%d" % effect_id

	# 纰版挒灞傝缃?
	var col_layer = 0
	if block_enemies:
		col_layer |= 4  # Layer 3: 闅滅鐗╁眰锛屾晫浜轰細纰版挒
	if block_bullets or reflect_bullets:
		col_layer |= 4  # 鍚屽眰锛屽瓙寮逛篃浼氱鎾?
	static_body.collision_layer = col_layer
	static_body.collision_mask = 0  # StaticBody 涓嶉渶瑕佷富鍔ㄦ娴?

	# 纰版挒褰㈢姸锛氭部绾挎鐨勭煩褰?
	var col_shape = CollisionShape2D.new()
	var rect_shape = RectangleShape2D.new()
	rect_shape.size = Vector2(length, width)
	col_shape.shape = rect_shape
	# 灏嗙鎾炲舰鐘舵斁鍦ㄧ嚎娈典腑鐐癸紝鏃嬭浆鍒扮嚎娈垫柟鍚?
	col_shape.position = vec / 2.0
	col_shape.rotation = angle
	static_body.add_child(col_shape)

	# 璁剧疆澧欎綋浣嶇疆涓鸿捣鐐?
	static_body.global_position = start

	# --- Line2D 瑙嗚鍗犱綅 ---
	var vis_line = Line2D.new()
	vis_line.add_point(Vector2.ZERO)
	vis_line.add_point(vec)
	vis_line.width = width
	vis_line.default_color = color
	vis_line.begin_cap_mode = Line2D.LINE_CAP_ROUND
	vis_line.end_cap_mode = Line2D.LINE_CAP_ROUND
	vis_line.z_index = 5
	static_body.add_child(vis_line)

	# --- 鎺ヨЕ浼ゅ Area2D ---
	var damage_area: Area2D = null
	if contact_damage > 0:
		damage_area = Area2D.new()
		damage_area.name = "WallDamageArea"
		damage_area.collision_layer = 0
		damage_area.collision_mask = 1 | 2  # 妫€娴?Layer1(Player/Enemy榛樿) + Layer2(Enemy鏍囪)
		damage_area.monitorable = false
		damage_area.monitoring = true

		var dmg_col = CollisionShape2D.new()
		var dmg_shape = RectangleShape2D.new()
		dmg_shape.size = Vector2(length, width + 16.0)  # 姣斿浣撳锛岀‘淇濇帴瑙︽娴嬪彲闈?
		dmg_col.shape = dmg_shape
		dmg_col.position = vec / 2.0
		dmg_col.rotation = angle
		damage_area.add_child(dmg_col)
		static_body.add_child(damage_area)

	# --- 闃绘尅鏁屼汉 Area2D锛堝洜涓烘晫浜烘槸 Area2D锛屼笉鍙?StaticBody2D 鐗╃悊闃绘尅锛?--
	var block_area: Area2D = null
	if block_enemies:
		block_area = Area2D.new()
		block_area.name = "WallBlockArea"
		block_area.collision_layer = 0
		block_area.collision_mask = 1 | 2  # 妫€娴?Layer1(Player/Enemy榛樿) + Layer2(Enemy鏍囪)
		block_area.monitorable = false
		block_area.monitoring = true

		var blk_col = CollisionShape2D.new()
		var blk_shape = RectangleShape2D.new()
		blk_shape.size = Vector2(length, width + 32.0)  # 姣斿浣撳寰堝锛岀‘淇濇彁鍓嶆娴嬪埌鏁屼汉
		blk_col.shape = blk_shape
		blk_col.position = vec / 2.0
		blk_col.rotation = angle
		block_area.add_child(blk_col)
		static_body.add_child(block_area)

	# --- 闃绘尅瀛愬脊 Area2D锛堟晫浜哄瓙寮规槸 Area2D/HitboxComponent锛屼笉鍙?StaticBody2D 闃绘尅锛?--
	var bullet_block_area: Area2D = null
	if block_bullets or reflect_bullets:
		bullet_block_area = Area2D.new()
		bullet_block_area.name = "WallBulletBlockArea"
		bullet_block_area.collision_layer = 0
		bullet_block_area.collision_mask = 4  # Layer 3: HitboxEnemy锛堟晫浜哄瓙寮圭殑 hitbox锛?
		bullet_block_area.monitorable = false
		bullet_block_area.monitoring = true

		var blt_col = CollisionShape2D.new()
		var blt_shape = RectangleShape2D.new()
		blt_shape.size = Vector2(length, width + 24.0)  # 姣斿浣撶◢瀹界‘淇濇嫤鎴?
		blt_col.shape = blt_shape
		blt_col.position = vec / 2.0
		blt_col.rotation = angle
		bullet_block_area.add_child(blt_col)
		static_body.add_child(bullet_block_area)

		# 棰勮绠楀浣撴硶绾匡紙鐢ㄤ簬鍙嶅皠锛?
		var wall_dir = vec.normalized()
		var wall_normal_for_reflect = Vector2(-wall_dir.y, wall_dir.x)  # 鍨傜洿浜庡浣撴柟鍚?

		# 杩炴帴淇″彿锛氭娴嬪埌鏁屼汉瀛愬脊鏃堕樆鎸℃垨鍙嶅皠
		var do_reflect = reflect_bullets
		bullet_block_area.area_entered.connect(func(area: Area2D):
			# --- 瑙ｆ瀽瀛愬脊鑺傜偣 ---
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

			# --- 鍙嶅皠閫昏緫 ---
			if do_reflect and is_instance_valid(projectile_node):
				if projectile_node is Projectile:
					# 鏍囧噯 Projectile锛氬弽杞?velocity 娌垮浣撴硶绾垮弽灏?
					var vel: Vector2 = projectile_node.velocity
					var reflected = vel - 2.0 * vel.dot(wall_normal_for_reflect) * wall_normal_for_reflect
					projectile_node.velocity = reflected
					projectile_node.rotation = reflected.angle()
					# 淇敼 hitbox 纰版挒灞傦細浠庢晫浜哄瓙寮瑰彉涓虹帺瀹跺瓙寮癸紝浣垮叾鑳戒激瀹虫晫浜?
					if projectile_node.hitbox:
						projectile_node.hitbox.collision_layer = 16  # Layer 5: HitboxPlayer
						projectile_node.hitbox.collision_mask = 8    # Layer 4: HurtboxEnemy
						projectile_node.hitbox.source = Global.player if is_instance_valid(Global.player) else null
					return

			# --- 绾樆鎸★細閿€姣佸瓙寮?---
			if is_instance_valid(projectile_node):
				projectile_node.queue_free()
		)

	# 娣诲姞鍒?SkillEffectManager 鑷韩锛坅utoload 鑺傜偣锛岃鑹插垏鎹笉褰卞搷锛?
	add_child(static_body)

	# --- 淇濆瓨鏁堟灉鏁版嵁 ---
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
		# 棰勮绠楀浣撴硶绾挎柟鍚戯紙鐢ㄤ簬鎺ㄥ洖鏁屼汉锛?
		var wall_normal = vec.rotated(PI / 2.0).normalized()
		effect_data["wall_normal"] = wall_normal
		effect_data["wall_start"] = start
		effect_data["wall_end"] = end_pos
		effect_data["wall_width"] = width
	active_effects[effect_id] = effect_data

	# 鍚姩澧欎綋鐢熷懡鍛ㄦ湡
	_start_wall_lifecycle(effect_id)

	return effect_id

## 澧欎綋鍙楀埌浼ゅ锛堝閮ㄨ皟鐢紝鐢ㄤ簬鍙牬鍧忓浣擄級
func wall_take_damage(effect_id: int, damage: int) -> void:
	if not active_effects.has(effect_id):
		return
	var effect_data = active_effects[effect_id]
	if effect_data.get("type") != "wall":
		return
	if effect_data["health"] < 0:
		return  # 涓嶅彲鐮村潖

	effect_data["health"] -= damage
	if effect_data["health"] <= 0:
		_destroy_wall(effect_id)

## 鍚姩澧欎綋鐢熷懡鍛ㄦ湡绠＄悊
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

## 鏇存柊澧欎綋鏁堟灉
func _update_wall_effect(effect_id: int, delta: float) -> void:
	if not active_effects.has(effect_id):
		return

	var effect_data = active_effects[effect_id]
	if _is_effect_ending(effect_data):
		return
	var static_body = effect_data["static_body"]

	if not is_instance_valid(static_body):
		active_effects.erase(effect_id)
		return

	effect_data["elapsed"] += delta
	var duration = effect_data["config"].get("duration", 5.0)

	# 鎺ヨЕ浼ゅ tick
	if effect_data.has("damage_area"):
		var damage_area: Area2D = effect_data["damage_area"]
		var contact_damage_val: int = effect_data["config"].get("contact_damage", 0)
		var contact_interval: float = effect_data["config"].get("contact_interval", 0.5)

		if is_instance_valid(damage_area) and contact_damage_val > 0:
			effect_data["contact_timer"] += delta
			if effect_data["contact_timer"] >= contact_interval:
				_apply_wall_contact_damage(damage_area, contact_damage_val)
				effect_data["contact_timer"] = 0.0

	# 闃绘尅鏁屼汉锛圓rea2D 鎺ㄥ洖鏈哄埗锛屽洜涓烘晫浜烘槸 Area2D 涓嶅彈 StaticBody2D 鐗╃悊闃绘尅锛?
	if effect_data["config"].get("block_enemies", false) and effect_data.has("block_area"):
		var block_area: Area2D = effect_data["block_area"]
		if is_instance_valid(block_area):
			_push_enemies_from_wall(block_area, effect_data)

	# 鎸佺画鏃堕棿鍒版湡 鈫?娣″嚭骞剁Щ闄?
	if effect_data["elapsed"] >= duration:
		_end_wall_effect(effect_id)

## 搴旂敤澧欎綋鎺ヨЕ浼ゅ
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
			enemy.health_component.take_damage(damage, {
				"source": self,
				"kind": "wall_contact_damage",
				"damage_type": "DMG_AOE",
				"skill_slot": "q",
				"space_skill_mode": "open",
			})
			if DEBUG_VERBOSE:
				print("[SkillEffectManager] 澧欎綋鎺ヨЕ浼ゅ: %d -> %s" % [damage, enemy.name])

## 灏嗘晫浜烘帹绂诲浣擄紙Area2D 鎺ㄥ洖鏈哄埗锛?
## 鍥犱负鏁屼汉鏄?Area2D 浣跨敤 position += 绉诲姩锛孲taticBody2D 鏃犳硶鐗╃悊闃绘尅
## 鎵€浠ラ€氳繃姣忓抚妫€娴嬮噸鍙犲苟鎺ㄥ洖鏉ユā鎷熼樆鎸℃晥鏋?
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
			# 璁＄畻鏁屼汉鍒板浣撶嚎娈电殑鏈€杩戠偣
			var closest = Geometry2D.get_closest_point_to_segment(enemy.global_position, wall_start, wall_end)
			var to_enemy = enemy.global_position - closest
			var dist = to_enemy.length()

			# 濡傛灉鏁屼汉鍦ㄥ浣撳搴﹀唴锛屾帹鍒板浣撹竟缂樺
			var push_dist = (wall_width / 2.0 + 16.0)  # 澧欎綋鍗婂 + 缂撳啿锛堝姞澶х紦鍐茬‘淇濇帹鍑猴級
			if dist < push_dist:
				var push_dir: Vector2
				if dist > 0.1:
					push_dir = to_enemy.normalized()
				else:
					# 鏁屼汉鍑犱箮鍦ㄥ浣撶嚎涓婏紝浣跨敤澧欎綋娉曠嚎鎺ㄥ紑
					push_dir = effect_data["wall_normal"]
				enemy.global_position = closest + push_dir * push_dist
				# 浠呴娆℃帹鍥炴椂鎵撳嵃鏃ュ織锛堥伩鍏嶅埛灞忥級
				if not effect_data.has("_push_logged"):
					effect_data["_push_logged"] = true
					if DEBUG_VERBOSE:
						print("[SkillEffectManager] 澧欎綋鎺ㄥ洖鏁屼汉: %s, dist=%.1f" % [enemy.name, dist])

## 澧欎綋娣″嚭骞剁Щ闄?
func _end_wall_effect(effect_id: int) -> void:
	if not active_effects.has(effect_id):
		return

	var effect_data = active_effects[effect_id]
	if _is_effect_ending(effect_data):
		return
	_mark_effect_ending(effect_data)
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

## 绔嬪嵆閿€姣佸浣擄紙鐢熷懡鍊煎綊闆舵椂璋冪敤锛?
func _destroy_wall(effect_id: int) -> void:
	if not active_effects.has(effect_id):
		return

	var effect_data = active_effects[effect_id]
	var static_body = effect_data["static_body"]

	if is_instance_valid(static_body):
		# 蹇€熼棯鐑佸悗閿€姣?
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
# Buff 鍖哄煙鏁堟灉
# ==============================================================================

## 鍒涘缓 Buff 鍖哄煙鏁堟灉锛圓rea2D锛?
## @param config: 閰嶇疆瀛楀吀
##   - polygon: PackedVector2Array (澶氳竟褰㈠舰鐘讹紝涓?start/end 浜岄€変竴)
##   - start: Vector2 (绾挎鍨嬭捣鐐癸紝涓?polygon 浜岄€変竴)
##   - end: Vector2 (绾挎鍨嬬粓鐐?
##   - width: float (绾挎鍨嬪搴︼紝榛樿 24)
##   - duration: float (鎸佺画鏃堕棿锛岄粯璁?5.0)
##   - buff_type: String (蹇呴渶) - Buff 绫诲瀷:
##       "attack_boost", "speed_boost", "heal", "lifesteal",
##       "invincible", "cooldown_reduction", "ignore_collision"
##   - buff_value: float (Buff 鏁板€硷紝榛樿 0.0)
##   - tick_interval: float (鏁堟灉瑙﹀彂闂撮殧锛岄粯璁?1.0)
##   - color: Color (鍖哄煙棰滆壊)
##   - target_group: String (鐩爣缁勶紝榛樿 "player")
##   - fade_out_duration: float (娣″嚭鏃堕棿锛岄粯璁?0.3)
## @return: effect_id, -1 琛ㄧず澶辫触
func create_buff_zone(config: Dictionary) -> int:
	# 楠岃瘉蹇呴渶鍙傛暟
	var has_polygon = config.has("polygon")
	var has_line = config.has("start") and config.has("end")
	if not has_polygon and not has_line:
		push_error("[SkillEffectManager] create_buff_zone 缂哄皯蹇呴渶鍙傛暟: polygon 鎴?start/end")
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

	# --- Area2D 妫€娴嬪尯鍩?---
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
		"buff_targets": [],
	}

	if has_polygon:
		# --- 澶氳竟褰㈠舰鐘?---
		var points: PackedVector2Array = config["polygon"]
		if points.size() < 3:
			push_error("[SkillEffectManager] create_buff_zone 澶氳竟褰㈢偣鏁颁笉瓒? %d" % points.size())
			return -1

		# 纰版挒褰㈢姸
		var col = CollisionPolygon2D.new()
		col.polygon = points
		area.add_child(col)

		# 瑙嗚鏁堟灉 - Polygon2D
		var vis_poly = Polygon2D.new()
		vis_poly.polygon = points
		vis_poly.color = color
		vis_poly.z_index = 5
		area.add_child(vis_poly)
		effect_data["vis_poly"] = vis_poly

		# 璁剧疆纰版挒鎺╃爜妫€娴?players 缁?
		area.collision_mask = 1  # Layer 1: players
	else:
		# --- 绾挎褰㈢姸 ---
		var start: Vector2 = config["start"]
		var end_pos: Vector2 = config["end"]
		var width: float = config.get("width", 48.0)  # 榛樿48px瀹斤紝纭繚鐜╁瀹规槗瑙﹀彂

		area.position = start
		var vec = end_pos - start
		var length = vec.length()
		var angle = vec.angle()

		# 纰版挒褰㈢姸 - 姣旇瑙夊搴︽洿澶э紝纭繚妫€娴嬪彲闈?
		var col = CollisionShape2D.new()
		var shape = RectangleShape2D.new()
		shape.size = Vector2(length, width + 32.0)  # 纰版挒姣旇瑙夊32px
		col.shape = shape
		col.position = Vector2(length / 2.0, 0)
		col.rotation = angle
		area.add_child(col)

		# 瑙嗚鏁堟灉 - Line2D
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

		# 璁剧疆纰版挒鎺╃爜妫€娴?players 缁?
		area.collision_mask = 1  # Layer 1: players

	# 娣诲姞鍒板満鏅爲锛堣€岄潪 SkillEffectManager 鑷韩锛夛紝纭繚 Area2D 鐗╃悊妫€娴嬫甯稿伐浣?
	var scene_root = get_tree().current_scene
	if scene_root:
		scene_root.add_child(area)
	else:
		add_child(area)

	active_effects[effect_id] = effect_data

	# 鍚姩 Buff 鍖哄煙鐢熷懡鍛ㄦ湡
	_start_buff_zone_lifecycle(effect_id)

	return effect_id

## 鍚姩 Buff 鍖哄煙鐢熷懡鍛ㄦ湡绠＄悊
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

## 鏇存柊 Buff 鍖哄煙鏁堟灉
func _update_buff_zone(effect_id: int, delta: float) -> void:
	if not active_effects.has(effect_id):
		return

	var effect_data = active_effects[effect_id]
	if _is_effect_ending(effect_data):
		return
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
		var applied_targets: Array = _apply_buff_to_targets(area, config)
		var cached_targets: Array = effect_data.get("buff_targets", [])
		for target in applied_targets:
			if target not in cached_targets:
				cached_targets.append(target)
		effect_data["buff_targets"] = cached_targets
		effect_data["buff_timer"] = 0.0

	# 鎸佺画鏃堕棿鍒版湡 鈫?娣″嚭骞剁Щ闄?
	if effect_data["elapsed"] >= duration:
		_end_buff_zone(effect_id)

## 瀵瑰尯鍩熷唴鐩爣搴旂敤 Buff 鏁堟灉
func _apply_buff_to_targets(area: Area2D, config: Dictionary) -> Array:
	if not is_instance_valid(area):
		return []

	var target_group: String = config.get("target_group", "player")
	var buff_type: String = config.get("buff_type", "")
	var buff_value: float = config.get("buff_value", 0.0)

	var targets = _collect_buff_zone_targets(area)
	
	# 鏀堕泦鍛戒腑鐨勭帺瀹?
	var hit_players: Array = []
	for t in targets:
		var player = null
		if t.is_in_group(target_group):
			player = t
		elif t.owner and t.owner.is_in_group(target_group):
			player = t.owner

		if player and is_instance_valid(player) and player not in hit_players:
			hit_players.append(player)

	# 澶囩敤鏂规锛氬鏋?Area2D 閲嶅彔妫€娴嬫湭鍛戒腑锛屼娇鐢ㄨ窛绂绘娴?
	# 杩欒В鍐充簡 SkillEffectManager(Node) 浣滀负鐖惰妭鐐规椂 Area2D 鐗╃悊妫€娴嬪彲鑳戒笉鍙潬鐨勯棶棰?
	if hit_players.is_empty() and target_group == "player":
		var player = Global.player if is_instance_valid(Global.player) else null
		if player:
			# 璁＄畻鐜╁鍒?buff 鍖哄煙鐨勮窛绂?
			var in_range = false
			if config.has("polygon"):
				# 澶氳竟褰細妫€鏌ョ帺瀹舵槸鍚﹀湪澶氳竟褰㈠唴
				in_range = Geometry2D.is_point_in_polygon(player.global_position, config["polygon"])
			elif config.has("start") and config.has("end"):
				# 绾挎锛氭鏌ョ帺瀹跺埌绾挎鐨勮窛绂?
				var closest = Geometry2D.get_closest_point_to_segment(
					player.global_position, config["start"], config["end"]
				)
				var dist = player.global_position.distance_to(closest)
				var width = config.get("width", 48.0)
				in_range = dist <= (width / 2.0 + 20.0)  # 绾挎鍗婂 + 鐜╁纰版挒鍗婂緞
			
			if in_range:
				hit_players.append(player)

	# 搴旂敤 Buff
	for player in hit_players:
		_apply_single_buff(player, buff_type, buff_value, config)

	return hit_players

## 瀵瑰崟涓洰鏍囧簲鐢?Buff
func _apply_single_buff(player: Node, buff_type: String, buff_value: float, config: Dictionary) -> void:
	match buff_type:
		"attack_boost":
			# 澧炲姞鏀诲嚮鍔涚櫨鍒嗘瘮
			if not player.has_meta("buff_attack_boost"):
				player.set_meta("buff_attack_boost", buff_value)
			else:
				# 鍒锋柊鍊硷紙鍙栬緝澶у€硷級
				var current = player.get_meta("buff_attack_boost")
				player.set_meta("buff_attack_boost", max(current, buff_value))

		"speed_boost":
			# 澧炲姞绉诲姩閫熷害鐧惧垎姣?
			if not player.has_meta("buff_speed_boost"):
				player.set_meta("buff_speed_boost", buff_value)
				if DEBUG_VERBOSE:
					print("[SkillEffectManager] Buff鍖哄煙鍛戒腑: speed_boost -> %s (+%.0f%%)" % [player.name, buff_value * 100])
			else:
				var current = player.get_meta("buff_speed_boost")
				player.set_meta("buff_speed_boost", max(current, buff_value))

		"heal":
			# 鎭㈠鐢熷懡鍊?
			if player.has_node("HealthComponent"):
				player.health_component.heal(int(buff_value))
			elif "hp" in player:
				player.hp = min(player.hp + int(buff_value), player.max_hp)

		"lifesteal":
			# 璁剧疆鐢熷懡鍋峰彇鐧惧垎姣?
			player.set_meta("buff_lifesteal", buff_value)

		"invincible":
			# 鏃犳晫鐘舵€?
			player.set_meta("buff_invincible", true)

		"cooldown_reduction":
			# 鍑忓皯鍐峰嵈鐧惧垎姣?
			player.set_meta("buff_cooldown_reduction", buff_value)

		"ignore_collision":
			# 蹇界暐鍗曚綅纰版挒
			player.set_meta("buff_ignore_collision", true)

## 娓呴櫎鍗曚釜鐩爣涓婄殑 Buff meta
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
		# "heal" 涓嶉渶瑕佹竻闄?meta锛屽洜涓哄畠鏄嵆鏃舵晥鏋?

## 娓呴櫎鍖哄煙鍐呮墍鏈夌洰鏍囩殑 Buff
func _clear_buff_zone_buffs(area: Area2D, config: Dictionary, targets: Array = []) -> void:
	var target_group: String = config.get("target_group", "player")
	var buff_type: String = config.get("buff_type", "")

	var resolved_targets: Array = targets.duplicate()

	for t in resolved_targets:
		var player = null
		if t.is_in_group(target_group):
			player = t
		elif t.owner and t.owner.is_in_group(target_group):
			player = t.owner

		if player and is_instance_valid(player):
			_clear_buff_meta(player, buff_type)

	if target_group == "player":
		var player = Global.player if is_instance_valid(Global.player) else null
		if player:
			_clear_buff_meta(player, buff_type)

func _collect_buff_zone_targets(area: Area2D) -> Array:
	var resolved_targets: Array = []
	if not is_instance_valid(area):
		return resolved_targets
	if not area.monitoring:
		return resolved_targets
	resolved_targets = area.get_overlapping_bodies() + area.get_overlapping_areas()
	return resolved_targets

func _end_buff_zone(effect_id: int) -> void:
	if not active_effects.has(effect_id):
		return

	var effect_data = active_effects[effect_id]
	if _is_effect_ending(effect_data):
		return
	var area = effect_data["area"]
	var config = effect_data["config"]
	var targets: Array = effect_data.get("buff_targets", [])
	if targets.is_empty():
		targets = _collect_buff_zone_targets(area)
		effect_data["buff_targets"] = targets

	_mark_effect_ending(effect_data)

	if not is_instance_valid(area):
		active_effects.erase(effect_id)
		return

	# 娓呴櫎鍖哄煙鍐呮墍鏈夌洰鏍囩殑 Buff meta
	_clear_buff_zone_buffs(area, config, targets)

	var fade_out_duration = config.get("fade_out_duration", 0.3)

	# 娣″嚭瑙嗚鏁堟灉
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

	# 娌℃湁瑙嗚鍏冪礌锛岀洿鎺ュ垹闄?
	area.queue_free()
	active_effects.erase(effect_id)

# ==============================================================================
# Debuff 鍖哄煙鏁堟灉
# ==============================================================================

## 鍒涘缓 Debuff 鍖哄煙鏁堟灉锛圓rea2D锛?
## @param config: 閰嶇疆瀛楀吀
##   - polygon: PackedVector2Array (澶氳竟褰㈠舰鐘讹紝涓?start/end 浜岄€変竴)
##   - start: Vector2 (绾挎鍨嬭捣鐐癸紝涓?polygon 浜岄€変竴)
##   - end: Vector2 (绾挎鍨嬬粓鐐?
##   - width: float (绾挎鍨嬪搴︼紝榛樿 24)
##   - duration: float (鎸佺画鏃堕棿锛岄粯璁?5.0)
##   - debuff_type: String (蹇呴渶) - Debuff 绫诲瀷:
##       "slow", "damage_amp", "poison", "freeze", "fear", "curse"
##   - debuff_value: float (Debuff 鏁板€硷紝榛樿 0.0)
##   - debuff_duration: float (鍗曟 Debuff 鎸佺画鏃堕棿锛岄粯璁?3.0)
##   - tick_interval: float (鏁堟灉瑙﹀彂闂撮殧锛岄粯璁?1.0)
##   - damage: int (鍙€? - 鍖哄煙浼ゅ
##   - damage_interval: float (鍙€? - 浼ゅ闂撮殧
##   - color: Color (鍖哄煙棰滆壊)
##   - fade_out_duration: float (娣″嚭鏃堕棿锛岄粯璁?0.3)
## @return: effect_id, -1 琛ㄧず澶辫触
func create_debuff_zone(config: Dictionary) -> int:
	config = _apply_runtime_damage_multiplier(config)
	# 楠岃瘉蹇呴渶鍙傛暟
	var has_polygon = config.has("polygon")
	var has_line = config.has("start") and config.has("end")
	if not has_polygon and not has_line:
		push_error("[SkillEffectManager] create_debuff_zone 缂哄皯蹇呴渶鍙傛暟: polygon 鎴?start/end")
		return -1

	if DEBUG_VERBOSE:
		print("[SkillEffectManager] create_debuff_zone 琚皟鐢? type=%s, debuff=%s, damage=%d" % [
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

	# --- Area2D 妫€娴嬪尯鍩?---
	var area = Area2D.new()
	area.name = "DebuffZone_%d" % effect_id
	area.collision_layer = 0
	area.collision_mask = 1 | 2  # 妫€娴?Layer1(Player/Enemy榛樿) + Layer2(Enemy鏍囪)
	area.monitorable = false
	area.monitoring = true

	var effect_data = {
		"type": "debuff_zone",
		"area": area,
		"config": config,
		"elapsed": 0.0,
		"debuff_timer": max(tick_interval - 0.1, 0.0),  # 棣栨 debuff 鍦?~0.1绉掑悗瑙﹀彂锛堢粰鐗╃悊寮曟搸鏃堕棿娉ㄥ唽閲嶅彔锛?
	}

	if has_polygon:
		# --- 澶氳竟褰㈠舰鐘?---
		var points: PackedVector2Array = config["polygon"]
		if points.size() < 3:
			push_error("[SkillEffectManager] create_debuff_zone 澶氳竟褰㈢偣鏁颁笉瓒? %d" % points.size())
			return -1

		# 纰版挒褰㈢姸
		var col = CollisionPolygon2D.new()
		col.polygon = points
		area.add_child(col)

		# 瑙嗚鏁堟灉 - Polygon2D
		var vis_poly = Polygon2D.new()
		vis_poly.polygon = points
		vis_poly.color = color
		vis_poly.z_index = 5
		area.add_child(vis_poly)
		effect_data["vis_poly"] = vis_poly
	else:
		# --- 绾挎褰㈢姸 ---
		var start: Vector2 = config["start"]
		var end_pos: Vector2 = config["end"]
		var width: float = config.get("width", 24.0)

		area.position = start
		var vec = end_pos - start
		var length = vec.length()
		var angle = vec.angle()

		# 纰版挒褰㈢姸
		var col = CollisionShape2D.new()
		var shape = RectangleShape2D.new()
		shape.size = Vector2(length, width)
		col.shape = shape
		col.position = Vector2(length / 2.0, 0)
		col.rotation = angle
		area.add_child(col)

		# 瑙嗚鏁堟灉 - Line2D
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

	# 鍒濆鍖栧彲閫夌殑鍖哄煙浼ゅ璁℃椂鍣?
	if config.get("damage", 0) > 0:
		effect_data["damage_timer"] = 0.0

	# 娣诲姞鍒?SkillEffectManager 鑷韩锛坅utoload 鑺傜偣锛岃鑹插垏鎹笉褰卞搷锛?
	add_child(area)

	active_effects[effect_id] = effect_data

	# 鍚姩 Debuff 鍖哄煙鐢熷懡鍛ㄦ湡
	_start_debuff_zone_lifecycle(effect_id)

	return effect_id

## 鍚姩 Debuff 鍖哄煙鐢熷懡鍛ㄦ湡绠＄悊
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

## 鏇存柊 Debuff 鍖哄煙鏁堟灉
func _update_debuff_zone(effect_id: int, delta: float) -> void:
	if not active_effects.has(effect_id):
		return

	var effect_data = active_effects[effect_id]
	if _is_effect_ending(effect_data):
		return
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

	# 鍙€夌殑鍖哄煙浼ゅ tick锛堢嫭绔嬩簬 debuff tick锛?
	if effect_data.has("damage_timer"):
		var damage_interval: float = config.get("damage_interval", 0.5)
		effect_data["damage_timer"] += delta
		if effect_data["damage_timer"] >= damage_interval:
			_apply_damage(area, config.get("damage", 0))
			effect_data["damage_timer"] = 0.0

	# 鎸佺画鏃堕棿鍒版湡 鈫?娣″嚭骞剁Щ闄?
	if effect_data["elapsed"] >= duration:
		_end_debuff_zone(effect_id)

## 瀵瑰尯鍩熷唴鏁屼汉搴旂敤 Debuff 鏁堟灉
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
				print("[SkillEffectManager] Debuff鍖哄煙鍛戒腑: %s -> %s (type=%s)" % [debuff_type, enemy.name, enemy.get_class()])
			_apply_single_debuff(enemy, debuff_type, debuff_value, debuff_duration)

## 瀵瑰崟涓晫浜哄簲鐢?Debuff
func _apply_single_debuff(enemy: Node, debuff_type: String, debuff_value: float, debuff_duration: float) -> void:
	match debuff_type:
		"slow":
			# 鍑忛€?- debuff_value 涓哄噺閫熸瘮渚嬶紙濡?0.5 = 50% 鍑忛€燂級
			enemy.apply_status("slow", debuff_duration, debuff_value)
		"damage_amp":
			# 浼ゅ鏀惧ぇ - 浣跨敤 "marked" 鐘舵€?
			enemy.apply_status("marked", debuff_duration, debuff_value)
		"poison":
			# 涓瘨 - DOT 浼ゅ
			enemy.apply_status("poison", debuff_duration, debuff_value, 1, 1.0)
		"freeze":
			# 鍐板喕 - 瀹屽叏鍋滄绉诲姩鍜屾敾鍑?
			enemy.apply_status("freeze", debuff_duration, debuff_value)
		"fear":
			# 鎭愭儳 - 閫冭窇琛屼负锛岄渶瑕?tick 鏇存柊绉诲姩鏂瑰悜
			enemy.apply_status("fear", debuff_duration, debuff_value, 1, 0.1)
		"curse":
			# 璇呭拻 - DOT 浼ゅ锛岀被浼?poison
			enemy.apply_status("curse", debuff_duration, debuff_value, 1, 1.0)

## Debuff 鍖哄煙娣″嚭骞剁Щ闄?
func _end_debuff_zone(effect_id: int) -> void:
	if not active_effects.has(effect_id):
		return

	var effect_data = active_effects[effect_id]
	if _is_effect_ending(effect_data):
		return
	_mark_effect_ending(effect_data)
	var area = effect_data["area"]
	var config = effect_data["config"]

	if not is_instance_valid(area):
		active_effects.erase(effect_id)
		return

	var fade_out_duration = config.get("fade_out_duration", 0.3)

	# 娣″嚭瑙嗚鏁堟灉
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

	# 娌℃湁瑙嗚鍏冪礌锛岀洿鎺ュ垹闄?
	area.queue_free()
	active_effects.erase(effect_id)

# ==============================================================================
# 鍙敜鐗╃鐞?
# ==============================================================================

## 鍒涘缓鍙敜鐗?
## @param config: 閰嶇疆瀛楀吀
##   - position: Vector2 (蹇呴渶) - 鐢熸垚浣嶇疆
##   - summon_type: String (蹇呴渶) - 鍙敜鐗╃被鍨?("turret", "beetle", "slime", "phantom")
##   - duration: float (蹇呴渶) - 瀛樻椿鏃堕棿
##   - health: int (鍙€? 榛樿 -1) - 鐢熷懡鍊硷紝-1 涓烘棤闄?
##   - damage: int (鍙€? 榛樿 10) - 鏀诲嚮浼ゅ
##   - attack_interval: float (鍙€? 榛樿 1.0) - 鏀诲嚮闂撮殧
##   - attack_range: float (鍙€? 榛樿 200.0) - 鏀诲嚮鑼冨洿
##   - max_count: int (鍙€? 榛樿 5) - 鍚屾妧鑳芥渶澶ф暟閲?
##   - owner_skill_id: String (蹇呴渶) - 鎵€灞炴妧鑳?ID
##   - color: Color (鍙€? - 鍗犱綅棰滆壊
## @return: effect_id, -1 琛ㄧず澶辫触
func create_summon(config: Dictionary) -> int:
	# 楠岃瘉蹇呴渶鍙傛暟
	if not config.has("position"):
		push_error("[SkillEffectManager] create_summon 缂哄皯蹇呴渶鍙傛暟: position")
		return -1
	if not config.has("owner_skill_id"):
		push_error("[SkillEffectManager] create_summon 缂哄皯蹇呴渶鍙傛暟: owner_skill_id")
		return -1

	var owner_skill_id: String = config["owner_skill_id"]
	var max_count: int = config.get("max_count", 5)

	# --- max_count 闄愬埗锛氱Щ闄ゆ渶鏃╃殑鍙敜鐗?---
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

	# 鏍规嵁绫诲瀷鍐冲畾瑙嗚鍗婂緞
	var visual_radius: float = 16.0
	if summon_type in ["beetle", "slime"]:
		visual_radius = 10.0

	# --- 鍒涘缓鍙敜鐗╂牴鑺傜偣 ---
	var summon_root = Node2D.new()
	summon_root.name = "Summon_%s_%d" % [summon_type, effect_id]
	summon_root.global_position = pos

	# --- Area2D 鐢ㄤ簬鏁屼汉妫€娴?---
	var detect_area = Area2D.new()
	detect_area.name = "DetectArea"
	detect_area.collision_layer = 0
	detect_area.collision_mask = 1 | 2  # 妫€娴?Layer1(Player/Enemy榛樿) + Layer2(Enemy鏍囪)
	detect_area.monitorable = false
	detect_area.monitoring = true

	# 妫€娴嬭寖鍥寸鎾炲舰鐘讹紙鍦嗗舰锛宎ttack_range锛?
	var detect_col = CollisionShape2D.new()
	var detect_shape = CircleShape2D.new()
	detect_shape.radius = attack_range
	detect_col.shape = detect_shape
	detect_area.add_child(detect_col)
	summon_root.add_child(detect_area)

	# --- Polygon2D 褰╄壊鍦嗗舰鍗犱綅瑙嗚 ---
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

	# 娣诲姞鍒?SkillEffectManager 鑷韩锛堣鑹插垏鎹笉褰卞搷锛?
	add_child(summon_root)

	# --- 淇濆瓨鏁堟灉鏁版嵁 ---
	var effect_data = {
		"type": "summon",
		"node": summon_root,
		"detect_area": detect_area,
		"vis_poly": vis_poly,
		"config": config,
		"elapsed": 0.0,
		"attack_timer": 0.0,
		"owner_skill_id": owner_skill_id,
		"focus_target": null,  # 鐢ㄤ簬 focus_fire 鎸囦护
	}
	active_effects[effect_id] = effect_data

	# 鍚姩鍙敜鐗╃敓鍛藉懆鏈?
	_start_summon_lifecycle(effect_id)

	return effect_id

## 鍚戞寚瀹氭妧鑳界殑鎵€鏈夊彫鍞ょ墿鍙戦€佹寚浠?
## @param owner_skill_id: String - 鎵€灞炴妧鑳?ID
## @param command: String - 鎸囦护: "focus_fire", "self_destruct", "return"
## @param target: Node2D (鍙€? - 鐩爣鑺傜偣锛堢敤浜?focus_fire锛?
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
			# 棰勭暀锛氬彫鍞ょ墿杩斿洖鐜╁韬竟
			pass

## 鑾峰彇鎸囧畾鎶€鑳界殑鎵€鏈夊彫鍞ょ墿 effect_id 鍒楄〃锛堟寜鍒涘缓椤哄簭锛?
func _get_summon_ids_by_skill(owner_skill_id: String) -> Array:
	var ids: Array = []
	for eid in active_effects.keys():
		var data = active_effects[eid]
		if data.get("type") == "summon" and data.get("owner_skill_id") == owner_skill_id:
			ids.append(eid)
	ids.sort()  # effect_id 閫掑锛屾帓搴忓嵆涓哄垱寤洪『搴?
	return ids

## 寮哄埗鎵ц max_count 闄愬埗
func _enforce_summon_max_count(owner_skill_id: String, max_count: int) -> void:
	var existing_ids = _get_summon_ids_by_skill(owner_skill_id)
	# 濡傛灉宸茶揪涓婇檺锛岀Щ闄ゆ渶鏃╃殑鍙敜鐗╋紙鍙兘闇€瑕佺Щ闄ゅ涓級
	while existing_ids.size() >= max_count and not existing_ids.is_empty():
		var oldest_id = existing_ids[0]
		_remove_summon(oldest_id)
		existing_ids.remove_at(0)

## 鍚姩鍙敜鐗╃敓鍛藉懆鏈熺鐞?
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

## 鏇存柊鍙敜鐗╅€昏緫
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

	# 鎸佺画鏃堕棿鍒版湡 鈫?绉婚櫎
	if effect_data["elapsed"] >= duration:
		_end_summon(effect_id)
		return

	# --- 鏀诲嚮閫昏緫 ---
	var attack_interval: float = config.get("attack_interval", 1.0)
	effect_data["attack_timer"] += delta
	if effect_data["attack_timer"] >= attack_interval:
		_summon_attack(effect_id)
		effect_data["attack_timer"] = 0.0

## 鍙敜鐗╂敾鍑婚€昏緫
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

	# 骞诲奖绫诲瀷锛氬槻璁借寖鍥村唴鎵€鏈夋晫浜猴紙姣忔鏀诲嚮 tick 鍒锋柊浠囨仺锛?
	if summon_type == "phantom":
		_phantom_taunt_enemies(effect_data, detect_area, summon_node)

	# 鏌ユ壘鐩爣锛氫紭鍏?focus_target锛屽惁鍒欐渶杩戞晫浜?
	var target_enemy = _find_summon_target(effect_data, detect_area, summon_node)
	if target_enemy == null:
		return

	# 閫犳垚浼ゅ
	if target_enemy.has_node("HealthComponent"):
		target_enemy.health_component.take_damage(damage, {
			"source": summon_node,
			"kind": "summon_attack",
			"damage_type": "DMG_DIRECT",
		})

	# 鏀诲嚮瑙嗚鍙嶉锛氱煭鏆傞棯鐧?
	var vis_poly = effect_data["vis_poly"]
	if is_instance_valid(vis_poly):
		var original_color = vis_poly.color
		vis_poly.color = Color.WHITE
		var tween = summon_node.create_tween()
		tween.tween_property(vis_poly, "color", original_color, 0.15)

## 鏌ユ壘鍙敜鐗╂敾鍑荤洰鏍?
func _find_summon_target(effect_data: Dictionary, detect_area: Area2D, summon_node: Node2D) -> Node:
	# 浼樺厛浣跨敤 focus_fire 鎸囧畾鐨勭洰鏍?
	var focus_target = effect_data.get("focus_target")
	if focus_target != null and is_instance_valid(focus_target):
		# focus_fire 妯″紡锛氭敾鍑昏窛绂?target 鏈€杩戠殑鏁屼汉
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

	# 榛樿锛氭敾鍑昏寖鍥村唴鏈€杩戞晫浜?
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

## 骞诲奖鍢茶锛氳鑼冨洿鍐呮晫浜烘敾鍑诲够褰卞垎韬€岄潪鐜╁
func _phantom_taunt_enemies(effect_data: Dictionary, detect_area: Area2D, summon_node: Node2D) -> void:
	if not is_instance_valid(detect_area) or not is_instance_valid(summon_node):
		return
	var targets = detect_area.get_overlapping_bodies() + detect_area.get_overlapping_areas()
	for t in targets:
		var enemy = _resolve_enemy(t)
		if enemy and enemy.has_method("set_taunt_target"):
			# 鍙槻璁介偅浜涜繕娌¤鍢茶鍒拌繖涓够褰辩殑鏁屼汉锛屾垨鑰?override_target 宸插け鏁堢殑
			if not is_instance_valid(enemy.override_target) or enemy.override_target != summon_node:
				enemy.set_taunt_target(summon_node)

## 浠庣鎾炵洰鏍囪В鏋愬嚭鏁屼汉鑺傜偣
func _resolve_enemy(target: Node) -> Node:
	if target.is_in_group("enemies") and is_instance_valid(target):
		return target
	if target.owner and target.owner.is_in_group("enemies") and is_instance_valid(target.owner):
		return target.owner
	return null

## 鍙敜鐗╄嚜鐖?
func _self_destruct_summon(effect_id: int) -> void:
	if not active_effects.has(effect_id):
		return

	var effect_data = active_effects[effect_id]
	var summon_node = effect_data["node"]
	var detect_area: Area2D = effect_data["detect_area"]
	var config = effect_data["config"]
	var damage: int = config.get("damage", 10) * 2  # 鑷垎浼ゅ = 2x 鏅€氫激瀹?

	if not is_instance_valid(summon_node) or not is_instance_valid(detect_area):
		_remove_summon(effect_id)
		return

	# 瀵硅寖鍥村唴鎵€鏈夋晫浜洪€犳垚鐖嗙偢浼ゅ
	var targets = detect_area.get_overlapping_bodies() + detect_area.get_overlapping_areas()
	for t in targets:
		var enemy = _resolve_enemy(t)
		if enemy and enemy.has_node("HealthComponent"):
			enemy.health_component.take_damage(damage, {
				"source": summon_node,
				"kind": "summon_explode",
				"damage_type": "DMG_AOE",
			})

	# 鐖嗙偢瑙嗚鍙嶉锛氬揩閫熸斁澶?+ 娣″嚭
	var vis_poly = effect_data["vis_poly"]
	if is_instance_valid(vis_poly):
		vis_poly.color = Color(1.0, 0.5, 0.0, 1.0)  # 姗欒壊鐖嗙偢
		var tween = summon_node.create_tween()
		tween.tween_property(summon_node, "scale", Vector2(2.5, 2.5), 0.15)
		tween.parallel().tween_property(vis_poly, "modulate:a", 0.0, 0.15)
		tween.tween_callback(func():
			_remove_summon(effect_id)
		)
	else:
		_remove_summon(effect_id)

## 鍙敜鐗╁埌鏈熸贰鍑虹Щ闄?
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

## 绔嬪嵆绉婚櫎鍙敜鐗?
func _remove_summon(effect_id: int) -> void:
	if not active_effects.has(effect_id):
		return

	var effect_data = active_effects[effect_id]
	var summon_node = effect_data["node"]
	var summon_type: String = effect_data["config"].get("summon_type", "turret")

	# 骞诲奖娑堝け鏃舵竻闄ゆ墍鏈夎鍢茶鍒板畠鐨勬晫浜虹殑 override_target
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
# 鐢熷懡鍛ㄦ湡绠＄悊
# ==============================================================================

## 鍚姩鏁堟灉鐢熷懡鍛ㄦ湡绠＄悊
func _start_effect_lifecycle(effect_id: int) -> void:
	if not active_effects.has(effect_id):
		return
	
	var effect_data = active_effects[effect_id]
	var area = effect_data["area"]
	var config = effect_data["config"]
	
	# 鍒涘缓绠＄悊 Timer
	var timer = Timer.new()
	timer.wait_time = 0.016  # ~60fps
	area.add_child(timer)
	
	timer.timeout.connect(func():
		_update_effect(effect_id, timer.wait_time)
	)
	
	timer.start()

## 鏇存柊鏁堟灉
func _update_effect(effect_id: int, delta: float) -> void:
	if not active_effects.has(effect_id):
		return

	var effect_data = active_effects[effect_id]
	if _is_effect_ending(effect_data):
		return
	var area = effect_data["area"]
	var config = effect_data["config"]
	
	if not is_instance_valid(area):
		active_effects.erase(effect_id)
		return
	
	effect_data["elapsed"] += delta
	var duration = config.get("duration", 5.0)
	
	# 浼ゅ tick
	if config.get("damage", 0) > 0:
		if not effect_data.has("damage_timer"):
			effect_data["damage_timer"] = 0.0
		
		effect_data["damage_timer"] += delta
		var damage_interval = config.get("damage_interval", 0.5)
		
		if effect_data["damage_timer"] >= damage_interval:
			_apply_damage(area, config.get("damage", 0))
			effect_data["damage_timer"] = 0.0
	
	# 鐗╃悊鏁堟灉 tick
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
	
	# 鐢熷懡鍛ㄦ湡缁撴潫
	if effect_data["elapsed"] >= duration:
		_end_effect(effect_id)

## 搴旂敤浼ゅ
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
			enemy.health_component.take_damage(damage, {
				"source": self,
				"kind": "area_effect_tick",
				"damage_type": "DMG_AOE",
				"skill_slot": "q",
				"space_skill_mode": "closed",
			})

## 搴旂敤鍚搁檮鍒颁腑蹇?
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

## 搴旂敤鍚搁檮鍒扮嚎娈?
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

## 缁撴潫鏁堟灉
func _end_effect(effect_id: int) -> void:
	if not active_effects.has(effect_id):
		return

	var effect_data = active_effects[effect_id]
	if _is_effect_ending(effect_data):
		return
	_mark_effect_ending(effect_data)
	var area = effect_data["area"]
	var config = effect_data["config"]
	
	if not is_instance_valid(area):
		active_effects.erase(effect_id)
		return
	
	# 娣″嚭鍔ㄧ敾
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
	
	# 娌℃湁瑙嗚鍏冪礌锛岀洿鎺ュ垹闄?
	area.queue_free()
	active_effects.erase(effect_id)

# ==============================================================================
# 鎵嬪姩鎺у埗
# ==============================================================================

## 鎵嬪姩绉婚櫎鏁堟灉
func remove_effect(effect_id: int) -> void:
	if not active_effects.has(effect_id):
		return

	var effect_data = active_effects[effect_id]

	if effect_data.get("type") == "buff_zone" and effect_data.has("area") and effect_data.has("config"):
		var area_var: Variant = effect_data["area"]
		var targets: Array = effect_data.get("buff_targets", [])
		if targets.is_empty() and area_var is Area2D and is_instance_valid(area_var):
			var area: Area2D = area_var
			if area.monitoring:
				targets = _collect_buff_zone_targets(area)
		if area_var is Area2D and is_instance_valid(area_var):
			_clear_buff_zone_buffs(area_var, effect_data["config"], targets)

	if effect_data.get("type") == "summon":
		_remove_summon(effect_id)
		return

	var node_key = "area"
	if effect_data.get("type") == "wall":
		node_key = "static_body"
	elif effect_data.get("type") == "debuff_zone":
		node_key = "area"

	if effect_data.has(node_key):
		var node_var: Variant = effect_data[node_key]
		if typeof(node_var) == TYPE_OBJECT and is_instance_valid(node_var):
			node_var.call_deferred("queue_free")

	active_effects.erase(effect_id)

## 娓呯悊鎵€鏈夋晥鏋?
func clear_all_effects() -> void:
	for effect_id in active_effects.keys().duplicate():
		remove_effect(effect_id)
