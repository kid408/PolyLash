extends SkillBase
class_name SkillStormEye

var storm_eye_radius: float = 145.0
var storm_eye_damage: int = 34
var storm_eye_pull_force: float = 520.0
var storm_eye_duration: float = 3.2
var damage_tick_interval: float = 0.33
var physics_tick_interval: float = 0.05
var reverse_push_scale: float = 0.75

var spawned_effects: Array[Node] = []

const WIND_ACTIVE_META: String = "wind_path_active_until_msec"

func execute() -> void:
	if not can_execute():
		return
	if not consume_energy():
		if is_instance_valid(skill_owner):
			Global.spawn_floating_text(skill_owner.global_position, "No Energy!", Color.RED)
		return
	if not is_instance_valid(skill_owner):
		return

	var center_pos: Vector2 = skill_owner.get_global_mouse_position()
	var reverse_mode: bool = _is_wind_window_active()
	call_deferred("_spawn_storm_eye", center_pos, reverse_mode)
	Global.on_camera_shake.emit(6.8, 0.12)
	Global.spawn_floating_text(center_pos, "REVERSE FLOW" if reverse_mode else "STORM EYE", Color(0.55, 1.25, 1.35))
	start_cooldown()

func _spawn_storm_eye(center_pos: Vector2, reverse_mode: bool) -> void:
	var area: Area2D = Area2D.new()
	area.global_position = center_pos
	area.collision_layer = 0
	area.collision_mask = 1 | 2
	area.monitorable = false
	area.monitoring = true
	area.name = "StormEye_%s" % str(Time.get_ticks_msec())

	var col: CollisionShape2D = CollisionShape2D.new()
	var shape: CircleShape2D = CircleShape2D.new()
	shape.radius = storm_eye_radius
	col.shape = shape
	area.add_child(col)

	var vis: Polygon2D = Polygon2D.new()
	vis.polygon = _build_circle_points(storm_eye_radius, 36)
	vis.color = Color(0.16, 1.2, 1.25, 0.42) if not reverse_mode else Color(0.62, 1.35, 1.45, 0.48)
	vis.z_index = 9
	area.add_child(vis)

	get_tree().current_scene.add_child(area)
	area.add_to_group("player_skill_effects")
	spawned_effects.append(area)

	var intro_tween: Tween = area.create_tween()
	vis.scale = Vector2(0.25, 0.25)
	intro_tween.tween_property(vis, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK)

	var move_timer: Timer = Timer.new()
	move_timer.wait_time = max(0.02, physics_tick_interval)
	move_timer.one_shot = false
	move_timer.autostart = true
	area.add_child(move_timer)
	move_timer.timeout.connect(_on_storm_move_tick.bind(weakref(area), reverse_mode))

	var damage_timer: Timer = Timer.new()
	damage_timer.wait_time = max(0.08, damage_tick_interval)
	damage_timer.one_shot = false
	damage_timer.autostart = true
	area.add_child(damage_timer)
	damage_timer.timeout.connect(_on_storm_damage_tick.bind(weakref(area), reverse_mode))

	var life_timer: SceneTreeTimer = get_tree().create_timer(max(0.2, storm_eye_duration))
	life_timer.timeout.connect(_on_storm_expired.bind(weakref(area), weakref(vis)))

func _on_storm_move_tick(area_ref: WeakRef, reverse_mode: bool) -> void:
	var area_obj: Variant = area_ref.get_ref() if area_ref != null else null
	if area_obj == null or not is_instance_valid(area_obj):
		return
	if not (area_obj is Area2D):
		return
	var area: Area2D = area_obj

	var elapsed_ratio: float = _estimate_elapsed_ratio(area)
	for enemy in _extract_enemies(area):
		var to_center: Vector2 = area.global_position - enemy.global_position
		var distance: float = to_center.length()
		var dir: Vector2 = to_center / max(1.0, distance)
		var force: float = storm_eye_pull_force
		if reverse_mode and elapsed_ratio < 0.45:
			force = -storm_eye_pull_force * reverse_push_scale
		if enemy.has_method("apply_knockback"):
			enemy.call("apply_knockback", dir, force * physics_tick_interval)
		else:
			enemy.global_position += dir * force * physics_tick_interval * 0.04

func _on_storm_damage_tick(area_ref: WeakRef, reverse_mode: bool) -> void:
	var area_obj: Variant = area_ref.get_ref() if area_ref != null else null
	if area_obj == null or not is_instance_valid(area_obj):
		return
	if not (area_obj is Area2D):
		return
	var area: Area2D = area_obj

	var hit_count: int = 0
	for enemy in _extract_enemies(area):
		var damage: int = storm_eye_damage
		if reverse_mode and enemy.has_method("has_status") and bool(enemy.call("has_status", "marked")):
			damage = max(damage, int(round(float(storm_eye_damage) * 1.35)))
		_apply_damage(enemy, damage)
		_apply_status(enemy, "slow", 0.9, 0.28, 1, 0.1)
		_apply_status(enemy, "marked", 1.1, 0.10, 1, 0.2)
		hit_count += 1

	if hit_count > 0 and reverse_mode:
		Global.spawn_floating_text(area.global_position, "REVERSE x%d" % hit_count, Color(0.7, 1.35, 1.45))

func _on_storm_expired(area_ref: WeakRef, visual_ref: WeakRef) -> void:
	var area_obj: Variant = area_ref.get_ref() if area_ref != null else null
	if area_obj == null or not is_instance_valid(area_obj):
		return
	if not (area_obj is Area2D):
		return
	var area: Area2D = area_obj

	var impact: int = 0
	for enemy in _extract_enemies(area):
		_apply_damage(enemy, int(round(float(storm_eye_damage) * 1.5)))
		_apply_status(enemy, "slow", 1.0, 0.34, 1, 0.1)
		impact += 1
	if impact > 0:
		spawn_skill_vfx(area.global_position, Color(0.58, 1.28, 1.36, 0.86), 0.78)
		Global.on_camera_shake.emit(8.2, 0.13)

	var visual_obj: Variant = visual_ref.get_ref() if visual_ref != null else null
	if visual_obj != null and is_instance_valid(visual_obj):
		var vis: Node = visual_obj
		var fade_tween: Tween = area.create_tween()
		fade_tween.tween_property(vis, "modulate:a", 0.0, 0.2)
		fade_tween.tween_callback(_queue_free_if_valid.bind(weakref(area)))
	else:
		area.queue_free()

func _is_wind_window_active() -> bool:
	if not is_instance_valid(skill_owner):
		return false
	if not skill_owner.has_meta(WIND_ACTIVE_META):
		return false
	var expire_msec: int = int(skill_owner.get_meta(WIND_ACTIVE_META, 0))
	return Time.get_ticks_msec() <= expire_msec

func _estimate_elapsed_ratio(area: Area2D) -> float:
	if area == null or not is_instance_valid(area):
		return 1.0
	var created_msec: int = int(area.get_meta("created_msec", -1))
	if created_msec <= 0:
		area.set_meta("created_msec", Time.get_ticks_msec())
		return 0.0
	var elapsed: float = float(Time.get_ticks_msec() - created_msec) / 1000.0
	return clamp(elapsed / max(0.1, storm_eye_duration), 0.0, 1.0)

func _extract_enemies(area: Area2D) -> Array:
	var result: Array = []
	var overlaps: Array = area.get_overlapping_bodies() + area.get_overlapping_areas()
	for target_obj: Variant in overlaps:
		if target_obj == null or not is_instance_valid(target_obj):
			continue
		var enemy: Node2D = _resolve_enemy(target_obj)
		if enemy == null:
			continue
		if result.has(enemy):
			continue
		result.append(enemy)
	return result

func _resolve_enemy(target_obj: Variant) -> Node2D:
	if target_obj is Node2D and target_obj.is_in_group("enemies"):
		return target_obj
	if target_obj is Area2D:
		var area_target: Area2D = target_obj
		if area_target.owner and area_target.owner is Node2D and area_target.owner.is_in_group("enemies"):
			return area_target.owner
	return null

func _apply_damage(enemy: Node2D, amount: int) -> void:
	if not enemy.has_node("HealthComponent"):
		return
	var hc: Node = enemy.get_node("HealthComponent")
	if hc != null and hc.has_method("take_damage"):
		hc.call("take_damage", max(1, amount))

func _apply_status(enemy: Node2D, status_name: String, duration: float, value: float, stacks: int = 1, tick_interval: float = 0.6) -> void:
	if enemy.has_method("apply_status"):
		enemy.call("apply_status", status_name, max(0.1, duration), value, max(1, stacks), max(0.05, tick_interval))

func _build_circle_points(radius: float, steps: int) -> PackedVector2Array:
	var points: PackedVector2Array = PackedVector2Array()
	var safe_steps: int = max(8, steps)
	for i: int in range(safe_steps):
		var angle: float = TAU * float(i) / float(safe_steps)
		points.append(Vector2(cos(angle), sin(angle)) * radius)
	return points

func _queue_free_if_valid(node_ref: WeakRef) -> void:
	var node_obj: Variant = node_ref.get_ref() if node_ref != null else null
	if node_obj != null and is_instance_valid(node_obj):
		node_obj.queue_free()

func cleanup() -> void:
	for effect_obj: Variant in spawned_effects:
		if effect_obj != null and is_instance_valid(effect_obj):
			effect_obj.queue_free()
	spawned_effects.clear()
