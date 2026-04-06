extends WeaponBehavior
class_name RangeBehavior

@onready var muzzle: Marker2D = get_node_or_null("Muzzle") as Marker2D

func _resolve_muzzle() -> Marker2D:
	if is_instance_valid(muzzle):
		return muzzle
	if weapon and is_instance_valid(weapon):
		var local_muzzle: Marker2D = weapon.get_node_or_null("WeaponBehavior/Muzzle") as Marker2D
		if is_instance_valid(local_muzzle):
			muzzle = local_muzzle
			return muzzle
		var sprite_muzzle: Marker2D = weapon.get_node_or_null("Sprite2D/Muzzle") as Marker2D
		if is_instance_valid(sprite_muzzle):
			muzzle = sprite_muzzle
			return muzzle
	return null

func execute_attack() -> void:
	weapon.is_attacking = true

	var active_muzzle: Marker2D = _resolve_muzzle()
	print("[RangeBehavior] begin attack: ", weapon.data.item_name if weapon.data else "unknown")
	print("[RangeBehavior] weapon_pos=", weapon.global_position, " rot_deg=", rad_to_deg(weapon.rotation))
	print("[RangeBehavior] muzzle_pos=", active_muzzle.global_position if active_muzzle else weapon.global_position)

	Global.frame_freeze(0.01, 0.7)
	var shoot_direction: Vector2 = Vector2.RIGHT.rotated(weapon.rotation)
	Global.on_directional_shake.emit(shoot_direction, 0.5)

	create_projectiles()

	var tween: Tween = create_tween()
	var attack_pos: Vector2 = Vector2(weapon.atk_start_pos.x - weapon.data.stats.recoil, weapon.atk_start_pos.y)
	tween.tween_property(weapon.sprite, "position", attack_pos, weapon.data.stats.recoil_duration)
	tween.tween_property(weapon.sprite, "position", weapon.atk_start_pos, weapon.data.stats.recoil_duration)
	await tween.finished

	weapon.is_attacking = false
	critical = false

func create_projectiles() -> void:
	if not weapon or not weapon.data or not weapon.data.stats:
		printerr("[RangeBehavior] missing weapon data")
		return

	if not weapon.data.stats.projectile_scene:
		printerr("[RangeBehavior] projectile_scene is null for ", weapon.data.item_name if weapon.data else "unknown")
		return

	var stats: WeaponStats = weapon.data.stats
	var bullet_mode: String = stats.bullet_mode if not stats.bullet_mode.is_empty() else "single"

	match bullet_mode:
		"single":
			spawn_single_bullet()
		"spread":
			spawn_spread_bullets()
		"pierce":
			spawn_pierce_bullet()
		"magic", "arc":
			spawn_magic_bullet()
		_:
			spawn_single_bullet()

	var bullet_count: int = stats.bullet_count if bullet_mode == "spread" else 1
	print("[RangeBehavior] fired ", bullet_mode, " x", bullet_count)

func spawn_single_bullet() -> void:
	spawn_bullet_at_angle(0.0)

func spawn_spread_bullets() -> void:
	var stats: WeaponStats = weapon.data.stats
	var count: int = stats.bullet_count
	var spread: float = stats.spread_angle

	for i in range(count):
		var angle_offset: float = 0.0
		if count > 1:
			var t: float = float(i) / float(count - 1)
			angle_offset = lerp(-spread / 2.0, spread / 2.0, t)
		spawn_bullet_at_angle(angle_offset)

func spawn_pierce_bullet() -> void:
	var stats: WeaponStats = weapon.data.stats
	var instance: Projectile = stats.projectile_scene.instantiate() as Projectile
	get_tree().root.add_child(instance)

	var active_muzzle: Marker2D = _resolve_muzzle()
	instance.global_position = active_muzzle.global_position if active_muzzle else weapon.global_position
	var velocity: Vector2 = Vector2.RIGHT.rotated(weapon.rotation) * stats.projectile_speed

	if instance.has_method("setup"):
		instance.setup({
			"pierce_count": stats.pierce_count,
			"effect_type": stats.effect_type,
			"param1": stats.param1,
			"param2": stats.param2,
			"param3": stats.param3
		})

	instance.set_projectile(velocity, get_damage(), critical, stats.knockback, weapon.get_parent(), stats)

func spawn_magic_bullet() -> void:
	var stats: WeaponStats = weapon.data.stats
	var instance: Projectile = stats.projectile_scene.instantiate() as Projectile
	get_tree().root.add_child(instance)

	var active_muzzle: Marker2D = _resolve_muzzle()
	instance.global_position = active_muzzle.global_position if active_muzzle else weapon.global_position
	var velocity: Vector2 = Vector2.RIGHT.rotated(weapon.rotation) * stats.projectile_speed

	if instance.has_method("setup"):
		var gravity: float = float(stats.param1) if not stats.param1.is_empty() else 0.0
		var homing_strength: float = float(stats.param2) if not stats.param2.is_empty() else 0.0
		instance.setup({
			"gravity": gravity,
			"homing_strength": homing_strength,
			"effect_type": stats.effect_type,
			"param1": stats.param1,
			"param2": stats.param2,
			"param3": stats.param3
		})

	instance.set_projectile(velocity, get_damage(), critical, stats.knockback, weapon.get_parent(), stats)

func spawn_bullet_at_angle(angle_offset: float) -> void:
	var stats: WeaponStats = weapon.data.stats
	var instance: Projectile = stats.projectile_scene.instantiate() as Projectile
	get_tree().root.add_child(instance)

	var active_muzzle: Marker2D = _resolve_muzzle()
	instance.global_position = active_muzzle.global_position if active_muzzle else weapon.global_position

	var angle: float = weapon.rotation + deg_to_rad(angle_offset)
	var velocity: Vector2 = Vector2.RIGHT.rotated(angle) * stats.projectile_speed

	print("[RangeBehavior] spawn bullet pos=", instance.global_position, " offset_deg=", angle_offset, " velocity=", velocity)

	if instance.has_method("setup"):
		instance.setup({
			"effect_type": stats.effect_type,
			"param1": stats.param1,
			"param2": stats.param2,
			"param3": stats.param3
		})

	instance.set_projectile(velocity, get_damage(), critical, stats.knockback, weapon.get_parent(), stats)
