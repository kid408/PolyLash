extends SkillBase
class_name SkillFireNova

var fire_nova_radius: float = 165.0
var fire_nova_damage: int = 44
var fire_nova_duration: float = 4.8
var damage_tick_interval: float = 0.35
var oil_slow_value: float = 0.30
var oil_mark_amp: float = 0.22
var ignite_bonus_damage: int = 18
var ignition_burst_damage: int = 54
var ignition_knockback: float = 380.0

var spawned_effects: Array[Node] = []
const FIRE_ACTIVE_META: String = "pyro_fire_active_until_msec"

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
	var synergy_mode: bool = _is_fire_window_active()
	call_deferred("_spawn_oil_zone", center_pos, synergy_mode)
	Global.on_camera_shake.emit(6.6, 0.12)
	Global.spawn_floating_text(center_pos, "OIL FILM+" if synergy_mode else "OIL FILM", Color(1.0, 0.68, 0.15))
	start_cooldown()

func _spawn_oil_zone(center_pos: Vector2, synergy_mode: bool) -> void:
	var radius: float = fire_nova_radius * (1.12 if synergy_mode else 1.0)
	var tick_interval: float = damage_tick_interval * (0.82 if synergy_mode else 1.0)
	var burst_damage: int = int(round(float(ignition_burst_damage) * (1.2 if synergy_mode else 1.0)))
	var area: Area2D = Area2D.new()
	area.global_position = center_pos
	area.collision_layer = 0
	area.collision_mask = 1 | 2
	area.monitorable = false
	area.monitoring = true
	area.name = "PyroOilZone_%s" % str(Time.get_ticks_msec())

	var col: CollisionShape2D = CollisionShape2D.new()
	var shape: CircleShape2D = CircleShape2D.new()
	shape.radius = radius
	col.shape = shape
	area.add_child(col)

	var vis: Polygon2D = Polygon2D.new()
	vis.polygon = _build_circle_points(radius, 36)
	vis.color = Color(1.2, 0.6, 0.12, 0.46) if synergy_mode else Color(1.0, 0.5, 0.08, 0.42)
	vis.z_index = 9
	area.add_child(vis)

	get_tree().current_scene.add_child(area)
	area.add_to_group("player_skill_effects")
	spawned_effects.append(area)

	var appear_tween: Tween = area.create_tween()
	vis.scale = Vector2(0.2, 0.2)
	appear_tween.tween_property(vis, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_BACK)

	var tick_timer: Timer = Timer.new()
	tick_timer.wait_time = max(0.08, tick_interval)
	tick_timer.one_shot = false
	tick_timer.autostart = true
	area.add_child(tick_timer)
	tick_timer.timeout.connect(_on_oil_tick.bind(weakref(area), synergy_mode))

	var life_timer: SceneTreeTimer = get_tree().create_timer(max(0.2, fire_nova_duration))
	life_timer.timeout.connect(_on_oil_expired.bind(weakref(area), weakref(vis), burst_damage, synergy_mode))

func _on_oil_tick(area_ref: WeakRef, synergy_mode: bool) -> void:
	var area_obj: Variant = area_ref.get_ref() if area_ref != null else null
	if area_obj == null or not is_instance_valid(area_obj):
		return
	if not (area_obj is Area2D):
		return
	var area: Area2D = area_obj

	for enemy in _extract_enemies(area):
		_apply_status(enemy, "slow", 0.8, oil_slow_value, 1, 0.12)
		_apply_status(enemy, "marked", 1.2, oil_mark_amp, 1, 0.25)

		var ignite_damage: int = max(1, ignite_bonus_damage)
		if enemy.has_method("has_status") and bool(enemy.call("has_status", "burn")):
			ignite_damage = max(ignite_damage, int(round(float(ignite_bonus_damage) * 1.8)))
		elif synergy_mode:
			ignite_damage = max(ignite_damage, int(round(float(ignite_bonus_damage) * 1.28)))
		_apply_damage(enemy, ignite_damage)
		_apply_status(enemy, "burn", 1.6, float(max(1, int(round(float(ignite_damage) * 0.45)))), 1, 0.5)

func _on_oil_expired(area_ref: WeakRef, visual_ref: WeakRef, burst_damage: int, synergy_mode: bool) -> void:
	var area_obj: Variant = area_ref.get_ref() if area_ref != null else null
	if area_obj == null or not is_instance_valid(area_obj):
		return
	if not (area_obj is Area2D):
		return
	var area: Area2D = area_obj

	var impacted: int = 0
	for enemy in _extract_enemies(area):
		_apply_damage(enemy, burst_damage)
		_apply_status(enemy, "burn", 2.1, float(max(1, int(round(float(burst_damage) * 0.32)))), 1, 0.5)
		_apply_status(enemy, "slow", 0.9, min(0.75, oil_slow_value + 0.12), 1, 0.1)
		if enemy.has_method("apply_knockback"):
			var dir: Vector2 = (enemy.global_position - area.global_position).normalized()
			enemy.call("apply_knockback", dir, ignition_knockback)
		impacted += 1

	if impacted > 0:
		Global.spawn_floating_text(area.global_position, "IGNITE+ x%d" % impacted if synergy_mode else "IGNITE x%d" % impacted, Color(1.25, 0.6, 0.2))
		spawn_skill_vfx(area.global_position, Color(1.3, 0.52, 0.12, 0.86), 0.85)
		Global.on_camera_shake.emit(8.0 + float(impacted) * 0.25, 0.15)

	var visual_obj: Variant = visual_ref.get_ref() if visual_ref != null else null
	if visual_obj != null and is_instance_valid(visual_obj):
		var vis: Node = visual_obj
		var fade_tween: Tween = area.create_tween()
		fade_tween.tween_property(vis, "modulate:a", 0.0, 0.18)
		fade_tween.tween_callback(_queue_free_if_valid.bind(weakref(area)))
	else:
		area.queue_free()

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

func _is_fire_window_active() -> bool:
	if not is_instance_valid(skill_owner):
		return false
	if not skill_owner.has_meta(FIRE_ACTIVE_META):
		return false
	var expire_msec: int = int(skill_owner.get_meta(FIRE_ACTIVE_META, 0))
	return Time.get_ticks_msec() <= expire_msec
