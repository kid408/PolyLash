extends SkillQBase
class_name SkillLurewardenLoop

# Core parameters from config/player/skill_params_wide.csv (skill_lurewarden_loop).
var dash_damage: int = 1
var dash_base_damage: int = 10
var dash_knockback: float = 2.0

# Role signature tuning.
var pen_duration: float = 5.6
var pen_pull_force: float = 220.0
var pack_mark_damage_amp: float = 0.16
var execute_bonus_damage: int = 68
var execute_threshold_ratio: float = 0.32
var energy_refund_ratio: float = 0.25
var fence_width: float = 20.0
var dash_speed: float = 1450.0
var dash_turn_lerp: float = 0.22
var decoy_line_duration: float = 2.8
var decoy_pen_duration: float = 4.2
var decoy_taunt_radius: float = 420.0
var decoy_tick_interval: float = 0.25
var decoy_max_count: int = 4

const PEN_META_CENTER: String = "lurewarden_pen_center"
const PEN_META_RADIUS: String = "lurewarden_pen_radius"
const PEN_META_EXPIRE_MSEC: String = "lurewarden_pen_expire_msec"
const DECOY_GROUP: String = "lurewarden_decoys"
const DECOY_OWNER_META: String = "lurewarden_owner_id"
const DECOY_CREATED_META: String = "lurewarden_created_msec"

func charge(delta: float) -> void:
	super.charge(delta)
	_dash_along_brush(delta)

func _dash_along_brush(delta: float) -> void:
	if not is_planning or not is_drawing:
		return
	if not is_instance_valid(skill_owner):
		return
	var target: Vector2 = skill_owner.get_global_mouse_position()
	var to_target: Vector2 = target - skill_owner.global_position
	var distance: float = to_target.length()
	if distance <= 2.0:
		return
	var desired_dir: Vector2 = to_target / distance
	var current_dir: Vector2 = Vector2.RIGHT.rotated(skill_owner.rotation)
	var dash_dir: Vector2 = current_dir.lerp(desired_dir, dash_turn_lerp).normalized()
	var step: float = min(distance, dash_speed * delta)
	skill_owner.global_position += dash_dir * step
	skill_owner.rotation = dash_dir.angle()

func _spawn_line_effect(start: Vector2, end: Vector2) -> void:
	var duration: float = max(_get_line_duration(), 2.4)
	var lane_damage: int = max(1, dash_base_damage)
	var pull_force: float = max(100.0, pen_pull_force * 0.55)
	var lane_width: float = max(14.0, fence_width)

	SkillEffectManager.create_line_effect({
		"start": start,
		"end": end,
		"width": lane_width,
		"damage": lane_damage,
		"damage_interval": 0.24,
		"duration": duration,
		"color": Color(1.05, 0.88, 0.28, 0.9),
		"pull_to_line": true,
		"pull_force": pull_force,
		"pull_interval": 0.06
	})

	SkillEffectManager.create_debuff_zone({
		"start": start,
		"end": end,
		"width": lane_width + 8.0,
		"duration": duration,
		"debuff_type": "slow",
		"debuff_value": 0.44,
		"debuff_duration": 1.0,
		"tick_interval": 0.35,
		"color": Color(1.0, 0.9, 0.35, 0.2)
	})

	SkillEffectManager.create_debuff_zone({
		"start": start,
		"end": end,
		"width": lane_width + 4.0,
		"duration": duration,
		"debuff_type": "marked",
		"debuff_value": pack_mark_damage_amp * 0.75,
		"debuff_duration": 1.2,
		"tick_interval": 0.4,
		"color": Color(1.0, 0.82, 0.25, 0.16)
	})

	_spawn_decoy_lure(start.lerp(end, 0.68), max(decoy_line_duration, duration * 0.72), false)

func _spawn_area_effect(polygon: PackedVector2Array) -> void:
	if polygon.size() < 3:
		return

	var duration: float = max(3.0, pen_duration)
	var ring_damage: int = max(1, int(round(float(dash_base_damage) * 1.25)))
	var ring_pull_force: float = max(140.0, pen_pull_force)

	_spawn_pen_fence(polygon, duration)

	SkillEffectManager.create_area_effect({
		"polygon": polygon,
		"damage": ring_damage,
		"damage_interval": 0.28,
		"duration": duration,
		"color": Color(1.0, 0.78, 0.2, 0.45),
		"pull_to_center": true,
		"pull_force": ring_pull_force,
		"pull_interval": 0.06
	})

	SkillEffectManager.create_debuff_zone({
		"polygon": polygon,
		"duration": duration,
		"debuff_type": "slow",
		"debuff_value": 0.52,
		"debuff_duration": 1.2,
		"tick_interval": 0.35,
		"color": Color(1.0, 0.86, 0.3, 0.24)
	})

	SkillEffectManager.create_debuff_zone({
		"polygon": polygon,
		"duration": duration,
		"debuff_type": "marked",
		"debuff_value": pack_mark_damage_amp,
		"debuff_duration": 1.6,
		"tick_interval": 0.45,
		"color": Color(1.0, 0.72, 0.2, 0.18)
	})

	_cache_pen_snapshot(polygon, duration)
	_apply_execute_sweep(polygon)
	_spawn_decoy_lure(_polygon_center(polygon), max(decoy_pen_duration, duration * 0.82), true)

func _cache_pen_snapshot(polygon: PackedVector2Array, duration: float) -> void:
	if not is_instance_valid(skill_owner):
		return
	var center: Vector2 = _polygon_center(polygon)
	var radius: float = _polygon_radius(polygon, center)
	var expire_msec: int = Time.get_ticks_msec() + int(round(duration * 1000.0))
	skill_owner.set_meta(PEN_META_CENTER, center)
	skill_owner.set_meta(PEN_META_RADIUS, radius)
	skill_owner.set_meta(PEN_META_EXPIRE_MSEC, expire_msec)

func _spawn_pen_fence(polygon: PackedVector2Array, duration: float) -> void:
	var point_count: int = polygon.size()
	if point_count < 3:
		return
	for i: int in range(point_count):
		var start: Vector2 = polygon[i]
		var end: Vector2 = polygon[(i + 1) % point_count]
		SkillEffectManager.create_wall_effect({
			"start": start,
			"end": end,
			"width": max(10.0, fence_width * 0.6),
			"duration": duration,
			"block_enemies": true,
			"block_bullets": true,
			"contact_damage": max(1, int(round(float(dash_base_damage) * 0.5))),
			"contact_interval": 0.32,
			"color": Color(1.1, 0.9, 0.35, 0.82)
		})

func _apply_execute_sweep(polygon: PackedVector2Array) -> void:
	var execute_count: int = 0
	var hit_count: int = 0
	var enemies: Array = get_tree().get_nodes_in_group("enemies")
	for enemy_obj: Variant in enemies:
		if enemy_obj == null or not is_instance_valid(enemy_obj):
			continue
		if not (enemy_obj is Node2D):
			continue
		var enemy: Node2D = enemy_obj
		if not Geometry2D.is_point_in_polygon(enemy.global_position, polygon):
			continue
		if not enemy.has_node("HealthComponent"):
			continue

		var hc: Node = enemy.get_node("HealthComponent")
		var hp_ratio: float = 1.0
		if hc != null and "max_health" in hc and "current_health" in hc:
			var max_hp: float = max(1.0, float(hc.get("max_health")))
			hp_ratio = float(hc.get("current_health")) / max_hp

		var damage: int = max(1, int(round(float(dash_base_damage) * 1.4)))
		if hp_ratio <= execute_threshold_ratio:
			damage = max(damage, execute_bonus_damage)
			execute_count += 1
		else:
			hit_count += 1

		if hc != null and hc.has_method("take_damage"):
			hc.call("take_damage", damage)
		if enemy.has_method("apply_status"):
			enemy.call("apply_status", "slow", 0.8, 0.42)
			enemy.call("apply_status", "marked", 1.2, pack_mark_damage_amp * 0.85)

	if execute_count > 0:
		_grant_execute_refund(execute_count)

	if execute_count > 0 or hit_count > 0:
		var center: Vector2 = _polygon_center(polygon)
		Global.spawn_floating_text(
			center,
			"HERD EXEC %d / HIT %d" % [execute_count, hit_count],
			Color(1.2, 1.0, 0.4)
		)
		spawn_skill_vfx(center, Color(1.15, 0.88, 0.3, 0.9), 0.75)
		Global.on_camera_shake.emit(6.0 + float(execute_count) * 0.8, 0.14)

func _grant_execute_refund(execute_count: int) -> void:
	if execute_count <= 0:
		return
	if not is_instance_valid(skill_owner):
		return
	if not skill_owner.has_method("gain_energy"):
		return
	var base_refund: float = max(1.0, energy_cost * energy_refund_ratio)
	var total_refund: float = base_refund * float(execute_count)
	skill_owner.call("gain_energy", total_refund)

func _spawn_decoy_lure(pos: Vector2, duration: float, closure_phase: bool) -> void:
	if not is_instance_valid(skill_owner) or not is_inside_tree():
		return
	if _has_owned_decoy_near(pos, 96.0):
		return
	_trim_owned_decoys(decoy_max_count - 1)
	var decoy := Node2D.new()
	decoy.name = "LurewardenDecoy"
	decoy.global_position = pos
	decoy.z_index = 58
	decoy.add_to_group("player")
	decoy.add_to_group("player_skill_effects")
	decoy.add_to_group(DECOY_GROUP)
	decoy.set_meta(DECOY_OWNER_META, skill_owner.get_instance_id())
	decoy.set_meta(DECOY_CREATED_META, Time.get_ticks_msec())
	decoy.set_meta("closure_phase", closure_phase)

	var marker := Polygon2D.new()
	marker.polygon = PackedVector2Array([
		Vector2(0, -22),
		Vector2(18, 0),
		Vector2(0, 22),
		Vector2(-18, 0),
	])
	marker.color = Color(1.0, 0.92, 0.32, 0.95)
	decoy.add_child(marker)

	if closure_phase:
		var ring := Polygon2D.new()
		ring.polygon = PackedVector2Array([
			Vector2(0, -34),
			Vector2(26, 0),
			Vector2(0, 34),
			Vector2(-26, 0),
		])
		ring.color = Color(1.0, 0.72, 0.22, 0.34)
		decoy.add_child(ring)

	var scene: Node = get_tree().current_scene if get_tree() != null else null
	if scene != null:
		scene.add_child(decoy)
	else:
		add_child(decoy)

	var taunt_timer := Timer.new()
	taunt_timer.wait_time = max(0.12, decoy_tick_interval)
	taunt_timer.one_shot = false
	taunt_timer.autostart = true
	decoy.add_child(taunt_timer)
	taunt_timer.timeout.connect(_on_decoy_taunt_tick.bind(weakref(decoy), closure_phase))

	var life_timer := Timer.new()
	life_timer.wait_time = max(0.5, duration)
	life_timer.one_shot = true
	life_timer.autostart = true
	decoy.add_child(life_timer)
	life_timer.timeout.connect(_on_decoy_expire.bind(weakref(decoy)))

	spawn_skill_vfx(pos, Color(1.0, 0.92, 0.3, 0.68), 0.34)
	if closure_phase:
		Global.spawn_floating_text(pos, "DECOY!", Color(1.0, 0.92, 0.38))

func _on_decoy_taunt_tick(decoy_ref: WeakRef, closure_phase: bool) -> void:
	var decoy_obj: Variant = decoy_ref.get_ref() if decoy_ref != null else null
	if decoy_obj == null or not is_instance_valid(decoy_obj):
		return
	if not (decoy_obj is Node2D):
		return
	var decoy: Node2D = decoy_obj
	var taunt_radius: float = decoy_taunt_radius * (1.18 if closure_phase else 1.0)
	for enemy_obj: Variant in get_tree().get_nodes_in_group("enemies"):
		if enemy_obj == null or not is_instance_valid(enemy_obj):
			continue
		if not (enemy_obj is Node2D):
			continue
		var enemy: Node2D = enemy_obj
		if enemy.global_position.distance_to(decoy.global_position) > taunt_radius:
			continue
		if enemy.has_method("set_taunt_target"):
			enemy.call("set_taunt_target", decoy)
		if enemy.has_method("apply_status"):
			enemy.call("apply_status", "marked", 0.9 if not closure_phase else 1.3, pack_mark_damage_amp * (0.55 if not closure_phase else 0.9), 1, 0.2)
			enemy.call("apply_status", "slow", 0.55 if not closure_phase else 0.8, 0.18 if not closure_phase else 0.26, 1, 0.1)

func _on_decoy_expire(decoy_ref: WeakRef) -> void:
	var decoy_obj: Variant = decoy_ref.get_ref() if decoy_ref != null else null
	if decoy_obj == null or not is_instance_valid(decoy_obj):
		return
	if not (decoy_obj is Node2D):
		return
	var decoy: Node2D = decoy_obj
	spawn_skill_vfx(decoy.global_position, Color(1.0, 0.82, 0.28, 0.42), 0.24)
	decoy.queue_free()

func _owned_decoys() -> Array[Node2D]:
	var result: Array[Node2D] = []
	if not is_inside_tree() or not is_instance_valid(skill_owner):
		return result
	for node_var: Variant in get_tree().get_nodes_in_group(DECOY_GROUP):
		if node_var == null or not is_instance_valid(node_var):
			continue
		if not (node_var is Node2D):
			continue
		var node: Node2D = node_var
		if int(node.get_meta(DECOY_OWNER_META, 0)) != skill_owner.get_instance_id():
			continue
		result.append(node)
	return result

func _has_owned_decoy_near(pos: Vector2, min_distance: float) -> bool:
	for decoy: Node2D in _owned_decoys():
		if decoy.global_position.distance_to(pos) < min_distance:
			return true
	return false

func _trim_owned_decoys(max_count: int) -> void:
	var decoys: Array[Node2D] = _owned_decoys()
	if decoys.size() <= max_count:
		return
	decoys.sort_custom(func(a: Node2D, b: Node2D) -> bool:
		return int(a.get_meta(DECOY_CREATED_META, 0)) < int(b.get_meta(DECOY_CREATED_META, 0))
	)
	var remove_count: int = decoys.size() - max_count
	for i: int in range(remove_count):
		if is_instance_valid(decoys[i]):
			decoys[i].queue_free()

func _clear_owned_decoys() -> void:
	for decoy: Node2D in _owned_decoys():
		if is_instance_valid(decoy):
			decoy.queue_free()

func _polygon_center(polygon: PackedVector2Array) -> Vector2:
	if polygon.is_empty():
		return Vector2.ZERO
	var center: Vector2 = Vector2.ZERO
	for point: Vector2 in polygon:
		center += point
	return center / float(polygon.size())

func _polygon_radius(polygon: PackedVector2Array, center: Vector2) -> float:
	var radius: float = 0.0
	for point: Vector2 in polygon:
		radius = max(radius, center.distance_to(point))
	return max(8.0, radius)

func _get_line_color() -> Color:
	return Color(1.05, 0.9, 0.3, 1.0)

func _get_closure_color() -> Color:
	return Color(1.2, 0.7, 0.18, 1.0)

func _get_q_asset_kind(is_closed_path: bool) -> String:
	return "lurewarden_pen" if is_closed_path else "lurewarden_lane"

func _get_q_asset_duration(is_closed_path: bool) -> float:
	return max(pen_duration, 1.0) if is_closed_path else max(_get_line_duration(), 2.4)

func _build_q_asset_payload(
	is_closed_path: bool,
	segment_count: int,
	polygon_count: int,
	center: Vector2,
	radius: float
) -> Dictionary:
	return {
		"role_id": "lurewarden",
		"is_closed": is_closed_path,
		"segment_count": segment_count,
		"polygon_count": polygon_count,
		"center": center,
		"radius": radius,
		"execute_bonus_damage": execute_bonus_damage,
		"pack_mark_damage_amp": pack_mark_damage_amp,
	}

func cleanup() -> void:
	_clear_owned_decoys()
	super.cleanup()

