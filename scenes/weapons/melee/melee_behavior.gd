extends WeaponBehavior
class_name MeleeBehavior

const DEBUG_VERBOSE := false

@export var hitbox: HitboxComponent

var current_shape: Node = null

func _ready() -> void:
	if not hitbox:
		var parent: Node = get_parent()
		if parent:
			hitbox = parent.get_node_or_null("HitboxComponent") as HitboxComponent

	if hitbox:
		if not hitbox.on_hit_hurtbox.is_connected(_on_melee_hit):
			hitbox.on_hit_hurtbox.connect(_on_melee_hit)
	else:
		printerr("[MeleeBehavior] hitbox is null")

func setup_hitbox(stats: WeaponStats) -> void:
	if not hitbox:
		printerr("[MeleeBehavior] hitbox is null")
		return
	if not stats:
		printerr("[MeleeBehavior] weapon stats is null")
		return

	cleanup_old_shape()

	var shape_type: String = stats.shape_type
	if shape_type.is_empty():
		shape_type = "point"

	match shape_type:
		"point":
			_create_point_shape(stats)
		"line", "thrust":
			_create_line_shape(stats)
		"sector":
			_create_sector_shape(stats)
		"circle":
			_create_circle_shape(stats)
		_:
			_create_point_shape(stats)

func cleanup_old_shape() -> void:
	if current_shape and is_instance_valid(current_shape):
		if is_instance_valid(hitbox) and current_shape.get_parent() == hitbox:
			hitbox.remove_child(current_shape)
		current_shape.queue_free()
		current_shape = null

func _create_point_shape(stats: WeaponStats) -> void:
	var collision_shape: CollisionShape2D = CollisionShape2D.new()
	var circle: CircleShape2D = CircleShape2D.new()

	var radius: float = max(1.0, stats.max_range * 0.5)
	var p1: String = str(stats.param1)
	if not p1.is_empty():
		var parsed: float = float(p1)
		if parsed > 0.0:
			radius = parsed

	circle.radius = radius
	collision_shape.shape = circle
	collision_shape.disabled = false
	collision_shape.position = Vector2(stats.max_range * 0.5, 0.0)

	hitbox.add_child(collision_shape)
	current_shape = collision_shape

func _create_line_shape(stats: WeaponStats) -> void:
	var collision_shape: CollisionShape2D = CollisionShape2D.new()
	var rect: RectangleShape2D = RectangleShape2D.new()

	var width: float = max(1.0, stats.max_range)
	var height: float = 20.0
	var p2: String = str(stats.param2)
	if not p2.is_empty():
		var parsed_h: float = float(p2)
		if parsed_h > 0.0:
			height = parsed_h

	rect.size = Vector2(width, height)
	collision_shape.shape = rect
	collision_shape.disabled = false
	collision_shape.position = Vector2(width * 0.5, 0.0)

	hitbox.add_child(collision_shape)
	current_shape = collision_shape

func _create_sector_shape(stats: WeaponStats) -> void:
	var collision_polygon: CollisionPolygon2D = CollisionPolygon2D.new()

	var angle_deg: float = stats.sector_angle
	if angle_deg <= 0.0:
		var p1: String = str(stats.param1)
		if not p1.is_empty():
			angle_deg = float(p1)
	if angle_deg <= 0.0:
		angle_deg = 90.0

	var radius: float = max(1.0, stats.max_range)
	collision_polygon.polygon = generate_sector_polygon(angle_deg, radius)

	hitbox.add_child(collision_polygon)
	current_shape = collision_polygon

func _create_circle_shape(stats: WeaponStats) -> void:
	var collision_shape: CollisionShape2D = CollisionShape2D.new()
	var circle: CircleShape2D = CircleShape2D.new()

	var radius: float = max(1.0, stats.max_range)
	var p1: String = str(stats.param1)
	if not p1.is_empty():
		var parsed: float = float(p1)
		if parsed > 0.0:
			radius = parsed

	circle.radius = radius
	collision_shape.shape = circle
	collision_shape.disabled = false

	hitbox.add_child(collision_shape)
	current_shape = collision_shape

func generate_sector_polygon(angle_deg: float, radius: float) -> PackedVector2Array:
	var points: PackedVector2Array = PackedVector2Array()
	points.append(Vector2.ZERO)

	var segments: int = 16
	var start_angle: float = -angle_deg * 0.5
	var end_angle: float = angle_deg * 0.5

	for i in range(segments + 1):
		var t: float = float(i) / float(segments)
		var current_angle: float = lerp(start_angle, end_angle, t)
		var rad: float = deg_to_rad(current_angle)
		points.append(Vector2(cos(rad), sin(rad)) * radius)

	return points

func create_attack_tween(shape_type: String):
	if shape_type == "sector" or shape_type == "circle":
		var t: Tween = create_tween()
		t.tween_property(hitbox, "rotation", PI * 2.0, weapon.data.stats.attack_duration)
		t.tween_property(hitbox, "rotation", 0.0, weapon.data.stats.back_duration)
		return t
	return null

func execute_attack() -> void:
	if not weapon or not weapon.data or not weapon.data.stats:
		return
	if not hitbox:
		return

	var stats: WeaponStats = weapon.data.stats
	weapon.is_attacking = true
	setup_hitbox(stats)

	Global.frame_freeze(0.02, 0.5)
	var attack_direction: Vector2 = Vector2.RIGHT.rotated(weapon.rotation)
	Global.on_directional_shake.emit(attack_direction, 0.8)

	var tween: Tween = create_tween()
	var recoil_pos: Vector2 = Vector2(weapon.atk_start_pos.x - stats.recoil, weapon.atk_start_pos.y)
	var attack_pos: Vector2 = Vector2(weapon.atk_start_pos.x + stats.max_range, weapon.atk_start_pos.y)

	tween.tween_property(weapon.sprite, "position", recoil_pos, stats.recoil_duration)
	tween.tween_callback(func():
		hitbox.enable()
		var damage_value: float = get_damage()
		var owner: Node2D = weapon.get_parent() as Node2D
		hitbox.setup(damage_value, critical, stats.knockback, owner)
	)
	tween.tween_property(weapon.sprite, "position", attack_pos, stats.attack_duration)
	tween.tween_callback(func():
		hitbox.disable()
	)
	tween.tween_property(weapon.sprite, "position", weapon.atk_start_pos, stats.back_duration)
	tween.finished.connect(func():
		weapon.is_attacking = false
		critical = false
	)

func _on_melee_hit(hurtbox: HurtboxComponent) -> void:
	call_deferred("_spawn_explosion_if_needed", hurtbox)

func _spawn_explosion_if_needed(hurtbox: HurtboxComponent) -> void:
	if not weapon or not weapon.data or not weapon.data.stats:
		return

	var stats: WeaponStats = weapon.data.stats
	if stats.explosion_radius <= 0.0:
		return

	var explosion_scene: PackedScene = load("res://scenes/vfx/explosion_area.tscn") as PackedScene
	if not explosion_scene:
		printerr("[MeleeBehavior] failed to load explosion scene")
		return

	var explosion: Node2D = explosion_scene.instantiate() as Node2D
	if not explosion:
		return

	if hurtbox and is_instance_valid(hurtbox):
		explosion.global_position = hurtbox.global_position
	else:
		explosion.global_position = weapon.global_position

	var valid_owner: Node = null
	var parent: Node = weapon.get_parent()
	if parent and is_instance_valid(parent):
		valid_owner = parent

	var base_damage: float = stats.damage
	if valid_owner and is_instance_valid(valid_owner):
		var owner_damage: Variant = valid_owner.get("damage")
		if typeof(owner_damage) == TYPE_FLOAT or typeof(owner_damage) == TYPE_INT:
			base_damage += float(owner_damage)
	elif Global.player and is_instance_valid(Global.player):
		var player_damage: Variant = Global.player.get("damage")
		if typeof(player_damage) == TYPE_FLOAT or typeof(player_damage) == TYPE_INT:
			base_damage += float(player_damage)

	var explosion_damage: float = base_damage * stats.explosion_damage_scale

	if explosion.has_method("setup"):
		explosion.call("setup", explosion_damage, stats.explosion_radius, valid_owner)

	get_tree().root.add_child(explosion)
