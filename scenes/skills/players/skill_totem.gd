extends SkillBase
class_name SkillTotem

## ==============================================================================
## 宸ュ叺E鎶€鑳?- 鍥捐吘
## ==============================================================================
## 
## 鍔熻兘璇存槑:
## - 鎸塃閿湪鐜╁浣嶇疆鐢熸垚鍥捐吘
## - 鍥捐吘鍢茶闄勮繎鏁屼汉
## - 鍥捐吘鏈夌敓鍛藉€硷紝琚嚮姣佸悗鐖嗙偢
## - 鍥捐吘鎸佺画涓€瀹氭椂闂村悗鑷姩鐖嗙偢
## 
## 浣跨敤鏂规硶:
##   - 鎸塃閿噴鏀?
## 
## ==============================================================================

# ==============================================================================
# 鎶€鑳藉弬鏁帮紙浠嶤SV鍔犺浇锛?
# ==============================================================================

## 鍥捐吘鎸佺画鏃堕棿
var totem_duration: float = 8.0

## 鍥捐吘鏈€澶х敓鍛藉€?
var totem_max_health: float = 200.0

## 鍥捐吘鍢茶鑼冨洿
var totem_taunt_radius: float = 600.0

## 鍥捐吘鐖嗙偢鍗婂緞
var totem_explosion_radius: float = 120.0

## 鍥捐吘鐖嗙偢浼ゅ
var totem_explosion_damage: int = 150

## 宸茬敓鎴愮殑鍥捐吘鍒楄〃锛堢敤浜庢竻鐞嗭級
var spawned_totems: Array[Node] = []

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
	
	# 鐢熸垚鍥捐吘
	var totem = _create_totem()
	totem.global_position = skill_owner.global_position
	get_tree().current_scene.add_child(totem)
	spawned_totems.append(totem)  # 杩借釜鍥捐吘
	
	# 鍢茶闄勮繎鏁屼汉
	var enemies = get_tree().get_nodes_in_group("enemies")
	for e in enemies:
		if e.global_position.distance_to(skill_owner.global_position) < totem_taunt_radius:
			if e.has_method("set_taunt_target"):
				e.set_taunt_target(totem)
	
	Global.spawn_floating_text(skill_owner.global_position, "Taunt!", Color.GREEN)
	
	# 寮€濮嬪喎鍗?
	start_cooldown()

# ==============================================================================
# 鍥捐吘鍒涘缓
# ==============================================================================

## 鍒涘缓鍥捐吘
func _create_totem() -> Area2D:
	var totem = Area2D.new()
	totem.add_to_group("player")
	totem.add_to_group("player_skill_effects")
	
	# 纰版挒褰㈢姸
	var col = CollisionShape2D.new()
	var shape = CircleShape2D.new()
	shape.radius = 30.0
	col.shape = shape
	totem.add_child(col)
	
	# 瑙嗚鏁堟灉锛堜笁瑙掑舰锛?
	var vis = Polygon2D.new()
	vis.polygon = [Vector2(0, -30), Vector2(20, 10), Vector2(-20, 10)]
	vis.color = Color.GREEN
	totem.add_child(vis)
	
	# 鍙椾激鐩?
	var hurtbox = HurtboxComponent.new()
	var hb_col = CollisionShape2D.new()
	hb_col.shape = shape
	hurtbox.add_child(hb_col)
	hurtbox.collision_layer = 1
	totem.add_child(hurtbox)
	
	# 鍥捐吘鐘舵€?
	var state = {"hp": totem_max_health}
	
	# 鍙椾激鍥炶皟
	hurtbox.on_damaged.connect(func(hitbox):
		if not is_instance_valid(totem):
			return
		state.hp -= hitbox.damage
		Global.spawn_floating_text(totem.global_position, str(hitbox.damage), Color.WHITE)
		
		# 鍙椾激闂儊
		var tween = totem.create_tween()
		tween.tween_property(vis, "modulate", Color.RED, 0.1)
		tween.tween_property(vis, "modulate", Color.WHITE, 0.1)
		
		# 鐢熷懡鍊艰€楀敖锛岀垎鐐?
		if state.hp <= 0:
			_explode_totem(totem)
	)
	
	# 鎸佺画鏃堕棿瀹氭椂鍣?
	var timer = Timer.new()
	timer.wait_time = totem_duration
	timer.one_shot = true
	timer.autostart = true
	totem.add_child(timer)
	timer.timeout.connect(_on_totem_expired.bind(totem))
	
	return totem

# ==============================================================================
# 鍥捐吘鐖嗙偢
# ==============================================================================

## 鍥捐吘杩囨湡
func _on_totem_expired(totem: Node2D) -> void:
	if is_instance_valid(totem):
		_explode_totem(totem)

## 鍥捐吘鐖嗙偢
func _explode_totem(totem: Node2D) -> void:
	if not is_instance_valid(totem) or totem.is_queued_for_deletion():
		return
	
	# 瀵硅寖鍥村唴鏁屼汉閫犳垚浼ゅ
	var enemies = get_tree().get_nodes_in_group("enemies")
	var hit_count = 0
	
	for e in enemies:
		if not is_instance_valid(e):
			continue
		if e.global_position.distance_to(totem.global_position) < totem_explosion_radius:
			if e.has_node("HealthComponent"):
				e.health_component.take_damage(totem_explosion_damage)
				hit_count += 1
				if e.has_method("apply_knockback"):
					var dir = (e.global_position - totem.global_position).normalized()
					e.apply_knockback(dir, 300.0)
	
	if hit_count > 0:
		Global.on_camera_shake.emit(3.0, 0.1)
	
	# 鐖嗙偢瑙嗚鏁堟灉
	var flash = Polygon2D.new()
	var points = PackedVector2Array()
	for i in range(16):
		var angle = i * TAU / 16
		points.append(Vector2(cos(angle), sin(angle)) * totem_explosion_radius)
	flash.polygon = points
	flash.color = Color(1, 0.5, 0, 0.5)
	flash.global_position = totem.global_position
	get_tree().current_scene.add_child(flash)
	
	var tw = flash.create_tween()
	tw.tween_property(flash, "modulate:a", 0.0, 0.3)
	tw.tween_callback(func():
		if is_instance_valid(flash):
			flash.queue_free()
	)
	
	totem.queue_free()

## 娓呯悊璧勬簮锛堣鑹插垏鎹㈡椂璋冪敤锛?
func cleanup() -> void:
	for totem: Node in spawned_totems:
		if is_instance_valid(totem):
			totem.queue_free()
	spawned_totems.clear()

