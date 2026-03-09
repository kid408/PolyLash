extends SkillBase
class_name SkillStormEye

## ==============================================================================
## 寰￠鑰匛鎶€鑳?- 鏆撮鐪?
## ==============================================================================
## 
## 鍔熻兘璇存槑:
## - 鎸塃閿湪鐜╁浣嶇疆鐢熸垚鑼冨洿鏆撮鐪?
## - 瀵硅寖鍥村唴鏁屼汉閫犳垚鎸佺画浼ゅ
## - 寮哄姏鍚搁檮鏁屼汉鍒颁腑蹇?
## - 甯︽湁瑙嗚鐗规晥鍜岄煶鏁?
## 
## 浣跨敤鏂规硶:
##   - 鎸塃閿噴鏀?
## 
## ==============================================================================

# ==============================================================================
# 鎶€鑳藉弬鏁帮紙浠嶤SV鍔犺浇锛?
# ==============================================================================

## 鏆撮鐪煎崐寰?
var storm_eye_radius: float = 140.0

## 鏆撮鐪间激瀹?
var storm_eye_damage: int = 35

## 鏆撮鐪煎惛闄勫姏搴?
var storm_eye_pull_force: float = 500.0

## 鏆撮鐪兼寔缁椂闂?
var storm_eye_duration: float = 3.0

## 浼ゅtick闂撮殧
var damage_tick_interval: float = 0.5

## 鐗╃悊tick闂撮殧
var physics_tick_interval: float = 0.05

## 宸茬敓鎴愮殑鏁堟灉鑺傜偣鍒楄〃锛堢敤浜庢竻鐞嗭級
var spawned_effects: Array[Node] = []

# ==============================================================================
# 鐢熷懡鍛ㄦ湡
# ==============================================================================

func _ready() -> void:
	super._ready()

# ==============================================================================
# 鎶€鑳芥墽琛?
# ==============================================================================

## 鎵ц鎶€鑳?
func execute() -> void:
	if not consume_energy():
		if skill_owner:
			Global.spawn_floating_text(skill_owner.global_position, "No Energy!", Color.RED)
		return
	
	if not skill_owner:
		return
	
	# 鐩告満闇囧姩
	Global.on_camera_shake.emit(8.0, 0.2)
	
	# 鐢熸垚鏆撮鐪?
	call_deferred("_spawn_storm_eye", skill_owner.global_position)
	
	# 寮€濮嬪喎鍗?
	start_cooldown()

# ==============================================================================
# 鏆撮鐪肩敓鎴?
# ==============================================================================

## 鐢熸垚鏆撮鐪?
func _spawn_storm_eye(center_pos: Vector2) -> void:
	var area = Area2D.new()
	area.global_position = center_pos
	area.collision_mask = 1 | 2  # 妫€娴?Layer1(Player/Enemy榛樿) + Layer2(Enemy鏍囪)
	area.monitorable = false
	area.monitoring = true
	
	# 纰版挒褰㈢姸
	var col = CollisionShape2D.new()
	var shape = CircleShape2D.new()
	shape.radius = storm_eye_radius
	col.shape = shape
	area.add_child(col)
	
	# 瑙嗚鏁堟灉锛堝渾褰㈠杈瑰舰锛?
	var vis = Polygon2D.new()
	var points = PackedVector2Array()
	var steps = 32
	for i in range(steps):
		var angle = i * TAU / steps
		points.append(Vector2(cos(angle), sin(angle)) * storm_eye_radius)
	
	vis.polygon = points
	vis.color = Color(0.1, 1.2, 1.2, 0.4)
	vis.z_index = 5
	area.add_child(vis)
	
	get_tree().current_scene.add_child(area)
	area.add_to_group("player_skill_effects")
	spawned_effects.append(area)  # 杩借釜鏁堟灉鑺傜偣
	Global.spawn_floating_text(center_pos, "VORTEX!", Color.CYAN)
	
	# 缂╂斁鍔ㄧ敾
	vis.scale = Vector2.ZERO
	var tween = area.create_tween()
	tween.tween_property(vis, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_BACK)
	
	# 鐗╃悊Tick锛堝惛鍚戜腑蹇冿級
	var timer = Timer.new()
	timer.wait_time = physics_tick_interval
	timer.autostart = true
	area.add_child(timer)
	timer.timeout.connect(_on_storm_zone_tick.bind(area, center_pos))
	
	# 浼ゅTick
	var dmg_timer = Timer.new()
	dmg_timer.wait_time = damage_tick_interval
	dmg_timer.autostart = true
	area.add_child(dmg_timer)
	dmg_timer.timeout.connect(_on_damage_tick.bind(area, storm_eye_damage))
	
	# 瀵垮懡
	var life = get_tree().create_timer(storm_eye_duration)
	life.timeout.connect(_on_object_expired.bind(area, vis))

# ==============================================================================
# 鍥炶皟鍑芥暟
# ==============================================================================

## 鏆撮鐪肩墿鐞嗘晥鏋滐細灏嗘晫浜哄惛闄勫埌涓績鐐?
func _on_storm_zone_tick(area_ref: Area2D, center: Vector2) -> void:
	if not is_instance_valid(area_ref) or area_ref.is_queued_for_deletion():
		return
	
	var targets = area_ref.get_overlapping_bodies() + area_ref.get_overlapping_areas()
	var dt = physics_tick_interval
	
	for t in targets:
		var enemy = null
		if t.is_in_group("enemies"):
			enemy = t
		elif t.owner and t.owner.is_in_group("enemies"):
			enemy = t.owner
		
		if is_instance_valid(enemy):
			var dir = (center - enemy.global_position).normalized()
			enemy.global_position += dir * storm_eye_pull_force * dt

## 浼ゅtick
func _on_damage_tick(area_ref: Area2D, amount: int) -> void:
	if not is_instance_valid(area_ref) or area_ref.is_queued_for_deletion():
		return
	
	var targets = area_ref.get_overlapping_bodies() + area_ref.get_overlapping_areas()
	for t in targets:
		var enemy = null
		if t.is_in_group("enemies"):
			enemy = t
		elif t.owner and t.owner.is_in_group("enemies"):
			enemy = t.owner
		
		if enemy and enemy.has_node("HealthComponent"):
			enemy.health_component.take_damage(amount)

## 瀵硅薄杩囨湡
func _on_object_expired(area_ref: Area2D, visual_ref: Node) -> void:
	if is_instance_valid(area_ref):
		if is_instance_valid(visual_ref):
			var tween = area_ref.create_tween()
			tween.tween_property(visual_ref, "modulate:a", 0.0, 0.3)
			tween.tween_callback(func():
				if is_instance_valid(area_ref):
					area_ref.queue_free()
			)
		else:
			area_ref.queue_free()

## 娓呯悊璧勬簮锛堣鑹插垏鎹㈡椂璋冪敤锛?
func cleanup() -> void:
	for effect: Node in spawned_effects:
		if is_instance_valid(effect):
			effect.queue_free()
	spawned_effects.clear()

